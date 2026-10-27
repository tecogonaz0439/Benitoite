//! 独立交換のキー・元ソース対応を実際の型検査済み入力から確かめる。
// 関門: 番号と順序は Lean と共有する外部の契約であり、データ構造の選択ではない。
// 既存の脱糖検査は元 NodeId/span や未取得の接頭辞を出力しない。
// 型検査器・solver・名前解決は本物を使い、本番の差し込み口は増やさない。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::super::budget::{Budget, Cap, Limits};
use super::super::input::BodySource;
use super::*;
use crate::types::builtin::BuiltinTypeId as B;

fn numbering_budget(operations: u64, items: u64) -> Budget {
    Budget {
        limits: Limits {
            body: Cap { operations, items },
            whole: Cap { operations, items },
        },
        ..Budget::default()
    }
}

fn numbering_stop(resource: super::super::budget::Resource) -> IdentityStop {
    IdentityStop::AnalysisBudget(super::super::budget::StopReason::Unidentified(
        super::super::budget::LimitFailure {
            scope: super::super::budget::Scope::Body,
            resource,
        },
    ))
}

use crate::typeck::{
    context::{Body, fixed, lift, reason},
    decls::{Decls, Scope},
    generate,
    infer::{Constraint, ReasonKind},
};
use crate::types::EffectSet;

