//! 鍵の辞書式比較（設計書 03-06「Map と Set（初回リリース版）」）。
//! 基本型の葉は定数評価器と同じ関数で比べ、複合の鍵は仕事の積み重ねで辿る。

use super::tree::invalid;
use super::{Cursor, Stop, Value, ValueCtx};
use crate::base::prim::{KeyAtom, cmp_key_atom};
use crate::runtime::{
    heap::{FieldsKind, ObjKind},
    list,
};
use std::cmp::Ordering;

enum Work<'e> {
    Values(Value<'e>, Value<'e>),
    Order(Ordering),
    Lists(list::Cursor<'e>, list::Cursor<'e>),
    Trees(Cursor<'e>, Cursor<'e>, bool),
}

fn atom<'c, 'e>(ctx: &'c ValueCtx<'e>, v: Value<'e>) -> Option<KeyAtom<'c>> {
    match v {
        Value::Unit => Some(KeyAtom::Unit),
        Value::Int(n) => Some(KeyAtom::Integer(n)),
        Value::Byte(n) => Some(KeyAtom::Byte(n)),
        Value::Bool(b) => Some(KeyAtom::Boolean(b)),
        Value::Char(c) => Some(KeyAtom::Character(c)),
        Value::Obj(_) => match ctx.kind(v)? {
            ObjKind::Str => ctx.str(v).map(KeyAtom::String),
            ObjKind::Bytes => ctx.bytes(v).map(KeyAtom::Bytes),
            ObjKind::Decimal => ctx.decimal(v).map(KeyAtom::Decimal),
            ObjKind::Fields(_) | ObjKind::Cell | ObjKind::Opaque | ObjKind::Host => None,
        },
        Value::Float(_)
        | Value::Tag(_)
        | Value::Resource(_)
        | Value::EmptyList
        | Value::EmptyMap
        | Value::EmptySet => None,
    }
}

fn ctor<'e>(ctx: &ValueCtx<'e>, v: Value<'e>) -> Option<(u32, u32)> {
    if let Value::Tag(tag) = v {
        Some((tag.0, 0))
    } else {
        let (kind, tag) = ctx.fields_header(v)?;
        (kind == FieldsKind::Ctor).then_some((tag, ctx.fields_len(v)?))
    }
}
fn is_tree<'e>(ctx: &ValueCtx<'e>, v: Value<'e>, map: bool) -> bool {
    if map {
        matches!(v, Value::EmptyMap) || ctx.kind(v) == Some(ObjKind::Fields(FieldsKind::MapNode))
    } else {
        matches!(v, Value::EmptySet) || ctx.kind(v) == Some(ObjKind::Fields(FieldsKind::SetNode))
    }
}

pub(super) fn compare<'e>(
    ctx: &ValueCtx<'e>,
    a: Value<'e>,
    b: Value<'e>,
) -> Result<Ordering, Stop> {
    let mut pending = vec![Work::Values(a, b)];
    while let Some(work) = pending.pop() {
        let order = match work {
            Work::Order(order) => order,
            Work::Lists(mut a, mut b) => match (a.next(ctx)?, b.next(ctx)?) {
                (None, None) => Ordering::Equal,
                (None, Some(_)) => Ordering::Less,
                (Some(_), None) => Ordering::Greater,
                (Some(x), Some(y)) => {
                    pending.push(Work::Lists(a, b));
                    pending.push(Work::Values(x, y));
                    Ordering::Equal
                }
            },
            Work::Trees(mut a, mut b, map) => match (a.next(ctx)?, b.next(ctx)?) {
                (None, None) => Ordering::Equal,
                (None, Some(_)) => Ordering::Less,
                (Some(_), None) => Ordering::Greater,
                (Some((ak, av)), Some((bk, bv))) => {
                    pending.push(Work::Trees(a, b, map));
                    if map {
                        pending.push(Work::Values(av, bv));
                    }
                    pending.push(Work::Values(ak, bk));
                    Ordering::Equal
                }
            },
            Work::Values(a, b) => {
                if let (Some(a), Some(b)) = (atom(ctx, a), atom(ctx, b)) {
                    cmp_key_atom(a, b).ok_or_else(invalid)?
                } else if let (Some((at, an)), Some((bt, bn))) = (ctor(ctx, a), ctor(ctx, b)) {
                    let tag_order = at.cmp(&bt);
                    if tag_order == Ordering::Equal {
                        pending.push(Work::Order(an.cmp(&bn)));
                        for i in (0..an.min(bn)).rev() {
                            pending.push(Work::Values(
                                ctx.field(a, i).ok_or_else(invalid)?,
                                ctx.field(b, i).ok_or_else(invalid)?,
                            ));
                        }
                    }
                    tag_order
                } else if list::is_list(ctx, a) && list::is_list(ctx, b) {
                    pending.push(Work::Lists(list::cursor(ctx, a)?, list::cursor(ctx, b)?));
                    Ordering::Equal
                } else if is_tree(ctx, a, true) && is_tree(ctx, b, true) {
                    pending.push(Work::Trees(Cursor::map(a), Cursor::map(b), true));
                    Ordering::Equal
                } else if is_tree(ctx, a, false) && is_tree(ctx, b, false) {
                    pending.push(Work::Trees(Cursor::set(a), Cursor::set(b), false));
                    Ordering::Equal
                } else {
                    return Err(invalid());
                }
            }
        };
        if order != Ordering::Equal {
            return Ok(order);
        }
    }
    Ok(Ordering::Equal)
}
