# -*- coding: utf-8 -*-
"""指定ロックの下で既定ビルド又は全環境監査を一度実行し、生出力を一時領域へ保存する。"""
import argparse
import json
import hashlib
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('phase', choices=['build', 'axioms'])
parser.add_argument('--lock', required=True)
parser.add_argument('--tmp', type=Path, required=True)
a = parser.parse_args()
command = ['lake', 'build']
if a.phase == 'axioms':
    command = ['lake', 'env', 'lean', '-M', '12288', '../'+str((HERE/'axioms.lean').relative_to(ROOT))]
log = a.tmp/(a.phase+'.log')
assert not log.exists(), '同じ最終検査の記録を上書きしない'
start = subprocess.check_output(['date', '+%Y-%m-%d %H:%M:%S %Z'], text=True).strip()
def source_fingerprint():
    modules = json.loads((HERE/'audit-modules.json').read_text())
    paths = ['formal/'+m.replace('.', '/')+'.lean' for m in modules] + ['formal/Benitoite.lean']
    hashes = {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
    return hashlib.sha256(json.dumps(hashes, sort_keys=True).encode()).hexdigest()

source_sha = source_fingerprint()
tick = time.monotonic()
with log.open('w') as f:
    result = subprocess.run(['/usr/bin/lockf', '-t', '3600', a.lock, *command],
                            cwd=ROOT/'formal', stdout=f, stderr=subprocess.STDOUT)
    f.write(f'\nrc={result.returncode}\n')
end = subprocess.check_output(['date', '+%Y-%m-%d %H:%M:%S %Z'], text=True).strip()
assert source_fingerprint() == source_sha, '検査中に本番のソースが変わった'
meta = {'source_sha256':source_sha,'start':start,'end':end,'seconds_including_lock_wait':round(time.monotonic()-tick,3),
        'rc':result.returncode}
(a.tmp/(a.phase+'-time.json')).write_text(json.dumps(meta,ensure_ascii=False,indent=1)+'\n')
print(json.dumps({'phase':a.phase,**meta},ensure_ascii=False,indent=1))
raise SystemExit(result.returncode)
