//! 型と型パラメータの解析（設計書 02-03「型の解析」、01-02「初回リリース版の文法の全体」）。
use super::{CommaList, Fail, PResult, Parser, child, comma_list, patterns_ext, text, traits};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::{ast::*, token::TokenKind};

pub(super) fn parse_type(p: &mut Parser, depth: u32) -> PResult<Box<TypeExpr>> {
    parse_type_in(p, depth, false)
}
// 型の並びの要素だけに、括弧で囲めば並びを分けられるという情報を渡す。
fn parse_type_in(p: &mut Parser, depth: u32, in_list: bool) -> PResult<Box<TypeExpr>> {
    p.enter(depth)?;
    if p.at(TokenKind::Error) {
        return Ok(Box::new(TypeExpr::Error(p.error_token_node())));
    }
    match p.peek_kind() {
        TokenKind::LParen => parse_paren(p, depth),
        TokenKind::KwFunction => parse_fn(p, depth, in_list),
        TokenKind::UpperIdent | TokenKind::KwDie => parse_named(p, depth),
        TokenKind::LowerIdent
        | TokenKind::IntLit
        | TokenKind::FloatLit
        | TokenKind::DecimalLit
        | TokenKind::StringLit
        | TokenKind::StrStart
        | TokenKind::StrMid
        | TokenKind::StrEnd
        | TokenKind::CharLit
        | TokenKind::KwAnd
        | TokenKind::KwBind
        | TokenKind::KwCase
        | TokenKind::KwConst
        | TokenKind::KwData
        | TokenKind::KwDiv
        | TokenKind::KwDo
        | TokenKind::KwEffect
        | TokenKind::KwElse
        | TokenKind::KwEnd
        | TokenKind::KwFalse
        | TokenKind::KwHandle
        | TokenKind::KwIf
        | TokenKind::KwImplement
        | TokenKind::KwImport
        | TokenKind::KwLambda
        | TokenKind::KwBlock
        | TokenKind::KwLazy
        | TokenKind::KwMatch
        | TokenKind::KwMod
        | TokenKind::KwNot
        | TokenKind::KwOr
        | TokenKind::KwPublic
        | TokenKind::KwRecord
        | TokenKind::KwResume
        | TokenKind::KwReturn
        | TokenKind::KwShadow
        | TokenKind::KwThen
        | TokenKind::KwTrait
        | TokenKind::KwTrue
        | TokenKind::KwTry
        | TokenKind::KwType
        | TokenKind::KwUses
        | TokenKind::KwWith
        | TokenKind::Plus
        | TokenKind::Minus
        | TokenKind::Star
        | TokenKind::Slash
        | TokenKind::Eq
        | TokenKind::NotEq
        | TokenKind::Lt
        | TokenKind::Le
        | TokenKind::Gt
        | TokenKind::Ge
        | TokenKind::PipeGt
        | TokenKind::Arrow
        | TokenKind::LeftArrow
        | TokenKind::Colon
        | TokenKind::Comma
        | TokenKind::Dot
        | TokenKind::DotDot
        | TokenKind::Amp
        | TokenKind::At
        | TokenKind::RParen
        | TokenKind::LBracket
        | TokenKind::RBracket
        | TokenKind::Underscore
        | TokenKind::LineBreak
        | TokenKind::Newline
        | TokenKind::Error
        | TokenKind::BadSymbol
        | TokenKind::Eof => Err(p.unexpected(text::TYPE)),
    }
}
fn parse_named(p: &mut Parser, depth: u32) -> PResult<Box<TypeExpr>> {
    let start = p.pos;
    let path = p.qual_name(true)?;
    if p.at(TokenKind::LBracket)
        && matches!(
            p.peek_nth_kind(1),
            TokenKind::StringLit | TokenKind::StrStart | TokenKind::IntLit
        )
    {
        return parse_scope_named(p, start, path);
    }
    let args = if p.eat(TokenKind::LBracket) {
        comma_list(
            p,
            depth,
            CommaList {
                close: TokenKind::RBracket,
                element: text::TYPE,
                separator: text::COMMA_OR_RBRACKET,
                allow_empty: false,
                indexed: false,
            },
            push_type,
            |out, error| out.push(TypeExpr::Error(error)),
        )?
    } else {
        Vec::new()
    };
    Ok(finish_named(p, start, path, args, None))
}
// 範囲の分岐を再帰する型引数の枠から外す。
#[inline(never)]
fn parse_scope_named(p: &mut Parser, start: usize, path: Vec<Name>) -> PResult<Box<TypeExpr>> {
    let from = p.pos;
    p.bump();
    let scope = super::scope::parse(p, from)?;
    Ok(finish_named(
        p,
        start,
        path,
        Vec::new(),
        Some(Box::new(scope)),
    ))
}
fn type_start(kind: TokenKind) -> bool {
    matches!(
        kind,
        TokenKind::UpperIdent | TokenKind::KwDie | TokenKind::KwFunction | TokenKind::LParen
    )
}
// 再帰中の枠に AST の構築領域を置かない（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
fn finish_named(
    p: &mut Parser,
    start: usize,
    path: Vec<Name>,
    args: Vec<TypeExpr>,
    scope: Option<Box<ScopeArgs>>,
) -> Box<TypeExpr> {
    Box::new(TypeExpr::Named(NamedType {
        id: p.node_id(),
        span: p.span_from(start),
        path,
        args,
        scope,
    }))
}
// 型を始める字句と範囲の字句を分ける。名前の種類は解決後に検査する。
type ParsedArguments = (Option<Vec<TypeExpr>>, Option<Box<ScopeArgs>>);

