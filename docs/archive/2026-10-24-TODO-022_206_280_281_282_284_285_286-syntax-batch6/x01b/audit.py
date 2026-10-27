"""最終差分、検査中の入力の不変、件数と記録の伏せ方を点検する。"""
from pathlib import Path
import ast
import hashlib
import json
import re
import subprocess
import zipfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
inputs = json.loads((OUT/'work-inputs-final.json').read_text())
assert all(hashlib.sha256((ROOT/f).read_bytes()).hexdigest() == h for f,h in inputs.items())
files = subprocess.check_output(['git','diff','--name-only'], cwd=ROOT, text=True).splitlines()
assert set(files) == set(inputs)
assert subprocess.check_output(['git','diff','--name-only','--','formal'], cwd=ROOT, text=True).splitlines() == ['formal/tests/test_interval_exchange.py']
assert not any('/src/' in f or 'reference' in f or f.endswith(('.lean','.toml','.lock','.tsv')) for f in files)
subprocess.run(['git','diff','--check'], cwd=ROOT, check=True)
for path in OUT.glob('*.py'):
    ast.parse(path.read_text())
ast.parse((ROOT/'formal/tests/test_interval_exchange.py').read_text())
log = (OUT/'work-corrected.log').read_text()
lib, tests = log.split('== tests_related',1)
tests = tests.split('== source_rules',1)[0]
pattern = r'test result: ok\. (\d+) passed; (\d+) failed; (\d+) ignored;'
lib_counts = re.findall(pattern,lib)
test_counts = re.findall(pattern,tests)
assert len(lib_counts) == 1 and len(test_counts) == 40
assert all(int(failed) == 0 for _, failed, _ in lib_counts+test_counts)
units = re.findall(r'^   \[([^]]+)\]',log,re.MULTILINE)
assert len(units) == 8 and 'selected checks passed' in log
assert json.loads((OUT/'work-check.json').read_text())['exit'] == 0
index = json.loads((OUT/'local-records-index.json').read_text())
with zipfile.ZipFile(OUT/'local-records.zip') as archive:
    assert sorted(archive.namelist()) == sorted(row['path'] for row in index)
    for row in index:
        assert hashlib.sha256(archive.read(row['path'])).hexdigest() == row['sha256']
for path in OUT.iterdir():
    if path.is_file() and path.suffix != '.zip':
        assert str(ROOT).encode() not in path.read_bytes(), path.name
        assert str(Path.home()).encode() not in path.read_bytes(), path.name
counts = lambda rows: dict(passed=sum(int(p) for p,_,_ in rows),failed=0,ignored=sum(int(i) for _,_,i in rows))
numstat = subprocess.check_output(['git','diff','--numstat'],cwd=ROOT,text=True).splitlines()
summary = dict(files=files, hashes=inputs, units=units, lib=counts(lib_counts),
               integration=dict(targets=len(test_counts),**counts(test_counts)),
               sourceUnchangedDuringWork=True, leanDefinitionsUnchanged=True,
               productionRustChanged=False, archiveFiles=len(index),
               maximumResidentSetSize=None, memoryReason='sysctl kern.clockrate: Operation not permitted',
               codeLines=[dict(path=f,added=int(a),removed=int(d)) for a,d,f in (row.split('\t') for row in numstat)])
(OUT/'self-review.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,ensure_ascii=False))
