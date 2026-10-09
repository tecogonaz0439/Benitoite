//! JSON の解析と、再帰を使わない値の変換・文字列化（設計書 03-08「Json」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{CheckedLen, CtorTag, FieldsKind, StrBuf, Value, ValueCtx};
use crate::runtime::{Stop, list, map};

mod text {
    pub const NUMBER_OUT_OF_RANGE: &str = "number out of range";
}

// レコードの宣言順を一か所で定める（実装プラン 10-15「レコードの値の作り方」）。
mod parse_error {
    pub const LINE: usize = 0;
    pub const COLUMN: usize = 1;
    pub const MESSAGE: usize = 2;
    pub const LEN: usize = 3;
}

builtin! {
    /// `Json.parse` の本体（設計書 03-08「Json」、ADR 0322）。
    name = "Json.parse",
    pure fn parse(ctx, arg0: Value<'e>) -> Value<'e> {
        let input = ctx.str(arg0)
            .ok_or_else(|| Stop::Internal("Json.parse expected String".into()))?;
        let parsed = match serde_json::from_str::<serde_json::Value>(input) {
            Ok(value) => value,
            Err(error) => {
                let reason = error.to_string();
                let suffix = format!(" at line {} column {}", error.line(), error.column());
                return error_value(&ctx, error.line(), character_column(input, error.line(), error.column()),
                    reason.strip_suffix(&suffix).unwrap_or(&reason));
            }
        };
        // arbitrary_precision は範囲外の数も保存する。重複した鍵で捨てられた数も含めて
        // 入力を検査し、文字列内の数字は読み飛ばす（設計書 03-08「Json」、実装プラン L21）。
        if let Some((line, column)) = overflow_position(input) {
            return error_value(&ctx, line, column, text::NUMBER_OUT_OF_RANGE);
        }
        let value = convert(&ctx, &parsed)?;
        ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
    }
}

fn character_column(input: &str, line: usize, column: usize) -> usize {
    let row = input.split('\n').nth(line.saturating_sub(1)).unwrap_or("");
    // serde の列はバイトであり EOF では 0 になる。境界を切らず文字の開始を数える
    // （設計書 03-08「Json」、実装プラン L21「手順の要点」）。
    row.char_indices()
        .take_while(|(i, _)| *i < column)
        .count()
        .max(1)
}

fn error_value<'e>(
    ctx: &ValueCtx<'e>,
    line: usize,
    column: usize,
    reason: &str,
) -> Result<Value<'e>, Stop> {
    let mut fields = [Value::Unit; parse_error::LEN];
    *fields
        .get_mut(parse_error::LINE)
        .ok_or_else(|| Stop::Internal("ParseError line field".into()))? =
        Value::Int(super::integer_count(line)?);
    *fields
        .get_mut(parse_error::COLUMN)
        .ok_or_else(|| Stop::Internal("ParseError column field".into()))? =
        Value::Int(super::integer_count(column)?);
    *fields
        .get_mut(parse_error::MESSAGE)
        .ok_or_else(|| Stop::Internal("ParseError message field".into()))? =
        ctx.alloc_str(reason, "Json.parse")?;
    let error = ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &fields)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_ERROR, &[error])
}

fn number_value<'e>(s: &str) -> Option<Value<'e>> {
    if !s.contains(['.', 'e', 'E'])
        && let Ok(n) = s.parse::<i64>()
    {
        return Some(Value::Int(n));
    }
    s.parse::<f64>()
        .ok()
        .filter(|n| n.is_finite())
        .map(Value::Float)
}

