"""再開3の復元後の既定ビルドと全環境の公理監査を各一度実行する。"""
import argparse
import json
from pathlib import Path
import subprocess
import time
from run_checks import HERE, ROOT, date, digest, snapshot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    assert not (args.tmp / "build.log").exists()
    before = snapshot()
    record = {"base": "dcaa396bad7a60d4da9b99d07ad9b75c0f328b07",
              "source_count": len(before), "production_modules_added": [], "checks": {}}
    (args.tmp / "sources-before.json").write_text(json.dumps(before, sort_keys=True)+"\n")
    record["source_snapshot"] = digest(args.tmp / "sources-before.json")
    lock = ["/usr/bin/lockf", "-t", "3600", str(args.lock)]
    relative = "../" + str(HERE.relative_to(ROOT)) + "/axioms.lean"
    for label, command in [("build", lock+["lake", "build"]),
                           ("axioms", lock+["lake", "env", "lean", "-M", "12288", relative])]:
        tick, start = time.monotonic(), date()
        print(label+" 開始 "+start, flush=True)
        raw = args.tmp / (label+".log")
        with raw.open("wb") as out:
            result = subprocess.run(command, cwd=ROOT/"formal", stdout=out, stderr=subprocess.STDOUT)
        record["checks"][label] = {"command": [x.replace(str(args.lock), "<lock>") for x in command],
            "cwd": "formal", "start": start, "end": date(), "exit": result.returncode,
            "seconds": round(time.monotonic()-tick, 3), "raw": digest(raw),
            "maximum_rss": "未取得（計画上の非採取）"}
        (HERE/"resume3-checks.json").write_text(json.dumps(record, ensure_ascii=False, indent=2)+"\n")
        print(label+" 終了 "+str(result.returncode), flush=True)
        if result.returncode:
            print(raw.read_text()[-5000:]);raise SystemExit(result.returncode)
    assert before == snapshot()


if __name__ == "__main__":
    main()
