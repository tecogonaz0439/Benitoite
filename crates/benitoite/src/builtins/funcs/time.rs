//! 固定の時差による時刻の計算・暦変換・書式（設計書 03-08「Time」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{FieldsKind, StrBuf, Value, ValueCtx};
use crate::runtime::{RuntimeError, Stop};
use jiff::{Timestamp, civil::DateTime, fmt::strtime::BrokenDownTime, tz::Offset};

mod text {
    pub const INSTANT_RANGE: &str = "time is outside the range of Time.Instant";
    pub const FIELD_RANGE: &str = "date and time field is out of range";
    pub const FORMAT_SPECIFIER: &str = "unknown or incomplete time format specifier";
}

// 欄の位置はソースの宣言順に揃える（実装プラン 10-15「レコードの値の作り方」）。
mod instant {
    pub const UNIX_NANOSECONDS: u32 = 0;
}

mod date_time {
    pub const YEAR: u32 = 0;
    pub const MONTH: u32 = 1;
    pub const DAY: u32 = 2;
    pub const HOUR: u32 = 3;
    pub const MINUTE: u32 = 4;
    pub const SECOND: u32 = 5;
    pub const NANOSECOND: u32 = 6;
    pub const OFFSET_MINUTES: u32 = 7;
}

const SECOND_NANOS: i128 = 1_000_000_000;
const MILLISECOND_NANOS: i128 = 1_000_000;

