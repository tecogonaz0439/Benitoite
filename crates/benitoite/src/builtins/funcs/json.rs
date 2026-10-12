//! JSON の解析と、再帰を使わない値の変換・文字列化（設計書 03-08「Json」）。

use std::collections::BTreeMap;
use std::fmt;

use serde_core::de::{self, DeserializeSeed, MapAccess, SeqAccess, Visitor};

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{CheckedLen, CtorTag, FieldsKind, StrBuf, Value, ValueCtx};
use crate::runtime::{Stop, list, map};

mod text {
    pub const INVALID_NUMBER: &str = "invalid number";
    pub const JSON_VALUE: &str = "a JSON value";
    pub const NUMBER_OUT_OF_RANGE: &str = "number out of range";
}

// レコードの宣言順を一か所で定める（設計書 02-06「脱糖」）。
mod parse_error {
    pub const LINE: usize = 0;
    pub const COLUMN: usize = 1;
    pub const MESSAGE: usize = 2;
    pub const LEN: usize = 3;
}

builtin! {
    /// `Json.parse` の本体（設計書 03-08「Json」）。
    name = "Json.parse",
    pure fn parse(ctx, arg0: Value<'e>) -> Value<'e> {
        let input = ctx.str(arg0)
            .ok_or_else(|| Stop::Internal("Json.parse expected String".into()))?;
        let mut numbers = NumberState {
            lexemes: number_lexemes(input).peekable(),
            error_position: None,
        };
        let mut deserializer = serde_json::Deserializer::from_str(input);
        let parsed = match (&mut numbers).deserialize(&mut deserializer).and_then(|value| {
            deserializer.end()?;
            if let Some(number) = numbers.lexemes.peek() {
                // 正しい JSON では字面と Visitor の呼び出しが一対一に対応するため
                // 届かない分岐だが、対応が崩れても余った字面の位置で入力の誤りにする。
                numbers.error_position = Some(number.position);
                return Err(de::Error::custom(text::INVALID_NUMBER));
            }
            Ok(value)
        }) {
            Ok(value) => value,
            Err(error) => {
                let reason = error.to_string();
                let suffix = format!(" at line {} column {}", error.line(), error.column());
                let reason = reason.strip_suffix(&suffix).unwrap_or(&reason);
                // serde は数の終わりを指すため、自前の数の誤りと serde の範囲外の
                // 誤りだけ始まりへ戻す。入力の終わりの誤りは最後の文字の直後を指し、
                // それ以外の構文の位置はそのまま使う（設計書 03-08「Json」）。
                // 文言の比較は serde_json の ErrorCode::NumberOutOfRange の表示が
                // NUMBER_OUT_OF_RANGE と同じことに頼る。serde_json の版を上げるときに確かめる。
                let position = if error.classify() == serde_json::error::Category::Data {
                    numbers.error_position
                } else if reason == text::NUMBER_OUT_OF_RANGE {
                    numbers.lexemes.peek().map(|number| number.position)
                } else if error.classify() == serde_json::error::Category::Eof {
                    // serde は最後の文字を指し、LF で終わるときだけ次の行になるため、
                    // 入力全体から最後の文字の直後を求める（設計書 03-08「Json」）。
                    let line = input.bytes().filter(|&b| b == b'\n').count().saturating_add(1);
                    let column = input.rsplit('\n').next().unwrap_or("")
                        .chars().count().saturating_add(1);
                    Some((line, column))
                } else {
                    None
                };
                let (line, column) = position.unwrap_or_else(|| (
                    error.line(), character_column(input, error.line(), error.column())
                ));
                return error_value(&ctx, line, column, reason);
            }
        };
        let value = convert(&ctx, &parsed)?;
        ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[value])
    }
}

fn character_column(input: &str, line: usize, column: usize) -> usize {
    let row = input.split('\n').nth(line.saturating_sub(1)).unwrap_or("");
    // serde の列はバイトであり、LF の直後を指すとき（文字列の中の LF の誤りなど）は
    // 0 になる。境界を切らず文字の開始を数える
    // （設計書 03-08「Json」）。
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

fn number_value(s: &str) -> Option<JsonNumber> {
    if !s.contains(['.', 'e', 'E'])
        && let Ok(n) = s.parse::<i64>()
    {
        return Some(JsonNumber::Integer(n));
    }
    s.parse::<f64>()
        .ok()
        .filter(|n| n.is_finite())
        .map(JsonNumber::Float)
}

fn number_lexemes(input: &str) -> NumberLexemes<'_> {
    NumberLexemes {
        input,
        chars: input.char_indices().peekable(),
        line: 1,
        column: 1,
    }
}

