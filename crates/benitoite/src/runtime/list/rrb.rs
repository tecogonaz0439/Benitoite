//! RRB 木の不変なノードと道筋の操作（設計書 03-06「List の内部の表現」、実装プラン R36）。

use super::{Stop, Value, ValueCtx, invalid_list};
use crate::runtime::heap::FieldsKind;

pub(super) const WIDTH: usize = 32;
pub(super) const BITS: u32 = 5;
/// 頭と正規化した根に認める最大のシフト量（実装プラン R36）。
pub(super) const MAX_SHIFT: u32 = 25;
pub(super) const HEAD: u32 = 0;
const STRICT: u32 = 1;
const RELAXED: u32 = 2;
const LEAF: u32 = 3;
const E_MAX: usize = 2;

// 大きさは親の累積表か頭から受け取る。厳密な子の大きさを知るために子孫を再走査しない。
#[derive(Clone, Copy)]
/// 区間内の部分木。要素数は親から渡し、子孫全体の再走査を避ける。
pub(super) struct Tree<'e> {
    pub value: Value<'e>,
    pub shift: u32,
    pub size: u32,
}

fn add(a: u32, b: u32) -> Result<u32, Stop> {
    a.checked_add(b).ok_or_else(invalid_list)
}
fn sub(a: u32, b: u32) -> Result<u32, Stop> {
    a.checked_sub(b).ok_or_else(invalid_list)
}
fn index(i: usize) -> Result<u32, Stop> {
    u32::try_from(i).map_err(|_| invalid_list())
}
fn integer<'e>(ctx: &ValueCtx<'e>, value: Value<'e>, i: u32) -> Result<u32, Stop> {
    ctx.field(value, i)
        .and_then(Value::as_int)
        .and_then(|n| u32::try_from(n).ok())
        .ok_or_else(invalid_list)
}
fn capacity(shift: u32) -> Result<u32, Stop> {
    1_u32.checked_shl(shift).ok_or_else(invalid_list)
}
fn role<'e>(ctx: &ValueCtx<'e>, tree: Tree<'e>) -> Result<u32, Stop> {
    let (kind, tag) = ctx.fields_header(tree.value).ok_or_else(invalid_list)?;
    if kind != FieldsKind::ListNode || tag >> 2 != tree.shift {
        return Err(invalid_list());
    }
    Ok(tag & 3)
}

/// 要素の小さい並びから、不変な葉を作る。
pub(super) fn leaf<'e>(ctx: &ValueCtx<'e>, items: &[Value<'e>]) -> Result<Tree<'e>, Stop> {
    if items.is_empty() || items.len() > WIDTH {
        return Err(invalid_list());
    }
    let size = index(items.len())?;
    let value = ctx.alloc_fields(FieldsKind::ListNode, LEAF, items)?;
    debug_assert_eq!(ctx.fields_len(value), Some(size));
    Ok(Tree {
        value,
        shift: 0,
        size,
    })
}

/// 末尾の欄が正しい葉を指すことを確かめる。
pub(super) fn leaf_tree<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<Tree<'e>, Stop> {
    let size = ctx.fields_len(value).ok_or_else(invalid_list)?;
    let tree = Tree {
        value,
        shift: 0,
        size,
    };
    if role(ctx, tree)? != LEAF || !(1..=32).contains(&size) {
        return Err(invalid_list());
    }
    Ok(tree)
}

/// 一つの葉の要素だけを読み出す。
pub(super) fn elements<'e>(ctx: &ValueCtx<'e>, tree: Tree<'e>) -> Result<Vec<Value<'e>>, Stop> {
    if role(ctx, tree)? != LEAF || ctx.fields_len(tree.value) != Some(tree.size) {
        return Err(invalid_list());
    }
    (0..tree.size)
        .map(|i| ctx.field(tree.value, i).ok_or_else(invalid_list))
        .collect()
}

