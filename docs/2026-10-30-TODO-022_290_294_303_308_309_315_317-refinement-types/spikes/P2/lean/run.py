import datetime,json,pathlib,subprocess,time,sys,resource,os,signal
root=pathlib.Path('<repo>')
out=root/'spikes/P2/logs'
start=time.monotonic(); stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
name=sys.argv[1] if len(sys.argv)>1 else 'P2.lean'
result=out/f'lean-{stamp}-status.json'
cmd=['/usr/bin/time','-l','python3',str(root/'spikes/P2/lean/lean-child.py'),name,str(result)]
with (out/f'lean-{stamp}.log').open('w') as f:
 p=subprocess.Popen(cmd,cwd=root/'formal',stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
 try:
  status=p.wait(timeout=600)
 except subprocess.TimeoutExpired:
  os.killpg(p.pid,signal.SIGKILL)
  p.wait()
  status='timeout-600s'
record={'time':stamp,'file':name,'command':cmd,'seconds':time.monotonic()-start,'time_wrapper_exit':status}
if result.exists():record.update(json.loads(result.read_text()))
with (out/'lean-runs.jsonl').open('a') as f:f.write(json.dumps(record)+'\n')
print(json.dumps(record)); print((out/f'lean-{stamp}.log').read_text())
