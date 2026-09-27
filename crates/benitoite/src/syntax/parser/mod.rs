//! 構文解析（設計書 02-03「構文解析の方式」「誤りからの回復」「入れ子の深さ」「構文解析の結果」）。
//!
//! 改行の判定を終えた字句の列（NEWLINE を含み、`LineBreak` を含まない）から AST を作る。
//! 手書きの再帰下降で、01-02「文法」の規則ごとに関数を一つ書く（ADR 0020）。
//!
//! このファイルは、すべての解析の関数が共有する基盤を持つ。
//! - 字句の読み進め（`Parser::peek`・`bump`・`expect`）
//! - 構文エラーの報告と、一つの誤りから派生した報告の抑制（`Parser::unexpected`・`report`）
//! - 誤りからの回復（`Parser::recover`）
//! - 入れ子の深さの数え上げと打ち切り（`Parser::enter`）
//!
//! 規則ごとの解析は子のモジュールに分ける: `decl`（プログラムと宣言）、`types`（型と `uses`）、
//! `pattern`（パターン）、`stmt`（ブロックと文）、`expr`（式）。
//!
//! 解析の関数の約束:
//! - 引数 `depth` は、その関数が作るノードの深さである（プログラムが 0）。
//! - 構文エラーを報告して回復していないときは `Err(Fail)` を返す。並びを持つ解析の関数が
//!   受け取って回復し、並びに誤りのノードを置く。
//!
//! スタックの使い方: 入れ子の深さを上限（1000）まで許すので、再帰の一段で使うスタックを小さく保つ
//! （実装プラン 00-02「再帰の深さ」。1000 段の入れ子を、テストのスレッドの既定のスタックの大きさで
//! 解析できなければならない）。最適化しないビルドでは、関数の中の一時の値がそれぞれ別の場所を占め、
//! 再帰の間ずっと残る。そこで次のように書く。
//! - 並びの要素は、要素の解析の関数が並びに直接加える（`comma_list`・`line_list`）。大きな要素の値を
//!   並びの関数の枠に置かないためである。
//! - 再帰の経路にある関数は、大きなノードを組み立てる処理を別の関数に分け、その結果をそのまま返す。

mod decl;
mod expr;
mod pattern;
mod stmt;
mod text;
mod types;

use super::ast::{ErrorNode, Literal, Name, Program};
use super::token::{Comment, Token, TokenKind, TokenValue};
use crate::base::{BytePos, FileId, IdGen, NodeId, SourceKind, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};

/// 構文解析器が作る AST の深さの上限（02-03「入れ子の深さ」）。
pub const MAX_DEPTH: u32 = 1000;

/// 構文解析の結果（02-03「構文解析の結果」）。
#[derive(Debug)]
pub struct ParseOutput {
    pub program: Program,
    pub comments: Vec<Comment>,
    /// 字句の切り出しの誤りと構文解析の誤り。呼び出し側（10-09 の `parse_source`）が字句の誤りを先に並べる
    pub diagnostics: Vec<Diagnostic>,
}

/// NEWLINE を含む字句の列（`resolve_newlines` の出力）から AST を作る。
/// `kind` が `SourceKind::Prelude` のときだけ、修飾した関数の宣言を受け付ける。
/// ノード番号は `ids` から振る。`comments` は字句の切り出しの結果をそのまま受け取り、結果に入れる。
pub fn parse(
    file: FileId,
    kind: SourceKind,
    tokens: Vec<Token>,
    comments: Vec<Comment>,
    ids: &mut IdGen,
) -> ParseOutput {
    // 数え上げの状態は検査ごとに一つで、prelude と利用者のソースで共有する（02-03「AST」）。
    // 解析の間だけ `Parser` に預け、終わったら呼び出し側へ戻す。
    let mut parser = Parser::new(file, kind, tokens, std::mem::take(ids));
    let program = decl::parse_program(&mut parser);
    *ids = parser.ids;
    ParseOutput {
        program,
        comments,
        diagnostics: parser.diagnostics,
    }
}

/// 解析の関数が失敗したことを表す印。
///
/// 構文エラーを報告した（または報告を抑制した）後、まだ回復していない状態で呼び出し元へ戻ることを表す。
/// 並びを持つ解析の関数（トップレベルの宣言、ブロックの文、型の宣言の構成子、括弧の中の要素）が
/// これを受け取り、`Parser::recover` で読み飛ばして誤りのノードを置く（02-03「誤りからの回復」）。
/// 打ち切り（`Parser::aborted`）のときも、この印で呼び出し元へ戻る。
#[derive(Debug)]
struct Fail;

type PResult<T> = Result<T, Fail>;

/// 構文解析の途中の状態。検査ごとに作り、大域の状態を持たない（ADR 0015）。
#[derive(Debug)]
struct Parser {
    file: FileId,
    kind: SourceKind,
    tokens: Vec<Token>,
    /// 次に読む字句の位置。`Eof` の位置で止まる
    pos: usize,
    /// `Eof` より後を読もうとしたときに返す字句
    eof: Token,
    ids: IdGen,
    diagnostics: Vec<Diagnostic>,
    /// 報告を抑制中の印。構文エラーを報告したら立て、期待どおりの字句を読み進めたら下ろす
    /// （02-03「誤りからの回復」の最後の方針）
    suppressed: bool,
    /// 解析を打ち切った印。入れ子の深さが上限を超えたときに立てる（02-03「入れ子の深さ」）
    aborted: bool,
    /// `enter` に渡した深さの最大値。式の解析が、繰り返しで読む演算子と呼び出しの連なりの深さを
    /// 求めるのに使う（`expr` の「入れ子の深さ」）。値を読む側が 0 に戻してから測る
    deepest: u32,
}

