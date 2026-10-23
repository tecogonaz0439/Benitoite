#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-23-f4dda59f-batch5-f3/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-23-f4dda59f-batch5-f3/profiles/before.json.gz -- <repo>/target/bench/builds/a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-23-f4dda59f-batch5-f3/profiles/after.json.gz -- <repo>/target/bench/builds/f4dda59f35807b7555992ea7c8ac74ab0e31aa8f-default/release/benitoite "$COMMAND" "$INPUT"
fi