struct NumberLexemes<'a> {
    input: &'a str,
    chars: std::iter::Peekable<std::str::CharIndices<'a>>,
    line: usize,
    column: usize,
}

impl NumberLexemes<'_> {
    fn take_if(&mut self, predicate: impl FnOnce(char) -> bool) -> Option<char> {
        let (_, c) = self.chars.next_if(|&(_, c)| predicate(c))?;
        self.column = self.column.saturating_add(1);
        Some(c)
    }

    fn digits(&mut self) {
        while self.take_if(|c| c.is_ascii_digit()).is_some() {}
    }
}

impl<'a> Iterator for NumberLexemes<'a> {
    type Item = NumberLexeme<'a>;

    fn next(&mut self) -> Option<Self::Item> {
        while let Some((start, c)) = self.chars.next() {
            let position = (self.line, self.column);
            self.column = self.column.saturating_add(1);
            if c == '"' {
                while let Some((_, c)) = self.chars.next() {
                    self.column = self.column.saturating_add(1);
                    if c == '\\' {
                        self.chars.next();
                        self.column = self.column.saturating_add(1);
                    } else if c == '"' {
                        break;
                    }
                }
            } else if c == '-' || c.is_ascii_digit() {
                // 数の直後の構文の誤りを範囲外と誤診断しないよう、JSON の数の文法
                // -?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)? で止める。
                // -・1.・1e など不完全な字面は serde が Visitor を呼ぶ前に拒む。
                let first = if c == '-' {
                    self.take_if(|c| c.is_ascii_digit()).unwrap_or(c)
                } else {
                    c
                };
                if matches!(first, '1'..='9') {
                    self.digits();
                }
                if self.take_if(|c| c == '.').is_some() {
                    self.digits();
                }
                if self.take_if(|c| matches!(c, 'e' | 'E')).is_some() {
                    self.take_if(|c| matches!(c, '+' | '-'));
                    self.digits();
                }
                let end = self.chars.peek().map_or(self.input.len(), |&(i, _)| i);
                return Some(NumberLexeme {
                    source: self.input.get(start..end).unwrap_or(""),
                    position,
                });
            } else if c == '\n' {
                self.line = self.line.saturating_add(1);
                self.column = 1;
            }
        }
        None
    }
}

// 言語の値をここで確保すると Stop を serde の誤りへ通せないため、深さ 128 以下の
// 材料の木だけを作る。CheckedLen は convert に残す（設計書 03-08「Json」）。
enum JsonNumber {
    Integer(i64),
    Float(f64),
}

enum JsonMaterial {
    Null,
    Bool(bool),
    Number(JsonNumber),
    String(String),
    Array(Vec<JsonMaterial>),
    Object(BTreeMap<String, JsonMaterial>),
}

struct NumberLexeme<'a> {
    source: &'a str,
    position: (usize, usize),
}

struct NumberState<'a> {
    lexemes: std::iter::Peekable<NumberLexemes<'a>>,
    error_position: Option<(usize, usize)>,
}

impl NumberState<'_> {
    fn next_number<E: de::Error>(&mut self) -> Result<JsonMaterial, E> {
        let number = self
            .lexemes
            .next()
            .ok_or_else(|| E::custom(text::INVALID_NUMBER))?;
        // serde の数の値では -0 の分類が失われる。元の字面で分類することで
        // 型と符号を保ち、重複した鍵の値も文書の順に消費する（設計書 03-08「Json」）。
        let Some(value) = number_value(number.source) else {
            self.error_position = Some(number.position);
            return Err(E::custom(text::NUMBER_OUT_OF_RANGE));
        };
        Ok(JsonMaterial::Number(value))
    }
}

impl<'de> DeserializeSeed<'de> for &mut NumberState<'_> {
    type Value = JsonMaterial;

    fn deserialize<D: de::Deserializer<'de>>(
        self,
        deserializer: D,
    ) -> Result<Self::Value, D::Error> {
        deserializer.deserialize_any(self)
    }
}

