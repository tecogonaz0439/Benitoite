# coding: utf-8
from pathlib import Path
import json
import shlex
import subprocess
import time

D = Path('docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms')
O = Path('work/m013/scratch/P1b')
E = D/'evidence/P1b'
E.mkdir(parents=True, exist_ok=True)
for p in (O/'reproduced/dry-run').iterdir():
    (E/p.name).write_bytes(p.read_bytes())
head = subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
command = ['bash','scripts/check.sh','--level','work','--base',head,'--dry-run']
assert '--dry-run' in command
start=time.monotonic()
result=subprocess.run(command, text=True, capture_output=True)
elapsed=time.monotonic()-start
def redact(s):
    return s.replace(str(Path.cwd()),'<repo>').replace(str(Path.home()),'<home>')
for root in [O,E]:
    (root/'work-p1b.stdout.txt').write_text(redact(result.stdout))
    (root/'work-p1b.stderr.txt').write_text(redact(result.stderr))
    (root/'work-p1b.json').write_text(json.dumps({
        'head':head,'base':head,'command':shlex.join(command),
        'exit':result.returncode,'elapsed_seconds':round(elapsed,4),
        'stdout':'work-p1b.stdout.txt','stderr':'work-p1b.stderr.txt',
        'selected':[line.strip() for line in result.stdout.splitlines() if line.lstrip().startswith('[')]
    },ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'exit':result.returncode,'seconds':round(elapsed,4)},ensure_ascii=False))
if result.returncode:
    raise SystemExit(result.returncode)
