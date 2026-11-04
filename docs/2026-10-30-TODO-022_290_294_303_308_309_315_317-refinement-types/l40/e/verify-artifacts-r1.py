"""内容を再生成した二つのソースと既定ビルド成果物の一致を検査する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
NAMES = ("StandardArithmeticResponse", "StandardOrderResponse")


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    rows = []
    for name in NAMES:
        source = Path("Benitoite/Release/Refinement") / (name + ".lean")
        setup = Path(".lake/build/ir/Benitoite/Release/Refinement") / (name + ".setup.json")
        cached = Path(".lake/build/lib/lean/Benitoite/Release/Refinement") / (name + ".olean")
        fresh = args.tmp / (name + ".olean")
        before = digest(ROOT / "formal" / source)
        label = args.tag + "-artifact-" + name
        command = [sys.executable, str(HERE / "run-r1.py"), "--tmp", str(args.tmp),
                   "--record", "checks-r1-u28-final.json", "--formal", label, "--",
                   "lake", "env", "lean", "-M", "12288", "--setup", str(setup),
                   "-o", str(fresh), str(source)]
        subprocess.run(command, cwd=ROOT, check=True)
        assert digest(ROOT / "formal" / source) == before
        cached_digest = digest(ROOT / "formal" / cached)
        fresh_digest = digest(fresh)
        assert cached_digest == fresh_digest, name
        rows.append({"module": name, "source": before, "cached": cached_digest,
                     "fresh": fresh_digest, "setup": digest(ROOT / "formal" / setup),
                     "check_label": label})
    result = {"exit": 0, "ended": datetime.now(timezone.utc).isoformat(), "rows": rows,
              "method": "同じLake setup・固定Lean・M 12288で一時領域へ再生成し、既定oleanとbytes/SHAを照合"}
    (HERE / ("content-checks-" + args.tag + ".json")).write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