/// 親の大きさと累積表から、直下の子の大きさを求める。
pub(super) fn children<'e>(ctx: &ValueCtx<'e>, tree: Tree<'e>) -> Result<Vec<Tree<'e>>, Stop> {
    let role = role(ctx, tree)?;
    let fields = ctx.fields_len(tree.value).ok_or_else(invalid_list)?;
    let count = match role {
        STRICT => fields,
        RELAXED if fields % 2 == 0 => fields / 2,
        _ => return Err(invalid_list()),
    };
    if !(1..=32).contains(&count) || tree.shift < BITS {
        return Err(invalid_list());
    }
    let child_shift = sub(tree.shift, BITS)?;
    let full = capacity(tree.shift)?;
    let mut previous = 0;
    let mut result = Vec::with_capacity(usize::try_from(count).map_err(|_| invalid_list())?);
    for i in 0..count {
        let end = if role == RELAXED {
            integer(ctx, tree.value, add(count, i)?)?
        } else if add(i, 1)? == count {
            tree.size
        } else {
            add(i, 1)?.checked_mul(full).ok_or_else(invalid_list)?
        };
        let size = sub(end, previous)?;
        if size == 0 || size > full {
            return Err(invalid_list());
        }
        result.push(Tree {
            value: ctx.field(tree.value, i).ok_or_else(invalid_list)?,
            shift: child_shift,
            size,
        });
        previous = end;
    }
    if previous != tree.size {
        return Err(invalid_list());
    }
    Ok(result)
}

/// 同じ高さの子からノードを作り、直下の不変条件を確かめる。
pub(super) fn branch<'e>(
    ctx: &ValueCtx<'e>,
    nodes: &[Tree<'e>],
    relaxed: bool,
) -> Result<Tree<'e>, Stop> {
    if nodes.is_empty() || nodes.len() > WIDTH {
        return Err(invalid_list());
    }
    let child_shift = nodes.first().ok_or_else(invalid_list)?.shift;
    let shift = add(child_shift, BITS)?;
    let full = capacity(shift)?;
    let mut strict = !relaxed;
    let mut size = 0;
    let mut values = Vec::with_capacity(64);
    let mut sizes = Vec::with_capacity(WIDTH);
    for (i, node) in nodes.iter().enumerate() {
        if node.shift != child_shift || node.size == 0 || node.size > full {
            return Err(invalid_list());
        }
        if i.checked_add(1).ok_or_else(invalid_list)? < nodes.len() && node.size != full {
            strict = false;
        }
        size = add(size, node.size)?;
        values.push(node.value);
        sizes.push(Value::Int(i64::from(size)));
    }
    let kind = if strict { STRICT } else { RELAXED };
    if !strict {
        values.extend(sizes);
    }
    let tag = shift.checked_shl(2).ok_or_else(invalid_list)? | kind;
    let value = ctx.alloc_fields(FieldsKind::ListNode, tag, &values)?;
    let tree = Tree { value, shift, size };
    // 新しいノードの直下だけを検査する。共有した子孫全体は辿らない（R36「共通の規則」）。
    debug_assert!(valid_local(ctx, tree));
    Ok(tree)
}

fn valid_local<'e>(ctx: &ValueCtx<'e>, tree: Tree<'e>) -> bool {
    let Ok(nodes) = children(ctx, tree) else {
        return false;
    };
    let mut total = 0_u32;
    for child in nodes {
        let Ok(r) = role(ctx, child) else {
            return false;
        };
        // 子の実際の大きさも、葉・累積表・厳密な最右道筋から独立に求める。
        let actual = match r {
            LEAF => ctx.fields_len(child.value),
            RELAXED => ctx
                .fields_len(child.value)
                .and_then(|n| n.checked_sub(1))
                .and_then(|i| integer(ctx, child.value, i).ok()),
            STRICT => strict_size(ctx, child).ok(),
            _ => None,
        };
        if actual != Some(child.size) {
            return false;
        }
        let Some(next) = total.checked_add(child.size) else {
            return false;
        };
        total = next;
    }
    total == tree.size
}

fn strict_size<'e>(ctx: &ValueCtx<'e>, mut tree: Tree<'e>) -> Result<u32, Stop> {
    let mut prefix = 0_u32;
    loop {
        let r = role(ctx, tree)?;
        let n = ctx.fields_len(tree.value).ok_or_else(invalid_list)?;
        match r {
            LEAF => return add(prefix, n),
            RELAXED => return add(prefix, integer(ctx, tree.value, sub(n, 1)?)?),
            STRICT => {
                let last = sub(n, 1)?;
                prefix = add(
                    prefix,
                    last.checked_mul(capacity(tree.shift)?)
                        .ok_or_else(invalid_list)?,
                )?;
                tree.value = ctx.field(tree.value, last).ok_or_else(invalid_list)?;
                tree.shift = sub(tree.shift, BITS)?;
            }
            _ => return Err(invalid_list()),
        }
    }
}

