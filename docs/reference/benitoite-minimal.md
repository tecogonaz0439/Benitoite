# Benitoite Minimal Language Reference

This reference covers the **minimal implementation** of Benitoite. The language name `Benitoite`, command name `benitoite`, and file extension `.bnt` are provisional (OPEN-011); they may change.

## 1. Run a script

Use these commands from a terminal:

```text
benitoite check [--diagnostics=text|json] <script.bnt>
benitoite run [--diagnostics=text|json] [--max-call-stack=<size>] <script.bnt> [arguments...]
benitoite --help
benitoite --version
```

`check` reads and type-checks the script without running it. `run` checks it and then calls `main`. Arguments after the script path are passed to `Process.args()` in order. The script path may have any extension. `--max-call-stack` accepts an integer followed by `KiB`, `MiB`, or `GiB`; its default is `1GiB`.

The exit status is:

| Status | Meaning |
|---:|---|
| 0 | Check succeeded, or `main` returned `()` or `Ok(())`. |
| 1 | `main` returned `Err`, a runtime error occurred, execution ran out of a limited resource, or a command-line argument is not valid UTF-8. |
| 2 | The script has a check error, the command is invalid, the script cannot be read, or the implementation cannot run it because of a limit. |
| 3 | The implementation encountered an internal error. |

Diagnostics go to standard error. The default format is human-readable text; pass `--diagnostics=json` for one JSON object per diagnostic line. A JSON diagnostic has `kind`, `severity`, `code`, `message`, `primary`, `secondary`, `notes`, and `helps` fields. A missing source position is represented by `"primary": null`. Text diagnostics show an error code and source location, and may include `= help:` suggestions.

## 2. Program structure

A program is one file; user-defined modules and imports are not part of this minimal implementation. Only function and type declarations may appear at the top level. Execution starts at a function named `main` with no type or effect parameters. It must return `Unit` or `Result[Unit, String]` and may be pure or declare `uses IO`.

Statements are separated by newlines; semicolons are not part of the language. Put an opening brace on the same line as the function signature or expression that introduces its block. A brace on the next line is an error because the newline ends the declaration or expression.

A block contains `let` bindings and expressions. Its final expression is the block's value. If the final statement is a binding, or the block is empty, the value is `()`. A non-final expression statement must have type `Unit`. Write `let _ = expression` when intentionally discarding a non-Unit value. A `let` binding may have an optional type annotation; it cannot destructure a value.

Use `//` for a comment through the end of the line. There are no block comments.

Identifiers use ASCII letters, digits, and underscores. Lowercase names are used for functions, variables, and parameters; uppercase names are used for types, constructors, modules, and effects. Keywords cannot be used as identifiers. A single `_` is a wildcard or a partial-application placeholder. Names such as `_unused` are ordinary lowercase identifiers. The language has no `for`, `while`, or `loop` statements; use recursion or list functions.

## 3. Basic types and literals

Benitoite has six basic types:

| Type | Values |
|---|---|
| `Int` | Signed 64-bit integers |
| `Float` | IEEE 754 binary64 floating-point values |
| `String` | Immutable sequences of Unicode scalar values |
| `Char` | One Unicode scalar value |
| `Bool` | `true` or `false` |
| `Unit` | Only `()` |

Integer values range from `-2^63` through `2^63 - 1`. Integer literals may be decimal, hexadecimal (`0xff`), octal (`0o755`), or binary (`0b1010`). Underscores may separate digits, as in `1_000_000`. A decimal integer other than `0` cannot start with `0`. Integer literals have no sign; `-1` applies unary minus to `1`. An out-of-range literal is a check error, except for the minimum value written directly as `-9223372036854775808`.

A floating-point literal is decimal and may use an exponent, such as `3.14`, `1e10`, or `1.2e-3`. Digits are required on both sides of a decimal point (`1.0` is valid; `1.` and `.5` are not). Underscores may separate digits. There are no hexadecimal floating-point literals.

A string uses double quotes and must fit on one line. Supported escapes are `\n`, `\r`, `\t`, `\\`, `\"`, `\$`, and `\u{H}` for a Unicode scalar value. String interpolation is not part of this minimal implementation; the interpolation marker, a dollar sign followed by an opening brace, is rejected. A character uses single quotes and contains exactly one Unicode scalar value, either directly or as an escape; for example, `'a'`, `'あ'`, and `'\n'`.

