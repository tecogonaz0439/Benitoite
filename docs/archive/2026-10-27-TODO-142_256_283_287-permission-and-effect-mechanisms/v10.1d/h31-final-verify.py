"""V10.1d: V10.1b で実行前に固定した H31 の期待値を、版上げ後の書き出しと比較結果へ照合する（verify-local.py の H31 の部分を出力先だけ替えて写した）。"""
from pathlib import Path
import hashlib
import json
import sys
ROOT=Path(sys.argv[1]).resolve()
V=ROOT/'docs/2026-10-27-TODO-142_256_283_287-permission-and-effect-mechanisms/v10.1b'
OUT=ROOT/'target/desugar-diff/v10.1d'
def read(p):return json.loads(p.read_text())
def walk(value):
 yield value
 if isinstance(value,dict):
  for k,v in value.items():
   if k!='candidates': yield from walk(v)
 elif isinstance(value,list):
  for v in value:yield from walk(v)
for label in ['h31']:
 frozen=read(V/(label+'-freeze.json'))['files']
 if isinstance(frozen,dict):frozen=[dict(path=str((V/p).relative_to(ROOT)),sha256=h) for p,h in frozen.items()]
 for row in frozen:assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
j2=None
summary=read(OUT/'range-source-comparison/summary.json');h31=[]
for c in read(V/'h31-expectations.json')['cases']:
 item=read(OUT/'range-sources'/c['name']/'named-programs-corpus.json')['inputs'][0]
 expected=c['h31'];sig=expected['signature'];ix=sig['range']
 ops=[op for op in item['ops'] if op['header']['names']==sig['names']]
 assert len(ops)==1
 op=ops[0];assert op['header']['params'][sig['parameterIndex']]['opaque']['ix']['fixed']==ix
 assert all(a['name']['ix']['fixed']=='top' for a in op['header']['eff'])
 definitions=item['definitions'];assert len(definitions)==c['definitions']
 assert [d['name'].split(' (')[0] for d in definitions]==expected['definitionNames']
 for d in definitions:
  for rep in ['surface','core']:
   form=d['scope']['inScope'][rep]
   header=form['header'];assert header['params'][0]['opaque']['ix']['fixed']==ix
   if expected['prim']:
    assert header['eff']==[{'name':{'value':'IO.File.Write','ix':{'fixed':ix}}}]
   else:assert header['eff']==op['header']['eff']
   tag='primName' if rep=='surface' else 'prim'
   calls=[v[tag] for v in walk(form['body']) if isinstance(v,dict) and tag in v and v[tag]['name']==({'File.writeTextIn':'Benitoite.IO.File.writeTextIn'}.get(expected['prim']))]
   assert len(calls)==expected['primOccurrencesPerRepresentation']
   for call in calls:assert call['ranges']==[ix]
  success=next(r for r in summary['successes'] if r['name']==c['name'])
  assert success['allDefinitionsChecked']==expected['allDefinitionsChecked']
  assert success['nonTopRanges']==c['nonTopRanges']
 h31.append(dict(name=c['name'],operationSignatureIndex=ix,definitions=c['definitions'],nonTopRanges=c['nonTopRanges'],effects=expected['effects'],prim=expected['prim'],allDefinitionsChecked=True,expectationMatched=True))
result=dict(j2=j2,h31=h31,groups=summary['groups'],definitions=summary['definitions'],nonTopRanges=sum(summary['nonTopRanges'].values()),topCompatibility=summary['topCompatibility'],rejections=summary['rejections'],excluded=summary['excluded'],reportSubset=summary['reportSubset'],obligation35='版上げ後の書き出しと範囲の実ソースの比較で、固定した期待値に一致した')
Path(sys.argv[2]).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
