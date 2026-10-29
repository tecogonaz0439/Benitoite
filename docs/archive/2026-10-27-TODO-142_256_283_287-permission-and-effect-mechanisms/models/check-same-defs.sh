#!/bin/sh
# 二つの独立小モデルに写した定義の同一性を確かめる（PM30 のレビュー RV-PM の中2への対応）。
#
# PermissionKinds.lean と Policy.lean の本文（#print axioms の行を除く）と same-defs-tail.lean を
# 一時ファイルへ連結し、formal/ の lake env lean で検査する。same-defs-tail.lean は、写した六つの
# 宣言について `@Policy.X = @PermissionKinds.X` を rfl で確かめる。どちらかのモデルを変えたら走らせる。
#
# 使い方: sh <このファイル>（どのディレクトリからでもよい）。終了状態は lean の終了状態で、
# 出力に sorry・error が含まれる場合も 1 とする。一時ファイルは終わったら消す。
set -eu

here=$(cd "$(dirname "$0")" && pwd)
formal=$(cd "$here/../../../formal" && pwd)

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT INT TERM
combined="$tmpdir/SameDefs.lean"
out="$tmpdir/out.log"

grep -v '^#print axioms' "$here/PermissionKinds.lean" > "$combined"
grep -v '^#print axioms' "$here/Policy.lean" >> "$combined"
cat "$here/same-defs-tail.lean" >> "$combined"

status=0
(cd "$formal" && lake env lean -M 12288 "$combined") > "$out" 2>&1 || status=$?
# 一時ファイルの場所は記録に残さないよう置き換えて表示する。
sed "s#$tmpdir#<tmp>#g" "$out"

if [ "$status" -ne 0 ]; then
  echo "check-same-defs: lean exited with $status"
  exit "$status"
fi
if grep -qE 'sorry|error' "$out"; then
  echo "check-same-defs: output contains sorry or error"
  exit 1
fi
echo "check-same-defs: ok"
