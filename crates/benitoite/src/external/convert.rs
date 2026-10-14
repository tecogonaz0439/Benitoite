//! 外部の関数との値の受け渡し（設計書 03-10「型の対応」、02-09「外部の関数の実行」）。
//! 子の変換を明示の作業列に積み、値の長さや入れ子で Rust のスタックを増やさない。

use super::runtime::{ExternalHandle, ExternalHandles};
use super::{ExternalSpec, WitPlan};
use crate::builtins::table::tags;
use crate::runtime::heap::{CheckedLen, CtorTag, FieldsKind, NoGcCtx, Value};
use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit, Stop, list, map};
use std::rc::Rc;
use wasmtime::component::Val;

/// 照合済みの変換表と実行時の値の不一致は処理系の不具合にする。
pub(super) fn invalid() -> Stop {
    Stop::Internal("external value does not match conversion plan".into())
}
fn field<'e>(ctx: &NoGcCtx<'e>, value: Value<'e>, i: usize) -> Result<Value<'e>, Stop> {
    ctx.field(value, u32::try_from(i).map_err(|_| invalid())?)
        .ok_or_else(invalid)
}
fn ctor_tag<'e>(ctx: &NoGcCtx<'e>, value: Value<'e>) -> Result<u32, Stop> {
    match value {
        Value::Tag(CtorTag(tag)) => Ok(tag),
        Value::Obj(_) => match ctx.fields_header(value) {
            Some((FieldsKind::Ctor, tag)) => Ok(tag),
            _ => Err(invalid()),
        },
        Value::Int(_)
        | Value::Int8(_)
        | Value::Int16(_)
        | Value::Int32(_)
        | Value::UInt16(_)
        | Value::UInt32(_)
        | Value::UInt64(_)
        | Value::Float32(_)
        | Value::Float(_)
        | Value::Byte(_)
        | Value::Bool(_)
        | Value::Char(_)
        | Value::Unit
        | Value::Resource(_)
        | Value::EmptyList
        | Value::EmptyMap
        | Value::EmptySet => Err(invalid()),
    }
}

fn variant_case<'a, 'e>(
    ctx: &NoGcCtx<'e>,
    cases: &'a [(String, u32, Option<Box<WitPlan>>)],
    value: Value<'e>,
) -> Result<(&'a str, Option<&'a WitPlan>), Stop> {
    let tag = ctor_tag(ctx, value)?;
    let (name, _, payload) = cases
        .iter()
        .find(|(_, t, _)| *t == tag)
        .ok_or_else(invalid)?;
    match payload {
        None if matches!(value, Value::Tag(_)) => Ok((name, None)),
        Some(p) => {
            let count = if let WitPlan::TupleFields(fields) = p.as_ref() {
                fields.len()
            } else {
                1
            };
            if ctx.fields_len(value).and_then(|n| usize::try_from(n).ok()) == Some(count) {
                Ok((name, Some(p)))
            } else {
                Err(invalid())
            }
        }
        _ => Err(invalid()),
    }
}

fn enum_case<'a>(cases: &'a [(String, u32)], value: Value<'_>) -> Result<&'a str, Stop> {
    let Value::Tag(CtorTag(tag)) = value else {
        return Err(invalid());
    };
    cases
        .iter()
        .find(|(_, t)| *t == tag)
        .map(|(name, _)| name.as_str())
        .ok_or_else(invalid)
}

fn tuple_fields<'a, 'e>(
    ctx: &NoGcCtx<'e>,
    fields: &'a [WitPlan],
    value: Value<'e>,
) -> Result<Vec<(&'a WitPlan, Value<'e>)>, Stop> {
    if ctx.fields_len(value).and_then(|n| usize::try_from(n).ok()) != Some(fields.len()) {
        return Err(invalid());
    }
    fields
        .iter()
        .enumerate()
        .map(|(i, p)| Ok((p, field(ctx, value, i)?)))
        .collect()
}

