# coding: utf-8
"""単体検査を排他・時間制限付きで実行し、パスを伏せて保存する。"""
from pathlib import Path
import importlib.util, fcntl, json, sys, tempfile, time
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
spec = importlib.util.spec_from_file_location("process_control", OUT / "process-control.py")
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
lock = open(Path(tempfile.gettempdir()) / "benitoite-l20d-lean.lock", "a")
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
name, source = sys.argv[1:]
source_path = Path(source)
if not source_path.is_absolute():
    source_path = ROOT / source_path
command = ["lake", "env", "lean", "-M", "6144", str(source_path)]
started = time.monotonic()
result = control.run(command, cwd=ROOT / "formal", timeout=175 if source_path.stem == "Sound" else 25 if source_path.stem.endswith("Examples") else 300)
output = result.stdout.replace(str(ROOT), "<repo>").replace(str(Path.home()), "<home>").replace(tempfile.gettempdir(), "<tmp>").replace("/tmp/", "<tmp>/")
(OUT / (name + ".log")).write_text(output)
record = {"exit": result.returncode, "outer_seconds": time.monotonic() - started, "command": [part.replace(str(ROOT), "<repo>") for part in command]}
(OUT / (name + ".json")).write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
print(output[-12000:])
print(json.dumps(record, ensure_ascii=False))
raise SystemExit(result.returncode)
