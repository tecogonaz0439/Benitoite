"""検査を逐次実行し、手元のパスを伏せて時間・終了状態・出力を記録する。"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent


def redact(text):
    for source, label in ((str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                          (tempfile.gettempdir(), '<tmp>'), ('/private/tmp', '<tmp>'), ('/tmp/', '<tmp>/')):
        text = text.replace(source, label)
    return text


def main():
    name, *command = sys.argv[1:]
    env = dict(os.environ, CARGO_HOME=str(Path(os.path.realpath(os.path.join(os.sep, 'tmp')))
                                        / 'benitoite-a01a-cargo'))
    start = time.monotonic()
    process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    lines = []
    with (HERE/(name+'.log')).open('w') as stream:
        for line in process.stdout:
            line = redact(line)
            stream.write(line)
            stream.flush()
            lines.append(line)
            if line.startswith('== '):
                print(line.rstrip(), flush=True)
    process.wait()
    record = dict(command=[redact(c) for c in command], exit=process.returncode,
                  seconds=round(time.monotonic()-start, 3), cargoHome='<tmp>/benitoite-a01a-cargo')
    (HERE/(name+'.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(record, ensure_ascii=False))
    print(''.join(lines)[-3000:])
    sys.exit(process.returncode)


if __name__ == '__main__':
    main()
