//! ランタイムを使う組み込みの関数を、部品を渡す公開の実行経路で確かめる（設計書 02-09「実行ごとの状態」）。
// テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::arithmetic_side_effects
)]
#[path = "golden/differential.rs"]
mod differential;

use benitoite::pipeline::{self, CheckOptions};
use benitoite::runtime::heap::HeapConfig;
use benitoite::runtime::io::event::Wakeup;
use benitoite::runtime::io::ops::{Completion, JobWork, LentOwned, Outcome, WorkerJob};
use benitoite::runtime::io::services::RunInput;
use benitoite::runtime::run::{self, EndKind, NoInterrupt, OutputTarget, RunEnv, StdinSource};
use benitoite::runtime::sched::parts::{IdleWake, WorkerExec};
use benitoite::runtime::sched::testing::ScheduleHandle;
use benitoite::vm::{ExecMode, VmConfig};
use std::collections::VecDeque;
use std::sync::{Arc, Mutex, mpsc};

// 関門: 書式本体だけでは検出できない14頭の登録漏れ・引数順・権限・宣言型を、
// 本番の表から raw の包みを呼ぶ境界で守る。表層の型選択と定数評価は
// formatted_interpolation_connects_constants_and_both_evaluators が確かめる。
type FormatCodes = (i64, i64, i64, bool, bool, i64, i64);

fn call_format<'e>(
    ctx: &mut benitoite::runtime::heap::NoGcCtx<'e>,
    name: &str,
    value: benitoite::runtime::heap::Value<'e>,
    codes: FormatCodes,
) -> Result<benitoite::runtime::heap::Value<'e>, benitoite::runtime::Stop> {
    use benitoite::builtins::iface::{CallCtx, Reply};
    use benitoite::builtins::{builtin_decl, lookup_builtin};
    use benitoite::runtime::heap::Value as V;
    let (kind, align, sign, alternate, zero, width, precision) = codes;
    let decl = builtin_decl(lookup_builtin(name).unwrap()).unwrap();
    let args = [
        value,
        V::Int(kind),
        V::Int(align),
        V::Int(sign),
        V::Bool(alternate),
        V::Bool(zero),
        V::Int(width),
        V::Int(precision),
    ];
    match (decl.raw)(&mut CallCtx::new(ctx, None, None, None), &args)? {
        Reply::Done(value) => Ok(value),
        other @ (Reply::Wait(_) | Reply::SpawnTasks(_) | Reply::Exit(_)) => {
            panic!("pure formatter returned {other:?}")
        }
    }
}

fn check_format<'e>(
    ctx: &mut benitoite::runtime::heap::NoGcCtx<'e>,
    name: &str,
    value: benitoite::runtime::heap::Value<'e>,
    codes: FormatCodes,
    expected: &str,
) {
    let result = call_format(ctx, name, value, codes).unwrap();
    assert_eq!(ctx.str(result), Some(expected), "{name} {codes:?}");
}

#[test]
fn format_all_fourteen_heads_have_fixed_contracts_and_execute() {
    use benitoite::builtins::iface::Capability;
    use benitoite::builtins::{
        builtin_decl, lookup_builtin,
        table::{EntryKind, builtin_kind, builtin_scheme},
    };
    use benitoite::runtime::heap::{Heap, Value as V};
    use benitoite::types::{Ty, TyCon, builtin::BuiltinTypeId as B};
    let basic = |id| {
        Ty::Con(
            TyCon::Builtin(id),
            vec![],
            benitoite::types::builtin::RangeIndex::TOP,
        )
    };
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        let text = ctx.alloc_str("猫", "format test").unwrap();
        let decimal = ctx.alloc_decimal(benitoite::base::Decimal::parse_literal("1.50").unwrap());
        // この一覧は独立した契約であり、FORMAT 表から作らない
        // （設計書 02-06「書式化の内部頭」、03-06「書式付き補間の内部書式化」）。
        let cases = [
            (
                "Integer",
                B::INTEGER,
                V::Int(i64::MIN),
                "-9223372036854775808",
            ),
            ("Integer8", B::INTEGER8, V::Int8(i8::MIN), "-128"),
            ("Integer16", B::INTEGER16, V::Int16(i16::MIN), "-32768"),
            ("Integer32", B::INTEGER32, V::Int32(i32::MIN), "-2147483648"),
            ("Byte", B::BYTE, V::Byte(u8::MAX), "255"),
            (
                "UnsignedInteger16",
                B::UNSIGNED_INTEGER16,
                V::UInt16(u16::MAX),
                "65535",
            ),
            (
                "UnsignedInteger32",
                B::UNSIGNED_INTEGER32,
                V::UInt32(u32::MAX),
                "4294967295",
            ),
            (
                "UnsignedInteger64",
                B::UNSIGNED_INTEGER64,
                V::UInt64(u64::MAX),
                "18446744073709551615",
            ),
            ("Float", B::FLOAT, V::Float(-0.0), "-0.0"),
            ("Float32", B::FLOAT32, V::Float32(0.1), "0.1"),
            ("Decimal", B::DECIMAL, decimal, "1.50"),
            ("String", B::STRING, text, "猫"),
            ("Character", B::CHARACTER, V::Char('é'), "é"),
            ("Boolean", B::BOOLEAN, V::Bool(true), "true"),
        ];
        for (ty, operand, value, expected) in cases {
            let name = format!("%Format.{ty}");
            let id = lookup_builtin(&name).unwrap();
            let decl = builtin_decl(id).unwrap();
            assert_eq!((decl.arity, decl.capability), (8, Capability::Pure));
            assert_eq!(builtin_kind(id), Some(EntryKind::Format { operand }));
            let scheme = builtin_scheme(id).unwrap();
            assert_eq!(
                scheme.params,
                vec![
                    basic(operand),
                    basic(B::INTEGER),
                    basic(B::INTEGER),
                    basic(B::INTEGER),
                    basic(B::BOOLEAN),
                    basic(B::BOOLEAN),
                    basic(B::INTEGER),
                    basic(B::INTEGER)
                ]
            );
            assert_eq!(
                scheme.param_names,
                [
                    "value",
                    "kind",
                    "align",
                    "sign",
                    "alternate",
                    "zero",
                    "width",
                    "precision"
                ]
            );
            assert_eq!(scheme.ret, basic(B::STRING));
            assert!(
                scheme.effects.is_empty()
                    && scheme.type_params.is_empty()
                    && scheme.effect_params.is_empty()
                    && scheme.class_constraints.is_empty()
                    && scheme.no_fail.is_empty()
            );
            // 幅1は空書式ではなく、有効な指定。長い内容を切断しない。
            check_format(ctx, &name, value, (0, 0, 0, false, false, 1, -1), expected);
        }
    });
}

#[test]
fn format_integer_radices_signs_and_zero_padding() {
    use benitoite::runtime::heap::{Heap, Value as V};
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (kind, alternate, zero, width, n, expected) in [
            (1, false, false, 0, -42, "-42"),
            (2, true, false, 0, -42, "-0b101010"),
            (3, true, false, 0, -42, "-0o52"),
            (4, true, true, 8, -42, "-0x0002a"),
            (5, true, true, 8, -42, "-0X0002A"),
            (2, true, false, 0, 0, "0b0"),
            (3, true, false, 0, 0, "0o0"),
            (4, true, false, 0, 0, "0x0"),
            (5, true, false, 0, 0, "0X0"),
            (4, true, false, 0, i64::MIN, "-0x8000000000000000"),
        ] {
            check_format(
                ctx,
                "%Format.Integer",
                V::Int(n),
                (kind, 0, 0, alternate, zero, width, -1),
                expected,
            );
        }
        for (name, value, expected) in [
            ("Integer8", V::Int8(i8::MIN), "-0x80"),
            ("Integer16", V::Int16(i16::MIN), "-0x8000"),
            ("Integer32", V::Int32(i32::MIN), "-0x80000000"),
            ("Byte", V::Byte(255), "0xff"),
            ("UnsignedInteger16", V::UInt16(u16::MAX), "0xffff"),
            ("UnsignedInteger32", V::UInt32(u32::MAX), "0xffffffff"),
            (
                "UnsignedInteger64",
                V::UInt64(u64::MAX),
                "0xffffffffffffffff",
            ),
        ] {
            check_format(
                ctx,
                &format!("%Format.{name}"),
                value,
                (4, 0, 0, true, false, 0, -1),
                expected,
            );
        }
        check_format(
            ctx,
            "%Format.Integer",
            V::Int(42),
            (1, 0, 1, false, true, 6, -1),
            "+00042",
        );
        check_format(
            ctx,
            "%Format.UnsignedInteger64",
            V::UInt64(0),
            (1, 0, 1, false, true, 4, -1),
            "+000",
        );
    });
}

#[test]
fn format_fractional_rounding_uses_each_values_exact_representation() {
    use benitoite::base::Decimal;
    use benitoite::runtime::heap::{Heap, Value as V};
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (n, expected) in [
            (2.5, "2"),
            (3.5, "4"),
            (-2.5, "-2"),
            (-3.5, "-4"),
            (-0.25, "-0"),
            (-0.0, "-0"),
        ] {
            check_format(
                ctx,
                "%Format.Float",
                V::Float(n),
                (6, 0, 0, false, false, 0, 0),
                expected,
            );
            check_format(
                ctx,
                "%Format.Float32",
                V::Float32(n as f32),
                (6, 0, 0, false, false, 0, 0),
                expected,
            );
        }
        for (n, expected) in [(25, "2"), (35, "4"), (-25, "-2"), (-35, "-4"), (-2, "0")] {
            let value = ctx.alloc_decimal(Decimal::new(n, 1).unwrap());
            check_format(
                ctx,
                "%Format.Decimal",
                value,
                (6, 0, 0, false, false, 0, 0),
                expected,
            );
        }
        for (name, value, precision, expected) in [
            ("Float", V::Float(0.125), 2, "0.12"),
            ("Float", V::Float(0.375), 2, "0.38"),
            ("Float32", V::Float32(0.0625), 3, "0.062"),
            ("Float", V::Float(2.675), 2, "2.67"),
            ("Float", V::Float(2.685), 2, "2.69"),
            ("Float32", V::Float32(2.685), 2, "2.68"),
            ("Float", V::Float(0.1), 28, "0.1000000000000000055511151231"),
            (
                "Float32",
                V::Float32(0.1),
                28,
                "0.1000000014901161193847656250",
            ),
            (
                "Float",
                V::Float(f64::from_bits(1)),
                28,
                "0.0000000000000000000000000000",
            ),
            (
                "Float32",
                V::Float32(f32::from_bits(1)),
                28,
                "0.0000000000000000000000000000",
            ),
            ("Float", V::Float(1.5), -1, "1.500000"),
            ("Float32", V::Float32(1.5), -1, "1.500000"),
            (
                "Float32",
                V::Float32(f32::MAX),
                0,
                "340282346638528859811704183484516925440",
            ),
        ] {
            check_format(
                ctx,
                &format!("%Format.{name}"),
                value,
                (6, 0, 0, false, false, 0, precision),
                expected,
            );
        }
        // binary64 最大値は (2^53 - 1) * 2^971。独立に整数へ展開した数字列を固定する。
        check_format(ctx, "%Format.Float", V::Float(f64::MAX), (6, 0, 0, false, false, 0, 28), concat!(
            "179769313486231570814527423731704356798070567525844996598917476803157260780028538760589558632766878171540458953514382464234321326889464182768467546703537516986049910576551282076245490090389328944075868508455133942304583236903222948165808559332123348274797826204144723168738177180919299881250404026184124858368",
            ".0000000000000000000000000000"));
        for (n, scale, precision, expected) in [
            (2675, 3, 2, "2.68"),
            (2685, 3, 2, "2.68"),
            (9995, 3, 2, "10.00"),
            (-1, 28, 2, "0.00"),
            (1, 28, 28, "0.0000000000000000000000000001"),
            (150, 2, -1, "1.50"),
            (15, 1, -1, "1.5"),
            (0, 0, 2, "0.00"),
            (
                benitoite::base::decimal::MAX_MANTISSA,
                0,
                2,
                "79228162514264337593543950335.00",
            ),
            (
                -benitoite::base::decimal::MAX_MANTISSA,
                0,
                2,
                "-79228162514264337593543950335.00",
            ),
        ] {
            let value = ctx.alloc_decimal(Decimal::new(n, scale).unwrap());
            check_format(
                ctx,
                "%Format.Decimal",
                value,
                (6, 0, 0, false, false, 0, precision),
                expected,
            );
        }
        let decimal = ctx.alloc_decimal(Decimal::new(-1, 3).unwrap());
        check_format(
            ctx,
            "%Format.Decimal",
            decimal,
            (6, 0, 1, false, true, 8, 2),
            "+0000.00",
        );
        let decimal = ctx.alloc_decimal(Decimal::new(15, 1).unwrap());
        check_format(
            ctx,
            "%Format.Decimal",
            decimal,
            (6, 0, 1, false, true, 8, 2),
            "+0001.50",
        );
    });
}

