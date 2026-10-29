#!/bin/bash
# Lean の証明、脱糖・宣言表・網羅性の差分検査と型検査済みの全定義の検査。
# 出力は target/{desugar,coverage,interval}-diff/ に保持する。macOS /bin/bash 3.2 で動く。
# 形式化の内側では、処理系より先に定義・証明・01-12 の写しをそろえ、sorry のない既定の
# lake build と定義・言明・仮定のレビューを完了する。本スクリプトの全比較は、Rust と Lean の
# 接続を閉じる区切りと最終の関係状態に割り当て、同じ状態への成功は引用できる。
# check.sh の formal_build は既定のビルドだけで、全比較の代わりにはならない。
# 検査時期と引用は設計書 07-03「実装の規約と静的な検査」、先行条件は 07-04 に従う。
# このファイルの変更は formal に分類する。説明だけなら計画で --only 等を名指しする。
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "$BASH_SOURCE")/.." && pwd)"
cd "$repo_root"
output_dir="${BENITOITE_DESUGAR_DIFF_DIR:-$repo_root/target/desugar-diff/run-$$}"
# 書き出し側もパスを検査する。絶対パスにして cargo の作業ディレクトリに依存させない。
case "$output_dir" in
    /*) ;;
    *) output_dir="$repo_root/$output_dir" ;;
esac
case "$output_dir" in
    "$repo_root"/*) ;;
    *) printf '%s\n' 'output directory must be inside the repository' >&2; exit 2 ;;
esac
export BENITOITE_DESUGAR_DIFF_DIR="$output_dir"
coverage_dir="${BENITOITE_COVERAGE_DIFF_DIR:-$repo_root/target/coverage-diff/run-$$}"
case "$coverage_dir" in
    /*) ;;
    *) coverage_dir="$repo_root/$coverage_dir" ;;
esac
case "$coverage_dir" in
    "$repo_root"/*) ;;
    *) printf '%s\n' 'coverage output directory must be inside the repository' >&2; exit 2 ;;
esac
# 既存の脱糖 corpus/report/builtins と別の出力先を使う。
if [ "$coverage_dir" = "$output_dir" ]; then
    printf '%s\n' 'coverage and desugar output directories must differ' >&2
    exit 2
fi
export BENITOITE_COVERAGE_DIFF_DIR="$coverage_dir"
interval_dir="${BENITOITE_INTERVAL_DIFF_DIR:-$repo_root/target/interval-diff/run-$$}"
case "$interval_dir" in
    /*) ;;
    *) interval_dir="$repo_root/$interval_dir" ;;
esac
# リンク・..・親子関係も含めて三出力先の衝突を拒み、以前の報告を混ぜない。
python3 -B scripts/check/formal_interval.py prepare \
    --interval-dir "$interval_dir" --desugar-dir "$output_dir" --coverage-dir "$coverage_dir"
export BENITOITE_INTERVAL_DIFF_DIR="$interval_dir"

build_start=$SECONDS
printf '%s\n' '== formal: lake build'
build_output="$(cd formal && lake build 2>&1)" || {
    printf '%s\n' "$build_output" >&2
    exit 1
}
printf '%s\n' "$build_output"
if printf '%s\n' "$build_output" | grep -q 'declaration uses .sorry.'; then
    printf '%s\n' 'formal/ has sorry' >&2
    exit 1
fi
printf 'lake build: %ss\n' "$((SECONDS - build_start))"

exe_start=$SECONDS
printf '%s\n' '== formal: lake build desugarDiff'
(cd formal && lake build desugarDiff)
printf 'lake build desugarDiff: %ss\n' "$((SECONDS - exe_start))"

exe_start=$SECONDS
printf '%s\n' '== formal: lake build builtinCheck'
build_output="$(cd formal && lake build builtinCheck 2>&1)" || {
    printf '%s\n' "$build_output" >&2
    exit 1
}
printf '%s\n' "$build_output"
if printf '%s\n' "$build_output" | grep -q 'declaration uses .sorry.'; then
    printf '%s\n' 'builtinCheck has sorry' >&2
    exit 1
fi
printf 'lake build builtinCheck: %ss\n' "$((SECONDS - exe_start))"

coverage_build_start=$SECONDS
printf '%s\n' '== formal: lake build coverageDiff'
(cd formal && lake build coverageDiff)
printf 'lake build coverageDiff: %ss\n' "$((SECONDS - coverage_build_start))"

coverage_export_start=$SECONDS
printf '%s\n' '== formal: Rust coverage export'
cargo test --test coverage_export -- --include-ignored --nocapture
printf 'Rust coverage export (including cargo): %ss\n' "$((SECONDS - coverage_export_start))"

coverage_diff_start=$SECONDS
printf '%s\n' '== formal: coverageDiff'
coverage_status=0
formal/.lake/build/bin/coverageDiff "$coverage_dir/named-all-corpus.json" "$coverage_dir/report.json" || coverage_status=$?
printf 'coverageDiff: %ss; report: %s/report.json\n' "$((SECONDS - coverage_diff_start))" "$coverage_dir"
# 閉じた通常入力に加え、view を持つ独立入力も毎回比較する。
printf '%s\n' '== formal: coverageDiff with views'
formal/.lake/build/bin/coverageDiff "$coverage_dir/future-corpus.json" "$coverage_dir/future-report.json" || coverage_status=$?
printf 'coverage stages: %ss\n' "$((SECONDS - coverage_build_start))"

program_coverage_build_start=$SECONDS
printf '%s\n' '== formal: lake build coverageProgramDiff'
(cd formal && lake build coverageProgramDiff)
printf 'lake build coverageProgramDiff: %ss\n' "$((SECONDS - program_coverage_build_start))"

surface_build_start=$SECONDS
printf '%s\n' '== formal: lake build surfaceCheck'
(cd formal && lake build surfaceCheck)
printf '%s\n' '== formal: lake build surfaceCheckAll'
(cd formal && lake build surfaceCheckAll)
printf 'lake build surfaceCheckAll: %ss\n' "$((SECONDS - surface_build_start))"

interval_build_start=$SECONDS
printf '%s\n' '== formal: lake build intervalDiff'
(cd formal && lake build intervalDiff)
printf 'lake build intervalDiff: %ss\n' "$((SECONDS - interval_build_start))"

width_exchange_start=$SECONDS
printf '%s\n' '== formal: width exchange'
python3 -I formal/tests/test_width_exchange.py
printf 'width exchange: %ss; reports: target/p3a-gate/width-exchange/\n' "$((SECONDS - width_exchange_start))"

named_exchange_start=$SECONDS
printf '%s\n' '== formal: named exchange'
python3 -I formal/tests/test_named_exchange.py
printf 'named exchange: %ss\n' "$((SECONDS - named_exchange_start))"

extensible_exchange_start=$SECONDS
printf '%s\n' '== formal: extensible exchange'
python3 -I formal/tests/test_extensible_exchange.py
printf 'extensible exchange: %ss\n' "$((SECONDS - extensible_exchange_start))"

try_exchange_start=$SECONDS
printf '%s\n' '== formal: try exchange'
python3 -I formal/tests/test_try_exchange.py
printf 'try exchange: %ss\n' "$((SECONDS - try_exchange_start))"

batch2_start=$SECONDS
printf '%s\n' '== formal: batch2 independent exchange'
python3 -B formal/tests/test_batch2_exchange.py
printf 'batch2 exchange: %ss\n' "$((SECONDS - batch2_start))"

batch3_start=$SECONDS
printf '%s\n' '== formal: batch3 independent exchange'
python3 -B formal/tests/test_batch3_exchange.py
printf 'batch3 independent exchange: %ss\n' "$((SECONDS - batch3_start))"

batch4_start=$SECONDS
printf '%s\n' '== formal: batch4 independent exchange'
python3 -B formal/tests/test_batch4_exchange.py
printf 'batch4 independent exchange: %ss\n' "$((SECONDS - batch4_start))"

range_exchange_start=$SECONDS
printf '%s\n' '== formal: range independent exchange'
python3 -I formal/tests/test_range_exchange.py --output "$output_dir/range-exchange-comparison"
printf 'range independent exchange: %ss\n' "$((SECONDS - range_exchange_start))"

export_start=$SECONDS
printf '%s\n' '== formal: Rust export'
# 区間専用の四書き出しは次の段でそれぞれ別の出力先へ渡す。
cargo test --test desugar_export -- --include-ignored --nocapture --skip export_interval
printf 'Rust export (including cargo): %ss\n' "$((SECONDS - export_start))"

interval_start=$SECONDS
printf '%s\n' '== formal: Rust interval exports'
for entry in identity manifest range vm; do
    BENITOITE_DESUGAR_DIFF_DIR="$interval_dir/$entry" \
        cargo test --test desugar_export "export_interval_$entry" -- --nocapture
done
# VM 比較で起動する実 CLI を、この関係状態から用意する。
cargo build -p benitoite --bin benitoite
range_source_start=$SECONDS
printf '%s\n' '== formal: independent range sources and rejection comparison'
python3 -B formal/tests/test_range_sources.py \
    --exports "$output_dir/range-sources" --cli "$repo_root/target/debug/benitoite" \
    --output "$output_dir/range-source-comparison"
printf 'range source comparison: %ss\n' "$((SECONDS - range_source_start))"
range_budget_start=$SECONDS
printf '%s\n' '== formal: range numbering and analysis budgets'
python3 -B formal/tests/test_range_budget_sources.py \
    --rust-dir "$output_dir/range-budget" --output-dir "$output_dir/range-budget-comparison"
printf 'range budget comparison: %ss\n' "$((SECONDS - range_budget_start))"
known_difference_start=$SECONDS
printf '%s\n' '== formal: named range exclusions and accepted controls'
python3 -B formal/tests/test_range_known_differences.py \
    --cli "$repo_root/target/debug/benitoite" --output-dir "$output_dir/range-known-differences"
printf 'range known differences: %ss\n' "$((SECONDS - known_difference_start))"
python3 -B scripts/check/formal_interval.py collect \
    --interval-dir "$interval_dir" --desugar-dir "$output_dir" --coverage-dir "$coverage_dir"
printf '%s\n' '== formal: interval independent/Rust/eval/VM comparison'
python3 -B formal/tests/test_interval_exchange.py \
    --output "$interval_dir/comparison" --source-dir "$interval_dir/identity" \
    --rust-dir "$interval_dir/programs" \
    --rust-dir "$interval_dir/identity" \
    --rust-dir "$interval_dir/manifest/manifest-interval" \
    --rust-dir "$interval_dir/range/interval" \
    --rust-dir "$interval_dir/vm/original" \
    --rust-dir "$interval_dir/vm/instrumented" \
    --rust-dir "$interval_dir/vm/range/original" \
    --rust-dir "$interval_dir/vm/range/instrumented" \
    --rust-dir "$interval_dir/vm/shifts/original" \
    --rust-dir "$interval_dir/vm/shifts/instrumented" \
    --vm-dir "$interval_dir/vm" --cli "$repo_root/target/debug/benitoite"
printf 'interval comparison: %ss; reports: %s/comparison/\n' "$((SECONDS - interval_start))" "$interval_dir"

batch3_start=$SECONDS
printf '%s\n' '== formal: batch3/batch4 Rust exchange'
python3 -B formal/tests/test_batch3_exchange.py --rust-dir "$output_dir/batch3/b3"
for profile in b3 blocks g2 g3; do
    python3 -B crates/benitoite/tests/desugar_export/check_batch3.py \
        --rust-dir "$output_dir/batch3/$profile" --report "$output_dir/batch3/$profile-exchange-results.json"
done
printf 'batch3/batch4 Rust exchange: %ss\n' "$((SECONDS - batch3_start))"

batch5_start=$SECONDS
# --rust-dir の呼び出しは独立入力の単体テストも行うため、両方をここで一度ずつ検査する。
printf '%s\n' '== formal: batch5 independent/Rust exchange'
python3 -B formal/tests/test_batch5_exchange.py --rust-dir "$output_dir/batch5"
printf 'batch5 independent/Rust exchange: %ss\n' "$((SECONDS - batch5_start))"

diff_start=$SECONDS
printf '%s\n' '== formal: desugarDiff'
status=$coverage_status
formal/.lake/build/bin/desugarDiff "$output_dir/named-programs-corpus.json" "$output_dir/report.json" || status=$?
printf 'desugarDiff: %ss; report: %s/report.json\n' "$((SECONDS - diff_start))" "$output_dir"
table_start=$SECONDS
printf '%s\n' '== formal: builtinCheck'
formal/.lake/build/bin/builtinCheck "$output_dir/named-programs-corpus.json" "$output_dir/named-programs-builtins.json" "$output_dir/builtin-report.json" || status=$?
printf 'builtinCheck: %ss; report: %s/builtin-report.json\n' "$((SECONDS - table_start))" "$output_dir"
program_coverage_start=$SECONDS
printf '%s\n' '== formal: coverageProgramDiff'
# 既存の脱糖と E1c-1 の report を上書きせず、別のディレクトリへ保存する。
mkdir -p "$output_dir/coverage"
formal/.lake/build/bin/coverageProgramDiff "$output_dir/named-programs-coverage.json" "$output_dir/named-programs-builtins.json" "$output_dir/coverage/report.json" || status=$?
printf 'coverageProgramDiff: %ss; report: %s/coverage/report.json\n' "$((SECONDS - program_coverage_start))" "$output_dir"
surface_check_start=$SECONDS
printf '%s\n' '== formal: surfaceCheckAll'
# 型検査の成功・対象外を区別し、不一致は 1、準備の失敗は 2 で止める。
mkdir -p "$output_dir/surface-check"
formal/.lake/build/bin/surfaceCheckAll "$output_dir/named-programs-corpus.json" "$output_dir/named-programs-builtins.json" "$output_dir/named-programs-stdlib.json" "$output_dir/surface-check/report.json" || status=$?
printf 'surfaceCheckAll: %ss; report: %s/surface-check/report.json\n' "$((SECONDS - surface_check_start))" "$output_dir"

named_export_start=$SECONDS
printf '%s\n' '== formal: per-program final Rust exports'
# 全件の報告が揃ってから、入力の対応と六入口の件数も照合する。
python3 -I crates/benitoite/tests/desugar_export/check_named.py "$output_dir" "$coverage_dir"
printf 'final exports: %ss; reports: %s/named-*-report.json\n' "$((SECONDS - named_export_start))" "$output_dir"
if [ "$status" -ne 0 ]; then
    exit "$status"
fi
# 六入口の最終照合を通してから、全入力・報告のハッシュと件数を確定して読み戻す。
python3 -B scripts/check/formal_interval.py manifest \
    --interval-dir "$interval_dir" --desugar-dir "$output_dir" --coverage-dir "$coverage_dir"
python3 -B scripts/check/formal_interval.py verify \
    --interval-dir "$interval_dir" --desugar-dir "$output_dir" --coverage-dir "$coverage_dir"
exit "$status"
