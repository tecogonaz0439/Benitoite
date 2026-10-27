#!/usr/bin/env python3
"""外側の計時と検査本体の終了を分け、パスを伏せて保存する。"""
import datetime
import importlib.util
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
spec = importlib.util.spec_from_file_location('u01_inventory', HERE / 'inventory.py')
inventory = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inventory)


def main():
    kind, name, *command = sys.argv[1:]
    start = datetime.datetime.now().astimezone().isoformat()
    clock = time.monotonic()
    if kind == 'timed':
        actual = ['/usr/bin/time', '-l', sys.executable, str(Path(__file__).resolve()), 'child', name] + command
    else:
        actual = command
    result = subprocess.run(actual, cwd=ROOT, capture_output=True, env=os.environ)
    elapsed = time.monotonic() - clock
    suffix = '-time' if kind == 'timed' else ''
    (HERE / (name + suffix + '.log')).write_text(inventory.redact(
        result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace')))
    inventory.write(HERE / (name + suffix + '.json'), {
        'started': start, 'ended': datetime.datetime.now().astimezone().isoformat(),
        'command': [inventory.redact(s) for s in actual],
        'exit': result.returncode, 'seconds': elapsed})
    print(json.dumps({'name': name, 'kind': kind, 'exit': result.returncode, 'seconds': elapsed}), flush=True)
    return result.returncode


if __name__ == '__main__':
    raise SystemExit(main())
