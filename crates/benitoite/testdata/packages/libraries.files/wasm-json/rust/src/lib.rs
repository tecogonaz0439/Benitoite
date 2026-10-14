//! JSON の WASM の検証用実装（設計書 03-08「Json」、03-10「外部の関数」）。

wit_bindgen::generate!({ world: "json", path: "../wit" });
use exports::bnt::json::codec::{Document, Guest, GuestDocument, Node, ParseError};
use serde_core::de::{self, DeserializeSeed, MapAccess, SeqAccess, Visitor};
use std::collections::BTreeMap;
use std::fmt;

struct Component;
struct ParsedDocument(JsonMaterial);

mod text {
    pub const INVALID_NUMBER: &str = "invalid number";
    pub const JSON_VALUE: &str = "a JSON value";
    pub const NUMBER_OUT_OF_RANGE: &str = "number out of range";
    pub const INVALID_NODES: &str = "invalid JSON node table";
}

// 32 ビットのゲストでは位置と要素数が s64 に必ず収まる。
fn count(n: usize) -> i64 {
    i64::try_from(n).unwrap_or(i64::MAX)
}

// src/builtins/funcs/json.rs の parse と character_column を写す。
// 字面で数を分類し、誤りを文字の列と数の始まり・入力の終わりへ付け替える。
fn parse(input: &str) -> Result<JsonMaterial, ParseError> {
    parse_seed(input, |numbers, deserializer| {
        numbers.deserialize(deserializer)
    })
}

fn validate(input: &str) -> Result<(), ParseError> {
    parse_seed(input, |numbers, deserializer| {
        Validation(numbers).deserialize(deserializer)
    })
}

// 木を作る解析と要素を捨てる検証で、数の検査と診断の位置・文言を共用する。
fn parse_seed<T>(
    input: &str,
    read: impl FnOnce(
        &mut NumberState<'_>,
        &mut serde_json::Deserializer<serde_json::de::StrRead<'_>>,
    ) -> Result<T, serde_json::Error>,
) -> Result<T, ParseError> {
    let mut numbers = NumberState {
        lexemes: number_lexemes(input).peekable(),
        error_position: None,
    };
    let mut deserializer = serde_json::Deserializer::from_str(input);
    let parsed = match read(&mut numbers, &mut deserializer).and_then(|value| {
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
                let line = input
                    .bytes()
                    .filter(|&b| b == b'\n')
                    .count()
                    .saturating_add(1);
                let column = input
                    .rsplit('\n')
                    .next()
                    .unwrap_or("")
                    .chars()
                    .count()
                    .saturating_add(1);
                Some((line, column))
            } else {
                None
            };
            let (line, column) = position.unwrap_or_else(|| {
                (
                    error.line(),
                    character_column(input, error.line(), error.column()),
                )
            });
            return Err(ParseError {
                line: count(line),
                column: count(column),
                message: reason.to_owned(),
            });
        }
    };
    Ok(parsed)
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

// src/builtins/funcs/json.rs の number_value・NumberLexemes・NumberState・
// JsonMaterial と、その DeserializeSeed・Visitor の実装を写す。
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

