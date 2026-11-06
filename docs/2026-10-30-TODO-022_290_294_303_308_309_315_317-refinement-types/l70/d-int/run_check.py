# -*- coding: utf-8 -*-
"""既定ビルド又は公理監査を共有ロックの下で一度実行し、前後の入力を照合する。"""
import argparse
import datetime
import json
import subprocess
import time
from pathlib import Path
from inventory import HERE, ROOT, digest, fingerprint, save, sources

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
parser.add_argument("--lock", type=Path, required=True)
parser.add_argument("--kind", choices=["build", "axioms"], required=True)
args = parser.parse_args()
args.tmp.mkdir(parents=True, exist_ok=True)
command = ["lake", "build"] if args.kind == "build" else [
    "lake", "env", "lean", "-M", "12288", str((HERE / "axioms.lean").relative_to(ROOT))]
# Lean の監査ファイルも formal/ からの相対指定にする。
if args.kind == "axioms":
    command[-1] = "../" + command[-1]
before = sources()
start = datetime.datetime.now().astimezone().isoformat()
t0 = time.monotonic()
log = args.tmp / (args.kind + ".log")
with log.open("w") as out:
    result = subprocess.run(["/usr/bin/lockf", "-t", "3600", str(args.lock)] + command,
                            cwd=ROOT / "formal", stdout=out, stderr=subprocess.STDOUT)
    out.write("\nrc=" + str(result.returncode) + "\n")
end = datetime.datetime.now().astimezone().isoformat()
after = sources()
summary = dict(command=" ".join(command), start=start, end=end, seconds=time.monotonic() - t0,
               exit_code=result.returncode, bytes=log.stat().st_size, sha256=digest(log),
               fingerprint=fingerprint(before), after_fingerprint=fingerprint(after),
               inputs=len(before), same_inputs=before == after)
save(HERE / (args.kind + "-summary.json"), summary)
print(json.dumps(summary, ensure_ascii=False, indent=1))
assert before == after, "検査中に本番の入力が変わった"
raise SystemExit(result.returncode)
