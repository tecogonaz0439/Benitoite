"""局所検査の対象と必要な import を、固定 Lean と同じメモリ制限で検査する。"""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
FORMAL=ROOT/'formal'
def digest(data): return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('module',nargs='+')
 ap.add_argument('--tmp',type=Path,required=True)
 args=ap.parse_args();args.tmp.mkdir(parents=True,exist_ok=True)
 seen=set()
 def run(module):
  if module in seen: return
  seen.add(module)
  src=FORMAL/(module.replace('.','/')+'.lean')
  if not src.exists(): return
  imports=re.findall(r'^import\s+([\w.]+)',src.read_text(),re.M)
  for dep in imports: run(dep)
  out=FORMAL/'.lake/build/lib/lean'/(module.replace('.','/')+'.olean')
  inputs=[src]+[FORMAL/'.lake/build/lib/lean'/(d.replace('.','/')+'.olean') for d in imports]
  newest=max(p.stat().st_mtime for p in inputs if p.exists())
  if out.exists() and out.stat().st_mtime>=newest: return
  out.parent.mkdir(parents=True,exist_ok=True)
  cmd=['lake','env','lean','-M','12288',str(src.relative_to(FORMAL)),'-o',str(out.relative_to(FORMAL))]
  begin=time.time();p=subprocess.run(cmd,cwd=FORMAL,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  elapsed=time.time()-begin
  log=args.tmp/(module+'.log');log.write_bytes(p.stdout)
  record={'command':cmd,'cwd':'formal/','start':begin,'seconds':elapsed,'exit':p.returncode,'output':digest(p.stdout),'source':digest(src.read_bytes())}
  records=args.tmp/'local-checks.jsonl'
  with records.open('a') as f:f.write(json.dumps(record)+'\n')
  print(json.dumps({'module':module,'exit':p.returncode,'seconds':round(elapsed,2)}),flush=True)
  if p.returncode:
   print(p.stdout.decode(errors='replace')[:18000],flush=True)
   raise SystemExit(p.returncode)
 for module in args.module:run(module)
if __name__=='__main__':main()
