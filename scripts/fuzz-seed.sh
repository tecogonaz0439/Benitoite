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
    for target in check_mutated compile_ok format; do
        corpus_dir="$repo_root/fuzz/corpus/$target"
        mkdir -p "$corpus_dir"
        cp "$source_file" "$corpus_dir/$seed_name"
    done
    seed_count=$((seed_count + 1))
done < <(find "$testdata_dir" -type d \( -name '*.files' -o -name '*.formatted' \) -prune -o -type f -name '*.bnt' -print0)

printf 'Copied %s .bnt seed(s) to check_mutated, compile_ok and format corpora\n' "$seed_count"

# 固定のパスに収まるディレクトリだけを写し、別のモジュール構成に変えてしまわない
# （実装プラン C15「種の入力」）。バイト 0x00 はシェルの変数に保存せず Python で連結する。
python3 - "$testdata_dir" "$repo_root/fuzz/corpus/check_modules" <<'PY'
from pathlib import Path
import sys
import zlib

testdata = Path(sys.argv[1])
corpus = Path(sys.argv[2])
paths = (
    "main.bnt",
    "Lib/Text.bnt",
    "Lib/Geometry/Shape.bnt",
    "Util.bnt",
    "Lib/Deep/Inner.bnt",
    "util.bnt",
)
copied = skipped = 0
corpus.mkdir(parents=True, exist_ok=True)
for entry in sorted(testdata.rglob("main.bnt")):
    if any(part.endswith((".files", ".formatted")) for part in entry.relative_to(testdata).parts):
        continue
    directory = entry.parent
    contents = {
        source.relative_to(directory).as_posix(): source.read_bytes()
        for source in directory.rglob("*.bnt")
        if not any(part.endswith(".files") for part in source.relative_to(directory).parts)
    }
    if not contents.keys() <= set(paths) or any(b"\x00" in text for text in contents.values()):
        skipped += 1
        continue
    last = max(index for index, path in enumerate(paths) if path in contents)
    data = b"\x00".join(contents.get(path, b"") for path in paths[:last + 1])
    relative = directory.relative_to(testdata).as_posix()
    seed_id = zlib.crc32(relative.encode("utf-8"))
    (corpus / f"{seed_id}-{directory.name}").write_bytes(data)
    copied += 1

print(f"Copied {copied} directory seed(s) to check_modules corpus; skipped {skipped} unrepresentable directory seed(s)")
PY