#[test]
fn format_special_values_and_display_width_alignment() {
    use benitoite::runtime::heap::{Heap, Value as V};
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for (n, expected) in [
            (f64::NAN, "         NaN"),
            (-f64::NAN, "         NaN"),
            (f64::INFINITY, "   +Infinity"),
            (f64::NEG_INFINITY, "   -Infinity"),
        ] {
            check_format(
                ctx,
                "%Format.Float",
                V::Float(n),
                (6, 0, 1, false, true, 12, 2),
                expected,
            );
            check_format(
                ctx,
                "%Format.Float32",
                V::Float32(n as f32),
                (6, 0, 1, false, true, 12, 2),
                expected,
            );
        }
        check_format(
            ctx,
            "%Format.Float",
            V::Float(-0.0),
            (6, 0, 1, false, true, 8, 2),
            "-0000.00",
        );
        for (s, kind, align, width, expected) in [
            ("猫", 7, 2, 4, "  猫"),
            ("猫", 7, 0, 4, "猫  "),
            ("猫", 7, 3, 5, " 猫  "),
            ("猫", 7, 3, 1, "猫"),
            ("·", 7, 2, 2, " ·"),
            ("e\u{301}", 7, 2, 3, "  e\u{301}"),
            ("\u{301}", 7, 1, 2, "\u{301}  "),
            ("👩‍👩‍👧‍👦", 7, 2, 4, "  👩‍👩‍👧‍👦"),
            ("ل\0ا", 7, 2, 4, "  ل\0ا"),
            ("لا", 7, 2, 3, "  لا"),
        ] {
            let value = ctx.alloc_str(s, "format test").unwrap();
            check_format(
                ctx,
                "%Format.String",
                value,
                (kind, align, 0, false, false, width, -1),
                expected,
            );
        }
        check_format(
            ctx,
            "%Format.Character",
            V::Char('猫'),
            (8, 3, 0, false, false, 5, -1),
            " 猫  ",
        );
        check_format(
            ctx,
            "%Format.Boolean",
            V::Bool(false),
            (0, 0, 0, false, false, 7, -1),
            "false  ",
        );
        check_format(
            ctx,
            "%Format.Integer",
            V::Int(42),
            (1, 1, 0, false, false, 5, -1),
            "42   ",
        );
        check_format(
            ctx,
            "%Format.Integer",
            V::Int(42),
            (1, 3, 0, false, false, 5, -1),
            " 42  ",
        );
        // 最大幅は一度だけ確かめ、stress 構成でも反復や深い入力と組み合わせない。
        let result = call_format(
            ctx,
            "%Format.Integer",
            V::Int(-42),
            (4, 0, 0, true, true, 65535, -1),
        )
        .unwrap();
        let text = ctx.str(result).unwrap();
        assert_eq!(text.len(), 65535);
        assert!(text.starts_with("-0x") && text.ends_with("2a"));
        assert!(text.get(3..65533).unwrap().bytes().all(|b| b == b'0'));
    });
}

#[test]
fn format_invalid_internal_arguments_are_internal_errors() {
    use benitoite::runtime::{
        Stop,
        heap::{Heap, Value as V},
    };
    let mut heap = Heap::new(HeapConfig::default());
    heap.epoch(|ctx| {
        for codes in [
            (0, 0, 0, false, false, 0, -1),
            (9, 0, 0, false, false, 0, -1),
            (-1, 0, 0, false, false, 0, -1),
            (1, 4, 0, false, false, 1, -1),
            (1, 0, 2, false, false, 0, -1),
            (1, 0, 0, false, false, -1, -1),
            (1, 0, 0, false, false, 65536, -1),
            (6, 0, 0, false, false, 0, -2),
            (6, 0, 0, false, false, 0, 29),
            (1, 0, 0, false, false, 0, 0),
            (1, 1, 0, false, false, 0, -1),
            (1, 0, 0, false, true, 0, -1),
            (1, 1, 0, false, true, 8, -1),
            (1, 0, 0, true, false, 0, -1),
        ] {
            assert!(
                matches!(
                    call_format(ctx, "%Format.Integer", V::Int(1), codes),
                    Err(Stop::Internal(_))
                ),
                "{codes:?}"
            );
        }
        for (name, value, codes) in [
            ("Integer", V::Int(1), (6, 0, 0, false, false, 0, -1)),
            ("Float", V::Float(1.0), (1, 0, 0, false, false, 0, -1)),
            ("Boolean", V::Bool(true), (2, 0, 0, false, false, 0, -1)),
            ("Character", V::Char('a'), (0, 0, 1, false, false, 0, -1)),
            ("Boolean", V::Bool(true), (0, 0, 0, false, true, 8, -1)),
            ("Character", V::Char('a'), (7, 0, 0, false, false, 0, -1)),
        ] {
            assert!(matches!(
                call_format(ctx, &format!("%Format.{name}"), value, codes),
                Err(Stop::Internal(_))
            ));
        }
        // 型付きタプルの Rust 本体にも、言語側は8引数のまま渡す。
        use benitoite::builtins::iface::CallCtx;
        use benitoite::builtins::{builtin_decl, lookup_builtin};
        let decl = builtin_decl(lookup_builtin("%Format.Integer").unwrap()).unwrap();
        let args = [
            V::Int(1),
            V::Int(1),
            V::Int(0),
            V::Int(0),
            V::Bool(false),
            V::Bool(false),
            V::Int(0),
            V::Int(-1),
            V::Int(0),
        ];
        for len in [7, 9] {
            assert!(matches!(
                (decl.raw)(
                    &mut CallCtx::new(ctx, None, None, None),
                    args.get(..len).unwrap()
                ),
                Err(Stop::Internal(_))
            ));
        }
        let mut wrong_type = args.get(..8).unwrap().to_vec();
        *wrong_type.get_mut(1).unwrap() = V::Bool(true);
        assert!(matches!(
            (decl.raw)(&mut CallCtx::new(ctx, None, None, None), &wrong_type),
            Err(Stop::Internal(_))
        ));
        // 固定引数の型の取り出しにも本番の包みを通す。
        assert!(matches!(
            call_format(
                ctx,
                "%Format.Integer8",
                V::Int(1),
                (1, 0, 0, false, false, 0, -1)
            ),
            Err(Stop::Internal(_))
        ));
    });
}

// 関門: 表層から型別の内部頭へ渡す型・七定数・省略の保持と、定数との一致を守る。
// rawの頭のテストは、表層の型選択・引数列・定数評価を通らない。
// 同じ独立期待値を両実行器に要求し、書式を無視する共通の退行も捕まえる。
#[test]
fn formatted_interpolation_connects_constants_and_both_evaluators() {
    let cases = [
        ("Integer", "-42", "+#08x", "-0x0002a"),
        ("Integer8", "-128s8", "d", "-128"),
        ("Integer16", "-32768s16", "#b", "-0b1000000000000000"),
        ("Integer32", "-2147483648s32", "#o", "-0o20000000000"),
        ("Byte", "255u8", "#X", "0XFF"),
        ("UnsignedInteger16", "65535u16", "#x", "0xffff"),
        ("UnsignedInteger32", "4294967295u32", "d", "4294967295"),
        (
            "UnsignedInteger64",
            "18446744073709551615u64",
            "d",
            "18446744073709551615",
        ),
        ("Float", "2.5", "+08.0f", "+0000002"),
        ("Float32", "2.675f32", ".2f", "2.67"),
        ("Decimal", "2.675m", ".2f", "2.68"),
        ("String", r#""猫""#, ">5s", "   猫"),
        ("Character", "'猫'", "^5c", " 猫  "),
        ("Boolean", "true", "6", "true  "),
        ("Float", "1.5", "f", "1.500000"),
        ("Float32", "1.5f32", "f", "1.500000"),
        ("Decimal", "1.50m", "f", "1.50"),
        ("Float", "-0.0", ".0f", "-0"),
        ("Decimal", "-0.1m", ".0f", "0"),
        ("String", r#""e\u{301}""#, "^4", " é  "),
        ("String", r#""猫犬""#, "2s", "猫犬"),
        ("String", r#""""#, "3s", "   "),
    ];
    let mut source = String::new();
    for (i, (ty, value, spec, _)) in cases.iter().enumerate() {
        source.push_str(&format!(
            "const text{i}: String = \"${{{value}:{spec}}}\"\nfunction render{i}(value: {ty}) -> String\n return \"${{value:{spec}}}\"\nend function\n"
        ));
    }
    source.push_str("function main() -> Result[Unit, String]\n");
    for (i, (_, value, _, expected)) in cases.iter().enumerate() {
        source.push_str(&format!(
            " if text{i} <> \"{expected}\" or render{i}({value}) <> \"{expected}\" then return Result.Error(\"format case {i}\") end if\n"
        ));
    }
    // 連続・入れ子・書式なしとの混在。Stringも書式化する必要がある。
    source.push_str(
        r#"
 bind plain <- "猫"
 bind mixed <- "${"${42:#x}":>6s}${plain}${true:>6}"
 if mixed <> "  0x2a猫  true" then return Result.Error("nested interpolation") end if
 return Result.Ok(())
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let checked = pipeline::check_text(
            "formatted-interpolation.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(
            checked.error_count(),
            0,
            "{source}: {:?}",
            checked.diagnostics
        );
        let result = differential::compare(
            checked.program.unwrap(),
            checked.sources,
            environment(mode, Arc::new(Mutex::new(Vec::new()))).input,
            VmConfig::default(),
            mode,
            differential::CompareOptions {
                require_returned: true,
                ..Default::default()
            },
            Box::new(|| Ok(())),
        );
        match result {
            differential::Comparison::Matched => {}
            differential::Comparison::Failed(reason)
            | differential::Comparison::Excluded(reason) => panic!("{mode:?}: {reason}"),
        }
    }
}

fn compile(source: &str) -> benitoite::bytecode::program::CompiledProgram {
    let checked = pipeline::check_text(
        "runtime-builtins.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    pipeline::compile(&core, checked.sources).unwrap()
}
fn environment(mode: ExecMode, output: Arc<Mutex<Vec<u8>>>) -> RunEnv {
    RunEnv {
        input: RunInput {
            arguments: vec![],
            working_directory: "/".into(),
            script_directory: "/".into(),
        },
        stdin: StdinSource::Bytes(b"Ada\n".to_vec()),
        stdout: OutputTarget::Capture(output),
        stderr: OutputTarget::Capture(Arc::new(Mutex::new(Vec::new()))),
        interrupt: Box::new(NoInterrupt),
        parts: None,
        mode,
        vm: VmConfig::default(),
        heap: HeapConfig {
            stress: true,
            ..HeapConfig::default()
        },
        dev_panic_after_first_write: false,
    }
}
// ScriptWorkers の起こし口と出力の待ちをそのまま使い、単一の標準入力の仕事を同期で行う。
// 出力先のロックを idle まで保ち、偶然 writer が先に終わる場合を除く。
#[derive(Debug)]
struct InlineWorkers {
    waiting: Box<dyn WorkerExec>,
    done: VecDeque<Completion>,
    prompt: Option<PromptGate>,
}
#[derive(Debug)]
struct PromptGate {
    output: Arc<Mutex<Vec<u8>>>,
    release_output: mpsc::Sender<()>,
    observations: Arc<Mutex<(bool, usize)>>,
}
impl WorkerExec for InlineWorkers {
    fn wakeup(&self) -> Option<Wakeup> {
        self.waiting.wakeup()
    }
    fn submit(&mut self, job: WorkerJob) {
        if let Some(prompt) = &self.prompt {
            assert!(
                prompt.observations.lock().unwrap().0,
                "stdin began before the output wait"
            );
            assert_eq!(
                *prompt.output.try_lock().expect("output still transferring"),
                b"Name: "
            );
            assert!(matches!(job.lent, LentOwned::Stdin(_)));
            prompt.observations.lock().unwrap().1 = 1;
        }
        let JobWork::Builtin(work) = job.work else {
            panic!("expected builtin work")
        };
        let mut lent = job.lent;
        use benitoite::builtins::iface::Lent;
        let done = work.run(match &mut lent {
            LentOwned::Nothing => Lent::Nothing,
            LentOwned::Resource(_, reader) => Lent::Resource(reader.as_mut()),
            LentOwned::Stdin(reader) => Lent::Stdin(reader.as_mut()),
        });
        self.done.push_back(Completion {
            op: job.op,
            outcome: Outcome::Worker(done),
            returned: lent,
        });
    }
    fn try_recv(&mut self) -> Option<Completion> {
        self.done.pop_front().or_else(|| self.waiting.try_recv())
    }
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        if !self.done.is_empty() {
            return IdleWake::Progress;
        }
        if let Some(prompt) = &self.prompt {
            prompt.observations.lock().unwrap().0 = true;
            let _released = prompt.release_output.send(());
        }
        self.waiting.idle(deadline)
    }
}
// 関門: 公開の RunEnv::parts が WorkerExec::wakeup を出力へ渡す契約。
// 本体や VM のテストでは run_program の部品の配線を通らない。
#[test]
fn injected_parts_wait_for_output_before_reading_stdin() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit,String] uses Console.Write,Console.Read
 Console.write("Name: ")
 bind name <- try Console.readLine() |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
 return if name = Option.Some("Ada") then Result.Ok(()) else Result.Error("unexpected input") end if
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let held = Arc::clone(&output);
        let (release, receive) = mpsc::channel();
        let (ready, initialized) = mpsc::channel();
        let gate = std::thread::spawn(move || {
            let guard = held
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner);
            let _ready = ready.send(());
            let timed_out = matches!(
                receive.recv_timeout(std::time::Duration::from_secs(120)),
                Err(mpsc::RecvTimeoutError::Timeout)
            );
            drop(guard);
            timed_out
        });
        initialized.recv().unwrap();
        let script = ScheduleHandle::new([], false);
        let mut parts = script.parts();
        let observations = Arc::new(Mutex::new((false, 0)));
        parts.workers = Box::new(InlineWorkers {
            waiting: parts.workers,
            done: VecDeque::new(),
            prompt: Some(PromptGate {
                output: Arc::clone(&output),
                release_output: release.clone(),
                observations: Arc::clone(&observations),
            }),
        });
        let mut env = environment(mode, Arc::clone(&output));
        env.parts = Some(parts);
        let end = run::run_program(&program, env);
        let _released = release.send(());
        let gate_timed_out = gate.join().unwrap();
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0);
        assert!(end.reports.is_empty());
        assert!(end.main_error.is_none());
        assert!(
            !gate_timed_out,
            "the output gate was not released by idle within 120 s"
        );
        assert_eq!(*output.lock().unwrap(), b"Name: ");
        assert_eq!(*observations.lock().unwrap(), (true, 1));
        assert!(script.record().error.is_none(), "{:?}", script.record());
    }
}
// 関門: Exit の VM の応答だけでは、公開の終了結果と終了状態の変換を確かめられない。
// 資源の解放の回数は file のプログラムのテストに任せ、この境界では出力と終了結果を確かめる。
#[test]
fn process_exit_finishes_output_and_returns_the_requested_status() {
    let program = compile(
        r#"
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.IO.File
function main() -> Result[Unit,String] uses File.Read,State,Console.Write,Process.Exit
 with reader = try File.openReader("Cargo.toml") |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda) do
  bind _ <- try File.readLine(reader) |> Result.mapError(r: _,f: lambda(error) return IOError.message(error) end lambda)
  Console.write("before exit")
  Process.exit(3)
  Console.write("after exit")
  return Result.Ok(())
 end with
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let script = ScheduleHandle::new([], false);
        let mut env = environment(mode, Arc::clone(&output));
        env.input.working_directory = env!("CARGO_MANIFEST_DIR").into();
        let mut parts = script.parts();
        parts.workers = Box::new(InlineWorkers {
            waiting: parts.workers,
            done: VecDeque::new(),
            prompt: None,
        });
        env.parts = Some(parts);
        let end = run::run_program(&program, env);
        assert_eq!(end.end, EndKind::Exited(3), "{end:?}");
        assert_eq!(end.exit_code, 3);
        assert!(end.reports.is_empty());
        assert_eq!(*output.lock().unwrap(), b"before exit");
        assert!(script.record().error.is_none());
    }
}

