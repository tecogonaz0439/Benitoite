//! IOError の種類を値から取り出す契約（実装プラン R29）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(clippy::unwrap_used)]
use super::*;
use crate::builtins::iface::CallCtx;
use crate::builtins::table::tags;
use crate::runtime::heap::{Heap, HeapConfig};
// 関門: VM と参照インタプリタで共有する本体の分類を確かめる。message のテストではタグを読まない。
#[test]
fn kind_returns_each_of_the_nine_kinds() {
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let message = ctx.alloc_str("reason", "test").unwrap();
        for tag in [tags::IO_ERROR_KIND_NOT_FOUND, tags::IO_ERROR_KIND_PERMISSION_DENIED,
            tags::IO_ERROR_KIND_ALREADY_EXISTS, tags::IO_ERROR_KIND_IS_DIRECTORY,
            tags::IO_ERROR_KIND_NOT_DIRECTORY, tags::IO_ERROR_KIND_DIRECTORY_NOT_EMPTY,
            tags::IO_ERROR_KIND_INVALID_INPUT, tags::IO_ERROR_KIND_INVALID_UTF8, tags::IO_ERROR_KIND_OTHER] {
            let error = ctx.alloc_fields(FieldsKind::IoError, tag, &[message]).unwrap();
            assert!(matches!(kind(CallCtx::new(ctx, None, None, None).pure_ctx(), error).unwrap(), Value::Tag(crate::runtime::heap::CtorTag(t)) if t == tag));
        }
        assert!(matches!(kind(CallCtx::new(ctx, None, None, None).pure_ctx(), Value::Unit), Err(Stop::Internal(_))));
    });
}
