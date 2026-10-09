//! 診断コードと文言の型板の表（設計書 02-10「診断コード」「文言の言語」、ADR 0031・0033・0035）。
//! 番号の付け方と各コードを出す段は、実装プラン 10-02「診断コードの表」「コードの一覧」で定める。

use super::{ReportKind, Severity};

/// 一つの診断コードの表の項目。
#[derive(Clone, Copy, Debug)]
pub struct CodeInfo {
    /// `E0401` などのコードの文字列
    pub id: &'static str,
    pub kind: ReportKind,
    pub severity: Severity,
    pub message: &'static str,
    /// 主な位置のラベルの型板。空文字列ならラベルを付けない
    pub label: &'static str,
    /// 鍵で引く型板（補助の位置のラベル、注記、修正案）
    pub extras: &'static [(&'static str, &'static str)],
    /// `extras` の鍵のうち、置き換えを持つ修正案に使うもの（02-10「修正案」）
    pub fixes: &'static [&'static str],
    /// コードの説明（MCP の道具 `explain` が引く。02-10）
    pub explanation: &'static str,
}

/// 廃止したコード。番号を使い回さない（ADR 0031、実装プラン 10-02「番号の付け方」）。
pub const RETIRED: &[&str] = &[
    "E0111", "E0117", "E0205", "E0307", "E0308", "E0317", "E0444",
];

/// 重大度はコードの頭の文字で決まる（`W` は警告）。
fn severity_of(id: &str) -> Severity {
    if id.starts_with('W') {
        Severity::Warning
    } else {
        Severity::Error
    }
}

macro_rules! diag_codes {
    ($(
        $code:ident $kind:ident $message:literal $label:literal
        [$($key:ident : $text:literal),* $(,)?]
        $(fix [$($fix:ident),* $(,)?])?
        $explanation:literal;
    )*) => {
        /// 診断コード。名前はコードの文字列と同じにする。
        #[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
        pub enum DiagCode {
            $($code,)*
        }

        /// すべてのコード（表の順）。
        pub const ALL: &[DiagCode] = &[$(DiagCode::$code,)*];

        impl DiagCode {
            pub fn info(self) -> CodeInfo {
                match self {
                    $(DiagCode::$code => CodeInfo {
                        id: stringify!($code),
                        kind: ReportKind::$kind,
                        severity: severity_of(stringify!($code)),
                        message: $message,
                        label: $label,
                        extras: &[$((stringify!($key), $text)),*],
                        fixes: &[$($(stringify!($fix)),*)?],
                        explanation: $explanation,
                    },)*
                }
            }
        }
    };
}

impl DiagCode {
    /// コードの文字列から引く（MCP の道具 `explain` とテストが使う）。廃止したコードと知らない文字列は `None`。
    pub fn from_id(id: &str) -> Option<DiagCode> {
        ALL.iter().copied().find(|code| code.info().id == id)
    }
}

