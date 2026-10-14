//! 言語の値と予算付きの相対位置の形式を変換する（設計書 03-10「型の対応」）。
//! 値は回収しない区間の中で二度走査し、量の検査を終えてから出力を確保する。

use super::layout::{FieldLayout, LayoutError, LayoutKind, LayoutTable, MemoryLayout};
use super::wire::{self, Header, WireError};
use crate::builtins::table::tags;
use crate::external::WitPlan;
use crate::runtime::heap::{CtorTag, FieldsKind, NoGcCtx, Value};
use crate::runtime::{Stop, list, map};

mod decode;

/// 配置とは別に保存する、タグ番号に依存しない構築量の規則。
/// 子の出現は配置表の子を辿って数え、ABI 専用の組には値の費用を加えない。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(crate) struct ConstructionRule {
    pub value_bytes: u64,
    pub content_bytes: bool,
    pub selected_item_bytes: u64,
    /// 選択した場合に省略された言語の欄の費用。Result の Unit の欄だけが該当する。
    pub case_bytes: Vec<u64>,
}

/// 配置と同じ番号で規則を参照する。生成物の共有では配置とこの表の両方を比較する。
#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub(crate) struct ConstructionTable {
    pub nodes: Vec<ConstructionRule>,
}

/// 型の表を一度作り、値ごとの走査では名前と配置を計算し直さない。
pub(crate) struct CodecPlan<'a> {
    pub layout: LayoutTable,
    pub construction: ConstructionTable,
    plans: Vec<&'a WitPlan>,
}

impl<'a> CodecPlan<'a> {
    /// 照合済みの型の配置と、実際の言語の値の費用を対応付ける。
    pub(crate) fn new(plans: &'a [WitPlan], total: &mut usize) -> Result<Self, LayoutError> {
        Self::with_layout(plans, LayoutTable::new(plans, total)?)
    }

    /// 照合時に予算を検査した配置を使い、呼び出しごとに予算をリセットしない。
    pub(crate) fn with_layout(
        plans: &'a [WitPlan],
        layout: LayoutTable,
    ) -> Result<Self, LayoutError> {
        let mut node_plans = vec![None; layout.nodes.len()];
        let mut work: Vec<_> = plans
            .iter()
            .zip(&layout.roots.fields)
            .map(|(plan, field)| (plan, field.node))
            .collect();
        while let Some((plan, id)) = work.pop() {
            let slot = node_plans
                .get_mut(id)
                .ok_or(LayoutError::Internal("codec node is missing"))?;
            if slot.replace(plan).is_some() {
                return Err(LayoutError::Internal("codec node is shared"));
            }
            let kind = &layout
                .nodes
                .get(id)
                .ok_or(LayoutError::Internal("codec layout is missing"))?
                .kind;
            match (plan, kind) {
                (WitPlan::List(p), LayoutKind::List { element }) => work.push((p, *element)),
                (WitPlan::Map(key, value), LayoutKind::Map { entry }) => {
                    let [k, v] = entry.fields.as_slice() else {
                        return Err(LayoutError::Internal("map fields are missing"));
                    };
                    work.push((key, k.node));
                    work.push((value, v.node));
                }
                (
                    WitPlan::Tuple(ps)
                    | WitPlan::TupleFields(ps)
                    | WitPlan::ConstructorTuple { fields: ps, .. },
                    LayoutKind::Record { fields },
                ) => {
                    for (p, f) in ps.iter().zip(fields) {
                        work.push((p, f.node));
                    }
                }
                (WitPlan::Record { fields: ps }, LayoutKind::Record { fields }) => {
                    for ((_, p), f) in ps.iter().zip(fields) {
                        work.push((p, f.node));
                    }
                }
                (WitPlan::Option(p), LayoutKind::Variant { cases, .. }) => {
                    let id = cases
                        .get(1)
                        .copied()
                        .flatten()
                        .ok_or(LayoutError::Internal("option payload is missing"))?;
                    work.push((p, id));
                }
                (WitPlan::Result { ok, err }, LayoutKind::Variant { cases, .. }) => {
                    for (p, id) in [ok, err].into_iter().zip(cases) {
                        if let Some(p) = p {
                            work.push((
                                p,
                                id.ok_or(LayoutError::Internal("result payload is missing"))?,
                            ));
                        }
                    }
                }
                (WitPlan::Variant { cases: ps }, LayoutKind::Variant { cases, .. }) => {
                    for ((_, _, p), id) in ps.iter().zip(cases) {
                        if let Some(p) = p {
                            work.push((
                                p,
                                id.ok_or(LayoutError::Internal("variant payload is missing"))?,
                            ));
                        }
                    }
                }
                (
                    _,
                    LayoutKind::Scalar
                    | LayoutKind::String
                    | LayoutKind::Bytes
                    | LayoutKind::Enum { .. }
                    | LayoutKind::Flags,
                ) => {}
                _ => return Err(LayoutError::Internal("codec plan does not match layout")),
            }
        }
        let plans = node_plans
            .into_iter()
            .map(|p| p.ok_or(LayoutError::Internal("codec plan is missing")))
            .collect::<Result<Vec<_>, _>>()?;
        let nodes = plans
            .iter()
            .map(|p| ConstructionRule {
                value_bytes: if matches!(p, WitPlan::TupleFields(_)) {
                    0
                } else {
                    wire::VALUE_BYTES
                },
                content_bytes: matches!(p, WitPlan::String | WitPlan::Bytes),
                selected_item_bytes: if matches!(p, WitPlan::Flags { .. }) {
                    wire::VALUE_BYTES
                } else {
                    0
                },
                case_bytes: if let WitPlan::Result { ok, err } = p {
                    [ok, err]
                        .into_iter()
                        .map(|p| if p.is_none() { wire::VALUE_BYTES } else { 0 })
                        .collect()
                } else {
                    vec![]
                },
            })
            .collect();
        Ok(Self {
            layout,
            construction: ConstructionTable { nodes },
            plans,
        })
    }

