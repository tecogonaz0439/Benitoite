# -*- coding: utf-8 -*-
"""生出力は一時領域に置き、終了・外側時間・ハッシュを保存する。"""
import argparse
from datetime import datetime
import json
from pathlib import Path
import subprocess
import time
from support import HERE, ROOT, digest, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--label", required=True)
parser.add_argument("--cwd", default=".")
parser.add_argument("command", nargs=argparse.REMAINDER)
args = parser.parse_args()
args.tmp.mkdir(exist_ok=True, parents=True)
start = datetime.now().astimezone().isoformat(timespec="seconds")
timer = time.monotonic()
raw = args.tmp / (args.label + ".log")
with raw.open("wb") as output:
    result = subprocess.run(args.command, cwd=ROOT / args.cwd,
                            stdout=output, stderr=subprocess.STDOUT)
def local(x):
    # 手元の絶対パスを記録に残さない。一時領域は<tmp>、その他は<local>とする。
    if x == str(args.tmp):
        return "<tmp>"
    return "<local>/" + Path(x).name if x.startswith("/") else x
record = {"cwd": args.cwd, "command": [local(x) for x in args.command],
          "start": start, "end": datetime.now().astimezone().isoformat(timespec="seconds"),
          "exit": result.returncode, "wall_seconds": round(time.monotonic() - timer, 4),
          "raw": digest(raw), "rss": "未取得（計画上の非採取）"}
write(HERE / (args.label + ".json"), record)
print(json.dumps(record, ensure_ascii=False))
if result.returncode:
    print(raw.read_text()[-12000:])
raise SystemExit(result.returncode)