// 関門: コレクションの八つのソース関数が、鍵順に一度ずつ関数を呼び、その結果を使う契約。
// 本体の単体テストはソースの脱糖や State の伝播を通らない。実行の公開の境界を使い、
// Reference の観察結果と返り値を確かめる（設計書 03-06「関数を引数にとる関数の共通の規則」）。
#[test]
fn map_and_set_source_functions_call_in_key_order_once_and_use_the_results() {
    let cases = [
        (
            "Map.map",
            "Map.map(m: m, f: lambda(key, value)\n record_visit(log: log, n: key * 100 + value)\nreturn key + value end lambda)",
            "Map.toList(result) = mapped",
        ),
        (
            "Map.filter",
            "Map.filter(m: m, p: lambda(key, value)\n record_visit(log: log, n: key * 100 + value)\nreturn key <> 2 end lambda)",
            "Map.toList(result) = filteredMap",
        ),
        (
            "Map.fold",
            "Map.fold(m: m, initial: 7, f: lambda(acc, key, value)\n record_visit(log: log, n: key * 100 + value)\nreturn acc + key + value end lambda)",
            "result = foldedMap",
        ),
        (
            "Map.forEach",
            "Map.forEach(m: m, f: lambda(key, value) return record_visit(log: log, n: key * 100 + value) end lambda)",
            "result = ()",
        ),
        (
            "Set.map",
            "Set.map(s: s, f: lambda(value)\n record_visit(log: log, n: value * 110)\nreturn 1 end lambda)",
            "Set.toList(result) = mappedSet",
        ),
        (
            "Set.filter",
            "Set.filter(s: s, p: lambda(value)\n record_visit(log: log, n: value * 110)\nreturn value <> 2 end lambda)",
            "Set.toList(result) = filteredSet",
        ),
        (
            "Set.fold",
            "Set.fold(s: s, initial: 7, f: lambda(acc, value)\n record_visit(log: log, n: value * 110)\nreturn acc * 10 + value end lambda)",
            "result = foldedSet",
        ),
        (
            "Set.forEach",
            "Set.forEach(s: s, f: lambda(value) return record_visit(log: log, n: value * 110) end lambda)",
            "result = ()",
        ),
    ];
    for count in [0, 1, 3] {
        let pairs = (1..=count)
            .rev()
            .map(|n| format!("Pair({n}, {})", n * 10))
            .collect::<Vec<_>>()
            .join(", ");
        let keys = (1..=count)
            .rev()
            .map(|n| n.to_string())
            .collect::<Vec<_>>()
            .join(", ");
        let trace = (1..=count)
            .map(|n| (n * 110).to_string())
            .collect::<Vec<_>>()
            .join(", ");
        let mapped = (1..=count)
            .map(|n| format!("Pair({n}, {})", n * 11))
            .collect::<Vec<_>>()
            .join(", ");
        let filtered_map = (1..=count)
            .filter(|&n| n != 2)
            .map(|n| format!("Pair({n}, {})", n * 10))
            .collect::<Vec<_>>()
            .join(", ");
        let filtered_set = (1..=count)
            .filter(|&n| n != 2)
            .map(|n| n.to_string())
            .collect::<Vec<_>>()
            .join(", ");
        let folded_map = 7 + (1..=count).map(|n| n * 11).sum::<i64>();
        let folded_set = (1..=count).fold(7, |acc, n| acc * 10 + n);
        for (name, expression, expected) in cases {
            let source = format!(
                r#"
function record_visit(log: Reference[List[Integer]], n: Integer) -> Unit uses State
  return Reference.set(reference: log, value: List.append(xs: Reference.get(log), x: n))
end function
function main() -> Result[Unit, String] uses State
  bind m: Map[Integer, Integer] <- Map.fromList([{pairs}])
  bind s: Set[Integer] <- Set.fromList([{keys}])
  bind originalMap <- Map.toList(m)
  bind originalSet <- Set.toList(s)
  bind mapped: List[Pair[Integer, Integer]] <- [{mapped}]
  bind filteredMap: List[Pair[Integer, Integer]] <- [{filtered_map}]
  bind filteredSet: List[Integer] <- [{filtered_set}]
  bind mappedSet: List[Integer] <- [{mapped_set}]
  bind foldedMap <- {folded_map}
  bind foldedSet <- {folded_set}
  bind log: Reference[List[Integer]] <- Reference.new([])
  bind result <- {expression}
  return if {expected} and Reference.get(log) = [{trace}] and Map.toList(m) = originalMap and Set.toList(s) = originalSet then
    Result.Ok(())
  else
    Result.Error("{name} result or call order")
  end if
end function
"#,
                mapped_set = if count == 0 { "" } else { "1" }
            );
            let program = compile(&source);
            let output = Arc::new(Mutex::new(Vec::new()));
            let end =
                run::run_program(&program, environment(ExecMode::Direct, Arc::clone(&output)));
            assert_eq!(end.end, EndKind::Returned, "{name}, count {count}: {end:?}");
            assert_eq!(end.exit_code, 0, "{name}, count {count}: {end:?}");
            assert!(end.reports.is_empty(), "{name}, count {count}: {end:?}");
            assert!(end.main_error.is_none(), "{name}, count {count}: {end:?}");
            assert!(output.lock().unwrap().is_empty());
        }
    }
}

// 関門: Trait の辞書を選び、Map・Set の Show・Semigroup・Monoid のソースを実行する契約。
// 型検査を通すだけでは、鍵順の表示、右の値の優先、空の値、元の Decimal の鍵の保存を
// 確かめられないため、公開の実行経路で出力と終了結果まで確かめる。
#[test]
fn map_and_set_standard_traits_show_combine_and_empty() {
    let program = compile(
        r#"
import Benitoite.Trait
import Benitoite.Unofficial.IO.Console
function main() -> Result[Unit, String] uses Console.Write
  bind m <- Map.fromList([Pair(2, "b"), Pair(1, "a")])
  bind s <- Set.fromList([2, 1])
  Console.writeLine(Trait.Show.show(m))
  Console.writeLine(Trait.Show.show(s))
  Console.writeLine(Trait.Show.show(Trait.Semigroup.combine(x: m, y: Map.fromList([Pair(1, "new"), Pair(3, "c")]))))
  Console.writeLine(Trait.Show.show(Trait.Semigroup.combine(x: s, y: Set.fromList([3, 2]))))
  bind emptyMap: Map[Integer, String] <- Trait.Monoid.empty()
  bind emptySet: Set[Integer] <- Trait.Monoid.empty()
  Console.writeLine(Trait.Show.show(emptyMap))
  Console.writeLine(Trait.Show.show(emptySet))
  bind d <- Trait.Semigroup.combine(x: Map.fromList([Pair(1.0m, "old")]), y: Map.fromList([Pair(1.00m, "new")]))
  bind preserved <- Decimal.toString(List.head(Map.keys(d)) |> Option.unwrapOr(o: _, fallback: 0m)) = "1.0" and Map.get(m: d, k: 1.00m) = Option.Some("new")
  return if preserved and Map.toList(Trait.Semigroup.combine(x: emptyMap, y: m)) = Map.toList(m) and Map.toList(Trait.Semigroup.combine(x: m, y: emptyMap)) = Map.toList(m) and Set.toList(Trait.Semigroup.combine(x: emptySet, y: s)) = Set.toList(s) and Set.toList(Trait.Semigroup.combine(x: s, y: emptySet)) = Set.toList(s) and Map.toList(m) = [Pair(1, "a"), Pair(2, "b")] and Set.toList(s) = [1, 2] then
    Result.Ok(())
  else
    Result.Error("collection traits")
  end if
end function
"#,
    );
    let output = Arc::new(Mutex::new(Vec::new()));
    let end = run::run_program(&program, environment(ExecMode::Direct, Arc::clone(&output)));
    assert_eq!(end.end, EndKind::Returned, "{end:?}");
    assert_eq!(end.exit_code, 0, "{end:?}");
    assert!(end.reports.is_empty(), "{end:?}");
    assert!(end.main_error.is_none(), "{end:?}");
    assert_eq!(*output.lock().unwrap(), b"Map.fromList([Pair(1, \"a\"), Pair(2, \"b\")])\nSet.fromList([1, 2])\nMap.fromList([Pair(1, \"new\"), Pair(2, \"b\"), Pair(3, \"c\")])\nSet.fromList([1, 2, 3])\nMap.fromList([])\nSet.fromList([])\n");
}

// 関門: 不透明な失敗値の Show が message をそのまま返す契約を公開の実行経路で守る。
// 既存のコレクションの Show 検査にはこの二型の辞書選択・組み込みの呼び出しがない。
// 不正なパスと URL は外部のファイル・通信へ進まず失敗し、本番の差し込み口を増やさない。
#[test]
fn opaque_failures_show_their_messages_in_both_io_modes() {
    let program = compile(
        r#"
import Benitoite.Trait
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.Network.Http
function main() -> Result[Unit, String] uses File.Read, Http.Connect
  bind io <- match File.readText("\u{0}") with
    case Result.Error(e) -> Trait.Show.show(e) = IOError.message(e) and IOError.message(e) <> ""
    case Result.Ok(_) -> false
  end match
  bind network <- match Http.get("ftp://invalid.example/") with
    case Result.Error(e) -> Trait.Show.show(e) = "URL must be an absolute http or https URL"
      and Trait.Show.show(e) = NetworkError.message(e)
    case Result.Ok(_) -> false
  end match
  return if io and network then Result.Ok(()) else Result.Error("failure Show") end if
end function
"#,
    );
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(mode, Arc::clone(&output)));
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{mode:?}: {end:?}");
        assert!(end.main_error.is_none(), "{mode:?}: {end:?}");
        assert!(output.lock().unwrap().is_empty());
    }
}

// 作成時の関門: 狭い整数の変換の範囲と字句、拡大の正確さを公開の実行経路で守る。
// 旧 Integer のテストには縮小や符号なしの負号の拒否がなく、登録漏れや幅の取り違えを捕まえない。
// 本物の段をつなぎ、テスト専用の差し込み口は加えない。
#[test]
fn narrow_integer_conversions_preserve_values_and_reject_invalid_input() {
    for (module, suffix, low, high) in [
        ("Integer8", "s8", -128_i64, 127_i64),
        ("Integer16", "s16", -32768, 32767),
        ("Integer32", "s32", -2147483648, 2147483647),
        ("UnsignedInteger16", "u16", 0, 65535),
        ("UnsignedInteger32", "u32", 0, 4294967295),
    ] {
        let below = low - 1;
        let above = high + 1;
        let mut checks = vec![
            format!("{module}.fromInteger({low}) = Option.Some({low}{suffix})"),
            format!("{module}.fromInteger({high}) = Option.Some({high}{suffix})"),
            format!("{module}.fromInteger({below}) = Option.None"),
            format!("{module}.fromInteger({above}) = Option.None"),
            format!("{module}.fromInteger(-9223372036854775808) = Option.None"),
            format!("{module}.fromInteger(9223372036854775807) = Option.None"),
            format!("{module}.toInteger({low}{suffix}) = {low}"),
            format!("{module}.toInteger({high}{suffix}) = {high}"),
            format!("{module}.toFloat({low}{suffix}) = {low}.0"),
            format!("{module}.toFloat({high}{suffix}) = {high}.0"),
            format!("{module}.parse(\"{low}\") = Option.Some({low}{suffix})"),
            format!("{module}.parse(\"{high}\") = Option.Some({high}{suffix})"),
            format!("{module}.parse(\"{below}\") = Option.None"),
            format!("{module}.parse(\"{above}\") = Option.None"),
            format!("{module}.parse(\"0\") = Option.Some(0{suffix})"),
            format!(
                "{module}.parse(\"-0\") = {}",
                if low < 0 {
                    format!("Option.Some(0{suffix})")
                } else {
                    "Option.None".into()
                }
            ),
        ];
        for invalid in [
            "",
            "-",
            "+1",
            "01",
            "00",
            "-01",
            " 1",
            "1 ",
            "1\\n",
            "0x10",
            "1_0",
            "1.0",
            "1e1",
            "999999999999999999999999999999",
        ] {
            checks.push(format!("{module}.parse(\"{invalid}\") = Option.None"));
        }
        let source = format!(
            "function main() -> Result[Unit, String]\n return if {} then Result.Ok(()) else Result.Error(\"{module} conversions\") end if\nend function\n",
            checks.join(" and ")
        );
        let program = compile(&source);
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(ExecMode::Direct, output));
        assert_eq!(end.exit_code, 0, "{module}: {end:?}");
        assert_eq!(end.end, EndKind::Returned, "{module}: {end:?}");
        assert!(end.reports.is_empty(), "{module}: {end:?}");
    }
}