fn parse_arguments(p: &mut Parser, depth: u32) -> PResult<ParsedArguments> {
    if !p.at(TokenKind::LBracket) {
        return Ok((None, None));
    }
    let start = p.pos;
    p.bump();
    if type_start(p.peek_kind()) {
        let args = comma_list(
            p,
            depth,
            CommaList {
                close: TokenKind::RBracket,
                element: text::TYPE,
                separator: text::COMMA_OR_RBRACKET,
                allow_empty: true,
                indexed: false,
            },
            push_type,
            |out, error| out.push(TypeExpr::Error(error)),
        )?;
        Ok((Some(args), None))
    } else {
        Ok((None, Some(Box::new(super::scope::parse(p, start)?))))
    }
}

// 字句上の文字列列か endpoint の組の列だけを展開する。不正な群は一つで残す。
fn expand_effect(p: &mut Parser, effect: EffectRef, out: &mut Vec<EffectRef>) {
    let Some(scope) = &effect.scope else {
        out.push(effect);
        return;
    };
    let path = scope
        .items
        .iter()
        .all(|a| matches!(a.kind, ScopeArgKind::String(_)));
    let endpoints = scope.items.len().is_multiple_of(2)
        && scope.items.as_chunks::<2>().0.iter().all(|pair| {
            matches!(
                pair,
                [
                    ScopeArg {
                        kind: ScopeArgKind::String(_),
                        ..
                    },
                    ScopeArg {
                        kind: ScopeArgKind::Port(..),
                        ..
                    }
                ]
            )
        });
    let width = if path {
        1
    } else if endpoints {
        2
    } else {
        out.push(effect);
        return;
    };
    if scope.items.is_empty() {
        out.push(effect);
        return;
    }
    for start in (0..scope.items.len()).step_by(width) {
        let mut atom = effect.clone();
        atom.id = p.node_id();
        if let Some(scope) = &mut atom.scope {
            scope.element = start..start.saturating_add(width);
        }
        out.push(atom);
    }
}

