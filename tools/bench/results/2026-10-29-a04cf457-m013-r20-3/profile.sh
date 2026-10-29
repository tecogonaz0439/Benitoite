#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-29-a04cf457-m013-r20-3/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-29-a04cf457-m013-r20-3/profiles/before.json.gz -- <repo>/target/bench/builds/6124775788579e60530f55fb85570f26ef7fa900-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-29-a04cf457-m013-r20-3/profiles/after.json.gz -- <repo>/target/bench/builds/a04cf45702395ea497db59b3294370cb7a6f1a38-default/release/benitoite "$COMMAND" "$INPUT"
fi
