//! 構文解析の基盤（設計書 02-03「構文解析の方式」「誤りからの回復」「入れ子の深さ」）。
//!
//! 再帰の経路では式・型・パターンを箱で受け渡し、ノードの組み立てを別の関数に分ける。
//! 並びの要素は、要素を読む関数が直接並びに加え、再帰の枠に大きな値を残さない。
//!
//! F03・F04 のフックは子のモジュールに置く。引数の `p` は解析器、`depth` はノードの深さ。
//! `PResult<T>` は成功した値か回復を要求する `Fail`、`PatternCounter` はパターンの通し番号である。
//! 次の表のシグネチャは F03・F04 と共有し、各作業は担当する子のモジュールだけを実装する。
//!
//! | フック（`p: &mut Parser` は略記） | 引数 → 戻り値 | 仮の本体 | 担当 |
//! |---|---|---|---|
//! | `items::DocStore::new` | `text: &[u8], comments: &[Comment] → DocStore` | 参照を保存 | F03 |
//! | `DocStore::take_for` | `&mut self, start: Span, diagnostics: &mut Vec<Diagnostic> → Option<DocComment>` | `None`、報告なし | F03 |
//! | `DocStore::module_doc` | `&mut self, diagnostics: &mut Vec<Diagnostic> → Option<DocComment>` | `None`、報告なし | F03 |
//! | `DocStore::finish` | `&mut self, diagnostics: &mut Vec<Diagnostic> → ()` | 何もしない | F03 |
//! | `items::parse_import` | `p, first_decl: Option<Span>, depth: u32 → PResult<ImportDecl>` | E0201、次の宣言まで回復 | F03 |
//! | `items::parse_attributes` | `p → Vec<Attribute>` | E0201、属性を飛ばし空の並び | F03 |
//! | `items::parse_public` | `p → Option<Span>` | `public` を読み span を返す | F03 |
//! | `items::body_rule` | `attrs: &[Attribute], kind: SourceKind → BodyRule` | `Required` | F03 |
//! | `items::check_decl_header` | `p, decl: &TopDecl → ()` | 何もしない | F03 |
//! | `items::report_missing_body` | `p, name: &Name, attrs: &[Attribute] → ()` | E0201 | F03 |
//! | `items::reject_public` | `p, span: Span → ()` | 何もしない | F03 |
//! | `items::try_foreign_decl_start` | `p, depth: u32 → Option<PResult<Item>>` | `None` | F03 |
//! | `items::parse_record_decl` | `p, depth: u32 → PResult<Item>` | E0201、`end record` か次の宣言まで回復、誤りのノード | F03 |
//! | `items::parse_alias_decl`, `parse_const_decl` | `p, depth: u32 → PResult<Item>` | E0201、次の宣言まで回復、誤りのノード | F03 |
//! | `records::parse_record_expr` | `p, path: Vec<Name>, start: Span, depth: u32 → PResult<Box<Expr>>` | E0201、`)` まで回復、誤りのノード | F03 |
//! | `records::parse_record_pattern` | `p, path: Vec<Name>, start: Span, counter: &mut PatternCounter → PResult<Box<Pattern>>` | 同上 | F03 |
//! | `traits::parse_trait_decl`, `parse_impl_decl` | `p, depth: u32 → PResult<Item>` | E0201、対応する `end` か次の宣言まで回復、誤りのノード | F04 |
//! | `traits::builtin_constraint` | `p, name: &Name → Option<BuiltinConstraint>` | `equality`, `key`, `ordered` は `Some`、ほかは E0201 と `None`（その制約だけを捨てる） | F04 |
//! | `effects::parse_effect_decl` | `p, depth: u32 → PResult<Item>` | E0201、`end effect` か次の宣言まで回復、誤りのノード | F04 |
//! | `effects::parse_handle`, `parse_with`, `parse_lazy` | `p, depth: u32 → PResult<Box<Expr>>` | E0201、対応する `end` まで回復、誤りのノード | F04 |
//! | `effects::parse_resume` | `p, depth: u32 → PResult<Box<Expr>>` | E0201、`)` まで回復、誤りのノード | F04 |
//! | `effects::parse_try` | `p, depth: u32 → PResult<Box<Expr>>` | E0201、後の式を読んで捨て、誤りのノード | F04 |
//! | `effects::check_escape` | `p, keyword: TokenKind, span: Span → ()` | 何もしない | F04 |
//! | `interp::parse_interp` | `p, depth: u32 → PResult<Box<Expr>>` | E0201、対応する `StrEnd` まで回復、誤りのノード | F04 |
//! | `spread::parse_spread_elem` | `p, depth: u32, out: &mut Vec<ListElem> → PResult<()>` | E0201、要素の終わりまで回復、誤りのノードを追加 | F04 |
//! | `spread::check_list_spreads` | `p, list: &ListExpr → ()` | 何もしない | F04 |
//! | `patterns_ext::parse_arm_head_rest` | `p, first: Pattern, counter: &mut PatternCounter, depth: u32 → PResult<(Vec<Pattern>, Option<Box<Expr>>)>` | 最初のパターンだけ、ガードなし | F04 |
//! | `patterns_ext::parse_range_rest` | `p, first: Pattern, counter: &mut PatternCounter → PResult<Box<Pattern>>` | E0201、パターンの終わりまで回復、誤りのノード | F04 |
//! | `patterns_ext::parse_list_pattern` | `p, counter: &mut PatternCounter → PResult<Box<Pattern>>` | E0201、`]` まで回復、誤りのノード | F04 |
//! | `patterns_ext::report_tuple` | `p, count: usize, span: Span → ()` | `)` を期待する E0201 | F04 |
//!
//! 共通の関数（すべて `pub(super)`。`Parser` の状態と文脈の印も子から使える）:
//!
//! | 用途 | 関数 |
//! |---|---|
//! | 字句・名前 | `Parser::{peek, peek_kind, peek_nth_kind, at, advance, bump, eat, expect, expect_name, qual_name, word, symbol, skip_newlines, at_line_start}` |
//! | 位置・ノード | `Parser::{node_id, span_from, empty_span, error_node_from, error_token_node, snippet}`, `snippet::snippet`, `exprs::{span_of, pattern_span}`, `name_of`, `literal_of` |
//! | 診断・回復 | `Parser::{report, unexpected, recover}`, `Recovery`, `foreign::{report_symbol, report_unclaimed, operator, take_when, when_ahead, report_when, return_arrow}` |
//! | 深さ・並び | `Parser::enter`, `child`, `nth_child`, `element_depth`, `comma_list`, `CommaList`, `comma_list_tail`, `push`, `patterns::PatternCounter::{new, next_depth}` |
//! | 式・文・パターン・型 | `exprs::{parse_expr, parse_block, record_ahead}`, `exprs::BlockEnd`, `patterns::parse_pattern`, `types::{parse_type, parse_uses, parse_type_params}` |
//! | 宣言・シグネチャ | `decls::{parse_function, parse_signature, parse_params}`, `decls::Signature`, `is_decl_start` |
//! | ブロック | `Parser::{open_block, close_block, stub_expr}`, `items::{stub_decl, skip_delimited}` |
//! | 呼び名・テスト | `text` の字句・構文の呼び名、`test_support::{parse_source, codes, position, assert_recovers}`（テストのビルドだけ） |
//!
//! 仮の本体に依存するテストは各フックのファイルに置く。F03・F04 は中身を実装するときに
//! 自分のテストも改められるので、F02 のファイルとシグネチャを変えずに作業できる。

mod decls;
mod effects;
mod exprs;
mod foreign;
mod interp;
mod items;
mod patterns;
mod patterns_ext;
mod records;
mod snippet;
mod spread;
#[cfg(test)]
pub(crate) mod test_support;
mod text;
mod traits;
mod types;

use super::ast::Module;
use super::token::{Comment, Token};
use crate::base::{FileId, IdGen, SourceKind};
use crate::diag::Diagnostic;

/// 構文解析器が作る AST の深さの上限（02-03「入れ子の深さ」）。
pub const MAX_DEPTH: u32 = 1000;

/// 一つのファイルの構文解析の結果（02-03「構文解析の結果」）。
#[derive(Debug)]
pub struct ParseOutput {
    pub module: Module,
    /// 字句の切り出しの結果のコメントをそのまま入れる（ドキュメントコメントも含む）
    pub comments: Vec<Comment>,
    /// 構文解析の誤り。字句の切り出しの誤りは含めない（呼び出し側の読み込みの段が先に並べる）
    pub diagnostics: Vec<Diagnostic>,
}

/// NEWLINE を含む字句の列（`resolve_newlines` の出力）から、ファイル一つのモジュールの AST を作る。
/// `kind` が `SourceKind::Prelude`（標準ライブラリのソース。10-01「ソースの表」）のときだけ、`@builtin`・本体のない関数の宣言・制約 `ordered` を受け付ける。
/// ノード番号は `ids` から振る。`ids` は検査ごとに一つで、すべてのファイルで共有する（02-03「AST」）。
/// ドキュメントコメントは `comments` から宣言に結び付け、結び付かなかったものを構文エラーにする。
/// `text` は `lex` に渡したのと同じソースのバイト列（`Source::text()`）である。ドキュメントコメントと宣言の間の
/// 空行の判定と、修正案の置き換えの文字列（span の範囲のソースの写し）を作るために読む。
pub fn parse(
    file: FileId,
    kind: SourceKind,
    text: &[u8],
    tokens: Vec<Token>,
    comments: Vec<Comment>,
    ids: &mut IdGen,
) -> ParseOutput {
    let mut parser = Parser::new(file, kind, text, tokens, &comments, std::mem::take(ids));
    let module = decls::parse_module(&mut parser);
    parser.docs.finish(&mut parser.diagnostics);
    *ids = std::mem::take(&mut parser.ids);
    let diagnostics = std::mem::take(&mut parser.diagnostics);
    drop(parser);
    ParseOutput {
        module,
        comments,
        diagnostics,
    }
}