impl Parser {
    fn new(file: FileId, kind: SourceKind, mut tokens: Vec<Token>, ids: IdGen) -> Parser {
        // 入力は必ず `Eof` で終わる（10-03 の `LexOutput`）。手で組んだ列にも備え、欠けていれば補う。
        let end = tokens.last().map_or(BytePos(0), |t| t.span.end);
        let eof = match tokens.last() {
            Some(last) if last.kind == TokenKind::Eof => last.clone(),
            Some(_) | None => {
                let eof = Token {
                    kind: TokenKind::Eof,
                    span: Span {
                        file,
                        start: end,
                        end,
                    },
                    value: TokenValue::None,
                };
                tokens.push(eof.clone());
                eof
            }
        };
        Parser {
            file,
            kind,
            tokens,
            pos: 0,
            eof,
            ids,
            diagnostics: Vec::new(),
            suppressed: false,
            aborted: false,
            deepest: 0,
        }
    }

    // ---------------- 字句の読み進め ----------------

    fn peek(&self) -> &Token {
        self.tokens.get(self.pos).unwrap_or(&self.eof)
    }

    fn peek_kind(&self) -> TokenKind {
        self.peek().kind
    }

    /// 今の位置から `n` 個先の字句の種類。`Eof` の後は `Eof` を返し続ける。
    fn peek_nth_kind(&self, n: usize) -> TokenKind {
        self.pos
            .checked_add(n)
            .and_then(|i| self.tokens.get(i))
            .map_or(TokenKind::Eof, |t| t.kind)
    }

    fn at(&self, kind: TokenKind) -> bool {
        self.peek_kind() == kind
    }

    /// 字句を一つ読み進める。`Eof` では位置を動かさない。報告の抑制の印は変えない。
    fn advance(&mut self) -> Token {
        let token = self.peek().clone();
        if token.kind != TokenKind::Eof {
            self.pos = self.pos.saturating_add(1);
        }
        token
    }

    /// 期待どおりの字句として一つ読み進める。報告の抑制を解く（02-03「誤りからの回復」）。
    fn bump(&mut self) -> Token {
        self.suppressed = false;
        self.advance()
    }

    /// 次の字句が `kind` なら読み進める。そうでなければ構文エラーを報告して失敗する。
    fn expect(&mut self, kind: TokenKind) -> PResult<Token> {
        if self.aborted {
            return Err(Fail);
        }
        if self.at(kind) {
            Ok(self.bump())
        } else {
            Err(self.unexpected(describe_kind(kind)))
        }
    }

    /// 次の字句が `kind` なら読み進めて true を返す。
    fn eat(&mut self, kind: TokenKind) -> bool {
        if !self.aborted && self.at(kind) {
            self.bump();
            true
        } else {
            false
        }
    }

    /// 識別子（`LowerIdent` か `UpperIdent`）を名前として読む。`expected` は期待する構文の呼び名。
    fn expect_name(&mut self, kind: TokenKind, expected: &str) -> PResult<Name> {
        if self.aborted {
            return Err(Fail);
        }
        if !self.at(kind) {
            return Err(self.unexpected(expected));
        }
        let token = self.bump();
        Ok(name_of(&token))
    }

    // ---------------- 位置とノード番号 ----------------

    fn node_id(&mut self) -> NodeId {
        self.ids.node()
    }

