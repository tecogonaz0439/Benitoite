#!/usr/bin/env python3
"""実行器の終了・外側の時間・子孫の最大常駐量を保存する。"""

import datetime
import json
from pathlib import Path
import resource
import subprocess
import sys
import time


def main():
    if sys.argv[1] == "--inner":
        result = subprocess.run(sys.argv[2:], check=False)
        print(f"command_exit={result.returncode}", flush=True)
        return result.returncode
    stem, *command = sys.argv[1:]
    root = Path.cwd()
    output = Path(__file__).resolve().parent
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    before = time.monotonic()
    run = subprocess.Popen(
        ["/usr/bin/time", "-p", sys.executable, __file__, "--inner", *command],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    with (output / f"{stem}.log").open("w") as log:
        for line in run.stdout:
            line = line.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
            log.write(line)
            log.flush()
    status = run.wait()
    rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    metadata = {
        "command": command,
        "started_utc": started,
        "finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "exit": status,
        "outer_seconds": time.monotonic() - before,
        "max_rss_raw": rss,
        "max_rss_unit": "bytes" if sys.platform == "darwin" else "KiB",
        "max_rss_mib": rss / (1024 * 1024 if sys.platform == "darwin" else 1024),
        "rss_method": "getrusage(RUSAGE_CHILDREN); 実行器と終了した子孫の最大値。一括の同時常駐量ではない",
        "platform": sys.platform,
    }
    (output / f"{stem}.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(metadata, ensure_ascii=False))
    return status


if __name__ == "__main__":
    sys.exit(main())
