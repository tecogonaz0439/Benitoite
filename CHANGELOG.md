# Changelog

All notable changes to Benitoite are recorded in this file. Versions follow the policy in [Compatibility](docs/reference/benitoite.md#20-compatibility): while the major version is 0, a minor version may contain incompatible changes, and a patch version contains only bug fixes. Until `0.1.0`, any release may contain incompatible changes. Every incompatible change is listed with how to migrate.

## 0.0.8 (San Benito)

A source-only release; no executables are provided. `benitoite --version` prints `benitoite 0.0.8`. Review scripts and dependencies before updating `language` declarations and recorded package hashes.

### Added

- Operations may constrain value type parameters with traits, supertraits, `equality`, and `key`. Direct calls, function values, holes, pipes, and clause lambdas preserve the caller-selected implementations and public parameter contracts. Operations still cannot declare type constructor parameters, effect variables, or their own `uses`.
- `Benitoite.Unofficial.Failure` provides typed `Fail[E]`, non-resumable `raise`, and `fromResult` / `toResult` conversions. A failure clause returns the whole handle's result; nest handles to combine failure and ordinary clauses. One source effect set has at most one invariant failure type. A row beside explicit Fail in a signature excludes further Fail, including in callbacks; plain rows can propagate Fail. No Show or equality constraint is required. Put `toResult` outside a List.map to stop at the first failure, inside each child task to return a Result, and inside a lazy body to keep it pure. The conversions release nested resources and do not catch runtime errors, die/exit, cancellation, interruption, or external traps. Bare `try` and `or return` retain their existing meaning; IO still returns Result.
- `Benitoite.Unofficial.Json.Codec` provides pure Result-based conversion for primitive values, containers, and Option. Numeric kinds are strict; non-finite Float values fail. `ConversionError` is extensible and carries an outer-to-inner Field/Index/Key path to the first failure. Extra object keys use Key; Show quotes and escapes keys and does not automatically disclose input payloads.
- `Benitoite.Unofficial.Test.Property` provides pure Gen/Shrinker records, explicit seeded random state, bounded trials, and failure formatting. Config budgets are inclusive: trials 1..10000, size 0..10000, maxShrinks 0..100000. Invalid settings call no callbacks. Shrinking counts all candidate trials, including repeats; a reduced failure need not be minimal. Keep sizes small for container shrinking: candidate construction and deduplication may cost more than quadratic time and are not bounded by maxShrinks. One ordinary `@test` calls the library; `test --check` runs no callbacks.
- The development [derive tool](tools/derive/README.md) generates ordinary record codecs and Gen/Shrinker functions from resolved declarations. Use preview, review the manifest and diff, apply with the reviewed manifest SHA-256, then run ordinary check/test and derive check. Ordinary check does not detect every stale generated encoder. Noncyclic, nongeneric records and custom whole-field functions are supported; recursive/generic records require handwritten functions. Generation records preserve generatorVersion and config/structure/output hashes; replay also depends on type structures, callbacks, library rules, and concrete inputs. See the [two-level example](tools/derive/examples/People.bnt).

### Checking and harness interfaces

- `scripts/check.sh` separates work, stage, change, and release. Work runs relevant checks once, stage requires named checks, change covers the whole modification, and release validates the candidate separately. Legacy level-less `--only` and `--full` keep their previous sets. Unknown classification or base exits with 3, invalid arguments with 2. Long tests run in batches with nonzero success counts; release stack checks require ten successes. See the [testing policy](docs/design/07-quality/07-03-compiler-testing.md#実装の規約と静的な検査).
- Unhandled Fail on main or a test is rejected with E0506, including test --check. Handle or convert it within the entry. Fail is excluded from IO.All, effect reports, and --allow-effects names. Inspection report schemas and public CLI subcommands stay unchanged. New failures use E0513–E0518 for typed-effect arguments, incompatible joins, remaining rows, resume, unresolved caught error types, and mixed clauses.
- Formal exchange output uses corpus 11 and builtins/stdlib/coverage/coverage-program 4 for operation dictionaries, typed Fail, and row conditions. These development formats are separate from the unchanged public report formats.

### Incompatible changes and migration

- Character literals and ranges now establish exhaustiveness when they cover all Unicode scalar values, including nested patterns and full-range bindings. A catch-all after an unguarded full-domain range is rejected with `E0602`; a redundant alternative in the same branch uses `E0608`. Remove the unreachable branch after reviewing its body, or move intended work into a reachable branch. Keep the catch-all for guarded ranges and for Integer ranges. For example, `case '\u{0}'..'\u{10ffff}' ->` needs no following `case _ ->`.
- `E0601` character witnesses now show the smallest valid scalar in an uncovered interval instead of `_`. A match containing only `'a'` reports `'\u{0}'`. Visible ASCII uses character literals, newline/carriage return/tab/backslash/single quote use their escapes, and other scalars use unpadded lowercase Unicode escapes. Update diagnostic snapshots that depend on the old witness text.
- Declarations older than `0.0.8` report `E0908`, including pure scripts. All applicable migration notes appear in version order; `0.0.9` is a future version (`E0907`). Review match bodies and dependencies first, then set `language "0.0.8"` in entry/root settings and dependency settings. Run `benitoite package update` after dependency contents are final. Changing a declaration alone does not migrate code; omitting it uses the current rules.

## 0.0.7 (San Benito)

A source-only release; no executables are provided. `benitoite --version` prints `benitoite 0.0.7`. Review scripts and dependencies before updating their `language` declarations and recorded package hashes.

### Incompatible changes and migration

| Previous form or behavior | `0.0.7` behavior | How to migrate |
|---|---|---|
| `Command.environment` could explicitly set names starting with `DYLD_` or `LD_`. | `IO.Process.run` and `runAttached` return `Result.Error` with `IOErrorKind.InvalidInput` before starting a child. Matching ignores ASCII case and covers both entire prefixes, including build-tool variables such as `LD_RUN_PATH`. Empty values and explicit overrides with the same value as the parent are also rejected, on every supported OS. The error message identifies the name and does not disclose its value. | Review explicit environment settings and remove or redesign operations that require these variables. This covers build-tool settings as well as shared-library settings. Handle `InvalidInput` as an ordinary error result. Parent environment inheritance is unchanged, including for `shell`; this rule does not sanitize the inherited environment or provide a sandbox. Moving rejected settings into the parent environment is not a migration recommendation. |
| Declaring `language "0.0.6"` passed the release boundary. | Every older declaration reports `E0908`, even in a pure script. Notes and helps enumerate all applicable incompatible releases in version order. `language "0.0.7"` is accepted and `language "0.0.8"` reports `E0907`. | Review scripts and dependencies first, then update declarations in entry scripts, root settings, and each dependency's `package.bnt` to the current interpreter version (`language "0.0.7"` for this release). Recompute recorded dependency hashes with `benitoite package update` after all dependency contents are final. Omitting `language` continues to use the current rules; an old declaration does not restore the previous environment behavior. Changing the declaration alone does not migrate the code. |

### Harness interfaces

1. `benitoite check --report=json <file>` returns a single, versioned report containing the checked main contract, canonical atomic effects, source identities and SHA-256 hashes, diagnostics, and references to `IO.Process.shell`. It checks through external-function linking without executing the program. Reports describe declared contracts, not which operations will actually run.
2. `benitoite test --check [--report=json] <paths...>` checks the same targets selected by normal test discovery without running any test. The JSON report includes each target and test contract, preserves partial results on failure, and includes `Assert.Check` in declared effect sets.
3. `--allow-effects=<comma-separated-effects>` on `run` and `test` compares declared atomic effects with an explicit upper bound before execution. An empty value permits only an empty set. `E0512` reports an exceeded bound with exit status 2. With the option, test execution prepares and checks all selected entries before starting any test; a failure prevents the entire selected set from running. Without it, files are still prepared and run one at a time. This is a static contract check, not runtime permission enforcement or OS isolation.
4. `benitoite --version=json` returns the producer version, build commit and dirty information with provenance, target, supported format versions, and loader-environment policy. Unknown build information is `null`; dirty state is not automatically collected. The existing two-line `--version` output and diagnostic/test-result JSON Lines retain their formats.
5. `Command.environment` rejects explicit `DYLD_` and `LD_` settings as described above. The shared validation covers `run` and `runAttached` and leaves inherited variables unchanged.
6. `benitoite skill list [--format=text|json]` lists embedded logical document names, and `skill show [--format=text|json] <logical-name>` retrieves one document without installation or a HOME lookup. JSON includes byte lengths and SHA-256 hashes of the same version-substituted UTF-8 bodies used by installation. Logical names are case-sensitive and must match the embedded list.

See the [CLI reference](docs/reference/benitoite.md#2-the-command-line) and the embedded Skill's [inspection guide](crates/benitoite/skill/references/inspection.md) for invocation and report contracts. Static checks do not guarantee intended results, successful external operations, termination, or access restrictions.

## 0.0.6 (San Benito)

A source-only release; no executables are provided. `benitoite --version` prints `benitoite 0.0.6`. Migrate scripts and dependencies before updating their `language` declarations and recorded package hashes.

### Incompatible changes and migration

| Previous form or behavior | `0.0.6` | How to migrate |
|---|---|---|
| `die` could be an identifier, including an argument label or a member name. | `die` is a reserved keyword (`E0216` when used as a name). A standalone `die` reports `E0201` with help to use `try value or die`. The keyword set has 35 words. | Rename user-defined names spelled `die` and their references. `fn`, `pub`, `impl`, `async`, `await`, `spawn`, `select`, `extensible`, and `mut` remain usable as names. |
| Matches could enumerate all known cases of the standard failure types; bindings could destructure their known fields. | `IOErrorKind`, `NetworkErrorKind`, `Json.ParseError`, and `Csv.ParseError` are `@extensible`. Outside the defining package, matches and bindings must also cover future shapes (`E0601` / `E0607`). | Add an unguarded `case other` or `case _` to a match, including nested matches. Bind the whole value or `_` instead of destructuring it in a binding. A record's `..` covers only declared fields. Construction, updates, and getters retain their declared field contracts. `Result` and `Option` remain closed. |
| A return value could start on the line after a standalone `return`. | The newline immediately after `return` ends the statement; a missing value reports `E0201` with help to start on the same physical line. This also applies after `or return`. | Start the value on the same physical line, for example `return if condition then`. After the value starts, it may continue over multiple lines, including parenthesized expressions, calls, operators, and branches. |
| Declaring `language "0.0.5"` passed the release boundary. | Declarations before `0.0.6` report `E0908`; versions before `0.0.5` receive both releases' migration notes and helps, in version order. Future declarations report `E0907`. | First migrate the code, then set `language "0.0.6"` in the entry script or root settings and in each dependency's `package.bnt`. Recompute recorded hashes with `benitoite package update` after changing dependency contents. Omitting `language` uses the current rules. Changing the declaration alone does not migrate the code. |

### Explicit failure actions and diagnostics

- Use `try value or return` in reusable functions to return `Result.Error` or `Option.None` from the innermost function or lambda. Bare `try value` keeps that same meaning permanently; it is accepted and has no deprecation warning.
- Use `try value or die` or `try value or die(message)` at script entry points when failure should terminate execution. `die` requires a `Result` or `Option` operand and `Process.Exit`; a `Result` error requires `Show`. The message is a pure `String` expression evaluated only on failure, before formatting the error value. Import `Benitoite.Unofficial.IO.Process` when naming the effect. The operation writes the failure report to standard error and exits with status 1; successful `Option.Some` and `Result.Ok` continue with their contained value.
- `IOError`, `NetworkError`, `Json.ParseError`, and `Csv.ParseError` implement `Trait.Show`, returning their `message` string unchanged. The implementations for IOError and NetworkError live in `Benitoite.Trait`; the ParseError implementations live in Json and Csv. Explicit calls to `Trait.Show.show` require `import Benitoite.Trait`; `or die` connects its Show reference internally.
- A die failure is reported as `error: explicit failure exit`, followed by its source location, optional `message:`, and `cause:`, in that order. With `--diagnostics=json`, the report has `kind: "die"` and `code: null`.
- In `benitoite test`, die fails only that test, and the runner continues with the next one. A language handler can replace the existing `Process.Exit` operation; it receives only the usual exit code, and the handled call's report is discarded rather than attached to a later exit.
- `or` in an explicit try action is separate from Boolean `or`. The `or return` action takes no value, and `or die` accepts at most one parenthesized message; invalid actions report `E0258`. Parenthesize an explicit try expression before continuing with another operator or call (`E0259`). A die message cannot directly escape with `return` or `try` (`E0218`); an unavailable outer continuation reports `E0509`. An effectful message reports `E0511`; missing `Process.Exit` and unsatisfied `Show` constraints use the existing effect and type-class diagnostics.
- Add `@extensible` on `data` and record declarations. It takes no arguments (`E0817`); `E0801` now lists it. `E0601` and `E0607` may show a future-shape witness, a secondary location at the type declaration, and help to cover future values. These are static errors with exit status 2.
- `E0908` lists every applicable incompatible change. Notes include each version and summary; helps provide corresponding migration guidance in the same order, without source edits. The main message identifies the first applicable version.
- The unknown `?` operator's `E0211` help now suggests `try parse(text) or return`. Invalid try-action positions retain `E0218`; existing bare-try type checks and their diagnostics remain in place.

## 0.0.5 (San Benito)

A source-only release; no executables are provided. `benitoite --version` prints `benitoite 0.0.5`. This release changes calls, function types, and callback contracts together. Scripts written for `0.0.4` or earlier need the migration below.

### Incompatible changes and migration

| Previous form or behavior | `0.0.5` | How to migrate |
|---|---|---|
| Ordinary calls could pass two or more arguments by position, such as `List.map(xs, action)`. | Functions with two or more parameters require every explicit argument to be named (`E0449`); labels can appear in any order, and expressions run in source order. | Write `List.map(xs: xs, f: action)`. Use the declared names and preserve the original expression order. Zero-parameter calls use `f()`; one-parameter calls can still use `f(value)`. Direct data construction, patterns, attributes, handler bindings, and `resume` keep their existing rules. |
| Function types omitted parameter names, such as `function(Integer) -> String`. | Every function-type parameter needs a name (`E0257`), including nested callback types. Function values must match the contract's names and order (`E0454`). | Use the required contract, for example `function(value: Integer) -> String`, and rename a lambda and its bound references together, checking for capture. Use an explicit wrapper when an existing function has a different contract, for example `lambda(value) return Integer.toString(value)`. |
| Higher-order callbacks could differ in parameter names. | Names remain part of the contract through inference, annotations, and higher-order calls. An unresolved calling contract reports `E0455`. | Follow the callback declaration's names, including unused parameters; add a named function-type annotation when needed. Do not invent numbered names for ordinary function parameters. Existing outer parameter names in the standard library are unchanged. Main nested callback names are `value` for `List.map`, `acc, value` for `List.fold`, `key, value` for `Map.map`, and `error` for `Result.mapError`; the installed Skill lists every declaration. |
| Pipes and calls with `_` holes could use multiple positional arguments. | A pipe supplies the first parameter; remaining explicit arguments use labels. Holes use the target parameters' names, in source order, as the generated function's contract. | Write `xs \|> List.map(f: action)` and `Integer.subtract(a: _, b: 1)`. Check the generated contract against its expected type. Keep fixed expressions inside the call so they still run when the generated function is called. Constructor function values use `arg1`, `arg2`, … for positional data fields, and field names for records; direct constructor calls and patterns keep their existing rules. |
| A lambda whose body began on the header line could continue onto another line. | A body beginning on the header line must finish on that physical line. A lambda whose body is one statement on the header line can omit `end lambda`. | Keep `lambda(value) return value` on one line, or start the body on the next line and close it with `end lambda`. An explicit `end lambda` is still allowed on the same line. The formatter preserves the chosen ending. |
| Older `language` declarations passed the compatibility check. | Declarations before `0.0.5` report `E0908` with this migration's subject; future versions report `E0907`. Omitting `language` uses the current rules. | Migrate the code, then change the declaration to `language "0.0.5"` in the starting script or root settings, and in each dependency's `package.bnt`. Recompute recorded package hashes with `benitoite package update` after changing dependency files. Changing the version alone does not migrate syntax. |

The following diagnostic codes are added. Tools that read JSON diagnostics should use these codes and fields rather than match message text.

| New code | Meaning or replacement |
|---|---|
| `E0254` | A lambda without `end lambda` crosses a physical line. |
| `E0256` | Directly nested lambdas need parentheses around the inner lambda when either omits its terminator. |
| `E0257` | A function-type parameter has no name. |
| `E0449` | An ordinary function with two or more parameters requires named arguments. |
| `E0450` | A call mixes named and positional arguments. |
| `E0451` | An argument label does not name a parameter. |
| `E0452` | A parameter is supplied more than once, including a pipe's implicit first argument. |
| `E0453` | A named call omits required arguments. Missing named arguments use this code instead of `E0402`; the report identifies the call site and the missing names in declaration order, without the `function declared here` secondary location. |
| `E0454` | Function parameter names or order do not match the expected contract, including implementation methods and nested function types. |
| `E0455` | A function's parameter names and order cannot be determined. |
| `E0456` | A direct data constructor call uses named arguments. |

The approved diagnostic mapping changes `add(1)` with parameters `left, right` from `E0402` to `E0453` after migration to `add(left: 1)`; `right` is the missing name. Positional argument-count errors for a one-parameter function and direct data constructors continue to use `E0402`. Calls left in the multiple-positional form report `E0449` first; an extra label in a migrated call reports `E0451`.

To migrate a script:

1. Install the matching Skill with `benitoite skill install`, then look up each declaration. Add labels without moving argument expressions. Preserve the separate syntax of direct constructors, patterns, attributes, handler bindings, and `resume`.
2. Give every function-type parameter its intended contract name. Rename callback parameters and their bound references together, checking for capture by inner bindings. Keep required names even for unused parameters; use explicit wrappers for functions with another contract. Do not infer contract order from call-label order or invent numbered names for ordinary function parameters.
3. Label the explicit arguments remaining after a pipe's first parameter. For holes, check the generated parameter names and their source order against the expected function type. Keep the callee and fixed expressions inside the generated function so that their execution time does not change.
4. Keep a one-statement lambda on its header line, or start the body on the next line and end it with `end lambda`. For example, change `List.map(xs, lambda(x) return Integer.toString(x) end lambda)` to `List.map(xs: xs, f: lambda(value) return Integer.toString(value))`.
5. Update `language` declarations only after updating the code, including each dependency's `package.bnt`. Run `benitoite package update` to recompute changed dependency hashes and review the reported effects.
6. Run `benitoite check` on scripts and `benitoite test` on tests, and confirm output and effect declarations. `benitoite fmt` preserves argument order and the chosen lambda ending; it does not migrate calls or rename callback parameters.

For `E0451`–`E0453`, read the available or missing parameter names. For `E0454`, compare names position by position and use a wrapper when necessary. For `E0455`, add a named function-type annotation. Check each suggested edit's target declaration before applying it. See [Functions and lambdas](docs/reference/benitoite.md#6-functions-and-lambdas) for the current rules.

### Changed

- Prefer `match` for selecting a value or action and `if` without `else` for a conditional action or early return. `else`, `else if`, and `shadow` remain valid and produce no warning; prefer descriptive fresh names over `shadow`.
- Prefer a fresh binding such as `case other ->` or `case otherCode ->` for a final catch-all branch. These are ordinary names, not keywords. `case _ ->` remains valid without a warning; `_` inside constructor patterns, discarded bindings, and partial applications is unaffected.
- The formal model, proofs of type preservation and soundness, and differential checks now include parameter names and named calls, including pipes and holes. The release uses one set of language rules; declaring an old version does not select an old grammar.

## 0.0.4 (San Benito)

A source-only release; no executables are provided. `benitoite --version` prints `benitoite 0.0.4`. Some scripts that `0.0.3` accepted are now rejected; they are listed below with how to migrate.

### Added

Packages and external functions are experimental. Their spelling may change as the syntax is revised; they follow the same [compatibility policy](docs/reference/benitoite.md#20-compatibility) as the rest of the language. Usage is described in [Experimental: packages and external functions](docs/reference/benitoite.md#21-experimental-packages-and-external-functions).

- Add `Integer8`, `Integer16`, `Integer32`, `UnsignedInteger16`, `UnsignedInteger32`, `UnsignedInteger64`, and `Float32` as distinct numeric types, with checked integer arithmetic, comparisons, conversions, parsing, display, bit operations, and standard functions. Unsigned subtraction below zero overflows; unsigned unary minus is rejected. `Float32` rounds to binary32 after each operation. New integers support keys, `Show`, and `Order`; `Float32` supports `Show` and `Order`, but not keys.
- Add width-qualified canonical names with type-identical aliases: `Integer64` = `Integer`, `Float64` = `Float`, `UnsignedInteger8` = `Byte`, and `UnsignedInteger` = `UnsignedInteger64`. Keep `Integer`, `Float`, and `Byte` as the main displayed names, and retain `Byte`'s lack of arithmetic. All numeric types and alias modules are in the prelude.
- Add provisional numeric suffixes `s8`–`s64`, `u8`–`u64`, `f32`, and `f64`, preserving integer bases and digit separators. Unsuffixed literals keep `Integer`/`Float`; no implicit conversions are added. Suffix spelling may change as the syntax is revised. Check literal ranges statically, including directly negated signed minima and the entire unsigned 64-bit range. Extend constant-expression errors and ordinary-expression overflow/division warnings to the new types.
- Add `public(package)` declarations for sharing names within a package, including the starting root. Constructors, fields, methods, and operations inherit visibility; contracts reject less visible types, traits, and effects. Report invalid visibility arguments as `E0253`, explain package-only names in `E0330`, and format the modifier without spaces. Package effect reports count only `public` declarations.
- Add file headers for `language`, local `dependency` declarations, and `package` metadata. Validate fields, version syntax, declared language compatibility, and placement. Dependencies and language declarations belong in the starting file or the root's `package.bnt`; duplicates across the two are errors. `fmt` formats settings files.
- Resolve local dependencies from their `package.bnt`, including paths outside the root. Packages require a name and language version, and cannot declare dependencies. Dependency roots cannot contain the starting root, equal another dependency root, or contain one another. Import package modules through dependency aliases; imports inside packages use their own root. Report ambiguous root/package imports, allowing both paths when they refer to the same file, and require aliases for files inside dependency roots. Include imported package modules in name resolution and type checking, report their errors, and suppress their warnings even with `--deny-warnings`. Diagnostics identify package paths and avoid suggesting edits to private dependency declarations.
- Verify local dependency contents when a valid `hash` is declared, using deterministic SHA-256 hashes of included paths and file contents. Include all non-hidden subdirectories under the root's `wasm/`; skip hidden entries and invalid UTF-8 names. Reject symbolic links in visited non-hidden entries, colliding lowercase included paths, newline-containing paths, unreadable files, and packages over 10,000 included files, 100,000 visited entries, or 128 MiB. Failures are reported in deterministic order.
- Add `benitoite package add`, `update`, and `move`. Record hashes and built-in effects from public function and trait-method declarations, type aliases, record fields, and `data` constructor fields using official library import names, report changes from stored effect records and component imports, preserve source bodies and comments, and attempt to restore settings if moving an entry header fails. Bulk updates leave dependencies without hashes unchanged and report when there are no targets. Dependencies can store an `effects` field; `check` and `run` validate its shape (`E0929`), and `update` repairs malformed hashes or effect records. Effect reports read declarations without type-checking, omit user-defined effects and effect variables, and do not grant runtime permissions. Moving headers preserves comment-only settings files, including CR LF and comment whitespace. New settings files omit executable permission bits, directory targets for `move` report a usage error, and explicitly naming missing settings does not edit another file. Validation reports target dependency settings errors regardless of path spelling; diagnostics identify proposed edits that have not been written.
- Add `@external("wasm", "path.wasm", "name")` declarations for WebAssembly Component Model functions. Functions with external types in their signatures require `uses State`; other external functions are pure. Check component paths, absence of imports, direct or interface exports (using `interface#function` with an exact interface name including its version), and concrete parameter/result types before execution. Apply the `wasm/` path restriction to dependencies and to roots whose `package.bnt` declares a package. Diagnostics identify unsupported inner types and same-named user types by their declarations, and distinguish invalid components and inaccessible paths. Report empty names on either side of the last `#` as `E0815`. Missing-function diagnostics list nested functions and explain version mismatches or interface-only names; signature mismatches suggest a Benitoite declaration when all WIT types can be mapped.
- Execute external calls synchronously with a default fuel limit of 10^10, a default total linear-memory limit of 64 MiB per call (over the lifetime of a stateful instance), and a default 256 MiB value-transfer budget in each direction. Retain one stateful Wasmtime instance per component per execution for external type calls and reset call fuel and transfer budgets before each call. Queue collected handles for destruction before the next call and include guest memory growth in heap accounting to trigger collection. Functions without external types in their signatures create fresh instances on each call. Stateful calls are excluded from reference-interpreter comparisons. Direct calls and function values share the same path. Check and prepare arguments before compiling or instantiating components or processing deferred destruction, so transfer-budget errors take precedence over start traps. Sum typed argument transfer costs across all parameters. SIGINT and SIGTERM interrupt running Wasm; task timeouts do not. Traps, component ABI violations, and other instantiation failures report `R0601`; fuel exhaustion reports `R0904`, memory and transfer limits `R0905` with distinct notes, core instance/memory/table counts (16 each) and table-size limits (10,000 elements per table) `R0906`, and returned-value-size limits `R0902`. Deferred-destruction trap reports identify resource destructors. Resource-limit failures during instantiation are reported as resource errors. A `memory.grow` beyond the guest memory's declared maximum returns -1 before testing the host memory budget.
- Declare opaque external types with `@external("wasm", "path", "interface#resource") type Name`. External functions borrow these values in parameters and own them in results, including inside supported aggregate types, and must declare `uses State`. Check resource and component identity before execution; reject ownership-taking parameters. Report missing resources as `E1012` and missing `uses State` as `E0816` with an insertion edit. When such a function declares other effects, the `E0812` repair edit replaces them with `uses State`.
- Keep typed Wasmtime calls for the existing zero-to-three-parameter combinations of `Integer`, `Float`, `String`, `Bytes`, `List[Byte]`, `List[Integer]`, and `List[Float]`; numeric-list parameters require at most two parameters. Keep their existing transfer accounting and old type displays. Other supported nonrecursive ordinary values use generated WASM adapters, including new numeric widths, nested lists, maps, flags, general tuples, variants, and functions without results. Calls containing external resources retain the stateful dynamic route. Select routes before execution and never retry after a failure. If generation exceeds 16 MiB of adapter code or the memory32 layout range, or the conservative core-instance estimate including three adapter instances exceeds 16, select the dynamic route before calling. Compose adapters per function so another function declaration does not affect that composition or its instance-count estimate. Reuse compiled components and generated adapters within a check or execution, with no persistent cache; pure calls still create a fresh Store each time.
- Expand WIT correspondence to all numeric widths, concrete type arguments in records and `data`, single-constructor tuples of one or more elements, and multi-argument variant constructors represented by one flat WIT tuple payload. Add flags as `Set` of concrete `data` with 1–32 argument-free constructors, and maps with Boolean/integer/Character/String keys. Validate every returned map entry before normalization, keeping the last value for duplicate keys and returning key order. Keep normalized-name checks, rejection of recursive types, and type-expansion budgets (depth 100, 100,000 nodes per root, 1,000,000 nodes per check). Require `State` according to substituted fields that actually contain external resources.
- Count adapter transfer as actual packed bytes, including the 32-byte header and padding. Separately limit logical value construction in each direction with the same `--wasm-transfer` value: 16 bytes per Benitoite value occurrence plus string/Bytes contents. Count List elements, constructor fields, map keys/values (before duplicate normalization), and selected flags; Bytes elements and ABI-only grouping tuples do not add separate value occurrences. Include adapter memory and core objects in existing Store limits and adapter instructions in fuel/interruption handling. Keep the existing defaults and value-size limits. Each adapter adds three core instances for memory, conversion, and fusion. Multiple copies may require approximately three to four times the transfer size in linear memory and reach the default 64 MiB limit even for values accepted on a previous route. Transfer and construction budgets do not bound total process memory. Diagnostic codes and categories stay consistent across routes, but guest trap and ABI-violation wording may differ. Report construction-budget exhaustion as R0905 and distinguish adapter failure stages; guest traps and ABI violations remain R0601.
- Add `--wasm-memory`, `--wasm-fuel`, and `--wasm-transfer` to `run` and `test`, keeping the existing defaults. Memory and transfer budgets accept byte counts or `KiB`/`MiB`/`GiB` sizes from 1 MiB to 4 GiB; fuel accepts positive 64-bit integers. Add `--wasm-stats` for a single aggregate JSON report on stderr, including configured limits, call counts, consumption totals and maxima, stateful instance memory, and exhausted limits. Include route counts (`typed`, `adapter`, `dynamic`, `stateful`), fallback reasons, adapter-only `construction_bytes` (the sum of both directions), and adapter failures with code, requested amount, limit, and call count. Typed, dynamic, and stateful calls do not increase `construction_bytes` or its `incomplete_calls`; only adapter calls stopped before complete construction accounting increase that field. Identify per-function statistics by component path and declaration name. Test runs aggregate all test functions in one report. Reject values attached to `--wasm-stats`, including an empty value, with a message that the option does not take a value.
- Include Wasmtime 49.0.2 with Cranelift; additional permissive dependency licenses are accepted.
- Building from source now requires a C compiler (Xcode command line tools on macOS, `cc` on Linux).

### Incompatible changes

The name `package.bnt` now denotes a settings file. External signatures newly using the adapter route use packed transfer and logical construction accounting instead of dynamic WIT accounting. An existing value can therefore reach `--wasm-transfer`, memory, or object limits differently; inspect `--wasm-stats` and adjust the explicit limits or split the value when needed. Defaults remain unchanged.

| Change | Diagnostic | How to migrate |
|---|---|---|
| `run`, `check`, and `test` read the root's `package.bnt` as settings. Previously, an unrelated file with that name was ignored. Imports or declarations in it are now rejected. | `E0912` | Rename an existing source file to another `.bnt` name. Keep only header settings in `package.bnt`. |
| `package.bnt` cannot be the starting file for `run`, `check`, or `test`. | `E0913` | Rename an existing starting script and pass the new path, or run a separate starting file that uses these settings. |
| `benitoite test <directory>` skips `package.bnt` and nested directories that contain their own `package.bnt`. | — | Rename ordinary test source files previously called `package.bnt`. Test nested packages by specifying each package's root separately; rename unrelated files with that name if the directory should remain part of the outer test scan. |

### Fixed

- A broken symbolic link in a directory no longer makes module lookup fail.

## 0.0.3 (San Benito)

A source-only release; no executables are provided. `benitoite --version` prints `benitoite 0.0.3`. Some scripts that `0.0.2` accepted are now rejected; they are listed below with how to migrate.

### Incompatible changes

`benitoite check` now rejects some scripts that `0.0.2` accepted. Each of them could stop with an internal error or a runtime error, contained code that never runs, could hide an effect behind another name in `uses`, or could make the check use exponential time and memory.

| Rejected form | Diagnostic | How to migrate |
|---|---|---|
| `resume` in a `match` guard, such as `case x if resume(x) -> ...` | `E0509` | Call `resume` in the body of the branch. A guard is evaluated once, and if it is `false` the continuation can no longer be resumed. |
| `resume` in an argument of a call with `_` placeholders, such as `add(resume(10), _)` | `E0509` | Call `resume` outside the call, bind its result, and pass the name. The arguments are evaluated inside the function that the call creates. |
| `return` or `try` in an argument of a call with `_` placeholders whose value does not fit the created function, such as `add(return "text", _)` in a function that returns `String` | a type error such as `E0401` or `E0441` | `return` and `try` there leave the created function, not the enclosing one. Compute the value before the call. |
| A statement after a statement that always leaves (such as `return`) inside the body or a clause of `handle`, or inside `try` | `E0439` | Remove the statements that never run. The error is now reported once per block, at the first such statement. |
| An alternative of a guarded branch that an earlier alternative of the same branch covers, such as the second `1` in `case 1, 1 if g ->` | `E0608` | Remove the alternative; it is never selected. |
| Constants whose values together exceed 64 MiB | `E0435` | Compute a large value in a function without parameters, which runs when the script runs. |
| `as` on an import of a module that declares built-in effects (`IO.Console`, `IO.File`, `IO.Process`, `IO.Clock`, `IO.Random`, `Network.Http`, `IO`, `Assert`), such as `import Benitoite.Unofficial.IO.File as Console`, also when the new name is the original one | `E0339` | Remove `as` and refer to the module by its own name, such as `File.readText` and `uses File.Read`. If the name collides with another import, rename the other import. The alias could make `uses` show an effect name that does not match the operation, such as `uses Console.Write` for writing files. |
| A `match` or a pattern of `bind` or `shadow` whose coverage check needs more work than a fixed limit | `E0609` | Split the `match` into smaller ones, or check fewer fields in one branch or pattern. Before, such a check could use exponential time and memory. |
| A trait constraint whose dictionary is too large, such as implementations nested many levels deep that each require two or more traits of the same type parameter | `E0715` | Nest the types less deeply, or require fewer traits of the type parameters in the implementations. Before, resolving such a constraint could use exponential time and memory. |

Some functions and commands also behave differently.

| Change | How to migrate |
|---|---|
| `Csv.formatWith` stops with a runtime error (argument out of domain) when `delimiter` is not an ASCII character, as `Csv.parseWith` already did. Before, it wrote such a delimiter, and the output could not be read back with `Csv.parseWith`. | Use an ASCII delimiter, or join the fields yourself with `String.join`. |
| After a write to a `File.Writer` fails (including a write that flushes the buffer), the writer keeps the error. Later `File.write`, `File.writeLine`, and `File.writeChunk` return the same error without writing, the data left in the buffer is discarded, and `File.closeWriter` returns the same message with `IOErrorKind.Other`. Leaving a `with` block that holds such a writer is a release failure (a runtime error). Before, later writes could succeed and the buffered data was written again on the next flush. | Stop writing at the first error. Call `File.closeWriter` at the end of a `with` block to handle the error, and open the file again to retry. |
| The HTTP server answers 400 to a request target containing `#`, in any form, and does not call the handler. | Omit `#` and the fragment that follows it, or encode a literal `#` as `%23`. |
| The HTTP server answers 400 without calling the handler for targets that do not begin with `/` or `http://` or `https://`, except `*` for uppercase `OPTIONS` and `host:port` for uppercase `CONNECT`. Uppercase `CONNECT` accepts only `host:port`, with a non-empty host and a port of ASCII digits from 0 to 65535; `CONNECT /path` and absolute targets are rejected. Any target containing a literal `"`, `<`, `>`, or a non-ASCII character is also rejected. Before, these targets were passed to the handler. | Send a target beginning with `/`, or the appropriate form for `OPTIONS` or `CONNECT`; percent-encode `"`, `<`, `>`, and non-ASCII characters. |
| `Decimal.parse` returns `Option.None` for an integer part that starts with `0` and has more digits, such as `"01.5"`, `"007"`, or `"-01.5"`, as `Decimal` literals, `Integer.parse`, and `Float.parse` already did. `"0"`, `"0.5"`, and `"-0.5"` are still accepted. | Remove the leading zeros before calling `Decimal.parse`. |
| `benitoite fmt` does not replace a file whose owner has no write permission (such as mode `0444`), a file with more than one hard link, or a file owned by another user. It reports `E0125` with the reason and leaves the file unchanged. `fmt --check` still checks these files. | Make the file writable for its owner, remove the other hard links, or run `fmt` as the owner, and then format it. |
| `run`, `check`, `test`, and `fmt` read scripts and modules only from regular files. A path to a pipe, such as `benitoite check /dev/stdin` with a pipe or `benitoite run <(...)`, is reported as `E0101`. | Write the script to a temporary file and pass that path. |
| `run` and `test` report `L0112` and do not run the script when the decision tree of a `match` is too large, or when the decision trees in one definition need too much work in total. `check` does not report it. Before, such a `match` could use exponential time and memory. | Split the `match` into smaller ones, or move parts of it into separate functions. |
| `Task.withTimeout` returns `Option.None` when the task finishes at or after the deadline. Before, it could return `Option.Some` with the result of a task that finished after the deadline. The deadline is checked when tasks are next switched, so a task that finishes just before the deadline can also give `Option.None`. | Give a longer time if the result is needed in these cases. |
| `Http.respond` with a status from 100 to 199 is a runtime error (`R0701`). Before, the `1xx` status was sent as the final response. | Respond with a status from 200 to 599. |
| The HTTP server answers 400 to an HTTP/1.1 request without a `Host` header, to a request with two or more `Host` headers, to a `Host` value with characters other than letters, digits, and `-._~!$&'()*+,;=:[]%`, and to an absolute request target (`GET http://host/path`) whose authority is empty, contains `@`, or contains such characters. The handler is not called for these requests. | Send exactly one valid `Host` header in HTTP/1.1 requests. |
| When the input of `Json.parse` has both a number out of range and a syntax error, the error that comes first in the input is returned. Before, the syntax error was returned even when the number came first. | Update code or tests that expect the line, column, or message of `Json.ParseError` for such input. |
| `Json.ParseError.column` of an error at the end of the input, such as an unclosed array or string, points just after the last character. Before, it pointed at the last character unless the input ended with a line feed. | Update code or tests that expect the column of an error at the end of the input. |

### Changed

- Type mismatches where a declared return type or binding annotation determines a variable now keep errors in uses of that variable at their original locations. When a binding annotation and a `return` disagree about a variable's type, the error is now reported where the variable's value conflicts with the annotation, instead of at the `return`.

- Body diagnostics now show rigid type parameters with their operation names when needed and unresolved types as `_`; missing rigid constraints point to the operation declaration, and interpolation of type parameters reports `E0422`. Its help uses the module's `Benitoite.Trait` import alias or asks for the import before suggesting a `Show` constraint and conversion. For operation type parameters, it explains why conversion is unavailable and asks for a value of a known type.

- `E0218` now specifies that `return` and `try` are allowed inside an explicit `lambda ... end lambda` in a `lazy` body or `match` guard, and explains that the function and arguments of calls with `_` placeholders are not exempt.

- Text diagnostics escape terminal and bidirectional formatting controls in headers, labels, notes, help, trace names, waiting descriptions, and backtraces. JSON output is not escaped. Multiline notes and help omit one final line feed. Excerpts and suggested edits omit the initial UTF-8 BOM and align markers with escaped text.

- Internal reports identify panics caught on the main thread, describe each panic once, and preserve separate VM, worker, and output writer faults, replacing a copied panic at its existing position even when other faults are present. Spawned tasks no longer use the parent's spawn call as the primary runtime error location.

- Code generation limits are reported once per definition and diagnostic code, with a final error count in `run` and `test`. A help with an unavailable edit source omits all its edits, and waiting-task JSON includes empty trace fields when no call trace was recorded.

- Type-mismatch notes about hidden prelude types now require a user type on one side and the same-named prelude type on the other, so unrelated type errors do not suggest changing to a prelude type.

- Handler type errors qualify operation type parameter names such as `store.T` when they collide with other displayed type parameters, adding `#2`, `#3`, and so on when the qualified names also collide, and explain when a value cannot leave its clause, with a secondary label on the operation. Escape notes stay attached to the failing constraint even when its report is deferred. Diagnostic function types group the ten effects of `IO.All` when all are present, and constructor pattern arity errors show the path as written.

- `E0209` highlights the name and type arguments read as part of a `uses` list and offers parenthesis insertions only for a function type in a type-argument or function-parameter type list with a matching closing bracket within the current statement.

- Duplicate constant key errors and warnings show keys in `Show.show` notation, escaping quoted strings and characters and limiting each key to 4,096 bytes, including a final `…` when truncated. The `State` note on `E0507` is limited to functions declared in the prelude or standard library.

- Diagnostics for unused final expressions in function and lambda bodies point to the final expression, suggest `return` when appropriate, and avoid duplicate missing-return errors. Return-type mismatches on local bindings point to the returned value and show expected and actual types in the correct order. Failures inside a returned or annotated expression keep their original locations and repair suggestions. Unannotated lambdas whose required return type is `Unit` receive only discard advice. When a different required return type differs from the final expression, return advice has no insertion edit.

- `try` diagnostics distinguish functions, lambdas, and functions made by calls with `_`, and identify the placeholder call. Record-name errors in value positions show construction with named fields, qualifying a user module's same-named record as `G.Geometry(...)`. Constructor patterns do not receive construction help. Calls written with type arguments explain binding annotations and suggest removing the type arguments when followed by an argument list.

- Diagnostics for missing or private members (`E0303`, `E0330`) now explain when the first part hides a prelude name, and suggest inserting `Benitoite.` when the prelude provides that member. Explicit imports of the same prelude module are excluded, and notes distinguish imports from declarations. Type errors `E0401` and `E0410` also explain types declared in the diagnostic's module with prelude names and suggest writing the qualified prelude type.

- Invalid standard-library imports (`E0321`) now suggest modules whose last part matches, ignoring case, before spelling suggestions. A unique candidate has an edit that preserves any import alias.

- The repair for an alias on a module with built-in effects (`E0339`) now removes `as` and rewrites references to the alias in the same file. Resolution also accepts the original name after this error, preventing a duplicate missing-import suggestion. When that name conflicts with another import or declaration, the repair includes only the removal and instructions to rewrite references.

- Missing-name diagnostics now suggest standard-library names renamed in `0.0.1` and common aliases from other languages before spelling suggestions. Qualified keyword names such as `Int.mod` and `Option.bind` receive repairs on `E0216`. When no suggestion applies, `E0303` lists up to 40 names available at that position and the remaining count. References such as `IO.Console.writeLine` also receive a missing-import suggestion that adds the import and rewrites the module prefix; already imported modules receive a reference-only repair, and conflicting names receive instructions to choose an alias. `E0303` and `E0330` show the module name as written, including aliases, while the suggestion to add `public` names the declaring module.

- `benitoite skill install` and `uninstall` without `--project` report an error and write or remove nothing when `HOME` is not an absolute path to an existing directory. Before, `install` could create the skill directories relative to the working directory or at a missing path, and `uninstall` could remove a skill under a relative path or succeed at a missing path.

- When `File.readLines` or `Console.readAllLines` reads more than 2^24 lines, the runtime error is now `R0903` (the input read is too large), as for `File.listDirectory` and `File.walk`, instead of `R0902`.

- Reading a string value no longer rechecks its UTF-8 validity, making operations that repeatedly read long strings faster.

- In reports of failed `Assert.equal` and `Assert.notEqual` checks, each value is limited to 4 KiB (4,096 bytes), including a final `…` when truncated. Rendering stops at the limit, avoiding arbitrarily long reports and exponential rendering time for values that share structure.

- Failed `Assert.equal` and `Assert.notEqual` checks in generic helper bodies now recover constructor and record-field names from direct callers' type arguments, including a tail call from a caller with concrete types. Recovery stops after a tail call, even if an outer call of the same function is still running. Checks inside lambda bodies or handler bodies and clauses use the types with which the enclosing function is used in the program. Implementation methods do not recover types from callers. When a generic helper calls another helper through a tail call, the caller's type arguments are no longer available from that call. In this case, or when a generic function is passed as a value, reports use a type only when the types at every use can be determined and both values' shapes identify a unique type. Recursive generic helpers can leave types unknown. Repeated uses of the same type count once toward the search limit. Known parts of generic types retain their names; unresolved constructors appear as `<constructor #n of an unknown type>`.

### Fixed

- `benitoite fmt` now indents comments before `else` or the clause-opening `with` inside the preceding branch or `handle` body when it contains no statements. `fmt --check` reports such files until they are formatted again.
- After answering 400, 413, or 431 itself, the HTTP server closes only its sending side and reads and discards the rest of the request until the client closes its sending side, more than 1 MiB has been discarded, or 2 seconds have elapsed since the response was written. This reduces the risk of the client losing the response to a TCP reset. Closing proceeds while `Http.accept` is called.
- Comparing values that share structure with `=`, `<>`, `Assert.equal`, `Assert.notEqual`, and `List.contains`, and using such values as `Map` keys or `Set` elements, now avoids exponential expansion by comparing each distinct pair of parts only once after a small initial traversal. A `Float` NaN inside a value still makes it unequal to itself.
- `benitoite fmt` now also removes the blank line before a comment that is the first line inside a construct when the construct contains only comments or its first statement is `with`, as the standard layout requires. `fmt --check` reports such files until they are formatted again.
- Cancelling a task while it waits in a close function such as `File.closeWriter` now discards the release failure only when the resource is not bound by `with` and that task started the release, so a later close returns `Ok`. Cancelling a task that waits for a release started by another task preserves the failure for a remaining caller. For a resource bound by `with`, including one bound in another task, the failure is still reported once: by a later close in the block, or when the block exits.
- `File.readLine` and `Console.readLine` now apply the 2^30-byte limit to the line without its line ending, so a line of exactly 2^30 bytes followed by LF or CRLF can be read.
- `Http.respond` now drops `keep-alive`, `proxy-connection`, `te`, and `upgrade`, and every header named in the given `connection` values, so connection-specific headers copied from another response do not conflict with the server's `connection: close`.
- An uppercase `OPTIONS` request whose absolute target has no path or query component, such as `OPTIONS http://host:8001`, now gives the handler `path` `*` and an empty `query`, as `OPTIONS *` does. Other methods, and targets with `/` or a query component (including a trailing `?`), keep the previous behavior.
- `run` and `test` now check for interruption after a value is returned and the final output transfer completes. A pending Ctrl-C or SIGTERM results in exit status 130 even when a long pure built-in operation is followed by no further calls. A returned `Result.Error` message is suppressed in this case; output-transfer errors are still reported, and existing stop reasons are preserved. In `test`, the last test is not reported or counted when interruption is detected after it returns a value.
- Repeated regular-expression matching (`Regex.findAll`, `replaceAll`, `replaceAllWith`, and `split`) now checks interruption and cancellation between matches, so Ctrl-C and `Task.withTimeout` can stop it. A single search still runs synchronously, and worst-case matching time is unchanged. Replacement output is joined in chunks to avoid reaching the list-length limit just from collecting string parts. When a result exceeds a size limit, the report now names the operation that builds it (`List.append` or `String.join`).
- `Regex.compile` limits long error messages to 4 KiB, omitting the pattern and retaining the error reason and a truncation notice.
- Implementing a trait of the standard library in a user module reports `E0701` with exit status 2, instead of an internal compiler error with exit status 3.
- An error in a type alias, an orphan implementation, or the target of an implementation no longer causes further diagnostics (`E0401`, `E0702`, `E0705`) at the places that use it.
- The expected type of `E0711` shows the type parameter names of the trait declaration.
- The coverage check treats inconsistent pattern matrices, which can occur after other errors, as not covered.
- `Json.parse` reads every object as an object, whatever its keys are. Before, an object with a certain key could be read as a number or stop the program with an internal error, so a single request body passed to `Json.parse` could stop a server. A number that cannot be converted is now always returned as a `Json.ParseError`.
- The suggestion of `E0441` names `Result.ok` instead of `Result.toOption`, which does not exist.
- The message of `E0313` names all the names that a type parameter cannot reuse: top-level declarations, imported names, and prelude names.
- An internal error in `benitoite skill`, `test`, or `fmt` is reported with exit status 3, instead of ending with status 101 and no report.
- `check`, `run`, `test`, `fmt`, and `skill install` no longer wait forever when a script, a module, a file to format, or an existing `SKILL.md` is a named pipe (FIFO). A source file larger than the limit is no longer read to the end. To decide whether an existing skill can be replaced, `skill install` reads `SKILL.md` only when it is a regular file, not a symbolic link, of at most 1 MiB.
- `benitoite fmt` creates its temporary file readable only by the owner, so other users cannot read the content of a private file while it is formatted.
- Terminal control characters in source excerpts and file names are shown as escapes such as `\u{1B}` in text diagnostics, in the `would reformat` lines of `fmt --check`, in the test lines of `test`, and in the reports of `skill`, instead of being written to the terminal.
- `benitoite --licenses` in a build without the list of third-party licenses no longer names a release script that does not exist.
- The report of an internal error asks to remove any secrets from the script before reporting it.
- The HTTP server no longer sends `transfer-encoding` or `trailer` headers given to `Http.respond`, so a response, such as the result of `Http.send` passed on unchanged, never has both `transfer-encoding` and `content-length`.
- The HTTP server sends no body for responses to `HEAD` requests, for the statuses 204, 205, and 304, and for `2xx` responses to `CONNECT` requests. A response to `HEAD` has `content-length` only when the given body is not empty; 204, 304, and `2xx` responses to `CONNECT` have none, and 205 has `content-length: 0`.
- `Http.respond` builds the response once. Before, it validated and built the response again each time it resumed after waiting to write.
- The HTTP server reads chunked trailers with the same rules and limits as the request headers, answering 400 or 431 to invalid or too large trailers.
- An absolute request target such as `GET http://host/path?q=1` gives the `path` `/path` and the query `q=1`, so `Http.pathSegments` splits it correctly.
- The HTTP server sends `100 Continue` before reading the body of an HTTP/1.1 request with `Expect: 100-continue`, instead of waiting for a body the client does not send yet.
- The status line of a 431 response has the reason phrase `Request Header Fields Too Large`. The reason phrases of 428 and 429 are added too.
- On Linux, `Http.accept` treats the network errors that `accept(2)` reports for a single new connection (`ENETDOWN`, `EPROTO`, `ENOPROTOOPT`, `EHOSTDOWN`, `ENONET`, `EHOSTUNREACH`, `EOPNOTSUPP`, `ENETUNREACH`) as a failure of that connection and accepts the next one, instead of returning an error that ends `Http.serve`.
- The warning that `Http.accept` writes when it runs out of resources is dropped when standard error has no room, so that the warning does not hold up accepting connections.
- Cancelling a task that waits for a network operation, such as `Http.accept`, removes the record of its wait. Before, records of cancelled waits stayed, so repeatedly cancelling accepts on the same listener used more and more memory.
- `Regex.find` and the other functions that return `Regex.Match` keep only the matched part of the input, instead of a copy of the whole input for each match.
- The garbage collector counts the memory owned outside the heap objects, such as the text of a `Regex.Match`. Before, creating and dropping many such values could use up memory without starting a collection.
- The module documentation of `Regex` no longer says that matching takes linear time. Finding one match takes time proportional to the input length times the pattern size; finding all matches (`findAll`, `replaceAll`, `replaceAllWith`, `split`) can take time proportional to the square of the input length.
- `check` and `run` no longer use exponential time and memory on small sources with nested trait implementations or with `match` expressions that have many branches; such sources are now reported with `E0609`, `E0715`, or `L0112`.
- When a `with` reaches the call depth limit, the resource it opened is released before the program stops, so buffered writes are flushed and a failure to release is reported. Before, the resource was closed at the end without flushing.
- In the report of a runtime error inside the function given to `Reference.update`, the call trace shows the call of `Reference.update` when the function was called again because another task changed the reference. Before, it showed a place inside the function.
- A chain of tasks that each start the next one, such as recursive `Task.all`, uses memory proportional to its depth. Before, each task copied the whole spawn history of its parent, so memory grew with the square of the depth.
- The records of garbage collection pause times are kept only when measuring, so a long-running program, such as an HTTP server, no longer keeps a growing list of them.
- When the thread that writes standard output or standard error cannot be started, `run` stops before calling `main` and reports an internal error (exit status 3). Before, the script ran and the first write failed with `R0201`.
- When waiting for the event loop keeps failing, `run` stops with an internal error (exit status 3) after 1,000 failures in a row. Before, it retried every millisecond without end.
- `benitoite fmt` parses and formats each file on a thread with a large stack, as `check` does, so deeply nested code no longer overflows the stack. The compiler stages also use much less stack for long blocks, lists, and nested expressions.

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
