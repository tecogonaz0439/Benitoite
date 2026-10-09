//! 不変の二分木の分割と連結（設計書 03-06「Map と Set（初回リリース版）」）。
//! すべての走査は積み重ねで行い、回転で作るノードの局所の平衡と要素数を確かめる。

use super::{Stop, Value, ValueCtx, compare_keys};
use crate::runtime::heap::FieldsKind;
use std::cmp::Ordering;

const DELTA: u64 = 3;
const GAMMA: u64 = 2;

pub(super) fn invalid() -> Stop {
    Stop::Internal("invalid ordered collection or key".into())
}

#[derive(Clone, Copy)]
pub(super) enum TreeKind {
    Map,
    Set,
}

#[derive(Clone, Copy)]
pub(super) struct Node<'e> {
    pub key: Value<'e>,
    pub value: Value<'e>,
    left: Value<'e>,
    right: Value<'e>,
}

impl TreeKind {
    fn empty<'e>(self) -> Value<'e> {
        match self {
            Self::Map => Value::EmptyMap,
            Self::Set => Value::EmptySet,
        }
    }
    fn kind(self) -> FieldsKind {
        match self {
            Self::Map => FieldsKind::MapNode,
            Self::Set => FieldsKind::SetNode,
        }
    }
    pub(super) fn len<'e>(self, ctx: &ValueCtx<'e>, tree: Value<'e>) -> Result<u32, Stop> {
        if matches!(
            (self, tree),
            (Self::Map, Value::EmptyMap) | (Self::Set, Value::EmptySet)
        ) {
            return Ok(0);
        }
        let (kind, count) = ctx.fields_header(tree).ok_or_else(invalid)?;
        let fields = match self {
            Self::Map => 4,
            Self::Set => 3,
        };
        if kind != self.kind() || count == 0 || ctx.fields_len(tree) != Some(fields) {
            return Err(invalid());
        }
        Ok(count)
    }
    fn weight<'e>(self, ctx: &ValueCtx<'e>, tree: Value<'e>) -> Result<u64, Stop> {
        Ok(u64::from(self.len(ctx, tree)?).saturating_add(1))
    }
    fn node<'e>(self, ctx: &ValueCtx<'e>, tree: Value<'e>) -> Result<Node<'e>, Stop> {
        if self.len(ctx, tree)? == 0 {
            return Err(invalid());
        }
        let field = |i| ctx.field(tree, i).ok_or_else(invalid);
        let (value, left, right) = match self {
            Self::Map => (field(1)?, field(2)?, field(3)?),
            Self::Set => (Value::Unit, field(1)?, field(2)?),
        };
        Ok(Node {
            key: field(0)?,
            value,
            left,
            right,
        })
    }
    fn make<'e>(
        self,
        ctx: &ValueCtx<'e>,
        n: Node<'e>,
        left: Value<'e>,
        right: Value<'e>,
    ) -> Result<Value<'e>, Stop> {
        let l = self.len(ctx, left)?;
        let r = self.len(ctx, right)?;
        let count = l
            .checked_add(r)
            .and_then(|n| n.checked_add(1))
            .ok_or_else(invalid)?;
        let lw = u64::from(l).saturating_add(1);
        let rw = u64::from(r).saturating_add(1);
        debug_assert!(DELTA.saturating_mul(lw) >= rw && DELTA.saturating_mul(rw) >= lw);
        let fields = match self {
            Self::Map => vec![n.key, n.value, left, right],
            Self::Set => vec![n.key, left, right],
        };
        let result = ctx.alloc_fields(self.kind(), count, &fields)?;
        debug_assert_eq!(ctx.fields_header(result), Some((self.kind(), count)));
        debug_assert_eq!(
            u64::from(count),
            u64::from(l).saturating_add(u64::from(r)).saturating_add(1)
        );
        Ok(result)
    }
    // 重み size + 1 の原型の条件で回転する。一重の判定は厳密な < とする
    // （R37「木の形」、Hirai・Yamamoto 2011 の 3.4 節）。
    fn balance<'e>(
        self,
        ctx: &ValueCtx<'e>,
        n: Node<'e>,
        left: Value<'e>,
        right: Value<'e>,
    ) -> Result<Value<'e>, Stop> {
        let lw = self.weight(ctx, left)?;
        let rw = self.weight(ctx, right)?;
        if rw > DELTA.saturating_mul(lw) {
            let r = self.node(ctx, right)?;
            if self.weight(ctx, r.left)? < GAMMA.saturating_mul(self.weight(ctx, r.right)?) {
                let l = self.make(ctx, n, left, r.left)?;
                self.make(ctx, r, l, r.right)
            } else {
                let middle = self.node(ctx, r.left)?;
                let l = self.make(ctx, n, left, middle.left)?;
                let r = self.make(ctx, r, middle.right, r.right)?;
                self.make(ctx, middle, l, r)
            }
        } else if lw > DELTA.saturating_mul(rw) {
            let l = self.node(ctx, left)?;
            if self.weight(ctx, l.right)? < GAMMA.saturating_mul(self.weight(ctx, l.left)?) {
                let r = self.make(ctx, n, l.right, right)?;
                self.make(ctx, l, l.left, r)
            } else {
                let middle = self.node(ctx, l.right)?;
                let l = self.make(ctx, l, l.left, middle.left)?;
                let r = self.make(ctx, n, middle.right, right)?;
                self.make(ctx, middle, l, r)
            }
        } else {
            self.make(ctx, n, left, right)
        }
    }
    fn join<'e>(
        self,
        ctx: &ValueCtx<'e>,
        pivot: Node<'e>,
        mut left: Value<'e>,
        mut right: Value<'e>,
    ) -> Result<Value<'e>, Stop> {
        let mut path = Vec::new();
        loop {
            let lw = self.weight(ctx, left)?;
            let rw = self.weight(ctx, right)?;
            if lw > DELTA.saturating_mul(rw) {
                let n = self.node(ctx, left)?;
                path.push((n, true));
                left = n.right;
            } else if rw > DELTA.saturating_mul(lw) {
                let n = self.node(ctx, right)?;
                path.push((n, false));
                right = n.left;
            } else {
                break;
            }
        }
        let mut result = self.make(ctx, pivot, left, right)?;
        while let Some((n, from_left)) = path.pop() {
            result = if from_left {
                self.balance(ctx, n, n.left, result)?
            } else {
                self.balance(ctx, n, result, n.right)?
            };
        }
        Ok(result)
    }
    fn join2<'e>(
        self,
        ctx: &ValueCtx<'e>,
        left: Value<'e>,
        mut right: Value<'e>,
    ) -> Result<Value<'e>, Stop> {
        if self.len(ctx, left)? == 0 {
            return Ok(right);
        }
        if self.len(ctx, right)? == 0 {
            return Ok(left);
        }
        let mut path = Vec::new();
        let pivot = loop {
            let n = self.node(ctx, right)?;
            if self.len(ctx, n.left)? == 0 {
                right = n.right;
                break n;
            }
            path.push(n);
            right = n.left;
        };
        while let Some(n) = path.pop() {
            right = self.balance(ctx, n, right, n.right)?;
        }
        self.join(ctx, pivot, left, right)
    }
    pub(super) fn find<'e>(
        self,
        ctx: &ValueCtx<'e>,
        mut tree: Value<'e>,
        key: Value<'e>,
    ) -> Result<Option<Node<'e>>, Stop> {
        while self.len(ctx, tree)? != 0 {
            let n = self.node(ctx, tree)?;
            tree = match compare_keys(ctx, key, n.key)? {
                Ordering::Less => n.left,
                Ordering::Greater => n.right,
                Ordering::Equal => return Ok(Some(n)),
            };
        }
        Ok(None)
    }
    pub(super) fn insert<'e>(
        self,
        ctx: &ValueCtx<'e>,
        tree: Value<'e>,
        key: Value<'e>,
        value: Value<'e>,
    ) -> Result<Value<'e>, Stop> {
        let mut at = tree;
        let mut path = Vec::new();
        let mut result = loop {
            if self.len(ctx, at)? == 0 {
                compare_keys(ctx, key, key)?;
                break self.make(
                    ctx,
                    Node {
                        key,
                        value,
                        left: self.empty(),
                        right: self.empty(),
                    },
                    self.empty(),
                    self.empty(),
                )?;
            }
            let mut n = self.node(ctx, at)?;
            match compare_keys(ctx, key, n.key)? {
                Ordering::Equal => {
                    if matches!(self, Self::Set) {
                        return Ok(tree);
                    }
                    n.value = value;
                    break self.make(ctx, n, n.left, n.right)?;
                }
                Ordering::Less => {
                    path.push((n, false));
                    at = n.left;
                }
                Ordering::Greater => {
                    path.push((n, true));
                    at = n.right;
                }
            }
        };
        while let Some((n, right)) = path.pop() {
            result = if right {
                self.balance(ctx, n, n.left, result)?
            } else {
                self.balance(ctx, n, result, n.right)?
            };
        }
        Ok(result)
    }
    pub(super) fn remove<'e>(
        self,
        ctx: &ValueCtx<'e>,
        tree: Value<'e>,
        key: Value<'e>,
    ) -> Result<Value<'e>, Stop> {
        let mut at = tree;
        let mut path = Vec::new();
        let mut result = loop {
            if self.len(ctx, at)? == 0 {
                return Ok(tree);
            }
            let n = self.node(ctx, at)?;
            match compare_keys(ctx, key, n.key)? {
                Ordering::Equal => break self.join2(ctx, n.left, n.right)?,
                Ordering::Less => {
                    path.push((n, false));
                    at = n.left;
                }
                Ordering::Greater => {
                    path.push((n, true));
                    at = n.right;
                }
            }
        };
        while let Some((n, right)) = path.pop() {
            result = if right {
                self.balance(ctx, n, n.left, result)?
            } else {
                self.balance(ctx, n, result, n.right)?
            };
        }
        Ok(result)
    }
    fn split<'e>(
        self,
        ctx: &ValueCtx<'e>,
        tree: Value<'e>,
        key: Value<'e>,
    ) -> Result<(Value<'e>, Option<Node<'e>>, Value<'e>), Stop> {
        let mut at = tree;
        let mut path = Vec::new();
        let (mut left, found, mut right) = loop {
            if self.len(ctx, at)? == 0 {
                break (self.empty(), None, self.empty());
            }
            let n = self.node(ctx, at)?;
            match compare_keys(ctx, key, n.key)? {
                Ordering::Equal => break (n.left, Some(n), n.right),
                Ordering::Less => {
                    path.push((n, false));
                    at = n.left;
                }
                Ordering::Greater => {
                    path.push((n, true));
                    at = n.right;
                }
            }
        };
        while let Some((n, went_right)) = path.pop() {
            if went_right {
                left = self.join(ctx, n, n.left, left)?;
            } else {
                right = self.join(ctx, n, right, n.right)?;
            }
        }
        Ok((left, found, right))
    }
    // 中央の組を親にして後順で組む。各組を一度だけ読み、並べ替えない（10-07「定数の記述」）。
    pub(super) fn build_sorted<'e>(
        self,
        ctx: &ValueCtx<'e>,
        pairs: &[(Value<'e>, Value<'e>)],
    ) -> Result<Value<'e>, Stop> {
        u32::try_from(pairs.len()).map_err(|_| invalid())?;
        let mut work = vec![(0usize, pairs.len(), false)];
        let mut results = Vec::new();
        while let Some((start, count, ready)) = work.pop() {
            if count == 0 {
                results.push(self.empty());
                continue;
            }
            let half = count / 2;
            let mid = start.checked_add(half).ok_or_else(invalid)?;
            if !ready {
                work.push((start, count, true));
                work.push((
                    mid.checked_add(1).ok_or_else(invalid)?,
                    count.saturating_sub(half).saturating_sub(1),
                    false,
                ));
                work.push((start, half, false));
            } else {
                let right = results.pop().ok_or_else(invalid)?;
                let left = results.pop().ok_or_else(invalid)?;
                let &(key, value) = pairs.get(mid).ok_or_else(invalid)?;
                results.push(self.make(
                    ctx,
                    Node {
                        key,
                        value,
                        left,
                        right,
                    },
                    left,
                    right,
                )?);
            }
        }
        results.pop().ok_or_else(invalid)
    }
}

