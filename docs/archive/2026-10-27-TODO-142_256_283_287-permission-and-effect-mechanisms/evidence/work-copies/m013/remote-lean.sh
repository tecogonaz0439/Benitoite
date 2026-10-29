#!/bin/zsh
# work/m013/spikes/ を別機へ写し、別機の上で Lean のファイルを一つ検査する（ビルドは別機で行う。2026-10-26、設計者）。
# 使い方: remote-lean.sh <spikes の下のディレクトリ> <ファイル> [メモリの上限 MiB] [時間の上限 秒]
set -u
P=<repo>/work/m013
# 別機のメモリは 16GB なので、同時に一つだけ検査する（複数の試作が並行しても順に待つ）。
LOCK=$P/scratch/remote-lean.lock
until mkdir $LOCK 2>/dev/null; do sleep 5; done
trap 'rmdir $LOCK' EXIT
rsync -a --delete $P/spikes/ m1macmini:src/benitoite-m013/spikes/ 2>&1 | grep -v "^[|+]\|Host key"
rsync -a $P/remote/run-lean.sh m1macmini:src/benitoite-m013/bin/ 2>&1 | grep -v "^[|+]\|Host key"
ssh -o BatchMode=yes m1macmini "zsh -lc 'zsh ~/src/benitoite-m013/bin/run-lean.sh $1 $2 ${3:-6144} ${4:-900}'" 2>&1 | grep -v "^[|+]\|Host key"
