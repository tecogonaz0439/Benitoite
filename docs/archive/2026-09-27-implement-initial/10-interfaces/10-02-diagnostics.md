# 診断

本章は、診断の内部の表現、診断コードの初めの一覧と文言の型板、診断を組み立てる手段、診断を書き出す関数のシグネチャを定める。設計書の対応する章は[診断エンジン](../../2026-09-27-design-initial/02-impl/02-10-diagnostics.md)である。

## 診断の内部の表現

02-10「診断の内部の表現」の項目を、そのまま構造体の欄にする。実行時エラーの呼び出しの履歴と、処理系の不具合のバックトレースも同じ構造体に持たせ、文章と JSON の両方の形式をこの一つの表現から作る（02-10「JSON の形式」の最後の段落）。

```rust file=src/diag/mod.rs
//! 診断の内部の表現と、診断を組み立てる手段（設計書 02-10）。
//! 文言は codes.rs の表の型板から作り、診断を出す処理に英語の文を直接書かない（ADR 0033）。

pub mod codes;
pub mod render;

pub use codes::{CodeInfo, DiagCode};

use crate::base::Span;

/// 重大度。最小実行版の段は警告を出さない（02-10）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum Severity {
    Error,
    Warning,
}

/// 報告の種類。JSON の `kind` の値に対応する（02-10「JSON の形式」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum ReportKind {
    /// 検査の誤りと警告（`E`・`W` のコード）
    Check,
    /// 処理系の制限（`L` のコード）
    Limit,
    /// 実行時エラー（`R01nn`・`R02nn`）
    Runtime,
    /// 資源の不足（`R09nn`）
    Resource,
    /// 実行の開始前の誤り（`R03nn`）
    Args,
    /// 処理系の不具合（コードなし）
    Internal,
}

/// span とそれに添える短いラベル。ラベルは空でもよい。
#[derive(Clone, PartialEq, Debug)]
pub struct Label {
    pub span: Span,
    pub text: String,
}

/// 呼び出しの履歴の一段の名前（02-10「実行時エラーと資源の不足の報告」）。
#[derive(Clone, PartialEq, Debug)]
pub enum FrameName {
    /// 利用者のトップレベルの関数の名前、または修飾した名前（`List.map`、`Int.floorDiv`）
    Named(String),
    /// 利用者のラムダ。span はラムダを書いた位置。表示は `<lambda ファイル:行:列>`
    Lambda(Span),
}

#[derive(Clone, PartialEq, Debug)]
pub struct TraceFrame {
    pub name: FrameName,
    /// その関数を呼び出した位置。`main` と、prelude のソースの中から呼ばれた段は持たない
    pub call_site: Option<Span>,
}

/// 内側から外側へ並べた呼び出しの履歴。20 段を超えるときは内側 10 段と外側 10 段だけを持ち、
/// 省いた段の数を `omitted` に入れる（ADR 0034）。
#[derive(Clone, PartialEq, Debug)]
pub struct CallTrace {
    pub frames: Vec<TraceFrame>,
    pub omitted: u32,
}

/// 一つの診断・報告。
#[derive(Clone, PartialEq, Debug)]
pub struct Diagnostic {
    pub kind: ReportKind,
    pub severity: Severity,
    /// 処理系の不具合では `None`
    pub code: Option<DiagCode>,
    pub message: String,
    pub primary: Option<Label>,
    pub secondary: Vec<Label>,
    pub notes: Vec<String>,
    pub helps: Vec<String>,
    /// 実行時エラーと資源の不足の呼び出しの履歴
    pub trace: Option<CallTrace>,
    /// 処理系の不具合のバックトレース（取得できたとき）
    pub backtrace: Option<String>,
}

impl Diagnostic {
    pub fn is_error(&self) -> bool {
        self.severity == Severity::Error
    }
}

/// 診断を組み立てる手段。型板の `{名前}` を `arg` で与えた値で置き換える。
///
/// ```ignore
/// let d = DiagBuilder::new(DiagCode::E0401)
///     .arg("expected", "Int")
///     .arg("found", "String")
///     .primary(span)
///     .secondary(decl_span, "declared")
///     .note("because_let_annotation")
///     .build();
/// ```
///
/// `secondary`・`note`・`help`・`primary_label` の第 2 引数は、そのコードの `extras` の鍵である。
/// 鍵が表にないときと、型板の `{名前}` に値がないときは、型板をそのまま残す
/// （ゴールデンテストの期待値と食い違うので、テストで見つかる）。
#[derive(Debug)]
pub struct DiagBuilder {
    code: DiagCode,
    args: Vec<(&'static str, String)>,
    primary: Option<(Span, Option<&'static str>)>,
    secondary: Vec<(Span, &'static str)>,
    notes: Vec<&'static str>,
    helps: Vec<&'static str>,
}

impl DiagBuilder {
    pub fn new(code: DiagCode) -> DiagBuilder {
        DiagBuilder {
            code,
            args: Vec::new(),
            primary: None,
            secondary: Vec::new(),
            notes: Vec::new(),
            helps: Vec::new(),
        }
    }

    pub fn arg(mut self, key: &'static str, value: impl Into<String>) -> DiagBuilder {
        self.args.push((key, value.into()));
        self
    }

    /// 主な位置。ラベルはコードの `label` の型板で作る。
    pub fn primary(mut self, span: Span) -> DiagBuilder {
        self.primary = Some((span, None));
        self
    }

    /// 主な位置。ラベルは `extras` の鍵 `key` の型板で作る。
    pub fn primary_label(mut self, span: Span, key: &'static str) -> DiagBuilder {
        self.primary = Some((span, Some(key)));
        self
    }

    pub fn secondary(mut self, span: Span, key: &'static str) -> DiagBuilder {
        self.secondary.push((span, key));
        self
    }

    pub fn note(mut self, key: &'static str) -> DiagBuilder {
        self.notes.push(key);
        self
    }

    pub fn help(mut self, key: &'static str) -> DiagBuilder {
        self.helps.push(key);
        self
    }

    pub fn build(self) -> Diagnostic {
        let info = self.code.info();
        let fill = |template: &str| codes::fill_template(template, &self.args);
        let extra = |key: &str| {
            let template = info
                .extras
                .iter()
                .find(|(k, _)| *k == key)
                .map_or(key, |(_, t)| *t);
            fill(template)
        };
        let primary = self.primary.map(|(span, key)| Label {
            span,
            text: match key {
                Some(key) => extra(key),
                None => fill(info.label),
            },
        });
        Diagnostic {
            kind: info.kind,
            severity: Severity::Error,
            code: Some(self.code),
            message: fill(info.message),
            primary,
            secondary: self
                .secondary
                .iter()
                .map(|(span, key)| Label {
                    span: *span,
                    text: extra(key),
                })
                .collect(),
            notes: self.notes.iter().map(|key| extra(key)).collect(),
            helps: self.helps.iter().map(|key| extra(key)).collect(),
            trace: None,
            backtrace: None,
        }
    }
}
```

## 診断コードの初めの一覧

02-10「診断コード」の区分に従って番号を振る。一度公開したコードの意味は変えない（ADR 0031）。コードを加えるときは、区分の中の次の番号を使い、本章の表と `codes.rs` を同時に改める。

- `message` は 1 行目の文言、`label` は主な位置のラベルの型板である。
- `extras` は、補助の位置のラベル・注記・修正案に使う型板を、鍵で引く表である。どの鍵をどの誤りで使うかは、各段の作業の文書で定める。
- `explanation` は、v1 の MCP サーバの `explain` で引く説明である（02-10）。最小実行版では表示しない。
- 型板の中の `{名前}` は、`DiagBuilder::arg` で与える値で置き換える。型の名前は型の表示（[型](10-05-types.md)の `Ty` の表示）で、識別子はソースの綴りで与える。
- 型板の中で、コードの字面は `` ` `` で囲む。

```rust file=src/diag/codes.rs
//! 診断コードと文言の型板の表（設計書 02-10「診断コード」「文言の言語」、ADR 0031・0033）。

use super::ReportKind;

/// 一つの診断コードの表の項目。
#[derive(Clone, Copy, Debug)]
pub struct CodeInfo {
    /// `E0401` などのコードの文字列
    pub id: &'static str,
    pub kind: ReportKind,
    pub message: &'static str,
    /// 主な位置のラベルの型板。空文字列ならラベルを付けない
    pub label: &'static str,
    /// 鍵で引く型板（補助の位置のラベル、注記、修正案）
    pub extras: &'static [(&'static str, &'static str)],
    pub explanation: &'static str,
}

/// 診断コード。名前はコードの文字列と同じにする。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum DiagCode {
    // E01: 読み込みと字句
    E0101,
    E0102,
    E0103,
    E0104,
    E0105,
    E0106,
    E0107,
    E0108,
    E0109,
    E0110,
    E0111,
    E0112,
    E0113,
    E0114,
    E0115,
    E0116,
    E0117,
    // E02: 構文
    E0201,
    E0202,
    E0203,
    E0204,
    E0205,
    E0206,
    E0207,
    E0208,
    E0209,
    E0210,
    // E03: 名前
    E0301,
    E0302,
    E0303,
    E0304,
    E0305,
    E0306,
    E0307,
    E0308,
    E0309,
    E0310,
    E0311,
    E0312,
    E0313,
    E0314,
    E0315,
    E0316,
    E0317,
    // E04: 型
    E0401,
    E0402,
    E0403,
    E0404,
    E0405,
    E0406,
    E0407,
    E0408,
    E0409,
    E0410,
    E0411,
    E0412,
    E0413,
    E0414,
    E0415,
    E0416,
    E0417,
    E0418,
    E0419,
    // E05: エフェクト
    E0501,
    E0502,
    // E06: パターン
    E0601,
    E0602,
    // R01: 基本型の演算の実行時エラー
    R0101,
    R0102,
    // R02: IO の実行時エラー
    R0201,
    R0202,
    // R03: 実行の開始前の誤り
    R0301,
    // R09: 資源の不足
    R0901,
    R0902,
    // L01: 処理系の制限
    L0101,
    L0102,
}

impl DiagCode {
    pub fn info(self) -> CodeInfo {
        use ReportKind::{Args, Check, Limit, Resource, Runtime};
        let (id, kind, message, label, extras, explanation): (
            &'static str,
            ReportKind,
            &'static str,
            &'static str,
            &'static [(&'static str, &'static str)],
            &'static str,
        ) = match self {
            // ---- E01: 読み込みと字句 ----
            DiagCode::E0101 => (
                "E0101",
                Check,
                "cannot read file `{path}`",
                "",
                &[("reason", "{reason}")],
                "The source file could not be read. Check the path and the file permissions.",
            ),
            DiagCode::E0102 => (
                "E0102",
                Check,
                "source file is not valid UTF-8",
                "invalid UTF-8 byte sequence",
                &[],
                "Source files must be encoded in UTF-8.",
            ),
            DiagCode::E0103 => (
                "E0103",
                Check,
                "character {char} is not allowed here",
                "not allowed outside literals and comments",
                &[(
                    "allowed",
                    "only printable ASCII characters, spaces, tabs, and newlines may appear outside string literals, character literals, and comments",
                )],
                "Outside literals and comments, only printable ASCII, spaces, tabs, and newlines are allowed, so that invisible or look-alike characters cannot change the meaning of code.",
            ),
            DiagCode::E0104 => (
                "E0104",
                Check,
                "invisible control character {char} is not allowed",
                "",
                &[(
                    "escape",
                    "to include it in a value, write the escape `{escape}` in a string or character literal",
                )],
                "Bidirectional control characters and a byte order mark after the start of the file are not allowed anywhere, even in literals and comments.",
            ),
            DiagCode::E0105 => (
                "E0105",
                Check,
                "unexpected symbol `{symbol}`",
                "not a valid token",
                &[],
                "This symbol is not part of the language.",
            ),
            DiagCode::E0106 => (
                "E0106",
                Check,
                "semicolons are not used",
                "remove this `;`",
                &[("newline", "separate statements with a newline")],
                "Statements are separated by newlines, not semicolons.",
            ),
            DiagCode::E0107 => (
                "E0107",
                Check,
                "carriage return without a following line feed",
                "expected LF after CR",
                &[],
                "Line breaks must be LF or CR LF.",
            ),
            DiagCode::E0108 => (
                "E0108",
                Check,
                "unterminated string literal",
                "this string is not closed on this line",
                &[(
                    "one_line",
                    "a string literal must end on the line where it starts; write `\\n` for a line break",
                )],
                "String literals must be closed with `\"` on the same line.",
            ),
            DiagCode::E0109 => (
                "E0109",
                Check,
                "unterminated character literal",
                "this character literal is not closed",
                &[],
                "Character literals must be closed with `'`.",
            ),
            DiagCode::E0110 => (
                "E0110",
                Check,
                "invalid escape sequence `{escape}`",
                "invalid escape",
                &[
                    (
                        "valid_string",
                        "valid escapes are `\\n`, `\\r`, `\\t`, `\\\\`, `\\\"`, `\\$`, and `\\u{...}`",
                    ),
                    (
                        "valid_char",
                        "valid escapes are `\\n`, `\\r`, `\\t`, `\\\\`, `\\\"`, `\\'`, `\\$`, and `\\u{...}`",
                    ),
                    (
                        "unicode",
                        "`\\u{...}` must contain 1 to 6 hexadecimal digits naming a Unicode scalar value",
                    ),
                ],
                "Only the listed escape sequences may follow `\\`.",
            ),
            DiagCode::E0111 => (
                "E0111",
                Check,
                "`${` is reserved for string interpolation",
                "",
                &[(
                    "escape",
                    "write `\\$` to include a literal `$` followed by `{`",
                )],
                "`${` inside a string literal is reserved for string interpolation in a later version.",
            ),
            DiagCode::E0112 => (
                "E0112",
                Check,
                "empty character literal",
                "",
                &[],
                "A character literal must contain exactly one character.",
            ),
            DiagCode::E0113 => (
                "E0113",
                Check,
                "character literal contains more than one character",
                "",
                &[(
                    "use_string",
                    "use a string literal (\"...\") for text made of more than one character",
                )],
                "A character literal holds exactly one Unicode scalar value. Characters built from several scalar values must be written as strings.",
            ),
            DiagCode::E0114 => (
                "E0114",
                Check,
                "control character {char} must be escaped",
                "",
                &[("escape", "write it as `{escape}`")],
                "Control characters other than tab must be written with an escape sequence inside literals.",
            ),
            DiagCode::E0115 => (
                "E0115",
                Check,
                "malformed integer literal `{text}`",
                "",
                &[
                    (
                        "leading_zero",
                        "decimal literals other than `0` must not start with `0`",
                    ),
                    ("underscore", "`_` must be placed between two digits"),
                    ("digit", "invalid digit for this base"),
                    ("no_digits", "the base prefix must be followed by digits"),
                    (
                        "prefix",
                        "base prefixes must be lowercase: `0x`, `0o`, `0b`",
                    ),
                    (
                        "suffix",
                        "a number must not be directly followed by a letter, a digit of another base, or `_`",
                    ),
                ],
                "Integer literals are decimal, or hexadecimal, octal, or binary with a lowercase prefix.",
            ),
            DiagCode::E0116 => (
                "E0116",
                Check,
                "malformed floating-point literal `{text}`",
                "",
                &[
                    ("missing_digits", "digits are required on both sides of `.`"),
                    (
                        "leading_zero",
                        "the integer part must not start with `0` unless it is `0`",
                    ),
                    ("underscore", "`_` must be placed between two digits"),
                    ("exponent", "the exponent needs at least one digit"),
                    (
                        "suffix",
                        "a number must not be directly followed by a letter or `_`",
                    ),
                    (
                        "second_dot",
                        "a number cannot contain a second `.` followed by digits",
                    ),
                ],
                "Floating-point literals have digits on both sides of `.`, optionally followed by an exponent.",
            ),
            DiagCode::E0117 => (
                "E0117",
                Check,
                "`{word}` is a reserved word",
                "reserved words cannot be used as names",
                &[
                    (
                        "loop",
                        "there are no loop statements; use recursion or functions such as `List.map`, `List.forEach`, and `List.fold`",
                    ),
                    ("break", "there are no loops; use recursion"),
                    (
                        "return",
                        "the value of the last expression in a block is the return value of the function",
                    ),
                    (
                        "other",
                        "this word is reserved for future syntax; choose another name",
                    ),
                ],
                "Reserved words have no meaning yet but cannot be used as identifiers.",
            ),
            // ---- E02: 構文 ----
            DiagCode::E0201 => (
                "E0201",
                Check,
                "expected {expected}, found {found}",
                "unexpected {found}",
                &[],
                "The parser found a token that cannot appear here.",
            ),
            DiagCode::E0202 => (
                "E0202",
                Check,
                "comparison operators cannot be chained",
                "second comparison",
                &[(
                    "and",
                    "write the comparisons separately, such as `a < b && b < c`",
                )],
                "Comparison operators are non-associative.",
            ),
            DiagCode::E0203 => (
                "E0203",
                Check,
                "`.` cannot follow a value",
                "method-call syntax is not supported",
                &[(
                    "pipe",
                    "pass the value with a pipe, such as `xs |> List.map(f)`",
                )],
                "A dot is only used after a module or type name, such as `List.map` or `Shape.Circle`.",
            ),
            DiagCode::E0204 => (
                "E0204",
                Check,
                "`_` can only be a direct argument of a call",
                "not a call argument",
                &[],
                "The placeholder `_` builds a function from a call, such as `clamp(0, _, 100)`.",
            ),
            DiagCode::E0205 => (
                "E0205",
                Check,
                "the function body must start on the same line as its signature",
                "`{` starts a new line here",
                &[("same_line", "put `{` at the end of the previous line")],
                "A newline after the return type ends the declaration, so `{` must be on the same line.",
            ),
            DiagCode::E0206 => (
                "E0206",
                Check,
                "constructor `{name}` without fields must not have parentheses",
                "",
                &[("remove", "remove `()`")],
                "Constructors without fields are declared and written without parentheses.",
            ),
            DiagCode::E0207 => (
                "E0207",
                Check,
                "function names cannot be qualified with a module name",
                "",
                &[("remove", "remove `{module}.` from the name")],
                "Top-level functions are declared with a plain name.",
            ),
            DiagCode::E0208 => (
                "E0208",
                Check,
                "the program is nested too deeply",
                "nesting limit of {limit} reached here",
                &[],
                "The parser limits the depth of nested syntax.",
            ),
            DiagCode::E0209 => (
                "E0209",
                Check,
                "a function type with `uses` must be parenthesized here",
                "",
                &[(
                    "paren",
                    "write the function type in parentheses, such as `fn((fn() -> Unit uses IO), List[Int]) -> Unit`",
                )],
                "`uses` reads as many effect names as possible, so a function type with `uses` inside a list of types must be parenthesized.",
            ),
            DiagCode::E0210 => (
                "E0210",
                Check,
                "`_` cannot be a lambda parameter",
                "",
                &[("name", "use a name that starts with `_`, such as `_unused`")],
                "Unused lambda parameters are named with a leading `_`.",
            ),
            // ---- E03: 名前 ----
            DiagCode::E0301 => (
                "E0301",
                Check,
                "cannot find `{name}` in this scope",
                "not found",
                &[("similar", "a similar name exists: {candidates}")],
                "The name is not bound by a local binding or a top-level function.",
            ),
            DiagCode::E0302 => (
                "E0302",
                Check,
                "cannot find module or type `{name}`",
                "not found",
                &[("similar", "a similar name exists: {candidates}")],
                "The name before `.` must be a prelude module or a type.",
            ),
            DiagCode::E0303 => (
                "E0303",
                Check,
                "`{module}` has no member `{name}`",
                "not found in `{module}`",
                &[
                    ("similar", "a similar name exists: {candidates}"),
                    (
                        "length",
                        "strings have no unit-less length; use `String.byteLength` (bytes) or `String.charCount` (characters)",
                    ),
                    (
                        "slice",
                        "use `String.byteSlice` (byte positions) or `String.charSlice` (character positions)",
                    ),
                    (
                        "index_of",
                        "use `String.byteIndexOf`, which returns a byte position",
                    ),
                    (
                        "unwrap",
                        "there is no `{name}`; use `{module}.unwrapOr` or `match`",
                    ),
                ],
                "The module does not define this name.",
            ),
            DiagCode::E0304 => (
                "E0304",
                Check,
                "`{name}` is {found_kind}, not {expected_kind}",
                "",
                &[(
                    "qualify",
                    "constructors are written with their type name, such as `{suggestion}`",
                )],
                "Each position accepts only one kind of name.",
            ),
            DiagCode::E0305 => (
                "E0305",
                Check,
                "the type `{name}` is defined more than once",
                "redefined here",
                &[("first", "first defined here")],
                "Each top-level type name must be unique.",
            ),
            DiagCode::E0306 => (
                "E0306",
                Check,
                "the function `{name}` is defined more than once",
                "redefined here",
                &[("first", "first defined here")],
                "Each top-level function name must be unique.",
            ),
            DiagCode::E0307 => (
                "E0307",
                Check,
                "`{name}` is already defined by the prelude",
                "",
                &[],
                "Type names cannot reuse the names of prelude types, modules, or effects.",
            ),
            DiagCode::E0308 => (
                "E0308",
                Check,
                "`{name}` cannot be used as a type name",
                "",
                &[(
                    "prelude_ctor",
                    "`Some`, `None`, `Ok`, and `Err` are prelude constructors written without qualification",
                )],
                "These names are reserved for the prelude constructors.",
            ),
            DiagCode::E0309 => (
                "E0309",
                Check,
                "the constructor `{name}` is defined more than once in `{ty}`",
                "redefined here",
                &[("first", "first defined here")],
                "Constructor names must be unique within a type.",
            ),
            DiagCode::E0310 => (
                "E0310",
                Check,
                "the parameter `{name}` is declared more than once",
                "redeclared here",
                &[("first", "first declared here")],
                "Parameter names must be unique within a function or lambda.",
            ),
            DiagCode::E0311 => (
                "E0311",
                Check,
                "`{name}` is bound more than once in the same pattern",
                "bound again here",
                &[("first", "first bound here")],
                "A pattern cannot bind the same variable twice.",
            ),
            DiagCode::E0312 => (
                "E0312",
                Check,
                "the type parameter `{name}` is declared more than once",
                "redeclared here",
                &[("first", "first declared here")],
                "Type parameter names must be unique within a list.",
            ),
            DiagCode::E0313 => (
                "E0313",
                Check,
                "the type parameter `{name}` has the same name as a top-level type or module",
                "",
                &[],
                "Type parameters and effect variables cannot reuse top-level uppercase names.",
            ),
            DiagCode::E0314 => (
                "E0314",
                Check,
                "`{name}` is an effect and cannot be used as a type",
                "",
                &[(
                    "uses_only",
                    "effects and effect variables can only appear after `uses`",
                )],
                "Effect names and effect variables are not types.",
            ),
            DiagCode::E0315 => (
                "E0315",
                Check,
                "`{name}` is not an effect",
                "expected an effect name or an effect variable",
                &[],
                "Only `IO` and effect variables declared with `effect` can appear after `uses`.",
            ),
            DiagCode::E0316 => (
                "E0316",
                Check,
                "`{name}` is not an effect",
                "read as part of the `uses` list",
                &[(
                    "paren",
                    "if `{name}` belongs to the surrounding list, parenthesize the function type that has `uses`, such as `fn((fn() -> Unit uses IO), Int) -> Unit`",
                )],
                "`uses` reads as many comma-separated names as possible, so a following list element may be taken as an effect.",
            ),
            DiagCode::E0317 => (
                "E0317",
                Check,
                "`{name}` is written without a type name",
                "",
                &[("unqualified", "write `{name}` instead of `{module}.{name}`")],
                "The constructors `Some`, `None`, `Ok`, and `Err` are written without qualification.",
            ),
            // ---- E04: 型 ----
            DiagCode::E0401 => (
                "E0401",
                Check,
                "mismatched types",
                "expected `{expected}`, found `{found}`",
                &[
                    ("declared", "expected because of this"),
                    (
                        "because_call_arg",
                        "argument {index} must match the parameter type of the called function",
                    ),
                    (
                        "because_if_branches",
                        "the branches of `if` must have compatible types",
                    ),
                    (
                        "because_if_no_else",
                        "`if` without `else` must have type `Unit`",
                    ),
                    ("because_condition", "a condition must have type `Bool`"),
                    (
                        "because_match_arms",
                        "the arms of `match` must have compatible types",
                    ),
                    (
                        "because_pattern",
                        "a pattern must match the type of the value being matched",
                    ),
                    (
                        "because_list",
                        "the elements of a list must have compatible types",
                    ),
                    (
                        "because_let_annotation",
                        "the value must match the type annotation",
                    ),
                    (
                        "because_lambda_return",
                        "the lambda body must match the annotated return type",
                    ),
                    (
                        "because_fn_body",
                        "the function body must match the declared return type",
                    ),
                    (
                        "because_operands",
                        "both operands of `{op}` must have the same type",
                    ),
                    (
                        "because_logic",
                        "the operands of `{op}` must have type `Bool`",
                    ),
                    (
                        "because_int_operands",
                        "the operands of `{op}` must have type `Int`",
                    ),
                    ("because_call", "the called value must be a function"),
                    (
                        "float_literal",
                        "write a floating-point literal such as `{literal}.0`",
                    ),
                    (
                        "to_string",
                        "convert the value with `{function}` before joining it with `+`",
                    ),
                    (
                        "to_string_any",
                        "convert the other value to a `String` before joining it with `+`",
                    ),
                ],
                "Two types that must be equal are different.",
            ),
            DiagCode::E0402 => (
                "E0402",
                Check,
                "this function takes {expected} argument(s) but {found} were supplied",
                "",
                &[("declared", "function declared here")],
                "Functions are not curried; supply every argument, or use `_` placeholders to build a new function.",
            ),
            DiagCode::E0403 => (
                "E0403",
                Check,
                "a value of type `{found}` is not a function",
                "cannot be called",
                &[],
                "Only functions can be called.",
            ),
            DiagCode::E0404 => (
                "E0404",
                Check,
                "a type would contain itself",
                "this makes the type infinite",
                &[],
                "A type variable cannot be equal to a type that contains it.",
            ),
            DiagCode::E0405 => (
                "E0405",
                Check,
                "`{op}` cannot be applied to `{ty}`",
                "",
                &[
                    ("allowed", "`{op}` works on {allowed}"),
                    (
                        "to_string",
                        "convert the value with `{function}` before joining it with `+`",
                    ),
                    (
                        "to_string_any",
                        "convert the other value to a `String` before joining it with `+`",
                    ),
                ],
                "Arithmetic and ordering operators work only on the listed basic types.",
            ),
            DiagCode::E0406 => (
                "E0406",
                Check,
                "values of type `{ty}` cannot be compared with `{op}`",
                "",
                &[(
                    "why",
                    "types that contain functions or `IoError` cannot be compared with `==` or `!=`",
                )],
                "Equality is defined only for types without functions and opaque prelude types.",
            ),
            DiagCode::E0407 => (
                "E0407",
                Check,
                "the type of this expression cannot be determined",
                "",
                &[("annotate", "add a type annotation")],
                "An operator needs its operand type to be known by the end of the function body.",
            ),
            DiagCode::E0408 => (
                "E0408",
                Check,
                "integer literal is out of range for `Int`",
                "",
                &[(
                    "range",
                    "`Int` values range from -9223372036854775808 to 9223372036854775807",
                )],
                "Integer literals must fit in a 64-bit signed integer.",
            ),
            DiagCode::E0409 => (
                "E0409",
                Check,
                "floating-point literal is too large for `Float`",
                "",
                &[],
                "The literal rounds to infinity.",
            ),
            DiagCode::E0410 => (
                "E0410",
                Check,
                "`{name}` expects {expected} type argument(s) but {found} were given",
                "",
                &[],
                "Every type argument of a generic type must be written.",
            ),
            DiagCode::E0411 => (
                "E0411",
                Check,
                "the type `{name}` has no constructors",
                "",
                &[("add", "add at least one constructor")],
                "A type declaration needs at least one constructor.",
            ),
            DiagCode::E0412 => (
                "E0412",
                Check,
                "the constructor `{name}` has {expected} field(s) but the pattern has {found}",
                "",
                &[],
                "A constructor pattern needs one sub-pattern per field.",
            ),
            DiagCode::E0413 => (
                "E0413",
                Check,
                "the constructor `{name}` has no fields and is written without parentheses",
                "",
                &[("remove", "remove `()`")],
                "Constructors without fields are values, not functions.",
            ),
            DiagCode::E0414 => (
                "E0414",
                Check,
                "no `main` function",
                "",
                &[("define", "define `fn main() -> Unit uses IO { ... }`")],
                "A program starts by calling `main`.",
            ),
            DiagCode::E0415 => (
                "E0415",
                Check,
                "`main` has an invalid signature",
                "",
                &[
                    ("params", "`main` takes no parameters"),
                    (
                        "type_params",
                        "`main` cannot have type parameters or effect variables",
                    ),
                    ("ret", "`main` must return `Unit` or `Result[Unit, String]`"),
                    ("effects", "`main` can only use `IO`"),
                ],
                "`main` has no parameters, returns `Unit` or `Result[Unit, String]`, and uses at most `IO`.",
            ),
            DiagCode::E0416 => (
                "E0416",
                Check,
                "the value of this expression is not used",
                "this has type `{found}`, not `Unit`",
                &[("discard", "write `let _ = ...` to discard the value")],
                "An expression statement that is not the last in a block must have type `Unit`.",
            ),
            DiagCode::E0417 => (
                "E0417",
                Check,
                "a `uses` list can contain at most one effect variable",
                "",
                &[],
                "Use the same effect variable for several parameters to combine their effects.",
            ),
            DiagCode::E0418 => (
                "E0418",
                Check,
                "the effect variable `{name}` does not appear in any parameter type",
                "",
                &[],
                "An effect variable must be determined by a parameter type.",
            ),
            DiagCode::E0419 => (
                "E0419",
                Check,
                "`{name}` appears more than once in `uses`",
                "",
                &[],
                "Each effect is listed once.",
            ),
            // ---- E05: エフェクト ----
            DiagCode::E0501 => (
                "E0501",
                Check,
                "this function performs `{effect}` but does not declare it",
                "`{effect}` happens here",
                &[
                    ("declared", "declared here"),
                    (
                        "add_uses",
                        "add `uses {effect}` to the signature, or move this call to a function that uses `{effect}`",
                    ),
                ],
                "A function body can only perform the effects listed after `uses`.",
            ),
            DiagCode::E0502 => (
                "E0502",
                Check,
                "this lambda performs `{effect}` but its `uses` does not include it",
                "`{effect}` happens here",
                &[("declared", "declared here")],
                "A lambda with `uses` can only perform the listed effects.",
            ),
            // ---- E06: パターン ----
            DiagCode::E0601 => (
                "E0601",
                Check,
                "`match` does not cover every value",
                "`{witness}` is not matched",
                &[("add_arm", "add an arm for `{witness}`, or a `_` arm")],
                "Every possible value must be matched by some arm.",
            ),
            DiagCode::E0602 => (
                "E0602",
                Check,
                "this arm can never be selected",
                "unreachable arm",
                &[("covering", "this earlier arm already matches the values")],
                "Earlier arms match every value this arm matches.",
            ),
            // ---- R01: 基本型の演算 ----
            DiagCode::R0101 => (
                "R0101",
                Runtime,
                "division by zero",
                "",
                &[],
                "Integer division and remainder by zero stop the program.",
            ),
            DiagCode::R0102 => (
                "R0102",
                Runtime,
                "integer overflow",
                "",
                &[],
                "The result does not fit in a 64-bit signed integer.",
            ),
            // ---- R02: IO ----
            DiagCode::R0201 => (
                "R0201",
                Runtime,
                "failed to write to standard output",
                "",
                &[("reason", "{reason}")],
                "Writing to standard output failed, for example because the reading side of a pipe was closed.",
            ),
            DiagCode::R0202 => (
                "R0202",
                Runtime,
                "failed to write to standard error",
                "",
                &[("reason", "{reason}")],
                "Writing to standard error failed.",
            ),
            // ---- R03: 実行の開始前 ----
            DiagCode::R0301 => (
                "R0301",
                Args,
                "command-line argument {index} is not valid UTF-8",
                "",
                &[],
                "Arguments passed to a script must be valid UTF-8.",
            ),
            // ---- R09: 資源の不足 ----
            DiagCode::R0901 => (
                "R0901",
                Resource,
                "the call stack is too deep",
                "",
                &[
                    ("frames", "{frames} calls were active"),
                    (
                        "raise",
                        "use tail calls, or raise the limit with `--max-call-stack`",
                    ),
                ],
                "Nested non-tail calls exceeded the call stack limit.",
            ),
            DiagCode::R0902 => (
                "R0902",
                Resource,
                "`{function}` would create a value that is too large",
                "",
                &[(
                    "size",
                    "the result would have {size} {unit}; the limit is {limit}",
                )],
                "A single operation cannot build a string larger than 2^30 bytes or a list longer than 2^24 elements.",
            ),
            // ---- L01: 処理系の制限 ----
            DiagCode::L0101 => (
                "L0101",
                Limit,
                "the function `{name}` needs too many registers",
                "",
                &[(
                    "limit",
                    "a function can use at most 65535 registers; split it into smaller functions",
                )],
                "The bytecode addresses registers with 16 bits.",
            ),
            DiagCode::L0102 => (
                "L0102",
                Limit,
                "the function `{name}` has too many constants",
                "",
                &[(
                    "limit",
                    "a function can have at most 65536 constants; split it into smaller functions",
                )],
                "The bytecode addresses constants with 16 bits.",
            ),
        };
        CodeInfo {
            id,
            kind,
            message,
            label,
            extras,
            explanation,
        }
    }
}

