#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-25-2d563be9-syntax-batch6-a07/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-25-2d563be9-syntax-batch6-a07/profiles/before.json.gz -- <repo>/target/bench/builds/ac992bde2cb34d1861de3eb2943e75443a108189-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-25-2d563be9-syntax-batch6-a07/profiles/after.json.gz -- <repo>/target/bench/builds/2d563be9d72a1baf19065b081cf51de32a0cf52a-default/release/benitoite "$COMMAND" "$INPUT"
fi
