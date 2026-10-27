//! Log の操作宣言と位置の事前展開の境界（設計書 03-07「Log と SourceLocation」）。

use crate::builtins::iface::{BuiltinDecl, IoReply, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::{StrBuf, Value, ValueCtx};
use crate::runtime::{Stream, list};

// ハンドラ探索が未処理とした操作だけがここへ来る（設計書 02-08「ハンドラと継続」）。
builtin! {
    /// `Log.emit` の既定処理の入口。
    name = "Benitoite.Log.emit",
    io fn emit(ctx, record: Value<'e>) -> IoReply<'e> {
        let mut ctx = ctx;
        if level_rank(field(&ctx, record, 0)?)? == 0 {
            return Ok(IoReply::Done(Value::Unit));
        }
        let mut line = format_record(&ctx, record, "Log.emit")?;
        line.push_char('\n')?;
        match ctx.services().write_output(Stream::Stderr, line.as_str())? {
            None => Ok(IoReply::Done(Value::Unit)),
            Some(wait) => Ok(IoReply::Wait(wait)),
        }
    }
}
builtin! {
    /// `Log.enabled` の既定処理の入口。
    name = "Benitoite.Log.enabled",
    io fn enabled(ctx, level: Value<'e>) -> IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Done(Value::Bool(level_rank(level)? >= 1)))
    }
}
builtin! {
    /// 正常な経路では通常レコードへ展開済みであり、実行には残らない。
    name = "SourceLocation.here",
    pure fn here(ctx) -> Value<'e> {
        let _ = ctx;
        Err(Stop::Internal("SourceLocation.here was not expanded".into()))
    }
}

builtin! {
    /// 既定処理と明示テキストハンドラが共有する純粋な整形。
    name = "Log.formatRecord",
    pure fn format(ctx, record: Value<'e>) -> Value<'e> {
        ctx.alloc_str_buf(format_record(&ctx, record, "Log.formatRecord")?)
    }
}

pub(crate) const DECLS: &[BuiltinDecl] = &[emit::DECL, enabled::DECL, here::DECL, format::DECL];

fn invalid() -> Stop {
    Stop::Internal("invalid structured log value".into())
}

fn field<'e>(ctx: &ValueCtx<'e>, value: Value<'e>, index: u32) -> Result<Value<'e>, Stop> {
    ctx.field(value, index).ok_or_else(invalid)
}

fn level_rank(value: Value<'_>) -> Result<u32, Stop> {
    value
        .as_tag()
        .map(|t| t.0)
        .filter(|n| *n <= 3)
        .ok_or_else(invalid)
}

fn format_record<'e>(
    ctx: &ValueCtx<'e>,
    record: Value<'e>,
    function: &'static str,
) -> Result<StrBuf, Stop> {
    let level = match level_rank(field(ctx, record, 0)?)? {
        0 => text::DEBUG,
        1 => text::INFO,
        2 => text::WARN,
        3 => text::ERROR,
        _ => return Err(invalid()),
    };
    let mut buf = StrBuf::new(function);
    buf.push_str(text::LEVEL)?;
    buf.push_str(level)?;
    buf.push_str(text::SOURCE)?;
    let location = field(ctx, record, 3)?;
    let file = ctx.str(field(ctx, location, 0)?).ok_or_else(invalid)?;
    let line = field(ctx, location, 1)?.as_int().ok_or_else(invalid)?;
    let column = field(ctx, location, 2)?.as_int().ok_or_else(invalid)?;
    // 位置全体を先に有界化し、引用の際も同じ文字列上限を守る（設計書 02-09）。
    let mut source = StrBuf::new(function);
    source.push_str(file)?;
    source.push_str(&format!(":{line}:{column}"))?;
    super::json::quoted(&mut buf, source.as_str())?;
    buf.push_str(text::MESSAGE)?;
    super::json::quoted(
        &mut buf,
        ctx.str(field(ctx, record, 1)?).ok_or_else(invalid)?,
    )?;
    let attributes = field(ctx, record, 2)?;
    let mut attributes = list::cursor(ctx, attributes)?;
    while let Some(attribute) = attributes.next(ctx)? {
        buf.push_str(text::ATTRIBUTE)?;
        super::json::quoted(
            &mut buf,
            ctx.str(field(ctx, attribute, 0)?).ok_or_else(invalid)?,
        )?;
        buf.push_char('=')?;
        let value = field(ctx, attribute, 1)?;
        let (_, tag) = ctx.fields_header(value).ok_or_else(invalid)?;
        let scalar = field(ctx, value, 0)?;
        match tag {
            0 => super::json::quoted(&mut buf, ctx.str(scalar).ok_or_else(invalid)?)?,
            1 => buf.push_str(if scalar.as_bool().ok_or_else(invalid)? {
                text::TRUE
            } else {
                text::FALSE
            })?,
            2 => buf.push_str(&scalar.as_int().ok_or_else(invalid)?.to_string())?,
            3 => buf.push_str(&scalar.as_uint64().ok_or_else(invalid)?.to_string())?,
            4 => {
                let number = scalar.as_float().ok_or_else(invalid)?;
                if number.is_nan() {
                    buf.push_str(text::NAN)?;
                } else if number == f64::INFINITY {
                    buf.push_str(text::INFINITY)?;
                } else if number == f64::NEG_INFINITY {
                    buf.push_str(text::NEG_INFINITY)?;
                } else {
                    buf.push_str(&crate::base::prim::float_to_text(number))?;
                }
            }
            _ => return Err(invalid()),
        }
    }
    Ok(buf)
}

mod text {
    pub const LEVEL: &str = "level=";
    pub const SOURCE: &str = " source=";
    pub const MESSAGE: &str = " message=";
    pub const ATTRIBUTE: &str = " attr.";
    pub const DEBUG: &str = "DEBUG";
    pub const INFO: &str = "INFO";
    pub const WARN: &str = "WARN";
    pub const ERROR: &str = "ERROR";
    pub const TRUE: &str = "true";
    pub const FALSE: &str = "false";
    pub const NAN: &str = "nan";
    pub const INFINITY: &str = "inf";
    pub const NEG_INFINITY: &str = "-inf";
}
