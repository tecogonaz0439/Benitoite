#!/usr/bin/env bash
# nightly が要る Miri と、到達可能性の比較の長い実行をここに置く。
# stable の共通の検査と回収の強制は check.sh で行う
# （設計書 07-03「ヒープとランタイムの確かめ方（初回リリース版）」）。
# 後の作業は、runtime::heap:: の下の Miri で動かせない・遅すぎるテストに
# #[cfg_attr(miri, ignore)] を理由のコメントとともに付け、Miri で動かせない VM のテストは
# vm::miri_tests に置かない。絞り込みを変えるときは ADR 0318 を改める。
# 到達可能性を比べるテストは BENITOITE_HEAP_RANDOM_CASES から組み合わせの数を読み、
# 未指定時の数は、テストを書く作業が check.sh の時間を妨げない小さな値にする。
# R11: 到達可能性の比較は既定 24 列から 20000 列（各 320 操作）へ増やす。
# Miri では同じ比較を 2 列・各 24 操作に縮め、VM の七つの形・CONR と
# 根の漏れの世代検査を実行する。対象ごとの確保でも、解放した領域を読まないことを確かめる。
# R01・R03・R04 の百万規模の確保・深い構造・解放の連鎖は、Miri でだけ 64 個に縮める。
# Miri の絞り込みはモジュールの名前の頭で行う。VM のテストは、Miri のために選んだ
# vm::miri_tests だけを走らせ、vm:: のほかのテストは check.sh でだけ走らせる。
# スクリプトの全体は 10 分以内に収める（ADR 0318）。
# ヒープ検証器・回収の強制・compile_fail/no_run の通常の検査は check.sh に置く。
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

check_miri() {
    if ! cargo +nightly miri --version >/dev/null 2>&1; then
        printf '%s\n' \
            'nightly Rust or Miri is unavailable. Install them with:' \
            'rustup toolchain install nightly' \
            'rustup component add --toolchain nightly miri' >&2
        return 1
    fi
}

run_check "Miri availability" check_miri

# .cargo/config.toml の build.warnings = "deny" は Miri の sysroot の構築も止めるため、
# 暗黙の sysroot の構築を含む Miri の実行にだけ CARGO_BUILD_WARNINGS=warn を与える
# （実装プラン C00「scripts/check-heap.sh」）。stable の警告は check.sh で誤りにする。
# runtime::heap:: の下のヒープのテストと、vm::miri_tests の選んだ VM のテストを走らせる。
run_check "Miri (mark-sweep)" env CARGO_BUILD_WARNINGS=warn cargo +nightly miri test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --lib -- runtime::heap:: vm::miri_tests::

# runtime::heap:: の下のヒープのテストで、塊の中の論理的な解放を対象ごとの確保でも確かめる。
run_check "Miri per-object (mark-sweep)" env CARGO_BUILD_WARNINGS=warn cargo +nightly miri test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify,heap-per-object --lib -- runtime::heap::

# runtime::heap:: の下のヒープのテストを対象に、R11 の到達可能性の比較を長く実行する。
run_check "heap random cases (mark-sweep)" env BENITOITE_HEAP_RANDOM_CASES=20000 cargo test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --lib -- runtime::heap::

printf 'all heap checks passed\n'
