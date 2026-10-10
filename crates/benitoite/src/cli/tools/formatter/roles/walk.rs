//! AST を辿って字句ごとの役割を決める（設計書 06-03「字下げ」「字句の間の空白」「空の行」「入力表現」）。
//!
//! 字句と AST のノードの対応は span で取る。ノードの span の始まりの位置にある字句をそのノードの最初の字句、
//! span の終わりより前で最後に始まる字句を最後の字句とする。開きの字句・区切りの字句・閉じの字句は、
//! 06-03「字下げ」の表の構文ごとに、AST のノードの種類ごとの関数で一か所にまとめて決める。
//! 括弧の閉じの字句は、AST から決めた開きの括弧から、字句の列の括弧の対応で求める。誤りのない AST だけを
//! 受け取る（10-17「役割の表」）ので、括弧は必ず対応する。

use super::{BlankBefore, RoleTable, TokenRole, TopKind, TopRange};
use crate::base::{BytePos, Span};
use crate::syntax::ast::{
    Arg, Attribute, Block, DataDecl, EffectDecl, ElseBranch, Expr, FnDecl, FnType, HandleExpr,
    IfExpr, ImplDecl, Item, LambdaExpr, ListElem, MatchExpr, MethodSig, Module, Name, OpSig, Param,
    Pattern, RecordDecl, RecordExpr, Stmt, TopDecl, TraitDecl, TypeExpr, TypeParamDecl,
    TypeParamKind, UnOp, WithExpr,
};
use crate::syntax::token::{Token, TokenKind};

/// 行の最初の字句の段の決め方（06-03「字下げ」の規則 1〜3）。添字は字句の列の添字である。
#[derive(Clone, Copy, Debug)]
enum Place {
    /// 規則 1: 添字の字句を含む行と同じ段
    Same(usize),
    /// 規則 2・3: 添字の字句を含む行より一段深い段
    Deeper(usize),
    /// 規則 3 のトップレベルの宣言・属性・import の宣言: 段 0
    Top,
}

/// 決め方の強さ。規則 1・2（閉じの字句、`else`、節の並びを始める `with`、`case`）は、規則 3（並びの要素）より
/// 先に当てはめる（06-03「字下げ」の「次の順に規則を当てはめて」）。
#[derive(Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Debug)]
enum Strength {
    Element,
    Fixed,
}

/// 役割の表を作る途中の状態。
pub(super) struct Walker<'a> {
    tokens: &'a [Token],
    /// 字句ごとに、行の最初の字句か
    line_first: Vec<bool>,
    /// 行の最初の字句の添字（昇順）
    line_firsts: Vec<usize>,
    /// `(`・`[` の字句の添字から、対応する閉じ括弧の添字
    close_of: Vec<Option<usize>>,
    /// 字句ごとの規則 1〜3 の決め方
    place: Vec<Option<(Strength, Place)>>,
    /// 並びの要素の範囲（最初の字句と最後の字句の添字）。外側の要素を内側の要素より先に入れる
    elements: Vec<(usize, usize)>,
    /// 前に空白を置かない `(`・`[`（呼び出しや引数の並びを開くもの）
    tight_open: Vec<bool>,
    /// 単項の `-`
    unary_minus: Vec<bool>,
    /// 閉じの字句と、それが閉じる構文の開きの字句の添字
    closers: Vec<(usize, usize)>,
    /// 構文の中身の範囲（開きの字句と、中身の最後の字句の添字）。中身の最初の行の空の行を除くために使う
    contents: Vec<(usize, usize)>,
    /// 前の空の行を除く字句
    remove_blank: Vec<bool>,
    top: Vec<TopRange>,
}

