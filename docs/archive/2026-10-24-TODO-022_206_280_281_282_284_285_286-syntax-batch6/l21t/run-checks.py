"""L21T の局所検査と指定検査。保存時に手元のパスを伏せる。"""
from pathlib import Path
import json
import importlib.util
import fcntl
import os
import subprocess
import sys
import tempfile
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = "f6ed14a88c0a4cb6a7ef8305f6837150bf80036d"
spec = importlib.util.spec_from_file_location('process_control', OUT.parent / 'l20d' / 'process-control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
mode = sys.argv[1]
work = ["scripts/check.sh", "--level", "work", "--base", BASE, "--only",
        "formal_build,spec_examples,spec_tally"]
cwd = ROOT
if mode == "dry-run":
    command = work + ["--dry-run"]
elif mode == "formal-final-dry-run":
    command = work[:-1] + ["formal_build", "--dry-run"]
elif mode == "formal-final":
    command = ["/usr/bin/time", "-l", "/bin/zsh", str(OUT / "run-formal.sh")]
elif mode == "work":
    command = ["/usr/bin/time", "-l", "/bin/zsh", str(OUT / "run-work.sh")]
elif mode == "default-up-to-date":
    command = ["lake", "--no-build", "build"]
    cwd = ROOT / "formal"
else:
    raise SystemExit("dry-run/work/default-up-to-date")
lock = None
if mode not in ('dry-run', 'formal-final-dry-run'):
    lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit('別の L21T Lean 検査が実行中のため起動しない')
started = time.monotonic()
timeout = 300
result = control.run(command, cwd=cwd, env=os.environ.copy(), timeout=timeout)
output = result.stdout
for old, new in [(str(ROOT), "<repo>"), (str(Path.home()), "<home>"),
                 (tempfile.gettempdir().rstrip('/'), "<tmp>"),
                 ("<tmp>", "<tmp>"), ("/tmp", "<tmp>")]:
    output = output.replace(old, new)
record = {"wrapper_exit": result.returncode, "outer_seconds": time.monotonic() - started}
for line in output.splitlines():
    if line.startswith("L21T_CHECK_EXIT_STATUS="):
        record["check_exit"] = int(line.split("=", 1)[1])
    if line.startswith("L21T_DEFAULT_EXIT_STATUS="):
        record["check_exit"] = int(line.split("=", 1)[1])
    if "maximum resident set size" in line:
        record["maximum_resident_set_size_line"] = line.strip()
record["rss_available"] = "maximum_resident_set_size_line" in record
(OUT / f"{mode}.log").write_text(output)
(OUT / f"{mode}.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(output[-3000:])
print(json.dumps(record, ensure_ascii=False))
raise SystemExit(record.get("check_exit", result.returncode))
