"""既定ビルド又は全環境の公理監査を共有ロックの下で実行し、入出力を記録する。"""
import argparse
import datetime
import json
import subprocess
import time
from pathlib import Path
from inventory import HERE, ROOT, digest, save, fingerprint, sources

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tmp', type=Path, required=True)
parser.add_argument('--lock', type=Path, required=True)
parser.add_argument('--kind', choices=['build', 'axioms', 'verify'], required=True)
a = parser.parse_args()
if a.kind == 'build':
    command = ['lake', 'build']
elif a.kind == 'axioms':
    command = ['lake', 'env', 'lean', '-M', '12288', '../'+str((HERE/'axioms.lean').relative_to(ROOT))]
else:
    command = ['python3', str(HERE/'verify.py'), '--tmp', str(a.tmp)]
invocation = ['/usr/bin/lockf', '-t', '3600', str(a.lock)] + command if a.kind != 'verify' else command
before = sources()
start = datetime.datetime.now().astimezone().isoformat()
t0 = time.monotonic()
log = a.tmp / (a.kind+'.log')
with log.open('w') as out:
    result = subprocess.run(invocation, cwd=ROOT/'formal', stdout=out, stderr=subprocess.STDOUT)
    out.write('\nrc='+str(result.returncode)+'\n')
after = sources()
record = dict(command=' '.join(command).replace(str(ROOT), '<repo>').replace(str(a.tmp), '<tmp>'),
              start=start, end=datetime.datetime.now().astimezone().isoformat(),
              seconds=time.monotonic()-t0, exit_code=result.returncode,
              bytes=log.stat().st_size, sha256=digest(log), inputs=len(before),
              fingerprint=fingerprint(before), after_fingerprint=fingerprint(after), same_inputs=before==after)
save(HERE/(a.kind+'-summary.json'), record)
print(json.dumps(record, ensure_ascii=False, indent=1))
assert before == after, '検査中に本番の入力が変わった'
raise SystemExit(result.returncode)
