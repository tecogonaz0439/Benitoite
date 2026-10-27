"""追加した固定 manifest の一入力を既存の実入口で照合する。"""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT/'target/interval-diff/x05r-local'
source = BASE/'manifest'
out = BASE/'fixed'
out.mkdir(exist_ok=True)
name = 'testdata/warnings/local-width-intervals.bnt'
for suffix in ['corpus', 'builtins', 'stdlib', 'coverage']:
    doc = json.loads((source/('manifest-'+suffix+'.json')).read_text())
    doc['inputs'] = [i for i in doc['inputs'] if i['name'] == name]
    assert len(doc['inputs']) == 1
    (out/(suffix+'.json')).write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
commands = [('desugarDiff', ['corpus']), ('builtinCheck', ['corpus','builtins']),
            ('coverageProgramDiff', ['coverage','builtins']),
            ('surfaceCheckAll', ['corpus','builtins','stdlib']),
            ('surfaceCheck', ['corpus','builtins','stdlib'])]
for exe, files in commands:
    report = out/(exe+'.report.json')
    args = [str(out/(file+'.json')) for file in files]
    if exe == 'surfaceCheck':
        args += ['golden', name]
    p = subprocess.run([str(ROOT/'formal/.lake/build/bin'/exe), *args, str(report)],
                       capture_output=True, text=True)
    expected_exit = 1 if exe == 'surfaceCheckAll' else 0
    assert p.returncode == expected_exit, (exe, p.stdout, p.stderr)
    if exe == 'surfaceCheckAll':
        result = json.loads(report.read_text())
        assert result['q11Agrees'] is False and result['counts'] == dict(lazyRestriction=0,matched=9,mismatched=0,outOfScope=0,preparationFailure=0,q11=0)
    print(exe, report.read_text())
corpus = json.loads((out/'corpus.json').read_text())['inputs'][0]
coverage = json.loads((out/'coverage.json').read_text())['inputs'][0]
assert len(corpus['definitions']) == 9 and all('inScope' in d['scope'] for d in corpus['definitions'])
assert len(coverage['matches']) == 1 and not coverage['bindings']
print(json.dumps(dict(input=name, definitions=9, scopes=dict(inScope=9), coverage=dict(matches=1,bindings=0))))
