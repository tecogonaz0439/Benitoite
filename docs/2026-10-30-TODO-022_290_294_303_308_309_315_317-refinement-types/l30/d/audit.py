"""既定importの群A〜Eの全宣言と旧主定理の公理依存を照合する。"""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import os
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    raw = args.tmp / "axioms.log"
    targets = args.tmp / "audit-targets.txt"
    env = dict(os.environ, L30_AUDIT_TARGETS=str(targets))
    command = ["lake", "env", "lean", "-M", "12288", "../" + str((HERE / "audit.lean").relative_to(ROOT))]
    start = time.monotonic()
    with raw.open("wb") as stream:
        result = subprocess.run(command, cwd=ROOT / "formal", env=env, stdout=stream, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - start
    summary = {"command": command, "exit": result.returncode, "seconds": elapsed, "raw": digest(raw)}
    if result.returncode:
        print(json.dumps(summary))
        raise SystemExit(result.returncode)
    text = raw.read_text()
    names = targets.read_text().splitlines()
    records = re.findall(r"^'(.*?)' (does not depend on any axioms|depends on axioms: \[([^\]]*)\])", text, re.M | re.S)
    found = collections.Counter(n for n, _, _ in records)
    assert set(found) == set(names) and all(n == 1 for n in found.values())
    assert names == sorted(set(names))
    sets = collections.Counter(tuple(sorted(x.strip() for x in a.split(",") if x.strip())) for _, _, a in records)
    assert all(set(s) <= ALLOWED for s in sets)
    assert not re.search(r"error:|AUDIT_(?:MISSING|DUPLICATE|AXIOM)", text)
    modules = re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", text, re.M)
    assert len(modules) == 25
    summary.update({"targets": len(names), "target_list": digest(targets), "modules": dict(modules),
                    "axiom_sets": {" + ".join(k) or "none": v for k, v in sets.items()},
                    "private_or_generated_included": True, "new_axioms": 0})
    (HERE / "audit-summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary))


if __name__ == "__main__":
    main()
