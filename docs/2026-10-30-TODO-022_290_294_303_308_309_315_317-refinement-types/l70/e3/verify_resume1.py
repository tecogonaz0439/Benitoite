#!/usr/bin/env python3
"""既定 import・全宣言の印字・許可公理・保護した入力と記録の大きさを照合する。"""
import argparse
import collections
import datetime
import json
import re
import time
from pathlib import Path
from inventory import HERE, ROOT, digest, fingerprint, inputs, write
from inventory_resume1 import audit_source, local_inputs, modules, protected
from verify import ALLOWED, import_closure

PREFIX = "Benitoite.Release.Refinement."
REQUIRED = [
    "Surface.desugar_additions", "Surface.main_start", "Surface.surface_guarantees",
    "Surface.link_additions", "Surface.linked_main", "Surface.checkProgramAccepted_main",
    "Surface.MainExamples.main_guarantees", "SafeCheckErasure.eraseProgram",
    "SafeCheckErasure.erase", "SafeCheckErasure.Code", "SafeCheckErasure.StateRel",
    "SafeCheckErasure.state_step", "SafeCheckErasure.state_reflect",
    "SafeCheckErasure.observations_preserved", "SafeCheckErasure.infinite_preserved",
    "SafeCheckErasure.diverging_prefixes_preserved", "SafeCheckErasure.effects_preserved",
    "SafeCheckErasure.program_preservation", "SafeCheckErasure.computation_preservation",
    "CheckErasureBoundary.counterexample", "PatternContextObstruction.obstruction",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    start = datetime.datetime.now().astimezone().isoformat()
    clock = time.monotonic()
    current, current_local = inputs(), local_inputs()
    captured = json.loads((HERE / "resume1-inputs.json").read_text())
    # 検査済みのLean入力は固定し、照合台本だけの修正を別の記録で照合する。
    local = captured["local_inputs"]
    initial = json.loads((HERE / "resume1-verify-initial.json").read_text())
    assert initial["exit"] == 1 and initial["script"] == local["verify_resume1.py"]
    assert digest(HERE / "verify_resume1_initial.py") == initial["script"]
    assert {k: v for k, v in local.items() if k != "verify_resume1.py"} == {
        k: v for k, v in current_local.items() if k != "verify_resume1.py"}
    assert captured == dict(protected(), modules=modules(), local_inputs=local)
    added = set(modules())
    assert added and len(added) == 11, sorted(added)
    closure = import_closure()
    assert added <= closure, sorted(added - closure)
    assert all("formal/" + n.replace(".", "/") + ".lean" in current for n in closure)
    records = {n: json.loads((HERE / ("resume1-" + n + ".json")).read_text()) for n in ("build", "audit")}
    for name, record in records.items():
        assert record["exit"] == 0 and record["inputs_unchanged"] and record["local_inputs_unchanged"]
        assert record["inputs_count"] == len(current) and record["inputs_sha256"] == fingerprint(current)
        assert record["local_inputs"] == local
        assert record["output_digest"] == digest(args.tmp / (name + ".log"))
    generated = args.tmp / "audit.lean"
    assert generated.read_text() == audit_source()
    assert records["audit"]["generated_input"] == digest(generated)
    raw = (args.tmp / "audit.log").read_text()
    assert not re.search(r"error:|warning:|sorryAx|AUDIT_(?:AXIOM|MISSING|FIXED_POINT_LIMIT)", raw)
    rows = re.findall(r"^AUDIT_TARGET (\S+) (.+)$", raw, re.M)
    declared = [n for _, n in rows]
    assert len(declared) == len(set(declared)) == int(re.search(r"^AUDIT_COUNT (\d+)$", raw, re.M)[1])
    printed = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", raw, re.M | re.S)
    assert collections.Counter(n for n, _ in printed) == collections.Counter(declared)
    deps = {n: sorted(x.strip() for x in a.split(",") if x.strip()) for n, a in printed}
    assert all(set(a) <= ALLOWED for a in deps.values())
    assert {PREFIX + n for n in REQUIRED} <= set(declared)
    counts = {m: int(n) for m, n in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", raw, re.M)}
    actual = collections.Counter(m for m, _ in rows)
    assert set(counts) == closure
    assert all(counts[m] == actual[m] for m in closure)
    owned = [{"module": m, "name": n, "axioms": deps[n]} for m, n in rows if m in added or m == "local_input"]
    # example は既定ビルドで検査されるが、環境へ宣言を登録しない。
    empty = {"Benitoite.Release.Refinement.SafeCheckPreservationExamples"}
    assert {m for m in added if actual[m] == 0} == empty
    assert all(re.search(r"^example\s", (ROOT / "formal" / (m.replace(".", "/") + ".lean")).read_text(), re.M) for m in empty)
    catalogue = args.tmp / "added-declarations.json"
    write(catalogue, sorted(owned, key=lambda r: (r["module"], r["name"])))
    targets = args.tmp / "all-declarations.txt"
    targets.write_text("\n".join(sorted(declared)) + "\n")
    for module in added:
        source = ROOT / "formal" / (module.replace(".", "/") + ".lean")
        assert not re.search(r"\b(?:sorry|axiom|unsafe)\b|#eval|set_option\s+(?:maxHeartbeats|maxRecDepth)", source.read_text())
    files = [p for p in HERE.rglob("*") if p.is_file() and "__pycache__" not in p.parts]
    assert all(p.stat().st_size <= 100_000 for p in files)
    assert sum(p.stat().st_size for p in files) <= 5_000_000
    for path in files:
        text = path.read_text()
        assert not re.search(r"/(?:Users|private)/[A-Za-z]", text), path.name
        assert not re.search(r"\]\([^)]*docs/todo", text), path.name
    summary = {
        "status": "再開1の既定ビルド・全公理監査・照合が成功",
        "started": start, "ended": datetime.datetime.now().astimezone().isoformat(), "seconds": time.monotonic() - clock,
        "inputs_count": len(current), "inputs_sha256": fingerprint(current),
        "default_modules": len(closure), "production_modules_added": len(added),
        "new_module_counts": {m: actual[m] for m in sorted(added)},
        "all_declarations": len(rows), "added_module_declarations": sum(actual[m] for m in added),
        "local_declarations": actual["local_input"], "added_private": sum(r["name"].startswith("_private.") for r in owned),
        "required_named_declarations": len(REQUIRED),
        "fixed_point_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", raw, re.M)[1]),
        "axiom_sets": dict(collections.Counter(" + ".join(a) or "none" for a in deps.values())),
        "added_axiom_sets": dict(collections.Counter(" + ".join(r["axioms"]) or "none" for r in owned)),
        "new_axioms": 0, "sorryAx": 0, "owned_declarations_digest": digest(catalogue),
        "verifier_initial": initial["script"], "verifier_final": current_local["verify_resume1.py"],
        "all_declarations_digest": digest(targets), "record_bytes_before_summary": sum(p.stat().st_size for p in files),
        "build_warning_count": len(re.findall(r"warning:", (args.tmp / "build.log").read_text())),
    }
    write(HERE / "resume1-verification.json", summary)
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
