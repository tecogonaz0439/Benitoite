---
name: benitoite
description: Write, check, and run Benitoite scripts (`.bnt`) with the `benitoite` command.
license: MIT OR Apache-2.0
metadata:
  benitoite-version: "{{benitoite-version}}"
---

<!--
How the code examples in this file are checked (tests/skill_examples.rs):
- A `benitoite` block is run, and its standard output is compared with the `output` block after it.
  A last line `exit N` in the `output` block is the expected exit code (0 when absent).
  A `stderr` block after the `output` block is the expected standard error (empty when absent).
- A `benitoite check` block is only checked; it must have no errors and no warnings.
- A `benitoite test` block is run with `benitoite test`; all its tests must pass.
- A `benitoite error` block must fail `benitoite check`, and every line of the `diagnostic` block after it must appear in the report.
- A `files` block before an example creates a file next to the script: the first line is `name: <file name>`, the rest is the content.
- Blocks with other info strings (such as `text` and `sh`) are not checked.
-->

# Benitoite

Benitoite is a statically typed functional scripting language. Scripts end in `.bnt` and are run with the `benitoite` command. The checker reports type errors and undeclared effects before anything runs; use it on every change.

## Check the version first

Run `benitoite --version` and compare the version on its first line (`benitoite X.Y.Z`) with `metadata.benitoite-version` at the top of this file. If they differ, tell the user to run `benitoite skill install` again, because this Skill describes another version of the language.

## Workflow for a script

