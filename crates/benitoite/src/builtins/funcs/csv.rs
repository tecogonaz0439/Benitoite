//! CSV の読み書きとレコード開始行の追跡（設計書 03-08「Csv」）。

use crate::builtins::iface::{BuiltinDecl, builtin};
use crate::builtins::table::tags;
use crate::runtime::heap::{CheckedLen, FieldsKind, StrBuf, Value, ValueCtx};
use crate::runtime::{RuntimeError, Stop, list, map};
use csv_core::{ReadFieldResult, ReaderBuilder};

mod text {
    pub const UNCLOSED_QUOTE: &str = "unclosed quoted field";
    pub const DUPLICATE_HEADER: &str = "duplicate header name";
    pub const FIELD_COUNT: &str = "field count differs from header";
}

// レコードの宣言順を一か所で定める（実装プラン 10-15「レコードの値の作り方」）。
mod parse_error {
    pub const LINE: usize = 0;
    pub const MESSAGE: usize = 1;
    pub const LEN: usize = 2;
}

builtin! {
    /// `Csv.parse` の本体（設計書 03-08「Csv」）。
    name = "Csv.parse",
    pure fn parse(ctx, arg0: Value<'e>) -> Value<'e> {
        read_csv(&ctx, arg0, b',', false, "Csv.parse")
    }
}

builtin! {
    /// `Csv.parseWith` の本体。区切りは ASCII に限る（設計書 03-08「Csv」）。
    name = "Csv.parseWith",
    pure fn parse_with(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        let delimiter = delimiter(arg1, true, "Csv.parseWith")?;
        let delimiter = u8::try_from(u32::from(delimiter))
            .map_err(|_| Stop::Internal("checked ASCII delimiter does not fit u8".into()))?;
        read_csv(&ctx, arg0, delimiter, false, "Csv.parseWith")
    }
}

builtin! {
    /// `Csv.parseWithHeader` の本体。見出しのない空の入力は空のリストを返す
    /// （設計書 03-08「Csv」、実装プラン L23「手順の要点」）。
    name = "Csv.parseWithHeader",
    pure fn parse_with_header(ctx, arg0: Value<'e>) -> Value<'e> {
        read_csv(&ctx, arg0, b',', true, "Csv.parseWithHeader")
    }
}

builtin! {
    /// `Csv.format` の本体（設計書 03-08「Csv」）。
    name = "Csv.format",
    pure fn format(ctx, arg0: Value<'e>) -> Value<'e> {
        write_csv(&ctx, arg0, ',', "Csv.format")
    }
}

builtin! {
    /// `Csv.formatWith` の本体。ASCII でない区切りも書く（設計書 03-08「Csv」）。
    name = "Csv.formatWith",
    pure fn format_with(ctx, arg0: Value<'e>, arg1: Value<'e>) -> Value<'e> {
        write_csv(&ctx, arg0, delimiter(arg1, false, "Csv.formatWith")?, "Csv.formatWith")
    }
}

fn delimiter(value: Value<'_>, ascii: bool, function: &'static str) -> Result<char, Stop> {
    let c = value
        .as_char()
        .ok_or_else(|| Stop::Internal("CSV delimiter is not Character".into()))?;
    if matches!(c, '"' | '\r' | '\n') || (ascii && !c.is_ascii()) {
        return Err(Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
            function,
            argument: 1,
        }));
    }
    Ok(c)
}

fn error_value<'e>(
    ctx: &ValueCtx<'e>,
    line: usize,
    message: &str,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let mut fields = [Value::Unit; parse_error::LEN];
    *fields
        .get_mut(parse_error::LINE)
        .ok_or_else(|| Stop::Internal("CSV ParseError line field".into()))? =
        Value::Int(super::integer_count(line)?);
    *fields
        .get_mut(parse_error::MESSAGE)
        .ok_or_else(|| Stop::Internal("CSV ParseError message field".into()))? =
        ctx.alloc_str(message, function)?;
    let error = ctx.alloc_fields(FieldsKind::Ctor, tags::RECORD, &fields)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_ERROR, &[error])
}