There are no implicit conversions between types. Use explicit conversion functions such as `Int.toFloat` or `Int.toString`. `String` concatenation uses `+` and requires two strings; it stops if the result exceeds the string size limit.

The operators, from lowest to highest precedence, are:

| Operators | Associativity |
|---|---|
| `|>` | Left |
| `||` | Left |
| `&&` | Left |
| `== != < <= > >=` | Non-associative |
| `+ -` | Left |
| `* / %` | Left |
| Unary `- !` | Prefix |
| Function call `f(...)` | Postfix |

`&&` and `||` short-circuit. All other expression operands are evaluated from left to right. An `if` evaluates its condition and only the selected branch; a `match` evaluates its subject once and only the first matching arm. Comparisons cannot be chained: write `a < b && b < c`, not `a < b < c`.

`Int` arithmetic overflow, integer division by zero, and `Int` minimum divided by `-1` stop execution with a runtime error. Integer division truncates toward zero: `-7 / 2` is `-3` and `-7 % 2` is `-1`. `Float` division follows IEEE 754, including division by zero; `%` is only defined for `Int`. Positive and negative zero compare equal. Every ordered comparison and `==` with NaN is false; `!=` with NaN is true. Use `Float.isNaN` to detect it.

String comparison is lexicographic by Unicode scalar value and does not normalize text. `String.length` does not exist: use `String.byteLength` for UTF-8 bytes or `String.charCount` for scalar values. String positions and lengths are zero-based. A slice uses a half-open range; an invalid position or range returns `None`.

`==` and `!=` work for basic values and for lists and custom data types whose contents are equality types. Function values and values containing `IoError` cannot be compared for equality.

## 4. Functions and lambdas

Every top-level function must declare every parameter type and its return type:

```text
fn double(value: Int) -> Int {
  value * 2
}
```

A function without `uses` is pure. A function that performs IO declares `uses IO` after its return type. Function calls are not curried: the number of arguments must match exactly.

Lambdas are expressions. Their parameter types and return type may be inferred. A lambda's effects are inferred from its body unless it has an explicit return type and `uses` annotation.

```text
fn(x) { x + 1 }
fn(x: Int) -> Int { x + 1 }
fn(line: String) -> Unit uses IO { Console.println(line) }
```

A function's type includes its effects. For example, `fn(String) -> Unit uses IO` accepts a function that may perform IO. Type parameters are written after a top-level function name. An effect variable is declared with the keyword `effect` and may appear after `uses` in function types and signatures.

Functions are not partially applied by omitting arguments. Put `_` in each argument position to leave open:

```text
between(2, _, 4)       // fn(value) { between(2, value, 4) }
```

`x |> f(a, b)` passes `x` as the first argument: it expands to `f(x, a, b)`. If the right side is not a call, it expands to `e(x)`. If the right side is a call with a direct placeholder, the pipe applies to that call as a function value. Parentheses on the right force this function-value form. For example:

```text
lines |> List.filter(nonEmpty)   // List.filter(lines, nonEmpty)
x |> clamp(0, _, 100)             // clamp(0, x, 100)
x |> (makeHandler(config))        // (makeHandler(config))(x)
```

A function can call itself or another top-level function recursively. Calls in tail position use no additional call storage, even for mutual recursion. Lambdas cannot refer to themselves by name. There is no loop syntax.

This complete program uses a pipe and a placeholder to filter and format values:

```bnt
fn between(low: Int, value: Int, high: Int) -> Bool {
  low <= value && value <= high
}

fn main() -> Unit uses IO {
  let text = [1, 2, 3, 4, 5]
    |> List.filter(between(2, _, 4))
    |> List.map(Int.toString)
    |> String.join(",")
  Console.println(text)
}
```

## 5. Data types and pattern matching

Declare an algebraic data type with one or more constructors. Constructor arguments are positional. A constructor with arguments is also a function:

```text
type Shape {
  Circle(Float)
  Rect(Float, Float)
}
```

Qualify constructors with their type name in expressions and patterns: `Shape.Circle(2.0)` and `Shape.Circle(radius)`. The built-in `Option` constructors `Some` and `None` and `Result` constructors `Ok` and `Err` are exceptions; write them unqualified. Constructor argument counts must match exactly.

