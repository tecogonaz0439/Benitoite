"""time -p で指定コマンドを直接包み、伏せ字にした記録を残す。"""
import datetime
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def sanitized(value):
    value = value.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>")
    temporary = os.environ.get("TMPDIR")
    if temporary:
        value = value.replace(temporary.rstrip("/"), "<tmp>")
    return value


label, command = sys.argv[1], sys.argv[2:]
started_at = datetime.datetime.now(datetime.timezone.utc).isoformat()
started = time.perf_counter()
# time はパイプを挟まず、実コマンドの終了状態をそのまま返す。
result = subprocess.run(["/usr/bin/time", "-p", *command], capture_output=True, text=True)
elapsed = time.perf_counter() - started
rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
(HERE / f"{label}.log").write_text(sanitized(result.stdout + result.stderr))
record = dict(command=command, time_command=["/usr/bin/time", "-p", *command],
              check_exit_code=result.returncode, outer_exit_code=result.returncode,
              outer_wall_seconds=elapsed, started_at=started_at,
              finished_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              maxrss_raw=rss, maxrss_unit="bytes" if sys.platform == "darwin" else "KiB",
              maxrss_mib=rss / (2**20 if sys.platform == "darwin" else 1024),
              measured="getrusage(RUSAGE_CHILDREN); 子孫の最大値の補助値。同時常駐量の合計ではない")
(HERE / f"{label}.json").write_text(sanitized(json.dumps(record, ensure_ascii=False, indent=2)) + "\n")
print(sanitized(json.dumps(record, ensure_ascii=False)))
sys.exit(result.returncode)