use super::ast::{ErrorNode, Literal, Name};
use super::token::{TokenKind, TokenValue};
use crate::base::{BytePos, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode};
use std::collections::BTreeSet;

#[derive(Debug)]
pub(super) struct Fail;
pub(super) type PResult<T> = Result<T, Fail>;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum ClauseContext {
    None,
    Direct,
    Blocked,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(super) enum EscapeContext {
    Allowed,
    InLazy,
    InGuard,
}
#[derive(Clone, Copy, Debug)]
pub(super) struct Context {
    pub(super) stdlib: bool,
    pub(super) clause: ClauseContext,
    pub(super) escape: EscapeContext,
    pub(super) in_arm_head: bool,
}
#[derive(Clone, Copy, Debug)]
pub(super) struct OpenBlock {
    pub(super) kind: TokenKind,
    pub(super) span: Span,
}

pub(super) struct Parser<'a> {
    pub(super) file: FileId,
    pub(super) kind: SourceKind,
    pub(super) text: &'a [u8],
    pub(super) tokens: Vec<Token>,
    pub(super) pos: usize,
    eof: Token,
    ids: IdGen,
    pub(super) diagnostics: Vec<Diagnostic>,
    pub(super) suppressed: bool,
    pub(super) aborted: bool,
    pub(super) deepest: u32,
    pub(super) blocks: Vec<OpenBlock>,
    pub(super) reported_symbols: BTreeSet<usize>,
    pub(super) ctx: Context,
    docs: items::DocStore<'a>,
}

impl<'a> Parser<'a> {
    fn new(
        file: FileId,
        kind: SourceKind,
        text: &'a [u8],
        mut tokens: Vec<Token>,
        comments: &'a [Comment],
        ids: IdGen,
    ) -> Self {
        let end = tokens.last().map_or(BytePos(0), |t| t.span.end);
        let eof = Token {
            kind: TokenKind::Eof,
            span: Span {
                file,
                start: end,
                end,
            },
            value: TokenValue::None,
        };
        if tokens.last().is_none_or(|t| t.kind != TokenKind::Eof) {
            tokens.push(eof.clone());
        }
        Self {
            file,
            kind,
            text,
            tokens,
            pos: 0,
            eof,
            ids,
            diagnostics: Vec::new(),
            suppressed: false,
            aborted: false,
            deepest: 0,
            blocks: Vec::new(),
            reported_symbols: BTreeSet::new(),
            ctx: Context {
                stdlib: kind == SourceKind::Prelude,
                clause: ClauseContext::None,
                escape: EscapeContext::Allowed,
                in_arm_head: false,
            },
            docs: items::DocStore::new(text, comments),
        }
    }
    // ---------------- 字句の読み進め ----------------

    pub(super) fn peek(&self) -> &Token {
        self.tokens.get(self.pos).unwrap_or(&self.eof)
    }

    pub(super) fn peek_kind(&self) -> TokenKind {
        self.peek().kind
    }

    /// 今の位置から `n` 個先の字句の種類。`Eof` の後は `Eof` を返し続ける。
    pub(super) fn peek_nth_kind(&self, n: usize) -> TokenKind {
        self.pos
            .checked_add(n)
            .and_then(|i| self.tokens.get(i))
            .map_or(TokenKind::Eof, |t| t.kind)
    }

    pub(super) fn at(&self, kind: TokenKind) -> bool {
        self.peek_kind() == kind
    }

    /// 字句を一つ読み進める。`Eof` では位置を動かさない。報告の抑制の印は変えない。
    pub(super) fn advance(&mut self) -> Token {
        foreign::report_unclaimed(self);
        let token = self.peek().clone();
        if token.kind != TokenKind::Eof {
            self.pos = self.pos.saturating_add(1);
        }
        token
    }

    /// 期待どおりの字句として一つ読み進める。報告の抑制を解く（02-03「誤りからの回復」）。
    pub(super) fn bump(&mut self) -> Token {
        self.suppressed = false;
        self.advance()
    }

    /// 次の字句が `kind` なら読み進める。そうでなければ構文エラーを報告して失敗する。
    pub(super) fn expect(&mut self, kind: TokenKind) -> PResult<Token> {
        if self.aborted {
            return Err(Fail);
        }
        if self.at(kind) {
            Ok(self.bump())
        } else {
            Err(self.unexpected(text::token_name(kind)))
        }
    }

    /// 次の字句が `kind` なら読み進めて true を返す。
    pub(super) fn eat(&mut self, kind: TokenKind) -> bool {
        if !self.aborted && self.at(kind) {
            self.bump();
            true
        } else {
            false
        }
    }

    /// 識別子（`LowerIdent` か `UpperIdent`）を名前として読む。`expected` は期待する構文の呼び名。
    pub(super) fn expect_name(&mut self, kind: TokenKind, expected: &str) -> PResult<Name> {
        if self.aborted {
            return Err(Fail);
        }
        if self.at(TokenKind::Error) {
            let span = self.advance().span;
            return Ok(Name {
                text: String::new(),
                span,
            });
        }
        if text::keyword(self.peek_kind()).is_some() {
            let token = self.bump();
            let word = text::keyword(token.kind).unwrap_or_default();
            self.report(
                DiagBuilder::new(DiagCode::E0216)
                    .arg("word", word)
                    .primary(token.span)
                    .help("rename")
                    .build(),
            );
            return Ok(Name {
                text: word.to_owned(),
                span: token.span,
            });
        }
        if !self.at(kind) {
            return Err(self.unexpected(expected));
        }
        Ok(name_of(&self.bump()))
    }

    // ---------------- 位置とノード番号 ----------------

    pub(super) fn node_id(&mut self) -> NodeId {
        self.ids.node()
    }

    /// 字句の位置 `start` から、最後に読んだ字句の終わりまでの span（02-02「span」）。
    /// 一つも読んでいなければ、今の字句の開始に長さ 0 の span を置く。
    pub(super) fn span_from(&self, start: usize) -> Span {
        if self.pos <= start {
            return self.empty_span();
        }
        let first = self.tokens.get(start);
        let last = self.pos.checked_sub(1).and_then(|i| self.tokens.get(i));
        if let (Some(first), Some(last)) = (first, last) {
            first.span.to(last.span)
        } else {
            self.empty_span()
        }
    }

    /// 今の字句の開始に置く長さ 0 の span。
    pub(super) fn empty_span(&self) -> Span {
        let at = self.peek().span.start;
        Span {
            file: self.file,
            start: at,
            end: at,
        }
    }

    /// 字句の位置 `start` から今までに読んだ（読み飛ばした）範囲を覆う誤りのノード。
    pub(super) fn error_node_from(&mut self, start: usize) -> ErrorNode {
        let span = self.span_from(start);
        ErrorNode {
            id: self.node_id(),
            span,
        }
    }

    /// 誤りの字句を一つ読み、その位置の誤りのノードにする。構文エラーは報告しない。
    /// 誤りの字句は字句の切り出しが既に報告している（02-03「字句」の最後の段落）。
    /// 期待どおりの字句ではないので、報告の抑制は解かない。
    pub(super) fn error_token_node(&mut self) -> ErrorNode {
        let start = self.pos;
        self.advance();
        self.error_node_from(start)
    }

    // ---------------- 報告 ----------------

    /// 構文エラーを一つ報告する。抑制中と打ち切りの後は捨てる。報告したら抑制の印を立てる。
    pub(super) fn report(&mut self, diagnostic: Diagnostic) {
        if self.aborted || self.suppressed {
            return;
        }
        self.diagnostics.push(diagnostic);
        self.suppressed = true;
    }

    /// 今の字句が期待に合わないことを E0201 で報告し、失敗の印を返す。
    /// 今の字句が誤りの字句なら報告せず、抑制の印だけを立てる（02-03「字句」の最後の段落）。
    pub(super) fn unexpected(&mut self, expected: &str) -> Fail {
        if self.at(TokenKind::BadSymbol) {
            foreign::report_unclaimed(self);
            self.suppressed = true;
            return Fail;
        }
        let token = self.peek();
        if token.kind == TokenKind::Error {
            self.suppressed = true;
            return Fail;
        }
        let diagnostic = DiagBuilder::new(DiagCode::E0201)
            .arg("expected", expected)
            .arg("found", text::describe(token))
            .primary(token.span)
            .build();
        self.report(diagnostic);
        Fail
    }

    // ---------------- 入れ子の深さ ----------------

