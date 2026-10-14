//! 幅付きの定数評価を型検査の公開入口で確かめる。

// テストの失敗は panic で表し、独立した期待値を型検査の結果と照合する。
#![allow(clippy::expect_used, clippy::panic)]

use crate::diag::DiagCode as C;
use crate::resolve::ResolveOutput;
use crate::typeck::{TypeckOutput, test_support::check_files};
use crate::types::ConstValue as V;

fn constant<'a>(resolved: &ResolveOutput, typed: &'a TypeckOutput, name: &str) -> &'a V {
    let binding = resolved
        .bindings
        .iter()
        .find(|(_, b)| b.name == name)
        .expect("constant binding")
        .0;
    typed.consts.get(binding).expect("evaluated constant")
}

fn assert_value(actual: &V, expected: &V) {
    match (actual, expected) {
        (V::Integer8(a), V::Integer8(b)) => assert_eq!(a, b),
        (V::Integer16(a), V::Integer16(b)) => assert_eq!(a, b),
        (V::Integer32(a), V::Integer32(b)) => assert_eq!(a, b),
        (V::UnsignedInteger16(a), V::UnsignedInteger16(b)) => assert_eq!(a, b),
        (V::UnsignedInteger32(a), V::UnsignedInteger32(b)) => assert_eq!(a, b),
        (V::UnsignedInteger64(a), V::UnsignedInteger64(b)) => assert_eq!(a, b),
        (V::Float32(a), V::Float32(b)) => assert_eq!(a.to_bits(), b.to_bits()),
        (V::Boolean(a), V::Boolean(b)) => assert_eq!(a, b),
        (V::String(a), V::String(b)) => assert_eq!(a, b),
        _ => panic!("different values: {actual:?}, {expected:?}"),
    }
}

