"""実行の終了状態・外側時間・補助 RSS を伏せたログとともに保存する。"""
import datetime
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import tempfile
import time

root = Path(__file__).resolve().parents[3]
destination = Path(__file__).resolve().parent
label, *command = sys.argv[1:]
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
clock = time.monotonic()
process = subprocess.run(command, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - clock
rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss

def redact(value):
    return value.replace(str(root), "<wt>").replace(os.path.expanduser("~"), "<home>").replace(tempfile.gettempdir(), "<tmp>")

(destination / f"{label}.log").write_text(redact(process.stdout.decode(errors="replace")))
record = dict(command=command, started=started,
              finished=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              exit_status=process.returncode, elapsed_seconds=elapsed,
              supplemental_children_ru_maxrss=rss, ru_maxrss_unit="bytes (macOS)",
              ru_maxrss_mib=rss / 2**20)
rendered = redact(json.dumps(record, ensure_ascii=False, indent=2))
(destination / f"{label}.json").write_text(rendered + "\n")
print(rendered)
sys.exit(process.returncode)
