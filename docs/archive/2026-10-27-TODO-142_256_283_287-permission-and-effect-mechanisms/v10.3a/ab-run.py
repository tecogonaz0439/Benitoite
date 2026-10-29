"""追補のコマンド・終了状態・時間を、既存の記録を保って保存する。"""
from datetime import datetime, timezone
from pathlib import Path
import json
import os
import subprocess
import sys
import time

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]


def clean(value):
    return (value.replace(str(ROOT), '<wt>')
            .replace(str(Path.home()), '<home>')
            .replace('/private/tmp', '<tmp>').replace('/tmp/', '<tmp>/'))


name, *command = sys.argv[1:]
start = datetime.now(timezone.utc).isoformat()
before = time.monotonic()
env = dict(os.environ)
env['BENITOITE_DESUGAR_DIFF_DIR'] = str(ROOT / 'target/v10.3a/export2')
log = OUT / ('ab-' + name + '.log')
with log.open('wb') as stream:
    result = subprocess.run(command, cwd=ROOT, env=env,
                            stdout=stream, stderr=subprocess.STDOUT)
elapsed = time.monotonic() - before
log.write_text(clean(log.read_text(errors='replace')))
record = dict(command=[clean(x) for x in command],
              environment={'BENITOITE_DESUGAR_DIFF_DIR': '<wt>/target/v10.3a/export2'},
              started=start, finished=datetime.now(timezone.utc).isoformat(),
              exit=result.returncode, wallSeconds=elapsed)
(OUT / ('ab-' + name + '.json')).write_text(
    json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
print(log.read_text()[-4000:])
sys.exit(result.returncode)
