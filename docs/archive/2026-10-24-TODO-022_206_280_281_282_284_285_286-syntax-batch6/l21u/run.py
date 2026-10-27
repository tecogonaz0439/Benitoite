"""時間上限付きの局所検査。出力の手元のパスは保存前に伏せる。"""
from pathlib import Path
import fcntl, importlib.util, json, os, sys, tempfile, time
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
spec = importlib.util.spec_from_file_location('process_control', OUT.parent / 'l20d/process-control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)
label, location, timeout, *command = sys.argv[1:]
lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
start = time.monotonic()
result = control.run(command, cwd=ROOT / location, timeout=float(timeout), env=os.environ.copy())
def redact(text):
    return text.replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>').replace(tempfile.gettempdir(), '<tmp>').replace('/tmp/', '<tmp>/')
(OUT / (label + '.log')).write_text(redact(result.stdout))
record = {'command': [redact(x) for x in command], 'cwd': '<repo>/' + location,
          'exit': result.returncode, 'seconds': time.monotonic() - start}
(OUT / (label + '.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
sys.exit(result.returncode)
