"""実行の終了状態・外側時間・出力をパスを伏せて保存する。"""
from pathlib import Path
import datetime
import json
import os
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]

def redact(value):
    return str(value).replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>').replace('/private/tmp', '<tmp>').replace('/tmp/', '<tmp>/')

def run(label, args, cwd=ROOT, timeout=300):
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    before = time.monotonic()
    try:
        p = subprocess.run(args, cwd=cwd, text=True, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, timeout=timeout)
        code, output = p.returncode, p.stdout
    except subprocess.TimeoutExpired as exc:
        code = 124
        raw = exc.stdout or b''
        output = (raw.decode(errors='replace') if isinstance(raw, bytes) else raw) + '\nTIMEOUT\n'
    record = dict(command=[redact(a) for a in args], cwd=redact(cwd),
                  start=start, seconds=round(time.monotonic() - before, 3), exit=code)
    (OUT / (label + '.log')).write_text(redact(output))
    (OUT / (label + '.json')).write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(record), flush=True)
    if code:
        print(redact(output)[-10000:])
    return code

if __name__ == '__main__':
    label, place, *args = sys.argv[1:]
    raise SystemExit(run(label, args, ROOT / place))
