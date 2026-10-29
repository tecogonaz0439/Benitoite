#!/usr/bin/env python3
"""測定 Q の終了状態・外側の時間・子プロセスの最大常駐量を保存する。"""
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

root = Path.cwd()
destination = Path(__file__).parent
label = sys.argv[1]
command = ["cargo", "test", "-p", "benitoite", "--release", "--lib", "typeck::scope::tests::measure_scope_budget", "--", "--exact", "--ignored", "--nocapture"]
binary = sys.argv[2] if len(sys.argv) > 2 else None
if binary:
    command = [binary, "typeck::scope::tests::measure_scope_budget", "--exact", "--ignored", "--nocapture"]
    prefix = "measure-rss-"
else:
    prefix = "measure-"
environment = os.environ.copy()
environment["BENITOITE_SCOPE_MEASURE_DIR"] = str(destination / ("measure-rss" if binary else "measure-release"))
if label != "all":
    environment["BENITOITE_SCOPE_MEASURE_CASE"] = label
started = time.monotonic()
process = subprocess.run(["/usr/bin/time", "-p", *command], env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
elapsed = time.monotonic() - started
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
raw = usage.ru_maxrss
unit = "bytes" if sys.platform == "darwin" else "KiB"
byte_count = raw if unit == "bytes" else raw * 1024
output = process.stdout.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
(destination / f"{prefix}{label}.log").write_text(output)
record = {"command": command, "case": label, "exit": process.returncode, "wall_seconds": elapsed, "max_rss_raw": raw, "max_rss_unit": unit, "max_rss_mib": byte_count / 2**20, "rss_method": "getrusage(RUSAGE_CHILDREN); separate process for this invocation, not sum of child RSS"}
(destination / f"{prefix}{label}-outer.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False))
print(output[-5000:])
sys.exit(process.returncode)
