#!/usr/bin/env python3
"""検査本体と外側の計時の終了を分け、パスを伏せて記録する。"""
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def redact(text):
    for old, new in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                     ('/private/tmp', '<tmp>'), ('/tmp', '<tmp>')]:
        text = text.replace(old, new)
    return text


def main():
    kind, name, *command = sys.argv[1:]
    started = datetime.datetime.now().astimezone().isoformat()
    clock = time.monotonic()
    actual = command
    if kind == 'timed':
        actual = ['/usr/bin/time', '-l', sys.executable, str(Path(__file__).resolve()),
                  'child', name] + command
    result = subprocess.run(actual, cwd=ROOT, capture_output=True, env=os.environ)
    seconds = time.monotonic() - clock
    suffix = '-time' if kind == 'timed' else ''
    (HERE / (name + suffix + '.log')).write_text(redact(
        result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace')))
    status = {'started': started, 'ended': datetime.datetime.now().astimezone().isoformat(),
              'command': [redact(arg) for arg in actual], 'exit': result.returncode,
              'seconds': seconds}
    (HERE / (name + suffix + '.json')).write_text(
        json.dumps(status, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'name': name, 'kind': kind, 'exit': result.returncode,
                      'seconds': seconds}), flush=True)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
