"""N28 の基準と固定 seed のソースから、N29 の厳密な対応表を導く。リポジトリの根で実行する。"""
from pathlib import Path
import json,collections,re,copy,sys
base=Path('docs/2026-10-14-TODO-247-lambda-and-named-arguments');out=base/'n29';directory=Path('target/desugar-diff/n29-final')
sys.path.insert(0,'crates/benitoite/tests/desugar_export');import check_named as check
read=lambda p:json.loads(p.read_text());write=lambda p,x:p.write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
m=read(base/'n28/exchange-manifest.json');previous=check.keyed(read(base/'n28/routing-manifest.json'));actual=check.routing_entries(directory);current=check.keyed(actual)
assert current.keys()==previous.keys()
corpus=read(directory/'named-programs-corpus.json');coverage=check.keyed(read(directory/'named-programs-coverage.json')['inputs'])
old_programs=check.keyed(m['programs']);programs=[];changes=[];random_checks=0;old_random_checks=0;random_definitions=0;implementations=0;random_coverage=collections.Counter()
for key,old in previous.items():
 new=current[key]
 if key[0]=='golden':assert old==new,key
 else:
  source=Path('target/n29/after/formal')/(key[1].removeprefix('random-'))
  before=Path('target/n29/before/formal')/source.name
  factories=len(re.findall(r'^function make',source.read_text(),re.M))
  assert new['version']==8 and old['version']==7 and not new['excluded']
  expected=copy.deepcopy(old);expected['version']=8;expected['scopes']['inScope']+=factories
  assert new==expected,(key,new,expected)
  changes.append({'group':key[0],'name':key[1],'before':old,'after':new,'added_factory_definitions':factories})
for item in corpus['inputs']:
 key=item['group'],item['name'];scopes=collections.Counter(next(iter(d['scope'])) for d in item['definitions'])
 surfaces=[d['scope']['inScope']['surface'] for d in item['definitions'] if 'inScope' in d['scope']]
 impl={s['implementation'] for s in surfaces if s['implementation'] is not None}
 checks=sum(s['implementation'] is None for s in surfaces)+len(impl)
 cov=coverage[key];cov_counts={k:len(cov[k]) for k in ('matches','bindings')}
 entry=dict(group=key[0],name=key[1],definitions=len(item['definitions']),scopes=dict(scopes),coverage=cov_counts,implementations=len(impl),surfaceChecks=checks)
 if key[0]=='golden':
  old=old_programs[key]
  for k,v in entry.items():assert old.get(k,0)==v,(key,k,old.get(k),v)
  programs.append(old)
 else:
  assert all(s in ('inScope','accessor') for s in scopes)
  seed=int(key[1].removeprefix('random-').removesuffix('.bnt'))
  old_source=Path(f'target/n29/before/formal/{seed}.bnt').read_text();new_source=Path(f'target/n29/after/formal/{seed}.bnt').read_text()
  factories=len(re.findall(r'^function make',new_source,re.M))
  assert len(impl)==len(re.findall(r'^implement(?:\[|\s)',old_source,re.M))
  old_random_checks+=checks-factories;random_checks+=checks;random_definitions+=len(item['definitions']);implementations+=len(impl);random_coverage.update(cov_counts);programs.append(entry)
assert len(changes)==1000
m['programs']=programs;m['routingManifest']='routing-manifest.json';m['legacy']['random']=0
lr=m['legacyReports'];lr['desugar']['random']={kind:{k:0 for k in counts} for kind,counts in lr['desugar']['random'].items()};lr['builtin']['checkedInputs']-=1000
pc=lr['programCoverage'];pc['inputs']-=1000
for kind in ('matches','bindings'):
 n=random_coverage[kind]
 for k in ('cases','matched'):pc[kind][k]-=n
for k in ('cases','matched'):pc[k]-=sum(random_coverage.values())
s=lr['surface']
for k in ('inputs','fullyCheckedInputs'):s[k]-=1000
s['implementations']-=implementations;s['counts']['matched']-=old_random_checks
pr=m['programReports'];pr['randomDesugarDefinitions']={'outside':0,'mismatched':0,'matched':random_definitions,'excluded':0};pr['surfaceCounts']['matched']+=random_checks;pr['coverage']['matched']+=sum(random_coverage.values());pr['definitions']+=random_definitions;pr['surfaceChecks']+=random_checks;pr['coverageEntries']+=sum(random_coverage.values())
write(out/'routing-manifest.json',actual);write(out/'routing-changes.json',changes);write(out/'exchange-manifest.json',m)
summary=dict(inputs=len(actual),named_inputs=len(programs),random_definitions=random_definitions,old_random_surface_checks=old_random_checks,new_random_surface_checks=random_checks,random_implementations=implementations,random_coverage=dict(random_coverage),golden_routing_unchanged=True,random_scope_delta_equals_factory_definitions=True,random_coverage_unchanged=True)
write(out/'exchange-derivation.json',summary);print(summary)
