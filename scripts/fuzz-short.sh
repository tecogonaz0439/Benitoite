#!/usr/bin/env bash
set -euo pipefail

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

failed_targets=()
for target in check_bytes check_mutated compile_ok check_modules format; do
    printf 'Running %s for 60 seconds\n' "$target"
    if cargo +nightly fuzz run "$target" -- -max_total_time=60; then
        printf 'Completed %s without a failure\n' "$target"
    else
        status=$?
        failed_targets+=("$target")
        printf 'FAILED: %s (exit %s); continuing with remaining targets\n' "$target" "$status" >&2
    fi
done

if (( ${#failed_targets[@]} > 0 )); then
    printf 'Failed fuzz targets (see fuzz/artifacts/<target>/):\n' >&2
    printf '  %s\n' "${failed_targets[@]}" >&2
    exit 1
fi

printf 'All five fuzz targets completed without a failure\n'
