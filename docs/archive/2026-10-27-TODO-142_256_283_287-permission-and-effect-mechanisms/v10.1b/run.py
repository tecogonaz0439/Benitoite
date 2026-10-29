"""指定された局所コマンドを計時し、終了・ログを保存する。"""
import datetime
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
if sys.argv[1] == '--child':
    label = sys.argv[2]
    result = subprocess.run(sys.argv[3:], cwd=ROOT)
    (HERE / (label + '-command-exit.json')).write_text(json.dumps({'exit':result.returncode}) + '\n')
    sys.exit(result.returncode)
label = sys.argv[1]
command = sys.argv[2:]
start = datetime.datetime.now(datetime.timezone.utc)
clock = time.monotonic()
timed_command = [sys.executable, '-B', str(Path(__file__).resolve()), '--child', label, *command] if label.startswith('w-r') else command
result = subprocess.run(['/usr/bin/time', '-p', *timed_command], cwd=ROOT, text=True, capture_output=True)
def clean(text):
    return text.replace(str(ROOT), '<wt>').replace(str(Path.home()), '<home>')
(HERE / (label + '.log')).write_text(clean(result.stdout + result.stderr))
record = dict(command=clean(' '.join(command)), environment={key:clean(value) for key,value in os.environ.items() if key in ['BENITOITE_DESUGAR_DIFF_DIR','CARGO_TARGET_DIR']}, startedAt=start.isoformat(), finishedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(), exit=result.returncode, elapsedSeconds=time.monotonic()-clock, timeMode='/usr/bin/time -p', rss='-p は最大常駐量を表示しないため未取得')
if label.startswith('w-r'):
    record['checkShExit'] = json.loads((HERE / (label + '-command-exit.json')).read_text())['exit']
(HERE / (label + '.json')).write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(record, ensure_ascii=False))
print(clean((result.stdout + result.stderr)[-3000:]))
sys.exit(result.returncode)
