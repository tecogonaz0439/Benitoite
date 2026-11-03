"""既定の新旧全モジュールの公理依存と、再生成した全名の一覧を照合する。"""
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
NEW = {"TelApplication", "StandardKeyTyping", "StandardContracts", "StandardScalar",
       "StandardBodies", "IntervalFailure", "ValueInversion"}


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--inventory-only", action="store_true")
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    raw = args.tmp / ("inventory.log" if args.inventory_only else "axioms.log")
    targets = args.tmp / "audit-targets.txt"
    env = dict(os.environ, L40_AUDIT_TARGETS=str(targets.resolve()),
               L40_INVENTORY_ONLY="1" if args.inventory_only else "0")
    command = ["lake", "env", "lean", "-M", "12288", "../" + str((HERE / "axioms.lean").relative_to(ROOT))]
    start = time.monotonic()
    with raw.open("wb") as stream:
        result = subprocess.run(command, cwd=ROOT / "formal", env=env,
                                stdout=stream, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - start
    if result.returncode:
        print(json.dumps({"exit": result.returncode, "seconds": elapsed, "raw": digest(raw)}))
        raise SystemExit(result.returncode)
    output = raw.read_text()
    names = targets.read_text().splitlines()
    assert names == sorted(set(names)), "対象名の重複"
    markers = re.findall(r"^AUDIT_TARGET (.+)$", output, re.M)
    assert markers == names, "一覧と実行対象が異なる"
    modules = dict((m, int(n)) for m, n in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", output, re.M))
    assert sum(modules.values()) == len(names)
    assert "Benitoite" in modules and len(modules) > 600
    assert all("Benitoite.Release.Refinement." + n in modules for n in NEW)
    assert not re.search(r"error:|AUDIT_(?:REQUIRED_MISSING|MODULE_MISSING|MISSING|DUPLICATE|AXIOM)", output)
    summary = {"command": command, "exit": 0, "seconds": elapsed,
               "raw": digest(raw), "targets": len(names), "target_list": digest(targets),
               "module_count": len(modules), "modules": modules,
               "private_and_generated_included": True, "inventory_only": args.inventory_only,
               "new_modules": {n: modules["Benitoite.Release.Refinement." + n] for n in sorted(NEW)}}
    if not args.inventory_only:
        records = re.findall(r"^'(.*?)' (does not depend on any axioms|depends on axioms: \[([^\]]*)\])", output, re.M | re.S)
        found = collections.Counter(n for n, _, _ in records)
        assert set(found) == set(names) and all(n == 1 for n in found.values()), "print axiomsの欠落又は重複"
        sets = collections.Counter(tuple(sorted(a.strip() for a in s.split(",") if a.strip()))
                                   for _, _, s in records)
        assert all(set(s) <= ALLOWED for s in sets), "未承認の公理依存"
        summary.update({"axiom_sets": {" + ".join(k) or "none": v for k, v in sorted(sets.items())},
                        "new_axioms": 0})
    dest = HERE / ("inventory-summary.json" if args.inventory_only else "audit-summary.json")
    dest.write_text(json.dumps(summary, indent=2) + "\n")
    assert dest.stat().st_size <= 100_000
    print(json.dumps({k: v for k, v in summary.items() if k != "modules"}))


if __name__ == "__main__":
    main()