    /// 全長と構築量を検査し、宣言順の固定部と深さ優先の参照先を書き込む。
    pub(crate) fn encode<'e>(
        &self,
        ctx: &NoGcCtx<'e>,
        values: &[Value<'e>],
        limit: u64,
    ) -> Result<Encoded, CodecError> {
        if values.len() != self.layout.roots.fields.len() {
            return Err(invalid());
        }
        let roots = u32::try_from(values.len()).map_err(|_| WireError::Memory32)?;
        let mut measured = Buffer::new(self.layout.roots.memory, limit, None)?;
        self.walk(ctx, values, &mut measured)?;
        let length = measured.next;
        // 最初の走査では出力の Vec を持たず、全量が上限以内の場合だけ零で確保する。
        // 詰め物と非選択のペイロードは書かず、零のまま残す。
        let bytes = vec![0; usize::try_from(length).map_err(|_| invalid())?];
        let mut output = Buffer::new(self.layout.roots.memory, limit, Some(bytes))?;
        self.walk(ctx, values, &mut output)?;
        if output.next != length || output.construction != measured.construction {
            return Err(invalid());
        }
        let mut bytes = output.bytes.ok_or_else(invalid)?;
        Header {
            length,
            roots,
            limit,
        }
        .write(&mut bytes)?;
        Ok(Encoded {
            bytes,
            construction_bytes: measured.construction,
        })
    }

