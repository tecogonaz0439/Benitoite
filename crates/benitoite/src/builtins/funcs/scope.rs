//! Scopeの純粋な判定を既存Result/Pairへ包む（設計書 03-06「Scope」）。
//! checkPathInは形式と所属を検査して同じパスをPathInに保持し、失敗時はScopeErrorを作り、pathInValueは保持したパスを直接返す。
//! widenPathInは範囲の被覆を確かめて同じ不透明値を返す。

use crate::builtins::checked_scope::{self, CheckedPair, Failure};
use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::heap::{FieldsKind, Value, ValueCtx};
use crate::types::scope::{Kind, Path, Range, Target};

fn string<'c, 'e>(ctx: &'c ValueCtx<'e>, value: Value<'e>) -> Result<&'c str, Stop> {
    ctx.str(value)
        .ok_or_else(|| Stop::Internal("Scope expected String".into()))
}

fn result<'e>(
    ctx: &ValueCtx<'e>,
    checked: Result<Option<CheckedPair<'_>>, Failure>,
) -> Result<Value<'e>, Stop> {
    let (tag, first, second) = match checked {
        Ok(Some(pair)) => {
            // 共通判定が返す正規形を保存する。小文字化と最大prefixの省略は
            // 入力より長くならず、既にStringが満たした大きさの上限を保つ。
            (
                tags::RESULT_OK,
                ctx.alloc_str(&pair.pattern, "Scope.check")?,
                ctx.alloc_str(&pair.target, "Scope.check")?,
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

fn path_in_result<'e>(
    ctx: &ValueCtx<'e>,
    pattern: Value<'e>,
    path: Value<'e>,
    range: &Range,
) -> Result<Value<'e>, Stop> {
    let path_text = string(ctx, path)?;
    let checked = checked_scope::check_path(Some(string(ctx, pattern)?), Some(path_text)).and_then(
        |checked| {
            let target = Path::parse(path_text).map_err(|_| Failure::OutsideScope)?;
            if range.matches_kind(Kind::Path, &Target::Path(target)) {
                Ok(checked)
            } else {
                Err(Failure::OutsideScope)
            }
        },
    );
    let (tag, value) = match checked {
        Ok(Some(_)) => {
            // 不透明型の欄に検査したStringそのものを残す。既存の構成子の追跡で
            // 安全点を越えて保持でき、射影で複製も再検査も要らない
            // （設計書 02-08「値の表現」、03-06「Scope」）。
            let value = ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &[path])?;
            (tags::RESULT_OK, value)
        }
        Ok(None) => return Err(Stop::Internal("Scope runtime input was incomplete".into())),
        Err(failure) => {
            let (tag, args) = match failure {
                Failure::InvalidPattern(reason) => (
                    tags::SCOPE_ERROR_INVALID_PATTERN,
                    [pattern, ctx.alloc_str(reason, "Scope.checkPathIn")?],
                ),
                Failure::InvalidTarget(reason) => (
                    tags::SCOPE_ERROR_INVALID_TARGET,
                    [path, ctx.alloc_str(reason, "Scope.checkPathIn")?],
                ),
                Failure::OutsideScope => (tags::SCOPE_ERROR_OUTSIDE_SCOPE, [pattern, path]),
                Failure::InvalidMinimum
                | Failure::InvalidMaximum
                | Failure::InvalidBounds
                | Failure::InvalidPort
                | Failure::PortOutsideScope => {
                    return Err(Stop::Internal(
                        "Scope path check returned a port failure".into(),
                    ));
                }
            };
            let error = ctx.alloc_fields(FieldsKind::Ctor, tag, &args)?;
            (tags::RESULT_ERROR, error)
        }
    };
    ctx.alloc_fields(FieldsKind::Ctor, tag, &[value])
}

builtin! {
    /// 動的なパターンと所属を検査し、同じパスを保存する（設計書 03-06「Scope」）。
    name = "Scope.checkPathIn",
    pure fn check_path_in(ctx, pattern: Value<'e>, path: Value<'e>) -> Value<'e> {
        let [range] = ctx.ranges() else {
            return Err(Stop::Internal("Scope check requires one static range".into()));
        };
        if !range.fits_kind(Kind::Path) {
            return Err(Stop::Internal("Scope check requires a path range".into()));
        }
        path_in_result(&ctx, pattern, path, range)
    }
}

builtin! {
    /// 戻りの範囲による被覆を確かめ、同じ不透明値を返す（設計書 03-06「Scope」）。
    name = "Scope.widenPathIn",
    pure fn widen_path_in(ctx, path: Value<'e>) -> Value<'e> {
        let [source, destination] = ctx.ranges() else {
            return Err(Stop::Internal("Scope widen requires two static ranges".into()));
        };
        if !source.fits_kind(Kind::Path) || !destination.fits_kind(Kind::Path)
            || !destination.covers(source)
        {
            return Err(Stop::Internal("Scope widen requires covering path ranges".into()));
        }
        path_in_value(ctx, path)?;
        Ok(path)
    }
}

builtin! {
    /// 検査済みの不透明値から保存したパスを直接返す（設計書 03-06「Scope」）。
    name = "Scope.pathInValue",
    pure fn path_in_value(ctx, path: Value<'e>) -> Value<'e> {
        if ctx.fields_header(path) != Some((FieldsKind::Ctor, tags::RECORD))
            || ctx.fields_len(path) != Some(1)
        {
            return Err(Stop::Internal("Scope expected PathIn".into()));
        }
        let value = ctx.field(path, 0)
            .ok_or_else(|| Stop::Internal("Scope PathIn lost its path".into()))?;
        string(&ctx, value)?;
        Ok(value)
    }
}

/// 番号を保つため、表の末尾にだけ登録する。
pub const DECLS: &[BuiltinDecl] = &[
    check_host::DECL,
    check_path::DECL,
    check_endpoint::DECL,
    check_path_in::DECL,
    path_in_value::DECL,
    widen_path_in::DECL,
];
