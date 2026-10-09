//! 型と型パラメータの解析（設計書 02-03「型の解析」、01-02「初回リリース版の文法の全体」）。
use super::{CommaList, Fail, PResult, Parser, child, comma_list, patterns_ext, text, traits};
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::{ast::*, token::TokenKind};

pub(super) fn parse_type(p: &mut Parser, depth: u32) -> PResult<Box<TypeExpr>> {
    p.enter(depth)?;
    if p.at(TokenKind::Error) {
        return Ok(Box::new(TypeExpr::Error(p.error_token_node())));
    }
    match p.peek_kind() {
        TokenKind::LParen => parse_paren(p, depth),
        TokenKind::KwFunction => parse_fn(p, depth),
        TokenKind::UpperIdent => parse_named(p, depth),
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
    Ok(Box::new(TypeExpr::Named(NamedType {
        id: p.node_id(),
        span: p.span_from(start),
        path,
        args,
    })))
}
fn push_type(p: &mut Parser, depth: u32, out: &mut Vec<TypeExpr>) -> PResult<()> {
    let Ok(ty) = parse_type(p, depth) else {
        return Err(Fail);
    };
    out.push(*ty);
    Ok(())
}
fn parse_paren(p: &mut Parser, depth: u32) -> PResult<Box<TypeExpr>> {
    let start = p.pos;
    p.bump();
    let Ok(inner) = parse_type(p, child(depth)) else {
        return Err(Fail);
    };
    let mut count = 1_usize;
    let tuple = p.peek().span;
    let has_comma = p.at(TokenKind::Comma);
    while p.eat(TokenKind::Comma) {
        if p.at(TokenKind::RParen) {
            break;
        }
        drop(parse_type(p, child(depth))?);
        count = count.saturating_add(1);
    }
    if has_comma {
        patterns_ext::report_tuple(p, count, tuple);
    }
    p.expect(TokenKind::RParen)?;
    Ok(finish_paren(p, start, inner))
}
fn finish_paren(p: &mut Parser, start: usize, inner: Box<TypeExpr>) -> Box<TypeExpr> {
    Box::new(TypeExpr::Paren(ParenType {
        id: p.node_id(),
        span: p.span_from(start),
        inner,
    }))
}
fn parse_fn(p: &mut Parser, depth: u32) -> PResult<Box<TypeExpr>> {
    let start = p.pos;
    p.bump();
    p.expect(TokenKind::LParen)?;
    let params = comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RParen,
            element: text::TYPE,
            separator: text::COMMA_OR_RPAREN,
            allow_empty: true,
            indexed: false,
        },
        push_type,
        |out, error| out.push(TypeExpr::Error(error)),
    )?;
    p.expect(TokenKind::Arrow)?;
    let Ok(ret) = parse_type(p, child(depth)) else {
        return Err(Fail);
    };
    let uses = parse_uses(p, depth)?;
    Ok(finish_fn(p, start, params, ret, uses))
}
fn finish_fn(
    p: &mut Parser,
    start: usize,
    params: Vec<TypeExpr>,
    ret: Box<TypeExpr>,
    uses: Option<UsesList>,
) -> Box<TypeExpr> {
    Box::new(TypeExpr::Fn(FnType {
        id: p.node_id(),
        span: p.span_from(start),
        params,
        ret,
        uses,
    }))
}

pub(super) fn parse_uses(p: &mut Parser, depth: u32) -> PResult<Option<UsesList>> {
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
        effects.push(EffectRef {
            id: p.node_id(),
            span: p.span_from(from),
            path,
        });
        if effects.len() > 1 && p.at(TokenKind::LBracket) {
            p.report(
                DiagBuilder::new(DiagCode::E0209)
                    .primary(p.peek().span)
                    .help("paren")
                    .build(),
            );
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
                // 型の宣言の制約は読み捨て、後続の型パラメータと本体を保つ
                // （実装プラン F08「`data` の型パラメータの制約」）。
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
