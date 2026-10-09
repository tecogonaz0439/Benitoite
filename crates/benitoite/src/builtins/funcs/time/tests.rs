//! 時刻の計算と書式の契約（設計書 03-08「Time」、実装プラン L24）。
// テストの失敗は panic で表す（実装プラン 00-02）。
#![allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]

// 関門: 組み込みの公開の呼び出しが返す値と停止を、独立した期待値で確かめる。
// 中間積だけの溢れ、負の数の切り捨て、暦の範囲、jiff と異なる書式の退行を捕まえる。
// 未実装の Time に既存の意味のテストはなく、同じ契約は表の行にまとめる。
// 本番の差し込み口や非公開の補助関数のテストは加えない（ADR 0276）。
use super::*;
use crate::builtins::funcs::operators::tests::direct;
use crate::runtime::heap::{Heap, HeapConfig};

fn record<'e>(ctx: &ValueCtx<'e>, fields: &[i64]) -> Value<'e> {
    let fields: Vec<_> = fields.iter().copied().map(Value::Int).collect();
    ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &fields)
        .unwrap()
}

fn payload<'e>(ctx: &ValueCtx<'e>, result: Value<'e>, tag: u32) -> Value<'e> {
    assert_eq!(ctx.fields_header(result), Some((FieldsKind::Ctor, tag)));
    let value = ctx.field(result, 0).unwrap();
    if tag == tags::RESULT_ERROR {
        assert!(!ctx.str(value).unwrap().is_empty());
    }
    value
}

fn nanos<'e>(ctx: &ValueCtx<'e>, value: Value<'e>) -> i64 {
    assert_eq!(
        ctx.fields_header(value),
        Some((FieldsKind::Ctor, tags::RECORD))
    );
    ctx.field(value, 0).unwrap().as_int().unwrap()
}

#[test]
fn unix_conversions_floor_negative_values_and_check_the_instant_range() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (units, seconds, milliseconds) in [
            (0, 0, 0),
            (1, 1_000_000_000, 1_000_000),
            (-1, -1_000_000_000, -1_000_000),
        ] {
            assert_eq!(
                {
                    let value = direct!(ctx, from_unix_seconds, Value::Int(units)).unwrap();
                    nanos(ctx, value)
                },
                seconds
            );
            assert_eq!(
                {
                    let value = direct!(ctx, from_unix_milliseconds, Value::Int(units)).unwrap();
                    nanos(ctx, value)
                },
                milliseconds
            );
        }
        for (n, seconds, milliseconds) in [
            (0, 0, 0),
            (1, 0, 0),
            (-1, -1, -1),
            (1_999_999_999, 1, 1999),
            (-1_000_000_001, -2, -1001),
            (i64::MIN, -9_223_372_037, -9_223_372_036_855),
            (i64::MAX, 9_223_372_036, 9_223_372_036_854),
        ] {
            let t = record(ctx, &[n]);
            assert_eq!(
                direct!(ctx, to_unix_seconds, t).unwrap().as_int(),
                Some(seconds)
            );
            assert_eq!(
                direct!(ctx, to_unix_milliseconds, t).unwrap().as_int(),
                Some(milliseconds)
            );
        }
        for n in [-9_223_372_036, 9_223_372_036] {
            assert_eq!(
                {
                    let value = direct!(ctx, from_unix_seconds, Value::Int(n)).unwrap();
                    nanos(ctx, value)
                },
                n * 1_000_000_000
            );
        }
        for n in [-9_223_372_036_854, 9_223_372_036_854] {
            assert_eq!(
                {
                    let value = direct!(ctx, from_unix_milliseconds, Value::Int(n)).unwrap();
                    nanos(ctx, value)
                },
                n * 1_000_000
            );
        }
        for n in [i64::MIN, -9_223_372_037, 9_223_372_037, i64::MAX] {
            assert_eq!(
                direct!(ctx, from_unix_seconds, Value::Int(n)).unwrap_err(),
                Stop::Runtime(RuntimeError::IntegerOverflow)
            );
        }
        for n in [i64::MIN, -9_223_372_036_855, 9_223_372_036_855, i64::MAX] {
            assert_eq!(
                direct!(ctx, from_unix_milliseconds, Value::Int(n)).unwrap_err(),
                Stop::Runtime(RuntimeError::IntegerOverflow)
            );
        }
    });
}

