# Regex WASM verification package

`Pattern` exposes functions that pass an external type and pure functions that receive the pattern on each call. External-type functions require `uses State`. `Raw` shares its function declarations with `public(package)`; `Raw.Pattern` and `Raw.Found` are public because public aliases refer to them.

The guest uses the same default `RegexBuilder` as the built-in implementation. It copies `compile_error`, `retry_start`, and `span_at` from `src/builtins/funcs/regex.rs`, and the `findAllFrom` and `replaceAllFrom` procedures from `src/prelude/stdlib/Regex.bnt`. Replacements are literal: `$1` is not expanded. Empty-match selection, Unicode, errors, and repeated use of a resource are compared in the golden.

In addition to `compile`, `isMatch`, `find`, `findAll`, `replaceAll`, `isMatchOnce`, and `findAllOnce`, `count` and `countOnce` count matches without retaining a result list. The crate's default features remain enabled.

## Memory limit

The host limits guest linear memory to 64 MiB by default. Large inputs can trap before producing a result. For stateful calls the limit applies over the instance lifetime; otherwise it applies to each call. The argument for changing this limit is planned in the next implementation step. `find-all` and its pure counterpart retain every match, so a dense result set can exceed the limit even when the input fits. The benchmark uses `count` for large inputs to avoid this result list.

A short release check on 2026-10-13 passed the default count input (150,000 lines, 2,550,000 bytes) through both the resource and pure forms. It uses count rather than a retained match list.

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
wasm-tools component new "$CARGO_TARGET_DIR/wasm32-unknown-unknown/release/bnt_wasm_regex.wasm" -o wasm/regex.wasm
wasm-tools component wit wasm/regex.wasm
strings wasm/regex.wasm | rg '/Users/|/home/|/private/|aarch64-apple-darwin|x86_64-'
shasum -a 256 wasm/regex.wasm
```

The `strings` check produces no matches (exit status 1). The standard-library source path is mapped to `/rustc/<commit>` in addition to registry and guest paths, so the host toolchain triple does not remain in these source paths. The component was rebuilt twice on the same machine and the bytes matched; cross-host reproducibility has not been tested. Cached dependencies were reused; no dedicated rebuild test is added.

The checked-in component is 919,609 bytes. SHA-256:

```text
9ea978836c933f8b05586c1732520989d9cd64094461ae6c155b21dd357c0aec
```

## Component contract

`wasm-tools component wit` reports the following world, with no imports:

```wit
package root:component;

world root {
  export bnt:regex/re@0.1.0;
}
package bnt:regex@0.1.0 {
  interface re {
    record found {
      text: string,
      byte-start: s64,
      byte-end: s64,
    }

    resource pattern {
      compile: static func(source: string) -> result<pattern, string>;
      is-match: func(text: string) -> bool;
      find: func(text: string) -> option<found>;
      find-all: func(text: string) -> list<found>;
      count: func(text: string) -> s64;
      replace-all: func(text: string, replacement: string) -> string;
    }

    is-match-once: func(source: string, text: string) -> result<bool, string>;

    find-all-once: func(source: string, text: string) -> result<list<found>, string>;

    count-once: func(source: string, text: string) -> result<s64, string>;
  }
}
```

## Licenses

The guest code is licensed under `MIT OR Apache-2.0`. [THIRD-PARTY.md](THIRD-PARTY.md) lists statically linked crates, the Rust standard library and allocator, versions, copyright notices, and license texts.