// 解析は serde の上限の内側で材料の木を作り、書き出しは明示の積み重ねで辿る。
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
    fn next_number<E: de::Error>(&mut self) -> Result<JsonNumber, E> {
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
        Ok(value)
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
        self.next_number().map(JsonMaterial::Number)
    }

    fn visit_u64<E: de::Error>(self, _value: u64) -> Result<Self::Value, E> {
        self.next_number().map(JsonMaterial::Number)
    }

    fn visit_f64<E: de::Error>(self, _value: f64) -> Result<Self::Value, E> {
        self.next_number().map(JsonMaterial::Number)
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

// 検証では配列と対象の要素を保持しない。数は元の字面を分類して範囲を確かめる。
struct Validation<'a, 'input>(&'a mut NumberState<'input>);

impl<'de> DeserializeSeed<'de> for Validation<'_, '_> {
    type Value = ();
    fn deserialize<D: de::Deserializer<'de>>(self, deserializer: D) -> Result<(), D::Error> {
        deserializer.deserialize_any(self)
    }
}
impl<'de> Visitor<'de> for Validation<'_, '_> {
    type Value = ();
    fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(text::JSON_VALUE)
    }
    fn visit_unit<E: de::Error>(self) -> Result<(), E> {
        Ok(())
    }
    fn visit_bool<E: de::Error>(self, _value: bool) -> Result<(), E> {
        Ok(())
    }
    fn visit_i64<E: de::Error>(self, _value: i64) -> Result<(), E> {
        self.0.next_number().map(|_| ())
    }
    fn visit_u64<E: de::Error>(self, _value: u64) -> Result<(), E> {
        self.0.next_number().map(|_| ())
    }
    fn visit_f64<E: de::Error>(self, _value: f64) -> Result<(), E> {
        self.0.next_number().map(|_| ())
    }
    fn visit_str<E: de::Error>(self, _value: &str) -> Result<(), E> {
        Ok(())
    }
    fn visit_string<E: de::Error>(self, _value: String) -> Result<(), E> {
        Ok(())
    }
    fn visit_seq<A: SeqAccess<'de>>(self, mut array: A) -> Result<(), A::Error> {
        while array.next_element_seed(Validation(&mut *self.0))?.is_some() {}
        Ok(())
    }
    fn visit_map<A: MapAccess<'de>>(self, mut object: A) -> Result<(), A::Error> {
        while object.next_key::<serde_core::de::IgnoredAny>()?.is_some() {
            object.next_value_seed(Validation(&mut *self.0))?;
        }
        Ok(())
    }
}

// 利用者が節点の表で渡した深い木も、ゲストのスタックを増やさずに解放する。
impl Drop for JsonMaterial {
    fn drop(&mut self) {
        fn children(value: &mut JsonMaterial, work: &mut Vec<JsonMaterial>) {
            match value {
                JsonMaterial::Array(items) => work.extend(std::mem::take(items)),
                JsonMaterial::Object(items) => work.extend(std::mem::take(items).into_values()),
                JsonMaterial::Null
                | JsonMaterial::Bool(_)
                | JsonMaterial::Number(_)
                | JsonMaterial::String(_) => {}
            }
        }
        let mut work = Vec::new();
        children(self, &mut work);
        while let Some(mut value) = work.pop() {
            children(&mut value, &mut work);
        }
    }
}

