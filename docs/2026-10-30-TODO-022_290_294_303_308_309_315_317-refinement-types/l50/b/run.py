"""検査の終了・外側の時間・生出力の大きさとハッシュを記録する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, subprocess, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "6c8ec4247893fa0013ec74ffabe8e33bc55a0678"
def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--tmp", type=Path, required=True)
    p.add_argument("kind", choices=["dry-run", "work", "local-scope", "local-member", "local-effect"])
    a = p.parse_args()
    if a.kind in ["work", "dry-run"]:
        cmd = ["scripts/check.sh", "--level", "work", "--base", BASE]
        if a.kind == "dry-run": cmd += ["--dry-run"]
        cwd = ROOT
    else:
        name = {"local-scope":"ScopeCoverage", "local-member":"MembershipTargets", "local-effect":"EffectTargets"}[a.kind]
        cmd = ["lake", "env", "lean", "-M", "12288", "Benitoite/Release/Refinement/"+name+".lean"]
        cwd = ROOT/"formal"
    record = HERE/(a.kind+"-check.json")
    if record.exists(): raise SystemExit("同じ検査の記録は上書きしない")
    a.tmp.mkdir(parents=True, exist_ok=True)
    raw = a.tmp/(a.kind+".log")
    start = datetime.now(timezone.utc).isoformat(); tick = time.monotonic()
    with raw.open("wb") as f:
        result = subprocess.run(cmd, cwd=cwd, stdout=f, stderr=subprocess.STDOUT)
    summary = {"command":cmd, "cwd":"." if cwd==ROOT else "formal", "base":BASE,
        "start_utc":start,"end_utc":datetime.now(timezone.utc).isoformat(),
        "seconds":time.monotonic()-tick,"exit":result.returncode,"runs":1,"raw":digest(raw)}
    record.write_text(json.dumps(summary,ensure_ascii=False,indent=2)+"\n")
    print(json.dumps(summary,ensure_ascii=False))
    if result.returncode: print(raw.read_text()[-8000:])
    raise SystemExit(result.returncode)
if __name__ == "__main__": main()
