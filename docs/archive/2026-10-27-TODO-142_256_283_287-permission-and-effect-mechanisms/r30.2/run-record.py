"""指定した検査を計時し、終了状態と伏せ字にした出力を保存する。"""
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


def sanitized(text):
    text = text.replace(str(ROOT), "<wt>").replace(str(Path.home()), "<home>")
    temporary = os.environ.get("TMPDIR")
    if temporary:
        text = text.replace(temporary.rstrip("/"), "<tmp>")
    return text


if sys.argv[1] == "--child":
    label, command = sys.argv[2], sys.argv[3:]
    started = time.perf_counter()
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    elapsed = time.perf_counter() - started
    (HERE / f"{label}.log").write_text(sanitized(result.stdout.decode(errors="replace")))
    rss = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
    record = dict(command=command, check_exit_code=result.returncode,
                  child_wall_seconds=elapsed, maxrss_raw=rss,
                  maxrss_unit="bytes" if sys.platform == "darwin" else "KiB",
                  maxrss_mib=rss / (2**20 if sys.platform == "darwin" else 1024),
                  measured="getrusage(RUSAGE_CHILDREN); 子孫の最大値、合計ではない")
    (HERE / f"{label}.json").write_text(sanitized(json.dumps(record, ensure_ascii=False, indent=2)) + "\n")
    sys.exit(result.returncode)

label, command = sys.argv[1], sys.argv[2:]
started = time.perf_counter()
result = subprocess.run(["/usr/bin/time", "-p", sys.executable, str(Path(__file__).resolve()),
                         "--child", label, *command], capture_output=True, text=True)
elapsed = time.perf_counter() - started
(HERE / f"{label}-time.log").write_text(sanitized(result.stdout + result.stderr))
record_path = HERE / f"{label}.json"
record = json.loads(record_path.read_text())
record.update(outer_exit_code=result.returncode, outer_wall_seconds=elapsed,
              recorded_at=datetime.datetime.now(datetime.timezone.utc).isoformat(),
              time_command=["/usr/bin/time", "-p", "python3", "r30.2/run-record.py", "--child", label, *command])
record_path.write_text(sanitized(json.dumps(record, ensure_ascii=False, indent=2)) + "\n")
print(json.dumps(record, ensure_ascii=False))
sys.exit(result.returncode)
