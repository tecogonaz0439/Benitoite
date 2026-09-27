#!/usr/bin/env bash
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

if ! rustc +nightly --version >/dev/null 2>&1; then
    cat >&2 <<'EOF'
fuzzing requires the nightly Rust toolchain.
Install it with: rustup toolchain install nightly
EOF
    exit 1
fi

if ! cargo +nightly fuzz --version >/dev/null 2>&1; then
    cat >&2 <<'EOF'
fuzzing requires cargo-fuzz 0.13.2.
Install it with: cargo install cargo-fuzz --version 0.13.2 --locked
EOF
    exit 1
fi

./scripts/fuzz-seed.sh

for target in check_bytes check_mutated compile_ok; do
    printf 'Running %s for 60 seconds\n' "$target"
    cargo +nightly fuzz run "$target" -- -max_total_time=60
done