fn push_type(p: &mut Parser, depth: u32, out: &mut Vec<TypeExpr>) -> PResult<()> {
    let Ok(ty) = parse_type_in(p, depth, true) else {
        return Err(Fail);
    };
    out.push(*ty);
    Ok(())
}
// 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
fn parse_paren(p: &mut Parser, depth: u32) -> PResult<Box<TypeExpr>> {
    let start = p.pos;
    p.bump();
    let Ok(inner) = parse_type_in(p, child(depth), false) else {
        return Err(Fail);
    };
    let mut count = 1_usize;
    let tuple = p.peek().span;
    let has_comma = p.at(TokenKind::Comma);
    while p.eat(TokenKind::Comma) {
        if p.at(TokenKind::RParen) {
            break;
        }
        drop(parse_type_in(p, child(depth), false)?);
        count = count.saturating_add(1);
    }
    if has_comma {
        patterns_ext::report_tuple(p, count, tuple);
    }
    p.expect(TokenKind::RParen)?;
    Ok(finish_paren(p, start, inner))
}
// 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
fn finish_paren(p: &mut Parser, start: usize, inner: Box<TypeExpr>) -> Box<TypeExpr> {
    Box::new(TypeExpr::Paren(ParenType {
        id: p.node_id(),
        span: p.span_from(start),
        inner,
    }))
}
fn parse_fn(p: &mut Parser, depth: u32, in_list: bool) -> PResult<Box<TypeExpr>> {
    let start = p.pos;
    p.bump();
    p.expect(TokenKind::LParen)?;
    let entries = comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RParen,
            element: text::TYPE,
            separator: text::COMMA_OR_RPAREN,
            allow_empty: true,
            indexed: false,
        },
        push_fn_param,
        |out, error| {
            out.push((None, TypeExpr::Error(error)));
        },
    )?;
    p.expect(TokenKind::Arrow)?;
    let Ok(ret) = parse_type_in(p, child(depth), false) else {
        return Err(Fail);
    };
    let uses = parse_uses(p, depth, in_list.then_some(start))?;
    Ok(finish_fn(p, start, entries, ret, uses))
}
fn push_fn_param(
    p: &mut Parser,
    depth: u32,
    out: &mut Vec<(Option<Name>, TypeExpr)>,
) -> PResult<()> {
    let name = if matches!(
        p.peek_kind(),
        TokenKind::LowerIdent | TokenKind::KwDie | TokenKind::KwRecord
    ) {
        let name = p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?;
        p.expect(TokenKind::Colon)?;
        Some(name)
    } else {
        // 同じ関数型では最初の無名パラメータだけを報告する。入れ子の型は別の並びを持つ。
        if !out.iter().any(|(name, _)| name.is_none()) {
            p.diagnostics.push(
                DiagBuilder::new(DiagCode::E0257)
                    .primary(p.peek().span)
                    .help("named")
                    .build(),
            );
        }
        None
    };
    let ty = parse_type_in(p, depth, true)?;
    out.push((name, *ty));
    Ok(())
}

// 再帰の入口の枠を小さく保ち、展開で分岐が戻るのを防ぐ（設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[inline(never)]
fn finish_fn(
    p: &mut Parser,
    start: usize,
    entries: Vec<(Option<Name>, TypeExpr)>,
    ret: Box<TypeExpr>,
    uses: Option<UsesList>,
) -> Box<TypeExpr> {
    let mut params = Vec::with_capacity(entries.len());
    let mut param_names = Vec::with_capacity(entries.len());
    for (name, ty) in entries {
        let Some(name) = name else {
            return Box::new(TypeExpr::Error(p.error_node_from(start)));
        };
        param_names.push(name);
        params.push(ty);
    }
    Box::new(TypeExpr::Fn(FnType {
        id: p.node_id(),
        span: p.span_from(start),
        params,
        param_names,
        ret,
        uses,
    }))
}

pub(super) fn parse_uses(
    p: &mut Parser,
    depth: u32,
    fn_start: Option<usize>,
) -> PResult<Option<UsesList>> {
    if !p.at(TokenKind::KwUses) {
        return Ok(None);
    }
    let start = p.pos;
    p.bump();
    let mut effects = Vec::new();
    loop {
        p.enter(child(depth))?;
        let from = p.pos;
        let path = p.qual_name(true)?;
        let ambiguous = !effects.is_empty() && path.len() == 1;
        let (args, scope) = if ambiguous {
            (None, None)
        } else {
            parse_arguments(p, depth)?
        };
        let effect = EffectRef {
            id: p.node_id(),
            span: p.span_from(from),
            path,
            args,
            scope,
        };
        expand_effect(p, effect, &mut effects);
        if effects.len() > 1
            && effects.last().is_some_and(|e| e.path.len() == 1)
            && p.at(TokenKind::LBracket)
        {
            let end = matching_bracket(p);
            let span = end
                .and_then(|end| effects.last().map(|e| e.span.to(end)))
                .unwrap_or(p.peek().span);
            let mut d = DiagBuilder::new(DiagCode::E0209).primary(span);
            if end.is_some()
                && let Some(start) = fn_start.and_then(|i| p.tokens.get(i))
                && let Some(prev) = effects.len().checked_sub(2).and_then(|i| effects.get(i))
            {
                d = d.help_edits(
                    "paren",
                    vec![
                        Edit {
                            span: Span {
                                end: start.span.start,
                                ..start.span
                            },
                            replacement: "(".into(),
                        },
                        Edit {
                            span: Span {
                                start: prev.span.end,
                                ..prev.span
                            },
                            replacement: ")".into(),
                        },
                    ],
                );
            } else {
                d = d.help("paren");
            }
            p.report(d.build());
            p.bump();
            p.recover(p.pos, super::Recovery::Comma);
            while !p.at(TokenKind::RBracket) && !p.at(TokenKind::Eof) {
                p.advance();
            }
            if p.at(TokenKind::RBracket) {
                p.advance();
            }
        }
        if !p.at(TokenKind::Comma) || p.peek_nth_kind(1) != TokenKind::UpperIdent {
            break;
        }
        p.bump();
    }
    Ok(Some(UsesList {
        span: p.span_from(start),
        effects,
    }))
}