#[test]
fn arithmetic_checks_final_sum_and_floors_wide_differences() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (start, millis, expected) in [
            (0, -1, -1_000_000),
            (-1, 1, 999_999),
            (1, -1, -999_999),
            (i64::MIN, 0, i64::MIN),
            (i64::MAX, 0, i64::MAX),
            (i64::MIN, 9_223_372_036_855, 224_192),
            (i64::MAX, -9_223_372_036_855, -224_193),
        ] {
            let t = record(ctx, &[start]);
            assert_eq!(
                {
                    let value = direct!(ctx, add_milliseconds, t, Value::Int(millis)).unwrap();
                    nanos(ctx, value)
                },
                expected
            );
        }
        for (start, millis) in [(i64::MIN, -1), (i64::MAX, 1), (0, i64::MIN), (0, i64::MAX)] {
            let t = record(ctx, &[start]);
            assert_eq!(
                direct!(ctx, add_milliseconds, t, Value::Int(millis)).unwrap_err(),
                Stop::Runtime(RuntimeError::IntegerOverflow)
            );
        }
        for (a, b, expected) in [
            (0, 0, 0),
            (-1, 0, -1),
            (0, -1, 0),
            (1_000_001, 0, 1),
            (i64::MAX, i64::MIN, 18_446_744_073_709),
            (i64::MIN, i64::MAX, -18_446_744_073_710),
        ] {
            let a = record(ctx, &[a]);
            let b = record(ctx, &[b]);
            assert_eq!(
                direct!(ctx, difference_milliseconds, a, b)
                    .unwrap()
                    .as_int(),
                Some(expected)
            );
        }
    });
}

#[test]
fn calendar_round_trips_offsets_fraction_and_range_endpoints() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (n, offset, expected) in [
            (0, 0, [1970, 1, 1, 0, 0, 0, 0, 0]),
            (0, 540, [1970, 1, 1, 9, 0, 0, 0, 540]),
            (-1, -300, [1969, 12, 31, 18, 59, 59, 999_999_999, -300]),
            (789_000_000, 540, [1970, 1, 1, 9, 0, 0, 789_000_000, 540]),
            (0, -1439, [1969, 12, 31, 0, 1, 0, 0, -1439]),
            (0, 1439, [1970, 1, 1, 23, 59, 0, 0, 1439]),
            (i64::MIN, 0, [1677, 9, 21, 0, 12, 43, 145_224_192, 0]),
            (i64::MAX, 0, [2262, 4, 11, 23, 47, 16, 854_775_807, 0]),
        ] {
            let t = record(ctx, &[n]);
            let dt = direct!(ctx, to_date_time, t, Value::Int(offset)).unwrap();
            assert_eq!(ctx.fields_len(dt), Some(8));
            for (i, expected) in expected.into_iter().enumerate() {
                assert_eq!(
                    ctx.field(dt, u32::try_from(i).unwrap()).unwrap().as_int(),
                    Some(expected)
                );
            }
            let result = direct!(ctx, from_date_time, dt).unwrap();
            assert_eq!(nanos(ctx, payload(ctx, result, tags::RESULT_OK)), n);
        }
        for n in [i64::MIN, i64::MAX] {
            for offset in [-1439, -300, 540, 1439] {
                let t = record(ctx, &[n]);
                let dt = direct!(ctx, to_date_time, t, Value::Int(offset)).unwrap();
                let result = direct!(ctx, from_date_time, dt).unwrap();
                assert_eq!(nanos(ctx, payload(ctx, result, tags::RESULT_OK)), n);
            }
        }
        let leap_day = record(ctx, &[2000, 2, 29, 12, 0, 0, 1, 0]);
        let result = direct!(ctx, from_date_time, leap_day).unwrap();
        assert_eq!(
            nanos(ctx, payload(ctx, result, tags::RESULT_OK)),
            951_825_600_000_000_001
        );
    });
}

