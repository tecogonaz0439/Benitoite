# Declaration inventory, version 1

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
    "fields": {}
  }]
}
```

`source` is relative to `--root`; `type` uses the resolved module name and record name, not an import alias or a compiler binding number. For JSON targets the virtual entry also imports `Benitoite.Unofficial.Json.Codec`, including its standard sources in the input hashes before generation. Property targets likewise import `Benitoite.Unofficial.Test.Property` and include its dependencies. The example imports all target modules and the modules of configured custom functions through a virtual entry under that root. The source must match the resolved declaration. Targets must be records without type parameters. All objects reject unknown and duplicate keys, including nested objects. Region names contain ASCII letters, digits, `_`, or `-`; target identities and regions within a source must be unique.

A `fields` entry can specify `encode` with `decode`, optional `decodeMissing` with `decode`, or `gen` with `shrink`. Each value names an existing fully qualified function. A function outside the target module must be public. JSON and property sections are optional; when present they require both output function names. `json.keys` maps existing field names to distinct JSON keys. This reader exports custom signatures; generators must subsequently validate the signatures against their conversion or generator contracts.

On success, stdout contains exactly one JSON object:

| Key | Contract |
| --- | --- |
| `version` | Integer `1`. |
| `configSha256` | Lowercase SHA-256 of the original config bytes, without normalization. |
| `targets` | Config order. Each row contains `source`, `region`, `config`, resolved `type`, `module`, local `name`, declaration `span`, `public`, `package`, `typeParams`, ordered `fields`, `dependencies`, and `customFunctions`. |
| `records` | Resolved name to record description, including imported and embedded declarations. Allows consumers to follow dependencies without resolving types again. |
| `functions` | Resolved name to function description: `name`, `span`, visibility, and `signature`. Includes functions that have not passed body checking. |
| `modules` | Loaded module names and source paths, with ordered imports containing their local `alias`, resolved `module`, original `written` module path, and `span`. Each module has `preambleEnd`, the original UTF-8 byte end of its module documentation and header declarations (0 if absent), and its importable `importPath`, which includes `Unofficial` where required. Excludes the virtual entry. |
| `declarations` | Declared names, their `module`, `kind`, `topLevel`, visibility and `span`. Nested members have `topLevel: false`. Use the top-level entries when checking generated names for collisions. |
| `inputs` | Every successfully read filesystem input, including files read only to verify package hashes, followed by loaded embedded standard sources. Each has `path`, `sha256`, and `kind` (`file` or `embedded`). The virtual entry is excluded. |

Paths under the canonical root are relative to it; other filesystem paths remain absolute, and embedded sources retain their `<benitoite>/…` names. Hashes use bytes captured during declaration loading, not files read a second time after collection. Two successful reads of the same path with different contents reject collection. This does not lock files or exclude concurrent updates after loading.

All spans are `{ "path": "People.bnt", "start": 0, "end": 42 }`, with UTF-8 byte offsets and an exclusive end. Fields preserve declaration order and have `name`, `span`, `typeSpan`, and `type`. Dependencies list referenced nominal types in first encounter order; they do not recursively expand records. Recursive declarations can be represented. Generation must check supported dependency graphs, required targets and access to their generated functions before editing.

The field type tree uses these forms:

- `{"tag":"builtin","name":"String"}` (also `Boolean`, `Integer`, `Float`).
- `{"tag":"record","name":"Other.Address"}` for a record without type arguments.
- `{"tag":"list","element":…}`.
- `{"tag":"map","key":{"tag":"builtin","name":"String"},"value":…}`.
- `{"tag":"option","element":…}` for the standard Option identity.
- `{"tag":"unsupported","resolved":"…","original":"…","span":…}` for other types. `resolved` uses qualified nominal names and the signature's parameter names; `original` and `span` preserve the enclosing annotation for unsupported children too.

Aliases are expanded by the ordinary type checker. A user-defined type named Option does not become the standard option tag. Record references use names rather than expanding their fields inside the tree.

Resolved standard module names follow the compiler tables (for example `Benitoite.Failure`); their importable paths can differ (`Benitoite.Unofficial.Failure`). `customFunctions` is keyed by the configured name and retains the resolved function `name` in each value. Import resolution supplies this mapping.

A function `signature` contains ordered `params` (`name`, `type`), `returnType`, ordered `typeParams` (`name`, `kind`, `builtin` constraint), `effectParams`, `noFail` effect parameter indices, `constraints` (`param` index and resolved `class`), and `effects` (`names`, `vars`, `failures`). A kind is `Value` or `Ctor { arity: n }`; builtin constraints are `Equality`, `Key`, or `Ordered`. Named effects carry `builtin` or resolved `name`; effect variables and class parameters use indices scoped to that signature. Positions and original annotation text are metadata, not semantic structure: consumers must omit them when computing structure hashes.

Exit status is 0 for an inventory, 1 for declaration/IO/target failures, and 2 for invalid arguments or config syntax/schema. Failures write an explanation to stderr and no inventory to stdout. This example does not generate or edit source files. JSON conversion, Property generation, managed regions, and regeneration checks are separate work.
