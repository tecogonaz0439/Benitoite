"""コマンドを逐次実行し、手元のパスを伏せて結果を保存する。"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent

def main():
    name, *command = sys.argv[1:]
    env = dict(os.environ, CARGO_HOME=str(Path(os.path.realpath(os.path.join(os.sep, 'tmp'))) / 'benitoite-a01a-cargo'))
    started = time.monotonic()
    process = subprocess.Popen(command, cwd=ROOT / "formal" if command[0] == "lake" else ROOT,
                               env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    lines = []
    with (HERE / (name + '.log')).open('w') as log:
        for line in process.stdout:
            line = line.replace(str(ROOT), '<repo>').replace(str(Path.home()), '<home>').replace(os.path.realpath(os.path.join(os.sep, 'tmp')), '<tmp>').replace(os.path.join(os.sep, 'tmp') + os.sep, '<tmp>/')
            log.write(line)
            log.flush()
            lines.append(line)
            if line.startswith('== '):
                print(line.rstrip(), flush=True)
    process.wait()
    output = ''.join(lines)
    record = {'command': command, 'exit': process.returncode, 'seconds': round(time.monotonic() - started, 3)}
    (HERE / (name + '.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(record, ensure_ascii=False))
    print(output[-3500:])
    sys.exit(process.returncode)

if __name__ == '__main__':
    main()
