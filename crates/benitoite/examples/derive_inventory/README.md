# Declaration inventory, version 3

Build with `cargo build -p benitoite --example derive_inventory`, then run:

```sh
target/debug/examples/derive_inventory --root /path/to/project --config /path/to/derive.json
```

This reads declarations through `pipeline::declarations::collect_declarations`. It parses whole files and checks imports, visibility, declaration names, type signatures, and constraints. It does not resolve names in bodies, check bodies, evaluate constants, execute functions, or validate external components. Success is **not** a successful `benitoite check`. Generated function references in syntactically valid bodies may remain unresolved.

Configuration uses this schema:

```json
{
  "version": 1,
  "targets": [{
    "source": "People.bnt",
    "type": "People.Person",
    "region": "person",
    "json": {"encode": "encodePerson", "decode": "decodePerson", "keys": {}},
    "property": {"generator": "genPerson", "shrinker": "shrinkPerson"},
    "show": true,
    "order": true,
    "fields": {}
  }]
}
```

`source` is relative to `--root`; `type` uses the resolved module name and record name, not an import alias or a compiler binding number. For JSON targets the virtual entry also imports `Benitoite.Unofficial.Json.Codec`, including its standard sources in the input hashes before generation. Property targets likewise import `Benitoite.Unofficial.Test.Property` and include its dependencies. The example imports all target modules and the modules of configured custom functions through a virtual entry under that root. The source must match the resolved declaration. Targets must be records; type parameters and recursive declarations are retained in version 3. Supported generation shapes are checked per feature by tools/derive, rather than rejected by this reader. All objects reject unknown and duplicate keys, including nested objects. Region names contain ASCII letters, digits, `_`, or `-`; target identities and regions within a source must be unique.

A `fields` entry can specify `encode` with `decode`, optional `decodeMissing` with `decode`, or `gen` with `shrink`. Each value names an existing fully qualified function. A function outside the target module must be public. JSON and property sections are optional; when present they require both output function names. `json.keys` maps existing field names to distinct JSON keys. This reader exports custom signatures; generators must subsequently validate the signatures against their conversion or generator contracts.

`show` and `order` are independent optional booleans. Omitted or false flags
request no implementation. A selected flag adds `Benitoite.Trait` to the virtual
entry and covers its transitive embedded sources in `inputs`. Show/Order-only
targets need neither JSON nor Property settings. Other values, duplicate keys,
and unknown keys are configuration errors (exit 2). The consumer checks dictionary
dependencies and implementation collisions; this reader still collects declarations
without checking bodies. Empty record declarations remain syntax errors.

On success, stdout contains exactly one JSON object:

| Key | Contract |
| --- | --- |
| `version` | Integer `3`. Configuration remains version 1. |
| `configSha256` | Lowercase SHA-256 of the original config bytes, without normalization. |
| `targets` | Config order. Each row contains `source`, `region`, `config`, resolved `type`, `module`, local `name`, declaration `span`, `public`, `package`, normalized `visibility`, `opaque`, `canConstruct`, `canInspect`, `typeParams`, ordered `fields`, `dependencies`, and `customFunctions`. |
| `records` | Resolved name to record description, including imported and embedded declarations. Allows consumers to follow dependencies without resolving types again. |
| `functions` | Resolved name to function description: `name`, `span`, visibility, and `signature`. Includes functions that have not passed body checking. |
| `modules` | Loaded module names and source paths, with ordered imports containing their local `alias`, resolved `module`, original `written` module path, and `span`. Each module has `preambleEnd`, the original UTF-8 byte end of its module documentation and header declarations (0 if absent), and its importable `importPath`, which includes `Unofficial` where required. Both `fileUses` and `importInsertLimit` are required, as defined below. Excludes the virtual entry. |
| `declarations` | Declared names, their `module`, `kind`, `topLevel`, visibility and `span`. Nested members have `topLevel: false`. Use the top-level entries when checking generated names for collisions. |
| `inputs` | Every successfully read filesystem input, including files read only to verify package hashes, followed by loaded embedded standard sources. Each has `path`, `sha256`, and `kind` (`file` or `embedded`). The virtual entry is excluded. |

Paths under the canonical root are relative to it; other filesystem paths remain absolute, and embedded sources retain their `<benitoite>/…` names. Hashes use bytes captured during declaration loading, not files read a second time after collection. Two successful reads of the same path with different contents reject collection. This does not lock files or exclude concurrent updates after loading.

`fileUses` is null when the file has no file-level declaration, otherwise
`{text, span}` contains its exact original declaration bytes as a UTF-8 string
and its original source interval. `importInsertLimit` is null exactly when
`fileUses` is null; otherwise it is the declaration's starting UTF-8 byte offset.
It must be within the source and at least `preambleEnd`; imports must end before
it. `preambleEnd` retains its documentation/header meaning and does not include
file-level `uses`. A consumer must not insert imports into a managed region after
this limit, even if that region precedes ordinary declarations. Older inventories
are incompatible and must be recollected.

