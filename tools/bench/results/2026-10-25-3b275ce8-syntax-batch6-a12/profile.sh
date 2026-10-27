#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-25-3b275ce8-syntax-batch6-a12/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-25-3b275ce8-syntax-batch6-a12/profiles/before.json.gz -- <repo>/target/bench/builds/ac992bde2cb34d1861de3eb2943e75443a108189-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-25-3b275ce8-syntax-batch6-a12/profiles/after.json.gz -- <repo>/target/bench/builds/3b275ce839a27e35e0ba47028cde8801a64011b6-default/release/benitoite "$COMMAND" "$INPUT"
fi