builtin! {
    /// `Time.fromUnixSeconds` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.fromUnixSeconds",
    pure fn from_unix_seconds(ctx, arg0: Value<'e>) -> Value<'e> {
        let nanos = scaled(integer(arg0)?, SECOND_NANOS)?;
        make_instant(&ctx, narrow(nanos)?)
    }
}

builtin! {
    /// `Time.fromUnixMilliseconds` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.fromUnixMilliseconds",
    pure fn from_unix_milliseconds(ctx, arg0: Value<'e>) -> Value<'e> {
        let nanos = scaled(integer(arg0)?, MILLISECOND_NANOS)?;
        make_instant(&ctx, narrow(nanos)?)
    }
}

builtin! {
    /// `Time.toUnixSeconds` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.toUnixSeconds",
    pure fn to_unix_seconds(ctx, arg0: Value<'e>) -> Value<'e> {
        Ok(Value::Int(narrow(i128::from(nanoseconds(&ctx, arg0)?).div_euclid(SECOND_NANOS))?))
    }
}

builtin! {
    /// `Time.toUnixMilliseconds` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.toUnixMilliseconds",
    pure fn to_unix_milliseconds(ctx, arg0: Value<'e>) -> Value<'e> {
        Ok(Value::Int(narrow(i128::from(nanoseconds(&ctx, arg0)?).div_euclid(MILLISECOND_NANOS))?))
    }
}

builtin! {
    /// `Time.addMilliseconds` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.addMilliseconds",
    pure fn add_milliseconds(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        // 積だけを i64 に戻すと、負の時刻との和が収まる場合まで拒否する（実装プラン L24）。
        let nanos = i128::from(nanoseconds(&ctx, arg0)?)
            .checked_add(scaled(integer(arg1)?, MILLISECOND_NANOS)?)
            .ok_or_else(|| Stop::Internal("time addition exceeds i128".into()))?;
        make_instant(&ctx, narrow(nanos)?)
    }
}

builtin! {
    /// `Time.differenceMilliseconds` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.differenceMilliseconds",
    pure fn difference_milliseconds(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let nanos = i128::from(nanoseconds(&ctx, arg0)?)
            .checked_sub(i128::from(nanoseconds(&ctx, arg1)?))
            .ok_or_else(|| Stop::Internal("time difference exceeds i128".into()))?;
        Ok(Value::Int(narrow(nanos.div_euclid(MILLISECOND_NANOS))?))
    }
}

builtin! {
    /// `Time.toDateTime` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.toDateTime",
    pure fn to_date_time(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let minutes = integer(arg1)?;
        let offset = checked_offset(minutes, "Time.toDateTime", 1)?;
        let dt = offset.to_datetime(timestamp(&ctx, arg0)?);
        ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &[
            Value::Int(i64::from(dt.year())), Value::Int(i64::from(dt.month())),
            Value::Int(i64::from(dt.day())), Value::Int(i64::from(dt.hour())),
            Value::Int(i64::from(dt.minute())), Value::Int(i64::from(dt.second())),
            Value::Int(i64::from(dt.subsec_nanosecond())), Value::Int(minutes),
        ])
    }
}

builtin! {
    /// `Time.fromDateTime` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.fromDateTime",
    pure fn from_date_time(ctx, arg0: Value<'e>) -> Value<'e> {
        // 日付が不正でも時差の定義域の違反を先に報告する（設計書 03-08「Time」）。
        let minutes = field(&ctx, arg0, date_time::OFFSET_MINUTES)?;
        let offset = checked_offset(minutes, "Time.fromDateTime", 0)?;
        let fields = [
            field(&ctx, arg0, date_time::YEAR)?, field(&ctx, arg0, date_time::MONTH)?,
            field(&ctx, arg0, date_time::DAY)?, field(&ctx, arg0, date_time::HOUR)?,
            field(&ctx, arg0, date_time::MINUTE)?, field(&ctx, arg0, date_time::SECOND)?,
            field(&ctx, arg0, date_time::NANOSECOND)?,
        ];
        match civil_time(fields).and_then(|dt| offset.to_timestamp(dt).map_err(|e| e.to_string())) {
            Ok(ts) => timestamp_result(&ctx, ts, "Time.fromDateTime"),
            Err(message) => error_value(&ctx, &message, "Time.fromDateTime"),
        }
    }
}

builtin! {
    /// `Time.formatISO8601` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.formatISO8601",
    pure fn format_i_s_o8601(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let offset = checked_offset(integer(arg1)?, "Time.formatISO8601", 1)?;
        let ts = timestamp(&ctx, arg0)?;
        let printer = jiff::fmt::temporal::DateTimePrinter::new();
        let mut writer = TimeWriter::new("Time.formatISO8601");
        let result = if offset == Offset::UTC {
            printer.print_timestamp(&ts, jiff::fmt::StdFmtWrite(&mut writer))
        } else {
            printer.print_timestamp_with_offset(&ts, offset, jiff::fmt::StdFmtWrite(&mut writer))
        };
        writer.finish(result)?;
        ctx.alloc_str_buf(writer.buf)
    }
}

builtin! {
    /// `Time.parseISO8601` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.parseISO8601",
    pure fn parse_i_s_o8601(ctx, arg0: Value<'e>) -> Value<'e> {
        let source = ctx.str(arg0).ok_or_else(|| Stop::Internal("time text is not String".into()))?;
        // Timestamp の解析は注記を読み飛ばし、名前の解決を行わない（設計書 03-08「Time」）。
        match source.parse::<Timestamp>() {
            Ok(ts) => timestamp_result(&ctx, ts, "Time.parseISO8601"),
            Err(error) => error_value(&ctx, &error.to_string(), "Time.parseISO8601"),
        }
    }
}

builtin! {
    /// `Time.format` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Time.format",
    pure fn format(ctx, arg0: Value<'e>, arg1: Value<'e>, arg2: Value<'e>) -> Value<'e> {
        let offset = checked_offset(integer(arg1)?, "Time.format", 1)?;
        let ts = timestamp(&ctx, arg0)?;
        let pattern = ctx.str(arg2).ok_or_else(|| Stop::Internal("time pattern is not String".into()))?;
        let mut dt = BrokenDownTime::from(offset.to_datetime(ts));
        dt.set_offset(Some(offset));
        let mut writer = TimeWriter::new("Time.format");
        let mut chars = pattern.chars();
        while let Some(c) = chars.next() {
            if c != '%' {
                writer.buf.push_char(c)?;
                continue;
            }
            // 字句単位の変換なら %%f を壊さず、フラグや幅を拒否できる（設計書 03-08「Time」、実装プラン L24）。
            let specifier = match chars.next() {
                Some('Y') => "%Y", Some('m') => "%m", Some('d') => "%d",
                Some('H') => "%H", Some('I') => "%I", Some('p') => "%p",
                Some('M') => "%M", Some('S') => "%S", Some('f') => "%9f",
                Some('j') => "%j", Some('a') => "%a", Some('A') => "%A",
                Some('b') => "%b", Some('B') => "%B", Some('z') => "%z",
                Some('%') => "%%",
                Some(':') if chars.next() == Some('z') => "%:z",
                _ => return error_value(&ctx, text::FORMAT_SPECIFIER, "Time.format"),
            };
            let result = dt.format(specifier, jiff::fmt::StdFmtWrite(&mut writer));
            writer.finish(result)?;
        }
        let value = ctx.alloc_str_buf(writer.buf)?;
        ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
    }
}

fn integer(value: Value<'_>) -> Result<i64, Stop> {
    value
        .as_int()
        .ok_or_else(|| Stop::Internal("time field is not Integer".into()))
}

fn field<'e>(ctx: &ValueCtx<'e>, value: Value<'e>, index: u32) -> Result<i64, Stop> {
    if ctx.fields_header(value) != Some((FieldsKind::Ctor, tags::RECORD)) {
        return Err(Stop::Internal("time value is not a record".into()));
    }
    integer(
        ctx.field(value, index)
            .ok_or_else(|| Stop::Internal("missing time record field".into()))?,
    )
}

fn nanoseconds<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<i64, Stop> {
    field(ctx, value, instant::UNIX_NANOSECONDS)
}

fn scaled(value: i64, scale: i128) -> Result<i128, Stop> {
    i128::from(value)
        .checked_mul(scale)
        .ok_or_else(|| Stop::Internal("time product exceeds i128".into()))
}

fn narrow(nanos: i128) -> Result<i64, Stop> {
    i64::try_from(nanos).map_err(|_| Stop::Runtime(RuntimeError::IntegerOverflow))
}

fn make_instant<'e>(ctx: &ValueCtx<'e>, nanos: i64) -> Result<Value<'e>, Stop> {
    ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &[Value::Int(nanos)])
}

fn timestamp<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> Result<Timestamp, Stop> {
    Timestamp::from_nanosecond(i128::from(nanoseconds(ctx, value)?))
        .map_err(|e| Stop::Internal(format!("Integer nanoseconds rejected by jiff: {e}")))
}

fn checked_offset(minutes: i64, function: &'static str, argument: u16) -> Result<Offset, Stop> {
    if !(-1439..=1439).contains(&minutes) {
        return Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
            function,
            argument,
        }));
    }
    let seconds = minutes
        .checked_mul(60)
        .and_then(|n| i32::try_from(n).ok())
        .ok_or_else(|| Stop::Internal("checked time offset does not fit i32".into()))?;
    Offset::from_seconds(seconds)
        .map_err(|e| Stop::Internal(format!("checked time offset rejected by jiff: {e}")))
}