#[derive(Clone, Copy)]
enum QuoteState {
    Start,
    Plain,
    Quoted,
    AfterQuote,
}

// Reader は誤りを返さず、line() は LF だけを数える。引用符と物理行だけを
// 追跡し、フィールドの解析は Reader に任せる（実装プラン L23、設計書 03-08「Csv」）。
struct Position {
    state: QuoteState,
    line: usize,
    record_line: usize,
    active: bool,
    previous_cr: bool,
}

impl Position {
    fn new() -> Self {
        Self {
            state: QuoteState::Start,
            line: 1,
            record_line: 1,
            active: false,
            previous_cr: false,
        }
    }

    fn consume(&mut self, bytes: &[u8], delimiter: u8) -> Result<(), Stop> {
        for &b in bytes {
            let newline = matches!(b, b'\r' | b'\n');
            if !self.active && !newline {
                self.record_line = self.line;
                self.active = true;
            }
            self.state = match (self.state, b) {
                (QuoteState::Start, b'"') => QuoteState::Quoted,
                (QuoteState::Quoted, b'"') => QuoteState::AfterQuote,
                (QuoteState::Quoted, _) | (QuoteState::AfterQuote, b'"') => QuoteState::Quoted,
                (_, b) if b == delimiter || newline => QuoteState::Start,
                _ => QuoteState::Plain,
            };
            if newline && !matches!(self.state, QuoteState::Quoted) {
                self.active = false;
            }
            if b == b'\r' || (b == b'\n' && !self.previous_cr) {
                self.line = self
                    .line
                    .checked_add(1)
                    .ok_or_else(|| Stop::Internal("CSV line number overflow".into()))?;
            }
            self.previous_cr = b == b'\r';
        }
        Ok(())
    }
}

fn check_next(len: usize, function: &'static str) -> Result<(), Stop> {
    CheckedLen::elements(super::count(len)?.saturating_add(1), function)?;
    Ok(())
}

fn read_csv<'e>(
    ctx: &ValueCtx<'e>,
    source: Value<'e>,
    delimiter: u8,
    with_header: bool,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let source = ctx
        .str(source)
        .ok_or_else(|| Stop::Internal("CSV input is not String".into()))?;
    let mut input = source.as_bytes();
    let mut first_read = true;
    let mut reader = ReaderBuilder::new().delimiter(delimiter).build();
    let mut position = Position::new();
    let mut buffer = [0u8; 4096];
    let mut field = Vec::new();
    let mut fields = Vec::new();
    let mut rows = Vec::new();
    let mut header: Option<Vec<(Value<'e>, usize)>> = None;
    loop {
        let (status, consumed, written) = reader.read_field(input, &mut buffer);
        let consumed_bytes = input
            .get(..consumed)
            .ok_or_else(|| Stop::Internal("CSV reader input range".into()))?;
        // Reader が読み捨てる先頭の BOM は位置の追跡からも除く。
        // 入力自体からは除かず、Reader が二つ目の BOM まで捨てることを防ぐ。
        let consumed_bytes = if first_read {
            consumed_bytes
                .strip_prefix(b"\xef\xbb\xbf")
                .unwrap_or(consumed_bytes)
        } else {
            consumed_bytes
        };
        first_read = false;
        position.consume(consumed_bytes, delimiter)?;
        input = input
            .get(consumed..)
            .ok_or_else(|| Stop::Internal("CSV reader remaining input range".into()))?;
        if input.is_empty() && matches!(position.state, QuoteState::Quoted) {
            return error_value(ctx, position.record_line, text::UNCLOSED_QUOTE, function);
        }
        CheckedLen::bytes(
            super::count(field.len())?.saturating_add(super::count(written)?),
            function,
        )?;
        field.extend_from_slice(
            buffer
                .get(..written)
                .ok_or_else(|| Stop::Internal("CSV reader output range".into()))?,
        );
        match status {
            ReadFieldResult::InputEmpty | ReadFieldResult::OutputFull => continue,
            ReadFieldResult::End => break,
            ReadFieldResult::Field { record_end } => {
                check_next(fields.len(), function)?;
                fields.push(
                    ctx.alloc_str_utf8(&field, function)?.ok_or_else(|| {
                        Stop::Internal("CSV reader produced invalid UTF-8".into())
                    })?,
                );
                field.clear();
                if !record_end {
                    continue;
                }
                let row = if with_header {
                    if let Some(header) = &header {
                        if fields.len() != header.len() {
                            return error_value(
                                ctx,
                                position.record_line,
                                text::FIELD_COUNT,
                                function,
                            );
                        }
                        // header は鍵の順で保存し、元の列の位置で値を取り出す
                        // （実装プラン L23、runtime::map::map_from_sorted の前提）。
                        CheckedLen::elements(super::count(header.len())?, function)?;
                        let pairs = header
                            .iter()
                            .map(|&(key, index)| {
                                fields
                                    .get(index)
                                    .copied()
                                    .map(|value| (key, value))
                                    .ok_or_else(|| Stop::Internal("CSV header column range".into()))
                            })
                            .collect::<Result<Vec<_>, _>>()?;
                        map::map_from_sorted(ctx, &pairs, function)?
                    } else {
                        let mut sorted: Vec<_> = fields
                            .drain(..)
                            .enumerate()
                            .map(|(i, key)| (key, i))
                            .collect();
                        let mut failure = None;
                        sorted.sort_by(|a, b| match map::compare_keys(ctx, a.0, b.0) {
                            Ok(order) => order,
                            Err(error) => {
                                failure = Some(error);
                                std::cmp::Ordering::Equal
                            }
                        });
                        if let Some(error) = failure {
                            return Err(error);
                        }
                        for pair in sorted.windows(2) {
                            if let [a, b] = pair
                                && map::compare_keys(ctx, a.0, b.0)? == std::cmp::Ordering::Equal
                            {
                                return error_value(
                                    ctx,
                                    position.record_line,
                                    text::DUPLICATE_HEADER,
                                    function,
                                );
                            }
                        }
                        header = Some(sorted);
                        continue;
                    }
                } else {
                    list::from_values(ctx, &fields, function)?
                };
                check_next(rows.len(), function)?;
                rows.push(row);
                fields.clear();
            }
        }
    }
    let rows = list::from_values(ctx, &rows, function)?;
    ctx.alloc_fields(FieldsKind::Ctor, tags::RESULT_OK, &[rows])
}

