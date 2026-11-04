"""群末の既定ビルド又は指定workを一度実行して小さい記録を残す。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=["build", "work"])
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    raw = args.tmp / (args.kind + ".log")
    assert not raw.exists(), "この一時領域の同じ群末検査は実行済み"
    if args.kind == "build":
        command, cwd = ["lake", "build"], "formal"
    else:
        command, cwd = ["scripts/check.sh", "--level", "work", "--base",
                        "e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f"], "."
    start = datetime.now(timezone.utc).isoformat()
    tick = time.monotonic()
    with raw.open("wb") as stream:
        result = subprocess.run(command, cwd=ROOT / cwd, stdout=stream, stderr=subprocess.STDOUT)
    data = raw.read_bytes()
    record = {"command": command, "cwd": cwd, "start_utc": start,
              "end_utc": datetime.now(timezone.utc).isoformat(), "seconds": time.monotonic() - tick,
              "exit": result.returncode, "runs": 1,
              "raw": {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}}
    (HERE / (args.kind + "-check.json")).write_text(json.dumps(record, indent=2) + "\n")
    print(json.dumps(record))
    if result.returncode:
        print(data.decode()[-10000:])
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
