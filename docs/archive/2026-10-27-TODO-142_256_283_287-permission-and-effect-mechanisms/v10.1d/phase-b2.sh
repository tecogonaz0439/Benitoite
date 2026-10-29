#!/bin/bash
# V10.1d の段 B2: 区間の集約と比較（実 CLI が変わったため）、check_named（extensible の書き出しが変わったため）、最終の manifest と verify。
# 引数は check-formal.sh の同じ段と同じ。
set -euo pipefail
wt="$1"; log="$2"
cd "$wt"
OUT="$wt/target/desugar-diff/v10.1d"; COV="$wt/target/coverage-diff/v10.1d"; INT="$wt/target/interval-diff/v10.1d"
export BENITOITE_DESUGAR_DIFF_DIR="$OUT" BENITOITE_COVERAGE_DIFF_DIR="$COV" BENITOITE_INTERVAL_DIFF_DIR="$INT"
step() { name="$1"; shift; printf '== %s\n' "$name"; /usr/bin/time -l "$@" > "$log/$name.log" 2>&1; st=$?; printf '%s exit %s\n' "$name" "$st"; return $st; }
step collect python3 -B scripts/check/formal_interval.py collect --interval-dir "$INT" --desugar-dir "$OUT" --coverage-dir "$COV"
step interval-comparison python3 -B formal/tests/test_interval_exchange.py \
    --output "$INT/comparison" --source-dir "$INT/identity" \
    --rust-dir "$INT/programs" \
    --rust-dir "$INT/identity" \
    --rust-dir "$INT/manifest/manifest-interval" \
    --rust-dir "$INT/range/interval" \
    --rust-dir "$INT/vm/original" \
    --rust-dir "$INT/vm/instrumented" \
    --rust-dir "$INT/vm/range/original" \
    --rust-dir "$INT/vm/range/instrumented" \
    --rust-dir "$INT/vm/shifts/original" \
    --rust-dir "$INT/vm/shifts/instrumented" \
    --vm-dir "$INT/vm" --cli "$wt/target/debug/benitoite"
step check-named python3 -I crates/benitoite/tests/desugar_export/check_named.py "$OUT" "$COV"
step manifest python3 -B scripts/check/formal_interval.py manifest --interval-dir "$INT" --desugar-dir "$OUT" --coverage-dir "$COV"
step verify python3 -B scripts/check/formal_interval.py verify --interval-dir "$INT" --desugar-dir "$OUT" --coverage-dir "$COV"
printf '%s\n' 'phase B2 done'
