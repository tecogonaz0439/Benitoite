#!/bin/zsh
# 使い方: loop.sh 開始番号 — 失敗したファイルを書き換えては作り直し、書き換えが無くなったら止まる
set -u
S=<scratch>
L=<wt>/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.06c
n=$1
while true; do
  N=$(printf %02d $n)
  $S/build.sh $N | head -1
  if grep -q '== exit 0' $L/build-$N-trial.log; then echo "BUILD OK $N"; break; fi
  files=($(python3 -I -c "import json;d=json.load(open('$L/count-$N.json'));print(' '.join(d['error_files']))"))
  out=$(python3 -I $S/fixtop.py $N $files)
  echo "fix $N: $(echo $out | tr -d '\n ')"
  if [ "$(echo $out | tr -d '{} \n')" = "" ]; then echo "STOP $N"; break; fi
  n=$((n+1))
done