// ファイル位置には外側の型引数リストがないため、入れ子の uses の
// E0209 の回復を使わない（設計書 02-03「型の解析」）。
pub(super) fn parse_file_uses(p: &mut Parser) -> Option<UsesList> {
    let start = p.pos;
    p.bump();
    let mut effects = Vec::new();
    loop {
        if !p.at(TokenKind::UpperIdent) {
            if effects.is_empty() {
                p.report(
                    DiagBuilder::new(DiagCode::E0261)
                        .primary(p.span_from(start))
                        .note("empty")
                        .build(),
                );
            } else {
                p.unexpected(text::UPPER_NAME);
            }
            recover_file_uses(p);
            return None;
        }
        let from = p.pos;
        let parsed = (|| {
            p.enter(1)?;
            let path = p.qual_name(true)?;
            let (args, scope) = parse_arguments(p, 1)?;
            Ok::<_, Fail>(EffectRef {
                id: p.node_id(),
                span: p.span_from(from),
                path,
                args,
                scope,
            })
        })();
        match parsed {
            Ok(effect) => expand_effect(p, effect, &mut effects),
            Err(_) => {
                recover_file_uses(p);
                return None;
            }
        }
        if !p.eat(TokenKind::Comma) {
            break;
        }
        // コンマ直後の改行は字句段で継続済み。次の宣言・EOFなら末尾コンマである。
        if p.at(TokenKind::Eof) || p.after_physical_newline() && !p.at(TokenKind::UpperIdent) {
            break;
        }
    }
    Some(UsesList {
        span: p.span_from(start),
        effects,
    })
}

fn recover_file_uses(p: &mut Parser) {
    while !p.at(TokenKind::Eof) && !p.at(TokenKind::Newline) && !p.aborted {
        if p.after_physical_newline()
            && (super::is_decl_start(p.peek_kind()) || p.at(TokenKind::KwUses))
        {
            break;
        }
        p.advance();
    }
}

// 回復で字句を読み飛ばす前に、入れ子の型引数も含めた位置を求める。
// 閉じ括弧がなければ、誤りが消えると決められないので置き換えは付けない（設計書 02-03「型の解析」）。
fn matching_bracket(p: &Parser) -> Option<Span> {
    let mut depth = 0_usize;
    let mut parens = 0_usize;
    for token in p.tokens.iter().skip(p.pos) {
        if token.kind == TokenKind::LBracket {
            depth = depth.saturating_add(1);
        } else if token.kind == TokenKind::RBracket {
            depth = depth.checked_sub(1)?;
            if depth == 0 {
                return Some(token.span);
            }
        } else if token.kind == TokenKind::LParen {
            parens = parens.saturating_add(1);
        } else if token.kind == TokenKind::RParen {
            parens = parens.checked_sub(1)?;
        } else if matches!(
            token.kind,
            TokenKind::Newline | TokenKind::KwEnd | TokenKind::Eof
        ) {
            break;
        }
    }
    None
}