/// 型板の `{名前}` を値で置き換える。値のない `{名前}` はそのまま残す。
pub fn fill_template(template: &str, args: &[(&'static str, String)]) -> String {
    let mut out = String::with_capacity(template.len());
    let mut rest = template;
    while let Some(open) = rest.find('{') {
        let (before, from_open) = rest.split_at(open);
        out.push_str(before);
        let after_open = from_open.get(1..).unwrap_or("");
        match after_open.find('}') {
            Some(close) => {
                let key = after_open.get(..close).unwrap_or("");
                let is_key =
                    !key.is_empty() && key.chars().all(|c| c.is_ascii_alphanumeric() || c == '_');
                match args.iter().find(|(k, _)| *k == key) {
                    Some((_, value)) if is_key => {
                        out.push_str(value);
                        rest = after_open.get(close.saturating_add(1)..).unwrap_or("");
                    }
                    _ => {
                        out.push('{');
                        rest = after_open;
                    }
                }
            }
            None => {
                out.push_str(from_open);
                rest = "";
            }
        }
    }
    out.push_str(rest);
    out
}

/// 診断コードの表に属さない、報告の定型の文（ADR 0033）。
pub mod text {
    /// 実行時エラーの履歴の見出し（02-10）
    pub const TRACE_HEADER: &str = "call trace (innermost first):";
    /// 末尾呼び出しの注記
    pub const TRACE_TAIL_NOTE: &str = "functions left by tail calls are not shown";
    /// 省いた段の行。`{count}` を置き換える
    pub const TRACE_OMITTED: &str = "... {count} frames omitted ...";
    /// 書き出しの失敗を先の報告に加えるときの注記。`{stream}` と `{reason}` を置き換える
    pub const FLUSH_FAILED_NOTE: &str = "also failed to write to {stream}: {reason}";
    /// 文章の形式で 50 件を超えたときの行。`{count}` を置き換える
    pub const TOO_MANY: &str = "{count} more errors not shown";
    /// 検査の誤りの件数の行。`{verb}` は `run` か `check`
    pub const SUMMARY_ONE: &str = "could not {verb} {file} due to 1 previous error";
    pub const SUMMARY_MANY: &str = "could not {verb} {file} due to {count} previous errors";
    /// 処理系の不具合の報告（02-10「処理系の不具合と処理系の制限の報告」）
    pub const INTERNAL_MESSAGE: &str = "internal compiler error";
    pub const INTERNAL_VERSION: &str = "benitoite {version}";
    pub const INTERNAL_STAGE: &str = "the error occurred in the {stage} stage";
    pub const INTERNAL_PANIC: &str = "panic: {message} at {location}";
    pub const INTERNAL_REPORT: &str =
        "this is a bug in the implementation; please report it with the script that caused it";
}
```

`DiagBuilder::build` は重大度を常に `Error` にする。最小実行版は警告を出さないからである（02-10）。

## 診断の書き出し

次の関数の中身は作業 T05 が書く。書式は 02-10「文章の形式」「JSON の形式」「実行時エラーと資源の不足の報告」に従う。

```rust sig=src/diag/render.rs
use crate::base::SourceTable;
use super::Diagnostic;

/// 文章の形式の選択肢。
#[derive(Clone, Copy, Debug)]
pub struct TextOptions {
    /// 色を付けるか。CLI が、標準エラー出力が端末で `NO_COLOR` がないときに true にする
    pub color: bool,
}

/// 検査の誤りの一覧を、文章の形式にする。段の順・位置の順に並べ替えずに、渡された順に書く
/// （並べるのは呼び出し側。10-09 の `check`）。50 件を超えた分は書かずに件数を示し、
/// 最後に誤りの件数の行を書く。`verb` は `"run"` か `"check"`、`file` はスクリプトの表示名。
pub fn render_check_text(diags: &[Diagnostic], sources: &SourceTable, verb: &str, file: &str, opts: TextOptions) -> String;

/// 一件の診断・報告を文章の形式にする（末尾に空行を含めない改行で終える）。
/// 実行時エラー、資源の不足、処理系の不具合、処理系の制限、コマンドライン引数の誤りに使う。
pub fn render_one_text(diag: &Diagnostic, sources: &SourceTable, opts: TextOptions) -> String;

/// 一件の診断・報告を、JSON のオブジェクト一つの一行にする（末尾に改行を付けない）。
pub fn render_json_line(diag: &Diagnostic, sources: &SourceTable) -> String;
```

JSON の文字列の書き出しは、依存するクレートを使わずに手で書く（[実装の規約](../00-common/00-02-conventions.md)の「依存するクレート」）。文字列の中の `"`・`\`・制御文字（U+0000〜U+001F）をエスケープし、それ以外の文字はそのまま UTF-8 で書く。オブジェクトの項目の順は、02-10 の表の順（`kind`・`severity`・`code`・`message`・`primary`・`secondary`・`notes`・`helps`）の後に、あれば `trace`・`traceOmitted`・`backtrace` を続ける。ゴールデンテストは JSON の文字列どうしを比べるので、この順と、`:` と `,` の後に空白を入れないことを守る。
