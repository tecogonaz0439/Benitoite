#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
testdata_dir="$repo_root/crates/benitoite/testdata"

if [[ ! -d "$testdata_dir" ]]; then
    printf 'No testdata directory yet; no fuzz seeds copied: %s\n' "$testdata_dir"
    exit 0
fi

seed_count=0
while IFS= read -r -d '' source_file; do
    relative_path=${source_file#"$testdata_dir"/}
    seed_id=$(printf '%s' "$relative_path" | cksum | awk '{print $1}')
    seed_name="${seed_id}-${relative_path##*/}"
    for target in check_mutated compile_ok; do
        corpus_dir="$repo_root/fuzz/corpus/$target"
        mkdir -p "$corpus_dir"
        cp "$source_file" "$corpus_dir/$seed_name"
    done
    seed_count=$((seed_count + 1))
done < <(find "$testdata_dir" -type d -name '*.files' -prune -o -type f -name '*.bnt' -print0)

printf 'Copied %s .bnt seed(s) to check_mutated and compile_ok corpora\n' "$seed_count"
