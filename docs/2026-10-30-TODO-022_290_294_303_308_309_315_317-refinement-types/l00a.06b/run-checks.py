#!/usr/bin/env python3
"""指定した work を dry-run の後に一度だけ実行し、外側の時間を記録する。"""
from datetime import datetime, timezone
from pathlib import Path
import json
import subprocess
import sys
import time

BASE = "74bdfcdd0f8e0a2b1d1944955d072511542e97d5"
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
COMMAND = ["rtk", "proxy", "scripts/check.sh", "--level", "work", "--base", BASE]
kind = sys.argv[1]
assert kind in ("dry-run", "work")
records = json.loads((HERE / "checks.json").read_text()) if (HERE / "checks.json").exists() else []
assert all(r["kind"] != kind for r in records), "same check already recorded"
for kind, args in [(kind, ["--dry-run"] if kind == "dry-run" else [])]:
    started = datetime.now(timezone.utc).isoformat()
    t = time.monotonic()
    proc = subprocess.run(COMMAND + args, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - t
    (HERE / (kind + ".log")).write_text(proc.stdout)
    record = dict(kind=kind, command=COMMAND + args, started_at=started,
                  exit_code=proc.returncode, elapsed_seconds=elapsed,
                  log=kind + ".log")
    records.append(record)
    (HERE / "checks.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(record, ensure_ascii=False), flush=True)
    print(proc.stdout, flush=True)
    if proc.returncode:
        raise SystemExit(proc.returncode)