// 作成時の関門: 床と 0 方向の除算の違い、最小値の剰余、絶対値と大小を守る。
// 算術演算子の既存テストは標準関数の床への補正を通らず、負の除数の誤りを捕まえない。
#[test]
fn narrow_integer_standard_functions_keep_floor_and_truncation_distinct() {
    for (module, suffix, low, high) in [
        ("Integer8", "s8", -128_i64, 127_i64),
        ("Integer16", "s16", -32768, 32767),
        ("Integer32", "s32", -2147483648, 2147483647),
        ("UnsignedInteger16", "u16", 0, 65535),
        ("UnsignedInteger32", "u32", 0, 4294967295),
    ] {
        let mut checks = vec![
            format!("{module}.minimum(a: {low}{suffix}, b: {high}{suffix}) = {low}{suffix}"),
            format!("{module}.minimum(a: {high}{suffix}, b: {low}{suffix}) = {low}{suffix}"),
            format!("{module}.maximum(a: {low}{suffix}, b: {high}{suffix}) = {high}{suffix}"),
            format!("{module}.maximum(a: {high}{suffix}, b: {low}{suffix}) = {high}{suffix}"),
            format!("{module}.absolute({high}{suffix}) = {high}{suffix}"),
            format!("{module}.absolute(0{suffix}) = 0{suffix}"),
            format!("{module}.floorDivide(a: {low}{suffix}, b: 1{suffix}) = {low}{suffix}"),
            format!("{module}.floorModulo(a: {low}{suffix}, b: 1{suffix}) = 0{suffix}"),
        ];
        let mut divisions = vec![(7, 3, 2, 1, 2, 1), (6, 3, 2, 0, 2, 0), (0, 3, 0, 0, 0, 0)];
        if low < 0 {
            checks.push(format!("{module}.absolute(-7{suffix}) = 7{suffix}"));
            checks.push(format!(
                "{module}.floorModulo(a: {low}{suffix}, b: -1{suffix}) = 0{suffix}"
            ));
            checks.push(format!(
                "{module}.floorDivide(a: {high}{suffix}, b: {low}{suffix}) = -1{suffix}"
            ));
            checks.push(format!(
                "{module}.floorModulo(a: {high}{suffix}, b: {low}{suffix}) = -1{suffix}"
            ));
            checks.push(format!(
                "{module}.floorDivide(a: {low}{suffix}, b: {high}{suffix}) = -2{suffix}"
            ));
            checks.push(format!(
                "{module}.floorModulo(a: {low}{suffix}, b: {high}{suffix}) = {}{suffix}",
                high - 1
            ));
            divisions.extend([
                (-7, 3, -3, 2, -2, -1),
                (7, -3, -3, -2, -2, 1),
                (-7, -3, 2, -1, 2, -1),
                (-6, 3, -2, 0, -2, 0),
                (6, -3, -2, 0, -2, 0),
                (0, -3, 0, 0, 0, 0),
            ]);
        }
        for (a, b, q, r, trunc_q, trunc_r) in divisions {
            checks.extend([
                format!("{module}.floorDivide(a: {a}{suffix}, b: {b}{suffix}) = {q}{suffix}"),
                format!("{module}.floorModulo(a: {a}{suffix}, b: {b}{suffix}) = {r}{suffix}"),
                format!("({a}{suffix} div {b}{suffix}) = {trunc_q}{suffix}"),
                format!("({a}{suffix} mod {b}{suffix}) = {trunc_r}{suffix}"),
            ]);
        }
        let source = format!(
            "function main() -> Result[Unit, String]\n return if {} then Result.Ok(()) else Result.Error(\"{module} standard functions\") end if\nend function\n",
            checks.join(" and ")
        );
        let program = compile(&source);
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(ExecMode::Direct, output));
        assert_eq!(end.exit_code, 0, "{module}: {end:?}");
        assert_eq!(end.end, EndKind::Returned, "{module}: {end:?}");
        assert!(end.reports.is_empty(), "{module}: {end:?}");
    }
}

// 作成時の関門: 標準関数の失敗が None や panic にならず、規定の診断で停止する契約。
// 既存の演算子のテストは標準関数を呼ばないため、同じ幅でも別の登録と本体を確かめる。
#[test]
fn fixed_width_integer_standard_functions_report_overflow_and_zero_divisors() {
    use benitoite::diag::DiagCode;
    for (module, suffix, low) in [
        ("Integer8", "s8", -128_i64),
        ("Integer16", "s16", -32768),
        ("Integer32", "s32", -2147483648),
        ("UnsignedInteger16", "u16", 0),
        ("UnsignedInteger32", "u32", 0),
        ("UnsignedInteger64", "u64", 0),
        ("UnsignedInteger", "u64", 0),
    ] {
        let mut cases = vec![
            (
                format!("{module}.floorDivide(a: 1{suffix}, b: 0{suffix})"),
                DiagCode::R0101,
            ),
            (
                format!("{module}.floorModulo(a: 1{suffix}, b: 0{suffix})"),
                DiagCode::R0101,
            ),
        ];
        if low < 0 {
            cases.extend([
                (format!("{module}.absolute({low}{suffix})"), DiagCode::R0102),
                (
                    format!("{module}.floorDivide(a: {low}{suffix}, b: -1{suffix})"),
                    DiagCode::R0102,
                ),
            ]);
        }
        for (expression, code) in cases {
            let program = compile(&format!(
                "function main() -> Unit\n bind n <- {expression}\n return ()\nend function\n"
            ));
            let output = Arc::new(Mutex::new(Vec::new()));
            let end = run::run_program(&program, environment(ExecMode::Direct, output));
            assert_eq!(end.end, EndKind::Stopped, "{expression}: {end:?}");
            assert_eq!(end.exit_code, 1, "{expression}: {end:?}");
            assert_eq!(end.reports.len(), 1, "{expression}: {end:?}");
            assert_eq!(
                end.reports.first().unwrap().code,
                Some(code),
                "{expression}: {end:?}"
            );
        }
    }
}

// Return の明示は実行結果・失敗側の短絡・入力の一回評価を変えない。
#[test]
fn explicit_and_implicit_try_return_have_the_same_success_and_failure() {
    for action in ["", " or return"] {
        let source = format!(
            r#"
import Benitoite.Unofficial.IO.Console
function inputResult(x: Result[Integer, String]) -> Result[Integer, String] uses Console.Write
  Console.write("r")
  return x
end function
function result(x: Result[Integer, String]) -> Result[String, String] uses Console.Write
  bind n <- try inputResult(x){action}
  Console.write("+")
  return Result.Ok(Integer.toString(n))
end function
function inputOption(x: Option[Integer]) -> Option[Integer] uses Console.Write
  Console.write("o")
  return x
end function
function option(x: Option[Integer]) -> Option[String] uses Console.Write
  bind n <- try inputOption(x){action}
  Console.write("+")
  return Option.Some(Integer.toString(n))
end function
function main() -> Result[Unit, String] uses Console.Write
  bind ok <- result(Result.Ok(7))
  bind error <- result(Result.Error("failure"))
  bind some <- option(Option.Some(8))
  bind none <- option(Option.None)
  return if ok = Result.Ok("7") and error = Result.Error("failure") and some = Option.Some("8") and none = Option.None then
    Result.Ok(())
  else
    Result.Error("try result changed")
  end if
end function
"#
        );
        let program = compile(&source);
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let output = Arc::new(Mutex::new(Vec::new()));
            let end = run::run_program(&program, environment(mode, Arc::clone(&output)));
            assert_eq!(end.end, EndKind::Returned, "{action}: {end:?}");
            assert_eq!(end.exit_code, 0, "{action}: {end:?}");
            assert!(end.reports.is_empty(), "{action}: {end:?}");
            assert!(end.main_error.is_none(), "{action}: {end:?}");
            assert_eq!(*output.lock().unwrap(), b"r+ro+o");
        }
    }
}

#[path = "fixtures/scope.rs"]
mod scope_cases;

// 関門: 同じ独立入力をLeanの小モデルへも渡し、全保存欄・失敗の優先順・Showを照合する。
// 既存RangeはIntegerだけが対象で、Listの保持や成功要素の射影を通らない。
#[test]
fn checked_lists_preserve_inputs_and_error_boundaries() {
    let cases: Vec<serde_json::Value> =
        serde_json::from_str(include_str!("fixtures/checked-lists.json")).unwrap();
    let mut source = String::from(
        "import Benitoite.Unofficial.Range\nimport Benitoite.Unofficial.NonEmptyList\nimport Benitoite.Trait\nfunction main() -> Result[Unit, String]\n",
    );
    for (i, case) in cases.iter().enumerate() {
        let field = |name| case.get(name).unwrap();
        let xs = field("values");
        let length = xs.as_array().unwrap().len();
        source.push_str(&format!("bind values{i}: List[Integer] <- {xs}\n"));
        let result = field("result").as_str().unwrap();
        let (call, success, error) = match field("kind").as_str().unwrap() {
            "length" => {
                let lo = field("minimum");
                let hi = field("maximum");
                (
                    format!("Range.checkLength(minimum: {lo}, maximum: {hi}, values: values{i})"),
                    format!(
                        "Range.lengthMinimum(v) = {lo} and Range.lengthMaximum(v) = {hi} and Range.checkedLength(v) = {length} and Range.lengthValues(v) = {xs}"
                    ),
                    if result == "InvalidBounds" {
                        format!(
                            "Range.LengthError.InvalidBounds(lo, hi) -> lo = {lo} and hi = {hi} and Trait.Show.show(e) = \"InvalidBounds({lo}, {hi})\""
                        )
                    } else {
                        format!(
                            "Range.LengthError.OutOfRange(lo, hi, n) -> lo = {lo} and hi = {hi} and n = {length} and Trait.Show.show(e) = \"OutOfRange({lo}, {hi}, {length})\""
                        )
                    },
                )
            }
            "index" => {
                let index = field("index");
                (
                    format!("Range.checkIndex(index: {index}, values: values{i})"),
                    format!(
                        "Range.indexValue(v) = {index} and Range.indexValues(v) = {xs} and Range.get(v) = {}",
                        case.get("element").unwrap_or(&serde_json::Value::Null)
                    ),
                    format!(
                        "Range.IndexError.OutOfBounds(i, n) -> i = {index} and n = {length} and Trait.Show.show(e) = \"OutOfBounds({index}, {length})\""
                    ),
                )
            }
            "nonempty" => (
                format!("NonEmptyList.fromList(values{i})"),
                if result == "ok" {
                    format!(
                        "NonEmptyList.toList(v) = {xs} and NonEmptyList.head(v) = {} and NonEmptyList.tail(v) = {} and NonEmptyList.toList(NonEmptyList.map(value: v, f: lambda(value) return value * 2)) = {}",
                        field("head"),
                        field("tail"),
                        field("mapped")
                    )
                } else {
                    String::new()
                },
                "NonEmptyList.EmptyListError.EmptyList -> Trait.Show.show(e) = \"EmptyList\""
                    .into(),
            ),
            kind => panic!("unknown case kind {kind}"),
        };
        let branches = if result == "ok" {
            format!("case Result.Ok(v) -> {success}\ncase Result.Error(_) -> false")
        } else {
            let other = if field("kind") == "length" {
                "case _ -> false\n"
            } else {
                ""
            };
            format!(
                "case Result.Ok(_) -> false\ncase Result.Error(e) -> match e with\ncase {error}\n{other}end match"
            )
        };
        source.push_str(&format!("bind good{i} <- match {call} with\n{branches}\nend match\nif not good{i} then return Result.Error(\"case {i}\") end if\n"));
    }
    source.push_str("return Result.Ok(())\nend function\n");
    let program = compile(&source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let end = run::run_program(&program, environment(mode, Arc::default()));
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(end.main_error.is_none(), "{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{mode:?}: {end:?}");
    }
}