#[test]
fn width_integer_constants_preserve_each_width_and_division_rules() {
    // 幅の拡大、u64 の符号付きへの変換、MIN mod -1 の誤ったあふれを捕まえる。
    // リテラルだけの既存テストでは演算結果を確かめられない。
    for (name, suffix, minimum, maximum, low, high, quotient, remainder) in [
        (
            "Integer8",
            "s8",
            "-128",
            "127",
            V::Integer8(-128),
            V::Integer8(127),
            V::Integer8(-2),
            V::Integer8(-1),
        ),
        (
            "Integer16",
            "s16",
            "-32768",
            "32767",
            V::Integer16(-32768),
            V::Integer16(32767),
            V::Integer16(-2),
            V::Integer16(-1),
        ),
        (
            "Integer32",
            "s32",
            "-2147483648",
            "2147483647",
            V::Integer32(-2147483648),
            V::Integer32(2147483647),
            V::Integer32(-2),
            V::Integer32(-1),
        ),
        (
            "UnsignedInteger16",
            "u16",
            "0",
            "65535",
            V::UnsignedInteger16(0),
            V::UnsignedInteger16(65535),
            V::UnsignedInteger16(2),
            V::UnsignedInteger16(1),
        ),
        (
            "UnsignedInteger32",
            "u32",
            "0",
            "4294967295",
            V::UnsignedInteger32(0),
            V::UnsignedInteger32(4294967295),
            V::UnsignedInteger32(2),
            V::UnsignedInteger32(1),
        ),
        (
            "UnsignedInteger64",
            "u64",
            "0",
            "18446744073709551615",
            V::UnsignedInteger64(0),
            V::UnsignedInteger64(18446744073709551615),
            V::UnsignedInteger64(2),
            V::UnsignedInteger64(1),
        ),
    ] {
        let signed = suffix.starts_with('s');
        let lhs = if signed { "-7" } else { "7" };
        let special = if signed {
            format!(
                "const special: {name} = {minimum}{suffix} mod -1{suffix}\nconst neg: {name} = -(1{suffix})\n"
            )
        } else {
            String::new()
        };
        let source = format!(
            "const low: {name} = {minimum}{suffix} + 0{suffix}\nconst high: {name} = {maximum}{suffix} - 0{suffix}\nconst product: {name} = {maximum}{suffix} * 1{suffix}\nconst quotient: {name} = {lhs}{suffix} div 3{suffix}\nconst remainder: {name} = {lhs}{suffix} mod 3{suffix}\n{special}const text: String = \"${{high}}\"\nconst ordered: Boolean = low < high\nconst same: Boolean = high = product\n"
        );
        let (_, resolved, typed, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(diagnostics.is_empty(), "{source}: {diagnostics:#?}");
        for (binding, value) in [
            ("low", low),
            ("high", high.clone()),
            ("product", high),
            ("quotient", quotient),
            ("remainder", remainder),
        ] {
            assert_value(constant(&resolved, &typed, binding), &value);
        }
        assert_value(
            constant(&resolved, &typed, "text"),
            &V::String(maximum.into()),
        );
        assert_value(constant(&resolved, &typed, "ordered"), &V::Boolean(true));
        assert_value(constant(&resolved, &typed, "same"), &V::Boolean(true));
        if signed {
            let zero = match name {
                "Integer8" => V::Integer8(0),
                "Integer16" => V::Integer16(0),
                _ => V::Integer32(0),
            };
            let minus_one = match name {
                "Integer8" => V::Integer8(-1),
                "Integer16" => V::Integer16(-1),
                _ => V::Integer32(-1),
            };
            assert_value(constant(&resolved, &typed, "special"), &zero);
            assert_value(constant(&resolved, &typed, "neg"), &minus_one);
        }
    }
    let source = "const high: UnsignedInteger64 = 9223372036854775808u64 + 1u64\nconst quotient: UnsignedInteger64 = 18446744073709551615u64 div 2u64\nconst remainder: UnsignedInteger64 = 18446744073709551615u64 mod 2u64\n";
    let (_, resolved, typed, diagnostics) = check_files(&[("main.bnt", source)], false);
    assert!(diagnostics.is_empty());
    for (name, expected) in [
        ("high", 9223372036854775809),
        ("quotient", 9223372036854775807),
        ("remainder", 1),
    ] {
        assert_value(
            constant(&resolved, &typed, name),
            &V::UnsignedInteger64(expected),
        );
    }
}

#[test]
fn width_arithmetic_failures_are_errors_in_consts_and_warnings_in_functions() {
    // 同じ独立した境界値で、const の拒否と通常式の警告を公開の診断から確かめる。
    for (name, suffix, minimum, maximum) in [
        ("Integer8", "s8", "-128", "127"),
        ("Integer16", "s16", "-32768", "32767"),
        ("Integer32", "s32", "-2147483648", "2147483647"),
        ("UnsignedInteger16", "u16", "0", "65535"),
        ("UnsignedInteger32", "u32", "0", "4294967295"),
        ("UnsignedInteger64", "u64", "0", "18446744073709551615"),
    ] {
        let mut cases = vec![
            (format!("{maximum}{suffix} + 1{suffix}"), C::W0402),
            (format!("{minimum}{suffix} - 1{suffix}"), C::W0402),
            (format!("{maximum}{suffix} * 2{suffix}"), C::W0402),
            (format!("1{suffix} div 0{suffix}"), C::W0401),
            (format!("1{suffix} mod 0{suffix}"), C::W0401),
        ];
        if suffix.starts_with('s') {
            cases.push((format!("{minimum}{suffix} div -1{suffix}"), C::W0402));
            cases.push((format!("-({minimum}{suffix})"), C::W0402));
        }
        let mut source = String::new();
        for (index, (expression, _)) in cases.iter().enumerate() {
            source.push_str(&format!("const bad{index}: {name} = {expression}\nfunction f{index}() -> {name}\n return {expression}\nend function\n"));
        }
        source.push_str(&format!("function dynamic(a: {name}) -> {name}\n return a div (1{suffix} - 1{suffix})\nend function\n"));
        let (_, resolved, typed, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(
            diagnostics
                .iter()
                .all(|d| matches!(d.code, Some(C::E0435 | C::W0401 | C::W0402))),
            "{source}: {diagnostics:#?}"
        );
        assert_eq!(
            diagnostics
                .iter()
                .filter(|d| d.code == Some(C::E0435))
                .count(),
            cases.len()
        );
        let warnings = diagnostics
            .iter()
            .filter(|d| matches!(d.code, Some(C::W0401 | C::W0402)))
            .collect::<Vec<_>>();
        let mut expected = cases.iter().map(|(_, code)| *code).collect::<Vec<_>>();
        expected.push(C::W0401);
        assert_eq!(
            warnings
                .iter()
                .map(|d| d.code.expect("warning code"))
                .collect::<Vec<_>>(),
            expected
        );
        for warning in warnings.into_iter().filter(|d| d.code == Some(C::W0402)) {
            assert_eq!(
                warning.message,
                format!("this calculation overflows `{name}`")
            );
        }
        assert!(
            resolved
                .bindings
                .iter()
                .filter(|(_, b)| b.name.starts_with("bad"))
                .all(|(id, _)| typed.consts.get(id).is_none())
        );
    }
}

#[test]
fn width_float_constants_round_each_operation_and_keep_ieee_values() {
    // 2^24 で各段を丸めず f64 で続ける退行と、無限大を算術の停止にする退行を捕まえる。
    let source = "const rounded: Float32 = (16777216.0f32 + 1.0f32) - 16777216.0f32\nconst product: Float32 = 0.1f32 * 10.0f32\nconst quotient: Float32 = 1.0f32 / 2.0f32\nconst negativeZero: Float32 = -(0.0f32)\nconst infinity: Float32 = 1.0f32 / 0.0f32\nconst negativeInfinity: Float32 = -1.0f32 / 0.0f32\nconst nan: Float32 = 0.0f32 / 0.0f32\nconst text: String = \"${0.1f32} ${negativeZero} ${infinity} ${nan}\"\nconst same: Boolean = nan = nan\nconst different: Boolean = nan <> nan\nconst less: Boolean = nan < 1.0f32\nconst equalZero: Boolean = negativeZero = 0.0f32\nfunction f() -> Float32\n return 3.0e38f32 * 2.0f32 + (0.0f32 / 0.0f32)\nend function\n";
    let (_, resolved, typed, diagnostics) = check_files(&[("main.bnt", source)], false);
    assert!(diagnostics.is_empty(), "{diagnostics:#?}");
    for (name, expected) in [
        ("rounded", 0.0),
        ("product", 1.0),
        ("quotient", 0.5),
        ("negativeZero", -0.0),
        ("infinity", f32::INFINITY),
        ("negativeInfinity", f32::NEG_INFINITY),
    ] {
        assert_value(constant(&resolved, &typed, name), &V::Float32(expected));
    }
    assert!(matches!(constant(&resolved, &typed, "nan"), V::Float32(n) if n.is_nan()));
    assert_value(
        constant(&resolved, &typed, "text"),
        &V::String("0.1 -0.0 Infinity NaN".into()),
    );
    for (name, expected) in [
        ("same", false),
        ("different", true),
        ("less", false),
        ("equalZero", true),
    ] {
        assert_value(constant(&resolved, &typed, name), &V::Boolean(expected));
    }
}

#[test]
fn width_collection_constants_sort_keys_and_detect_duplicates() {
    // 鍵の数の大小を守る。u64 の上半分を i64 に読み替えると並びが逆になる。
    for (name, suffix, low, high, expected_low, expected_high) in [
        (
            "Integer8",
            "s8",
            "-128",
            "127",
            V::Integer8(-128),
            V::Integer8(127),
        ),
        (
            "Integer16",
            "s16",
            "-32768",
            "32767",
            V::Integer16(-32768),
            V::Integer16(32767),
        ),
        (
            "Integer32",
            "s32",
            "-2147483648",
            "2147483647",
            V::Integer32(-2147483648),
            V::Integer32(2147483647),
        ),
        (
            "UnsignedInteger16",
            "u16",
            "0",
            "65535",
            V::UnsignedInteger16(0),
            V::UnsignedInteger16(65535),
        ),
        (
            "UnsignedInteger32",
            "u32",
            "0",
            "4294967295",
            V::UnsignedInteger32(0),
            V::UnsignedInteger32(4294967295),
        ),
        (
            "UnsignedInteger64",
            "u64",
            "9223372036854775807",
            "18446744073709551615",
            V::UnsignedInteger64(9223372036854775807),
            V::UnsignedInteger64(18446744073709551615),
        ),
    ] {
        let source = format!(
            "import Benitoite.Set\nimport Benitoite.Map\nconst keys: Set[{name}] = Set.fromList([{high}{suffix}, {low}{suffix}])\nconst map: Map[{name}, String] = Map.fromList([Pair({high}{suffix}, \"high\"), Pair({low}{suffix}, \"low\")])\nconst bad: Set[{name}] = Set.fromList([{high}{suffix}, {high}{suffix} - 0{suffix}])\nfunction f() -> Unit\n bind _ <- Set.fromList([{high}{suffix}, {high}{suffix} - 0{suffix}])\nend function\n"
        );
        let (_, resolved, typed, diagnostics) = check_files(&[("main.bnt", &source)], false);
        assert!(
            diagnostics
                .iter()
                .all(|d| matches!(d.code, Some(C::E0436 | C::W0403))),
            "{diagnostics:#?}"
        );
        let V::Set(values) = constant(&resolved, &typed, "keys") else {
            panic!("Set constant")
        };
        assert_eq!(values.len(), 2);
        for (actual, expected) in values.iter().zip([&expected_low, &expected_high]) {
            assert_value(actual, expected);
        }
        let V::Map(entries) = constant(&resolved, &typed, "map") else {
            panic!("Map constant")
        };
        assert_eq!(entries.len(), 2);
        for ((key, value), (expected, label)) in entries
            .iter()
            .zip([(&expected_low, "low"), (&expected_high, "high")])
        {
            assert_value(key, expected);
            assert_value(value, &V::String(label.into()));
        }
        for (code, message) in [
            (
                C::E0436,
                format!("the key `{high}` appears more than once in a constant"),
            ),
            (C::W0403, format!("the key `{high}` appears more than once")),
        ] {
            let found = diagnostics
                .iter()
                .filter(|d| d.code == Some(code))
                .collect::<Vec<_>>();
            assert_eq!(found.len(), 1);
            assert_eq!(
                found.first().expect("duplicate diagnostic").message,
                message
            );
        }
    }
}

#[test]
fn width_invalid_types_are_not_evaluated_and_conversions_do_not_warn() {
    // 型やリテラルの誤りを、定数の算術の失敗や警告として報告してはならない。
    for source in [
        "const bad: Integer8 = 127s8 + 1\n",
        "const bad: Integer8 = 128s8 + 1s8\n",
        "const bad: UnsignedInteger16 = -0u16\n",
        "const bad: Byte = 255u8 + 1u8\n",
        "function f() -> Integer8\n return 127s8 + 1\nend function\n",
    ] {
        let (_, resolved, typed, diagnostics) = check_files(&[("main.bnt", source)], false);
        assert!(diagnostics.iter().any(|d| d.is_error()));
        assert!(
            !diagnostics
                .iter()
                .any(|d| matches!(d.code, Some(C::E0435 | C::W0401 | C::W0402)))
        );
        assert!(
            resolved
                .bindings
                .iter()
                .filter(|(_, b)| b.name == "bad")
                .all(|(id, _)| typed.consts.get(id).is_none())
        );
    }
    let source = "function f() -> Unit\n bind _ <- Byte.fromInteger(256)\n bind _ <- Float.truncate(1.0e30)\nend function\n";
    let (_, _, _, diagnostics) = check_files(&[("main.bnt", source)], false);
    assert!(diagnostics.is_empty(), "{diagnostics:#?}");
}
