from pathlib import Path
import collections, hashlib, json, subprocess
root=Path.cwd(); base='045b0a22887cceb1cd866d40d6bbe55d02ef5310'
out=root/'docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a16a'
ref=root/'crates/benitoite/testdata/interval-budget'
columns={
'body':'name kind cap operations saved peak next stop warnings independent unsupported'.split(),
'whole':'name kind cap operations saved peak bodies warnings phases discovered pending remaining stop modules'.split(),
'summary':'name kind cap inputDefinitions unsupportedBodies bodyBudgetExceeded wholeBudgetSkipped unidentifiedBodies phaseStops'.split()}
expected=json.loads((out.parent/'l20d/reference-impact.json').read_text())
results={}
for name, cols in columns.items():
 p=ref/(name+'.tsv'); oldbytes=subprocess.check_output(['git','show',f'{base}:{p.relative_to(root)}']);newbytes=p.read_bytes()
 oldrows=[line.split('\t') for line in oldbytes.decode().splitlines() if not line.startswith('#')]
 newrows=[line.split('\t') for line in newbytes.decode().splitlines() if not line.startswith('#')]
 assert all(len(row)==len(cols) for row in oldrows+newrows)
 old={tuple(row[:3]):row for row in oldrows};new={tuple(row[:3]):row for row in newrows}
 changed=collections.defaultdict(lambda:{'changed':0,'removed':0,'added':0,'columns':set()})
 for key in old.keys()|new.keys():
  if key not in old: changed[key[0]]['added']+=1
  elif key not in new: changed[key[0]]['removed']+=1
  elif old[key]!=new[key]:
   changed[key[0]]['changed']+=1
   changed[key[0]]['columns'].update(c for c,a,b in zip(cols,old[key],new[key]) if a!=b)
 shapes={}
 for shape,d in sorted(changed.items()):
  d['columns']=[c for c in cols if c in d['columns']]
  if name=='body':
   before=[[row for row in oldrows if row[0]==shape and row[1]==str(k)] for k in range(4)]
   after=[[row for row in newrows if row[0]==shape and row[1]==str(k)] for k in range(4)]
   d['old_success_caps']=[next(int(r[2]) for r in group if r[7]=='0') for group in before]
   d['new_success_caps']=[next(int(r[2]) for r in group if r[7]=='0') for group in after]
   d['old_complete']=before[0][-1][3:];d['new_complete']=after[0][-1][3:]
  shapes[shape]=d
 result={'old_rows':len(oldrows),'new_rows':len(newrows),'shapes':shapes}
 prior={k:v for k,v in expected[name].items() if k!='saved_sha256'}
 assert result==prior, name
 result.update(matches_l20d=True,old_sha256=hashlib.sha256(oldbytes).hexdigest(),new_sha256=hashlib.sha256(newbytes).hexdigest())
 results[name]=result
 print(name, len(oldrows),len(newrows),'shapes',len(shapes),'changed',sum(d['changed'] for d in shapes.values()),'added',sum(d['added'] for d in shapes.values()),'matches L20d')
(out/'reference-impact.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n')
