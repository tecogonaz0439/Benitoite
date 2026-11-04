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
NEW = set(json.loads((HERE / "modules-r3.json").read_text()))


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--inventory-only", action="store_true")
    parser.add_argument("--tag", required=True)
    parser.add_argument("--reuse-completed", action="store_true",
                        help="完走済みのLean出力と対象一覧を再検査し、記録だけを分割する")
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    raw = args.tmp / ("inventory.log" if args.inventory_only else "axioms.log")
    targets = args.tmp / "audit-targets.txt"
    env = dict(os.environ, L40_AUDIT_TARGETS=str(targets.resolve()),
               L40_INVENTORY_ONLY="1" if args.inventory_only else "0")
    local_inputs = []
    bodies = []
    for name in local_inputs:
        body = (HERE / name).read_text()
        body = re.sub(r"^import .+\n", "", body, flags=re.M)
        bodies.append(body)
    audit_input = args.tmp / "audit-input.lean"
    audit_body = (HERE / "axioms-r1.lean").read_text().replace("-- LOCAL_INPUTS", "\n".join(bodies))
    audit_body = audit_body.replace("-- NEW_MODULES", ", ".join(json.dumps("Benitoite.Release.Refinement." + n) for n in sorted(NEW)))
    audit_input.write_text(audit_body)
    command = ["lake", "env", "lean", "-M", "12288", str(audit_input.resolve())]
    start = time.monotonic()
    if args.reuse_completed:
        assert raw.exists() and targets.exists()
        elapsed = None
    else:
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
    summary = {"command": ["lake", "env", "lean", "-M", "12288", "<tmp>/audit-input.lean"], "exit": 0, "seconds": elapsed,
               "raw": digest(raw), "targets": len(names), "target_list": digest(targets),
               "module_count": len(modules) - 1, "modules": modules,
               "local_records": modules["local_records"], "audit_input": digest(audit_input),
               "local_inputs": {n: digest(HERE / n) for n in local_inputs},
               "historical_inputs": {},
               "private_and_generated_included": True, "inventory_only": args.inventory_only,
               "new_modules": {n: modules["Benitoite.Release.Refinement." + n] for n in sorted(NEW)}}
    summary["reused_completed_lean"] = args.reuse_completed
    summary["lean_execution_exit"] = 0
    if not args.inventory_only:
        records = re.findall(r"^'(.*?)' (does not depend on any axioms|depends on axioms: \[([^\]]*)\])", output, re.M | re.S)
        found = collections.Counter(n for n, _, _ in records)
        assert set(found) == set(names) and all(n == 1 for n in found.values()), "print axiomsの欠落又は重複"
        sets = collections.Counter(tuple(sorted(a.strip() for a in s.split(",") if a.strip()))
                                   for _, _, s in records)
        assert all(set(s) <= ALLOWED for s in sets), "未承認の公理依存"
        summary.update({"axiom_sets": {" + ".join(k) or "none": v for k, v in sorted(sets.items())},
                        "new_axioms": 0})
    added = collections.defaultdict(list)
    for mod, name in re.findall(r"^AUDIT_NEW_DECL (\S+) (.+)$", output, re.M):
        added[mod].append(name)
    required_modules = {"Benitoite.Release.Refinement." + n for n in NEW}
    assert set(added) == {mod for mod in required_modules if modules[mod] > 0}
    for mod in sorted(required_modules):
        names_in_module = added[mod]
        assert len(names_in_module) == modules[mod]
        assert len(names_in_module) == len(set(names_in_module))
        item = {"module": mod, "count": len(names_in_module), "names": sorted(names_in_module)}
        path = HERE / ("declarations-" + args.tag + "-" + mod.split(".")[-1] + ".json")
        if len(json.dumps(item, indent=2).encode()) > 99999:
            pieces = []
            for offset in range(0, len(item["names"]), 250):
                part = HERE / (path.stem + "-part-" + str(offset//250+1).zfill(2) + ".json")
                chunk = item["names"][offset:offset+250]
                part.write_text(json.dumps(chunk, indent=2) + "\n")
                assert part.stat().st_size <= 100000
                pieces.append({"file":part.name,"count":len(chunk),**digest(part)})
            item = {"module":mod,"count":len(names_in_module),"names_parts":pieces}
        path.write_text(json.dumps(item, indent=2) + "\n")
        assert path.stat().st_size <= 100000
    summary["added_declarations"] = sum(len(v) for v in added.values())
    summary["tag"] = args.tag
    summary["frozen_inputs"] = digest(HERE / "r1-start.json")
    original = set(json.loads((HERE / "modules.json").read_text()))
    summary["resumed_modules"] = {n: summary["new_modules"][n] for n in sorted(NEW - original)}
    summary["resumed_declarations"] = sum(summary["resumed_modules"].values())
    source_items = [(str(p.relative_to(ROOT)), digest(p)) for p in [ROOT / "formal/Benitoite.lean"] + [ROOT / "formal/Benitoite/Release/Refinement" / (n + ".lean") for n in sorted(NEW)]]
    summary["source_inputs_parts"] = []
    for offset in range(0,len(source_items),150):
        part = HERE / ("audit-source-inputs-" + args.tag + "-part-" + str(offset//150+1).zfill(2) + ".json")
        data = json.dumps(dict(source_items[offset:offset+150]),indent=2) + "\n"
        assert len(data.encode()) <= 100000
        part.write_text(data)
        summary["source_inputs_parts"].append({"file":part.name,**digest(part)})
    dest = HERE / (("inventory-summary-" if args.inventory_only else "audit-summary-") + args.tag + ".json")
    module_path=HERE / ("audit-modules-" + args.tag + ".json")
    module_path.write_text(json.dumps(summary.pop("modules"),separators=(",",":"))+"\n")
    assert module_path.stat().st_size <= 100000
    summary["module_record"]={"file":module_path.name,**digest(module_path)}
    dest.write_text(json.dumps(summary,separators=(",",":")) + "\n")
    assert dest.stat().st_size <= 100_000
    print(json.dumps({k:summary[k] for k in ["exit","seconds","module_count","targets","new_axioms","added_declarations","raw"]}))


if __name__ == "__main__":
    main()
