#!/usr/bin/env python3
"""試作専用。time -l のログと、sandbox時のRSSの代替計測を残す。"""
import datetime, json, os, pathlib, resource, signal, subprocess, sys, time
base = pathlib.Path(__file__).resolve().parent
repo = base.parents[3]
if sys.argv[1] == '--lean-child':
    name = sys.argv[2]
    source = sys.argv[3] if len(sys.argv)>3 else 'Skeleton.lean'
    result = subprocess.run(['lake','env','lean','-M','12288',str(base/source)], cwd=repo/'formal')
    (base/'checks'/f'{name}.status').write_text(str(result.returncode))
    raise SystemExit(result.returncode)
name = sys.argv[1]
source = sys.argv[2] if len(sys.argv)>2 else 'Skeleton.lean'
start = datetime.datetime.now().astimezone().isoformat()
t0 = time.monotonic()
with (base/'checks'/f'{name}.log').open('w') as log:
    run = subprocess.Popen(['/usr/bin/time','-l',sys.executable,str(base/'check.py'),'--lean-child',name,source], cwd=repo/'formal', stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    timed_out = False
    try:
        run.wait(timeout=600)
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(run.pid, signal.SIGKILL)
        run.wait()

usage=resource.getrusage(resource.RUSAGE_CHILDREN)
record=dict(source=source, start=start, seconds=round(time.monotonic()-t0,3), exit=(int((base/'checks'/f'{name}.status').read_text()) if not timed_out else 'timeout'), timed_out=timed_out, time_exit=run.returncode, maxrss_bytes=usage.ru_maxrss, maxrss_source='getrusage(RUSAGE_CHILDREN), macOS bytes; time -l sysctl is denied in sandbox')
(base/'checks'/f'{name}.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(record,ensure_ascii=False))
