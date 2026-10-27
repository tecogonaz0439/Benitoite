"""L25T の単体検査。プロセス群の終了を回収し、記録のパスを伏せる。"""
from pathlib import Path
import fcntl
import importlib.util
import json
import os
import sys
import tempfile
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '079397f3c36b866091ec8dcb1783cfb4ccef9033'
spec = importlib.util.spec_from_file_location('control', OUT.parent / 'l23/process-control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)

def redact(value):
    for actual, replacement in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                                (tempfile.gettempdir(), '<tmp>'), ('/private/tmp', '<tmp>'),
                                ('/tmp/', '<tmp>/')]:
        value = value.replace(actual, replacement)
    return value.replace(sys.executable, 'python3')

def run(name, command, cwd, timeout=300):
    started = time.monotonic()
    result = control.run(command, cwd=cwd, timeout=timeout, env=os.environ.copy())
    (OUT / (name + '.log')).write_text(redact(result.stdout))
    record = dict(command=[redact(str(part)) for part in command], cwd=redact(str(cwd)),
                  exit=result.returncode, seconds=round(time.monotonic() - started, 3))
    (OUT / (name + '.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(record, ensure_ascii=False), flush=True)
    if result.returncode:
        print('\n'.join(line for line in redact(result.stdout).splitlines() if 'error:' in line or line.startswith('error ')), flush=True)
    return result.returncode

if __name__ == '__main__':
    lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    name, target = sys.argv[1:]
    command = ['lake', 'build', target[6:]] if target.startswith('build:') else ['lake', 'env', 'lean', '-M', '6144', target]
    raise SystemExit(run(name, command, ROOT / 'formal', 175 if target.endswith('/Sound.lean') else 25 if target.endswith('Examples.lean') else 300))
