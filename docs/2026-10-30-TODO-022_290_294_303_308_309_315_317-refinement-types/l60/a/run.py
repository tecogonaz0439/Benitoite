"""検査の生出力を一時領域へ保存し、終了・外側時間・ハッシュを記録する。"""
import argparse
import json
from pathlib import Path
import subprocess
import time
from datetime import datetime
from inventory import ROOT, HERE, digest, write

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument("--tmp", type=Path, required=True)
ap.add_argument("--label", required=True)
ap.add_argument("--cwd", default=".")
ap.add_argument("command", nargs=argparse.REMAINDER)
args = ap.parse_args()
args.tmp.mkdir(exist_ok=True, parents=True)
start = datetime.now().astimezone().isoformat(timespec="seconds")
t = time.monotonic()
raw = args.tmp / (args.label + ".log")
with raw.open("wb") as output:
    proc = subprocess.run(args.command, cwd=ROOT/args.cwd, stdout=output, stderr=subprocess.STDOUT)
record = {"label":args.label,"cwd":args.cwd,"command":["<tmp>" if x == str(args.tmp) else x for x in args.command],"start":start,
    "end":datetime.now().astimezone().isoformat(timespec="seconds"),
    "exit":proc.returncode,"wall_seconds":round(time.monotonic()-t,4),"raw":digest(raw),
    "rss":"未取得（計画上の非採取）"}
write(HERE/(args.label+".json"),record)
print(json.dumps(record,ensure_ascii=False))
if proc.returncode:
    print(raw.read_text()[-10000:])
raise SystemExit(proc.returncode)