// 中順の位置だけを保存し、木全体の写しを持たない（R37「構造の等しさ」）。
pub(in crate::runtime) struct Cursor<'e> {
    kind: TreeKind,
    at: Value<'e>,
    path: Vec<Node<'e>>,
}
impl<'e> Cursor<'e> {
    pub(super) fn new(at: Value<'e>, kind: TreeKind) -> Self {
        Self {
            kind,
            at,
            path: Vec::new(),
        }
    }
    pub(in crate::runtime) fn map(at: Value<'e>) -> Self {
        Self::new(at, TreeKind::Map)
    }
    pub(in crate::runtime) fn set(at: Value<'e>) -> Self {
        Self::new(at, TreeKind::Set)
    }
    pub(in crate::runtime) fn next(
        &mut self,
        ctx: &ValueCtx<'e>,
    ) -> Result<Option<(Value<'e>, Value<'e>)>, Stop> {
        while self.kind.len(ctx, self.at)? != 0 {
            let n = self.kind.node(ctx, self.at)?;
            self.path.push(n);
            self.at = n.left;
        }
        if let Some(n) = self.path.pop() {
            self.at = n.right;
            Ok(Some((n.key, n.value)))
        } else {
            Ok(None)
        }
    }
}

#[derive(Clone, Copy)]
pub(super) enum Operation {
    Union,
    Intersection,
    Difference,
}

