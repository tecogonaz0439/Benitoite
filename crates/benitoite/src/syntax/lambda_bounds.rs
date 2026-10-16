//! AST を作らずラムダの見出しと終端候補を調べる（設計書 02-03「ラムダの境界走査」）。
//! 生の改行と NEWLINE を同じように除いて読み、キーには開始位置を使う。

use super::token::{Token, TokenKind as K};
use crate::base::BytePos;
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Copy)]
pub(super) struct Bound {
    pub(super) explicit: bool,
    pub(super) line: u32,
    end: usize,
    pub(super) boundary: BytePos,
}

pub(super) struct Bounds {
    by_start: BTreeMap<BytePos, Bound>,
    short_boundaries: BTreeSet<BytePos>,
}
impl Bounds {
    pub(super) fn get(&self, token: &Token) -> Option<Bound> {
        self.by_start.get(&token.span.start).copied()
    }
    pub(super) fn short_body_ends_at(&self, boundary: BytePos) -> bool {
        self.short_boundaries.contains(&boundary)
    }
    pub(super) fn new(tokens: &[Token]) -> Self {
        let ts: Vec<_> = tokens
            .iter()
            .filter(|t| !matches!(t.kind, K::LineBreak | K::Newline))
            .collect();
        let pairs = delimiter_pairs(&ts);
        let mut bounds = BTreeMap::new();
        let mut short_boundaries = BTreeSet::new();
        // 内側の分類を再利用し、不正入力の探索量も入力長に比例させる。
        let mut budget = ts.len().saturating_mul(8);
        for (i, token) in ts.iter().enumerate().rev() {
            if token.kind != K::KwLambda
                || i.checked_sub(1)
                    .and_then(|j| ts.get(j))
                    .is_some_and(|t| t.kind == K::KwEnd)
            {
                continue;
            }
            let mut cursor = Cursor {
                ts: &ts,
                pairs: &pairs,
                pos: i.saturating_add(1),
            };
            if !cursor.group(K::LParen) {
                continue;
            }
            if cursor.eat(K::Arrow) && !cursor.ty() {
                continue;
            }
            if !cursor.uses() {
                continue;
            }
            let Some(header) = cursor.pos.checked_sub(1).and_then(|j| ts.get(j)) else {
                continue;
            };
            let Some(body) = ts.get(cursor.pos) else {
                continue;
            };
            let multiline = body.start_line > header.end_line;
            let line = body.start_line;
            let mut j = cursor.pos;
            let mut explicit = multiline;
            while let Some(t) = ts.get(j) {
                if budget == 0 {
                    break;
                }
                budget = budget.saturating_sub(1);
                if t.kind == K::KwEnd {
                    if ts
                        .get(j.saturating_add(1))
                        .is_some_and(|t| t.kind == K::KwLambda && (multiline || t.end_line == line))
                        && (multiline || t.start_line == line)
                    {
                        explicit = true;
                        j = j.saturating_add(2);
                    }
                    break;
                }
                if matches!(
                    t.kind,
                    K::Eof
                        | K::RParen
                        | K::RBracket
                        | K::Comma
                        | K::KwCase
                        | K::KwElse
                        | K::KwDo
                        | K::KwThen
                        | K::StrMid
                        | K::StrEnd
                ) {
                    break;
                }
                if !multiline && t.end_line > line {
                    break;
                }
                let jump = if t.kind == K::KwLambda {
                    bounds.get(&t.span.start).map(|b: &Bound| b.end)
                } else {
                    pairs.get(&j).copied()
                };
                if let Some(end) = jump {
                    if !multiline
                        && ts
                            .get(end.saturating_sub(1))
                            .is_some_and(|t| t.end_line > line)
                    {
                        break;
                    }
                    j = end;
                } else {
                    j = j.saturating_add(1);
                }
            }
            let boundary = ts.get(j).map_or(token.span.end, |t| t.span.start);
            if !explicit {
                short_boundaries.insert(boundary);
            }
            bounds.insert(
                token.span.start,
                Bound {
                    explicit,
                    line,
                    end: j,
                    boundary,
                },
            );
        }
        Self {
            by_start: bounds,
            short_boundaries,
        }
    }
}