fn children<'a, 'e>(
    ctx: &NoGcCtx<'e>,
    plan: &'a WitPlan,
    value: Value<'e>,
) -> Result<Vec<(&'a WitPlan, Value<'e>)>, Stop> {
    Ok(match plan {
        WitPlan::List(p) => list::to_vec(ctx, value)?
            .into_iter()
            .map(|v| (p.as_ref(), v))
            .collect(),
        WitPlan::Tuple(ps) => ps
            .iter()
            .enumerate()
            .map(|(i, p)| Ok((p, field(ctx, value, i)?)))
            .collect::<Result<_, Stop>>()?,
        WitPlan::ConstructorTuple { tag, fields } => {
            if ctor_tag(ctx, value)? != *tag {
                return Err(invalid());
            }
            tuple_fields(ctx, fields, value)?
        }
        WitPlan::TupleFields(fields) => tuple_fields(ctx, fields, value)?,
        WitPlan::Record { fields } => {
            if ctx.fields_header(value) != Some((FieldsKind::Ctor, tags::RECORD))
                || usize::try_from(ctx.fields_len(value).ok_or_else(invalid)?)
                    .map_err(|_| invalid())?
                    != fields.len()
            {
                return Err(invalid());
            }
            fields
                .iter()
                .enumerate()
                .map(|(i, (_, p))| Ok((p, field(ctx, value, i)?)))
                .collect::<Result<_, Stop>>()?
        }
        WitPlan::Variant { cases } => match variant_case(ctx, cases, value)?.1 {
            Some(p @ WitPlan::TupleFields(_)) => vec![(p, value)],
            Some(p) => vec![(p, field(ctx, value, 0)?)],
            None => vec![],
        },
        WitPlan::Enum { cases } => {
            enum_case(cases, value)?;
            vec![]
        }
        WitPlan::Flags { .. } => vec![],
        WitPlan::Map(_, _) => vec![],
        WitPlan::Option(p) => {
            if matches!(value, Value::Tag(CtorTag(tags::OPTION_NONE))) {
                vec![]
            } else if ctx.fields_header(value) == Some((FieldsKind::Ctor, tags::OPTION_SOME)) {
                vec![(p.as_ref(), field(ctx, value, 0)?)]
            } else {
                return Err(invalid());
            }
        }
        WitPlan::Result { ok, err } => {
            let Some((FieldsKind::Ctor, tag)) = ctx.fields_header(value) else {
                return Err(invalid());
            };
            let p = if tag == tags::RESULT_OK {
                ok
            } else if tag == tags::RESULT_ERROR {
                err
            } else {
                return Err(invalid());
            };
            match p {
                Some(p) => vec![(p.as_ref(), field(ctx, value, 0)?)],
                None => {
                    if !matches!(field(ctx, value, 0)?, Value::Unit) {
                        return Err(invalid());
                    }
                    vec![]
                }
            }
        }
        WitPlan::Own(_)
        | WitPlan::Borrow(_)
        | WitPlan::S8
        | WitPlan::S16
        | WitPlan::S32
        | WitPlan::U16
        | WitPlan::U32
        | WitPlan::U64
        | WitPlan::F32
        | WitPlan::S64
        | WitPlan::F64
        | WitPlan::Bool
        | WitPlan::Char
        | WitPlan::String
        | WitPlan::U8
        | WitPlan::Bytes => vec![],
    })
}

