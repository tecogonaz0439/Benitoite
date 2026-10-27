#!/usr/bin/env python3
"""実行結果・外側時間を保存し、手元のパスを伏せる。"""

import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

out = Path(__file__).resolve().parent
repo = out.parents[2]
name, *command = sys.argv[1:]
started = time.monotonic()
result = subprocess.run(command, cwd=repo, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True)
elapsed = time.monotonic() - started


def redact(value):
    for path, replacement in [(str(repo), '<repo>'), (str(Path.home()), '<home>'),
                              (tempfile.gettempdir(), '<tmp>'),
                              (str(Path('/') / 'private' / 'tmp'), '<tmp>'),
                              (str(Path('/') / 'tmp') + '/', '<tmp>/')]:
        value = value.replace(path, replacement)
    return value


output = redact(result.stdout)
(out / (name + '.log')).write_text(output)
(out / (name + '.json')).write_text(json.dumps({
    'command': [redact(arg) for arg in command],
    'exit': result.returncode, 'seconds': elapsed,
}, ensure_ascii=False, indent=2) + '\n')
print(output[-6000:])
print(f'{name}: exit={result.returncode}, seconds={elapsed:.3f}')
sys.exit(result.returncode)
