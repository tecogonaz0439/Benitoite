"""timeと指定work本体の終了状態を区別する。"""
from pathlib import Path
import json
import os
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
COMMAND = ['scripts/check.sh', '--level', 'work', '--only', 'fmt,lint_default,tests_related', '--test', 'desugar_export', '--base',
           '2878da41c88ad296c7d6d4e2a6eec63c64412bcb']
started = time.monotonic()
result = subprocess.run(COMMAND, cwd=ROOT, env=os.environ.copy())
(OUT/'correction-check.json').write_text(json.dumps(dict(command=COMMAND, exit=result.returncode,
    seconds=round(time.monotonic()-started, 3)), indent=2)+'\n')
raise SystemExit(result.returncode)
