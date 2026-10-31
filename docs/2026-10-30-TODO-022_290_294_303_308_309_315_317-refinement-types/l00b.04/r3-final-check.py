"""三値評価の検査後の変更と、記録のハッシュを照合する。Leanを再実行しない。"""
from pathlib import Path
import datetime
import hashlib
import json
import re
import tempfile

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
RAW=Path(tempfile.gettempdir())/json.loads((HERE/'record-location.json').read_text())['tmp_name']
sha=lambda data:hashlib.sha256(data).hexdigest()
baseline=json.loads((RAW/'r3-baseline.json').read_text())
fixed=json.loads((HERE/'r3-inputs.json').read_text())
for n,h in fixed.items():assert sha((ROOT/n).read_bytes())==h,n
for n,h in baseline['protected'].items():assert sha((ROOT/n).read_bytes())==h,n
records=json.loads((HERE/'r3-commands.json').read_text())
assert len(records)==6
for r in records:
    assert r['exit']==0
    o=r['output'];p=(RAW if o['storage']=='<tmp>' else HERE)/o['name']
    assert p.stat().st_size==o['bytes'] and sha(p.read_bytes())==o['sha256']
    if r.get('input_sha256'):assert sha((ROOT/'formal'/r['command'][-1]).read_bytes())==r['input_sha256']
assert {n for n,h in fixed.items() if baseline['formal'].get(n)!=h}=={'formal/Benitoite/Release/Refinement/ClosedEvaluation.lean'}
summary=json.loads((HERE/'r3-axioms-summary.json').read_text())
assert summary['rejected']==[] and set(summary['used'])<={'propext','Quot.sound','Classical.choice'}
for n in ['signatures.md','results.md']+[p.name for p in HERE.glob('r3-*') if p.suffix in {'.md','.py','.lean','.json','.log','.txt'}]:
    s=(HERE/n).read_text()
    assert ('/'+'Users/') not in s,n
    if n.endswith('.md'):
        for link in re.findall(r'\]\(([^)]+)\)',s):
            if not re.match(r'https?://',link):assert (HERE/link.split('#')[0]).exists(),(n,link)
for p in HERE.glob('r3-*'):assert p.stat().st_size<=100_000,p.name
manifest=json.loads((HERE/'r3-new-files.json').read_text())
assert set(manifest['files'])=={str(p.relative_to(ROOT)) for p in HERE.glob('r3-*') if p.is_file()}
for name,size,digest in re.findall(r'\| `([^`]+)` \| (\d+) \| `([0-9a-f]+)` \|',(HERE/'r3-large-records.md').read_text()):
    b=(RAW/name).read_bytes();assert len(b)==int(size) and sha(b)==digest,name
out={'formal_inputs':len(fixed),'protected_inputs':len(baseline['protected']),'protected_changes':[],
 'verified_commands':len(records),'new_files':len(manifest['files']),'used_axioms':summary['used'],
 'git':'未実行','work':'未実行','finished_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
(HERE/'r3-final-check.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(out,ensure_ascii=False))
