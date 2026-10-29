#!/bin/zsh
# 試行 n から、失敗したファイルを単独で検査し、Top の構築関数への置き換えを繰り返す。
S=<scratch>
W=<wt>
D=$W/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.01/candidate-i
n=$1; last=$2
while [ $n -le $last ]; do
  $S/trial.sh $n 6 | grep -E '^\{|^error|exit|acquired|real' | cut -c1-260
  if grep -q '== exit 0' $D/build-$n-trial.log; then echo "build ok at $n"; break; fi
  files=$(python3 -c "import json;d=json.load(open('$D/counts-$n.json'));print(' '.join(sorted({x['file'] for x in d['diagnostics'] if x['kind']=='error'})))")
  cd $W/formal
  bad=0
  for f in ${=files}; do
    for k in 1 2 3 4 5 6; do
      lake env lean -M 12288 $f > $S/lean-out.txt 2>&1
      if ! grep -qE '^[^ ]+\.lean:[0-9]+:[0-9]+: error' $S/lean-out.txt; then break; fi
      r=$(python3 -I $S/fixtop.py $S/lean-out.txt $f)
      echo "$r"
      if echo "$r" | grep -q ' 0$'; then break; fi
    done
    if grep -qE '^[^ ]+\.lean:[0-9]+:[0-9]+: error' $S/lean-out.txt; then echo "manual needed: $f"; grep -E 'error' $S/lean-out.txt | cut -c1-200 | head -6; bad=1; fi
  done
  n=$((n+1))
  if [ $bad = 1 ]; then echo "next trial number: $n"; break; fi
done
