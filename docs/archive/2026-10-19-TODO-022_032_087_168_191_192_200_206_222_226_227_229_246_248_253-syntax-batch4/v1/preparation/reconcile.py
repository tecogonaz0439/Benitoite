# coding: utf-8
import collections,json,hashlib,runpy
from pathlib import Path
ROOT=Path.cwd();P=Path('crates/benitoite/tests/desugar_export');D=Path('docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/v1');out=Path('target/formal-v1/manifest')
read=lambda p:json.loads(p.read_text());dump=lambda p,v:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
m=read(P/'exchange-manifest.json');old=json.loads(json.dumps(m));corpus=read(out/'named-programs-corpus.json');cov=read(out/'named-programs-coverage.json');sur=read(out/'surface-report.json');key=lambda v:(v['group'],v['name']);coverage={key(i):i for i in cov['inputs']};oldprograms={key(i):i for i in m['programs']}
assert corpus['version']==13 and cov['version']==5
assert sur['counts']['mismatched']==sur['counts']['preparationFailure']==0 and sur['q11Agrees']
nonmatched=sorted([o for o in sur['outcomes'] if o['category']!='matched'],key=lambda o:json.dumps(o,sort_keys=True))
def classification(o):return (o['group'],o['input'],o['category'],o['kind'],tuple(o.get('unconvertiblePrims',[])),(o.get('error') or {}).get('reason'))
assert collections.Counter(map(classification,nonmatched))==collections.Counter(map(classification,m['programReports']['surfaceOutcomes'])),'classification boundary changed'
programs=[];changes=[];groups=collections.defaultdict(collections.Counter);defs=collections.defaultdict(collections.Counter);totals=collections.Counter()
for i in corpus['inputs']:
 scopes=collections.Counter(next(iter(d['scope'])) for d in i['definitions']);surfaces=[d['scope']['inScope']['surface'] for d in i['definitions'] if 'inScope' in d['scope']];impls={s['implementation'] for s in surfaces if s['implementation'] is not None};n=sum(s['implementation'] is None for s in surfaces)+len(impls)
 c=coverage.get(key(i));c=None if c is None else {k:len(c[k]) for k in ['matches','bindings']}
 entry={'group':i['group'],'name':i['name'],'excluded':i['excluded'],'definitions':len(i['definitions']),'scopes':dict(scopes),'coverage':c,'implementations':len(impls),'surfaceChecks':n}
 prior=oldprograms.get(key(i))
 if prior and 'singleSurfaceFailure' in prior:entry['singleSurfaceFailure']=prior['singleSurfaceFailure']
 programs.append(entry)
 if entry!=prior:changes.append({'name':i['name'],'before':prior,'after':entry})
 category='excluded' if i['excluded'] else ('outside' if scopes.get('inScope',0)==0 else 'matched');groups[i['group']][category]+=1
 for k,v in scopes.items():defs[i['group']]['outside' if k=='outOfScope' else 'matched']+=v
 totals.update(definitions=len(i['definitions']),surfaceChecks=n,coverageEntries=sum(c.values()) if c else 0)
# All successful scopes are inScope or ordinary generated accessors; no new outside bucket.
assert all(k in ('inScope','accessor') for i in programs for k in i['scopes'])
m['namedVersions']={'corpus':13,'table':5,'coverage':5};m['programs']=programs
reports=m['programReports'];reports.update(totals);reports['surfaceCounts']=sur['counts'];reports['surfaceOutcomes']=nonmatched
for group,destination in [('golden','desugarDefinitions'),('random','randomDesugarDefinitions')]:reports[destination]={k:defs[group][k] for k in ['outside','mismatched','matched','excluded']}
reports['desugarPrograms']={g:{k:groups[g][k] for k in ['matched','excluded','outside','mismatched']} for g in ['golden','random']}
reports['coverage']={**reports['coverage'],'matched':totals['coverageEntries']}
# Named independent inputs are the normal work exports. Keep all old named counts strict.
named=[]
for entry in m['named']:
 stem=entry['stem'];path=max(Path('target',stem).glob('export-*/'+stem+'-corpus.json'),key=lambda p:p.stat().st_mtime);data=read(path);assert data['version']==13
 assert len(data['inputs'])==1;item=data['inputs'][0];assert len(item['definitions'])==entry['definitions'];scopes=collections.Counter(next(iter(d['scope'])) for d in item['definitions']);assert dict(scopes)==entry.get('scopes',{'inScope':entry['definitions']})
 for suffix in ['builtins','stdlib']:
  assert read(path.with_name(stem+'-'+suffix+'.json'))['version']==5
 if entry['coverage'] is not None:
  c=read(path.with_name(stem+'-coverage.json'));assert c['version']==5;assert {k:len(c['inputs'][0][k]) for k in ['matches','bindings']}==entry['coverage']
 named.append({'stem':stem,'definitions':entry['definitions'],'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
reader=runpy.run_path(str(P/'check_named.py'));routing=reader['routing_entries'](out)
# Identifiers must cover exactly the current golden discovery plus the original 1000 generated inputs.
assert {i['name'] for i in routing if i['group']=='golden'}==reader['discover_golden']()
assert {i['name'] for i in routing if i['group']=='random'}=={f'random-{n}.bnt' for n in range(1000)}
assert len(routing)==len(programs)==1789
# All prior input identifiers remain; changes/new entries are retained for human review.
assert set(oldprograms)<=set(map(key,programs))
summary={'inputs':len(programs),'golden_inputs':len(programs)-1000,'programReports':{k:v for k,v in reports.items() if k!='surfaceOutcomes'},'changed_programs':changes,'nonmatched_categories_preserved':True,'surface_report_sha256':hashlib.sha256((out/'surface-report.json').read_bytes()).hexdigest(),'named':named}
dump(D/'manifest-audit.json',summary);dump(P/'exchange-manifest.json',m);dump(P/'routing-manifest.json',routing)
print(json.dumps({k:v for k,v in summary.items() if k not in ['changed_programs','named']},indent=2));print('changed input count',len(changes));print('new input names',[c['name'] for c in changes if c['before'] is None]);print('changed existing names',[c['name'] for c in changes if c['before'] is not None])
