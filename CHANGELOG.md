# Changelog

All notable changes to Benitoite are recorded in this file. Versions follow the policy in [Compatibility](docs/reference/benitoite.md#20-compatibility): while the major version is 0, a minor version may contain incompatible changes, and a patch version contains only bug fixes. Until `0.1.0`, any release may contain incompatible changes. Every incompatible change is listed with how to migrate.

## 0.0.2 (San Benito)

A source-only release; no executables are provided. The language and the behavior of `benitoite` are the same as in `0.0.1`, except that `benitoite --version` prints `benitoite 0.0.2`. Scripts written for `0.0.1` need no changes.

### Changed

- The formal verification in `formal/` now covers the desugaring of the whole language of `0.0.1`: a Lean proof shows that desugaring preserves types, and differential tests compare the Lean desugaring with the implementation.
- The coverage check of `match` is formalized and proved sound, and differential tests compare it with the implementation's check.
- A Lean checker for the typed surface syntax is proved sound and used to check the type checker's output for the test programs.
- The design documents in `docs/design/` now describe only what the implementation does.

## 0.0.1 (San Benito)

The first release, source only; no executables are provided. It replaces the minimal implementation (`0.0.0`), which was not distributed. The language is described in the [Benitoite Language Reference](docs/reference/benitoite.md), and installation in [Installing Benitoite](docs/reference/install.md).

### Added

- Modules: one file is one module, imported by name (`import Lib.Text`); `public` declarations; a directory with `main.bnt` can be run.
- Records, `Pair` and `Triple`, type aliases (`type`), and top-level constants (`const`).
- Type classes (`trait` and `implement`), constraints (`[T: Show & equality]`), and the standard classes in `Benitoite.Trait`.
- User-defined effects and effect handlers (`effect`, `handle ... with case ... -> ... end handle`, `resume`), also for the operations of the built-in effects.
- `try` for returning `Result.Error` and `Option.None` early.
- String interpolation (`"${x}"`), multi-line strings (`"""`), raw strings (`r"..."`), and `Decimal` (`1.25m`), `Byte`, and `Bytes`.
- Pattern alternatives, guards, ranges, list patterns, and list spreads (`[x, ..rest]`).
- Explicit laziness (`lazy ... end lazy`), resource scopes (`with ... do ... end with`), mutable cells (`Reference`), and tasks (`Task`, `TaskGroup`).
- Attributes `@test` and `@deprecated`, and documentation comments (`///` and `//!`).
- Fine-grained built-in effects (`Console.Write`, `File.Read`, `Process.Run`, `Http.Connect`, and others) and `IO.All`.
- Standard library modules for files, processes, the clock, random numbers, time, paths, JSON, CSV, regular expressions, Base64, hashes, and HTTP.
- Commands `benitoite test`, `benitoite fmt`, and `benitoite skill install|uninstall`; the option `--licenses`; the option `--deny-warnings`; running a script without `run` and with a shebang line `#!/usr/bin/env benitoite`; exit status 130 on `SIGINT` and `SIGTERM`.
- Warnings (`W` codes), reported by `check`, `run`, and `test`.
- The bundled Agent Skill, installed with `benitoite skill install`.

### Incompatible changes from 0.0.0

Scripts written for `0.0.0` do not pass `benitoite check` in `0.0.1` without changes. The diagnostics of `0.0.1` point out many old forms of syntax (such as `fn`, `let`, and braces) and suggest the new one; fix the script by running `benitoite check` and following the `= help:` lines. The table lists each change and how to migrate.

#### Syntax

| `0.0.0` | `0.0.1` | How to migrate |
|---|---|---|
| `fn name(a: Int) -> Int { ... }` | `function name(a: Integer) -> Integer` ... `end function` | Replace `fn` with `function` and the braces with `end function`. |
| `{ ... }` blocks of `if`, `match`, and lambdas | `if c then ... else ... end if`, `match v with ... end match`, `lambda(x) ... end lambda` | Close every block with `end` and its keyword. `{` and `}` are now used only in `${...}`. |
| `fn(x) { x + 1 }` | `lambda(x) return x + 1 end lambda` | Write lambdas with `lambda` and `return`. |
| The last expression of a block is its value | `return expression` | Add `return` before the value of a function or lambda. The value of an `if`, a `match` branch, and a handler clause is still its last expression. |
| `let x = e` | `bind x <- e` | Replace `let`. To hide a name that is already visible, write `shadow x <- e`. |
| `let _ = e` | `bind _ <- e` | Same as above. |
| `match v { P => e }` | `match v with` / `case P -> e` / `end match` | Write `with`, start each branch with `case`, and use `->`. |
| `type Shape { Circle(Float) }` | `data Shape` / `Circle(Float)` / `end data` | Replace `type` with `data` and the braces with `end data`. `type` now declares a type alias. |
| `Some(x)`, `None`, `Ok(x)`, `Err(e)` | `Option.Some(x)`, `Option.None`, `Result.Ok(x)`, `Result.Error(e)` | Write the type name before these constructors, in expressions and patterns. |
| `==`, `!=`, `&&`, `||`, `!` | `=`, `<>`, `and`, `or`, `not` | Replace the operators. |
| `a / b` and `a % b` on `Int` | `a div b` and `a mod b` | `/` is now only for `Float` and `Decimal`. The results of `div` and `mod` are the same as those of `/` and `%` in `0.0.0`. |
| `fn(String) -> Unit uses IO` (function type) | `function(String) -> Unit uses Console.Write` | Write function types with `function`. |
| `"$" + "{"` was needed because `${` was rejected | `"${x}"` interpolates; `\$` writes `$` | Strings in `0.0.0` could not contain `${`, so no existing string changes meaning. |

#### Types and effects

| `0.0.0` | `0.0.1` | How to migrate |
|---|---|---|
| `Int`, `Bool`, `Char` | `Integer`, `Boolean`, `Character` | Rename the types and their modules (`Int.toString` becomes `Integer.toString`). |
| `uses IO` | `uses Console.Write`, `File.Read`, ... | List the specific effects that the function uses (see [Effects](docs/reference/benitoite.md#10-effects)). `uses IO.All` is accepted and covers the console, files, processes, the clock, random numbers, and `State`, but not the network. |
| `IoError`, `IoError.message` | `IOError`, `IOError.message` | Rename. `IOError.kind` and `IOErrorKind` are new. |

#### Modules and the standard library

| `0.0.0` | `0.0.1` | How to migrate |
|---|---|---|
| `Console`, `File`, and `Process` were available without import | `import Benitoite.Unofficial.IO.Console` (and `IO.File`, `IO.Process`) | Add an `import` for every IO module the script uses, also when the module appears only in `uses`. |
| `Console.println`, `Console.print`, `Console.eprintln` | `Console.writeLine`, `Console.write`, `Console.writeErrorLine` | Rename. |
| `Process.args()` | `Process.arguments()` | Rename. It needs the effect `Process.Environment`. |
| `String.charCount`, `String.charAt`, `String.charSlice`, `String.chars`, `String.fromChars` | `String.characterCount`, `String.characterAt`, `String.characterSlice`, `String.characters`, `String.fromCharacters` | Rename. |
| `Char.toInt`, `Char.fromInt`, `Char.isAsciiDigit`, `Char.isAsciiWhitespace` | `Character.toInteger`, `Character.fromInteger`, `Character.isASCIIDigit`, `Character.isASCIIWhitespace` | Rename. |
| `Float.sqrt`, `Float.abs`, `Float.ceil` | `Float.squareRoot`, `Float.absolute`, `Float.ceiling` | Rename. |
| `Int.abs`, `Int.min`, `Int.max`, `Int.floorDiv` | `Integer.absolute`, `Integer.minimum`, `Integer.maximum`, `Integer.floorDivide` | Rename. |
| `Int.mod` (remainder of floor division; its sign follows the divisor) | `Integer.floorModulo` | Move to `Integer.floorModulo`, not to the operator `mod`. The operator `mod` gives the remainder of division rounded toward zero, whose sign follows the dividend, so the result differs for negative numbers (`Integer.floorModulo(-7, 2)` is `1`; `-7 mod 2` is `-1`). `Integer.mod` does not exist. |
| `List.concat` | `List.concatenate` | Rename. |
| `Result.mapErr`, `Result.isErr` | `Result.mapError`, `Result.isError` | Rename. |

Names are now written in full words. `check` reports an old name as a missing member (`E0303`) without suggesting the new one; use this table to find it.

#### Command line and diagnostics

| `0.0.0` | `0.0.1` | How to migrate |
|---|---|---|
| `benitoite --version` printed one line | It prints `benitoite 0.0.1` and, on a second line, the Unicode version (`Unicode 17.0.0`) | Read only the first line when you need the version of `benitoite`. |
| In JSON diagnostics, `helps` was an array of strings | Each element of `helps` is an object with `message` and `edits` (replacements with `file`, `start`, `end`, and `replacement`) | Read the text of a help from its `message`. |
| `run` and `check` wrote nothing for a script without errors | `check`, `run`, and `test` also write warnings to standard error | Warnings do not change the exit status. Use `--deny-warnings` to treat them as errors. |
| A file name that is a command | `benitoite check` and the other command names, and the reserved names `server`, `mcp`, `sign`, `verify`, `repl`, `lsp`, `package`, and `agent`, are read as commands | Run such a file as `benitoite ./check`. |

### Unofficial modules

In `0.0.1`, the IO, network, and text and data modules (`IO.Console`, `IO.File`, `IO.Process`, `IO.Clock`, `IO.Random`, `Time`, `Path`, `Json`, `Csv`, `Regex`, `Encoding`, `Hash`, and `Network.Http`) are unofficial and are imported under `Benitoite.Unofficial`. When a later minor version moves one of them into the standard library, its import name changes from `Benitoite.Unofficial.<Name>` to `Benitoite.<Name>`. That move is an incompatible change and will be listed here: to migrate, change the `import` lines of the script. From `0.1.0`, unofficial modules do not change in patch versions.
