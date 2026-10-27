"""計測器の終了と指定 work 本体の終了を分けて記録する。"""
from pathlib import Path
import json
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
command = ['scripts/check.sh', '--level', 'work', '--base',
           '6e47419f989453b55dc4bc8a121285a1819b3d9f', '--only',
           'formal_build,spec_examples,spec_tally']
started = time.monotonic()
result = subprocess.run(command, cwd=ROOT)
(OUT / 'work-check.json').write_text(json.dumps(dict(command=command,
    check_exit=result.returncode, seconds=round(time.monotonic() - started, 3)), indent=2) + '\n')
raise SystemExit(result.returncode)
