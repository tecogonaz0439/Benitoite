# Generated-region management

This development tool manages reviewed edits to ordinary Benitoite source. It
uses the real declaration inventory and formatter, and shares byte-range edits,
diffs, input validation, and replay receipts with
[source-migrate](../source-migrate/README.md).

**Current availability:** region management, JSON record conversion, Property
generator/shrinker templates, and ordinary Show/Order implementations are implemented.
Each feature may be requested independently or together in the same managed region.
There is no `generationInfo` function, `--force`, or `detach` command.

Build the readers when their Rust inputs change:

```sh
cargo build -p benitoite --example derive_inventory
cargo build -p benitoite --bin benitoite
```

The current entry points are:

```sh
python3 -B tools/derive/derive.py preview --root /path/to/project --config /path/to/project/derive.json --out /path/to/review
python3 -B tools/derive/derive.py apply --root /path/to/project --config /path/to/project/derive.json --manifest /path/to/review/manifest.json --manifest-sha256 <reviewed-digest>
python3 -B tools/derive/derive.py check --root /path/to/project --config /path/to/project/derive.json
```

An empty `targets` array is accepted. JSON targets generate ordinary Result-based
functions; the [runnable example](examples/People.bnt) and its
[configuration](examples/derive.json) show a two-level record with both codecs and Property functions.
There is no new public `benitoite` subcommand. A relative `--config` is relative
to the current working directory, and `source` paths are relative to `--root`.

## 0.0.9 version transition

