"""検査の開始・終了と生出力の識別を記録する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, subprocess, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def digest(p):
    b = p.read_bytes()
    return {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("label")
    ap.add_argument("--tmp", type=Path, required=True)
    ap.add_argument("--formal", action="store_true")
    ap.add_argument("--timeout", type=int)
    ap.add_argument("command", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.command
    if cmd and cmd[0] == "--": cmd = cmd[1:]
    a.tmp.mkdir(parents=True, exist_ok=True)
    log = a.tmp / (a.label + ".log")
    start = datetime.now(timezone.utc).isoformat()
    t = time.monotonic()
    with log.open("wb") as f:
        try:
            r = subprocess.run(cmd, cwd=ROOT / "formal" if a.formal else ROOT,
                               stdout=f, stderr=subprocess.STDOUT, timeout=a.timeout)
        except subprocess.TimeoutExpired:
            r = subprocess.CompletedProcess(cmd,124)
    item = {"label": a.label, "command": cmd, "cwd": "formal/" if a.formal else ".",
            "start": start, "end": datetime.now(timezone.utc).isoformat(),
            "seconds": time.monotonic()-t, "exit": r.returncode, "raw": digest(log),
            "rss": "未取得（計画上の非採取）"}
    item["command"] = [s.replace(str(ROOT), "<repo>").replace(str(a.tmp), "<tmp>") for s in cmd]
    out = HERE / "checks-r3.json"
    old = json.loads(out.read_text()) if out.exists() else []
    old.append(item)
    out.write_text(json.dumps(old, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(item, ensure_ascii=False))
    if r.returncode: print(log.read_text()[-10000:])
    raise SystemExit(r.returncode)
if __name__ == "__main__": main()
