#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-26-1f1f32ae-syntax-batch6-a18/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-26-1f1f32ae-syntax-batch6-a18/profiles/before.json.gz -- <repo>/target/bench/builds/ac992bde2cb34d1861de3eb2943e75443a108189-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-26-1f1f32ae-syntax-batch6-a18/profiles/after.json.gz -- <repo>/target/bench/builds/1f1f32aeaf1c37dddb106ffcb82551bdfa5b0b90-default/release/benitoite "$COMMAND" "$INPUT"
fi
