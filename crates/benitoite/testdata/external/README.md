# Components used by checks and execution

The `.wat` files are the source of the adjacent `.wasm` fixtures.
Rebuild each adjacent binary with wasm-tools 1.261.0:

```sh
wasm-tools parse path/to/x.wat -o path/to/x.wasm
```

`cargo test -p benitoite --test golden testdata_components_match_their_text`
verifies that the checked-in binaries match their text.
The Rust Fuzzy component has its own source and build instructions in
`../packages/libraries.files/fuzzy/README.md`.

The `root` case covers direct calls, function values, and a Wasm call after deep
language recursion. `roundtrip` exercises each supported parameter/result type
through the Component Model ABI; the text writes flat return values at address
0 and places incoming buffers at address 1024 in each fresh instance. `trap`
and `memory` cover runtime error and resource diagnostics. Fuel exhaustion and
small value-size boundaries are unit tests, so their inputs do not require
multi-second infinite loops or large host allocations.

`bad-utf8`, `bad-character`, `bad-option`, and `bad-pointer` return invalid
Component Model ABI values and must report runtime failures rather than
implementation bugs. `large-table` exceeds the element limit at instantiation.
`aliased-result` points two lists at the same guest buffer; the value transfer
budget must reject the amplified host representation. Large `Bytes` round trips,
argument/result budget rejection, total memory across instances, NaN, infinities,
and empty buffers/strings are covered at the external runtime boundary.

`interface` calls an exact versioned interface export directly and as a function
value, alongside a world-level export. `interface-diagnostics` checks missing
functions, exact interface versions, interface-only names, and suggested
declarations for parameter-count, argument-type, and result-type mismatches.

`records` passes records, payload and payload-free variants, enums (including
the standard library `Trait.Ordering`),
`Result[Integer, MyError]`, and `Option[Point]` through direct and interface
exports. The guest changes record fields and cycles enum cases, so the output
also checks field and constructor correspondence. `record-mismatch` checks
the rendered aggregate types and the first mismatch reason. The table tests
in `src/external/tests.rs` cover the other structural and declaration errors.

`interface/x.wat` and `interface-diagnostics/x.wat` have identical contents; unit tests also use `interface/x.wat`.

`resource` imports its external type from `Lib/Cell.bnt`, constructs cells,
retains state across method calls, passes two cells, and returns `Option[Cell]`.
Its pure `[static]cell.count` call uses a fresh instance and sees no live cells. Its loop constructs and discards 1,500 cells; without
collection and deferred destruction, the guest would exceed 64 MiB.
`resource-effect` checks the missing `uses State` diagnostic and its insertion edit.
The source of `resource/x.wat` is `resource/src/r.wit` and `resource/src/core.wat`.
With wasm-tools 1.261.0, run these commands from the repository root.
Temporary build outputs stay under `target/`. The fixture includes a pure
`[static]cell.count() -> s64` function:

```sh
mkdir -p target/resource-fixture
wasm-tools parse crates/benitoite/testdata/external/resource/src/core.wat -o target/resource-fixture/core0.wasm
wasm-tools component embed crates/benitoite/testdata/external/resource/src/r.wit target/resource-fixture/core0.wasm -o target/resource-fixture/core.wasm
wasm-tools component new target/resource-fixture/core.wasm -o target/resource-fixture/component.wasm
wasm-tools print target/resource-fixture/component.wasm > crates/benitoite/testdata/external/resource/x.wat
cp crates/benitoite/testdata/external/resource/x.wat crates/benitoite/testdata/external/resource-effect/x.wat
wasm-tools parse crates/benitoite/testdata/external/resource/x.wat -o crates/benitoite/testdata/external/resource/x.wasm
wasm-tools parse crates/benitoite/testdata/external/resource-effect/x.wat -o crates/benitoite/testdata/external/resource-effect/x.wasm
rm -r target/resource-fixture
```

Component imports are empty; the core
resource imports are supplied by the component's canonical resource functions.
