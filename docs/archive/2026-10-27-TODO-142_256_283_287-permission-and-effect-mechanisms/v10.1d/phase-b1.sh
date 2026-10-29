#!/bin/bash
# V10.1d の段 B1: 入力が同じ段の出力を引用として写し、範囲の実ソースの段（H31 と CLI の変化）を走らせ直す。
set -euo pipefail
wt="$1"; log="$2"; here="$3"
cd "$wt"
OUT="$wt/target/desugar-diff/v10.1d"; COV="$wt/target/coverage-diff/v10.1d"; INT="$wt/target/interval-diff/v10.1d"
export BENITOITE_DESUGAR_DIFF_DIR="$OUT" BENITOITE_COVERAGE_DIFF_DIR="$COV" BENITOITE_INTERVAL_DIFF_DIR="$INT"
step() { name="$1"; shift; printf '== %s\n' "$name"; /usr/bin/time -l "$@" > "$log/$name.log" 2>&1; st=$?; printf '%s exit %s\n' "$name" "$st"; return $st; }
step cite python3 -I "$here/cite.py" "$wt/target" "$log/compare.json" "$log/cited.json"
step range-sources python3 -B formal/tests/test_range_sources.py \
    --exports "$OUT/range-sources" --cli "$wt/target/debug/benitoite" --output "$OUT/range-source-comparison"
step h31-verify python3 -I "$here/h31-final-verify.py" "$wt" "$log/h31-final.json"
step range-known-differences python3 -B formal/tests/test_range_known_differences.py \
    --cli "$wt/target/debug/benitoite" --output-dir "$OUT/range-known-differences"
printf '%s\n' 'phase B1 done'
