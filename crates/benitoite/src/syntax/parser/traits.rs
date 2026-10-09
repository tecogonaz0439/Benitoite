//! 型クラス・実装・組み込みの制約の解析（設計書 01-02「型クラス」、02-03「文脈の制限」）。
use super::{Fail, PResult, Parser, Recovery, child, decls, items, text, types};
use crate::base::SourceKind;
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::{ast::*, token::TokenKind};

pub(super) fn parse_trait_decl(p: &mut Parser, depth: u32) -> PResult<Item> {
    p.enter(depth)?;
    let start = p.pos;
    let opened = p.bump().span;
    let name = p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?;
    p.expect(TokenKind::LBracket)?;
    let param = parse_trait_param(p, child(depth))?;
    p.expect(TokenKind::RBracket)?;
    p.open_block(TokenKind::KwTrait, opened);
    let mut methods = Vec::new();
    p.skip_newlines();
    while !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) && !p.symbol("}") && !p.aborted {
        let from = p.pos;
        if push_method(p, child(depth), &mut methods).is_err() {
            if p.aborted {
                return Err(Fail);
            }
            p.recover(from, Recovery::Line);
        }
        finish_line(p, from);
    }
    p.close_block(TokenKind::KwTrait);
    Ok(Item::Trait(TraitDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        param,
        methods,
    }))
}

fn parse_trait_param(p: &mut Parser, depth: u32) -> PResult<TypeParamDecl> {
    p.enter(depth)?;
    let start = p.pos;
    let name = p.expect_name(TokenKind::UpperIdent, text::TYPE_PARAMETER)?;
    let kind = if p.eat(TokenKind::LBracket) {
        let mut arity = 0_u32;
        loop {
            p.expect(TokenKind::Underscore)?;
            arity = arity.saturating_add(1);
            if !p.eat(TokenKind::Comma) {
                break;
            }
        }
        p.expect(TokenKind::RBracket)?;
        TypeParamKind::Ctor { arity }
    } else {
        TypeParamKind::Value
    };
    let mut constraints = Vec::new();
    if p.eat(TokenKind::Colon) {
        let colon = p.span_from(p.pos.saturating_sub(1));
        let mut separator = colon;
        loop {
            let from = p.pos;
            if p.at(TokenKind::LowerIdent) {
                let invalid = p.bump();
                // 唯一の制約なら ':' も取り除き、途中なら隣の '&' も取り除く。
                // 修正後も制約の並びを読めるようにする（設計書 02-10「修正案」）。
                let remove = if constraints.is_empty() && p.at(TokenKind::Amp) {
                    invalid.span.to(p.peek().span)
                } else {
                    separator.to(invalid.span)
                };
                p.report(
                    DiagBuilder::new(DiagCode::E0223)
                        .arg("name", p.snippet(invalid.span))
                        .primary(invalid.span)
                        .help_edits(
                            "remove",
                            vec![Edit {
                                span: remove,
                                replacement: String::new(),
                            }],
                        )
                        .build(),
                );
            } else {
                p.enter(child(depth))?;
                let path = p.qual_name(true)?;
                constraints.push(ConstraintRef::Class(ClassRef {
                    id: p.node_id(),
                    span: p.span_from(from),
                    path,
                }));
            }
            if !p.at(TokenKind::Amp) {
                break;
            }
            separator = p.bump().span;
        }
    }
    Ok(TypeParamDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        kind,
        constraints,
    })
}

fn push_method(p: &mut Parser, depth: u32, out: &mut Vec<MethodSig>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let doc = p.docs.take_for(p.peek().span, &mut p.diagnostics);
    let sig = decls::parse_signature(p, depth)?;
    out.push(MethodSig {
        id: p.node_id(),
        span: p.span_from(start),
        doc,
        name: sig.name,
        type_params: sig.type_params,
        params: sig.params,
        ret: sig.ret,
        uses: sig.uses,
    });
    Ok(())
}