    fn walk<'e>(
        &self,
        ctx: &NoGcCtx<'e>,
        values: &[Value<'e>],
        output: &mut Buffer,
    ) -> Result<(), CodecError> {
        let mut work = vec![Work::Roots(0)];
        while let Some(task) = work.pop() {
            match task {
                Work::Roots(index) => {
                    if let Some(field) = self.layout.roots.fields.get(index) {
                        let value = *values.get(index).ok_or_else(invalid)?;
                        work.push(Work::Roots(index.saturating_add(1)));
                        work.push(Work::Value(
                            field.node,
                            value,
                            add(wire::HEADER_SIZE, field.offset)?,
                        ));
                    }
                }
                Work::Fields(fields, value, base, index) => {
                    if let Some(field) = fields.get(index) {
                        let v = ctx
                            .field(value, u32::try_from(index).map_err(|_| invalid())?)
                            .ok_or_else(invalid)?;
                        work.push(Work::Fields(fields, value, base, index.saturating_add(1)));
                        work.push(Work::Value(field.node, v, add(base, field.offset)?));
                    }
                }
                Work::List(node, mut cursor, base, stride, remaining) => {
                    match (remaining, cursor.next(ctx)?) {
                        (0, None) => {}
                        (0, Some(_)) | (_, None) => return Err(invalid()),
                        (_, Some(v)) => {
                            work.push(Work::List(
                                node,
                                cursor,
                                add(base, stride)?,
                                stride,
                                remaining.saturating_sub(1),
                            ));
                            work.push(Work::Value(node, v, base));
                        }
                    }
                }
                Work::Map(fields, mut cursor, base, stride, remaining) => {
                    match (remaining, cursor.next(ctx)?) {
                        (0, None) => {}
                        (0, Some(_)) | (_, None) => return Err(invalid()),
                        (_, Some((key, value))) => {
                            let [k, v] = fields else {
                                return Err(invalid());
                            };
                            work.push(Work::Map(
                                fields,
                                cursor,
                                add(base, stride)?,
                                stride,
                                remaining.saturating_sub(1),
                            ));
                            work.push(Work::Value(v.node, value, add(base, v.offset)?));
                            work.push(Work::Value(k.node, key, add(base, k.offset)?));
                        }
                    }
                }
                Work::Value(id, value, offset) => {
                    self.visit(ctx, id, value, offset, output, &mut work)?
                }
            }
        }
        Ok(())
    }

