#!/usr/bin/env bash
# stable で行う lint・テスト・回収の強制と、規約・ライセンスの検査をここに置く。
# 言語仕様と付録の例は、cargo test の tests/spec_examples.rs で検査する。
# 回収の強制は全体をここで検査し、根の数え漏れを各作業で見つける。
# nightly が要る Miri と到達可能性の比較の長い実行は check-heap.sh に置く
# （実装プラン 00-02「完了条件の共通の検査」）。
# R11: ヒープ検証器・根の漏れ・到達可能性の比較（既定 24 列、各 320 操作）と
# 七つの VM の形・CONR をマーク・スイープで走らせる。通常の cargo test が
# R02・R07 の compile_fail と対の no_run の rustdoc の例も実行する。
# Miri・対象ごとの確保・到達可能性の長い比較（20000 列）は check-heap.sh に置く。
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

check_placeholder_allows() {
    local source_file
    local failed=0

    while IFS= read -r source_file; do
        if ! grep -Fq 'todo!(' "$source_file"; then
            printf 'leftover placeholder allow: %s\n' "$source_file" >&2
            failed=1
        fi
    done < <(grep -rlF --include='*.rs' '#![allow(clippy::todo, unused_variables)]' crates/benitoite/src/ || true)

    return "$failed"
}

run_check "format" cargo fmt --all --check
run_check "lint (mark-sweep)" cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats
run_check "test (mark-sweep)" cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify
run_check "gc-stress (mark-sweep)" cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --lib --tests
run_check "leftover placeholder allows" check_placeholder_allows
run_check "spec coverage tool" python3 tools/spec-coverage/spec_coverage.py --self-test
run_check "licenses" check_licenses

printf 'all checks passed\n'