impl<'de> Visitor<'de> for &mut NumberState<'_> {
    type Value = JsonMaterial;

    fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(text::JSON_VALUE)
    }

    fn visit_unit<E: de::Error>(self) -> Result<Self::Value, E> {
        Ok(JsonMaterial::Null)
    }

    fn visit_bool<E: de::Error>(self, value: bool) -> Result<Self::Value, E> {
        Ok(JsonMaterial::Bool(value))
    }

    fn visit_i64<E: de::Error>(self, _value: i64) -> Result<Self::Value, E> {
        self.next_number()
    }

    fn visit_u64<E: de::Error>(self, _value: u64) -> Result<Self::Value, E> {
        self.next_number()
    }

    fn visit_f64<E: de::Error>(self, _value: f64) -> Result<Self::Value, E> {
        self.next_number()
    }

    fn visit_str<E: de::Error>(self, value: &str) -> Result<Self::Value, E> {
        Ok(JsonMaterial::String(value.to_owned()))
    }

    fn visit_string<E: de::Error>(self, value: String) -> Result<Self::Value, E> {
        Ok(JsonMaterial::String(value))
    }

    fn visit_seq<A: SeqAccess<'de>>(self, mut array: A) -> Result<Self::Value, A::Error> {
        let mut items = Vec::new();
        while let Some(item) = array.next_element_seed(&mut *self)? {
            items.push(item);
        }
        Ok(JsonMaterial::Array(items))
    }

    fn visit_map<A: MapAccess<'de>>(self, mut object: A) -> Result<Self::Value, A::Error> {
        let mut items = BTreeMap::new();
        while let Some(key) = object.next_key::<String>()? {
            let value = object.next_value_seed(&mut *self)?;
            items.insert(key, value);
        }
        Ok(JsonMaterial::Object(items))
    }
}

fn ctor<'e>(ctx: &ValueCtx<'e>, tag: u32, value: Value<'e>) -> Result<Value<'e>, Stop> {
    ctx.alloc_fields(FieldsKind::Ctor, tag, &[value])
}

