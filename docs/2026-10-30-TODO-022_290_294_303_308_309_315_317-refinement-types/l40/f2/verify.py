"""入力・既定 import・公理監査・担当義務・共通検査の記録を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = '2719963cf6c41badadbd3589fd150179f34fe075'

def load(name): return json.loads((HERE/name).read_text())
def digest(path):
    b = path.read_bytes()
    return {'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
def write(name, value):
    b = (json.dumps(value,ensure_ascii=False,indent=2)+'\n').encode()
    assert len(b) <= 100000
    (HERE/name).write_bytes(b)

modules = load('modules.json')
prefix = 'Benitoite.Release.Refinement.'
new_files = {'formal/'+(prefix+m).replace('.','/')+'.lean' for m in modules}
start = {}
for f in sorted(HERE.glob('inputs-start-*.json')): start.update(json.loads(f.read_text()))
allowed = {'formal/Benitoite.lean','docs/design/01-spec/01-12-core-calculus.md',
           'docs/design/07-quality/07-04-formal-semantics.md'}
changed = {name:digest(ROOT/name) for name,before in start.items() if digest(ROOT/name) != before}
assert set(changed) == allowed, changed
current = {str(f.relative_to(ROOT)) for f in (ROOT/'formal').rglob('*.lean') if '.lake' not in f.parts}
assert current - set(start) == new_files
assert set(start)-current == {p for p in start if p.startswith('docs/')}

seen = set()
def imports(module):
    if module in seen: return
    seen.add(module)
    f = ROOT/'formal'/(module.replace('.','/')+'.lean')
    if f.exists():
        for child in re.findall(r'^import (\S+)',f.read_text(),re.M): imports(child)
imports('Benitoite')
assert all(prefix+m in seen for m in modules)
root_text = (ROOT/'formal/Benitoite.lean').read_text()
rest = '\n'.join(x for x in root_text.splitlines() if x not in {'import '+prefix+m for m in modules})
assert any(hashlib.sha256((rest.rstrip()+'\n'*n).encode()).hexdigest() == start['formal/Benitoite.lean']['sha256']
           for n in range(1,4)), '既存 import の本文の差'

audit = load('audit-summary.json')
assert audit['exit'] == 0 and audit['new_axioms'] == 0 and audit['private_and_generated_included']
assert set(audit['new_modules']) == set(modules)
assert sum(audit['new_modules'].values()) == audit['requested_module_declarations']
assert sum(audit['axiom_sets'].values()) == audit['targets']
for names in audit['axiom_sets']:
    assert names == 'none' or set(names.split(' + ')) <= {'propext','Quot.sound','Classical.choice'}
for part in audit['source_input_parts']:
    for name, expected in load(part['file']).items(): assert digest(ROOT/name) == expected
assert digest(HERE/'audit.py') == audit['audit_script']
assert digest(HERE/'axioms.lean') == audit['audit_template']
for key in ['module_parts','requested_module_parts','source_input_parts']:
    for part in audit[key]:
        assert digest(HERE/part['file']) == {k:part[k] for k in ['bytes','sha256']}
for part in audit['requested_module_parts']:
    for row in load(part['file']):
        names = []
        for piece in row['parts']:
            assert digest(HERE/piece['file']) == {k:piece[k] for k in ['bytes','sha256']}
            names += load(piece['file'])
        assert len(names) == len(set(names)) == row['count']

source_decls = {}
for module in modules:
    text = (ROOT/'formal/Benitoite/Release/Refinement'/(module+'.lean')).read_text()
    assert not re.search(r'\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval', text)
    assert not re.search(r'\b(?:L\d{2}(?:\.\d+)?|B\d{2}(?:-\d+)?|O\d{3}|TODO-\d+|RV-\w+)\b', text)
    matches = list(re.finditer(r'^(private )?(def|theorem|inductive|structure) ([\w.]+)',text,re.M))
    source_decls[module] = {'public':[m[3] for m in matches if not m[1]],
                            'private':[m[3] for m in matches if m[1]],
                            'anonymous_examples':len(re.findall(r'^example\b',text,re.M))}
assert source_decls == load('source-declarations.json')
flow = (ROOT/'formal/Benitoite/Release/Refinement/IntervalFlowLeaves.lean').read_text()
blocks = re.findall(r'^theorem block_(\w+)\b',flow,re.M)
expected_blocks = ['empty','builderBind','last','lastBind','lastDiscard','lastPat','bind','bindAbrupt',
                   'discard','discardAbrupt','seq','seqAbrupt','bindPat','bindPatAbrupt']
assert blocks == expected_blocks
for family in ['arms','width_arms','result_arms']:
    assert re.findall(r'^theorem '+family+r'_(\w+)\b',flow,re.M) == ['nil','skip','body','guardTrue','guardFalse','guardAbrupt']
core = (ROOT/'docs/design/01-spec/01-12-core-calculus.md').read_text()
assert flow[flow.index('def joinV'):flow.index('\nprivate theorem joinV_mem')] in core
first = (ROOT/'formal/Benitoite/Release/Refinement/FirstFailure.lean').read_text()
assert first[first.index('def BeforeError'):first.index('\nnoncomputable section')] in core
for m in modules:
    assert m in core and m in (ROOT/'docs/design/07-quality/07-04-formal-semantics.md').read_text()

obligations = (HERE/'obligations.md').read_text()
assert len(re.findall(r'^\| O\d{3} \|',obligations,re.M)) == 64
for o in ['O038','O058','O062','O090','O091','O124','O137','O169','O016','O027','O084','O118']:
    assert re.search(r'^\| '+o+r' \| F2',obligations,re.M)
checks = load('checks.json')
work = [r for r in checks if r['label'] == 'work']
assert len(work) == 1 and work[0]['exit'] == 0
assert work[0]['command'] == ['scripts/check.sh','--level','work','--base',BASE]
dry = [r for r in checks if r['label'] == 'dry-run']
assert len(dry) == 1 and dry[0]['exit'] == 0
assert dry[0]['command'] == work[0]['command']+['--dry-run']
restart_work = [r for r in checks if r['label'] == 'work-r1']
assert len(restart_work) == 1 and restart_work[0]['exit'] == 0
assert restart_work[0]['command'] == work[0]['command']
restart_dry = [r for r in checks if r['label'] == 'dry-run-r1']
assert len(restart_dry) == 1 and restart_dry[0]['exit'] == 0
assert restart_dry[0]['command'] == restart_work[0]['command']+['--dry-run']
restart2_work = [r for r in checks if r['label'] == 'work-r2']
assert len(restart2_work) == 1 and restart2_work[0]['exit'] == 0
assert restart2_work[0]['command'] == work[0]['command']
restart2_dry = [r for r in checks if r['label'] == 'dry-run-r2']
assert len(restart2_dry) == 1 and restart2_dry[0]['exit'] == 0
assert restart2_dry[0]['command'] == restart2_work[0]['command']+['--dry-run']
restart2_build = [r for r in checks if r['label'] == 'build-final-r2']
assert len(restart2_build) == 1 and restart2_build[0]['exit'] == 0
assert restart2_build[0]['command'] == ['lake','build']
assert audit['start_utc'] > restart2_build[0]['end_utc']
assert any(r['label']=='build-final-r1' and r['exit']==0 and r['command']==['lake','build'] for r in checks)
assert any(r['label']=='build-final' and r['exit']==0 and r['command']==['lake','build'] for r in checks)
for r in checks:
    if r['command'][:3] == ['lake','env','lean']: assert r['command'][3:5] == ['-M','12288']
    assert '--only' not in r['command']

for f in HERE.iterdir():
    if f.is_file():
        assert f.stat().st_size <= 100000, f.name
        text = f.read_text()
        assert (chr(47)+'Users'+chr(47)) not in text, f.name
        assert not re.search(r'\]\([^)]*docs/todo',text)
        if f.suffix == '.md':
            for link in re.findall(r'\]\(([^)#]+)(?:#[^)]*)?\)',text):
                if not re.match(r'\w+://',link): assert (f.parent/link).exists(), (f.name,link)

inputs = {name:digest(ROOT/name) for name in sorted(allowed|new_files)}
write('inputs-final.json',inputs)
write('verification.json',{'checked_utc':datetime.now(timezone.utc).isoformat(),'base':BASE,
    'new_modules':modules,'existing_formal_files_unchanged':len([p for p in start if p.startswith('formal/')])-1,
    'import_closure_modules':len(seen),'block_readers':len(blocks),'arm_readers':18,
    'audit_targets':audit['targets'],'new_declarations':audit['requested_module_declarations'],
    'axioms_allowed_only':True,'obligations':64,'work_runs':1,'restart_work_runs':len(restart_work),'restart2_work_runs':len(restart2_work),'expression_readers_added':12,'all_records_below_100000_bytes':True,
    'record_bytes':sum(f.stat().st_size for f in HERE.iterdir() if f.is_file())})
print(json.dumps(load('verification.json'),ensure_ascii=False))
