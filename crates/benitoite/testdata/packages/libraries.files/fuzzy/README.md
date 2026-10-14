# Fuzzy component

The source is a Levenshtein distance implementation, licensed under MIT.
Built with Rust 1.98.1, wit-bindgen 0.62.0 and wasm-tools 1.261.0.
From `rust/`, run:

```sh
rustup target add wasm32-unknown-unknown
cargo build --release --target wasm32-unknown-unknown
wasm-tools component new target/wasm32-unknown-unknown/release/fuzzy.wasm -o ../wasm/fuzzy.wasm
wasm-tools component wit ../wasm/fuzzy.wasm
```

The last command reports no imports and this export:

```wit
package root:component;
world root {
  export distance: func(a: string, b: string) -> s64;
}
```

`rust/` and `wit/` are build sources, excluded from the package hash.