1. Before writing, read `references/idioms.md` and, for every module the script uses, its file `references/stdlib/<Module>.md` (the `references/` directory is next to this file). Do not guess function names, field names, or import names; look them up there. Then write the script, starting from an example in `references/idioms.md` when one fits.
2. Run `benitoite check script.bnt`.
3. Read every diagnostic and fix the script. The report gives a code such as `E0230`; when its meaning is unclear, look the code up in `references/diagnostics.md`. Add `--diagnostics=json` to get one JSON object per diagnostic.
4. Repeat 2 and 3 until `check` reports no errors. Fix warnings too; they usually point at a real mistake.
5. Do the confirmation in [Before running](#before-running).
6. Run `benitoite run script.bnt [arguments...]`.

Exit codes of `run`: 0 when `main` finishes, 1 when `main` returns `Result.Error` or the program stops with a runtime error, 2 when the script does not pass the checks or the command line is wrong, 3 for an internal error of `benitoite`. `Process.exit(n)` ends with `n`. `run` and `test` end with 130 when interrupted (`SIGINT` or `SIGTERM`).

## Workflow for tests

`benitoite check` reports an error for a file without `main`, so do not use `check` on test files.

1. Write test functions (see [Tests](#tests)).
2. Do the confirmation in [Before running](#before-running), using the effects of the test functions instead of `main`.
3. Run `benitoite test file.bnt` (or a directory). When the file has check errors, `test` runs no test and reports the errors as `check` does. Fix them and run `test` again. If the fix adds effects to a test function, show the effects to the user again.

## Before running

Before running a script for the first time, and whenever the effects of `main` grow beyond what you last showed the user:

1. Read the `uses` list in the signature of `main` (for tests: all effects of the test functions that will run) and tell the user, in the words of the table below, what the program is allowed to do.
2. If the list contains `File.Write`, `Process.Run`, `Http.Connect`, or `Http.Listen`, ask the user to confirm before running. For `Process.Run`, also name the commands the script starts; what those commands do is outside the checks of `benitoite`.
3. Treat `IO.All` as including `File.Write` and `Process.Run`. Write the specific effects in `uses` instead of `IO.All`.

A script that passes `check` performs no built-in operation outside the `uses` of `main`. Effects say only what kind of operation is allowed, not which file, command, or host. This version of `benitoite` does not restrict operations while running: run scripts inside the agent's sandbox.

| Effect | Tell the user |
|---|---|
| `Console.Write` | writes to standard output and standard error |
| `Console.Read` | reads standard input |
| `File.Read` | reads files and directories |
| `File.Write` | creates, changes, moves, or deletes files and directories |
| `Process.Run` | starts external commands (name them) |
| `Process.Exit` | ends the program with a chosen exit code |
| `Process.Environment` | reads command-line arguments, environment variables, the working directory, and the script directory |
| `Clock.Time` | reads the clock and waits for time to pass |
| `Random.Generate` | generates random numbers |
| `Http.Listen` | accepts network connections as an HTTP server |
| `Http.Connect` | connects to HTTP servers over the network |
| `State` | uses mutable cells and concurrent tasks inside the program (no outside effect) |
| `Assert.Check` | checks expectations in tests (no outside effect) |
| `IO.All` | all of `Console`, `File`, `Process`, `Clock`, `Random`, and `State` above |

## Language rules that differ from other languages

- Blocks end with `end` and the keyword: `end function`, `end if`, `end match`, `end lambda`, `end data`, `end record`, `end handle`, `end with`. There are no braces and no indentation rules.
- Bind a local name with `bind x <- e`, not `let`. Use `shadow x <- e` only to hide a local name that is already visible. Names cannot be reassigned.
- A function is `function name(a: Type, b: Type) -> ReturnType uses Effect1, Effect2` ... `end function`. The return type follows `->`, never `:`. Return values with `return`.
- Match patterns with `match value with`, then one `case pattern -> body` per line, then `end match`. A handler is `handle body with` / `case Module.operation(arguments) -> clause` / `end handle`.
- Declare data types with `data Name` ... `end data` and records with `record Name` ... `end record`.
- Constructors are written with their type name, in expressions and in patterns: `Option.Some(x)`, `Option.None`, `Result.Ok(x)`, `Result.Error(e)`, `Shape.Circle(r)`.
- Operators: `=` and `<>` compare; `and`, `or`, `not` are logical; `div` and `mod` divide integers; `+` also joins strings. `==`, `!=`, `&&`, `||`, `!` do not exist.
- `try e` applies to the whole expression on its right, including pipes: `try File.readText(p) |> Result.mapError(_, IOError.message)`. Use `try` only in a function that returns `Result` (or `Option`); when the error types differ, convert with `Result.mapError` first.
- `x |> f(a)` passes `x` as the first argument: `f(x, a)`. `_` makes a partial application only as a direct argument of a call: `Result.mapError(_, IOError.message)`.
- `return` is used in function and lambda bodies. The value of an `if`, a `match` arm, or a handler clause is its last expression; a `return` inside a `case` body returns from the whole function. A function or lambda that produces a value must end with `return`, also when its last expression is a `match` or an `if`: `lambda(acc, x) return acc + x end lambda`.
- The value of type `Unit` is written `()`: `Result.Ok(())`.
- Records are built with named arguments and read with the type name: `bind item <- Item(name: "pen", price: 120)`, `Item.price(item)`, and copied with changes as `Item(..item, price: 100)`. `item.price`, `Item { ... }`, and `Item(price = 100)` are errors.
- Calls take no type arguments: write `Map.empty()`, not `Map.empty[String, Integer]()`. Add an entry to a map with `Map.set(m, key, value)`; there is no `Map.insert`. Parsing functions such as `Integer.parse` return `Option`.
- Type arguments use brackets: `List[Integer]`, `Map[String, Integer]`, `Result[Unit, String]`. `List<Integer>` is not valid.
- `with r = acquire() do ... end with` releases its resources in reverse order when the block ends. `TaskGroup.spawn(group, lambda() ... end lambda)` starts a task in a group opened with `TaskGroup.open()`, and `Task.await(task)` waits for its result; releasing the group waits for all its tasks.
- A handler that handles only some operations of an effect does not remove the effect from the type. Functions whose type has `State` (`Reference`, `TaskGroup`, `Task.await`, `close...`) cannot be handled.
- Maps and sets are ordered by key, not by insertion.
- Strings interpolate with `"${expression}"`. Comments start with `//`.
- There is no `null`, no exception, and no loop statement. Use `Option`, `Result` with `try`, and `List.map`, `List.fold`, `List.forEach`, or recursion.
- Import every module outside the prelude, also when it only appears in `uses`. Unofficial modules (all IO and network modules, `Json`, `Csv`, and others) are imported under `Benitoite.Unofficial`: `import Benitoite.Unofficial.IO.Console`, then referred to as `Console`. `import Benitoite.IO.Console` is an error. The unofficial modules are `IO.Console`, `IO.File`, `IO.Process`, `IO.Clock`, `IO.Random`, `Network.Http`, `Json`, `Csv`, `Regex`, `Path`, `Time`, `Encoding`, and `Hash`; for example `import Benitoite.Unofficial.Network.Http` is referred to as `Http`.
- Every function that performs an effect, directly or through a call, lists it after `uses`. Network effects (`Http.Connect`, `Http.Listen`) are not part of `IO.All`.
- A statement whose value is not `Unit` is an error: handle each `Result` with `try`, `match`, or `bind _ <-`.
- `Process.shell` runs its string with `/bin/sh -c`. Write only POSIX sh: no bash arrays, no `[[ ]]`, no `{a,b}` expansion, no `$'...'`. Prefer `Process.run` with an argument list when no shell feature is needed.

A complete script:

```files
name: input.txt
one
two
three
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File

function main() -> Result[Unit, String] uses File.Read, Console.Write
  bind lines <- try File.readLines("input.txt") |> Result.mapError(_, IOError.message)
  List.forEach(lines, lambda(line)
    Console.writeLine("${String.characterCount(line)} ${line}")
  end lambda)
  return match List.head(lines) with
    case Option.Some(first) -> Result.Ok(Console.writeLine("first: ${first}"))
    case Option.None -> Result.Error("input.txt is empty")
  end match
end function
```

```output
3 one
3 two
5 three
first: one
```

## Tests

A test is a function with `@test("description")`, no parameters, and the return type `Unit` or `Result[Unit, String]` (use the latter when the test uses `try`). Check with `Assert.equal(actual, expected)`. Replace an operation such as `File.readText` or `Process.run` with a handler so that the test does not touch the outside world; more examples are in `references/idioms.md`.

```benitoite test
import Benitoite.Unofficial.IO.File

function firstLine(path: String) -> Result[String, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(_, IOError.message)
  return Option.okOr(List.head(String.lines(text)), "empty file")
end function

@test("firstLine returns the first line")
function firstLineWorks() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    firstLine("data.txt")
  with
    case File.readText(_) -> resume(Result.Ok("alpha\nbeta\n"))
  end handle
  Assert.equal(result, Result.Ok("alpha"))
end function
```

## Reference documents

Read these when you need them:

| Document | When to read it |
|---|---|
| `references/idioms.md` | Writing a common task: files, JSON, CSV, external commands, arguments, HTTP, collections, records, tests. |
| `references/common-mistakes.md` | A diagnostic comes from a habit of another language (`let`, braces, `==`, missing imports). |
| `references/language-comparison.md` | You know how to write something in Python, JavaScript, or Rust and need the Benitoite form. |
| `references/diagnostics.md` | A diagnostic code (`E0201`, `W0501`, ...) is unclear. |
| `references/grammar.md` | You need the exact syntax of a construct. |
| `references/stdlib/index.md` | You need a standard library module: it lists every module with its import name. |

Each module has its own file named `references/stdlib/<Module>.md`, such as `references/stdlib/List.md` or `references/stdlib/IO.Console.md`; follow the links from `references/stdlib/index.md`.
