"""編集範囲・残す記録・移動先のハッシュ・リンク・Lean引用の入力を最終確認する。"""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = ROOT/'target/k10.2-raw'


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


changed = subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=ROOT,text=True).splitlines()
allowed = {'scripts/check-formal.sh','scripts/check/formal_interval.py',
           'docs/design/01-spec/01-12-core-calculus.md',
           'docs/design/07-quality/07-03-compiler-testing.md',
           'docs/design/07-quality/07-04-formal-semantics.md'}
require(all(p.startswith(('crates/benitoite/','formal/tests/')) or p in allowed for p in changed),
        'tracked edit outside allowed scope')
require(not subprocess.check_output(['git','diff','HEAD','--','crates/benitoite/src','formal/Benitoite',
            'formal/lakefile.toml'],cwd=ROOT), 'runtime or Lean source changed')
require(not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=ROOT), 'index differs')
head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
require(head == 'c3ca4504dae42271df7336aca41d0a6d5447d0e3', 'HEAD changed')
untracked = subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',
                'crates/benitoite','formal/tests'],cwd=ROOT,text=True).splitlines()
state = dict(head=head,baseline=head,changed=changed,untrackedInputs=untracked,
             files=[dict(path=p,bytes=(ROOT/p).stat().st_size,sha256=sha((ROOT/p).read_bytes()))
                    for p in changed+untracked])
(HERE/'k10.2b-source-state.json').write_text(json.dumps(state,ensure_ascii=False,indent=2)+'\n')

missing = []
for path in HERE.rglob('*.md'):
    for value in re.findall(r'\[[^\]]*\]\(([^)]+)\)', path.read_text()):
        value = value.split('#')[0]
        if value and '://' not in value and not (path.parent/value).exists():
            missing.append([path.relative_to(HERE).as_posix(), value])
require(not missing, missing)
files = [p for p in HERE.rglob('*') if p.is_file()]
require(not any(p.stat().st_size > 200*1024 for p in files), 'large file remains')
require(not any(str(Path.home()).encode() in p.read_bytes() for p in files
                if p.suffix not in ('.gz','.zip','.pyc')), 'local absolute path remains')
for path in [ROOT/'formal/tests'/name for name in ('test_range_sources.py','test_range_rejections.py',
             'test_range_budget_sources.py','test_range_known_differences.py')] + list(HERE.rglob('*.py')):
    tree = ast.parse(path.read_text())
    if 'rv-probes' not in path.parts and 'independent-exchange' not in path.parts:
        require(not any(isinstance(n,ast.Assert) for n in ast.walk(tree)), str(path)+': assert remains')
rows = json.loads((HERE/'k10.2b-moved-records.json').read_text())
for entry in rows:
    data = (RAW/entry['inventory']).read_bytes()
    require(sha(data) == entry['inventorySha256'], entry['path']+': inventory differs')
    members = json.loads(data)
    require(len(members) == entry['files'] and sum(r['bytes'] for r in members) == entry['bytes'],
            entry['path']+': file count/bytes differ')
    for row in members:
        data = (RAW/row['path']).read_bytes()
        require(len(data) == row['bytes'] and sha(data) == row['sha256'], row['path']+': contents differ')
        require(not (HERE/row['path']).exists(), row['path']+': duplicate retained')
old = json.loads((HERE/'b-lean-inputs-and-tools.json').read_text())
require(all(sha((ROOT/name).read_bytes()) == expected for name,expected in old['hashes'].items()),
        'B-Lean inputs or binaries differ')
for name in ('exchange-manifest.json','routing-manifest.json'):
    text = (ROOT/'crates/benitoite/tests/desugar_export'/name).read_text()
    require('/Users/' not in text and '/home/' not in text, name+': local path remains')
summary = dict(status='passed',missingLinks=missing,movedFiles=sum(r['files'] for r in rows),
               movedBytes=sum(r['bytes'] for r in rows),retainedFiles=len(files),
               retainedBytes=sum(p.stat().st_size for p in files),checkedLeanInputs=len(old['hashes']),
               remainingLargeFiles=0,localAbsolutePaths=0,headUnchanged=True,indexUnchanged=True,
               runtimeSourceChanges=0)
(HERE/'k10.2b-record-verification.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(summary))