impl<'a> Walker<'a> {
    pub(super) fn new(tokens: &'a [Token]) -> Walker<'a> {
        let len = tokens.len();
        let mut line_first = vec![false; len];
        let mut line_firsts = Vec::new();
        let mut close_of = vec![None; len];
        let mut open_stack: Vec<usize> = Vec::new();
        let mut at_line_start = true;
        for (index, token) in tokens.iter().enumerate() {
            let kind = token.kind;
            if kind == TokenKind::LineBreak {
                at_line_start = true;
                continue;
            }
            if kind == TokenKind::Eof {
                continue;
            }
            if matches!(kind, TokenKind::LParen | TokenKind::LBracket) {
                open_stack.push(index);
            } else if matches!(kind, TokenKind::RParen | TokenKind::RBracket)
                && let Some(open) = open_stack.pop()
                && let Some(slot) = close_of.get_mut(open)
            {
                *slot = Some(index);
            }
            // 書き手の改行を保つので、改行の印の直後の字句は整形の後も行の最初の字句である（設計書 06-03「整形の考え方」）。
            if at_line_start {
                if let Some(slot) = line_first.get_mut(index) {
                    *slot = true;
                }
                line_firsts.push(index);
            }
            at_line_start = false;
        }
        Walker {
            tokens,
            line_first,
            line_firsts,
            close_of,
            place: vec![None; len],
            elements: Vec::new(),
            tight_open: vec![false; len],
            unary_minus: vec![false; len],
            closers: Vec::new(),
            contents: Vec::new(),
            remove_blank: vec![false; len],
            top: Vec::new(),
        }
    }

    // ---------------- 字句と span の対応 ----------------

    fn kind(&self, index: usize) -> Option<TokenKind> {
        self.tokens.get(index).map(|t| t.kind)
    }

    /// 位置 `pos` で始まる字句か、なければその後の最初の字句の添字。
    fn at_or_after(&self, pos: BytePos) -> usize {
        self.tokens.partition_point(|t| t.span.start < pos)
    }

    /// 位置 `pos` で始まる字句の添字。
    fn at(&self, pos: BytePos) -> Option<usize> {
        let index = self.at_or_after(pos);
        (self.tokens.get(index)?.span.start == pos).then_some(index)
    }

    /// span の最初の字句と最後の字句の添字。長さ 0 の span（空のブロック）は字句を持たない。
    fn range(&self, span: Span) -> Option<(usize, usize)> {
        if span.start >= span.end {
            return None;
        }
        let first = self.at(span.start)?;
        let last = self
            .tokens
            .partition_point(|t| t.span.start < span.end)
            .checked_sub(1)?;
        (first <= last).then_some((first, last))
    }

    fn first(&self, span: Span) -> Option<usize> {
        self.range(span).map(|(first, _)| first)
    }

    fn last(&self, span: Span) -> Option<usize> {
        self.range(span).map(|(_, last)| last)
    }

    /// `index` の後の、改行の印でない最初の字句。
    fn next(&self, index: usize) -> Option<usize> {
        let mut i = index.checked_add(1)?;
        while self.kind(i)? == TokenKind::LineBreak {
            i = i.checked_add(1)?;
        }
        Some(i)
    }

    /// `index` の前の、改行の印でない最後の字句。
    fn prev(&self, index: usize) -> Option<usize> {
        let mut i = index.checked_sub(1)?;
        while self.kind(i)? == TokenKind::LineBreak {
            i = i.checked_sub(1)?;
        }
        Some(i)
    }

    /// `index` の後の字句が `kind` なら、その添字。
    fn next_is(&self, index: usize, kind: TokenKind) -> Option<usize> {
        self.next(index).filter(|&i| self.kind(i) == Some(kind))
    }

    /// 名前の字句の添字。
    fn name(&self, name: &Name) -> Option<usize> {
        self.at(name.span.start)
    }

    /// 名前の並び（修飾した名前）の最後の段の字句の添字。
    fn path_end(&self, path: &[Name]) -> Option<usize> {
        self.name(path.last()?)
    }

    /// `end` で閉じる構文の span の `end` の字句の添字（span の最後の字句は `end` の後の語）。
    fn end_word(&self, span: Span) -> Option<usize> {
        let last = self.last(span)?;
        if self.kind(last) == Some(TokenKind::KwEnd) {
            return Some(last);
        }
        self.prev(last)
            .filter(|&i| self.kind(i) == Some(TokenKind::KwEnd))
    }

    // ---------------- 役割の記録 ----------------

    fn set_place(&mut self, index: usize, strength: Strength, place: Place) {
        if let Some(slot) = self.place.get_mut(index) {
            let keep = matches!(slot, Some((old, _)) if *old > strength);
            if !keep {
                *slot = Some((strength, place));
            }
        }
    }

    fn mark(flags: &mut [bool], index: usize) {
        if let Some(slot) = flags.get_mut(index) {
            *slot = true;
        }
    }

    /// 並びの要素を記録する。要素の最初の字句の段は `place` で決め（規則 3）、要素の中の続きの行の段は
    /// 要素の始まる行で決める（規則 4）。
    fn element(&mut self, span: Span, place: Place) {
        if let Some((first, last)) = self.range(span) {
            self.set_place(first, Strength::Element, place);
            self.elements.push((first, last));
        }
    }

    /// 規則 4 の続きの行の段を決めるためだけの範囲。`match` の分岐と `handle` の節の頭（パターンとガード、
    /// 操作の引数）の続きの行を、その `case` の行より一段深くする。
    fn continuation_range(&mut self, span: Span) {
        if let Some(range) = self.range(span) {
            self.elements.push(range);
        }
    }

    /// 閉じの字句（`end`・`)`・`]`）を記録する（規則 1、06-03「空の行」、10-17「役割の表」の `inner_level`）。
    fn closer(&mut self, close: usize, open: usize) {
        self.set_place(close, Strength::Fixed, Place::Same(open));
        Self::mark(&mut self.remove_blank, close);
        self.closers.push((close, open));
    }

    /// 区切りの字句（`if` の `else`、節の並びを始める `with`）を記録する（規則 1）。
    fn separator(&mut self, index: usize, open: usize) {
        self.set_place(index, Strength::Fixed, Place::Same(open));
        Self::mark(&mut self.remove_blank, index);
    }

    /// 構文の中身（開きの字句 `open` の後から `last` まで）を記録する（06-03「空の行」）。
    fn content(&mut self, open: usize, last: usize) {
        self.contents.push((open, last));
    }

    /// 丸括弧・角括弧を開く（06-03「字下げ」の表の最後の行）。`tight` は前に空白を置かない括弧
    /// （06-03「字句の間の空白」の表の、引数の並びなどを開く `(`・`[`）。閉じ括弧の添字を返す。
    fn open_bracket(&mut self, open: usize, tight: bool) -> Option<usize> {
        if !matches!(
            self.kind(open),
            Some(TokenKind::LParen | TokenKind::LBracket)
        ) {
            return None;
        }
        if tight {
            Self::mark(&mut self.tight_open, open);
        }
        let close = self.close_of.get(open).copied().flatten()?;
        self.closer(close, open);
        self.content(open, close);
        Some(close)
    }

    /// `end` で閉じる構文（関数の宣言、宣言の中身、`lambda`・`with`・`lazy`・`match`・`handle`・`if`）を開く。
    fn open_end(&mut self, open: usize, span: Span) {
        if let Some(end) = self.end_word(span) {
            self.closer(end, open);
            self.content(open, end);
        }
    }

    /// 文の並びを、`open` の字句の行より一段深い要素として辿る。
    fn block(&mut self, block: &Block, open: usize) {
        for stmt in &block.stmts {
            self.element(stmt.span(), Place::Deeper(open));
            self.stmt(stmt);
        }
    }

    // ---------------- モジュールと宣言 ----------------

    pub(super) fn module(&mut self, module: &Module) {
        for import in &module.imports {
            self.element(import.span, Place::Top);
            self.top_range(import.span, TopKind::Import);
        }
        for decl in &module.decls {
            self.top_decl(decl);
        }
        self.top.sort_by_key(|range| range.first);
    }

    fn top_range(&mut self, span: Span, kind: TopKind) {
        if let Some((first, last)) = self.range(span) {
            self.top.push(TopRange { first, last, kind });
        }
    }

    fn top_decl(&mut self, decl: &TopDecl) {
        let kind = match decl.item {
            Item::Const(_) => TopKind::Const,
            Item::Fn(_)
            | Item::Data(_)
            | Item::Alias(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::Impl(_)
            | Item::Error(_) => TopKind::Other,
        };
        self.top_range(decl.span, kind);
        self.element(decl.span, Place::Top);
        let first = self.first(decl.span);
        // `///` の行と属性の間の空の行を除く（06-03「空の行」）。
        if decl.doc.is_some()
            && let Some(first) = first
        {
            Self::mark(&mut self.remove_blank, first);
        }
        // 属性と `public` と宣言の本体は、どれもトップレベルの並びの要素として段 0 に置く（規則 3）。
        // 宣言の最初の行の後に置いた属性・`public`・宣言の行の前の空の行を除く（属性の行と宣言の間）。
        let mut heads: Vec<usize> = Vec::new();
        for attr in &decl.attrs {
            self.attribute(attr);
            heads.extend(self.first(attr.span));
        }
        if let Some(public) = decl.public {
            heads.extend(self.at(public.start));
        }
        heads.extend(self.item_first(&decl.item));
        for head in heads {
            self.set_place(head, Strength::Element, Place::Top);
            if Some(head) != first {
                Self::mark(&mut self.remove_blank, head);
            }
        }
        self.item(&decl.item);
    }

    fn item_first(&self, item: &Item) -> Option<usize> {
        let span = match item {
            Item::Fn(d) => d.span,
            Item::Const(d) => d.span,
            Item::Data(d) => d.span,
            Item::Alias(d) => d.span,
            Item::Record(d) => d.span,
            Item::Trait(d) => d.span,
            Item::Effect(d) => d.span,
            Item::Impl(d) => d.span,
            Item::Error(d) => d.span,
        };
        self.first(span)
    }

    fn attribute(&mut self, attr: &Attribute) {
        let Some(name) = self.name(&attr.name) else {
            return;
        };
        let Some(open) = self.next_is(name, TokenKind::LParen) else {
            return;
        };
        if self.last(attr.span).is_some_and(|last| open > last) {
            return;
        }
        if self.open_bracket(open, true).is_some() {
            for arg in &attr.args {
                self.element(arg.span, Place::Deeper(open));
            }
        }
    }

    fn item(&mut self, item: &Item) {
        match item {
            Item::Fn(d) => self.fn_decl(d),
            Item::Const(d) => {
                self.ty(&d.ty);
                self.expr(&d.value);
            }
            Item::Data(d) => self.data(d),
            Item::Alias(d) => {
                if let Some(name) = self.name(&d.name) {
                    self.type_params(name, &d.type_params);
                }
                self.ty(&d.ty);
            }
            Item::Record(d) => self.record(d),
            Item::Trait(d) => self.trait_decl(d),
            Item::Effect(d) => self.effect(d),
            Item::Impl(d) => self.implement(d),
            Item::Error(_) => {}
        }
    }

    /// 宣言の最初の字句（`function`・`data` など）。`public` が span に入っていれば、その次の字句。
    fn keyword(&self, span: Span) -> Option<usize> {
        let first = self.first(span)?;
        if self.kind(first) == Some(TokenKind::KwPublic) {
            self.next(first)
        } else {
            Some(first)
        }
    }

    /// 名前の後の型パラメータの並び `[...]`。並びの後の字句（なければ名前）の添字を返す。
    fn type_params(&mut self, name: usize, params: &[TypeParamDecl]) -> usize {
        let Some(open) = self.next_is(name, TokenKind::LBracket) else {
            return name;
        };
        let Some(close) = self.open_bracket(open, true) else {
            return name;
        };
        for param in params {
            self.element(param.span, Place::Deeper(open));
            self.type_param(param);
        }
        close
    }

    fn type_param(&mut self, param: &TypeParamDecl) {
        if let TypeParamKind::Ctor { .. } = param.kind
            && let Some(name) = self.name(&param.name)
            && let Some(open) = self.next_is(name, TokenKind::LBracket)
            && let Some(close) = self.open_bracket(open, true)
        {
            // `F[_, _]` の `_` は AST のノードを持たないので、括弧の中の `_` の字句を要素とする。
            for index in open..close {
                if self.kind(index) == Some(TokenKind::Underscore)
                    && let Some(token) = self.tokens.get(index)
                {
                    self.element(token.span, Place::Deeper(open));
                }
            }
        }
    }

    /// 関数・メソッド・操作の名前の後の、型パラメータの並びと引数の並び。
    fn signature(&mut self, name: &Name, type_params: &[TypeParamDecl], params: &[Param]) {
        let Some(name) = self.name(name) else {
            return;
        };
        let before = self.type_params(name, type_params);
        let Some(open) = self.next_is(before, TokenKind::LParen) else {
            return;
        };
        if self.open_bracket(open, true).is_some() {
            self.params(params, open);
        }
    }

    fn params(&mut self, params: &[Param], open: usize) {
        for param in params {
            self.element(param.span, Place::Deeper(open));
            if let Some(ty) = &param.ty {
                self.ty(ty);
            }
        }
    }

    fn fn_decl(&mut self, decl: &FnDecl) {
        self.signature(&decl.name, &decl.type_params, &decl.params);
        self.ty(&decl.ret);
        if let Some(body) = &decl.body
            && let Some(open) = self.keyword(decl.span)
        {
            self.open_end(open, decl.span);
            self.block(body, open);
        }
    }

    fn data(&mut self, decl: &DataDecl) {
        let Some(open) = self.keyword(decl.span) else {
            return;
        };
        self.open_end(open, decl.span);
        if let Some(name) = self.name(&decl.name) {
            self.type_params(name, &decl.type_params);
        }
        for variant in &decl.variants {
            self.element(variant.span, Place::Deeper(open));
            let Some(name) = self.name(&variant.name) else {
                continue;
            };
            let Some(paren) = self.next_is(name, TokenKind::LParen) else {
                continue;
            };
            if self.last(variant.span).is_some_and(|last| paren > last) {
                continue;
            }
            if self.open_bracket(paren, true).is_some() {
                for field in &variant.fields {
                    self.element(field.span(), Place::Deeper(paren));
                    self.ty(field);
                }
            }
        }
    }

    fn record(&mut self, decl: &RecordDecl) {
        let Some(open) = self.keyword(decl.span) else {
            return;
        };
        self.open_end(open, decl.span);
        if let Some(name) = self.name(&decl.name) {
            self.type_params(name, &decl.type_params);
        }
        for field in &decl.fields {
            self.element(field.span, Place::Deeper(open));
            self.ty(&field.ty);
        }
    }

    fn trait_decl(&mut self, decl: &TraitDecl) {
        let Some(open) = self.keyword(decl.span) else {
            return;
        };
        self.open_end(open, decl.span);
        if let Some(name) = self.name(&decl.name) {
            self.type_params(name, std::slice::from_ref(&decl.param));
        }
        for method in &decl.methods {
            self.element(method.span, Place::Deeper(open));
            self.method(method);
        }
    }

    fn method(&mut self, method: &MethodSig) {
        self.signature(&method.name, &method.type_params, &method.params);
        self.ty(&method.ret);
    }

    fn effect(&mut self, decl: &EffectDecl) {
        let Some(open) = self.keyword(decl.span) else {
            return;
        };
        self.open_end(open, decl.span);
        for op in &decl.ops {
            self.element(op.span, Place::Deeper(open));
            self.op(op);
        }
    }

    fn op(&mut self, op: &OpSig) {
        self.signature(&op.name, &op.type_params, &op.params);
        self.ty(&op.ret);
    }

    fn implement(&mut self, decl: &ImplDecl) {
        let Some(open) = self.keyword(decl.span) else {
            return;
        };
        self.open_end(open, decl.span);
        self.type_params(open, &decl.type_params);
        if let Some(class) = self.path_end(&decl.class.path)
            && let Some(bracket) = self.next_is(class, TokenKind::LBracket)
            && self.open_bracket(bracket, true).is_some()
        {
            self.element(decl.target.span(), Place::Deeper(bracket));
        }
        self.ty(&decl.target);
        for function in &decl.fns {
            self.element(function.decl.span, Place::Deeper(open));
            self.fn_decl(&function.decl);
        }
    }

    // ---------------- 型 ----------------

    fn ty(&mut self, ty: &TypeExpr) {
        match ty {
            TypeExpr::Named(t) => {
                if t.args.is_empty() {
                    return;
                }
                let Some(name) = self.path_end(&t.path) else {
                    return;
                };
                let Some(open) = self.next_is(name, TokenKind::LBracket) else {
                    return;
                };
                if self.open_bracket(open, true).is_some() {
                    for arg in &t.args {
                        self.element(arg.span(), Place::Deeper(open));
                        self.ty(arg);
                    }
                }
            }
            TypeExpr::Fn(t) => self.fn_type(t),
            TypeExpr::Paren(t) => {
                if let Some(open) = self.first(t.span)
                    && self.open_bracket(open, false).is_some()
                {
                    self.element(t.inner.span(), Place::Deeper(open));
                }
                self.ty(&t.inner);
            }
            TypeExpr::Error(_) => {}
        }
    }

    fn fn_type(&mut self, t: &FnType) {
        if let Some(keyword) = self.first(t.span)
            && let Some(open) = self.next_is(keyword, TokenKind::LParen)
            && self.open_bracket(open, true).is_some()
        {
            for param in &t.params {
                self.element(param.span(), Place::Deeper(open));
                self.ty(param);
            }
        }
        self.ty(&t.ret);
    }

    // ---------------- 文と式 ----------------

    fn stmt(&mut self, stmt: &Stmt) {
        match stmt {
            Stmt::Bind(s) => {
                self.pattern(&s.pattern);
                if let Some(ty) = &s.ty {
                    self.ty(ty);
                }
                self.expr(&s.value);
            }
            Stmt::Expr(e) => self.expr(e),
            Stmt::Error(_) => {}
        }
    }

    /// 式を辿る。入れ子の深さに比例する再帰であり、構文解析器が深さを抑える（00-02「再帰の深さ」）。
    /// 普通のスレッドのスタックで深い入れ子を辿れるように、式の種類ごとの処理は別の関数に分ける。
    fn expr(&mut self, expr: &Expr) {
        match expr {
            Expr::Lit(_) | Expr::Name(_) | Expr::Error(_) => {}
            Expr::Interp(e) => {
                for segment in &e.segments {
                    self.expr(&segment.expr);
                }
            }
            Expr::Unit(e) => {
                if let Some(open) = self.first(e.span) {
                    self.open_bracket(open, false);
                }
            }
            Expr::Paren(e) => self.paren_expr(e.span, &e.inner),
            Expr::List(e) => self.list_expr(e.span, &e.elems),
            Expr::Call(e) => self.call(&e.callee, &e.args),
            Expr::Record(e) => self.record_expr(e),
            Expr::Binary(e) => {
                self.expr(&e.lhs);
                self.expr(&e.rhs);
            }
            Expr::Unary(e) => {
                if e.op == UnOp::Neg
                    && let Some(op) = self.at(e.op_span.start)
                {
                    Self::mark(&mut self.unary_minus, op);
                }
                self.expr(&e.operand);
            }
            Expr::Pipe(e) => {
                self.expr(&e.lhs);
                self.expr(&e.rhs);
            }
            Expr::If(e) => self.if_expr(e),
            Expr::Match(e) => self.match_expr(e),
            Expr::Lambda(e) => self.lambda(e),
            Expr::Return(e) => self.expr(&e.value),
            Expr::Try(e) => self.expr(&e.value),
            Expr::Lazy(e) => {
                if let Some(open) = self.first(e.span) {
                    self.open_end(open, e.span);
                    self.block(&e.body, open);
                }
            }
            Expr::With(e) => self.with_expr(e),
            Expr::Handle(e) => self.handle(e),
            Expr::Resume(e) => self.resume(e.span, &e.value),
        }
    }

    fn paren_expr(&mut self, span: Span, inner: &Expr) {
        if let Some(open) = self.first(span)
            && self.open_bracket(open, false).is_some()
        {
            self.element(inner.span(), Place::Deeper(open));
        }
        self.expr(inner);
    }

    fn list_expr(&mut self, span: Span, elems: &[ListElem]) {
        let Some(open) = self.first(span) else {
            return;
        };
        let opened = self.open_bracket(open, false).is_some();
        for elem in elems {
            let (span, inner) = match elem {
                ListElem::Expr(e) => (e.span(), e),
                ListElem::Spread(s) => (s.span, &s.expr),
            };
            if opened {
                self.element(span, Place::Deeper(open));
            }
            self.expr(inner);
        }
    }

    fn call(&mut self, callee: &Expr, args: &[Arg]) {
        self.expr(callee);
        let Some(open) = self.last(callee.span()).and_then(|i| self.next(i)) else {
            return;
        };
        let opened = self.open_bracket(open, true).is_some();
        for arg in args {
            match arg {
                Arg::Expr(e) => {
                    if opened {
                        self.element(e.span(), Place::Deeper(open));
                    }
                    self.expr(e);
                }
                Arg::Placeholder(p) => {
                    if opened {
                        self.element(p.span, Place::Deeper(open));
                    }
                }
            }
        }
    }

    fn record_expr(&mut self, e: &RecordExpr) {
        let Some(open) = self
            .path_end(&e.path)
            .and_then(|name| self.next_is(name, TokenKind::LParen))
        else {
            return;
        };
        let opened = self.open_bracket(open, true).is_some();
        if let Some(base) = &e.base {
            // `..base` の要素は `..` から始まる。`base` の式の span は `..` を含まない。
            if opened
                && let Some(first) = self.first(base.span())
                && let Some(dots) = self.prev(first)
                && let (Some(dots_token), Some(last)) =
                    (self.tokens.get(dots), self.last(base.span()))
                && let Some(last_token) = self.tokens.get(last)
            {
                let span = dots_token.span.to(last_token.span);
                self.element(span, Place::Deeper(open));
            }
            self.expr(base);
        }
        for field in &e.fields {
            if opened {
                self.element(field.span, Place::Deeper(open));
            }
            self.expr(&field.value);
        }
    }

    fn if_expr(&mut self, e: &IfExpr) {
        let Some(open) = self.first(e.span) else {
            return;
        };
        self.open_end(open, e.span);
        // `else if` の内側の `IfExpr` の span は外側の `end if` を含まないので、閉じの位置は最も外側の
        // span から一度だけ求めて、連なりの各分岐に渡す。
        let end = self.end_word(e.span);
        self.if_chain(e, open, open, end);
    }

    /// `if` と、`else if` の連なり。`open` は最も外側の `if`（開きの字句）、`branch` はこの分岐を始めた
    /// `if` の字句、`end` は最も外側の `if` の `end` の字句である。`else if` の `if` は開きの字句ではない
    /// （06-03「字下げ」の表）。
    fn if_chain(&mut self, e: &IfExpr, open: usize, branch: usize, end: Option<usize>) {
        self.expr(&e.cond);
        self.block(&e.then_block, branch);
        match &e.else_branch {
            None => {}
            Some(ElseBranch::Block(block)) => {
                let after = self.at_or_after(block.span.start);
                let Some(else_word) = self.prev(after) else {
                    return;
                };
                self.separator(else_word, open);
                if let Some(end) = end {
                    self.content(else_word, end);
                }
                self.block(block, else_word);
            }
            Some(ElseBranch::If(inner)) => {
                let Some(inner_if) = self.first(inner.span) else {
                    return;
                };
                let Some(else_word) = self.prev(inner_if) else {
                    return;
                };
                self.separator(else_word, open);
                if let Some(end) = end {
                    self.content(inner_if, end);
                }
                self.if_chain(inner, open, inner_if, end);
            }
        }
    }

    fn match_expr(&mut self, e: &MatchExpr) {
        let Some(open) = self.first(e.span) else {
            return;
        };
        self.open_end(open, e.span);
        self.expr(&e.scrutinee);
        for arm in &e.arms {
            let Some((case, last)) = self.range(arm.span) else {
                continue;
            };
            // 規則 2: 分岐の `case` は `match` の開きの行より一段深い。
            self.set_place(case, Strength::Fixed, Place::Deeper(open));
            self.continuation_range(arm.span);
            self.content(case, last);
            for pattern in &arm.patterns {
                self.pattern(pattern);
            }
            if let Some(guard) = &arm.guard {
                self.expr(guard);
            }
            self.block(&arm.body, case);
        }
    }

    fn lambda(&mut self, e: &LambdaExpr) {
        let Some(open) = self.first(e.span) else {
            return;
        };
        self.open_end(open, e.span);
        if let Some(paren) = self.next_is(open, TokenKind::LParen)
            && self.open_bracket(paren, true).is_some()
        {
            self.params(&e.params, paren);
        }
        if let Some(ret) = &e.ret {
            self.ty(ret);
        }
        self.block(&e.body, open);
    }

    fn with_expr(&mut self, e: &WithExpr) {
        let Some(open) = self.first(e.span) else {
            return;
        };
        self.open_end(open, e.span);
        // 2 つ目以降の束縛の行は、`with` の開きの行より一段深い（06-03「字下げ」の表）。
        for bind in &e.binds {
            self.element(bind.span, Place::Deeper(open));
            self.expr(&bind.value);
        }
        self.block(&e.body, open);
    }

    fn handle(&mut self, e: &HandleExpr) {
        let Some(open) = self.first(e.span) else {
            return;
        };
        self.open_end(open, e.span);
        self.block(&e.body, open);
        // 節の並びを始める `with` は、最初の節の `case` の前の字句である。
        if let Some(with) = e
            .clauses
            .first()
            .and_then(|clause| self.first(clause.span))
            .and_then(|case| self.prev(case))
            .filter(|&i| self.kind(i) == Some(TokenKind::KwWith))
        {
            self.separator(with, open);
        }
        for clause in &e.clauses {
            let Some((case, last)) = self.range(clause.span) else {
                continue;
            };
            self.set_place(case, Strength::Fixed, Place::Deeper(open));
            self.continuation_range(clause.span);
            self.content(case, last);
            if let Some(paren) = self
                .last(clause.op.span)
                .and_then(|op| self.next_is(op, TokenKind::LParen))
                && self.open_bracket(paren, true).is_some()
            {
                for param in &clause.params {
                    self.element(param.span, Place::Deeper(paren));
                }
            }
            self.block(&clause.body, case);
        }
    }

    fn resume(&mut self, span: Span, value: &Expr) {
        if let Some(keyword) = self.first(span)
            && let Some(open) = self.next_is(keyword, TokenKind::LParen)
            && self.open_bracket(open, true).is_some()
        {
            self.element(value.span(), Place::Deeper(open));
        }
        self.expr(value);
    }

    // ---------------- パターン ----------------

    fn pattern(&mut self, pattern: &Pattern) {
        match pattern {
            Pattern::Wildcard(_) | Pattern::Var(_) | Pattern::Error(_) => {}
            Pattern::Lit(p) => {
                if p.negative {
                    self.negative_sign(p.span);
                }
            }
            Pattern::Range(p) => {
                if p.lo.negative {
                    self.negative_sign(p.lo.span);
                }
                if p.hi.negative {
                    self.negative_sign(p.hi.span);
                }
            }
            Pattern::Unit(p) => {
                if let Some(open) = self.first(p.span) {
                    self.open_bracket(open, false);
                }
            }
            Pattern::Ctor(p) => {
                if !p.has_parens {
                    return;
                }
                let Some(open) = self
                    .path_end(&p.path)
                    .and_then(|name| self.next_is(name, TokenKind::LParen))
                else {
                    return;
                };
                let opened = self.open_bracket(open, true).is_some();
                for arg in &p.args {
                    if opened {
                        self.element(arg.span(), Place::Deeper(open));
                    }
                    self.pattern(arg);
                }
            }
            Pattern::Record(p) => {
                let Some(open) = self
                    .path_end(&p.path)
                    .and_then(|name| self.next_is(name, TokenKind::LParen))
                else {
                    return;
                };
                let Some(close) = self.open_bracket(open, true) else {
                    return;
                };
                for field in &p.fields {
                    self.element(field.span, Place::Deeper(open));
                    self.pattern(&field.pattern);
                }
                if p.rest {
                    // 最後の `..` は AST のノードを持たないので、閉じ括弧の前（末尾の `,` を除く）の字句とする。
                    let mut index = self.prev(close);
                    if let Some(i) = index
                        && self.kind(i) == Some(TokenKind::Comma)
                    {
                        index = self.prev(i);
                    }
                    if let Some(i) = index.filter(|&i| self.kind(i) == Some(TokenKind::DotDot))
                        && let Some(token) = self.tokens.get(i)
                    {
                        self.element(token.span, Place::Deeper(open));
                    }
                }
            }
            Pattern::List(p) => {
                let Some(open) = self.first(p.span) else {
                    return;
                };
                let opened = self.open_bracket(open, false).is_some();
                for item in &p.before {
                    if opened {
                        self.element(item.span(), Place::Deeper(open));
                    }
                    self.pattern(item);
                }
                if let Some(rest) = &p.rest
                    && opened
                {
                    self.element(rest.span, Place::Deeper(open));
                }
                for item in &p.after {
                    if opened {
                        self.element(item.span(), Place::Deeper(open));
                    }
                    self.pattern(item);
                }
            }
        }
    }

    /// パターンの整数リテラルの前置の `-`（単項の `-` と同じく後に空白を置かない）。
    fn negative_sign(&mut self, span: Span) {
        if let Some(first) = self.first(span)
            && self.kind(first) == Some(TokenKind::Minus)
        {
            Self::mark(&mut self.unary_minus, first);
        }
    }

    // ---------------- 表を作る ----------------

    pub(super) fn finish(self) -> RoleTable {
        let len = self.tokens.len();
        // 行の最初の字句の添字を、字句ごとに求める。複数行の文字列の後に続く字句は、文字列の開きの行に属する。
        let mut head = vec![0usize; len];
        let mut current = 0usize;
        for (index, slot) in head.iter_mut().enumerate() {
            if self.line_first.get(index).copied().unwrap_or(false) {
                current = index;
            }
            *slot = current;
        }
        // 規則 4: 行の最初の字句を含む最も内側の要素（その字句より前に始まるもの）の最初の字句。
        let mut container: Vec<Option<usize>> = vec![None; len];
        for &(first, last) in &self.elements {
            let from = self.line_firsts.partition_point(|&i| i <= first);
            for &index in self.line_firsts.get(from..).unwrap_or(&[]) {
                if index > last {
                    break;
                }
                if let Some(slot) = container.get_mut(index) {
                    *slot = Some(first);
                }
            }
        }
        let mut levels: Vec<Option<u32>> = vec![None; len];
        let level_of_line = |levels: &[Option<u32>], index: usize| -> u32 {
            head.get(index)
                .and_then(|&h| levels.get(h).copied().flatten())
                .unwrap_or(0)
        };
        for &index in &self.line_firsts {
            let place = self.place.get(index).copied().flatten().map(|(_, p)| p);
            let level = match place {
                Some(Place::Same(open)) => level_of_line(&levels, open),
                Some(Place::Deeper(open)) => level_of_line(&levels, open).saturating_add(1),
                Some(Place::Top) => 0,
                None => match container.get(index).copied().flatten() {
                    Some(first) => level_of_line(&levels, first).saturating_add(1),
                    None => 0,
                },
            };
            if let Some(slot) = levels.get_mut(index) {
                *slot = Some(level);
            }
        }
        let mut roles = vec![TokenRole::default(); len];
        for (index, role) in roles.iter_mut().enumerate() {
            role.level = levels.get(index).copied().flatten().unwrap_or(0);
            role.space_before = self.space_before(index);
            if self.remove_blank.get(index).copied().unwrap_or(false) {
                role.blank_before = BlankBefore::Remove;
            }
        }
        // 構文の中身の最初の行（開きの行の次の行）の前の空の行を除く（06-03「空の行」）。
        for &(open, last) in &self.contents {
            let from = self.line_firsts.partition_point(|&i| i <= open);
            if let Some(&index) = self.line_firsts.get(from)
                && index <= last
                && let Some(role) = roles.get_mut(index)
            {
                role.blank_before = BlankBefore::Remove;
            }
        }
        for &(close, open) in &self.closers {
            let inner = level_of_line(&levels, open).saturating_add(1);
            if let Some(role) = roles.get_mut(close) {
                role.inner_level = Some(inner);
            }
        }
        RoleTable {
            roles,
            top: self.top,
        }
    }

    /// 同じ行の直前の字句との間に空白を置くか（06-03「字句の間の空白」の表と、その後の段落）。
    fn space_before(&self, index: usize) -> bool {
        use TokenKind as K;
        let Some(kind) = self.kind(index) else {
            return false;
        };
        let Some(prev) = index.checked_sub(1) else {
            return false;
        };
        let Some(prev_kind) = self.kind(prev) else {
            return false;
        };
        if matches!(kind, K::LineBreak | K::Eof) || prev_kind == K::LineBreak {
            return false;
        }
        // `(`・`[` の後と、`)`・`]`・`,`・`:` の前
        if matches!(prev_kind, K::LParen | K::LBracket)
            || matches!(kind, K::RParen | K::RBracket | K::Comma | K::Colon)
        {
            return false;
        }
        // `.` の前と後
        if kind == K::Dot || prev_kind == K::Dot {
            return false;
        }
        // `..` の後と、`,` の後でない `..` の前
        if prev_kind == K::DotDot || (kind == K::DotDot && prev_kind != K::Comma) {
            return false;
        }
        // 呼び出しや引数の並びなどを開く `(`・`[` の前
        if self.tight_open.get(index).copied().unwrap_or(false) {
            return false;
        }
        // 単項の `-` の後と、`@` の後
        if self.unary_minus.get(prev).copied().unwrap_or(false) || prev_kind == K::At {
            return false;
        }
        // 補間の開始・中間の後と、中間・終わりの前
        if matches!(prev_kind, K::StrStart | K::StrMid) || matches!(kind, K::StrMid | K::StrEnd) {
            return false;
        }
        true
    }
}
