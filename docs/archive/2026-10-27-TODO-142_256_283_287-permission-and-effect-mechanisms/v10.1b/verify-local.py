"""実行前に固定した期待値を、既存交換の書き出し・比較結果へ照合する。"""
from pathlib import Path
import hashlib
import json
V=Path(__file__).resolve().parent
ROOT=V.parents[2]
OUT=ROOT/'target/v10.1b'
def read(p):return json.loads(p.read_text())
def walk(value):
 yield value
 if isinstance(value,dict):
  for k,v in value.items():
   if k!='candidates': yield from walk(v)
 elif isinstance(value,list):
  for v in value:yield from walk(v)
for label in ['j2','h31']:
 frozen=read(V/(label+'-freeze.json'))['files']
 if isinstance(frozen,dict):frozen=[dict(path=str((V/p).relative_to(ROOT)),sha256=h) for p,h in frozen.items()]
 for row in frozen:assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest()==row['sha256'],row['path']
j2=[]
for expected in read(V/'j2-expected.json')['cases']:
 label=Path(expected['file']).stem
 metadata=read(V/(label+'.json'))
 report=json.JSONDecoder().raw_decode((V/(label+'.log')).read_text())[0]
 assert metadata['exit']==expected['exit']
 assert [d['code'] for d in report['diagnostics']]==expected['codes']
 if 'primary' in expected:
  primary=report['diagnostics'][0]['primary'];e=expected['primary']
  assert primary['start']==dict(column=e['column'],line=e['line'],offset=e['start'])
  assert primary['end']['offset']==e['end']
  assert expected['remaining'] in report['diagnostics'][0]['message']
 j2.append(dict(file=expected['file'],exit=metadata['exit'],codes=expected['codes'],expectationMatched=True))
summary=read(OUT/'compare/summary.json');h31=[]
for c in read(V/'h31-expectations.json')['cases']:
 item=read(OUT/'export/range-sources'/c['name']/'named-programs-corpus.json')['inputs'][0]
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
result=dict(j2=j2,h31=h31,groups=summary['groups'],definitions=summary['definitions'],nonTopRanges=sum(summary['nonTopRanges'].values()),topCompatibility=summary['topCompatibility'],rejections=summary['rejections'],excluded=summary['excluded'],reportSubset=summary['reportSubset'],obligation35='局所比較のみ成功。最終確認はV10.1dであり未完を保つ')
(V/'local-verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(result,ensure_ascii=False))
