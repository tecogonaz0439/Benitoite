"""指定検査を一度実行し、検査本体と time の終了を分けて保存する。"""
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def redact(value):
    for source, label in ((str(ROOT), '<repo>'), (str(Path.home()), '<home>'),
                          (tempfile.gettempdir(), '<tmp>'), ('/private/tmp', '<tmp>'),
                          ('/tmp/', '<tmp>/')):
        value = value.replace(source, label)
    return value


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def write(name, record):
    (HERE/name).write_text(redact(json.dumps(record, ensure_ascii=False, indent=2))+'\n')


def main():
    mode, name, *command = sys.argv[1:]
    start, stamp = time.monotonic(), now()
    if mode == 'child':
        result = subprocess.run(command, cwd=ROOT)
        write(name+'-body.json', dict(command=command, started=stamp, ended=now(),
              exit=result.returncode, seconds=round(time.monotonic()-start, 3)))
        print('X05a body exit: '+str(result.returncode), flush=True)
        sys.exit(result.returncode)
    env = dict(os.environ, CARGO_HOME=str(Path(os.path.realpath(os.path.join(os.sep, 'tmp')))
                                         / 'benitoite-a01a-cargo'))
    if name == 'k1':
        for key, directory in (('DESUGAR', 'desugar'), ('COVERAGE', 'coverage'),
                               ('INTERVAL', 'interval')):
            env['BENITOITE_'+key+'_DIFF_DIR'] = 'target/'+directory+'-diff/x05a-k1-20261027'
    actual = command
    if mode == 'timed':
        actual = ['/usr/bin/time', '-l', sys.executable, str(Path(__file__).relative_to(ROOT)),
                  'child', name]+command
    write(name+'-started.json', dict(command=actual, started=stamp,
          environment={k: redact(v) for k, v in env.items()
                       if k == 'CARGO_HOME' or k.startswith('BENITOITE_')}))
    process = subprocess.Popen(actual, cwd=ROOT, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True)
    with (HERE/(name+'.log')).open('w') as stream:
        for line in process.stdout:
            line = redact(line)
            stream.write(line)
            stream.flush()
            if line.startswith(('== ', 'X05a body exit:', 'interval manifest:')):
                print(line.rstrip(), flush=True)
    process.wait()
    record = dict(command=actual, started=stamp, ended=now(), exit=process.returncode,
                  seconds=round(time.monotonic()-start, 3))
    write(name+'.json', record)
    print(redact(json.dumps(record, ensure_ascii=False)), flush=True)
    sys.exit(process.returncode)


if __name__ == '__main__':
    main()