diag_codes! {
    // ---- E01: 読み込みと字句 ----
    E0101 Check "cannot read file `{path}`" ""
        [reason: "{reason}", imported: "the module is imported here"]
        "The source file could not be read. Check the path and the file permissions. A file larger than 256 MiB, or a file that makes all sources of the program larger than 512 MiB, is also reported with this code.";
    E0102 Check "source file is not valid UTF-8" "invalid UTF-8 byte sequence" []
        "Source files must be encoded in UTF-8.";
    E0103 Check "character {char} is not allowed here" "not allowed outside literals and comments"
        [allowed: "only printable ASCII characters, spaces, tabs, and newlines may appear outside string literals, character literals, and comments"]
        "Outside literals and comments, only printable ASCII, spaces, tabs, and newlines are allowed, so that invisible or look-alike characters cannot change the meaning of code.";
    E0104 Check "invisible control character {char} is not allowed" ""
        [escape: "to include it in a value, write the escape `{escape}` in a string or character literal"]
        "Bidirectional control characters and a byte order mark after the start of the file are not allowed anywhere, even in literals, comments, and the shebang line.";
    E0105 Check "unexpected symbol `{symbol}`" "not a valid token" []
        "This symbol is not part of the language.";
    E0106 Check "semicolons are not used" "remove this `;`"
        [newline: "separate statements with a newline"]
        fix [newline]
        "Statements are separated by newlines, not semicolons.";
    E0107 Check "carriage return without a following line feed" "expected LF after CR" []
        "Line breaks must be LF or CR LF.";
    E0108 Check "unterminated string literal" "this string is not closed on this line"
        [one_line: "a string literal must end on the line where it starts; write `\\n` for a line break",
         multi_line: "for text with line breaks, use a multi-line string that starts and ends with `\"\"\"`"]
        "String literals must be closed with `\"` on the same line. Multi-line strings are written with `\"\"\"`.";
    E0109 Check "unterminated character literal" "this character literal is not closed" []
        "Character literals must be closed with `'`.";
    E0110 Check "invalid escape sequence `{escape}`" "invalid escape"
        [valid_string: "valid escapes are `\\n`, `\\r`, `\\t`, `\\\\`, `\\\"`, `\\$`, and `\\u{...}`",
         valid_char: "valid escapes are `\\n`, `\\r`, `\\t`, `\\\\`, `\\\"`, `\\'`, `\\$`, and `\\u{...}`",
         unicode: "`\\u{...}` must contain 1 to 6 hexadecimal digits naming a Unicode scalar value"]
        "Only the listed escape sequences may follow `\\`.";
    E0112 Check "empty character literal" "" []
        "A character literal must contain exactly one character.";
    E0113 Check "character literal contains more than one character" ""
        [use_string: "use a string literal (\"...\") for text made of more than one character"]
        fix [use_string]
        "A character literal holds exactly one Unicode scalar value. Characters built from several scalar values must be written as strings.";
    E0114 Check "control character {char} must be escaped" ""
        [escape: "write it as `{escape}`"]
        fix [escape]
        "Control characters other than tab must be written with an escape sequence inside literals.";
    E0115 Check "malformed integer literal `{text}`" ""
        [leading_zero: "decimal literals other than `0` must not start with `0`",
         underscore: "`_` must be placed between two digits",
         digit: "invalid digit for this base",
         no_digits: "the base prefix must be followed by digits",
         prefix: "base prefixes must be lowercase: `0x`, `0o`, `0b`",
         suffix: "a number must not be directly followed by a letter, a digit of another base, or `_`; separate words with a space, such as `2 mod 3`"]
        "Integer literals are decimal, or hexadecimal, octal, or binary with a lowercase prefix.";
    E0116 Check "malformed floating-point literal `{text}`" ""
        [missing_digits: "digits are required on both sides of `.`",
         leading_zero: "the integer part must not start with `0` unless it is `0`",
         underscore: "`_` must be placed between two digits",
         exponent: "the exponent needs at least one digit",
         suffix: "a number must not be directly followed by a letter or `_`; separate words with a space, such as `2 mod 3`",
         second_dot: "a number cannot contain a second `.` followed by digits"]
        "Floating-point literals have a decimal point or an exponent. Each part must contain digits.";
    E0118 Check "empty string interpolation" "`${}` contains no expression"
        [escape: "write `\\$` to include a literal `$` followed by `{`"]
        "An interpolation `${...}` must contain an expression.";
    E0119 Check "string interpolation is not closed on this line" "this `${` is not closed"
        [one_line: "an interpolation must end with `}` on the line where it starts, also inside multi-line strings"]
        "The expression of an interpolation is written on one line and closed with `}`.";
    E0120 Check "comments are not allowed inside string interpolation" ""
        [move: "move the comment outside the string literal"]
        "`//` inside `${...}` would hide the rest of the line, so comments cannot be written there.";
    E0121 Check "text after the opening `\"\"\"` of a multi-line string" ""
        [newline: "start the text on the line after `\"\"\"`"]
        fix [newline]
        "The first line of a multi-line string starts on the line after the opening `\"\"\"`.";
    E0122 Check "this line does not start with the indentation of the closing `\"\"\"`" ""
        [closing: "the closing `\"\"\"` is here",
         same_chars: "indent the line with the same spaces or tabs as the closing line"]
        "Every non-blank line of a multi-line string must start with the indentation of the closing line. The indentation is removed from every line.";
    E0123 Check "unterminated multi-line string" "this string is not closed"
        [close: "close the string with `\"\"\"` at the start of a line after indentation"]
        "A multi-line string ends with `\"\"\"` after indentation at the start of a line. The expression may continue after the closing quotes.";
    E0124 Check "malformed Decimal literal `{text}`" ""
        [exponent: "a Decimal literal cannot have an exponent",
         suffix_case: "the Decimal suffix is a lowercase `m`",
         base: "a Decimal literal must be written in decimal",
         missing_digits: "digits are required on both sides of `.`",
         leading_zero: "the integer part must not start with `0` unless it is `0`",
         underscore: "`_` must be placed between two digits",
         suffix: "`m` must not be directly followed by a letter, a digit, or `_`; separate words with a space"]
        fix [suffix_case]
        "Decimal literals are decimal numbers followed by a lowercase `m`, such as `12.50m`.";
    E0125 Check "cannot write formatted file `{path}`" ""
        [reason: "{reason}", temp_left: "the temporary file `{temp}` could not be removed"]
        "`benitoite fmt` writes the formatted source to a temporary file in the same directory and renames it over the original file. Writing or renaming failed, so the original file was left unchanged. Check the permissions of the file and its directory.";

    // ---- E02: 構文 ----
    E0201 Check "expected {expected}, found {found}" "unexpected {found}" []
        "The parser found a token that cannot appear here.";
    E0202 Check "comparison operators cannot be chained" "second comparison"
        [and: "write the comparisons separately, such as `a < b and b < c`"]
        fix [and]
        "Comparison operators are non-associative.";
    E0203 Check "`.` cannot follow a value" "method-call syntax is not supported"
        [pipe: "pass the value with a pipe, such as `xs |> List.map(f)`",
         field: "read a record field with its field function, such as `Person.name(p)` or `p |> Person.name`"]
        "A dot is only used after a module, type, record, trait, or effect name, such as `List.map` or `Shape.Circle`.";
    E0204 Check "`_` can only be a direct argument of a call" "not a call argument"
        [record: "a record construction is not a call; write a lambda instead"]
        "The placeholder `_` builds a function from a call, such as `clamp(0, _, 100)`.";
    E0206 Check "constructor `{name}` without fields must not have parentheses" ""
        [remove: "remove `()`"]
        fix [remove]
        "Constructors without fields are declared and written without parentheses.";
    E0207 Check "function names cannot be qualified with a module name" ""
        [remove: "remove `{module}.` from the name"]
        fix [remove]
        "Top-level functions are declared with a plain name. The module of a function is the file it is written in.";
    E0208 Check "the program is nested too deeply" "nesting limit of {limit} reached here" []
        "The parser limits the depth of nested syntax.";
    E0209 Check "a function type with `uses` must be parenthesized here" ""
        [paren: "write the function type in parentheses, such as `function((function() -> Unit uses Console.Write), List[Integer]) -> Unit`"]
        "`uses` reads as many effect names as possible, so a function type with `uses` inside a list of types must be parenthesized.";
    E0210 Check "`_` cannot be a lambda parameter" ""
        [name: "use a name that starts with `_`, such as `_unused`"]
        fix [name]
        "Unused lambda parameters are named with a leading `_`.";
    E0211 Check "`{symbol}` is not an operator in Benitoite" "not a Benitoite operator"
        [equal: "write `=` to compare values",
         not_equal: "write `<>` for inequality",
         and: "write `and`",
         or: "write `or`",
         not: "write `not`",
         remainder: "write `mod` for the remainder",
         question: "write `try` before the expression, such as `try parse(text)`",
         fat_arrow: "write the branch as `case pattern -> expression`"]
        fix [equal, not_equal, and, or, not, remainder]
        "Benitoite writes these operators as words or with other symbols.";
    E0212 Check "blocks are not written with braces" "braces are not used"
        [end: "close the block with `end {construct}` instead of `}`",
         open: "start the block with the keyword of the construct; it ends with `end` and the construct name, such as `end function` or `end if`"]
        "Blocks start with a keyword and end with `end` followed by the name of the construct.";
    E0213 Check "`end {found}` does not close `{expected}`" "expected `end {expected}`"
        [opened: "the `{expected}` block starts here",
         replace: "write `end {expected}`"]
        fix [replace]
        "A block is closed by `end` followed by the name of the construct that opened it.";
    E0214 Check "`{construct}` is not closed" "expected `end {construct}` before this"
        [opened: "the `{construct}` block starts here"]
        "Every block must be closed with `end` and the name of its construct.";
    E0215 Check "`with` must be on the same line as `match`" "`with` starts a new line here"
        [same_line: "put `with` at the end of the previous line, such as `match value with`"]
        fix [same_line]
        "A line break after the value of `match` ends the expression, so `with` must follow on the same line.";
    E0216 Check "`{word}` is a keyword and cannot be used as a name" "keyword used as a name"
        [rename: "choose another name"]
        "Keywords cannot be used as names of variables, functions, or types.";
    E0217 Check "parenthesized lists of values are not tuples" ""
        [pair: "use `Pair`, such as `Pair(a, b)` or the type `Pair[A, B]`",
         triple: "use `Triple`, such as `Triple(a, b, c)` or the type `Triple[A, B, C]`",
         record: "declare a `record` for four or more values"]
        "Benitoite has no tuple syntax. `Pair` and `Triple` hold two or three values, and records hold more.";
    E0218 Check "`{keyword}` cannot be used inside {context}" ""
        [lazy_body: "a `lazy` body produces one value; compute the value with an expression",
         guard: "a guard is a condition; check the value in the branch body instead",
         lambda: "`{keyword}` is allowed inside a lambda written there"]
        "`return` and `try` cannot leave a `lazy` body or a `match` guard, except inside a lambda written there.";
    E0219 Check "`import` must come before other declarations" "import after a declaration"
        [first: "the first declaration is here"]
        "All `import` declarations are written at the start of the file.";
    E0220 Check "an attribute argument must be a string literal" ""
        [plain: "write a plain string literal without interpolation, such as `@deprecated(\"use format instead\")`"]
        "Attribute arguments are string literals, and interpolation is not allowed in them.";
    E0221 Check "`public` is not allowed on {what}" ""
        [remove: "remove `public`",
         implement: "an implementation is visible wherever its trait and type are visible"]
        fix [remove]
        "Implementations and the functions inside them are not marked `public`.";
    E0222 Check "`{name}` is not a built-in constraint" ""
        [builtin: "the lowercase constraints are `equality` and `key`; traits are written with an uppercase name",
         ordered: "`ordered` can only be used in the standard library"]
        "A lowercase name in a constraint must be one of the built-in constraints.";
    E0223 Check "the built-in constraint `{name}` cannot be a supertrait" ""
        [remove: "remove `{name}` from the supertraits"]
        fix [remove]
        "Only traits can be supertraits of a trait.";
    E0224 Check "a record update must change at least one field" ""
        [use_value: "use `{value}` directly"]
        fix [use_value]
        "`Record(..value)` without fields would copy the value unchanged.";
    E0225 Check "a record pattern must name at least one field" ""
        [wildcard: "use the pattern `_` to match any value"]
        fix [wildcard]
        "`Record(..)` without fields matches every value; `_` says this directly.";
    E0226 Check "a list literal can contain at most one spread" "second spread"
        [first: "first spread here",
         concat: "join the lists with `List.concatenate`"]
        "A list literal may contain one `..e`. Join more lists with `List.concatenate`.";
    E0227 Check "`{written}` is not the spread syntax" ""
        [spread: "write `..{name}` to spread a list"]
        fix [spread]
        "A list is spread into a list literal with `..e`.";
    E0228 Check "this documentation comment is not attached to a declaration" ""
        [plain: "write a normal comment with `//`"]
        fix [plain]
        "A `///` comment must be directly followed by the declaration it documents.";
    E0229 Check "a module documentation comment must be at the start of the file" ""
        [plain: "write a normal comment with `//`"]
        fix [plain]
        "`//!` comments come before `import` declarations and other declarations.";
    E0230 Check "`let` is not used to bind names" ""
        [bind: "write `bind {name} <- {value}`",
         shadow: "if `{name}` is already a local name here, write `shadow {name} <- {value}`"]
        "A binding statement is written `bind x <- e`, or `shadow x <- e` to hide a visible local name.";
    E0231 Check "`case ... of` is not the syntax of `match`" ""
        [match_with: "write `match {value} with`"]
        "Pattern matching is written `match value with`, followed by branches `case pattern ->`.";
    E0232 Check "`when` does not start a branch" ""
        [case: "write the branch as `case {pattern} ->`"]
        "Branches of `match` and clauses of `handle` start with `case` and use `->`.";
    E0233 Check "an algebraic data type is declared with `data`" ""
        [data: "write `data {name}` and close it with `end data`"]
        fix [data]
        "`type` declares a type alias. Types with constructors are declared with `data ... end data`.";
    E0234 Check "the return type is written after `->`" "expected `->`"
        [arrow: "replace `:` with `->`"]
        fix [arrow]
        "The return type of a function, lambda, method, or operation follows `->`.";
    E0235 Check "`try` does not start a block" ""
        [result: "there are no exceptions; return a `Result` and write `try` before a call that returns `Result` or `Option`"]
        "`try` returns an `Error` or `None` to the caller early. Errors are values, and there is no exception-catching syntax.";
    E0236 Check "alternatives in a pattern are separated by commas" ""
        [comma: "write `case {first}, {second} ->`"]
        fix [comma]
        "A branch that accepts several patterns lists them separated by `,`.";
    E0237 Check "a type alias cannot list constructors" ""
        [data: "declare a `data` type with one constructor per line, closed by `end data`"]
        "`type` gives another name to an existing type. Constructors are declared in `data`.";
    E0238 Check "a branch must start with `case`" ""
        [case: "write the branch as `case {pattern} -> ...`"]
        "Every branch of `match` starts with `case` and uses `->`.";
    E0239 Check "`{word}` is not Benitoite syntax" ""
        [switch: "write `match {value} with`",
         default: "write `case _ ->`"]
        "Pattern matching is written with `match ... with` and branches `case pattern ->`.";
    E0240 Check "`break` is not needed in a branch" ""
        [remove: "remove `break`; a branch never continues into the next branch"]
        fix [remove]
        "Branches of `match` do not fall through.";
    E0241 Check "a guard is written with `if`" ""
        [if: "write `case {pattern} if {condition} ->`"]
        fix [if]
        "A branch condition follows the pattern after `if`.";
    E0242 Check "a range is written `low..high`" ""
        [range: "write `{low}..{high}`; both ends are included"]
        fix [range]
        "Range patterns include both ends and are written with `..` only.";
    E0243 Check "a lambda is written with parentheses and `end lambda`" ""
        [lambda: "write `lambda({params}) return {body} end lambda`"]
        "Lambdas are written `lambda(x) return x + 1 end lambda`.";
    E0244 Check "modules are imported by name" ""
        [by_name: "write `import {module}`, a module name relative to the directory of the starting file"]
        "`import` names a module, such as `import Lib.Text` for the file `Lib/Text.bnt`.";
    E0245 Check "`implement` must name a trait" ""
        [functions: "write top-level functions instead, such as `function describe(p: {name}) -> String`"]
        "`implement` implements a trait for a type, such as `implement Show[Person]`.";
    E0246 Check "`with` does not install a handler" ""
        [handle: "write `handle ... with case operation(args) -> ... end handle`"]
        "Handlers are written with `handle ... with` and clauses `case`. `with` also binds resources.";
    E0247 Check "attributes are written with `@` and a lowercase name" ""
        [test: "write `@test`",
         other: "the attributes are `@test`, `@test(\"...\")`, and `@deprecated(\"...\")`"]
        fix [test]
        "Attributes are written on the line before a declaration.";
    E0248 Check "a type alias is written `type Name = Type`" ""
        [alias: "write `type {name} = ...`"]
        "`type` declares a type alias; there is no `alias` keyword.";
    E0249 Check "documentation comments are written with `///`" ""
        [doc: "write each line of the documentation with `///` before the declaration"]
        "Documentation comments start with `///`, and module documentation starts with `//!`.";
    E0250 Check "a list pattern can contain at most one `..`" "second `..`"
        [first: "first `..` here"]
        "A list pattern has one rest part, such as `[first, ..rest]`.";

    E0251 Check "`fn` is not used for function declarations or lambdas" ""
        [function: "write `function {signature} ... end function`",
         lambda: "write `lambda{signature} ... end lambda`, using `return` for the result"]
        "Declare functions with `function` and write anonymous functions with `lambda`.";

    // ---- E03: 名前、import、公開 ----
    E0301 Check "cannot find `{name}` in this scope" "not found"
        [similar: "a similar name exists: {candidates}"]
        fix [similar]
        "The name is not bound by a local binding, a function, or a constant visible here.";
    E0302 Check "cannot find `{name}`" "not found"
        [similar: "a similar name exists: {candidates}"]
        fix [similar]
        "The name before `.` must be a module imported in this file, a prelude module, a type, a record, a trait, or an effect.";
    E0303 Check "`{module}` has no member `{name}`" "not found in `{module}`"
        [similar: "a similar name exists: {candidates}",
         length: "strings have no unit-less length; use `String.byteLength` (bytes) or `String.characterCount` (characters)",
         slice: "use `String.byteSlice` (byte positions) or `String.characterSlice` (character positions)",
         index_of: "use `String.byteIndexOf`, which returns a byte position",
         unwrap: "there is no `{name}`; use `{module}.unwrapOr` or `match`",
         not_reexported: "names imported by `{module}` are not visible through it; import that module directly"]
        fix [similar]
        "The module, type, record, trait, or effect does not define this name.";
    E0304 Check "`{name}` is {found_kind}, not {expected_kind}" "" []
        "Each position accepts only one kind of name.";
    E0305 Check "the name `{name}` is defined more than once" "redefined here"
        [first: "first defined here",
         import: "give the import another name with `as`, such as `{suggestion}`"]
        fix [import]
        "Types, records, type aliases, traits, effects, and import names share one namespace in a module.";
    E0306 Check "`{name}` is defined more than once" "redefined here"
        [first: "first defined here"]
        "Functions, constants, and effect operations share one namespace in a module.";
    E0309 Check "the constructor `{name}` is defined more than once in `{ty}`" "redefined here"
        [first: "first defined here"]
        "Constructor names must be unique within a type.";
    E0310 Check "the parameter `{name}` is declared more than once" "redeclared here"
        [first: "first declared here"]
        "Parameter names must be unique within a function or lambda.";
    E0311 Check "`{name}` is bound more than once in the same pattern" "bound again here"
        [first: "first bound here"]
        "A pattern cannot bind the same variable twice.";
    E0312 Check "the type parameter `{name}` is declared more than once" "redeclared here"
        [first: "first declared here"]
        "Type parameter names must be unique within a list.";
    E0313 Check "the type parameter `{name}` has the same name as a top-level declaration" ""
        [declared: "the top-level declaration is here"]
        "Type parameters and effect variables cannot reuse top-level uppercase names or `Benitoite`.";
    E0314 Check "`{name}` is an effect and cannot be used as a type" ""
        [uses_only: "effects and effect variables can only appear after `uses`"]
        "Effect names and effect variables are not types.";
    E0315 Check "`{name}` is not an effect" "expected an effect name or an effect variable"
        [qualify: "effects of other modules are written with the module name, such as `Console.Write`"]
        fix [qualify]
        "After `uses`, write effects declared in this module, `State`, effects qualified with a module name, or effect variables.";
    E0316 Check "`{name}` is not an effect" "read as part of the `uses` list"
        [paren: "if `{name}` belongs to the surrounding list, parenthesize the function type that has `uses`, such as `function((function() -> Unit uses Console.Write), Integer) -> Unit`"]
        fix [paren]
        "`uses` reads as many comma-separated names as possible, so a following list element may be taken as an effect.";
    E0318 Check "cannot find module `{module}`" "no file `{path}` under the root directory"
        [similar: "a similar module exists: {candidates}",
         case_only: "the directory has `{actual}`, which differs only in upper and lower case"]
        "A module name refers to a file under the directory of the starting file, such as `Lib/Text.bnt` for `Lib.Text`.";
    E0319 Check "the module `{module}` is outside the root directory" ""
        [resolved: "`{path}` resolves to `{target}`, outside `{root}`"]
        "Modules are imported only from the directory of the starting file and its subdirectories, after resolving symbolic links.";
    E0320 Check "the module where execution starts cannot be imported" ""
        [entry: "`{module}` is the starting file of this program"]
        "The starting module is not a library. Move the shared declarations to another module.";
    E0321 Check "`{module}` is not a standard library module" ""
        [similar: "a similar module exists: {candidates}",
         root_file: "names that start with `Benitoite` always refer to the standard library, so `{path}` cannot be imported",
         unofficial: "this module is unofficial in this version and is imported as `{suggestion}`",
         standard: "this module is a standard module in this version and is imported as `{suggestion}`"]
        fix [similar, unofficial, standard]
        "Modules whose names start with `Benitoite` are the standard library modules. Unofficial modules are imported with `Unofficial` after `Benitoite`, such as `Benitoite.Unofficial.IO.Console`.";
    E0322 Check "modules import each other in a cycle" "this import closes the cycle"
        [member: "part of the cycle",
         chain: "the cycle is {chain}"]
        "Imports must not form a cycle. Move the declarations the modules share to another module.";
    E0323 Check "two imports have the name `{name}`" "second import named `{name}`"
        [first: "first import named `{name}`",
         alias: "give one of them another name with `as`, such as `import {module} as {suggestion}`"]
        fix [alias]
        "Each import gives the module one name in the file, the last part of its name or the name after `as`.";
    E0324 Check "the module `{module}` is imported more than once" "imported again here"
        [first: "first imported here",
         remove: "remove this import"]
        fix [remove]
        "A module is imported once in a file.";
    E0325 Check "`Benitoite` cannot be used as a name here" ""
        [reserved: "`Benitoite` always refers to the standard library namespace"]
        "`Benitoite` cannot be declared or used as an import name.";
    E0326 Check "the effect `{name}` has the same name as its module" ""
        [rename: "effects are not modules; choose a name different from the module name"]
        "An effect cannot have the name of the module that declares it, because a qualified name such as `Log.write` would be ambiguous.";
    E0327 Check "the field `{name}` is declared more than once" "redeclared here"
        [first: "first declared here"]
        "Field names must be unique within a record.";
    E0328 Check "the method `{name}` is declared more than once in `{trait_name}`" "redeclared here"
        [first: "first declared here"]
        "Method names must be unique within a trait.";
    E0329 Check "the public {what} `{name}` uses the non-public {used_kind} `{used}`" "`{used}` is not public"
        [declared: "`{used}` is declared here",
         make_public: "mark `{used}` as `public`",
         handle: "handle the effect inside the function before returning"]
        fix [make_public]
        "Everything a public declaration exposes, including types, traits, and effects, must also be public.";
    E0330 Check "`{name}` is not public in `{module}`" "not public"
        [declared: "declared here",
         make_public: "mark `{name}` as `public` in `{module}`"]
        fix [make_public]
        "Only `public` declarations of another module can be used.";
    E0331 Check "the constructor `{name}` must be written with its type name" ""
        [qualify: "write `{suggestion}`"]
        fix [qualify]
        "Constructors are written with their type name, such as `Option.Some(x)`, `Result.Error(e)`, and `Shape.Circle(r)`.";
    E0332 Check "the module `{module}` is not imported" ""
        [import: "add `import {full}` at the start of the file"]
        fix [import]
        "Standard library modules outside the prelude must be imported before use.";
    E0333 Check "`IO` is a module, not an effect" "expected an effect"
        [all: "use `IO.All` to allow every effect in `Benitoite.IO`"]
        fix [all]
        "The built-in effects are `Console.Write`, `File.Read`, and so on. `IO.All` stands for all of them.";
    E0334 Check "`{name}` is already a local name here" "`bind` cannot hide a local name"
        [visible: "`{name}` is bound here",
         shadow: "write `shadow` to bind a new value to `{name}`"]
        fix [shadow]
        "`bind` introduces names that are not visible yet. `shadow` hides a visible local name.";
    E0335 Check "`{name}` is not a local name here" "nothing to shadow"
        [bind: "write `bind` to introduce `{name}`"]
        fix [bind]
        "`shadow` hides a visible local name. `bind` introduces a new one.";
    E0336 Check "this binding mixes visible and new names" ""
        [visible: "`{name}` is bound here",
         split: "split the statement into a `bind` and a `shadow`"]
        "All variables on the left of `bind` must be new, and all variables on the left of `shadow` must be visible local names.";
    E0337 Check "`shadow` does not bind any variable here" ""
        [bind: "write `bind _ <- ...` to evaluate and discard the value"]
        fix [bind]
        "`shadow` needs at least one variable on its left.";
    E0338 Check "{binder} `{name}` hides a local name" ""
        [hidden: "`{name}` is bound here",
         rename: "choose another name"]
        "Lambda parameters, pattern variables of branches, handler clause parameters, and `with` bindings cannot hide visible local names.";

    // ---- E04: 型 ----
    E0401 Check "mismatched types" "expected `{expected}`, found `{found}`"
        [declared: "expected because of this",
         expanded: "the expanded expected type is `{expanded}`",
         because_call_arg: "argument {index} must match the parameter type of the called function",
         because_if_branches: "the branches of `if` must have compatible types",
         because_if_no_else: "`if` without `else` must have type `Unit`",
         because_condition: "a condition must have type `Boolean`",
         because_match_arms: "the branches of `match` must have compatible types",
         because_pattern: "a pattern must match the type of the value being matched",
         because_alternatives: "a variable bound in several alternatives must have one type",
         because_list: "the elements of a list must have compatible types",
         because_spread: "a spread `..e` must be a list of the element type",
         because_bind_annotation: "the value must match the type annotation",
         because_const_annotation: "the value of a constant must match its type",
         because_return: "the returned value must match the declared return type",
         because_lambda_return: "the lambda body must match the annotated return type",
         because_field: "the value must match the type of the field `{field}`",
         because_update: "a record update keeps the type arguments of the record",
         because_resume: "the value passed to `resume` must match the result type of the operation",
         because_handle: "the body and the clauses of `handle` must have compatible types",
         because_operands: "both operands of `{op}` must have the same type",
         because_logic: "the operands of `{op}` must have type `Boolean`",
         because_int_operands: "the operands of `{op}` must have type `Integer`",
         because_call: "the called value must be a function",
         float_literal: "write a floating-point literal such as `{literal}.0`",
         to_string: "convert the value with `{function}`, or use string interpolation such as `\"${x}\"`",
         to_string_any: "convert the other value to a `String` before joining it with `+`, or use string interpolation"]
        fix [float_literal]
        "Two types that must be equal are different.";
    E0402 Check "this function takes {expected} argument(s) but {found} were supplied" ""
        [declared: "function declared here"]
        "Functions are not curried; supply every argument, or use `_` placeholders to build a new function.";
    E0403 Check "a value of type `{found}` is not a function" "cannot be called"
        [constant: "`{name}` is a constant; remove `()`"]
        fix [constant]
        "Only functions can be called.";
    E0404 Check "a type would contain itself" "this makes the type infinite" []
        "A type variable cannot be equal to a type that contains it.";
    E0405 Check "`{op}` cannot be applied to `{ty}`" ""
        [allowed: "`{op}` works on {allowed}",
         div: "use `div` for integer division, or convert with `Integer.toFloat` before `/`",
         type_param: "operators cannot be applied to values of a type parameter",
         to_string: "convert the value with `{function}`, or use string interpolation such as `\"${x}\"`",
         to_string_any: "convert the other value to a `String` before joining it with `+`, or use string interpolation"]
        fix [div]
        "Arithmetic and ordering operators work only on the listed basic types.";
    E0406 Check "values of type `{ty}` cannot be compared with `{op}`" ""
        [why: "types that contain functions, `IOError`, or other opaque types cannot be compared with `=` or `<>`",
         constraint: "add the constraint `equality` to the type parameter, such as `[{param}: equality]`"]
        fix [constraint]
        "Equality is defined only for types without functions and opaque standard library types.";
    E0407 Check "the type of this expression cannot be determined" ""
        [annotate: "add a type annotation"]
        "An operator, an interpolation, a comparison, a key, a trait method, a `try`, or a `with` needs its type to be known by the end of the function body.";
    E0408 Check "integer literal is out of range for `Integer`" ""
        [range: "`Integer` values range from -9223372036854775808 to 9223372036854775807"]
        "Integer literals must fit in a 64-bit signed integer.";
    E0409 Check "floating-point literal is too large for `Float`" "" []
        "The literal rounds to infinity.";
    E0410 Check "`{name}` expects {expected} type argument(s) but {found} were given" "" []
        "Every type argument of a generic type or a type alias must be written.";
    E0411 Check "the type `{name}` has no constructors" ""
        [add: "add at least one constructor"]
        "A `data` declaration needs at least one constructor.";
    E0412 Check "the constructor `{name}` has {expected} field(s) but the pattern has {found}" "" []
        "A constructor pattern needs one sub-pattern per field.";
    E0413 Check "the constructor `{name}` has no fields and is written without parentheses" ""
        [remove: "remove `()`"]
        fix [remove]
        "Constructors without fields are values, not functions.";
    E0414 Check "no `main` function" ""
        [define: "define `function main() -> Unit` in the file where execution starts"]
        "A program starts by calling `main` of the starting module.";
    E0415 Check "`main` has an invalid signature" ""
        [params: "`main` takes no parameters",
         type_params: "`main` cannot have type parameters or effect variables",
         ret: "`main` must return `Unit` or `Result[Unit, String]`",
         effects: "`main` can only use the built-in effects in `IO.All` and the network effects",
         assert: "`main` cannot use `Assert.Check`"]
        "`main` has no parameters, returns `Unit` or `Result[Unit, String]`, and uses only built-in effects.";
    E0416 Check "the value of this expression is not used" "this has type `{found}`, not `Unit`"
        [discard: "write `bind _ <- ...` to discard the value",
         reassign: "`=` compares values and variables cannot be reassigned; to bind a new value to the name, write `shadow {name} <- ...`"]
        fix [discard, reassign]
        "An expression statement that is not the last in a block must have type `Unit`.";
    E0417 Check "a `uses` list can contain at most one effect variable" "" []
        "Use the same effect variable for several parameters to combine their effects.";
    E0418 Check "the effect variable `{name}` does not appear in any parameter type" "" []
        "An effect variable must be determined by a parameter type.";
    E0419 Check "`{name}` appears more than once in `uses`" ""
        [remove: "remove the second `{name}`"]
        fix [remove]
        "Each effect is listed once.";
    E0420 Check "Decimal literal has more than 28 digits after the decimal point" ""
        [limit: "a `Decimal` has at most 28 digits after the decimal point"]
        "Decimal literals are not rounded, so their digits must fit the `Decimal` type.";
    E0421 Check "Decimal literal is out of range for `Decimal`" ""
        [limit: "the digits of a `Decimal`, without the decimal point, must be less than 2^96"]
        "Decimal literals are not rounded, so their value must fit the `Decimal` type.";
    E0422 Check "a value of type `{ty}` cannot be interpolated into a string" ""
        [show: "convert the value to a `String` first with `{function}`",
         import_show: "if this type implements `Show`, write `import Benitoite.Trait` and convert the value with `Trait.Show.show`",
         convert: "convert the value to a `String` before interpolating it"]
        fix [show]
        "`${...}` accepts `String`, `Integer`, `Float`, `Decimal`, `Byte`, `Character`, and `Boolean`.";
    E0423 Check "`{ty}` cannot be used as a key" ""
        [float: "`Float` has values that are not equal to themselves; use `Integer`, `Decimal`, or `String` instead"]
        "Map keys and set elements must have types that satisfy `key`. Types that contain `Float` do not.";
    E0424 Check "the type parameter `{param}` needs the constraint `{constraint}`" ""
        [required: "required by this use",
         add: "add the constraint, such as `[{param}: {constraint}]`"]
        fix [add]
        "Comparing values or using them as keys requires `equality` or `key` on a type parameter.";
    E0425 Check "the constraint `{constraint}` cannot be written here" "" []
        "Type declarations cannot have constraints. Built-in constraints can be written on value type parameters of functions, methods, and implementations, but not on type constructor parameters or supertraits.";
    E0426 Check "`{name}` needs type arguments here" "" []
        "A type constructor such as `List` or a parameter `F[_]` is a type only with its type arguments.";
    E0427 Check "`{name}` takes {expected} type argument(s) where {found} are needed" "" []
        "A trait over type constructors, such as `Functor`, needs a type constructor that takes the same number of type arguments.";
    E0428 Check "the record `{name}` is missing fields: {fields}" "missing fields"
        [declared: "the record is declared here"]
        "A record construction gives a value to every field. Use `Record(..value, field: x)` to copy the other fields.";
    E0429 Check "the record `{name}` has no field `{field}`" "unknown field"
        [similar: "a similar field exists: {candidates}"]
        fix [similar]
        "Only the fields declared in the record can be written.";
    E0430 Check "the field `{field}` is given more than once" "given again here"
        [first: "first given here"]
        "Each field is written once in a construction, an update, or a pattern.";
    E0431 Check "the type alias `{name}` refers to itself" ""
        [member: "part of the cycle",
         chain: "the cycle is {chain}",
         data: "declare a `data` type for a recursive type"]
        "A type alias is replaced by its definition, so it cannot refer to itself directly or through other aliases.";
    E0432 Check "the type parameter `{param}` is not used in the type alias `{name}`" "" []
        "Every type parameter of a type alias must appear on its right-hand side.";
    E0433 Check "this expression cannot be used in a constant" "not a constant expression"
        [function: "write a function without parameters to compute the value when it is called"]
        "A constant is computed before the program runs, from literals, other constants, operators, constructors, records, lists, and `Map.fromList` or `Set.fromList`.";
    E0434 Check "the type of the constant `{name}` cannot contain type parameters" "" []
        "A constant has one value, so its type must be a concrete type.";
    E0435 Check "computing the constant `{name}` fails: {condition}" "fails here" []
        "A constant whose computation would stop with a runtime error is reported before the program runs.";
    E0436 Check "the key `{key}` appears more than once in a constant" "repeated key"
        [first: "first given here"]
        "`Map.fromList` and `Set.fromList` in a constant must not repeat a key.";
    E0437 Check "constants refer to each other in a cycle" "this constant is part of a cycle"
        [member: "part of the cycle",
         chain: "the cycle is {chain}"]
        "A constant can use other constants, but not itself through a chain of constants.";
    E0438 Check "the function can reach its end without `return`" "the end of the body is reachable"
        [path: "the body can reach its end through this path",
         add: "add `return` with a value of type `{expected}`"]
        "A function or lambda whose return type is not `Unit` must leave through `return` on every path.";
    E0439 Check "this statement is never executed" "unreachable statement"
        [exit: "this always leaves the block"]
        "A statement after `return`, or after an `if` or `match` that always leaves, is never executed.";
    E0440 Check "`try` cannot be applied to `{ty}`" ""
        [kinds: "`try` works on `Result` and `Option`"]
        "`try` takes a `Result` or an `Option`.";
    E0441 Check "`try` on `{ty}` needs the function to return {needed}" ""
        [declared: "the function returns `{declared}`",
         convert: "convert the value with `Option.okOr` or `Result.toOption` before `try`"]
        "`try` on a `Result` needs the enclosing function or lambda to return a `Result`, and `try` on an `Option` needs it to return an `Option`.";
    E0442 Check "`try` cannot return an error of type `{found}` from a function that returns errors of type `{expected}`" ""
        [declared: "the function returns `{declared}`",
         map_error: "convert the error with `Result.mapError` before `try`"]
        "The error type of the value after `try` must be the error type of the function's result.";
    E0443 Check "`{ty}` is not a resource type" ""
        [resources: "`with` binds values opened by functions such as `File.openReader` and `TaskGroup.open`"]
        "A `with` binding needs a resource, which is released when the block ends.";

    // ---- E05: エフェクト、ハンドラ ----
    E0501 Check "this function performs `{effect}` but does not declare it" "`{effect}` happens here"
        [declared: "declared here",
         add_uses: "add `uses {effect}` to the signature, or move this call to a function that uses `{effect}`"]
        "A function body can only perform the effects listed after `uses`.";
    E0502 Check "this lambda performs `{effect}` but its `uses` does not include it" "`{effect}` happens here"
        [declared: "declared here"]
        "A lambda with `uses` can only perform the listed effects.";
    E0503 Check "a `lazy` body cannot perform `{effect}`" "`{effect}` happens here"
        [lambda: "use a lambda without parameters to delay an effectful computation"]
        "A `lazy` body is computed at most once at an unknown time, so it cannot have effects.";
    E0504 Check "a guard cannot perform `{effect}`" "`{effect}` happens here"
        [body: "compute the condition in the branch body instead"]
        "Guards are conditions and cannot have effects.";
    E0505 Check "`TaskGroup.open` can only be called in a `with` binding" ""
        [with: "write `with group = TaskGroup.open() do ... end with`"]
        "A task group must be released when its block ends, so it is opened only by `with`.";
    E0506 Check "`{function}` does not handle the effect `{effect}`" "`{effect}` is not handled"
        [handle: "handle `{effect}` with `handle ... with` inside `{function}`"]
        "Effects declared by the program must be handled inside `main` and inside test functions.";
    E0507 Check "`{name}` is not an operation of an effect" ""
        [state: "`State` has no operations and cannot be handled"]
        "A clause of `handle` names an operation declared in an `effect`.";
    E0508 Check "the operation `{name}` is handled twice in one `handle`" "second clause"
        [first: "first clause here"]
        "Each operation has at most one clause in a `handle`.";
    E0509 Check "`resume` can only be used directly in a clause of `handle`" ""
        [lambda: "`resume` cannot be used in a lambda or a `lazy` body inside a clause"]
        "`resume` continues the computation that performed the operation, so it is written in the clause itself.";
    E0510 Check "invalid effect operation declaration" ""
        [uses: "an operation declaration cannot have `uses`; the handler decides the effects",
         effect_var: "an operation cannot have effect variables",
         type_ctor: "an operation cannot have type constructor parameters such as `F[_]`",
         trait_constraint: "a type parameter of an operation can have only `equality` or `key`, not a trait"]
        "Operations of an effect are declared with a name, parameters, and a result type.";

    // ---- E06: パターン ----
    E0601 Check "`match` does not cover every value" "`{witness}` is not matched"
        [add_arm: "add a branch `case {witness} ->`, or `case _ ->`"]
        "Every possible value must be matched by some branch.";
    E0602 Check "this branch can never be selected" "unreachable branch"
        [covering: "this earlier branch already matches the values"]
        "Earlier branches match every value this branch matches.";
    E0603 Check "the pattern variable `{name}` has the name of a constant" "binds a new variable"
        [constant: "the constant is declared here",
         guard: "compare with the constant in a guard, such as `case n if n = {name} ->`"]
        fix [guard]
        "A lowercase name in a pattern always binds a new variable. Compare with a constant in a guard.";
    E0604 Check "the alternatives bind different variables" ""
        [missing: "`{name}` is not bound in this alternative",
         first: "`{name}` is bound here",
         extra: "`{name}` is bound only in this alternative",
         sets: "missing variables: {missing}; extra variables: {extra}",
         missing_set: "missing variables: {missing}",
         extra_set: "extra variables: {extra}"]
        "Every alternative in one branch must bind the same variables.";
    E0605 Check "the range `{low}..{high}` is empty" ""
        [swap: "write `{high}..{low}`"]
        fix [swap]
        "The lower end of a range pattern must not be greater than the upper end.";
    E0606 Check "a range pattern needs two `Integer` or two `Character` literals" "" []
        "Range patterns compare integers or characters.";
    E0607 Check "this pattern does not match every value of `{ty}`" "`{witness}` is not matched"
        [match: "use `match ... with` to handle the other values"]
        "The pattern on the left of `bind` or `shadow` must match every value.";
    E0608 Check "this alternative can never be selected" "unreachable alternative"
        [covering: "already matched here"]
        "Earlier patterns match every value this alternative matches.";

    // ---- E07: 型クラス ----
    E0701 Check "this implementation must be in the module of `{trait_name}` or of `{ty}`" ""
        [trait_decl: "the trait is declared here",
         type_decl: "the type is declared here"]
        "An implementation is written in the module that declares the trait or the type, so that it is found without importing other modules.";
    E0702 Check "`{trait_name}` is implemented more than once for `{ty}`" "overlapping implementation"
        [other: "the other implementation is here"]
        "Each type constructor has at most one implementation of a trait.";
    E0703 Check "traits are supertraits of each other in a cycle" ""
        [member: "part of the cycle",
         chain: "the cycle is {chain}"]
        "Supertraits must not form a cycle.";
    E0704 Check "the implementation of `{trait_name}` for `{ty}` needs `{supertrait}` for `{ty}`" ""
        [constraint: "add the constraint `{constraint}` to the type parameter of the implementation"]
        "A type implements a trait only if it implements the supertraits under the same constraints.";
    E0705 Check "`{ty}` does not implement `{trait_name}`" "`{trait_name}` is required here"
        [required: "required by this use"]
        "A value used with a trait method, or passed where a constraint is required, must have an implementation.";
    E0706 Check "the type parameter `{param}` needs the constraint `{trait_name}`" ""
        [add: "add the constraint, such as `[{param}: {trait_name}]`"]
        fix [add]
        "Using a trait method on a value of a type parameter requires that constraint on the parameter.";
    E0707 Check "the implementation of `{trait_name}` is missing methods: {methods}" ""
        [trait_decl: "the trait is declared here"]
        "An implementation defines every method of its trait.";
    E0708 Check "`{name}` is not a method of `{trait_name}`" ""
        [similar: "a similar method exists: {candidates}"]
        fix [similar]
        "An implementation defines only the methods of its trait.";
    E0709 Check "the method `{name}` does not mention the type parameter of `{trait_name}`" "" []
        "A method is chosen by the type of its parameters or its result, so it must mention the trait's type parameter.";
    E0710 Check "the trait `{name}` declares no methods" "" []
        "A trait declares at least one method.";
    E0711 Check "the method `{name}` does not match its declaration in `{trait_name}`" "expected `{expected}`, found `{found}`"
        [declared: "declared here"]
        "An implemented method has the parameter and result types of the trait's method, and at most its effects.";
    E0712 Check "cannot implement a trait for `{ty}`" ""
        [form: "implement it for a type name with distinct type parameters, such as `Option[T]`"]
        "Implementations are written for one type constructor applied to distinct type parameters.";
    E0713 Check "the type parameter `{param}` is not used in the implemented type" "" []
        "Every type parameter of an implementation must appear in the implemented type.";
    E0714 Check "`{name}` does not fit the trait `{trait_name}`" ""
        [value: "`{trait_name}` is for types of values, such as `Integer`",
         constructor: "`{trait_name}` is for type constructors, such as `List`"]
        "A trait is either for types of values or for type constructors, and its implementations and constraints must match.";

    // ---- E08: 属性 ----
    E0801 Check "unknown attribute `@{name}`" ""
        [allowed: "the attributes are `@test`, `@test(\"...\")`, and `@deprecated(\"...\")`"]
        "Only the listed attributes can be written.";
    E0802 Check "`@{name}` cannot be written on {what}" "" []
        "`@test` is written on functions. `@deprecated` is written on functions, constants, `data` types, type aliases, records, traits, and effects.";
    E0803 Check "`@{name}` is written more than once" "written again here"
        [first: "first written here",
         remove: "remove this attribute"]
        fix [remove]
        "Each attribute is written at most once on a declaration.";
    E0804 Check "`@deprecated` needs one non-empty message" ""
        [message: "write the reason and the replacement, such as `@deprecated(\"use formatDate instead\")`"]
        "The message of `@deprecated` is shown with every use of the declaration.";
    E0805 Check "`@test` takes at most one description" "" []
        "`@test` is written alone or with one description string.";
    E0806 Check "the test function `{name}` has an invalid signature" ""
        [params: "a test function takes no parameters",
         type_params: "a test function cannot have type parameters or effect variables",
         ret: "a test function must return `Unit` or `Result[Unit, String]`"]
        "Test functions are called without arguments by `benitoite test`.";
    E0807 Check "`@builtin` can only be used in the standard library" ""
        [remove: "remove `@builtin` and write the body of the function"]
        "Built-in functions are provided by the standard library.";
    E0808 Check "the function `{name}` has no body" ""
        [body: "write the body and close it with `end function`"]
        "Functions without a body exist only in the standard library.";

    // ---- W03: 名前の警告 ----
    W0301 Check "`{name}` is deprecated" "deprecated"
        [declared: "declared deprecated here",
         message: "{message}"]
        "The declaration is marked `@deprecated` and may be removed later. The note shows its message.";

    // ---- W04: 型と演算の警告 ----
    W0401 Check "this divides by zero" "the divisor is always 0" []
        "The divisor is a constant expression whose value is 0, so the division stops the program when it runs.";
    W0402 Check "this calculation overflows `{ty}`" "always overflows" []
        "Every operand is a constant expression and the result does not fit the type, so the calculation stops the program when it runs.";
    W0403 Check "the key `{key}` appears more than once" "repeated key"
        [first: "first given here"]
        "`Map.fromList` keeps the last value for a repeated key and `Set.fromList` keeps one element, so a repeated key in a list literal is likely a mistake.";

    // ---- W05: エフェクトの警告 ----
    W0501 Check "`uses IO.All` allows more effects than this function performs" ""
        [narrow: "write `uses {effects}`",
         remove: "remove `uses IO.All`; this function performs no effects"]
        fix [narrow, remove]
        "Listing only the effects a function performs shows which operations it needs.";

    // ---- R01: 基本型の演算 ----
    R0101 Runtime "division by zero" "" []
        "Integer and Decimal division, `mod`, `Integer.floorDivide`, and `Integer.floorModulo` by zero stop the program.";
    R0102 Runtime "integer overflow" "" []
        "The result does not fit in a 64-bit signed integer.";
    R0103 Runtime "Decimal overflow" "" []
        "The result does not fit in a `Decimal` even after rounding.";

    // ---- R02: 標準出力と標準エラー出力 ----
    R0201 Runtime "failed to write to standard output" ""
        [reason: "{reason}"]
        "Writing to standard output failed, for example because the reading side of a pipe was closed.";
    R0202 Runtime "failed to write to standard error" ""
        [reason: "{reason}"]
        "Writing to standard error failed.";

    // ---- R03: 実行の開始前 ----
    R0301 Args "command-line argument {index} is not valid UTF-8" "" []
        "Arguments passed to a script must be valid UTF-8.";

    // ---- R04: リソース ----
    R0401 Runtime "failed to release `{resource}` opened at {location}" "released here"
        [failure: "failed to release `{resource}` opened at {location}: {reason}",
         reason: "{reason}"]
        "Releasing a resource failed when its `with` block ended, when its task was cancelled, or when a handler discarded the computation.";
    R0402 Runtime "`{resource}` is used after it was released" "" []
        "A resource cannot be used after its `with` block has ended.";

    // ---- R05: ハンドラ ----
    R0501 Runtime "`resume` was called twice in one clause" "" []
        "A continuation can be resumed at most once.";
    R0502 Runtime "the handler for `{operation}` cannot be used in a task" ""
        [clause: "the clause is here",
         tail: "a handler inherited by a task must end its clause with `resume`"]
        "Tasks inherit only handlers whose clauses end by calling `resume`.";

    // ---- R07: 引数 ----
    R0701 Runtime "argument {index} of `{function}` is out of range" "" []
        "The function accepts only the values described in its documentation for this argument.";

    // ---- R08: ネットワーク ----
    R0801 Runtime "a response was already sent for this request" "" []
        "`Http.respond` can be called once for each exchange.";

    // ---- R09: 資源の不足 ----
    R0901 Resource "the call stack is too deep" ""
        [frames: "{frames} calls were active",
         raise: "use tail calls, or raise the limit with `--max-call-stack`"]
        "Nested non-tail calls exceeded the call stack limit.";
    R0902 Resource "`{function}` would create a value that is too large" ""
        [size: "the result would have {size} {unit}; the limit is {limit}"]
        "A single operation cannot build a string or `Bytes` larger than 2^30 bytes, or a list longer than 2^24 elements.";
    R0903 Resource "`{function}` read more than the limit of {limit} {unit}" "" []
        "A single read cannot produce a value larger than the size limit. Read the input in parts.";

    // ---- R10: 並行処理 ----
    R1001 Runtime "no task can proceed because tasks are waiting for each other" "" []
        "Every remaining task waits for another task, so the program cannot continue.";
    R1002 Runtime "the awaited task was cancelled, so it has no result" "" []
        "`Task.await` cannot return a value for a task that was cancelled. A `Task` value used outside its `with` block may refer to such a task.";

    // ---- L01: 処理系の制限 ----
    L0101 Limit "the function `{name}` needs too many registers" ""
        [limit: "a function can use at most 65535 registers; split it into smaller functions"]
        "The bytecode addresses registers with 16 bits.";
    L0102 Limit "the function `{name}` has too many constants" ""
        [limit: "a function can have at most 65536 constants; split it into smaller functions"]
        "The bytecode addresses constants with 16 bits.";
    L0103 Limit "the function `{name}` has too many `match` expressions" ""
        [limit: "a function can have at most 65536 switch tables; split it into smaller functions"]
        "The bytecode addresses the switch tables of a function with 16 bits.";
    L0104 Limit "the function `{name}` has too many `handle` expressions" ""
        [limit: "a function can have at most 65536 handlers; split it into smaller functions"]
        "The bytecode addresses the handler descriptions of a function with 16 bits.";
    L0105 Limit "the program has too many constructors" ""
        [limit: "a program can have at most 65535 constructors"]
        "The bytecode addresses constructors with 16 bits.";
    L0106 Limit "the program uses too many built-in functions" ""
        [limit: "a program can use at most 65535 built-in functions"]
        "The bytecode addresses built-in functions with 16 bits.";
    L0107 Limit "the program has too many implementations" ""
        [limit: "a program can have at most 65535 implementations"]
        "The bytecode addresses implementations with 16 bits.";
    L0108 Limit "the program has too many effect operations" ""
        [limit: "a program can have at most 65535 effect operations"]
        "The bytecode addresses effect operations with 16 bits.";
    L0109 Limit "the trait `{name}` has too many methods" ""
        [limit: "a trait can have at most 65535 methods"]
        "The bytecode addresses the methods of a trait with 16 bits.";
    L0110 Limit "the trait `{name}` has too many supertraits" ""
        [limit: "a trait can have at most 65535 supertraits"]
        "The bytecode addresses the supertraits of a trait with 16 bits.";
    L0111 Limit "an implementation of `{name}` has too many constraints" ""
        [limit: "an implementation can have at most 65535 constraint dictionaries"]
        "The bytecode addresses the dictionaries of an implementation with 16 bits.";
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
    /// タスクの起動の履歴の見出し
    pub const TASK_ORIGINS_HEADER: &str = "in a task started by (innermost first):";
    /// 行き詰まりで待つタスクの見出し
    pub const WAITING_HEADER: &str = "waiting tasks:";
    /// 待つタスクの行の、種類と位置の間の語。`{kind}` と `{location}` を置き換える
    pub const WAITS_FOR: &str = "waits for {kind}";
    /// 末尾呼び出しの注記
    pub const TRACE_TAIL_NOTE: &str = "functions left by tail calls are not shown";
    /// 省いた段の行。`{count}` を置き換える
    pub const TRACE_OMITTED: &str = "... {count} frames omitted ...";
    /// 書き出しの失敗を先の報告に加えるときの注記。`{stream}` と `{reason}` を置き換える
    pub const FLUSH_FAILED_NOTE: &str = "also failed to write to {stream}: {reason}";
    /// 止める途中の解放の失敗を先の報告に加えるときの注記（02-10「解放の失敗の報告」）
    pub const RELEASE_WHILE_STOPPING: &str =
        "while stopping, failed to release `{resource}` opened at {location}: {reason}";
    /// `Process.exit` で止める途中の解放の失敗の最後の注記。`{code}` を置き換える
    pub const RELEASE_EXIT_NOTE: &str =
        "the program was exiting by `Process.exit({code})`; the exit status is not changed";
    /// 中断の要求で止める途中の解放の失敗の最後の注記
    pub const RELEASE_INTERRUPT_NOTE: &str =
        "the program was interrupted; the exit status is not changed";
    /// `--deny-warnings` で警告を誤りとして扱ったときの注記
    pub const DENIED_WARNING_NOTE: &str = "treated as an error because of `--deny-warnings`";
    /// 文章の形式で 50 件を超えたときの行。`{count}` を置き換える
    pub const TOO_MANY: &str = "{count} more diagnostics not shown";
    /// 件数の行（02-10「文章の形式」）。`{verb}` は `run`・`check`・`test`
    pub const SUMMARY_ONE: &str = "could not {verb} {file} due to 1 previous error";
    pub const SUMMARY_MANY: &str = "could not {verb} {file} due to {count} previous errors";
    /// 誤りの件数の行に続ける警告の件数
    pub const SUMMARY_WARNINGS_ONE: &str = "; 1 warning emitted";
    pub const SUMMARY_WARNINGS_MANY: &str = "; {count} warnings emitted";
    /// 警告だけがあるときの件数の行
    pub const WARNINGS_ONLY_ONE: &str = "1 warning emitted";
    pub const WARNINGS_ONLY_MANY: &str = "{count} warnings emitted";
    /// 処理系の不具合の報告（02-10「処理系の不具合と処理系の制限の報告」）
    pub const INTERNAL_MESSAGE: &str = "internal compiler error";
    pub const INTERNAL_VERSION: &str = "benitoite {version}";
    pub const INTERNAL_STAGE: &str = "the error occurred in the {stage} stage";
    pub const INTERNAL_THREAD: &str = "the panic occurred in the {thread} thread";
    pub const INTERNAL_PANIC: &str = "panic: {message} at {location}";
    pub const INTERNAL_REPORT: &str =
        "this is a bug in the implementation; please report it with the script that caused it";
}
