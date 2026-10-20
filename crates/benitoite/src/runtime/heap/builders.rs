//! 局所構築器の私有 Host バッファと失敗の原子性（設計書 02-09「構築器の物理バッファ」）。

use super::{CheckedLen, HostData, NoGcCtx, Slot, Trace, Tracer, Value};
use crate::resolve::builders::{BuilderClass, BuilderOp};
use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, SizeUnit, Stop, list};

#[derive(Debug)]
struct StringBuilderData {
    buffer: String,
}
#[derive(Debug)]
struct BytesBuilderData {
    buffer: Vec<u8>,
}
#[derive(Debug)]
struct ListBuilderData {
    buffer: Vec<Slot>,
}

impl Trace for StringBuilderData {
    fn trace(&self, _: &mut Tracer<'_>) {}
}
impl Trace for BytesBuilderData {
    fn trace(&self, _: &mut Tracer<'_>) {}
}
impl Trace for ListBuilderData {
    fn trace(&self, t: &mut Tracer<'_>) {
        self.buffer.trace(t);
    }
}
impl HostData for StringBuilderData {
    fn heap_bytes(&self) -> usize {
        self.buffer.capacity()
    }
}
impl HostData for BytesBuilderData {
    fn heap_bytes(&self) -> usize {
        self.buffer.capacity()
    }
}
impl HostData for ListBuilderData {
    fn heap_bytes(&self) -> usize {
        // Vec が実際に所有できる容量の積は usize に収まる。予約前にも同じ積を検査する。
        match self.buffer.capacity().checked_mul(size_of::<Slot>()) {
            Some(bytes) => bytes,
            None => usize::MAX,
        }
    }
}

/// 空の Host を作る。値は呼び出し側が区間内で専用の根へ保存する。
pub(crate) fn new<'e>(ctx: &NoGcCtx<'e>, kind: BuilderClass) -> Result<Value<'e>, Stop> {
    Ok(match kind {
        BuilderClass::String => ctx.alloc_host(StringBuilderData {
            buffer: String::new(),
        }),
        BuilderClass::Bytes => ctx.alloc_host(BytesBuilderData { buffer: Vec::new() }),
        BuilderClass::List => ctx.alloc_host(ListBuilderData { buffer: Vec::new() }),
    })
}

/// 引数は受け手を除く通常値だけとし、途中に安全点を置かない。
pub(crate) fn apply<'e>(
    ctx: &mut NoGcCtx<'e>,
    kind: BuilderClass,
    op: BuilderOp,
    receiver: Value<'e>,
    args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    apply_with(ctx, kind, op, receiver, args, &mut HostReservation)
}

#[derive(Clone, Copy)]
struct Request {
    capacity: usize,
    bytes: u64,
    function: &'static str,
}
impl Request {
    fn failed(self) -> Stop {
        Stop::Resource(ResourceError::AllocationFailed {
            function: self.function,
            requested_bytes: self.bytes,
        })
    }
}

// ホストの予約だけを差し替える私有の境界。ヒープ・操作・内容の更新は本物を使う。
trait Reservation {
    fn string(&mut self, buffer: &mut String, request: Request) -> Result<(), Stop>;
    fn vector<T>(&mut self, buffer: &mut Vec<T>, request: Request) -> Result<(), Stop>;
}
struct HostReservation;
impl Reservation for HostReservation {
    fn string(&mut self, buffer: &mut String, request: Request) -> Result<(), Stop> {
        buffer
            .try_reserve_exact(
                request
                    .capacity
                    .checked_sub(buffer.len())
                    .ok_or_else(invalid)?,
            )
            .map_err(|_| request.failed())
    }
    fn vector<T>(&mut self, buffer: &mut Vec<T>, request: Request) -> Result<(), Stop> {
        buffer
            .try_reserve_exact(
                request
                    .capacity
                    .checked_sub(buffer.len())
                    .ok_or_else(invalid)?,
            )
            .map_err(|_| request.failed())
    }
}

