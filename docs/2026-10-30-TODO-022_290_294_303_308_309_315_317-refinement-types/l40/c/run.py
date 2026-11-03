"""指定した局所検査と群末検査の生出力を一時領域へ置き、要約を保存する。"""
import argparse, hashlib, json, subprocess, time
from datetime import datetime, timezone
from pathlib import Path
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("name")
    p.add_argument("--tmp", type=Path, required=True)
    p.add_argument("--formal", action="store_true")
    p.add_argument("command", nargs=argparse.REMAINDER)
    a = p.parse_args()
    command = a.command
    if command[0] == "--": command = command[1:]
    a.tmp.mkdir(exist_ok=True, parents=True)
    log = a.tmp / (a.name + ".log")
    start = datetime.now(timezone.utc).isoformat()
    t = time.monotonic()
    with log.open("wb") as out:
        result = subprocess.run(command, cwd=ROOT / "formal" if a.formal else ROOT,
                                stdout=out, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - t
    data = log.read_bytes()
    display_command = ["<tmp>/" + x[5:] if x.startswith("/tmp/") else x for x in command]
    entry = dict(command=display_command, cwd="formal" if a.formal else ".", start=start,
                 end=datetime.now(timezone.utc).isoformat(), exit=result.returncode,
                 seconds=elapsed, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
    dest = HERE / "checks.json"
    saved = json.loads(dest.read_text()) if dest.exists() else {}
    assert a.name not in saved, "同名の検査記録を上書きしない"
    saved[a.name] = entry
    dest.write_text(json.dumps(saved, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps({a.name:entry}, ensure_ascii=False))
    if result.returncode:
        print(data.decode(errors="replace")[-8000:])
    raise SystemExit(result.returncode)
if __name__ == "__main__": main()
