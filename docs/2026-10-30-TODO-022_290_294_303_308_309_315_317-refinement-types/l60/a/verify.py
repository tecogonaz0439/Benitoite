"""停止時点の完了/未完・全件対応・保護対象・既定importを照合する。"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
from inventory import HERE, ROOT, FORMAL, digest, write, population
from ledger import lean_rows, normalized
from rust_inventory import registrations

ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--tmp',type=Path,required=True)
ap.add_argument('--resume1',action='store_true')
ap.add_argument('--resume2',action='store_true')
ap.add_argument('--resume3',action='store_true')
ap.add_argument('--resume4',action='store_true')
ap.add_argument('--resume5',action='store_true')
args=ap.parse_args()
if args.resume5:
    from verify_resume5 import verify
    verify(args.tmp)
    raise SystemExit(0)
if args.resume4:
    from verify_resume4 import verify
    verify(args.tmp)
    raise SystemExit(0)
if args.resume3:
    from verify_resume3 import verify
    verify(args.tmp)
    raise SystemExit(0)
if args.resume2:
    from verify_resume2 import verify
    verify(args.tmp)
    raise SystemExit(0)
if args.resume1:
    from verify_resume1 import verify
    verify(args.tmp)
    raise SystemExit(0)
initial=json.loads((args.tmp/'initial.json').read_text())
allowed={'formal/Benitoite.lean','docs/design/01-spec/01-12-core-calculus.md',
    'docs/design/07-quality/07-04-formal-semantics.md'}
changed={file for file,h in initial.items() if digest(ROOT/file)['sha256']!=h}
assert changed==allowed,sorted(changed)
imports=(ROOT/'formal/Benitoite.lean').read_text()
modules=json.loads((HERE/'changed-modules.json').read_text())
seen=set()
def visit(module):
    if module in seen:return
    file=ROOT/'formal'/(module.replace('.','/')+'.lean')
    if not file.exists():return
    seen.add(module)
    for m in re.findall(r'^import (\S+)',file.read_text(),re.M):visit(m)
visit('Benitoite')
assert set(modules)<=seen
formal_inputs=[]
for m in sorted(seen):
    file=ROOT/'formal'/(m.replace('.','/')+'.lean')
    formal_inputs.append({'module':m,'file':str(file.relative_to(ROOT)),**digest(file)})
from ledger import pages
formal_input_pages=pages('formal-inputs',formal_inputs)
new_sources={str(p.relative_to(ROOT)) for p in FORMAL.glob('*.lean') if str(p.relative_to(ROOT)) not in initial}
assert new_sources=={'formal/'+m.replace('.','/')+'.lean' for m in modules}
for source in new_sources:
    text=(ROOT/source).read_text()
    assert not re.search(r'\bsorry\b|^axiom |set_option max(?:Heartbeats|RecDepth)|#eval|L60|L70',text,re.M),source
    assert 'import '+source.removeprefix('formal/').removesuffix('.lean').replace('/','.') in imports

summary=json.loads((HERE/'ledger-summary.json').read_text())
def read_pages(key):
    out=[]
    for p in summary[key]:
        file=HERE/p['file'];assert digest(file)=={k:p[k] for k in ['bytes','sha256']}
        out+=json.loads(file.read_text())
    return out
evidence=read_pages('evidence_pages');ledger=read_pages('ledger_pages');rust=read_pages('rust_pages');conditions=read_pages('condition_pages')
assert len(evidence)==552 and len(rust)==523 and len(conditions)==75
assert summary['composition_complete'] is False
assert Counter(r['group'] for r in evidence)==Counter(r['group'] for r in lean_rows())
assert [r['name'] for r in rust]==[r['name'] for r in registrations()]
byid={r['id']:r for r in ledger}
source_byname={}
for r in lean_rows():source_byname.setdefault(r['lean_name'],set()).update(r['evidence'])
for r in evidence:
    target=byid[r['ledger']]
    assert target['classification']=='合成' and r['id'] in target['evidence_rows']
    assert set(r['evidence'])<=set(target['evidence'])
for r in rust:
    target=byid[r['ledger']]
    assert normalized(r['name'])==target['lean_name'] and r['id'] in target['rust_references']
    assert r['name'] in target['rust_names']
for r in ledger:
    if r['classification']=='仮定':
        assert not r['evidence'] and not r['evidence_rows']
        assert r['lean_name'] not in source_byname
        assert len(r['rust_names'])==1 and r['reason']
    else:assert r['evidence_rows']
assert len(json.loads((HERE/'first-sixteen.json').read_text()))==16
assert len(json.loads((HERE/'resources.json').read_text()))==5
assert len(json.loads((HERE/'branch-fields.json').read_text()))==76
audit=json.loads((HERE/'audit-summary.json').read_text())
assert audit['new_axioms']==audit['sorryAx']==0
assert set(modules)<=set(audit['modules'])
for key in ['declaration_pages','signature_pages']:
    for p in audit[key]:assert digest(HERE/p['file'])=={k:p[k] for k in ['bytes','sha256']}
assert audit['input']==digest(HERE/'axioms.lean')
for label in ['work-dry','work-final','audit-final','evidence-check','collision-check']:
    r=json.loads((HERE/(label+'.json')).read_text())
    assert r['exit']==0 and r['raw']==digest(args.tmp/(label+'.log'))
for r in json.loads((HERE/'source-inputs.json').read_text()):
    assert digest(ROOT/r['file'])=={k:r[k] for k in ['bytes','sha256']}
times=json.loads((HERE/'times.json').read_text())
assert set(times)=={'L60.01','L60.02','L60.03','L60.04'} and all('end' in v for v in times.values())
assert 'L60.05は開始していない' in (HERE/'stop.md').read_text()
files=[p for p in HERE.iterdir() if p.is_file()]
for file in files:
    assert file.stat().st_size<=100000,(file.name,file.stat().st_size)
    if file.suffix in ['.md','.lean','.json']:
        text=file.read_text()
        assert not re.search(r'/(?:Users|private/tmp|tmp)/|\]\([^)]*docs/todo',text),file.name
        if file.suffix=='.md':
            for link in re.findall(r'\]\(([^)]+)\)',text):
                if not link.startswith(('https:','http:','#')):
                    assert (file.parent/link.split('#')[0]).exists(),(file.name,link)
assert sum(f.stat().st_size for f in files)<4000000
out={'b_work':'80230d96305756057a63a07dc2b0d8aa1ebf3a75',
    'status':'停止時点の自己照合成功。群Aの完了ではない',
    'changed_existing':sorted(changed),'new_sources':sorted(new_sources),
    'default_closure':len(seen),'protected_initial_files':len(initial)-len(changed),
    'formal_input_pages':formal_input_pages,
    'initial_manifest':digest(args.tmp/'initial.json'),
    'evidence_rows':len(evidence),'ledger_rows':len(ledger),'rust_references':len(rust),'conditions':len(conditions),
    'audit_targets':audit['targets'],'new_declarations':audit['new_declarations'],
    'signature_rows':sum(len(json.loads((HERE/p['file']).read_text())) for p in audit['signature_pages']),
    'work_executions':1,'new_axioms':0,'sorryAx':0,'stopped_unit':'L60.04','unstarted_unit':'L60.05',
    'files':len(files),'record_bytes':sum(f.stat().st_size for f in files),
    'independent_review':'未実施・取りまとめの担当','acceptance':'未実施・設計者の担当'}
write(HERE/'verification.json',out)
print(json.dumps(out,ensure_ascii=False))
