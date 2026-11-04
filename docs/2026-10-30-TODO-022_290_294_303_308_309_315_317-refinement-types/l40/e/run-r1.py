"""検査の開始・終了と生出力の識別を記録する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, subprocess, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def digest(p):
    b = p.read_bytes()
    return {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
def validate_command(cmd, formal):
    if cmd[:2] == ["lake", "build"] and (cmd != ["lake", "build"] or not formal):
        raise ValueError("lake buildはformal/から対象・オプションを指定せず実行する")
    if cmd[:3] == ["lake", "env", "lean"]:
        memory = "-M12288" in cmd or any(cmd[i:i+2] == ["-M", "12288"] for i in range(len(cmd)-1))
        if not formal or not memory:
            raise ValueError("単独Leanはformal/から-M 12288を明示して実行する")

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("label")
    ap.add_argument("--tmp", type=Path, required=True)
    ap.add_argument("--formal", action="store_true")
    ap.add_argument("--record", default="checks-r1.json")
    ap.add_argument("command", nargs=argparse.REMAINDER)
    a = ap.parse_args()
    cmd = a.command
    if cmd and cmd[0] == "--": cmd = cmd[1:]
    validate_command(cmd, a.formal)
    a.tmp.mkdir(parents=True, exist_ok=True)
    log = a.tmp / (a.label + ".log")
    start = datetime.now(timezone.utc).isoformat()
    t = time.monotonic()
    with log.open("wb") as f:
        r = subprocess.run(cmd, cwd=ROOT / "formal" if a.formal else ROOT,
                           stdout=f, stderr=subprocess.STDOUT)
    item = {"label": a.label, "command": cmd, "cwd": "formal/" if a.formal else ".",
            "start": start, "end": datetime.now(timezone.utc).isoformat(),
            "seconds": time.monotonic()-t, "exit": r.returncode, "raw": digest(log),
            "rss": "未取得（計画上の非採取）"}
    item["command"] = [s.replace(str(ROOT), "<repo>").replace(str(a.tmp), "<tmp>") for s in cmd]
    assert Path(a.record).name == a.record and a.record.startswith("checks-r1") and a.record.endswith(".json")
    out = HERE / a.record
    old = json.loads(out.read_text()) if out.exists() else []
    old.append(item)
    out.write_text(json.dumps(old, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(item, ensure_ascii=False))
    if r.returncode: print(log.read_text()[-10000:])
    raise SystemExit(r.returncode)
if __name__ == "__main__": main()