All spans are `{ "path": "People.bnt", "start": 0, "end": 42 }`, with UTF-8 byte offsets and an exclusive end. Fields preserve declaration order and have `name`, `span`, `typeSpan`, and `type`. Dependencies list referenced nominal types in first encounter order; they do not recursively expand records. Recursive declarations can be represented. Generation must check supported dependency graphs, required targets and access to their generated functions before editing.

The wire types are explicit tagged trees (unknown tags and keys are errors):

```text
Kind = {tag: "value"} | {tag: "constructor", arity: positive integer}
Head = {tag: "named", name: resolved name} | {tag: "parameter", index: integer}
Type = {tag: "application", head: Head, arguments: [Type, ...]}
     | {tag: "parameter", index: integer}
     | {tag: "function", params: [{name, type: Type}, ...], returnType: Type, effects: Effects}
Effects = {names: [{tag: "builtin" | "named", name}, ...], vars: [integer, ...], failures: [Type, ...]}
```

All names, including builtins, use canonical identities: `Benitoite.String.String`,
`Benitoite.List.List`, `Benitoite.Option.Option`, `People.Person`. Numeric aliases
such as Integer64 resolve to `Benitoite.Integer.Integer`. Types appear once in
`types`, keyed by that identity, with `name`, `kind` (`builtin`, `data`, `record`,
`external`), `arity`, declaring `module`, `visibility`, `public`, `package`,
`opaque`, and `extensible`. A zero-argument application is a value type, while a
bare Head in an implementation is a type constructor. Aliases are expanded;
recursive and parameterized records are represented without expanding fields.
Rigid/recovery types must not be exported. The producer and consumer validate
parameter indices, kinds, argument counts, and unique parameter contract names.

`classes` is keyed by resolved identity, with `name`, `module`, visibility,
`paramKind`, ordered `superclasses`, and ordered `methods` (`name`, `signature`).
`implementations` follows module/declaration order and includes anonymous and
polymorphic declarations: `class`, `target` (Type for value classes, Head for
constructor classes), `typeParams`, ordered `constraints`, `module`, `span`,
ordered `methods`, and `sourceRegion` (managed region name, otherwise null).
Consumers compare resolved class/target identities, never invented impl names.

Every declaration uses `visibility: "private" | "package" | "public"`; the old
boolean flags remain for display and must agree with it. Targets are generated
in their declaring source/module, so `canConstruct` and `canInspect` are true
there even for opaque types. Record descriptions likewise describe access from
their own declaring module. These values do not authorize bypassing invariants:
JSON decoding and Property generators/shrinkers for an opaque target are
refused, even inside its owner. For an opaque field, specify handwritten custom
functions for the whole field. The inventory still includes the representation.

Fields additionally contain `metadata: {resolved, original, span}` for display.
Positions and this metadata never define type identity or semantic hashes.
The fixed declaration `kind` tags are `function`, `implementationFunction`,
`constant`, `data`, `builtinType`, `alias`, `externalType`, `record`, `field`,
`constructor`, `trait`, `method`, `effect`, `operation`, `module`, `namespace`,
`typeParameter`, `effectParameter`, and `local`. An import resolved to a standard
builder module uses `stringBuilder`, `listBuilder`, or `bytesBuilder`; these are
classifications of dedicated constructs, not ordinary type declarations. Bodies
are not traversed to enumerate local builder bindings.

Resolved standard module names follow the compiler tables (for example `Benitoite.Failure`); their importable paths can differ (`Benitoite.Unofficial.Failure`). `customFunctions` is keyed by the configured name and retains the resolved function `name` in each value. Import resolution supplies this mapping.

A top-level function's signature uses the effective outer effect row from
resolved declaration collection, including the file-level addition. The original
individual `uses` is not used to reconstruct that row. Implementation methods
and nested function types retain their existing effects. Pure custom JSON and
Property functions must be checked against this effective signature; collection
still does not check bodies, including bodies generated earlier.

A function `signature` contains ordered `params` (`name`, `type`), `returnType`,
ordered `typeParams` (`name`, structured `kind`, `builtin`: null / `equality` /
`key` / `ordered`), `effectParams`, ascending `noFail` indices, ordered
`constraints` (`param`, resolved `class`), and `effects`. Nested function types
use the enclosing signature's parameter indices, without new quantifiers.
Effect names are sorted by canonical name, variables by number, and failures
by canonical JSON UTF-8 bytes, all deduplicated. Builtin effect names follow the
builtin table (for example `State`, `IO.Console.Write`); IO.All is expanded.
No Rust Debug/Serialize representation is part of this contract.

Exit status is 0 for an inventory, 1 for declaration/IO/target failures, and 2 for invalid arguments or config syntax/schema. Failures write an explanation to stderr and no inventory to stdout. This example does not generate or edit source files. JSON conversion, Property generation, managed regions, and regeneration checks are separate work.