// 括弧・補間と通常のブロックの対応は一度作る。ラムダは後ろから独立に分類する。
fn delimiter_pairs(ts: &[&Token]) -> BTreeMap<usize, usize> {
    let mut pairs = BTreeMap::new();
    let mut stack: Vec<(K, usize, Option<usize>)> = Vec::new();
    for (i, t) in ts.iter().enumerate() {
        let previous = i.checked_sub(1).and_then(|j| ts.get(j)).map(|t| t.kind);
        if previous == Some(K::KwEnd) {
            close(&mut stack, &mut pairs, t.kind, i.saturating_add(1));
            continue;
        }
        match t.kind {
            K::RParen => close(&mut stack, &mut pairs, K::LParen, i.saturating_add(1)),
            K::RBracket => close(&mut stack, &mut pairs, K::LBracket, i.saturating_add(1)),
            K::StrEnd => close(&mut stack, &mut pairs, K::StrStart, i.saturating_add(1)),
            K::KwCase => {
                // 分類前のラムダ候補には短い形もある。分岐境界で降ろし、次のガードの
                // if を通常のブロックと誤認しない（設計書 02-03「ラムダの境界走査」）。
                while stack.last().is_some_and(|o| o.0 == K::KwLambda) {
                    stack.pop();
                }
                let depth = stack.len();
                if let Some(top) = stack
                    .last_mut()
                    .filter(|o| matches!(o.0, K::KwMatch | K::KwHandle))
                {
                    top.2 = Some(depth);
                }
            }
            K::Arrow => {
                let depth = stack.len();
                if let Some(top) = stack.last_mut().filter(|o| o.2 == Some(depth)) {
                    top.2 = None;
                }
            }
            K::KwIf
                if previous == Some(K::KwElse)
                    || stack.last().is_some_and(|o| o.2 == Some(stack.len())) => {}
            K::KwWith
                if ts
                    .get(i.saturating_add(1))
                    .is_some_and(|t| t.kind == K::KwCase) => {}
            K::LParen
            | K::LBracket
            | K::StrStart
            | K::KwLambda
            | K::KwIf
            | K::KwMatch
            | K::KwHandle
            | K::KwLazy
            | K::KwWith => stack.push((t.kind, i, None)),
            K::LowerIdent
            | K::UpperIdent
            | K::IntLit
            | K::FloatLit
            | K::DecimalLit
            | K::StringLit
            | K::StrMid
            | K::CharLit
            | K::KwAnd
            | K::KwBind
            | K::KwConst
            | K::KwData
            | K::KwDie
            | K::KwDiv
            | K::KwDo
            | K::KwEffect
            | K::KwElse
            | K::KwEnd
            | K::KwFalse
            | K::KwFunction
            | K::KwImplement
            | K::KwImport
            | K::KwMod
            | K::KwNot
            | K::KwOr
            | K::KwPublic
            | K::KwRecord
            | K::KwResume
            | K::KwReturn
            | K::KwShadow
            | K::KwThen
            | K::KwTrait
            | K::KwTrue
            | K::KwTry
            | K::KwType
            | K::KwUses
            | K::Plus
            | K::Minus
            | K::Star
            | K::Slash
            | K::Eq
            | K::NotEq
            | K::Lt
            | K::Le
            | K::Gt
            | K::Ge
            | K::PipeGt
            | K::LeftArrow
            | K::Colon
            | K::Comma
            | K::Dot
            | K::DotDot
            | K::Amp
            | K::At
            | K::Underscore
            | K::LineBreak
            | K::Newline
            | K::Error
            | K::BadSymbol
            | K::Eof => {}
        }
    }
    pairs
}
fn close(
    stack: &mut Vec<(K, usize, Option<usize>)>,
    pairs: &mut BTreeMap<usize, usize>,
    kind: K,
    end: usize,
) {
    if let Some(i) = stack.iter().rposition(|o| o.0 == kind) {
        if let Some(open) = stack.get(i) {
            pairs.insert(open.1, end);
        }
        stack.truncate(i);
    }
}

struct Cursor<'a> {
    ts: &'a [&'a Token],
    pairs: &'a BTreeMap<usize, usize>,
    pos: usize,
}
impl Cursor<'_> {
    fn kind(&self) -> Option<K> {
        self.ts.get(self.pos).map(|t| t.kind)
    }
    fn eat(&mut self, kind: K) -> bool {
        if self.kind() != Some(kind) {
            return false;
        }
        self.pos = self.pos.saturating_add(1);
        true
    }
    fn group(&mut self, kind: K) -> bool {
        if self.kind() != Some(kind) {
            return false;
        }
        let Some(end) = self.pairs.get(&self.pos) else {
            return false;
        };
        self.pos = *end;
        true
    }
    fn name(&mut self) -> bool {
        if !self.eat(K::UpperIdent) {
            return false;
        }
        while self.eat(K::Dot) {
            if !self.eat(K::UpperIdent) {
                return false;
            }
        }
        true
    }
    // 関数型の戻り値は右へ連なるためループで読み、Rust のスタックを増やさない。
    fn ty(&mut self) -> bool {
        let mut functions = 0usize;
        loop {
            if self.eat(K::KwFunction) {
                if !self.group(K::LParen) || !self.eat(K::Arrow) {
                    return false;
                }
                functions = functions.saturating_add(1);
                if functions > usize::try_from(super::parser::MAX_DEPTH).unwrap_or(usize::MAX) {
                    return false;
                }
            } else {
                if self.kind() == Some(K::LParen) {
                    if !self.group(K::LParen) {
                        return false;
                    }
                } else {
                    if !self.name() {
                        return false;
                    }
                    if self.kind() == Some(K::LBracket) && !self.group(K::LBracket) {
                        return false;
                    }
                }
                break;
            }
        }
        for _ in 0..functions {
            if !self.uses() {
                return false;
            }
        }
        true
    }
    fn uses(&mut self) -> bool {
        if !self.eat(K::KwUses) {
            return true;
        }
        if !self.name() {
            return false;
        }
        while self.kind() == Some(K::Comma)
            && self
                .ts
                .get(self.pos.saturating_add(1))
                .is_some_and(|t| t.kind == K::UpperIdent)
        {
            self.pos = self.pos.saturating_add(1);
            if !self.name() {
                return false;
            }
        }
        // 型引数を含む uses は正常な見出しにしない。通常の型解析が E0209 と回復を担う。
        self.kind() != Some(K::LBracket)
    }
}