// 関門: 純粋な小モデルでは扱わない要素の共有・効果の順序・Failの伝播を実行境界で守る。
// mapの先頭の二重評価、後続の先行実行、要素の複製を独立した観測値で検出する。
#[test]
fn checked_lists_share_elements_and_map_effects_in_order() {
    let source = r#"
import Benitoite.Unofficial.Range
import Benitoite.Unofficial.NonEmptyList
import Benitoite.Unofficial.Failure
import Benitoite.Unofficial.IO.Process
function main() -> Result[Unit, String] uses State, Process.Exit
  bind cell <- Reference.new(10)
  bind original <- [cell]
  bind length <- try Range.checkLength(minimum: 1, maximum: 1, values: original) or die
  bind index <- try Range.checkIndex(index: 0, values: original) or die
  bind nonempty <- try NonEmptyList.fromList(original) or die
  Reference.set(reference: cell, value: 42)
  bind kept <- try List.head(Range.lengthValues(length)) or die
  bind indexed <- try List.head(Range.indexValues(index)) or die
  if Reference.get(kept) <> 42 or Reference.get(indexed) <> 42 or Reference.get(Range.get(index)) <> 42 or Reference.get(NonEmptyList.head(nonempty)) <> 42 then
    return Result.Error("elements were copied")
  end if
  if not List.isEmpty(NonEmptyList.tail(nonempty)) then return Result.Error("singleton tail") end if
  bind log <- Reference.new([])
  bind input <- try NonEmptyList.fromList([3, 1, 3]) or die
  bind mapped <- NonEmptyList.map(value: input, f: lambda(value)
    Reference.set(reference: log, value: List.append(xs: Reference.get(log), x: value))
    return Integer.toString(value)
  end lambda)
  if Reference.get(log) <> [3, 1, 3] or NonEmptyList.toList(mapped) <> ["3", "1", "3"] then
    return Result.Error("map order or result")
  end if
  bind failedInput <- try NonEmptyList.fromList([1, 2, 3]) or die
  Reference.set(reference: log, value: [])
  bind failed <- Failure.toResult(body: lambda()
    return NonEmptyList.map(value: failedInput, f: lambda(value)
      Reference.set(reference: log, value: List.append(xs: Reference.get(log), x: value))
      if value = 2 then return Failure.raise("middle") end if
      return value
    end lambda)
  end lambda)
  bind failureKept <- match failed with
    case Result.Error(e) -> e = "middle"
    case Result.Ok(_) -> false
  end match
  if not failureKept or Reference.get(log) <> [1, 2] then return Result.Error("map continued after Fail") end if
  Reference.set(reference: log, value: [])
  bind headFailed <- Failure.toResult(body: lambda()
    return NonEmptyList.map(value: failedInput, f: lambda(value)
      Reference.set(reference: log, value: List.append(xs: Reference.get(log), x: value))
      if value = 1 then return Failure.raise("head") end if
      return value
    end lambda)
  end lambda)
  bind headFailureKept <- match headFailed with
    case Result.Error(e) -> e = "head"
    case Result.Ok(_) -> false
  end match
  if not headFailureKept or Reference.get(log) <> [1] then return Result.Error("map continued after head Fail") end if
  return Result.Ok(())
end function
"#;
    let program = compile(source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let end = run::run_program(&program, environment(mode, Arc::default()));
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(end.main_error.is_none(), "{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{mode:?}: {end:?}");
    }
}

// 四問: 独立入力で成功時の全保存欄と六失敗・優先順・Showを公開実行経路で守る。
// 静的拒否の表だけでは、私有builtinの配線・Result/Pair・標準ラッパー・射影を通らない。
// 通常の引数を通じて実行時Errorを観察し、差し込み口は増やさない。
#[test]
fn scope_checked_values_preserve_inputs_and_runtime_errors() {
    use scope_cases::quoted as q;
    let mut source = String::from(
        r#"
import Benitoite.Unofficial.Scope
import Benitoite.Trait
function dynamicHost(pattern: String, host: String) -> Result[Scope.CheckedHost, Scope.ScopeError]
 return Scope.checkHost(pattern: pattern, host: host)
end function
function dynamicPath(pattern: String, path: String) -> Result[Scope.CheckedPath, Scope.ScopeError]
 return Scope.checkPath(pattern: pattern, path: path)
end function
function dynamicEndpoint(hostPattern: String, host: String, minimumPort: Integer, maximumPort: Integer, port: Integer) -> Result[Scope.CheckedEndpoint, Scope.ScopeError]
 return Scope.checkEndpoint(hostPattern: hostPattern, host: host, minimumPort: minimumPort, maximumPort: maximumPort, port: port)
end function
function main() -> Result[Unit, String]
"#,
    );
    for (i, case) in scope_cases::cases().into_iter().enumerate() {
        let kind = case.get("kind").unwrap().as_str().unwrap();
        let result = case.get("result").unwrap().as_str().unwrap();
        let pattern = q(case.get("pattern").unwrap().as_str().unwrap());
        let target = q(case.get("target").unwrap().as_str().unwrap());
        let expected = if result == "ok" {
            let p = q(case.get("expectedPattern").unwrap().as_str().unwrap());
            let t = q(case.get("expectedTarget").unwrap().as_str().unwrap());
            let comparison = match kind {
                "host" => format!("Scope.hostPattern(value) = {p} and Scope.host(value) = {t}"),
                "path" => format!("Scope.pathPattern(value) = {p} and Scope.path(value) = {t}"),
                _ => format!(
                    "Scope.endpointHostPattern(value) = {p} and Scope.endpointHost(value) = {t} and Scope.endpointMinimumPort(value) = {} and Scope.endpointMaximumPort(value) = {} and Scope.endpointPort(value) = {}",
                    case.get("minimum").unwrap(),
                    case.get("maximum").unwrap(),
                    case.get("port").unwrap()
                ),
            };
            // 関門: 保存した正規形を再び同じ入口へ渡す。IP/CIDRの表示が単に
            // 期待文字列と一致するだけでなく、保存後も同じ対象を受理する契約を守る。
            // 非正規形の保存や、射影時に最大prefixを取り違える退行は代数の単体検査では届かない。
            let reused = match kind {
                "host" => "dynamicHost(pattern: Scope.hostPattern(value), host: Scope.host(value))".to_owned(),
                "path" => "dynamicPath(pattern: Scope.pathPattern(value), path: Scope.path(value))".to_owned(),
                _ => "dynamicEndpoint(hostPattern: Scope.endpointHostPattern(value), host: Scope.endpointHost(value), minimumPort: Scope.endpointMinimumPort(value), maximumPort: Scope.endpointMaximumPort(value), port: Scope.endpointPort(value))".to_owned(),
            };
            let reused_comparison = comparison.replace("(value)", "(again)");
            format!(
                "case Result.Ok(value) -> {comparison} and match {reused} with\n case Result.Ok(again) -> {reused_comparison}\n case Result.Error(_) -> false\n end match\n case Result.Error(_) -> false"
            )
        } else {
            let error = match result {
                "InvalidPattern" => format!(
                    "Scope.ScopeError.InvalidPattern(input, reason) -> input = {pattern} and String.byteLength(reason) > 0"
                ),
                "InvalidTarget" => format!(
                    "Scope.ScopeError.InvalidTarget(input, reason) -> input = {target} and String.byteLength(reason) > 0"
                ),
                "OutsideScope" => {
                    format!("Scope.ScopeError.OutsideScope(p, t) -> p = {pattern} and t = {target}")
                }
                "InvalidPortRange" => format!(
                    "Scope.ScopeError.InvalidPortRange(lo, hi) -> lo = {} and hi = {}",
                    case.get("minimum").unwrap(),
                    case.get("maximum").unwrap()
                ),
                "InvalidPort" => format!(
                    "Scope.ScopeError.InvalidPort(port) -> port = {}",
                    case.get("port").unwrap()
                ),
                _ => format!(
                    "Scope.ScopeError.PortOutsideScope(lo, hi, port) -> lo = {} and hi = {} and port = {}",
                    case.get("minimum").unwrap(),
                    case.get("maximum").unwrap(),
                    case.get("port").unwrap()
                ),
            };
            format!(
                "case Result.Ok(_) -> false\n case Result.Error(error) ->\n String.byteLength(Trait.Show.show(error)) <= 4096 and match error with\n case {error}\n case _ -> false\n end match"
            )
        };
        source.push_str(&format!(" bind good{i} <- match dynamic{}({}) with\n {expected}\n end match\n if not good{i} then return Result.Error(\"scope case {i}\") end if\n", scope_cases::operation(&case), scope_cases::arguments(&case)));
    }
    source.push_str(r#"
 bind original <- String.repeat(s: "あ", n: 3000)
 bind preserved <- match dynamicHost(pattern: "localhost", host: original) with
   case Result.Error(Scope.ScopeError.InvalidTarget(value, _)) -> value = original
   case _ -> false
 end match
 if not preserved then return Result.Error("scope original input") end if
 bind shown <- Trait.Show.show(Scope.ScopeError.InvalidPattern("a\"\n", "why"))
 if shown <> "InvalidPattern(\"a\\\"\\n\", \"why\")" then return Result.Error(shown) end if
 bind long <- Trait.Show.show(Scope.ScopeError.OutsideScope(String.repeat(s: "é", n: 5000), String.repeat(s: "\u{0}", n: 5000)))
 if String.byteLength(long) > 4096 or not String.endsWith(s: long, suffix: "...") then return Result.Error("scope show limit") end if
 if not String.startsWith(s: long, prefix: "OutsideScope(\"") or not String.endsWith(s: long, suffix: "\")...") then return Result.Error("scope show delimiters") end if
 bind escaped <- Trait.Show.show(Scope.ScopeError.InvalidPattern(String.repeat(s: "\u{0}", n: 5000), String.repeat(s: "\\\"\nあ", n: 5000)))
 if String.byteLength(escaped) > 4096 or not String.endsWith(s: escaped, suffix: "\")...") then return Result.Error("scope escaped show delimiters") end if
 if not String.contains(s: escaped, part: "\\u{0}") or String.contains(s: escaped, part: "\\u{...") then return Result.Error("scope show partial escape") end if

 return Result.Ok(())
end function
"#);
    let program = compile(&source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(mode, Arc::clone(&output)));
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(end.main_error.is_none(), "{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{mode:?}: {end:?}");
        assert!(output.lock().unwrap().is_empty());
    }
}

// 関門: 新しい純粋入口の動的な所属判定・元のパス・失敗入力と優先順を、
// 通常ソースからVMと参照実行器で守る。旧Checked型の検査はこの入口を通らず、
// Topだけを見て検査を省く退行や、Okの保存後のGCでの消失を捕まえない。
// 差し込み口は増やさず、同じResultの受け渡しと既存のstress環境を使う。
#[test]
fn scope_path_in_checks_dynamic_inputs_and_preserves_the_same_ok() {
    let source = r#"
import Benitoite.Unofficial.Scope
function retain[T](value: T) -> T
 return value
end function
function accepted(pattern: String, path: String) -> Boolean
 bind original <- Scope.checkPathIn(pattern: pattern, path: path)
 bind kept <- retain(original)
 bind unused <- String.repeat(s: "猫", n: 4000)
 return String.byteLength(unused) = 12000 and match kept with
   case Result.Ok(value) -> Scope.pathInValue(path: value) = path and Scope.pathInValue(path: value) = path
   case Result.Error(_) -> false
 end match
end function
function rejected(pattern: String, path: String, expected: Integer) -> Boolean
 return match Scope.checkPathIn(pattern: pattern, path: path) with
   case Result.Error(Scope.ScopeError.InvalidPattern(input, reason)) -> expected = 1 and input = pattern and String.byteLength(reason) > 0
   case Result.Error(Scope.ScopeError.InvalidTarget(input, reason)) -> expected = 2 and input = path and String.byteLength(reason) > 0
   case Result.Error(Scope.ScopeError.OutsideScope(p, t)) -> expected = 3 and p = pattern and t = path
   case _ -> false
 end match
end function
function main() -> Result[Unit, String]
 if not accepted(pattern: "/data/**", path: "/data") then return Result.Error("tree stem") end if
 if not accepted(pattern: "/data/**", path: "/data/猫/*") then return Result.Error("same target spelling") end if
 if not accepted(pattern: "/data/exact", path: "/data/exact") then return Result.Error("exact") end if
 if not accepted(pattern: "/**", path: "/") then return Result.Error("root") end if
 if not rejected(pattern: "/data/**", path: "/database/file", expected: 3) then return Result.Error("component membership") end if
 if not rejected(pattern: "/data/exact", path: "/data/exact/child", expected: 3) then return Result.Error("exact excludes child") end if
 if not rejected(pattern: "/data/*", path: "/data/child", expected: 1) then return Result.Error("invalid pattern") end if
 if not rejected(pattern: "/data/**", path: "/data/../else", expected: 2) then return Result.Error("invalid target") end if
 if not rejected(pattern: "/data/*", path: "relative", expected: 1) then return Result.Error("pattern before target") end if
 bind direct <- Scope.checkPathIn(pattern: "/data/**", path: "/data/direct")
 return match direct with
   case Result.Ok(value) ->
    bind text <- Scope.pathInValue(path: value)
    if text = "/data/direct" then Result.Ok(()) else Result.Error("direct projection") end if
   case Result.Error(_) -> Result.Error("direct check")
 end match
end function
"#;
    let program = compile(source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let end = run::run_program(
            &program,
            environment(mode, Arc::new(Mutex::new(Vec::new()))),
        );
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(end.main_error.is_none(), "{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{mode:?}: {end:?}");

        let checked = pipeline::check_text(
            "scope-path-in.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let compared = differential::compare(
            checked.program.unwrap(),
            checked.sources,
            environment(mode, Arc::new(Mutex::new(Vec::new()))).input,
            VmConfig::default(),
            mode,
            differential::CompareOptions {
                require_returned: true,
                ..Default::default()
            },
            Box::new(|| Ok(())),
        );
        match compared {
            differential::Comparison::Matched => {}
            differential::Comparison::Failed(reason)
            | differential::Comparison::Excluded(reason) => panic!("{mode:?}: {reason}"),
        }
    }
}