// 小さい木を分割の軸にして、大きい木の道筋だけを写す。左右の仕事を順に
// 積み重ねへ置き、帰りに join する（R37「木の形」、SPAA 2016 の join に基づく集合演算）。
pub(super) fn combine<'e>(
    ctx: &ValueCtx<'e>,
    a: Value<'e>,
    b: Value<'e>,
    op: Operation,
) -> Result<Value<'e>, Stop> {
    enum Work<'e> {
        Visit(Value<'e>, Value<'e>),
        Finish(Node<'e>, bool),
    }
    let kind = TreeKind::Set;
    let mut work = vec![Work::Visit(a, b)];
    let mut results = Vec::new();
    while let Some(job) = work.pop() {
        match job {
            Work::Visit(a, b) => {
                let an = kind.len(ctx, a)?;
                let bn = kind.len(ctx, b)?;
                if an == 0 || bn == 0 || ctx.same_object(a, b) {
                    results.push(match op {
                        Operation::Union => {
                            if an == 0 {
                                b
                            } else {
                                a
                            }
                        }
                        Operation::Intersection => {
                            if an == 0 || bn == 0 {
                                Value::EmptySet
                            } else {
                                a
                            }
                        }
                        Operation::Difference => {
                            if bn == 0 {
                                a
                            } else {
                                Value::EmptySet
                            }
                        }
                    });
                    continue;
                }
                let (pivot, al, ar, bl, br, keep) = if an <= bn {
                    let n = kind.node(ctx, a)?;
                    let (bl, found, br) = kind.split(ctx, b, n.key)?;
                    let keep = match op {
                        Operation::Union => true,
                        Operation::Intersection => found.is_some(),
                        Operation::Difference => found.is_none(),
                    };
                    (n, n.left, n.right, bl, br, keep)
                } else {
                    let n = kind.node(ctx, b)?;
                    let (al, found, ar) = kind.split(ctx, a, n.key)?;
                    let keep = match op {
                        Operation::Union => true,
                        Operation::Intersection => found.is_some(),
                        Operation::Difference => false,
                    };
                    (found.unwrap_or(n), al, ar, n.left, n.right, keep)
                };
                work.push(Work::Finish(pivot, keep));
                work.push(Work::Visit(ar, br));
                work.push(Work::Visit(al, bl));
            }
            Work::Finish(pivot, keep) => {
                let right = results.pop().ok_or_else(invalid)?;
                let left = results.pop().ok_or_else(invalid)?;
                results.push(if keep {
                    kind.join(ctx, pivot, left, right)?
                } else {
                    kind.join2(ctx, left, right)?
                });
            }
        }
    }
    results.pop().ok_or_else(invalid)
}