fn write_csv<'e>(
    ctx: &ValueCtx<'e>,
    rows: Value<'e>,
    delimiter: char,
    function: &'static str,
) -> Result<Value<'e>, Stop> {
    let mut output = StrBuf::new(function);
    for row in list::to_vec(ctx, rows)? {
        let fields = list::to_vec(ctx, row)?;
        for (index, &field) in fields.iter().enumerate() {
            if index != 0 {
                output.push_char(delimiter)?;
            }
            let field = ctx
                .str(field)
                .ok_or_else(|| Stop::Internal("CSV field is not String".into()))?;
            // Reader はファイル先頭の BOM を読み捨てるので、フィールドの内容として
            // 保つには引用符を先に書く（実装プラン L23「往復」）。
            let leading_bom = output.as_str().is_empty() && field.starts_with('\u{feff}');
            let quoted = leading_bom
                || (fields.len() == 1 && field.is_empty())
                || field.contains([delimiter, '"', '\r', '\n']);
            if quoted {
                output.push_char('"')?;
            }
            for c in field.chars() {
                output.push_char(c)?;
                if quoted && c == '"' {
                    output.push_char('"')?;
                }
            }
            if quoted {
                output.push_char('"')?;
            }
        }
        output.push_char('\n')?;
    }
    ctx.alloc_str_buf(output)
}

/// U3 の部分の項目（実装プラン 10-15「部分と番号」）。
pub const DECLS: &[BuiltinDecl] = &[
    parse::DECL,
    parse_with::DECL,
    parse_with_header::DECL,
    format::DECL,
    format_with::DECL,
];