// 関門: 通常ソースの純粋な検査→同じOkの保存→射影→五欄の参照を守る。
// URL境界・既定port・IPの数値・動的条件の退行と、安全点後の要求の消失を
// 捕まえる。既存Http.sendはこの純粋入口を通らない。差し込み口や裸の
// RequestIn注釈を増やさず、両IO方式と既存の参照実行器を使う。
#[test]
fn http_request_in_checks_endpoints_and_retains_the_same_request() {
    let mut source = String::from(
        r#"
import Benitoite.Unofficial.Network.Http
import Benitoite.Unofficial.Scope
function retain[T](value: T) -> T
 return value
end function
function accepted(pattern: String, lo: Integer, hi: Integer, url: String) -> Boolean
 bind request <- Http.ClientRequest(method: "PATCH", url: url, headers: [Pair("X-Test", "same"), Pair("X-Test", "again")], body: String.toUTF8("猫"), timeoutMilliseconds: 1234)
 bind original <- Http.checkRequestIn(hostPattern: pattern, minimumPort: lo, maximumPort: hi, request: request)
 bind kept <- retain(original)
 bind unused <- String.repeat(s: "猫", n: 4000)
 return String.byteLength(unused) = 12000 and match kept with
  case Result.Ok(value) ->
   bind projected <- Http.requestInValue(request: value)
   bind changed <- Http.ClientRequest(..projected, url: "https://outside.example/")
   bind unchanged <- Http.requestInValue(request: value)
   Http.ClientRequest.method(projected) = "PATCH" and Http.ClientRequest.url(projected) = url and
    Http.ClientRequest.headers(projected) = [Pair("X-Test", "same"), Pair("X-Test", "again")] and
    Http.ClientRequest.body(projected) = String.toUTF8("猫") and Http.ClientRequest.timeoutMilliseconds(projected) = 1234 and
    Http.ClientRequest.url(changed) = "https://outside.example/" and Http.ClientRequest.url(unchanged) = url and
    match Http.checkRequestIn(hostPattern: pattern, minimumPort: lo, maximumPort: hi, request: changed) with
     case Result.Error(_) -> true
     case Result.Ok(_) -> false
    end match
  case Result.Error(_) -> false
 end match
end function
function rejected(pattern: String, lo: Integer, hi: Integer, url: String, expected: Integer) -> Boolean
 return match Http.checkRequestIn(hostPattern: pattern, minimumPort: lo, maximumPort: hi, request: Http.clientRequest(method: "GET", url: url)) with
  case Result.Error(Http.RequestCheckError.InvalidUrl(message)) -> expected = 1 and String.byteLength(message) > 0
  case Result.Error(Http.RequestCheckError.Scope(Scope.ScopeError.InvalidPattern(input, reason))) -> expected = 2 and input = pattern and String.byteLength(reason) > 0
  case Result.Error(Http.RequestCheckError.Scope(Scope.ScopeError.InvalidTarget(_, reason))) -> expected = 3 and String.byteLength(reason) > 0
  case Result.Error(Http.RequestCheckError.Scope(Scope.ScopeError.InvalidPortRange(minimum, maximum))) -> expected = 4 and minimum = lo and maximum = hi
  case Result.Error(Http.RequestCheckError.Scope(Scope.ScopeError.OutsideScope(input, _))) -> expected = 5 and input = pattern
  case Result.Error(Http.RequestCheckError.Scope(Scope.ScopeError.PortOutsideScope(minimum, maximum, _))) -> expected = 6 and minimum = lo and maximum = hi
  case _ -> false
 end match
end function
function main() -> Result[Unit, String]
"#,
    );
    for (i, (pattern, lo, hi, url)) in [
        (
            "api.example.com",
            443,
            443,
            "https://API.EXAMPLE.COM/a?q=one%20two#fragment",
        ),
        ("*.example.com", 80, 80, "http://api.example.com"),
        ("a0x.example", 80, 80, "http://a0x.example/"),
        ("dead.beef", 80, 80, "http://dead.beef/"),
        ("123.example", 80, 80, "http://123.example/"),
        ("**.example.com", 443, 443, "https://deep.api.example.com:/"),
        ("api.example.com", 80, 80, "HTTP://api.example.com:/"),
        ("api.example.com", 443, 443, "http://api.example.com:443/"),
        ("127.0.0.0/8", 0, 65535, "http://127.0.0.1:0/"),
        ("::1", 80, 80, "http://[0:0:0:0:0:0:0:1]/"),
        ("2001:db8::/32", 443, 443, "https://[2001:DB8:0:0:0:0:0:1]/"),
        ("::/0", 443, 443, "https://[::1]/"),
        ("::/0", 80, 80, "http://[::fffe:ffff:ffff]/"),
        ("::/0", 80, 80, "http://[::1:0:0:0]/"),
        ("::/0", 80, 80, "http://[::192.0.2.1]/"),
        ("64:ff9b::/96", 80, 80, "http://[64:ff9b::192.0.2.1]/"),
    ]
    .into_iter()
    .enumerate()
    {
        source.push_str(&format!(" if not accepted(pattern: {pattern:?}, lo: {lo}, hi: {hi}, url: {url:?}) then return Result.Error(\"accepted {i}\") end if\n"));
    }
    for (i, (pattern, lo, hi, url, expected)) in [
        ("example.com", 0, 65535, "not a URL", 1),
        ("example.com", 0, 65535, "ftp://example.com/", 1),
        ("example.com", 0, 65535, "/relative", 1),
        ("example.com", 0, 65535, "http:///path", 1),
        ("example.com", 0, 65535, "https://example.com:65536/", 1),
        ("example.com", 0, 65535, "https://example.com:xyz/", 1),
        ("example.com", 0, 65535, "https://example.com:-1/", 1),
        ("example.com", 0, 65535, "https://user@example.com/", 1),
        ("example.com", 0, 65535, "https://example.com/%GG", 1),
        ("example.com", 0, 65535, "https://example.com/猫", 1),
        ("example.com", 0, 65535, "https://example.com/a\\b", 1),
        ("example.com", 0, 65535, "https://example.com./", 3),
        ("127.1", 0, 65535, "http://127.1/", 3),
        ("123", 0, 65535, "http://123/", 3),
        ("0x7f000001", 0, 65535, "http://0x7f000001/", 3),
        ("127.0x.0.1", 0, 65535, "http://127.0x.0.1/", 3),
        ("127.0x.1", 0, 65535, "http://127.0x.1/", 3),
        ("**.1", 0, 65535, "http://0x7f.0x0.0x.1/", 3),
        ("0x.1.2.3", 0, 65535, "http://0x.1.2.3/", 3),
        ("127.0X.0.1", 0, 65535, "http://127.0X.0.1/", 3),
        ("127.0.0.1", 0, 65535, "http://127.00.0.1/", 3),
        ("127.0.0.1", 0, 65535, "http://999.0.0.1/", 3),
        ("*.127.0.0.1", 0, 65535, "http://127.0.0.1/", 2),
        ("bad..pattern", 0, 65535, "http://example.com/", 2),
        ("example.com", -1, 443, "https://example.com/", 4),
        ("example.com", 0, 65536, "https://example.com/", 4),
        ("example.com", 444, 443, "https://example.com/", 4),
        (
            "example.com",
            -9223372036854775807_i64,
            9223372036854775807_i64,
            "https://example.com/",
            4,
        ),
        ("*.example.com", 0, 65535, "https://example.com/", 5),
        ("other.example", 0, 65535, "https://example.com/", 5),
        ("127.0.0.1", 0, 65535, "https://[::ffff:127.0.0.1]/", 3),
        ("::/0", 0, 65535, "http://[::ffff:127.0.0.1]:18081/", 3),
        ("::/0", 0, 65535, "http://[::FfFf:7F00:0001]:18081/", 3),
        (
            "::/0",
            0,
            65535,
            "http://[0000:0000:0000:0000:0000:FFFF:7f00:0001]:18081/",
            3,
        ),
        ("::/0", 0, 65535, "http://[::FFFF:7F00:1]:18081/", 3),
        (
            "::/0",
            0,
            65535,
            "http://[0:0:0:0:0:FFFF:127.0.0.1]:18081/",
            3,
        ),
        ("::/0", 0, 65535, "http://[::ffff:0.0.0.0]:18081/", 3),
        (
            "::/0",
            0,
            65535,
            "http://[::ffff:255.255.255.255]:18081/",
            3,
        ),
        (
            "::ffff:0.0.0.0/96",
            0,
            65535,
            "http://[::ffff:127.0.0.1]:18081/",
            3,
        ),
        (
            "::ffff:0.0.0.0/96",
            0,
            65535,
            "http://[::FFFF:7F00:1]:18081/",
            3,
        ),
        (
            "::ffff:0.0.0.0/96",
            0,
            65535,
            "http://[0:0:0:0:0:FFFF:127.0.0.1]:18081/",
            3,
        ),
        (
            "::ffff:0.0.0.0/96",
            0,
            65535,
            "http://[::ffff:0.0.0.0]:18081/",
            3,
        ),
        (
            "::ffff:0.0.0.0/96",
            0,
            65535,
            "http://[::ffff:255.255.255.255]:18081/",
            3,
        ),
        (
            "::ffff:127.0.0.1",
            0,
            65535,
            "http://[::ffff:127.0.0.1]:18081/",
            3,
        ),
        (
            "::ffff:127.0.0.1",
            0,
            65535,
            "http://[::FFFF:7F00:1]:18081/",
            3,
        ),
        (
            "::ffff:127.0.0.1",
            0,
            65535,
            "http://[0:0:0:0:0:FFFF:127.0.0.1]:18081/",
            3,
        ),
        (
            "::ffff:127.0.0.1",
            0,
            65535,
            "http://[::ffff:0.0.0.0]:18081/",
            3,
        ),
        (
            "::ffff:127.0.0.1",
            0,
            65535,
            "http://[::ffff:255.255.255.255]:18081/",
            3,
        ),
        ("example.com", 80, 80, "https://example.com/", 6),
        ("example.com", 443, 443, "http://example.com/", 6),
        ("bad..pattern", -1, -1, "ftp://example.com/", 1),
    ]
    .into_iter()
    .enumerate()
    {
        source.push_str(&format!(" if not rejected(pattern: {pattern:?}, lo: {lo}, hi: {hi}, url: {url:?}, expected: {expected}) then return Result.Error(\"rejected {i}\") end if\n"));
    }
    source.push_str(" return Result.Ok(())\nend function\n");
    let program = compile(&source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let end = run::run_program(
            &program,
            environment(mode, Arc::new(Mutex::new(Vec::new()))),
        );
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(end.main_error.is_none(), "{mode:?}: {end:?}");
        assert!(end.reports.is_empty(), "{mode:?}: {end:?}");
        let checked = pipeline::check_text(
            "http-request-in.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let compared = differential::compare(
            checked.program.unwrap(),
            checked.sources,
            environment(mode, Arc::new(Mutex::new(Vec::new()))).input,
            VmConfig::default(),
            mode,
            differential::CompareOptions {
                require_returned: true,
                ..Default::default()
            },
            Box::new(|| Ok(())),
        );
        match compared {
            differential::Comparison::Matched => {}
            differential::Comparison::Failed(reason)
            | differential::Comparison::Excluded(reason) => panic!("{mode:?}: {reason}"),
        }
    }
}

// 関門: 「同じレコードを返す」は言語の構造的等値だけでは区別できない。
// 公開の組み込み呼出しとsame_objectで、射影が同値の複製を作る退行を捕まえる。
// 通常ソースのテストが扱えない同一性だけをここで確認し、差し込み口は加えない。
#[test]
fn http_request_in_projection_and_widen_return_the_original_objects() {
    use benitoite::builtins::iface::{CallCtx, Reply};
    use benitoite::builtins::{builtin_decl, lookup_builtin};
    use benitoite::runtime::heap::{FieldsKind, Heap, Value as V};
    use benitoite::types::scope::{EndpointPattern, HostPattern, Port, PortRange, Range};
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let method = ctx.alloc_str("POST", "request identity").unwrap();
        let url = ctx
            .alloc_str("https://example.com/path?x=1", "request identity")
            .unwrap();
        let body = ctx.alloc_bytes(b"body", "request identity").unwrap();
        let request = ctx
            .alloc_fields(
                FieldsKind::Ctor,
                0,
                &[method, url, V::EmptyList, body, V::Int(1234)],
            )
            .unwrap();
        let pattern = ctx.alloc_str("example.com", "request identity").unwrap();
        let narrow = Range::Endpoint(EndpointPattern {
            host: HostPattern::parse("example.com").unwrap(),
            ports: PortRange::new(Port::from_int(443).unwrap(), Port::from_int(443).unwrap())
                .unwrap(),
        });
        let check = builtin_decl(lookup_builtin("Http.checkRequestIn").unwrap()).unwrap();
        let outside = Range::Endpoint(EndpointPattern {
            host: HostPattern::parse("other.example").unwrap(),
            ports: PortRange::new(Port::from_int(443).unwrap(), Port::from_int(443).unwrap())
                .unwrap(),
        });
        let Reply::Done(rejected) = (check.raw)(
            &mut CallCtx::new(ctx, None, None, None).with_ranges(&[outside]),
            &[pattern, V::Int(443), V::Int(443), request],
        )
        .unwrap() else {
            panic!("check did not return")
        };
        assert_eq!(ctx.fields_header(rejected), Some((FieldsKind::Ctor, 1)));
        let Reply::Done(result) = (check.raw)(
            &mut CallCtx::new(ctx, None, None, None).with_ranges(std::slice::from_ref(&narrow)),
            &[pattern, V::Int(443), V::Int(443), request],
        )
        .unwrap() else {
            panic!("check did not return")
        };
        assert_eq!(ctx.fields_header(result), Some((FieldsKind::Ctor, 0)));
        let checked = ctx.field(result, 0).unwrap();
        let widen = builtin_decl(lookup_builtin("Http.widenRequestIn").unwrap()).unwrap();
        let Reply::Done(widened) = (widen.raw)(
            &mut CallCtx::new(ctx, None, None, None).with_ranges(&[narrow, Range::Top]),
            &[checked],
        )
        .unwrap() else {
            panic!("widen did not return")
        };
        assert!(ctx.same_object(checked, widened));
        assert!(ctx.same_object(request, ctx.field(widened, 0).unwrap()));
        assert_eq!(ctx.str(ctx.field(widened, 1).unwrap()), Some("example.com"));
        assert!(matches!(ctx.field(widened, 2), Some(V::Int(443))));
        let project = builtin_decl(lookup_builtin("Http.requestInValue").unwrap()).unwrap();
        let Reply::Done(projected) = (project.raw)(
            &mut CallCtx::new(ctx, None, None, None).with_ranges(&[Range::Top]),
            &[widened],
        )
        .unwrap() else {
            panic!("projection did not return")
        };
        assert!(ctx.same_object(request, projected));
    });
}