pub(super) fn parse_impl_decl(p: &mut Parser, depth: u32) -> PResult<Item> {
    p.enter(depth)?;
    let start = p.pos;
    let opened = p.bump().span;
    let type_params = types::parse_type_params(p, depth, true)?;
    let from = p.pos;
    let path = p.qual_name(true)?;
    let class = ClassRef {
        id: p.node_id(),
        span: p.span_from(from),
        path,
    };
    if !p.at(TokenKind::LBracket) {
        p.report(
            DiagBuilder::new(DiagCode::E0245)
                .arg("name", p.snippet(class.span))
                .primary(opened.to(class.span))
                .help("functions")
                .build(),
        );
        skip_implementation(p);
        return Ok(Item::Error(p.error_node_from(start)));
    }
    p.bump();
    let target = *types::parse_type(p, child(depth))?;
    p.expect(TokenKind::RBracket)?;
    p.open_block(TokenKind::KwImplement, opened);
    let mut fns = Vec::new();
    p.skip_newlines();
    while !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) && !p.symbol("}") && !p.aborted {
        let from = p.pos;
        let open = p.blocks.len();
        let saved = p.ctx;
        if push_impl_fn(p, child(depth), &mut fns).is_err() {
            if p.aborted {
                return Err(Fail);
            }
            p.recover(from, Recovery::Line);
            p.blocks.truncate(open);
        }
        p.ctx = saved;
        finish_line(p, from);
    }
    p.close_block(TokenKind::KwImplement);
    Ok(Item::Impl(ImplDecl {
        id: p.node_id(),
        span: p.span_from(start),
        type_params,
        class,
        target,
        fns,
    }))
}
fn push_impl_fn(p: &mut Parser, depth: u32, out: &mut Vec<ImplFn>) -> PResult<()> {
    let doc = p.docs.take_for(p.peek().span, &mut p.diagnostics);
    if let Some(span) = items::parse_public(p) {
        items::reject_public(p, span);
    }
    let decl = decls::parse_function(p, depth, items::BodyRule::Required, &[])?;
    out.push(ImplFn {
        id: p.node_id(),
        doc,
        decl,
    });
    Ok(())
}
fn finish_line(p: &mut Parser, from: usize) {
    if p.pos == from && !p.at(TokenKind::Eof) {
        p.advance();
    }
    if !matches!(
        p.peek_kind(),
        TokenKind::Newline | TokenKind::KwEnd | TokenKind::Eof
    ) && !p.symbol("}")
    {
        p.unexpected(text::NEWLINE_OR_END);
        p.recover(p.pos, Recovery::Line);
    }
    p.skip_newlines();
}
fn skip_implementation(p: &mut Parser) {
    let mut nesting = 0_u32;
    while !p.at(TokenKind::Eof) && !p.aborted {
        if p.at(TokenKind::KwEnd) && p.peek_nth_kind(1) == TokenKind::KwImplement {
            p.advance();
            p.advance();
            if nesting == 0 {
                break;
            }
            nesting = nesting.saturating_sub(1);
        } else {
            if p.at(TokenKind::KwImplement) {
                nesting = nesting.saturating_add(1);
            }
            p.advance();
        }
    }
}
pub(super) fn builtin_constraint(p: &mut Parser, name: &Name) -> Option<BuiltinConstraint> {
    match name.text.as_str() {
        "equality" => Some(BuiltinConstraint::Equality),
        "key" => Some(BuiltinConstraint::Key),
        "ordered" if p.kind == SourceKind::Prelude => Some(BuiltinConstraint::Ordered),
        _ => {
            let key = if name.text == "ordered" {
                "ordered"
            } else {
                "builtin"
            };
            p.report(
                DiagBuilder::new(DiagCode::E0222)
                    .arg("name", &name.text)
                    .primary(name.span)
                    .help(key)
                    .build(),
            );
            None
        }
    }
}

