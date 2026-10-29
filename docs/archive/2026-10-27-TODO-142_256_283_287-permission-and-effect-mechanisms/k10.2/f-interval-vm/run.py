import datetime, hashlib, json, os, resource, subprocess, sys, time
from pathlib import Path
root=Path.cwd()
base=Path(__file__).parent
rel=base.relative_to(root).as_posix() if base.is_absolute() else base.as_posix()
commands=[
 ['env',f'BENITOITE_DESUGAR_DIFF_DIR={rel}/identity','cargo','test','--test','desugar_export','export_interval_identity','--','--exact','--nocapture'],
 ['env',f'BENITOITE_DESUGAR_DIFF_DIR={rel}/vm','cargo','test','--test','desugar_export','interval::vm::export_interval_vm','--','--exact','--nocapture'],
 ['cargo','build','-p','benitoite','--bin','benitoite'],
 ['python3','-B','formal/tests/test_interval_exchange.py','--output',f'{rel}/interval-comparison','--source-dir',f'{rel}/identity','--rust-dir',f'{rel}/identity','--rust-dir',f'{rel}/vm/original','--rust-dir',f'{rel}/vm/instrumented','--rust-dir',f'{rel}/vm/range/original','--rust-dir',f'{rel}/vm/range/instrumented','--rust-dir',f'{rel}/vm/shifts/original','--rust-dir',f'{rel}/vm/shifts/instrumented','--vm-dir',f'{rel}/vm','--cli','target/debug/benitoite']]
i=int(sys.argv[1]); cmd=['/usr/bin/time','-p']+commands[i]
start=datetime.datetime.now(datetime.timezone.utc).isoformat(); tick=time.monotonic()
p=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
elapsed=time.monotonic()-tick
raw=p.stdout
for a,b in [(str(root),'<wt>'),(str(Path.home()),'<home>')]: raw=raw.replace(a,b)
label=f'{i+1:02d}'
(base/(label+'.log')).write_text(raw)
r={'command':cmd,'exit':p.returncode,'start_utc':start,'end_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'elapsed_seconds':elapsed,'max_rss_bytes':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'max_rss_note':'macOS getrusage(RUSAGE_CHILDREN), 子プロセス単体の最大値、同時使用の総和ではない'}
(base/(label+'.json')).write_text(json.dumps(r,ensure_ascii=False,indent=2)+'\n')
(base/(label+'.exit')).write_text(str(p.returncode)+'\n')
print(json.dumps(r,ensure_ascii=False)); print(raw[-4000:]); sys.exit(p.returncode)