/// 基数と累積表で一つの道筋を辿る。
pub(super) fn lookup<'e>(
    ctx: &ValueCtx<'e>,
    mut tree: Tree<'e>,
    mut i: u32,
) -> Result<Value<'e>, Stop> {
    if i >= tree.size {
        return Err(invalid_list());
    }
    while tree.shift != 0 {
        let r = role(ctx, tree)?;
        let fields = ctx.fields_len(tree.value).ok_or_else(invalid_list)?;
        let (child, offset, size) = match r {
            STRICT if (1..=32).contains(&fields) => {
                let full = capacity(tree.shift)?;
                let child = i >> tree.shift;
                let offset = child.checked_mul(full).ok_or_else(invalid_list)?;
                let size = if add(child, 1)? == fields {
                    sub(tree.size, offset)?
                } else {
                    full
                };
                (child, offset, size)
            }
            RELAXED if fields % 2 == 0 && (2..=64).contains(&fields) => {
                let n = fields / 2;
                // 各子は高々 full 要素なので、基数で選ぶ位置より左に目的の子はない。
                // 累積表をその位置から前へ調べる（R36「木の形」）。
                let first = i >> tree.shift;
                let mut previous = if first == 0 {
                    0
                } else {
                    integer(ctx, tree.value, add(n, sub(first, 1)?)?)?
                };
                let mut found = None;
                for child in first..n {
                    let end = integer(ctx, tree.value, add(n, child)?)?;
                    if i < end {
                        found = Some((child, previous, sub(end, previous)?));
                        break;
                    }
                    previous = end;
                }
                found.ok_or_else(invalid_list)?
            }
            _ => return Err(invalid_list()),
        };
        tree = Tree {
            value: ctx.field(tree.value, child).ok_or_else(invalid_list)?,
            shift: sub(tree.shift, BITS)?,
            size,
        };
        i = sub(i, offset)?;
    }
    if role(ctx, tree)? != LEAF {
        return Err(invalid_list());
    }
    ctx.field(tree.value, i).ok_or_else(invalid_list)
}

/// 子が一つの根と、根直下を一つに詰められる段を取り除く。
pub(super) fn normalize<'e>(ctx: &ValueCtx<'e>, mut tree: Tree<'e>) -> Result<Tree<'e>, Stop> {
    while tree.shift != 0 {
        if slot_count(ctx, tree)? == 1 {
            tree.value = ctx.field(tree.value, 0).ok_or_else(invalid_list)?;
            tree.shift = sub(tree.shift, BITS)?;
            continue;
        }
        // 厳密な根は最初の子が満ちているため、次の子と合わせて一つには詰められない。
        if role(ctx, tree)? == STRICT {
            break;
        }
        if tree.shift == BITS && tree.size > 32 {
            break;
        }
        let nodes = children(ctx, tree)?;
        if tree.shift == BITS {
            let mut items = Vec::with_capacity(WIDTH);
            for node in nodes {
                items.extend(elements(ctx, node)?);
            }
            tree = leaf(ctx, &items)?;
        } else {
            // cut の両境界に残る単子鎖を、別の切り出しとの連結で高さとして蓄積させない。
            // 根直下の子の欄が合計 32 個以内なら、孫を共有して一段縮める（実装プラン R36）。
            let mut count = 0_u32;
            for node in &nodes {
                count = add(count, slot_count(ctx, *node)?)?;
                if count > 32 {
                    break;
                }
            }
            if count > 32 {
                break;
            }
            let mut grandchildren = Vec::with_capacity(WIDTH);
            for node in nodes {
                grandchildren.extend(children(ctx, node)?);
            }
            tree = branch(ctx, &grandchildren, true)?;
        }
    }
    Ok(tree)
}

/// 右端の道筋だけを写し、末尾の葉を木へ押し込む。
pub(super) fn push_leaf<'e>(
    ctx: &ValueCtx<'e>,
    root: Option<Tree<'e>>,
    tail: Tree<'e>,
) -> Result<Tree<'e>, Stop> {
    let Some(mut tree) = root else {
        return Ok(tail);
    };
    let mut path = Vec::new();
    while tree.shift != 0 {
        let mut nodes = children(ctx, tree)?;
        tree = nodes.pop().ok_or_else(invalid_list)?;
        path.push(nodes);
    }
    let mut carry = vec![tree, tail];
    while let Some(mut nodes) = path.pop() {
        nodes.extend(carry);
        carry = nodes
            .chunks(WIDTH)
            .map(|chunk| branch(ctx, chunk, false))
            .collect::<Result<_, _>>()?;
    }
    let root = if carry.len() == 1 {
        *carry.first().ok_or_else(invalid_list)?
    } else {
        branch(ctx, &carry, false)?
    };
    let root = normalize(ctx, root)?;
    debug_assert!(root.shift <= MAX_SHIFT);
    Ok(root)
}