    fn visit<'p, 'e>(
        &'p self,
        ctx: &NoGcCtx<'e>,
        id: usize,
        value: Value<'e>,
        offset: u32,
        output: &mut Buffer,
        work: &mut Vec<Work<'p, 'e>>,
    ) -> Result<(), CodecError> {
        let plan = *self.plans.get(id).ok_or_else(invalid)?;
        let layout = self.layout.nodes.get(id).ok_or_else(invalid)?;
        let rule = self.construction.nodes.get(id).ok_or_else(invalid)?;
        output.charge(rule.value_bytes)?;
        match (plan, value) {
            (WitPlan::S8, Value::Int8(v)) => return output.put(offset, &v.to_le_bytes()),
            (WitPlan::S16, Value::Int16(v)) => return output.put(offset, &v.to_le_bytes()),
            (WitPlan::S32, Value::Int32(v)) => return output.put(offset, &v.to_le_bytes()),
            (WitPlan::S64, Value::Int(v)) => return output.put(offset, &v.to_le_bytes()),
            (WitPlan::U8, Value::Byte(v)) => return output.put(offset, &v.to_le_bytes()),
            (WitPlan::U16, Value::UInt16(v)) => return output.put(offset, &v.to_le_bytes()),
            (WitPlan::U32, Value::UInt32(v)) => return output.put(offset, &v.to_le_bytes()),
            (WitPlan::U64, Value::UInt64(v)) => return output.put(offset, &v.to_le_bytes()),
            (WitPlan::F32, Value::Float32(v)) => {
                return output.put(offset, &v.to_bits().to_le_bytes());
            }
            (WitPlan::F64, Value::Float(v)) => {
                return output.put(offset, &v.to_bits().to_le_bytes());
            }
            (WitPlan::Bool, Value::Bool(v)) => return output.put(offset, &[u8::from(v)]),
            (WitPlan::Char, Value::Char(v)) => {
                return output.put(offset, &u32::from(v).to_le_bytes());
            }
            _ => {}
        }
        match plan {
            WitPlan::String | WitPlan::Bytes => {
                let bytes = if matches!(plan, WitPlan::String) {
                    ctx.str(value).ok_or_else(invalid)?.as_bytes()
                } else {
                    ctx.bytes(value).ok_or_else(invalid)?
                };
                let count = u32::try_from(bytes.len()).map_err(|_| WireError::Memory32)?;
                if !rule.content_bytes {
                    return Err(invalid());
                }
                output.charge(u64::from(count))?;
                let base = if count == 0 {
                    0
                } else {
                    output.reserve(MemoryLayout {
                        size: count,
                        alignment: 1,
                    })?
                };
                output.reference(offset, base, count)?;
                if count != 0 {
                    output.put(base, bytes)?;
                }
            }
            WitPlan::List(_) => {
                let LayoutKind::List { element } = layout.kind else {
                    return Err(invalid());
                };
                let memory = self.layout.nodes.get(element).ok_or_else(invalid)?.memory;
                let count = list::len(ctx, value)?;
                let base = output.array(offset, memory, count)?;
                work.push(Work::List(
                    element,
                    list::cursor(ctx, value)?,
                    base,
                    memory.stride()?,
                    count,
                ));
            }
            WitPlan::Map(_, _) => {
                let LayoutKind::Map { entry } = &layout.kind else {
                    return Err(invalid());
                };
                let count = map::map_len(ctx, value)?;
                let base = output.array(offset, entry.memory, count)?;
                work.push(Work::Map(
                    &entry.fields,
                    map::map_cursor(ctx, value)?,
                    base,
                    entry.memory.stride()?,
                    count,
                ));
            }
            WitPlan::Tuple(ps)
            | WitPlan::ConstructorTuple { fields: ps, .. }
            | WitPlan::TupleFields(ps) => {
                let tag = if matches!(plan, WitPlan::Tuple(_)) {
                    Some(match ps.len() {
                        2 => tags::PAIR,
                        3 => tags::TRIPLE,
                        _ => return Err(invalid()),
                    })
                } else if let WitPlan::ConstructorTuple { tag, .. } = plan {
                    Some(*tag)
                } else {
                    None
                };
                check_fields(ctx, value, tag, ps.len())?;
                let LayoutKind::Record { fields } = &layout.kind else {
                    return Err(invalid());
                };
                work.push(Work::Fields(fields, value, offset, 0));
            }
            WitPlan::Record { fields: ps } => {
                check_fields(ctx, value, Some(tags::RECORD), ps.len())?;
                let LayoutKind::Record { fields } = &layout.kind else {
                    return Err(invalid());
                };
                work.push(Work::Fields(fields, value, offset, 0));
            }
            WitPlan::Enum { cases } => {
                let index = enum_index(cases, value)?;
                let LayoutKind::Enum { discriminant_size } = layout.kind else {
                    return Err(invalid());
                };
                output.discriminant(offset, discriminant_size, index)?;
            }
            WitPlan::Flags { cases } => {
                let mut cursor = map::set_cursor(ctx, value)?;
                let mut bits = 0_u32;
                while let Some((v, _)) = cursor.next(ctx)? {
                    let index = enum_index(cases, v)?;
                    bits |= 1_u32.checked_shl(index).ok_or_else(invalid)?;
                    output.charge(rule.selected_item_bytes)?;
                }
                output.discriminant(offset, layout.memory.size, bits)?;
            }
            WitPlan::Option(_) | WitPlan::Result { .. } | WitPlan::Variant { .. } => {
                let (index, payload) = selected_case(ctx, plan, value)?;
                let LayoutKind::Variant {
                    discriminant_size,
                    payload_offset,
                    cases,
                } = &layout.kind
                else {
                    return Err(invalid());
                };
                output.discriminant(
                    offset,
                    *discriminant_size,
                    u32::try_from(index).map_err(|_| invalid())?,
                )?;
                if let Some(bytes) = rule.case_bytes.get(index) {
                    output.charge(*bytes)?;
                }
                let node = cases.get(index).ok_or_else(invalid)?;
                match (node, payload) {
                    (Some(node), Some(value)) => {
                        work.push(Work::Value(*node, value, add(offset, *payload_offset)?))
                    }
                    (None, None) => {}
                    _ => return Err(invalid()),
                }
            }
            WitPlan::S8
            | WitPlan::S16
            | WitPlan::S32
            | WitPlan::S64
            | WitPlan::U8
            | WitPlan::U16
            | WitPlan::U32
            | WitPlan::U64
            | WitPlan::F32
            | WitPlan::F64
            | WitPlan::Bool
            | WitPlan::Char
            | WitPlan::Borrow(_)
            | WitPlan::Own(_) => return Err(invalid()),
        }
        Ok(())
    }
}