// 関門: 静的な範囲を実行本体へ渡す境界と、拡大で値を作り直さない契約を守る。
// 通常ソースでは成功値の同一性や型検証を通らない静的範囲の不一致を観測できない。
// 既存の raw と same_object だけを使い、テスト専用の口は加えない。
#[test]
fn scope_path_in_checks_static_membership_and_widen_preserves_the_object() {
    use benitoite::builtins::iface::{CallCtx, Reply};
    use benitoite::builtins::{builtin_decl, lookup_builtin};
    use benitoite::runtime::heap::{FieldsKind, Heap};
    use benitoite::types::scope::{PathPattern, Range};
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let pattern = ctx.alloc_str("/**", "path identity").unwrap();
        let path = ctx.alloc_str("/data/input", "path identity").unwrap();
        let check = builtin_decl(lookup_builtin("Scope.checkPathIn").unwrap()).unwrap();
        let narrow = Range::Path(PathPattern::parse("/data/**").unwrap());
        let outside = Range::Path(PathPattern::parse("/other/**").unwrap());
        let Reply::Done(rejected) = (check.raw)(
            &mut CallCtx::new(ctx, None, None, None).with_ranges(&[outside]),
            &[pattern, path],
        )
        .unwrap() else {
            panic!("check did not return")
        };
        assert_eq!(ctx.fields_header(rejected), Some((FieldsKind::Ctor, 1)));
        let Reply::Done(result) = (check.raw)(
            &mut CallCtx::new(ctx, None, None, None).with_ranges(std::slice::from_ref(&narrow)),
            &[pattern, path],
        )
        .unwrap() else {
            panic!("check did not return")
        };
        assert_eq!(ctx.fields_header(result), Some((FieldsKind::Ctor, 0)));
        let checked = ctx.field(result, 0).unwrap();
        let widen = builtin_decl(lookup_builtin("Scope.widenPathIn").unwrap()).unwrap();
        let Reply::Done(widened) = (widen.raw)(
            &mut CallCtx::new(ctx, None, None, None).with_ranges(&[narrow, Range::Top]),
            &[checked],
        )
        .unwrap() else {
            panic!("widen did not return")
        };
        assert!(ctx.same_object(checked, widened));
        assert!(ctx.same_object(path, ctx.field(widened, 0).unwrap()));
    });
}

// 関門: raw の同一性検査では届かない、範囲の選択から両実行器への列の受け渡しを守る。
// 明示拡大の行き先を Top と書き、拡大後の射影も事実なしで受理できる契約にする。
#[test]
fn scoped_widen_calls_round_trip_through_both_evaluators() {
    let source = r#"import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.Network.Http
function pathRoundTrip() -> Boolean
 bind result <- Scope.checkPathIn(pattern: "/data/**", path: "/data/a")
 return match result with
 case Result.Ok(value) ->
  bind wide: Scope.PathIn <- Scope.widenPathIn(path: value)
  bind text <- Scope.pathInValue(path: wide)
  text = "/data/a"
 case Result.Error(_) -> false
 end match
end function
function requestRoundTrip() -> Boolean
 bind request <- Http.ClientRequest(method: "PATCH", url: "https://api.example.com/a", headers: [Pair("X-Test", "same")], body: String.toUTF8("猫"), timeoutMilliseconds: 1234)
 bind result <- Http.checkRequestIn(hostPattern: "api.example.com", minimumPort: 443, maximumPort: 443, request: request)
 return match result with
 case Result.Ok(value) ->
  bind wide: Http.RequestIn <- Http.widenRequestIn(request: value)
  bind original <- Http.requestInValue(request: wide)
  Http.ClientRequest.url(original) = "https://api.example.com/a" and Http.ClientRequest.method(original) = "PATCH" and Http.ClientRequest.body(original) = String.toUTF8("猫")
 case Result.Error(_) -> false
 end match
end function
function main() -> Result[Unit, String]
 if pathRoundTrip() and requestRoundTrip() then return Result.Ok(()) else return Result.Error("widen round trip") end if
end function"#;
    let program = compile(source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let end = run::run_program(
            &program,
            environment(mode, Arc::new(Mutex::new(Vec::new()))),
        );
        assert_eq!(end.end, EndKind::Returned, "{end:?}");
        assert_eq!(end.exit_code, 0, "{end:?}");
        assert!(end.main_error.is_none(), "{end:?}");
        assert!(end.reports.is_empty(), "{end:?}");
        let checked = pipeline::check_text(
            "widen.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        match differential::compare(
            checked.program.unwrap(),
            checked.sources,
            environment(mode, Arc::new(Mutex::new(Vec::new()))).input,
            VmConfig::default(),
            mode,
            differential::CompareOptions {
                require_returned: true,
                ..Default::default()
            },
            Box::new(|| Ok(())),
        ) {
            differential::Comparison::Matched => {}
            differential::Comparison::Failed(reason)
            | differential::Comparison::Excluded(reason) => panic!("{mode:?}: {reason}"),
        }
    }
}

// 関門: 六操作の登録から実ファイルまでを通し、対象の取り違え、置換と追記の混同、
// IOError の混同を独立したバイト列で検出する。Scope の既存同一性検査だけでは IO に届かない。
// 作業ディレクトリの木に限る入力と効果を持つ関数から六操作を実行し、非 Top の接続も通す。
// 外部ファイル以外を差し替えず、既存の VM/参照実行器の公開入口を使う。
#[test]
fn file_in_operations_use_the_retained_path_and_preserve_values_and_errors() {
    let directory = std::path::PathBuf::from(env!("CARGO_TARGET_TMPDIR"))
        .join(format!("file-in-runtime-{}", std::process::id()));
    std::fs::create_dir_all(&directory).unwrap();
    let directory = directory.canonicalize().unwrap();
    let path = directory.join("actual");
    let missing = directory.join("absent-parent/actual");
    let decoy = directory.join("decoy");
    std::fs::write(&decoy, b"untouched").unwrap();
    let source = r#"import Benitoite.Unofficial.Scope
import Benitoite.Unofficial.IO.File
function checked(path: String) -> Result[Scope.PathIn, String]
 return Scope.checkPathIn(pattern: "/**", path: path) |> Result.mapError(r: _, f: lambda(error) return "scope" end lambda)
end function
function missing[T](result: Result[T, IOError]) -> Boolean
 return match result with
 case Result.Error(error) -> IOError.kind(error) = IOErrorKind.NotFound
 case Result.Ok(_) -> false
 end match
end function
function io[T](result: Result[T, IOError]) -> Result[T, String]
 return Result.mapError(r: result, f: lambda(error) return IOError.message(error) end lambda)
end function
function intercepted(path: Scope.PathIn) -> Result[String, IOError] uses File.Read
 return handle File.readTextIn(path: path) with
 case File.readTextIn(captured) ->
  bind pad <- String.repeat(s: "x", n: 128)
  bind text <- Scope.pathInValue(path: captured)
  resume(Result.Ok(if String.characterCount(pad) = 128 then text else "wrong capture" end if))
 end handle
end function
function checkedIn(path: String) -> Result[Scope.PathIn[$TREE], String]
 bind result: Result[Scope.PathIn[$TREE], Scope.ScopeError] <- Scope.checkPathIn(pattern: $TREE, path: path)
 return Result.mapError(r: result, f: lambda(error) return "scope" end lambda)
end function
function operate(path: Scope.PathIn[$TREE], absent: Scope.PathIn[$TREE]) -> Result[Unit, String] uses File.Read[$TREE], File.Write[$TREE]
 if not (missing(File.readTextIn(path: absent)) and missing(File.readBytesIn(path: absent)) and
         missing(File.writeTextIn(path: absent, text: "x")) and missing(File.appendTextIn(path: absent, text: "x")) and
         missing(File.writeBytesIn(path: absent, content: Bytes.empty())) and missing(File.appendBytesIn(path: absent, content: Bytes.empty()))) then
   return Result.Error("missing path")
 end if
 bind replaced <- File.writeTextIn(path: path, text: "猫")
 bind first <- File.readTextIn(path: path)
 bind appended <- File.appendTextIn(path: path, text: "!\n")
 bind second <- File.readTextIn(path: path)
 if io(replaced) <> Result.Ok(()) or io(appended) <> Result.Ok(()) or io(first) <> Result.Ok("猫") or io(second) <> Result.Ok("猫!\n") then
   return Result.Error("text replace/append/read")
 end if
 bind binary <- Bytes.fromList([255u8, 0u8, 65u8])
 bind wrote <- File.writeBytesIn(path: path, content: binary)
 bind bytes <- File.readBytesIn(path: path)
 bind invalid <- File.readTextIn(path: path)
 bind invalidUTF8 <- match invalid with
 case Result.Error(error) -> IOError.kind(error) = IOErrorKind.InvalidUTF8
 case Result.Ok(_) -> false
 end match
 bind added <- File.appendBytesIn(path: path, content: Bytes.fromList([66u8, 10u8]))
 bind final <- File.readBytesIn(path: path)
 if io(wrote) = Result.Ok(()) and io(added) = Result.Ok(()) and io(bytes) = Result.Ok(binary) and invalidUTF8 and io(final) = Result.Ok(Bytes.fromList([255u8, 0u8, 65u8, 66u8, 10u8])) then
   return Result.Ok(())
 else
   return Result.Error("binary replace/append/read")
 end if
end function
function main() -> Result[Unit, String] uses File.Read, File.Write
 bind handledPath <- try checked(path: $PATH) or return
 if io(intercepted(path: handledPath)) <> Result.Ok($PATH) then return Result.Error("handler target") end if
 bind path <- try checkedIn(path: $PATH) or return
 bind absent <- try checkedIn(path: $MISSING) or return
 return operate(path: path, absent: absent)
end function"#
        .replace(
            "$TREE",
            &format!("{:?}", format!("{}/**", directory.to_str().unwrap())),
        )
        .replace("$PATH", &format!("{:?}", path.to_str().unwrap()))
        .replace("$MISSING", &format!("{:?}", missing.to_str().unwrap()));
    let checked = pipeline::check_text(
        "file-in.bnt",
        source.as_bytes(),
        CheckOptions {
            require_main: true,
            deny_warnings: false,
        },
    );
    assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
    let core = pipeline::desugar_checked(checked.program.as_ref().unwrap()).unwrap();
    assert!(benitoite::ir::check::check_program(&core).is_empty());
    let program = pipeline::compile(&core, Arc::clone(&checked.sources)).unwrap();
    for mode in [ExecMode::Direct, ExecMode::Request] {
        std::fs::write(&path, b"old bytes to replace").unwrap();
        let stdout = Arc::new(Mutex::new(Vec::new()));
        let env = environment(mode, Arc::clone(&stdout));
        let input = env.input.clone();
        let end = run::run_program(&program, env);
        assert_eq!(end.end, EndKind::Returned, "{mode:?}: {end:?}");
        assert_eq!(end.exit_code, 0, "{mode:?}: {end:?}");
        assert!(
            end.main_error.is_none() && end.reports.is_empty(),
            "{end:?}"
        );
        assert_eq!(std::fs::read(&path).unwrap(), [255, 0, 65, 66, 10]);
        std::fs::write(&path, b"old bytes to replace").unwrap();
        let (reference, out, err) = differential::run_reference(&core, input);
        assert!(
            matches!(
                differential::compare_results(
                    &program,
                    &checked.sources,
                    &end,
                    (&stdout.lock().unwrap(), &[]),
                    reference,
                    (&out, &err)
                ),
                differential::Comparison::Matched
            ),
            "{mode:?}"
        );
        assert_eq!(std::fs::read(&path).unwrap(), [255, 0, 65, 66, 10]);
        assert_eq!(std::fs::read(&decoy).unwrap(), b"untouched");
        assert!(!missing.exists());
    }
    std::fs::remove_dir_all(directory).unwrap();
}

