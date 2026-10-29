//! 型検査の公開入口が返す入力と、Lean の規則から手で数えた独立期待値。
// 関門: 独立した契約は標準の同一性、引数の契約位置、先行順、入口の辞書位置である。
// コンテナや穴を数える、名前付き引数を並べ替えて数える、入れ子を0へ戻す退行を捕まえる。
// 既存の区間の検査は合成した本体根を数え、Scope の先頭右辺0を検査しない。
// 読み込み・名前解決・型検査は本物を使い、テスト用の本番差し込み口を増やさない。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

use super::*;

#[path = "measure.rs"]
mod measure;

// 関門: 通常ソースから、入力の増加に対する費用と予算による忘却を測る。
// 数え方の単体検査では、標準宣言の登録・推論・大きい入力の費用を確認できない。
#[test]
#[ignore = "long: measures scope analysis budget on growing source inputs"]
fn measure_scope_budget() {
    measure::run();
}

fn check(source: &str) -> (crate::resolve::ResolveOutput, crate::typeck::TypeckOutput) {
    let (_, resolved, out, diagnostics) =
        crate::typeck::test_support::check_files(&[(".bnt", source)], false);
    assert!(
        !diagnostics.iter().any(crate::diag::Diagnostic::is_error),
        "{diagnostics:#?}"
    );
    (resolved, out)
}

fn body(out: &crate::typeck::TypeckOutput, name: &str) -> ScopeNumberedInput {
    let body = out
        .scope_inputs
        .bodies
        .iter()
        .find(|b| b.body_key.definition == name)
        .unwrap_or_else(|| {
            panic!(
                "missing {name}, found {:?}",
                out.scope_inputs
                    .bodies
                    .iter()
                    .map(|b| &b.body_key.definition)
                    .collect::<Vec<_>>()
            )
        });
    let body = body.numbered(DEFAULT_NUMBERING_OPERATIONS);
    assert_eq!(body.body_key.surface_preorder, 0);
    assert_eq!(body.stopped, None);
    body
}

#[test]
fn source_preorder_keeps_nested_bodies_guards_and_named_arguments() {
    let source = r#"import Benitoite.Unofficial.Scope
function sample(path: String) -> Unit
 bind checked <- Scope.checkPathIn(path: path, pattern: "/data/**")
 bind f <- lambda(x: String) -> Unit
  bind _ <- Scope.checkPathIn(pattern: "/tmp/**", path: x)
  ()
 end lambda
 bind delayed <- lazy
  Scope.checkPathIn(pattern: "/cache/**", path: path)
 end lazy
 bind _ <- match true with
 case true if false -> Scope.checkPathIn(pattern: "/a/**", path: path)
 case _ -> Scope.checkPathIn(pattern: "/a/**", path: path)
 end match
 ()
end function
"#;
    let (resolved, out) = check(source);
    let sample = body(&out, ".sample");
    // 手計算: call0/callee1/path2/pattern3, lambda4/call5..8/unit9,
    // lazy10/call11..14, match15/scrutinee16/guard17/call18..21/call22..25/unit26。
    assert_eq!(sample.occurrences.len(), 27);
    assert_eq!(
        sample.calls.iter().map(|c| c.preorder).collect::<Vec<_>>(),
        [0, 5, 11, 18, 22]
    );
    assert_eq!(
        sample
            .statements
            .iter()
            .map(|s| s.preorder)
            .collect::<Vec<_>>(),
        [0, 4, 5, 9, 10, 11, 15, 18, 22, 26]
    );
    for statement in &sample.statements {
        assert_eq!(
            sample.occurrences[usize::try_from(statement.preorder).unwrap()].origin,
            ScopeOrigin::Expression(statement.rhs)
        );
    }
    let call = &sample.calls[0];
    assert_eq!(
        call.binding,
        resolved.stdlib("Benitoite.Scope.checkPathIn").unwrap()
    );
    assert_eq!(call.declaration, ScopeDeclaration::CheckPath);
    assert_eq!(call.argument_preorders, [2, 3]);
    assert_eq!(call.source_to_contract, [1, 0]);
    assert_eq!(
        call.contract_to_source,
        [
            ScopeArgumentSource::Explicit(1),
            ScopeArgumentSource::Explicit(0)
        ]
    );
    assert_eq!(sample.entry.dictionaries, 0);
    assert_eq!(sample.entry.next_id, 1);
}

