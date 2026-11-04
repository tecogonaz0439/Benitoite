"""検査を一回実行し、生出力を一時領域、終了と識別情報を改造へ記録する。"""
from datetime import datetime, timezone
from pathlib import Path
import argparse
import subprocess
import time
from inventory import HERE, ROOT, digest, write


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("label")
    ap.add_argument("--tmp", type=Path, required=True)
    ap.add_argument("--formal", action="store_true")
    ap.add_argument("command", nargs=argparse.REMAINDER)
    args = ap.parse_args()
    command = args.command
    if command and command[0] == "--":
        command = command[1:]
    assert command
    destination = HERE / (args.label + ".json")
    assert not destination.exists(), "同じ検査記録を上書きしない"
    args.tmp.mkdir(parents=True, exist_ok=True)
    raw = args.tmp / (args.label + ".log")
    start, tick = datetime.now(timezone.utc).isoformat(), time.monotonic()
    with raw.open("wb") as stream:
        result = subprocess.run(command, cwd=ROOT / "formal" if args.formal else ROOT,
                                stdout=stream, stderr=subprocess.STDOUT)
    record = {"command": [a.replace(str(args.tmp), "<tmp>") for a in command], "cwd": "formal" if args.formal else ".",
              "exit": result.returncode, "seconds": time.monotonic() - tick,
              "start_utc": start, "end_utc": datetime.now(timezone.utc).isoformat(),
              "raw": digest(raw), "maximum_rss": "未取得（正式採取は取りまとめ）"}
    write(destination, record)
    print(record)
    if result.returncode:
        print(raw.read_text()[-6000:])
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
