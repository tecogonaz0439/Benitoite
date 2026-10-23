#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-23-678aba50-batch5-f5r/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-23-678aba50-batch5-f5r/profiles/before.json.gz -- <repo>/target/bench/builds/a1f4fb5f3e5c3619aad6ecb2b1f7c9d20586317a-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-23-678aba50-batch5-f5r/profiles/after.json.gz -- <repo>/target/bench/builds/678aba50ae8f6ad52d0bdb26e7847d62bcbb7b5c-default/release/benitoite "$COMMAND" "$INPUT"
fi
