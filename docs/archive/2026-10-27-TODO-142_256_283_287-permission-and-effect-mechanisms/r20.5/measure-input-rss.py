#!/usr/bin/env python3
"""Q と同じテスト実行ファイルを入力ごとに新しいプロセスで起動する補助測定。"""
import json
from pathlib import Path
import re
import subprocess
import sys

here = Path(__file__).parent
log = (here / "measure-all.log").read_text()
match = re.search(r"Running unittests src/lib.rs \((target/[^)]+)\)", log)
if match is None:
    raise SystemExit("測定 Q の実行ファイルをログから取得できない")
binary = match.group(1)
records = []
for path in sorted((here / "measure-release").glob("*.json")):
    result = subprocess.run([sys.executable, str(here / "measure-run.py"), path.stem, binary], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if result.returncode:
        print(result.stdout)
        raise SystemExit(result.returncode)
    record = json.loads((here / f"measure-rss-{path.stem}-outer.json").read_text())
    initial = json.loads(path.read_text())
    repeated = json.loads((here / "measure-rss" / path.name).read_text())
    assert initial["sha256"] == repeated["sha256"]
    record["sha256"] = initial["sha256"]
    records.append(record)
    print(path.stem, f"{record['wall_seconds']:.6f}s", f"{record['max_rss_mib']:.3f}MiB", flush=True)
(here / "measure-input-rss.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