Patterns can be a wildcard (`_`), a variable, an integer/string/character/boolean/Unit literal, or a constructor pattern. Floating-point literals are not patterns. Pattern variables are scoped to their match arm.

`match` evaluates its subject once and evaluates only the first matching arm. Every possible value must match an arm, and no arm may be unreachable because an earlier arm already matches it. The checker reports both non-exhaustive and unreachable matches. Use both `true` and `false` to cover `Bool`, and `()` to cover `Unit`. For `Int`, `String`, and `Char`, literal patterns alone are never exhaustive; include a wildcard or variable arm.

`List` exposes no constructors and cannot be destructured by pattern matching. Use `List.head`, `List.tail`, or other `List` functions to inspect it.

This complete program aggregates values from a custom type using pattern matching:

```bnt
type Change {
  Added(Int)
  Removed(Int)
}

fn amount(change: Change) -> Int {
  match change {
    Change.Added(value) => value
    Change.Removed(value) => -value
  }
}

fn total(changes: List[Change]) -> Int {
  changes |> List.fold(0, fn(acc, change) { acc + amount(change) })
}

fn main() -> Unit uses IO {
  let changes = [Change.Added(5), Change.Removed(2), Change.Added(4)]
  Console.println(Int.toString(total(changes)))
}
```

## 6. Effects

The only effect in the minimal implementation is `IO`. Effects are written in function signatures and function types:

- Omitting `uses` means the function is pure.
- A function that calls an IO function must declare `uses IO`.
- A pure function cannot call an IO function.
- Calling an IO function performs the IO at that call. Creating a lambda that performs IO does not perform its body; calling the lambda does.

A top-level function can declare an effect variable in its type-parameter list, such as `effect E`. Use the same variable after `uses` in a function parameter type and in the function's own effect when its body forwards that effect. This lets a higher-order function preserve the callback's effects.

An unannotated lambda infers its effects from its body. When a lambda declares an explicit return type and effect set, its body must fit that set. A pure function can be used where an effectful function is expected, but a function that uses IO cannot be passed where a pure function is required.

The effect checker tracks what code may do; it is not a runtime permission system. The minimal implementation does not request or enforce per-file permissions.

This complete program forwards an inferred callback effect through an effect variable:

```bnt
fn twice[effect E](action: fn() -> Unit uses E) -> Unit uses E {
  action()
  action()
}

fn main() -> Unit uses IO {
  twice(fn() { Console.println("tick") })
}
```

## 7. Errors

IO operations that can fail return `Result[T, IoError]`. For example, `File.readText` returns `Result[String, IoError]`. Handle it with `match`:

```text
match File.readText("input.txt") {
  Ok(text) => ...
  Err(error) => ...
}
```

This complete program reads a file and prints its line count:

```bnt
fn main() -> Result[Unit, String] uses IO {
  match File.readText("input.txt") {
    Ok(text) => {
      let count = text |> String.lines |> List.length
      Console.println(Int.toString(count))
      Ok(())
    }
    Err(error) => Err(IoError.message(error))
  }
}
```

The `IoError` type is opaque: it cannot be destructured or compared for equality. Use `IoError.message(error)` to obtain a human-readable message. There is no `unwrap` function. Use `Option.unwrapOr` or `Result.unwrapOr` when a default is appropriate, or use `match` when both outcomes matter.

The `main` function may return `Result[Unit, String]`. Returning `Err(message)` writes that message to standard error and exits with status 1. Runtime errors such as integer overflow are not values and cannot be caught with `match` or returned as `Result`; they stop execution immediately.

## 8. Prelude reference

The Function column gives the qualified name to call; the Type column shows its full function type. `—` means the function has no additional runtime stop specified here. A callback passed to a higher-order function may itself stop at runtime, and that stop propagates. `IO` functions execute external operations when called.