#[test]
fn entry_scope_matches_explicit_function_and_method_arguments() {
    let source = r#"import Benitoite.Unofficial.Scope
trait Inspect[T]
 function inspect[U: Inspect](value: T, other: U) -> Unit
end trait
implement[T: Inspect] Inspect[List[T]]
 function inspect[U: Inspect](value: List[T], other: U) -> Unit
  bind _ <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
  ()
 end function
end implement
function constrained[T: Inspect](value: T) -> Unit
 bind _ <- Scope.checkPathIn(pattern: "/tmp/**", path: "/tmp/a")
 ()
end function
"#;
    let (resolved, out) = check(source);
    for (name, dictionaries, values, next) in
        [("%impl:1:0:inspect", 1, 2, 3), (".constrained", 1, 1, 2)]
    {
        let input = body(&out, name);
        assert_eq!(input.entry.dictionaries, dictionaries);
        assert_eq!(input.entry.next_id, next);
        assert_eq!(input.entry.positions.len(), dictionaries + values);
        assert!(input.entry.positions[values..].iter().all(Option::is_none));
        let value_names: Vec<_> = input.entry.positions[..values]
            .iter()
            .map(|b| resolved.bindings.get(b.unwrap()).unwrap().name.as_str())
            .collect();
        assert_eq!(
            value_names,
            if values == 2 {
                vec!["other", "value"]
            } else {
                vec!["value"]
            }
        );
        assert_eq!(
            input.calls.iter().map(|c| c.preorder).collect::<Vec<_>>(),
            [0]
        );
        assert_eq!(
            input
                .statements
                .iter()
                .map(|s| s.preorder)
                .collect::<Vec<_>>(),
            [0, 4]
        );
    }
    assert!(
        out.scope_inputs
            .bodies
            .iter()
            .any(|b| b.body_key.definition.starts_with("Benitoite.")),
        "standard bodies are included"
    );
}

#[test]
fn standard_identity_and_contract_order_use_resolved_declarations() {
    let source = r#"import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.Network.Http
function checkPathIn(pattern: String, path: String) -> String
 return path
end function
function sample(request: Http.ClientRequest, path: Scope.PathIn, checked: Http.RequestIn) -> Unit
 bind _ <- Http.checkRequestIn(request: request, maximumPort: 443, hostPattern: "api.example", minimumPort: 80)
 bind _ <- Scope.pathInValue(path)
 bind _ <- Http.requestInValue(checked)
 bind _ <- Scope.checkPathIn(pattern: "/**", path: "/a")
 bind _ <- checkPathIn(pattern: "/**", path: "/a")
 bind _ <- Scope.checkPath(pattern: "/**", path: "/a")
 bind indirect <- Scope.checkPathIn
 bind _ <- indirect(pattern: "/**", path: "/a")
 ()
end function
"#;
    let (resolved, out) = check(source);
    let input = body(&out, ".sample");
    assert_eq!(
        input
            .calls
            .iter()
            .map(|c| (c.preorder, c.declaration))
            .collect::<Vec<_>>(),
        [
            (0, ScopeDeclaration::CheckRequest),
            (6, ScopeDeclaration::PathValue),
            (9, ScopeDeclaration::RequestValue),
            (12, ScopeDeclaration::CheckPath)
        ]
    );
    assert_eq!(input.calls[0].argument_preorders, [2, 3, 4, 5]);
    assert_eq!(input.calls[0].source_to_contract, [3, 2, 0, 1]);
    assert_eq!(
        input.calls[0].contract_to_source,
        [2, 3, 1, 0].map(ScopeArgumentSource::Explicit)
    );
    assert_eq!(
        input.calls[0].binding,
        resolved
            .stdlib("Benitoite.Network.Http.checkRequestIn")
            .unwrap()
    );
    assert_eq!(
        input.calls[1].binding,
        resolved.stdlib("Benitoite.Scope.pathInValue").unwrap()
    );
    assert_eq!(
        input.calls[2].binding,
        resolved
            .stdlib("Benitoite.Network.Http.requestInValue")
            .unwrap()
    );
    assert_eq!(
        input
            .statements
            .iter()
            .map(|s| s.preorder)
            .collect::<Vec<_>>(),
        [0, 6, 9, 12, 16, 20, 24, 25, 29]
    );
    assert_eq!(input.occurrences.len(), 30);
}