fn overflow_position(input: &str) -> Option<(usize, usize)> {
    let mut chars = input.char_indices().peekable();
    let mut line = 1usize;
    let mut column = 1usize;
    while let Some((start, c)) = chars.next() {
        if c == '"' {
            column = column.saturating_add(1);
            while let Some((_, c)) = chars.next() {
                column = column.saturating_add(1);
                if c == '\\' {
                    chars.next();
                    column = column.saturating_add(1);
                } else if c == '"' {
                    break;
                }
            }
        } else if c == '-' || c.is_ascii_digit() {
            let location = (line, column);
            let mut end = start.saturating_add(c.len_utf8());
            column = column.saturating_add(1);
            while let Some(&(i, c)) = chars.peek() {
                if !matches!(c, '0'..='9' | '.' | 'e' | 'E' | '+' | '-') {
                    break;
                }
                chars.next();
                end = i.saturating_add(c.len_utf8());
                column = column.saturating_add(1);
            }
            if number_value(input.get(start..end)?).is_none() {
                return Some(location);
            }
        } else if c == '\n' {
            line = line.saturating_add(1);
            column = 1;
        } else {
            column = column.saturating_add(1);
        }
    }
    None
}

fn ctor<'e>(ctx: &ValueCtx<'e>, tag: u32, value: Value<'e>) -> Result<Value<'e>, Stop> {
    ctx.alloc_fields(FieldsKind::Ctor, tag, &[value])
}

enum Convert<'a> {
    Visit(&'a serde_json::Value),
    Array(usize),
    Object(&'a serde_json::Map<String, serde_json::Value>),
}

fn convert<'e>(ctx: &ValueCtx<'e>, root: &serde_json::Value) -> Result<Value<'e>, Stop> {
    let mut work = vec![Convert::Visit(root)];
    let mut values = Vec::new();
    while let Some(step) = work.pop() {
        let value = match step {
            Convert::Visit(value) => match value {
                serde_json::Value::Null => Value::Tag(CtorTag(tags::JSON_VALUE_NULL)),
                serde_json::Value::Bool(b) => ctor(ctx, tags::JSON_VALUE_BOOLEAN, Value::Bool(*b))?,
                serde_json::Value::Number(n) => {
                    let value = number_value(n.as_str())
                        .ok_or_else(|| Stop::Internal("unchecked JSON number".into()))?;
                    let tag = if matches!(value, Value::Int(_)) {
                        tags::JSON_VALUE_INTEGER
                    } else {
                        tags::JSON_VALUE_FLOAT
                    };
                    ctor(ctx, tag, value)?
                }
                serde_json::Value::String(s) => ctor(
                    ctx,
                    tags::JSON_VALUE_STRING,
                    ctx.alloc_str(s, "Json.parse")?,
                )?,
                serde_json::Value::Array(items) => {
                    CheckedLen::elements(super::count(items.len())?, "Json.parse")?;
                    work.push(Convert::Array(items.len()));
                    work.extend(items.iter().rev().map(Convert::Visit));
                    continue;
                }
                serde_json::Value::Object(items) => {
                    CheckedLen::elements(super::count(items.len())?, "Json.parse")?;
                    work.push(Convert::Object(items));
                    work.extend(items.values().rev().map(Convert::Visit));
                    continue;
                }
            },
            Convert::Array(count) => {
                let start = values
                    .len()
                    .checked_sub(count)
                    .ok_or_else(|| Stop::Internal("JSON array conversion stack".into()))?;
                let items = values.split_off(start);
                ctor(
                    ctx,
                    tags::JSON_VALUE_ARRAY,
                    list::from_values(ctx, &items, "Json.parse")?,
                )?
            }
            Convert::Object(object) => {
                let start = values
                    .len()
                    .checked_sub(object.len())
                    .ok_or_else(|| Stop::Internal("JSON object conversion stack".into()))?;
                let items = values.split_off(start);
                let mut pairs = Vec::with_capacity(object.len());
                for (key, value) in object.keys().zip(items) {
                    pairs.push((ctx.alloc_str(key, "Json.parse")?, value));
                }
                ctor(
                    ctx,
                    tags::JSON_VALUE_OBJECT,
                    map::map_from_sorted(ctx, &pairs, "Json.parse")?,
                )?
            }
        };
        values.push(value);
    }
    values
        .pop()
        .ok_or_else(|| Stop::Internal("empty JSON conversion".into()))
}

