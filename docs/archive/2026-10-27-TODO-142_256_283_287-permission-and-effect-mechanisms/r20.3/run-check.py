"""検査の直接の終了状態・外側の時間・子プロセスの最大常駐量を保存する。"""
import datetime
import json
from pathlib import Path
import resource
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[3]
destination = Path(__file__).resolve().parent
name, *command = sys.argv[1:]
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
begin = time.monotonic()
completed = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - begin
raw = completed.stdout.decode(errors="replace")
redacted = raw.replace(str(root), "<wt>").replace(str(Path.home()), "<home>")
(destination / f"{name}.log").write_text(redacted)
maximum = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
maximum_bytes = maximum if sys.platform == "darwin" else maximum * 1024
record = {
    "command": command,
    "cwd": "<wt>",
    "started_utc": started,
    "finished_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "command_exit": completed.returncode,
    "outer_seconds": elapsed,
    "maxrss_raw": maximum,
    "maxrss_unit": "bytes" if sys.platform == "darwin" else "KiB",
    "maxrss_bytes": maximum_bytes,
    "maxrss_mib": maximum_bytes / 2**20,
    "maxrss_method": "getrusage(RUSAGE_CHILDREN), a fresh wrapper process per command; maximum child RSS, not sum",
}
(destination / f"{name}.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(record, ensure_ascii=False))
if completed.returncode:
    print(redacted[-16000:])
sys.exit(completed.returncode)
