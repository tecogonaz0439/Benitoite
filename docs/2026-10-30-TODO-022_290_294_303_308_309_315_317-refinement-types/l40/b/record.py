"""局所検査のコマンド・終了・外側時間と生出力の識別を保存する。"""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[3]

def run(label, command, cwd):
    start = datetime.datetime.now(datetime.timezone.utc).isoformat()
    now = time.monotonic()
    result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - now
    path = Path(tempfile.gettempdir()) / ("l40-b-" + label + ".log")
    path.write_bytes(result.stdout)
    entry = dict(label=label, command=command, cwd=str(Path(cwd).relative_to(ROOT)),
                 start=start, end=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                 exit=result.returncode, seconds=elapsed, bytes=len(result.stdout),
                 sha256=hashlib.sha256(result.stdout).hexdigest(), raw="<tmp>/" + path.name)
    target = BASE / "checks.json"
    data = json.loads(target.read_text()) if target.exists() else []
    data.append(entry)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(entry, ensure_ascii=False))
    if result.returncode:
        print(result.stdout.decode(errors="replace")[-10000:])
    return result.returncode

if __name__ == "__main__":
    label, mode, *args = sys.argv[1:]
    command = (["lake", "env", "lean", "-M", "12288"] + args if mode == "lean"
               else args)
    raise SystemExit(run(label, command, ROOT / "formal" if mode in {"lean", "formal"} else ROOT))
