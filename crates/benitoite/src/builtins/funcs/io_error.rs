//! IO の失敗のメッセージと種類（設計書 01-07「IO の失敗」、01-09「IO の失敗の種類」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::Stop;
use crate::runtime::heap::FieldsKind;
use crate::runtime::heap::Value;

builtin! {
    /// `IOError.message` の本体（実装プラン 10-12「項目の一覧」）。
    name = "IOError.message",
    pure fn message(ctx, error: Value<'e>) -> Value<'e> {
        if !matches!(ctx.fields_header(error), Some((FieldsKind::IoError, _)))
            || ctx.fields_len(error) != Some(1)
        {
            return Err(Stop::Internal("IOError.message expected IOError".into()));
        }
        let message = ctx
            .field(error, 0)
            .ok_or_else(|| Stop::Internal("IOError has no message".into()))?;
        if ctx.str(message).is_none() {
            return Err(Stop::Internal("IOError message is not String".into()));
        }
        Ok(message)
    }
}

builtin! {
    /// `IOError.kind` の本体（実装プラン 10-12「項目の一覧」）。
    name = "IOError.kind",
    pure fn kind(ctx, error: Value<'e>) -> Value<'e> {
        let Some((FieldsKind::IoError, tag)) = ctx.fields_header(error) else {
            return Err(Stop::Internal("IOError.kind expected IOError".into()));
        };
        Ok(Value::Tag(crate::runtime::heap::CtorTag(tag)))
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[message::DECL, kind::DECL];

#[cfg(test)]
mod tests;