#[cfg(test)]
mod tests {
    // テストの失敗は panic で表す（実装プラン 00-02）。
    #![allow(
        clippy::unwrap_used,
        clippy::indexing_slicing,
        clippy::arithmetic_side_effects
    )]
    // 関門: 03-08 の行・引用符・見出し・区切り・往復の契約を本体の境界で守る。
    // CRLF の二重計数、空の行の生成、列の取り違え、引用符の閉じ忘れの見逃しを捕まえる。
    // 既存の表のテストは本体を呼ばない。L23 の個別指示に従い直接呼び、差し込み口は増やさない。
    // レコードの脱糖と欄の宣言順は tests/l23_csv.rs のスクリプトだけで確かめる。
    use super::*;
    use crate::builtins::funcs::operators::tests::direct;
    use crate::runtime::heap::{Heap, HeapConfig, NoGcCtx};

    fn payload<'e>(ctx: &ValueCtx<'e>, result: Value<'e>, tag: u32) -> Value<'e> {
        assert_eq!(ctx.fields_header(result), Some((FieldsKind::Ctor, tag)));
        ctx.field(result, 0).unwrap()
    }

    fn strings<'e>(ctx: &ValueCtx<'e>, rows: Value<'e>) -> Vec<Vec<String>> {
        list::to_vec(ctx, rows)
            .unwrap()
            .into_iter()
            .map(|row| {
                list::to_vec(ctx, row)
                    .unwrap()
                    .into_iter()
                    .map(|field| ctx.str(field).unwrap().to_owned())
                    .collect()
            })
            .collect()
    }

    fn rows<'e>(ctx: &ValueCtx<'e>, source: &[&[&str]]) -> Value<'e> {
        let rows: Vec<_> = source
            .iter()
            .map(|fields| {
                let fields: Vec<_> = fields
                    .iter()
                    .map(|s| ctx.alloc_str(s, "test").unwrap())
                    .collect();
                list::from_values(ctx, &fields, "test").unwrap()
            })
            .collect();
        list::from_values(ctx, &rows, "test").unwrap()
    }

    fn read<'e>(ctx: &mut NoGcCtx<'e>, source: &str) -> Value<'e> {
        let source = ctx.alloc_str(source, "test").unwrap();
        let result = direct!(ctx, parse, source).unwrap();
        payload(ctx, result, tags::RESULT_OK)
    }

    #[test]
    fn parse_records_with_newlines_quotes_empty_fields_and_unequal_widths() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (source, expected) in [
                ("", vec![]),
                ("\n\r\n\r", vec![]),
                ("a,b\nx,y", vec![vec!["a", "b"], vec!["x", "y"]]),
                ("a,b\nx,y\n", vec![vec!["a", "b"], vec!["x", "y"]]),
                ("a,b\r\nx,y", vec![vec!["a", "b"], vec!["x", "y"]]),
                ("a,b\r\nx,y\r\n", vec![vec!["a", "b"], vec!["x", "y"]]),
                ("a\rb,c\r", vec![vec!["a"], vec!["b", "c"]]),
                ("a\n\nb", vec![vec!["a"], vec!["b"]]),
                ("\r\na\r\n\r\nb,c\r\n", vec![vec!["a"], vec!["b", "c"]]),
                (
                    "a,b,c\nx\ny,z",
                    vec![vec!["a", "b", "c"], vec!["x"], vec!["y", "z"]],
                ),
                (
                    "\"a\nb\",\"c\"\"d\"\r\n\"é\r\n😀\",\"x\ry\"",
                    vec![vec!["a\nb", "c\"d"], vec!["é\r\n😀", "x\ry"]],
                ),
                ("\"\"", vec![vec![""]]),
                (
                    ",\n,,\nx,",
                    vec![vec!["", ""], vec!["", "", ""], vec!["x", ""]],
                ),
                ("a\"b,\"c\"\"d\"", vec![vec!["a\"b", "c\"d"]]),
                ("\u{feff}a,b", vec![vec!["a", "b"]]),
                ("\u{feff}\u{feff}a,b", vec![vec!["\u{feff}a", "b"]]),
            ] {
                let actual = read(ctx, source);
                assert_eq!(strings(ctx, actual), expected, "{source:?}");
            }
        });
    }

    #[test]
    fn parse_errors_point_to_record_start_across_blank_lines_and_multiline_fields() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for (source, header, line, reason) in [
                ("\"unfinished", false, 1, text::UNCLOSED_QUOTE),
                ("a\n\"unfinished", false, 2, text::UNCLOSED_QUOTE),
                (
                    "a\r\n\r\n\"first\nsecond\r\nthird",
                    false,
                    3,
                    text::UNCLOSED_QUOTE,
                ),
                ("a\r\r\"first\rsecond", false, 3, text::UNCLOSED_QUOTE),
                ("\n\"first\nsecond", false, 2, text::UNCLOSED_QUOTE),
                ("h1,h2\n\"first\nsecond", true, 2, text::UNCLOSED_QUOTE),
                ("a,a\n1,2", true, 1, text::DUPLICATE_HEADER),
                ("\r\n\r\na,a", true, 3, text::DUPLICATE_HEADER),
                ("\"a\",a", true, 1, text::DUPLICATE_HEADER),
                (",", true, 1, text::DUPLICATE_HEADER),
                ("a,b\n1", true, 2, text::FIELD_COUNT),
                ("a,b\n1,2,3", true, 2, text::FIELD_COUNT),
                ("a,b\r\n\r\n\"first\nsecond\"", true, 3, text::FIELD_COUNT),
                ("a,b\r\r\"first\rsecond\",x,y", true, 3, text::FIELD_COUNT),
            ] {
                let input = ctx.alloc_str(source, "test").unwrap();
                let result = if header {
                    direct!(ctx, parse_with_header, input)
                } else {
                    direct!(ctx, parse, input)
                }
                .unwrap();
                let error = payload(ctx, result, tags::RESULT_ERROR);
                assert_eq!(
                    ctx.fields_header(error),
                    Some((FieldsKind::Ctor, tags::RECORD))
                );
                assert_eq!(ctx.fields_len(error), Some(2));
                assert_eq!(
                    ctx.field(error, 0).unwrap().as_int(),
                    Some(line),
                    "{source:?}"
                );
                assert_eq!(
                    ctx.str(ctx.field(error, 1).unwrap()),
                    Some(reason),
                    "{source:?}"
                );
            }
        });
    }

    #[test]
    fn headers_make_sorted_maps_and_accept_empty_input_and_header_only() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            for source in ["", "\n\r\n", "a,b", "a,b\n"] {
                let source = ctx.alloc_str(source, "test").unwrap();
                let result = direct!(ctx, parse_with_header, source).unwrap();
                assert_eq!(
                    list::len(ctx, payload(ctx, result, tags::RESULT_OK)).unwrap(),
                    0
                );
            }
            let input = ctx
                .alloc_str("z,é,a,😀\r\nZ,E,A,D\r\nzz,ee,aa,dd", "test")
                .unwrap();
            let result = direct!(ctx, parse_with_header, input).unwrap();
            let actual = list::to_vec(ctx, payload(ctx, result, tags::RESULT_OK)).unwrap();
            assert_eq!(actual.len(), 2);
            for (row, expected) in actual.into_iter().zip([
                vec![("a", "A"), ("z", "Z"), ("é", "E"), ("😀", "D")],
                vec![("a", "aa"), ("z", "zz"), ("é", "ee"), ("😀", "dd")],
            ]) {
                let actual: Vec<_> = map::map_to_vec(ctx, row)
                    .unwrap()
                    .into_iter()
                    .map(|(k, v)| (ctx.str(k).unwrap(), ctx.str(v).unwrap()))
                    .collect();
                assert_eq!(actual, expected);
                for (key, value) in expected {
                    let key = ctx.alloc_str(key, "test").unwrap();
                    assert_eq!(
                        ctx.str(map::map_get(ctx, row, key).unwrap().unwrap()),
                        Some(value)
                    );
                }
            }
        });
    }

    #[test]
    fn format_quotes_special_fields_and_round_trips_comma_and_tab() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let input = rows(
                ctx,
                &[
                    &["a,b", "c\"d", "e\nf", "g\rh", "é😀", "x\ty"],
                    &[""],
                    &["", ""],
                ],
            );
            for (delimiter, expected) in [
                (
                    ',',
                    "\"a,b\",\"c\"\"d\",\"e\nf\",\"g\rh\",é😀,x\ty\n\"\"\n,\n",
                ),
                (
                    '\t',
                    "a,b\t\"c\"\"d\"\t\"e\nf\"\t\"g\rh\"\té😀\t\"x\ty\"\n\"\"\n\t\n",
                ),
            ] {
                let out = if delimiter == ',' {
                    direct!(ctx, format, input)
                } else {
                    direct!(ctx, format_with, input, Value::Char(delimiter))
                }
                .unwrap();
                assert_eq!(ctx.str(out), Some(expected));
                let back = if delimiter == ',' {
                    direct!(ctx, parse, out)
                } else {
                    direct!(ctx, parse_with, out, Value::Char(delimiter))
                }
                .unwrap();
                assert!(
                    crate::runtime::equal::values_equal(
                        ctx,
                        input,
                        payload(ctx, back, tags::RESULT_OK)
                    )
                    .unwrap()
                );
            }
            for (input, expected) in [
                (rows(ctx, &[]), ""),
                (rows(ctx, &[&[]]), "\n"),
                (rows(ctx, &[&[""]]), "\"\"\n"),
            ] {
                let out = direct!(ctx, format, input).unwrap();
                assert_eq!(ctx.str(out), Some(expected));
                let out = direct!(ctx, format_with, input, Value::Char('\t')).unwrap();
                assert_eq!(ctx.str(out), Some(expected));
            }
            let bom = rows(ctx, &[&["\u{feff}data", "end"]]);
            let out = direct!(ctx, format, bom).unwrap();
            let result = direct!(ctx, parse, out).unwrap();
            assert!(
                crate::runtime::equal::values_equal(
                    ctx,
                    bom,
                    payload(ctx, result, tags::RESULT_OK)
                )
                .unwrap()
            );
        });
    }

    #[test]
    fn delimiters_enforce_argument_domain_and_support_ascii_and_unicode_output() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let input = ctx.alloc_str("a,b", "test").unwrap();
            let rows = rows(ctx, &[&["a、b", "é", "plain"]]);
            for c in ['"', '\r', '\n'] {
                assert_eq!(
                    direct!(ctx, parse_with, input, Value::Char(c)).unwrap_err(),
                    Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                        function: "Csv.parseWith",
                        argument: 1
                    })
                );
                assert_eq!(
                    direct!(ctx, format_with, rows, Value::Char(c)).unwrap_err(),
                    Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                        function: "Csv.formatWith",
                        argument: 1
                    })
                );
            }
            for c in ['、', 'é'] {
                assert_eq!(
                    direct!(ctx, parse_with, input, Value::Char(c)).unwrap_err(),
                    Stop::Runtime(RuntimeError::ArgumentOutOfDomain {
                        function: "Csv.parseWith",
                        argument: 1
                    })
                );
            }
            for (c, source) in [(';', "a;b"), ('|', "a|b"), ('\0', "a\0b")] {
                let input = ctx.alloc_str(source, "test").unwrap();
                let result = direct!(ctx, parse_with, input, Value::Char(c)).unwrap();
                assert_eq!(
                    strings(ctx, payload(ctx, result, tags::RESULT_OK)),
                    vec![vec!["a", "b"]]
                );
            }
            for (c, expected) in [('、', "\"a、b\"、é、plain\n"), ('é', "a、bé\"é\"éplain\n")]
            {
                let out = direct!(ctx, format_with, rows, Value::Char(c)).unwrap();
                assert_eq!(ctx.str(out), Some(expected));
            }
        });
    }

    #[test]
    fn long_fields_preserve_utf8_and_quotes_across_reader_output_chunks() {
        Heap::new(HeapConfig::default()).epoch(|ctx| {
            let field = format!("{}é😀\"\r\n{}", "x".repeat(4095), "y".repeat(5000));
            let input = rows(ctx, &[&[&field, "end"]]);
            let out = direct!(ctx, format, input).unwrap();
            let result = direct!(ctx, parse, out).unwrap();
            assert!(
                crate::runtime::equal::values_equal(
                    ctx,
                    input,
                    payload(ctx, result, tags::RESULT_OK)
                )
                .unwrap()
            );
        });
    }
}
