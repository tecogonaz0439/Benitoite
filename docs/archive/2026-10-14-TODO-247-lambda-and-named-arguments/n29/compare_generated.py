"""固定 seed の構成と、変更前後の実行の観測結果を比べる。before/after は snapshot-driver.rs.txt で作る。"""
from pathlib import Path
import subprocess,json,hashlib
base=Path('target/n29');out=Path('docs/2026-10-14-TODO-247-lambda-and-named-arguments/n29')
rows=[]
for kind,count in [('regular',300),('formal',1000)]:
 for seed in range(count):
  before=base/'before'/kind/f'{seed}.bnt';after=base/'after'/kind/f'{seed}.bnt'
  assert before.with_suffix('.coverage').read_bytes()==after.with_suffix('.coverage').read_bytes(),(kind,seed)
  row=dict(kind=kind,seed=seed,before_sha256=hashlib.sha256(before.read_bytes()).hexdigest(),after_sha256=hashlib.sha256(after.read_bytes()).hexdigest(),coverage_unchanged=True)
  if kind=='regular':
   results=[]
   for source in (before,after):
    r=subprocess.run(['target/debug/benitoite','run','--diagnostics=json',str(source)],capture_output=True,timeout=15)
    diagnostics=[json.loads(x) for x in r.stderr.splitlines() if x.startswith(b'{')]
    results.append(dict(exit=r.returncode,stdout=r.stdout.decode(),diagnostics=[{k:d.get(k) for k in ('kind','severity','code','message')} for d in diagnostics]))
   row['before_result'],row['after_result']=results
   row['results_equal']=results[0]==results[1]
   if not row['results_equal']:print('MISMATCH',kind,seed,results,flush=True)
  rows.append(row)
(out/'generated-snapshot-review.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print('seeds',len(rows),'coverage equal',sum(r['coverage_unchanged'] for r in rows),'runtime matched',sum(r.get('results_equal',False) for r in rows),flush=True)
assert all(r.get('results_equal',True) for r in rows)
