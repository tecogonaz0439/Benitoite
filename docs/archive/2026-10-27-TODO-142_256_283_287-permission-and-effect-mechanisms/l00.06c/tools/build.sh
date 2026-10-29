#!/bin/zsh
# 使い方: build.sh NN  — 反映、排他の既定ビルド、差分の保存、件数の集計
set -u
N=$1
S=<scratch>
WT=<wt>
L=$WT/docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.06c
zsh $S/sync.sh
cd $WT && git diff -- formal > $L/trial-$N.diff
cd $WT/formal && <repo>/work/m013/lake-build-locked.sh $L/build-$N-trial.log
python3 -I $L/tools/breakage.py $WT/formal $L/build-$N-trial.log $L/count-$N.json
head -2 $L/build-$N-trial.log | tail -1
grep -E ' real|maximum resident' $L/build-$N-trial.log