#[test]
fn invalid_calendar_fields_are_result_errors_but_offset_is_a_runtime_error() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (index, bad) in [
            (0, 2263),
            (0, 9999),
            (0, -10_000),
            (0, i64::MAX),
            (1, 0),
            (1, 13),
            (1, i64::MIN),
            (2, 0),
            (2, 30),
            (3, -1),
            (3, 24),
            (4, -1),
            (4, 60),
            (5, -1),
            (5, 60),
            (6, -1),
            (6, 1_000_000_000),
            (6, i64::MAX),
        ] {
            let mut fields = [2026, 2, 28, 12, 34, 56, 0, 0];
            fields[index] = bad;
            let dt = record(ctx, &fields);
            let result = direct!(ctx, from_date_time, dt).unwrap();
            payload(ctx, result, tags::RESULT_ERROR);
        }
        for fields in [
            [2026, 2, 29, 0, 0, 0, 0, 0],
            [1900, 2, 29, 0, 0, 0, 0, 0],
            [1677, 9, 21, 0, 12, 43, 145_224_191, 0],
            [2262, 4, 11, 23, 47, 16, 854_775_808, 0],
        ] {
            let dt = record(ctx, &fields);
            let result = direct!(ctx, from_date_time, dt).unwrap();
            payload(ctx, result, tags::RESULT_ERROR);
        }
        let t = record(ctx, &[0]);
        let pattern = ctx.alloc_str("%Y", "test").unwrap();
        for offset in [-1440, 1440, i64::MIN, i64::MAX] {
            for (function, result) in [
                (
                    "Time.toDateTime",
                    direct!(ctx, to_date_time, t, Value::Int(offset)),
                ),
                (
                    "Time.formatISO8601",
                    direct!(ctx, format_i_s_o8601, t, Value::Int(offset)),
                ),
                (
                    "Time.format",
                    direct!(ctx, format, t, Value::Int(offset), pattern),
                ),
            ] {
                assert_eq!(
                    result.unwrap_err(),
                    Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                        function,
                        argument: 1
                    })
                );
            }
            // 存在しない日付でも offsetMinutes の失敗を先に返す。
            let dt = record(ctx, &[2026, 13, 30, 24, 60, 60, -1, offset]);
            assert_eq!(
                direct!(ctx, from_date_time, dt).unwrap_err(),
                Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                    function: "Time.fromDateTime",
                    argument: 0
                })
            );
        }
    });
}

#[test]
fn iso_format_preserves_fraction_and_offset_and_round_trips() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (n, offset, expected) in [
            (0, 0, "1970-01-01T00:00:00Z"),
            (789_000_000, 0, "1970-01-01T00:00:00.789Z"),
            (1, 0, "1970-01-01T00:00:00.000000001Z"),
            (-1, 0, "1969-12-31T23:59:59.999999999Z"),
            (789_000_000, 540, "1970-01-01T09:00:00.789+09:00"),
            (0, -300, "1969-12-31T19:00:00-05:00"),
            (0, 1439, "1970-01-01T23:59:00+23:59"),
            (0, -1439, "1969-12-31T00:01:00-23:59"),
            (i64::MIN, 0, "1677-09-21T00:12:43.145224192Z"),
            (i64::MAX, 0, "2262-04-11T23:47:16.854775807Z"),
        ] {
            let t = record(ctx, &[n]);
            let text = direct!(ctx, format_i_s_o8601, t, Value::Int(offset)).unwrap();
            assert_eq!(ctx.str(text), Some(expected));
            let result = direct!(ctx, parse_i_s_o8601, text).unwrap();
            assert_eq!(nanos(ctx, payload(ctx, result, tags::RESULT_OK)), n);
        }
    });
}