/// `full` は関数・実装・メソッド・操作の型パラメータかを示す。
pub(super) fn parse_type_params(
    p: &mut Parser,
    depth: u32,
    full: bool,
) -> PResult<Vec<TypeParamDecl>> {
    if !p.eat(TokenKind::LBracket) {
        return Ok(Vec::new());
    }
    comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RBracket,
            element: text::TYPE_PARAMETER,
            separator: text::COMMA_OR_RBRACKET,
            allow_empty: false,
            indexed: false,
        },
        |p, depth, out| push_type_param(p, depth, full, out),
        |_, _| {},
    )
}
fn push_type_param(
    p: &mut Parser,
    depth: u32,
    full: bool,
    out: &mut Vec<TypeParamDecl>,
) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let effect = full && p.eat(TokenKind::KwEffect);
    let name = p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?;
    let mut kind = if effect {
        TypeParamKind::Effect
    } else {
        TypeParamKind::Value
    };
    if full && !effect && p.eat(TokenKind::LBracket) {
        let mut arity = 0_u32;
        loop {
            p.expect(TokenKind::Underscore)?;
            arity = arity.saturating_add(1);
            if !p.eat(TokenKind::Comma) {
                break;
            }
        }
        p.expect(TokenKind::RBracket)?;
        kind = TypeParamKind::Ctor { arity };
    }
    let mut constraints = Vec::new();
    if !effect && p.eat(TokenKind::Colon) {
        loop {
            let from = p.pos;
            if !full {
                // 型の宣言の制約は読み捨て、後続の型パラメータと本体を保つ。
                if p.at(TokenKind::LowerIdent) {
                    p.bump();
                } else {
                    drop(p.qual_name(true)?);
                }
                let span = p.span_from(from);
                p.report(
                    DiagBuilder::new(DiagCode::E0425)
                        .arg("constraint", p.snippet(span))
                        .primary(span)
                        .build(),
                );
            } else if p.at(TokenKind::LowerIdent) {
                let constraint = p.expect_name(TokenKind::LowerIdent, text::CONSTRAINT)?;
                if let Some(kind) = traits::builtin_constraint(p, &constraint) {
                    constraints.push(ConstraintRef::Builtin {
                        span: constraint.span,
                        kind,
                    });
                }
            } else {
                let path = p.qual_name(true)?;
                constraints.push(ConstraintRef::Class(ClassRef {
                    id: p.node_id(),
                    span: p.span_from(from),
                    path,
                }));
            }
            if !p.eat(TokenKind::Amp) {
                break;
            }
        }
    }
    out.push(TypeParamDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        kind,
        constraints,
    });
    Ok(())
}

#[cfg(test)]
mod tests {
    // 診断の位置と回復後の AST という構文解析の契約を、公開の入口で確かめる。
    // 制約を読めず後続を失う退行は型検査のテストだけでは判別できない（設計書 07-03）。
    // テストの失敗と期待値の比較にだけ panic と添字を使う。
    #![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]
    use crate::base::SourceKind;
    use crate::diag::DiagCode;
    use crate::syntax::{ast::Item, parser::test_support::parse_source};

    #[test]
    fn uses_bracket_repairs_require_a_type_list_and_a_local_closing_bracket() {
        // 型の並びなら括弧が修正になる。宣言の型や閉じ忘れでは編集を付けない。
        for source in [
            "function f(cb: function() -> Unit uses A, List[Integer]) -> Unit\nend function",
            "function f() -> function() -> Unit uses A, List[Integer]\nend function",
            "record R\n cb: function() -> Unit uses A, List[Integer]\nend record",
            "function f() -> Unit\n bind cb: function() -> Unit uses A, List[Integer] <- g\nend function",
            "type F = function(function() -> Unit uses A, List[Integer) -> Unit\ntype G = List[Integer]]",
        ] {
            let (out, _) = parse_source(source, SourceKind::User);
            let diag = out
                .diagnostics
                .iter()
                .find(|d| d.code == Some(DiagCode::E0209))
                .unwrap();
            assert!(
                diag.helps.iter().all(|h| h.edits.is_empty()),
                "{source}: {diag:#?}"
            );
            let span = diag.primary.as_ref().unwrap().span;
            assert!(!source[span.start.0 as usize..span.end.0 as usize].contains('\n'));
        }
    }

