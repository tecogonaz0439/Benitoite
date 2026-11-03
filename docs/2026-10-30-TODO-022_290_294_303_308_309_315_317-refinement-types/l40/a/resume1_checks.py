"""再開の署名検査、公理監査、指定したworkを順に実行して記録する。"""
from pathlib import Path
import argparse,datetime,hashlib,json,subprocess,time
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
BASE="2a2453825e956404fbe82d0a586d8776f323150a"

def digest(path):
 data=path.read_bytes();return {"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument("--tmp",type=Path,required=True);args=p.parse_args();args.tmp.mkdir(parents=True,exist_ok=True)
 tasks=[]
 for name in ["signature-check","signature-extra","safe-contracts"]:
  tasks.append((name,["lake","env","lean","-M","12288","../"+str((HERE/(name+".lean")).relative_to(ROOT))],ROOT/"formal"))
 tasks += [("audit",["python3",str((HERE/"audit.py").relative_to(ROOT)),"--tmp",str(args.tmp)],ROOT),
           ("dry-run",["scripts/check.sh","--level","work","--base",BASE,"--dry-run"],ROOT),
           ("work",["scripts/check.sh","--level","work","--base",BASE],ROOT)]
 rows=[]
 for name,command,cwd in tasks:
  raw=args.tmp/(name+".log");start=datetime.datetime.now(datetime.timezone.utc).isoformat();timer=time.monotonic()
  with raw.open("wb") as output:result=subprocess.run(command,cwd=cwd,stdout=output,stderr=subprocess.STDOUT)
  row={"check":name,"command":[x.replace(str(args.tmp),"<tmp>") for x in command],"cwd":str(cwd.relative_to(ROOT)) or ".","start_utc":start,"end_utc":datetime.datetime.now(datetime.timezone.utc).isoformat(),"seconds":time.monotonic()-timer,"exit":result.returncode,"raw":digest(raw)}
  rows.append(row);(HERE/"resume1-checks.json").write_text(json.dumps(rows,ensure_ascii=False,indent=2)+"\n");print(json.dumps(row,ensure_ascii=False),flush=True)
  if result.returncode:raise SystemExit(result.returncode)
 (HERE/"signature-checks.json").write_text(json.dumps(rows[:3],ensure_ascii=False,indent=2)+"\n")
 (HERE/"checks.json").write_text(json.dumps(rows[-2:],ensure_ascii=False,indent=2)+"\n")
if __name__=="__main__":main()
