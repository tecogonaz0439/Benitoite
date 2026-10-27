"""timeと指定work本体の終了状態を区別する。"""
from pathlib import Path
import json
import os
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
COMMAND = ['scripts/check.sh', '--level', 'work', '--base',
           '22303cf6f1ce73472dc9f8b6e60696f21bac9489']
started = time.monotonic()
result = subprocess.run(COMMAND, cwd=ROOT, env=os.environ.copy())
(OUT/'work-check.json').write_text(json.dumps(dict(command=COMMAND, exit=result.returncode,
    seconds=round(time.monotonic()-started, 3)), indent=2)+'\n')
raise SystemExit(result.returncode)
