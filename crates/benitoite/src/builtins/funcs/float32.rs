//! 単精度の変換と標準関数を、型付きの呼び出しで実行する。
//! （設計書 01-04「型の変換」、02-08「組み込みの関数の呼び出し」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::runtime::heap::Value;

builtin! {
    /// 最近接偶数丸めで縮小し、有限値が無限大になった場合だけ None を返す。
    name = "Float32.fromFloat",
    pure fn from_float(ctx, n: f64) -> Value<'e> {
        // 縮小の丸めを行い、範囲を外れた有限値は結果の検査で拒否する。
        // 元からの特殊値と、零へ丸められた値の符号は保持する。
        // `as` は最近接偶数丸めのために使う（設計書 01-04「型の変換」）。
        let narrowed = n as f32;
        let value = (!n.is_finite() || narrowed.is_finite()).then_some(Value::Float32(narrowed));
        super::option(&ctx, value)
    }
}

builtin! {
    /// 有限値と零の符号を正確に保って拡大する。
    name = "Float32.toFloat",
    pure fn to_float(ctx, n: f32) -> f64 {
        let _ = ctx;
        Ok(f64::from(n))
    }
}

builtin! {
    /// Float と同じ十進の字句を直接単精度で読み、有限値だけを返す。
    name = "Float32.parse",
    pure fn parse(ctx, s: &'c str) -> Value<'e> {
        let parsed = super::decimal_float(s)
            .then(|| s.parse::<f32>().ok())
            .flatten()
            .filter(|v| v.is_finite());
        super::option(&ctx, parsed.map(Value::Float32))
    }
}

builtin! {
    /// 零へ切り捨て、Integer の範囲外と特殊値には None を返す。
    name = "Float32.truncate",
    pure fn truncate(ctx, n: f32) -> Value<'e> {
        let n = n.trunc();
        let value = if n.is_finite()
            && (-9_223_372_036_854_775_808.0..9_223_372_036_854_775_808.0).contains(&n)
        {
            // 上限を含めない検査によって、切り捨てた整数が i64 に収まる。
            Some(Value::Int(n as i64))
        } else {
            None
        };
        super::option(&ctx, value)
    }
}

builtin! {
    /// NaN かを返す。
    name = "Float32.isNaN",
    pure fn is_na_n(ctx, n: f32) -> bool {
        let _ = ctx;
        Ok(n.is_nan())
    }
}

builtin! {
    /// 正負の無限大かを返す。
    name = "Float32.isInfinite",
    pure fn is_infinite(ctx, n: f32) -> bool {
        let _ = ctx;
        Ok(n.is_infinite())
    }
}

builtin! {
    /// 符号を正にする。
    name = "Float32.absolute",
    pure fn absolute(ctx, n: f32) -> f32 {
        let _ = ctx;
        Ok(n.abs())
    }
}

builtin! {
    /// 負の無限大へ切り捨てる。
    name = "Float32.floor",
    pure fn floor(ctx, n: f32) -> f32 {
        let _ = ctx;
        Ok(n.floor())
    }
}

builtin! {
    /// 正の無限大へ切り上げる。
    name = "Float32.ceiling",
    pure fn ceiling(ctx, n: f32) -> f32 {
        let _ = ctx;
        Ok(n.ceil())
    }
}

builtin! {
    /// 最近接の整数へ丸め、半分なら零から遠い側へ丸める。
    name = "Float32.round",
    pure fn round(ctx, n: f32) -> f32 {
        let _ = ctx;
        Ok(n.round())
    }
}

builtin! {
    /// 単精度の平方根を返し、負値なら NaN を返す。
    name = "Float32.squareRoot",
    pure fn square_root(ctx, n: f32) -> f32 {
        let _ = ctx;
        Ok(n.sqrt())
    }
}

/// 既存の番号を保つため、全体の登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    from_float::DECL,
    to_float::DECL,
    parse::DECL,
    truncate::DECL,
    is_na_n::DECL,
    is_infinite::DECL,
    absolute::DECL,
    floor::DECL,
    ceiling::DECL,
    round::DECL,
    square_root::DECL,
];
