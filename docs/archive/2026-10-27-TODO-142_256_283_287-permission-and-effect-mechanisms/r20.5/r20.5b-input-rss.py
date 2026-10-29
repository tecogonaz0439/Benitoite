"""Q と同じ実行ファイルを入力ごとに起動し、入力別の最大常駐量を補助測定する。"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

here = Path(__file__).resolve().parent
log = (here / "r20.5b-q-final.log").read_text()
match = re.search(r"Running unittests src/lib.rs \((target/[^)]+)\)", log)
if match is None:
    raise SystemExit("Q の実行ファイルがログにない")
binary = str(Path(match.group(1)).resolve())
records = []
for path in sorted((here / "r20.5b-measure-final").glob("*.json")):
    command = [sys.executable, str(here / "run-command.py"), f"r20.5b-rss-{path.stem}",
               "env", f"BENITOITE_SCOPE_MEASURE_CASE={path.stem}",
               f"BENITOITE_SCOPE_MEASURE_DIR={here / 'r20.5b-measure-rss'}",
               binary, "typeck::scope::tests::measure_scope_budget",
               "--exact", "--ignored", "--nocapture"]
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if result.returncode:
        print(result.stdout)
        raise SystemExit(result.returncode)
    record = json.loads((here / f"r20.5b-rss-{path.stem}.json").read_text())
    original = json.loads(path.read_text())
    repeated = json.loads((here / "r20.5b-measure-rss" / path.name).read_text())
    assert original["sha256"] == repeated["sha256"]
    record.update(case=path.stem, sha256=original["sha256"])
    records.append(record)
    print(path.stem, record["exit"], f"{record['elapsed_seconds']:.6f}s", f"{record['maxrss_mib']:.3f}MiB", flush=True)
(here / "r20.5b-input-rss.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