// 各高さでノードの個数 r と、そのノードが持つ子の数 s を数える。
// r > ceil(s / 32) + 2 のときだけ詰め直す。満ちたノードが詰め直しの区切りにあれば共有する。
fn slot_count<'e>(ctx: &ValueCtx<'e>, tree: Tree<'e>) -> Result<u32, Stop> {
    let fields = ctx.fields_len(tree.value).ok_or_else(invalid_list)?;
    let count = match role(ctx, tree)? {
        LEAF if tree.shift == 0 && fields == tree.size => fields,
        STRICT if tree.shift >= BITS => fields,
        RELAXED if tree.shift >= BITS && fields % 2 == 0 => fields / 2,
        _ => return Err(invalid_list()),
    };
    if !(1..=32).contains(&count) {
        return Err(invalid_list());
    }
    Ok(count)
}

fn rebalance<'e>(ctx: &ValueCtx<'e>, nodes: Vec<Tree<'e>>) -> Result<Vec<Tree<'e>>, Stop> {
    let shift = nodes.first().ok_or_else(invalid_list)?.shift;
    let mut slots = 0_usize;
    for node in &nodes {
        if node.shift != shift {
            return Err(invalid_list());
        }
        // 個数だけなら累積表と子の Vec は要らない。詰め直すと決めてから読む（実装プラン R36）。
        let count = usize::try_from(slot_count(ctx, *node)?).map_err(|_| invalid_list())?;
        slots = slots.checked_add(count).ok_or_else(invalid_list)?;
    }
    let ideal = slots.div_ceil(WIDTH);
    let bound = ideal.checked_add(E_MAX).ok_or_else(invalid_list)?;
    if nodes.len() <= bound {
        return Ok(nodes);
    }
    let mut result = Vec::with_capacity(ideal);
    let mut leaf_buffer = Vec::with_capacity(WIDTH);
    let mut branch_buffer = Vec::with_capacity(WIDTH);
    for node in nodes {
        if shift == 0 {
            if leaf_buffer.is_empty() && node.size == 32 {
                result.push(node);
                continue;
            }
            for item in elements(ctx, node)? {
                leaf_buffer.push(item);
                if leaf_buffer.len() == WIDTH {
                    result.push(leaf(ctx, &leaf_buffer)?);
                    leaf_buffer.clear();
                }
            }
        } else {
            if branch_buffer.is_empty() && slot_count(ctx, node)? == 32 {
                result.push(node);
                continue;
            }
            let items = children(ctx, node)?;
            for item in items {
                branch_buffer.push(item);
                if branch_buffer.len() == WIDTH {
                    result.push(branch(ctx, &branch_buffer, false)?);
                    branch_buffer.clear();
                }
            }
        }
    }
    if !leaf_buffer.is_empty() {
        result.push(leaf(ctx, &leaf_buffer)?);
    }
    if !branch_buffer.is_empty() {
        result.push(branch(ctx, &branch_buffer, false)?);
    }
    debug_assert!(result.len() <= bound);
    debug_assert_eq!(result.len(), ideal);
    Ok(result)
}

/// 両側の境界の道筋を下から結合し、必要な段を詰め直す。
pub(super) fn join<'e>(
    ctx: &ValueCtx<'e>,
    mut a: Tree<'e>,
    mut b: Tree<'e>,
) -> Result<Tree<'e>, Stop> {
    while a.shift < b.shift {
        a = branch(ctx, &[a], false)?;
    }
    while b.shift < a.shift {
        b = branch(ctx, &[b], false)?;
    }
    let mut path = Vec::new();
    while a.shift != 0 {
        let mut left = children(ctx, a)?;
        let right = children(ctx, b)?;
        a = left.pop().ok_or_else(invalid_list)?;
        b = *right.first().ok_or_else(invalid_list)?;
        path.push((left, right.into_iter().skip(1).collect::<Vec<_>>()));
    }
    let mut items = elements(ctx, a)?;
    items.extend(elements(ctx, b)?);
    let mut middle = items
        .chunks(WIDTH)
        .map(|c| leaf(ctx, c))
        .collect::<Result<Vec<_>, _>>()?;
    while let Some((mut left, right)) = path.pop() {
        left.extend(middle);
        left.extend(right);
        let nodes = rebalance(ctx, left)?;
        middle = nodes
            .chunks(WIDTH)
            .map(|c| branch(ctx, c, false))
            .collect::<Result<_, _>>()?;
    }
    let root = if middle.len() == 1 {
        *middle.first().ok_or_else(invalid_list)?
    } else {
        branch(ctx, &middle, false)?
    };
    let root = normalize(ctx, root)?;
    debug_assert!(root.shift <= MAX_SHIFT);
    Ok(root)
}

