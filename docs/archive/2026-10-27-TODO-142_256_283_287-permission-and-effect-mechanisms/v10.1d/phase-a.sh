#!/bin/bash
# V10.1d の段 A: 版上げの後の Rust の書き出しを新しい出力先へ作り直す（check-formal.sh の該当段と同じ引数）。
set -euo pipefail
wt="$1"; log="$2"
cd "$wt"
OUT="$wt/target/desugar-diff/v10.1d"; COV="$wt/target/coverage-diff/v10.1d"; INT="$wt/target/interval-diff/v10.1d"
export BENITOITE_DESUGAR_DIFF_DIR="$OUT" BENITOITE_COVERAGE_DIFF_DIR="$COV" BENITOITE_INTERVAL_DIFF_DIR="$INT"
step() { name="$1"; shift; printf '== %s\n' "$name"; /usr/bin/time -l "$@" > "$log/$name.log" 2>&1; st=$?; printf '%s exit %s\n' "$name" "$st"; return $st; }
python3 -B scripts/check/formal_interval.py prepare --interval-dir "$INT" --desugar-dir "$OUT" --coverage-dir "$COV"
step coverage-export cargo test --test coverage_export -- --include-ignored --nocapture
step rust-export cargo test --test desugar_export -- --include-ignored --nocapture --skip export_interval
for entry in identity manifest range vm; do
    step "interval-$entry" env BENITOITE_DESUGAR_DIFF_DIR="$INT/$entry" cargo test --test desugar_export "export_interval_$entry" -- --nocapture
done
step cli-build cargo build -p benitoite --bin benitoite
printf '%s\n' 'phase A done'
