#!/usr/bin/env bash
# 第三者のライセンスの表示 THIRD_PARTY_LICENSES を、一つのビルド先について生成する
# （設計書 05-01「ライセンスの表示」、ADR 0235・0334、実装プラン 10-19「第三者のライセンスの表示」「リリースのスクリプト」）。
#
# 使い方: scripts/release/licenses.sh <ビルド先> <出力のファイル>
#
# - about.toml の targets をそのビルド先だけにした設定で `cargo about generate --locked --offline` を実行する。
#   ネットワークは使わない（ADR 0334 の決定 3）。依存のパッケージは `cargo fetch --locked` で取得しておく。
# - 各クレートの Cargo.toml の authors は、about.hbs が「Used by」の行に添える（ADR 0334 の決定 1・2）。
# - cargo-about は NOTICE の類のファイルを載せないので、そのビルド先の依存のパッケージの根にある
#   NOTICE・NOTICE.txt・NOTICE.md を、クレートの名前と版を添えて末尾に加える（10-19「第三者のライセンスの表示」）。
# - 環境変数 BENITOITE_LICENSES_MANIFEST で、対象の Cargo.toml を差し替えられる（NOTICE の処理を小さなパッケージで確かめるため）。
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: scripts/release/licenses.sh <target> <output-file>" >&2
    exit 2
fi
target="$1"
output="$2"

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
manifest="${BENITOITE_LICENSES_MANIFEST:-$root/crates/benitoite/Cargo.toml}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# targets の並びを、指定したビルド先だけの 1 行に置き換えた設定を作る
python3 - "$here/about.toml" "$work/about.toml" "$target" <<'PY'
import re, sys
src, dst, target = sys.argv[1], sys.argv[2], sys.argv[3]
with open(src, encoding="utf-8") as f:
    text = f.read()
replaced, count = re.subn(r'(?ms)^targets = \[.*?\]', f'targets = ["{target}"]', text)
if count != 1:
    sys.exit("about.toml: expected exactly one `targets` list")
with open(dst, "w", encoding="utf-8") as f:
    f.write(replaced)
PY

cargo about generate --locked --offline \
    --manifest-path "$manifest" \
    --config "$work/about.toml" \
    --output-file "$work/body.txt" \
    "$here/about.hbs"

# そのビルド先で使う依存（開発用の依存を除く）のパッケージの根から NOTICE を探す
cargo metadata --format-version 1 --locked --offline \
    --manifest-path "$manifest" --filter-platform "$target" > "$work/metadata.json"
python3 - "$work/metadata.json" "$manifest" > "$work/notice.txt" <<'PY'
import json, os, sys
with open(sys.argv[1], encoding="utf-8") as f:
    meta = json.load(f)
manifest = os.path.realpath(sys.argv[2])
packages = {p["id"]: p for p in meta["packages"]}
nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
roots = [p["id"] for p in meta["packages"] if os.path.realpath(p["manifest_path"]) == manifest]
members = set(meta["workspace_members"])
seen, stack = set(), list(roots)
while stack:
    pid = stack.pop()
    if pid in seen:
        continue
    seen.add(pid)
    for dep in nodes.get(pid, {}).get("deps", []):
        kinds = [k.get("kind") for k in dep.get("dep_kinds", [])]
        if any(k != "dev" for k in kinds):
            stack.append(dep["pkg"])
found = []
for pid in seen:
    if pid in members:
        continue
    pkg = packages[pid]
    base = os.path.dirname(pkg["manifest_path"])
    for name in ("NOTICE", "NOTICE.txt", "NOTICE.md"):
        path = os.path.join(base, name)
        if os.path.isfile(path):
            with open(path, encoding="utf-8", errors="replace") as f:
                found.append((pkg["name"], pkg["version"], name, f.read()))
found.sort()
if found:
    print("=" * 80)
    print("NOTICE files")
    print()
    for name, version, file, body in found:
        print("-" * 80)
        print(f"{name} {version} ({file})")
        print()
        print(body.rstrip("\n"))
        print()
PY

mkdir -p "$(dirname "$output")"
cat "$work/body.txt" "$work/notice.txt" > "$output"
