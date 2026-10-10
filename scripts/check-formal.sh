#!/bin/bash
# Lean の証明、脱糖・宣言表・網羅性の差分検査と型検査済みの全定義の検査。
# 出力は target/desugar-diff/ と target/coverage-diff/ に保持する。macOS /bin/bash 3.2 で動く。
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
formal/.lake/build/bin/coverageDiff "$coverage_dir/corpus.json" "$coverage_dir/report.json" || coverage_status=$?
printf 'coverageDiff: %ss; report: %s/report.json\n' "$((SECONDS - coverage_diff_start))" "$coverage_dir"
printf 'coverage stages: %ss\n' "$((SECONDS - coverage_build_start))"

program_coverage_build_start=$SECONDS
printf '%s\n' '== formal: lake build coverageProgramDiff'
(cd formal && lake build coverageProgramDiff)
printf 'lake build coverageProgramDiff: %ss\n' "$((SECONDS - program_coverage_build_start))"

surface_build_start=$SECONDS
printf '%s\n' '== formal: lake build surfaceCheckAll'
(cd formal && lake build surfaceCheckAll)
printf 'lake build surfaceCheckAll: %ss\n' "$((SECONDS - surface_build_start))"

export_start=$SECONDS
printf '%s\n' '== formal: Rust export'
cargo test --test desugar_export -- --include-ignored --nocapture
printf 'Rust export (including cargo): %ss\n' "$((SECONDS - export_start))"

diff_start=$SECONDS
printf '%s\n' '== formal: desugarDiff'
status=$coverage_status
formal/.lake/build/bin/desugarDiff "$output_dir/corpus.json" "$output_dir/report.json" || status=$?
printf 'desugarDiff: %ss; report: %s/report.json\n' "$((SECONDS - diff_start))" "$output_dir"
table_start=$SECONDS
printf '%s\n' '== formal: builtinCheck'
formal/.lake/build/bin/builtinCheck "$output_dir/corpus.json" "$output_dir/builtins.json" "$output_dir/builtin-report.json" || status=$?
printf 'builtinCheck: %ss; report: %s/builtin-report.json\n' "$((SECONDS - table_start))" "$output_dir"
program_coverage_start=$SECONDS
printf '%s\n' '== formal: coverageProgramDiff'
# 既存の脱糖と E1c-1 の report を上書きせず、別のディレクトリへ保存する。
mkdir -p "$output_dir/coverage"
formal/.lake/build/bin/coverageProgramDiff "$output_dir/coverage-matches.json" "$output_dir/builtins.json" "$output_dir/coverage/report.json" || status=$?
printf 'coverageProgramDiff: %ss; report: %s/coverage/report.json\n' "$((SECONDS - program_coverage_start))" "$output_dir"
surface_check_start=$SECONDS
printf '%s\n' '== formal: surfaceCheckAll'
# 型検査の成功・既知の差・対象外を区別し、不一致は 1、準備の失敗は 2 で止める。
mkdir -p "$output_dir/surface-check"
formal/.lake/build/bin/surfaceCheckAll "$output_dir/corpus.json" "$output_dir/builtins.json" "$output_dir/stdlib-decls.json" "$output_dir/surface-check/report.json" || status=$?
printf 'surfaceCheckAll: %ss; report: %s/surface-check/report.json\n' "$((SECONDS - surface_check_start))" "$output_dir"
exit "$status"
