"""timeの終了状態とは別に、指定work自体の結果を保存する。"""
from pathlib import Path
import json
import os
import subprocess
import time
import tempfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
COMMAND = ['scripts/check.sh', '--level', 'work', '--base',
           '587f44aaf272db8af4962290cdee82ed008e66a3',
           '--only', 'formal_build,spec_examples,spec_tally']
env = os.environ.copy()
cache = Path(tempfile.gettempdir()) / 'benitoite-a01a-cargo'
if cache.is_dir():
    env['CARGO_HOME'] = str(cache)
started = time.monotonic()
p = subprocess.run(COMMAND, cwd=ROOT, env=env)
(OUT/'work-check.json').write_text(json.dumps(dict(command=COMMAND, exit=p.returncode,
    seconds=round(time.monotonic()-started, 3), cargoHome='<tmp>/benitoite-a01a-cargo' if cache.is_dir() else 'default'), indent=2)+'\n')
raise SystemExit(p.returncode)
