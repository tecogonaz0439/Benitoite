//! プログラムと基本の宣言（設計書 01-02「プログラムと宣言」、02-03「構文解析の方式」）。
use super::{
    CommaList, PResult, Parser, Recovery, child, comma_list, effects, exprs, foreign,
    is_decl_start, items, text, traits, types,
};
use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::syntax::{ast::*, token::TokenKind};

pub(super) fn parse_module(p: &mut Parser) -> Module {
    let start = p.pos;
    let mut imports = Vec::new();
    let mut decls = Vec::new();
    let mut first_decl = None;
    let doc = p.docs.module_doc(&mut p.diagnostics);
    p.skip_newlines();
    while !p.at(TokenKind::Eof) && !p.aborted {
        let from = p.pos;
        let saved = p.ctx;
        let open = p.blocks.len();
        if p.at(TokenKind::KwImport) {
            if let Ok(import) = items::parse_import(p, first_decl, 1) {
                imports.push(import);
            }
        } else {
            first_decl.get_or_insert(p.peek().span);
            let doc = p.docs.take_for(p.peek().span, &mut p.diagnostics);
            let attrs = items::parse_attributes(p);
            let public = items::parse_public(p);
            let result = parse_item(p, &attrs, 1);
            let item = match result {
                Ok(item) => item,
                Err(_) => {
                    p.recover(from, Recovery::TopLevel);
                    p.blocks.truncate(open);
                    Item::Error(p.error_node_from(from))
                }
            };
            let decl = TopDecl {
                span: p.span_from(from),
                doc,
                attrs,
                public,
                item,
            };
            items::check_decl_header(p, &decl);
            decls.push(decl);
        }
        p.ctx = saved;
        if p.aborted {
            break;
        }
        if p.pos == from {
            p.advance();
        }
        if !p.at(TokenKind::Newline)
            && !p.symbol(";")
            && !p.at(TokenKind::Eof)
            && !p.at_line_start()
        {
            p.unexpected(text::NEWLINE_OR_END);
            p.recover(p.pos, Recovery::TopLevel);
        }
        p.skip_newlines();
    }
    Module {
        id: p.node_id(),
        span: p.span_from(start),
        file: p.file,
        doc,
        imports,
        decls,
    }
}
fn parse_item(p: &mut Parser, attrs: &[Attribute], depth: u32) -> PResult<Item> {
    match p.peek_kind() {
        TokenKind::KwFunction => Ok(Item::Fn(Box::new(parse_function(
            p,
            depth,
            items::body_rule(attrs, p.kind),
            attrs,
        )?))),
        TokenKind::KwData => parse_data(p, depth, false),
        TokenKind::KwType if !alias_ahead(p) => parse_data(p, depth, true),
        TokenKind::KwType => items::parse_alias_decl(p, depth),
        TokenKind::KwRecord => items::parse_record_decl(p, depth),
        TokenKind::KwConst => items::parse_const_decl(p, depth),
        TokenKind::KwTrait => traits::parse_trait_decl(p, depth),
        TokenKind::KwImplement => traits::parse_impl_decl(p, depth),
        TokenKind::KwEffect => effects::parse_effect_decl(p, depth),
        TokenKind::LowerIdent
        | TokenKind::UpperIdent
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
        | TokenKind::KwDiv
        | TokenKind::KwDo
        | TokenKind::KwElse
        | TokenKind::KwEnd
        | TokenKind::KwFalse
        | TokenKind::KwHandle
        | TokenKind::KwIf
        | TokenKind::KwImport
        | TokenKind::KwLambda
        | TokenKind::KwLazy
        | TokenKind::KwMatch
        | TokenKind::KwMod
        | TokenKind::KwNot
        | TokenKind::KwOr
        | TokenKind::KwPublic
        | TokenKind::KwResume
        | TokenKind::KwReturn
        | TokenKind::KwShadow
        | TokenKind::KwThen
        | TokenKind::KwTrue
        | TokenKind::KwTry
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
        | TokenKind::LParen
        | TokenKind::RParen
        | TokenKind::LBracket
        | TokenKind::RBracket
        | TokenKind::Underscore
        | TokenKind::LineBreak
        | TokenKind::Newline
        | TokenKind::Error
        | TokenKind::BadSymbol
        | TokenKind::Eof => {
            if let Some(result) = items::try_foreign_decl_start(p, depth) {
                return result;
            }
            if p.word("fn") {
                let start = p.pos;
                let key = if p.peek_nth_kind(1) == TokenKind::LParen {
                    "lambda"
                } else {
                    "function"
                };
                foreign::fn_form(p, key);
                return Ok(Item::Error(p.error_node_from(start)));
            }
            Err(p.unexpected(text::DECLARATION))
        }
    }
}
fn alias_ahead(p: &Parser) -> bool {
    if p.tokens.get(p.pos.saturating_add(1)).is_some_and(
        |t| matches!(&t.value, crate::syntax::token::TokenValue::Ident(s) if s == "alias"),
    ) {
        return true;
    }
    let mut index = p.pos.saturating_add(2);
    if p.tokens
        .get(index)
        .is_some_and(|t| t.kind == TokenKind::LBracket)
    {
        let mut nested = 0_u32;
        while let Some(token) = p.tokens.get(index) {
            if token.kind == TokenKind::LBracket {
                nested = nested.saturating_add(1);
            }
            if token.kind == TokenKind::RBracket {
                nested = nested.saturating_sub(1);
            }
            index = index.saturating_add(1);
            if nested == 0 {
                break;
            }
        }
    }
    p.tokens.get(index).is_some_and(|t| t.kind == TokenKind::Eq)
}