    /// 字句の位置 `start` から、最後に読んだ字句の終わりまでの span（02-02「span」）。
    /// 一つも読んでいなければ、今の字句の開始に長さ 0 の span を置く。
    fn span_from(&self, start: usize) -> Span {
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
    fn empty_span(&self) -> Span {
        let at = self.peek().span.start;
        Span {
            file: self.file,
            start: at,
            end: at,
        }
    }

    /// 字句の位置 `start` から今までに読んだ（読み飛ばした）範囲を覆う誤りのノード。
    fn error_node_from(&mut self, start: usize) -> ErrorNode {
        let span = self.span_from(start);
        ErrorNode {
            id: self.node_id(),
            span,
        }
    }

    /// 誤りの字句を一つ読み、その位置の誤りのノードにする。構文エラーは報告しない。
    /// 誤りの字句は字句の切り出しが既に報告している（02-03「字句」の最後の段落）。
    /// 期待どおりの字句ではないので、報告の抑制は解かない。
    fn error_token_node(&mut self) -> ErrorNode {
        let start = self.pos;
        self.advance();
        self.error_node_from(start)
    }

    // ---------------- 報告 ----------------

    /// 構文エラーを一つ報告する。抑制中と打ち切りの後は捨てる。報告したら抑制の印を立てる。
    fn report(&mut self, diagnostic: Diagnostic) {
        if self.aborted || self.suppressed {
            return;
        }
        self.diagnostics.push(diagnostic);
        self.suppressed = true;
    }

    /// 今の字句が期待に合わないことを E0201 で報告し、失敗の印を返す。
    /// 今の字句が誤りの字句なら報告せず、抑制の印だけを立てる（02-03「字句」の最後の段落）。
    fn unexpected(&mut self, expected: &str) -> Fail {
        let token = self.peek();
        if token.kind == TokenKind::Error {
            self.suppressed = true;
            return Fail;
        }
        let diagnostic = DiagBuilder::new(DiagCode::E0201)
            .arg("expected", expected)
            .arg("found", describe_token(token))
            .primary(token.span)
            .build();
        self.report(diagnostic);
        Fail
    }

    // ---------------- 入れ子の深さ ----------------

    /// 深さ `depth` のノードを作り始める前に呼ぶ。上限を超えたら E0208 を報告して打ち切る
    /// （02-03「入れ子の深さ」）。打ち切った後は、字句を読まずに失敗する。
    /// 渡された深さの最大値を `deepest` に記録する（`expr` の「入れ子の深さ」）。
    fn enter(&mut self, depth: u32) -> PResult<()> {
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
    fn recover(&mut self, start: usize, stop: Recovery) {
        if self.aborted {
            return;
        }
        let mut nesting: u32 = 0;
        for token in self.tokens.get(start..self.pos).unwrap_or_default() {
            nesting = count_bracket(nesting, token.kind);
        }
        loop {
            let kind = self.peek_kind();
            if kind == TokenKind::Eof {
                return;
            }
            if nesting == 0 && stop.stops_at(self) {
                return;
            }
            nesting = count_bracket(nesting, kind);
            self.advance();
        }
    }

    /// 今の字句が行の先頭（直前の字句が NEWLINE か、ファイルの先頭）にあるか。
    fn at_line_start(&self) -> bool {
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
fn push<T>(out: &mut Vec<T>, result: PResult<T>) -> PResult<()> {
    out.push(result?);
    Ok(())
}

/// 丸括弧・角括弧の中のコンマ区切りの並び（01-02 の `CommaList`）の読み方。
#[derive(Clone, Copy, Debug)]
struct CommaList {
    /// 並びを閉じる字句
    close: TokenKind,
    /// 要素の呼び名（空の並びを許さないときの E0201 の `{expected}`）
    element: &'static str,
    /// 要素の後に期待する字句の呼び名（`,` か閉じる字句）
    separator: &'static str,
    /// 空の並びを許すか（`FnTypeParams`・`TypeParams`・型引数は許さない）
    allow_empty: bool,
    /// 要素の深さを並びの位置で数えるか（02-03「入れ子の深さ」の「並びの要素」）。
    /// 偽なら、どの要素も親の深さに 1 を加えた深さにする
    indexed: bool,
}

/// 開き括弧を読んだ後から、閉じる字句までの並びを読む。閉じる字句も読む。
///
/// `depth` は並びを持つノードの深さである。要素の解析の関数 `elem` は、読んだ要素を第 3 引数の並びに
/// 加える（「スタックの使い方」）。要素の解析が失敗したら、同じ括弧の中の次の `,` か
/// 閉じる字句まで読み飛ばし（02-03「誤りからの回復」）、読み飛ばした範囲の誤りのノードを
/// `on_error` に渡す。`on_error` は、要素の型に誤りの変種があれば、それを並びに加える。
/// 閉じる字句に達しないまま並びが終わったら失敗し、外側の並びの回復に任せる。
fn comma_list<T>(
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
fn element_depth(depth: u32, indexed: bool, index: usize) -> u32 {
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
/// ないとき（`fn f(x: Int y: Int)`）は、E0201 を報告し、同じ括弧の中の次の `,` か閉じる字句まで
/// 読み飛ばして、読み飛ばした範囲を並びに置く（02-03「誤りからの回復」）。
/// 回復しても `,` にも閉じる字句にも着かなければ（外側の閉じ括弧か `Eof`）、失敗を返す。
fn comma_list_tail<T>(
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

/// `{` を読んだ後から、`}` までの改行区切りの並び（01-02 の `LineList`）を読む。`}` も読む。
///
/// ブロックの文、型の宣言の構成子、`match` の分岐（T12）が使う。`depth` は並びを持つノードの深さで、
/// `indexed` が真なら i 番目の要素を親の深さに `i + 1` を加えた深さで解析する（02-03「入れ子の深さ」）。
/// 要素の解析が失敗したときと、要素の後に NEWLINE でも `}` でもない字句が来たときは、
/// 同じ波括弧の中の次の NEWLINE か `}` まで読み飛ばし（02-03「誤りからの回復」）、
/// 読み飛ばした範囲の誤りのノードを `on_error` に渡す。`elem` と `on_error` は `comma_list` と同じく、
/// 要素を第 3 引数（`on_error` では第 1 引数）の並びに加える。
fn line_list<T>(
    p: &mut Parser,
    depth: u32,
    indexed: bool,
    mut elem: impl FnMut(&mut Parser, u32, &mut Vec<T>) -> PResult<()>,
    mut on_error: impl FnMut(&mut Vec<T>, ErrorNode),
) -> PResult<Vec<T>> {
    // `comma_list` と同じく、要素の解析の関数を呼ぶところ以外は補助の関数に分ける。
    let mut items = Vec::new();
    // 並びの位置。誤りの要素も数える
    let mut index: usize = 0;
    loop {
        match line_list_head(p) {
            ListStep::Element => {}
            ListStep::Done => return Ok(items),
            ListStep::Failed => return Err(Fail),
        }
        let start = p.pos;
        let failed = elem(p, element_depth(depth, indexed, index), &mut items).is_err();
        let added = line_list_tail(p, start, failed, &mut items, &mut on_error)?;
        index = index.saturating_add(added);
    }
}

/// 改行区切りの並びの、要素を読む前の処理。`}` なら読んで終える。
fn line_list_head(p: &mut Parser) -> ListStep {
    if p.aborted {
        return ListStep::Failed;
    }
    // 先頭・末尾・要素の間の NEWLINE（連続する NEWLINE は改行の判定が一つにまとめてある）
    while p.eat(TokenKind::Newline) {}
    if p.eat(TokenKind::RBrace) {
        return ListStep::Done;
    }
    if p.at(TokenKind::Eof) {
        let _: Fail = p.unexpected(describe_kind(TokenKind::RBrace));
        return ListStep::Failed;
    }
    ListStep::Element
}

/// 改行区切りの並びの、要素を読んだ後の処理。並びに置いた要素の数（位置の進み）を返す。
fn line_list_tail<T>(
    p: &mut Parser,
    start: usize,
    failed: bool,
    items: &mut Vec<T>,
    on_error: &mut impl FnMut(&mut Vec<T>, ErrorNode),
) -> PResult<usize> {
    if failed {
        if p.aborted {
            return Err(Fail);
        }
        p.recover(start, Recovery::Line);
        let node = p.error_node_from(start);
        on_error(items, node);
    }
    if matches!(
        p.peek_kind(),
        TokenKind::Newline | TokenKind::RBrace | TokenKind::Eof
    ) {
        return Ok(1);
    }
    // 要素の後の余分な字句（`{ let x = 1 2 }` の `2`）。報告して、読み飛ばした範囲を並びに置く。
    let _: Fail = p.unexpected(text::NEWLINE_OR_RBRACE);
    let start = p.pos;
    p.recover(start, Recovery::Line);
    let node = p.error_node_from(start);
    on_error(items, node);
    Ok(2)
}

/// 回復で読み飛ばす先（02-03「誤りからの回復」の表）。
/// 止まる字句は、読み飛ばし始めた位置と同じ括弧の入れ子の中でだけ調べる。
#[derive(Clone, Copy, Debug)]
enum Recovery {
    /// トップレベルの宣言: 括弧の外にある、行の先頭の `fn` または `type`
    TopLevel,
    /// ブロックの中の文、`match` の分岐、型の宣言の構成子: 次の NEWLINE か、波括弧を閉じる `}`
    Line,
    /// 丸括弧・角括弧の中の要素: 次の `,` か、括弧を閉じる字句
    Comma,
}

impl Recovery {
    fn stops_at(self, p: &Parser) -> bool {
        let kind = p.peek_kind();
        match self {
            Recovery::TopLevel => {
                matches!(kind, TokenKind::KwFn | TokenKind::KwType) && p.at_line_start()
            }
            Recovery::Line => matches!(kind, TokenKind::Newline | TokenKind::RBrace),
            // 括弧の中では、どの閉じ括弧でも止まる。種類の合わない閉じ括弧は外側の構文のものとみて、
            // 読み飛ばさずに外側の解析に任せる。
            Recovery::Comma => kind == TokenKind::Comma || is_close(kind),
        }
    }
}

/// 開いている括弧の数を、字句 `kind` を読んだ後の数に改める。
/// 開いていない閉じ括弧（対応のない閉じ括弧）は数えない。
fn count_bracket(nesting: u32, kind: TokenKind) -> u32 {
    if is_open(kind) {
        nesting.saturating_add(1)
    } else if is_close(kind) {
        nesting.saturating_sub(1)
    } else {
        nesting
    }
}

fn is_open(kind: TokenKind) -> bool {
    matches!(
        kind,
        TokenKind::LParen | TokenKind::LBracket | TokenKind::LBrace
    )
}

fn is_close(kind: TokenKind) -> bool {
    matches!(
        kind,
        TokenKind::RParen | TokenKind::RBracket | TokenKind::RBrace
    )
}

/// 親のノードの深さに 1 を加えた深さ（子のノードの深さ）。
/// 溢れたら上限を超えたものとして扱う（02-03「入れ子の深さ」）。
fn child(depth: u32) -> u32 {
    let Some(deeper) = depth.checked_add(1) else {
        // 溢れた深さは上限（`MAX_DEPTH`）を超える値にする。
        return u32::MAX;
    };
    deeper
}

/// 並びの `index` 番目（0 から数える）の要素の深さ。親の深さに `index + 1` を加える
/// （02-03「入れ子の深さ」の、ブロックの文と並びの要素の数え方）。
fn nth_child(depth: u32, index: usize) -> u32 {
    u32::try_from(index)
        .ok()
        .and_then(|i| i.checked_add(1))
        .and_then(|n| depth.checked_add(n))
        .unwrap_or(u32::MAX)
}

/// 識別子の字句から名前を作る。
fn name_of(token: &Token) -> Name {
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
fn literal_of(token: &Token) -> Option<Literal> {
    match (token.kind, &token.value) {
        (TokenKind::IntLit, TokenValue::Int { radix, digits }) => Some(Literal::Int {
            radix: *radix,
            digits: digits.clone(),
        }),
        (TokenKind::FloatLit, TokenValue::Float(text)) => Some(Literal::Float(text.clone())),
        (TokenKind::StringLit, TokenValue::Str(text)) => Some(Literal::Str(text.clone())),
        (TokenKind::CharLit, TokenValue::Char(c)) => Some(Literal::Char(*c)),
        (TokenKind::KwTrue, _) => Some(Literal::Bool(true)),
        (TokenKind::KwFalse, _) => Some(Literal::Bool(false)),
        _ => None,
    }
}

/// 字句の種類の呼び名（E0201 の `{expected}` に使う。期待する字句が一つに決まるとき）。
fn describe_kind(kind: TokenKind) -> &'static str {
    if matches!(kind, TokenKind::LowerIdent | TokenKind::UpperIdent) {
        return text::NAME;
    }
    text::TOKEN_SPELLINGS
        .iter()
        .find(|(k, _)| *k == kind)
        .map_or(text::NAME, |(_, s)| *s)
}

/// 見つけた字句の呼び名（E0201 の `{found}` に使う）。語句は `text` の表から引く。
fn describe_token(token: &Token) -> String {
    if matches!(token.kind, TokenKind::LowerIdent | TokenKind::UpperIdent)
        && let TokenValue::Ident(name) = &token.value
    {
        return format!("{} `{}`", text::IDENTIFIER, name);
    }
    text::TOKEN_SPELLINGS
        .iter()
        .find(|(k, _)| *k == token.kind)
        .map_or(text::IDENTIFIER, |(_, s)| *s)
        .to_string()
}

#[cfg(test)]
// テストの失敗は panic で表す（07-03）。
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::diag::DiagCode;
    use crate::syntax::ast::{
        CtorPat, Expr, FnDecl, Item, LetName, LitPat, Literal, Pattern, Stmt, TypeDecl, TypeExpr,
    };
    use crate::syntax::lexer::lex;
    use crate::syntax::newline::resolve_newlines;

    const FILE: FileId = FileId(0);

    /// 字句の切り出しと改行の判定を通してから構文解析する。字句の診断も返す。
    fn parse_as(src: &str, kind: SourceKind) -> (ParseOutput, Vec<Diagnostic>) {
        let lexed = lex(FILE, src.as_bytes());
        let tokens = resolve_newlines(lexed.tokens);
        let out = parse(FILE, kind, tokens, lexed.comments, &mut IdGen::new());
        (out, lexed.diagnostics)
    }

    pub(super) fn parse_user(src: &str) -> ParseOutput {
        parse_as(src, SourceKind::User).0
    }

    pub(super) fn codes(out: &ParseOutput) -> Vec<DiagCode> {
        out.diagnostics.iter().filter_map(|d| d.code).collect()
    }

    pub(super) fn only_fn(out: &ParseOutput) -> &FnDecl {
        match out.program.items.as_slice() {
            [Item::Fn(decl)] => decl,
            other => panic!("expected one function declaration, got {other:?}"),
        }
    }

    fn only_type(out: &ParseOutput) -> &TypeDecl {
        match out.program.items.as_slice() {
            [Item::Type(decl)] => decl,
            other => panic!("expected one type declaration, got {other:?}"),
        }
    }

    /// `src` の中の `needle` の最初の出現のバイトの位置。
    pub(super) fn offset(src: &str, needle: &str) -> u32 {
        u32::try_from(src.find(needle).expect("needle")).unwrap()
    }

    pub(super) fn primary_start(out: &ParseOutput, index: usize) -> u32 {
        out.diagnostics[index]
            .primary
            .as_ref()
            .unwrap()
            .span
            .start
            .0
    }

    fn effect_names(uses: &Option<crate::syntax::ast::UsesList>) -> Vec<&str> {
        uses.as_ref()
            .map(|u| u.effects.iter().map(|e| e.name.text.as_str()).collect())
            .unwrap_or_default()
    }

    fn fn_type(ty: &TypeExpr) -> &crate::syntax::ast::FnType {
        let TypeExpr::Fn(f) = ty else {
            panic!("expected a function type, got {ty:?}");
        };
        f
    }

    #[test]
    fn function_declaration_with_type_params_params_and_uses() {
        let out =
            parse_user("fn f[T, effect E](x: Int, g: fn(T) -> Unit uses E) -> Unit uses E { () }");
        assert_eq!(codes(&out), vec![]);
        let decl = only_fn(&out);
        assert_eq!(decl.name.text, "f");
        assert_eq!(decl.module, None);
        let params: Vec<(&str, bool)> = decl
            .type_params
            .iter()
            .map(|t| (t.name.text.as_str(), t.is_effect))
            .collect();
        assert_eq!(params, vec![("T", false), ("E", true)]);
        assert_eq!(decl.params.len(), 2);
        let g = fn_type(decl.params[1].ty.as_ref().unwrap());
        assert_eq!(effect_names(&g.uses), vec!["E"]);
        assert_eq!(effect_names(&decl.uses), vec!["E"]);
        assert!(matches!(
            decl.body.stmts.as_slice(),
            [Stmt::Expr(Expr::Unit(_))]
        ));
    }

    #[test]
    fn uses_binds_to_innermost_function_type() {
        // 戻り値の型が関数の型なら、`uses` はその型に付き、関数の宣言は `uses` を持たない（ADR 0047）。
        let out = parse_user("fn f() -> fn() -> Int uses IO { 1 }");
        assert_eq!(codes(&out), vec![]);
        let decl = only_fn(&out);
        assert_eq!(effect_names(&fn_type(&decl.ret).uses), vec!["IO"]);
        assert_eq!(decl.uses, None);

        // 括弧で囲めば、後の `uses` は関数の宣言に付く。
        let out = parse_user("fn f() -> (fn() -> Int uses IO) uses IO { 1 }");
        assert_eq!(codes(&out), vec![]);
        let decl = only_fn(&out);
        let TypeExpr::Paren(paren) = &decl.ret else {
            panic!("expected a parenthesized type, got {:?}", decl.ret);
        };
        assert_eq!(effect_names(&fn_type(&paren.inner).uses), vec!["IO"]);
        assert_eq!(effect_names(&decl.uses), vec!["IO"]);
    }

    #[test]
    fn uses_list_is_read_as_long_as_possible() {
        // `E` は内側の関数の型の `uses` に入り、外側の関数の型の引数は 1 個になる。
        // エフェクトでない名前の誤りは名前解決が報告する（02-03「型の解析」）。
        let out = parse_user("fn f(g: fn(fn() -> Unit uses IO, E) -> Unit) -> Unit { () }");
        assert_eq!(codes(&out), vec![]);
        let outer = fn_type(only_fn(&out).params[0].ty.as_ref().unwrap());
        assert_eq!(outer.params.len(), 1);
        assert_eq!(
            effect_names(&fn_type(&outer.params[0]).uses),
            vec!["IO", "E"]
        );
    }

    #[test]
    fn type_arguments_after_later_uses_name_are_reported() {
        let src = "fn f(g: fn(fn() -> Unit uses IO, List[Int]) -> Unit) -> Unit { () }";
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![DiagCode::E0209]);
        assert_eq!(primary_start(&out, 0), offset(src, "List"));
        assert!(!out.diagnostics[0].helps.is_empty());
        // 回復して、関数の宣言の解析を続ける。
        assert_eq!(only_fn(&out).name.text, "f");
    }

    #[test]
    fn type_declaration() {
        let out = parse_user("type Tree[T] {\n  Leaf\n  Node(Tree[T], T, Tree[T])\n}\n");
        assert_eq!(codes(&out), vec![]);
        let decl = only_type(&out);
        assert_eq!(decl.name.text, "Tree");
        assert_eq!(decl.type_params.len(), 1);
        let variants: Vec<(&str, usize)> = decl
            .variants
            .iter()
            .map(|v| (v.name.text.as_str(), v.fields.len()))
            .collect();
        assert_eq!(variants, vec![("Leaf", 0), ("Node", 3)]);
        let TypeExpr::Named(first) = &decl.variants[1].fields[0] else {
            panic!("expected a named type");
        };
        assert_eq!((first.name.text.as_str(), first.args.len()), ("Tree", 1));
    }

    #[test]
    fn constructor_with_empty_parentheses() {
        let src = "type Tree {\n  Leaf()\n  Node(Tree)\n}";
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![DiagCode::E0206]);
        assert_eq!(primary_start(&out, 0), offset(src, "()"));
        let decl = only_type(&out);
        assert_eq!(decl.variants.len(), 2);
        assert!(decl.variants[0].fields.is_empty());
    }

    #[test]
    fn effect_in_type_declaration_parameters() {
        let src = "type T[effect E] { A }";
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![DiagCode::E0201]);
        assert_eq!(primary_start(&out, 0), offset(src, "effect"));
        assert_eq!(
            out.diagnostics[0].message,
            "expected a type parameter, found `effect`"
        );
        assert_eq!(only_type(&out).variants.len(), 1);
    }

    #[test]
    fn qualified_function_name_is_accepted_only_in_prelude() {
        let src = "fn List.map[T](xs: List[T]) -> List[T] { xs }";

        let (out, _) = parse_as(src, SourceKind::User);
        assert_eq!(codes(&out), vec![DiagCode::E0207]);
        assert_eq!(primary_start(&out, 0), offset(src, "List.map"));
        assert!(!out.diagnostics[0].helps.is_empty());

        let (out, _) = parse_as(src, SourceKind::Prelude);
        assert_eq!(codes(&out), vec![]);
        let decl = only_fn(&out);
        assert_eq!(decl.module.as_ref().map(|m| m.text.as_str()), Some("List"));
        assert_eq!(decl.name.text, "map");
    }

    #[test]
    fn brace_on_next_line_is_reported_at_the_brace() {
        // 01-01「改行による区切り」の例。
        let src = "fn double(x: Int) -> Int\n{\n  x\n}\n";
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![DiagCode::E0205]);
        assert_eq!(primary_start(&out, 0), offset(src, "{"));
        assert!(!out.diagnostics[0].helps.is_empty());
        let decl = only_fn(&out);
        assert!(matches!(
            decl.body.stmts.as_slice(),
            [Stmt::Expr(Expr::Name(_))]
        ));
    }

    /// `src` を `match` の 1 個目の分岐のパターンとして解析する。分岐を読めなかったら（パターンの誤り）
    /// パターンは `None` になる。`match` の深さは 3（プログラム 0、関数の宣言 1、本体 2、本体の 0 番目の文 3）。
    fn parse_pattern_src(src: &str) -> (Option<Pattern>, Vec<Diagnostic>) {
        let out = parse_user(&format!(
            "fn f() -> Unit {{\n  match x {{\n    {src} => ()\n  }}\n}}"
        ));
        let pattern = match out.program.items.as_slice() {
            [Item::Fn(decl)] => match decl.body.stmts.as_slice() {
                [Stmt::Expr(Expr::Match(m))] => m.arms.first().map(|arm| arm.pattern.clone()),
                other => panic!("pattern {src:?}: {other:?}"),
            },
            // 入れ子の深さの上限を超えて打ち切ったとき
            _ => None,
        };
        (pattern, out.diagnostics)
    }

    fn lit_pattern(src: &str) -> LitPat {
        match parse_pattern_src(src) {
            (Some(Pattern::Lit(lit)), diags) if diags.is_empty() => lit,
            other => panic!("pattern {src:?}: {other:?}"),
        }
    }

    fn ctor_pattern(src: &str) -> CtorPat {
        match parse_pattern_src(src) {
            (Some(Pattern::Ctor(ctor)), diags) if diags.is_empty() => ctor,
            other => panic!("pattern {src:?}: {other:?}"),
        }
    }

    #[test]
    fn literal_patterns() {
        let int = |digits: &str| Literal::Int {
            radix: 10,
            digits: digits.to_string(),
        };
        let cases = [
            ("-1", (true, int("1"))),
            ("1", (false, int("1"))),
            ("\"a\"", (false, Literal::Str("a".to_string()))),
            ("'c'", (false, Literal::Char('c'))),
            ("true", (false, Literal::Bool(true))),
        ];
        for (src, expected) in cases {
            let lit = lit_pattern(src);
            assert_eq!((lit.negative, lit.lit), expected, "pattern {src:?}");
        }
        // 前置の `-` もパターンの span に含める。
        let lit = lit_pattern("-1");
        assert_eq!(lit.span.end.0 - lit.span.start.0, 2);
    }

    #[test]
    fn simple_patterns() {
        assert!(matches!(parse_pattern_src("_"), (Some(Pattern::Wildcard(_)), d) if d.is_empty()));
        assert!(matches!(parse_pattern_src("()"), (Some(Pattern::Unit(_)), d) if d.is_empty()));
        let (Some(Pattern::Var(var)), diags) = parse_pattern_src("x") else {
            panic!();
        };
        assert!(diags.is_empty());
        assert_eq!(var.name.text, "x");
    }

    #[test]
    fn constructor_patterns() {
        let node = ctor_pattern("Tree.Node(l, _, r)");
        assert_eq!(
            node.qualifier.as_ref().map(|q| q.text.as_str()),
            Some("Tree")
        );
        assert_eq!(node.name.text, "Node");
        assert!(node.has_parens);
        assert!(matches!(
            node.args.as_slice(),
            [Pattern::Var(_), Pattern::Wildcard(_), Pattern::Var(_)]
        ));

        let some = ctor_pattern("Some(x)");
        assert_eq!((some.qualifier, some.name.text.as_str()), (None, "Some"));
        assert_eq!(some.args.len(), 1);

        // 括弧を書いたが引数のない構成子。誤りは型検査器が報告する。
        let leaf = ctor_pattern("Tree.Leaf()");
        assert!(leaf.has_parens);
        assert!(leaf.args.is_empty());

        let none = ctor_pattern("None");
        assert!(!none.has_parens);
    }

    #[test]
    fn float_pattern_is_a_syntax_error() {
        let (pattern, diags) = parse_pattern_src("1.5");
        assert_eq!(pattern, None);
        let found: Vec<_> = diags.iter().map(|d| (d.code, d.message.as_str())).collect();
        assert_eq!(
            found,
            vec![(
                Some(DiagCode::E0201),
                "expected a pattern, found floating-point literal"
            )]
        );
    }

    /// `n` 段の `Some(...)` の中に `x` を置いたパターン。節は `n + 1` 個。
    fn nested_some(n: usize) -> String {
        format!("{}x{}", "Some(".repeat(n), ")".repeat(n))
    }

    #[test]
    fn pattern_nodes_are_counted_in_preorder() {
        // `match` の深さ 3 を基準に、節が 997 個なら最後の節の深さはちょうど上限（1000）である。
        // 996 段の入れ子を、テストのスレッドの既定のスタックで解析できることも確かめる。
        let (pattern, diags) = parse_pattern_src(&nested_some(996));
        assert!(pattern.is_some());
        assert_eq!(diags, vec![]);
        let (_, diags) = parse_pattern_src(&nested_some(997));
        let found: Vec<_> = diags.iter().filter_map(|d| d.code).collect();
        assert_eq!(found, vec![DiagCode::E0208]);

        // 入れ子が浅くても、節の総数で上限を超える（ADR 0086）。
        // 引数が 40 個で各引数が 30 段の入れ子の構成子のパターン（節は 1 + 40 * 30 = 1201 個）。
        let arg = format!("{}x{}", "A(".repeat(29), ")".repeat(29));
        let (_, diags) = parse_pattern_src(&format!("B({})", vec![arg; 40].join(", ")));
        let found: Vec<_> = diags.iter().filter_map(|d| d.code).collect();
        assert_eq!(found, vec![DiagCode::E0208]);
    }

    #[test]
    fn pattern_nodes_are_counted_across_arms() {
        // 一つの `match` のすべての分岐で節を通して数える（ADR 0086）。分岐が 100 個で、各分岐のパターンが
        // 10 個の節を持つと、節の総数が 1000 に達し、100 個目の分岐で上限を超える。
        let pattern = format!("{}x{}", "A(".repeat(9), ")".repeat(9));
        let arms = format!("    {pattern} => ()\n").repeat(100);
        let src =
            format!("fn f() -> Unit {{\n  match x {{\n{arms}  }}\n}}\nfn g() -> Unit {{ () }}");
        let out = parse_user(&src);
        assert_eq!(codes(&out), vec![DiagCode::E0208]);

        // 分岐が 99 個なら節は 990 個で、上限に収まる。
        let arms = format!("    {pattern} => ()\n").repeat(99);
        let out = parse_user(&format!("fn f() -> Unit {{\n  match x {{\n{arms}  }}\n}}"));
        assert_eq!(codes(&out), vec![]);
    }

    pub(super) fn body_stmts(out: &ParseOutput) -> &[Stmt] {
        &only_fn(out).body.stmts
    }

    #[test]
    fn let_statements() {
        let out = parse_user("fn f() -> Unit {\n  let x: Int = 1\n  let _ = f\n}");
        assert_eq!(codes(&out), vec![]);
        let [Stmt::Let(first), Stmt::Let(second)] = body_stmts(&out) else {
            panic!("{:?}", body_stmts(&out));
        };
        assert!(matches!(&first.name, LetName::Var(n) if n.text == "x"));
        assert!(matches!(first.ty, Some(TypeExpr::Named(_))));
        assert!(matches!(first.value, Expr::Lit(_)));
        assert!(matches!(second.name, LetName::Wildcard(_)));
        assert_eq!(second.ty, None);
    }

    #[test]
    fn extra_token_after_statement_reports_one_error() {
        let src = "fn f() -> Unit { let x = 1 2 }";
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![DiagCode::E0201]);
        assert_eq!(primary_start(&out, 0), offset(src, "2"));
        assert!(matches!(body_stmts(&out), [Stmt::Let(_), Stmt::Error(_)]));
    }

    #[test]
    fn element_error_in_parentheses_recovers_at_comma() {
        let out = parse_user("fn f(x: , y: Int) -> Unit { () }");
        assert_eq!(codes(&out), vec![DiagCode::E0201]);
        let names: Vec<&str> = only_fn(&out)
            .params
            .iter()
            .map(|p| p.name.text.as_str())
            .collect();
        assert_eq!(names, vec!["y"]);
    }

    #[test]
    fn missing_comma_recovers_inside_the_list() {
        // 要素の後にコンマがなければ、同じ括弧の中で回復し、宣言の解析を続ける。
        let src = "fn f(x: Int y: Int) -> Unit { () }\nfn g() -> Unit { () }";
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![DiagCode::E0201]);
        assert_eq!(primary_start(&out, 0), offset(src, "y"));
        let [Item::Fn(f), Item::Fn(g)] = out.program.items.as_slice() else {
            panic!("{:?}", out.program.items);
        };
        let names: Vec<&str> = f.params.iter().map(|p| p.name.text.as_str()).collect();
        assert_eq!(names, vec!["x"]);
        assert!(matches!(f.ret, TypeExpr::Named(_)));
        assert_eq!(g.name.text, "g");

        // 誤りの変種を持つ要素の並びには、読み飛ばした範囲を誤りのノードとして置く。
        let out = parse_user("type T { A(Int String, Bool) }");
        assert_eq!(codes(&out), vec![DiagCode::E0201]);
        assert!(matches!(
            only_type(&out).variants[0].fields.as_slice(),
            [TypeExpr::Named(_), TypeExpr::Error(_), TypeExpr::Named(_)]
        ));
    }

