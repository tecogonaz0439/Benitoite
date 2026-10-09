# Benitoite Language Reference

<!--
How the code examples in this file are checked (crates/benitoite/tests/reference_examples.rs):
- A `benitoite` block is run, and its standard output is compared with the `output` block after it.
  A last line `exit N` in the `output` block is the expected exit code (0 when absent).
  A `stderr` block after the `output` block is the expected standard error (empty when absent).
- A `benitoite check` block is only checked; it must have no errors and no warnings.
- A `benitoite test` block is run with `benitoite test`; all its tests must pass.
- A `benitoite error` block must fail `benitoite check`, and every line of the `diagnostic` block after it must appear in the report.
- A `files` block before an example creates a file next to the script: the first line is `name: <file name>`, the rest is the content.
  A name with `/` creates the directories on the way.
- Blocks with other info strings (such as `text` and `sh`) are not checked.
-->

This reference describes Benitoite `0.0.1`, the first release. It explains how to write and run Benitoite scripts, with examples. Every example marked as a program in this file is checked against `benitoite` by the test suite of the repository.

To install `benitoite`, see [Installing Benitoite](install.md). For the earlier minimal implementation (`0.0.0`), see [benitoite-minimal.md](benitoite-minimal.md); the changes between the two are listed in the [CHANGELOG](../../CHANGELOG.md).

Benitoite is a statically typed functional scripting language. A script is a `.bnt` file. Before anything runs, `benitoite` checks the types of the script and the effects it uses: what each function may do outside the program, such as writing files or starting commands. The checks guarantee only that the script follows these rules. They do not guarantee that the script does what you intended, that an outside operation succeeds, or that the script finishes.

## Contents

