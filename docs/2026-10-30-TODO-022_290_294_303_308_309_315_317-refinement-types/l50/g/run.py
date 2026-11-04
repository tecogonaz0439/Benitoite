"""固定した基準で検査を一度実行し、生出力の大きさとハッシュを保存する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, hashlib, json, subprocess, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "38a98b76258171b96ee73091d8c25833030d776d"
def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--tmp", type=Path, required=True)
    p.add_argument("--record-prefix", default="")
    p.add_argument("kind", choices=["build", "dry-run", "work"])
    args = p.parse_args()
    record = HERE / (args.record_prefix + args.kind + "-check.json")
    assert not record.exists(), "同じ検査の重複実行を拒否"
    command = ["lake", "build"] if args.kind == "build" else ["scripts/check.sh", "--level", "work", "--base", BASE]
    if args.kind == "dry-run": command.append("--dry-run")
    args.tmp.mkdir(parents=True, exist_ok=True)
    raw = args.tmp / (args.record_prefix + args.kind + ".log")
    tick = time.monotonic()
    start = datetime.now(timezone.utc).isoformat()
    with raw.open("wb") as stream:
        result = subprocess.run(command, cwd=ROOT / "formal" if args.kind == "build" else ROOT,
            stdout=stream, stderr=subprocess.STDOUT)
    data = raw.read_bytes()
    summary = {"command": command, "cwd": "formal" if args.kind == "build" else ".", "base": BASE, "runs": 1,
        "exit": result.returncode, "start_utc": start,
        "end_utc": datetime.now(timezone.utc).isoformat(), "seconds": time.monotonic()-tick,
        "raw": {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}}
    record.write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(summary, ensure_ascii=False))
    print("\n".join(data.decode().splitlines()[-12:]))
    raise SystemExit(result.returncode)
if __name__ == "__main__": main()
