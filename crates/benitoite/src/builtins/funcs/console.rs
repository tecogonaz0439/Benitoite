//! Console の組み込みの操作（設計書 03-07「Console」、02-09「出力のバッファ」）。

use crate::builtins::iface::IoCtx;
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::iface::{IoReply, IoWait, Lend, Lent, WorkerWait};
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::Stream;
use crate::runtime::heap::FieldsKind;
use crate::runtime::heap::Value;
use crate::runtime::{MAX_LIST_LEN, MAX_STRING_BYTES, SizeUnit};

builtin! {
    /// `Benitoite.IO.Console.write` の本体。
    name = "Benitoite.IO.Console.write",
    io fn write(ctx, s: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        write_text(&mut ctx, Stream::Stdout, s, false)
    }
}

builtin! {
    /// `Benitoite.IO.Console.writeLine` の本体。
    name = "Benitoite.IO.Console.writeLine",
    io fn write_line(ctx, s: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        write_text(&mut ctx, Stream::Stdout, s, true)
    }
}

builtin! {
    /// `Benitoite.IO.Console.writeError` の本体。
    name = "Benitoite.IO.Console.writeError",
    io fn write_error(ctx, s: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        write_text(&mut ctx, Stream::Stderr, s, false)
    }
}

builtin! {
    /// `Benitoite.IO.Console.writeErrorLine` の本体。
    name = "Benitoite.IO.Console.writeErrorLine",
    io fn write_error_line(ctx, s: &'c str) -> IoReply<'e> {
        let mut ctx = ctx;
        write_text(&mut ctx, Stream::Stderr, s, true)
    }
}

builtin! {
    /// `Benitoite.IO.Console.readLine` の本体。
    name = "Benitoite.IO.Console.readLine",
    io fn read_line(ctx) -> IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Stdin,
            |lent| {
                let Lent::Stdin(reader) = lent else {
                    return Err(Stop::Internal("Console.readLine requires lent stdin".into()));
                };
                Ok(super::file::read_line_limited(reader, MAX_STRING_BYTES))
            },
            read_line_done,
        ).after_output_flush())))
    }
}

builtin! {
    /// `Benitoite.IO.Console.readAll` の本体。
    name = "Benitoite.IO.Console.readAll",
    io fn read_all(ctx) -> IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(IoWait::Worker(WorkerWait::new(
            Lend::Stdin,
            |lent| {
                let Lent::Stdin(reader) = lent else {
                    return Err(Stop::Internal("Console.readAll requires lent stdin".into()));
                };
                Ok(super::file::read_all_limited(reader, MAX_STRING_BYTES))
            },
            read_all_done,
        ).after_output_flush())))
    }
}

fn write_text<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    stream: Stream,
    s: &str,
    newline: bool,
) -> Result<IoReply<'e>, Stop> {
    // 改行も含め一回で預け、待ったときもタスクの出力を分割しない（設計書 02-09「出力のバッファ」）。
    let line;
    let s = if newline {
        line = format!("{s}\n");
        line.as_str()
    } else {
        s
    };
    match ctx.services().write_output(stream, s)? {
        None => Ok(IoReply::Done(Value::Unit)),
        Some(wait) => Ok(IoReply::Wait(wait)),
    }
}
/// 部分の項目。番号は表の中の位置で決まるので、末尾以外には加えない。
pub const DECLS: &[BuiltinDecl] = &[
    write::DECL,
    write_line::DECL,
    write_error::DECL,
    write_error_line::DECL,
    read_line::DECL,
    read_all::DECL,
];

fn read_line_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<Result<Option<Vec<u8>>, super::file::IoFailure>, Stop>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    super::file::complete_line(
        ctx,
        output?,
        "Benitoite.IO.Console.readLine",
        MAX_STRING_BYTES,
    )
}
fn read_all_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: Result<Result<Vec<u8>, super::file::IoFailure>, Stop>,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    super::file::complete_text(
        ctx,
        output?,
        "Benitoite.IO.Console.readAll",
        MAX_STRING_BYTES,
    )
}

#[cfg(test)]
mod tests;