1. [A first script](#1-a-first-script)
2. [The command line](#2-the-command-line)
3. [Program structure](#3-program-structure)
4. [Basic types and literals](#4-basic-types-and-literals)
5. [Operators](#5-operators)
6. [Functions and lambdas](#6-functions-and-lambdas)
7. [Data types, records, and pattern matching](#7-data-types-records-and-pattern-matching)
8. [Constants and type aliases](#8-constants-and-type-aliases)
9. [Errors: `Option`, `Result`, and `try`](#9-errors-option-result-and-try)
10. [Effects](#10-effects)
11. [Effect handlers](#11-effect-handlers)
12. [Modules](#12-modules)
13. [Type classes](#13-type-classes)
14. [Explicit laziness](#14-explicit-laziness)
15. [Mutable cells, resources, and tasks](#15-mutable-cells-resources-and-tasks)
16. [Tests](#16-tests)
17. [Formatting](#17-formatting)
18. [Diagnostics](#18-diagnostics)
19. [The standard library](#19-the-standard-library)
20. [Compatibility](#20-compatibility)

## 1. A first script

Save the following as `hello.bnt`:

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  Console.writeLine("Hello, world!")
end function
```

```output
Hello, world!
```

Check it, then run it:

```sh
benitoite check hello.bnt
benitoite run hello.bnt
```

`check` prints nothing when the script has no errors and no warnings. `run` checks the script again and then calls `main`.

The first line imports the module `Console`. The signature of `main` says, after `uses`, that it writes to the console (`Console.Write`). A function that does something outside the program must list it this way, and so must every function that calls it. Reading the `uses` of `main` tells you everything a script may do.

## 2. The command line

```text
benitoite [options] <script> [script arguments...]
benitoite run   [options] <script> [script arguments...]
benitoite check [options] <script>
benitoite test  [options] <path>...
benitoite fmt   [options] <path>...
benitoite skill install|uninstall [--user | --project] [--agent <name>]...
benitoite --help
benitoite --version
benitoite --licenses
```

| Command | What it does |
|---|---|
| `run` | Checks the script and calls its `main`. Arguments after the script path are passed to the script (`Process.arguments()`), also when they start with `-`. |
| `check` | Checks the script without running it. |
| `test` | Runs the test functions in the given files, or in all `.bnt` files under the given directories. See [Tests](#16-tests). |
| `fmt` | Rewrites the given files, or all `.bnt` files under the given directories, in the standard layout. See [Formatting](#17-formatting). |
| `skill` | Writes the bundled Agent Skill to the places where coding agents read skills, or removes it. See [Installing Benitoite](install.md#3-install-the-agent-skill). |
| `--help` | Prints the usage. |
| `--version` | Prints the version of `benitoite` on the first line (`benitoite 0.0.1`) and the Unicode version used by character functions on the second line (`Unicode 17.0.0`). |
| `--licenses` | Prints the licenses of the third-party software in the executable. A build from source does not contain this list and says so. |

`<script>` is a file, or a directory that contains `main.bnt`. The file name and its extension are not checked. The directory of the script is the *root directory*: the script can import modules from the root directory and below it, and from the standard library ([Modules](#12-modules)). `benitoite` reads no configuration file.

`benitoite script.bnt` without a command means `benitoite run script.bnt`. A file whose name is a command (such as `check`) is run as `benitoite ./check`. The names `server`, `mcp`, `sign`, `verify`, `repl`, `lsp`, `package`, and `agent` are reserved for later versions; `benitoite server` is a usage error.

To run a script directly, make the file executable and put this line first:

```text
#!/usr/bin/env benitoite
```

On Linux, do not write `#!/usr/bin/env benitoite run`: Linux passes everything after the interpreter name as one argument. To pass options, use `env -S`, as in `#!/usr/bin/env -S benitoite --max-call-stack=2GiB`.

### Options

Options come after the command and before the script path.

| Option | Meaning | Default |
|---|---|---|
| `--diagnostics=text` or `--diagnostics=json` | Format of diagnostics and error reports. For `test`, also the format of the test results. | `text` |
| `--max-call-stack=<size>` | Limit for nested calls in `run` and `test` (for `test`, per test), written as an integer with `KiB`, `MiB`, or `GiB`, such as `512MiB`. | `1GiB` |
| `--deny-warnings` | Treat warnings as errors in `check`, `run`, and `test`. | off |
| `--check` | `fmt` only: report the files that would change, without rewriting them. | off |

### Exit status of `run` and `check`

| Status | Meaning |
|---:|---|
| 0 | `check` found no errors, or `main` returned `()` or `Result.Ok(())`. |
| 1 | `main` returned `Result.Error`, the program stopped with a runtime error or ran out of a resource, or a command-line argument is not valid UTF-8. |
| 2 | The script has check errors (or warnings with `--deny-warnings`), cannot run because of a limit of `benitoite`, or cannot be read; or the command line is wrong. |
| 3 | An internal error of `benitoite`. Please report it. |
| 130 | `run` received `SIGINT` or `SIGTERM`. It cancelled all tasks, released resources, and flushed output before ending. |

A script that calls `Process.exit(n)` ends with `n` (0 to 255). Because 1, 2, and 3 can come from `Process.exit` too, a tool that runs scripts can tell them apart by whether standard error contains a report in the format of `benitoite`.

Diagnostics, runtime errors, the message of `Result.Error` returned by `main`, and usage errors go to standard error. Standard output contains only what the script writes. If the reader of standard output or standard error goes away (a closed pipe), the program stops with a runtime error and exit status 1.

`benitoite` sets no limit on memory. To limit it, use the tool that starts `benitoite` (`ulimit`, a container, or the agent harness).

## 3. Program structure

A program starts at the function `main` in the script file. `main` takes no parameters and returns `Unit` or `Result[Unit, String]`. When it returns `Result.Error(message)`, the message is written to standard error and the exit status is 1.

The top level of a file contains, in this order, `import` declarations and then declarations: functions, constants, data types, type aliases, records, type classes, implementations, and effects. Code that runs is written only inside functions.

Blocks are closed with `end` and the keyword that opened them: `end function`, `end if`, `end match`, `end lambda`, `end data`, `end record`, `end trait`, `end implement`, `end effect`, `end handle`, `end with`, `end lazy`. There are no braces, and indentation has no meaning. Statements are separated by line breaks; there are no semicolons.

Inside a block:

- `bind name <- expression` gives a name to a value. Names cannot be reassigned.
- `shadow name <- expression` binds a name that hides a local name already visible. `bind` with a name that is already visible as a local name is an error, so hiding is always explicit.
- `return expression` ends the function and returns the value.
- An expression on its own line is a statement. When it is not the last statement of its block, or when it is the last statement of a function or lambda body, its value must be `Unit`; write `bind _ <- expression` to discard any other value.

A function whose return type is not `Unit` must end with `return` (or with an `if` or `match` whose every branch returns). The value of an `if`, of a `match` branch, of a handler clause, and of the bodies of `with`, `handle`, and `lazy` is its last expression. A `return` inside any of these returns from the function that contains it.

`//` starts a comment that runs to the end of the line. `///` before a declaration documents it, and `//!` at the start of a file documents the module. Identifiers use ASCII letters, digits, and `_`. Names of functions, values, and parameters start with a lowercase letter; names of types, constructors, modules, and effects start with an uppercase letter.

```benitoite
//! Prints a short report.

import Benitoite.Unofficial.IO.Console

/// Returns the larger of two integers.
function larger(a: Integer, b: Integer) -> Integer
  if a > b then
    return a
  end if
  return b
end function

function main() -> Unit uses Console.Write
  bind total <- 10
  shadow total <- total + larger(3, 7)
  bind label <- if total > 15 then "big" else "small" end if
  Console.writeLine("${label}: ${total}")
end function
```

```output
big: 17
```

There are no loop statements, no `null`, and no exceptions. Use recursion or list functions instead of loops, `Option` instead of `null`, and `Result` with `try` instead of exceptions.

## 4. Basic types and literals

| Type | Values | Literals |
|---|---|---|
| `Integer` | Signed 64-bit integers | `42`, `-7`, `1_000_000`, `0xff`, `0o755`, `0b1010` |
| `Float` | IEEE 754 binary64 | `3.14`, `1e10`, `1.2e-3` |
| `Decimal` | 128-bit decimal fractions, for money and other exact decimal values | `12m`, `1.25m`, `1_000.50m` |
| `Byte` | Integers from 0 to 255 | none; use `Byte.fromInteger` |
| `Character` | One Unicode scalar value | `'a'`, `'あ'`, `'\n'` |
| `String` | Immutable sequences of Unicode scalar values | `"text"`, `"""…"""`, `r"…"` |
| `Boolean` | `true` and `false` | `true`, `false` |
| `Unit` | Only `()` | `()` |

There are no implicit conversions. Use conversion functions such as `Integer.toFloat`, `Integer.toString`, `Decimal.fromInteger`, and `Integer.parse` (which returns `Option[Integer]`).

`Integer` overflow, and `div` or `mod` by zero, stop the program with a runtime error. `Float` division follows IEEE 754: dividing by zero gives an infinity or NaN. A `Float` literal needs digits on both sides of the point (`1.0`, not `1.` or `.5`).

### Strings

A string literal fits on one line. The escapes are `\n`, `\r`, `\t`, `\\`, `\"`, `\$`, and `\u{H}` (a Unicode scalar value in hexadecimal). `${expression}` inside a string inserts the value of the expression; write `\$` for a literal `$` followed by `{`. Values of the basic types except `Unit` can be inserted directly; for other types, convert them to `String` first.

A multi-line string starts with `"""` at the end of a line and ends with `"""` on a line of its own. The indentation before the closing `"""` is removed from every line. A raw string `r"…"` (or `r"""…"""`) processes neither escapes nor `${…}`, which is convenient for regular expressions.

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind name <- "Ada"
  bind price <- 1.25m
  bind page <- """
    <p>Hello, ${name}</p>
    <p>Total: ${price * 3m}</p>
    """
  Console.write(page)
  Console.writeLine(r"\d+ and ${not interpolated}")
  Console.writeLine("${String.characterCount("héllo")} characters, ${String.byteLength("héllo")} bytes")
  Console.writeLine(Decimal.toString(Decimal.round(2.675m, 2, RoundingMode.HalfToEven)))
end function
```

```output
<p>Hello, Ada</p>
<p>Total: 3.75</p>
\d+ and ${not interpolated}
5 characters, 6 bytes
2.68
```

`String.length` does not exist: choose `String.characterCount` (Unicode scalar values) or `String.byteLength` (UTF-8 bytes). Comparison of strings is by Unicode scalar value and does not normalize text.

## 5. Operators

From lowest to highest precedence:

| Operators | Meaning | Associativity |
|---|---|---|
| `|>` | Pipe: `x |> f(a)` is `f(x, a)` | Left |
| `or` | Logical or (short-circuit) | Left |
| `and` | Logical and (short-circuit) | Left |
| `=` `<>` `<` `<=` `>` `>=` | Comparison | None (`a < b < c` is an error) |
| `+` `-` | Addition, subtraction; `+` also joins strings | Left |
| `*` `/` `div` `mod` | Multiplication; `/` for `Float` and `Decimal`; `div` and `mod` for `Integer` | Left |
| `-` `not` | Negation | Prefix |
| `f(...)` | Call | Postfix |

`==`, `!=`, `&&`, `||`, `!`, and `%` do not exist. `div` rounds toward zero and the sign of `mod` follows the dividend: `-7 div 2` is `-3` and `-7 mod 2` is `-1`. For rounding down, use `Integer.floorDivide` and `Integer.floorModulo`. `Integer` has no `/`.

`=` and `<>` compare values of *equality types*: types that contain no function type and no opaque type (`IOError`, `NetworkError`, `Reference`, `Lazy`, `Task`, resources, `Regex.Pattern`, and others). Lists, maps, sets, options, results, records, and data types are compared by their contents. `<`, `<=`, `>`, and `>=` work only on `Integer`, `Float`, `Decimal`, `Byte`, `Character`, and `String`. `Float` comparison follows IEEE 754: NaN is not equal to anything, even to itself, so use `Float.isNaN` to detect it.

Operands are evaluated from left to right.

## 6. Functions and lambdas

A function declares the types of its parameters and its return type after `->`. A function without `uses` is pure.

```text
function name(a: Type, b: Type) -> ReturnType uses Effect1, Effect2
  ...
end function
```

Calls are not curried: give every argument. A *lambda* is a function value; its parameter and return types may be left out. Like a function, a lambda returns its value with `return`; a lambda that returns `Unit` can end with a statement instead.

`_` as a direct argument of a call makes a function of the missing argument: `Integer.maximum(_, 0)` is `lambda(x) return Integer.maximum(x, 0) end lambda`. The pipe `x |> f(a, b)` passes `x` as the first argument, `f(x, a, b)`; when the call on the right has a `_`, the pipe fills that position instead.

Type parameters are written in brackets after the name: `function first[T](xs: List[T]) -> Option[T]`. Type arguments also use brackets: `List[Integer]`, `Map[String, Integer]`. An *effect variable* is a type parameter that stands for a set of effects; it lets a function take a function argument with any effects and pass them on.

```benitoite
import Benitoite.Unofficial.IO.Console

function between(low: Integer, value: Integer, high: Integer) -> Boolean
  return low <= value and value <= high
end function

function twice[T, effect E](x: T, f: function(T) -> T uses E) -> T uses E
  return f(f(x))
end function

function main() -> Unit uses Console.Write
  bind text <- [1, 2, 3, 4, 5]
    |> List.filter(_, between(2, _, 4))
    |> List.map(_, Integer.toString)
    |> String.join(_, ",")
  Console.writeLine(text)
  Console.writeLine(Integer.toString(twice(5, lambda(n) return n * 3 end lambda)))
  bind shout <- lambda(s: String) -> String
    Console.writeLine("shouting ${s}")
    return String.toUppercase(s)
  end lambda
  Console.writeLine(twice("hi", shout))
end function
```

```output
2,3,4
45
shouting hi
shouting HI
HI
```

`twice` has the effect variable `E`. Called with the pure lambda, it is pure; called with `shout`, which writes to the console, it uses `Console.Write`, which `main` declares.

A call in tail position (`return f(...)`) does not grow the call stack, also between different functions. Write loops as recursive functions in this form, or use `List.map`, `List.fold`, and `List.forEach`. Deep recursion that is not in tail position is limited by `--max-call-stack`.

## 7. Data types, records, and pattern matching

### Data types

A data type lists its constructors, one per line. Constructors are always written with the type name, in expressions and in patterns: `Shape.Circle(1.0)`, `Option.Some(x)`, `Result.Error(e)`. A type whose only constructor has the same name as the type, such as `Pair` and `Triple`, is written without the type name: `Pair(1, "one")`.

### Records

A record has named fields. Build one with named arguments, read a field with `Type.field(value)`, and make a copy with some fields changed with `Type(..value, field: newValue)`. `value.field` is not valid.

### Pattern matching

`match value with` is followed by one `case pattern -> body` per branch and closed by `end match`. Branches are tried in order. The checker reports a `match` that does not cover every value, and a branch that can never be chosen.

Patterns can be:

- `_` (anything), a name (binds the value), and literals of `Integer`, `String`, `Character`, and `Boolean`;
- constructors, `Shape.Circle(r)`, and records, `Person(name: n, ..)`;
- ranges that include both ends, `0..9` and `'a'..'z'`;
- lists, `[]`, `[x]`, `[first, ..rest]`, `[.., last]`;
- several alternatives separated by commas, `case 1, 2 ->`;
- followed by a guard, `case n if n > 0 ->`.

A list literal can contain one spread, `[first, ..rest]`, which inserts the elements of another list. `bind` and `shadow` accept a pattern that always matches, such as `bind Pair(a, b) <- pair`.

```benitoite
import Benitoite.Unofficial.IO.Console

data Shape
  Circle(Float)
  Rectangle(Float, Float)
end data

record Item
  name: String
  price: Integer
  quantity: Integer
end record

function area(shape: Shape) -> Float
  return match shape with
    case Shape.Circle(r) -> 3.0 * r * r
    case Shape.Rectangle(w, h) -> w * h
  end match
end function

function describe(xs: List[Integer]) -> String
  return match xs with
    case [] -> "empty"
    case [x] -> "one: ${x}"
    case [first, ..rest] if first < 0 -> "starts negative, ${List.length(rest)} more"
    case [first, ..] -> "starts with ${first}"
  end match
end function

function grade(score: Integer) -> String
  return match score with
    case 90..100 -> "A"
    case 70..89 -> "B"
    case 0, 1 -> "almost nothing"
    case _ -> "C"
  end match
end function

function main() -> Unit uses Console.Write
  List.forEach([Shape.Circle(1.0), Shape.Rectangle(2.0, 3.5)], lambda(s)
    Console.writeLine(Float.toString(area(s)))
  end lambda)
  bind item <- Item(name: "pen", price: 120, quantity: 3)
  bind more <- Item(..item, quantity: 10)
  Console.writeLine("${Item.name(more)}: ${Item.price(more) * Item.quantity(more)}")
  bind Pair(low, high) <- Pair(1, 9)
  Console.writeLine(describe([low, ..[high, 4]]))
  Console.writeLine(describe([-1, 2, 3]))
  Console.writeLine("${grade(95)} ${grade(75)} ${grade(1)} ${grade(50)}")
end function
```

```output
3.0
7.0
pen: 1200
starts with 1
starts negative, 2 more
A B almost nothing C
```

Data types and records can have type parameters: `data Tree[T]` with constructors `Leaf` and `Node(Tree[T], T, Tree[T])`.

## 8. Constants and type aliases

`const` declares a constant at the top level. The type is required, and the value must be computable before the program runs: literals, other constants, constructors, records, lists, operators, interpolation of constants, and `Map.fromList`, `Set.fromList`, `Map.empty()`, `Set.empty()`. Refer to a constant by its name, without parentheses.

`type Name = Type` declares another name for a type. It does not create a new type.

```benitoite
import Benitoite.Unofficial.IO.Console

type UserId = Integer

const defaultPort: Integer = 8000 + 80
const banner: String = "listening on ${defaultPort}"
const statusNames: Map[Integer, String] = Map.fromList([Pair(200, "OK"), Pair(404, "Not Found")])

function lookup(id: UserId) -> String
  return Option.unwrapOr(Map.get(statusNames, id), "unknown")
end function

function main() -> Unit uses Console.Write
  Console.writeLine(banner)
  Console.writeLine(lookup(404))
end function
```

```output
listening on 8080
Not Found
```

## 9. Errors: `Option`, `Result`, and `try`

An operation that may have no value returns `Option[T]` (`Option.Some(x)` or `Option.None`). An operation that may fail returns `Result[T, E]` (`Result.Ok(x)` or `Result.Error(e)`). IO operations return `Result[T, IOError]`; a missing file is a value, not a crash.

`try e` evaluates `e`. If it is `Result.Error` (or `Option.None`), the function returns it at once; otherwise `try` gives the value inside. `try` applies to the whole expression on its right, including pipes, and can only be used in a function that returns `Result` (or `Option`). When the error types differ, convert first, usually with `Result.mapError`.

```benitoite
import Benitoite.Unofficial.IO.Console

function parsePort(text: String) -> Result[Integer, String]
  return match Integer.parse(text) with
    case Option.Some(n) if n > 0 and n < 65536 -> Result.Ok(n)
    case _ -> Result.Error("not a port: ${text}")
  end match
end function

function main() -> Result[Unit, String] uses Console.Write
  bind port <- try parsePort("8080")
  Console.writeLine("port ${port}")
  bind other <- try parsePort("http")
  Console.writeLine("never printed ${other}")
  return Result.Ok(())
end function
```

```output
port 8080
exit 1
```

```stderr
not a port: http
```

Some failures are not values: `Integer` overflow, division by zero, a value too large to build, and running out of the call stack *stop* the program with a runtime error and exit status 1. A `match` cannot catch them. The report shows the place and the calls that led to it.

## 10. Effects

An *effect* names a kind of operation that a function may perform outside pure computation. A function lists, after `uses`, every effect it performs directly or through the functions it calls. A function without `uses` is pure. Lambdas infer their effects from their bodies.

The built-in effects are:

| Effect | Allows |
|---|---|
| `Console.Write` | writing to standard output and standard error |
| `Console.Read` | reading standard input |
| `File.Read` | reading files and directories |
| `File.Write` | creating, changing, moving, and deleting files and directories |
| `Process.Run` | starting external commands |
| `Process.Exit` | ending the program with a chosen exit code |
| `Process.Environment` | reading command-line arguments, environment variables, the working directory, and the script directory |
| `Clock.Time` | reading the clock and waiting |
| `Random.Generate` | generating random numbers |
| `Http.Listen` | accepting connections as an HTTP server |
| `Http.Connect` | connecting to HTTP servers |
| `State` | mutable cells and concurrent tasks inside the program |
| `Assert.Check` | checking expectations in tests |
| `IO.All` | all of `Console`, `File`, `Process`, `Clock`, `Random`, and `State` (not the network effects) |

Effects say what *kind* of operation a function may perform, not which file, command, or host. A script that passes `check` performs no built-in operation outside the `uses` of `main`. This release does not restrict operations while a script runs; run scripts you do not trust inside a sandbox. Prefer listing specific effects over `IO.All`, so that readers of `main` see what the script does.

```benitoite error
import Benitoite.Unofficial.IO.Console

function greet(name: String) -> Unit
  Console.writeLine("Hello, ${name}")
end function

function main() -> Unit uses Console.Write
  greet("Ada")
end function
```

```diagnostic
error[E0501]
```

Adding `uses Console.Write` to `greet` fixes the error.

An effect is part of the type of a function value: `function(String) -> Unit uses Console.Write`.

## 11. Effect handlers

You can declare your own effects. An `effect` declaration lists its operations, which are called like functions. `handle body with case operation(arguments) -> clause end handle` runs `body` and, whenever the body calls one of the listed operations, runs the clause instead. In the clause, `resume(value)` continues the body, with `value` as the result of the operation. A clause that does not call `resume` ends the `handle` with its own value.

```benitoite
import Benitoite.Unofficial.IO.Console

effect Log
  function write(message: String) -> Unit
end effect

function sumPrices(items: List[Integer]) -> Integer uses Log
  write("items: ${List.length(items)}")
  return List.fold(items, 0, lambda(acc, x) return acc + x end lambda)
end function

function main() -> Unit uses Console.Write
  bind total <- handle
    sumPrices([120, 300, 80])
  with
    case write(message) ->
      Console.writeLine("log: ${message}")
      resume(())
  end handle
  Console.writeLine("total: ${total}")
end function
```

```output
log: items: 3
total: 500
```

Operations of built-in effects, such as `File.readText` or `Process.run`, can be handled in the same way. This is how tests replace the outside world ([Tests](#16-tests)). A handler that handles only some operations of an effect does not remove the effect from the type. Functions whose effects include `State` (`Reference`, `TaskGroup`, `Task.await`, and the `close…` functions) cannot be handled.

In `uses` and in `case`, an effect or operation declared in the same module is written without a module name (`Log`, `write`); one from another module is written with it (`Logging.Log`, `Logging.write`, `Console.writeLine`).

## 12. Modules

Each file is a module. Its name is its path from the root directory, with `/` replaced by `.` and without `.bnt`: the file `Lib/Text.bnt` is the module `Lib.Text`. `import Lib.Text` makes it available as `Text`; `import Lib.Text as T` makes it available as `T`. Only declarations marked `public` can be used from other modules. Imports cannot form a cycle.

```files
name: Lib/Text.bnt
/// Turns "Hello World" into "hello-world".
public function slug(text: String) -> String
  return String.toLowercase(String.replace(String.trim(text), " ", "-"))
end function
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Lib.Text

function main() -> Unit uses Console.Write
  Console.writeLine(Text.slug(" Hello World "))
end function
```

```output
hello-world
```

### Standard and unofficial modules

The modules of the standard library are named `Benitoite.<Name>`. Most of the core modules (`Integer`, `String`, `List`, `Map`, `Option`, `Result`, and others) are in the *prelude*: they can be used without `import`.

In this release, the IO and network modules and the text and data modules are *unofficial*: their interfaces may still change, so they are imported under `Benitoite.Unofficial`. Write `import Benitoite.Unofficial.IO.Console` and refer to the module as `Console`. `import Benitoite.IO.Console` is an error in this release. When an unofficial module becomes standard in a later minor version, its import name changes to `Benitoite.<Name>` and scripts must change their imports.

Every module outside the prelude must be imported, also when it appears only in `uses`. See [The standard library](#19-the-standard-library) for the list.

## 13. Type classes

A *type class* (`trait`) declares functions that several types implement. `implement` gives the implementation for one type. A type parameter can be constrained with `[T: Show]`; several constraints are joined with `&`. The built-in constraints `equality` (values can be compared with `=`) and `key` (values can be keys of `Map` and elements of `Set`) can be used in the same place. Methods are called through the class name: `Describe.describe(x)`.

```benitoite
import Benitoite.Unofficial.IO.Console

trait Describe[T]
  function describe(x: T) -> String
end trait

implement Describe[Integer]
  function describe(x: Integer) -> String
    return "the number ${x}"
  end function
end implement

implement[T: Describe] Describe[List[T]]
  function describe(xs: List[T]) -> String
    return "[" + String.join(List.map(xs, Describe.describe), ", ") + "]"
  end function
end implement

function describeIfSame[T: Describe & equality](a: T, b: T) -> String
  return if a = b then Describe.describe(a) else "different" end if
end function

function main() -> Unit uses Console.Write
  Console.writeLine(Describe.describe([1, 2]))
  Console.writeLine(describeIfSame(3, 3))
end function
```

```output
[the number 1, the number 2]
the number 3
```

An implementation applies to the whole program. An implementation must be in the module of the class or of the type, and two implementations cannot overlap. The standard classes, such as `Show`, `Order`, `Monoid`, `Functor`, and `Monad`, are in the module `Benitoite.Trait`.

## 14. Explicit laziness

`lazy ... end lazy` makes a value of type `Lazy[T]` without evaluating its body. `Lazy.force(value)` evaluates the body the first time and returns the saved result after that. The body must be pure.

```benitoite
import Benitoite.Unofficial.IO.Console

function choose(useFirst: Boolean, first: Lazy[Integer], second: Lazy[Integer]) -> Integer
  return if useFirst then Lazy.force(first) else Lazy.force(second) end if
end function

function main() -> Unit uses Console.Write
  bind result <- choose(true, lazy 42 end lazy, lazy 100 div String.characterCount("") end lazy)
  Console.writeLine("${result}")
end function
```

```output
42
```

The division by zero is never evaluated.

## 15. Mutable cells, resources, and tasks

### Mutable cells

A `Reference` is a mutable cell. `Reference.new`, `Reference.get`, and `Reference.set` need the effect `State`. Values themselves never change: lists, maps, and sets are persistent, and their functions return new collections.

### Resources and `with`

`with name = expression do ... end with` binds a resource, such as an HTTP listener or a task group, and releases it when the block ends, also when it ends with `return`, `try`, or a runtime error. Several resources are separated by commas and released in reverse order. Releasing has the effect `State`, so a function that uses `with` lists `State` in `uses`.

### Tasks

Tasks run concurrently within one program. `TaskGroup.open()` opens a group as a resource; `TaskGroup.spawn(group, lambda() ... end lambda)` starts a task in it, and `Task.await(task)` waits for its result. Releasing the group at `end with` waits for all its tasks. `Task.all` runs a list of functions as tasks and returns their results in order; `Task.withTimeout` and `Task.race` give up waiting after a time or for the first result. Operations that wait, such as reading a file, an HTTP request, or `Clock.sleep`, let other tasks run.

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write, State
  bind counter <- Reference.new(0)
  bind squares <- with group = TaskGroup.open() do
    bind tasks <- List.map([1, 2, 3], lambda(n)
      return TaskGroup.spawn(group, lambda()
        Reference.set(counter, Reference.get(counter) + 1)
        return n * n
      end lambda)
    end lambda)
    List.map(tasks, lambda(task) return Task.await(task) end lambda)
  end with
  Console.writeLine("${String.join(List.map(squares, Integer.toString), " ")} after ${Reference.get(counter)} tasks")
  Console.writeLine(String.join(List.map(Task.all([lambda() return "a" end lambda, lambda() return "b" end lambda]), lambda(s) return s end lambda), ""))
end function
```

```output
1 4 9 after 3 tasks
ab
```

When a task stops with a runtime error, the program stops. When the program is interrupted, all tasks are cancelled and resources are released.

## 16. Tests

A test is a function with the attribute `@test("description")`, no parameters, and the return type `Unit` or `Result[Unit, String]`. Check values with `Assert.equal(actual, expected)` and `Assert.isTrue(condition, message)`, which need the effect `Assert.Check`. A failed check stops that test; returning `Result.Error(message)` also fails it. Each test runs on its own, so a failure or a runtime error in one test does not stop the others.

```benitoite test
import Benitoite.Unofficial.IO.File

function countWords(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  return Result.Ok(List.length(List.filter(String.split(text, " "), lambda(w) return w <> "" end lambda)))
end function

@test("countWords counts words separated by spaces")
function countWordsCounts() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    countWords("notes.txt")
  with
    case File.readText(path) ->
      Assert.equal(path, "notes.txt")
      resume(Result.Ok("one two  three"))
  end handle
  Assert.equal(result, Result.Ok(3))
end function
```

The handler replaces `File.readText`, so the test reads no file. The test still lists `File.Read`, because the handler handles only `File.readText`, one of the operations of `File.Read`, and an effect is removed only when all its operations are handled.

Run tests with `benitoite test`. For a file `t.bnt` with one passing test and one test that checks `Assert.equal(double(2), 5)`, the report is:

```sh
benitoite test t.bnt
```

```text
test t.bnt: "double doubles" ... ok
test t.bnt: "fails" ... FAILED

failures:

---- t.bnt: "fails" ----
assertion failed: Assert.equal
  left:  4
  right: 5
  --> t.bnt:12:3
   = note: call trace (innermost first):
             fails
   = note: functions left by tail calls are not shown

test result: FAILED. 1 passed; 1 failed
```

A file with check errors is not run: its diagnostics go to standard error, and the tests of the other files still run. `benitoite check` reports an error for a file without `main`, so use `test`, not `check`, on test files.

With `--diagnostics=json`, `test` writes one JSON object per line to standard output: one with `"kind": "test"` per test, with the fields `file`, `name`, `function`, `location`, `outcome` (`"passed"` or `"failed"`), `failure`, `stdout`, and `stderr`, and a last one with `"kind": "testSummary"` and the counts `passed`, `failed`, and `filesNotRun`, and `interrupted`. A `failure` has a `reason` and a `message`. The reason is `"assert"` (a failed check, with `primary`, `trace`, and for `Assert.equal` and `Assert.notEqual` the values `left` and `right`), `"error"` (the test returned `Result.Error`), `"runtime"` (a runtime error, with the fields of a runtime error report), or `"exit"` (the test called `Process.exit`, with `exitCode`). Failures with the reasons `"assert"`, `"runtime"`, and `"exit"` also have `notes`, an array of strings that includes failures to release resources while stopping.

The exit status of `test` is 0 when all tests pass, 1 when a test fails, 2 for check errors, unreadable files, and usage errors, 3 for an internal error, and 130 when interrupted. When several apply, the first in the order 130, 3, 2, 1 is used.

## 17. Formatting

`benitoite fmt` rewrites files in the standard layout. It changes only whitespace: spaces within lines, indentation, blank lines, and trailing spaces. It keeps your line breaks and comments, does not add or remove tokens, and has no settings. `fmt` checks only the syntax, so a file with type errors can be formatted. A file with lexical or syntax errors (codes `E01nn` and `E02nn`) is left unchanged and its diagnostics are reported; the other files are still formatted. Other errors found while reading the file, such as a wrong attribute, do not stop formatting.

`fmt --check` rewrites nothing and lists the files that would change on standard error. `fmt` writes nothing to standard output. A file is replaced only after the new content is written completely, so an interrupted `fmt` does not leave a broken file.

The exit status of `fmt` is 0 on success, 1 when `--check` finds a file that would change, 2 for syntax errors, files that cannot be read or written, and usage errors, and 3 for an internal error.

## 18. Diagnostics

A diagnostic has a code: `E` for errors, `W` for warnings, and `L` for limits of `benitoite` (reported by `run` and `test` only, so a script that passes `check` can still end `run` with status 2). The text form shows the code, the place in the source, and often `= help:` with a suggested fix:

```benitoite error
function main() -> Unit
  let total = 1 + 2
end function
```

```diagnostic
error[E0230]: `let` is not used to bind names
   = help: write `bind total <- 1 + 2`
```

Warnings are reported by `check`, `run`, and `test` without failing them, unless `--deny-warnings` is given.

With `--diagnostics=json`, each diagnostic is one JSON object on its own line of standard error, with the fields `kind`, `severity`, `code`, `message`, `primary`, `secondary`, `notes`, and `helps`. `primary` is the main place (`null` when there is none), with `file`, `start`, `end` (each with `line`, `column`, and `offset`), and `label`. Each element of `helps` is an object with a `message` and an array `edits` of replacements; each replacement has `file`, `start`, `end`, and the `replacement` text. A help without a mechanical fix has an empty `edits`.

Tell diagnostics apart by `code` and the JSON fields, not by the message: messages and the contents of helps may change even in patch versions. A code that has been removed is never reused with another meaning.

The meaning of every code is listed in the bundled Agent Skill (`references/diagnostics.md`, installed by `benitoite skill install`).

## 19. The standard library

Modules in the prelude need no import. The others are imported with the name in the table. The full list of functions of each module is in the bundled Agent Skill (`references/stdlib/`).

| Module | Import | Contents |
|---|---|---|
| `Integer`, `Float`, `Decimal`, `RoundingMode`, `Byte`, `Character`, `String`, `Boolean` | prelude | Functions on the basic types |
| `List`, `Map`, `Set` | prelude | Persistent collections; maps and sets are ordered by key |
| `Option`, `Result`, `Pair`, `Triple` | prelude | Optional values, results, and tuples |
| `Bytes`, `ByteOrder` | prelude | Immutable byte sequences |
| `IOError`, `IOErrorKind`, `NetworkError`, `NetworkErrorKind` | prelude | Failures of IO and network operations |
| `Reference`, `Lazy`, `Task`, `TaskGroup`, `State` | prelude | Mutable cells, explicit laziness, tasks, and the effect `State` |
| `Assert` | prelude | Checks in tests |
| `IO` | prelude | The effect `IO.All` |
| `Trait` | `import Benitoite.Trait` | Standard type classes |
| `IO.Console` | `import Benitoite.Unofficial.IO.Console` | Standard input and output |
| `IO.File` | `import Benitoite.Unofficial.IO.File` | Files and directories |
| `IO.Process` | `import Benitoite.Unofficial.IO.Process` | Arguments, environment, external commands, exit |
| `IO.Clock` | `import Benitoite.Unofficial.IO.Clock` | The clock and waiting |
| `IO.Random` | `import Benitoite.Unofficial.IO.Random` | Random numbers |
| `Time` | `import Benitoite.Unofficial.Time` | Points in time and calendar dates |
| `Path` | `import Benitoite.Unofficial.Path` | Joining and splitting paths |
| `Json` | `import Benitoite.Unofficial.Json` | JSON |
| `Csv` | `import Benitoite.Unofficial.Csv` | CSV (RFC 4180) |
| `Regex` | `import Benitoite.Unofficial.Regex` | Regular expressions with matching time linear in the input |
| `Encoding` | `import Benitoite.Unofficial.Encoding` | Base64 |
| `Hash` | `import Benitoite.Unofficial.Hash` | SHA-256 hash values of bytes |
| `Network.Http` | `import Benitoite.Unofficial.Network.Http` | HTTP/1.1 servers without TLS, and clients for `http` and `https` |

A few behaviors worth knowing:

- Relative file paths are resolved against the working directory. Use `Process.scriptDirectory()` for files next to the script.
- `Process.run` starts a program with a list of arguments, without a shell. A non-zero exit code is not an error; read it from the result. When the command does not read all of the `input` you gave it (as `head` does), that is not an error either.
- `Process.shell` runs a command line with `/bin/sh -c`. Write only POSIX sh.
- `Http.get` and `Http.send` accept only the standard methods (`GET`, `HEAD`, `POST`, `PUT`, `DELETE`, `CONNECT`, `OPTIONS`, `TRACE`, `PATCH`, in uppercase). Another method, or a non-empty body with `GET`, `HEAD`, or `CONNECT`, gives `NetworkErrorKind.InvalidInput` without sending anything. A host name that cannot be resolved gives `NetworkErrorKind.HostNotFound`.

This example reads a JSON file and sums the amounts per category:

```files
name: orders.json
[
  {"category": "book", "amount": 1200},
  {"category": "food", "amount": 300},
  {"category": "book", "amount": 800}
]
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.Json

function amountOf(order: Json.Value) -> Option[Pair[String, Integer]]
  bind category <- try Option.andThen(Json.get(order, "category"), Json.asString)
  bind amount <- try Option.andThen(Json.get(order, "amount"), Json.asInteger)
  return Option.Some(Pair(category, amount))
end function

function main() -> Result[Unit, String] uses File.Read, Console.Write
  bind text <- try File.readText("orders.json") |> Result.mapError(_, IOError.message)
  bind value <- try Json.parse(text) |> Result.mapError(_, Json.ParseError.message)
  bind orders <- try Option.okOr(Json.asArray(value), "orders.json is not an array")
  bind totals <- List.fold(orders, Map.empty(), lambda(m, order)
    return match amountOf(order) with
      case Option.Some(Pair(category, amount)) ->
        Map.set(m, category, Option.unwrapOr(Map.get(m, category), 0) + amount)
      case Option.None -> m
    end match
  end lambda)
  Map.forEach(totals, lambda(category, total)
    Console.writeLine("${category}: ${total}")
  end lambda)
  return Result.Ok(())
end function
```

```output
book: 2000
food: 300
```

## 20. Compatibility

While the major version is 0:

- A minor version (`0.1.0` to `0.2.0`) may change the language, the standard library, the command line, and diagnostics in incompatible ways. Each incompatible change is listed in the [CHANGELOG](../../CHANGELOG.md) with how to migrate.
- A patch version (`0.1.0` to `0.1.1`) only fixes bugs, that is, behavior of `benitoite` that differs from its specification. It does not change the language, the standard library (including unofficial modules), the command line, diagnostic codes, or the JSON formats. Messages and suggested fixes in diagnostics may change.
- Moving an unofficial module into the standard library changes its import name, and happens only in a minor version.
- The bundled Agent Skill describes only the version of `benitoite` it comes with. Run `benitoite skill install` again after updating.

> Note: `0.0.1` is a source-only release; no executables are provided. Executables will be provided from `0.1.0`, and until then any release may contain incompatible changes.