/// 呼び出しへ渡すバイト列と、転送量とは別の言語の構築量。
#[derive(Debug, PartialEq, Eq)]
pub(crate) struct Encoded {
    pub bytes: Vec<u8>,
    pub construction_bytes: u64,
}

/// 形式の上限・不整合と、既存カーソルの失敗を保存する。
#[derive(Debug, PartialEq, Eq)]
pub(crate) enum CodecError {
    Wire(WireError),
    Value(Stop),
}

impl From<WireError> for CodecError {
    fn from(error: WireError) -> Self {
        Self::Wire(error)
    }
}
impl From<Stop> for CodecError {
    fn from(error: Stop) -> Self {
        Self::Value(error)
    }
}
impl From<LayoutError> for CodecError {
    fn from(error: LayoutError) -> Self {
        Self::Wire(match error {
            LayoutError::Memory32 => WireError::Memory32,
            LayoutError::Internal(message) => WireError::Internal(message),
            LayoutError::TypeBudget | LayoutError::GenerationBudget | LayoutError::Resource => {
                WireError::Internal("unsupported codec layout")
            }
        })
    }
}

enum Work<'p, 'e> {
    Roots(usize),
    Value(usize, Value<'e>, u32),
    Fields(&'p [FieldLayout], Value<'e>, u32, usize),
    List(usize, list::Cursor<'e>, u32, u32, u32),
    Map(&'p [FieldLayout], map::Cursor<'e>, u32, u32, u32),
}

struct Buffer {
    bytes: Option<Vec<u8>>,
    next: u32,
    construction: u64,
    limit: u64,
}
impl Buffer {
    fn new(roots: MemoryLayout, limit: u64, bytes: Option<Vec<u8>>) -> Result<Self, CodecError> {
        let next = add(wire::HEADER_SIZE, roots.size)?;
        if u64::from(next) > limit {
            return Err(WireError::TransferLimit.into());
        }
        Ok(Self {
            bytes,
            next,
            construction: 0,
            limit,
        })
    }
    fn charge(&mut self, bytes: u64) -> Result<(), CodecError> {
        self.construction = self
            .construction
            .checked_add(bytes)
            .ok_or(WireError::ConstructionLimit)?;
        if self.construction > self.limit {
            return Err(WireError::ConstructionLimit.into());
        }
        Ok(())
    }
    fn reserve(&mut self, memory: MemoryLayout) -> Result<u32, CodecError> {
        let base = MemoryLayout {
            size: self.next,
            alignment: memory.alignment,
        }
        .stride()?;
        let next = add(base, memory.size)?;
        if u64::from(next) > self.limit {
            return Err(WireError::TransferLimit.into());
        }
        self.next = next;
        Ok(base)
    }
    fn put(&mut self, offset: u32, value: &[u8]) -> Result<(), CodecError> {
        if let Some(bytes) = &mut self.bytes {
            wire::put(bytes, offset, value)?;
        }
        Ok(())
    }
    fn reference(&mut self, offset: u32, base: u32, count: u32) -> Result<(), CodecError> {
        self.put(offset, &base.to_le_bytes())?;
        self.put(
            add(offset, wire::REFERENCE_LENGTH_OFFSET)?,
            &count.to_le_bytes(),
        )
    }
    fn array(&mut self, offset: u32, memory: MemoryLayout, count: u32) -> Result<u32, CodecError> {
        let base = if count == 0 {
            0
        } else {
            self.reserve(MemoryLayout {
                size: memory.array_size(count)?,
                alignment: memory.alignment,
            })?
        };
        self.reference(offset, base, count)?;
        Ok(base)
    }
    fn discriminant(&mut self, offset: u32, size: u32, value: u32) -> Result<(), CodecError> {
        match size {
            1 => self.put(
                offset,
                &u8::try_from(value).map_err(|_| invalid())?.to_le_bytes(),
            ),
            2 => self.put(
                offset,
                &u16::try_from(value).map_err(|_| invalid())?.to_le_bytes(),
            ),
            4 => self.put(offset, &value.to_le_bytes()),
            _ => Err(invalid()),
        }
    }
}

fn add(left: u32, right: u32) -> Result<u32, WireError> {
    left.checked_add(right).ok_or(WireError::Memory32)
}
fn invalid() -> CodecError {
    WireError::Internal("language value does not match adapter plan").into()
}

fn check_fields<'e>(
    ctx: &NoGcCtx<'e>,
    value: Value<'e>,
    tag: Option<u32>,
    count: usize,
) -> Result<(), CodecError> {
    let Some((FieldsKind::Ctor, actual)) = ctx.fields_header(value) else {
        return Err(invalid());
    };
    if tag.is_some_and(|tag| tag != actual)
        || ctx.fields_len(value).and_then(|n| usize::try_from(n).ok()) != Some(count)
    {
        return Err(invalid());
    }
    Ok(())
}
fn enum_index(cases: &[(String, u32)], value: Value<'_>) -> Result<u32, CodecError> {
    let Value::Tag(CtorTag(tag)) = value else {
        return Err(invalid());
    };
    u32::try_from(
        cases
            .iter()
            .position(|(_, t)| *t == tag)
            .ok_or_else(invalid)?,
    )
    .map_err(|_| invalid())
}
fn selected_case<'e>(
    ctx: &NoGcCtx<'e>,
    plan: &WitPlan,
    value: Value<'e>,
) -> Result<(usize, Option<Value<'e>>), CodecError> {
    match plan {
        WitPlan::Option(_) => {
            if matches!(value, Value::Tag(CtorTag(tags::OPTION_NONE))) {
                return Ok((0, None));
            }
            check_fields(ctx, value, Some(tags::OPTION_SOME), 1)?;
            Ok((1, Some(ctx.field(value, 0).ok_or_else(invalid)?)))
        }
        WitPlan::Result { ok, err } => {
            let Some((FieldsKind::Ctor, tag)) = ctx.fields_header(value) else {
                return Err(invalid());
            };
            let (index, p) = match tag {
                tags::RESULT_OK => (0, ok),
                tags::RESULT_ERROR => (1, err),
                _ => return Err(invalid()),
            };
            check_fields(ctx, value, Some(tag), 1)?;
            let field = ctx.field(value, 0).ok_or_else(invalid)?;
            if p.is_some() {
                Ok((index, Some(field)))
            } else if matches!(field, Value::Unit) {
                Ok((index, None))
            } else {
                Err(invalid())
            }
        }
        WitPlan::Variant { cases } => {
            let tag = match value {
                Value::Tag(CtorTag(tag)) => tag,
                Value::Obj(_) => ctx
                    .fields_header(value)
                    .filter(|(kind, _)| *kind == FieldsKind::Ctor)
                    .map(|(_, tag)| tag)
                    .ok_or_else(invalid)?,
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
                | Value::EmptySet => return Err(invalid()),
            };
            let (index, (_, _, p)) = cases
                .iter()
                .enumerate()
                .find(|(_, (_, t, _))| *t == tag)
                .ok_or_else(invalid)?;
            match p.as_deref() {
                None if matches!(value, Value::Tag(_)) => Ok((index, None)),
                Some(WitPlan::TupleFields(fields)) => {
                    check_fields(ctx, value, Some(tag), fields.len())?;
                    Ok((index, Some(value)))
                }
                Some(_) => {
                    check_fields(ctx, value, Some(tag), 1)?;
                    Ok((index, Some(ctx.field(value, 0).ok_or_else(invalid)?)))
                }
                None => Err(invalid()),
            }
        }
        WitPlan::S8
        | WitPlan::S16
        | WitPlan::S32
        | WitPlan::S64
        | WitPlan::U8
        | WitPlan::U16
        | WitPlan::U32
        | WitPlan::U64
        | WitPlan::F32
        | WitPlan::F64
        | WitPlan::Bool
        | WitPlan::Char
        | WitPlan::String
        | WitPlan::Bytes
        | WitPlan::List(_)
        | WitPlan::Map(_, _)
        | WitPlan::Tuple(_)
        | WitPlan::ConstructorTuple { .. }
        | WitPlan::TupleFields(_)
        | WitPlan::Record { .. }
        | WitPlan::Enum { .. }
        | WitPlan::Flags { .. }
        | WitPlan::Borrow(_)
        | WitPlan::Own(_) => Err(invalid()),
    }
}

#[cfg(test)]
mod tests;
