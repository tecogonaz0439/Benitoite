#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-27-dc171a72-syntax-batch6-u03/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-27-dc171a72-syntax-batch6-u03/profiles/before.json.gz -- <repo>/target/bench/builds/ac992bde2cb34d1861de3eb2943e75443a108189-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-27-dc171a72-syntax-batch6-u03/profiles/after.json.gz -- <repo>/target/bench/builds/dc171a72882bec1c4ac4f8a31a11b05e11c235a3-default/release/benitoite "$COMMAND" "$INPUT"
fi