    #[test]
    fn declaration_constraints_are_reported_and_left_out_of_the_ast() {
        for source in [
            "data Box[T: equality & Trait.Show, U: key]\n Box(T, U)\nend data\n",
            "record Box[T: equality & Trait.Show, U: key]\n x: T\n y: U\nend record\n",
            "type Box[T: equality & Trait.Show, U: key] = Pair[T, U]\n",
        ] {
            let source = format!("{source}function after() -> Unit\nend function\n");
            let (out, lex) = parse_source(&source, SourceKind::User);
            assert!(lex.is_empty());
            assert_eq!(out.diagnostics.len(), 3, "{:?}", out.diagnostics);
            for (diag, name) in out
                .diagnostics
                .iter()
                .zip(["equality", "Trait.Show", "key"])
            {
                assert_eq!(diag.code, Some(DiagCode::E0425));
                assert_eq!(
                    diag.message,
                    format!("the constraint `{name}` cannot be written here")
                );
                let span = diag.primary.as_ref().unwrap().span;
                assert_eq!(
                    source.get(span.start.0 as usize..span.end.0 as usize),
                    Some(name)
                );
            }
            let params = match &out.module.decls[0].item {
                Item::Data(d) => &d.type_params,
                Item::Record(d) => &d.type_params,
                Item::Alias(d) => &d.type_params,
                Item::Fn(_)
                | Item::Const(_)
                | Item::Trait(_)
                | Item::Effect(_)
                | Item::Impl(_)
                | Item::ExternalType(_)
                | Item::Error(_) => panic!("declaration lost during recovery"),
            };
            assert_eq!(
                params
                    .iter()
                    .map(|p| p.name.text.as_str())
                    .collect::<Vec<_>>(),
                ["T", "U"]
            );
            assert!(params.iter().all(|p| p.constraints.is_empty()));
            assert!(matches!(&out.module.decls[1].item, Item::Fn(f) if f.name.text == "after"));
        }
    }
}

#[cfg(test)]
mod named_type_tests {
    // テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
    #![allow(clippy::unwrap_used, clippy::panic, clippy::indexing_slicing)]
    use super::*;
    use crate::base::{FileId, IdGen, SourceKind};
    use crate::syntax::{lexer::lex, newline::resolve_newlines};

    fn prepared_type(source: &str) -> (Box<TypeExpr>, Vec<crate::diag::Diagnostic>) {
        let lexed = lex(FileId(0), source.as_bytes());
        assert!(lexed.diagnostics.is_empty());
        let mut p = Parser::new(
            FileId(0),
            SourceKind::User,
            source.as_bytes(),
            resolve_newlines(lexed.tokens),
            &[],
            IdGen::new(),
        );
        let ty = parse_type_in(&mut p, 0, false).unwrap();
        assert!(p.at(TokenKind::Eof), "{source}: {:?}", p.diagnostics);
        (ty, p.diagnostics)
    }

    fn check_names(ty: &TypeExpr, expected: &[&str], source: &str) {
        let TypeExpr::Fn(f) = ty else {
            panic!("function type")
        };
        assert_eq!(
            f.param_names
                .iter()
                .map(|n| &n.text)
                .collect::<std::collections::BTreeSet<_>>()
                .len(),
            f.params.len()
        );
        assert_eq!(f.param_names.len(), f.params.len());
        assert_eq!(
            f.param_names
                .iter()
                .map(|n| n.text.as_str())
                .collect::<Vec<_>>(),
            expected
        );
        for (name, ty) in f.param_names.iter().zip(&f.params) {
            assert_eq!(
                &source[name.span.start.0 as usize..name.span.end.0 as usize],
                name.text
            );
            assert!(name.span.end.0 <= ty.span().start.0);
        }
    }

    #[test]
    fn function_types_keep_names_and_nested_types() {
        for (source, expected) in [
            ("function() -> Unit", vec![]),
            (
                "function(arg1: Integer, arg2: String) -> Unit",
                vec!["arg1", "arg2"],
            ),
            ("function() -> Unit", vec![]),
            ("function(value: Integer) -> Unit", vec!["value"]),
            (
                "function(left: Integer, right: String) -> Unit",
                vec!["left", "right"],
            ),
            (
                "function(cb: List[(function(item: Integer) -> Integer uses E)]) -> function(result: String) -> Unit",
                vec!["cb"],
            ),
        ] {
            let (ty, diagnostics) = prepared_type(source);
            assert!(diagnostics.is_empty(), "{source}: {diagnostics:?}");
            check_names(&ty, &expected, source);
            if source.contains("cb:") {
                let TypeExpr::Fn(f) = ty.as_ref() else {
                    panic!("function")
                };
                let TypeExpr::Named(list) = &f.params[0] else {
                    panic!("list")
                };
                let TypeExpr::Paren(paren) = &list.args[0] else {
                    panic!("paren")
                };
                check_names(&paren.inner, &["item"], source);
                check_names(&f.ret, &["result"], source);
            }
        }
    }

