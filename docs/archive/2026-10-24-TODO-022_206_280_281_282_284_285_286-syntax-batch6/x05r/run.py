"""実行・計測を記録し、手元の絶対パスを保存しない。"""
from pathlib import Path
import datetime
import json
import os
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent

def redact(text):
    for path, label in [(str(ROOT), '<repo>'), (str(Path.home()), '<home>'), ('/private/tmp', '<tmp>'), ('/tmp', '<tmp>')]:
        text = text.replace(path, label)
    return text

def main():
    label, *command = sys.argv[1:]
    if label == 'body':
        label, *command = command
        start = time.monotonic()
        code = subprocess.call(command, cwd=ROOT)
        (HERE/(label+'-body.json')).write_text(json.dumps(dict(command=list(map(redact, command)), exit=code,
            seconds=time.monotonic()-start), indent=2)+'\n')
        raise SystemExit(code)
    env = dict(os.environ)
    start = time.monotonic()
    started = datetime.datetime.now().astimezone().isoformat()
    with (HERE/(label+'.log')).open('w') as stream:
        p = subprocess.Popen(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for line in p.stdout:
            stream.write(redact(line))
            stream.flush()
        code = p.wait()
    (HERE/(label+'.json')).write_text(json.dumps(dict(command=list(map(redact, command)), exit=code,
        started=started, ended=datetime.datetime.now().astimezone().isoformat(), seconds=time.monotonic()-start), indent=2)+'\n')
    print(label, 'exit', code, 'seconds', round(time.monotonic()-start, 3))
    raise SystemExit(code)

if __name__ == '__main__':
    main()
