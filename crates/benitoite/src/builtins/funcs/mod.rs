//! 組み込みの関数の本体（設計書 02-08「組み込みの関数の呼び出し」、実装プラン 10-12）。

use crate::builtins::iface::BuiltinDecl;
use crate::builtins::table::tags;
use crate::runtime::Stop;
use crate::runtime::heap::{CtorTag, FieldsKind, Value, ValueCtx};

#[cfg(test)]
pub(crate) mod samples;

fn option<'e>(ctx: &ValueCtx<'e>, value: Option<Value<'e>>) -> Result<Value<'e>, Stop> {
    match value {
        Some(value) => ctx.alloc_fields(FieldsKind::Ctor, tags::OPTION_SOME, &[value]),
        None => Ok(Value::Tag(CtorTag(tags::OPTION_NONE))),
    }
}

fn count(n: usize) -> Result<u64, Stop> {
    u64::try_from(n).map_err(|_| Stop::Internal("length does not fit u64".into()))
}

fn integer_count(n: usize) -> Result<i64, Stop> {
    i64::try_from(n).map_err(|_| Stop::Internal("length does not fit Integer".into()))
}

fn ascii_whitespace(c: char) -> bool {
    matches!(c, ' ' | '\t' | '\n' | '\r')
}

fn decimal_integer(s: &str) -> bool {
    !s.is_empty() && !(s.len() > 1 && s.starts_with('0')) && s.bytes().all(|b| b.is_ascii_digit())
}

fn decimal_float(s: &str) -> bool {
    let s = s.strip_prefix('-').unwrap_or(s);
    let (mantissa, exponent) = match s.split_once(['e', 'E']) {
        Some((m, e)) => (m, Some(e)),
        None => (s, None),
    };
    if let Some(e) = exponent {
        let e = e.strip_prefix(['+', '-']).unwrap_or(e);
        if e.is_empty() || !e.bytes().all(|b| b.is_ascii_digit()) {
            return false;
        }
    }
    match mantissa.split_once('.') {
        Some((whole, fraction)) => {
            decimal_integer(whole)
                && !fraction.is_empty()
                && fraction.bytes().all(|b| b.is_ascii_digit())
        }
        None => decimal_integer(mantissa),
    }
}

pub mod assert;
pub mod bytes;
pub mod csv;
pub mod encoding;
pub mod hash;
pub mod http_client;
pub mod http_server;
pub mod http_util;
pub mod json;
pub mod network_error;
pub mod path;
pub mod random;
pub mod regex;
pub mod time;

pub mod boolean;
pub mod byte;
pub mod character;
pub mod clock;
pub mod console;
pub mod decimal;
pub mod file;
pub mod float;
pub mod integer;
pub mod io_error;
pub mod lazy;
pub mod list;
pub mod map;
pub mod operators;
pub mod process;
pub mod reference;
pub mod set;
pub mod stage1_io;
pub mod string;
pub mod task;
pub mod task_group;
pub mod traits;

/// 表の部分。末尾にだけ加える（実装プラン 10-12「部分と番号」）。
pub const PARTS: &[&[BuiltinDecl]] = &[
    operators::DECLS,
    integer::DECLS,
    float::DECLS,
    character::DECLS,
    string::DECLS,
    boolean::DECLS,
    byte::DECLS,
    decimal::DECLS,
    list::DECLS,
    map::DECLS,
    set::DECLS,
    io_error::DECLS,
    reference::DECLS,
    lazy::DECLS,
    task::DECLS,
    task_group::DECLS,
    traits::DECLS,
    console::DECLS,
    file::DECLS,
    process::DECLS,
    clock::DECLS,
    assert::DECLS,
    character::UNICODE_DECLS,
    string::UNICODE_DECLS,
    map::MORE_DECLS,
    set::MORE_DECLS,
    string::UTF8_DECLS,
    bytes::DECLS,
    network_error::DECLS,
    console::MORE_DECLS,
    process::ENVIRONMENT_DECLS,
    clock::MORE_DECLS,
    file::PATH_DECLS,
    file::RESOURCE_DECLS,
    process::RUN_DECLS,
    random::DECLS,
    path::DECLS,
    json::DECLS,
    regex::DECLS,
    csv::DECLS,
    time::DECLS,
    encoding::DECLS,
    hash::DECLS,
    http_server::DECLS,
    http_util::DECLS,
    http_client::DECLS,
];

