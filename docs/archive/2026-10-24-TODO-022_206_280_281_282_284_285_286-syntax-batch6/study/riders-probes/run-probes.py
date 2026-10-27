import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / 'work/m012/scratch/s2'
observations = []
for name in ('file-sink', 'json-sink'):
    for verb in ('check', 'run'):
        command = ['target/debug/benitoite', verb, f'work/m012/scratch/s2/{name}.bnt']
        started = time.monotonic()
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=30)
        (OUT / f'{name}.{verb}.stdout').write_text(result.stdout)
        (OUT / f'{name}.{verb}.stderr').write_text(result.stderr)
        observations.append({'command': command, 'exit': result.returncode, 'seconds': round(time.monotonic() - started, 3), 'stdout': result.stdout, 'stderr': result.stderr})
(OUT / 'observations.json').write_text(json.dumps(observations, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(observations, ensure_ascii=False, indent=2))
