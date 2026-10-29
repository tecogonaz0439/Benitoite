#!/usr/bin/env python3
"""検査を直接の子として実行し、終了状態・外側時間・RSS補助値を保存する。"""
import datetime
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import time

out = Path(__file__).resolve().parent
name, *command = sys.argv[1:]
root = Path.cwd()

def redact(value):
    value = value.replace(str(root), '<wt>').replace(str(Path.home()), '<home>')
    if os.environ.get('TMPDIR'):
        value = value.replace(os.environ['TMPDIR'], '<tmp>/')
    return value.replace('/private/tmp/', '<tmp>/').replace('/tmp/', '<tmp>/')

start = datetime.datetime.now(datetime.timezone.utc)
clock = time.monotonic()
completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - clock
usage = resource.getrusage(resource.RUSAGE_CHILDREN)
(out / (name + '.log')).write_text(redact(completed.stdout.decode('utf-8', errors='replace')))
record = {
    'command': [redact(arg) for arg in command],
    'startUtc': start.isoformat(),
    'endUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'exitCode': completed.returncode,
    'checkExitCode': completed.returncode if command[0] == 'scripts/check.sh' else None,
    'elapsedSeconds': elapsed,
    'maxRssRaw': usage.ru_maxrss,
    'maxRssUnit': 'bytes' if sys.platform == 'darwin' else 'KiB',
    'measurement': 'getrusage(RUSAGE_CHILDREN), 子孫の最大値。合計常駐量ではない',
}
(out / (name + '.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
raise SystemExit(completed.returncode)
