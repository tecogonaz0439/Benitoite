#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$BASH_SOURCE")/.." && pwd)"
cd "$repo_root"

run_check() {
    local check_name="$1"
    shift

    printf '== %s\n' "$check_name"
    if "$@"; then
        return 0
    fi

    printf 'FAILED: %s\n' "$check_name" >&2
    exit 1
}

check_licenses() {
    if ! cargo deny --version >/dev/null 2>&1; then
        printf '%s\n' 'cargo-deny is unavailable. Install it with: cargo install cargo-deny --locked' >&2
        return 1
    fi

    cargo deny check licenses
}

run_check "format" cargo fmt --all --check
run_check "lint" cargo clippy --workspace --all-targets --all-features
run_check "test" cargo test --workspace --all-features
run_check "language examples" python3 tools/grammar-check/grammar_check.py
run_check "spec coverage tool" python3 tools/spec-coverage/spec_coverage.py --self-test
run_check "licenses" check_licenses

printf 'all checks passed\n'
