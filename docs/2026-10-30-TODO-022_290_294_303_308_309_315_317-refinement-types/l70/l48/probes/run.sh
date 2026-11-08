#!/bin/bash
# 準備の段だけを全48文書に当てる（L70.48 の数え直し）。
# 使い方: run.sh <formal の作業ディレクトリ> <出力の jsonl> <書き出しの stage ディレクトリ> <共有ロック>
# 文書ごとに共有ロックを取り、同じディレクトリの prep-all.lean を `lake env lean --run` で実行する。
F=$1; OUT=$2; D=$3; LOCK=$4; P=$(cd "$(dirname "$0")" && pwd)/prep-all.lean
: > $OUT
cd $D
{ echo ./named-programs-builtins.json; find -L . -name "*builtins*.json" ! -path "./named-programs-builtins.json" | sort; } | while read f; do
  c=${f/builtins/corpus}; s=${f/builtins/stdlib}; [ -f $s ] || s=$(dirname $f)/stdlib-decls.json
  [ -f $c ] && [ -f $s ] || { echo "MISSING $f" >&2; continue; }
  k=$(echo ${f#./} | tr '/' '_'); st=$(date +%s)
  (cd $F && /usr/bin/lockf -t 3600 $LOCK lake env lean -M 12288 --run $P "$k" "$D/$c" "$D/$f" "$D/$s") >> $OUT 2>> $OUT.err; e=$?
  echo "$k exit=$e $(( $(date +%s)-st ))s" >> $OUT.log
done
echo done >> $OUT.log