    /// 深さ `depth` のノードを作り始める前に呼ぶ。上限を超えたら E0208 を報告して打ち切る
    /// （02-03「入れ子の深さ」）。打ち切った後は、字句を読まずに失敗する。
    /// 渡された深さの最大値を `deepest` に記録する（`expr` の「入れ子の深さ」）。
    pub(super) fn enter(&mut self, depth: u32) -> PResult<()> {
        self.deepest = self.deepest.max(depth);
        if self.aborted {
            return Err(Fail);
        }
        if depth <= MAX_DEPTH {
            return Ok(());
        }
        // 上限の報告は抑制の印によらず出す。打ち切りの原因を必ず示すため。
        let diagnostic = DiagBuilder::new(DiagCode::E0208)
            .arg("limit", MAX_DEPTH.to_string())
            .primary(self.peek().span)
            .build();
        self.diagnostics.push(diagnostic);
        self.aborted = true;
        Err(Fail)
    }

    // ---------------- 誤りからの回復 ----------------

    /// 構文エラーの後、`stop` の止まる字句まで読み飛ばす（02-03「誤りからの回復」）。
    ///
    /// `start` は、失敗した構文（並びの要素や宣言）の最初の字句の位置である。開いた括弧と閉じた括弧を
    /// `start` から数え、その構文の中で開いたままの括弧（`fn f(x: (Int, String))` の型の中の `(` など）の
    /// 内側では、止まる字句を調べない。内側のコンマや閉じ括弧を、外側の並びの区切りと取り違えないためである。
    /// 止まる字句と `Eof` は読まずに残す。打ち切った後は何も読まない。
    /// 読み飛ばした字句は期待どおりの字句ではないので、報告の抑制は解かない。
    pub(super) fn recover(&mut self, start: usize, stop: Recovery) {
        if self.aborted {
            return;
        }
        let mut nesting = Vec::new();
        let mut previous = TokenKind::Eof;
        for token in self.tokens.get(start..self.pos).unwrap_or_default() {
            recovery_nesting(&mut nesting, token.kind, previous);
            previous = token.kind;
        }
        while !self.at(TokenKind::Eof) {
            if nesting.is_empty() && stop.stops_at(self) {
                return;
            }
            let kind = self.peek_kind();
            recovery_nesting(&mut nesting, kind, previous);
            previous = kind;
            self.advance();
        }
    }

    /// 今の字句が行の先頭（直前の字句が NEWLINE か、ファイルの先頭）にあるか。
    pub(super) fn at_line_start(&self) -> bool {
        match self.pos.checked_sub(1) {
            None => true,
            Some(prev) => self
                .tokens
                .get(prev)
                .is_none_or(|t| t.kind == TokenKind::Newline),
        }
    }
}

/// 解析の結果を並びに加える。`comma_list` と `line_list` の要素の解析の関数を書くのに使う。
pub(super) fn push<T>(out: &mut Vec<T>, result: PResult<T>) -> PResult<()> {
    out.push(result?);
    Ok(())
}

/// 丸括弧・角括弧の中のコンマ区切りの並び（01-02 の `CommaList`）の読み方。
#[derive(Clone, Copy, Debug)]
pub(super) struct CommaList {
    /// 並びを閉じる字句
    pub(super) close: TokenKind,
    /// 要素の呼び名（空の並びを許さないときの E0201 の `{expected}`）
    pub(super) element: &'static str,
    /// 要素の後に期待する字句の呼び名（`,` か閉じる字句）
    pub(super) separator: &'static str,
    /// 空の並びを許すか（`FnTypeParams`・`TypeParams`・型引数は許さない）
    pub(super) allow_empty: bool,
    /// 要素の深さを並びの位置で数えるか（02-03「入れ子の深さ」の「並びの要素」）。
    /// 偽なら、どの要素も親の深さに 1 を加えた深さにする
    pub(super) indexed: bool,
}

/// 開き括弧を読んだ後から、閉じる字句までの並びを読む。閉じる字句も読む。
///
/// `depth` は並びを持つノードの深さである。要素の解析の関数 `elem` は、読んだ要素を第 3 引数の並びに
/// 加える（「スタックの使い方」）。要素の解析が失敗したら、同じ括弧の中の次の `,` か
/// 閉じる字句まで読み飛ばし（02-03「誤りからの回復」）、読み飛ばした範囲の誤りのノードを
/// `on_error` に渡す。`on_error` は、要素の型に誤りの変種があれば、それを並びに加える。
/// 閉じる字句に達しないまま並びが終わったら失敗し、外側の並びの回復に任せる。
pub(super) fn comma_list<T>(
    p: &mut Parser,
    depth: u32,
    spec: CommaList,
    mut elem: impl FnMut(&mut Parser, u32, &mut Vec<T>) -> PResult<()>,
    mut on_error: impl FnMut(&mut Vec<T>, ErrorNode),
) -> PResult<Vec<T>> {
    // 要素の解析の関数を呼ぶところ以外は補助の関数に分け、この関数の枠を小さく保つ
    // （「スタックの使い方」）。
    let mut items = Vec::new();
    // 並びの位置。誤りの要素も数える
    let mut index: usize = 0;
    loop {
        match comma_list_head(p, spec, index) {
            ListStep::Element => {}
            ListStep::Done => return Ok(items),
            ListStep::Failed => return Err(Fail),
        }
        let start = p.pos;
        let failed = elem(p, element_depth(depth, spec.indexed, index), &mut items).is_err();
        let added = comma_list_tail(p, spec, start, failed, &mut items, &mut on_error)?;
        index = index.saturating_add(added);
    }
}

/// 並びの次の一歩。
enum ListStep {
    /// 次の要素を読む
    Element,
    /// 並びを閉じる字句を読んだ
    Done,
    /// 失敗した（打ち切りか、閉じる字句がない）
    Failed,
}

/// 要素の深さ（02-03「入れ子の深さ」）。`indexed` なら並びの位置で数える。
pub(super) fn element_depth(depth: u32, indexed: bool, index: usize) -> u32 {
    if indexed {
        nth_child(depth, index)
    } else {
        child(depth)
    }
}

/// コンマ区切りの並びの、要素を読む前の処理。閉じる字句なら読んで終える。
fn comma_list_head(p: &mut Parser, spec: CommaList, index: usize) -> ListStep {
    if p.aborted {
        return ListStep::Failed;
    }
    if !p.at(spec.close) {
        return ListStep::Element;
    }
    if index == 0 && !spec.allow_empty {
        // 空の並びを報告し、閉じる字句を読んで続ける。期待どおりの字句ではないので抑制は解かない。
        let _: Fail = p.unexpected(spec.element);
        p.advance();
    } else {
        p.bump();
    }
    ListStep::Done
}

/// コンマ区切りの並びの、要素を読んだ後の処理。並びに置いた要素の数（位置の進み）を返す。
///
/// 要素の解析が失敗していたら、その要素の始まりから数えて回復する。要素の後に `,` も閉じる字句も
/// ないとき（`pub(super) fn f(x: Int y: Int)`）は、E0201 を報告し、同じ括弧の中の次の `,` か閉じる字句まで
/// 読み飛ばして、読み飛ばした範囲を並びに置く（02-03「誤りからの回復」）。
/// 回復しても `,` にも閉じる字句にも着かなければ（外側の閉じ括弧か `Eof`）、失敗を返す。
pub(super) fn comma_list_tail<T>(
    p: &mut Parser,
    spec: CommaList,
    start: usize,
    failed: bool,
    items: &mut Vec<T>,
    on_error: &mut impl FnMut(&mut Vec<T>, ErrorNode),
) -> PResult<usize> {
    let mut added: usize = 1;
    if failed {
        if p.aborted {
            return Err(Fail);
        }
        p.recover(start, Recovery::Comma);
        let node = p.error_node_from(start);
        on_error(items, node);
    } else if !p.at(TokenKind::Comma) && !p.at(spec.close) {
        let _: Fail = p.unexpected(spec.separator);
        let junk = p.pos;
        p.recover(junk, Recovery::Comma);
        let node = p.error_node_from(junk);
        on_error(items, node);
        added = 2;
    }
    // 末尾のコンマを許す（01-02 の `CommaList`）。閉じる字句は次の要素の前の処理で読む。
    if p.eat(TokenKind::Comma) || p.at(spec.close) {
        return Ok(added);
    }
    // 外側の構文の閉じ括弧か `Eof`。報告は済んでいる（抑制中）ので、外側の回復に任せる。
    Err(p.unexpected(spec.separator))
}

/// 親のノードの深さに 1 を加えた深さ（子のノードの深さ）。
/// 溢れたら上限を超えたものとして扱う（02-03「入れ子の深さ」）。
pub(super) fn child(depth: u32) -> u32 {
    let Some(deeper) = depth.checked_add(1) else {
        // 溢れた深さは上限（`MAX_DEPTH`）を超える値にする。
        return u32::MAX;
    };
    deeper
}

/// 並びの `index` 番目（0 から数える）の要素の深さ。親の深さに `index + 1` を加える
/// （02-03「入れ子の深さ」の、ブロックの文と並びの要素の数え方）。
pub(super) fn nth_child(depth: u32, index: usize) -> u32 {
    u32::try_from(index)
        .ok()
        .and_then(|i| i.checked_add(1))
        .and_then(|n| depth.checked_add(n))
        .unwrap_or(u32::MAX)
}

/// 識別子の字句から名前を作る。
pub(super) fn name_of(token: &Token) -> Name {
    let text = if let TokenValue::Ident(text) = &token.value {
        text.clone()
    } else {
        String::new()
    };
    Name {
        text,
        span: token.span,
    }
}

