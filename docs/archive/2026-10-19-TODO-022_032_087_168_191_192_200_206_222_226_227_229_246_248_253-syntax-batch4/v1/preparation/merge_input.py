# coding: utf-8
from pathlib import Path
import json,hashlib
base=Path('target/desugar-diff/export-36976');extra=Path('target/formal-v1/hash-match');out=Path('target/formal-v1/manifest');out.mkdir(parents=True,exist_ok=True)
key=lambda v:(v['group'],v['name'])
corpus=json.loads((base/'named-programs-corpus.json').read_text());fresh=json.loads((extra/'named-programs-corpus.json').read_text());assert len(fresh['inputs'])==1
item=fresh['inputs'][0];assert key(item)==('golden','testdata/packages/hash-match');assert not item['excluded'];idx=next(i for i,v in enumerate(corpus['inputs']) if key(v)==key(item));old=corpus['inputs'][idx];assert old['excluded']==['Some(E0919)'],old['excluded'];corpus['inputs'][idx]=item
for name,counts in fresh['annotations'].items():
 if name not in corpus['annotations']:corpus['annotations'][name]=[0,0]
 corpus['annotations'][name]=[a+b for a,b in zip(corpus['annotations'][name],counts)]
paths={}
for suffix in ['corpus','builtins','stdlib','coverage']:
 name='named-programs-'+suffix+'.json'
 if suffix=='corpus':data=corpus
 else:
  data=json.loads((base/name).read_text());added=json.loads((extra/name).read_text());assert data['version']==added['version']==5
  entries={key(v):v for v in data['inputs']};assert key(item) not in entries;entries[key(item)]=added['inputs'][0]
  data['inputs']=[entries[key(v)] for v in corpus['inputs'] if not v['excluded']]
 path=out/name;path.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n');paths[name]=hashlib.sha256(path.read_bytes()).hexdigest()
D=Path('docs/2026-10-19-TODO-022_032_087_168_191_192_200_206_222_226_227_229_246_248_253-syntax-batch4/v1')
r={'base':str(base),'refreshed_source':'testdata/packages/hash-match','old_exclusion':old['excluded'],'new_definitions':len(item['definitions']),'output':str(out),'files':paths}
(D/'export-inputs.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