The combined migration is described in the [0.0.9 release notes](../../CHANGELOG.md#009-san-benito).
These versions identify different contracts:

| Contract | Current version |
|---|---|
| Interpreter | `0.0.9` |
| Derive configuration | `1` |
| Declaration inventory | `2` |
| Manifest / persistent generation record / semantic hash | `2` |
| GENERATOR_VERSION | `2.0.0-syntax-batch3` |
| Property.libraryVersion | `2.0.0` |
| Property template revision | `2` |
| Show / Order template revisions | `1` / `1` |

Finish pending old apply/recovery with the saved old tool, then rebuild both
binaries and make one fresh preview for the combined transition. Review its
source diff and new record before applying that exact manifest's SHA-256. The
[record migration protocol](#markers-records-and-review-artifacts) authenticates
old bodies and refuses old manifests; normal check/test and derive check are
both required. The checked-in example already uses the versions above.

## Configuration and declaration input

[config.example.json](config.example.json) illustrates the version 1 settings
including JSON, Property, Show and Order. Use
[examples/derive.json](examples/derive.json) for an executable combined configuration.
The schema and resolved inventory are defined in the
[inventory contract](../../crates/benitoite/examples/derive_inventory/README.md).
The Rust reader rejects duplicate and unknown keys, invalid target declarations,
unknown fields, incomplete custom function pairs, and duplicate JSON keys. Python
does not parse type syntax or implement another type resolver. It follows resolved
record edges through the type tree to detect cycles and hash transitive records.
Templates check supported types, dependency targets, visibility,
and custom signature compatibility before producing review artifacts.

The inventory reads declarations without resolving or checking bodies. Its
success is not a successful normal `check`, `test --check`, or an effects report.

## JSON conversion contracts

Import `Benitoite.Unofficial.Json.Codec` for pure `Result` conversions.
`ConversionError` is an extensible record with `path`, `expected`, `found`, and
`reason`. Path steps are `Field(String)`, `Index(Integer)`, and `Key(String)`,
ordered from the outermost container. Show reports the path and kinds, without
automatically including the input payload or reason.

A target supports String, Boolean, Integer, finite Float, noncyclic records,
List, String-keyed Map, and Option of a non-null-accepting supported element.
Record dependencies need their own JSON target; across modules their types and
generated functions must be public. Generic records, recursive records, other
types, and nested Option require custom conversions (recursive record graphs
remain unsupported). Integer and Float require their exact JSON constructors;
NaN and infinities are rejected on both encode and decode.

`json.encode` and `json.decode` name the generated functions; their parameter is
`value`, and both return `Result[..., Codec.ConversionError]`. Functions have
the record's visibility. Fields are processed in declaration order, with the
first failure returned. `json.keys` changes JSON keys, including their Field
path component. Once all fields succeed, the first extra key in key order is
rejected. List errors add an index; Map errors add a key and use key order.
None encodes as null. An automatic Option field decodes missing or null as None;
required fields have no implicit default.

A `fields` entry can replace the **entire** field conversion with fully qualified
`encode` and `decode` function names. They must be pure monomorphic one-argument
functions from the field type to `Result[Json.Value, Codec.ConversionError]` and
back. Parameter names may differ: generated adapters preserve the codec's
`value` contract. An optional zero-argument `decodeMissing` returns the decoded
field type in the same Result; without it, a custom field is required even when
its type is Option. Failures are relative; generated callers prepend the field.
This also permits explicit numeric conversion or an injective nested-Option
representation. Custom function bodies and their roundtrip properties remain
the user's responsibility.

For supported values and custom functions that satisfy the same law,
`decode(encode(x)) = Ok(x)`. This does not promise preservation of arbitrary JSON
text, duplicate-key detection, or numeric representation across parse/stringify.
Parsing errors remain `Json.ParseError`; combine parse and decode explicitly.
The codec requires no Fail effect. An application may explicitly call
`Failure.fromResult` at its own boundary, as the example's `requirePerson` does.

After building the binaries, the checked-in example can be verified with:

```sh
python3 -B tools/derive/derive.py check --root tools/derive/examples --config tools/derive/examples/derive.json
benitoite check tools/derive/examples/People.bnt
benitoite test tools/derive/examples/People.bnt
```

The generated source and version 2 persistent record are checked in. They use
Property library 2.0.0; the first command verifies both record and source. To regenerate, use
the preview/review/apply commands above with the example's root and config.

## Property generation contracts

`property.generator` and `property.shrinker` name zero-argument functions returning
`Property.Gen[Record]` and `Property.Shrinker[Record]`. Their visibility matches
the record. They support String, Boolean, Integer (the full signed 64-bit range),
finite Float, noncyclic records, List, String-keyed Map, and Option. Property-only
nested Option preserves None/Some(None); adding JSON still requires custom JSON
conversions for that field. Generic and recursive records are unsupported.
A referenced record needs a Property target, and must be public across modules.

Each field receives the same size, in declaration order, and the random state
returned by the preceding field. Container sizes bound each container, not the
total nested value. Shrinking maps and appends ShrinkStep sequences in declaration
order, changing exactly one field at a time. Each field shrinker factory and its
candidates callback are deferred until that field is reached; a low work budget
does not evaluate later fields. The built-in scalar and container rules
are those of [Property](../../crates/benitoite/src/prelude/stdlib/Test/Property.bnt).
Field relationships are not inferred: use a handwritten generator and shrinker
for the entire record when relationships must be preserved.

A `fields` entry may specify fully qualified `gen` and `shrink` functions
**together**. Each must be pure, monomorphic, and take zero arguments, returning
`Property.Gen[FieldType]` and `Property.Shrinker[FieldType]` respectively. This
replaces the entire field, including an otherwise unsupported field type.
Signatures are checked before artifacts are written and hashed in the generation
record. The functions' bodies and distributions remain the user's responsibility.

The [example](examples/People.bnt) generates JSON and Property in one region and
runs JSON roundtrips from `generatedJsonRoundtrip`, one ordinary `@test`. It
matches Property.check and returns Property.formatFailure as a String error.
`test --check` executes no generator, shrinker, or property; no special attribute,
seed CLI flag, or new structured counterexample report is introduced.

For replay, keep the seed/config, type structures, custom functions, property,
and tool/library rule versions. Attach the generation record (including
`generatorVersion` and the target's `configSha256`) to a saved failure report;
no identification function is generated. The library failure retains original
and reduced inputs and messages, but a lossy show function cannot reconstruct
the input. Preserve a concrete counterexample as a fixed test for long-term use.

## Show and Order generation contracts

Set `"show": true` and/or `"order": true` on a target. Omitted or false flags
generate nothing for that class; values other than booleans are rejected.
Neither JSON nor Property is required for a Show/Order-only target.
The tool imports `Benitoite.Trait` when needed, reusing an existing alias by
resolved module identity. It emits ordinary `implement Trait.Show[Record]`
and `implement Trait.Order[Record]` declarations in the record's owner module,
then passes their source through the normal formatter.

Show uses the local type name, field names and declaration order. For example,
`Person(name: "Ada", age: 7)` is displayed with the String field's quotes and
escapes supplied by its own Show dictionary. The display is not a serialization
format. Order compares fields in declaration order and returns the first
non-Equal result, evaluating later fields only after Equal. All equal fields
produce Equal. This does not imply builtin equality or a `key` constraint.

Targets must be noncyclic records without type parameters. Empty record
declarations are rejected by the language parser with E0201; the tool does not
relax that rule. A field may use a handwritten dictionary for a data type or
a polymorphic container. The tool follows the resolved implementation heads
and their class constraints; missing dictionaries return
`derive.missing_implementation`. The normal check after apply remains required
for bodies and builtin constraints. Generated dependencies must explicitly
request the corresponding class: Show does not imply Order or request Show
for another record. Dependencies are generated before their dependents.

Handwritten implementations, implementations in another region, and polymorphic
implementations with the same resolved class/type head block generation with
`derive.overlapping_implementation` and the previous location. Input declarations
already containing duplicates retain the compiler's E0702 diagnostic. Only an
implementation for the same target and class in its authenticated previous
generated region may be replaced. Handwritten bytes outside the region are kept.

Private, package-public and public records use the same generation scheme;
`implement` does not acquire a public modifier. An opaque record may explicitly
request Show/Order in its owner module. Review the `traitTarget` row in
`generated.json`, including its `opaque` flag, to approve revealing its fields.
Combining that request with automatic JSON or Property construction rejects
the entire request with `derive.opaque_target`.

## Markers, records, and review artifacts

Each region uses exact complete comment lines:

```text
// benitoite-derive:begin person
... ordinary generated functions and required imports ...
// benitoite-derive:end person
```

Missing regions normally append to the declaring `.bnt` file. If new imports are
required, one new region is placed after module documentation, header declarations,
and existing imports, and before the first ordinary declaration; it contains all
newly required imports for that source. This placement follows the parser's requirement that imports precede declarations.
If every existing region follows declarations and no new region is being added,
new imports are refused: add an appropriate handwritten import before declarations
and preview again. Existing regions are edited only between the marker lines. Original
UTF-8 byte offsets are used; handwritten bytes, CRLF line endings, and marker
lines outside that body are preserved. Duplicate, nested, unmatched, or malformed
markers are rejected. An existing region without its generation record is treated
as handwritten code. A changed body is rejected rather than overwritten.

The persistent record is `<config-stem>.generated.json` beside the config. It
contains `version: 2`, `inventoryVersion: 2`, `hashVersion: 2`,
`generatorVersion: "2.0.0-syntax-batch3"`, and ordered `targets`. Each target
contains `source`, `region`, the resolved `type`, and these SHA-256 hashes:

| Key | Input |
| --- | --- |
| `declarationSha256` | Visibility, name, type parameters, ordered fields and resolved types, nominal dependencies. |
| `dependenciesSha256` | Transitive resolved record structures, keyed by resolved identity. |
| `customSignaturesSha256` | Configured custom functions with resolved names and signatures. |
| `configSha256` | Sorted-key JSON with absent `fields` and JSON `keys` normalized to empty objects. |
| `outputSha256` | Exact generated body bytes **after** the real formatter runs. |

Positions, annotation spelling, and source metadata are excluded from structural
hashes. Comments and whitespace in declarations therefore do not require
regeneration. Raw input hashes for a reviewed apply still include those bytes.
Changing the management rules or templates requires a `GENERATOR_VERSION` bump.
Semantic hashes explicitly select typed structure, canonical identities, normalized
visibility and opaque/access boundaries, field order, selected custom signatures,
and normalized configuration. Metadata, source positions, display text, package
display names, and unrelated functions are excluded. Canonical JSON uses UTF-8,
sorted object keys, no whitespace, ensure_ascii=false, and no non-finite numbers.
Target rows also record `inventoryVersion`, `hashVersion`, `fieldOrder`, selected
`templates` and their revisions, `propertyLibraryVersion` (currently `2.0.0`),
and `implementationDependencies` (empty for JSON/Property-only targets).
Show/Order dependencies record resolved classes, target trees, declaring modules,
parameter kinds/bounds, class constraints and method signatures, or the selected
generated target/region and template revision. Source positions and display
metadata are excluded. `traitTarget` records the explicit class selections and
opaque status for review. Each Show/Order template starts at revision `1` within
the combined version `2.0.0-syntax-batch3` transition. The Property template
uses revision `2` for the ShrinkStep API.

Version 1 records require migration: `check` returns `derive.migration_required`
without writing. Finish any pending old apply/recovery with the saved old tool
and its manifest/receipt first. New `preview` includes the previous record in `manifest.migration` and marks its
semantic hashes incomparable, so old input/record hashes remain visible for
review rather than silently gaining a new approval. It authenticates the existing region
against the old `outputSha256` before proposing replacements; mismatching bytes
return `derive.modified_region`. Old semantic hashes are never recalculated as
new approvals. Review the source diff **and** the version 2 record, then apply
the new manifest by its exact reviewed SHA-256. A record-only migration may
have an empty source diff. New apply refuses old manifests with
`derive.incompatible_manifest`; receipts remain bound to the exact manifest
hash, so an old receipt cannot authorize a new plan. Reapply and recovery after
a final record-write failure retain the same protocol.

The checked-in People/Address example has completed this combined migration.
Person requests Show, while Address requests Show and Order; Person.scores
contains a Map without an Order dictionary, so Person does not request Order.
Old List-returning shrinkers must be rewritten as deferred ShrinkStep sequences;
there is no default adapter that first constructs the complete list. Config now
requires maxShrinkWork and Counterexample includes shrinkWork after shrinks.
Seed alone does not reproduce a counterexample across these rule changes; retain
Property.libraryVersion, GENERATOR_VERSION, config, handwritten sources and
the concrete input.

Opaque target types require handwritten checked construction. JSON decoding
and Property generator/shrinker generation are refused for opaque records/data,
even in the owner module. Normal records containing opaque fields require
explicit custom encode/decode or gen/shrink functions for those whole fields.

`preview` writes three review artifacts to a fresh output location; apply adds
the receipt:

| Artifact | Content |
| --- | --- |
| `manifest.json` | Version 2 plan (inventory/hash version 2): generator version, canonical root/config, all filesystem input hashes, embedded input hashes, exact before/after edits, old record hash or absence, new record. |
| `changes.diff` | Unified source diff from source-migrate; empty for a record-only change. |
| `generated.json` | Proposed new generation record for review. |
| `manifest.json.receipt.json` | After apply: reviewed manifest hash and post-apply hashes for all filesystem inputs. |

Preview never overwrites an existing artifact or the persistent record. Reuse a
new review directory for each preview. Review both the source diff and proposed
record, then calculate/confirm the SHA-256 of the exact reviewed manifest bytes.
The printed preview digest identifies those bytes; it is not automatic approval.

`apply` requires that digest. It checks config, tool sources and reader/formatter
binaries, all inventory filesystem inputs (including read-only external package
inputs), embedded inputs, existing record state, and the current generation plan
before writing. Edit destinations must be safe root-relative target sources;
external inputs cannot become edit destinations. Changed inputs, records,
handwritten regions, and conflicting names or import aliases cause refusal.
Required imports belong inside a region. Templates use resolved module identity
to reuse existing aliases rather than modifying handwritten imports. Import
requests use the inventory's `importPath`; a required module absent from that
inventory is rejected before preview writes anything. The reader includes Json.Codec for JSON and Test.Property for Property, with
their dependencies, even when the target has no handwritten imports. Their
inputs are therefore covered before approval.

`check` regenerates and compares both the current record and generated bodies. It
does not write files. It detects structure/config/template changes even when old
generated functions still type-check or happen to have identical output text.
Formatter changes inside a region are changes too: output is formatted before
its hash is saved, and later edits to those bytes cause a mismatch.

## Verification and recovery

The required sequence is preview → human review →
apply → normal `benitoite check`/`test` → **derive check**. A second preview must
have an empty source diff and unchanged proposed record. Normal `benitoite check`
does not read generation records and cannot replace derive check. Generation
does not establish that custom function bodies implement the intended semantics.

Validation refusal happens before source writes. As with source-migrate, there
is no lock excluding concurrent external edits after validation and no atomic
multi-file transaction. IO failure during writes returns nonzero; inspect the
remaining diff and receipt before retrying. The record is written after source
edits and the receipt. If only the final record write fails, reapply the same
reviewed manifest: the source receipt verifies all post-apply inputs and allows
finishing the record write without rewriting source. A changed record is rejected
unless it is precisely the old or proposed state for that recovery. If no receipt
was saved after a partial source write, inspect/restore the exact pre-apply state
before retrying; do not delete protection data to force acceptance.

To stop managing a target, manually keep the generated body and remove:

1. Its begin and end marker lines.
2. Its target entry in the config.
3. Its target entry in the generation record (or the record file if none remain).

Then run derive check for remaining targets and normal check/test for the source.
These manual changes also invalidate older reviewed manifests and receipts.

## Diagnostics and self-tests

Failures print an English explanation to stderr. Target-related failures include
the source path, original half-open UTF-8 byte interval, and resolved target;
compiler diagnostics retain their own codes/positions. There is no separate
diagnostic JSON schema or D-number system.

| Exit | Meaning |
| --- | --- |
| 0 | Matching check, successful preview/apply, or verified reapplication. |
| 1 | Generation unavailable/impossible, collision, input/record/body mismatch, formatting or IO failure. |
| 2 | Invalid arguments or configuration syntax/schema. |

Run the self-tests after building the two binaries:

```sh
python3 -B tools/derive/test_derive.py
```

They use temporary projects and the real reader, formatter, source-migrate, and
normal check/test. Small fixed generation functions isolate the management
contract, and real JSON templates additionally test conversions through the VM. The suite checks first apply,
replay, empty second diff, structural changes, handwritten protection, collisions,
CRLF/UTF-8 offsets, all-input verification, unsupported settings, and record-write
recovery. JSON cases also cover nested records/containers, missing/null Option,
field and key order, renamed/literal keys, custom conversions, lossy types,
signature rejection, and stale generation records. Property cases check field-order
random state and size, one-field shrinking, custom functions, nested Option,
replay, unsupported types, and the combined JSON roundtrip example. The suite
does not invoke an LLM or modify repository fixtures.
