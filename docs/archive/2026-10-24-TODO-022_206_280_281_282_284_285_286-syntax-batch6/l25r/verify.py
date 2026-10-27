"""同じ基準の選択確認と最終 work を直列に実行する。"""
import fcntl
import os
import sys
import tempfile
from pathlib import Path
import run
lock = open(Path(tempfile.gettempdir())/'benitoite-l20d-lean.lock', 'a')
fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
os.environ['CARGO_HOME'] = str(Path(tempfile.gettempdir())/'benitoite-a01a-cargo')
mode = sys.argv[1]
if mode == 'axioms':
    command = ['lake', 'env', 'lean', '-M', '6144', str(run.OUT/'axioms.lean')]
    cwd = run.ROOT/'formal'
elif mode == 'ready':
    command = ['lake', '--no-build', 'build']
    cwd = run.ROOT/'formal'
elif mode == 'dry-run':
    command = ['scripts/check.sh', '--level', 'work', '--base', run.BASE,
               '--only', 'formal_build,spec_examples,spec_tally', '--dry-run']
    cwd = run.ROOT
elif mode == 'formal-dry-run':
    command = ['scripts/check.sh', '--level', 'work', '--base', run.BASE,
               '--only', 'formal_build', '--dry-run']
    cwd = run.ROOT
elif mode == 'formal':
    command = ['/usr/bin/time', '-l', sys.executable, str(run.OUT/'formal-check.py')]
    cwd = run.ROOT
elif mode == 'work':
    command = ['/usr/bin/time', '-l', sys.executable, str(run.OUT/'work-check.py')]
    cwd = run.ROOT
else:
    raise SystemExit('未知の検査モード')
raise SystemExit(run.run(mode, command, cwd, 300))
