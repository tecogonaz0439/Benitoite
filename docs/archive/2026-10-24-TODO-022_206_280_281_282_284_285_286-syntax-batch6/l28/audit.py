"""基準の既存定理と参照定義、作業末の入力と記録のパスを照合する。"""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
BASE = '640538669de0da18d8d0947327ff9c84fef22b55'
ALLOWED = {'formal/Benitoite/Interval/Exchange.lean',
           'formal/Benitoite/Interval/ExchangeExamples.lean',
           'formal/IntervalDiff/Main.lean'}
INPUTS = sorted(ALLOWED | {'formal/tests/test_interval_exchange.py',
    'docs/design/01-spec/01-12-core-calculus.md',
    'docs/design/07-quality/07-04-formal-semantics.md'})

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

def sha(data):
    return hashlib.sha256(data).hexdigest()

files = git('ls-tree', '-rz', '--name-only', BASE, 'formal', 'crates', 'fuzz', 'scripts',
            'Cargo.toml', 'Cargo.lock', 'deny.toml', 'rust-toolchain.toml').decode().strip('\0').split('\0')
changed, theorem_count = [], 0
for name in files:
    old = git('show', BASE+':'+name)
    if name.startswith('formal/') and name.endswith('.lean'):
        theorem_count += len(re.findall(rb'(?m)^\s*(?:(?:private|protected|noncomputable)\s+)?theorem\s+', old))
    if not (ROOT/name).is_file() or old != (ROOT/name).read_bytes():
        changed.append(name)
assert set(changed) == ALLOWED, changed
# 公開の定理が参照する定義のファイル全体の不変を別表へ残す。
references = ['Eval', 'EvalClosed', 'Domain', 'Environment', 'Sound', 'SyntacticReach',
              'CallReach', 'BudgetAnalyze', 'BudgetSound', 'BudgetNormal',
              'BudgetWhole', 'RangeState']
reference_rows = []
for stem in references:
    name = 'formal/Benitoite/Interval/'+stem+'.lean'
    old, new = git('show', BASE+':'+name), (ROOT/name).read_bytes()
    assert old == new, name
    reference_rows.append(dict(file=name, identical=True, sha256=sha(new)))
for name in ALLOWED:
    current = (ROOT/name).read_text()
    assert not re.search(r'(?m)^\s*(?:axiom|theorem)\s+', current), name
    assert not re.search(r'\bsorry\b', current), name
snap = {name: sha((ROOT/name).read_bytes()) for name in INPUTS}
snapshot_file = OUT/'work-inputs-sha256.json'
if '--snapshot' in sys.argv:
    snapshot_file.write_text(json.dumps(snap, indent=2)+'\n')
else:
    assert json.loads(snapshot_file.read_text()) == snap
# 保存するコードとログは手元の絶対パスを持たない。
for path in sorted(OUT.rglob('*')):
    if not path.is_file() or path.suffix == '.zip':
        continue
    raw = path.read_bytes()
    assert str(ROOT).encode() not in raw and str(Path.home()).encode() not in raw, path.name
for name in ['formal/tests/test_interval_exchange.py']:
    ast.parse((ROOT/name).read_text())
for path in OUT.glob('*.py'):
    ast.parse(path.read_text())
subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
record = dict(base=BASE, head=git('rev-parse', 'HEAD').decode().strip(),
              checkedFiles=len(files), unchangedFiles=len(files)-len(changed),
              changedFiles=changed, existingTheorems=theorem_count,
              definitions=reference_rows, inputs=snap)
(OUT/('audit-report-before.json' if '--snapshot' in sys.argv else 'audit-report-after.json')).write_text(json.dumps(record, indent=2)+'\n')
print(json.dumps({key: value for key, value in record.items() if key not in ('definitions', 'inputs')}, ensure_ascii=False))