/// `Val` の並びを確保する前に、ゲストへ渡す合計の大きさを調べる。
pub(super) fn check_arguments<'e>(
    ctx: &NoGcCtx<'e>,
    spec: &ExternalSpec,
    args: &[Value<'e>],
    limit: u64,
) -> Result<u64, Stop> {
    if spec.params.len() != args.len() {
        return Err(invalid());
    }
    // カーソルを作業列に残し、長いリストを予算の検査のためだけに複製しない。
    enum Work<'a, 'e> {
        Value(&'a WitPlan, Value<'e>),
        List(&'a WitPlan, list::Cursor<'e>),
        Flags(&'a [(String, u32)], map::Cursor<'e>),
        Map(&'a WitPlan, &'a WitPlan, map::Cursor<'e>),
    }
    let mut work: Vec<_> = spec
        .params
        .iter()
        .zip(args.iter().copied())
        .map(|(p, v)| Work::Value(p, v))
        .collect();
    let mut total = 0_u64;
    let val_size = u64::try_from(std::mem::size_of::<Val>()).map_err(|_| invalid())?;
    while let Some(task) = work.pop() {
        let (p, v) = match task {
            Work::Value(p, v) => (p, v),
            Work::Map(key, value, mut cursor) => {
                if let Some((k, v)) = cursor.next(ctx)? {
                    work.push(Work::Map(key, value, cursor));
                    work.push(Work::Value(value, v));
                    work.push(Work::Value(key, k));
                }
                continue;
            }
            Work::List(p, mut cursor) => {
                if let Some(v) = cursor.next(ctx)? {
                    work.push(Work::List(p, cursor));
                    work.push(Work::Value(p, v));
                }
                continue;
            }
            Work::Flags(cases, mut cursor) => {
                if let Some((value, _)) = cursor.next(ctx)? {
                    let name = enum_case(cases, value)?;
                    total = total.saturating_add(u64::try_from(name.len()).map_err(|_| invalid())?);
                    if total > limit {
                        return Err(Stop::Resource(ResourceError::ExternalTransfer {
                            function: spec.function.clone(),
                            component: spec.component.display.clone(),
                            limit,
                        }));
                    }
                    work.push(Work::Flags(cases, cursor));
                }
                continue;
            }
        };
        let size = |n: usize| u64::try_from(n).map_err(|_| invalid());
        let (cost, nested) = match p {
            WitPlan::String => (size(ctx.str(v).ok_or_else(invalid)?.len())?, vec![]),
            WitPlan::Bytes => (
                size(ctx.bytes(v).ok_or_else(invalid)?.len())?.saturating_mul(val_size),
                vec![],
            ),
            WitPlan::List(inner) => {
                let cost = u64::from(list::len(ctx, v)?).saturating_mul(val_size);
                // 長さの予算を確かめた後にだけ、要素の走査を始める。
                work.push(Work::List(inner, list::cursor(ctx, v)?));
                (cost, vec![])
            }
            WitPlan::Map(key, value) => {
                let pair_size = size(std::mem::size_of::<(Val, Val)>())?;
                let cost = u64::from(map::map_len(ctx, v)?).saturating_mul(pair_size);
                work.push(Work::Map(key, value, map::map_cursor(ctx, v)?));
                (cost, vec![])
            }
            WitPlan::Record { fields } => {
                let nested = children(ctx, p, v)?;
                let names = fields.iter().try_fold(0_u64, |total, (name, _)| {
                    Ok::<_, Stop>(total.saturating_add(size(name.len())?))
                })?;
                (
                    size(fields.len())?
                        .saturating_mul(val_size)
                        .saturating_add(names),
                    nested,
                )
            }
            WitPlan::Variant { cases } => {
                let (name, payload) = variant_case(ctx, cases, v)?;
                (
                    size(name.len())?.saturating_add(if payload.is_some() { val_size } else { 0 }),
                    children(ctx, p, v)?,
                )
            }
            WitPlan::Enum { cases } => (size(enum_case(cases, v)?.len())?, vec![]),
            WitPlan::Flags { cases } => {
                work.push(Work::Flags(cases, map::set_cursor(ctx, v)?));
                (0, vec![])
            }
            WitPlan::Tuple(_)
            | WitPlan::ConstructorTuple { .. }
            | WitPlan::TupleFields(_)
            | WitPlan::Option(_)
            | WitPlan::Result { .. } => {
                let nested = children(ctx, p, v)?;
                (size(nested.len())?.saturating_mul(val_size), nested)
            }
            WitPlan::Own(_)
            | WitPlan::Borrow(_)
            | WitPlan::S8
            | WitPlan::S16
            | WitPlan::S32
            | WitPlan::U16
            | WitPlan::U32
            | WitPlan::U64
            | WitPlan::F32
            | WitPlan::S64
            | WitPlan::F64
            | WitPlan::Bool
            | WitPlan::Char
            | WitPlan::U8 => (0, vec![]),
        };
        total = total.saturating_add(cost);
        if total > limit {
            return Err(Stop::Resource(ResourceError::ExternalTransfer {
                function: spec.function.clone(),
                component: spec.component.display.clone(),
                limit,
            }));
        }
        work.extend(nested.into_iter().map(|(p, v)| Work::Value(p, v)));
    }
    Ok(total)
}

enum ToWasm<'a, 'e> {
    Visit(&'a WitPlan, Value<'e>),
    Build(&'a WitPlan, Value<'e>, usize),
    Map(&'a WitPlan, &'a WitPlan, map::Cursor<'e>, Vec<(Val, Val)>),
    MapPair(&'a WitPlan, &'a WitPlan, map::Cursor<'e>, Vec<(Val, Val)>),
}
fn take<T>(values: &mut Vec<T>, n: usize) -> Result<Vec<T>, Stop> {
    let start = values.len().checked_sub(n).ok_or_else(invalid)?;
    Ok(values.split_off(start))
}

pub(super) fn to_wasm<'e>(
    ctx: &NoGcCtx<'e>,
    plan: &WitPlan,
    value: Value<'e>,
    mut handles: Option<&mut ExternalHandles<'_>>,
) -> Result<Val, Stop> {
    let mut work = vec![ToWasm::Visit(plan, value)];
    let mut out = vec![];
    while let Some(task) = work.pop() {
        match task {
            ToWasm::Map(key, value, mut cursor, pairs) => {
                if let Some((k, v)) = cursor.next(ctx)? {
                    work.push(ToWasm::MapPair(key, value, cursor, pairs));
                    work.push(ToWasm::Visit(value, v));
                    work.push(ToWasm::Visit(key, k));
                } else {
                    out.push(Val::Map(pairs));
                }
            }
            ToWasm::MapPair(key, value, cursor, mut pairs) => {
                let v = out.pop().ok_or_else(invalid)?;
                let k = out.pop().ok_or_else(invalid)?;
                pairs.push((k, v));
                work.push(ToWasm::Map(key, value, cursor, pairs));
            }
            ToWasm::Visit(p, v) => {
                if let WitPlan::Map(key, value) = p {
                    work.push(ToWasm::Map(
                        key,
                        value,
                        map::map_cursor(ctx, v)?,
                        Vec::new(),
                    ));
                    continue;
                }
                let scalar = match p {
                    WitPlan::Borrow(resource) => {
                        let h = ctx.opaque::<ExternalHandle>(v).ok_or_else(invalid)?;
                        let state = handles.as_deref_mut().ok_or_else(invalid)?;
                        if h.component != state.component
                            || h.resource != *resource
                            || !Rc::ptr_eq(&h.queue, state.queue)
                        {
                            return Err(invalid());
                        }
                        let any = state
                            .handles
                            .get(usize::try_from(h.slot).map_err(|_| invalid())?)
                            .and_then(Option::as_ref)
                            .ok_or_else(invalid)?;
                        Some(Val::Resource(*any))
                    }
                    WitPlan::Own(_) => return Err(invalid()),
                    WitPlan::Flags { cases } => {
                        let mut cursor = map::set_cursor(ctx, v)?;
                        let mut names = Vec::new();
                        while let Some((value, _)) = cursor.next(ctx)? {
                            names.push(enum_case(cases, value)?.to_owned());
                        }
                        Some(Val::Flags(names))
                    }
                    WitPlan::S8 => Some(Val::S8(v.as_int8().ok_or_else(invalid)?)),
                    WitPlan::S16 => Some(Val::S16(v.as_int16().ok_or_else(invalid)?)),
                    WitPlan::S32 => Some(Val::S32(v.as_int32().ok_or_else(invalid)?)),
                    WitPlan::U16 => Some(Val::U16(v.as_uint16().ok_or_else(invalid)?)),
                    WitPlan::U32 => Some(Val::U32(v.as_uint32().ok_or_else(invalid)?)),
                    WitPlan::U64 => Some(Val::U64(v.as_uint64().ok_or_else(invalid)?)),
                    WitPlan::F32 => Some(Val::Float32(v.as_float32().ok_or_else(invalid)?)),
                    WitPlan::S64 => Some(Val::S64(v.as_int().ok_or_else(invalid)?)),
                    WitPlan::F64 => Some(Val::Float64(v.as_float().ok_or_else(invalid)?)),
                    WitPlan::Bool => Some(Val::Bool(v.as_bool().ok_or_else(invalid)?)),
                    WitPlan::Char => Some(Val::Char(v.as_char().ok_or_else(invalid)?)),
                    WitPlan::U8 => Some(Val::U8(v.as_byte().ok_or_else(invalid)?)),
                    WitPlan::String => {
                        Some(Val::String(ctx.str(v).ok_or_else(invalid)?.to_owned()))
                    }
                    WitPlan::Bytes => Some(Val::List(
                        ctx.bytes(v)
                            .ok_or_else(invalid)?
                            .iter()
                            .map(|b| Val::U8(*b))
                            .collect(),
                    )),
                    WitPlan::List(_)
                    | WitPlan::Map(_, _)
                    | WitPlan::Option(_)
                    | WitPlan::Result { .. }
                    | WitPlan::Tuple(_)
                    | WitPlan::ConstructorTuple { .. }
                    | WitPlan::TupleFields(_)
                    | WitPlan::Record { .. }
                    | WitPlan::Variant { .. }
                    | WitPlan::Enum { .. } => None,
                };
                if let Some(scalar) = scalar {
                    out.push(scalar);
                } else {
                    let nested = children(ctx, p, v)?;
                    work.push(ToWasm::Build(p, v, nested.len()));
                    work.extend(nested.into_iter().rev().map(|(p, v)| ToWasm::Visit(p, v)));
                }
            }
            ToWasm::Build(p, v, n) => {
                let mut values = take(&mut out, n)?;
                out.push(match p {
                    WitPlan::Record { fields } => Val::Record(
                        fields
                            .iter()
                            .map(|(name, _)| name.clone())
                            .zip(values)
                            .collect(),
                    ),
                    WitPlan::Variant { cases } => {
                        let (name, _) = variant_case(ctx, cases, v)?;
                        Val::Variant(name.to_owned(), values.pop().map(Box::new))
                    }
                    WitPlan::Enum { cases } => Val::Enum(enum_case(cases, v)?.to_owned()),
                    WitPlan::List(_) => Val::List(values),
                    WitPlan::Tuple(_)
                    | WitPlan::ConstructorTuple { .. }
                    | WitPlan::TupleFields(_) => Val::Tuple(values),
                    WitPlan::Option(_) => Val::Option(values.pop().map(Box::new)),
                    WitPlan::Result { .. } => {
                        let payload = values.pop().map(Box::new);
                        match ctx.fields_header(v) {
                            Some((FieldsKind::Ctor, tags::RESULT_OK)) => Val::Result(Ok(payload)),
                            Some((FieldsKind::Ctor, tags::RESULT_ERROR)) => {
                                Val::Result(Err(payload))
                            }
                            _ => return Err(invalid()),
                        }
                    }
                    WitPlan::Own(_)
                    | WitPlan::Map(_, _)
                    | WitPlan::Flags { .. }
                    | WitPlan::Borrow(_)
                    | WitPlan::S8
                    | WitPlan::S16
                    | WitPlan::S32
                    | WitPlan::U16
                    | WitPlan::U32
                    | WitPlan::U64
                    | WitPlan::F32
                    | WitPlan::S64
                    | WitPlan::F64
                    | WitPlan::Bool
                    | WitPlan::Char
                    | WitPlan::String
                    | WitPlan::U8
                    | WitPlan::Bytes => return Err(invalid()),
                });
            }
        }
    }
    if out.len() != 1 {
        return Err(invalid());
    }
    out.pop().ok_or_else(invalid)
}

/// ヒープの値を作る前に、外部の戻り値の大きさを制限する。
pub(super) fn check_size(
    spec: &ExternalSpec,
    size: usize,
    unit: SizeUnit,
    limit: u64,
) -> Result<(), Stop> {
    let size = u64::try_from(size).map_err(|_| invalid())?;
    if size > limit {
        return Err(Stop::Resource(ResourceError::ExternalValueTooLarge {
            function: spec.function.clone(),
            size,
            unit,
            limit,
        }));
    }
    Ok(())
}
enum FromWasm<'a, 'e> {
    Visit(&'a WitPlan, &'a Val),
    List(usize),
    Ctor(u32, usize),
    Map(&'a WitPlan, &'a WitPlan, &'a [(Val, Val)], Value<'e>),
    MapInsert(&'a WitPlan, &'a WitPlan, &'a [(Val, Val)], Value<'e>),
}

pub(super) fn from_wasm<'e>(
    ctx: &NoGcCtx<'e>,
    spec: &ExternalSpec,
    plan: &WitPlan,
    value: &Val,
    mut handles: Option<&mut ExternalHandles<'_>>,
) -> Result<Value<'e>, Stop> {
    let mut work = vec![FromWasm::Visit(plan, value)];
    let mut out = vec![];
    while let Some(task) = work.pop() {
        match task {
            FromWasm::Map(key, value, pairs, map) => {
                if let Some(((k, v), rest)) = pairs.split_first() {
                    work.push(FromWasm::MapInsert(key, value, rest, map));
                    work.push(FromWasm::Visit(value, v));
                    work.push(FromWasm::Visit(key, k));
                } else {
                    out.push(map);
                }
            }
            FromWasm::MapInsert(key, value, rest, map) => {
                let v = out.pop().ok_or_else(invalid)?;
                let k = out.pop().ok_or_else(invalid)?;
                // 消える値も変換してから挿入し、外部の対象の登録を省かない。
                let map = map::map_insert(ctx, map, k, v, "external result")?;
                work.push(FromWasm::Map(key, value, rest, map));
            }
            FromWasm::List(n) => {
                let vs = take(&mut out, n)?;
                out.push(list::from_values(ctx, &vs, "external result")?);
            }
            FromWasm::Ctor(tag, n) => {
                let vs = take(&mut out, n)?;
                out.push(ctx.alloc_fields(FieldsKind::Ctor, tag, &vs)?);
            }
            FromWasm::Visit(p, v) => match (p, v) {
                (WitPlan::Own(resource), Val::Resource(any)) => {
                    if !any.owned() {
                        return Err(invalid());
                    }
                    let state = handles.as_deref_mut().ok_or_else(invalid)?;
                    let slot = if let Some(slot) = state.free.pop() {
                        let target = state
                            .handles
                            .get_mut(usize::try_from(slot).map_err(|_| invalid())?)
                            .ok_or_else(invalid)?;
                        if target.is_some() {
                            return Err(invalid());
                        }
                        *target = Some(*any);
                        slot
                    } else {
                        let slot = u32::try_from(state.handles.len()).map_err(|_| invalid())?;
                        state.handles.push(Some(*any));
                        slot
                    };
                    out.push(ctx.alloc_opaque(ExternalHandle {
                        component: state.component,
                        resource: *resource,
                        slot,
                        queue: Rc::clone(state.queue),
                        growth: std::mem::take(&mut state.growth),
                    }));
                }
                (WitPlan::S8, Val::S8(v)) => out.push(Value::Int8(*v)),
                (WitPlan::S16, Val::S16(v)) => out.push(Value::Int16(*v)),
                (WitPlan::S32, Val::S32(v)) => out.push(Value::Int32(*v)),
                (WitPlan::U16, Val::U16(v)) => out.push(Value::UInt16(*v)),
                (WitPlan::U32, Val::U32(v)) => out.push(Value::UInt32(*v)),
                (WitPlan::U64, Val::U64(v)) => out.push(Value::UInt64(*v)),
                (WitPlan::F32, Val::Float32(v)) => out.push(Value::Float32(*v)),
                (WitPlan::S64, Val::S64(v)) => out.push(Value::Int(*v)),
                (WitPlan::F64, Val::Float64(v)) => out.push(Value::Float(*v)),
                (WitPlan::Bool, Val::Bool(v)) => out.push(Value::Bool(*v)),
                (WitPlan::Char, Val::Char(v)) => out.push(Value::Char(*v)),
                (WitPlan::U8, Val::U8(v)) => out.push(Value::Byte(*v)),
                (WitPlan::String, Val::String(s)) => {
                    check_size(spec, s.len(), SizeUnit::Bytes, MAX_STRING_BYTES)?;
                    out.push(
                        ctx.alloc_str_utf8(s.as_bytes(), "external result")?
                            .ok_or_else(invalid)?,
                    );
                }
                (WitPlan::Bytes, Val::List(vs)) => {
                    check_size(spec, vs.len(), SizeUnit::Bytes, MAX_STRING_BYTES)?;
                    let bytes = vs
                        .iter()
                        .map(|v| match v {
                            Val::U8(b) => Ok(*b),
                            Val::Bool(_)
                            | Val::S8(_)
                            | Val::S16(_)
                            | Val::U16(_)
                            | Val::S32(_)
                            | Val::U32(_)
                            | Val::S64(_)
                            | Val::U64(_)
                            | Val::Float32(_)
                            | Val::Float64(_)
                            | Val::Char(_)
                            | Val::String(_)
                            | Val::List(_)
                            | Val::Map(_)
                            | Val::Record(_)
                            | Val::Tuple(_)
                            | Val::Variant(_, _)
                            | Val::Enum(_)
                            | Val::Option(_)
                            | Val::Result(_)
                            | Val::Flags(_)
                            | Val::Resource(_)
                            | Val::Future(_)
                            | Val::Stream(_)
                            | Val::ErrorContext(_)
                            | Val::FixedLengthList(_) => Err(invalid()),
                        })
                        .collect::<Result<Vec<_>, _>>()?;
                    let len = CheckedLen::bytes(
                        u64::try_from(bytes.len()).map_err(|_| invalid())?,
                        "external result",
                    )?;
                    out.push(ctx.alloc_bytes_with(len, |dst| dst.copy_from_slice(&bytes))?);
                }
                (WitPlan::List(p), Val::List(vs)) => {
                    check_size(spec, vs.len(), SizeUnit::Elements, MAX_LIST_LEN)?;
                    work.push(FromWasm::List(vs.len()));
                    work.extend(vs.iter().rev().map(|v| FromWasm::Visit(p, v)));
                }
                (WitPlan::Map(key, value), Val::Map(pairs)) => {
                    work.push(FromWasm::Map(key, value, pairs, Value::EmptyMap));
                }
                (WitPlan::Tuple(ps), Val::Tuple(vs)) if ps.len() == vs.len() => {
                    let tag = match ps.len() {
                        2 => tags::PAIR,
                        3 => tags::TRIPLE,
                        _ => return Err(invalid()),
                    };
                    work.push(FromWasm::Ctor(tag, vs.len()));
                    work.extend(ps.iter().zip(vs).rev().map(|(p, v)| FromWasm::Visit(p, v)));
                }
                (WitPlan::ConstructorTuple { tag, fields }, Val::Tuple(vs))
                    if fields.len() == vs.len() =>
                {
                    work.push(FromWasm::Ctor(*tag, vs.len()));
                    work.extend(
                        fields
                            .iter()
                            .zip(vs)
                            .rev()
                            .map(|(p, v)| FromWasm::Visit(p, v)),
                    );
                }
                (WitPlan::Record { fields }, Val::Record(vs)) if fields.len() == vs.len() => {
                    work.push(FromWasm::Ctor(tags::RECORD, vs.len()));
                    for ((name, p), (actual, v)) in fields.iter().zip(vs).rev() {
                        if name != actual {
                            return Err(invalid());
                        }
                        work.push(FromWasm::Visit(p, v));
                    }
                }
                (WitPlan::Variant { cases }, Val::Variant(name, payload)) => {
                    let (_, tag, p) = cases
                        .iter()
                        .find(|(n, _, _)| n == name)
                        .ok_or_else(invalid)?;
                    match (p, payload) {
                        (None, None) => out.push(Value::Tag(CtorTag(*tag))),
                        (Some(p), Some(v)) if matches!(p.as_ref(), WitPlan::TupleFields(_)) => {
                            let (WitPlan::TupleFields(fields), Val::Tuple(vs)) =
                                (p.as_ref(), v.as_ref())
                            else {
                                return Err(invalid());
                            };
                            if fields.len() != vs.len() {
                                return Err(invalid());
                            }
                            work.push(FromWasm::Ctor(*tag, vs.len()));
                            work.extend(
                                fields
                                    .iter()
                                    .zip(vs)
                                    .rev()
                                    .map(|(p, v)| FromWasm::Visit(p, v)),
                            );
                        }
                        (Some(p), Some(v)) => {
                            work.push(FromWasm::Ctor(*tag, 1));
                            work.push(FromWasm::Visit(p, v));
                        }
                        _ => return Err(invalid()),
                    }
                }
                (WitPlan::Enum { cases }, Val::Enum(name)) => {
                    let (_, tag) = cases.iter().find(|(n, _)| n == name).ok_or_else(invalid)?;
                    out.push(Value::Tag(CtorTag(*tag)));
                }
                (WitPlan::Flags { cases }, Val::Flags(names)) => {
                    let mut set = Value::EmptySet;
                    for name in names {
                        let (_, tag) = cases.iter().find(|(n, _)| n == name).ok_or_else(invalid)?;
                        set = map::set_insert(
                            ctx,
                            set,
                            Value::Tag(CtorTag(*tag)),
                            "external result",
                        )?;
                    }
                    out.push(set);
                }
                (WitPlan::Option(_), Val::Option(None)) => {
                    out.push(Value::Tag(CtorTag(tags::OPTION_NONE)))
                }
                (WitPlan::Option(p), Val::Option(Some(v))) => {
                    work.push(FromWasm::Ctor(tags::OPTION_SOME, 1));
                    work.push(FromWasm::Visit(p, v));
                }
                (WitPlan::Result { ok, err }, Val::Result(result)) => {
                    let (p, v, tag) = match result {
                        Ok(v) => (ok, v, tags::RESULT_OK),
                        Err(v) => (err, v, tags::RESULT_ERROR),
                    };
                    work.push(FromWasm::Ctor(tag, 1));
                    match (p, v) {
                        (Some(p), Some(v)) => work.push(FromWasm::Visit(p, v)),
                        (None, None) => out.push(Value::Unit),
                        _ => return Err(invalid()),
                    }
                }
                _ => return Err(invalid()),
            },
        }
    }
    if out.len() != 1 {
        return Err(invalid());
    }
    out.pop().ok_or_else(invalid)
}

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（AGENTS.md「実装の規約」）。
    #![allow(clippy::unwrap_used, clippy::panic)]
    use super::*;
    use crate::runtime::heap::{Heap, HeapConfig};
    use std::sync::Arc;

    fn spec() -> ExternalSpec {
        ExternalSpec {
            adapter: None,
            id: 0,
            function: "Test.roundtrip".into(),
            instance: None,
            export: "roundtrip".into(),
            component: Arc::new(crate::external::ComponentSource {
                display: "x.wasm".into(),
                bytes: Arc::from([]),
            }),
            params: vec![],
            result: None,
            route: super::super::ExternalRoute::of(&[], None),
        }
    }
    // 関門: 長いリスト、入れ子、Unit を持つ Result の反対の側、サイズの境界を確かめる。
    // 各型の ABI はゴールデンで守り、ここでは大量の確保をせず境界の前後を調べる。
    #[test]
    fn nested_conversion_and_size_boundaries() {
        let cases = vec![
            (WitPlan::Bytes, Val::List(vec![])),
            (
                WitPlan::Tuple(vec![WitPlan::S64, WitPlan::Bool, WitPlan::U8]),
                Val::Tuple(vec![Val::S64(-42), Val::Bool(true), Val::U8(255)]),
            ),
            (
                WitPlan::List(Box::new(WitPlan::S64)),
                Val::List(vec![Val::S64(1); 5000]),
            ),
            (WitPlan::List(Box::new(WitPlan::String)), Val::List(vec![])),
            (
                WitPlan::Result {
                    ok: Some(Box::new(WitPlan::S64)),
                    err: None,
                },
                Val::Result(Ok(Some(Box::new(Val::S64(42))))),
            ),
            (
                WitPlan::Result {
                    ok: Some(Box::new(WitPlan::S64)),
                    err: None,
                },
                Val::Result(Err(None)),
            ),
            (
                WitPlan::List(Box::new(WitPlan::Option(Box::new(WitPlan::List(
                    Box::new(WitPlan::S64),
                ))))),
                Val::List(vec![
                    Val::Option(Some(Box::new(Val::List(vec![Val::S64(3)])))),
                    Val::Option(None),
                ]),
            ),
        ];
        let mut heap = Heap::new(HeapConfig::default());
        let spec = spec();
        heap.epoch(|ctx| {
            for (p, expected) in cases {
                let v = from_wasm(ctx, &spec, &p, &expected, None).unwrap();
                assert_eq!(to_wasm(ctx, &p, v, None).unwrap(), expected, "{p:?}");
            }
            let mut args_spec = spec.clone();
            args_spec.params = vec![WitPlan::String, WitPlan::List(Box::new(WitPlan::S64))];
            let args = [
                ctx.alloc_str("字", "test").unwrap(),
                list::from_values(ctx, &[Value::Int(1), Value::Int(2)], "test").unwrap(),
            ];
            check_arguments(ctx, &args_spec, &args, 83).unwrap();
            assert!(matches!(
                check_arguments(ctx, &args_spec, &args, 82),
                Err(Stop::Resource(ResourceError::ExternalTransfer {
                    limit: 82,
                    ..
                }))
            ));
        });
        // 名前のバイト数と存在する子だけを数え、境界の前後を小さい値で確認する。
        // ABI の往復では予算の数え漏れを検出できない。
        let record = WitPlan::Record {
            fields: vec![
                ("byte-start".into(), WitPlan::S64),
                ("y".into(), WitPlan::S64),
            ],
        };
        let variant = WitPlan::Variant {
            cases: vec![
                ("circle".into(), 0, Some(Box::new(WitPlan::S64))),
                ("empty".into(), 1, None),
            ],
        };
        let val_size = u64::try_from(std::mem::size_of::<Val>()).unwrap();
        let budget_cases = [
            (
                WitPlan::ConstructorTuple {
                    tag: 1234,
                    fields: vec![WitPlan::String],
                },
                Val::Tuple(vec![Val::String("字".into())]),
                val_size + 3,
            ),
            (
                WitPlan::Variant {
                    cases: vec![(
                        "value".into(),
                        1235,
                        Some(Box::new(WitPlan::TupleFields(vec![
                            WitPlan::S64,
                            WitPlan::String,
                        ]))),
                    )],
                },
                Val::Variant(
                    "value".into(),
                    Some(Box::new(Val::Tuple(vec![
                        Val::S64(42),
                        Val::String("字".into()),
                    ]))),
                ),
                3 * val_size + 5 + 3,
            ),
            (
                record.clone(),
                Val::Record(vec![
                    ("byte-start".into(), Val::S64(1)),
                    ("y".into(), Val::S64(2)),
                ]),
                2 * val_size + 11,
            ),
            (
                WitPlan::Record {
                    fields: vec![("text".into(), WitPlan::String)],
                },
                Val::Record(vec![("text".into(), Val::String("字".into()))]),
                val_size + 4 + 3,
            ),
            (
                variant.clone(),
                Val::Variant("circle".into(), Some(Box::new(Val::S64(42)))),
                val_size + 6,
            ),
            (variant, Val::Variant("empty".into(), None), 5),
            (
                WitPlan::Enum {
                    cases: vec![("blue-ish".into(), 0)],
                },
                Val::Enum("blue-ish".into()),
                8,
            ),
            (
                WitPlan::Option(Box::new(record)),
                Val::Option(Some(Box::new(Val::Record(vec![
                    ("byte-start".into(), Val::S64(1)),
                    ("y".into(), Val::S64(2)),
                ])))),
                3 * val_size + 11,
            ),
        ];
        heap.epoch(|ctx| {
            for (plan, value, budget) in budget_cases {
                let v = from_wasm(ctx, &spec, &plan, &value, None).unwrap();
                let mut args_spec = spec.clone();
                args_spec.params = vec![plan];
                check_arguments(ctx, &args_spec, &[v], budget).unwrap();
                assert!(matches!(
                    check_arguments(ctx, &args_spec, &[v], budget - 1),
                    Err(Stop::Resource(ResourceError::ExternalTransfer { .. }))
                ));
            }
        });
        for unit in [SizeUnit::Bytes, SizeUnit::Elements] {
            check_size(&spec, 3, unit, 3).unwrap();
            assert_eq!(
                check_size(&spec, 4, unit, 3),
                Err(Stop::Resource(ResourceError::ExternalValueTooLarge {
                    function: "Test.roundtrip".into(),
                    size: 4,
                    unit,
                    limit: 3,
                }))
            );
        }
    }
}
