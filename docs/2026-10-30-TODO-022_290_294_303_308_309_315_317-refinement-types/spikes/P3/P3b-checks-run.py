import datetime, hashlib, json, os, pathlib, resource, signal, subprocess, sys, time
root=pathlib.Path(__file__).resolve().parents[4]
p=root/'spikes/P3'
label=sys.argv[1]
source=p/(sys.argv[2] if len(sys.argv)>2 else 'P3b-Derivations.lean')
marker=p/f'P3b-checks-{label}.lean-exit'
log=p/f'P3b-checks-{label}.log'
started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat()
source_sha256=hashlib.sha256(source.read_bytes()).hexdigest()
start=time.monotonic()
cmd=['/usr/bin/time','-l','/bin/sh','-c','lake env lean -M 12288 "$1"; r=$?; echo "$r" > "$2"; exit "$r"','lean-check',str(source),str(marker)]
with log.open('w') as f:
 try:
  child=subprocess.Popen(cmd,cwd=root/'formal',stdout=f,stderr=subprocess.STDOUT,start_new_session=True)
  status=child.wait(timeout=600)
 except subprocess.TimeoutExpired:
  os.killpg(child.pid, signal.SIGTERM)
  try: child.wait(timeout=10)
  except subprocess.TimeoutExpired:
   os.killpg(child.pid, signal.SIGKILL)
   child.wait()
  status='timeout600'
rec={'started_utc':started_utc,'source_sha256':source_sha256,'source_changed_during_check':source_sha256 != hashlib.sha256(source.read_bytes()).hexdigest(),'command':cmd,'cwd':str(root/'formal'),'time_exit':status,'lean_exit':marker.read_text().strip() if marker.exists() else None,'elapsed_s':time.monotonic()-start,'auxiliary_ru_maxrss_bytes':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'time_l_rss_available':'maximum resident set size' in log.read_text()}
p.joinpath(f'P3b-checks-{label}.json').write_text(json.dumps(rec,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(rec,ensure_ascii=False))
print(log.read_text()[-16000:])