fn limit(kind: BuilderClass) -> (u64, SizeUnit, usize) {
    match kind {
        BuilderClass::String | BuilderClass::Bytes => (MAX_STRING_BYTES, SizeUnit::Bytes, 1),
        BuilderClass::List => (MAX_LIST_LEN, SizeUnit::Elements, size_of::<Slot>()),
    }
}
fn too_large(kind: BuilderClass, function: &'static str, size: u64) -> Stop {
    let (limit, unit, _) = limit(kind);
    Stop::Resource(ResourceError::ValueTooLarge {
        function,
        size,
        unit,
        limit,
    })
}
fn required(
    kind: BuilderClass,
    function: &'static str,
    current: usize,
    extra: u64,
) -> Result<usize, Stop> {
    let size = u64::try_from(current)
        .ok()
        .and_then(|n| n.checked_add(extra))
        .unwrap_or(u64::MAX);
    match kind {
        BuilderClass::String | BuilderClass::Bytes => CheckedLen::bytes(size, function)?,
        BuilderClass::List => CheckedLen::elements(size, function)?,
    };
    usize::try_from(size).map_err(|_| too_large(kind, function, size))
}
fn request(kind: BuilderClass, function: &'static str, capacity: usize) -> Result<Request, Stop> {
    let bytes = capacity
        .checked_mul(limit(kind).2)
        .filter(|n| *n <= isize::MAX as usize)
        .and_then(|n| u64::try_from(n).ok())
        .ok_or_else(|| too_large(kind, function, u64::MAX))?;
    Ok(Request {
        capacity,
        bytes,
        function,
    })
}
fn growth(
    kind: BuilderClass,
    function: &'static str,
    capacity: usize,
    needed: usize,
) -> Result<Option<Request>, Stop> {
    if needed <= capacity {
        return Ok(None);
    }
    let initial = match kind {
        BuilderClass::List => 8,
        BuilderClass::String | BuilderClass::Bytes => 64,
    };
    let doubled = capacity
        .checked_mul(2)
        .ok_or_else(|| too_large(kind, function, u64::MAX))?;
    let upper = usize::try_from(limit(kind).0).map_err(|_| too_large(kind, function, u64::MAX))?;
    request(kind, function, needed.max(doubled.max(initial).min(upper))).map(Some)
}
fn name(kind: BuilderClass, op: BuilderOp) -> &'static str {
    match (kind, op) {
        (BuilderClass::String, BuilderOp::Append) => "StringBuilder.append",
        (BuilderClass::String, BuilderOp::AppendAll) => "StringBuilder.appendAll",
        (BuilderClass::String, BuilderOp::Copy) => "StringBuilder.copy",
        (BuilderClass::String, BuilderOp::Length) => "StringBuilder.byteLength",
        (BuilderClass::Bytes, BuilderOp::Append) => "BytesBuilder.append",
        (BuilderClass::Bytes, BuilderOp::AppendAll) => "BytesBuilder.appendAll",
        (BuilderClass::Bytes, BuilderOp::Copy) => "BytesBuilder.copy",
        (BuilderClass::Bytes, BuilderOp::Length) => "BytesBuilder.length",
        (BuilderClass::List, BuilderOp::Append) => "ListBuilder.append",
        (BuilderClass::List, BuilderOp::AppendAll) => "ListBuilder.appendAll",
        (BuilderClass::List, BuilderOp::Copy) => "ListBuilder.copy",
        (BuilderClass::List, BuilderOp::Length) => "ListBuilder.length",
    }
}
fn invalid() -> Stop {
    Stop::Internal("invalid local builder operation or value".into())
}

