//! Scopeの純粋な判定を既存Result/Pairへ包む（設計書 03-06「Scope」）。

use crate::builtins::checked_scope::{self, CheckedPair, Failure};
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::heap::{FieldsKind, Value, ValueCtx};

fn string<'c, 'e>(ctx: &'c ValueCtx<'e>, value: Value<'e>) -> Result<&'c str, Stop> {
    ctx.str(value)
        .ok_or_else(|| Stop::Internal("Scope expected String".into()))
}

fn normalized(text: &str, lowercase: bool) -> std::borrow::Cow<'_, str> {
    if lowercase {
        std::borrow::Cow::Owned(text.to_ascii_lowercase())
    } else {
        std::borrow::Cow::Borrowed(text)
    }
}

fn result<'e>(
    ctx: &ValueCtx<'e>,
    checked: Result<Option<CheckedPair<'_>>, Failure>,
) -> Result<Value<'e>, Stop> {
    let (tag, first, second) = match checked {
        Ok(Some(pair)) => {
            // 静的検査は成功文字列を複製しない。実行時のASCII小文字化は入力と
            // 同じ長さなので、既にStringが満たした大きさの上限を保つ。
            (
                tags::RESULT_OK,
                ctx.alloc_str(&normalized(pair.pattern, pair.lowercase), "Scope.check")?,
                ctx.alloc_str(&normalized(pair.target, pair.lowercase), "Scope.check")?,
            )
        }
        Ok(None) => return Err(Stop::Internal("Scope runtime input was incomplete".into())),
        Err(error) => {
            let (number, reason) = error.encoded();
            (
                tags::RESULT_ERROR,
                Value::Int(number),
                ctx.alloc_str(reason, "Scope.check")?,
            )
        }
    };
    // ValueCtxの区間内だけで合成する。安全点を越える一時値は作らない。
    let pair = ctx.alloc_fields(FieldsKind::Ctor, tags::PAIR, &[first, second])?;
    ctx.alloc_fields(FieldsKind::Ctor, tag, &[pair])
}

builtin! {
    /// ホストの判定。新しい型の構成子タグは標準ソースだけが使う（設計書 03-06「Scope」）。
    name = "Scope.checkHost",
    pure fn check_host(ctx, pattern: Value<'e>, host: Value<'e>) -> Value<'e> {
        result(&ctx, checked_scope::check_host(Some(string(&ctx, pattern)?), Some(string(&ctx, host)?)))
    }
}
builtin! {
    /// 絶対パスの字面を判定する（設計書 03-06「Scope」）。
    name = "Scope.checkPath",
    pure fn check_path(ctx, pattern: Value<'e>, path: Value<'e>) -> Value<'e> {
        result(&ctx, checked_scope::check_path(Some(string(&ctx, pattern)?), Some(string(&ctx, path)?)))
    }
}
builtin! {
    /// ホストと三つの整数を共通の失敗順で判定する（設計書 03-06「Scope」）。
    name = "Scope.checkEndpoint",
    pure fn check_endpoint(ctx, pattern: Value<'e>, host: Value<'e>, minimum: i64, maximum: i64, port: i64) -> Value<'e> {
        result(&ctx, checked_scope::check_endpoint(Some(string(&ctx, pattern)?), Some(string(&ctx, host)?), Some(minimum), Some(maximum), Some(port)))
    }
}

/// 番号を保つため、表の末尾にだけ登録する。
pub const DECLS: &[BuiltinDecl] = &[check_host::DECL, check_path::DECL, check_endpoint::DECL];
