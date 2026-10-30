#!/usr/bin/env python3
"""作業の読み取り検査を実行し、相対パス・終了状態・外側の時間を保存する。"""

import datetime
import json
import pathlib
import subprocess
import sys
import time

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
B_WORK = "a552a33798162eb285c843fa68cd8926adf3923f"
REL = str(HERE.relative_to(ROOT))
mode = sys.argv[1]
record_path = HERE / "checks.json"
records = json.loads(record_path.read_text()) if record_path.exists() else []

if mode in {"inventory", "verify"}:
    args = ["python3", "-B", REL + "/inventory.py"] + (["--verify"] if mode == "verify" else [])
elif mode == "audit":
    args = ["python3", "-B", REL + "/audit.py"]
elif mode in {"dry-run", "work"}:
    assert not any(r["mode"] == mode for r in records), "同じ末尾検査を二度実行しない"
    args = ["scripts/check.sh", "--level", "work", "--base", B_WORK]
    if mode == "dry-run":
        args += ["--dry-run"]
    else:
        assert any(r["mode"] == "dry-run" and r["exit_code"] == 0 for r in records)
else:
    raise SystemExit("使い方: run-checks.py inventory|verify|audit|dry-run|work")

before = datetime.datetime.now(datetime.timezone.utc).isoformat()
started = time.monotonic()
result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
elapsed = time.monotonic() - started
output = (result.stdout + result.stderr).replace(str(ROOT) + "/", "")
log = HERE / (mode + ".log")
log.write_text(output)
records.append(dict(mode=mode, B_WORK=B_WORK, command=args, cwd=".",
                    started_at=before, elapsed_seconds=elapsed,
                    exit_code=result.returncode, log=str(log.relative_to(ROOT))))
record_path.write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
print(output)
print(json.dumps(records[-1], ensure_ascii=False, indent=2))
raise SystemExit(result.returncode)
