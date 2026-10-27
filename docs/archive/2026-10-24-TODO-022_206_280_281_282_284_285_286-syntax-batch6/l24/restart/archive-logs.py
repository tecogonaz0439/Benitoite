"""反復した開発ログをzipへまとめ、最終検査と採取結果は直接参照できる形で残す。"""
import hashlib,json,shutil,zipfile
from pathlib import Path
import run

keep_prefixes = ['integrated-final-', 'acceptance-ready-']
keep_names = ['http-tests-second', 'default-up-to-date', 'axioms-final',
              'dry-run', 'work', 'work-check', 'audit', 'reference-impact']
keep_names += ['http-tests-first-Benitoite.Interval.' + name for name in
               ['Sound','BudgetNormal','BudgetSound','CallReach']]
files=[]
for path in sorted(run.OUT.iterdir()):
    if path.suffix not in ['.json','.log']:continue
    if path.stem in keep_names or any(path.stem.startswith(prefix) for prefix in keep_prefixes):continue
    if path.name=='development-logs-index.json':continue
    files.append(path)
assert not (run.OUT/'development-logs.zip').exists()
index=[]
with zipfile.ZipFile(run.OUT/'development-logs.zip','w',compression=zipfile.ZIP_DEFLATED) as archive:
    for path in files:
        data=path.read_bytes()
        archive.writestr(path.name,data)
        index.append(dict(name=path.name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
with zipfile.ZipFile(run.OUT/'development-logs.zip') as archive:
    assert archive.testzip() is None
    for item in index:
        assert hashlib.sha256(archive.read(item['name'])).hexdigest()==item['sha256']
(run.OUT/'development-logs-index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
for path in files:path.unlink()
for directory in run.OUT.rglob('__pycache__'):shutil.rmtree(directory)
print(json.dumps(dict(archived_files=len(files),uncompressed_bytes=sum(i['bytes'] for i in index),
                      zip_bytes=(run.OUT/'development-logs.zip').stat().st_size)))
