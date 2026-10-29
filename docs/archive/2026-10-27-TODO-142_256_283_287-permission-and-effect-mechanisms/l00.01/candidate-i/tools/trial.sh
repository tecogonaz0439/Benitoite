#!/bin/zsh
# 試行 n の差分を保存し、ビルド時点のソースの写しを作り、排他の道具でビルドして数える。
n=$1
S=<scratch>
W=<wt>
D=docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/l00.01/candidate-i
cd $W
git diff -- formal > $D/trial-$n.diff
rm -rf $S/snap-$n; mkdir -p $S/snap-$n; git archive HEAD formal | tar -x -C $S/snap-$n
(cd $S/snap-$n && patch -s -p1 < $W/$D/trial-$n.diff)
cd formal
echo "start $(date +%T)"
<repo>/work/m013/lake-build-locked.sh ../$D/build-$n-trial.log
echo "end $(date +%T)"
grep -E 'lock acquired| real|maximum resident' ../$D/build-$n-trial.log
python3 -I $S/count_breaks.py . ../$D/build-$n-trial.log Benitoite.Release.Atom,Benitoite.Release.Types ../$D/counts-$n.json $S/snap-$n/formal
grep -E '^error: [^ ]+\.lean' ../$D/build-$n-trial.log | cut -c1-170 | head -${2:-25}
