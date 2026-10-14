//! 転送形式の全体検査と、検査済みの値の非再帰の構築を分ける（設計書 03-10「型の対応」）。
//! 作業列と区間内の構築器は値の寿命を越えて保存しない。

use super::*;
use crate::runtime::heap::CheckedLen;

impl CodecPlan<'_> {
    /// 全体の妥当性・順序・二つの予算を検査してから、言語の値を作る。
    pub(crate) fn decode<'e>(
        &self,
        ctx: &NoGcCtx<'e>,
        bytes: &[u8],
        limit: u64,
    ) -> Result<Decoded<'e>, CodecError> {
        let construction_bytes = self.validate(bytes, limit)?;
        let mut values = Vec::with_capacity(self.layout.roots.fields.len());
        for field in &self.layout.roots.fields {
            values.push(self.build(
                ctx,
                bytes,
                field.node,
                add(wire::HEADER_SIZE, field.offset)?,
            )?);
        }
        Ok(Decoded {
            values,
            construction_bytes,
        })
    }

    fn validate(&self, bytes: &[u8], limit: u64) -> Result<u64, CodecError> {
        Header::read(
            bytes,
            u32::try_from(self.layout.roots.fields.len()).map_err(|_| invalid())?,
            limit,
        )?;
        let mut reader = Reader {
            bytes,
            buffer: Buffer::new(self.layout.roots.memory, limit, None)?,
        };
        reader.record(
            &self.layout.roots.fields,
            wire::HEADER_SIZE,
            self.layout.roots.memory.size,
            self,
        )?;
        let mut work = vec![Check::Fields(
            &self.layout.roots.fields,
            wire::HEADER_SIZE,
            0,
        )];
        while let Some(task) = work.pop() {
            match task {
                Check::Fields(fields, base, index) => {
                    if let Some(f) = fields.get(index) {
                        work.push(Check::Fields(fields, base, index.saturating_add(1)));
                        work.push(Check::Value(f.node, add(base, f.offset)?));
                    }
                }
                Check::Array(node, base, stride, count) => {
                    if count != 0 {
                        work.push(Check::Array(
                            node,
                            add(base, stride)?,
                            stride,
                            count.saturating_sub(1),
                        ));
                        work.push(Check::Value(node, base));
                    }
                }
                Check::Map(fields, base, stride, count) => {
                    if count != 0 {
                        work.push(Check::Map(
                            fields,
                            add(base, stride)?,
                            stride,
                            count.saturating_sub(1),
                        ));
                        reader.record(fields, base, stride, self)?;
                        work.push(Check::Fields(fields, base, 0));
                    }
                }
                Check::Value(id, offset) => {
                    let plan = *self.plans.get(id).ok_or_else(invalid)?;
                    let layout = self.layout.nodes.get(id).ok_or_else(invalid)?;
                    let rule = self.construction.nodes.get(id).ok_or_else(invalid)?;
                    wire::range(bytes, offset, layout.memory.size)?;
                    reader.buffer.charge(rule.value_bytes)?;
                    if scalar(plan, bytes, offset)?.is_some() {
                        continue;
                    }
                    match &layout.kind {
                        LayoutKind::String | LayoutKind::Bytes => {
                            let (base, count) = reference(bytes, offset)?;
                            CheckedLen::bytes(u64::from(count), "external result")?;
                            reader.buffer.charge(u64::from(count))?;
                            reader.reference(
                                base,
                                count,
                                MemoryLayout {
                                    size: count,
                                    alignment: 1,
                                },
                            )?;
                            if matches!(plan, WitPlan::String) {
                                std::str::from_utf8(wire::range(bytes, base, count)?)
                                    .map_err(|_| malformed())?;
                            }
                        }
                        LayoutKind::List { element } => {
                            let (base, count) = reference(bytes, offset)?;
                            CheckedLen::elements(u64::from(count), "external result")?;
                            let memory =
                                self.layout.nodes.get(*element).ok_or_else(invalid)?.memory;
                            reader.minimum(
                                count,
                                self.construction
                                    .nodes
                                    .get(*element)
                                    .ok_or_else(invalid)?
                                    .value_bytes,
                            )?;
                            reader.reference(
                                base,
                                count,
                                MemoryLayout {
                                    size: memory.array_size(count)?,
                                    alignment: memory.alignment,
                                },
                            )?;
                            work.push(Check::Array(*element, base, memory.stride()?, count));
                        }
                        LayoutKind::Map { entry } => {
                            let (base, count) = reference(bytes, offset)?;
                            let minimum = entry.fields.iter().try_fold(0_u64, |sum, f| {
                                sum.checked_add(
                                    self.construction
                                        .nodes
                                        .get(f.node)
                                        .ok_or_else(invalid)?
                                        .value_bytes,
                                )
                                .ok_or_else(|| CodecError::from(WireError::ConstructionLimit))
                            })?;
                            reader.minimum(count, minimum)?;
                            reader.reference(
                                base,
                                count,
                                MemoryLayout {
                                    size: entry.memory.array_size(count)?,
                                    alignment: entry.memory.alignment,
                                },
                            )?;
                            work.push(Check::Map(
                                &entry.fields,
                                base,
                                entry.memory.stride()?,
                                count,
                            ));
                        }
                        LayoutKind::Record { fields } => {
                            // タグを持たない Tuple は Pair と Triple にだけ対応する。
                            if let WitPlan::Tuple(ps) = plan {
                                tuple_tag(ps.len())?;
                            }
                            reader.record(fields, offset, layout.memory.size, self)?;
                            work.push(Check::Fields(fields, offset, 0));
                        }
                        LayoutKind::Enum { discriminant_size } => {
                            let WitPlan::Enum { cases } = plan else {
                                return Err(invalid());
                            };
                            let index = index(bytes, offset, *discriminant_size)?;
                            cases.get(index).ok_or_else(malformed)?;
                        }
                        LayoutKind::Flags => {
                            let WitPlan::Flags { cases } = plan else {
                                return Err(invalid());
                            };
                            let bits = wire::discriminant(bytes, offset, layout.memory.size)?;
                            let mask = if cases.len() == 32 {
                                u32::MAX
                            } else {
                                1_u32
                                    .checked_shl(u32::try_from(cases.len()).map_err(|_| invalid())?)
                                    .ok_or_else(invalid)?
                                    .saturating_sub(1)
                            };
                            if bits & !mask != 0 {
                                return Err(malformed());
                            }
                            reader.buffer.charge(
                                u64::from(bits.count_ones())
                                    .checked_mul(rule.selected_item_bytes)
                                    .ok_or(WireError::ConstructionLimit)?,
                            )?;
                        }
                        LayoutKind::Variant {
                            discriminant_size,
                            payload_offset,
                            cases,
                        } => {
                            let selected = index(bytes, offset, *discriminant_size)?;
                            let child = cases.get(selected).ok_or_else(malformed)?;
                            if let Some(cost) = rule.case_bytes.get(selected) {
                                reader.buffer.charge(*cost)?;
                            }
                            let payload = add(offset, *payload_offset)?;
                            reader.zero(add(offset, *discriminant_size)?, payload)?;
                            let used = if let Some(child) = child {
                                let memory =
                                    self.layout.nodes.get(*child).ok_or_else(invalid)?.memory;
                                work.push(Check::Value(*child, payload));
                                memory.size
                            } else {
                                0
                            };
                            reader.zero(add(payload, used)?, add(offset, layout.memory.size)?)?;
                        }
                        LayoutKind::Scalar => return Err(invalid()),
                    }
                }
            }
        }
        if usize::try_from(reader.buffer.next).map_err(|_| malformed())? != bytes.len() {
            return Err(malformed());
        }
        Ok(reader.buffer.construction)
    }

    fn build<'e>(
        &self,
        ctx: &NoGcCtx<'e>,
        bytes: &[u8],
        node: usize,
        offset: u32,
    ) -> Result<Value<'e>, CodecError> {
        let mut work = vec![Build::Value(node, offset)];
        let mut out: Vec<Result<Value<'e>, Stop>> = Vec::new();
        while let Some(task) = work.pop() {
            match task {
                Build::Value(id, offset) => {
                    let plan = *self.plans.get(id).ok_or_else(invalid)?;
                    let layout = self.layout.nodes.get(id).ok_or_else(invalid)?;
                    if let Some(v) = scalar(plan, bytes, offset)? {
                        out.push(Ok(v));
                        continue;
                    }
                    match (plan, &layout.kind) {
                        (WitPlan::String | WitPlan::Bytes, _) => {
                            let (base, count) = reference(bytes, offset)?;
                            let content = wire::range(bytes, base, count)?;
                            out.push(if matches!(plan, WitPlan::String) {
                                ctx.alloc_str(
                                    std::str::from_utf8(content).map_err(|_| malformed())?,
                                    "external result",
                                )
                            } else {
                                ctx.alloc_bytes(content, "external result")
                            });
                        }
                        (WitPlan::List(_), LayoutKind::List { element }) => {
                            let (base, count) = reference(bytes, offset)?;
                            let memory =
                                self.layout.nodes.get(*element).ok_or_else(invalid)?.memory;
                            work.push(Build::List(
                                *element,
                                base,
                                memory.stride()?,
                                count,
                                Box::new(list::TryListBuilder::new(
                                    u64::from(count),
                                    "external result",
                                )?),
                            ));
                        }
                        (WitPlan::Map(_, _), LayoutKind::Map { entry }) => {
                            let (base, count) = reference(bytes, offset)?;
                            work.push(Build::Map(
                                &entry.fields,
                                base,
                                entry.memory.stride()?,
                                count,
                                Value::EmptyMap,
                            ));
                        }
                        (WitPlan::Tuple(ps), LayoutKind::Record { fields }) => {
                            work.push(Build::Fields(
                                tuple_tag(ps.len())?,
                                fields,
                                offset,
                                0,
                                Vec::with_capacity(fields.len()),
                            ));
                        }
                        (WitPlan::ConstructorTuple { tag, .. }, LayoutKind::Record { fields }) => {
                            work.push(Build::Fields(
                                *tag,
                                fields,
                                offset,
                                0,
                                Vec::with_capacity(fields.len()),
                            ));
                        }
                        (WitPlan::Record { .. }, LayoutKind::Record { fields }) => {
                            work.push(Build::Fields(
                                tags::RECORD,
                                fields,
                                offset,
                                0,
                                Vec::with_capacity(fields.len()),
                            ));
                        }
                        (WitPlan::Enum { cases }, LayoutKind::Enum { discriminant_size }) => {
                            let (_, tag) = cases
                                .get(index(bytes, offset, *discriminant_size)?)
                                .ok_or_else(malformed)?;
                            out.push(Ok(Value::Tag(CtorTag(*tag))));
                        }
                        (WitPlan::Flags { cases }, _) => {
                            let bits = wire::discriminant(bytes, offset, layout.memory.size)?;
                            let mut set = Ok(Value::EmptySet);
                            for (i, (_, tag)) in cases.iter().enumerate() {
                                let mask = 1_u32
                                    .checked_shl(u32::try_from(i).map_err(|_| invalid())?)
                                    .ok_or_else(invalid)?;
                                if bits & mask != 0 {
                                    set = set.and_then(|s| {
                                        map::set_insert(
                                            ctx,
                                            s,
                                            Value::Tag(CtorTag(*tag)),
                                            "external result",
                                        )
                                    });
                                }
                            }
                            out.push(set);
                        }
                        (
                            _,
                            LayoutKind::Variant {
                                discriminant_size,
                                payload_offset,
                                cases,
                            },
                        ) => {
                            let selected = index(bytes, offset, *discriminant_size)?;
                            let child = *cases.get(selected).ok_or_else(malformed)?;
                            let payload = add(offset, *payload_offset)?;
                            let (tag, unit) = match plan {
                                WitPlan::Option(_) => (
                                    if selected == 0 {
                                        tags::OPTION_NONE
                                    } else {
                                        tags::OPTION_SOME
                                    },
                                    false,
                                ),
                                WitPlan::Result { .. } => (
                                    if selected == 0 {
                                        tags::RESULT_OK
                                    } else {
                                        tags::RESULT_ERROR
                                    },
                                    true,
                                ),
                                WitPlan::Variant { cases } => {
                                    (cases.get(selected).ok_or_else(invalid)?.1, false)
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
                                | WitPlan::TupleFields(_)
                                | WitPlan::ConstructorTuple { .. }
                                | WitPlan::Record { .. }
                                | WitPlan::Enum { .. }
                                | WitPlan::Flags { .. }
                                | WitPlan::Borrow(_)
                                | WitPlan::Own(_) => return Err(invalid()),
                            };
                            if let Some(child) = child {
                                if matches!(self.plans.get(child), Some(WitPlan::TupleFields(_))) {
                                    let LayoutKind::Record { fields } =
                                        &self.layout.nodes.get(child).ok_or_else(invalid)?.kind
                                    else {
                                        return Err(invalid());
                                    };
                                    work.push(Build::Fields(
                                        tag,
                                        fields,
                                        payload,
                                        0,
                                        Vec::with_capacity(fields.len()),
                                    ));
                                } else {
                                    work.push(Build::Wrap(tag));
                                    work.push(Build::Value(child, payload));
                                }
                            } else if unit {
                                out.push(ctx.alloc_fields(FieldsKind::Ctor, tag, &[Value::Unit]));
                            } else {
                                out.push(Ok(Value::Tag(CtorTag(tag))));
                            }
                        }
                        _ => return Err(invalid()),
                    }
                }
                Build::Wrap(tag) => {
                    let value = out.pop().ok_or_else(invalid)?;
                    out.push(value.and_then(|v| ctx.alloc_fields(FieldsKind::Ctor, tag, &[v])));
                }
                Build::Fields(tag, fields, base, index, mut values) => {
                    if index != 0 {
                        values.push(out.pop().ok_or_else(invalid)??);
                    }
                    if let Some(f) = fields.get(index) {
                        work.push(Build::Fields(
                            tag,
                            fields,
                            base,
                            index.saturating_add(1),
                            values,
                        ));
                        work.push(Build::Value(f.node, add(base, f.offset)?));
                    } else {
                        out.push(ctx.alloc_fields(FieldsKind::Ctor, tag, &values));
                    }
                }
                Build::List(node, base, stride, count, builder) => {
                    if count != 0 {
                        work.push(Build::ListItem(node, base, stride, count, builder));
                        work.push(Build::Value(node, base));
                    } else {
                        out.push((*builder).finish(ctx));
                    }
                }
                Build::ListItem(node, base, stride, count, mut builder) => {
                    builder.push(ctx, out.pop().ok_or_else(invalid)?)?;
                    work.push(Build::List(
                        node,
                        add(base, stride)?,
                        stride,
                        count.saturating_sub(1),
                        builder,
                    ));
                }
                Build::Map(fields, base, stride, count, value) => {
                    if count != 0 {
                        let [key, val] = fields else {
                            return Err(invalid());
                        };
                        work.push(Build::MapItem(fields, base, stride, count, value));
                        work.push(Build::Value(val.node, add(base, val.offset)?));
                        work.push(Build::Value(key.node, add(base, key.offset)?));
                    } else {
                        out.push(Ok(value));
                    }
                }
                Build::MapItem(fields, base, stride, count, value) => {
                    let v = out.pop().ok_or_else(invalid)??;
                    let k = out.pop().ok_or_else(invalid)??;
                    let value = map::map_insert(ctx, value, k, v, "external result")?;
                    work.push(Build::Map(
                        fields,
                        add(base, stride)?,
                        stride,
                        count.saturating_sub(1),
                        value,
                    ));
                }
            }
        }
        if out.len() != 1 {
            return Err(invalid());
        }
        Ok(out.pop().ok_or_else(invalid)??)
    }
}

