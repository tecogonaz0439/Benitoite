import subprocess, time, json, sys, pathlib, datetime, os, signal
root=pathlib.Path(__file__).resolve().parent
name=sys.argv[1]; timeout=int(sys.argv[2]); cmd=sys.argv[3:]
start=time.monotonic(); stamp=datetime.datetime.now(datetime.timezone.utc).isoformat()
log=root/'checks'/f'{name}.log'
with log.open('w') as f:
    exitfile=root/'checks'/f'{name}.command-exit'
    exitfile.unlink(missing_ok=True)
    p=subprocess.Popen(['/usr/bin/time','-l','sh','-c','"$@"; result=$?; printf "%s\\n" "$result" > "$P4_EXITFILE"; exit "$result"','p4-check',*cmd],cwd=root.parents[3]/'formal',stdout=f,stderr=subprocess.STDOUT,start_new_session=True,env={**os.environ,'P4_EXITFILE':str(exitfile),'LEAN_PATH':str(root)+os.pathsep+os.environ.get('LEAN_PATH','')})
    timed=False
    try: code=p.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed=True; os.killpg(p.pid,signal.SIGTERM)
        try: code=p.wait(timeout=5)
        except subprocess.TimeoutExpired: os.killpg(p.pid,signal.SIGKILL); code=p.wait()
tool_code=code
actual=int(exitfile.read_text().strip()) if exitfile.exists() else None
record=dict(command_exit_code=actual,time_exit_code=tool_code,name=name,command=cmd,started=stamp,elapsed_seconds=time.monotonic()-start,exit_code=actual,timeout=timed,log=str(log.relative_to(root)))
import re
s=log.read_text(); m=re.search(r'(\d+)\s+maximum resident set size',s)
record['max_rss_bytes']=int(m[1]) if m else None
(root/'checks'/f'{name}.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record)); print(s[-6000:])
sys.exit(actual if actual is not None else (code if code>=0 else 1))