builtin! {
    /// `Json.stringify` の本体（設計書 03-08「Json」）。
    name = "Json.stringify",
    pure fn stringify(ctx, arg0: Value<'e>) -> Value<'e> {
        write_json(&ctx, arg0, false, "Json.stringify")
    }
}

builtin! {
    /// `Json.stringifyPretty` の本体（設計書 03-08「Json」）。
    name = "Json.stringifyPretty",
    pure fn stringify_pretty(ctx, arg0: Value<'e>) -> Value<'e> {
        write_json(&ctx, arg0, true, "Json.stringifyPretty")
    }
}

enum Write<'e> {
    Visit(Value<'e>, usize),
    Key(Value<'e>),
    Literal(&'static str),
    Indent(usize),
}

fn quoted(buf: &mut StrBuf, s: &str) -> Result<(), Stop> {
    buf.push_char('"')?;
    for c in s.chars() {
        match c {
            '"' => buf.push_str("\\\"")?,
            '\\' => buf.push_str("\\\\")?,
            '\u{08}' => buf.push_str("\\b")?,
            '\u{0c}' => buf.push_str("\\f")?,
            '\n' => buf.push_str("\\n")?,
            '\r' => buf.push_str("\\r")?,
            '\t' => buf.push_str("\\t")?,
            '\u{00}'..='\u{1f}' => buf.push_str(&format!("\\u{:04x}", u32::from(c)))?,
            _ => buf.push_char(c)?,
        }
    }
    buf.push_char('"')
}

fn write_json<'e>(
    ctx: &ValueCtx<'e>,
    root: Value<'e>,
    pretty: bool,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let mut buf = StrBuf::new(function);
    let mut work = vec![Write::Visit(root, 0)];
    while let Some(step) = work.pop() {
        match step {
            Write::Literal(s) => buf.push_str(s)?,
            Write::Indent(depth) => {
                buf.push_char('\n')?;
                for _ in 0..depth {
                    buf.push_str("  ")?;
                }
            }
            Write::Key(key) => quoted(
                &mut buf,
                ctx.str(key)
                    .ok_or_else(|| Stop::Internal("JSON object key is not String".into()))?,
            )?,
            Write::Visit(value, depth) => {
                if matches!(value, Value::Tag(CtorTag(tags::JSON_VALUE_NULL))) {
                    buf.push_str("null")?;
                    continue;
                }
                let (FieldsKind::Ctor, tag) = ctx
                    .fields_header(value)
                    .ok_or_else(|| Stop::Internal("JSON value is not a constructor".into()))?
                else {
                    return Err(Stop::Internal("JSON value has wrong fields kind".into()));
                };
                let payload = ctx
                    .field(value, 0)
                    .ok_or_else(|| Stop::Internal("JSON constructor payload missing".into()))?;
                match tag {
                    tags::JSON_VALUE_BOOLEAN => buf.push_str(
                        if payload
                            .as_bool()
                            .ok_or_else(|| Stop::Internal("JSON Boolean payload".into()))?
                        {
                            "true"
                        } else {
                            "false"
                        },
                    )?,
                    tags::JSON_VALUE_INTEGER => buf.push_str(
                        &payload
                            .as_int()
                            .ok_or_else(|| Stop::Internal("JSON Integer payload".into()))?
                            .to_string(),
                    )?,
                    tags::JSON_VALUE_FLOAT => {
                        let n = payload
                            .as_float()
                            .ok_or_else(|| Stop::Internal("JSON Float payload".into()))?;
                        // 一つの数だけをクレートで書式化し、木は自前で辿る。1.0 と -0.0 の
                        // 型と符号を往復で保つ（設計書 03-08「Json」、ADR 0328）。
                        if let Some(n) = serde_json::Number::from_f64(n) {
                            buf.push_str(n.as_str())?;
                        } else {
                            buf.push_str("null")?;
                        }
                    }
                    tags::JSON_VALUE_STRING => quoted(
                        &mut buf,
                        ctx.str(payload)
                            .ok_or_else(|| Stop::Internal("JSON String payload".into()))?,
                    )?,
                    tags::JSON_VALUE_ARRAY | tags::JSON_VALUE_OBJECT => {
                        let object = tag == tags::JSON_VALUE_OBJECT;
                        let items = if object {
                            map::map_to_vec(ctx, payload)?
                        } else {
                            list::to_vec(ctx, payload)?
                                .into_iter()
                                .map(|v| (Value::Unit, v))
                                .collect()
                        };
                        buf.push_char(if object { '{' } else { '[' })?;
                        work.push(Write::Literal(if object { "}" } else { "]" }));
                        if items.is_empty() {
                            continue;
                        }
                        let child_depth = depth.checked_add(1).ok_or_else(|| {
                            Stop::Internal("JSON indentation depth overflow".into())
                        })?;
                        if pretty {
                            work.push(Write::Indent(depth));
                        }
                        for (index, (key, child)) in items.into_iter().enumerate().rev() {
                            work.push(Write::Visit(child, child_depth));
                            if object {
                                work.push(Write::Literal(if pretty { ": " } else { ":" }));
                                work.push(Write::Key(key));
                            }
                            if pretty {
                                work.push(Write::Indent(child_depth));
                            }
                            if index != 0 {
                                work.push(Write::Literal(","));
                            }
                        }
                    }
                    _ => return Err(Stop::Internal("unknown JSON constructor tag".into())),
                }
            }
        }
    }
    ctx.alloc_str_buf(buf)
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[parse::DECL, stringify::DECL, stringify_pretty::DECL];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    // 関門: 03-08 の数の分類、位置、出力と L21 が指定した深さの境目を守る。
    // 浮動小数点への一律変換、バイト列の列、再帰の採用による退行を捕まえる。
    // 既存の表の照合は本体を呼ばない。新しい差し込み口は作らず、10-15 の
    // 個別指示どおり本体を直接呼ぶ。ソースの関数とレコードの欄は tests/l21_json.rs で守る。
    use super::*;
    use crate::builtins::funcs::operators::tests::direct;
    use crate::runtime::heap::{Heap, HeapConfig, NoGcCtx};

    fn parsed<'e>(ctx: &mut NoGcCtx<'e>, source: &str, tag: u32) -> Value<'e> {
        let source = ctx.alloc_str(source, "test").unwrap();
        let result = direct!(ctx, parse, source).unwrap();
        assert_eq!(ctx.fields_header(result), Some((FieldsKind::Ctor, tag)));
        ctx.field(result, 0).unwrap()
    }

    fn payload<'e>(ctx: &ValueCtx<'e>, value: Value<'e>, tag: u32) -> Value<'e> {
        assert_eq!(ctx.fields_header(value), Some((FieldsKind::Ctor, tag)));
        assert_eq!(ctx.fields_len(value), Some(1));
        ctx.field(value, 0).unwrap()
    }

    #[test]
    fn numbers_preserve_integer_float_distinction_and_negative_zero() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (source, expected) in [
                ("0", 0),
                ("-0", 0),
                ("42", 42),
                ("-42", -42),
                ("9223372036854775807", i64::MAX),
                ("-9223372036854775808", i64::MIN),
            ] {
                let value = parsed(ctx, source, tags::RESULT_OK);
                assert_eq!(
                    payload(ctx, value, tags::JSON_VALUE_INTEGER).as_int(),
                    Some(expected)
                );
                let out = direct!(ctx, stringify, value).unwrap();
                assert_eq!(ctx.str(out), Some(expected.to_string().as_str()));
                let source = ctx.str(out).unwrap().to_owned();
                let back = parsed(ctx, &source, tags::RESULT_OK);
                assert_eq!(
                    payload(ctx, back, tags::JSON_VALUE_INTEGER).as_int(),
                    Some(expected)
                );
            }
            for (source, expected, written) in [
                ("-0.0", -0.0f64, "-0.0"),
                ("0.0", 0.0, "0.0"),
                ("1.0", 1.0, "1.0"),
                ("1E2", 100.0, "100.0"),
                ("1.25", 1.25, "1.25"),
                ("-2.5e-3", -0.0025, "-0.0025"),
                (
                    "9223372036854775808",
                    9223372036854775808.0,
                    "9.223372036854776e+18",
                ),
                (
                    "-9223372036854775809",
                    -9223372036854775808.0,
                    "-9.223372036854776e+18",
                ),
                ("1e300", 1e300, "1e+300"),
                ("5e-324", f64::from_bits(1), "5e-324"),
            ] {
                let value = parsed(ctx, source, tags::RESULT_OK);
                assert_eq!(
                    payload(ctx, value, tags::JSON_VALUE_FLOAT)
                        .as_float()
                        .unwrap()
                        .to_bits(),
                    expected.to_bits(),
                    "{source}"
                );
                for out in [
                    direct!(ctx, stringify, value).unwrap(),
                    direct!(ctx, stringify_pretty, value).unwrap(),
                ] {
                    assert_eq!(ctx.str(out), Some(written), "{source}");
                    let source = ctx.str(out).unwrap().to_owned();
                    let back = parsed(ctx, &source, tags::RESULT_OK);
                    assert_eq!(
                        payload(ctx, back, tags::JSON_VALUE_FLOAT)
                            .as_float()
                            .unwrap()
                            .to_bits(),
                        expected.to_bits()
                    );
                }
            }
        });
    }

    #[test]
    fn values_round_trip_with_escapes_sorted_keys_and_last_duplicate() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (source, expected) in [
                (" \n null\t ", "null"),
                ("true", "true"),
                ("false", "false"),
                (r#""\u00e9\ud83d\ude00""#, "\"é😀\""),
                (
                    r#""\"\\\b\f\n\r\t\u0000\u001f/""#,
                    r#""\"\\\b\f\n\r\t\u0000\u001f/""#,
                ),
                ("\"\u{7f}\"", "\"\u{7f}\""),
                ("[]", "[]"),
                ("{}", "{}"),
                (
                    r#"{"z":1,"a":[true,null,{"é":"😀"}],"z":2}"#,
                    r#"{"a":[true,null,{"é":"😀"}],"z":2}"#,
                ),
                ("[1,-2,3.0,\"text\",false]", "[1,-2,3.0,\"text\",false]"),
                (
                    r#"{"n":"1e400 and \"-1e400\""}"#,
                    r#"{"n":"1e400 and \"-1e400\""}"#,
                ),
            ] {
                let value = parsed(ctx, source, tags::RESULT_OK);
                let out = direct!(ctx, stringify, value).unwrap();
                assert_eq!(ctx.str(out), Some(expected), "{source}");
                let source = ctx.str(out).unwrap().to_owned();
                let back = parsed(ctx, &source, tags::RESULT_OK);
                assert!(crate::runtime::equal::values_equal(ctx, value, back).unwrap());
                let pretty = direct!(ctx, stringify_pretty, value).unwrap();
                let source = ctx.str(pretty).unwrap().to_owned();
                let back = parsed(ctx, &source, tags::RESULT_OK);
                assert!(crate::runtime::equal::values_equal(ctx, value, back).unwrap());
            }
        });
    }

    #[test]
    fn pretty_layout_and_non_finite_floats_follow_json_rules() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let value = parsed(ctx, r#"{"b":{},"a":[1,{"x":[]},2]}"#, tags::RESULT_OK);
            let pretty = direct!(ctx, stringify_pretty, value).unwrap();
            assert_eq!(ctx.str(pretty), Some("{\n  \"a\": [\n    1,\n    {\n      \"x\": []\n    },\n    2\n  ],\n  \"b\": {}\n}"));
            for n in [f64::NAN, f64::INFINITY, f64::NEG_INFINITY] {
                let value = ctor(ctx, tags::JSON_VALUE_FLOAT, Value::Float(n)).unwrap();
                for out in [direct!(ctx, stringify, value).unwrap(), direct!(ctx, stringify_pretty, value).unwrap()] {
                    assert_eq!(ctx.str(out), Some("null"));
                }
            }
        });
    }

    #[test]
    fn parse_errors_report_character_columns_and_separate_reasons() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (source, line, column, reason) in [
                ("[1,]", 1, 4, "trailing comma"),
                ("[\n1,\n]", 3, 1, "trailing comma"),
                ("[\"é😀\",]", 1, 7, "trailing comma"),
                ("\"é", 1, 2, "EOF while parsing a string"),
                ("[1,\n", 2, 1, "EOF while parsing a value"),
                ("1e400", 1, 1, text::NUMBER_OUT_OF_RANGE),
                ("-1e400", 1, 1, text::NUMBER_OUT_OF_RANGE),
                (
                    "{\n \"é😀\": [0, -1e400]\n}",
                    2,
                    12,
                    text::NUMBER_OUT_OF_RANGE,
                ),
                (r#"["1e400\"",2,1e400]"#, 1, 14, text::NUMBER_OUT_OF_RANGE),
                (r#"{"a":1e400,"a":0}"#, 1, 6, text::NUMBER_OUT_OF_RANGE),
            ] {
                let error = parsed(ctx, source, tags::RESULT_ERROR);
                assert_eq!(
                    ctx.fields_header(error),
                    Some((FieldsKind::Ctor, tags::RECORD))
                );
                assert_eq!(
                    ctx.field(error, u32::try_from(parse_error::LINE).unwrap())
                        .unwrap()
                        .as_int(),
                    Some(line),
                    "{source}"
                );
                assert_eq!(
                    ctx.field(error, u32::try_from(parse_error::COLUMN).unwrap())
                        .unwrap()
                        .as_int(),
                    Some(column),
                    "{source}"
                );
                let message = ctx
                    .str(
                        ctx.field(error, u32::try_from(parse_error::MESSAGE).unwrap())
                            .unwrap(),
                    )
                    .unwrap();
                assert_eq!(message, reason, "{source}");
                assert!(!message.contains(" at line"));
            }
        });
    }

    #[test]
    fn parser_depth_boundary_and_iterative_writing_of_deep_values() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for depth in [127, 128, 1000] {
                let input = format!("{}0{}", "[".repeat(depth), "]".repeat(depth));
                let value = parsed(
                    ctx,
                    &input,
                    if depth == 127 {
                        tags::RESULT_OK
                    } else {
                        tags::RESULT_ERROR
                    },
                );
                if depth == 127 {
                    let out = direct!(ctx, stringify, value).unwrap();
                    assert_eq!(ctx.str(out), Some(input.as_str()));
                } else {
                    assert_eq!(
                        ctx.str(ctx.field(value, 2).unwrap()),
                        Some("recursion limit exceeded")
                    );
                }
            }
            let mut value = Value::Tag(CtorTag(tags::JSON_VALUE_NULL));
            for _ in 0..1000 {
                let array = list::from_values(ctx, &[value], "test").unwrap();
                value = ctor(ctx, tags::JSON_VALUE_ARRAY, array).unwrap();
            }
            let out = direct!(ctx, stringify, value).unwrap();
            assert_eq!(
                ctx.str(out),
                Some(format!("{}null{}", "[".repeat(1000), "]".repeat(1000)).as_str())
            );
            let out = direct!(ctx, stringify_pretty, value).unwrap();
            let mut expected = String::new();
            for depth in 0..1000 {
                expected.push_str(&format!("{}[\n", "  ".repeat(depth)));
            }
            expected.push_str(&format!("{}null", "  ".repeat(1000)));
            for depth in (0..1000).rev() {
                expected.push_str(&format!("\n{}]", "  ".repeat(depth)));
            }
            assert_eq!(ctx.str(out), Some(expected.as_str()));
        });
    }
}
