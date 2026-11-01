from pathlib import Path
import sys,subprocess,time,json,hashlib,datetime,tempfile
root=Path.cwd();out=root/'docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/a3b'
label=sys.argv[1];cmd=sys.argv[2:];start=time.monotonic()
r=subprocess.run(cmd,cwd=root/'formal',stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
s=r.stdout.replace(str(root),'<repo>').replace(str(Path.home()),'<home>')
elapsed=time.monotonic()-start
log=out/(label+'.log')
if len(s.encode())>100000:
 log=(Path(tempfile.gettempdir())/'benitoite-l20-a3b')/(label+'.log')
 with (out/'large-records.md').open('a') as f:f.write(f'\n- `<tmp>/{log.name}`: {len(s.encode())} bytes; SHA-256 `{hashlib.sha256(s.encode()).hexdigest()}`.\n')
log.parent.mkdir(parents=True,exist_ok=True)
log.write_text(s)
(out/(label+'.json')).write_text(json.dumps({'command':cmd,'exit':r.returncode,'elapsed_seconds':elapsed,'log':log.name,'sha256':hashlib.sha256(s.encode()).hexdigest(),'utc':datetime.datetime.now(datetime.timezone.utc).isoformat()},indent=2)+'\n')
print('\n'.join(x for x in s.splitlines() if x.startswith('error:') or 'error:' in x or x.startswith('✔') or x.startswith('Build completed'))[-5000:]);print(s[-1500:] if r.returncode else '');print('exit',r.returncode,'seconds',round(elapsed,2))
sys.exit(r.returncode)
