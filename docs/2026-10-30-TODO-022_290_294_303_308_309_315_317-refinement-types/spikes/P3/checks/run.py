import subprocess, resource, time, json, pathlib, sys, os
root=pathlib.Path(__file__).resolve().parents[5]
p=root/'spikes/P3'
label=sys.argv[1]
source=p/'Syntax.lean'
marker=p/'checks'/f'{label}.lean-exit'
log=p/'checks'/f'{label}.log'
t0=time.monotonic()
cmd=['/usr/bin/time','-l','/bin/sh','-c','lake env lean -M 12288 "$1"; r=$?; echo "$r" > "$2"; exit "$r"','lean-check',str(source),str(marker)]
with log.open('w') as f:
 try:
  r=subprocess.run(cmd,cwd=root/'formal',stdout=f,stderr=subprocess.STDOUT,timeout=600)
  status=r.returncode
 except subprocess.TimeoutExpired:
  status='timeout600'
elapsed=time.monotonic()-t0
rss=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
record={'command':cmd,'cwd':str(root/'formal'),'time_exit':status,'lean_exit':marker.read_text().strip() if marker.exists() else None,'elapsed_s':elapsed,'ru_maxrss':rss,'unit':'bytes on macOS; resource RUSAGE_CHILDREN auxiliary measurement','time_l_rss_available':'maximum resident set size' in log.read_text()}
p.joinpath('checks',label+'.json').write_text(json.dumps(record,ensure_ascii=False,indent=2))
print(json.dumps(record,ensure_ascii=False))
print(log.read_text()[-15000:])