/// リテラルの字句（整数・浮動小数・文字列・文字、`true`・`false`）の値。リテラルでなければ `None`。
pub(super) fn literal_of(token: &Token) -> Option<Literal> {
    match (token.kind, &token.value) {
        (TokenKind::IntLit, TokenValue::Int { radix, digits }) => Some(Literal::Int {
            radix: *radix,
            digits: digits.clone(),
        }),
        (TokenKind::FloatLit, TokenValue::Float(text)) => Some(Literal::Float(text.clone())),
        (TokenKind::DecimalLit, TokenValue::Decimal(text)) => Some(Literal::Decimal(text.clone())),
        (TokenKind::StringLit, TokenValue::Str(text)) => Some(Literal::Str(text.clone())),
        (TokenKind::CharLit, TokenValue::Char(c)) => Some(Literal::Char(*c)),
        (TokenKind::KwTrue, _) => Some(Literal::Bool(true)),
        (TokenKind::KwFalse, _) => Some(Literal::Bool(false)),
        _ => None,
    }
}

/// 回復で止まる位置（設計書 02-03「誤りからの回復」）。
#[derive(Clone, Copy)]
pub(super) enum Recovery {
    TopLevel,
    Line,
    Comma,
}
impl Recovery {
    fn stops_at(self, p: &Parser) -> bool {
        match self {
            Self::TopLevel => is_decl_start(p.peek_kind()) && p.at_line_start(),
            Self::Line => p.at(TokenKind::Newline) || p.at(TokenKind::KwEnd) || p.symbol("}"),
            Self::Comma => matches!(
                p.peek_kind(),
                TokenKind::Comma | TokenKind::RParen | TokenKind::RBracket
            ),
        }
    }
}

fn recovery_nesting(stack: &mut Vec<TokenKind>, kind: TokenKind, previous: TokenKind) {
    if matches!(kind, TokenKind::LParen | TokenKind::LBracket) {
        stack.push(kind);
    } else if matches!(kind, TokenKind::RParen | TokenKind::RBracket)
        || previous == TokenKind::KwEnd
    {
        stack.pop();
    } else if previous != TokenKind::KwElse
        && matches!(
            kind,
            TokenKind::KwIf
                | TokenKind::KwLambda
                | TokenKind::KwMatch
                | TokenKind::KwLazy
                | TokenKind::KwHandle
        )
    {
        stack.push(kind);
    }
}

pub(super) fn is_decl_start(kind: TokenKind) -> bool {
    matches!(
        kind,
        TokenKind::KwImport
            | TokenKind::KwPublic
            | TokenKind::At
            | TokenKind::KwFunction
            | TokenKind::KwConst
            | TokenKind::KwData
            | TokenKind::KwType
            | TokenKind::KwRecord
            | TokenKind::KwTrait
            | TokenKind::KwImplement
            | TokenKind::KwEffect
    )
}

impl Parser<'_> {
    pub(super) fn symbol(&self, symbol: &str) -> bool {
        self.at(TokenKind::BadSymbol)
            && matches!(&self.peek().value, TokenValue::Symbol(s) if s == symbol)
    }
    pub(super) fn word(&self, word: &str) -> bool {
        self.at(TokenKind::LowerIdent)
            && matches!(&self.peek().value, TokenValue::Ident(s) if s == word)
    }
    pub(super) fn snippet(&self, span: Span) -> String {
        snippet::snippet(self.text, span)
    }
    pub(super) fn skip_newlines(&mut self) {
        while self.at(TokenKind::Newline) || self.symbol(";") {
            self.bump();
        }
    }
    pub(super) fn qual_name(&mut self, upper_only: bool) -> PResult<Vec<Name>> {
        let mut path = Vec::new();
        let mut upper = upper_only || self.at(TokenKind::UpperIdent);
        loop {
            path.push(self.expect_name(
                if upper {
                    TokenKind::UpperIdent
                } else {
                    TokenKind::LowerIdent
                },
                text::NAME,
            )?);
            if !upper || !self.at(TokenKind::Dot) {
                break;
            }
            self.bump();
            upper = upper_only || self.at(TokenKind::UpperIdent);
        }
        Ok(path)
    }
    pub(super) fn open_block(&mut self, kind: TokenKind, span: Span) {
        self.blocks.push(OpenBlock { kind, span });
    }
    pub(super) fn close_block(&mut self, kind: TokenKind) -> Span {
        // 閉じた後では外側が最も内側になるので、記号への修正案は降ろす前に選ぶ。
        if self.symbol("}") {
            foreign::report_unclaimed(self);
        }
        let opened = self.blocks.pop().unwrap_or(OpenBlock {
            kind,
            span: self.empty_span(),
        });
        if self.aborted {
            return self.empty_span();
        }
        if self.symbol("}") {
            return self.bump().span;
        }
        let at = self.peek().span;
        if self.at(TokenKind::KwEnd) {
            let found = self.peek_nth_kind(1);
            if found == kind {
                self.bump();
                return self.bump().span;
            }
            if self.blocks.iter().any(|block| block.kind == found) {
                self.report(
                    DiagBuilder::new(DiagCode::E0214)
                        .arg("construct", text::keyword(kind).unwrap_or_default())
                        .primary(at)
                        .secondary(opened.span, "opened")
                        .build(),
                );
                return at;
            }
            self.bump();
            let last = if !self.at(TokenKind::Eof) {
                self.advance().span
            } else {
                self.empty_span()
            };
            let expected = text::keyword(kind).unwrap_or_default();
            self.report(
                DiagBuilder::new(DiagCode::E0213)
                    .arg(
                        "found",
                        text::keyword(found).unwrap_or_else(|| text::token_name(found)),
                    )
                    .arg("expected", expected)
                    .primary(at.to(last))
                    .secondary(opened.span, "opened")
                    .help_edits(
                        "replace",
                        vec![crate::diag::Edit {
                            span: last,
                            replacement: expected.to_owned(),
                        }],
                    )
                    .build(),
            );
            return last;
        }
        self.report(
            DiagBuilder::new(DiagCode::E0214)
                .arg("construct", text::keyword(kind).unwrap_or_default())
                .primary(at)
                .secondary(opened.span, "opened")
                .build(),
        );
        at
    }
    pub(super) fn stub_expr(
        &mut self,
        depth: u32,
        expected: &str,
        end: TokenKind,
    ) -> PResult<Box<super::ast::Expr>> {
        self.enter(depth)?;
        let start = self.pos;
        self.unexpected(expected);
        self.advance();
        let mut nesting = 0_u32;
        while !self.at(TokenKind::Eof) && !self.aborted {
            if self.at(TokenKind::KwEnd) && self.peek_nth_kind(1) == end {
                self.advance();
                self.advance();
                if nesting == 0 {
                    break;
                }
                nesting = nesting.saturating_sub(1);
            } else {
                if self.at(end) {
                    nesting = nesting.saturating_add(1);
                }
                self.advance();
            }
        }
        Ok(Box::new(super::ast::Expr::Error(
            self.error_node_from(start),
        )))
    }
}

