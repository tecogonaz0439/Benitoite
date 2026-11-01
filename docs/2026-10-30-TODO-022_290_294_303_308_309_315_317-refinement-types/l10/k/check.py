#!/usr/bin/env python3
"""群 K/I/E の実装と境界を、固定入力・既定ビルド・公理依存・変異で照合する。"""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import re
import subprocess
import tempfile
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
FORMAL = ROOT / "formal"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
MODULES = ["LegacyKinds", "LegacyDeclarations", "LegacyInput", "LegacyRegularity", "LegacyTables", "LegacyTableFacts", "LegacyValues"]
CHANGED = {"formal/Benitoite.lean"}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def protected():
    initial = json.loads((HERE / "initial-inputs.json").read_text())
    initial.update(json.loads((HERE / "review-immutable-inputs.json").read_text()))
    for name, expected in initial.items():
        if name not in CHANGED and sha(ROOT / name) != expected:
            raise SystemExit("PROTECTED_INPUT_CHANGED " + name)
    return len(initial) - len(CHANGED)

def inputs():
    paths = [ROOT / "formal/Benitoite.lean", FORMAL / "lakefile.toml"]
    paths += [FORMAL / "Benitoite/Release/Refinement" / (name+".lean") for name in MODULES]
    paths += [HERE / name for name in ["boundary.lean", "axioms.lean", "handoff.lean", "signatures.md", "mutations.py", "check.py", "review-immutable-inputs.json"]]
    paths += [ROOT / name for name in ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md", "docs/design/00-overview/00-04-glossary.md"]]
    paths += [ROOT / name for name in json.loads((HERE / "review-immutable-inputs.json").read_text())]
    return {str(p.relative_to(ROOT)):sha(p) for p in paths}

def run(label, command):
    destination = Path(tempfile.gettempdir()) / ("l10-k-"+label+".log")
    began = time.monotonic(); started = datetime.now(timezone.utc).isoformat()
    with destination.open("w") as output:
        done = subprocess.run(command, cwd=FORMAL, stdout=output, stderr=subprocess.STDOUT)
    body = destination.read_text().replace(str(ROOT), "<repo>")
    destination.write_text(body)
    if destination.stat().st_size > 100000:
        filename = "<tmp>/" + destination.name
    else:
        target = HERE / (label+"-output.txt"); target.write_text(body); destination = target; filename = target.name
    axioms = set()
    for group in re.findall(r"depends on axioms: \[(.*?)\]", body, re.S):
        axioms.update(a.strip() for a in group.split(",") if a.strip())
    record = {"command":command,"cwd":"formal","started_utc":started,"seconds":round(time.monotonic()-began,3),
              "exit_code":done.returncode,"output":filename,"bytes":destination.stat().st_size,"sha256":sha(destination),
              "axioms_seen":sorted(axioms),"disallowed_axioms":sorted(axioms-ALLOWED),
              "print_axioms_count":len(re.findall(r"^'.*?' (?:does not depend on any axioms|depends on axioms:)",body,re.M)),
              "sorry_diagnostic":bool(re.search(r"declaration uses ['‘]sorry|\bsorryAx\b",body))}
    if label == "build":
        jobs = re.search(r"Build completed successfully \((\d+) jobs\)",body)
        record["jobs"] = int(jobs.group(1)) if jobs else None
    if label in {"boundary", "handoff"}:
        found = re.search(("BOUNDARY_CONSTANTS" if label == "boundary" else "HANDOFF_CONSTANTS") + r" (\d+)",body)
        record["constants"] = int(found.group(1)) if found else None
        record["complete"] = record["constants"] == record["print_axioms_count"]
    if label == "axioms":
        record["modules"] = {m:int(n) for m,n in re.findall(r"AUDIT_MODULE (\S+) (\d+)",body)}
        record["case_totals"] = {m:int(n) for m,n in re.findall(r"CASE_TOTAL (\S+) (\d+)",body)}
        record["complete"] = (sum(record["modules"].values())+18 == record["print_axioms_count"] and len(record["modules"]) == 8)
    (HERE / (label+"-result.json")).write_text(json.dumps(record,ensure_ascii=False,indent=2)+"\n")
    print(label, "exit",done.returncode,"seconds",record["seconds"],"axioms",record["print_axioms_count"],flush=True)
    if done.returncode or record["disallowed_axioms"] or record["sorry_diagnostic"] or record.get("complete") is False:
        print(body[-5000:]); raise SystemExit("CHECK_FAILED " + label)
    return record

def main():
    began = time.monotonic(); started = datetime.now(timezone.utc).isoformat()
    protected_count = protected(); before = inputs()
    if 'moreLeanArgs = ["-M", "12288"]' not in (FORMAL / "lakefile.toml").read_text(): raise SystemExit("BAD_MEMORY_LIMIT")
    result = {"started_utc":started,"base":"99ff1579586c5b62db54c00b1fbb673b96d02dc4","branch":"m014/l10.k",
              "protected_count":protected_count,"inputs":before,"rss":"未取得（計画上の非採取）"}
    result["build"] = run("build", ["lake","build"])
    relative = "../"+str(HERE.relative_to(ROOT))+"/"
    result["boundary"] = run("boundary", ["lake","env","lean","-M","12288",relative+"boundary.lean"])
    result["handoff"] = run("handoff", ["lake","env","lean","-M","12288",relative+"handoff.lean"])
    result["axioms"] = run("axioms", ["lake","env","lean","-M","12288",relative+"axioms.lean"])
    result["mutations"] = run("mutation-run", ["python3",relative+"mutations.py"])
    if before != inputs(): raise SystemExit("VERIFIED_INPUT_CHANGED")
    protected()
    result["seconds"] = round(time.monotonic()-began,3)
    result["ended_utc"] = datetime.now(timezone.utc).isoformat()
    (HERE / "verification.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    large = "# 大きな生の記録\n\n100,000 bytes を超える生の記録は一時領域に置く。手元の絶対パスは記録しない。\n\n| 記録 | bytes | SHA-256 |\n|---|---:|---|\n"
    for name in ["build","boundary","handoff","axioms","mutations"]:
        row = result[name]
        if row["output"].startswith("<tmp>/"): large += f'| `{row["output"]}` | {row["bytes"]} | `{row["sha256"]}` |\n'
    mutation = json.loads((HERE / "mutations-result.json").read_text())
    if mutation["output"].startswith("<tmp>/"):
        large += f'| `{mutation["output"]}` | {mutation["bytes"]} | `{mutation["sha256"]}` |\n'
    (HERE / "large-records.md").write_text(large)
    print("VERIFIED",result["seconds"],"protected",protected_count,flush=True)

if __name__ == "__main__": main()