### Int

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `Int.toString` | `fn(Int) -> String` | Format an integer in decimal. | — |
| `Int.parse` | `fn(String) -> Option[Int]` | Parse a decimal integer with an optional leading minus; invalid or out-of-range text returns `None`. | — |
| `Int.toFloat` | `fn(Int) -> Float` | Convert to the nearest `Float` value. | — |
| `Int.floorDiv` | `fn(Int, Int) -> Int` | Divide, rounding the quotient toward negative infinity. | Zero divisor or minimum integer divided by `-1`. |
| `Int.mod` | `fn(Int, Int) -> Int` | Remainder for floor division; its sign follows the divisor. | Zero divisor. |
| `Int.abs` | `fn(Int) -> Int` | Return the absolute value. | Minimum integer. |
| `Int.min` | `fn(Int, Int) -> Int` | Return the smaller value. | — |
| `Int.max` | `fn(Int, Int) -> Int` | Return the larger value. | — |

### Float

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `Float.toString` | `fn(Float) -> String` | Format a stable decimal representation. | — |
| `Float.parse` | `fn(String) -> Option[Float]` | Parse a decimal number with an optional leading minus; invalid text, NaN, and infinity return `None`. | — |
| `Float.truncate` | `fn(Float) -> Option[Int]` | Truncate toward zero; NaN, infinity, or an out-of-range result returns `None`. | — |
| `Float.isNaN` | `fn(Float) -> Bool` | Test whether the value is NaN. | — |
| `Float.abs` | `fn(Float) -> Float` | Return the absolute value; NaN remains NaN. | — |
| `Float.floor` | `fn(Float) -> Float` | Return the greatest integer-valued float not greater than the input. | — |
| `Float.ceil` | `fn(Float) -> Float` | Return the least integer-valued float not less than the input. | — |
| `Float.round` | `fn(Float) -> Float` | Round to the nearest integer; halfway values round away from zero. | — |
| `Float.sqrt` | `fn(Float) -> Float` | Return the IEEE 754 square root; a negative input returns NaN. | — |

### Char

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `Char.toInt` | `fn(Char) -> Int` | Return the Unicode scalar value as an integer. | — |
| `Char.fromInt` | `fn(Int) -> Option[Char]` | Convert a Unicode scalar value; invalid values return `None`. | — |
| `Char.toString` | `fn(Char) -> String` | Make a one-scalar string. | — |
| `Char.isAsciiDigit` | `fn(Char) -> Bool` | Test for ASCII `0` through `9`. | — |
| `Char.isAsciiWhitespace` | `fn(Char) -> Bool` | Test for ASCII space, tab, LF, or CR. | — |

### String

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `String.byteLength` | `fn(String) -> Int` | Count UTF-8 bytes. | — |
| `String.byteSlice` | `fn(String, Int, Int) -> Option[String]` | Take a half-open byte range; invalid or non-boundary positions return `None`. | — |
| `String.charCount` | `fn(String) -> Int` | Count Unicode scalar values. | — |
| `String.charAt` | `fn(String, Int) -> Option[Char]` | Get the scalar at a zero-based position; an invalid position returns `None`. | — |
| `String.charSlice` | `fn(String, Int, Int) -> Option[String]` | Take a half-open scalar-value range; invalid positions return `None`. | — |
| `String.isEmpty` | `fn(String) -> Bool` | Test whether the string is empty. | — |
| `String.contains` | `fn(String, String) -> Bool` | Test whether the string contains a substring; an empty substring is contained. | — |
| `String.startsWith` | `fn(String, String) -> Bool` | Test whether the string begins with a prefix. | — |
| `String.endsWith` | `fn(String, String) -> Bool` | Test whether the string ends with a suffix. | — |
| `String.byteIndexOf` | `fn(String, String) -> Option[Int]` | Find the first byte position of a substring; an empty substring returns `Some(0)`. | — |
| `String.split` | `fn(String, String) -> List[String]` | Split at non-overlapping separators. A non-empty separator preserves empty fields, so empty input returns `[""]`; an empty separator splits into one-scalar strings, so empty input returns `[]`. | Result exceeds the string or list size limit. |
| `String.lines` | `fn(String) -> List[String]` | Split on LF, remove one trailing CR from each line, omit a final empty line, and return an empty list for empty input. | Result exceeds the list size limit. |
| `String.join` | `fn(List[String], String) -> String` | Join strings with a separator; an empty list returns `""`. | Result exceeds the string size limit. |
| `String.trim` | `fn(String) -> String` | Remove leading and trailing ASCII whitespace. | — |
| `String.replace` | `fn(String, String, String) -> String` | Replace non-overlapping matches; an empty old string leaves the input unchanged. | Result exceeds the string size limit. |
| `String.repeat` | `fn(String, Int) -> String` | Repeat the string; a non-positive count returns `""`. | Result exceeds the string size limit. |
| `String.chars` | `fn(String) -> List[Char]` | Return the Unicode scalar values in order. | Result exceeds the list size limit. |
| `String.fromChars` | `fn(List[Char]) -> String` | Concatenate the characters in order. | Result exceeds the string size limit. |