#[cfg(test)]
mod tests {
    // VM と参照インタプリタが本体を共有するため、項目の意味は本体を直接呼んで確かめる
    // （設計書 07-03「差分テスト」、実装プラン R08「受け入れテスト」）。
    // テストの失敗は panic で表す（実装プラン 00-02「#[allow] を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::expect_used,
        clippy::panic,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]

    use super::*;
    use crate::builtins::iface::{CallCtx, IoReply, IoWait, Reply, WaitRequest};
    use crate::builtins::table::{call_builtin, complete_worker};
    use crate::runtime::heap::{Heap, HeapConfig};
    use crate::runtime::io::services::RunInput;
    use crate::runtime::{
        MAX_LIST_LEN, MAX_STRING_BYTES, ResourceError, RuntimeError, SizeUnit, Stream,
    };

    macro_rules! direct {
        ($ctx:expr, $function:path $(, $arg:expr)* $(,)?) => {{
            let call = CallCtx::new($ctx, None, None, None);
            $function(call.pure_ctx(), $($arg),*)
        }};
    }

    fn option_payload<'e>(value: Value<'e>, ctx: &ValueCtx<'e>) -> Option<Value<'e>> {
        if matches!(value, Value::Tag(CtorTag(tags::OPTION_NONE))) {
            return None;
        }
        assert_eq!(
            ctx.fields_header(value),
            Some((FieldsKind::Ctor, tags::OPTION_SOME))
        );
        assert_eq!(ctx.fields_len(value), Some(1));
        Some(ctx.field(value, 0).unwrap())
    }

    fn assert_value<'e>(actual: Value<'e>, ctx: &ValueCtx<'e>, expected: Value<'e>) {
        match (actual, expected) {
            (Value::Float(a), Value::Float(b)) => assert_eq!(a.to_bits(), b.to_bits()),
            _ => assert!(
                crate::runtime::equal::values_equal(ctx, actual, expected).unwrap(),
                "{actual:?} != {expected:?}"
            ),
        }
    }

    fn assert_option<'e>(actual: Value<'e>, ctx: &ValueCtx<'e>, expected: Option<Value<'e>>) {
        match (option_payload(actual, ctx), expected) {
            (Some(a), Some(b)) => assert_value(a, ctx, b),
            (None, None) => {}
            (a, b) => panic!("{a:?} != {b:?}"),
        }
    }

    fn int_list<'e>(ctx: &ValueCtx<'e>, items: &[i64]) -> Value<'e> {
        crate::runtime::list::from_values(
            ctx,
            &items.iter().copied().map(Value::Int).collect::<Vec<_>>(),
            "test",
        )
        .unwrap()
    }

    fn assert_int_list<'e>(value: Value<'e>, ctx: &ValueCtx<'e>, expected: &[i64]) {
        let items = crate::runtime::list::to_vec(ctx, value).unwrap();
        assert_eq!(items.len(), expected.len());
        for (item, expected) in items.into_iter().zip(expected) {
            assert_value(item, ctx, Value::Int(*expected));
        }
    }

    fn assert_strings<'e>(value: Value<'e>, ctx: &ValueCtx<'e>, expected: &[&str]) {
        let items = crate::runtime::list::to_vec(ctx, value).unwrap();
        assert_eq!(
            items
                .iter()
                .map(|item| ctx.str(*item).unwrap())
                .collect::<Vec<_>>(),
            expected
        );
    }

    fn input() -> RunInput {
        RunInput {
            arguments: vec!["one".into(), "あ".into(), "".into()],
            working_directory: std::env::current_dir().unwrap(),
            script_directory: std::env::current_dir().unwrap().join("scripts"),
        }
    }

    #[test]
    fn integer_operators_check_overflow_and_signed_division() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (function, a, b, result) in [
                (operators::integer_add as _, 40, 2, Ok(42)),
                (
                    operators::integer_add as _,
                    i64::MAX,
                    1,
                    Err(RuntimeError::IntegerOverflow),
                ),
                (operators::integer_subtract as _, 40, 2, Ok(38)),
                (
                    operators::integer_subtract as _,
                    i64::MIN,
                    1,
                    Err(RuntimeError::IntegerOverflow),
                ),
                (operators::integer_multiply as _, -7, 2, Ok(-14)),
                (
                    operators::integer_multiply as _,
                    i64::MAX,
                    2,
                    Err(RuntimeError::IntegerOverflow),
                ),
                (operators::integer_div as _, -7, 2, Ok(-3)),
                (operators::integer_div as _, 7, -2, Ok(-3)),
                (
                    operators::integer_div as _,
                    i64::MIN,
                    -1,
                    Err(RuntimeError::IntegerOverflow),
                ),
                (
                    operators::integer_div as _,
                    7,
                    0,
                    Err(RuntimeError::DivisionByZero),
                ),
                (operators::integer_mod as _, -7, 2, Ok(-1)),
                (operators::integer_mod as _, 7, -2, Ok(1)),
                (operators::integer_mod as _, i64::MIN, -1, Ok(0)),
                (
                    operators::integer_mod as _,
                    7,
                    0,
                    Err(RuntimeError::DivisionByZero),
                ),
            ] {
                let function: for<'c, 'e> fn(
                    crate::builtins::iface::PureCtx<'c, 'e>,
                    i64,
                    i64,
                ) -> Result<i64, Stop> = function;
                assert_eq!(direct!(ctx, function, a, b), result.map_err(Stop::Runtime));
            }
            assert_eq!(direct!(ctx, operators::integer_negate, 7), Ok(-7));
            assert_eq!(
                direct!(ctx, operators::integer_negate, i64::MIN),
                Err(Stop::Runtime(RuntimeError::IntegerOverflow))
            );
            for (a, b, less, le, greater, ge) in [
                (1, 2, true, true, false, false),
                (2, 2, false, true, false, true),
                (3, 2, false, false, true, true),
            ] {
                assert_eq!(direct!(ctx, operators::integer_less, a, b), Ok(less));
                assert_eq!(direct!(ctx, operators::integer_less_or_equal, a, b), Ok(le));
                assert_eq!(direct!(ctx, operators::integer_greater, a, b), Ok(greater));
                assert_eq!(
                    direct!(ctx, operators::integer_greater_or_equal, a, b),
                    Ok(ge)
                );
            }
        });
    }

    #[test]
    fn float_and_text_operators_follow_ieee_and_scalar_order() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            assert_eq!(direct!(ctx, operators::float_add, 1.5, 2.0).unwrap(), 3.5);
            assert_eq!(
                direct!(ctx, operators::float_subtract, 1.5, 2.0).unwrap(),
                -0.5
            );
            assert_eq!(
                direct!(ctx, operators::float_multiply, 1.5, 2.0).unwrap(),
                3.0
            );
            assert_eq!(
                direct!(ctx, operators::float_divide, 1.5, 2.0).unwrap(),
                0.75
            );
            assert_eq!(
                direct!(ctx, operators::float_divide, 1.0, 0.0).unwrap(),
                f64::INFINITY
            );
            assert!(
                direct!(ctx, operators::float_divide, 0.0, 0.0)
                    .unwrap()
                    .is_nan()
            );
            assert_eq!(
                direct!(ctx, operators::float_negate, 0.0)
                    .unwrap()
                    .to_bits(),
                (-0.0_f64).to_bits()
            );
            for (a, b, less, le, greater, ge) in [
                (1.0, 2.0, true, true, false, false),
                (0.0, -0.0, false, true, false, true),
                (f64::NAN, 1.0, false, false, false, false),
            ] {
                assert_eq!(direct!(ctx, operators::float_less, a, b).unwrap(), less);
                assert_eq!(
                    direct!(ctx, operators::float_less_or_equal, a, b).unwrap(),
                    le
                );
                assert_eq!(
                    direct!(ctx, operators::float_greater, a, b).unwrap(),
                    greater
                );
                assert_eq!(
                    direct!(ctx, operators::float_greater_or_equal, a, b).unwrap(),
                    ge
                );
            }
            let joined = direct!(ctx, operators::string_add, "あ", "b").unwrap();
            assert_eq!(ctx.str(joined), Some("あb"));
            for (a, b, less, le, greater, ge) in [
                ("a", "あ", true, true, false, false),
                ("", "", false, true, false, true),
                ("あ", "a", false, false, true, true),
            ] {
                assert_eq!(direct!(ctx, operators::string_less, a, b).unwrap(), less);
                assert_eq!(
                    direct!(ctx, operators::string_less_or_equal, a, b).unwrap(),
                    le
                );
                assert_eq!(
                    direct!(ctx, operators::string_greater, a, b).unwrap(),
                    greater
                );
                assert_eq!(
                    direct!(ctx, operators::string_greater_or_equal, a, b).unwrap(),
                    ge
                );
            }
            for (a, b, less, le, greater, ge) in [
                ('a', 'あ', true, true, false, false),
                ('あ', 'あ', false, true, false, true),
                ('あ', 'a', false, false, true, true),
            ] {
                assert_eq!(direct!(ctx, operators::character_less, a, b).unwrap(), less);
                assert_eq!(
                    direct!(ctx, operators::character_less_or_equal, a, b).unwrap(),
                    le
                );
                assert_eq!(
                    direct!(ctx, operators::character_greater, a, b).unwrap(),
                    greater
                );
                assert_eq!(
                    direct!(ctx, operators::character_greater_or_equal, a, b).unwrap(),
                    ge
                );
            }
            let a = int_list(ctx, &[1, 2]);
            let b = int_list(ctx, &[1, 2]);
            let c = int_list(ctx, &[2, 1]);
            assert!(direct!(ctx, operators::eq, a, b).unwrap());
            assert!(!direct!(ctx, operators::ne, a, b).unwrap());
            assert!(direct!(ctx, operators::ne, a, c).unwrap());
            assert!(
                !direct!(
                    ctx,
                    operators::eq,
                    Value::Float(f64::NAN),
                    Value::Float(f64::NAN)
                )
                .unwrap()
            );
            assert!(
                direct!(
                    ctx,
                    operators::ne,
                    Value::Float(f64::NAN),
                    Value::Float(f64::NAN)
                )
                .unwrap()
            );
        });
    }

    #[test]
    fn integer_conversions_and_helpers_cover_the_signed_range() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (n, text) in [
                (i64::MIN, "-9223372036854775808"),
                (i64::MAX, "9223372036854775807"),
                (0, "0"),
            ] {
                assert_eq!(
                    {
                        let value = direct!(ctx, integer::to_string, n).unwrap();
                        ctx.str(value)
                    },
                    Some(text)
                );
                assert_option(
                    direct!(ctx, integer::parse, text).unwrap(),
                    ctx,
                    Some(Value::Int(n)),
                );
            }
            for text in [
                "",
                "01",
                "-01",
                "+1",
                " 1",
                "1 ",
                "1_0",
                "1.0",
                "9223372036854775808",
                "-9223372036854775809",
            ] {
                assert_option(direct!(ctx, integer::parse, text).unwrap(), ctx, None);
            }
            assert_option(
                direct!(ctx, integer::parse, "-0").unwrap(),
                ctx,
                Some(Value::Int(0)),
            );
            for (n, expected) in [
                (1, 1.0),
                (i64::MAX, 9_223_372_036_854_775_808.0),
                (i64::MIN, -9_223_372_036_854_775_808.0),
            ] {
                assert_eq!(direct!(ctx, integer::to_float, n).unwrap(), expected);
            }
            for (a, b, q, r) in [
                (-7, 2, -4, 1),
                (7, -2, -4, -1),
                (-7, -2, 3, -1),
                (7, 2, 3, 1),
            ] {
                assert_eq!(direct!(ctx, integer::floor_divide, a, b), Ok(q));
                assert_eq!(direct!(ctx, integer::floor_modulo, a, b), Ok(r));
            }
            assert_eq!(
                direct!(ctx, integer::floor_divide, i64::MIN, -1),
                Err(Stop::Runtime(RuntimeError::IntegerOverflow))
            );
            assert_eq!(direct!(ctx, integer::floor_modulo, i64::MIN, -1), Ok(0));
            assert_eq!(
                direct!(ctx, integer::floor_divide, 1, 0),
                Err(Stop::Runtime(RuntimeError::DivisionByZero))
            );
            assert_eq!(
                direct!(ctx, integer::floor_modulo, 1, 0),
                Err(Stop::Runtime(RuntimeError::DivisionByZero))
            );
            assert_eq!(direct!(ctx, integer::absolute, -42), Ok(42));
            assert_eq!(
                direct!(ctx, integer::absolute, i64::MIN),
                Err(Stop::Runtime(RuntimeError::IntegerOverflow))
            );
            assert_eq!(
                direct!(ctx, integer::minimum, i64::MAX, i64::MIN),
                Ok(i64::MIN)
            );
            assert_eq!(
                direct!(ctx, integer::maximum, i64::MIN, i64::MAX),
                Ok(i64::MAX)
            );
        });
    }

    #[test]
    fn float_conversion_uses_the_shared_format_and_preserves_signed_zero() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (value, text) in [
                (1.0, "1.0"),
                (0.001, "0.001"),
                (123.45, "123.45"),
                (1e21, "1.0e+21"),
                (1e20, "100000000000000000000.0"),
                (1e-5, "0.00001"),
                (1e-6, "1.0e-6"),
                (1.5e-7, "1.5e-7"),
                (-0.0, "-0.0"),
                (0.0, "0.0"),
                (f64::MAX, "1.7976931348623157e+308"),
                (5e-324, "5.0e-324"),
                (f64::NAN, "NaN"),
                (f64::INFINITY, "Infinity"),
                (f64::NEG_INFINITY, "-Infinity"),
            ] {
                assert_eq!(crate::base::prim::float_to_text(value), text);
                assert_eq!(
                    {
                        let value = direct!(ctx, float::to_string, value).unwrap();
                        ctx.str(value)
                    },
                    Some(text)
                );
                let id = crate::builtins::table::interpolation_builtin(
                    crate::types::builtin::BuiltinTypeId::FLOAT,
                )
                .unwrap();
                let Reply::Done(actual) = call_builtin(
                    crate::builtins::builtin_decl(id).unwrap(),
                    ctx,
                    None,
                    None,
                    None,
                    &[Value::Float(value)],
                )
                .unwrap() else {
                    panic!("expected interpolation result");
                };
                assert_eq!(ctx.str(actual), Some(text));
                if value.is_finite() {
                    assert_option(
                        direct!(ctx, float::parse, text).unwrap(),
                        ctx,
                        Some(Value::Float(value)),
                    );
                }
            }
            for (text, expected) in [
                ("42", Some(42.0)),
                ("-1e-9999", Some(-0.0)),
                ("0E+05", Some(0.0)),
                ("NaN", None),
                ("Infinity", None),
                ("1e400", None),
                ("01.0", None),
                ("+1", None),
                (".5", None),
                ("1.", None),
                ("1e+", None),
                ("1e2e3", None),
                ("1_0", None),
                (" 1", None),
                ("", None),
            ] {
                assert_option(
                    direct!(ctx, float::parse, text).unwrap(),
                    ctx,
                    expected.map(Value::Float),
                );
            }
            for (value, expected) in [
                (2.9, Some(2)),
                (-2.9, Some(-2)),
                (-9_223_372_036_854_775_808.0, Some(i64::MIN)),
                (9_223_372_036_854_775_808.0, None),
                (f64::NAN, None),
                (f64::INFINITY, None),
                (f64::NEG_INFINITY, None),
            ] {
                assert_option(
                    direct!(ctx, float::truncate, value).unwrap(),
                    ctx,
                    expected.map(Value::Int),
                );
            }
            assert!(direct!(ctx, float::is_na_n, f64::NAN).unwrap());
            assert!(!direct!(ctx, float::is_na_n, f64::INFINITY).unwrap());
            assert_eq!(
                direct!(ctx, float::absolute, -0.0).unwrap().to_bits(),
                0.0_f64.to_bits()
            );
            assert_eq!(direct!(ctx, float::floor, -0.5).unwrap(), -1.0);
            assert_eq!(
                direct!(ctx, float::ceiling, -0.5).unwrap().to_bits(),
                (-0.0_f64).to_bits()
            );
            assert_eq!(direct!(ctx, float::round, 2.5).unwrap(), 3.0);
            assert_eq!(direct!(ctx, float::round, -2.5).unwrap(), -3.0);
            assert_eq!(direct!(ctx, float::square_root, 4.0).unwrap(), 2.0);
            assert!(direct!(ctx, float::square_root, -1.0).unwrap().is_nan());
        });
    }

    #[test]
    fn character_conversion_checks_scalar_ranges_and_ascii_classes() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            assert_eq!(direct!(ctx, character::to_integer, 'あ'), Ok(0x3042));
            assert_eq!(
                {
                    let value = direct!(ctx, character::to_string, 'あ').unwrap();
                    ctx.str(value)
                },
                Some("あ")
            );
            for (n, expected) in [
                (0, Some('\0')),
                (0xd7ff, Some('\u{d7ff}')),
                (0xd800, None),
                (0xdfff, None),
                (0xe000, Some('\u{e000}')),
                (0x10ffff, Some('\u{10ffff}')),
                (0x110000, None),
                (-1, None),
                (i64::MAX, None),
            ] {
                assert_option(
                    direct!(ctx, character::from_integer, n).unwrap(),
                    ctx,
                    expected.map(Value::Char),
                );
            }
            for (c, digit, space) in [
                ('0', true, false),
                ('9', true, false),
                ('a', false, false),
                ('９', false, false),
                (' ', false, true),
                ('\t', false, true),
                ('\n', false, true),
                ('\r', false, true),
                ('\u{b}', false, false),
                ('\u{c}', false, false),
                ('\u{a0}', false, false),
            ] {
                assert_eq!(direct!(ctx, character::is_a_s_c_i_i_digit, c), Ok(digit));
                assert_eq!(
                    direct!(ctx, character::is_a_s_c_i_i_whitespace, c),
                    Ok(space)
                );
            }
            for (value, text) in [(true, "true"), (false, "false")] {
                assert_eq!(
                    {
                        let value = direct!(ctx, boolean::to_string, value).unwrap();
                        ctx.str(value)
                    },
                    Some(text)
                );
            }
        });
    }

    #[test]
    fn string_positions_count_bytes_and_scalars_separately() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (s, bytes, chars) in [("", 0, 0), ("aあ🙂", 8, 3)] {
                assert_eq!(direct!(ctx, string::byte_length, s), Ok(bytes));
                assert_eq!(direct!(ctx, string::character_count, s), Ok(chars));
                assert_eq!(direct!(ctx, string::is_empty, s), Ok(s.is_empty()));
            }
            for (s, start, end, expected) in [
                ("aあ🙂", 1, 4, Some("あ")),
                ("aあ🙂", 2, 4, None),
                ("aあ🙂", 1, 5, None),
                ("a", -1, 0, None),
                ("a", 1, 0, None),
                ("a", 0, 2, None),
                ("", 0, 0, Some("")),
            ] {
                let actual = option_payload(
                    direct!(ctx, string::byte_slice, s, start, end).unwrap(),
                    ctx,
                );
                assert_eq!(actual.and_then(|value| ctx.str(value)), expected);
            }
            for (s, start, end, expected) in [
                ("aあ🙂", 1, 3, Some("あ🙂")),
                ("aあ🙂", 3, 3, Some("")),
                ("a", -1, 0, None),
                ("a", 1, 0, None),
                ("a", 0, 2, None),
                ("", 0, 0, Some("")),
            ] {
                let actual = option_payload(
                    direct!(ctx, string::character_slice, s, start, end).unwrap(),
                    ctx,
                );
                assert_eq!(actual.and_then(|value| ctx.str(value)), expected);
            }
            for (i, expected) in [
                (-1, None),
                (0, Some('a')),
                (1, Some('あ')),
                (2, Some('🙂')),
                (3, None),
                (i64::MAX, None),
            ] {
                assert_option(
                    direct!(ctx, string::character_at, "aあ🙂", i).unwrap(),
                    ctx,
                    expected.map(Value::Char),
                );
            }
            assert_option(
                direct!(ctx, string::character_at, "", 0).unwrap(),
                ctx,
                None,
            );
            for (s, sub, contains, starts, ends, index) in [
                ("aあb", "あ", true, false, false, Some(1)),
                ("aあb", "a", true, true, false, Some(0)),
                ("aあb", "b", true, false, true, Some(4)),
                ("aあb", "x", false, false, false, None),
                ("", "", true, true, true, Some(0)),
            ] {
                assert_eq!(direct!(ctx, string::contains, s, sub), Ok(contains));
                assert_eq!(direct!(ctx, string::starts_with, s, sub), Ok(starts));
                assert_eq!(direct!(ctx, string::ends_with, s, sub), Ok(ends));
                assert_option(
                    direct!(ctx, string::byte_index_of, s, sub).unwrap(),
                    ctx,
                    index.map(Value::Int),
                );
            }
        });
    }

    #[test]
    fn string_transforms_keep_empty_fields_and_documented_line_rules() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (s, sep, expected) in [
                ("a,,b,", ",", vec!["a", "", "b", ""]),
                ("", ",", vec![""]),
                ("あ🙂", "", vec!["あ", "🙂"]),
                ("", "", vec![]),
                ("aaa", "aa", vec!["", "a"]),
            ] {
                assert_strings(direct!(ctx, string::split, s, sep).unwrap(), ctx, &expected);
            }
            for (s, expected) in [
                ("a\r\nb\n", vec!["a", "b"]),
                ("a\n\nb", vec!["a", "", "b"]),
                ("", vec![]),
                ("\n", vec![""]),
                ("\r", vec![""]),
                ("a\r\r\n", vec!["a\r"]),
            ] {
                assert_strings(direct!(ctx, string::lines, s).unwrap(), ctx, &expected);
            }
            let texts = [
                ctx.alloc_str("a", "test").unwrap(),
                ctx.alloc_str("", "test").unwrap(),
                ctx.alloc_str("あ", "test").unwrap(),
            ];
            let xs = crate::runtime::list::from_values(ctx, &texts, "test").unwrap();
            assert_eq!(
                {
                    let value = direct!(ctx, string::join, xs, "🙂").unwrap();
                    ctx.str(value)
                },
                Some("a🙂🙂あ")
            );
            assert_eq!(
                {
                    let value = direct!(ctx, string::join, Value::EmptyList, ",").unwrap();
                    ctx.str(value)
                },
                Some("")
            );
            for (s, expected) in [
                (" \t\r\na \t", "a"),
                ("\u{a0}a\u{a0}", "\u{a0}a\u{a0}"),
                ("", ""),
            ] {
                assert_eq!(
                    {
                        let value = direct!(ctx, string::trim, s).unwrap();
                        ctx.str(value)
                    },
                    Some(expected)
                );
            }
            for (s, old, new, expected) in [
                ("aaa", "aa", "b", "ba"),
                ("aあa", "a", "🙂", "🙂あ🙂"),
                ("a", "", "b", "a"),
                ("a", "a", "", ""),
                ("", "a", "b", ""),
            ] {
                assert_eq!(
                    {
                        let value = direct!(ctx, string::replace, s, old, new).unwrap();
                        ctx.str(value)
                    },
                    Some(expected)
                );
            }
            for (s, n, expected) in [
                ("あ", 2, "ああ"),
                ("a", 0, ""),
                ("a", -1, ""),
                ("", i64::MAX, ""),
            ] {
                assert_eq!(
                    {
                        let value = direct!(ctx, string::repeat, s, n).unwrap();
                        ctx.str(value)
                    },
                    Some(expected)
                );
            }
            let chars = direct!(ctx, string::characters, "aあ🙂").unwrap();
            let items = crate::runtime::list::to_vec(ctx, chars).unwrap();
            assert_eq!(items.len(), 3);
            for (item, c) in items.into_iter().zip(['a', 'あ', '🙂']) {
                assert_value(item, ctx, Value::Char(c));
            }
            assert_eq!(
                {
                    let value = direct!(ctx, string::from_characters, chars).unwrap();
                    ctx.str(value)
                },
                Some("aあ🙂")
            );
            assert_eq!(
                {
                    let value = direct!(ctx, string::characters, "").unwrap();
                    crate::runtime::list::len(ctx, value)
                }
                .unwrap(),
                0
            );
            assert_eq!(
                {
                    let value = direct!(ctx, string::from_characters, Value::EmptyList).unwrap();
                    ctx.str(value)
                },
                Some("")
            );
        });
    }

    #[test]
    fn list_bodies_observe_sequence_and_pattern_bounds() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let xs = int_list(ctx, &[3, 1, 2]);
            assert_eq!(direct!(ctx, list::length, xs), Ok(3));
            assert_eq!(direct!(ctx, list::pattern_length, xs), Ok(3));
            assert_eq!(direct!(ctx, list::is_empty, xs), Ok(false));
            assert_eq!(direct!(ctx, list::is_empty, Value::EmptyList), Ok(true));
            assert_option(
                direct!(ctx, list::head, xs).unwrap(),
                ctx,
                Some(Value::Int(3)),
            );
            assert_option(
                direct!(ctx, list::head, Value::EmptyList).unwrap(),
                ctx,
                None,
            );
            assert_int_list(
                option_payload(direct!(ctx, list::tail, xs).unwrap(), ctx).unwrap(),
                ctx,
                &[1, 2],
            );
            assert_option(
                direct!(ctx, list::tail, Value::EmptyList).unwrap(),
                ctx,
                None,
            );
            for (i, expected) in [
                (0, Some(3)),
                (2, Some(2)),
                (3, None),
                (-1, None),
                (i64::MAX, None),
            ] {
                assert_option(
                    direct!(ctx, list::get, xs, i).unwrap(),
                    ctx,
                    expected.map(Value::Int),
                );
            }
            assert_int_list(
                direct!(ctx, list::prepend, xs, Value::Int(0)).unwrap(),
                ctx,
                &[0, 3, 1, 2],
            );
            assert_int_list(
                direct!(ctx, list::append, xs, Value::Int(0)).unwrap(),
                ctx,
                &[3, 1, 2, 0],
            );
            let ys = int_list(ctx, &[4, 5]);
            assert_int_list(
                direct!(ctx, list::concatenate, xs, ys).unwrap(),
                ctx,
                &[3, 1, 2, 4, 5],
            );
            assert_int_list(direct!(ctx, list::reverse, xs).unwrap(), ctx, &[2, 1, 3]);
            for (n, take, drop) in [
                (-1, vec![], vec![3, 1, 2]),
                (0, vec![], vec![3, 1, 2]),
                (2, vec![3, 1], vec![2]),
                (i64::MAX, vec![3, 1, 2], vec![]),
            ] {
                assert_int_list(direct!(ctx, list::take, xs, n).unwrap(), ctx, &take);
                assert_int_list(direct!(ctx, list::drop, xs, n).unwrap(), ctx, &drop);
            }
            for (start, end, expected) in
                [(-2, 2, vec![-2, -1, 0, 1]), (2, 2, vec![]), (3, 2, vec![])]
            {
                assert_int_list(
                    direct!(ctx, list::range, start, end).unwrap(),
                    ctx,
                    &expected,
                );
            }
            assert_eq!(direct!(ctx, list::contains, xs, Value::Int(1)), Ok(true));
            assert_eq!(direct!(ctx, list::contains, xs, Value::Int(4)), Ok(false));
            assert_eq!(
                direct!(ctx, list::contains, Value::EmptyList, Value::Int(4)),
                Ok(false)
            );
            assert_int_list(direct!(ctx, list::sort, xs).unwrap(), ctx, &[1, 2, 3]);
            assert_int_list(
                direct!(ctx, list::sort, Value::EmptyList).unwrap(),
                ctx,
                &[],
            );
            assert_value(
                direct!(ctx, list::get_front, xs, 1).unwrap(),
                ctx,
                Value::Int(1),
            );
            assert_value(
                direct!(ctx, list::get_back, xs, 0).unwrap(),
                ctx,
                Value::Int(2),
            );
            assert_int_list(direct!(ctx, list::slice, xs, 1, 1).unwrap(), ctx, &[1]);
            assert_int_list(direct!(ctx, list::slice, xs, 1, 2).unwrap(), ctx, &[]);
            for i in [-1, 3, i64::MAX] {
                assert!(matches!(
                    direct!(ctx, list::get_front, xs, i),
                    Err(Stop::Internal(_))
                ));
                assert!(matches!(
                    direct!(ctx, list::get_back, xs, i),
                    Err(Stop::Internal(_))
                ));
            }
            for (front, back) in [(-1, 0), (0, -1), (2, 2), (i64::MAX, 0)] {
                assert!(matches!(
                    direct!(ctx, list::slice, xs, front, back),
                    Err(Stop::Internal(_))
                ));
            }
            assert_int_list(xs, ctx, &[3, 1, 2]);
        });
    }

    #[test]
    fn list_sort_is_stable_for_nan_and_signed_zero_and_supports_text() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            let nan1 = f64::from_bits(0x7ff8_0000_0000_0001);
            let nan2 = f64::from_bits(0x7ff8_0000_0000_0002);
            let values = [
                nan1,
                0.0,
                f64::INFINITY,
                -0.0,
                -1.0,
                nan2,
                f64::NEG_INFINITY,
            ]
            .map(Value::Float);
            let xs = crate::runtime::list::from_values(ctx, &values, "test").unwrap();
            let actual = {
                let value = direct!(ctx, list::sort, xs).unwrap();
                crate::runtime::list::to_vec(ctx, value)
            }
            .unwrap();
            for (actual, expected) in actual.into_iter().zip([
                f64::NEG_INFINITY,
                -1.0,
                0.0,
                -0.0,
                f64::INFINITY,
                nan1,
                nan2,
            ]) {
                assert_value(actual, ctx, Value::Float(expected));
            }
            let chars = crate::runtime::list::from_values(
                ctx,
                &[Value::Char('あ'), Value::Char('a')],
                "test",
            )
            .unwrap();
            let sorted = {
                let value = direct!(ctx, list::sort, chars).unwrap();
                crate::runtime::list::to_vec(ctx, value)
            }
            .unwrap();
            assert_value(sorted[0], ctx, Value::Char('a'));
            assert_value(sorted[1], ctx, Value::Char('あ'));
            let texts = [
                ctx.alloc_str("あ", "test").unwrap(),
                ctx.alloc_str("", "test").unwrap(),
                ctx.alloc_str("a", "test").unwrap(),
            ];
            let xs = crate::runtime::list::from_values(ctx, &texts, "test").unwrap();
            assert_strings(direct!(ctx, list::sort, xs).unwrap(), ctx, &["", "a", "あ"]);
        });
    }

    #[test]
    fn growing_values_are_rejected_before_heap_allocation() {
        let mut heap = Heap::new(HeapConfig::default());
        let before = heap.stats().allocations;
        heap.epoch(|ctx| {
            for (s, n, size) in [
                (
                    "ab",
                    i64::try_from(MAX_STRING_BYTES / 2 + 1).unwrap(),
                    MAX_STRING_BYTES + 2,
                ),
                ("abc", i64::MAX, u64::MAX),
            ] {
                assert_eq!(
                    direct!(ctx, string::repeat, s, n).unwrap_err(),
                    Stop::Resource(ResourceError::ValueTooLarge {
                        function: "String.repeat",
                        size,
                        unit: SizeUnit::Bytes,
                        limit: MAX_STRING_BYTES
                    })
                );
            }
            for (start, end, size) in [
                (
                    0,
                    i64::try_from(MAX_LIST_LEN + 1).unwrap(),
                    MAX_LIST_LEN + 1,
                ),
                (i64::MIN, i64::MAX, u64::MAX),
            ] {
                assert_eq!(
                    direct!(ctx, list::range, start, end).unwrap_err(),
                    Stop::Resource(ResourceError::ValueTooLarge {
                        function: "List.range",
                        size,
                        unit: SizeUnit::Elements,
                        limit: MAX_LIST_LEN
                    })
                );
            }
        });
        assert_eq!(heap.stats().allocations, before);
    }

    #[test]
    fn show_quotes_and_escapes_literals_and_ioerror_returns_its_message() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (s, expected) in [
                ("", "\"\""),
                ("a\"b\\\n\t\r$", "\"a\\\"b\\\\\\n\\t\\r\\$\""),
                (
                    "あ\u{0}\u{7f}\u{202e}\u{feff}",
                    "\"あ\\u{0}\\u{7f}\\u{202e}\\u{feff}\"",
                ),
            ] {
                assert_eq!(
                    {
                        let value = direct!(ctx, traits::show_string, s).unwrap();
                        ctx.str(value)
                    },
                    Some(expected)
                );
            }
            for (c, expected) in [
                ('x', "'x'"),
                ('\'', "'\\\''"),
                ('"', "'\"'"),
                ('\n', "'\\n'"),
                ('\0', "'\\u{0}'"),
                ('あ', "'あ'"),
            ] {
                assert_eq!(
                    {
                        let value = direct!(ctx, traits::show_character, c).unwrap();
                        ctx.str(value)
                    },
                    Some(expected)
                );
            }
            let message = ctx.alloc_str("reason", "test").unwrap();
            let error = ctx
                .alloc_fields(FieldsKind::IoError, tags::IO_ERROR_KIND_OTHER, &[message])
                .unwrap();
            assert_eq!(
                {
                    let value = direct!(ctx, io_error::message, error).unwrap();
                    ctx.str(value)
                },
                Some("reason")
            );
            assert!(matches!(
                direct!(ctx, io_error::message, Value::Unit),
                Err(Stop::Internal(_))
            ));
        });
    }

    #[test]
    fn pure_wrappers_from_each_implemented_part_match_the_bodies() {
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            // 包みの引数の読み出しと IntoValue の適用を、部分ごとに一つの項目で確かめる
            // （実装プラン R08「包み」）。意味の期待値は項目の本体のテストが持つ。
            macro_rules! wrapped {
                ($function:path, $decl:expr, [$($rust:expr),*], [$($value:expr),*]) => {{
                    let direct = direct!(ctx, $function $(, $rust)*).unwrap();
                    let Reply::Done(value) = call_builtin(&$decl, ctx, None, None, None, &[$($value),*]).unwrap() else { panic!("expected pure result"); };
                    assert_value(value, ctx, crate::builtins::iface::IntoValue::into_value(direct));
                }};
            }
            let text = ctx.alloc_str("あ", "test").unwrap();
            let xs = int_list(ctx, &[1, 2]);
            let reason = ctx.alloc_str("failure", "test").unwrap();
            let error = ctx.alloc_fields(FieldsKind::IoError, tags::IO_ERROR_KIND_OTHER, &[reason]).unwrap();
            wrapped!(operators::integer_add, operators::integer_add::DECL, [40, 2], [Value::Int(40), Value::Int(2)]);
            wrapped!(integer::to_string, integer::to_string::DECL, [42], [Value::Int(42)]);
            wrapped!(float::floor, float::floor::DECL, [1.5], [Value::Float(1.5)]);
            wrapped!(character::to_string, character::to_string::DECL, ['あ'], [Value::Char('あ')]);
            wrapped!(string::repeat, string::repeat::DECL, ["あ", 2], [text, Value::Int(2)]);
            wrapped!(boolean::to_string, boolean::to_string::DECL, [true], [Value::Bool(true)]);
            wrapped!(list::reverse, list::reverse::DECL, [xs], [xs]);
            wrapped!(io_error::message, io_error::message::DECL, [error], [error]);
            wrapped!(traits::show_string, traits::show_string::DECL, ["あ"], [text]);
        });
    }

    #[test]
    fn console_bodies_and_wrappers_record_streams_and_call_order() {
        let mut heap = Heap::new(HeapConfig::default());
        let mut io = stage1_io::TestIo::new(input());
        heap.epoch(|ctx| {
            type ConsoleBody = for<'c, 'e> fn(
                crate::builtins::iface::IoCtx<'c, 'e>,
                &'c str,
            ) -> Result<IoReply<'e>, Stop>;
            let cases: [(ConsoleBody, BuiltinDecl, Stream, &[u8]); 4] = [
                (
                    console::write,
                    console::write::DECL,
                    Stream::Stdout,
                    "あ".as_bytes(),
                ),
                (
                    console::write_error_line,
                    console::write_error_line::DECL,
                    Stream::Stderr,
                    "あ\n".as_bytes(),
                ),
                (
                    console::write_line,
                    console::write_line::DECL,
                    Stream::Stdout,
                    "あ\n".as_bytes(),
                ),
                (
                    console::write_error,
                    console::write_error::DECL,
                    Stream::Stderr,
                    "あ".as_bytes(),
                ),
            ];
            let text = ctx.alloc_str("あ", "test").unwrap();
            let mut expected = Vec::new();
            for (body, decl, stream, bytes) in cases {
                let mut call = CallCtx::new(ctx, Some(&mut io), None, None);
                assert!(matches!(
                    body(call.io_ctx().unwrap(), "あ").unwrap(),
                    IoReply::Done(Value::Unit)
                ));
                assert!(matches!(
                    call_builtin(&decl, ctx, Some(&mut io), None, None, &[text]).unwrap(),
                    Reply::Done(Value::Unit)
                ));
                expected.push((stream, bytes.to_vec()));
                expected.push((stream, bytes.to_vec()));
            }
            assert_eq!(io.take_output(), expected);
        });
    }

    #[test]
    fn process_arguments_body_and_wrapper_return_the_supplied_list() {
        let mut heap = Heap::new(HeapConfig::default());
        let mut io = stage1_io::TestIo::new(input());
        heap.epoch(|ctx| {
            let mut call = CallCtx::new(ctx, Some(&mut io), None, None);
            let IoReply::Done(direct) = process::arguments(call.io_ctx().unwrap()).unwrap() else {
                panic!("expected arguments");
            };
            assert_strings(direct, ctx, &["one", "あ", ""]);
            let Reply::Done(wrapped) = call_builtin(
                &process::arguments::DECL,
                ctx,
                Some(&mut io),
                None,
                None,
                &[],
            )
            .unwrap() else {
                panic!("expected arguments wrapper");
            };
            assert_value(direct, ctx, wrapped);
        });
    }

    #[test]
    fn file_read_text_uses_working_directory_and_reports_io_failures() {
        let directory = std::env::current_dir()
            .unwrap()
            .join("target")
            .join(format!("r08-read-text-{}", std::process::id()));
        std::fs::create_dir_all(&directory).unwrap();
        std::fs::write(directory.join("valid"), "\u{feff}hello あ\n").unwrap();
        std::fs::write(directory.join("invalid"), [0xff]).unwrap();
        let mut input = input();
        input.working_directory = directory.clone();
        let mut io = stage1_io::TestIo::new(input);
        let mut heap = Heap::new(HeapConfig::default());
        heap.epoch(|ctx| {
            for (path, error_tag) in [
                ("valid", None),
                ("missing", Some(tags::IO_ERROR_KIND_NOT_FOUND)),
                ("invalid", Some(tags::IO_ERROR_KIND_INVALID_UTF8)),
            ] {
                let arg = ctx.alloc_str(path, "test").unwrap();
                for direct in [true, false] {
                    let wait = if direct {
                        let mut call = CallCtx::new(ctx, Some(&mut io), None, None);
                        let IoReply::Wait(IoWait::Worker(wait)) =
                            file::read_text(call.io_ctx().unwrap(), path).unwrap()
                        else {
                            panic!("expected worker");
                        };
                        wait
                    } else {
                        let Reply::Wait(WaitRequest::Io(IoWait::Worker(wait))) = call_builtin(
                            &file::read_text::DECL,
                            ctx,
                            Some(&mut io),
                            None,
                            None,
                            &[arg],
                        )
                        .unwrap() else {
                            panic!("expected wrapper worker");
                        };
                        wait
                    };
                    let result = complete_worker(wait, ctx, &mut io, None, &[arg]).unwrap();
                    assert_eq!(ctx.fields_len(result), Some(1));
                    let payload = ctx.field(result, 0).unwrap();
                    if let Some(tag) = error_tag {
                        assert_eq!(
                            ctx.fields_header(result),
                            Some((FieldsKind::Ctor, tags::RESULT_ERROR))
                        );
                        assert_eq!(ctx.fields_header(payload), Some((FieldsKind::IoError, tag)));
                        let reason = direct!(ctx, io_error::message, payload).unwrap();
                        assert!(!ctx.str(reason).unwrap().is_empty());
                    } else {
                        assert_eq!(
                            ctx.fields_header(result),
                            Some((FieldsKind::Ctor, tags::RESULT_OK))
                        );
                        assert_eq!(ctx.str(payload), Some("\u{feff}hello あ\n"));
                    }
                }
            }
        });
        std::fs::remove_dir_all(directory).unwrap();
    }
}

#[cfg(test)]
mod runtime_test_support;