/// 切る両境界以外の部分木を共有して、範囲を取り出す。
pub(super) fn cut<'e>(
    ctx: &ValueCtx<'e>,
    root: Tree<'e>,
    start: u32,
    end: u32,
) -> Result<Tree<'e>, Stop> {
    enum Work<'e> {
        Visit(Tree<'e>, u32, u32),
        Build(usize),
    }
    let mut pending = vec![Work::Visit(root, start, end)];
    let mut ready = Vec::new();
    while let Some(work) = pending.pop() {
        match work {
            Work::Visit(tree, start, end) => {
                if start == 0 && end == tree.size {
                    ready.push(tree);
                } else if tree.shift == 0 {
                    let items = elements(ctx, tree)?;
                    let range = usize::try_from(start).map_err(|_| invalid_list())?
                        ..usize::try_from(end).map_err(|_| invalid_list())?;
                    ready.push(leaf(ctx, items.get(range).ok_or_else(invalid_list)?)?);
                } else {
                    let mut visits = Vec::new();
                    let mut offset = 0;
                    for child in children(ctx, tree)? {
                        let next = add(offset, child.size)?;
                        if start < next && end > offset {
                            visits.push(Work::Visit(
                                child,
                                start.saturating_sub(offset),
                                end.min(next).checked_sub(offset).ok_or_else(invalid_list)?,
                            ));
                        }
                        offset = next;
                    }
                    pending.push(Work::Build(visits.len()));
                    pending.extend(visits.into_iter().rev());
                }
            }
            Work::Build(count) => {
                let first = ready.len().checked_sub(count).ok_or_else(invalid_list)?;
                let nodes = ready.split_off(first);
                ready.push(branch(ctx, &nodes, true)?);
            }
        }
    }
    if ready.len() != 1 {
        return Err(invalid_list());
    }
    normalize(ctx, ready.pop().ok_or_else(invalid_list)?)
}

/// 右端の道筋から末尾の葉を外し、残りの根を縮める。
pub(super) fn pop_leaf<'e>(
    ctx: &ValueCtx<'e>,
    mut tree: Tree<'e>,
) -> Result<(Option<Tree<'e>>, Tree<'e>), Stop> {
    let mut path = Vec::new();
    while tree.shift != 0 {
        let mut nodes = children(ctx, tree)?;
        tree = nodes.pop().ok_or_else(invalid_list)?;
        path.push(nodes);
    }
    let tail = tree;
    let mut remaining = None;
    while let Some(mut nodes) = path.pop() {
        if let Some(node) = remaining {
            nodes.push(node);
        }
        remaining = if nodes.is_empty() {
            None
        } else {
            // 右端だけの除去は、最後以外の子の充足を壊さない。形に応じて厳密にする（R36）。
            Some(branch(ctx, &nodes, false)?)
        };
    }
    Ok((
        remaining.map(|root| normalize(ctx, root)).transpose()?,
        tail,
    ))
}

/// 葉を順に訪ねる走査。言語の要素に含まれるリストへは降りない。
pub(crate) struct Cursor<'e> {
    pending: Vec<Tree<'e>>,
    leaf: Option<Tree<'e>>,
    index: u32,
}
impl<'e> Cursor<'e> {
    pub(super) fn new(root: Option<Tree<'e>>, tail: Option<Tree<'e>>) -> Self {
        let mut pending = Vec::new();
        pending.extend(tail);
        pending.extend(root);
        Self {
            pending,
            leaf: None,
            index: 0,
        }
    }
    /// 次の要素。走査だけではヒープの対象を確保しない（R36「作るもの」）。
    pub(crate) fn next(&mut self, ctx: &ValueCtx<'e>) -> Result<Option<Value<'e>>, Stop> {
        loop {
            if let Some(tree) = self.leaf {
                if self.index < tree.size {
                    let item = ctx.field(tree.value, self.index).ok_or_else(invalid_list)?;
                    self.index = add(self.index, 1)?;
                    return Ok(Some(item));
                }
                self.leaf = None;
            }
            let Some(tree) = self.pending.pop() else {
                return Ok(None);
            };
            if tree.shift == 0 {
                if role(ctx, tree)? != LEAF || ctx.fields_len(tree.value) != Some(tree.size) {
                    return Err(invalid_list());
                }
                self.leaf = Some(tree);
                self.index = 0;
            } else {
                self.pending.extend(children(ctx, tree)?.into_iter().rev());
            }
        }
    }
}
