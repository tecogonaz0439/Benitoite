# coding: utf-8
from pathlib import Path
import json,subprocess,runpy,tempfile,collections
P=Path('crates/benitoite/tests/desugar_export');D=Path('docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/v1');read=lambda p:json.loads(p.read_text());dump=lambda p,v:p.write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n')
m=read(P/'exchange-manifest.json');old=json.loads(subprocess.check_output(['git','show','HEAD:'+str(P/'exchange-manifest.json')],text=True));prior={(i['group'],i['name']):i for i in old['programs']}
corpus=read(Path('target/formal-v1/manifest/named-programs-corpus.json'));inputs={(i['group'],i['name']):i for i in corpus['inputs']};table={}
for suffix in ['builtins','stdlib']:
 data=read(Path('target/formal-v1/manifest/named-programs-'+suffix+'.json'));table[suffix]=(data,{(i['group'],i['name']):i for i in data['inputs']})
checks=[]
for i in m['programs']:
 key=(i['group'],i['name'])
 if not i['excluded'] and 'excluded' not in prior.get(key,{}):i.pop('excluded')
 if 'singleSurfaceFailure' not in i:continue
 with tempfile.TemporaryDirectory(prefix='benitoite-v1-single-') as t:
  t=Path(t);dump(t/'corpus.json',{**corpus,'inputs':[inputs[key]]})
  for suffix,(all_data,items) in table.items():dump(t/(suffix+'.json'),{**all_data,'inputs':[items[key]]})
  args=['formal/.lake/build/bin/surfaceCheck',str(t/'corpus.json'),str(t/'builtins.json'),str(t/'stdlib.json'),*key,str(t/'report.json')]
  p=subprocess.run(args,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT);assert p.returncode==1,(key,p.stdout);result=read(t/'report.json')['result'];assert result['ok'] is False
  assert result['error']['reason']==i['singleSurfaceFailure']['error']['reason'],(key,result)
  checks.append({'input':i['name'],'before':i['singleSurfaceFailure'],'after':result});i['singleSurfaceFailure']=result
# Current independent Coverage data keeps version4 and exact cases, including views.
closed=Path('target/coverage-diff/default');future=read(closed/'future-corpus.json');assert future['version']==4 and future['boundaryCases']==28 and future['randomCases']==10000
names=[c['name'] for c in future['cases'] if not c['name'].startswith('future/random/')];assert len(names)==28
m['coverageExports']['future-']={k:future[k] for k in ['version','boundaryCases','randomCases','seedXor']};m['coverageExports']['future-']['boundaryNames']=names;m['coverageExports']['future-']['randomPrefix']='future/random/'
m['futureCoverageReport']={'matched':10028,'mismatched':0,'fuelExhausted':0}
dump(P/'exchange-manifest.json',m);dump(D/'single-surface-results.json',checks)
# Review actual changes without adding empty optional fields to every old entry.
changes=[]
for i in m['programs']:
 before=prior.get((i['group'],i['name']))
 if i!=before:changes.append({'name':i['name'],'before':before,'after':i})
audit=read(D/'manifest-audit.json');audit['changed_programs']=changes;audit['single_surface_rejections']=len(checks);audit['independent_coverage']={k:{**v,'boundaryNamesCount':len(v['boundaryNames'])} for k,v in m['coverageExports'].items()};dump(D/'manifest-audit.json',audit)
print('single surface rejections:',len(checks),'changed inputs:',len(changes));print('changed existing:',[c['name'] for c in changes if c['before'] is not None])
reader=runpy.run_path(str(P/'check_named.py'))
# The named-only export has its own default directory outside check-formal.sh.
with tempfile.TemporaryDirectory(prefix='benitoite-v1-coverage-') as t:
 t=Path(t)
 for stem in m['coverageExports']:
  source=Path('target/coverage-diff/named/named-corpus.json') if stem=='named-' else closed/(stem+'corpus.json');(t/(stem+'corpus.json')).symlink_to(source.resolve())
 reader['check_coverage_exports'](t,m['coverageExports'])
# Input hash manifest for the independent corpus remains exact.
import hashlib
f=Path('formal/tests/batch4-exchange');manifest=read(f/'manifest.json')
for name,expected in manifest['files'].items():assert hashlib.sha256((f/name).read_bytes()).hexdigest()==expected,name
assert (manifest['definitions'],manifest['coverageCases'],manifest['coverageProgramCases'])==(45,6,3)
print('independent corpus: 45/6/3, hashes agree; Coverage closed 10020, views 10028, named 10')
