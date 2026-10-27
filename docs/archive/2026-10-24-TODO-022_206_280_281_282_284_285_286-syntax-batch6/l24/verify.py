"""L24 の停止理由と指定検査を直列で確認し、出力の手元のパスを伏せる。"""
from pathlib import Path
import fcntl
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '19a200f18c94e43e82b9e9b03fe088d377bad72a'
spec = importlib.util.spec_from_file_location('control', OUT.parent / 'l23/process-control.py')
control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(control)


def redact(text):
    for actual, replacement in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                                (tempfile.gettempdir(), '<tmp>'), ('/private/tmp', '<tmp>'),
                                ('/tmp/', '<tmp>/')]:
        text = text.replace(actual, replacement)
    return text


def run(name, command, cwd=ROOT, timeout=300):
    before = time.monotonic()
    result = control.run(command, cwd=cwd, timeout=timeout, env=os.environ.copy())
    (OUT / f'{name}.log').write_text(redact(result.stdout))
    record = dict(command=[redact(str(part)) for part in command],
                  cwd=redact(str(cwd)), exit=result.returncode,
                  seconds=round(time.monotonic() - before, 3))
    (OUT / f'{name}.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(record, ensure_ascii=False), flush=True)
    if result.returncode:
        print(redact(result.stdout[-7000:]), flush=True)
        raise SystemExit(result.returncode)


if __name__ == '__main__':
    lock = open(Path(tempfile.gettempdir()) / 'benitoite-l20d-lean.lock', 'a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    mode = sys.argv[1]
    if mode == 'probe':
        run('contract-obstruction', ['lake', 'env', 'lean', '-M', '6144',
            str(OUT / 'contract-obstruction.lean')], cwd=ROOT / 'formal')
    elif mode == 'ready':
        run('default-up-to-date', ['lake', '--no-build', 'build'], cwd=ROOT / 'formal')
    elif mode == 'dry-run':
        run('dry-run', ['scripts/check.sh', '--level', 'work', '--base', BASE,
            '--only', 'formal_build,spec_examples,spec_tally', '--dry-run'])
    elif mode == 'work':
        run('work', ['/usr/bin/time', '-l', sys.executable, str(OUT / 'work-check.py')])
    else:
        raise SystemExit('未知の検査モード')
