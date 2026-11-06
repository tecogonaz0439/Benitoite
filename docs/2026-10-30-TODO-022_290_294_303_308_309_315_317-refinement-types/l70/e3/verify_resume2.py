#!/usr/bin/env python3
"""再開1と再開2の全追加宣言・既定 import・許可公理・保護範囲・記録を照合する。"""
import argparse
import collections
import datetime
import json
import re
import time
from pathlib import Path
from inventory import HERE, ROOT, digest, fingerprint, inputs, write
from inventory_resume2 import B_WORK, audit_source, import_closure, local_inputs, modules, snapshot

ALLOWED_AXIOMS = {"propext", "Classical.choice", "Quot.sound"}
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
    "Surface.StandardSupport.complete", "Surface.StandardSupport.primitive",
    "Surface.DeclarationAgreement.realizes_of_check",
    "Surface.CheckedMainExamples.input_sound", "Surface.CheckedMainExamples.signatures_agree",
    "Surface.CheckedMainExamples.wrong_signature_rejected", "Surface.CheckedMainExamples.realizes", "Surface.CheckedMainExamples.checker_succeeds",
    "Surface.CheckedMainExamples.acceptance_succeeds", "Surface.CheckedMainExamples.entry_succeeds",
    "Surface.CheckedMainExamples.main_guarantees",
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    start = datetime.datetime.now().astimezone().isoformat()
    clock = time.monotonic()
    current, local = inputs(), local_inputs()
    captured = json.loads((HERE / "resume2-inputs.json").read_text())
    assert captured == snapshot(), "検査時の入力又は台本と一致しない"
    added, closure = set(modules()), import_closure()
    previous = json.loads((HERE / "resume1-inputs.json").read_text())
    assert set(previous["modules"]) < added, "再開1の全追加モジュールを保持する"
    assert added <= closure, sorted(added - closure)
    assert all("formal/" + n.replace(".", "/") + ".lean" in current for n in closure)
    records = {n: json.loads((HERE / ("resume2-" + n + ".json")).read_text()) for n in ("build", "audit")}
    for name, record in records.items():
        assert record["base"] == B_WORK
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
    assert all(set(a) <= ALLOWED_AXIOMS for a in deps.values())
    assert {PREFIX + n for n in REQUIRED} <= set(declared)
    # 台帳の全件性は Lean の評価ではなく、ソースの構成子と証明の各場合を照合する。
    refinement = ROOT / "formal/Benitoite/Release/Refinement"
    ledger = (refinement / "StandardModelSignatures.lean").read_text()
    support = (refinement / "SurfaceStandardSupport.lean").read_text()
    primitive_rows = re.findall(r"^  \| (p[0-9]{3})\s*$", ledger, re.M)
    support_cases = re.findall(r"^  case (p[0-9]{3}) =>", support, re.M)
    assert primitive_rows and collections.Counter(primitive_rows) == collections.Counter(support_cases)
    atom_source = support.split("def atoms : List Atom :=", 1)[1].split("private def Supported", 1)[0]
    atom_count = len(re.findall(r"\.(?:rho|name)\b", atom_source))
    assert atom_count == 12
    printed_counts = re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", raw, re.M)
    counts = {m: int(n) for m, n in printed_counts}
    assert len(counts) == len(printed_counts) and set(counts) == closure
    actual = collections.Counter(m for m, _ in rows)
    assert all(counts[m] == actual[m] for m in closure)
    local_names = {n for m, n in rows if m == "local_input"}
    local_printed = re.findall(r"^OWN_DECL (\S+) (.+)$", raw, re.M)
    assert {n for _, n in local_printed} == local_names
    assert len(local_printed) == len(local_names) == int(re.search(r"^OWN_COUNT (\d+)$", raw, re.M)[1])
    owned = [{"module": m, "name": n, "axioms": deps[n]} for m, n in rows if m in added or m == "local_input"]
    # 匿名の example は既定ビルドで検査されるが、環境へ宣言を登録しない。
    empty = {"Benitoite.Release.Refinement.SafeCheckPreservationExamples"}
    assert {m for m in added if actual[m] == 0} == empty
    assert all(re.search(r"^example\s", (ROOT / "formal" / (m.replace(".", "/") + ".lean")).read_text(), re.M)
               for m in empty)
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
        "status": "再開2の既定ビルド・全公理監査・照合が成功", "base": B_WORK,
        "started": start, "ended": datetime.datetime.now().astimezone().isoformat(), "seconds": time.monotonic() - clock,
        "inputs_count": len(current), "inputs_sha256": fingerprint(current),
        "local_inputs": local, "default_modules": len(closure), "production_modules_added": len(added),
        "new_module_counts": {m: actual[m] for m in sorted(added)},
        "all_declarations": len(rows), "added_module_declarations": sum(actual[m] for m in added),
        "local_declarations": actual["local_input"], "added_private": sum(r["name"].startswith("_private.") for r in owned),
        "required_named_declarations": len(REQUIRED),
        "primitive_rows": len(primitive_rows), "support_atoms": atom_count,
        "fixed_point_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", raw, re.M)[1]),
        "axiom_sets": dict(collections.Counter(" + ".join(a) or "none" for a in deps.values())),
        "added_axiom_sets": dict(collections.Counter(" + ".join(r["axioms"]) or "none" for r in owned)),
        "new_axioms": 0, "sorryAx": 0, "owned_declarations_digest": digest(catalogue),
        "all_declarations_digest": digest(targets), "record_bytes_before_summary": sum(p.stat().st_size for p in files),
        "build_warning_count": len(re.findall(r"warning:", (args.tmp / "build.log").read_text())),
    }
    path = HERE / "resume2-verification.json"
    assert not path.exists(), "既存の照合記録は上書きしない"
    write(path, summary)
    assert path.stat().st_size <= 100_000
    assert sum(p.stat().st_size for p in HERE.rglob("*") if p.is_file() and "__pycache__" not in p.parts) <= 5_000_000
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