### List

`List[T]` is opaque. Use list literals and these functions; patterns cannot inspect list cells.

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `List.length` | `fn[T](List[T]) -> Int` | Return the number of elements. | — |
| `List.isEmpty` | `fn[T](List[T]) -> Bool` | Test whether the list is empty. | — |
| `List.head` | `fn[T](List[T]) -> Option[T]` | Return the first element, or `None` if empty. | — |
| `List.tail` | `fn[T](List[T]) -> Option[List[T]]` | Return the list without its first element, or `None` if empty. | — |
| `List.get` | `fn[T](List[T], Int) -> Option[T]` | Get a zero-based element; an invalid index returns `None`. | — |
| `List.prepend` | `fn[T](List[T], T) -> List[T]` | Add an element at the front. | Result exceeds the list size limit. |
| `List.append` | `fn[T](List[T], T) -> List[T]` | Add an element at the end. | Result exceeds the list size limit. |
| `List.concat` | `fn[T](List[T], List[T]) -> List[T]` | Concatenate two lists. | Result exceeds the list size limit. |
| `List.reverse` | `fn[T](List[T]) -> List[T]` | Return a list with the elements in reverse order. | — |
| `List.take` | `fn[T](List[T], Int) -> List[T]` | Take the first `n` elements; non-positive `n` returns an empty list, and `n` at least the length returns the input. | — |
| `List.drop` | `fn[T](List[T], Int) -> List[T]` | Drop the first `n` elements; non-positive `n` returns the input, and `n` at least the length returns an empty list. | — |
| `List.range` | `fn(Int, Int) -> List[Int]` | Return integers from `start`, inclusive, to `end`, exclusive; `end <= start` returns an empty list. | Result exceeds the list size limit. |
| `List.contains` | `fn[T](List[T], T) -> Bool` | Test for an equal element. `T` must be an equality type. | — |
| `List.sort` | `fn[T](List[T]) -> List[T]` | Stable ascending order for `Int`, `Float`, `String`, or `Char`. NaNs sort last. | — |
| `List.map` | `fn[T, U, effect E](List[T], fn(T) -> U uses E) -> List[U] uses E` | Apply a function to each element, in order. | Callback stop propagates. |
| `List.filter` | `fn[T, effect E](List[T], fn(T) -> Bool uses E) -> List[T] uses E` | Keep elements for which the predicate is true, preserving order. | Callback stop propagates. |
| `List.fold` | `fn[T, A, effect E](List[T], A, fn(A, T) -> A uses E) -> A uses E` | Fold from the initial value, from the first element onward. | Callback stop propagates. |
| `List.forEach` | `fn[T, effect E](List[T], fn(T) -> Unit uses E) -> Unit uses E` | Call a function for each element in order. | Callback stop propagates. |
| `List.any` | `fn[T, effect E](List[T], fn(T) -> Bool uses E) -> Bool uses E` | Test whether any element matches; stop when the result is known. | Callback stop propagates. |
| `List.all` | `fn[T, effect E](List[T], fn(T) -> Bool uses E) -> Bool uses E` | Test whether all elements match; empty lists return true. | Callback stop propagates. |
| `List.find` | `fn[T, effect E](List[T], fn(T) -> Bool uses E) -> Option[T] uses E` | Return the first matching element, or `None`. | Callback stop propagates. |

`List.contains` requires an equality type. `List.sort` accepts only `Int`, `Float`, `String`, or `Char`. Sorting is stable; NaN values follow other floats, and equal NaNs retain their order.

### Option