#[test]
fn iso_parse_accepts_timestamp_syntax_and_rejects_missing_offset_or_range() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        for (source, expected) in [
            ("2016-12-31T23:59:60Z", 1_483_228_799_000_000_000),
            ("2016-12-31T23:59:59Z", 1_483_228_799_000_000_000),
            ("1970-01-01T09:00:30+09:00:30", 0),
            ("1970-01-01T00:00:00+25:59:59", -93_599_000_000_000),
            (
                "2026-09-28T12:34:56+09:00[Asia/Tokyo]",
                1_790_566_496_000_000_000,
            ),
            ("2026-09-28T12:34:56+09:00", 1_790_566_496_000_000_000),
            ("1970-01-01T00:00:00Z[Unknown/Zone]", 0),
            ("19700101T000000Z", 0),
            ("1970-01-01T00Z", 0),
            ("1970-01-01T00:00Z", 0),
            ("1970-01-01t00:00:00z", 0),
            ("1970-01-01 00:00:00Z", 0),
            ("+001970-01-01T00:00:00Z", 0),
            ("1970-01-01T00:00:00,789Z", 789_000_000),
        ] {
            let source = ctx.alloc_str(source, "test").unwrap();
            let result = direct!(ctx, parse_i_s_o8601, source).unwrap();
            assert_eq!(nanos(ctx, payload(ctx, result, tags::RESULT_OK)), expected);
        }
        for source in [
            "",
            "garbage",
            "2026-09-28T12:34:56",
            "9999-01-01T00:00:00Z",
            "0001-01-01T00:00:00Z",
            "1677-09-21T00:12:43.145224191Z",
            "2262-04-11T23:47:16.854775808Z",
        ] {
            let source = ctx.alloc_str(source, "test").unwrap();
            let result = direct!(ctx, parse_i_s_o8601, source).unwrap();
            payload(ctx, result, tags::RESULT_ERROR);
        }
    });
}

#[test]
fn format_accepts_only_the_specified_tokens_and_uses_nine_fraction_digits() {
    Heap::new(HeapConfig::default()).epoch(|ctx| {
        let t = record(ctx, &[1_790_566_496_789_000_000]);
        for (offset, pattern, expected) in [
            (
                540,
                "%Y %m %d %H %I %p %M %S %f %j %a %A %b %B %z %:z %%",
                "2026 09 28 12 12 PM 34 56 789000000 271 Mon Monday Sep September +0900 +09:00 %",
            ),
            (0, "%H %I %p %z %:z", "03 03 AM +0000 +00:00"),
            (
                -300,
                "%Y-%m-%d %H %I %p %z %:z",
                "2026-09-27 22 10 PM -0500 -05:00",
            ),
            (1439, "%z %:z", "+2359 +23:59"),
            (-1439, "%z %:z", "-2359 -23:59"),
            (0, "%%f", "%f"),
            (0, "%%%f", "%789000000"),
            (0, "é😀/日本語", "é😀/日本語"),
            (0, "", ""),
        ] {
            let pattern = ctx.alloc_str(pattern, "test").unwrap();
            let result = direct!(ctx, format, t, Value::Int(offset), pattern).unwrap();
            assert_eq!(
                ctx.str(payload(ctx, result, tags::RESULT_OK)),
                Some(expected)
            );
        }
        for (n, pattern, expected) in [
            (0, "%f", "000000000"),
            (1, "%f", "000000001"),
            (i64::MIN, "%Y", "1677"),
        ] {
            let t = record(ctx, &[n]);
            let pattern = ctx.alloc_str(pattern, "test").unwrap();
            let result = direct!(ctx, format, t, Value::Int(0), pattern).unwrap();
            assert_eq!(
                ctx.str(payload(ctx, result, tags::RESULT_OK)),
                Some(expected)
            );
        }
        for pattern in [
            "%Q", "%Z", "%F", "%-d", "%_m", "%^a", "%5Y", "%3f", "%:Y", "%::z", "%", "prefix %",
        ] {
            let pattern = ctx.alloc_str(pattern, "test").unwrap();
            let result = direct!(ctx, format, t, Value::Int(0), pattern).unwrap();
            payload(ctx, result, tags::RESULT_ERROR);
        }
    });
}
