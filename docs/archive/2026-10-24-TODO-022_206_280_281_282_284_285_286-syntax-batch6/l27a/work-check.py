"""time の資源統計の成否と検査本体の終了状態を分けて記録する。"""
from pathlib import Path
import json, subprocess, sys, time
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
command = ['scripts/check.sh', '--level', 'work', '--base',
           '258735b076842aebf3498505b7238be67a5fba31', '--only',
           'formal_build,spec_examples,spec_tally']
before = time.monotonic()
result = subprocess.run(command, cwd=ROOT)
(OUT / 'work-check.json').write_text(json.dumps(dict(command=' '.join(command),
    exit=result.returncode, seconds=round(time.monotonic()-before,3)), indent=2)+'\n')
sys.exit(result.returncode)
