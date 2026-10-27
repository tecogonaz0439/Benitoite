#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-24-f17f1193-syntax-batch6-m01/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-24-f17f1193-syntax-batch6-m01/profiles/before.json.gz -- <repo>/target/bench/builds/706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-24-f17f1193-syntax-batch6-m01/profiles/after.json.gz -- <repo>/target/bench/builds/f17f11933b981509014c841936731f114383aff6-default/release/benitoite "$COMMAND" "$INPUT"
fi
