#!/bin/sh
# Separate from timings; choose INPUT and STATE, then run profile_summary.py.
set -eu
: "${INPUT:?absolute input path required}"
: "${STATE:=after}"
mkdir -p /Users/tecogonaz/src/Benitoite/tools/bench/results/2026-10-21-270a717c-comparison/profiles
: "${COMMAND:=check}"
if [ "$STATE" = before ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o /Users/tecogonaz/src/Benitoite/tools/bench/results/2026-10-21-270a717c-comparison/profiles/before.json.gz -- /Users/tecogonaz/src/Benitoite/target/bench/builds/c31e64b03d2810343e1779926bea4ebc958b6164-default/release/benitoite "$COMMAND" "$INPUT"
fi
if [ "$STATE" = after ]; then
 BENITOITE_DEV_IO_MODE=direct samply record --save-only --unstable-presymbolicate -o /Users/tecogonaz/src/Benitoite/tools/bench/results/2026-10-21-270a717c-comparison/profiles/after.json.gz -- /Users/tecogonaz/src/Benitoite/target/bench/builds/270a717c670d9640d4c08f10bc400afa6e3fcef2-default/release/benitoite "$COMMAND" "$INPUT"
fi
