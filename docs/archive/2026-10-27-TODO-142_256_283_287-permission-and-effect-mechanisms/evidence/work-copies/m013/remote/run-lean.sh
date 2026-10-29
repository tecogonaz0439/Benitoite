#!/bin/zsh
# 別機（m1macmini）の上で、試作の Lean のファイルを一つ検査する。
# 使い方: run-lean.sh <spikes の下のディレクトリ> <ファイル> [メモリの上限 MiB] [時間の上限 秒]
# -M が効かない場合に備え、top の MEM を 5 秒ごとに見て上限を超えたら止める（記憶 lean-memory-limit）。
set -u
DIR=$1; FILE=$2; MEM=${3:-6144}; LIMIT=${4:-900}
KILL_GB=10
cd ~/src/benitoite-m013/spikes/$DIR || exit 2
LOG=$(mktemp -t runlean)
/usr/bin/time -l lean -M $MEM $FILE > $LOG 2>&1 &
TPID=$!
START=$SECONDS; PEAK=0; WHY=""
while kill -0 $TPID 2>/dev/null; do
  sleep 5
  LPID=$(pgrep -P $TPID lean | head -1)
  if [ -n "$LPID" ]; then
    M=$(top -l 1 -pid $LPID -stats mem | tail -1 | tr -d ' ')
    case $M in
      *G) V=${M%G}; V=${V%%[^0-9.]*}; MB=$(printf '%.0f' $((V*1024)));;
      *M) V=${M%M}; V=${V%%[^0-9.]*}; MB=$(printf '%.0f' $V);;
      *) MB=0;;
    esac
    [ $MB -gt $PEAK ] && PEAK=$MB
    if [ $MB -gt $((KILL_GB*1024)) ]; then WHY="memory ${MB}MB > ${KILL_GB}GB"; kill $LPID; fi
  fi
  if [ $((SECONDS-START)) -gt $LIMIT ]; then WHY="time > ${LIMIT}s"; [ -n "${LPID:-}" ] && kill $LPID; kill $TPID 2>/dev/null; fi
done
wait $TPID; RC=$?
cat $LOG
echo "== run-lean: exit $RC, elapsed $((SECONDS-START))s, top-mem-peak ${PEAK}MB ${WHY:+, stopped: $WHY}"
rm -f $LOG
