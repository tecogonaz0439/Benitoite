#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p <repo>/tools/bench/results/2026-10-28-432ed9df-m013-r10-2b/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-28-432ed9df-m013-r10-2b/profiles/before.json.gz -- <repo>/target/bench/builds/6124775788579e60530f55fb85570f26ef7fa900-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o <repo>/tools/bench/results/2026-10-28-432ed9df-m013-r10-2b/profiles/after.json.gz -- <repo>/target/bench/builds/432ed9df61ea101b3395fbae835e9a83af19039d-default/release/benitoite "$COMMAND" "$INPUT"
fi
