#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-24-958fbbd3-syntax-batch6-r05/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-24-958fbbd3-syntax-batch6-r05/profiles/before.json.gz -- <repo>/target/bench/builds/706d7ca3d16fc27d67e2ded0f7b1fee371aeb8a8-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-24-958fbbd3-syntax-batch6-r05/profiles/after.json.gz -- <repo>/target/bench/builds/958fbbd3228c8d379304fea16f4c00129a026a3b-default/release/benitoite "$COMMAND" "$INPUT"
fi
