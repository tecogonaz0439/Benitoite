//! ネットワークの失敗の種類と理由（設計書 01-09「ネットワークの失敗の種類（初回リリース版）」）。
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::{
    Stop,
    heap::{CtorTag, FieldsKind, Value},
};

builtin! {
    /// `NetworkError.kind` の本体（実装プラン 10-15）。
    name = "NetworkError.kind",
    pure fn kind(ctx, error: Value<'e>) -> Value<'e> {
        let Some((FieldsKind::NetworkError, tag)) = ctx.fields_header(error) else {
            return Err(Stop::Internal("NetworkError.kind expected NetworkError".into()));
        };
        Ok(Value::Tag(CtorTag(tag)))
    }
}
builtin! {
    /// `NetworkError.message` の本体（実装プラン 10-15）。
    name = "NetworkError.message",
    pure fn message(ctx, error: Value<'e>) -> Value<'e> {
        if !matches!(ctx.fields_header(error), Some((FieldsKind::NetworkError, _))) || ctx.fields_len(error) != Some(1) {
            return Err(Stop::Internal("NetworkError.message expected NetworkError".into()));
        }
        let message = ctx.field(error, 0).ok_or_else(|| Stop::Internal("NetworkError message missing".into()))?;
        if ctx.str(message).is_none() { return Err(Stop::Internal("NetworkError message is not String".into())); }
        Ok(message)
    }
}
/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[kind::DECL, message::DECL];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(clippy::unwrap_used)]
    use super::*;
    use crate::builtins::iface::CallCtx;
    use crate::builtins::table::tags;
    use crate::runtime::heap::{Heap, HeapConfig};
    // 関門: NetworkError の九つの分類と理由を、本番のアクセサで読む（L30）。
    #[test]
    fn all_kinds_and_messages_are_preserved() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let reason = ctx.alloc_str("network reason", "test").unwrap();
            for tag in [tags::NETWORK_ERROR_KIND_HOST_NOT_FOUND, tags::NETWORK_ERROR_KIND_CONNECTION_REFUSED,
                tags::NETWORK_ERROR_KIND_CONNECTION_RESET, tags::NETWORK_ERROR_KIND_TIMED_OUT,
                tags::NETWORK_ERROR_KIND_ADDRESS_IN_USE, tags::NETWORK_ERROR_KIND_INVALID_INPUT,
                tags::NETWORK_ERROR_KIND_PERMISSION_DENIED, tags::NETWORK_ERROR_KIND_INVALID_HTTP_DATA,
                tags::NETWORK_ERROR_KIND_OTHER] {
                let error = ctx.alloc_fields(FieldsKind::NetworkError, tag, &[reason]).unwrap();
                assert!(matches!(kind(CallCtx::new(ctx, None, None, None).pure_ctx(), error).unwrap(), Value::Tag(CtorTag(actual)) if actual == tag));
                let value = message(CallCtx::new(ctx, None, None, None).pure_ctx(), error).unwrap();
                assert_eq!(ctx.str(value), Some("network reason"));
            }
        });
    }
}
