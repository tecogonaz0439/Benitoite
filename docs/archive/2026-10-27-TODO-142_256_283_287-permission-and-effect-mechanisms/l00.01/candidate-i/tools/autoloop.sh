#!/bin/zsh
# 試行 n から始め、失敗したファイルに腕の機械的な書き換えを当てて単独で通れば次の試行へ進む。
S=<scratch>
W=<wt>
D=$W/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.01/candidate-i
n=$1; last=$2
while [ $n -le $last ]; do
  $S/trial.sh $n 8 | grep -E '^\{|^error|exit' | cut -c1-260
  if grep -q '== exit 0' $D/build-$n-trial.log; then echo "build ok at $n"; break; fi
  files=$(python3 -c "import json;d=json.load(open('$D/counts-$n.json'));print(' '.join(sorted({x['file'] for x in d['diagnostics'] if x['kind']=='error'})))")
  cd $W/formal
  python3 -I $S/fixarms.py ${=files}
  bad=0
  for f in ${=files}; do
    out=$(lake env lean -M 12288 $f 2>&1 | grep -E '^[^ ]+\.lean:[0-9]+:[0-9]+: error')
    if [ -n "$out" ]; then echo "manual needed: $f"; echo "$out" | cut -c1-200 | head -8; bad=1; fi
  done
  n=$((n+1))
  if [ $bad = 1 ]; then echo "next trial number: $n"; break; fi
done