fn civil_time(fields: [i64; 7]) -> Result<DateTime, String> {
    let [year, month, day, hour, minute, second, nanos] = fields;
    let range = |_| text::FIELD_RANGE.to_owned();
    DateTime::new(
        i16::try_from(year).map_err(range)?,
        i8::try_from(month).map_err(range)?,
        i8::try_from(day).map_err(range)?,
        i8::try_from(hour).map_err(range)?,
        i8::try_from(minute).map_err(range)?,
        i8::try_from(second).map_err(range)?,
        i32::try_from(nanos).map_err(range)?,
    )
    .map_err(|e| e.to_string())
}

fn timestamp_result<'e>(
    ctx: &ValueCtx<'e>,
    ts: Timestamp,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    match i64::try_from(ts.as_nanosecond()) {
        Ok(nanos) => {
            let value = make_instant(ctx, nanos)?;
            ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
        }
        Err(_) => error_value(ctx, text::INSTANT_RANGE, function),
    }
}

fn error_value<'e>(
    ctx: &ValueCtx<'e>,
    message: &str,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let message = ctx.alloc_str(message, function)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_ERROR, &[message])
}

// jiff の書き出しを上限付きの構築器につなぐ。資源の不足は jiff の誤りにせず
// Stop のまま返す（設計書 02-09「一つの操作で作る値の大きさの上限」）。
struct TimeWriter {
    buf: StrBuf,
    failure: Option<Stop>,
}

impl TimeWriter {
    fn new(function: &'static str) -> Self {
        Self {
            buf: StrBuf::new(function),
            failure: None,
        }
    }

    fn finish(&mut self, result: Result<(), jiff::Error>) -> Result<(), Stop> {
        if let Some(stop) = self.failure.take() {
            return Err(stop);
        }
        result.map_err(|e| Stop::Internal(format!("valid time format rejected by jiff: {e}")))
    }
}

impl std::fmt::Write for TimeWriter {
    fn write_str(&mut self, s: &str) -> std::fmt::Result {
        self.buf.push_str(s).map_err(|stop| {
            self.failure = Some(stop);
            std::fmt::Error
        })
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    from_unix_seconds::DECL,
    from_unix_milliseconds::DECL,
    to_unix_seconds::DECL,
    to_unix_milliseconds::DECL,
    add_milliseconds::DECL,
    difference_milliseconds::DECL,
    to_date_time::DECL,
    from_date_time::DECL,
    format_i_s_o8601::DECL,
    parse_i_s_o8601::DECL,
    format::DECL,
];

#[cfg(test)]
mod tests;
