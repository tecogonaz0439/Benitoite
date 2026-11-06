"""停止時の局所試行・既定ビルド・全環境監査を各一度実行する。gitは呼ばない。"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def snapshot():
    paths = []
    for folder, dirs, files in os.walk(ROOT / "formal"):
        dirs[:] = sorted(d for d in dirs if d not in {".lake", ".git"})
        paths.extend(Path(folder) / f for f in files if f.endswith(".lean") or f in {
            "lakefile.toml", "lean-toolchain", "lake-manifest.json"})
    paths += [ROOT / "docs/design/01-spec/01-12-core-calculus.md",
              ROOT / "docs/design/07-quality/07-04-formal-semantics.md"]
    return {str(p.relative_to(ROOT)): digest(p) for p in sorted(paths)}


def date():
    return subprocess.check_output(["date", "+%Y-%m-%dT%H:%M:%S%z"], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    args.lock.parent.mkdir(parents=True, exist_ok=True)
    baseline = args.tmp / "sources-before.json"
    assert not baseline.exists(), "初回の記録を上書きしない"
    baseline.write_text(json.dumps(snapshot(), ensure_ascii=False, sort_keys=True) + "\n")
    relative = "../" + str(HERE.relative_to(ROOT)) + "/"
    lock = ["/usr/bin/lockf", "-t", "3600", str(args.lock)]
    commands = [(stem, ["lake", "env", "lean", "-M", "12288", relative + stem + ".lean"])
                for stem in ["match-trial", "effect-trial", "range-trial"]]
    commands += [("build", lock + ["lake", "build"]),
                 ("axioms", lock + ["lake", "env", "lean", "-M", "12288", relative + "axioms.lean"])]
    records = {"base": "dcaa396bad7a60d4da9b99d07ad9b75c0f328b07",
               "source_snapshot": digest(baseline), "source_count": len(snapshot()),
               "production_modules_added": [], "production_declarations_added": 0, "checks": {}}
    for label, command in commands:
        start, tick = date(), time.monotonic()
        print(label + " 開始 " + start, flush=True)
        raw = args.tmp / (label + ".log")
        with raw.open("wb") as stream:
            result = subprocess.run(command, cwd=ROOT / "formal", stdout=stream, stderr=subprocess.STDOUT)
        record = {"command": [a.replace(str(args.lock), "<lock>") for a in command],
                  "cwd": "formal", "start": start, "end": date(),
                  "seconds": round(time.monotonic() - tick, 3), "exit": result.returncode,
                  "raw": digest(raw), "maximum_rss": "未取得（計画上の非採取）"}
        if label.endswith("trial"):
            record["input"] = digest(HERE / (label + ".lean"))
        if label == "axioms":
            record["input"] = digest(HERE / "axioms.lean")
        records["checks"][label] = record
        (HERE / "checks.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")
        print(label + " 終了 " + str(result.returncode) + " " + str(record["seconds"]) + "秒", flush=True)
        if result.returncode:
            print(raw.read_text()[-5000:])
            raise SystemExit(result.returncode)
    assert json.loads(baseline.read_text()) == snapshot(), "検査中にソースが変わった"


if __name__ == "__main__":
    main()