#[cfg(test)]
// 公開の parse の AST と診断を守る。仮の本体のテストでは新構文の意味を確かめられない。
// 本物の字句解析・改行判定を使い、テストの失敗は panic で表す（設計書 07-03、test-audit）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::super::test_support::{assert_recovers, codes, parse_source, position};
    use super::*;

    fn user(src: &str) -> super::super::ParseOutput {
        let (out, lex) = parse_source(src, SourceKind::User);
        assert!(lex.is_empty(), "{src}: {lex:?}");
        out
    }
    #[test]
    fn trait_parameters_supertraits_and_method_signatures() {
        for (header, kind, supers) in [
            (
                "Monoid[T: Semigroup]",
                TypeParamKind::Value,
                vec!["Semigroup"],
            ),
            ("Functor[F[_]]", TypeParamKind::Ctor { arity: 1 }, vec![]),
            (
                "Traversable[F[_]: Functor & M.Foldable]",
                TypeParamKind::Ctor { arity: 1 },
                vec!["Functor", "M.Foldable"],
            ),
        ] {
            let src = format!(
                "trait {header}\n/// method documentation\nfunction empty[A: Show](x: A) -> T uses Console.Write\nend trait"
            );
            let out = user(&src);
            assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
            let Item::Trait(t) = &out.module.decls[0].item else {
                panic!()
            };
            assert_eq!(t.param.kind, kind);
            let paths: Vec<_> = t
                .param
                .constraints
                .iter()
                .map(|c| match c {
                    ConstraintRef::Class(c) => c
                        .path
                        .iter()
                        .map(|n| n.text.as_str())
                        .collect::<Vec<_>>()
                        .join("."),
                    _ => panic!(),
                })
                .collect();
            assert_eq!(paths, supers);
            assert_eq!(t.methods.len(), 1);
            let m = &t.methods[0];
            assert_eq!(m.name.text, "empty");
            assert!(m.doc.is_some());
            assert_eq!(m.type_params.len(), 1);
            assert_eq!(m.params[0].name.text, "x");
            assert!(matches!(&m.ret, TypeExpr::Named(t) if t.path[0].text == "T"));
            assert!(m.uses.is_some());
            assert_eq!(t.span.start, position(&src, "trait").unwrap());
            assert_eq!(m.span.end, position(&src, "\nend trait").unwrap());
        }
        // メソッド名の重なりは名前解決の持ち物（ADR 0279）。
        let out = user("trait T[A]\nfunction f() -> A\nfunction f() -> A\nend trait");
        assert!(out.diagnostics.is_empty());
    }
    #[test]
    fn implementation_functions_keep_docs_and_distinct_reference_ids() {
        let src = "implement[T: Show] M.Show[List[T]]\n/// show the list\npublic function show(xs: List[T]) -> String\nreturn \"list\"\nend function\nend implement";
        let out = user(src);
        assert_eq!(codes(&out), [DiagCode::E0221]);
        assert_eq!(
            out.diagnostics[0].primary.as_ref().unwrap().span.start,
            position(src, "public").unwrap()
        );
        let Item::Impl(i) = &out.module.decls[0].item else {
            panic!()
        };
        assert_eq!(i.type_params.len(), 1);
        assert_eq!(
            i.class
                .path
                .iter()
                .map(|n| n.text.as_str())
                .collect::<Vec<_>>(),
            ["M", "Show"]
        );
        assert!(
            matches!(&i.target, TypeExpr::Named(t) if t.path[0].text == "List" && t.args.len() == 1)
        );
        assert_eq!(i.fns.len(), 1);
        assert_ne!(i.fns[0].id, i.fns[0].decl.id);
        assert!(i.fns[0].doc.is_some());
        assert_eq!(i.fns[0].decl.name.text, "show");
        assert!(i.fns[0].decl.body.is_some());
        assert_recovers(
            "implement Person\nfunction f() -> Unit\n()\nend function\nend implement",
            &[DiagCode::E0245],
        );
    }
    #[test]
    fn constraint_diagnostics_remove_only_the_invalid_constraint() {
        for (src, kind, expected, key) in [
            (
                "function f[T: equality & key]() -> Unit\n()\nend function",
                SourceKind::User,
                None,
                "",
            ),
            (
                "function f[T: ordered]() -> Unit\n()\nend function",
                SourceKind::User,
                Some(DiagCode::E0222),
                "ordered",
            ),
            (
                "function f[T: ordered]() -> Unit\n()\nend function",
                SourceKind::Prelude,
                None,
                "",
            ),
            (
                "function f[T: equality & eq & key]() -> Unit\n()\nend function",
                SourceKind::User,
                Some(DiagCode::E0222),
                "builtin",
            ),
        ] {
            let (out, lex) = parse_source(src, kind);
            assert!(lex.is_empty());
            assert_eq!(codes(&out), expected.into_iter().collect::<Vec<_>>());
            let Item::Fn(f) = &out.module.decls[0].item else {
                panic!()
            };
            let constraints = &f.type_params[0].constraints;
            if src.contains("equality") {
                assert!(matches!(
                    constraints.as_slice(),
                    [
                        ConstraintRef::Builtin {
                            kind: BuiltinConstraint::Equality,
                            ..
                        },
                        ConstraintRef::Builtin {
                            kind: BuiltinConstraint::Key,
                            ..
                        }
                    ]
                ));
            } else if kind == SourceKind::Prelude {
                assert!(matches!(
                    constraints.as_slice(),
                    [ConstraintRef::Builtin {
                        kind: BuiltinConstraint::Ordered,
                        ..
                    }]
                ));
            } else {
                assert!(constraints.is_empty());
            }
            if expected.is_some() {
                assert!(
                    out.diagnostics[0].helps[0]
                        .message
                        .contains(if key == "ordered" {
                            "standard library"
                        } else {
                            "`equality` and `key`"
                        })
                );
                let word = if key == "ordered" { "ordered" } else { "eq &" };
                assert_eq!(
                    out.diagnostics[0].primary.as_ref().unwrap().span.start,
                    position(src, word).unwrap()
                );
            }
        }
        for header in [
            "Eq[T: equality]",
            "Eq[T: equality & Show]",
            "Eq[T: Show & key]",
        ] {
            let src = format!("trait {header}\nfunction f() -> T\nend trait");
            let out = user(&src);
            assert_eq!(codes(&out), [DiagCode::E0223]);
            let edit = &out.diagnostics[0].helps[0].edits[0];
            let mut fixed = src.clone();
            fixed.replace_range(
                edit.span.start.0 as usize..edit.span.end.0 as usize,
                &edit.replacement,
            );
            assert!(user(&fixed).diagnostics.is_empty(), "{fixed}");
        }
    }
    #[test]
    fn all_standard_library_sources_parse_as_prelude() {
        let document = include_str!(
            "../../../../../docs/implement/10-interfaces/10-14-prelude-and-stdlib-sources.md"
        );
        let mut count = 0;
        for block in document.split("```text file=src/prelude/stdlib/").skip(1) {
            let (path, block) = block.split_once('\n').unwrap();
            let source = block.split_once("```").unwrap().0;
            let (out, lex) = parse_source(source, SourceKind::Prelude);
            assert!(lex.is_empty(), "{path}: {lex:?}");
            assert!(out.diagnostics.is_empty(), "{path}: {:?}", out.diagnostics);
            count += 1;
        }
        assert_eq!(count, 27);
    }

    #[test]
    fn golden_programs_and_resource_specification_example_parse() {
        for src in [
            include_str!("../../../testdata/traits/f04_standard_trait.bnt"),
            include_str!("../../../testdata/traits/f04_supertraits.bnt"),
            include_str!("../../../testdata/handlers/f04_log.bnt"),
            include_str!("../../../testdata/syntax/f04_interpolation.bnt"),
            include_str!("../../../testdata/syntax/f04_lazy.bnt"),
            include_str!("../../../testdata/syntax/f04_try.bnt"),
            include_str!("../../../testdata/syntax/f04_list_spread.bnt"),
            include_str!("../../../testdata/patterns/f04_commands.bnt"),
            include_str!("../../../testdata/patterns/f04_scores.bnt"),
            include_str!("../../../testdata/effects/f04_resources.bnt"),
        ] {
            let out = user(src);
            assert!(out.diagnostics.is_empty(), "{src}: {:?}", out.diagnostics);
            assert!(
                matches!(&out.module.decls.last().unwrap().item, Item::Fn(f) if f.name.text == "main")
            );
        }
        // 仕様書の copyHeader は書き込みの関数を含む。構文の検査では版の範囲によらず
        // 原文を読み、実行用のゴールデンテストは U1・U2 の関数だけを使う（実装プラン 10-14）。
        let spec = include_str!("../../../../../docs/design/01-spec/01-10-resources.md");
        let src = spec
            .split_once("```text\n")
            .unwrap()
            .1
            .split_once("```")
            .unwrap()
            .0;
        let out = user(src);
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        let Item::Fn(f) = &out.module.decls[0].item else {
            panic!()
        };
        let Stmt::Expr(Expr::With(w)) = &f.body.as_ref().unwrap().stmts[0] else {
            panic!()
        };
        assert_eq!(w.binds.len(), 2);
        assert!(w.binds.iter().all(
            |b| matches!(&b.value, Expr::Try(t) if matches!(t.value.as_ref(), Expr::Pipe(_)))
        ));
    }
}