    #[test]
    fn prepared_named_function_type_formats_from_each_label() {
        use crate::cli::tools::formatter::{print, roles};
        let source = "type F = function(\n cb : function(\n item : Integer\n ) -> Integer,\n value : String\n) -> Unit\n";
        let skeleton = source;
        let (mut out, lexical) =
            super::super::test_support::parse_source(skeleton, SourceKind::User);
        assert!(lexical.is_empty());
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        let lexed = lex(FileId(0), source.as_bytes());
        let mut p = Parser::new(
            FileId(0),
            SourceKind::User,
            source.as_bytes(),
            resolve_newlines(lexed.tokens.clone()),
            &[],
            IdGen::new(),
        );
        p.pos = p
            .tokens
            .iter()
            .position(|t| t.kind == TokenKind::KwFunction)
            .unwrap();
        let ty = parse_type_in(&mut p, 0, false).unwrap();
        assert!(p.diagnostics.is_empty(), "{:?}", p.diagnostics);
        let Item::Alias(a) = &mut out.module.decls[0].item else {
            panic!("alias")
        };
        a.ty = *ty;
        let roles = roles::build_roles(&out.module, &lexed.tokens, source.as_bytes());
        let bytes = print::print(&print::PrintInput {
            text: source.as_bytes(),
            tokens: &lexed.tokens,
            comments: &lexed.comments,
            roles: &roles,
        });
        assert_eq!(
            String::from_utf8(bytes).unwrap(),
            "type F = function(\n  cb: function(\n    item: Integer\n  ) -> Integer,\n  value: String\n) -> Unit\n"
        );
    }

    #[test]
    fn ordinary_input_accepts_named_function_types() {
        let (out, lexical) = super::super::test_support::parse_source(
            "type F = function(value: Integer) -> Unit",
            SourceKind::User,
        );
        assert!(lexical.is_empty());
        assert_eq!(super::super::test_support::codes(&out), []);
        let Item::Alias(alias) = &out.module.decls[0].item else {
            panic!("expected alias")
        };
        check_names(
            &alias.ty,
            &["value"],
            "type F = function(value: Integer) -> Unit",
        );
    }
}

#[cfg(test)]
mod final_type_tests {
    // テストの失敗は panic で表す（AGENTS.md「`#[allow]` を書いてよい箇所」）。
    #![allow(clippy::unwrap_used)]
    use super::*;
    use crate::base::SourceKind;
    use crate::syntax::parser::test_support::parse_source;

    #[test]
    fn unnamed_function_types_report_the_parameter_without_inventing_names() {
        for (ty, parameter) in [
            ("function(Integer) -> Unit", "Integer"),
            ("function(Integer, Integer) -> Unit", "Integer"),
            (
                "function(value: Integer, String, Integer) -> Unit",
                "String",
            ),
            ("function(value: Integer, String) -> Unit", "String"),
            (
                "function(callback: function(Integer) -> Unit) -> Unit",
                "Integer",
            ),
        ] {
            let source = format!("type Bad = {ty}\nfunction after() -> Unit\nend function");
            let (out, lexical) = parse_source(&source, SourceKind::User);
            assert!(lexical.is_empty());
            let diagnostics = &out.diagnostics;
            assert_eq!(
                diagnostics.iter().map(|d| d.code).collect::<Vec<_>>(),
                [Some(DiagCode::E0257)],
                "{source}: {diagnostics:?}"
            );
            let span = diagnostics.first().unwrap().primary.as_ref().unwrap().span;
            assert_eq!(
                source.get(span.start.0 as usize..span.end.0 as usize),
                Some(parameter)
            );
            assert_eq!(
                diagnostics.first().unwrap().helps.first().unwrap().message,
                "write `function(name: Type) -> Result`"
            );
            assert!(
                diagnostics
                    .first()
                    .unwrap()
                    .helps
                    .iter()
                    .all(|h| h.edits.is_empty())
            );
            assert!(
                out.module
                    .decls
                    .iter()
                    .any(|d| matches!(&d.item, Item::Fn(f) if f.name.text == "after"))
            );
        }
    }
}