fn apply_with<'e>(
    ctx: &mut NoGcCtx<'e>,
    kind: BuilderClass,
    op: BuilderOp,
    receiver: Value<'e>,
    args: &[Value<'e>],
    reservation: &mut impl Reservation,
) -> Result<Value<'e>, Stop> {
    let function = name(kind, op);
    let append = matches!(op, BuilderOp::Append | BuilderOp::AppendAll);
    if args.len() != usize::from(append) {
        return Err(invalid());
    }
    if !append {
        return read(ctx, kind, op, receiver, function, reservation);
    }
    let arg = *args.first().ok_or_else(invalid)?;
    match kind {
        BuilderClass::String => ctx
            .host_mut_with_values::<StringBuilderData, _>(receiver, |data, _, values| {
                let extra = if op == BuilderOp::Append {
                    u64::from(values.str_byte_len(arg).ok_or_else(invalid)?)
                } else {
                    let mut total = 0_u64;
                    let mut cursor = list::cursor(values, arg)?;
                    while let Some(value) = cursor.next(values)? {
                        let len = u64::from(values.str_byte_len(value).ok_or_else(invalid)?);
                        total = total
                            .checked_add(len)
                            .ok_or_else(|| too_large(kind, function, u64::MAX))?;
                    }
                    total
                };
                let needed = required(kind, function, data.buffer.len(), extra)?;
                if let Some(request) = growth(kind, function, data.buffer.capacity(), needed)? {
                    reservation.string(&mut data.buffer, request)?;
                }
                if op == BuilderOp::Append {
                    data.buffer.push_str(values.str(arg).ok_or_else(invalid)?);
                } else {
                    let mut cursor = list::cursor(values, arg)?;
                    while let Some(value) = cursor.next(values)? {
                        data.buffer.push_str(values.str(value).ok_or_else(invalid)?);
                    }
                }
                Ok(Value::Unit)
            })
            .ok_or_else(invalid)?,
        BuilderClass::Bytes => ctx
            .host_mut_with_values::<BytesBuilderData, _>(receiver, |data, _, values| {
                let single = if op == BuilderOp::Append {
                    let Value::Byte(byte) = arg else {
                        return Err(invalid());
                    };
                    [byte]
                } else {
                    [0]
                };
                let bytes = if op == BuilderOp::Append {
                    single.as_slice()
                } else {
                    values.bytes(arg).ok_or_else(invalid)?
                };
                let needed = required(
                    kind,
                    function,
                    data.buffer.len(),
                    u64::try_from(bytes.len()).unwrap_or(u64::MAX),
                )?;
                if let Some(request) = growth(kind, function, data.buffer.capacity(), needed)? {
                    reservation.vector(&mut data.buffer, request)?;
                }
                data.buffer.extend_from_slice(bytes);
                Ok(Value::Unit)
            })
            .ok_or_else(invalid)?,
        BuilderClass::List => ctx
            .host_mut_with_values::<ListBuilderData, _>(receiver, |data, ops, values| {
                let extra = if op == BuilderOp::Append {
                    1
                } else {
                    u64::from(list::len(values, arg)?)
                };
                let needed = required(kind, function, data.buffer.len(), extra)?;
                if op == BuilderOp::AppendAll {
                    // 入力の表現も予約前に検査し、途中の失敗による部分追記を防ぐ。
                    let mut cursor = list::cursor(values, arg)?;
                    while cursor.next(values)?.is_some() {}
                }
                if let Some(request) = growth(kind, function, data.buffer.capacity(), needed)? {
                    reservation.vector(&mut data.buffer, request)?;
                }
                if op == BuilderOp::Append {
                    data.buffer.push(ops.new_slot(arg));
                } else {
                    let mut cursor = list::cursor(values, arg)?;
                    while let Some(value) = cursor.next(values)? {
                        data.buffer.push(ops.new_slot(value));
                    }
                }
                Ok(Value::Unit)
            })
            .ok_or_else(invalid)?,
    }
}

fn read<'e>(
    ctx: &NoGcCtx<'e>,
    kind: BuilderClass,
    op: BuilderOp,
    receiver: Value<'e>,
    function: &'static str,
    reservation: &mut impl Reservation,
) -> Result<Value<'e>, Stop> {
    match kind {
        BuilderClass::String => {
            let data = ctx
                .host::<StringBuilderData>(receiver)
                .ok_or_else(invalid)?;
            if op == BuilderOp::Length {
                return length(data.buffer.len());
            }
            let checked = CheckedLen::bytes(
                u64::try_from(data.buffer.len()).unwrap_or(u64::MAX),
                function,
            )?;
            let mut buffer = String::new();
            if checked.get() != 0 {
                reservation.string(&mut buffer, request(kind, function, data.buffer.len())?)?;
            }
            buffer.push_str(&data.buffer);
            // 文字列の既存入口は UTF-8 と検査済み長の契約を保つ。
            ctx.alloc_str_parts(&[&buffer], function)
        }
        BuilderClass::Bytes => {
            let data = ctx.host::<BytesBuilderData>(receiver).ok_or_else(invalid)?;
            if op == BuilderOp::Length {
                return length(data.buffer.len());
            }
            let checked = CheckedLen::bytes(
                u64::try_from(data.buffer.len()).unwrap_or(u64::MAX),
                function,
            )?;
            let mut buffer = Vec::new();
            if checked.get() != 0 {
                reservation.vector(&mut buffer, request(kind, function, data.buffer.len())?)?;
            }
            buffer.extend_from_slice(&data.buffer);
            ctx.alloc_bytes_with(checked, |out| out.copy_from_slice(&buffer))
        }
        BuilderClass::List => {
            let data = ctx.host::<ListBuilderData>(receiver).ok_or_else(invalid)?;
            if op == BuilderOp::Length {
                return length(data.buffer.len());
            }
            let count = u64::try_from(data.buffer.len()).unwrap_or(u64::MAX);
            CheckedLen::elements(count, function)?;
            let mut buffer = Vec::new();
            if count != 0 {
                reservation.vector(&mut buffer, request(kind, function, data.buffer.len())?)?;
            }
            for slot in &data.buffer {
                buffer.push(ctx.new_slot(ctx.load(slot)));
            }
            let result = list::from_iter_exact(
                ctx,
                count,
                buffer.iter().map(|slot| ctx.load(slot)),
                function,
            );
            ctx.discard(buffer);
            result
        }
    }
}
fn length<'e>(len: usize) -> Result<Value<'e>, Stop> {
    i64::try_from(len).map(Value::Int).map_err(|_| invalid())
}

#[cfg(test)]
#[path = "builders_tests.rs"]
mod tests;
