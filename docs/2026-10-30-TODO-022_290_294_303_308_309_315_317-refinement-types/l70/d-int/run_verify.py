# -*- coding: utf-8 -*-
"""最後の照合を一度実行し、時刻と出力の指紋を記録する。"""
import argparse
import datetime
import json
import subprocess
import sys
import time
from pathlib import Path
from inventory import HERE, ROOT, digest, save

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()
log = args.tmp / "verify.log"
start = datetime.datetime.now().astimezone().isoformat()
t0 = time.monotonic()
with log.open("w") as out:
    result = subprocess.run([sys.executable, str(HERE / "verify.py"), "--tmp", str(args.tmp)],
                            cwd=ROOT, stdout=out, stderr=subprocess.STDOUT)
    out.write("\nrc=" + str(result.returncode) + "\n")
summary = dict(start=start, end=datetime.datetime.now().astimezone().isoformat(),
               seconds=time.monotonic() - t0, exit_code=result.returncode,
               bytes=log.stat().st_size, sha256=digest(log))
save(HERE / "verify-summary.json", summary)
print(json.dumps(summary, ensure_ascii=False, indent=1))
if result.returncode:
    print(log.read_text())
raise SystemExit(result.returncode)
