# Hash WASM verification package

`Digest.sha256` and `Digest.sha256Hex` pass `Bytes` through the typed fast path. `sha256List` declares the same WIT export with `List[Byte]` to compare the dynamic path. The built-in `Hash` module remains available.

The guest uses sha2 0.10.9, while the built-in implementation uses 0.11.0. The golden compares SHA-256 for empty, short, non-ASCII, arbitrary-byte, and 1 MiB inputs.

## Memory limit

The host limits guest linear memory to 64 MiB by default. Large inputs can trap before producing a result. For stateful calls the limit applies over the instance lifetime; otherwise it applies to each call. The argument for changing this limit is planned in the next implementation step. In particular, a 100 MB input cannot fit, and 32 MiB may fail depending on allocation growth.

A short release check on 2026-10-13 passed at 1 MB and 6 MB through both Bytes and List[Byte], and at 32 MiB through Bytes. This does not guarantee that other allocation patterns fit.

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
wasm-tools component new "$CARGO_TARGET_DIR/wasm32-unknown-unknown/release/bnt_wasm_hash.wasm" -o wasm/hash.wasm
wasm-tools component wit wasm/hash.wasm
strings wasm/hash.wasm | rg '/Users/|/home/|/private/|aarch64-apple-darwin|x86_64-'
shasum -a 256 wasm/hash.wasm
```

The `strings` check produces no matches (exit status 1). The standard-library source path is mapped to `/rustc/<commit>` in addition to registry and guest paths, so the host toolchain triple does not remain in these source paths. The component was rebuilt twice on the same machine and the bytes matched; cross-host reproducibility has not been tested. Cached dependencies were reused; no dedicated rebuild test is added.

The checked-in component is 21,948 bytes. SHA-256:

```text
2c6484b64f17dc1ddfa6e11d74a2ef810f2220c4ec55e6b5e20d8e8d1c90a865
```

## Component contract

`wasm-tools component wit` reports the following world, with no imports:

```wit
package root:component;

world root {
  export sha256: func(data: list<u8>) -> list<u8>;
  export sha256-hex: func(data: list<u8>) -> string;
}
```

## Licenses

The guest code is licensed under `MIT OR Apache-2.0`. [THIRD-PARTY.md](THIRD-PARTY.md) lists statically linked crates, the Rust standard library and allocator, versions, copyright notices, and license texts.