#[cfg(test)]
// 公開の parse の結果（AST・診断・位置・修正案・打ち切り）が契約である。最小実行版とは
// 字句と AST が異なるため、新構文の退行をこの境界で確かめる。準備は本物の lex と改行判定を使い、
// 実装の補助の関数を置き換えない（test-audit の作成時の関門、設計書 07-03）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::test_support::{codes, parse_source, position};
    use super::*;
    use crate::syntax::ast::*;

    fn user(src: &str) -> ParseOutput {
        let (out, lex) = parse_source(src, SourceKind::User);
        assert!(lex.is_empty(), "{src}: {lex:?}");
        out
    }
    fn body(src: &str) -> String {
        format!("function f() -> Unit\n{src}\nend function")
    }
    fn function(out: &ParseOutput) -> &FnDecl {
        let Item::Fn(f) = &out.module.decls[0].item else {
            panic!("{:?}", out.module);
        };
        f
    }
    fn expr(out: &ParseOutput) -> &Expr {
        let Stmt::Expr(e) = &function(out).body.as_ref().unwrap().stmts[0] else {
            panic!();
        };
        e
    }
    fn shape(e: &Expr) -> String {
        match e {
            Expr::Name(n) => n
                .path
                .iter()
                .map(|n| n.text.as_str())
                .collect::<Vec<_>>()
                .join("."),
            Expr::Lit(l) => match &l.lit {
                Literal::Int { digits, .. } => digits.clone(),
                Literal::Bool(b) => b.to_string(),
                Literal::Float(f) | Literal::Decimal(f) => f.clone(),
                Literal::Str(s) => format!("{s:?}"),
                Literal::Char(c) => format!("'{c}'"),
            },
            Expr::Binary(b) => format!("({:?} {} {})", b.op, shape(&b.lhs), shape(&b.rhs)),
            Expr::Unary(u) => format!("({:?} {})", u.op, shape(&u.operand)),
            Expr::Pipe(b) => format!("(pipe {} {})", shape(&b.lhs), shape(&b.rhs)),
            Expr::Paren(p) => format!("(paren {})", shape(&p.inner)),
            Expr::Return(r) => format!("(return {})", shape(&r.value)),
            Expr::Unit(_) => "()".to_owned(),
            Expr::Call(c) => format!(
                "(call {} {})",
                shape(&c.callee),
                c.args
                    .iter()
                    .map(|a| match a {
                        Arg::Expr(e) => shape(e),
                        Arg::Placeholder(_) => "_".to_owned(),
                    })
                    .collect::<Vec<_>>()
                    .join(" ")
            ),
            Expr::List(_)
            | Expr::If(_)
            | Expr::Match(_)
            | Expr::Lambda(_)
            | Expr::Error(_)
            | Expr::Interp(_)
            | Expr::Record(_)
            | Expr::Try(_)
            | Expr::Lazy(_)
            | Expr::With(_)
            | Expr::Handle(_)
            | Expr::Resume(_) => panic!("unhandled shape {e:?}"),
        }
    }

    #[test]
    fn precedence_calls_and_written_forms() {
        for (source, expected) in [
            (
                "a or b and c = d + e * f",
                "(Or a (And b (Eq c (Add d (Mul e f)))))",
            ),
            ("not a and b", "(And (Not a) b)"),
            ("-x * y", "(Mul (Neg x) y)"),
            ("x |> f |> g", "(pipe (pipe x f) g)"),
            ("a div b mod c", "(Mod (IntDiv a b) c)"),
            ("return x |> f", "(return (pipe x f))"),
            ("f(_, 1)", "(call f _ 1)"),
            ("f(g(_))", "(call f (call g _))"),
            ("List.map", "List.map"),
            ("A.B.c", "A.B.c"),
            ("Shape.Circle(1.0)", "(call Shape.Circle 1.0)"),
            ("x |> (f(a))", "(pipe x (paren (call f a)))"),
        ] {
            let out = user(&body(source));
            assert!(
                out.diagnostics.is_empty(),
                "{source}: {:?}",
                out.diagnostics
            );
            assert_eq!(shape(expr(&out)), expected, "{source}");
        }
        let out = user(&body("if a then 1 else if b then 2 else 3 end if"));
        assert!(out.diagnostics.is_empty());
        let Expr::If(branch) = expr(&out) else {
            panic!();
        };
        assert!(
            matches!(&branch.else_branch, Some(ElseBranch::If(b)) if matches!(b.else_branch, Some(ElseBranch::Block(_))))
        );
    }

    // 仕様書の例をそのまま境界へ渡し、例と実装の乖離を検出する。期待する AST の主要な欄は
    // 別の表のテストで確かめるので、ここでは例を読めるという契約だけを受け持つ。
    fn spec_examples() -> Vec<String> {
        let syntax = include_str!("../../../../../docs/design/01-spec/01-02-syntax.md");
        let lexical = include_str!("../../../../../docs/design/01-spec/01-01-lexical.md");
        let mut examples = Vec::new();
        // 区切りが `None` の節は、章の最後の節なので章の終わりまでを読む。
        for (document, from, to, program) in [
            (
                syntax,
                "### プログラムと宣言",
                Some("### ブロックと文"),
                true,
            ),
            (
                syntax,
                "### ブロックと文",
                Some("### モジュールと import"),
                false,
            ),
            (syntax, "### 例", None, true),
            (lexical, "### 改行による区切り", None, false),
        ] {
            let rest = document.split_once(from).unwrap().1;
            let section = match to {
                Some(to) => rest.split_once(to).unwrap().0,
                None => rest,
            };
            for fenced in section.split("```text\n").skip(1) {
                let source = fenced.split_once("```").unwrap().0;
                examples.push(if program || source.starts_with("function ") {
                    source.to_owned()
                } else {
                    body(source)
                });
            }
        }
        examples
    }

    #[test]
    fn specification_examples_and_golden_programs_parse() {
        let examples = spec_examples();
        assert_eq!(examples.len(), 11);
        for source in &examples {
            let out = user(source);
            assert!(
                out.diagnostics.is_empty(),
                "{source}: {:?}",
                out.diagnostics
            );
        }
        let shape = user(&examples[8]);
        let Item::Fn(area) = &shape.module.decls[1].item else {
            panic!();
        };
        let Stmt::Expr(Expr::Return(ret)) = &area.body.as_ref().unwrap().stmts[0] else {
            panic!();
        };
        let Expr::Match(m) = ret.value.as_ref() else {
            panic!();
        };
        assert_eq!(m.arms.len(), 2);
        let Item::Fn(total) = &shape.module.decls[2].item else {
            panic!();
        };
        let Stmt::Expr(Expr::Return(ret)) = &total.body.as_ref().unwrap().stmts[0] else {
            panic!();
        };
        assert!(
            matches!(ret.value.as_ref(), Expr::Pipe(p) if matches!(p.lhs.as_ref(), Expr::Pipe(_)))
        );
        for source in [
            include_str!("../../../testdata/syntax/f02_blocks.bnt"),
            include_str!("../../../testdata/syntax/f02_data.bnt"),
            include_str!("../../../testdata/syntax/f02_operators.bnt"),
            include_str!("../../../testdata/syntax/f02_pipe.bnt"),
            include_str!("../../../testdata/syntax/f02_bindings.bnt"),
        ] {
            let out = user(source);
            assert!(
                out.diagnostics.is_empty(),
                "{source}: {:?}",
                out.diagnostics
            );
            assert!(
                matches!(&out.module.decls.last().unwrap().item, Item::Fn(f) if f.name.text == "main" && f.uses.is_none())
            );
        }
    }

    // 位置と番号は後の段の表・診断の独立した契約であり、木の形だけの検査では守れない。
    // 仕様書の例と代表的な型・パターンを辿り、共有の IdGen を複数ファイルで使う。
    struct NodeCheck<'a> {
        tokens: &'a [Token],
        ids: &'a mut BTreeSet<NodeId>,
    }
    impl NodeCheck<'_> {
        fn node(&mut self, id: NodeId, span: Span, parent: Span) {
            assert!(self.ids.insert(id), "duplicate node {id:?}");
            assert_eq!(span.file, parent.file);
            assert!(
                parent.start <= span.start && span.start <= span.end && span.end <= parent.end,
                "{span:?} outside {parent:?}"
            );
            assert!(
                self.tokens.iter().any(|t| t.span.start == span.start),
                "invalid start {span:?}"
            );
            assert!(
                self.tokens.iter().any(|t| t.span.end == span.end),
                "invalid end {span:?}"
            );
        }
        fn uses(&mut self, uses: &Option<UsesList>, parent: Span) {
            if let Some(uses) = uses {
                assert!(parent.start <= uses.span.start && uses.span.end <= parent.end);
                for e in &uses.effects {
                    self.node(e.id, e.span, uses.span);
                }
            }
        }
        fn params(&mut self, params: &[Param], parent: Span) {
            for param in params {
                self.node(param.id, param.span, parent);
                assert_eq!(param.span.start, param.name.span.start);
                if let Some(ty) = &param.ty {
                    self.ty(ty, param.span);
                    assert_eq!(param.span.end, ty.span().end);
                }
            }
        }
        fn type_params(&mut self, params: &[TypeParamDecl], parent: Span) {
            for param in params {
                self.node(param.id, param.span, parent);
                for constraint in &param.constraints {
                    if let ConstraintRef::Class(class) = constraint {
                        self.node(class.id, class.span, param.span);
                    }
                }
            }
        }
        fn ty(&mut self, ty: &TypeExpr, parent: Span) {
            self.node(ty.id(), ty.span(), parent);
            match ty {
                TypeExpr::Named(t) => {
                    for arg in &t.args {
                        self.ty(arg, t.span);
                    }
                }
                TypeExpr::Fn(t) => {
                    for param in &t.params {
                        self.ty(param, t.span);
                    }
                    self.ty(&t.ret, t.span);
                    self.uses(&t.uses, t.span);
                }
                TypeExpr::Paren(t) => self.ty(&t.inner, t.span),
                TypeExpr::Error(_) => panic!("error type in valid input"),
            }
        }
        fn pattern(&mut self, pattern: &Pattern, parent: Span) {
            self.node(pattern.id(), pattern.span(), parent);
            match pattern {
                Pattern::Ctor(p) => {
                    for arg in &p.args {
                        self.pattern(arg, p.span);
                    }
                }
                Pattern::Wildcard(_) | Pattern::Var(_) | Pattern::Lit(_) | Pattern::Unit(_) => {}
                Pattern::Record(_) | Pattern::Range(_) | Pattern::List(_) | Pattern::Error(_) => {
                    panic!("unexpected F02 pattern")
                }
            }
        }
        fn block(&mut self, block: &Block, parent: Span) {
            self.node(block.id, block.span, parent);
            if let Some((first, last)) = block.stmts.first().zip(block.stmts.last()) {
                assert_eq!(block.span, first.span().to(last.span()));
            } else {
                assert_eq!(block.span.start, block.span.end);
            }
            for stmt in &block.stmts {
                match stmt {
                    Stmt::Bind(b) => {
                        self.node(b.id, b.span, block.span);
                        assert_eq!(b.span.start, b.keyword_span.start);
                        assert_eq!(b.span.end, b.value.span().end);
                        self.pattern(&b.pattern, b.span);
                        if let Some(ty) = &b.ty {
                            self.ty(ty, b.span);
                        }
                        self.expr(&b.value, b.span);
                    }
                    Stmt::Expr(e) => self.expr(e, block.span),
                    Stmt::Error(_) => panic!("error statement in valid input"),
                }
            }
        }
        fn branch(&mut self, branch: &IfExpr) {
            self.expr(&branch.cond, branch.span);
            self.block(&branch.then_block, branch.span);
            match &branch.else_branch {
                Some(ElseBranch::Block(b)) => self.block(b, branch.span),
                Some(ElseBranch::If(b)) => {
                    self.node(b.id, b.span, branch.span);
                    self.branch(b);
                }
                None => {}
            }
        }
        fn expr(&mut self, expr: &Expr, parent: Span) {
            self.node(expr.id(), expr.span(), parent);
            match expr {
                Expr::Lit(_) | Expr::Name(_) | Expr::Unit(_) => {}
                Expr::Paren(e) => self.expr(&e.inner, e.span),
                Expr::List(e) => {
                    for elem in &e.elems {
                        let ListElem::Expr(arg) = elem else {
                            panic!();
                        };
                        self.expr(arg, e.span);
                    }
                }
                Expr::Call(e) => {
                    assert_eq!(e.span.start, e.callee.span().start);
                    self.expr(&e.callee, e.span);
                    for arg in &e.args {
                        match arg {
                            Arg::Expr(arg) => self.expr(arg, e.span),
                            Arg::Placeholder(a) => self.node(a.id, a.span, e.span),
                        }
                    }
                }
                Expr::Binary(e) => {
                    assert_eq!(e.span, e.lhs.span().to(e.rhs.span()));
                    self.expr(&e.lhs, e.span);
                    self.expr(&e.rhs, e.span);
                }
                Expr::Unary(e) => {
                    assert_eq!(e.span, e.op_span.to(e.operand.span()));
                    self.expr(&e.operand, e.span);
                }
                Expr::Pipe(e) => {
                    assert_eq!(e.span, e.lhs.span().to(e.rhs.span()));
                    self.expr(&e.lhs, e.span);
                    self.expr(&e.rhs, e.span);
                }
                Expr::If(e) => self.branch(e),
                Expr::Match(e) => {
                    self.expr(&e.scrutinee, e.span);
                    for arm in &e.arms {
                        self.node(arm.id, arm.span, e.span);
                        assert_eq!(arm.span.end, arm.body.span.end);
                        for p in &arm.patterns {
                            self.pattern(p, arm.span);
                        }
                        self.block(&arm.body, arm.span);
                    }
                }
                Expr::Lambda(e) => {
                    self.params(&e.params, e.span);
                    if let Some(ty) = &e.ret {
                        self.ty(ty, e.span);
                    }
                    self.uses(&e.uses, e.span);
                    self.block(&e.body, e.span);
                }
                Expr::Return(e) => {
                    assert_eq!(e.span.end, e.value.span().end);
                    self.expr(&e.value, e.span);
                }
                Expr::Interp(_)
                | Expr::Record(_)
                | Expr::Try(_)
                | Expr::Lazy(_)
                | Expr::With(_)
                | Expr::Handle(_)
                | Expr::Resume(_)
                | Expr::Error(_) => panic!("unexpected F02 expression"),
            }
        }
    }

    #[test]
    fn nodes_cover_their_tokens_and_have_distinct_ids_across_files() {
        let mut sources = spec_examples();
        sources.push("data Tree[T]\nLeaf\nNode(Tree[T], T, Tree[T])\nend data\nfunction f[T: M.Show & equality, F[_, _], effect E](x: (function(T) -> T uses E)) -> Unit\nbind Pair(a, b): Pair[Integer, Integer] <- Pair(-1, 2)\nshadow a <- 3\nbind _ <- f(_, 1)\nbind _ <- [1.2m, 'あ', \"文字\", true]\nmatch x with\ncase C(-1, 'a', \"x\", true, (), _) -> ()\ncase C() -> ()\nend match\nend function".to_owned());
        let mut ids = IdGen::new();
        let mut seen = BTreeSet::new();
        for (index, source) in sources.iter().enumerate() {
            let file = FileId(u32::try_from(index).unwrap());
            let lexed = crate::syntax::lexer::lex(file, source.as_bytes());
            assert!(lexed.diagnostics.is_empty());
            let tokens = crate::syntax::newline::resolve_newlines(lexed.tokens);
            let out = parse(
                file,
                SourceKind::User,
                source.as_bytes(),
                tokens.clone(),
                lexed.comments.clone(),
                &mut ids,
            );
            assert!(
                out.diagnostics.is_empty(),
                "{source}: {:?}",
                out.diagnostics
            );
            assert_eq!(out.comments, lexed.comments);
            let module = &out.module;
            let mut check = NodeCheck {
                tokens: &tokens,
                ids: &mut seen,
            };
            check.node(module.id, module.span, module.span);
            for decl in &module.decls {
                match &decl.item {
                    Item::Fn(f) => {
                        check.node(f.id, f.span, module.span);
                        assert_eq!(decl.span, f.span);
                        check.type_params(&f.type_params, f.span);
                        check.params(&f.params, f.span);
                        check.ty(&f.ret, f.span);
                        check.uses(&f.uses, f.span);
                        check.block(f.body.as_ref().unwrap(), f.span);
                        assert!(
                            source[usize::try_from(f.span.start.0).unwrap()
                                ..usize::try_from(f.span.end.0).unwrap()]
                                .ends_with("end function")
                        );
                    }
                    Item::Data(d) => {
                        check.node(d.id, d.span, module.span);
                        assert_eq!(decl.span, d.span);
                        check.type_params(&d.type_params, d.span);
                        for v in &d.variants {
                            check.node(v.id, v.span, d.span);
                            for ty in &v.fields {
                                check.ty(ty, v.span);
                            }
                        }
                    }
                    Item::Const(_)
                    | Item::Alias(_)
                    | Item::Record(_)
                    | Item::Trait(_)
                    | Item::Effect(_)
                    | Item::Impl(_)
                    | Item::Error(_) => panic!("unexpected F02 declaration"),
                }
            }
        }
    }

    #[test]
    fn bindings_data_and_type_parameters() {
        let source = "data Tree[T]\nLeaf\nNode(Tree[T], T, Tree[T])\nend data\nfunction f[T: Show & equality, F[_], effect E](x: T) -> Unit\nbind x: Integer <- 1\nshadow x <- 2\nbind _ <- f()\nbind Pair(a, b) <- p\nend function";
        let out = user(source);
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        let Item::Data(data) = &out.module.decls[0].item else {
            panic!();
        };
        assert_eq!(data.variants.len(), 2);
        assert_eq!(data.variants[1].fields.len(), 3);
        let Item::Fn(f) = &out.module.decls[1].item else {
            panic!();
        };
        assert!(matches!(
            &f.type_params[0].constraints[..],
            [
                ConstraintRef::Class(_),
                ConstraintRef::Builtin {
                    kind: BuiltinConstraint::Equality,
                    ..
                }
            ]
        ));
        assert_eq!(f.type_params[1].kind, TypeParamKind::Ctor { arity: 1 });
        assert_eq!(f.type_params[2].kind, TypeParamKind::Effect);
        let stmts = &f.body.as_ref().unwrap().stmts;
        let Stmt::Bind(first) = &stmts[0] else {
            panic!();
        };
        assert_eq!(first.mode, BindMode::Bind);
        assert!(first.ty.is_some());
        assert_eq!(
            first.keyword_span.start,
            position(source, "bind x").unwrap()
        );
        let Stmt::Bind(second) = &stmts[1] else {
            panic!();
        };
        assert_eq!(second.mode, BindMode::Shadow);
        assert!(matches!(&stmts[2], Stmt::Bind(b) if matches!(b.pattern, Pattern::Wildcard(_))));
        assert!(
            matches!(&stmts[3], Stmt::Bind(b) if matches!(&b.pattern, Pattern::Ctor(p) if p.args.len() == 2))
        );
    }

    #[test]
    fn uses_attaches_to_the_innermost_type_and_reads_longest_list() {
        for (ty, effects, outer_params) in [
            (
                "function(function() -> Unit uses Console.Write, E) -> Unit",
                vec!["Console.Write", "E"],
                1,
            ),
            (
                "function() -> function() -> Integer uses Console.Write",
                vec!["Console.Write"],
                0,
            ),
            (
                "function((function() -> Unit uses A), List[Integer]) -> Unit",
                vec!["A"],
                2,
            ),
        ] {
            let out = user(&format!("function f(x: {ty}) -> Unit\n()\nend function"));
            assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
            let TypeExpr::Fn(outer) = function(&out).params[0].ty.as_ref().unwrap() else {
                panic!();
            };
            assert_eq!(outer.params.len(), outer_params);
            assert!(outer.uses.is_none());
            let inner = if outer.params.is_empty() {
                outer.ret.as_ref()
            } else {
                &outer.params[0]
            };
            let inner = if let TypeExpr::Paren(inner) = inner {
                inner.inner.as_ref()
            } else {
                inner
            };
            let TypeExpr::Fn(inner) = inner else {
                panic!();
            };
            assert_eq!(
                inner
                    .uses
                    .as_ref()
                    .unwrap()
                    .effects
                    .iter()
                    .map(|e| e
                        .path
                        .iter()
                        .map(|n| n.text.as_str())
                        .collect::<Vec<_>>()
                        .join("."))
                    .collect::<Vec<_>>(),
                effects
            );
        }
        let out = user(
            "function f(x: function(function() -> Unit uses A, List[Integer]) -> Unit) -> Unit\n()\nend function",
        );
        assert_eq!(codes(&out), [DiagCode::E0209]);
    }

    #[test]
    fn diagnostics_and_recovery_for_foreign_forms() {
        for (source, expected) in [
            ("_ + 1", vec![DiagCode::E0204]),
            ("fn(x) { fn(y) { y } }\n()", vec![DiagCode::E0251]),
            ("xs.map(f)", vec![DiagCode::E0203]),
            ("p.name", vec![DiagCode::E0203]),
            ("let x = 1", vec![DiagCode::E0230]),
            ("!ok", vec![DiagCode::E0211]),
            ("n % 2", vec![DiagCode::E0211]),
            ("a; b", vec![DiagCode::E0106]),
            ("x?", vec![DiagCode::E0211]),
            (
                "if x == 1 && y != 2 { () } else { () }",
                vec![
                    DiagCode::E0211,
                    DiagCode::E0211,
                    DiagCode::E0211,
                    DiagCode::E0212,
                    DiagCode::E0212,
                    DiagCode::E0212,
                    DiagCode::E0212,
                ],
            ),
            (
                "match x { Some(v) => v, None => 0 }",
                vec![
                    DiagCode::E0212,
                    DiagCode::E0238,
                    DiagCode::E0211,
                    DiagCode::E0238,
                    DiagCode::E0211,
                    DiagCode::E0212,
                ],
            ),
            ("case x of", vec![DiagCode::E0231]),
            (
                "case x of\nSome(v) -> v\nNone -> 0\nend case\n()",
                vec![DiagCode::E0231],
            ),
            ("if x { () }", vec![DiagCode::E0212, DiagCode::E0212]),
            (
                "match x with\nwhen Some(v): v\nend match",
                vec![DiagCode::E0232],
            ),
            (
                "match x with\nSome(v) -> v\nend match",
                vec![DiagCode::E0238],
            ),
            ("match x with\nwhen -> ()\nend match", vec![DiagCode::E0238]),
            ("switch x", vec![DiagCode::E0239]),
            ("match x with\ndefault: 1\nend match", vec![DiagCode::E0239]),
            (
                "match x with\ncase _ -> ()\nbreak\nend match",
                vec![DiagCode::E0240],
            ),
            ("lambda x: x + 1", vec![DiagCode::E0243]),
            (
                "lambda(x): Integer return x end lambda",
                vec![DiagCode::E0234],
            ),
            (
                "match x with\ncase p => e\nend match",
                vec![DiagCode::E0211],
            ),
            ("bind match <- 1", vec![DiagCode::E0216]),
            ("lambda(_) () end lambda", vec![DiagCode::E0210]),
        ] {
            let src = body(source);
            let out = user(&src);
            assert_eq!(codes(&out), expected, "{source}: {:?}", out.diagnostics);
            for diagnostic in &out.diagnostics {
                assert!(diagnostic.primary.is_some());
            }
        }
        for (source, expected) in [
            ("fn f(x: Int) -> Int { x + 1 }", vec![DiagCode::E0251]),
            ("type Shape\nCircle(Float)\nend type", vec![DiagCode::E0233]),
            ("data Tree\nLeaf()\nend data", vec![DiagCode::E0206]),
            (
                "function f(): Integer\nreturn 1\nend function",
                vec![DiagCode::E0234],
            ),
            (
                "function with() -> Unit\n()\nend function",
                vec![DiagCode::E0216],
            ),
            (
                "function f(data: Integer) -> Unit\n()\nend function",
                vec![DiagCode::E0216],
            ),
            (
                "function List.map() -> Unit\n()\nend function",
                vec![DiagCode::E0207],
            ),
        ] {
            let out = user(source);
            assert_eq!(codes(&out), expected, "{source}: {:?}", out.diagnostics);
        }
    }

    #[test]
    fn diagnostic_locations_and_source_based_suggestions() {
        for (source, code, primary, helps) in [
            (
                body("let Pair(a, b) = make(\"値\")"),
                DiagCode::E0230,
                "let",
                vec![
                    "bind Pair(a, b) <- make(\"値\")",
                    "shadow Pair(a, b) <- make(\"値\")",
                ],
            ),
            (
                body("case make(\"値\") of"),
                DiagCode::E0231,
                "case",
                vec!["match make(\"値\") with"],
            ),
            (
                body("match x with\nwhen Some(v): v\nend match"),
                DiagCode::E0232,
                "when",
                vec!["case Some(v) ->"],
            ),
            (
                body("match x with\nSome(v) -> v\nend match"),
                DiagCode::E0238,
                "Some(v)",
                vec!["case Some(v) ->"],
            ),
            (
                body("switch lookup(\"値\")"),
                DiagCode::E0239,
                "switch",
                vec!["match lookup(\"値\") with"],
            ),
            (
                body("match x with\ndefault: ()\nend match"),
                DiagCode::E0239,
                "default",
                vec!["case _ ->"],
            ),
            (
                body("lambda x, y: x + y"),
                DiagCode::E0243,
                "lambda x, y: x + y",
                vec!["lambda(x, y) return x + y end lambda"],
            ),
            (
                body("p.name"),
                DiagCode::E0203,
                ".name",
                vec!["pipe", "Person.name(p)"],
            ),
            (body("_ + 1"), DiagCode::E0204, "_", vec![]),
            (body("x?"), DiagCode::E0211, "?", vec!["try"]),
            (
                body("match x with\ncase p => e\nend match"),
                DiagCode::E0211,
                "=>",
                vec!["case pattern -> expression"],
            ),
            (
                body("bind match <- 1"),
                DiagCode::E0216,
                "match",
                vec!["another name"],
            ),
        ] {
            let out = user(&source);
            assert_eq!(codes(&out), [code], "{source}: {:?}", out.diagnostics);
            let d = &out.diagnostics[0];
            let start = position(&source, primary).unwrap();
            assert_eq!(
                d.primary.as_ref().unwrap().span,
                Span {
                    file: FileId(0),
                    start,
                    end: BytePos(start.0 + u32::try_from(primary.len()).unwrap())
                }
            );
            assert_eq!(d.helps.len(), helps.len());
            for (help, text) in d.helps.iter().zip(helps) {
                assert!(help.message.contains(text), "{help:?} lacks {text}");
                assert!(help.edits.is_empty());
            }
        }
        for pattern in [
            "-1",
            "'a'",
            "\"x\"",
            "true",
            "false",
            "()",
            "Tree.Leaf",
            "Tree.Leaf()",
        ] {
            let out = user(&body(&format!(
                "match x with\ncase {pattern} -> ()\nend match"
            )));
            assert!(
                out.diagnostics.is_empty(),
                "{pattern}: {:?}",
                out.diagnostics
            );
            let Expr::Match(m) = expr(&out) else {
                panic!();
            };
            if pattern == "-1" {
                assert!(matches!(&m.arms[0].patterns[0], Pattern::Lit(p) if p.negative));
            }
            if pattern == "Tree.Leaf()" {
                assert!(
                    matches!(&m.arms[0].patterns[0], Pattern::Ctor(p) if p.has_parens && p.args.is_empty())
                );
            }
        }
        for pattern in ["1.0", "1.0m", "-'a'"] {
            let out = user(&body(&format!(
                "match x with\ncase {pattern} -> ()\nend match"
            )));
            assert_eq!(
                codes(&out),
                [DiagCode::E0201],
                "{pattern}: {:?}",
                out.diagnostics
            );
        }
        for name in ["default", "when", "when(1)", "switch(1)"] {
            let out = user(&body(&format!("match x with\ncase _ -> {name}\nend match")));
            assert!(out.diagnostics.is_empty(), "{name}: {:?}", out.diagnostics);
        }
        for source in ["x + return 1", "not return true", "x |> try f()"] {
            assert_eq!(codes(&user(&body(source))), [DiagCode::E0201], "{source}");
        }
        for source in [
            "match x with\ncase _ -> end match",
            "match x with\ncase 1 -> () case _ -> ()\nend match",
        ] {
            assert_eq!(codes(&user(&body(source))), [DiagCode::E0201], "{source}");
        }
    }

    fn apply_edit(source: &str, edits: &[crate::diag::Edit]) -> String {
        let mut result = source.to_owned();
        let mut edits = edits.to_vec();
        edits.sort_by_key(|e| std::cmp::Reverse(e.span.start));
        for e in edits {
            result.replace_range(
                usize::try_from(e.span.start.0).unwrap()..usize::try_from(e.span.end.0).unwrap(),
                &e.replacement,
            );
        }
        result
    }
    #[test]
    fn fixes_have_exact_locations_and_resulting_text() {
        for (source, expected, primary) in [
            (body("a < b < c"), body("a < b and b < c"), "< c"),
            (
                body("match x\nwith\ncase _ -> 1\nend match"),
                body("match x with\ncase _ -> 1\nend match"),
                "with",
            ),
            (
                "data Tree\nLeaf()\nend data".to_owned(),
                "data Tree\nLeaf\nend data".to_owned(),
                "()",
            ),
            (
                "type Shape\nCircle(Float)\nend type".to_owned(),
                "data Shape\nCircle(Float)\nend data".to_owned(),
                "type Shape",
            ),
            (
                "function f(): Integer\nreturn 1\nend function".to_owned(),
                "function f()-> Integer\nreturn 1\nend function".to_owned(),
                ":",
            ),
            (
                body("lambda(_) () end lambda"),
                body("lambda(_unused) () end lambda"),
                "_",
            ),
            (body("a; b"), body("a\n b"), ";"),
            (body("a; // tail"), body("a // tail"), ";"),
            (body("a;\nb"), body("a\nb"), ";"),
            (body("!ok"), body("not ok"), "!"),
            (body("a == b"), body("a = b"), "=="),
            (body("a != b"), body("a <> b"), "!="),
            (body("a && b"), body("a and b"), "&&"),
            (body("a&&b"), body("a and b"), "&&"),
            (body("a || b"), body("a or b"), "||"),
            (body("a||b"), body("a or b"), "||"),
            (body("a % b"), body("a mod b"), "%"),
            (body("n%2"), body("n mod 2"), "%"),
            (
                "function List.map() -> Unit\n()\nend function".to_owned(),
                "function map() -> Unit\n()\nend function".to_owned(),
                "List.map",
            ),
            (
                body("match x with\ncase _ -> ()\nbreak\nend match"),
                body("match x with\ncase _ -> ()\n\nend match"),
                "break",
            ),
        ] {
            let out = user(&source);
            assert_eq!(out.diagnostics.len(), 1, "{source}: {:?}", out.diagnostics);
            let d = &out.diagnostics[0];
            assert_eq!(
                d.primary.as_ref().unwrap().span.start,
                position(&source, primary).unwrap()
            );
            let edits = d
                .helps
                .iter()
                .flat_map(|h| h.edits.clone())
                .collect::<Vec<_>>();
            assert!(!edits.is_empty(), "{source}");
            assert_eq!(apply_edit(&source, &edits), expected, "{source}");
            assert!(user(&expected).diagnostics.is_empty(), "{expected}");
        }
        let out = user(&body("a < b < c"));
        assert_eq!(shape(expr(&out)), "(Lt a b)");
        let out = user(&body("p.name"));
        assert_eq!(out.diagnostics[0].helps.len(), 2);
        assert!(out.diagnostics[0].helps.iter().all(|h| h.edits.is_empty()));
    }

    #[test]
    fn mismatched_and_missing_ends_identify_the_opening() {
        let source = body("if c then 1 end match");
        let out = user(&source);
        assert_eq!(codes(&out), [DiagCode::E0213]);
        let d = &out.diagnostics[0];
        assert_eq!(
            d.secondary[0].span.start,
            position(&source, "if c").unwrap()
        );
        assert_eq!(
            apply_edit(&source, &d.helps[0].edits),
            body("if c then 1 end if")
        );
        let source = "function f() -> Unit\nif c then 1\nend function";
        let out = user(source);
        assert_eq!(codes(&out), [DiagCode::E0214]);
        let out = user("function f() -> Unit\nlambda() ()");
        assert_eq!(codes(&out), [DiagCode::E0214]);
    }

    #[test]
    fn independent_errors_and_lexical_error_tokens() {
        let source = "function f() -> Unit\nbind a <- )\nbind b <- )\nbind c <- )\nend function\nfunction after() -> Unit\n()\nend function";
        let out = user(source);
        assert_eq!(codes(&out), [DiagCode::E0201; 3]);
        assert!(
            matches!(&out.module.decls.last().unwrap().item, Item::Fn(f) if f.name.text == "after")
        );
        let (out, lex) = parse_source(
            "function f() -> Unit\n\"open\nend function",
            SourceKind::User,
        );
        assert!(!lex.is_empty());
        assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
        let out = user("function f() -> Unit\n@ # ^\nend function");
        for symbol in ["#", "^"] {
            assert_eq!(
                out.diagnostics
                    .iter()
                    .filter(|d| d.primary.as_ref().is_some_and(|l| l.span.start
                        == position("function f() -> Unit\n@ # ^\nend function", symbol).unwrap()))
                    .count(),
                1
            );
        }
    }

    #[test]
    fn builtin_body_rule_is_ready_for_f03() {
        let source = "function native() -> Unit\n";
        // F02 の作業文書が、仮の body_rule を通さず、この形で確かめるよう個別に指定する。
        let lexed = crate::syntax::lexer::lex(FileId(0), source.as_bytes());
        let mut p = Parser::new(
            FileId(0),
            SourceKind::Prelude,
            source.as_bytes(),
            crate::syntax::newline::resolve_newlines(lexed.tokens),
            &[],
            IdGen::new(),
        );
        let f = decls::parse_function(&mut p, 1, items::BodyRule::Omitted, &[]).unwrap();
        assert!(f.body.is_none());
        assert!(p.diagnostics.is_empty());
    }

    #[test]
    fn nesting_and_sequence_limits_use_the_default_test_thread_stack() {
        let wrap = |src: String| body(&src);
        let cases: Vec<(&str, String, String)> = vec![
            (
                "parentheses",
                wrap(format!("{}x{}", "(".repeat(997), ")".repeat(997))),
                wrap(format!("{}x{}", "(".repeat(998), ")".repeat(998))),
            ),
            (
                "if",
                wrap(format!(
                    "{}x{}",
                    "if c then ".repeat(498),
                    " end if".repeat(498)
                )),
                wrap(format!(
                    "{}x{}",
                    "if c then ".repeat(1001),
                    " end if".repeat(1001)
                )),
            ),
            (
                "lambda",
                wrap(format!(
                    "{}(){}",
                    "lambda() ".repeat(498),
                    " end lambda".repeat(498)
                )),
                wrap(format!(
                    "{}(){}",
                    "lambda() ".repeat(1001),
                    " end lambda".repeat(1001)
                )),
            ),
            (
                "statements",
                wrap(vec!["()"; 998].join("\n")),
                wrap(vec!["()"; 1001].join("\n")),
            ),
            (
                "list elements",
                wrap(format!("[{}]", vec!["1"; 997].join(","))),
                wrap(format!("[{}]", vec!["1"; 1001].join(","))),
            ),
            (
                "operator chain",
                wrap(format!("x{}", " + x".repeat(997))),
                wrap(format!("x{}", " + x".repeat(998))),
            ),
            (
                "nested patterns",
                wrap(format!(
                    "match x with\ncase {}_{} -> ()\nend match",
                    "C(".repeat(996),
                    ")".repeat(996)
                )),
                wrap(format!(
                    "match x with\ncase {}_{} -> ()\nend match",
                    "C(".repeat(997),
                    ")".repeat(997)
                )),
            ),
            (
                "nested lists",
                wrap(format!("{}x{}", "[".repeat(997), "]".repeat(997))),
                wrap(format!("{}x{}", "[".repeat(998), "]".repeat(998))),
            ),
            (
                "unary",
                wrap(format!("{}x", "not ".repeat(997))),
                wrap(format!("{}x", "not ".repeat(998))),
            ),
            (
                "call chain",
                wrap(format!("f{}", "()".repeat(997))),
                wrap(format!("f{}", "()".repeat(998))),
            ),
            (
                "pattern nodes",
                wrap(format!(
                    "match x with\ncase C({}) -> ()\nend match",
                    vec!["_"; 996].join(",")
                )),
                wrap(format!(
                    "match x with\ncase C({}) -> ()\nend match",
                    vec!["_"; 997].join(",")
                )),
            ),
            (
                "parenthesized types",
                format!(
                    "function f(x: {}Integer{}) -> Unit\n()\nend function",
                    "(".repeat(997),
                    ")".repeat(997)
                ),
                format!(
                    "function f(x: {}Integer{}) -> Unit\n()\nend function",
                    "(".repeat(998),
                    ")".repeat(998)
                ),
            ),
            (
                "named types",
                format!(
                    "function f(x: {}Integer{}) -> Unit\n()\nend function",
                    "List[".repeat(997),
                    "]".repeat(997)
                ),
                format!(
                    "function f(x: {}Integer{}) -> Unit\n()\nend function",
                    "List[".repeat(998),
                    "]".repeat(998)
                ),
            ),
            (
                "function types",
                format!(
                    "function f(x: {}Integer) -> Unit\n()\nend function",
                    "function() -> ".repeat(997)
                ),
                format!(
                    "function f(x: {}Integer) -> Unit\n()\nend function",
                    "function() -> ".repeat(998)
                ),
            ),
            (
                "call arguments",
                wrap(format!("f({})", vec!["1"; 997].join(","))),
                wrap(format!("f({})", vec!["1"; 998].join(","))),
            ),
            (
                "patterns across arms",
                wrap(format!(
                    "match x with\n{}\nend match",
                    vec!["case C(_, _, _) -> ()"; 249].join("\n")
                )),
                wrap(format!(
                    "match x with\n{}\nend match",
                    vec!["case C(_, _, _) -> ()"; 250].join("\n")
                )),
            ),
        ];
        for (name, inside, outside) in cases {
            eprintln!("depth case: {name}");
            let out = user(&inside);
            assert!(out.diagnostics.is_empty(), "{name}: {:?}", out.diagnostics);
            let out = user(&outside);
            assert_eq!(
                codes(&out),
                [DiagCode::E0208],
                "{name}: {:?}",
                out.diagnostics
            );
        }
    }
}