enum Convert<'a> {
    Visit(&'a JsonMaterial),
    Array(usize),
    Object(&'a BTreeMap<String, JsonMaterial>),
}

fn convert<'e>(ctx: &ValueCtx<'e>, root: &JsonMaterial) -> Result<Value<'e>, Stop> {
    let mut work = vec![Convert::Visit(root)];
    let mut values = Vec::new();
    while let Some(step) = work.pop() {
        let value = match step {
            Convert::Visit(value) => match value {
                JsonMaterial::Null => Value::Tag(CtorTag(tags::JSON_VALUE_NULL)),
                JsonMaterial::Bool(b) => ctor(ctx, tags::JSON_VALUE_BOOLEAN, Value::Bool(*b))?,
                JsonMaterial::Number(n) => {
                    let (tag, value) = match n {
                        JsonNumber::Integer(n) => (tags::JSON_VALUE_INTEGER, Value::Int(*n)),
                        JsonNumber::Float(n) => (tags::JSON_VALUE_FLOAT, Value::Float(*n)),
                    };
                    ctor(ctx, tag, value)?
                }
                JsonMaterial::String(s) => ctor(
                    ctx,
                    tags::JSON_VALUE_STRING,
                    ctx.alloc_str(s, "Json.parse")?,
                )?,
                JsonMaterial::Array(items) => {
                    CheckedLen::elements(super::count(items.len())?, "Json.parse")?;
                    work.push(Convert::Array(items.len()));
                    work.extend(items.iter().rev().map(Convert::Visit));
                    continue;
                }
                JsonMaterial::Object(items) => {
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
                        // 型と符号を往復で保つ（設計書 03-08「Json」）。
                        if let Some(n) = serde_json::Number::from_f64(n) {
                            buf.push_str(&n.to_string())?;
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

/// 部分の項目。番号は表の中の位置で決まるので、末尾以外には加えない。
pub const DECLS: &[BuiltinDecl] = &[parse::DECL, stringify::DECL, stringify_pretty::DECL];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（AGENTS.md「実装の規約」の「`#[allow]` を書いてよい箇所」）。
    #![allow(
        clippy::unwrap_used,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    // 関門: 数の分類、位置、出力と深さの境目を守る（設計書 03-08「Json」）。
    // 浮動小数点への一律変換、バイト列の列、再帰の採用による退行を捕まえる。
    // 組み込みの関数は関数ごとの単体テストで確かめる（設計書 07-03「差分テスト」）。
    // ソースの関数とレコードの欄は tests/l21_json.rs で守る。
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
                ("1e-400", 0.0, "0.0"),
                ("-1e-400", -0.0, "-0.0"),
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
                    "18446744073709551616",
                    1.8446744073709552e19,
                    "1.8446744073709552e+19",
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
    fn special_number_key_remains_an_object() {
        // 関門: 正当な object を内部の数と取り違える TODO-194 の退行を捕まえる。
        // 既存の往復の表にはこの鍵がなく、公開の範囲や差し込み口を増やさず本体で確かめる。
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for contents in ["123", "1e9999", "-0", "abc"] {
                let object = format!(r#"{{"$serde_json::private::Number":"{contents}"}}"#);
                let escaped = format!(r#"{{"\u0024serde_json::private::Number":"{contents}"}}"#);
                for (source, expected) in [
                    (object.clone(), object.clone()),
                    (escaped, object.clone()),
                    (format!("[{object}]"), format!("[{object}]")),
                    (
                        format!(r#"{{"nested":{object}}}"#),
                        format!(r#"{{"nested":{object}}}"#),
                    ),
                ] {
                    let value = parsed(ctx, &source, tags::RESULT_OK);
                    let out = direct!(ctx, stringify, value).unwrap();
                    assert_eq!(ctx.str(out), Some(expected.as_str()), "{source}");
                    let back = parsed(ctx, &expected, tags::RESULT_OK);
                    assert!(crate::runtime::equal::values_equal(ctx, value, back).unwrap());
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
                ("[-0, -0.0, -0e3, -0]", "[0,-0.0,-0.0,0]"),
                (r#"{"a":-0.0,"a":-0}"#, r#"{"a":0}"#),
                (r#"{"a":-0,"a":-0.0,"b":-0}"#, r#"{"a":-0.0,"b":0}"#),
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
        // 関門: Json.parse の診断を守る。数の直後の構文の誤りを範囲外と誤診断する
        // 退行は既存の行では捕まらないため、基準の位置と文言を同じ表で確かめる。
        // CR だけの行も試す。CR LF の行だけでは、CR を行の区切りにする退行を捕まえられない。
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (source, line, column, reason) in [
                ("[1,]", 1, 4, "trailing comma"),
                ("[1-2]", 1, 3, "expected `,` or `]`"),
                ("[1+2]", 1, 3, "expected `,` or `]`"),
                ("[1.5.5]", 1, 5, "expected `,` or `]`"),
                (r#"{"a":1e5e5}"#, 1, 9, "expected `,` or `}`"),
                ("[1,2-]", 1, 5, "expected `,` or `]`"),
                ("[1E+2-3]", 1, 6, "expected `,` or `]`"),
                (r#"["\\",1-2]"#, 1, 8, "expected `,` or `]`"),
                ("[01]", 1, 3, text::INVALID_NUMBER),
                ("[-]", 1, 3, text::INVALID_NUMBER),
                ("[1.]", 1, 4, text::INVALID_NUMBER),
                ("[1.0e]", 1, 6, text::INVALID_NUMBER),
                ("1 2", 1, 3, "trailing characters"),
                ("[\n1,\n]", 3, 1, "trailing comma"),
                ("[\"é😀\",]", 1, 7, "trailing comma"),
                ("\"é", 1, 3, "EOF while parsing a string"),
                ("[1,", 1, 4, "EOF while parsing a value"),
                ("", 1, 1, "EOF while parsing a value"),
                ("   ", 1, 4, "EOF while parsing a value"),
                ("[1,\r\n", 2, 1, "EOF while parsing a value"),
                ("[1,\r", 1, 5, "EOF while parsing a value"),
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
                ("[1e400,}", 1, 2, text::NUMBER_OUT_OF_RANGE),
                ("[},1e400]", 1, 2, "expected value"),
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
