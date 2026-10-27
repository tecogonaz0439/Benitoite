"""指定検査本体の終了と外側の計測器の終了を別々に記録する。"""
from pathlib import Path
import json
import subprocess
import time

OUT = Path(__file__).resolve().parent
command = ['scripts/check.sh', '--level', 'work', '--base',
           '19a200f18c94e43e82b9e9b03fe088d377bad72a', '--only',
           'formal_build,spec_examples,spec_tally']
started = time.monotonic()
result = subprocess.run(command, cwd=OUT.parents[2])
(OUT / 'work-check.json').write_text(json.dumps(dict(command=command,
    check_exit=result.returncode, seconds=round(time.monotonic() - started, 3)), indent=2) + '\n')
raise SystemExit(result.returncode)