/// 復号した根の並びと、重複を縮める前に数えた論理上の構築量。
pub(crate) struct Decoded<'e> {
    pub values: Vec<Value<'e>>,
    pub construction_bytes: u64,
}

enum Check<'a> {
    Value(usize, u32),
    Fields(&'a [FieldLayout], u32, usize),
    Array(usize, u32, u32, u32),
    Map(&'a [FieldLayout], u32, u32, u32),
}

enum Build<'a, 'e> {
    Value(usize, u32),
    Wrap(u32),
    Fields(u32, &'a [FieldLayout], u32, usize, Vec<Value<'e>>),
    List(usize, u32, u32, u32, Box<list::TryListBuilder<'e>>),
    ListItem(usize, u32, u32, u32, Box<list::TryListBuilder<'e>>),
    Map(&'a [FieldLayout], u32, u32, u32, Value<'e>),
    MapItem(&'a [FieldLayout], u32, u32, u32, Value<'e>),
}

struct Reader<'a> {
    bytes: &'a [u8],
    buffer: Buffer,
}
impl Reader<'_> {
    fn zero(&self, start: u32, end: u32) -> Result<(), CodecError> {
        wire::require_zero(wire::range(
            self.bytes,
            start,
            end.checked_sub(start).ok_or_else(malformed)?,
        )?)?;
        Ok(())
    }
    fn record(
        &self,
        fields: &[FieldLayout],
        base: u32,
        size: u32,
        plan: &CodecPlan<'_>,
    ) -> Result<(), CodecError> {
        let mut next = base;
        for f in fields {
            let offset = add(base, f.offset)?;
            self.zero(next, offset)?;
            next = add(
                offset,
                plan.layout
                    .nodes
                    .get(f.node)
                    .ok_or_else(invalid)?
                    .memory
                    .size,
            )?;
        }
        self.zero(next, add(base, size)?)
    }
    fn reference(&mut self, base: u32, count: u32, memory: MemoryLayout) -> Result<(), CodecError> {
        if count == 0 {
            if base != 0 {
                return Err(malformed());
            }
        } else {
            let previous = self.buffer.next;
            let expected = self.buffer.reserve(memory)?;
            if base != expected {
                return Err(malformed());
            }
            self.zero(previous, base)?;
            wire::range(self.bytes, base, memory.size)?;
        }
        Ok(())
    }
    fn minimum(&self, count: u32, item: u64) -> Result<(), CodecError> {
        let minimum = u64::from(count)
            .checked_mul(item)
            .and_then(|n| self.buffer.construction.checked_add(n))
            .ok_or(WireError::ConstructionLimit)?;
        if minimum > self.buffer.limit {
            return Err(WireError::ConstructionLimit.into());
        }
        Ok(())
    }
}

fn reference(bytes: &[u8], offset: u32) -> Result<(u32, u32), CodecError> {
    Ok((
        u32::from_le_bytes(wire::word(bytes, offset)?),
        u32::from_le_bytes(wire::word(
            bytes,
            add(offset, wire::REFERENCE_LENGTH_OFFSET)?,
        )?),
    ))
}
fn index(bytes: &[u8], offset: u32, size: u32) -> Result<usize, CodecError> {
    usize::try_from(wire::discriminant(bytes, offset, size)?).map_err(|_| malformed())
}
fn tuple_tag(count: usize) -> Result<u32, CodecError> {
    match count {
        2 => Ok(tags::PAIR),
        3 => Ok(tags::TRIPLE),
        _ => Err(invalid()),
    }
}
fn malformed() -> CodecError {
    WireError::Internal("adapter wire format mismatch").into()
}
fn scalar<'e>(plan: &WitPlan, bytes: &[u8], offset: u32) -> Result<Option<Value<'e>>, CodecError> {
    Ok(Some(match plan {
        WitPlan::S8 => Value::Int8(i8::from_le_bytes(wire::word(bytes, offset)?)),
        WitPlan::S16 => Value::Int16(i16::from_le_bytes(wire::word(bytes, offset)?)),
        WitPlan::S32 => Value::Int32(i32::from_le_bytes(wire::word(bytes, offset)?)),
        WitPlan::S64 => Value::Int(i64::from_le_bytes(wire::word(bytes, offset)?)),
        WitPlan::U8 => Value::Byte(u8::from_le_bytes(wire::word(bytes, offset)?)),
        WitPlan::U16 => Value::UInt16(u16::from_le_bytes(wire::word(bytes, offset)?)),
        WitPlan::U32 => Value::UInt32(u32::from_le_bytes(wire::word(bytes, offset)?)),
        WitPlan::U64 => Value::UInt64(u64::from_le_bytes(wire::word(bytes, offset)?)),
        WitPlan::F32 => Value::Float32(f32::from_bits(u32::from_le_bytes(wire::word(
            bytes, offset,
        )?))),
        WitPlan::F64 => Value::Float(f64::from_bits(u64::from_le_bytes(wire::word(
            bytes, offset,
        )?))),
        WitPlan::Bool => Value::Bool(match u8::from_le_bytes(wire::word(bytes, offset)?) {
            0 => false,
            1 => true,
            _ => return Err(malformed()),
        }),
        WitPlan::Char => Value::Char(
            char::from_u32(u32::from_le_bytes(wire::word(bytes, offset)?)).ok_or_else(malformed)?,
        ),
        WitPlan::String
        | WitPlan::Bytes
        | WitPlan::List(_)
        | WitPlan::Map(_, _)
        | WitPlan::Tuple(_)
        | WitPlan::TupleFields(_)
        | WitPlan::ConstructorTuple { .. }
        | WitPlan::Record { .. }
        | WitPlan::Enum { .. }
        | WitPlan::Flags { .. }
        | WitPlan::Option(_)
        | WitPlan::Result { .. }
        | WitPlan::Variant { .. }
        | WitPlan::Borrow(_)
        | WitPlan::Own(_) => return Ok(None),
    }))
}