#[test]
fn normalization_counts_const_bodies_and_only_present_interpolation_converters() {
    let source = r#"import Benitoite.Unofficial.Scope
const number: Integer = 7
const pattern: String = "/**"
function sample(text: String) -> Unit
 bind xs <- [1, ..[2], 3]
 bind message <- "${text}:${number}"
 bind _ <- Scope.checkPathIn(pattern: pattern, path: text)
 bind _ <- Scope.checkPathIn(path: text, pattern: pattern)
 ()
end function
"#;
    let (_, out) = check(source);
    let input = body(&out, ".sample");
    // listSpread0/concat1/int2/list3/int4/int5; interpolation6/text7/const8/int9/converter10;
    // call11/callee12/const13/pattern14/text15、call16/callee17/text18/const19/pattern20、unit21。
    assert_eq!(
        input
            .statements
            .iter()
            .map(|s| s.preorder)
            .collect::<Vec<_>>(),
        [0, 6, 11, 16, 21]
    );
    assert_eq!(input.calls[0].preorder, 11);
    assert_eq!(input.occurrences.len(), 22);
    assert_eq!(input.calls[0].argument_preorders, [13, 15]);
    assert_eq!(input.calls[1].argument_preorders, [18, 19]);
    assert_eq!(input.calls[1].source_to_contract, [1, 0]);
    assert_eq!(input.occurrences[14].origin, input.occurrences[20].origin);
    assert_ne!(
        input.occurrences[14].preorder,
        input.occurrences[20].preorder
    );
    assert!(matches!(
        input.occurrences[1].origin,
        ScopeOrigin::ListConcatenate(_)
    ));
    assert!(matches!(
        input.occurrences[10].origin,
        ScopeOrigin::InterpolationConverter(_)
    ));
    assert_eq!(
        input
            .occurrences
            .iter()
            .filter(|e| matches!(e.origin, ScopeOrigin::InterpolationConverter(_)))
            .count(),
        1
    );
    assert!(
        out.scope_inputs
            .bodies
            .iter()
            .find(|b| b.body_key.definition == ".sample")
            .unwrap()
            .contains_rules()
    );
    assert!(
        !out.scope_inputs
            .bodies
            .iter()
            .find(|b| b.body_key.definition == ".pattern")
            .unwrap()
            .contains_rules()
    );
    let constant = body(&out, ".number");
    assert_eq!(constant.occurrences.len(), 1);
    assert_eq!(constant.statements[0].preorder, 0);

    // 全本体を列挙したまま、末尾一つだけを読む。根0、定数の子を一段ずつ進め、
    // 深さ4096までの4097出現を残す。停止後に葉を詰めて補わない。
    let mut chain = String::from("const d0: Integer = 0\n");
    for index in 1..=4097 {
        chain.push_str(&format!("const d{index}: Integer = d{}\n", index - 1));
    }
    // 長い入力は通常の公開パイプラインと同じ段ごとのスタックで検査する。
    let checked = crate::pipeline::check_text(
        "scope-chain.bnt",
        chain.as_bytes(),
        crate::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let out = checked.program.unwrap().types;
    let chain_bodies: Vec<_> = out
        .scope_inputs
        .bodies
        .iter()
        .filter(|b| b.body_key.definition.starts_with(".d"))
        .collect();
    assert_eq!(chain_bodies.len(), 4098);
    let tail = chain_bodies.last().unwrap();
    assert!(!tail.contains_rules());
    let numbered = tail.numbered(DEFAULT_NUMBERING_OPERATIONS);
    assert_eq!(numbered.stopped, Some(ScopeInputStop::Depth));
    assert_eq!(numbered.occurrences.len(), 4097);
    assert_eq!(numbered.occurrences.last().unwrap().preorder, 4096);
}

#[test]
fn dedicated_bindings_and_handler_clauses_follow_surface_preorder() {
    let source = r#"import Benitoite.StringBuilder
import Benitoite.Unofficial.IO.Process
effect E
 function get() -> Integer
 function other() -> Integer
end effect
function builder() -> String
 bind b: StringBuilder <- StringBuilder.new()
 StringBuilder.append(text: "a", builder: b)
 return StringBuilder.copy(b)
end function
function resources() -> Unit uses State
 with first = TaskGroup.open(), second = TaskGroup.open() do
 ()
 end with
end function
function handlers() -> Unit
 bind n <- handle get() with
 case get() -> resume(2)
 case other() -> resume(3)
 end handle
 ()
end function
function partial() -> function(a: Integer) -> Integer
 return Integer.minimum(a: _, b: -1)
end function
"#;
    let (_, out) = check(source);
    // 専用束縛は0個、append0/text1/return2/copy3。
    let builder = body(&out, ".builder");
    assert_eq!(builder.occurrences.len(), 4);
    assert_eq!(
        builder
            .statements
            .iter()
            .map(|s| s.preorder)
            .collect::<Vec<_>>(),
        [0, 2]
    );
    // with0/open-call1/callee2/with3/open-call4/callee5/unit6。
    let resources = body(&out, ".resources");
    assert_eq!(resources.occurrences.len(), 7);
    assert_eq!(
        resources
            .statements
            .iter()
            .map(|s| s.preorder)
            .collect::<Vec<_>>(),
        [0, 3, 6]
    );
    assert!(matches!(
        resources.occurrences[3].origin,
        ScopeOrigin::WithBinding(_)
    ));
    // handle0/get-call1/callee2/最初の節resume3/int4/次の節resume5/int6/unit7。
    let handlers = body(&out, ".handlers");
    assert_eq!(handlers.occurrences.len(), 8);
    assert_eq!(
        handlers
            .statements
            .iter()
            .map(|s| s.preorder)
            .collect::<Vec<_>>(),
        [0, 1, 3, 5, 7]
    );
    // return0/partialCall1/callee2/negInt3。穴は0個、負のリテラルは子を持たない。
    let partial = body(&out, ".partial");
    assert_eq!(partial.occurrences.len(), 4);
    assert_eq!(
        partial
            .statements
            .iter()
            .map(|s| s.preorder)
            .collect::<Vec<_>>(),
        [0]
    );
}

// 関門: パイプの内側の標準呼び出しも primResolve の対象である。
// 既存の直接呼び出しの表は、左辺から引数を受ける右辺の取り落としを捕まえない。
// 普通の公開入口から三つの位置を通し、Lean の先行順から数えた値を使う。
#[test]
fn pipe_calls_keep_rules_on_left_inside_arguments_and_on_right() {
    let source = r#"import Benitoite.Unofficial.Scope
function ignore[T](value: T) -> Unit
 ()
end function
function left(p: String) -> Unit
 bind _ <- Scope.checkPathIn(pattern: "/**", path: p) |> ignore()
 ()
end function
function nested(p: String) -> Unit
 ignore(Scope.checkPathIn(pattern: "/**", path: p))
end function
function right(p: String) -> Unit
 bind _ <- "/**" |> Scope.checkPathIn(path: p)
 ()
end function
"#;
    let checked = crate::pipeline::check_text(
        "scope-pipe.bnt",
        source.as_bytes(),
        crate::pipeline::CheckOptions {
            require_main: false,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let out = checked.program.unwrap().types;
    for (name, preorder, arguments) in [
        (".left", 1, vec![3, 4]),
        (".nested", 2, vec![4, 5]),
        (".right", 2, vec![4]),
    ] {
        let source = out
            .scope_inputs
            .bodies
            .iter()
            .find(|b| b.body_key.definition == name)
            .unwrap();
        assert!(source.contains_rules(), "{name}");
        let input = body(&out, name);
        assert_eq!(input.calls.len(), 1, "{name}");
        assert_eq!(input.calls[0].preorder, preorder, "{name}");
        assert_eq!(input.calls[0].argument_preorders, arguments, "{name}");
        let call = &input.calls[0];
        assert_eq!(call.declaration, ScopeDeclaration::CheckPath);
        if name == ".right" {
            let ScopeOrigin::Expression(lhs) = input.occurrences[1].origin else {
                panic!("left operand");
            };
            assert_eq!(call.source_to_contract, [1]);
            assert_eq!(
                call.contract_to_source,
                [
                    ScopeArgumentSource::PipeLeft(lhs),
                    ScopeArgumentSource::Explicit(0)
                ]
            );
        } else {
            assert_eq!(call.source_to_contract, [0, 1]);
            assert_eq!(
                call.contract_to_source,
                [0, 1].map(ScopeArgumentSource::Explicit)
            );
        }
    }
}

// 関門: 数十行の共有定数から指数個の出現を展開しても、予算内で止まる。
// 深さ停止の既存例は共有先を一回ずつしか使わず、この増え方を捕まえない。
// 公開パイプラインと上限付きの読み取りを使い、取得済みの接頭辞を確認する。
#[test]
fn shared_constants_stop_numbering_at_the_operation_budget() {
    let (levels, limit) = if cfg!(feature = "gc-stress") {
        ([8, 12], 128)
    } else {
        ([22, 40], DEFAULT_NUMBERING_OPERATIONS)
    };
    for level in levels {
        let mut source = String::from("import Benitoite.Unofficial.Scope\nconst c0: Integer = 0\n");
        for index in 1..=level {
            let previous = index - 1;
            source.push_str(&format!(
                "const c{index}: Integer = c{previous} + c{previous}\n"
            ));
        }
        source.push_str(&format!("function sample() -> Unit\n bind _ <- Scope.checkPathIn(pattern: \"/**\", path: \"/a\")\n bind _ <- c{level}\n ()\nend function\n"));
        let checked = crate::pipeline::check_text(
            "scope-shared.bnt",
            source.as_bytes(),
            crate::pipeline::CheckOptions {
                require_main: false,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let out = checked.program.unwrap().types;
        let input = out
            .scope_inputs
            .bodies
            .iter()
            .find(|b| b.body_key.definition == ".sample")
            .unwrap();
        assert!(input.contains_rules());
        for budget in [0, limit] {
            let numbered = input.numbered(budget);
            eprintln!(
                "shared level={level} budget={budget} occurrences={} stop={:?}",
                numbered.occurrences.len(),
                numbered.stopped
            );
            assert_eq!(
                numbered.stopped,
                Some(ScopeInputStop::NumberingLimit {
                    max_operations: budget
                })
            );
            assert!(u64::try_from(numbered.occurrences.len()).unwrap() <= budget);
            assert!(
                numbered
                    .occurrences
                    .iter()
                    .enumerate()
                    .all(|(i, e)| u64::try_from(i).unwrap() == e.preorder)
            );
            if budget == 0 {
                assert!(numbered.calls.is_empty());
                assert!(numbered.statements.is_empty());
            } else {
                assert_eq!(numbered.calls.len(), 1);
                assert_eq!(numbered.calls[0].preorder, 0);
                assert_eq!(
                    numbered
                        .statements
                        .iter()
                        .map(|s| s.preorder)
                        .collect::<Vec<_>>(),
                    [0, 4]
                );
                assert!(!numbered.occurrences.is_empty());
            }
        }
    }
}

// 関門: 解決済み入力が欠けた定義を、全本体の判定から黙って除外しない。
// 通常の成功ソースでは欠落は発生しないため、実際の名前解決結果から該当項目だけを落とす。
// 収集の入口で停止理由を観察し、テスト専用の本番APIは増やさない。
#[test]
fn missing_definition_inputs_remain_as_stopped_bodies() {
    let source = "const number: Integer = 7\ntrait Inspect[T]\n function inspect(value: T) -> Unit\nend trait\nimplement Inspect[Integer]\n function inspect(value: Integer) -> Unit\n ()\n end function\nend implement\nfunction sample() -> Unit\n ()\nend function\n";
    let (load, mut resolved, out, diagnostics) =
        crate::typeck::test_support::check_files(&[(".bnt", source)], false);
    assert!(
        !diagnostics.iter().any(crate::diag::Diagnostic::is_error),
        "{diagnostics:?}"
    );
    let definitions: Vec<_> =
        crate::typeck::source_input::definitions(&load.asts, &load.modules, &resolved)
            .map(Result::unwrap)
            .filter(|d| d.name == ".number" || d.name == ".sample" || d.name == "%impl:2:0:inspect")
            .map(|d| (d.name, d.source.node()))
            .collect();
    assert_eq!(definitions.len(), 3);
    resolved.decls = resolved
        .decls
        .iter()
        .filter(|(node, _)| !definitions.iter().any(|(_, missing)| node == missing))
        .fold(NodeMap::new(), |mut map, (node, binding)| {
            map.insert(node, *binding);
            map
        });
    let inputs = Inputs::collect(
        &load.asts,
        &load.modules,
        &resolved,
        &out.decl_types,
        &out.impls,
    )
    .finish();
    for (name, node) in definitions {
        let input = inputs
            .bodies
            .iter()
            .find(|b| b.body_key.definition == name)
            .unwrap();
        assert_eq!(input.binding, None);
        assert!(input.contains_rules());
        let numbered = input.numbered(DEFAULT_NUMBERING_OPERATIONS);
        assert_eq!(numbered.stopped, Some(ScopeInputStop::MissingInput(node)));
        assert!(numbered.occurrences.is_empty());
    }
}
