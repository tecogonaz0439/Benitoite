"""計測器の終了と指定 work 本体の終了を分けて記録する。"""
from pathlib import Path
import json
import subprocess
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
command = ['scripts/check.sh', '--level', 'work', '--base',
           'be57d4e92d7a48fb74dc33a4d3c3867b60207aeb', '--only',
           'formal_build,spec_examples,spec_tally']
started = time.monotonic()
result = subprocess.run(command, cwd=ROOT)
(OUT / 'work-check.json').write_text(json.dumps(dict(command=command,
    check_exit=result.returncode, seconds=round(time.monotonic() - started, 3)), indent=2) + '\n')
raise SystemExit(result.returncode)
