#!/usr/bin/env python3
"""既存の Scope 測定入口を局所実行し、パスを伏せて保存する。"""
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

root = Path.cwd()
destination = Path(__file__).resolve().parent
case = sys.argv[1]
environment = os.environ.copy()
environment["BENITOITE_SCOPE_MEASURE_DIR"] = str(destination / "cost-inputs")
environment["BENITOITE_SCOPE_MEASURE_CASE"] = case
command = ["cargo", "test", "-p", "benitoite", "--release", "--lib", "typeck::scope::tests::measure_scope_budget", "--", "--exact", "--ignored", "--nocapture"]
started = time.monotonic()
process = subprocess.run(["/usr/bin/time", "-p", *command], env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
elapsed = time.monotonic() - started
raw = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
unit = "bytes" if sys.platform == "darwin" else "KiB"
byte_count = raw if unit == "bytes" else raw * 1024
output = process.stdout.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
(destination / f"cost-{case}.log").write_text(output)
record = {"case": case, "command": command, "exit": process.returncode, "wall_seconds": elapsed, "max_rss_raw": raw, "max_rss_unit": unit, "max_rss_mib": byte_count / 2**20, "rss_method": "getrusage(RUSAGE_CHILDREN); child high-water mark, not sum of RSS"}
(destination / f"cost-{case}-outer.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False))
print(output[-2000:])
sys.exit(process.returncode)
