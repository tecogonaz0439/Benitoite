"""指定した作業末の検査を一度実行し、外側の時間と生の出力の識別を記録する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse,hashlib,json,subprocess,time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE='2a2453825e956404fbe82d0a586d8776f323150a'

def digest(p):
 d=p.read_bytes();return {'bytes':len(d),'sha256':hashlib.sha256(d).hexdigest()}

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--tmp',required=True,type=Path);args=ap.parse_args()
 args.tmp.mkdir(parents=True,exist_ok=True)
 rows=[]
 for label,extra in [('dry-run',['--dry-run']),('work',[])]:
  command=['scripts/check.sh','--level','work','--base',BASE]+extra
  raw=args.tmp/(label+'.log');start=datetime.now(timezone.utc).isoformat();timer=time.monotonic()
  with raw.open('wb') as stream:r=subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
  row={'check':label,'command':command,'exit':r.returncode,'start_utc':start,'end_utc':datetime.now(timezone.utc).isoformat(),'seconds':time.monotonic()-timer,'raw':digest(raw)}
  rows.append(row);(HERE/'checks.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
  print(json.dumps(row,ensure_ascii=False),flush=True)
  if r.returncode:raise SystemExit(r.returncode)
if __name__=='__main__':main()