fn fixture(source: &str, check: impl FnOnce(&[BodyInput<'_>], &InputTables<'_>)) {
    fixture_owned(source, |inputs, tables| check(&inputs, tables));
}

pub(in crate::typeck::interval) fn fixture_owned(
    source: &str,
    check: impl FnOnce(Vec<BodyInput<'_>>, &InputTables<'_>),
) {
    fixture_files_owned(&[("main.bnt", source)], check);
}

pub(in crate::typeck::interval) fn fixture_files_owned(
    files: &[(&str, &str)],
    check: impl FnOnce(Vec<BodyInput<'_>>, &InputTables<'_>),
) {
    fixture_files_batched(files, 1, |mut batches, tables| {
        check(batches.pop().unwrap(), tables)
    });
}

// 同じ解決済み Body から各試行の入力を収集する。本番の入力へ Clone や検査用フラグを足さない。
pub(in crate::typeck::interval) fn fixture_files_batched(
    files: &[(&str, &str)],
    copies: usize,
    check: impl FnOnce(Vec<Vec<BodyInput<'_>>>, &InputTables<'_>),
) {
    let (load, resolved, output, diagnostics) =
        crate::typeck::test_support::check_files(files, false);
    assert!(
        !diagnostics.iter().any(crate::diag::Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    let mut decls = Decls::new(&load.modules, &load.asts, &load.sources, &resolved);
    decls.out = output;
    let definitions: Vec<_> =
        super::super::input::definitions(&load.asts, &load.modules, &resolved)
            .map(Result::unwrap)
            .filter(|d| {
                !load.modules.get(d.order.module).is_some_and(|m| {
                    matches!(
                        m.kind,
                        crate::modules::ModuleKind::Prelude | crate::modules::ModuleKind::Stdlib
                    )
                })
            })
            .collect();
    let mut batches: Vec<Vec<_>> = (0..copies).map(|_| Vec::new()).collect();
    for definition in definitions {
        let scheme = decls
            .out
            .decl_types
            .get(definition.binding)
            .unwrap()
            .clone();
        // finish 前の収集を本物の Body/solver で再現する。型表を手作りしない。
        let mut body = Body::new(
            &mut decls,
            definition.order.module,
            Scope::default(),
            scheme,
        );
        match definition.source {
            BodySource::Function {
                declaration,
                body: block,
            } => {
                body.owner = Some(declaration.id);
                body.return_annotation = Some(declaration.ret.span());
                for (param, ty) in declaration.params.iter().zip(body.scheme.params.clone()) {
                    let ty = lift(&ty);
                    body.locals
                        .insert(*resolved.decls.get(param.id).unwrap(), ty.clone());
                    body.record_type(param.id, ty);
                }
                let ty = body.block(block);
                generate::equal(
                    &mut body,
                    generate::basic(B::UNIT),
                    ty,
                    block.span,
                    ReasonKind::FnBody,
                );
                body.add(Constraint::EffSub {
                    sub: body.body_effect.clone(),
                    sup: fixed(body.scheme.effects.clone()),
                    reason: reason(declaration.name.span, ReasonKind::FnUses),
                });
            }
            BodySource::Constant(c) => {
                body.ret = None;
                body.effect = fixed(EffectSet::empty());
                let ty = body.expr(&c.value);
                let expected = lift(&body.scheme.ret);
                generate::equal(
                    &mut body,
                    expected,
                    ty,
                    c.value.span(),
                    ReasonKind::ConstValue,
                );
            }
        }
        body.solve();
        for batch in &mut batches {
            batch.push(BodyInput::collect(definition.clone(), &body, true).unwrap());
        }
    }
    check(
        batches,
        &InputTables {
            resolved: &resolved,
            constants: &decls.out.consts,
            literals: &decls.out.lit_values,
            range_bounds: &decls.out.range_bounds,
            schemes: &decls.out.decl_types,
        },
    );
}

fn build<'ast>(
    inputs: &[BodyInput<'ast>],
    tables: &InputTables<'_>,
    name: &str,
    operations: u64,
    saved: u64,
    fuel: u32,
) -> IdentityMap<'ast> {
    let input = inputs
        .iter()
        .find(|i| i.definition.name.ends_with(&format!(".{name}")))
        .unwrap();
    let constants = inputs
        .iter()
        .filter(|i| matches!(i.definition.source, BodySource::Constant(_)))
        .map(|i| (i.definition.binding, i))
        .collect();
    IdentityMap::build(
        input,
        tables,
        &constants,
        &mut numbering_budget(operations, saved),
        fuel,
    )
}

fn text(source: &str, entry: &Occurrence<'_>) -> String {
    let span = entry.origin.unwrap().span;
    source[usize::try_from(span.start.0).unwrap()..usize::try_from(span.end.0).unwrap()].to_owned()
}

#[test]
fn source_order_negative_literals_and_return_keep_surface_keys() {
    let source = "function pair(first: Integer, second: Integer) -> Integer\n return first + second\nend function\nfunction order(a: Integer, b: Integer) -> Integer\n bind direct <- -7\n bind general <- -(a)\n return pair(second: b, first: a)\nend function\n";
    fixture(source, |inputs, tables| {
        let map = build(inputs, tables, "order", 1000, 1000, 100);
        assert_eq!(map.stopped, None);
        assert_eq!(
            map.occurrences.iter().map(|e| e.form).collect::<Vec<_>>(),
            [
                F::Block,
                F::NegInt,
                F::Neg,
                F::Paren,
                F::Local,
                F::Return,
                F::Call,
                F::FunName,
                F::Local,
                F::Local
            ]
        );
        assert!(map.occurrences.get(0).unwrap().origin.is_none());
        assert_eq!(text(source, &map.occurrences.get(1).unwrap()), "-7");
        assert_eq!(text(source, &map.occurrences.get(2).unwrap()), "-(a)");
        assert_eq!(text(source, &map.occurrences.get(8).unwrap()), "b");
        assert_eq!(text(source, &map.occurrences.get(9).unwrap()), "a");
        assert_eq!(map.occurrences.get(8).unwrap().parent, Some(6));
        assert_eq!(map.occurrences.get(5).unwrap().end, Some(10));
        assert_eq!(map.key(9).unwrap().surface_preorder, 9);
        assert!(map.key(10).is_none());
    });
}

#[test]
fn direct_negative_minima_and_zero_are_single_surface_occurrences() {
    let source = "function negatives() -> Unit\n bind _ <- -9223372036854775808\n bind _ <- -128s8\n bind _ <- -32768s16\n bind _ <- -2147483648s32\n bind _ <- -1.0\n bind _ <- -1.0f32\n bind _ <- -1m\n bind _ <- -0\nend function\n";
    fixture(source, |inputs, tables| {
        let map = build(inputs, tables, "negatives", 1000, 1000, 100);
        assert_eq!(map.stopped, None);
        assert_eq!(
            map.occurrences.iter().map(|e| e.form).collect::<Vec<_>>(),
            [
                F::Block,
                F::NegInt,
                F::NegInteger8,
                F::NegInteger16,
                F::NegInteger32,
                F::NegFloat,
                F::NegFloat32,
                F::NegDecimal,
                F::Literal
            ]
        );
        assert_eq!(
            text(source, &map.occurrences.get(1).unwrap()),
            "-9223372036854775808"
        );
        assert_eq!(text(source, &map.occurrences.get(8).unwrap()), "-0");
        assert!(map.occurrences.iter().skip(1).all(|e| e.parent == Some(0)));
    });
}

#[test]
fn unknown_children_and_synthetic_functions_have_source_origins() {
    let source = "function shapes(xs: List[Integer], s: String) -> String\n bind values <- [1, ..xs, 2]\n return \"${1}${s}${2}\"\nend function\n";
    fixture(source, |inputs, tables| {
        let map = build(inputs, tables, "shapes", 1000, 1000, 100);
        assert_eq!(map.stopped, None);
        assert_eq!(
            map.occurrences.iter().map(|e| e.form).collect::<Vec<_>>(),
            [
                F::Block,
                F::ListSpread,
                F::PrimName,
                F::Literal,
                F::Local,
                F::Literal,
                F::Return,
                F::Interpolation,
                F::Literal,
                F::Local,
                F::Literal,
                F::PrimName,
                F::PrimName
            ]
        );
        assert_eq!(
            map.occurrences.get(1).unwrap().origin,
            map.occurrences.get(2).unwrap().origin
        );
        assert_eq!(
            map.occurrences.get(8).unwrap().origin.unwrap().node,
            map.occurrences.get(11).unwrap().origin.unwrap().node
        );
        assert_eq!(text(source, &map.occurrences.get(11).unwrap()), "${1}");
        assert_eq!(text(source, &map.occurrences.get(12).unwrap()), "${2}");
        assert!(matches!(
            map.occurrences.get(11).unwrap().source,
            SourceNode::Synthetic(Synthetic::InterpolationConverter)
        ));
    });
}

#[test]
fn embedded_constants_use_original_types_and_multiple_occurrences() {
    let source =
        "const c: Integer = 1 + 2\nfunction twice() -> Integer\n return c + c\nend function\n";
    fixture(source, |inputs, tables| {
        let map = build(inputs, tables, "twice", 1000, 1000, 100);
        assert_eq!(map.stopped, None);
        assert_eq!(
            map.occurrences.iter().map(|e| e.form).collect::<Vec<_>>(),
            [
                F::Block,
                F::Return,
                F::Binary,
                F::Const,
                F::Binary,
                F::Literal,
                F::Literal,
                F::Const,
                F::Binary,
                F::Literal,
                F::Literal
            ]
        );
        assert_eq!(
            map.occurrences.get(4).unwrap().origin,
            map.occurrences.get(8).unwrap().origin
        );
        assert_eq!(text(source, &map.occurrences.get(4).unwrap()), "1 + 2");
        assert_ne!(
            map.occurrences.get(3).unwrap().origin,
            map.occurrences.get(7).unwrap().origin
        );
        assert_ne!(
            map.occurrences.get(3).unwrap().type_owner,
            map.occurrences.get(4).unwrap().type_owner
        );
        let constant = build(inputs, tables, "c", 1000, 1000, 100);
        assert_eq!(constant.next, 4);
        assert_eq!(
            constant.occurrences.get(1).unwrap().origin,
            map.occurrences.get(4).unwrap().origin
        );
        let input = inputs
            .iter()
            .find(|i| i.definition.name.ends_with(".twice"))
            .unwrap();
        let missing = IdentityMap::build(
            input,
            tables,
            &BTreeMap::new(),
            &mut numbering_budget(1000, 1000),
            100,
        );
        assert!(matches!(
            missing.stopped,
            Some(IdentityStop::MissingConstant(_))
        ));
        assert_eq!(missing.next, 4);
    });
}

#[test]
fn numbering_stops_with_prefix_instead_of_renumbering() {
    fixture(
        "function limited() -> Integer\n return 1 + 2\nend function\n",
        |inputs, tables| {
            // 五つの出現と、その取得時に必要な作業枠を合わせた保持上限。
            // 旧番号付け専用予算の「保存5項」を、全保持の緩い上限で置き換えない。
            let complete = build(inputs, tables, "limited", 1000, 10, 100);
            assert_eq!(complete.stopped, None);
            assert_eq!(complete.next, 5);
            for (operations, saved, fuel, expected) in [
                (
                    0,
                    1000,
                    100,
                    numbering_stop(super::super::budget::Resource::Operations),
                ),
                (
                    1000,
                    0,
                    100,
                    numbering_stop(super::super::budget::Resource::Items),
                ),
                (
                    1000,
                    4,
                    100,
                    numbering_stop(super::super::budget::Resource::Items),
                ),
                (
                    1000,
                    9,
                    100,
                    numbering_stop(super::super::budget::Resource::Items),
                ),
                (1000, 1000, 2, IdentityStop::Depth),
            ] {
                let stopped = build(inputs, tables, "limited", operations, saved, fuel);
                assert_eq!(stopped.stopped, Some(expected));
                assert_eq!(
                    stopped
                        .occurrences
                        .iter()
                        .map(|e| e.preorder)
                        .collect::<Vec<_>>(),
                    (0..stopped.next).collect::<Vec<_>>()
                );
                assert_eq!(
                    stopped
                        .occurrences
                        .iter()
                        .map(|e| e.origin)
                        .collect::<Vec<_>>(),
                    complete
                        .occurrences
                        .iter()
                        .take(stopped.occurrences.len())
                        .map(|e| e.origin)
                        .collect::<Vec<_>>()
                );
                assert!(
                    stopped
                        .occurrences
                        .iter()
                        .all(|e| e.end.is_none_or(|end| end <= stopped.next))
                );
            }
            let input = inputs
                .iter()
                .find(|i| i.definition.name.ends_with(".limited"))
                .unwrap();
            let mut budget = numbering_budget(1000, 1000);
            IdentityMap::build(input, tables, &BTreeMap::new(), &mut budget, 100);
            let exact_operations = budget.body.operations;
            assert_eq!(
                build(inputs, tables, "limited", exact_operations, 1000, 100).stopped,
                None
            );
            assert_eq!(
                build(inputs, tables, "limited", exact_operations - 1, 1000, 100).stopped,
                Some(numbering_stop(super::super::budget::Resource::Operations))
            );
        },
    );
}

#[test]
fn builder_slots_try_actions_and_nested_with_do_not_invent_ast_children() {
    let source = "import Benitoite.StringBuilder\nimport Benitoite.Unofficial.IO.Process\nfunction builder() -> String\n bind b: StringBuilder <- StringBuilder.new()\n StringBuilder.append(text: \"a\", builder: b)\n return StringBuilder.copy(b)\nend function\nfunction result(r: Result[Integer, String]) -> Result[Integer, String]\n bind n <- try r\n return Result.Ok(n)\nend function\nfunction option(o: Option[Integer]) -> Integer uses Process.Exit\n return try o or die(\"message\")\nend function\nfunction resources() -> Unit uses State\n with first = TaskGroup.open(), second = TaskGroup.open() do\n ()\n end with\nend function\n";
    fixture(source, |inputs, tables| {
        for (name, expected) in [
            (
                "builder",
                vec![F::Block, F::BuilderOp, F::Literal, F::Return, F::BuilderOp],
            ),
            (
                "result",
                vec![
                    F::Block,
                    F::TryResult,
                    F::Local,
                    F::Return,
                    F::ConCall,
                    F::Local,
                ],
            ),
            (
                "option",
                vec![F::Block, F::Return, F::TryOptionDie, F::Local, F::Literal],
            ),
            (
                "resources",
                vec![
                    F::Block,
                    F::With,
                    F::Call,
                    F::PrimName,
                    F::With,
                    F::Call,
                    F::PrimName,
                    F::Unit,
                ],
            ),
        ] {
            let map = build(inputs, tables, name, 1000, 1000, 100);
            assert_eq!(map.stopped, None, "{name}");
            assert_eq!(
                map.occurrences.iter().map(|e| e.form).collect::<Vec<_>>(),
                expected,
                "{name}"
            );
            if name == "resources" {
                assert_eq!(
                    text(source, &map.occurrences.get(4).unwrap()),
                    "second = TaskGroup.open()"
                );
                assert!(matches!(
                    map.occurrences.get(4).unwrap().source,
                    SourceNode::WithBinding(_, 1)
                ));
            }
        }
    });
}

// 関門: 復元した別本体の範囲と命名は、独立交換が読む元の番号の契約である。
// 発見を本物の型付き入力に接続し、節を内側の本体より先に登録する順序も守る。
#[test]
fn boundaries_keep_original_preorders_and_clause_order() {
    let source = "effect E\n function get() -> Integer\n function other() -> Integer\nend effect\nfunction boundaries() -> Unit uses State\n bind f <- lambda() -> Lazy[Integer] return lazy 1 end lazy end lambda\n bind n <- handle get() with\n case get() -> resume(2)\n case other() -> resume(3)\n end handle\nend function\n";
    fixture(source, |inputs, tables| {
        let input = inputs
            .iter()
            .find(|i| i.definition.name.ends_with(".boundaries"))
            .unwrap();
        let mut budget = Budget::default();
        let seed =
            super::super::discovery::prepare_root(input, tables, &BTreeMap::new(), &mut budget)
                .unwrap();
        let report = super::super::discovery::discover(
            input,
            tables,
            &BTreeMap::new(),
            seed,
            &mut budget,
            100,
        );
        assert_eq!(report.result, Ok(()));
        assert_eq!(report.queue, Some(Ok(())));
        assert_eq!(budget.body.temporary, 0);
        let bodies: Vec<_> = report.entries.iter().map(|e| &e.embedded).collect();
        assert_eq!(
            bodies
                .iter()
                .map(|b| (b.owner, b.ordinal, b.parent_start, b.parent_end))
                .collect::<Vec<_>>(),
            [
                (1, 0, Some(2), Some(5)),
                (3, 0, Some(4), Some(5)),
                (5, 0, Some(8), Some(10)),
                (5, 1, Some(10), Some(12)),
            ]
        );
        assert_eq!(
            bodies[1].definition(&input.definition.name),
            format!("{}%body:3:0", input.definition.name)
        );
        assert!(bodies[1].parent_key(&input.definition.name, 0).is_none());
        assert_eq!(
            bodies[1]
                .parent_key(&input.definition.name, 1)
                .unwrap()
                .surface_preorder,
            4
        );
        assert!(bodies[1].parent_key(&input.definition.name, 2).is_none());
    });
}

#[test]
fn failure_clause_and_empty_lambda_keep_body_ranges() {
    let source = "import Benitoite.Unofficial.Failure\nfunction risky() -> Integer uses Failure.Fail[String]\n return 0\nend function\nfunction recovery() -> Integer\n return handle risky() with\n case Failure.raise(error) -> 7\n end handle\nend function\nfunction empty() -> Unit\n bind f <- lambda() -> Unit end lambda\nend function\n";
    fixture(source, |inputs, tables| {
        for (name, expected) in [("recovery", (5, 6)), ("empty", (2, 2))] {
            let input = inputs
                .iter()
                .find(|i| i.definition.name.ends_with(&format!(".{name}")))
                .unwrap();
            let mut budget = Budget::default();
            let seed =
                super::super::discovery::prepare_root(input, tables, &BTreeMap::new(), &mut budget)
                    .unwrap();
            let report = super::super::discovery::discover(
                input,
                tables,
                &BTreeMap::new(),
                seed,
                &mut budget,
                100,
            );
            assert_eq!(report.result, Ok(()));
            assert_eq!(report.entries.len(), 1);
            let body = &report.entries[0].embedded;
            assert_eq!(
                (body.parent_start, body.parent_end),
                (Some(expected.0), Some(expected.1))
            );
            if name == "empty" {
                assert!(body.parent_key(&input.definition.name, 1).is_none());
            }
        }
    });
}
