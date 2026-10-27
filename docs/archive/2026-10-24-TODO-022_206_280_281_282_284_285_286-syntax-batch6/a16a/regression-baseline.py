from pathlib import Path
import hashlib, json, subprocess
root=Path.cwd();base='045b0a22887cceb1cd866d40d6bbe55d02ef5310'
out=root/'docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/a16a'
paths=[root/'crates/benitoite/src/typeck/interval'/name for name in ['discovery.rs','environment.rs','flow.rs','flow/matching.rs']]
saved={p:p.read_bytes() for p in paths};result=None
try:
 for p in paths: p.write_bytes(subprocess.check_output(['git','show',f'{base}:{p.relative_to(root)}']))
 result=subprocess.run(['cargo','test','-p','benitoite','--lib','range_scans_charge','--','--nocapture'])
finally:
 for p,data in saved.items(): p.write_bytes(data)
 check={str(p.relative_to(root)):{'restored':p.read_bytes()==data,'sha256':hashlib.sha256(data).hexdigest()} for p,data in saved.items()}
 (out/'baseline-restore.json').write_text(json.dumps(check,ensure_ascii=False,indent=2)+'\n')
 assert all(v['restored'] for v in check.values())
if result is None or result.returncode==0: raise RuntimeError('開始版で退行テストが失敗しなかった')
print('開始版の失敗を確認し、今回の実装を復元した。Cargo exit=',result.returncode)