/// メソッドと操作もこのシグネチャの読み方を共有する。F04 は必要な欄を各ノードへ移す。
pub(super) struct Signature {
    pub(super) name: Name,
    pub(super) type_params: Vec<TypeParamDecl>,
    pub(super) params: Vec<Param>,
    pub(super) ret: TypeExpr,
    pub(super) uses: Option<UsesList>,
}
pub(super) fn parse_signature(p: &mut Parser, depth: u32) -> PResult<Signature> {
    p.expect(TokenKind::KwFunction)?;
    let from = p.pos;
    let path = p.qual_name(false)?;
    let name = path.last().cloned().ok_or(super::Fail)?;
    if path.len() == 1
        && p.tokens
            .get(from)
            .is_some_and(|t| t.kind == TokenKind::UpperIdent)
    {
        p.report(
            DiagBuilder::new(DiagCode::E0201)
                .arg("expected", text::LOWER_NAME)
                .arg("found", text::UPPER_NAME)
                .primary(name.span)
                .build(),
        );
    }
    if path.len() > 1 {
        let start = path.first().map_or(name.span, |n| n.span);
        let prefix = Span {
            end: name.span.start,
            ..start
        };
        let module = p.snippet(prefix).trim_end_matches('.').to_owned();
        p.report(
            DiagBuilder::new(DiagCode::E0207)
                .arg("module", module)
                .primary(p.span_from(from))
                .help_edits(
                    "remove",
                    vec![Edit {
                        span: prefix,
                        replacement: String::new(),
                    }],
                )
                .build(),
        );
    }
    let type_params = types::parse_type_params(p, depth, true)?;
    let params = parse_params(p, depth, false)?;
    foreign::return_arrow(p)?;
    let ret = types::parse_type(p, child(depth))?;
    let uses = types::parse_uses(p, depth)?;
    Ok(Signature {
        name,
        type_params,
        params,
        ret: *ret,
        uses,
    })
}
pub(super) fn parse_function(
    p: &mut Parser,
    depth: u32,
    rule: items::BodyRule,
    attrs: &[Attribute],
) -> PResult<FnDecl> {
    p.enter(depth)?;
    let start = p.pos;
    let opened = p.peek().span;
    let signature = parse_signature(p, depth)?;
    let body = if rule == items::BodyRule::Omitted {
        if !p.at(TokenKind::Newline) && !p.at(TokenKind::Eof) {
            p.unexpected(text::token_name(TokenKind::Newline));
        }
        None
    } else {
        p.skip_newlines();
        if is_decl_start(p.peek_kind()) || p.at(TokenKind::Eof) {
            items::report_missing_body(p, &signature.name, attrs);
            None
        } else {
            p.open_block(TokenKind::KwFunction, opened);
            if p.symbol("{") {
                p.bump();
            }
            let block = exprs::parse_block(p, child(depth), exprs::BlockEnd::End)?;
            p.close_block(TokenKind::KwFunction);
            Some(*block)
        }
    };
    Ok(FnDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name: signature.name,
        type_params: signature.type_params,
        params: signature.params,
        ret: signature.ret,
        uses: signature.uses,
        body,
    })
}

