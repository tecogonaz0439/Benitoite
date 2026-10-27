"""検査本体と外側の time の終了状態を区別する。"""
import json
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
command = ['scripts/check.sh', '--level', 'work', '--base', '0341dfe350598fb3626137d4d47121301acea382']
started = time.monotonic()
result = subprocess.run(command)
record = {'command': command, 'exit': result.returncode, 'seconds': round(time.monotonic() - started, 3)}
(HERE / 'work-check-scoped.json').write_text(json.dumps(record, indent=2) + '\n')
sys.exit(result.returncode)
