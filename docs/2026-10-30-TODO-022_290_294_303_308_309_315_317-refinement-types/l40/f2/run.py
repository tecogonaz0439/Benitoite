"""検査の時刻・終了・出力の識別値を保存する。生出力は一時領域へ置く。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, subprocess, tempfile, time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('label')
ap.add_argument('--formal', action='store_true')
ap.add_argument('command', nargs=argparse.REMAINDER)
a = ap.parse_args()
cmd = a.command
if cmd and cmd[0] == '--': cmd = cmd[1:]
tmp = Path(tempfile.gettempdir()) / 'benitoite-l40-f2'
tmp.mkdir(exist_ok=True)
log = tmp / (a.label+'.log')
start = datetime.now(timezone.utc); tick = time.monotonic()
with log.open('wb') as out:
    r = subprocess.run(cmd, cwd=ROOT/('formal' if a.formal else '.'), stdout=out, stderr=subprocess.STDOUT)
data = log.read_bytes()
record = {'label':a.label,'command':cmd,'cwd':'formal/' if a.formal else '.',
          'start_utc':start.isoformat(),'end_utc':datetime.now(timezone.utc).isoformat(),
          'seconds':time.monotonic()-tick,'exit':r.returncode,'raw':{'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}}
p=HERE/'checks.json'
rows=json.loads(p.read_text()) if p.exists() else []
rows.append(record);p.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(record,ensure_ascii=False))
print(data.decode(errors='replace')[-(12000 if r.returncode else 1500):])
raise SystemExit(r.returncode)