builtin! {
    /// `Benitoite.IO.Console.readAllLines` の本体。
    name = "Benitoite.IO.Console.readAllLines",
    io fn read_all_lines(ctx) -> crate::builtins::iface::IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(IoWait::Worker(read_remaining(read_all_lines_done))))
    }
}

builtin! {
    /// `Benitoite.IO.Console.readAllBytes` の本体。
    name = "Benitoite.IO.Console.readAllBytes",
    io fn read_all_bytes(ctx) -> crate::builtins::iface::IoReply<'e> {
        let _ = ctx;
        Ok(IoReply::Wait(IoWait::Worker(read_remaining(read_all_bytes_done))))
    }
}

/// 後から加えた部分の項目。既存の部分の途中に入れると後ろの番号がずれるので、
/// 別の部分にした。末尾以外には加えない。
pub const MORE_DECLS: &[BuiltinDecl] = &[read_all_lines::DECL, read_all_bytes::DECL];

type RemainingInput = Result<Result<Vec<u8>, super::file::IoFailure>, Stop>;

fn read_remaining(
    done: for<'c, 'e> fn(
        &mut IoCtx<'c, 'e>,
        RemainingInput,
        &[Value<'e>],
    ) -> Result<Value<'e>, Stop>,
) -> WorkerWait {
    WorkerWait::new(
        Lend::Stdin,
        |lent| {
            let Lent::Stdin(reader) = lent else {
                return Err(Stop::Internal("Console read requires lent stdin".into()));
            };
            Ok(super::file::read_all_limited(reader, MAX_STRING_BYTES))
        },
        done,
    )
    .after_output_flush()
}

fn remaining_input<'c, 'e>(
    ctx: &IoCtx<'c, 'e>,
    output: RemainingInput,
    function: &'static str,
    limit: u64,
) -> Result<Result<Vec<u8>, Value<'e>>, Stop> {
    match output? {
        Ok(bytes) => {
            super::file::check_input_size(bytes.len(), limit, SizeUnit::Bytes, function)?;
            Ok(Ok(bytes))
        }
        Err(failure) => Ok(Err(super::file::result_error(ctx, failure, function)?)),
    }
}

fn read_all_lines_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: RemainingInput,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    const FUNCTION: &str = "Benitoite.IO.Console.readAllLines";
    let bytes = match remaining_input(ctx, output, FUNCTION, MAX_STRING_BYTES)? {
        Ok(bytes) => bytes,
        Err(error) => return Ok(error),
    };
    let s = match std::str::from_utf8(&bytes) {
        Ok(s) => s,
        Err(_) => {
            return super::file::result_error(
                ctx,
                std::io::Error::new(std::io::ErrorKind::InvalidData, text::INVALID_UTF8).into(),
                FUNCTION,
            );
        }
    };
    let n = super::string::line_parts(s).count();
    super::file::check_input_size(n, MAX_LIST_LEN, SizeUnit::Elements, FUNCTION)?;
    let mut lines = Vec::with_capacity(n);
    for part in super::string::line_parts(s) {
        // 外部入力の各行も UTF-8 を検査する確保の口を通す（設計書 01-07）。
        lines.push(
            ctx.alloc_str_utf8(part.as_bytes(), FUNCTION)?
                .ok_or_else(|| Stop::Internal("validated input line is not UTF-8".into()))?,
        );
    }
    let value = crate::runtime::list::from_values(ctx, &lines, FUNCTION)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}

fn read_all_bytes_done<'c, 'e>(
    ctx: &mut IoCtx<'c, 'e>,
    output: RemainingInput,
    _args: &[Value<'e>],
) -> Result<Value<'e>, Stop> {
    const FUNCTION: &str = "Benitoite.IO.Console.readAllBytes";
    let bytes = match remaining_input(ctx, output, FUNCTION, MAX_STRING_BYTES)? {
        Ok(bytes) => bytes,
        Err(error) => return Ok(error),
    };
    let value = ctx.alloc_bytes(&bytes, FUNCTION)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
}

mod text {
    pub const INVALID_UTF8: &str = "input is not valid UTF-8";
}
