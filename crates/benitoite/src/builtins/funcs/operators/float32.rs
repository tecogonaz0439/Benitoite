//! 単精度の算術を、各結果を f32 に保つ型付きの組み込み呼び出しで実行する
//! （設計書 01-04「Float」、02-08「組み込みの関数の呼び出し」）。

use crate::builtins::iface::{BuiltinDecl, builtin};

builtin! {
    /// 単精度の和を返す。
    name = "%Float32.add",
    pure fn add(ctx, a: f32, b: f32) -> f32 {
        let _ = ctx;
        Ok(std::ops::Add::add(a, b))
    }
}

builtin! {
    /// 単精度の差を返す。
    name = "%Float32.subtract",
    pure fn subtract(ctx, a: f32, b: f32) -> f32 {
        let _ = ctx;
        Ok(std::ops::Sub::sub(a, b))
    }
}

builtin! {
    /// 単精度の積を返す。
    name = "%Float32.multiply",
    pure fn multiply(ctx, a: f32, b: f32) -> f32 {
        let _ = ctx;
        Ok(std::ops::Mul::mul(a, b))
    }
}

builtin! {
    /// 単精度の商を返し、除数が零でも IEEE の結果を保つ。
    name = "%Float32.divide",
    pure fn divide(ctx, a: f32, b: f32) -> f32 {
        let _ = ctx;
        Ok(std::ops::Div::div(a, b))
    }
}

builtin! {
    /// 零を含めて符号を反転する。
    name = "%Float32.negate",
    pure fn negate(ctx, a: f32) -> f32 {
        let _ = ctx;
        Ok(-a)
    }
}

/// 既存の関数の番号を保つため、全体の登録表の末尾へ置く。
pub(crate) const DECLS: &[BuiltinDecl] = &[
    add::DECL,
    subtract::DECL,
    multiply::DECL,
    divide::DECL,
    negate::DECL,
];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（AGENTS.md「実装の規約」）。
    #![allow(clippy::unwrap_used, clippy::panic)]

    use crate::builtins::iface::Reply;
    use crate::builtins::table::{builtin_decl, call_builtin, lookup_builtin};
    use crate::runtime::heap::{Heap, HeapConfig, Value};

    // 作成時の関門: 登録された関数の値の意味を、独立した binary32 の期待値で守る。
    // ゴールデンの経路確認では見えない、幅の拡大・零の符号の消失・零除算の停止を捕まえる。
    // NaN の追加のビット情報は契約に含めず、分類だけを検査する。
    #[test]
    fn arithmetic_rounds_each_result_and_preserves_ieee_values() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (name, args, bits) in [
                ("%Float32.add", vec![16777216.0, 1.0], Some(0x4b800000)),
                ("%Float32.add", vec![16777218.0, 1.0], Some(0x4b800002)),
                (
                    "%Float32.subtract",
                    vec![16777216.0, -1.0],
                    Some(0x4b800000),
                ),
                (
                    "%Float32.multiply",
                    vec![1.0000001, 1.0000001],
                    Some(0x3f800002),
                ),
                ("%Float32.divide", vec![1.0, 3.0], Some(0x3eaaaaab)),
                ("%Float32.add", vec![-0.0, -0.0], Some(0x80000000)),
                ("%Float32.add", vec![0.0, -0.0], Some(0)),
                ("%Float32.subtract", vec![-0.0, 0.0], Some(0x80000000)),
                ("%Float32.subtract", vec![0.0, 0.0], Some(0)),
                ("%Float32.multiply", vec![-0.0, 2.0], Some(0x80000000)),
                ("%Float32.multiply", vec![-0.0, -2.0], Some(0)),
                ("%Float32.divide", vec![-0.0, 2.0], Some(0x80000000)),
                ("%Float32.divide", vec![0.0, -2.0], Some(0x80000000)),
                ("%Float32.divide", vec![1.0, 0.0], Some(0x7f800000)),
                ("%Float32.divide", vec![1.0, -0.0], Some(0xff800000)),
                ("%Float32.multiply", vec![f32::MAX, 2.0], Some(0x7f800000)),
                ("%Float32.multiply", vec![f32::from_bits(1), 0.5], Some(0)),
                (
                    "%Float32.multiply",
                    vec![-f32::from_bits(1), 0.5],
                    Some(0x80000000),
                ),
                ("%Float32.negate", vec![0.0], Some(0x80000000)),
                ("%Float32.negate", vec![-0.0], Some(0)),
                ("%Float32.negate", vec![1.5], Some(0xbfc00000)),
                ("%Float32.negate", vec![f32::INFINITY], Some(0xff800000)),
                ("%Float32.divide", vec![0.0, 0.0], None),
                ("%Float32.add", vec![f32::NAN, 1.0], None),
                (
                    "%Float32.subtract",
                    vec![f32::INFINITY, f32::INFINITY],
                    None,
                ),
                ("%Float32.multiply", vec![0.0, f32::INFINITY], None),
                ("%Float32.divide", vec![f32::INFINITY, f32::INFINITY], None),
                ("%Float32.negate", vec![f32::NAN], None),
            ] {
                let decl = builtin_decl(lookup_builtin(name).unwrap()).unwrap();
                let args = args.into_iter().map(Value::Float32).collect::<Vec<_>>();
                let Reply::Done(value) = call_builtin(decl, ctx, None, None, None, &args).unwrap()
                else {
                    panic!("{name} did not return a value");
                };
                let actual = value.as_float32().unwrap();
                match bits {
                    Some(bits) => assert_eq!(actual.to_bits(), bits, "{name}: {args:?}"),
                    None => assert!(actual.is_nan(), "{name}: {args:?} -> {actual:?}"),
                }
            }
        });
    }
}
