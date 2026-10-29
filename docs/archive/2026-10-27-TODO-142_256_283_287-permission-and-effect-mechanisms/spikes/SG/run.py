#!/usr/bin/env python3
"""指定された別機の検査器だけを起動し、SG 内へ証拠を保存する。"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import subprocess
import time
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
MODEL = HERE / "Model.lean"
COMMAND = ["zsh", "work/m013/remote-lean.sh", "SG", "Model.lean", "6144", "180"]


def digest() -> str:
    return hashlib.sha256(MODEL.read_bytes()).hexdigest()


start = datetime.now(timezone.utc).isoformat()
before = digest()
stem = sys.argv[1] if len(sys.argv) > 1 else "final"
clock = time.monotonic()
with (HERE / f"{stem}.log").open("w") as out:
    proc = subprocess.run(COMMAND, cwd=REPO, stdout=out, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - clock
log = (HERE / f"{stem}.log").read_text()
summary = re.findall(r"^== run-lean: exit (\d+), elapsed (\d+)s, top-mem-peak (\d+)MB.*$", log, re.M)
last_line = next((line for line in reversed(log.splitlines()) if line.startswith("== run-lean:")), None)
rss = re.search(r"^\s*(\d+)\s+maximum resident set size$", log, re.M)
version = re.search(r'^"(\d+\.\d+\.\d+)"$', log, re.M)
diagnostics = re.findall(r"^Model\.lean:\d+:\d+: (?:error|warning):.*$", log, re.M)
after = digest()
ok = (
    proc.returncode == 0 and bool(summary) and summary[-1][0] == "0"
    and before == after and not diagnostics and "sorryAx" not in log
)
record = {
    "command": COMMAND,
    "started_utc": start,
    "finished_utc": datetime.now(timezone.utc).isoformat(),
    "wall_seconds_including_sync_and_queue": round(elapsed, 3),
    "wrapper_process_exit": proc.returncode,
    "remote_summary": last_line,
    "remote_exit": int(summary[-1][0]) if summary else None,
    "remote_elapsed_seconds": int(summary[-1][1]) if summary else None,
    "sampled_peak_mb": int(summary[-1][2]) if summary else None,
    "sampled_peak_note": "0 は5秒ごとの標本で捕捉しなかった意味。使用量0とはしない。",
    "time_maximum_resident_bytes": int(rss[1]) if rss else None,
    "lean_version": version[1] if version else None,
    "source_sha256_before": before,
    "source_sha256_after": after,
    "diagnostics": diagnostics,
    "passed": ok,
}
(HERE / f"{stem}-run.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False, indent=2))
raise SystemExit(0 if ok else 1)
