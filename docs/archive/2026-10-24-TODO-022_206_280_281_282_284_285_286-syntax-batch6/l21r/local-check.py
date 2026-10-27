"""Lean の局所検査を排他・時間上限付きで実行し、各試行を別名で残す。"""
from pathlib import Path
import fcntl
import importlib.util
import json
import sys
import tempfile
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
spec = importlib.util.spec_from_file_location("process_control", OUT / "process-control.py")
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
lock = open(Path(tempfile.gettempdir()) / "benitoite-l20d-lean.lock", "a")
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
source = sys.argv[1]
name = sys.argv[2]
started = time.monotonic()
command = ["lake", "env", "lean", "-M", "6144", source]
if len(sys.argv) > 3 and sys.argv[3] == "build":
    command = ["lake", "build", source]
timeout = 25 if "Examples" in source else (175 if source.endswith("/Sound.lean") else 300)
result = control.run(command, cwd=ROOT / "formal", timeout=timeout)
output = result.stdout
for old, new in [(str(ROOT), "<repo>"), (str(Path.home()), "<home>"),
                 (tempfile.gettempdir().rstrip("/"), "<tmp>"), ("/tmp/", "<tmp>/")]:
    output = output.replace(old, new)
(OUT / (name + ".log")).write_text(output)
record = {"command": command, "exit": result.returncode,
          "seconds": time.monotonic() - started}
(OUT / (name + ".json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(output[-12000:])
print(json.dumps(record, ensure_ascii=False))
raise SystemExit(result.returncode)
