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

This reference describes Benitoite `0.0.7`, including the experimental features in [section 21](#21-experimental-packages-and-external-functions). It explains how to write and run Benitoite scripts, with examples. Every example marked as a program in this file is checked against `benitoite` by the test suite of the repository.

To install `benitoite`, see [Installing Benitoite](install.md).

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
21. [Experimental: packages and external functions](#21-experimental-packages-and-external-functions)

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

The first line imports the module `Console`. The signature of `main` says, after `uses`, that it writes to the console (`Console.Write`). A function that does something outside the program must list it this way, and so must every function that calls it. Reading the `uses` of `main` tells you the kinds of operations a script may perform; it does not tell you their targets or results.

## 2. The command line

```text
benitoite [options] <script> [script arguments...]
benitoite run   [options] <script> [script arguments...]
benitoite check [options] <script>
benitoite test  [options] <path>...
benitoite fmt   [options] <path>...
benitoite skill install|uninstall [--user | --project] [--agent <name>]...
benitoite skill list [--format=text|json]
benitoite skill show [--format=text|json] <logical-name>
benitoite package add|update|move ...
benitoite --help
benitoite --version
benitoite --version=json
benitoite --licenses
```

| Command | What it does |
|---|---|
| `run` | Checks the script and calls its `main`. Arguments after the script path are passed to the script (`Process.arguments()`), also when they start with `-`. |
| `check` | Checks the script without running it. |
| `test` | Runs the test functions in the given files, or in all `.bnt` files under the given directories, except `package.bnt` and nested packages. See [Tests](#16-tests). |
| `fmt` | Rewrites the given files, or all `.bnt` files under the given directories, in the standard layout. See [Formatting](#17-formatting). |
| `skill` | Installs or removes the bundled Agent Skill, or lists and retrieves its embedded documents without installing them. See [Installing Benitoite](install.md#3-install-the-agent-skill). |
| `package` | Experimental. Adds, updates, or moves local dependency declarations. See [The package commands](#the-package-commands). |
| `--help` | Prints the usage. |
| `--version` | Prints the version of `benitoite` on the first line (`benitoite 0.0.7`) and the Unicode version used by character functions on the second line (`Unicode 17.0.0`). |
| `--version=json` | Prints version, build, and supported-format information as one JSON object. It must be the first argument and accepts no following arguments. |
| `--licenses` | Prints the licenses of the third-party software in the executable. A build from source does not contain this list and says so. |

`<script>` is a file, or a directory that contains `main.bnt`. The file name and its extension are not checked, except that `package.bnt` is a settings file and cannot be the starting file. The directory of the script is the *root directory*: the script can import modules from the root directory and below it, from the standard library ([Modules](#12-modules)), and from declared local dependencies (see [section 21](#21-experimental-packages-and-external-functions)). `benitoite` reads `package.bnt` in the root directory itself as a settings file; it does not search parent directories or the working directory.

The script and its modules must be regular files. A path to a pipe, such as `/dev/stdin` connected to a pipe or `<(...)` in the shell, cannot be read and is reported as `E0101`; write such a script to a temporary file and pass that path.

`benitoite script.bnt` without a command means `benitoite run script.bnt`. A file whose name is a command (such as `check`) is run as `benitoite ./check`. The names `server`, `mcp`, `sign`, `verify`, `repl`, `lsp`, and `agent` are reserved for later versions; `benitoite server` is a usage error.

To run a script directly, make the file executable and put this line first:

```text
#!/usr/bin/env benitoite
```

On Linux, do not write `#!/usr/bin/env benitoite run`: Linux passes everything after the interpreter name as one argument. To pass options, use `env -S`, as in `#!/usr/bin/env -S benitoite --max-call-stack=2GiB`.

### Options

For `run` and `check`, options come after the command and before the script path (or before the script when `run` is omitted). For `test` and `fmt`, options may also follow paths. Unknown options, repeated options, missing or invalid values, and options that the command does not accept are usage errors with exit status 2. Value options in this table require `=`, except that `--allow-effects` also accepts a separate value.

| Option | Meaning | Default |
|---|---|---|
| `--diagnostics=text` or `--diagnostics=json` | Format of diagnostics and error reports. For `test`, also the format of the test results. | `text` |
| `--max-call-stack=<size>` | Limit for nested calls in `run` and `test` (for `test`, per test), written as an integer with `KiB`, `MiB`, or `GiB`, such as `512MiB`. | `1GiB` |
| `--deny-warnings` | Treat warnings as errors in `check`, `run`, and `test`. | off |
| `--report=json` | For `check` and `test --check`, write a single JSON inspection report to standard output. See [Inspection reports](#inspection-reports). | off |
| `--allow-effects=<names>` or `--allow-effects <names>` | For `run` and executing `test`, compare each entry function's declared effects against an allowed set before execution. See [Effect limits before execution](#effect-limits-before-execution). | no limit |
| `--check` | For `test`, check without running tests. For `fmt`, report the files that would change, without rewriting them. | off |

The four `--wasm-*` options for `run` and executing `test` are described under [Execution limits and statistics](#execution-limits-and-statistics).

### Exit status of `run` and `check`

| Status | Meaning |
|---:|---|
| 0 | `check` found no errors, or `main` returned `()` or `Result.Ok(())`. |
| 1 | `main` returned `Result.Error`, the program stopped with a runtime error or ran out of a resource, or a command-line argument is not valid UTF-8. |
| 2 | The script has check errors (or warnings with `--deny-warnings`), exceeds `--allow-effects` (`E0512`), cannot run because of a limit of `benitoite`, or cannot be read; or the command line is wrong. |
| 3 | An internal error of `benitoite`. Please report it. |
| 130 | `run` received `SIGINT` or `SIGTERM`. It cancelled all tasks, released resources, and flushed output before ending. |

A script that calls `Process.exit(n)` ends with `n` (0 to 255). Because 1, 2, and 3 can come from `Process.exit` too, a tool that runs scripts can tell them apart by whether standard error contains a report in the format of `benitoite`.

For `run` and `check` without `--report=json`, diagnostics, runtime errors, the message of `Result.Error` returned by `main`, and usage errors go to standard error. Standard output contains only what the script writes. If the reader of standard output or standard error goes away (a closed pipe), the program stops with a runtime error and exit status 1. Inspection reports instead contain their diagnostics in the single JSON object on standard output.

`benitoite` sets no limit on memory. To limit it, use the tool that starts `benitoite` (`ulimit`, a container, or the agent harness).

### Version and supported formats

Use `benitoite --version=json` to discover the formats that an executable supports. Check both the required key in `formats` and an integer version that your tool understands; do not infer capabilities from the release version alone. For example, a build with unknown commit and dirty state can return:

```json
{
  "schemaVersion": 1,
  "kind": "version",
  "name": "benitoite",
  "version": "0.0.7",
  "unicodeVersion": "17.0.0",
  "build": {
    "commit": null,
    "dirty": null,
    "target": "aarch64-apple-darwin",
    "provenance": {"commit": "unknown", "dirty": "notCollected"}
  },
  "formats": {
    "version": [1],
    "diagnostics": [1],
    "testResults": [1],
    "checkReport": [1],
    "testCheckReport": [1],
    "effectLimit": [1],
    "loaderEnvironment": [1],
    "skillList": [1],
    "skillDocument": [1]
  },
  "loaderEnvironment": {
    "schemaVersion": 1,
    "mode": "always",
    "deniedPrefixes": ["DYLD_", "LD_"],
    "nameComparison": "asciiCaseInsensitive",
    "inherited": "unchanged",
    "errorKind": "InvalidInput"
  }
}
```

`build.commit` is a full lowercase hexadecimal Git object ID or `null`. `build.dirty` is a boolean or `null`; `null` means unknown, not a clean tree. Dirty state is not collected automatically: an unspecified build input gives `provenance.dirty: "notCollected"`. An explicit build input, including an explicit unknown value, gives `"environment"`. Commit provenance is `"environment"`, `"git"`, or `"unknown"`. These are values embedded at build time, not observations of the runtime environment. See [Build information](install.md#build-information) for inputs, monitoring limits, and when to rebuild.

`diagnostics: [1]` and `testResults: [1]` refer to the existing JSON Lines formats, including `kind: "die"`, `code: null`, and test `failure.die`. Those lines have no added `schemaVersion` or initial version record. `checkReport` and `testCheckReport` describe the single-object reports below. `effectLimit` versions the option syntax, set comparison, and `E0512` contract; it is not an output object. `loaderEnvironment` describes the [explicit environment restriction](#io-and-network-behavior). `skillList` and `skillDocument` describe [embedded Skill queries](install.md#read-the-skill-without-installing-it).

Removing fields or changing their types, required presence, or meaning changes the corresponding format version, as does adding a classification that requires a new interpretation of success. An optional field that can be ignored without changing the meaning may be added within the same format version. Treat unknown formats, statuses, and effect names as unsupported, not as success or an empty effect set.

### Inspection reports

These commands check scripts without executing user functions:

```sh
benitoite check --report=json main.bnt
benitoite test --check --report=json tests/
```

`check` requires `main`; `test --check` uses the same file and test selection as executing `test` and requires no `main`. Neither mode generates Benitoite bytecode or runs a VM. Existing compile-time constant evaluation and static checking of external declarations still take place. An external WASM component may be compiled for that static check, without being instantiated or called. A successful inspection does not guarantee that later code generation will fit the compiler's limits.

`--report=json` accepts only this spelling, without a separate value. It can be combined with `--diagnostics=json`; diagnostics then appear only inside the report. Explicit `--diagnostics=text` is a usage error, while leaving diagnostics unspecified is allowed. `test --report=json` without `--check` is a usage error and runs no tests. `test --check` rejects `--max-call-stack`, every `--wasm-*` option, and `--allow-effects`, even when the given value equals the default. `run` and `fmt` do not accept reports.

After a valid report option has been recognized within the command's option range, recognizable usage errors are also returned in a report, regardless of whether the error precedes the option. For `check`, that range ends at the script path; for `test`, it includes options before and after paths. A known option's separate value is consumed while scanning, even when that spelling is invalid, so a value that happens to be `--report=json` does not enable reports. Without a recognized report option, usage errors remain text on standard error.

Each report is one UTF-8 JSON object followed by LF on standard output. It includes warnings, check errors, usage errors, and caught internal errors, without repeating them on standard error. It writes no test result or summary lines. Object key order and JSON whitespace are not part of the contract.

| Common field | Meaning |
|---|---|
| `schemaVersion`, `kind` | Integer `1`; `"checkReport"` or `"testCheckReport"`. |
| `producer` | `{name, version, build}`, with the same version and build information as the version query. |
| `status` | `"ok"`, `"checkError"`, `"usageError"`, or `"internalError"`; test inspection can also return `"interrupted"`. |
| `complete` | True only when selection, every target's check, and contract extraction have succeeded. |
| `targetsComplete` | Whether entry selection or directory discovery finished; independent of type-checking success. |
| `executed` | Always `false`. |
| `requestedTargets` | `[{requestIndex, path}]`, in argument order, with zero-based indices and the supplied paths, including invalid ones. |
| `targets` | Entries in discovery order: explicit argument order, and lexical file order within each directory. |
| `sources` | `[{sourceId, displayPath, kind, contentHash}]`, in target order and then source-file ID order. `kind` is `"user"` or `"prelude"`; the latter includes all embedded standard-library sources. |
| `sourceSets` | `[{targetId, sourceIds}]`, one row per target, including an empty source-ID array for an uninspected target. |
| `aggregateEffects` | An Effects object for `main`, or the union of all selected tests' effects, only when the whole report is complete; otherwise `null`. |
| `diagnostics` | An array of the diagnostic objects described in [Diagnostics](#18-diagnostics). |
| `diagnosticTargets` | One `{diagnosticIndex, targetId}` per diagnostic. Discovery-wide and usage errors have `targetId: null`. |

Every target has `targetId`, `requestIndex`, `entry`, `root`, `sourceId`, `kind`, `status`, and `complete`. `entry` and `root` are display paths; `sourceId` is `null` if the entry's bytes were not retained. Main targets have `kind: "main"` and a `main` field. Test targets have `kind: "tests"` and a `tests` field, without `main`.

A successful `main` is `{symbol: "main", location, effects, processShellReference, shellReferenceScope}`. Each item in `tests` is `{function, description, location, effects}` in declaration order. An omitted test description is `null`; an explicitly empty description is `""`. `location` identifies the function name, using `{file, start, end, label: ""}`; start and end contain one-based `line` and `column` and a zero-based byte `offset` in the original source.

An Effects object is `{basis: "declaredUpperBound", expanded: [...]}`. Its array contains unique atomic built-in names in lexical order. It reports the declared upper bound, including effects that the body does not use. `IO.All` expands to `Clock.Time`, `Console.Read`, `Console.Write`, `File.Read`, `File.Write`, `Process.Environment`, `Process.Exit`, `Process.Run`, `Random.Generate`, and `State`; it includes neither HTTP effect nor `Assert.Check`. Tests retain `Assert.Check` in each contract, the aggregate, and later effect-limit comparisons. Declaring `Assert.Check` on `main` is a check error (`E0415`). An unhandled `or die` needs `Process.Exit`; fully handling it and removing it from the declared bound removes it from the report. A bare `try` or `or return` adds no exit effect.

Pure success has `expanded: []`. Unknown effects are represented by a `null` Effects value, never an empty array. If a target's check fails, its `main` or `tests` is `null`. A checked file with no tests has `tests: []`. An empty directory is a complete success with `targets: []` and an empty aggregate effect set. A failure in one file leaves successful targets' contracts available, but makes the overall `complete` false and `aggregateEffects` null. Discovery failure stops before checking any entries; previously discovered targets remain incomplete reference information with `status: "checkError"` and `tests: null`. Internal errors and observed interruptions can leave later entries uninspected.

`processShellReference` is `"present"` or `"absent"` for a successful check, and `"unknown"` for an unconfirmed test target. It is inside `main` for a main target and directly on a test target, alongside `shellReferenceScope: "checkedProgram"`. A `null` main also leaves shell references unconfirmed. The check covers expression references to the standard `IO.Process.shell` throughout the checked program, including dependencies, standard sources, function values, and functions that are never called. It does not analyze reachability from `main` or a test. An import alone, a handler operation name alone, comments, strings, and user functions of the same name do not count. `"present"` does not mean a shell will run; `"absent"` does not mean arbitrary commands cannot start one.

`contentHash` is `{algorithm: "sha256", value: "<64 lowercase hexadecimal digits>"}` over the same complete source bytes used by the check, with no normalization of BOM, line endings, or invalid UTF-8. It covers sources read into the source table, including settings, dependencies, and prelude sources. It excludes WASM binaries, files read only to verify dependency hashes, missing settings files, and directory observations. Sources whose complete bytes were not retained have no `sources` item. Display paths are neither reversible OS-path encodings nor instructions to open files.

IDs such as `t0` and `t0:s0` are local to a report. Repeated explicit paths create separate targets and source sets; equal display names or hashes are not merged. A report does not fix the source bytes for a later run, and its hashes are not an attestation of executable trust.

Usage errors have `complete: false`, `targetsComplete: false`, empty `targets`, `sources`, and `sourceSets`, and `aggregateEffects: null`. Their diagnostic uses `kind: "check"`, `severity: "error"`, `code: null`, `primary: null`, and empty `secondary`, `notes`, and `helps`. This combination of `kind: "check"` and `code: null` exists only inside a report with `status: "usageError"`; it is not added to ordinary diagnostic JSON Lines. For example, `benitoite check --report=json` returns status 2 with `requestedTargets: []` and the message `"missing script path"`.

| Report status | Exit status |
|---|---:|
| `ok` | 0 |
| `checkError` or `usageError` | 2 |
| `internalError` | 3 |
| `interrupted` (test inspection only) | 130 |

Check for a complete single JSON object, an understood `schemaVersion` and `kind`, `status: "ok"`, `complete: true`, and exit status 0 before using the aggregate as a confirmed set. A warning promoted by `--deny-warnings` makes the report a `checkError`. For multiple test-inspection failures, precedence is interrupted, internal error, usage error, then check error.

Report assembly and serialization finish before output starts. A write or flush failure takes precedence and exits with 1, without appending or resending another report. OS writes are not guaranteed to be indivisible. Initialization failures, failures outside the report boundary, a failure while building the failure report itself, aborts, forced termination, and broken output do not guarantee a complete report. Test inspection observes interruption before starting each file, not continuously during checking; a request during the last file may go unreported. Main inspection leaves signals to the OS default behavior.

### Effect limits before execution

After inspecting and reviewing a script, an agent or harness can pass the accepted atomic names to an executing command:

```sh
benitoite run --allow-effects=Console.Write,Process.Exit main.bnt
benitoite test --allow-effects=Assert.Check,File.Read tests/
benitoite --allow-effects= pure.bnt
```

The last command allows the empty set. The option accepts one comma-separated set in any order, using the 13 atomic names in [Effects](#10-effects), with `State` and `Assert.Check` included. It rejects duplicate names, empty elements, whitespace anywhere, unknown or user-defined names, import aliases, `IO.All`, and `*`; it does not trim the value. The option may occur once. It is not accepted by `check`, `test --check`, or `fmt`. After a `run` script path it is a script argument.

The newly checked declared upper bound must be a subset of the supplied set; extra allowed names are accepted. A missing effect produces one `E0512` per offending function, with its location, the missing effects, and the allowed set, and exits with 2 before execution. With `--diagnostics=json`, these are ordinary diagnostic lines on standard error, without an approval object on standard output. Earlier type or effect errors take precedence over comparing an unknown contract.

`run` compiles the same checked program whose contract was compared. With an effect limit, `test` prepares every entry, compares every selected test's contract (including `Assert.Check`), and finishes compilation and execution preparation for all entries before any test starts. If any entry fails preparation, none run. See [Tests](#16-tests) for the resulting summary. Without the option, executing tests retain their usual per-file preparation and execution.

This is a static contract comparison. It neither fixes the source after inspection nor restricts operations at runtime. Changes that keep `File.Write` but alter its path or contents, or keep `Process.Run` but change the command, still fit the same set. Different test entries may also observe different dependency contents if files change between preparations; there is no single snapshot of all inputs. Use the harness or OS sandbox to restrict actual operations and resources.

## 3. Program structure

A program starts at the function `main` in the script file. `main` takes no parameters and returns `Unit` or `Result[Unit, String]`. When it returns `Result.Error(message)`, the message is written to standard error and the exit status is 1.

The top level of a file contains, in this order, `import` declarations and then declarations: functions, constants, data types, type aliases, records, type classes, implementations, and effects. Code that runs is written only inside functions.

Except for a short lambda (see [Functions and lambdas](#6-functions-and-lambdas)), blocks are closed with `end` and the keyword that opened them: `end function`, `end if`, `end match`, `end lambda`, `end data`, `end record`, `end trait`, `end implement`, `end effect`, `end handle`, `end with`, `end lazy`. There are no braces, and indentation has no meaning. Statements are separated by line breaks; there are no semicolons. A physical line break immediately after `return` always ends the statement, even inside parentheses or before a continuation operator on the next line. Comments and blank lines do not change this rule.

Inside a block:

- `bind name <- expression` gives a name to a value. Names cannot be reassigned.
- `shadow name <- expression` binds a name that hides a local name already visible. `bind` with a name that is already visible as a local name is an error, so hiding is always explicit. `shadow` is valid but discouraged; prefer a new name that describes the new value, even when hiding the old name is intentional. This is documentation advice and does not add a warning.
- `return expression` ends the function and returns the value. Start the value on the same physical line as `return`; a missing value is an error (E0201). Once the value has started, ordinary continuation rules allow multiple lines, such as after an operator in `return x +`, inside `return (` or the arguments of `return f(`, or after `then` in `return if condition then`. A short lambda must still fit entirely on one physical line.
- An expression on its own line is a statement. When it is not the last statement of its block, or when it is the last statement of a function or lambda body, its value must be `Unit`; write `bind _ <- expression` to discard any other value.

A function whose return type is not `Unit` must end with `return` (or with an `if` or `match` whose every branch returns). The value of an `if`, of a `match` branch, of a handler clause, and of the bodies of `with`, `handle`, and `lazy` is its last expression. A `return` inside an `if`, a `match` branch, a handler clause, or the body of `with` or `handle` returns from the function that contains it. A `lazy` body and a `match` guard cannot contain `return` or `try`, except inside a `lambda ... end lambda` written there; the arguments of a call with `_` placeholders are not such an exception.

`//` starts a comment that runs to the end of the line. `///` before a declaration documents it, and `//!` at the start of a file documents the module. Identifiers use ASCII letters, digits, and `_`. Names of functions, values, and parameters start with a lowercase letter; names of types, constructors, modules, and effects start with an uppercase letter.

`die` is reserved and cannot be used as a name, including an argument label, field, import alias, or name after a dot; it is accepted only in `try e or die` and `try e or die(message)`, never as a standalone expression.

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
  bind increased <- total + larger(a: 3, b: 7)
  bind label <- match increased > 15 with
    case true -> "big"
    case false -> "small"
  end match
  Console.writeLine("${label}: ${increased}")
end function
```

```output
big: 17
```

There are no loop statements, no `null`, and no exceptions. Use recursion or list functions instead of loops, `Option` instead of `null`, and `Result` with `try` instead of exceptions.

Prefer `match` for selecting a value or action. Use `if` without `else` for a conditional action or an early return, as in `larger` above. `else` and `else if` are valid but discouraged; the checker adds no warning for them. When rewriting a selection, preserve the number and order of condition evaluations, evaluate only the selected branch, and keep `return` in the same function or lambda. Conditions with effects cannot be match guards; nest matches on their boolean results instead.

This example evaluates the second condition only when the first is false. Each `return` ends `choose`, and only the selected result is returned.

```benitoite
import Benitoite.Unofficial.IO.Console

function condition(label: String, value: Boolean) -> Boolean uses Console.Write
  Console.writeLine(label)
  return value
end function

function choose(first: Boolean, second: Boolean) -> String uses Console.Write
  match condition(label: "first", value: first) with
    case true -> return "first selected"
    case false ->
      match condition(label: "second", value: second) with
        case true -> return "second selected"
        case false -> return "neither selected"
      end match
  end match
end function

function main() -> Unit uses Console.Write
  Console.writeLine(choose(first: true, second: true))
  Console.writeLine(choose(first: false, second: true))
  Console.writeLine(choose(first: false, second: false))
end function
```

```output
first
first selected
first
second
second selected
first
second
neither selected
```

## 4. Basic types and literals

| Type | Values | Literals |
|---|---|---|
| `Integer` | Signed 64-bit integers | `42`, `-7`, `1_000_000`, `0xff`, `0o755`, `0b1010` |
| `Float` | IEEE 754 binary64 | `3.14`, `1e10`, `1.2e-3` |
| `Decimal` | 128-bit decimal fractions, for money and other exact decimal values | `12m`, `1.25m`, `1_000.50m` |
| `Byte` | Integers from 0 to 255; no arithmetic | `255u8`, or `Byte.fromInteger` |
| `Integer8`, `Integer16`, `Integer32` | Signed 8-, 16-, and 32-bit integers | `-128s8`, `42s16`, `0xffs32` |
| `UnsignedInteger16`, `UnsignedInteger32`, `UnsignedInteger64` | Unsigned 16-, 32-, and 64-bit integers | `42u16`, `0xffffu32`, `18446744073709551615u64` |
| `Float32` | IEEE 754 binary32 | `1.5f32`, `1e-3f32` |
| `Character` | One Unicode scalar value | `'a'`, `'あ'`, `'\n'` |
| `String` | Immutable sequences of Unicode scalar values | `"text"`, `"""…"""`, `r"…"` |
| `Boolean` | `true` and `false` | `true`, `false` |
| `Unit` | Only `()` | `()` |

There are no implicit conversions. Use conversion functions such as `Integer.toFloat`, `Integer.toString`, `Decimal.fromInteger`, and `Integer.parse` (which returns `Option[Integer]`).

Every integer type with arithmetic stops with a runtime error on overflow or `div`/`mod` by zero. Unsigned subtraction below zero also overflows. The signed minimum `div -1` overflows, while the signed minimum `mod -1` is zero. `Byte` has comparisons, bit operations, and conversions, but no arithmetic. `Float` and `Float32` division follow IEEE 754: dividing by zero gives an infinity or NaN. A floating-point literal needs digits on both sides of the point (`1.0`, not `1.` or `.5`).

### Numeric type names and suffixes

Width-qualified names are the canonical names. The aliases `Integer`, `Float`, and `Byte` are the main names in this reference, diagnostics, and displayed signatures. The names in each row below denote one type; switching between them requires no conversion. All these types and their standard modules are in the prelude.

| Canonical name | Alias | Default display | Integer range or floating-point format |
|---|---|---|---|
| `Integer8` | — | `Integer8` | −128 through 127 |
| `Integer16` | — | `Integer16` | −32768 through 32767 |
| `Integer32` | — | `Integer32` | −2^31 through 2^31−1 |
| `Integer64` | `Integer` | `Integer` | −2^63 through 2^63−1 |
| `UnsignedInteger8` | `Byte` | `Byte` | 0 through 255; no arithmetic |
| `UnsignedInteger16` | — | `UnsignedInteger16` | 0 through 65535 |
| `UnsignedInteger32` | — | `UnsignedInteger32` | 0 through 2^32−1 |
| `UnsignedInteger64` | `UnsignedInteger` | `UnsignedInteger64` | 0 through 2^64−1 |
| `Float32` | — | `Float32` | binary32 |
| `Float64` | `Float` | `Float` | binary64 |

`Integer8`, `Integer16`, `Integer32`, `UnsignedInteger16`, `UnsignedInteger32`, `UnsignedInteger64`, and `Float32` are seven distinct types. A literal without a suffix has a fixed type: `1` is always `Integer`, and `1.0` is always `Float`, even when the surrounding code expects another width. Binary arithmetic, equality, and comparisons require the same type on both sides after expanding aliases. Use `1s32 + 2s32` for `Integer32` arithmetic, or an explicit conversion for a computed value.

The integer suffixes are lowercase `s8`, `s16`, `s32`, `s64`, `u8`, `u16`, `u32`, and `u64`; the floating-point suffixes are `f32` and `f64`. **This suffix syntax is provisional and may change when the language syntax is revised.** The ordinary compatibility policy still applies. `1s64` is an `Integer`, `1.0f64` is a `Float`, and `255u8` is a `Byte`. Integer suffixes retain hexadecimal, octal, binary, and underscores between digits: `0xffu8`, `0o177s8`, `0b1010u16`, `1_000s32`. A floating-point suffix needs a decimal point or exponent: use `1.0f32`, not `1f32`. In hexadecimal, `0xfff32` remains an unsuffixed integer because `f32` consists of hexadecimal digits. Decimal's `m` suffix cannot be combined with another suffix.

Out-of-range literals are static errors. A minus sign directly on a signed literal includes the sign in range checking, so `-128s8` is valid; `-(128s8)` contains an out-of-range positive literal. Unary minus is forbidden for unsigned types, including `-0u16` and `-1u8`. `Integer8`, `Integer16`, `Integer32`, the unsigned integer types, `Byte`, and `Float32` do not support constant or range patterns; bind the value and compare in a guard instead. Constant overflow and division by zero are errors in `const` expressions and warnings in ordinary expressions.

`Float32` rounds at value creation and after each arithmetic operation to binary32, using nearest rounding with ties to even. Operations are not combined into a fused multiply-add. Infinity, NaN, signed zero, and comparisons follow `Float`; NaN payload bits are not preserved as a contract. `toString`, interpolation, and `Trait.Show` use decimal integers and the shortest decimal representation that reads back to the same floating-point width, without a suffix. All integer types support equality, `ordered`, and map/set keys; `Float32` supports equality and `ordered`, but cannot be a key. `Trait.Show` and `Trait.Order` have standard implementations for all seven types; `Trait.Order` treats all NaNs as equal and greater than other values, and treats positive and negative zero as equal.

### Numeric conversions and standard functions

Conversion functions return `Option` when the value can be outside the destination's range. Arithmetic overflow stops execution; it does not return `Option.None`. There are no direct conversions between every pair of widths: use `Integer` as the intermediate type, and `Decimal` for the full unsigned 64-bit range.

| Module(s) | Functions | Contract |
|---|---|---|
| `Integer8`, `Integer16`, `Integer32`, `UnsignedInteger16`, `UnsignedInteger32` | `fromInteger`, `toInteger` | `fromInteger` returns `Option[T]`; `toInteger` is exact and returns `Integer` |
| `UnsignedInteger64` | `fromInteger`, `toInteger` | Both return `Option`; negative input or a result above `Integer`'s maximum gives `None` |
| `UnsignedInteger64` | `fromDecimal`, `toDecimal` | Exact over the full range; `fromDecimal` accepts only integral values in range (including `1.0m`) and returns `Option` |
| Signed 8/16/32-bit and unsigned 16/32/64-bit integer modules | `parse`, `toString`, `toFloat` | Decimal parsing returns `Option` and rejects whitespace, base prefixes, underscores, out-of-range values, and negative unsigned values; `toFloat` rounds to binary64 |
| Signed 8/16/32-bit and unsigned 16/32/64-bit integer modules | `absolute`, `minimum`, `maximum`, `floorDivide`, `floorModulo` | Same-width results; signed minimum `absolute` overflows; unsigned `absolute` is the identity |
| Signed 8/16/32-bit and unsigned 16/32/64-bit integer modules | `bitwiseAnd`, `bitwiseOr`, `bitwiseExclusiveOr`, `bitwiseNot`, `shiftLeft`, `shiftRight` | Shift counts are `Integer` in 0 through width−1; left shifts discard bits beyond the width; signed right shifts extend the sign, unsigned right shifts fill with zero |
| `Integer8`, `Integer16`, `Integer32` | `shiftRightUnsigned` | Right shift with zero fill |
| `Float32` | `fromFloat`, `toFloat` | `fromFloat` returns `Option`, rounds to binary32, and rejects finite values that become infinite; infinite and NaN inputs give `Some`; `toFloat` widens finite values exactly |
| `Float32` | `parse`, `toString`, `truncate` | Parse directly to binary32 using `Float`'s decimal spelling, returning `Some` only for finite values; `truncate` returns `Option[Integer]`, rounding toward zero and rejecting NaN, infinity, and out-of-range values |
| `Float32` | `absolute`, `floor`, `ceiling`, `round`, `squareRoot`, `isNaN`, `isInfinite` | Same behavior as `Float` at binary32 precision; `round` takes halfway values away from zero; negative square roots give NaN |

For `Float32` to a narrow integer, combine `truncate` and `fromInteger`. There is no direct `Float` conversion to the upper half of `UnsignedInteger64`; use a literal, `parse`, or an exact `Decimal`. `Decimal.fromFloat` uses decimal formatting and is not an exact binary-integer conversion.

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write
  bind small <- Option.unwrapOr(o: Integer8.fromInteger(42), fallback: 0s8)
  bind maximum <- 18446744073709551615u64
  bind narrowed <- Option.unwrapOr(o: Float32.fromFloat(0.1), fallback: 0.0f32)
  bind same: Integer64 <- Integer8.toInteger(small)
  Console.writeLine("${small + 1s8} ${same} ${Integer8.fromInteger(128) = Option.None}")
  Console.writeLine("${UnsignedInteger64.toInteger(maximum) = Option.None} ${UnsignedInteger64.toDecimal(maximum)}")
  Console.writeLine("${narrowed} ${Float32.toFloat(narrowed) = 0.1}")
end function
```

```output
43 42 true
true 18446744073709551615
0.1 false
```

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
  Console.writeLine(Decimal.toString(Decimal.round(x: 2.675m, places: 2, mode: RoundingMode.HalfToEven)))
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
| `|>` | Pipe: supply the first parameter, as in `xs |> List.map(f: action)` | Left |
| `or` | Logical or (short-circuit) | Left |
| `and` | Logical and (short-circuit) | Left |
| `=` `<>` `<` `<=` `>` `>=` | Comparison | None (`a < b < c` is an error) |
| `+` `-` | Addition, subtraction; `+` also joins strings | Left |
| `*` `/` `div` `mod` | Multiplication; `/` for `Float`, `Float32`, and `Decimal`; `div` and `mod` for integer types with arithmetic | Left |
| `-` `not` | Negation | Prefix |
| `f(...)` | Call | Postfix |

`==`, `!=`, `&&`, `||`, `!`, and `%` do not exist. `div` rounds toward zero and the sign of `mod` follows the dividend: `-7 div 2` is `-3` and `-7 mod 2` is `-1`. For rounding down, use `Integer.floorDivide` and `Integer.floorModulo`. Integer types have no `/`; use a floating-point or decimal conversion for a fractional result.

`=` and `<>` compare values of *equality types*: types that contain no function type and no opaque type (`IOError`, `NetworkError`, `Reference`, `Lazy`, `Task`, resources, external types, `Regex.Pattern`, and others). Lists, maps, sets, options, results, records, and data types are compared by their contents. `<`, `<=`, `>`, and `>=` work only on all the numeric types, `Character`, and `String`. `Float` and `Float32` comparison follow IEEE 754: NaN is not equal to anything, even to itself, so use the corresponding `isNaN` function to detect it.

Operands are evaluated from left to right.

## 6. Functions and lambdas

A function declares the types of its parameters and its return type after `->`. A function without `uses` is pure.

```text
function name(a: Type, b: Type) -> ReturnType uses Effect1, Effect2
  ...
end function
```

Calls are not curried: give every argument. For an ordinary function with two or more parameters, write every argument with its parameter name: `between(low: 2, value: 3, high: 4)`. A one-parameter function can be called with or without its name, and a zero-parameter function uses `f()`. Do not mix named and positional arguments. Named arguments can be written in any order, but each parameter must be supplied exactly once. A label names a parameter, not a local variable: `value: input` passes the local value `input` to the parameter `value`. The callee is evaluated first, then the argument expressions once each in source order, even when labels are written in a different order from the declaration.

These calling rules apply to declared functions, built-ins, function values, lambdas, type-class methods, effect operations, and external functions. Direct data construction and data patterns use positional fields, such as `Pair(1, "one")`; records use named fields (see [Data types and records](#7-data-types-records-and-pattern-matching)). Attributes, handler-clause bindings, and `resume(value)` have their own syntax.

A *lambda* is a function value; its parameter and return types may be left out. Like a function, a lambda returns its value with `return`; a lambda that returns `Unit` can end with a statement instead.

Prefer a short lambda for a one-statement body. Explicit terminators are valid, and the formatter preserves the chosen form. A lambda containing one statement can omit `end lambda` when its entire header and body fit on one physical line, for example `lambda(x) return x + 1`. When the body starts on the last line of the header, only an `end lambda` on that same physical line closes it. An `end lambda` on a later line can close an outer lambda; blank lines do not change that correspondence. To write a multiline lambda, start its body on the line after the header and close it with `end lambda`.

A short lambda needs `return` to return a non-`Unit` value. The pipe in `lambda(x) return x + 1 |> increment` belongs to its body; write `(lambda(x) return x + 1)(3)` to call the lambda itself. If either lambda in a directly nested pair omits its terminator, put parentheses around the entire inner lambda: `lambda(x) return (lambda(y) return x + y)`. A call argument or a binding statement provides an independent boundary. Before adding a second statement to a short body, move the body to the line after the header and add `end lambda`.

### Function contracts and callbacks

Write a function type with a name for each parameter: `function(value: Integer) -> Integer`, or `function(acc: Integer, value: Integer) -> Integer`. Names in a type do not bind local values. Parameter names and their order are part of the contract, together with types and effects. They must match at every position, even for a one-parameter callback; the checker does not rename a lambda to fit an expected type. Calling a function with labels in a different order does not change its contract order.

`List.map` expects `function(value: T) -> U`, so write `List.map(xs: xs, f: lambda(value) return value * 2)`. See [The standard library](#19-the-standard-library) for common callback contracts and the complete declarations. Keep the expected name even when the parameter is unused; do not replace it with `_unused`. To use a descriptive local name, add a `bind` in a multiline body.

To pass a function with a different contract, wrap it in a lambda with the required names. For example, `Integer.toString` takes `n`, so pass `lambda(value) return Integer.toString(value)` to `List.map`. Constructor function values and record accessors also have named contracts, described in [Data types and records](#7-data-types-records-and-pattern-matching).

A call through an unannotated function parameter does not determine contract order from its labels. If constraints in the same function body do not establish the contract, add a type annotation, for example `g: function(a: Integer, b: Integer) -> Integer`. Otherwise the checker reports `E0455`, also for an unused lambda or a call with one positional argument. A caller cannot later supply the missing contract of an already checked function.

### Holes and pipes

`_` as a direct argument of a call makes a function of the missing argument: `Integer.maximum(a: _, b: 0)` has type `function(a: Integer) -> Integer`. Each hole inherits the name of its target parameter, and multiple holes are ordered as written: `between(high: _, value: 3, low: _)` takes `high, low`, not `low, high`. A direct positional constructor hole inherits its original position name: `Pair(_, "one")` takes `arg1`. The callee and fixed argument expressions are evaluated when the generated function is called, not when it is created. `return` and `try` inside those expressions target the generated function; `resume` cannot cross that boundary.

Without direct holes, a call on the right of a pipe receives the left value as its first declared parameter: `xs |> List.map(f: action)`. Label every remaining explicit argument when the function has two or more parameters. Explicitly supplying the first parameter again is a duplicate; the pipe does not search for some other free parameter. Evaluation is the left side once, then the right callee, then explicit arguments in source order.

With direct holes, as in `xs |> List.map(xs: _, f: action)`, the pipe instead calls the generated function with one argument. A parenthesized right side also receives a single argument as a function value. Two holes require two arguments; a pipe does not automatically partially apply that function again.

### Type and effect parameters

Type parameters are written in brackets after the name: `function first[T](xs: List[T]) -> Option[T]`. Type arguments also use brackets: `List[Integer]`, `Map[String, Integer]`. An *effect variable* is a type parameter that stands for a set of effects; it lets a function take a function argument with any effects and pass them on.

```benitoite
import Benitoite.Unofficial.IO.Console

function between(low: Integer, value: Integer, high: Integer) -> Boolean
  return low <= value and value <= high
end function

function twice[T, effect E](x: T, f: function(value: T) -> T uses E) -> T uses E
  return f(f(x))
end function

function main() -> Unit uses Console.Write
  bind text <- [1, 2, 3, 4, 5]
    |> List.filter(p: between(low: 2, value: _, high: 4))
    |> List.map(f: lambda(value) return Integer.toString(value))
    |> String.join(separator: ",")
  Console.writeLine(text)
  Console.writeLine(Integer.toString(twice(x: 5, f: lambda(value) return value * 3)))
  bind shout <- lambda(value: String) -> String
    Console.writeLine("shouting ${value}")
    return String.toUppercase(value)
  end lambda
  Console.writeLine(twice(x: "hi", f: shout))
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

A data type lists its constructors, one per line. Constructors are written with the type name, in expressions and in patterns: `Shape.Circle(1.0)`, `Option.Some(x)`, `Result.Error(e)`. A type whose only constructor has the same name as the type, such as `Pair` and `Triple`, is written without the type name: `Pair(1, "one")`.

A constructor with fields can also be used as a function value. Its parameters are `arg1`, `arg2`, and so on, in field order: after `bind make <- Pair`, call `make(arg1: 1, arg2: "one")`. A direct constructor call such as `Pair(1, "one")` uses positional fields; labels in that direct call report `E0456`.

### Records

A record has named fields. Build one with named arguments, read a field with `Type.field(value)`, and make a copy with some fields changed with `Type(..value, field: newValue)`. `value.field` is not valid.

A record accessor such as `Item.price` has the parameter name `value`. A record constructor used as a function value takes the field names in declaration order. These names must match any expected callback contract, as described in [Function contracts and callbacks](#function-contracts-and-callbacks).

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

For a final catch-all branch, prefer an ordinary name such as `case other ->` or `case otherCode ->`. These names bind the matched value and are not keywords. Choose a name that does not collide with an outer local name or a visible constant; put no unreachable branch after an unguarded catch-all. `case _ ->` is valid and produces no warning. This recommendation does not apply to `_` inside a constructor pattern, in a discarded binding, or as a partial-application placeholder.

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
    case otherScore -> "C"
  end match
end function

function main() -> Unit uses Console.Write
  List.forEach(xs: [Shape.Circle(1.0), Shape.Rectangle(2.0, 3.5)], f: lambda(value)
    Console.writeLine(Float.toString(area(value)))
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

### Extensible types

Put the argument-free attribute `@extensible` before a `data` or `record` declaration, before `public` or `public(package)` if present. It can also be used on private declarations and alongside `@deprecated`. `@extensible()` is accepted as the same attribute; the formatter keeps the parentheses. Arguments report `E0817` (or `E0220` for non-string arguments), duplicates report `E0803`, and use on another kind of declaration reports `E0802`. Attributes before individual constructors are not allowed (`E0201`).

Inside the defining package, patterns covering every declared constructor can be exhaustive. Outside it, a source `match` must also cover future shapes with an unguarded variable or `_` pattern. A constructor named `Other` is a known constructor and does not cover future shapes. Guards do not count toward exhaustiveness. This rule also applies inside `Result`, `Option`, lists, and record fields, and through type aliases. After all known constructors, a branch for future shapes remains valid; a branch after an unguarded `_` is still unreachable.

The package boundary is the same as for `public(package)`: the starting script and its root modules form one package, the standard library and prelude form another, and each dependency's internal modules belong to that dependency. Importing a type into another module of the same package does not make the use external.

The standard library marks four failure types as extensible: `IOErrorKind`, `NetworkErrorKind`, `Json.ParseError`, and `Csv.ParseError`. `Result` and `Option` themselves remain closed: `Result.Ok(value)` and `Result.Error(error)` cover both cases when their contents are bound as variables. `String` error values keep the ordinary string-pattern rules; the opaque `IOError` and `NetworkError` have no constructors to match.

For an extensible record, `ParseError(message: text, ..)` covers only the known record shape; `..` omits current fields. Outside its package, add a variable or `_` branch to `match`. A destructuring `bind` or `shadow` must always match, so using just that record pattern reports `E0607`; use a getter or a `match` with a branch for future shapes. Construction, updates, and getters keep their declared field contracts. The attribute does not guarantee compatibility when record fields are added or changed.

This example handles a known JSON error shape and keeps a branch for future shapes. It also constructs and updates the record using its existing API:

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.Json

function describe(result: Result[Json.Value, Json.ParseError]) -> String
  return match result with
    case Result.Ok(_) -> "parsed"
    case Result.Error(Json.ParseError(message: text, ..)) -> text
    case Result.Error(otherError) -> "another JSON error"
  end match
end function

function main() -> Unit uses Console.Write
  bind original <- Json.ParseError(line: 1, column: 2, message: "expected a value")
  bind revised <- Json.ParseError(..original, message: "invalid input")
  Console.writeLine(describe(Result.Error(original)))
  Console.writeLine(Json.ParseError.message(revised))
end function
```

```output
expected a value
invalid input
```

Missing future shapes report `E0601` for `match`, or `E0607` for a binding pattern, with the type declaration as a secondary location. The counterexample is shown as `<future constructor of TypeName>` or `<future shape of TypeName>` for a record. These are diagnostic descriptions, not constructor names you can write in source. `E0601` suggests an unguarded variable or `_`; `E0607` suggests rewriting the binding as a `match` with an unguarded `case _ ->` branch.

Adding `@extensible` to a closed type can reject external matches and destructuring bindings that were previously accepted. Adding constructors to an extensible data type preserves the exhaustiveness of external source patterns; it does not guarantee the same results, including when values formerly classified as `Other` receive a new constructor. Removing or renaming constructors, or changing their fields, is outside that guarantee. Removing the attribute commits to a closed constructor set and can make a branch for future shapes unreachable. The attribute does not let callers add constructors. Runtime constructor tags, ABI, equality, and key constraints keep their existing rules. [WIT structural matching](#external-functions-and-types-through-wasm) is a separate contract and still requires an exact match.

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
  return Option.unwrapOr(o: Map.get(m: statusNames, k: id), fallback: "unknown")
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

`try e` and `try e or return` evaluate `e` once. If it is `Result.Error` (or `Option.None`), the innermost function or lambda returns that failure at once; otherwise the expression gives the value inside. These returning forms require the enclosing return type to be `Result` with the same error type, or `Option`, respectively. Bare `try e` is permanently fixed to this returning meaning; it never switches to an exit based on the return type or its position. It adds no Show constraint or exit effect. `try` applies to the whole expression on its right, including pipes, up to an action at the same depth. When the error types differ, convert first with `Result.mapError(r: result, f: lambda(error) return IOError.message(error))`, for example when a function returns `Result[T, String]` and `result` contains an `IOError`. The callback parameter is named `error`.

For a returning pipeline, write `try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return`. Here `try` unwraps the result of the whole pipeline. A returning try inside a lambda returns from that lambda. Inside the callee or fixed arguments of a call with `_` holes, it returns from the generated function, so it does not return from the surrounding function. See [Holes and pipes](#holes-and-pipes).

Use an explicit action in new code: `or return` for reusable functions, libraries, and callbacks; `or die` for an entry point that should report a failure and end the run. An entry point whose contract returns a `Result.Error`, or which cannot use `Process.Exit`, can also use `or return`. The following example illustrates returning a failure from `main`.

```benitoite
import Benitoite.Unofficial.IO.Console

function parsePort(text: String) -> Result[Integer, String]
  return match Integer.parse(text) with
    case Option.Some(n) if n > 0 and n < 65536 -> Result.Ok(n)
    case otherPort -> Result.Error("not a port: ${text}")
  end match
end function

function main() -> Result[Unit, String] uses Console.Write
  bind port <- try parsePort("8080") or return
  Console.writeLine("port ${port}")
  bind other <- try parsePort("http") or return
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

Some failures are not values: integer overflow, division by zero, a value too large to build, and running out of the call stack *stop* the program with a runtime error and exit status 1. A `match` cannot catch them. The report shows the place and the calls that led to it.

`try e or die` and `try e or die(message)` accept a standard `Result[T, E]` or `Option[T]` and produce `T` on success, without restricting the enclosing function's return type. They add `Process.Exit`; import `Benitoite.Unofficial.IO.Process` to name it in `uses`. The module cannot be renamed with `as` (E0339), so write `uses Process.Exit`. The compiler connects the standard Show and exit references internally, but does not import names into your scope. No `Console.Write` effect is required for the host's failure report.

| Action | Enclosing return type | Display requirement | Additional effect |
|---|---|---|---|
| Bare try or `or return` | `Result[U, E]` or `Option[U]`, matching the input | None | None |
| `or die` or `or die(message)` | Any | `Trait.Show` for Result's error type; none for Option | `Process.Exit` |

The input is evaluated once. Success evaluates neither the message nor Show. Failure evaluates the optional pure `String` message once, then the error's Show once, then calls the standard exit operation with status 1. A message does not implicitly bind the error to a name. Direct `return`, `try`, and outer `resume` are forbidden in the message; a lambda written there has its own return boundary. `IOError`, `NetworkError`, `Json.ParseError`, and `Csv.ParseError` already implement Show by returning their `message` string unchanged. Implement Show for another error type, or use `Result.mapError` to convert it to a type with Show. The returning forms need no Show.

A String cause retains Show's quotes and escapes. Option.None has the fixed cause `expected a value, got Option.None`. The message is displayed as plain text, and an empty message is distinct from no message; neither removes the cause. If the message or Show stops with a runtime error or resource failure, that stop is used instead of a die report. Purity and static checking do not guarantee termination, the intended result, or success of external operations.

The default exit ends the whole run, including when called by a child task: remaining tasks are cancelled, resources are released, and buffered output is transferred. The CLI then reports `error: explicit failure exit`, the source location, an optional `message: ...`, and a `cause: ...` once to standard error. Release and final output failures follow as supplementary reports and keep status 1. With `--diagnostics=json`, the die report has `kind: "die"`, `code: null`, and the same location and notes. Cancellation does not undo external work already started. Competing exits, interruption, and internal errors follow the ordinary stop rules; only the adopted die carries this report.

A language handler can replace the existing `Process.Exit` operation; it receives only the usual exit code, and the handled call's report is discarded rather than attached to a later exit. In `benitoite test`, die fails that test and the runner continues with the next one. Text and JSON preserve its cause, message, and location without adding a second copy to captured output. Use `Process.exit(code)` for an arbitrary exit status.

The input includes pipes up to `or return` or `or die` at the same depth; ordinary Boolean `or` stays an operator. Parenthesize an explicit try before adding an operator or call, as in `(try parsePort(text) or die) + 1`. `or return` takes no value. A physical newline immediately after its `return` ends the statement. Start a message's `(` on the same physical line as `die`; outside parentheses, a newline after `die` or its message ends the statement. A short lambda must include its whole action and message on one physical line. The formatter preserves bare and explicit forms.

```files
name: input.txt
ready
```

```benitoite
import Benitoite.Unofficial.IO.Console
import Benitoite.Unofficial.IO.File
import Benitoite.Unofficial.IO.Process

function load(path: String) -> Result[String, IOError] uses File.Read
  return Result.Ok(try File.readText(path) or return)
end function

function main() -> Unit uses File.Read, Console.Write, Process.Exit
  bind text <- try load("input.txt") or die("could not read input.txt")
  Console.write(text)
end function
```

```output
ready
```

`load` preserves the original IOError for its caller. `main` uses the standard Show implementation if loading fails, so it needs no conversion solely for display. Adding Process.Exit changes the function's contract; review the action, return type, and effects together.

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
| `Process.Exit` | ends the run with a chosen exit code; `or die` reports its cause and optional message to standard error and exits with status 1 |
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

An effect is part of the type of a function value: `function(text: String) -> Unit uses Console.Write`.

## 11. Effect handlers

You can declare your own effects. An `effect` declaration lists its operations, which are called like functions. `handle body with case operation(arguments) -> clause end handle` runs `body` and, whenever the body calls one of the listed operations, runs the clause instead. In the clause, `resume(value)` continues the body, with `value` as the result of the operation. A clause that does not call `resume` ends the `handle` with its own value. `resume` is written directly in the clause; it cannot appear in a lambda, a `lazy` body, a `match` guard, or an argument of a call with `_` placeholders (a `handle` written there can resume its own clauses).

```benitoite
import Benitoite.Unofficial.IO.Console

effect Log
  function write(message: String) -> Unit
end effect

function sumPrices(items: List[Integer]) -> Integer uses Log
  write("items: ${List.length(items)}")
  return List.fold(xs: items, initial: 0, f: lambda(acc, value) return acc + value)
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

Each file is a module. Its name is its path from the root directory, with `/` replaced by `.` and without `.bnt`: the file `Lib/Text.bnt` is the module `Lib.Text`. `import Lib.Text` makes it available as `Text`; `import Lib.Text as T` makes it available as `T`. Declarations marked `public` can be used from any module that imports them. Declarations marked `public(package)` can be used only by modules of the same package. A dependency package consists of the modules under its root; the starting file and the modules under the starting root also count as one package. Unmarked declarations are private to their module. Imports cannot form a cycle.

```files
name: Lib/Text.bnt
/// Turns "Hello World" into "hello-world".
public function slug(text: String) -> String
  return String.toLowercase(String.replace(s: String.trim(text), old: " ", new: "-"))
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

Visibility has three levels: private < `public(package)` < `public`. Types, traits, and effects used in a declaration's contract must be at least as visible as the declaration. This includes nested function types, constraints, and `uses`; a `public` function cannot expose a `public(package)` type from another module either. Constructors, record fields, trait methods, and effect operations inherit the visibility of their enclosing declaration. `public(package)` can also mark constants and type aliases. Neither `public` nor `public(package)` can mark `implement` or its functions.

The parentheses accept only `package` (`E0253` for other words). Spaces before `(` are accepted and removed by `fmt`; a newline between `public` and `(` is accepted; a newline after `public(package)` separates it from the declaration and is an error. `package` remains available as an identifier. The effect report from `benitoite package` counts only `public` contracts.

### Standard and unofficial modules

The modules of the standard library are named `Benitoite.<Name>`. Most of the core modules (`Integer`, `String`, `List`, `Map`, `Option`, `Result`, and others) are in the *prelude*: they can be used without `import`.

In this release, the IO and network modules and the text and data modules are *unofficial*: their interfaces may still change, so they are imported under `Benitoite.Unofficial`. Write `import Benitoite.Unofficial.IO.Console` and refer to the module as `Console`. `import Benitoite.IO.Console` is an error in this release. When an unofficial module becomes standard in a later minor version, its import name changes to `Benitoite.<Name>` and scripts must change their imports.

Every module outside the prelude must be imported, also when it appears only in `uses`. See [The standard library](#19-the-standard-library) for the list.

The modules that declare built-in effects (`IO.Console`, `IO.File`, `IO.Process`, `IO.Clock`, `IO.Random`, `Network.Http`, `IO`, and `Assert`) cannot be renamed with `as`; that is the error `E0339`, also when the new name is the same as the original one. This keeps the effect names in `uses` true: `uses Console.Write` always means writing to the console. When an imported module of your own has the same name as one of these modules, rename your module with `as`.

For importing modules from a local dependency, see [Experimental: packages and external functions](#21-experimental-packages-and-external-functions).

## 13. Type classes

A *type class* (`trait`) declares functions that several types implement. `implement` gives the implementation for one type. A type parameter can be constrained with `[T: Show]`; several constraints are joined with `&`. The built-in constraints `equality` (values can be compared with `=`) and `key` (values can be keys of `Map` and elements of `Set`) can be used in the same place.

Methods are called through the class name: `Describe.describe(x)`. Methods with two or more parameters require named arguments.

Each implementation must use the parameter names and order declared by the class, including names in nested function types; a mismatch reports `E0454`. Standard methods follow the same rule: the callback of `Functor.map` takes `value`, and that of `Foldable.fold` takes `acc, value`.

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
  function describe(x: List[T]) -> String
    return "[" + String.join(xs: List.map(xs: x, f: lambda(value) return Describe.describe(value)), separator: ", ") + "]"
  end function
end implement

function describeIfSame[T: Describe & equality](a: T, b: T) -> String
  return match a = b with
    case true -> Describe.describe(a)
    case false -> "different"
  end match
end function

function main() -> Unit uses Console.Write
  Console.writeLine(Describe.describe([1, 2]))
  Console.writeLine(describeIfSame(a: 3, b: 3))
end function
```

```output
[the number 1, the number 2]
the number 3
```

An implementation applies to the whole program. An implementation must be in the module of the class or of the type, and two implementations cannot overlap. The standard classes, such as `Show`, `Order`, `Monoid`, `Functor`, and `Monad`, are in the module `Benitoite.Trait`.

`IOError`, `NetworkError`, `Json.ParseError`, and `Csv.ParseError` have standard `Trait.Show` implementations. Each returns exactly its type's `message` string, without adding quotes, line or column numbers, or other location information. The implementations for IOError and NetworkError live in `Benitoite.Trait`; the ParseError implementations live in Json and Csv. Explicit calls to `Trait.Show.show` require `import Benitoite.Trait`. In contrast, `or die` connects its Show reference internally. Ordinary `Show[String]` still adds quotes and escapes.

## 14. Explicit laziness

`lazy ... end lazy` makes a value of type `Lazy[T]` without evaluating its body. `Lazy.force(value)` evaluates the body the first time and returns the saved result after that. The body must be pure.

```benitoite
import Benitoite.Unofficial.IO.Console

function choose(useFirst: Boolean, first: Lazy[Integer], second: Lazy[Integer]) -> Integer
  return match useFirst with
    case true -> Lazy.force(first)
    case false -> Lazy.force(second)
  end match
end function

function main() -> Unit uses Console.Write
  bind result <- choose(useFirst: true, first: lazy 42 end lazy, second: lazy 100 div String.characterCount("") end lazy)
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

Tasks run concurrently within one program. `TaskGroup.open()` opens a group as a resource; `TaskGroup.spawn(group: group, action: lambda() ...)` starts a task in it, and `Task.await(task)` waits for its result. Releasing the group at `end with` waits for all its tasks. `Task.all` runs a list of functions as tasks and returns their results in order; `Task.race` returns the first result and cancels the other tasks. `Task.withTimeout(milliseconds: milliseconds, action: action)` returns `Option.Some` with the result when the task finishes before the time has passed, and otherwise cancels the task and returns `Option.None`; a task that finishes just before the deadline can still give `Option.None`, because the deadline is checked when `benitoite` next switches tasks. Operations that wait, such as reading a file, an HTTP request, or `Clock.sleep`, let other tasks run.

```benitoite
import Benitoite.Unofficial.IO.Console

function main() -> Unit uses Console.Write, State
  bind counter <- Reference.new(0)
  bind squares <- with group = TaskGroup.open() do
    bind tasks <- List.map(xs: [1, 2, 3], f: lambda(value)
      return TaskGroup.spawn(group: group, action: lambda()
        Reference.set(reference: counter, value: Reference.get(counter) + 1)
        return value * value
      end lambda)
    end lambda)
    List.map(xs: tasks, f: lambda(value) return Task.await(value))
  end with
  Console.writeLine("${String.join(xs: List.map(xs: squares, f: lambda(value) return Integer.toString(value)), separator: " ")} after ${Reference.get(counter)} tasks")
  Console.writeLine(String.join(xs: List.map(xs: Task.all([lambda() return "a", lambda() return "b"]), f: lambda(value) return value), separator: ""))
end function
```

```output
1 4 9 after 3 tasks
ab
```

When a task stops with a runtime error, the program stops. When the program is interrupted, all tasks are cancelled and resources are released.

## 16. Tests

A test is a function with the attribute `@test("description")`, no parameters, and the return type `Unit` or `Result[Unit, String]`. Check values with `Assert.equal(actual: actual, expected: expected)` and `Assert.isTrue(condition: condition, message: message)`, which need the effect `Assert.Check`. A failed check stops that test; returning `Result.Error(message)` also fails it. Each test runs on its own, so a failure or a runtime error in one test does not stop the others.

Only tests declared in a selected entry file are run; tests in its imported modules are not added. A directly named file uses its parent directory as the import root. Files discovered under a named directory use that directory as their shared root, with nested package roots excluded. Repeated explicit paths remain separate entries. Inspection with `test --check` uses the same rules.

```benitoite test
import Benitoite.Unofficial.IO.File

function countWords(path: String) -> Result[Integer, String] uses File.Read
  bind text <- try File.readText(path) |> Result.mapError(r: _, f: lambda(error) return IOError.message(error)) or return
  return Result.Ok(List.length(List.filter(xs: String.split(s: text, separator: " "), p: lambda(value) return value <> "")))
end function

@test("countWords counts words separated by spaces")
function countWordsCounts() -> Unit uses Assert.Check, File.Read
  bind result <- handle
    countWords("notes.txt")
  with
    case File.readText(path) ->
      Assert.equal(actual: path, expected: "notes.txt")
      resume(Result.Ok("one two  three"))
  end handle
  Assert.equal(actual: result, expected: Result.Ok(3))
end function
```

The handler replaces `File.readText`, so the test reads no file. The test still lists `File.Read`, because the handler handles only `File.readText`, one of the operations of `File.Read`, and an effect is removed only when all its operations are handled.

Run tests with `benitoite test`. For a file `t.bnt` with one passing test and one test that checks `Assert.equal(actual: double(2), expected: 5)`, the report is:

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

In reports of failed `Assert.equal` and `Assert.notEqual` checks, `left` and `right` each contain at most 4 KiB (4,096 bytes), including any final `…` (U+2026). A longer rendering is cut at the last character boundary within 4,093 bytes and ends with `…`; the remaining value is not traversed. The cut may fall inside an escape sequence such as `\u{202e}`. Text and JSON Lines reports use the same rendered strings.

Checks directly in generic helper bodies recover constructor names from the direct caller's type arguments, including a tail call from a caller with concrete types. Recovery stops after a tail call, even if an outer call of the same function is still running. Checks inside lambda bodies or handler bodies and clauses use the types with which the enclosing function is used in the program, rather than guessing which call created them. Checks inside implementation methods do not recover types from callers.

When a generic helper calls another helper through a tail call, the caller's type arguments are no longer available from that call. In this case, or when a generic function is passed as a value, the report uses a type only if the types at every use of the function can be determined and the shapes of both compared values identify a unique type. A recursive generic helper can also leave the type unknown.

At positions where the type remains unknown, constructors appear as `<constructor #n of an unknown type>`, where `n` is their zero-based position in the type declaration. A check with a concrete compared type renders constructors by name; known parts of a type, such as `Option` in `Option[T]`, retain their names even when `T` cannot be recovered.

A file with check errors is not run: its diagnostics go to standard error, and, without `--allow-effects`, the tests of the other files still run. `benitoite check` reports an error for a file without `main`. To inspect test files without executing them, use `benitoite test --check <path>...`; success writes nothing to standard output, and diagnostics use the selected format on standard error. Add `--report=json` for an [inspection report](#inspection-reports), which includes the selected test contracts and does not produce test result or summary lines.

With `--diagnostics=json`, executing `test` writes one JSON object per line to standard output: one with `"kind": "test"` per test, with the fields `file`, `name`, `function`, `location`, `outcome` (`"passed"` or `"failed"`), `failure`, `stdout`, and `stderr`, and a last one with `"kind": "testSummary"` and the counts `passed`, `failed`, and `filesNotRun`, and `interrupted`. A `failure` has a `reason` and a `message`. The reason is `"assert"` (a failed check, with `primary`, `trace`, and for `Assert.equal` and `Assert.notEqual` the values `left` and `right`), `"error"` (the test returned `Result.Error`), `"runtime"` (a runtime error, with the fields of a runtime error report), or `"exit"` (the test called `Process.exit` or stopped with `or die`, with `exitCode`; `or die` also includes its diagnostic object in `die`). Failures with the reasons `"assert"`, `"runtime"`, and `"exit"` also have `notes`, an array of strings that includes failures to release resources while stopping. Check diagnostics go to standard error.

With `--allow-effects`, all entries must finish preparation before any test starts. A check error, an insufficient effect set, or a compilation limit rejects the entire run with status 2. When discovery has finished, the JSON output contains no `kind: "test"` lines and only a summary such as:

```json
{"kind":"testSummary","passed":0,"failed":0,"filesNotRun":2,"interrupted":false}
```

Here two entries were selected and neither started. `filesNotRun` counts all entries skipped by the rejection, including entries with no tests and repeated explicit paths, rather than only entries with errors. Text summaries use `; 2 files not run` and report `FAILED`. If preparation ends with an observed interruption or internal error and the selected entries are known, the summary uses the same skipped count, with status 130 and `interrupted: true` for interruption, or status 3 for an internal error. Discovery failures, usage errors, and outer failures that cannot establish the targets produce no summary. A successful empty selection can return 0 passed, 0 failed, and `filesNotRun: 0`. A reader must check the exit status, summary presence, `filesNotRun`, and `interrupted`, not just `passed` and `failed`.

The exit status of executing `test` is 0 when all tests pass, 1 when a test fails, 2 for check errors, effect-limit rejection, compilation limits, unreadable files, and usage errors, 3 for an internal error, and 130 when interrupted. When several apply, the first in the order 130, 3, 2, 1 is used. Output failures exit with 1. Non-executing `test --check` uses the [inspection statuses](#inspection-reports), with or without a JSON report.

## 17. Formatting

`benitoite fmt` rewrites files in the standard layout. It changes only whitespace: spaces within lines, indentation, blank lines, and trailing spaces. It keeps your line breaks and comments, does not add or remove tokens, and has no settings. `fmt` checks only the syntax, so a file with type errors can be formatted. A file with lexical or syntax errors (codes `E01nn` and `E02nn`) is left unchanged and its diagnostics are reported; the other files are still formatted. Other errors found while reading the file, such as a wrong attribute, do not stop formatting.

`fmt --check` rewrites nothing and lists the files that would change on standard error. `fmt` writes nothing to standard output. A file is replaced only after the new content is written completely, so an interrupted `fmt` does not leave a broken file. The new content is first written to a temporary file in the same directory that only the owner can read.

`fmt` does not replace a file whose owner has no write permission (such as mode `0444`), a file with more than one hard link, or a file owned by another user. It reports `E0125` with the reason and leaves the file unchanged. To format such a file, make it writable for its owner, remove the other hard links, or run `fmt` as the owner. `fmt --check` checks these files as usual. `fmt` reads only regular files.

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

An `or die` report has `kind: "die"`, `severity: "error"`, and `code: null`, with the source location and notes containing the rendered cause and optional user message; it ends a run with status 1. It is distinct from a runtime error. Usage errors normally remain text, even with `--diagnostics=json`. The [inspection report](#inspection-reports) modes put diagnostics in their `diagnostics` array instead of standard error; only their `usageError` diagnostics use the combination `kind: "check"`, `code: null`.

Tell diagnostics apart by `code` and the JSON fields, not by the message: messages and the contents of helps may change even in patch versions. A code that has been removed is never reused with another meaning.

### Calls, function contracts, and lambdas

| Code | Meaning and correction |
|---|---|
| `E0254` | A lambda without `end lambda` crosses a physical line. Put the body after the header line and add `end lambda` for a multiline body. |
| `E0256` | Directly nested lambdas need parentheses around the inner lambda when either omits `end lambda`. |
| `E0257` | A function-type parameter has no name. Write each parameter as `name: Type`, using the expected contract's names. |
| `E0449` | A function with two or more parameters requires named arguments. Use the declared names while preserving expression order. |
| `E0450` | A call mixes named and positional arguments. Use one form consistently. |
| `E0451` | A label does not name a parameter. Read the available names in declaration order. |
| `E0452` | A parameter is supplied more than once, including a pipe's implicit first argument. Supply it once. |
| `E0453` | Named arguments omit required parameters. Supply the missing names listed by the diagnostic. |
| `E0454` | Function parameter names or their order differ from the expected contract, including in an implementation method. Match the contract or use a wrapper with the required names. |
| `E0455` | A function's parameter names and order cannot be determined. Add a named function-type annotation. Call-label order does not establish a contract. |
| `E0456` | A direct data constructor call uses labels. Use positional fields, or bind the constructor to a function value and use that value's parameter names. |

`E0402` reports positional argument-count errors, including direct constructor calls. `E0453` reports missing named arguments at the call site and lists their names. Apply suggested edits after checking the target declaration; reordering effectful expressions can change the program's behavior.

The meaning of every code is listed in the bundled Agent Skill (`references/diagnostics.md`, installed by `benitoite skill install`).

## 19. The standard library

Modules in the prelude need no import. The others are imported with the name in the table. The full list of functions of each module is in the bundled Agent Skill (`references/stdlib/`).

| Module | Import | Contents |
|---|---|---|
| `Integer`, `Float`, `Decimal`, `RoundingMode`, `Byte`, `Character`, `String`, `Boolean`, all numeric widths and aliases in [section 4](#numeric-type-names-and-suffixes) | prelude | Functions on the basic types |
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
| `Regex` | `import Benitoite.Unofficial.Regex` | Regular expressions; finding one match takes time proportional to the input length times the pattern size, and finding all matches can take time proportional to the square of the input length |
| `Encoding` | `import Benitoite.Unofficial.Encoding` | Base64 |
| `Hash` | `import Benitoite.Unofficial.Hash` | SHA-256 hash values of bytes |
| `Network.Http` | `import Benitoite.Unofficial.Network.Http` | HTTP/1.1 servers without TLS, and clients for `http` and `https` |

### Parameter names in library calls

Read parameter names from the declarations in the [standard library reference](../../crates/benitoite/skill/references/stdlib/index.md). For example, `List.map` takes outer arguments `xs, f`; its `f` argument has the contract `function(value: T) -> U uses E`. These are separate sets of names: write `List.map(xs: items, f: lambda(value) return value * 2)`.

Common callback contracts are:

| Functions | Callback parameter names, in order |
|---|---|
| `List.map`, `List.filter`, `List.forEach`, `Set.map`, `Set.filter`, `Set.forEach`, `Option.map`, `Result.map` | `value` |
| `List.fold`, `Set.fold` | `acc, value` |
| `Map.map`, `Map.filter`, `Map.forEach` | `key, value` |
| `Map.fold` | `acc, key, value` |
| `Result.mapError` | `error` |
| `Trait.Functor.map` | `value` |
| `Trait.Foldable.fold` | `acc, value` |

Keep these names even for unused parameters. When passing a function with different parameter names, use the wrappers described in [Function contracts and callbacks](#function-contracts-and-callbacks).

### IO and network behavior

A few behaviors worth knowing:

- After a write to a `File.Writer` fails, including a write that flushes the buffer, the writer discards the buffered data and keeps the error. Later `File.write`, `File.writeLine`, and `File.writeChunk` return the same error without writing anything. `File.closeWriter` closes without writing and returns the same message with `IOErrorKind.Other`. Leaving a `with` block that holds the writer is a release failure (a runtime error), even if you handled the write error. To handle the release error, call `File.closeWriter` at the end of the block and check its result. Stop writing at the first error and open the file again to retry.
- `Process.run` and `Process.shell` wait until the command's standard output and standard error are closed. If the command starts a background process that keeps either output open, they do not return after the command exits; wrap the call in `Task.withTimeout` to limit the wait. A timeout does not stop the started processes.
- Relative file paths are resolved against the working directory. Use `Process.scriptDirectory()` for files next to the script.
- `Process.run` starts a program with a list of arguments, without a shell. A non-zero exit code is not an error; read it from the result. When the command does not read all of the `input` you gave it (as `head` does), that is not an error either.
- `Process.shell` runs a command line with `/bin/sh -c`. Write only POSIX sh.
- `Process.run` and `Process.runAttached` reject explicitly supplied `Command.environment` names starting with `DYLD_` or `LD_`, comparing ASCII letters without regard to case. This includes `LD_RUN_PATH` used by build tools, lowercase spellings, empty values, and resetting a variable to its inherited value. They return `Result.Error` with `IOErrorKind.InvalidInput` before starting a child or arranging its pipes. Existing invalid-input checks (including NUL, empty names, and `=` in names) take precedence. The message names the first forbidden variable in lexical order of the original names and does not expose its value.
- This environment rule always applies, on every OS, but leaves inherited variables unchanged; `Process.shell` continues to inherit them too. Allowing `Process.Run` permits commands such as `env` or a shell to set variables themselves. The rule does not control the initial environment, `PATH`, command-specific settings, grandchildren, or all Windows DLL search behavior. It is not a sandbox; the harness and OS must enforce isolation.
- `Http.respond` accepts statuses from 200 to 599; any other status, including the `1xx` statuses, is a runtime error. `benitoite` sets `content-length` and `connection: close` and drops your `content-length`, `connection`, `transfer-encoding`, `trailer`, `keep-alive`, `proxy-connection`, `te`, and `upgrade` headers, as well as any headers named in any of your `connection` values. Names are compared without regard to case; `connection` values are split at commas, surrounding spaces and tabs are removed, and empty elements are skipped. It sends no body for responses to `HEAD` requests, for the statuses 204, 205, and 304, and for `2xx` responses to `CONNECT` requests; a body given in these cases is dropped.
- The HTTP server accepts targets beginning with `/` (including `//a`), absolute targets beginning with `http://` or `https://` (case-insensitive), `*` for uppercase `OPTIONS` only, and authority targets for uppercase `CONNECT` only. A `CONNECT` target must consist of a non-empty host made of ASCII letters, digits, and `-._~!$&'()*+,;=:[]%`, followed by `:` and one or more ASCII digits with a value from 0 to 65535; other forms, including `/path` and absolute targets, are rejected for `CONNECT`. Other target forms, and any target containing a literal `"`, `<`, `>`, or a non-ASCII character, receive 400 without calling the handler. Percent-encode these characters. Literal `[`, `]`, `\`, `^`, `` ` ``, `{`, `|`, and `}` are accepted in paths and queries. A `%` that is not followed by two hexadecimal digits is accepted and kept as is.
- The HTTP server answers 400 to a request target containing `#` and does not pass it to the handler. Omit the fragment or encode a literal `#` as `%23`; the `path` keeps percent encoding. For an uppercase `OPTIONS` request, an absolute target with neither a path nor a query component (`OPTIONS http://host`) gives `path` `*` and an empty `query`; `OPTIONS http://host/`, `OPTIONS http://host?x=1`, and `OPTIONS http://host?` give `path` `/`. Other methods, such as `GET http://host` or `options http://host`, give `path` `/` for an empty absolute path.
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
import Benitoite.Unofficial.IO.Process
import Benitoite.Unofficial.Json

function amountOf(order: Json.Value) -> Option[Pair[String, Integer]]
  bind category <- try Option.andThen(o: Json.get(value: order, k: "category"), f: Json.asString) or return
  bind amount <- try Option.andThen(o: Json.get(value: order, k: "amount"), f: Json.asInteger) or return
  return Option.Some(Pair(category, amount))
end function

function main() -> Unit uses File.Read, Console.Write, Process.Exit
  bind text <- try File.readText("orders.json") or die
  bind parsed <- try Json.parse(text) or die
  bind orders <- try Option.okOr(o: Json.asArray(parsed), error: "orders.json is not an array") or die
  bind totals <- List.fold(xs: orders, initial: Map.empty(), f: lambda(acc, value)
    return match amountOf(value) with
      case Option.Some(Pair(category, amount)) ->
        Map.set(m: acc, k: category, value: Option.unwrapOr(o: Map.get(m: acc, k: category), fallback: 0) + amount)
      case Option.None -> acc
    end match
  end lambda)
  Map.forEach(m: totals, f: lambda(key, value)
    Console.writeLine("${key}: ${value}")
  end lambda)
  return ()
end function
```

```output
book: 2000
food: 300
```

## 20. Compatibility

### Version policy

While the major version is 0:

- A minor version (`0.1.0` to `0.2.0`) may change the language, the standard library, the command line, and diagnostics in incompatible ways. Each incompatible change is listed in the [CHANGELOG](../../CHANGELOG.md) with how to migrate.
- A patch version (`0.1.0` to `0.1.1`) only fixes bugs, that is, behavior of `benitoite` that differs from its specification. It does not change the language, the standard library (including unofficial modules), the command line, diagnostic codes, or the JSON formats. Messages and suggested fixes in diagnostics may change.
- Moving an unofficial module into the standard library changes its import name, and happens only in a minor version.
- The bundled Agent Skill describes only the version of `benitoite` it comes with. Run `benitoite skill install` again after updating.

> Note: Releases `0.0.1` through `0.0.7` are source-only releases; no executables are provided. Executables will be provided from `0.1.0`, and until then any release may contain incompatible changes.

## 21. Experimental: packages and external functions

Packages and external functions are experimental. Their spelling may change as the syntax is revised. They follow the same [compatibility policy](#20-compatibility) as the rest of the language; experimental features have no exception to that policy.

### Local dependencies

A package is a directory with a `package.bnt` settings file and modules that other scripts can import. For example, create these two files under `packages/textkit`:

```files
name: packages/textkit/package.bnt
language "0.0.7"

package Textkit
  license "MIT"
end package
```

```files
name: packages/textkit/Slug.bnt
public function slug(text: String) -> String
  return String.toLowercase(String.replace(s: String.trim(text), old: " ", new: "-"))
end function
```

Declare the dependency before imports and declarations in the starting script:

```benitoite
// spec: 01-03 依存のパッケージの取り込み
language "0.0.7"

dependency Textkit
  path "packages/textkit"
end dependency

import Benitoite.Unofficial.IO.Console
import Textkit.Slug

function main() -> Unit uses Console.Write
  Console.writeLine(Slug.slug(" Hello Packages "))
end function
```

```output
hello-packages
```

`Textkit` in `dependency Textkit` is the dependency alias: an uppercase identifier other than `Benitoite`. It may differ from the name in the package's `package` block. `import Textkit.Slug` uses this alias and the path from the package root, so it reads `Slug.bnt` in `packages/textkit`. Inside a package, imports use paths from that package's own root; they cannot import modules from the caller's root. Only `public` declarations are available to callers.

The dependency's `path` is relative to the starting script's root directory, rather than the working directory. It may point outside the root, and an absolute path is also accepted. Each package needs its own `package.bnt` with a `package` block and a `language` declaration. Dependencies cannot themselves declare dependencies in this version. Git sources, version selection, and downloading packages are not supported; `source`, `version`, and `commit` fields are rejected.

Keep dependency directories distinct from root module names, as in lowercase `packages/textkit` above. An import that finds different modules in both the root and a dependency is an error. A file inside a declared dependency must be imported through its alias. Dependency roots cannot contain the starting root, equal another dependency root, or contain one another. Imported package modules take part in the normal name and type checks. Their errors are reported; their warnings are suppressed, also with `--deny-warnings`.

### File headers, settings, and language versions

The file header contains `language` and `dependency` items after any leading `//!` documentation and before imports or declarations. Imported modules cannot contain these settings. Alternatively, place settings in `package.bnt` in the root directory itself. Benitoite does not search parent directories for it.

For example, a root settings file can record the language version while the starting script contains only declarations:

```files
name: package.bnt
language "0.0.7"
```

```benitoite check
// spec: 01-03 依存の記述と `package.bnt`
function main() -> Unit
end function
```

Dependency blocks can also be moved into that root settings file. Put all dependencies in one place: declaring them in both the starting script and `package.bnt` is an error. Declaring `language` in both files is also an error.

`language "MAJOR.MINOR.PATCH"` records the language version the file was written for, using three decimal integers. For Benitoite `0.0.7`, a declaration of `0.0.7` passes the compatibility check; a later version reports `E0907`, and an earlier version reports `E0908`. The declaration is optional in the starting script and root settings, and required in a package's settings. The interpreter uses the same language rules with or without a declaration. Root and dependency versions are checked independently. The migration help for the loader-environment change asks you to review the script, then update its declaration to the current interpreter version and update dependency hashes; the target version is not fixed to the release that introduced the change. The [version policy](#version-policy) explains compatibility guarantees; release-specific changes are recorded in the [CHANGELOG](../../CHANGELOG.md).

`package.bnt` contains settings only: `language`, `dependency`, and `package` blocks, with no imports or declarations. A `package` block can appear only in this file, and cannot be combined with dependencies. Its name is an uppercase identifier; its only metadata field is the optional `license`. Fields take plain string literals; interpolation is not allowed. Field order is unrestricted, but duplicate or unknown fields are errors.

`package.bnt` cannot be the starting file for `run`, `check`, or `test`. `benitoite test <directory>` skips it and skips nested directories that contain their own `package.bnt`. To test a package, specify that package's root. `fmt` formats settings files as well as scripts.

### Content hashes and effect records

`hash` is optional for a local dependency. When present, Benitoite checks the package's included paths and file contents on every load, even if no module from the package is imported. A mismatch reports the expected and computed values. Without `hash`, no content check or warning about the missing hash is made; this is useful while developing a package.

The following shows the field syntax. The all-zero hash is illustrative; use `package add` or `package update` to compute the actual value:

```text
dependency Textkit
  path "packages/textkit"
  hash "sha256:0000000000000000000000000000000000000000000000000000000000000000"
  effects ""
end dependency
```

The hash covers `.bnt` and `.wasm` files and files whose names start with `LICENSE`, `COPYING`, or `README` (the latter names ignore ASCII case). It includes `package.bnt`. It follows directories whose names start with an ASCII uppercase letter, and all non-hidden directories under the root's `wasm/`. Hidden entries and names that are not valid UTF-8 are excluded. Root directories such as `rust/`, `wit/`, and `target/` are not followed. Relative paths and file bytes determine the hash; file permissions and empty directories do not.

Hashing rejects symbolic links in the visited non-hidden entries, included paths that collide after lowercasing or contain a newline, and unreadable included files. Limits are 10,000 included files, 100,000 visited entries, and 128 MiB of included file contents. A hash does not prevent another process from changing files between hashing and loading them.

`effects` is a record written by the package commands, for example `effects "Console.Write, File.Read"`, or `effects ""` for an empty set. Loading checks its format but does not compare it with the package. The actual effect checks use function types, and operations reachable from `main` must appear in its `uses`, after accounting for handlers. The record is for reviewing changes to dependencies; it neither grants permissions nor restricts the files or hosts a script may access.

### The package commands

```text
benitoite package add <alias> --path <directory> [<root or entry>]
benitoite package update [<alias>] [<root or entry>]
benitoite package move <entry>
```

`add` declares a new dependency, computes its hash, records its public built-in effects, and reports its components. The `--path` value is relative to the selected root (or absolute), and is copied into the declaration as written. Existing aliases are errors. `add` writes where dependencies already exist; otherwise it uses an existing `package.bnt`, or the starting file if there is no settings file. It needs a settings file or a starting file to edit.

`update` recomputes hashes and effect records. Without an alias, it updates only dependencies that already have a hash. With an alias, it also adds a hash if one was absent. It shows effects added with `+` and removed with `-`, comparing with the stored `effects` field. If that record is absent or malformed, it reports `(not recorded)` and the current effects. A malformed `hash` or `effects` field can be repaired by an explicit update. If the hash is unchanged and only effects are updated, it shows the hash once. If no dependencies have hashes, a bulk update reports `no dependencies with hash to update`. If both records are unchanged, it reports `unchanged` and does not replace the file.

For `add` and `update`, omitting the target selects the working directory. A directory target uses its `main.bnt` if present; a file target selects that starting file. Passing an existing `package.bnt` selects its directory as the root. An explicitly named `package.bnt` that does not exist reports `E0101` and does not edit the starting file. A single uppercase identifier argument to `update` is an alias; write an identifier-shaped directory path as `./Name` to distinguish it.

For the pure Textkit package above, if `main.bnt` does not declare `Textkit` yet, adding it prints the following (`<computed-hash>` stands for the actual `sha256:` value):

```text
benitoite package add Textkit --path packages/textkit main.bnt

added dependency Textkit (package Textkit) to main.bnt
  hash: <computed-hash>
  effects: (none)
  components: (none)
```

The commands report built-in effects from all public function and public trait-method declarations, public type-alias right-hand sides, public record field types, and public `data` constructor field types, including effects in nested function types. Library modules are identified by their official import names, such as `Benitoite.Unofficial.IO.Console`; `State` and `IO.All` need no import. Effects reached through import names absent from the standard-library table are not counted. They do not type-check the package to make that report, include user-defined effects or effect variables, or expand `IO.All`. Component reports identify components with `(no imports)` or give a failure reason. A component failure alone does not prevent editing; `benitoite check` still checks the paths, exports, and types actually used by the script.

`move` moves the starting file's header settings and associated comments into `package.bnt` next to it. It requires a file target; a directory is a usage error. It refuses an empty header or a destination that already contains `language` or dependencies. For example:

```text
benitoite package move main.bnt
moved language, dependency Textkit from main.bnt to package.bnt
```

These commands edit the header while preserving the source body and its comments. Moving into a comment-only settings file appends after its comments and keeps their bytes and line endings. A newly created settings file copies the starting file's permissions with executable bits removed. They format the edited settings and replace files through temporary files; `move` attempts to restore the settings if writing the starting file fails. Validation checks the target dependency's declaration and settings, and does not reject editing because of errors in unrelated dependency settings. Diagnostics that point into a proposed edit identify it as not yet written. They report changes on standard output and diagnostics on standard error, returning 0 for success and 2 for invalid input or read/write failures (3 for an internal error). All three accept `--diagnostics=text|json`; their change reports remain text, and there is no `--json` report option.

### External functions and types through WASM

An external function gets its body from a binary WebAssembly Component Model component. The component must have no imports: Benitoite provides no host functions or WASI. A core Wasm module or a text-format file is not accepted. Declare a top-level function without a body or `end function`:

<!-- WASM のバイナリは files ブロックで置けないため、以下は text の例とする。照合・実行は testdata/external/ のゴールデンが確かめる。 -->

```text
@external("wasm", "wasm/fuzzy.wasm", "distance")
public function distance(a: String, b: String) -> Integer
```

The corresponding WIT contract exports the function directly from a world:

```text
package example:fuzzy;

world fuzzy {
  export distance: func(a: string, b: string) -> s64;
}
```

The declaration must give concrete parameter and result types. It cannot have type parameters, constraints, or effect variables. Functions whose expanded parameter or result types contain an external type must declare `uses State`; all other external functions are pure and cannot declare `uses`. `public`, `public(package)`, and `@deprecated` may be used, but `@test` and `@builtin` may not. The third attribute argument names a function exported directly in the world, or a function inside an exported interface as `interface#function`, for example `bnt:test/api@1.2.0#add`. If the string contains `#`, the last `#` separates the interface export name from the function name; neither side may be empty (`E0815`). The interface name must match the export exactly, including its version; compatible versions are not substituted. `check`, `run`, and `test` check parameter counts and types by position and the result type before execution. Parameter names need not match. Missing-function diagnostics (`E1006`) list both direct exports and `interface#function` exports. Signature mismatches (`E1007`–`E1009`) suggest a declaration when every WIT type has a supported Benitoite representation; WIT parameter names such as `byte-start` become `byteStart`, `list<u8>` becomes `Bytes`, and omitted results become `Unit`.

The component path is relative to the root that owns the declaration, including for declarations in nested modules. It uses `/`, ends in `.wasm`, and cannot contain empty segments, `.` or `..`, hidden segments, or backslashes. Names must match directory entries exactly, including case. Resolved paths must stay under the root. For a dependency, or a root whose `package.bnt` declares a package, components must also stay under `wasm/`.

| Benitoite type | WIT type |
|---|---|
| `Integer8`, `Integer16`, `Integer32`, `Integer` (`Integer64`) | `s8`, `s16`, `s32`, `s64`, respectively |
| `Byte` (`UnsignedInteger8`), `UnsignedInteger16`, `UnsignedInteger32`, `UnsignedInteger64` (`UnsignedInteger`) | `u8`, `u16`, `u32`, `u64`, respectively |
| `Float32`, `Float` (`Float64`), `Boolean`, `Character`, `String` | `f32`, `f64`, `bool`, `char`, `string`, respectively |
| `Bytes`, `List[Byte]` | `list<u8>` |
| `List[T]`, `Option[T]`, `Result[T, E]` | `list<T>`, `option<T>`, `result<T, E>`, using the same correspondence recursively |
| `Pair[A, B]`, `Triple[A, B, C]` | `tuple<A, B>`, `tuple<A, B, C>` |
| Records with concrete type arguments | `record` with matching fields after substituting type arguments |
| `data` with concrete type arguments | `variant` with matching cases; zero arguments mean no payload, one means that type, two or more mean one flat tuple payload |
| `data` with only argument-free constructors | `enum` or a `variant` with no payloads |
| Other single-constructor `data` with one or more arguments | `tuple` when the WIT type is a tuple; match arguments by position, ignoring the constructor name |
| `Set[D]`, where D is concrete `data` with 1–32 argument-free constructors | `flags` with matching count, order, and names |
| `Map[K, V]` | `map<K, V>`; K must be `Boolean`, an integer type (including `Byte`), `Character`, or `String` |
| External type | `borrow<R>` in parameters, `own<R>` in results |
| `Unit` as the function result | No result |

Type aliases are expanded. `Option`, `Result`, `Pair`, and `Triple` must be the standard library types. For a `Unit` side of `Result`, omit that side in WIT: `Result[Unit, String]` corresponds to `result<_, string>`, and `Result[Unit, Unit]` to `result`. Other nested or parameter uses of `Unit`, including zero-element tuples, are unsupported. Records and `data` types from user modules and the standard library use the same structural rules. Their type names need not match WIT type names. Field and case counts, declaration order, names, types, and payload presence must match. Names are compared after removing `-` and lowercasing ASCII letters: `byte-start` matches `byteStart`, and `not-found` matches `NotFound`. Underscores are preserved and cannot match WIT names. Duplicate normalized names on either side of a record, variant, enum, or flags type are rejected.

`@extensible` does not relax these checks for `enum`, `variant`, or `record`, and does not allow unknown external tags. Adding a constructor or field still requires the WIT declaration to match the current Benitoite declaration exactly.

Concrete type arguments are substituted into fields and constructor arguments, so `Box[Box[Integer]]` is accepted when `Box[T]` contains a field of type T. External functions themselves remain monomorphic. Unresolved type/effect variables and recursive declaration dependencies, including recursion through `List` or `Option`, report `E1010`. Type expansion is limited to depth 100, 100,000 nodes per root type, and 1,000,000 nodes per check. Sharing one type between sibling fields is allowed. Structural mismatches report `E1008` or `E1009`, showing the WIT shape and the first mismatch in a `reason` note. A suggested declaration is omitted when its signature requires a user-defined record, variant, enum, flags element type, or resource handle, since Benitoite type names cannot be inferred.

An empty flags selection is allowed even though the flags type needs 1–32 items. Returned bits beyond the declared items are discarded. A map argument is sent in key order. Every returned entry is checked in its original order, including entries later discarded by duplicate-key normalization; the last value for each key wins, and the final map is ordered by key. Unsupported key types such as `Decimal`, `Bytes`, records, and `data` report `E1010` even if they are valid map keys inside Benitoite. `Set` is supported only as flags. Functions, `Decimal`, the resource types used with `with`, and tasks cannot cross this boundary. External types use the separate rules below.

For example, these declarations use the same components and exports as the repository's `external/wit-docs-values` executable example:

```text
record Box[T]
  value: T
end record
@external("wasm", "generic.wasm", "box")
function box(v: Box[Integer]) -> Box[Integer]
@external("wasm", "generic.wasm", "nested")
function nested(v: Box[Box[Integer]]) -> Box[Box[Integer]]

data D1
  F1
end data
@external("wasm", "flags.wasm", "f1")
function f1(v: Set[D1]) -> Pair[Set[D1], Integer]

@external("wasm", "maps.wasm", "result")
function result(v: Map[String, Integer]) -> Map[String, Integer]

data Four
  Item(Integer, Integer, Integer, Integer)
end data
@external("wasm", "tuples.wasm", "tuple4")
function tuple4(v: Four) -> Four

data Two
  Value(Integer, Integer)
  Empty
end data
@external("wasm", "variants.wasm", "fields")
function two(v: Two) -> Two
```

The corresponding WIT shapes are a record with `value: s64`, a nested record, `flags { f1 }` with a `tuple<flags-type, s64>` result, `map<string, s64>`, `tuple<s64, s64, s64, s64>`, and `variant { value(tuple<s64, s64>), empty }`. The sample guests return `42` from `box(Box(value: 35))`, `0` as the inner value of `nested(Box(value: Box(value: -7)))`, `Pair(Set.fromList([D1.F1]), 0)` from `f1(Set.empty())`, `[Pair("a", 2), Pair("z", 3)]` from `Map.toList(result(Map.empty()))`, `Four.Item(12, 14, 16, 18)` from `tuple4(Four.Item(1, 2, 3, 4))`, and `Two.Value(14, 29)` from `two(Two.Value(3, 7))`. These outputs describe the sample guests, not transformations imposed on arbitrary external functions.

#### External types and instance lifetime

Declare an external type with an `@external` attribute and a `type` declaration without `=` or a right-hand side. It names an exported WIT resource and has no type parameters. `public`, `public(package)`, and `@deprecated` are allowed. `@test` and `@builtin` are not. Missing or non-resource exports report `E1012`, listing resource exports.

```text
@external("wasm", "wasm/counter.wasm", "bnt:test/counter@0.1.0#cell")
public type Cell
@external("wasm", "wasm/counter.wasm", "bnt:test/counter@0.1.0#[constructor]cell")
public function newCell(start: Integer) -> Cell uses State
@external("wasm", "wasm/counter.wasm", "bnt:test/counter@0.1.0#[method]cell.bump")
public function bump(self: Cell, by: Integer) -> Integer uses State
```

An external type corresponds to `borrow<R>` in a parameter and `own<R>` in a result. These rules also apply inside lists, options, results, tuples, records, and variants. The declaration and function must refer to the same resource in the same component file. Parameters that take ownership (`own<R>`) are rejected (`E1008`). External values are opaque and cannot be compared for equality, used as map keys or set elements, or passed to `Assert.equal`. They have no default `Show` implementation; user implementations follow the ordinary rules for user types. They are separate from the resource types managed by `with`, so they cannot be used in `with`. A function that passes an external type but omits `uses State` reports `E0816` with an insertion edit. Other effect declarations are rejected with `E0812`; functions with external types receive an edit replacing the declaration with `uses State`. Effect checking happens during type checking, before component matching, so `E0816` or `E0812` can precede unsupported-type (`E1010`) or missing-resource (`E1012`) errors.

When an external value is collected, its handle is queued for destruction before the next call into its stateful instance. Destruction time depends on collection; methods that inspect shared guest state, and resource consumption, may therefore depend on collection time. There is no explicit destruction function. Destruction waits for collection, so retaining many non-external values can let repeatedly created and discarded external values reach the stateful instance’s memory limit (64 MiB by default). Functions whose signatures contain no external type, including `[static]` functions, create fresh instances and cannot inspect the stateful instance. Guest memory growth during a call that returns external values contributes to heap accounting to trigger collection; the first converted external value accounts for the whole increment. Execution end, interruption, or a failed call discards the stateful instance. Stateful calls are excluded from comparison with the reference interpreter.

#### Execution limits and statistics

External calls run synchronously. Functions that pass external types share one stateful component instance per component in each execution; other functions create a fresh instance on every call. During a call, other Benitoite tasks do not run and `Task.withTimeout` cannot cancel it. `SIGINT` and `SIGTERM` can interrupt Wasm execution and end the process with status 130. By default, each call has a fuel limit of 10^10, a total linear-memory limit of 64 MiB (over the lifetime of a stateful instance), and a value-transfer budget of 256 MiB in each direction. Fuel limits computation, not elapsed time. Each call also limits core instances, memories, and tables to 16 each, and each guest table to 10,000 elements. A `memory.grow` beyond the memory's own declared maximum returns -1 as in Wasm.

The checker selects a transfer route before execution. It calls the original guest function once and never retries through another route after a failure:

| Route in statistics | When used | Transfer accounting |
|---|---|---|
| `stateful` | A parameter or result contains an external resource type | Dynamic WIT values, retaining the component instance |
| `typed` | No resources; zero to three parameters and one result; all types are `Integer`, `Float`, `String`, `Bytes`, `List[Byte]`, `List[Integer]`, or `List[Float]`; numeric-list parameters require at most two parameters | Numbers cost zero, bytes one per element, numeric lists eight per element, argument strings their UTF-8 byte length |
| `adapter` | Other supported, nonrecursive values, including numeric widths outside the `typed` route, nested lists, maps, flags, general tuples, variants, and functions without a result | Actual packed bytes, including the 32-byte header and padding; a separate construction budget uses the same configured limit |
| `dynamic` | The adapter would exceed its 16 MiB generated-code limit or memory32 layout range, or the conservative core-instance estimate (including three adapter instances) would exceed 16 | Dynamic WIT values; the decision happens before the guest is called |

Aliases preserve route selection: `Integer64`, `Float64`, and `UnsignedInteger8` denote the same types as `Integer`, `Float`, and `Byte`. Adapters are composed per function, so adding a declaration for another function does not change its composition or instance-count estimate. Compiled components and generated adapters are reused within checking or one execution; there is no persistent cache. The adapter's memory, core instances, and tables count toward the same Store limits as the guest, and its instructions consume the same fuel and respond to the same interruption requests. Each adapter adds three core instances for memory, conversion, and fusion. The defaults do not increase to accommodate the adapter. Multiple copies can make adapter linear-memory use approximately three to four times the transfer size, so a value whose transfer size is below the transfer budget may reach the default 64 MiB memory limit. Original guest string encodings, including UTF-16, are handled by the Component Model; the adapter's packed strings are UTF-8. Guest post-return cleanup runs through the Component Model after values have been copied, and the host does not call it a second time.

For the adapter route, the transfer budget limits the complete packed argument and result byte sequences independently. A second budget limits the logical construction cost in each direction to the same `--wasm-transfer` value: 16 bytes per occurrence of a Benitoite value, plus string and `Bytes` contents. List elements, constructor fields, every map key/value, and selected flags constructors count as occurrences. A `Bytes` element does not add a separate 16 bytes; a `List[Byte]` element does. ABI-only root records, map-entry tuples, and tuples used to group a constructor's arguments do not add a Benitoite value. Duplicate map entries are counted and validated before normalization. Even zero-size ABI values count toward construction. This is logical construction cost, not allocated heap bytes or total process memory.

Dynamic routes count each list element as a host `Val` (40 bytes on supported platforms), including each byte of `Bytes`; maps count both key and value representations. Record fields include their WIT names and child representations; variants include the selected name and a representation for a present payload; enums and selected flags include name bytes. Children add their own costs. Scalars and resource handles cost zero. On the typed route, result strings are charged their guest-encoded byte length during lifting, while statistics report UTF-8 bytes. Thus the same value can reach the transfer limit differently depending on the signature and route. `Bytes` and `List[Byte]` keep distinct Benitoite result types. Arguments are checked and prepared before execution-time compilation or instantiation; returned lists are built directly into small leaves, without an intermediate array of Benitoite values for the whole list.

Value-size limits apply before construction: strings and `Bytes` at most 2^30 bytes, and lists at most 2^24 elements. Map and Set have no language-wide element-count limit. The transfer and construction budgets, fuel, and Store limits are checked even without statistics.

`run` and `test` accept `--wasm-memory=<size>`, `--wasm-fuel=<count>`, and `--wasm-transfer=<size>` to change these limits. Sizes are byte counts or integers with a `KiB`, `MiB`, or `GiB` suffix, from 1 MiB through 4 GiB. Fuel is a decimal integer from 1 through 2^64−1. Invalid or duplicate settings are usage errors (exit status 2). For `run`, put these options before the script path; `test` also accepts them between paths. Every test function uses the same configured limits.

`--wasm-stats` writes one JSON line to stderr at the end, including the configured `limits`, explicit `overrides`, `calls`, `functions`, `fuel`, `memory`, `arguments_transfer`, `results_transfer`, `stateful_instances`, and `reached_limits`. It also includes `routes` (call counts for `typed`, `adapter`, `dynamic`, and `stateful`), `fallback_reasons`, adapter-only `construction_bytes`, and `adapter_failures` with a numeric `code`, `requested`, `limit`, and `calls`. Each consumption object contains `total`, `maximum`, and `incomplete_calls`. `construction_bytes` aggregates argument and result logical costs so its maximum is the largest per-call sum; it is separate from packed transfer bytes. Typed, dynamic, and stateful calls do not increase `construction_bytes` or its `incomplete_calls`; only adapter calls stopped before the whole construction cost is measured increase that field. The memory total counts growth once; its maximum counts the whole call or stateful instance lifetime. Calls rejected during argument validation are included in the call count. Transfer totals include only calls whose values could be counted; unavailable consumption increases `incomplete_calls`. Dynamic and typed string statistics count host UTF-8 bytes, which may differ from the guest-encoded bytes charged during lifting. Adapter transfer statistics count the packed byte sequences. `test` aggregates all test executions into one report without a per-test breakdown. Without this option, output is unchanged. The public embedding API and reference interpreter keep the default limits.

Traps, ABI violations, and instantiation failures other than resource-limit failures stop execution with `R0601`; exhausted fuel reports `R0904`, memory, transfer, and construction limits report `R0905` with notes identifying the exhausted budget and the adapter failure stage when available, table-size and core object-count limits report `R0906` with the resource kind and required count, and returned-value-size limits report `R0902`. The diagnostic code and failure category are consistent across routes, but trap wording can differ: a guest ABI violation may surface while the adapter lowers a value or calls the guest. These failures are not converted to `Result.Error`. A component that returns an error through a declared `Result` returns an ordinary value.

Arguments and results can coexist in host memory. Dynamic WIT representations, typed arrays, packed adapter buffers, guest and adapter linear memory, and Benitoite values all consume memory. The configured transfer and memory budgets constrain different parts of this consumption; they do not bound total process memory.

These checks do not guarantee a component's result is correct or that it returns normally. Component compilation happens during checking as well as execution. Input components are limited to 256 MiB, but checking has no time or host-memory limit. Isolation of the interpreter, including checking untrusted components, remains the responsibility of the harness or OS; scripts have no runtime permission control.
