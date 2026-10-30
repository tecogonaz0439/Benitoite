#!/usr/bin/env python3
"""担当作業の検査を個別に実行し、終了と外側の時間を保存する。"""
from datetime import datetime, timezone
from pathlib import Path
import json
import subprocess
import sys
import time

BASE = "22aaeb3cb1faf65264abad20cab8eb99ec3fcc81"
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
kind = sys.argv[1]
records_path = HERE / "checks.json"
records = json.loads(records_path.read_text()) if records_path.exists() else []
assert all(r["kind"] != kind for r in records), "same check already recorded"
if kind == "local-build":
    cmd = ["rtk", "proxy", "lake", "build", "Benitoite.Release.Refinement.OpenSubstitution"]
    cwd = ROOT / "formal"
elif kind == "proof":
    cmd = ["rtk", "proxy", "lake", "env", "lean", "-M", "12288", "../" + str((HERE / "proof-audit.lean").relative_to(ROOT))]
    cwd = ROOT / "formal"
else:
    assert kind in ("dry-run", "work")
    if kind == "work":
        assert any(r["kind"] == "dry-run" and r["exit_code"] == 0 for r in records)
    cmd = ["rtk", "proxy", "scripts/check.sh", "--level", "work", "--base", BASE]
    if kind == "dry-run":
        cmd.append("--dry-run")
    cwd = ROOT
started = datetime.now(timezone.utc).isoformat()
t = time.monotonic()
p = subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - t
log_path = HERE / (kind + ".log")
log_path.write_text(p.stdout)
record = dict(kind=kind, command=cmd, cwd=str(cwd.relative_to(ROOT)) or ".", started_at=started,
              exit_code=p.returncode, elapsed_seconds=elapsed, log=log_path.name)
records.append(record)
records_path.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False), flush=True)
if kind in ("dry-run", "work") or p.returncode:
    print(p.stdout, flush=True)
raise SystemExit(p.returncode)
