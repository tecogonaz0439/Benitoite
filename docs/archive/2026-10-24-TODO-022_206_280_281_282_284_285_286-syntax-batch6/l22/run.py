"""一つの検査を実行し、終了状態・時間とパスを伏せた出力を保存する。"""
from pathlib import Path
import fcntl
import importlib.util
import json
import sys
import tempfile
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
spec = importlib.util.spec_from_file_location('control', OUT / 'process-control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
label, timeout, location, *command = sys.argv[1:]
lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
started = time.monotonic()
result = control.run(command, cwd=ROOT / location, timeout=int(timeout))
output = result.stdout.replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>')
output = output.replace(tempfile.gettempdir(), '<tmp>').replace('/tmp/', '<tmp>/')
(OUT / (label + '.log')).write_text(output)
record = dict(command=command, cwd='<repo>/' + location, exit=result.returncode,
              seconds=round(time.monotonic() - started, 3))
(OUT / (label + '.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
if result.returncode:
    print(output[-6000:])
raise SystemExit(result.returncode)