// 関門: 標準ソースの辞書選択と全ての損失なし変換を、独立した値の期待で守る。
#[test]
fn log_scalar_conversions_use_explicit_instances_and_evaluate_inputs_once() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
record Custom
 value: Integer
end record
implement Log.ToLogValue[Custom]
 function toLogValue(value: Custom) -> Log.Value
   return Log.Value.Integer(Custom.value(value) + 1)
 end function
end implement
function input() -> Custom uses Console.Write
 Console.write("input;")
 return Custom(value: 8)
end function
function main() -> Result[Unit, String] uses Console.Write
 bind actual <- [
   Log.Attribute.value(Log.attribute(key: "x", value: "text")),
   Log.Attribute.value(Log.attribute(key: "x", value: false)),
   Log.Attribute.value(Log.attribute(key: "x", value: -9223372036854775808)),
   Log.Attribute.value(Log.attribute(key: "x", value: 18446744073709551615u64)),
   Log.Attribute.value(Log.attribute(key: "x", value: -0.0)),
   Log.Attribute.value(Log.attribute(key: "x", value: -128s8)),
   Log.Attribute.value(Log.attribute(key: "x", value: -32768s16)),
   Log.Attribute.value(Log.attribute(key: "x", value: -2147483648s32)),
   Log.Attribute.value(Log.attribute(key: "x", value: 255u8)),
   Log.Attribute.value(Log.attribute(key: "x", value: 65535u16)),
   Log.Attribute.value(Log.attribute(key: "x", value: 4294967295u32)),
   Log.Attribute.value(Log.attribute(key: "x", value: 1.5f32)),
   Log.Attribute.value(Log.attribute(key: "x", value: input()))]
 bind expected <- [Log.Value.Text("text"), Log.Value.Boolean(false), Log.Value.Integer(-9223372036854775808),
   Log.Value.UnsignedInteger(18446744073709551615u64), Log.Value.Float(-0.0),
   Log.Value.Integer(-128), Log.Value.Integer(-32768), Log.Value.Integer(-2147483648),
   Log.Value.Integer(255), Log.Value.Integer(65535), Log.Value.Integer(4294967295),
   Log.Value.Float(1.5), Log.Value.Integer(9)]
 return if actual = expected then Result.Ok(()) else Result.Error("wrong scalar conversion") end if
end function
"#;
    let program = compile(source);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let end = run::run_program(&program, environment(mode, Arc::clone(&output)));
        assert_eq!(end.end, EndKind::Returned, "{end:?}");
        assert_eq!(end.exit_code, 0);
        assert_eq!(*output.lock().unwrap(), b"input;");
        assert!(end.reports.is_empty(), "{end:?}");
    }
}

// 外部writerの完了をidleまで止め、バッファの待ちを偶然のスレッド順に依存させない。
#[derive(Debug)]
struct ReleaseOutputOnIdle {
    inner: Box<dyn WorkerExec>,
    release: mpsc::Sender<()>,
    observed: Arc<Mutex<bool>>,
}
impl WorkerExec for ReleaseOutputOnIdle {
    fn wakeup(&self) -> Option<Wakeup> {
        self.inner.wakeup()
    }
    fn submit(&mut self, job: WorkerJob) {
        self.inner.submit(job);
    }
    fn try_recv(&mut self) -> Option<Completion> {
        self.inner.try_recv()
    }
    fn idle(&mut self, deadline: Option<u64>) -> IdleWake {
        *self.observed.lock().unwrap() = true;
        let _sent = self.release.send(());
        self.inner.idle(deadline)
    }
}

// 関門: 大きい記録がバッファの待ちを通っても、同じstderrへ一回ずつ順番に届く。
// 大きさは既存の1 MiBの未転送量の境界を越すために必要であり、要素数や再帰は増やさない。
#[test]
fn log_large_records_share_console_buffer_and_final_flush() {
    let source = r#"
import Benitoite.Unofficial.IO.Console
function main() -> Unit uses Log, Console.Write
 bind text <- String.repeat(s: "x", n: 2097152)
 bind location <- SourceLocation.Location(file: "app", line: 1, column: 1)
 Console.writeError("before\n")
 Log.info(message: text, attributes: [], location: location)
 Log.info(message: text, attributes: [], location: location)
 Console.writeError("after\n")
end function
"#;
    let program = compile(source);
    let line = format!(
        "level=INFO source=\"app:1:1\" message=\"{}\"\n",
        "x".repeat(2_097_152)
    );
    let expected = format!("before\n{line}{line}after\n");
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let output = Arc::new(Mutex::new(Vec::new()));
        let error = Arc::new(Mutex::new(Vec::new()));
        let held = Arc::clone(&error);
        let (release, receive) = mpsc::channel();
        let (ready, initialized) = mpsc::channel();
        let gate = std::thread::spawn(move || {
            let guard = held.lock().unwrap();
            ready.send(()).unwrap();
            let timed_out = receive
                .recv_timeout(std::time::Duration::from_secs(30))
                .is_err();
            drop(guard);
            timed_out
        });
        initialized.recv().unwrap();
        let script = ScheduleHandle::new([], false);
        let mut parts = script.parts();
        let observed = Arc::new(Mutex::new(false));
        parts.workers = Box::new(ReleaseOutputOnIdle {
            inner: parts.workers,
            release: release.clone(),
            observed: Arc::clone(&observed),
        });
        let mut env = environment(mode, Arc::clone(&output));
        env.stderr = OutputTarget::Capture(Arc::clone(&error));
        env.parts = Some(parts);
        let end = run::run_program(&program, env);
        let _sent = release.send(());
        assert!(!gate.join().unwrap(), "output gate timed out");
        assert!(*observed.lock().unwrap(), "output did not wait");
        assert!(script.record().error.is_none(), "{:?}", script.record());
        assert_eq!(end.end, EndKind::Returned, "{end:?}");
        assert_eq!(end.exit_code, 0);
        assert!(output.lock().unwrap().is_empty());
        assert_eq!(*error.lock().unwrap(), expected.as_bytes());
        assert!(end.reports.is_empty(), "{end:?}");
    }
}

// 関門: 外部の出力先の失敗をLogもConsoleと同じR0202/終了1として返し、握りつぶさない。
#[test]
fn log_output_failure_uses_the_console_stop_and_exit_status() {
    for operation in [
        "Console.writeErrorLine(text)",
        "Log.info(message: text, attributes: [], location: SourceLocation.here())",
        "Log.withTextLogger(minimum: Log.Level.Debug, body: lambda() Log.debug(message: text, attributes: [], location: SourceLocation.here()) end lambda)",
    ] {
        let source = format!(
            "import Benitoite.Unofficial.IO.Console\nfunction main() -> Unit uses Log, Console.Write\n bind text <- String.repeat(s: \"x\", n: 2097152)\n {operation}\n {operation}\nend function\n"
        );
        let program = compile(&source);
        for mode in [ExecMode::Direct, ExecMode::Request] {
            let output = Arc::new(Mutex::new(Vec::new()));
            let error = Arc::new(Mutex::new(Vec::new()));
            // Captureは外部の出力先である。公開の出力先を失敗させ、本番のwriterを通す。
            let poisoned = Arc::clone(&error);
            let result = std::panic::catch_unwind(move || {
                let _guard = poisoned.lock().unwrap();
                panic!("poison the external output target");
            });
            assert!(result.is_err());
            let mut env = environment(mode, Arc::clone(&output));
            env.stderr = OutputTarget::Capture(error);
            let end = run::run_program(&program, env);
            assert_eq!(end.end, EndKind::Stopped, "{operation}: {end:?}");
            assert_eq!(end.exit_code, 1, "{operation}: {end:?}");
            assert_eq!(
                end.reports
                    .iter()
                    .filter_map(|d| d.code)
                    .collect::<Vec<_>>(),
                [benitoite::diag::DiagCode::R0202],
                "{operation}: {end:?}"
            );
            assert!(output.lock().unwrap().is_empty());
        }
    }
}

// 関門: 幅本体の単体検査では通らない標準宣言・名前付き引数・純粋性と
// VM/参照評価の値の橋渡しを、独立した期待内容と幅で確かめる。
#[test]
fn display_width_functions_preserve_content_and_pad_in_both_modes() {
    let cases = [
        (r#""""#, 0, 0),
        (r#""猫""#, 2, 2),
        (r#""·""#, 1, 2),
        (r#""=\u{338}""#, 1, 2),
        (r#""\u{301}""#, 0, 0),
        (r#""e\u{301}""#, 1, 1),
        (r#""👩‍👩‍👧‍👦""#, 2, 2),
        (r#""\u{1faea}""#, 2, 2),
        (r#""a\u{200d}""#, 1, 1),
        (r#""❤\u{fe0f}""#, 2, 2),
        (r#""لا""#, 1, 1),
        (r#""ل\u{0}ا""#, 2, 2),
        (r#""a\nb\tc\u{7f}\u{85}\u{2028}\u{2029}""#, 3, 3),
        (r#""\u{1b}[31m""#, 4, 4),
    ];
    let mut source = String::new();
    for suffix in ["", "CJK"] {
        source.push_str(&format!(r#"
function verify{suffix}(s: String, width: Integer, original: Integer, expected: Integer, spaces: String) -> Boolean
 bind start <- String.displayWidthPadStart{suffix}(s: s, width: width)
 bind finish <- String.displayWidthPadEnd{suffix}(s: s, width: width)
 return String.displayWidth{suffix}(s) = original and start = spaces + s and finish = s + spaces and String.displayWidth{suffix}(start) = expected and String.displayWidth{suffix}(finish) = expected
end function
"#));
    }
    source.push_str("function main() -> Result[Unit,String]\n");
    for (i, (text, default, cjk)) in cases.into_iter().enumerate() {
        for (suffix, measured) in [("", default), ("CJK", cjk)] {
            for target in [i64::MIN, -1, 0, measured, measured + 3] {
                let spaces = " "
                    .repeat(usize::try_from(target.saturating_sub(measured).max(0)).unwrap_or(0));
                source.push_str(&format!(
                    " if not verify{suffix}(s: {text}, width: {target}, original: {measured}, expected: {}, spaces: \"{spaces}\") then return Result.Error(\"display width case {i} {suffix} {target}\") end if\n",
                    measured.max(target)
                ));
            }
        }
    }
    // 論理上限内の動的な幅を使い、安全点の後で元の文字列と結果を読み直す。
    // gc-stress の構成では各安全点で回収する。
    source.push_str(r#"
 bind original <- String.repeat(s: "猫", n: 1000)
 bind padded <- String.displayWidthPadEnd(s: original, width: 4096)
 bind unused <- String.repeat(s: "x", n: 8192)
 return if String.byteLength(original) = 3000 and String.displayWidth(padded) = 4096 and String.byteLength(padded) = 5096 and String.endsWith(s: padded, suffix: "   ") and String.byteLength(unused) = 8192 then Result.Ok(()) else Result.Error("padding after GC") end if
end function
"#);
    for mode in [ExecMode::Direct, ExecMode::Request] {
        let checked = pipeline::check_text(
            "display-width.bnt",
            source.as_bytes(),
            CheckOptions {
                require_main: true,
                deny_warnings: false,
            },
        );
        assert_eq!(checked.error_count(), 0, "{:?}", checked.diagnostics);
        let result = differential::compare(
            checked.program.unwrap(),
            checked.sources,
            environment(mode, Arc::new(Mutex::new(Vec::new()))).input,
            VmConfig::default(),
            mode,
            differential::CompareOptions {
                require_returned: true,
                ..Default::default()
            },
            Box::new(|| Ok(())),
        );
        match result {
            differential::Comparison::Matched => {}
            differential::Comparison::Failed(reason)
            | differential::Comparison::Excluded(reason) => panic!("{mode:?}: {reason}"),
        }
    }
}

// 関門: 極端な動的 Integer を usize へ切り詰めず、UTF-8 バイト数も含む
// 論理上限で確保前に拒否する。幅算法だけのテストにはこの接続がない。
#[test]
fn display_width_padding_rejects_oversized_dynamic_targets() {
    for function in [
        "displayWidthPadStart",
        "displayWidthPadEnd",
        "displayWidthPadStartCJK",
        "displayWidthPadEndCJK",
    ] {
        for (text, target, size) in [
            (r#""""#, 1_073_741_825_i64, 1_073_741_825_u64),
            (r#""""#, 4_294_967_296, 4_294_967_296),
            (r#""""#, i64::MAX, u64::try_from(i64::MAX).unwrap()),
            (r#""\u{301}""#, 1_073_741_824, 1_073_741_826),
        ] {
            let source = format!(
                "function pad(s: String, width: Integer) -> String\n return String.{function}(s: s, width: width)\nend function\nfunction main() -> Unit\n bind result <- pad(s: {text}, width: {target})\nend function\n"
            );
            let program = compile(&source);
            for mode in [ExecMode::Direct, ExecMode::Request] {
                let end = run::run_program(
                    &program,
                    environment(mode, Arc::new(Mutex::new(Vec::new()))),
                );
                assert_eq!(
                    end.end,
                    EndKind::Stopped,
                    "{function} {target} {mode:?}: {end:?}"
                );
                assert_eq!(end.exit_code, 1);
                assert_eq!(end.reports.len(), 1);
                let report = end.reports.first().unwrap();
                assert_eq!(report.code, Some(benitoite::diag::codes::DiagCode::R0902));
                let report = format!("{report:?}");
                assert!(report.contains(&size.to_string()), "{report}");
                assert!(report.contains(&format!("String.{function}")), "{report}");
            }
        }
    }
}