pub(super) fn parse_params(p: &mut Parser, depth: u32, lambda: bool) -> PResult<Vec<Param>> {
    p.expect(TokenKind::LParen)?;
    comma_list(
        p,
        depth,
        CommaList {
            close: TokenKind::RParen,
            element: text::PARAMETER,
            separator: text::COMMA_OR_RPAREN,
            allow_empty: true,
            indexed: false,
        },
        |p, depth, out| push_param(p, depth, lambda, out),
        |_, _| {},
    )
}
fn push_param(p: &mut Parser, depth: u32, lambda: bool, out: &mut Vec<Param>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let name = if lambda && p.at(TokenKind::Underscore) {
        let span = p.bump().span;
        p.report(
            DiagBuilder::new(DiagCode::E0210)
                .primary(span)
                .help_edits(
                    "name",
                    vec![Edit {
                        span,
                        replacement: "_unused".to_owned(),
                    }],
                )
                .build(),
        );
        Name {
            text: "_unused".to_owned(),
            span,
        }
    } else {
        p.expect_name(TokenKind::LowerIdent, text::LOWER_NAME)?
    };
    let ty = if !lambda || p.at(TokenKind::Colon) {
        p.expect(TokenKind::Colon)?;
        Some(*types::parse_type(p, child(depth))?)
    } else {
        None
    };
    out.push(Param {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        ty,
    });
    Ok(())
}
fn parse_data(p: &mut Parser, depth: u32, foreign_type: bool) -> PResult<Item> {
    p.enter(depth)?;
    let start = p.pos;
    let keyword = p.bump().span;
    let name = p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?;
    let type_params = types::parse_type_params(p, depth, false)?;
    let kind = if foreign_type {
        TokenKind::KwType
    } else {
        TokenKind::KwData
    };
    p.open_block(kind, keyword);
    let mut variants = Vec::new();
    p.skip_newlines();
    while !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) && !p.aborted && !p.symbol("}") {
        let from = p.pos;
        if push_variant(p, child(depth), &mut variants).is_err() {
            p.recover(from, Recovery::Line);
        }
        if p.pos == from {
            p.advance();
        }
        if !p.at(TokenKind::Newline) && !p.at(TokenKind::KwEnd) && !p.at(TokenKind::Eof) {
            p.unexpected(text::NEWLINE_OR_END);
            p.recover(p.pos, Recovery::Line);
        }
        p.skip_newlines();
    }
    // 構成子のない宣言は文法では読める（01-02 の LineList）。誤りは型検査が E0411 で報告する（01-05）。
    let close_start = p.pos;
    p.close_block(kind);
    if foreign_type && !p.aborted {
        let mut edits = vec![Edit {
            span: keyword,
            replacement: "data".to_owned(),
        }];
        if let Some(token) = p.tokens.get(close_start.saturating_add(1))
            && token.kind == TokenKind::KwType
        {
            edits.push(Edit {
                span: token.span,
                replacement: "data".to_owned(),
            });
        }
        p.suppressed = false;
        p.report(
            DiagBuilder::new(DiagCode::E0233)
                .arg("name", &name.text)
                .primary(keyword)
                .help_edits("data", edits)
                .build(),
        );
    }
    Ok(Item::Data(DataDecl {
        id: p.node_id(),
        span: p.span_from(start),
        name,
        type_params,
        variants,
    }))
}
fn push_variant(p: &mut Parser, depth: u32, out: &mut Vec<Variant>) -> PResult<()> {
    p.enter(depth)?;
    let start = p.pos;
    let doc = p.docs.take_for(p.peek().span, &mut p.diagnostics);
    let name = p.expect_name(TokenKind::UpperIdent, text::UPPER_NAME)?;
    let fields = if p.eat(TokenKind::LParen) {
        let opening = p.span_from(p.pos.saturating_sub(1));
        if p.at(TokenKind::RParen) {
            let closing = p.bump().span;
            p.report(
                DiagBuilder::new(DiagCode::E0206)
                    .arg("name", &name.text)
                    .primary(opening.to(closing))
                    .help_edits(
                        "remove",
                        vec![Edit {
                            span: opening.to(closing),
                            replacement: String::new(),
                        }],
                    )
                    .build(),
            );
            Vec::new()
        } else {
            comma_list(
                p,
                depth,
                CommaList {
                    close: TokenKind::RParen,
                    element: text::TYPE,
                    separator: text::COMMA_OR_RPAREN,
                    allow_empty: true,
                    indexed: false,
                },
                |p, depth, out| {
                    out.push(*types::parse_type(p, depth)?);
                    Ok(())
                },
                |out, e| out.push(TypeExpr::Error(e)),
            )?
        }
    } else {
        Vec::new()
    };
    out.push(Variant {
        id: p.node_id(),
        span: p.span_from(start),
        doc,
        name,
        fields,
    });
    Ok(())
}
