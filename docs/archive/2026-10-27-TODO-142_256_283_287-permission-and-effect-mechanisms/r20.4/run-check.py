"""検査の終了状態・外側の時間・子プロセスの最大常駐量を保存する。"""
import datetime
import json
from pathlib import Path
import resource
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[3]
destination = Path(__file__).resolve().parent
name, *command = sys.argv[1:]
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
begin = time.monotonic()
completed = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - begin


def redact(value):
    return (value.replace(str(root), "<wt>")
            .replace(str(Path.home()), "<home>")
            .replace(tempfile.gettempdir().rstrip("/"), "<tmp>"))


raw = redact(completed.stdout.decode(errors="replace"))
(destination / f"{name}.log").write_text(raw)
maximum = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
maximum_bytes = maximum if sys.platform == "darwin" else maximum * 1024
record = {
    "command": [redact(arg) for arg in command],
    "cwd": "<wt>",
    "started_utc": started,
    "finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "command_exit": completed.returncode,
    "outer_seconds": elapsed,
    "maxrss_raw": maximum,
    "maxrss_unit": "bytes" if sys.platform == "darwin" else "KiB",
    "maxrss_bytes": maximum_bytes,
    "maxrss_mib": maximum_bytes / 2**20,
    "maxrss_gib": maximum_bytes / 2**30,
    "maxrss_method": "getrusage(RUSAGE_CHILDREN); fresh wrapper; maximum child RSS, not sum",
}
(destination / f"{name}.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False))
if completed.returncode:
    print(raw[-12000:])
sys.exit(completed.returncode)