enum Visit<'a> {
    Value(&'a JsonMaterial),
    Key(&'a str),
}
fn flatten(root: &JsonMaterial) -> Vec<Node> {
    let mut work = vec![Visit::Value(root)];
    let mut result = Vec::new();
    while let Some(step) = work.pop() {
        let value = match step {
            Visit::Key(k) => {
                result.push(Node::Key(k.to_owned()));
                continue;
            }
            Visit::Value(v) => v,
        };
        match value {
            JsonMaterial::Null => result.push(Node::Null),
            JsonMaterial::Bool(b) => result.push(Node::Boolean(*b)),
            JsonMaterial::Number(JsonNumber::Integer(i)) => result.push(Node::Integer(*i)),
            JsonMaterial::Number(JsonNumber::Float(f)) => result.push(Node::Float(*f)),
            JsonMaterial::String(s) => result.push(Node::Text(s.clone())),
            JsonMaterial::Array(a) => {
                result.push(Node::Array(count(a.len())));
                for child in a.iter().rev() {
                    work.push(Visit::Value(child));
                }
            }
            JsonMaterial::Object(m) => {
                result.push(Node::Object(count(m.len())));
                for (k, v) in m.iter().rev() {
                    work.push(Visit::Value(v));
                    work.push(Visit::Key(k));
                }
            }
        }
    }
    result
}

enum Frame {
    Array(Vec<JsonMaterial>, usize),
    Object(BTreeMap<String, JsonMaterial>, usize, Option<String>),
}
fn rebuild(nodes: Vec<Node>) -> Result<JsonMaterial, String> {
    let invalid = || text::INVALID_NODES.to_owned();
    let mut work = Vec::new();
    let mut root = None;
    for node in nodes {
        let mut value = match node {
            Node::Key(k) => {
                let Some(Frame::Object(_, _, key)) = work.last_mut() else {
                    return Err(invalid());
                };
                if key.replace(k).is_some() {
                    return Err(invalid());
                }
                continue;
            }
            Node::Null => JsonMaterial::Null,
            Node::Boolean(b) => JsonMaterial::Bool(b),
            Node::Integer(i) => JsonMaterial::Number(JsonNumber::Integer(i)),
            Node::Float(f) => JsonMaterial::Number(JsonNumber::Float(f)),
            Node::Text(s) => JsonMaterial::String(s),
            Node::Array(n) => {
                let n = usize::try_from(n).map_err(|_| invalid())?;
                if n > 0 {
                    work.push(Frame::Array(Vec::new(), n));
                    continue;
                }
                JsonMaterial::Array(Vec::new())
            }
            Node::Object(n) => {
                let n = usize::try_from(n).map_err(|_| invalid())?;
                if n > 0 {
                    work.push(Frame::Object(BTreeMap::new(), n, None));
                    continue;
                }
                JsonMaterial::Object(BTreeMap::new())
            }
        };
        loop {
            match work.last_mut() {
                None => {
                    if root.replace(value).is_some() {
                        return Err(invalid());
                    }
                    break;
                }
                Some(Frame::Array(items, remaining)) => {
                    items.push(value);
                    *remaining = remaining.checked_sub(1).ok_or_else(invalid)?;
                    if *remaining > 0 {
                        break;
                    }
                }
                Some(Frame::Object(items, remaining, key)) => {
                    items.insert(key.take().ok_or_else(invalid)?, value);
                    *remaining = remaining.checked_sub(1).ok_or_else(invalid)?;
                    if *remaining > 0 {
                        break;
                    }
                }
            }
            value = match work.pop() {
                Some(Frame::Array(items, _)) => JsonMaterial::Array(items),
                Some(Frame::Object(items, _, _)) => JsonMaterial::Object(items),
                None => return Err(invalid()),
            };
        }
    }
    if !work.is_empty() {
        return Err(invalid());
    }
    root.ok_or_else(invalid)
}

enum Write<'a> {
    Visit(&'a JsonMaterial, usize),
    Key(&'a str),
    Literal(&'static str),
    Indent(usize),
}

// src/builtins/funcs/json.rs の quoted を写し、バッファだけを String に改める。
fn quoted(buf: &mut String, s: &str) {
    buf.push('"');
    for c in s.chars() {
        match c {
            '"' => buf.push_str("\\\""),
            '\\' => buf.push_str("\\\\"),
            '\u{08}' => buf.push_str("\\b"),
            '\u{0c}' => buf.push_str("\\f"),
            '\n' => buf.push_str("\\n"),
            '\r' => buf.push_str("\\r"),
            '\t' => buf.push_str("\\t"),
            '\u{00}'..='\u{1f}' => buf.push_str(&format!("\\u{:04x}", u32::from(c))),
            _ => buf.push(c),
        }
    }
    buf.push('"');
}

// src/builtins/funcs/json.rs の write_json を写し、材料の木を直接辿る。
// 数だけを serde_json で書式化し、整形とエスケープは組み込み版に揃える。
fn write_json(root: &JsonMaterial, pretty: bool) -> String {
    let mut buf = String::new();
    let mut work = vec![Write::Visit(root, 0)];
    while let Some(step) = work.pop() {
        match step {
            Write::Literal(s) => buf.push_str(s),
            Write::Key(k) => quoted(&mut buf, k),
            Write::Indent(depth) => {
                buf.push('\n');
                for _ in 0..depth {
                    buf.push_str("  ");
                }
            }
            Write::Visit(value, depth) => match value {
                JsonMaterial::Null => buf.push_str("null"),
                JsonMaterial::Bool(b) => buf.push_str(if *b { "true" } else { "false" }),
                JsonMaterial::Number(JsonNumber::Integer(i)) => buf.push_str(&i.to_string()),
                JsonMaterial::Number(JsonNumber::Float(f)) => {
                    if let Some(n) = serde_json::Number::from_f64(*f) {
                        buf.push_str(&n.to_string());
                    } else {
                        buf.push_str("null");
                    }
                }
                JsonMaterial::String(s) => quoted(&mut buf, s),
                JsonMaterial::Array(_) | JsonMaterial::Object(_) => {
                    let object = matches!(value, JsonMaterial::Object(_));
                    let items: Vec<(Option<&str>, &JsonMaterial)> = match value {
                        JsonMaterial::Array(a) => a.iter().map(|v| (None, v)).collect(),
                        JsonMaterial::Object(m) => {
                            m.iter().map(|(k, v)| (Some(k.as_str()), v)).collect()
                        }
                        _ => Vec::new(),
                    };
                    buf.push(if object { '{' } else { '[' });
                    work.push(Write::Literal(if object { "}" } else { "]" }));
                    if items.is_empty() {
                        continue;
                    }
                    let child_depth = depth.saturating_add(1);
                    if pretty {
                        work.push(Write::Indent(depth));
                    }
                    for (index, (key, child)) in items.into_iter().enumerate().rev() {
                        work.push(Write::Visit(child, child_depth));
                        if let Some(key) = key {
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
            },
        }
    }
    buf
}

// RFC 6901 のトークンを順に復号し、配列では先頭の 0 と符号を許さない。
fn pointer<'a>(root: &'a JsonMaterial, path: &str) -> Option<&'a JsonMaterial> {
    if path.is_empty() {
        return Some(root);
    }
    let mut value = root;
    for raw in path.strip_prefix('/')?.split('/') {
        let mut key = String::new();
        let mut chars = raw.chars();
        while let Some(c) = chars.next() {
            if c == '~' {
                key.push(match chars.next()? {
                    '0' => '~',
                    '1' => '/',
                    _ => return None,
                });
            } else {
                key.push(c);
            }
        }
        value = match value {
            JsonMaterial::Object(m) => m.get(&key)?,
            JsonMaterial::Array(a) => {
                if key.is_empty()
                    || (key.len() > 1 && key.starts_with('0'))
                    || !key.bytes().all(|b| b.is_ascii_digit())
                {
                    return None;
                }
                a.get(key.parse::<usize>().ok()?)?
            }
            JsonMaterial::Null
            | JsonMaterial::Bool(_)
            | JsonMaterial::Number(_)
            | JsonMaterial::String(_) => return None,
        };
    }
    Some(value)
}

impl Guest for Component {
    type Document = ParsedDocument;
    fn validate(text: String) -> Result<(), ParseError> {
        validate(&text)
    }
    fn pretty(text: String) -> Result<String, ParseError> {
        Ok(write_json(&parse(&text)?, true))
    }
    fn minify(text: String) -> Result<String, ParseError> {
        Ok(write_json(&parse(&text)?, false))
    }
    fn parse(text: String) -> Result<Vec<Node>, ParseError> {
        Ok(flatten(&parse(&text)?))
    }
    fn stringify(nodes: Vec<Node>) -> Result<String, String> {
        Ok(write_json(&rebuild(nodes)?, false))
    }
    fn stringify_pretty(nodes: Vec<Node>) -> Result<String, String> {
        Ok(write_json(&rebuild(nodes)?, true))
    }
}
impl GuestDocument for ParsedDocument {
    fn parse(text: String) -> Result<Document, ParseError> {
        Ok(Document::new(ParsedDocument(parse(&text)?)))
    }
    fn get(&self, path: String) -> Option<String> {
        pointer(&self.0, &path).map(|v| write_json(v, false))
    }
    fn len(&self, path: String) -> Option<i64> {
        match pointer(&self.0, &path)? {
            JsonMaterial::Array(a) => Some(count(a.len())),
            JsonMaterial::Object(m) => Some(count(m.len())),
            JsonMaterial::Null
            | JsonMaterial::Bool(_)
            | JsonMaterial::Number(_)
            | JsonMaterial::String(_) => None,
        }
    }
}
export!(Component);
