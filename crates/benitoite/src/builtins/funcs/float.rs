//! 浮動小数の変換と演算（設計書 01-04「Float」「型の変換」、03-06「Float」）。
//! 仮の本体は、後の作業が本体と Rust の引数型だけを書き換える。
//! 名前・権限・引数の数・DECLS の中の位置は変えない（実装プラン 10-12「まだ書かない項目の仮の本体」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;

builtin! {
    /// `Float.toString` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.toString",
    pure fn to_string(ctx, n: f64) -> Value<'e> {
        ctx.alloc_str(&crate::base::prim::float_to_text(n), "Float.toString")
    }
}

builtin! {
    /// `Float.parse` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.parse",
    pure fn parse(ctx, s: &'c str) -> Value<'e> {
        let parsed = super::decimal_float(s)
            .then(|| s.parse::<f64>().ok())
            .flatten()
            .filter(|v| v.is_finite());
        super::option(&ctx, parsed.map(Value::Float))
    }
}

builtin! {
    /// `Float.truncate` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.truncate",
    pure fn truncate(ctx, n: f64) -> Value<'e> {
        let n = n.trunc();
        let value = if n.is_finite()
            && (-9_223_372_036_854_775_808.0..9_223_372_036_854_775_808.0).contains(&n)
        {
            // 上の検査によって切り捨てた整数が i64 に収まる（設計書 01-04「型の変換」）。
            Some(Value::Int(n as i64))
        } else {
            None
        };
        super::option(&ctx, value)
    }
}

builtin! {
    /// `Float.isNaN` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.isNaN",
    pure fn is_na_n(ctx, n: f64) -> bool {
        let _ = ctx;
        Ok(n.is_nan())
    }
}

builtin! {
    /// `Float.absolute` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.absolute",
    pure fn absolute(ctx, n: f64) -> f64 {
        let _ = ctx;
        Ok(n.abs())
    }
}

builtin! {
    /// `Float.floor` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.floor",
    pure fn floor(ctx, n: f64) -> f64 {
        let _ = ctx;
        Ok(n.floor())
    }
}

builtin! {
    /// `Float.ceiling` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.ceiling",
    pure fn ceiling(ctx, n: f64) -> f64 {
        let _ = ctx;
        Ok(n.ceil())
    }
}

builtin! {
    /// `Float.round` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.round",
    pure fn round(ctx, n: f64) -> f64 {
        let _ = ctx;
        Ok(n.round())
    }
}

builtin! {
    /// `Float.squareRoot` の本体（実装プラン 10-12「項目の一覧」）。
    name = "Float.squareRoot",
    pure fn square_root(ctx, n: f64) -> f64 {
        let _ = ctx;
        Ok(n.sqrt())
    }
}

/// 部分の項目。末尾以外には加えない（実装プラン 10-12「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    to_string::DECL,
    parse::DECL,
    truncate::DECL,
    is_na_n::DECL,
    absolute::DECL,
    floor::DECL,
    ceiling::DECL,
    round::DECL,
    square_root::DECL,
];
