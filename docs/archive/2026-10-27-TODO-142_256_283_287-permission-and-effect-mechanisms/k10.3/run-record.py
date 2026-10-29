#!/usr/bin/env python3
"""指定した一段を直接計時し、手元の場所を伏せて終了と補助RSSを保存する。"""
import datetime
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]


def redact(text):
    return text.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>")


def main():
    name, *command = sys.argv[1:]
    if command[:1] == ["--"]:
        command = command[1:]
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    before = time.monotonic()
    # time の子として対象を直接起動し、パイプや要約器の終了を記録しない。
    with (OUT / f"{name}.log").open("w+") as log:
        process = subprocess.run(["/usr/bin/time", "-p", *command], cwd=ROOT,
                                 stdout=log, stderr=subprocess.STDOUT)
        elapsed = time.monotonic() - before
        rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
        log.seek(0)
        contents = redact(log.read())
        log.seek(0)
        log.write(contents)
        log.truncate()
    result = dict(command=[redact(c) for c in command], startedAt=started,
                  exit=process.returncode, outerSeconds=elapsed,
                  maxRssBytesAuxiliary=rss, maxRssMiB=rss / 2**20,
                  maxRssGiB=rss / 2**30,
                  environment={k: redact(v) for k, v in os.environ.items()
                               if k.startswith("BENITOITE_") or k in ("PYTHONOPTIMIZE", "CARGO_TARGET_DIR")},
                  rssMethod="macOS getrusage(RUSAGE_CHILDREN).ru_maxrss; bytes; 子プロセス一つの最大値であり同時使用量の合計ではない")
    (OUT / f"{name}.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    (OUT / f"{name}.exit").write_text(str(process.returncode) + "\n")
    print(json.dumps(result, ensure_ascii=False), flush=True)
    return process.returncode


if __name__ == "__main__":
    sys.exit(main())
