//! Clock の組み込みの操作（設計書 03-07「Clock」）。

use crate::builtins::iface::IoReply;
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::heap::FieldsKind;
use crate::runtime::heap::Value;

builtin! {
    /// `Benitoite.IO.Clock.sleep` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Benitoite.IO.Clock.sleep",
    io fn sleep(ctx, millis: i64) -> IoReply<'e> {
        let _ = ctx;
        if millis <= 0 {
            return Ok(IoReply::Done(Value::Unit));
        }
        let millis = u64::try_from(millis)
            .map_err(|_| Stop::Internal("positive sleep duration does not fit u64".into()))?;
        Ok(IoReply::Wait(crate::builtins::iface::IoWait::Sleep { millis }))
    }
}

builtin! {
    /// `Benitoite.IO.Clock.monotonicMilliseconds` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Benitoite.IO.Clock.monotonicMilliseconds",
    io fn monotonic_milliseconds(ctx) -> IoReply<'e> {
        let mut ctx = ctx;
        Ok(IoReply::Done(Value::Int(ctx.services().monotonic_millis())))
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[sleep::DECL, monotonic_milliseconds::DECL];

#[cfg(test)]
mod tests;

builtin! {
    /// `Benitoite.IO.Clock.now` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Clock.now",
    io fn now(ctx) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        let nanos = ctx.services().now_millis().checked_mul(1_000_000)
            .ok_or(Stop::Runtime(crate::runtime::RuntimeError::IntegerOverflow))?;
        Ok(IoReply::Done(ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &[Value::Int(nanos)])?))
    }
}

builtin! {
    /// `Benitoite.IO.Clock.localOffsetMinutes` の本体（実装プラン 10-15「項目の一覧」）。
    name = "Benitoite.IO.Clock.localOffsetMinutes",
    io fn local_offset_minutes(ctx) -> crate::builtins::iface::IoReply<'e> {
        let mut ctx = ctx;
        Ok(IoReply::Done(Value::Int(i64::from(ctx.services().local_offset_minutes()))))
    }
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const MORE_DECLS: &[BuiltinDecl] = &[now::DECL, local_offset_minutes::DECL];