Write constructors without qualification: `Some(value)` and `None`.

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `Option.map` | `fn[T, U, effect E](Option[T], fn(T) -> U uses E) -> Option[U] uses E` | Apply the function to `Some`; preserve `None`. | Callback stop propagates. |
| `Option.andThen` | `fn[T, U, effect E](Option[T], fn(T) -> Option[U] uses E) -> Option[U] uses E` | Apply the function to `Some`; preserve `None`. | Callback stop propagates. |
| `Option.unwrapOr` | `fn[T](Option[T], T) -> T` | Return the value or the supplied default. | — |
| `Option.isSome` | `fn[T](Option[T]) -> Bool` | Test for `Some`. | — |
| `Option.isNone` | `fn[T](Option[T]) -> Bool` | Test for `None`. | — |
| `Option.okOr` | `fn[T, X](Option[T], X) -> Result[T, X]` | Convert `Some` to `Ok` and `None` to `Err`. | — |

### Result

Write constructors without qualification: `Ok(value)` and `Err(error)`.

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `Result.map` | `fn[T, U, X, effect E](Result[T, X], fn(T) -> U uses E) -> Result[U, X] uses E` | Apply the function to `Ok`; preserve `Err`. | Callback stop propagates. |
| `Result.mapErr` | `fn[T, X, Y, effect E](Result[T, X], fn(X) -> Y uses E) -> Result[T, Y] uses E` | Apply the function to `Err`; preserve `Ok`. | Callback stop propagates. |
| `Result.andThen` | `fn[T, U, X, effect E](Result[T, X], fn(T) -> Result[U, X] uses E) -> Result[U, X] uses E` | Apply the function to `Ok`; preserve `Err`. | Callback stop propagates. |
| `Result.unwrapOr` | `fn[T, X](Result[T, X], T) -> T` | Return the `Ok` value or the supplied default. | — |
| `Result.isOk` | `fn[T, X](Result[T, X]) -> Bool` | Test for `Ok`. | — |
| `Result.isErr` | `fn[T, X](Result[T, X]) -> Bool` | Test for `Err`. | — |
| `Result.ok` | `fn[T, X](Result[T, X]) -> Option[T]` | Convert `Ok` to `Some` and `Err` to `None`. | — |

### IoError

`IoError` is opaque and cannot be compared or destructured.

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `IoError.message` | `fn(IoError) -> String` | Return a human-readable description of an IO error. | — |

### Console, File, and Process

| Function | Type | Description | Additional runtime stop |
|---|---|---|---|
| `Console.print` | `fn(String) -> Unit uses IO` | Write a string to standard output. | Write failure. |
| `Console.println` | `fn(String) -> Unit uses IO` | Write a string and LF to standard output. | Write failure. |
| `Console.eprintln` | `fn(String) -> Unit uses IO` | Write a string and LF to standard error. | Write failure. |
| `File.readText` | `fn(String) -> Result[String, IoError] uses IO` | Read a whole UTF-8 text file; invalid UTF-8 and file errors return `Err`. | Result exceeds the string size limit. |
| `Process.args` | `fn() -> List[String] uses IO` | Return the script arguments, excluding the script path, in order. | — |

A resource-limit stop is not an `Err` value. Standard output and standard error preserve the order of writes made to each stream. There is no prelude `List.dropFirst` function for user scripts; that helper is available only inside the prelude implementation.

## 9. Diagnostics and common fixes

A check error reports a code such as `E0401`, a source location, and a message. A text diagnostic may provide one or more `= help:` suggestions. With `--diagnostics=json`, each diagnostic is a separate JSON line. Fix the reported issue, then run `benitoite check` again.

| Mistake | Use this instead |
|---|---|
| `String.length(s)` | Choose `String.byteLength(s)` or `String.charCount(s)`; state whether the unit is bytes or Unicode scalar values. |
| `xs.map(f)` | Use `xs |> List.map(f)`. |
| `a < b < c` | Use `a < b && b < c`. |
| `value.unwrap()` | Use `match` or an appropriate `Option.unwrapOr` / `Result.unwrapOr`. |
| `for` or `while` | Use a recursive function or a `List` function. |
| Unqualified user constructor `Circle(r)` | Write `Shape.Circle(r)`. Keep `Some`, `None`, `Ok`, and `Err` unqualified. |
| IO call inside a pure function | Add `uses IO` to the function and propagate it to callers, or move the operation to an IO-capable function. |

Example diagnostics use English messages. Runtime errors such as overflow stop execution; they cannot be handled by a `match` arm.
