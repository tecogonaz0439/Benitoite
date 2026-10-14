# Json WASM verification package

`Codec` exposes three boundary shapes: `validate`, `pretty`, and `minify` pass strings; `parse` returns a preorder node table that `Nodes` rebuilds as `Json.Value`; `document` retains a parsed document as an external value and exposes JSON Pointer queries through `get` and `len`. `stringify` and `stringifyPretty` flatten a value before passing it to the guest and return `Result[String, String]`. External-type functions require `uses State`; `Nodes` shares its types and functions with `public(package)`.

The guest adapts the parser, number lexeme classification, error-position conversion, material tree, and writer from `src/builtins/funcs/json.rs`. `validate` shares number classification, range checks, and error conversion with parsing, but discards elements and keys without building a material tree. The other operations retain the material tree. Number types, negative zero, last duplicate key, key order, escaping, formatting, and error positions and messages match the built-in implementation. Parsing retains serde's default depth limit; conversion, writing, and tree destruction use explicit work stacks.

JSON Pointer decodes `~0` and `~1` once. Array indices reject non-digits, leading zeros, and out-of-range indices. `get` writes the selected value in the built-in JSON format; `len` returns a size only for arrays and objects. The golden compares success and errors for all three shapes, depth boundaries, non-finite values, 128-level writing, Pointer queries, and the order-summary acceptance data.

## Memory limit

The host limits guest linear memory to 64 MiB by default. Large inputs can trap before producing a result. For stateful calls the limit applies over the instance lifetime; otherwise it applies to each call. The argument for changing this limit is planned in the next implementation step. In all three shapes, large material trees, node tables, output buffers, or retained documents can exceed the limit. Validation avoids the tree, but still receives the input in guest memory. A 10 MB array of numbers can exceed the limit in shapes 1 (pretty/minify), 2, and 3.

A short release check on 2026-10-13 used benchmark seed 212. All five tasks passed at 1 KB and 100 KB. At 10 MB (28,920 records, 607,321 nodes), stringify, read, and validate passed, while parse and pretty reported the linear-memory `R0905`. A 10 MB array of 5,000,000 zeroes passed validate; pretty, parse, and document reported `R0905`. These are input-limit checks, not performance measurements.

## Build

Built with Rust 1.98.1, wit-bindgen 0.62.0, and wasm-tools 1.261.0. `rust/` is a separate Cargo workspace and is excluded from the host build; `rust/` and `wit/` are excluded from the package hash.

From this package's root, with the dependencies and `wasm32-unknown-unknown` target already installed and wasm-tools 1.261.0 on PATH:

```sh
guest_root=$(pwd -P)
repo_root=$(git rev-parse --show-toplevel)
rust_sysroot=$(rustc --print sysroot)
rust_commit=$(rustc -vV | sed -n 's/^commit-hash: //p')
export CARGO_TARGET_DIR="$repo_root/target/wasm-guests"
export RUSTFLAGS="--remap-path-prefix=${CARGO_HOME:-$HOME/.cargo}/registry/src=/cargo/registry/src --remap-path-prefix=${RUSTUP_HOME:-$HOME/.rustup}=/rustup --remap-path-prefix=$rust_sysroot/lib/rustlib/src/rust=/rustc/$rust_commit --remap-path-prefix=$guest_root=/build"
cargo build --manifest-path rust/Cargo.toml --offline --locked --release --target wasm32-unknown-unknown
wasm-tools component new "$CARGO_TARGET_DIR/wasm32-unknown-unknown/release/bnt_wasm_json.wasm" -o wasm/json.wasm
wasm-tools component wit wasm/json.wasm
strings wasm/json.wasm | rg '/Users/|/home/|/private/|aarch64-apple-darwin|x86_64-'
shasum -a 256 wasm/json.wasm
```

The `strings` check produces no matches (exit status 1). The standard-library source path is mapped to `/rustc/<commit>` in addition to registry and guest paths, so the host toolchain triple does not remain in these source paths. The component was rebuilt twice on the same machine and the bytes matched; cross-host reproducibility has not been tested. Cached dependencies were reused; no dedicated rebuild test is added.

The checked-in component is 129,759 bytes. SHA-256:

```text
f4f5813226c3253a6325fa6ce5b75ed58c0020dce11731778304161e27e74d24
```

## Component contract

`wasm-tools component wit` reports the following world, with no imports:

```wit
package root:component;

world root {
  export bnt:json/codec@0.1.0;
}
package bnt:json@0.1.0 {
  interface codec {
    variant node {
      null,
      boolean(bool),
      integer(s64),
      float(f64),
      text(string),
      array(s64),
      object(s64),
      key(string),
    }

    record parse-error {
      line: s64,
      column: s64,
      message: string,
    }

    resource document {
      parse: static func(text: string) -> result<document, parse-error>;
      get: func(pointer: string) -> option<string>;
      len: func(pointer: string) -> option<s64>;
    }

    validate: func(text: string) -> result<_, parse-error>;

    pretty: func(text: string) -> result<string, parse-error>;

    minify: func(text: string) -> result<string, parse-error>;

    parse: func(text: string) -> result<list<node>, parse-error>;

    stringify: func(nodes: list<node>) -> result<string, string>;

    stringify-pretty: func(nodes: list<node>) -> result<string, string>;
  }
}
```

## Licenses

The guest code is licensed under `MIT OR Apache-2.0`. [THIRD-PARTY.md](THIRD-PARTY.md) lists statically linked crates, the Rust standard library and allocator, versions, copyright notices, and license texts.