    #[test]
    fn recovery_counts_brackets_opened_by_the_failed_element() {
        // 括弧の型の中で失敗しても、その中のコンマと `)` を引数の並びの区切りと取り違えない。
        let src = "fn f(x: (Int, String), y: Int) -> Unit { () }\nfn g() -> Unit { () }";
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![DiagCode::E0201]);
        assert_eq!(primary_start(&out, 0), offset(src, ", String"));
        let [Item::Fn(f), Item::Fn(g)] = out.program.items.as_slice() else {
            panic!("{:?}", out.program.items);
        };
        let names: Vec<&str> = f.params.iter().map(|p| p.name.text.as_str()).collect();
        assert_eq!(names, vec!["y"]);
        assert_eq!(g.name.text, "g");
    }

    #[test]
    fn type_declaration_without_constructors_is_not_a_syntax_error() {
        // 構成子のない型の宣言の誤り（E0411）は型検査が報告する。
        let out = parse_user("type T {}");
        assert_eq!(codes(&out), vec![]);
        assert!(only_type(&out).variants.is_empty());
    }

    #[test]
    fn top_level_recovery_resumes_at_next_declaration() {
        let src = "fn f() -> { () }\nfn g() -> Unit { () }\n";
        let out = parse_user(src);
        assert_eq!(codes(&out), vec![DiagCode::E0201]);
        let [Item::Error(error), Item::Fn(g)] = out.program.items.as_slice() else {
            panic!("{:?}", out.program.items);
        };
        assert_eq!(error.span.start.0, 0);
        assert_eq!(g.name.text, "g");
        assert!(matches!(
            g.body.stmts.as_slice(),
            [Stmt::Expr(Expr::Unit(_))]
        ));
    }

    #[test]
    fn error_token_becomes_error_node_without_syntax_error() {
        // 予約語は字句の切り出しが報告し、誤りの字句として届く（02-03「字句」）。
        for src in [
            "fn f() -> Unit {\n  let return = 1\n}",
            "fn return() -> Unit { () }",
        ] {
            let (out, lex_diags) = parse_as(src, SourceKind::User);
            assert!(!lex_diags.is_empty(), "{src:?}");
            assert_eq!(codes(&out), vec![], "{src:?}");
            let has_error_node = match out.program.items.as_slice() {
                [Item::Error(_)] => true,
                [Item::Fn(decl)] => matches!(decl.body.stmts.as_slice(), [Stmt::Error(_)]),
                _ => false,
            };
            assert!(has_error_node, "{src:?}: {:?}", out.program.items);
        }
        // 式と型の位置では、その位置の誤りのノードになる。
        let (out, _) = parse_as(
            "fn f(x: while) -> Unit { let y = return }",
            SourceKind::User,
        );
        assert_eq!(codes(&out), vec![]);
        let decl = only_fn(&out);
        assert!(matches!(decl.params[0].ty, Some(TypeExpr::Error(_))));
        assert!(matches!(
            decl.body.stmts.as_slice(),
            [Stmt::Let(l)] if matches!(l.value, Expr::Error(_))
        ));
    }

    /// 本体の中に `inner` 段のブロックを入れ子にした関数。一番内側のブロックの深さは `2 + inner` である
    /// （プログラム 0、関数の宣言 1、本体 2、本体の 0 番目の文 3、…）。
    fn nested_blocks(inner: usize) -> String {
        format!(
            "fn f() -> Unit {}{}",
            "{".repeat(inner + 1),
            "}".repeat(inner + 1)
        )
    }

    #[test]
    fn nesting_up_to_the_limit_is_accepted() {
        let inner = usize::try_from(MAX_DEPTH).unwrap() - 2;
        let out = parse_user(&nested_blocks(inner));
        assert_eq!(codes(&out), vec![]);
        // 一番内側のブロックまで AST ができている。
        let mut block = &only_fn(&out).body;
        let mut depth = 2;
        while let [Stmt::Expr(Expr::Block(next))] = block.stmts.as_slice() {
            block = next;
            depth += 1;
        }
        assert_eq!(depth, MAX_DEPTH);
    }

    #[test]
    fn nesting_beyond_the_limit_stops_parsing() {
        let inner = usize::try_from(MAX_DEPTH).unwrap() - 1;
        let src = format!("fn g() -> Unit {{ () }}\n{}\n)", nested_blocks(inner));
        let out = parse_user(&src);
        // E0208 は一つだけで、打ち切った後の字句（最後の `)`）について診断を出さない。
        assert_eq!(codes(&out), vec![DiagCode::E0208]);
        assert_eq!(
            out.diagnostics[0].primary.as_ref().unwrap().text,
            "nesting limit of 1000 reached here"
        );
        // 打ち切る前に作った宣言は残る。
        assert!(matches!(out.program.items.first(), Some(Item::Fn(g)) if g.name.text == "g"));

        // ブロックの文は、i 番目を 1 段ずつ深く数える。
        let many = format!("fn f() -> Unit {{\n{}}}", "()\n".repeat(1001));
        assert_eq!(codes(&parse_user(&many)), vec![DiagCode::E0208]);
    }

    #[test]
    fn comments_are_passed_through() {
        let src = "// head\nfn f() -> Unit { () } // tail\n";
        let lexed = lex(FILE, src.as_bytes());
        let expected = lexed.comments.clone();
        let out = parse_user(src);
        assert_eq!(expected.len(), 2);
        assert_eq!(out.comments, expected);
        assert_eq!(codes(&out), vec![]);
    }

    #[test]
    fn statement_after_semicolon() {
        // `;` は字句の切り出しが E0106 を報告し、改行の印として渡す（T02）。
        let (out, lex_diags) =
            parse_as("fn f() -> Unit { let x = 1; let y = 2 }", SourceKind::User);
        assert_eq!(
            lex_diags.iter().filter_map(|d| d.code).collect::<Vec<_>>(),
            vec![DiagCode::E0106]
        );
        assert_eq!(codes(&out), vec![]);
        assert!(matches!(body_stmts(&out), [Stmt::Let(_), Stmt::Let(_)]));
    }
}
