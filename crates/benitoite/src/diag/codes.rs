//! 診断コードと文言の型板の表（設計書 02-10「診断コード」「文言の言語」「修正案」）。
//! 番号の区分は設計書 02-10「診断コード」に従い、各コードの文言と報告する段をこの表にまとめる。

use super::{ReportKind, Severity};

/// E0512 の集合表示で使う空集合の文言。
pub(crate) const EMPTY_EFFECT_SET: &str = "(none)";

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

/// 廃止したコード。番号を使い回さない（設計書 02-10「診断コード」）。
pub const RETIRED: &[&str] = &[
    "E0111", "E0117", "E0205", "E0307", "E0308", "E0317", "E0444", "E0445",
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
        "`benitoite fmt` writes the formatted source to a temporary file in the same directory and renames it over the original file. It refuses to replace a read-only file, a file with more than one hard link, or a file owned by another user. Writing or renaming failed or was refused, so the original file was left unchanged. Check the permissions, links, and owner of the file and its directory.";

    E0126 Check "cannot write `{path}`" ""
        [reason: "{reason}", temp_left: "temporary file left at `{temp}`", create_rollback: "could not remove newly created `{config}`: {rollback_reason}; the entry file was not changed", rollback: "could not restore `{config}`: {rollback_reason}; declarations may remain in both files and cause E0911"]
        "The package command could not safely replace or create a file. Check file permissions and the reported reason.";

    E0127 Check "invalid numeric suffix in `{text}`" ""
        [integer_form: "`s8/s16/s32/s64/u8/u16/u32/u64` require an integer literal",
         float_form: "`f32/f64` require a decimal point or an exponent; write a form such as `1.0f32`"]
        "Integer suffixes can follow decimal, hexadecimal, octal, or binary integers. Floating-point suffixes require a decimal point or an exponent. Suffixes cannot be combined with each other or with `m`.";

    // ---- E02: 構文 ----
    E0201 Check "expected {expected}, found {found}" "unexpected {found}"
        [lambda_line: "put `end lambda` on the same physical line as the body, or start the body on the line after the lambda header",
         return_start: "return starts here",
         return_value_line: "start the return value on the same physical line as `return`",
         die_action: "use `try value or die` or `try value or die(message)` to exit on failure",
         type_arguments: "call functions without type arguments, such as `Map.empty()`; write the type on the binding, such as `bind m: Map[String, Integer] <- Map.empty()`, and use `List.get` to read list elements"]
        fix [type_arguments]
        "The parser found a token that cannot appear here.";
    E0202 Check "comparison operators cannot be chained" "second comparison"
        [and: "write the comparisons separately, such as `a < b and b < c`"]
        fix [and]
        "Comparison operators are non-associative.";
    E0203 Check "`.` cannot follow a value" "method-call syntax is not supported"
        [pipe: "pass the value with a pipe, such as `xs |> List.map(f: f)`",
         field: "read a record field with its field function, such as `Person.name(p)` or `p |> Person.name`"]
        "A dot is only used after a module, type, record, trait, or effect name, such as `List.map` or `Shape.Circle`.";
    E0204 Check "`_` can only be a direct argument of a call" "not a call argument"
        [record: "a record construction is not a call; write a lambda instead"]
        "The placeholder `_` builds a function from a call, such as `clamp(lo: 0, value: _, hi: 100)`.";
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
    E0209 Check "a function type with `uses` must be parenthesized here" "read as part of the `uses` list"
        [paren: "write the function type in parentheses, such as `function((function() -> Unit uses Console.Write), List[Integer]) -> Unit`"]
        fix [paren]
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
         question: "write `try` before the expression, such as `try parse(text) or return`",
         fat_arrow: "write the branch as `case pattern -> expression`"]
        fix [equal, not_equal, and, or, not, remainder]
        "Benitoite writes these operators as words or with other symbols.";
    E0212 Check "blocks are not written with braces" "braces are not used"
        [end: "close the block with `end {construct}` instead of `}`",
         open: "start the block with the keyword of the construct; it ends with `end` and the construct name, such as `end function` or `end if`"]
        "Blocks start with a keyword and end with `end` followed by the name of the construct.";
    E0213 Check "`end {found}` does not close `{expected}`" "expected `end {expected}`"
        [lambda_line: "put `end lambda` on the same physical line as the body, or start the body on the line after the lambda header",
         opened: "the `{expected}` block starts here",
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
        [rename: "choose another name",
         renamed: "`{old}` was renamed to `{new}` in 0.0.1",
         alias: "use `{new}`"]
        fix [renamed, alias]
        "Keywords cannot be used as names of variables, functions, or types.";
    E0217 Check "parenthesized lists of values are not tuples" ""
        [pair: "use `Pair`, such as `Pair(a, b)` or the type `Pair[A, B]`",
         triple: "use `Triple`, such as `Triple(a, b, c)` or the type `Triple[A, B, C]`",
         record: "declare a `record` for four or more values"]
        "Benitoite has no tuple syntax. `Pair` and `Triple` hold two or three values, and records hold more.";
    E0218 Check "`{keyword}` cannot be used inside {context}" ""
        [lazy_body: "a `lazy` body produces one value; compute the value with an expression",
         guard: "a guard is a condition; check the value in the branch body instead",
         die_message: "use a pure String expression for the message of `or die`",
         lambda: "`{keyword}` is allowed inside a `lambda ... end lambda` written there"]
        "`return` and `try` cannot leave a `lazy` body, a `match` guard, or the message of `or die`, except inside a `lambda ... end lambda` written there. The function and the arguments of a call with `_` placeholders are not exempt.";
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
    E0243 Check "a lambda is written as `lambda(parameters)` followed by a body" ""
        [lambda: "write `lambda({params}) return {body}`; keep the entire lambda on one physical line, or start the body on the next line and add `end lambda`"]
        "For one statement, prefer a short lambda: `lambda(x) return x + 1`.";
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
         other: "the attributes are `@test`, `@test(\"...\")`, `@deprecated(\"...\")`, and `@external(\"wasm\", \"...\", \"...\")`"]
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

    E0252 Check "`{item}` must come at the start of the file, before `import` and declarations" "written after an import or a declaration"
        [first: "the first import or declaration is here"]
        "Write `language`, `dependency`, and `package` before the first `import` or declaration.";

    E0253 Check "`public(...)` accepts only `package`" "expected `package`"
        [package: "write `package` inside the parentheses"]
        fix [package]
        "Use `public(package)` to share a declaration only within its package.";

    E0254 Check "a lambda without `end lambda` must fit on one physical line" ""
        [crossed: "the lambda continues on another physical line",
         end: "start the body on the next line and add `end lambda` to use a multiline body"]
        "A lambda without its terminator contains one statement and fits on one physical line.";

    E0256 Check "parenthesize the inner lambda when either lambda omits `end lambda`" ""
        [paren: "enclose the inner lambda in parentheses"]
        fix [paren]
        "A directly nested lambda needs parentheses when either lambda omits its terminator.";

    E0257 Check "each function-type parameter must have a name" ""
        [named: "write `function(name: Type) -> Result`"]
        "Function-type parameter names are part of the contract. Use the names required by the surrounding contract.";

    E0258 Check "invalid failure action after `try`" ""
        [return_value: "the `or return` action takes no value",
         die_message: "write exactly one message expression inside the parentheses",
         die_action: "use `or die` or `or die(message)` to exit on failure"]
        "Write `or return` without a value to return the failure, or `or die` with an optional parenthesized message to exit.";

    E0259 Check "parenthesize an explicit `try` expression before continuing it" ""
        [paren: "write `(try ... or return)` or `(try ... or die)` before applying another operator or call"]
        "Enclose an explicit `try` expression in parentheses before continuing it.";

    E0260 Check "invalid documentation example: {reason}" ""
        [syntax: "use `benitoite test`, `benitoite check`, `benitoite error` followed by `diagnostic`, or `benitoite` followed by `output`"]
        "Documentation examples use fenced blocks. Error examples require a real E-code on its own diagnostic line; run examples require output. Files and nonzero exit expectations are not supported in comments.";

    E0261 Check "invalid file-level `uses` declaration" "file-level effects declared here"
        [position: "write one file-level `uses` after all imports and before ordinary declarations",
         empty: "a file-level `uses` requires at least one effect; omit the declaration for an empty set",
         function_line: "write a function's `uses` on the same physical line as its return type"]
        "A file-level `uses` is a single nonempty declaration after imports. Its original location is retained separately from each function's contract.";

    E0262 Check "invalid interpolation format" "invalid format here"
        [empty: "omit the colon for an interpolation without a format",
         whitespace: "remove whitespace from the format",
         minus: "omit `-`; only `+` can be written as a sign flag",
         kind: "use one of `d`, `b`, `o`, `x`, `X`, `f`, `s`, or `c` in this order: align, sign, #, zero, width, precision, kind",
         width: "write an ASCII width from 1 to 65535",
         precision: "write an ASCII precision from 0 to 28 after `.`",
         fixed: "precision requires the kind `f`; append `f` if that is intended",
         align_width: "alignment requires a width",
         zero_width: "zero padding requires a width",
         zero_align: "zero padding cannot be combined with explicit alignment",
         alternate: "`#` requires `b`, `o`, `x`, or `X`"]
        fix [empty, whitespace, minus, fixed]
        "After a complete expression, the colon starts a static format. Its syntax, bounds, and flag combinations are checked separately from compatibility with the expression's type.";

    // ---- E03: 名前、import、公開 ----
    E0301 Check "cannot find `{name}` in this scope" "not found"
        [similar: "a similar name exists: {candidates}",
         renamed: "`{old}` was renamed to `{new}` in 0.0.1"]
        fix [similar, renamed]
        "The name is not bound by a local binding, a function, or a constant visible here.";
    E0302 Check "cannot find `{name}`" "not found"
        [similar: "a similar name exists: {candidates}",
         renamed: "`{old}` was renamed to `{new}` in 0.0.1"]
        fix [similar, renamed]
        "The name before `.` must be a module imported in this file, a prelude module, a type, a record, a trait, or an effect.";
    E0303 Check "`{module}` has no member `{name}`" "not found in `{module}`"
        [similar: "a similar name exists: {candidates}",
         length: "strings have no unit-less length; use `{module}.byteLength` (bytes) or `{module}.characterCount` (characters)",
         slice: "use `{module}.byteSlice` (byte positions) or `{module}.characterSlice` (character positions)",
         index_of: "use `{module}.byteIndexOf`, which returns a byte position",
         unwrap: "there is no `{name}`; use `{module}.unwrapOr` or `match`",
         renamed: "`{old}` was renamed to `{module}.{new}` in 0.0.1",
         alias: "use `{module}.{new}`",
         import_member: "add `import {full}` and use `{local}.`",
         use_imported: "`{full}` is imported as `{local}`; use `{local}.`",
         import_member_as: "add `import {full} as <name>` and use that name, since `{local}` is already used in this file",
         construct: "build a record with its field names, such as `{record}({fields})`",
         members: "`{module}` has: {names}",
         members_more: "`{module}` has: {names}, and {remaining} more",
         shadowed: "`{first}` here is the {shadow_kind} declared in this file, which hides the prelude {prelude_kind} `{first}`",
         shadowing: "`{first}` declared here",
         shadowed_import: "`{first}` here is the module imported in this file, which hides the prelude {prelude_kind} `{first}`",
         imported: "`{first}` imported here",
         prelude: "write `Benitoite.{first}` to use the prelude {prelude_kind}",
         not_reexported: "names imported by `{module}` are not visible through it; import that module directly"]
        fix [similar, renamed, alias, import_member, use_imported, prelude]
        "The module, type, record, trait, or effect does not define this name.";
    E0304 Check "`{name}` is {found_kind}, not {expected_kind}" ""
        [construct: "build a record with its field names, such as `{record}({fields})`"]
        "Each position accepts only one kind of name.";
    E0305 Check "the name `{name}` is defined more than once" "redefined here"
        [first: "first defined here",
         import: "give the import another name with `as`, such as `{suggestion}`",
         rename: "rename the declaration `{name}`; the module `{module}` declares built-in effects and cannot be renamed with `as`"]
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
        "Parameter names must be unique within a function, lambda, or function type.";
    E0311 Check "`{name}` is bound more than once in the same pattern" "bound again here"
        [first: "first bound here"]
        "A pattern cannot bind the same variable twice.";
    E0312 Check "the type parameter `{name}` is declared more than once" "redeclared here"
        [first: "first declared here"]
        "Type parameter names must be unique within a list.";
    E0313 Check "the type parameter `{name}` has the same name as a top-level declaration, an imported name, or a prelude name" ""
        [declared: "the other declaration is here"]
        "Type parameters and effect variables cannot reuse the module's top-level uppercase names, imported names, prelude names, or `Benitoite`.";
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
    E0318 Check "cannot find module `{module}`" "no file `{path}` under {where}"
        [similar: "a similar module exists: {candidates}",
         case_only: "the directory has `{actual}`, which differs only in upper and lower case",
         package: "modules of the package `{package}` are imported by their path from the package root `{root}`"]
        "A module name refers to a file under the starting root or a declared package root, such as `Lib/Text.bnt` for `Lib.Text`.";
    E0319 Check "the module `{module}` is outside {where}" ""
        [resolved: "`{path}` resolves to `{target}`, outside `{root}`"]
        "An imported module must stay within its root directory or package root after resolving symbolic links.";
    E0320 Check "the module where execution starts cannot be imported" ""
        [entry: "`{module}` is the starting file of this program"]
        "The starting module is not a library. Move the shared declarations to another module.";
    E0321 Check "`{module}` is not a standard library module" ""
        [similar: "a similar module exists: {candidates}",
         last_segment: "use {candidates}",
         root_file: "names that start with `Benitoite` always refer to the standard library, so `{path}` cannot be imported",
         unofficial: "this module is unofficial in this version and is imported as `{suggestion}`",
         standard: "this module is a standard module in this version and is imported as `{suggestion}`"]
        fix [similar, last_segment, unofficial, standard]
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
        [reserved: "`Benitoite` always refers to the standard library namespace",
         dependency: "a dependency cannot be named `Benitoite`, which always refers to the standard library"]
        "`Benitoite` cannot be declared or used as an import name or a dependency alias.";
    E0326 Check "the effect `{name}` has the same name as its module" ""
        [rename: "effects are not modules; choose a name different from the module name"]
        "An effect cannot have the name of the module that declares it, because a qualified name such as `Log.write` would be ambiguous.";
    E0327 Check "the field `{name}` is declared more than once" "redeclared here"
        [first: "first declared here"]
        "Field names must be unique within a record.";
    E0328 Check "the method `{name}` is declared more than once in `{trait_name}`" "redeclared here"
        [first: "first declared here"]
        "Method names must be unique within a trait.";
    E0329 Check "the {level} {what} `{name}` uses the {used_level} {used_kind} `{used}`" "`{used}` is not public"
        [declared: "`{used}` is declared here",
         make_public: "mark `{used}` as `{target}`",
         handle: "handle the effect inside the function before returning",
         file_contract: "the file-level uses adds this effect to every public top-level function in the file",
         file: "remove the effect from the file-level uses or move the public functions to a file without that declaration"]
        fix [make_public]
        "Everything a declaration exposes, including types, traits, and effects, must be at least as visible as the declaration.";
    E0330 Check "`{name}` is not public in `{module}`" "not public"
        [declared: "declared here",
         shadowed: "`{first}` here is the {shadow_kind} declared in this file, which hides the prelude {prelude_kind} `{first}`",
         shadowing: "`{first}` declared here",
         shadowed_import: "`{first}` here is the module imported in this file, which hides the prelude {prelude_kind} `{first}`",
         imported: "`{first}` imported here",
         prelude: "write `Benitoite.{first}` to use the prelude {prelude_kind}",
         make_public: "mark `{name}` as `public` in `{declared_in}`",
         package: "`{declared_in}` belongs to a dependency package; use its public names",
         package_only: "`{name}` is marked `public(package)`, so only modules of the same package can use it"]
        fix [prelude, make_public]
        "Use `public` declarations of another module, or `public(package)` declarations within the same package.";
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
    E0339 Check "the module `{module}` declares built-in effects and cannot be renamed with `as`" "renamed here"
        [remove: "remove `as {name}` and replace references to `{name}.` with `{original}.`"]
        fix [remove]
        "Modules that declare built-in effects cannot be renamed, so that `uses` always shows the original effect names, such as `Console.Write` and `File.Write`.";

    E0340 Check "the representation of opaque type `{type}` is private to `{module}`" "representation is private"
        [declared: "opaque type declared here",
         public_api: "use the module's public construction and inspection functions"]
        "Outside the declaring module, an opaque type can be passed as an ordinary value, but its constructors, fields, record updates, and representation patterns cannot be used.";

    // ---- E04: 型 ----
    E0401 Check "mismatched types" "expected `{expected}`, found `{found}`"
        [declared: "expected because of this",
         escaped: "`{param}` is a type parameter of the operation `{operation}`; a value of this type cannot leave the clause",
         clause: "the clause of `{operation}`",
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
         numeric_width: "use the `{suffix}` literal suffix for `{expected}`, or explicitly convert a value to that type; numeric types are not converted implicitly",
         to_string: "convert the value with `{function}`, or use string interpolation such as `\"${x}\"`",
         to_string_any: "convert the other value to a `String` before joining it with `+`, or use string interpolation",
         shadowed: "`{shadowed}` here is a type declared in a user module, which hides the prelude name `{shadowed}`",
         prelude_type: "write `Benitoite.{shadowed}` for the prelude type"]
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
        [why: "types that contain functions or built-in opaque types without equality such as `IOError` cannot be compared with `=` or `<>`",
         constraint: "add the constraint `equality` to the type parameter, such as `[{param}: equality]`",
         operation: "add the constraint `{constraint}` to the type parameter `{declared}` in the declaration of the operation `{operation}`"]
        fix [constraint]
        "Equality types contain no function types, no built-in opaque types without equality such as `IOError`, and no external types. An `@opaque` data type or record follows the equality rules for its contents.";
    E0407 Check "the type of this expression cannot be determined" ""
        [annotate: "add a type annotation"]
        "An operator, an interpolation, a comparison, a key, a trait method, a `try`, or a `with` needs its type to be known by the end of the function body.";
    E0408 Check "integer literal is out of range for `Integer`" ""
        [range: "`Integer` values range from -9223372036854775808 to 9223372036854775807"]
        "Integer literals must fit in a 64-bit signed integer.";
    E0409 Check "floating-point literal is too large for `Float`" "" []
        "The literal rounds to infinity.";
    E0410 Check "`{name}` expects {expected} type argument(s) but {found} were given" ""
        [shadowed: "`{shadowed}` here is a type declared in a user module, which hides the prelude name `{shadowed}`",
         prelude_type: "write `Benitoite.{shadowed}` for the prelude type"]
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
         effects: "`main` can only use the built-in effects in `IO.All`, the network effects, and `Log`",
         assert: "`main` cannot use `Assert.Check`"]
        "`main` has no parameters, returns `Unit` or `Result[Unit, String]`, and uses only built-in effects.";
    E0416 Check "the value of this expression is not used" "this has type `{found}`, not `Unit`"
        [return_value: "write `return` to return this value from the {what}",
         discard: "write `bind _ <- ...` to discard the value",
         reassign: "`=` compares values and variables cannot be reassigned; to bind a new value to the name, write `shadow {name} <- ...`"]
        fix [return_value, discard, reassign]
        "An expression statement must have type `Unit` unless it is the last in a block other than a function or lambda body. Return a value from a function or lambda with `return`.";
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
         convert: "convert the value to a `String` before interpolating it",
         type_param: "add the constraint `{constraint}` to the type parameter, such as `[{param}: {constraint}]`, and convert the value with `{function}`",
         type_param_import: "write `import Benitoite.Trait`, add the constraint `Trait.Show` to the type parameter, such as `[{param}: Trait.Show]`, and convert the value with `Trait.Show.show`",
         rigid: "values of the operation's type parameter `{declared}` cannot be converted to `String`; interpolate a value of a known type instead"]
        fix [show]
        "`${...}` accepts `String`, `Integer`, `Float`, `Decimal`, `Byte`, `Character`, and `Boolean`.";
    E0423 Check "`{ty}` cannot be used as a key" ""
        [float: "`Float` has values that are not equal to themselves; use `Integer`, `Decimal`, or `String` instead"]
        "Map keys and set elements must have types that satisfy `key`. Types that contain `Float` do not.";
    E0424 Check "the type parameter `{param}` needs the constraint `{constraint}`" ""
        [required: "required by this use",
         add: "add the constraint, such as `[{param}: {constraint}]`",
         operation: "add the constraint `{constraint}` to the type parameter `{declared}` in the declaration of the operation `{operation}`"]
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
    E0435 Check "computing the constant `{name}` fails: {condition}" "fails here"
        [budget: "compute this value in a function without parameters, which runs when the script runs"]
        "A constant is computed when the script is checked. Its computation must not stop with a runtime error, and the values that the constants create must fit in the budget for constants; compute a large value in a function without parameters instead.";
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
         declared_lambda: "the lambda returns `{declared}`",
         declared_placeholder: "the function made by `_` in this call returns `{declared}`",
         placeholder_call: "this call with `_` makes a function",
         convert: "convert the value with `Option.okOr` or `Result.ok` before `try`"]
        "`try` on a `Result` needs the enclosing function or lambda to return a `Result`, and `try` on an `Option` needs it to return an `Option`.";
    E0442 Check "`try` cannot return an error of type `{found}` from a function that returns errors of type `{expected}`" ""
        [declared: "the function returns `{declared}`",
         declared_lambda: "the lambda returns `{declared}`",
         declared_placeholder: "the function made by `_` in this call returns `{declared}`",
         placeholder_call: "this call with `_` makes a function",
         map_error: "convert the error with `Result.mapError` before `try`"]
        "The error type of the value after `try` must be the error type of the function's result.";
    E0443 Check "`{ty}` is not a resource type" ""
        [resources: "`with` binds values opened by functions such as `File.openReader` and `TaskGroup.open`"]
        "A `with` binding needs a resource, which is released when the block ends.";

    E0446 Check "integer literal is out of range for `Byte`" ""
        [range: "a `u8` literal must be between 0 and 255"]
        "The suffix `u8` denotes `Byte`. Byte literals are checked before execution and cannot be negative.";
    E0447 Check "integer literal is out of range for `{ty}`" ""
        [range: "`{ty}` values range from {minimum} to {maximum}"]
        "A suffixed integer literal must fit in its declared width, including a directly applied minus sign.";
    E0449 Check "this function requires named arguments" ""
        [available: "available parameters, in declaration order: {names}",
         named: "add the parameter names in declaration order"]
        fix [named]
        "Use parameter names when calling a function with two or more parameters.";
    E0450 Check "named and positional arguments cannot be mixed" ""
        [first: "the first argument uses the other form"]
        "Use named arguments consistently in a call.";
    E0451 Check "this function has no parameter named `{name}`" ""
        [available: "available parameters, in declaration order: {names}"]
        "An argument label must name a parameter of the function contract.";
    E0452 Check "the parameter `{name}` is supplied more than once" ""
        [first: "first supplied here"]
        "Each parameter must be supplied exactly once.";
    E0453 Check "missing arguments for parameters: {names}" "" []
        "Supply each parameter of the function contract.";
    E0456 Check "direct constructor calls use positional fields" ""
        [bind: "use positional fields, or bind the constructor to a function value before using named arguments"]
        "Direct data construction uses positional fields; constructor function values have parameter contracts.";
    E0457 Check "invalid constant regular expression: {reason}" "invalid pattern"
        [constant: "constant declared here", origins_omitted: "{omitted} other constant declarations omitted"]
        "A direct Regex.compile call checks a known constant source. Pass dynamic input to observe Result.Error at runtime.";
    E0458 Check "constant regular expression exceeds the compilation limit: {reason}" "compilation limit"
        [constant: "constant declared here", origins_omitted: "{omitted} other constant declarations omitted"]
        "The runtime RegexBuilder also rejects this source. The constant evaluation budget is a separate limit.";
    E0459 Check "invalid constant scope pattern: {reason}" "invalid pattern"
        [constant: "constant declared here", origins_omitted: "{omitted} other constant declarations omitted"]
        "Use an exact host/path pattern, *.host, **.host, or an absolute path ending in /**.";
    E0460 Check "invalid constant scope target: {reason}" "invalid target"
        [constant: "constant declared here", origins_omitted: "{omitted} other constant declarations omitted"]
        "Supply a host or absolute path with the spelling required by Scope.";
    E0461 Check "invalid constant scope port bounds or port" "invalid port"
        [constant: "constant declared here", origins_omitted: "{omitted} other constant declarations omitted", condition: "lower bound supplied here"]
        "Ports must be between 0 and 65535, and minimumPort must not exceed maximumPort.";
    E0463 Check "a builder requires an annotated local bind and a direct new call" ""
        [bind: "use `bind b: StringBuilder <- StringBuilder.new()`"]
        "Builder declarations require a dedicated annotation and matching direct new call.";
    E0464 Check "a local builder cannot be used as an ordinary type or value" ""
        [copy: "use copy to obtain an ordinary immutable value"]
        "Builder classifications are allowed only in annotated local binds; builder names are allowed only as direct operation targets.";
    E0465 Check "a local builder cannot be captured across {boundary}" ""
        [declared: "builder declared here", boundary: "capture boundary starts here",
         copy: "bind a copy or length before the boundary and capture that ordinary value"]
        "A lambda, lazy expression, partial application, or handler clause starts a fresh builder context.";
    E0466 Check "builder operations require a direct call" ""
        [direct: "write a direct call without holes or a pipe"]
        "Builder operations cannot be used as function values, partially applied, or piped.";
    E0467 Check "SourceLocation.here requires a direct call" ""
        [direct: "write `SourceLocation.here()` and pass the resulting location explicitly"]
        "The standard here expression cannot be used as a function value, partially applied, or piped.";
    E0468 Check "a value of type `{ty}` is incompatible with this interpolation format" "incompatible format"
        [value: "value has type `{ty}`", allowed: "this format accepts {allowed}",
         change: "choose a format compatible with the value's type; numeric formatting requires an explicitly numeric value",
         integer_fixed: "use `d` for integer output, or explicitly convert the value to Float, Float32, or Decimal if fractional output is intended"]
        "Static interpolation formats restrict the value to a closed set of basic types. No implicit conversion or user-defined Show implementation changes this set.";
    E0462 Check "constant target is outside the supplied scope" "outside scope"
        [constant: "constant declared here", origins_omitted: "{omitted} other constant declarations omitted", condition: "scope condition supplied here"]
        "The known target does not satisfy the supplied host/path pattern or inclusive port range.";
    E0454 Check "function parameter names do not match" ""
        [declared: "method declared here",
         contracts: "expected `{expected}`, found `{found}`",
         first_name: "parameter {index}: expected `{expected_name}`, found `{found_name}`"]
        "Function types must have the same parameter names in the same order.";
    E0455 Check "the parameter names and order of this function cannot be determined" ""
        [annotation: "add a function-type annotation with parameter names",
         bind: "bind the callee to a value with an explicit named function type before using a pipe or placeholders"]
        "The function contract must be determined before type checking finishes.";

    E0448 Check "floating-point literal is too large for `Float32`" "" []
        "The literal rounds to infinity in binary32.";

    // ---- E05: エフェクト、ハンドラ ----
    E0501 Check "this function performs `{effect}` but does not declare it" "`{effect}` happens here"
        [declared: "declared here",
         add_uses: "add `uses {effect}` to the signature, or move this call to a function that uses `{effect}`",
         die_uses: "add `uses Process.Exit` to the signature for `or die`",
         die_import: "add `import Benitoite.Unofficial.IO.Process` and `uses Process.Exit`; the internal dependency of `or die` does not import the name `Process`"]
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
        [handle: "handle `{effect}` with `handle ... with` inside `{function}`",
         to_result: "or convert the failure with Failure.toResult inside `{function}`",
         file: "remove the effect from the file-level uses or move `{function}` to a file without that declaration; handling it in the body does not remove the declared effect"]
        "Effects declared by the program must be handled inside `main` and inside test functions. For the standard Failure.Fail, import Benitoite.Unofficial.Failure, catch it with Failure.toResult, and remove the handled Fail from the entry function's uses. Result.andThen/flatMap chains Result values; it does not handle Fail.";
    E0507 Check "`{name}` is not an operation of an effect" ""
        [state: "`State` has no operations and cannot be handled"]
        "A clause of `handle` names an operation declared in an `effect`.";
    E0508 Check "the operation `{name}` is handled twice in one `handle`" "second clause"
        [first: "first clause here"]
        "Each operation has at most one clause in a `handle`.";
    E0509 Check "`resume` can only be used directly in a clause of `handle`" ""
        [lambda: "`resume` cannot be used in a lambda or a `lazy` body inside a clause",
         die_message: "`resume` cannot be used in the message of `or die`; use a pure String expression",
         guard: "`resume` cannot be used in a `match` guard; call it in the body of the branch",
         placeholder: "`resume` cannot be used in an argument of a call with `_` placeholders; the arguments are evaluated inside the function that the call creates"]
        "`resume` continues the computation that performed the operation, so it is written in the clause itself, not inside a lambda, a `lazy` body, a `match` guard, the message of `or die`, or an argument of a call with `_` placeholders.";
    E0510 Check "invalid effect operation declaration" ""
        [uses: "an operation declaration cannot have `uses`; the handler decides the effects",
         effect_var: "an operation cannot have effect variables",
         type_ctor: "an operation cannot have type constructor parameters such as `F[_]`"]
        "Operations of an effect are declared with a name, parameters, and a result type.";

    E0511 Check "the message of `or die` cannot perform `{effect}`" ""
        [pure: "use a pure String expression for the message",
         message: "the message is written here"]
        "The optional message of `or die` must be a pure String expression.";

    E0512 Check "effects of `{function}` exceed `--allow-effects`" "effect limit checked for this function"
        [missing: "effects not allowed: {missing}",
         allowed: "allowed effects: {allowed}",
         file: "added to this function by the file-level uses declaration",
         review: "review the required effects before changing --allow-effects"]
        "The declared atomic effects of the checked function (main or a test) exceed the set passed to --allow-effects. Nothing is started. Review the required effects before changing the allowed set. This is a static check, not runtime permission control or an OS sandbox.";

    E0513 Check "invalid type arguments for effect `{name}` (expected {count})" ""
        []
        "Only the standard Failure.Fail takes exactly one value type argument.";
    E0514 Check "incompatible failure types `{expected}` and `{found}` in one effect set" ""
        [convert: "convert errors explicitly in a failure clause before joining effects",
         individual: "the function's uses is declared here"]
        "A source computation can have at most one invariant failure type.";
    E0515 Check "cannot establish that the remaining effects exclude Failure.Fail" ""
        [signature: "declare Failure.Fail in the callback signature, handle failures inside the callback, or move the handle boundary"]
        "NoFail conditions come only from declared signatures. A row next to an explicit Failure.Fail excludes failures.";
    E0516 Check "`resume` is not allowed in a failure clause" ""
        [result: "return the result of the whole handle instead"]
        "Failure.raise aborts the captured continuation.";
    E0517 Check "cannot determine the error type caught by this handle" ""
        [annotation: "annotate the callback or result type to fix the failure type"]
        "The failure type must be fixed before its handler is erased.";
    E0518 Check "cannot mix failure and ordinary operation clauses in one handle" ""
        [nest: "nest two handles instead"]
        "A failure handle contains exactly one Failure.raise clause.";

    // ---- E06: パターン ----
    E0601 Check "`match` does not cover every value" "`{witness}` is not matched"
        [add_arm: "add a branch `case {witness} ->`, or `case _ ->`",
         future: "add an unguarded variable or `_` pattern to cover future values of `{future_ty}`",
         extensible_decl: "this type permits future shapes outside its package"]
        r"Every possible value must be matched by some branch. Character ranges can cover all Unicode scalars without a catch-all. For a match containing only 'a', the missing-character witness is '\u{0}'. Integer ranges still need a catch-all.";
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
        [match: "use `match ... with` to handle the other values",
         future: "use `match ... with` and add an unguarded `case _ ->` branch to cover future values of `{future_ty}`",
         extensible_decl: "this type permits future shapes outside its package"]
        "The pattern on the left of `bind` or `shadow` must match every value.";
    E0608 Check "this alternative can never be selected" "unreachable alternative"
        [covering: "already matched here"]
        "Earlier patterns match every value this alternative matches.";

    E0609 Check "could not confirm that {subject}" "checking exceeded a coverage budget: {limit}"
        [split: "split the `match` into smaller ones, or check fewer fields in one branch",
         split_pattern: "check fewer fields in this pattern, or bind the value first and check the fields separately"]
        "The checker limits the work it spends on deciding whether a `match` covers every value and whether a pattern on the left of `bind` or `shadow` matches every value. A `match` or a pattern that needs more work than the limit is an error.";

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
        [required: "required by this use",
         die_show: "implement Trait.Show or convert the error with Result.mapError"]
        "A value used with a trait method, or passed where a constraint is required, must have an implementation.";
    E0706 Check "the type parameter `{param}` needs the constraint `{trait_name}`" ""
        [add: "add the constraint, such as `[{param}: {trait_name}]`",
         die_show: "implement Trait.Show or convert the error with Result.mapError"]
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

    E0715 Check "the dictionary for `{trait_name}` on `{ty}` is too large" "more than {limit} dictionary and type nodes are needed here"
        [reduce: "nest the types less deeply, or require fewer traits of the type parameters in the implementations"]
        "Nesting implementations that require two or more traits of the same type parameter doubles the size of the dictionary at each level. The checker limits the total number of dictionary nodes and type nodes copied into them.";

    // ---- E08: 属性 ----
    E0801 Check "unknown attribute `@{name}`" ""
        [allowed: "the attributes are `@test`, `@test(\"...\")`, `@deprecated(\"...\")`, `@extensible`, `@opaque`, and `@external(\"wasm\", \"...\", \"...\")`"]
        "Only the listed attributes can be written.";
    E0802 Check "`@{name}` cannot be written on {what}" "" []
        "`@test` is written on functions. `@external` is written on top-level functions and on `type` declarations without a right-hand side. `@deprecated` is written on functions, constants, `data` types, type aliases, records, traits, and effects. `@extensible` is written on `data` types and records. `@opaque` is written on public or package-public `data` types and records.";
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
        [body: "write the body and close it with `end function`",
         external: "to call a function of a WebAssembly component, write `@external(\"wasm\", \"path\", \"name\")` before the function"]
        "A function needs a body, unless it is an external function declared with `@external` or a built-in function of the standard library.";
    E0809 Check "`@external` takes three strings: the kind, the component path, and the function name" ""
        [form: "write `@external(\"wasm\", \"wasm/fuzzy.wasm\", \"distance\")`"]
        "External declarations identify a component and one exported function.";
    E0810 Check "unknown kind of external function `{kind}`" "unknown kind"
        [wasm: "this version supports only `\"wasm\"`"]
        "Only WebAssembly components can provide external functions.";
    E0811 Check "an external {what} cannot have type parameters" "type parameters"
        [fixed: "write concrete types for the parameters and the result; the types are checked against the component",
         resource: "an external type stands for one resource of the component and takes no type parameters"]
        "External functions have concrete parameter and result types.";
    E0812 Check "an external function can declare only `uses State`, and only when its type contains an external type" "not allowed here"
        [pure: "external functions that pass external types declare `uses State`; all other external functions are pure",
         remove: "remove `uses`",
         state: "replace `uses` with `uses State`",
         file: "remove the incompatible effect from the file-level uses or move the external function to a file without that declaration"] fix [remove, state]
        "External functions declare State exactly when passing external types.";
    E0813 Check "`@external` cannot be combined with `@{other}`" "" []
        "An external function cannot also be a test or a built-in function.";
    E0814 Check "an external function has no body" "remove this body"
        [remove: "the component provides the body; end the declaration after the result type"]
        "An external function obtains its body from the component.";
    E0815 Check "the interface and function names in `@external` must both be nonempty" ""
        [form: "write `interface#function`, with a name on each side of the last `#`"]
        "The third argument of `@external` selects a function directly or as `interface#function`. Neither side of the last `#` can be empty.";

    E0816 Check "the external function `{name}` passes an external type, so it must declare `uses State`" "external type in this signature"
        [state: "add `uses State` after the result type"] fix [state]
        "Functions that pass external types use component state.";

    E0817 Check "`@extensible` takes no arguments" ""
        [remove: "remove the arguments from `@extensible`"]
        "`@extensible` is written without arguments on a `data` type or record.";

    E0818 Check "`@opaque` takes no arguments" ""
        [remove: "remove the arguments from `@opaque`"]
        "Write `@opaque` without arguments on a public or package-public data type or record.";
    E0819 Check "`@opaque` cannot be combined with `@{other}`" "incompatible attributes" []
        "`@opaque` cannot be combined with `@extensible` or `@external`; an external type is already opaque.";
    E0820 Check "`@opaque` requires a public or package-public data or record declaration" "" []
        "The opaque attribute separates visibility of a type from access to its representation.";

    // ---- E09: パッケージと依存 ----
    E0901 Check "unknown field `{field}` in `{block}`" ""
        [fields: "the fields of `{block}` are {fields}"]
        "Dependency fields are `path` and `hash`; `source`, `version`, and `commit` are recognized but unavailable. `package` blocks accept only `license`.";
    E0902 Check "{what} is written more than once" "written again here"
        [first: "first written here"]
        "Each field, `language` line, `package` block, and dependency alias may appear only once in the header.";
    E0903 Check "the field `{field}` cannot be used in this version" ""
        [local: "this version reads dependencies only from a local directory written with `path`"]
        "Only local `path` dependencies are supported. Do not write `source`, `version`, or `commit`.";
    E0904 Check "the dependency `{alias}` has no `path`" ""
        [path: "write the directory of the package, such as `path \"../textkit\"`"]
        "Each dependency needs a `path` field.";
    E0905 Check "malformed language version `{version}`" ""
        [form: "write three numbers separated by `.`, such as `0.0.3`"]
        "Language versions have three ASCII decimal numbers that fit in 64 bits, without leading zeroes except for zero itself.";
    E0906 Check "malformed hash `{hash}`" ""
        [form: "write `sha256:` followed by 64 lowercase hexadecimal digits"]
        "A dependency hash consists of `sha256:` and exactly 64 lowercase hexadecimal digits.";
    E0907 Check "this file needs Benitoite {version} or later, but this is Benitoite {current}" "" []
        "The declared language version is newer than the interpreter. Use an interpreter at least as new as the declaration.";
    E0908 Check "this file was written for Benitoite {version}, and the language changed incompatibly in {changed}" ""
        []
        "The main message identifies the first incompatible language change after the declared version and no later than the interpreter's version. Notes list every applicable version and its summary in version order, and helps list the corresponding migration guidance in the same order, without source edits.";
    E0909 Check "`{item}` can be written only at the start of the starting file or in `package.bnt`" "" []
        "Imported modules cannot have `language` or `dependency` headers. A `package` block can be written only in `package.bnt`.";
    E0910 Check "a `package` block can be written only in `package.bnt`" "" []
        "Move the `package` block into `package.bnt` at the root.";
    E0911 Check "{what} is written both at the start of `{file}` and in `package.bnt`" ""
        [other: "also written here"]
        "Write dependencies in one place, either the starting file or `package.bnt`. The same rule applies to `language` declarations.";
    E0912 Check "`package.bnt` can contain only `language`, `dependency`, and `package`" "not allowed in `package.bnt`" []
        "A settings file cannot contain imports or declarations.";
    E0913 Check "`{path}` is a settings file and cannot be checked, run, or tested" "" []
        "Do not specify `package.bnt` as a starting file. Check, run, or test the scripts that use it; `fmt` can format it.";
    E0914 Check "the package `{package}` needs a `language` line" "" []
        "A `package.bnt` with a `package` block must declare the language version, even when checked as the root package.";
    E0915 Check "a package cannot have dependencies in this version" ""
        [package: "this `package.bnt` declares the package `{package}`"]
        "A `package.bnt` with a `package` block cannot contain dependencies in this version.";

    E0916 Check "cannot read the dependency `{alias}` at `{path}`" ""
        [reason: "{reason}"]
        "The dependency directory and its `package.bnt` must be readable.";
    E0917 Check "the dependency `{alias}` at `{path}` is not a Benitoite package" ""
        [no_config: "the directory has no `package.bnt`",
         no_block: "its `package.bnt` has no `package` block"]
        "A dependency must have `package.bnt` with a `package` block and a `language` line.";
    E0918 Check "`{module}` names both a module under the root directory and a module of the dependency `{alias}`" ""
        [root_file: "under the root directory: `{root_path}`",
         package_file: "in the package `{package}`: `{package_path}`",
         rename: "rename the directory under the root directory, or the dependency"]
        "An import cannot refer to two different files. A root path and package path resolving to the same file are allowed.";

    E0919 Check "the contents of the dependency `{alias}` do not match its `hash`" ""
        [expected: "expected: {expected}",
         computed: "computed: {computed}",
         package: "package: `{package}`",
         update: "if the change is intended, write the computed hash"]
        "A dependency with `hash` must match the computed hash of its package contents. Update the declaration only if the change is intended.";
    E0920 Check "cannot compute the hash of the dependency `{alias}`" ""
        [symlink: "`{path}` is a symbolic link",
         case: "`{path}` and `{other}` have the same path after conversion to Unicode lowercase",
         name: "`{path}` contains a newline",
         too_many: "the number of included files exceeds the limit of {limit}",
         too_many_entries: "the number of visited directory entries exceeds the limit of {limit}",
         too_large: "the total size of included files exceeds the limit of {limit} bytes",
         read: "cannot read `{path}`: {reason}",
         package: "package: `{package}`"]
        "The package hash rejects symbolic links, colliding lowercase paths, newline-containing paths, unreadable files, and packages exceeding the file count, directory entry count, or total size limit.";

    E0921 Check "`{path}` belongs to the dependency `{alias}` and cannot be imported as a root module" "use the dependency alias"
        [package: "package: `{package}`",
         import: "write `import {suggestion}`"]
        fix [import]
        "A file under a declared dependency root must be imported through its dependency alias.";
    E0922 Check "the dependency `{alias}` at `{path}` overlaps another root" "invalid dependency root"
        [root: "a dependency root cannot be the root directory itself or an ancestor of it",
         dependency: "dependency roots cannot be equal or contain one another",
         other: "the overlapping dependency `{other}` is declared here"]
        "Choose a dependency directory that does not contain the starting root and does not overlap another dependency root.";

    E0923 Check "the dependency `{alias}` is already declared" "existing dependency" []
        "Use a different alias or update the existing dependency.";
    E0924 Check "the dependency `{alias}` is not declared" "" []
        "Specify an alias declared in the entry or package.bnt.";
    E0925 Check "there are no header items to move" "" []
        "The entry must contain language or dependency declarations.";
    E0926 Check "`{path}` already contains language or dependency declarations" "existing declaration" []
        "Do not overwrite existing declarations when moving the entry header.";
    E0927 Check "cannot choose a file for the dependency declaration" "" [entry: "specify an entry file, or create package.bnt"]
        "A root without an entry and without package.bnt has no destination.";
    E0928 Check "cannot move the header of `package.bnt`" "" []
        "Specify an entry file rather than the configuration file.";
    E0929 Check "malformed recorded effects" "" []
        "The effects field must be empty or a comma-separated list of uppercase names such as Console.Write, File.Read. It records the last package command report and is not checked against package contents during loading.";

    // ---- E10: 外部の関数 ----
    E1001 Check "cannot read the component `{path}`" "" [reason: "{reason}"]
        "The component must be a readable file within the allowed directory.";
    E1002 Check "malformed component path `{path}`" ""
        [form: "write a relative path separated by `/` that ends with `.wasm`, without `.` or `..`",
         hidden: "a name that starts with `.` is not part of a package"]
        "Component paths use visible relative names and the `.wasm` extension.";
    E1003 Check "the component `{path}` is outside the {base}" ""
        [root: "a component of a module under the root directory must be under the root directory",
         package: "a component of the package `{package}` must be under its `wasm` directory"]
        "Canonical component paths must remain within the allowed directory.";
    E1004 Check "`{path}` is not a WebAssembly component" ""
        [not_wasm: "the file does not start with the WebAssembly magic bytes",
         core: "it is a core WebAssembly module; wrap it with `wasm-tools component new`",
         invalid: "the component is invalid: {reason}"]
        "External functions require binary WebAssembly components.";
    E1005 Check "the component `{path}` imports {count}, so it cannot be called as a pure function" ""
        [imports: "imports: {names}",
         target: "build it for `wasm32-unknown-unknown` and wrap it with `wasm-tools component new`; `wasm32-wasip2` adds WASI imports"]
        "Only components without imports can provide pure external functions, including calls through generated adapters.";
    E1006 Check "the component `{path}` has no function `{name}`" ""
        [exports: "the functions it exports are {names}",
         version: "the component exports the interface as `{found}`; the version must match exactly",
         interface: "`{name}` is an interface; write `{name}#function`"]
        "External declarations name a function exported by the component, directly or as `interface#function`.";
    E1007 Check "the function `{name}` of the component takes {found}, but `{function}` declares {expected}" ""
        [declaration: "the component function corresponds to `{declaration}`"]
        "The declared parameter count must match the component function.";
    E1008 Check "argument {index} of `{function}` does not match the component" "declared as `{declared}`"
        [component: "the component expects `{wit}`", maps: "`{declared}` is passed as `{expected}`", reason: "{reason}",
         declaration: "the component function corresponds to `{declaration}`",
         user_type: "`{name}` here is the type declared in `{file}`, not `Benitoite.{name}.{name}`"]
        "Parameter types are checked by position against their WIT representations.";
    E1009 Check "the result of `{function}` does not match the component" "declared as `{declared}`"
        [component: "the component returns `{wit}`", maps: "`{declared}` is passed as `{expected}`", reason: "{reason}",
         declaration: "the component function corresponds to `{declaration}`",
         user_type: "`{name}` here is the type declared in `{file}`, not `Benitoite.{name}.{name}`"]
        "The result type must match its WIT representation.";
    E1010 Check "`{ty}` cannot be passed to or from an external function in this version" ""
        [types: "the types that can be passed are Integer, Integer8, Integer16, Integer32, Float, Float32, Boolean, Character, String, Byte, UnsignedInteger16, UnsignedInteger32, UnsignedInteger64, Bytes, List, Map, Set[D] as flags when D is a data type with 1 to 32 constructors that take no arguments, Option, Result, Pair, Triple, records and `data` types with concrete type arguments that are not recursive (including a single-constructor data type passed as a tuple), and Unit as a result",
         recursive: "recursive types cannot be passed, including recursion through List or other types",
         recursive_declaration: "the dependency cycle includes the declaration of `{recursive_name}`",
         flags_count: "flags require a data type with 1 to 32 constructors; empty selections are allowed",
         flags_data: "flags require Set[D], where D is a concrete data type and every constructor takes no arguments",
         map_key: "map keys must be Boolean, an integer of any supported width, Character, or String",
         budget: "types deeper than 100 cannot match any WIT type; larger types are not checked (100,000 expanded nodes per type, 1,000,000 per check); declaration dependency visits also count toward the per-check limit",
         adapter_preparation: "external function `{name}` cannot prepare its generated adapter within the type-walk budget",
         adapter_preparation_budget: "adapter preparation allows 4,000,000 type-node visits per declaration, separately from WIT matching",
         declaration_budget: "external function `{name}` is not checked because the total type expansion budget is exhausted",
         declaration: "external declaration `{name}`",
         user_type: "`{name}` here is the type declared in `{file}`, not `Benitoite.{name}.{name}`"]
        "External functions accept only the supported concrete types.";
    E1011 Check "the function `{name}` of the component `{path}` is asynchronous" "" []
        "External functions must be synchronous in this version.";
    E1012 Check "the component `{path}` has no resource `{name}`" ""
        [exports: "exported resources: {names}"]
        "External types name an exported resource of the component.";

    // ---- W03: 名前の警告 ----
    W0301 Check "`{name}` is deprecated" "deprecated"
        [declared: "declared deprecated here",
         message: "{message}"]
        "The declaration is marked `@deprecated` and may be removed later. The note shows its message.";

    // ---- W04: 型と演算の警告 ----
    W0401 Check "this divides by zero" "the divisor is always 0"
        [inferred_range: "the inferred divisor interval is {interval}",
         local_analysis: "this local analysis applies only if execution reaches this operation and all operands are evaluated successfully",
         origin: "this binding or comparison contributes to the inferred interval"]
        "Constant evaluation or local interval analysis shows that the divisor is always zero. If execution reaches this operation and all operands are evaluated successfully, the division stops the program at runtime.";
    W0402 Check "this calculation overflows `{ty}`" "always overflows"
        [inferred_range: "the inferred result interval before the range check is {interval}",
         allowed_range: "the range of `{ty}` is {range}",
         local_analysis: "this local analysis applies only if execution reaches this operation and all operands are evaluated successfully",
         origin: "this binding or comparison contributes to the inferred interval"]
        "Constant evaluation or local interval analysis shows that the result does not fit the type. If execution reaches this operation and all operands are evaluated successfully, the calculation stops the program at runtime.";
    W0403 Check "the key `{key}` appears more than once" "repeated key"
        [first: "first given here"]
        "`Map.fromList` keeps the last value for a repeated key and `Set.fromList` keeps one element, so a repeated key in a list literal is likely a mistake.";
    W0404 Check "argument `{parameter}` to `{function}` is always out of range" "always out of range"
        [inferred_range: "the inferred interval is {interval}",
         allowed_range: "the allowed range is {range}",
         local_analysis: "this local analysis applies only if execution reaches this call and all arguments are evaluated successfully",
         origin: "this binding or comparison contributes to the inferred interval"]
        "Local interval analysis shows that the argument is always out of range. If execution reaches this call and all arguments are evaluated successfully, the call stops the program at runtime.";

    // ---- W05: エフェクトの警告 ----
    W0501 Check "`uses IO.All` allows more effects than this function performs" ""
        [narrow: "write `uses {effects}`",
         remove: "remove `uses IO.All`; this function performs no effects",
         covered: "remove this `IO.All`; the remaining declarations cover this function's effects",
         shared: "review the file-level IO.All declaration for all functions; no automatic edit is offered",
         file: "IO.All added by this file-level uses declaration"]
        fix [narrow, remove, covered]
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

    // ---- R06: 外部の関数 ----
    R0601 Runtime "the external function `{function}` trapped: {trap}" ""
        [component: "component `{component}`, function `{export}`"]
        "A WebAssembly trap or a Component Model ABI violation stops execution. Guest panics and Rust allocation failures can also become an unreachable trap.";

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

    R0904 Resource "the external function `{function}` used up its fuel limit of {limit}" ""
        [component: "component `{component}`"]
        "Each external call has a default fuel limit of 10^10, independent of elapsed time. The user running the script can change it with `--wasm-fuel`.";
    R0905 Resource "the external function `{function}` exceeded its {budget} limit of {limit} bytes" ""
        [component: "component `{component}`",
         linear_memory: "total guest linear memory is limited to {limit} bytes per call, or over the lifetime of a stateful instance",
         adapter_allocation: "the external function `{function}` could not allocate generated adapter memory for {requested} bytes",
         adapter_memory: "the generated adapter allocator's memory.grow failed while reserving {requested} bytes, with {allocated} bytes already allocated; adapter memory also counts toward the Store's total linear-memory limit",
         adapter_store_memory: "this call uses generated adapter memory as well as guest memory; both count toward the Store's total linear-memory limit",
         adapter_memory32: "the generated adapter allocator requested {requested} bytes, exceeding the memory32 address limit of {limit} bytes",
         transfer: "values passed to or from an external function are limited to {limit} bytes in their host representation, in each direction"]
        "By default, external calls limit total guest linear memory to 64 MiB and each direction of value transfer to a 256 MiB budget. Generated adapters count the complete transfer buffer and separately limit logical value construction to the same budget. The user running the script can change these limits with `--wasm-memory` and `--wasm-transfer`.";
    R0906 Resource "the external function `{function}` needed {size} {resource}; the limit is {limit}" ""
        [component: "component `{component}`",
         component_handles: "the external function `{function}` exceeded the limit of {limit} component handles"]
        "Each Store limits core instances, memories, and tables to 16 each, each guest table to 10,000 elements, and simultaneously live component handles to 100,000. Stateful calls retain the live handle count across calls; dropping a handle returns capacity. Reduce the component's resource requirements.";


    R0907 Resource "`{function}` could not reserve buffer memory" ""
        [capacity: "the requested buffer capacity was {requested_bytes} bytes"]
        "The logical length was within the value size limit, but the host could not reserve the requested buffer capacity. This is not a process-wide memory usage measurement.";

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
    L0113 Limit "the program uses too many external functions" ""
        [limit: "a program can use at most 65535 external functions"]
        "The bytecode addresses external functions with 16 bits.";
    L0112 Limit "the definition `{name}` is too large to compile" ""
        [definition_final: "the final match decisions in this definition exceed their node or edge budget; split it into smaller functions",
         nodes: "the final match decision exceeds its node budget; split it into smaller matches",
         edges: "the final match decision exceeds its edge budget; split it into smaller matches",
         table: "the match decision requires more than 64 MiB of working tables; simplify the match",
         instructions: "the definition requires more than 4,194,304 generated instructions; split it into smaller functions"]
        "The compiler shares match decisions and falls back to matching rows in source order; final decision nodes, edges, working tables, and generated instructions remain bounded.";
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

/// 診断コードの表に属さない、報告の定型の文（設計書 02-10「文言の言語」）。
pub mod text {
    /// 明示的な失敗終了の主文と注記。原因と説明は別々の注記に保持する。
    pub const DIE_MESSAGE: &str = "explicit failure exit";
    pub const DIE_MESSAGE_NOTE: &str = "message: {message}";
    pub const DIE_CAUSE_NOTE: &str = "cause: {cause}";
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
    pub const INTERNAL_REPORT: &str = "this is a bug in the implementation; please report it with the script that caused it, after removing any secrets";
}
