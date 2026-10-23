#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-23-81bf92d4-batch5-a6/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-23-81bf92d4-batch5-a6/profiles/before.json.gz -- <repo>/target/bench/builds/a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-23-81bf92d4-batch5-a6/profiles/after.json.gz -- <repo>/target/bench/builds/81bf92d4a6fe7c79e7193f716c0b286ef1a3ed93-default/release/benitoite "$COMMAND" "$INPUT"
fi
