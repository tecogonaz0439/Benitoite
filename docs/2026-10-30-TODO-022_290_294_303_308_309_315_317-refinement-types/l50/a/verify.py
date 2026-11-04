"""再開3の本番・全宣言・既定import・署名・保存候補・記録を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import ast
import collections
import hashlib
import importlib.util
import json
import re
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PRIOR = ["ScopeCoverage", "MembershipTargets", "ShapeTargets"]
NEW = ["EffectTargets", "ModelConstraints", "ScopeDeclarations", "TargetModelConditions"]
ADDED = PRIOR + NEW
MODULES = {"Benitoite.Release.Refinement." + n for n in ADDED}
PREFIX = "formal/Benitoite/Release/Refinement/"
SNAPSHOTS = {"docs/design/01-spec/01-12-core-calculus.md",
             "docs/design/07-quality/07-04-formal-semantics.md"}


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    start = datetime.now(timezone.utc).isoformat()
    tick = time.monotonic()
    baseline = json.loads((args.tmp / "resume3-start-inputs.json").read_text())
    production = {str(p.relative_to(ROOT)): digest(p)
                  for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts}
    current = {**production, **{p: digest(ROOT / p) for p in SNAPSHOTS}}
    added = sorted(set(current) - set(baseline))
    changed = sorted(p for p in baseline if current.get(p) != baseline[p])
    assert not added, added
    assert set(changed) == {PREFIX + "ScopeDeclarations.lean"}, changed
    visited = set()

    def visit(module):
        if module in visited:
            return
        path = ROOT / "formal" / (module.replace(".", "/") + ".lean")
        assert path.is_file(), module
        visited.add(module)
        for child in re.findall(r"^import (Benitoite(?:\.[\w]+)*)\s*$", path.read_text(), re.M):
            visit(child)

    visit("Benitoite")
    assert MODULES <= visited, "追加モジュールが既定importにない"
    summary = json.loads((HERE / "audit-summary.json").read_text())
    assert summary["exit"] == 0 and summary["new_axioms"] == 0
    assert summary["private_and_generated_included"]
    assert summary["raw"] == digest(args.tmp / "obstruction-audit.log")
    assert summary["input"] == digest(args.tmp / "obstruction-audit.lean")
    second = "".join("\n".join(line for line in (HERE / name).read_text().splitlines()
                              if not line.startswith("import ")) + "\n"
                     for name in ["resume1-obstruction.lean", "contracts.lean", "internal-save.lean"])
    assert (args.tmp / "obstruction-audit.lean").read_text() == (
        (HERE / "obstruction.lean").read_text() + second + (HERE / "audit-tail.lean").read_text())
    assert summary["target_list"] == digest(args.tmp / "targets.txt")
    assert summary["script"] == digest(HERE / "audit.py")
    assert summary["signatures_file"] == digest(HERE / "signatures.md")
    assert summary["signatures"] == 11 and summary["contracts"] == 24
    declarations = json.loads((HERE / "declarations.json").read_text())
    assert summary["declarations"] == digest(HERE / "declarations.json")
    assert len(declarations) == summary["targets"]
    assert {d["name"] for d in declarations} == set((args.tmp / "targets.txt").read_text().splitlines())
    assert all(set(d["axioms"]) <= {"propext", "Quot.sound", "Classical.choice"} for d in declarations)
    assert set(summary["module_counts"]) == MODULES | {"local_records"}
    assert dict(collections.Counter(d["module"] for d in declarations)) == summary["module_counts"]
    assert summary["production_added_declarations"] == sum(d["module"] != "local_records" for d in declarations)
    assert any(d["name"].startswith("_private.") for d in declarations)
    assert any(d["kind"] == "recursor" for d in declarations)
    names = {d["name"] for d in declarations}
    for prefix, entries in {
        "L50ShapeObstruction.": ["counterexample", "f04_false", "not_namesWF", "f04_with_names"],
        "L50ObservationObstruction.": ["counterexample", "f05_false", "not_namesWF", "f05_with_names"],
        "L50Contracts.": ["F06Current", "F06Resolve", "F07Pure", "F07IO", "F08", "F09Model", "F09File", "F09Http"],
        "L50InternalSave.": ["Detail", "save", "save_exact", "Stored"],
    }.items():
        assert all(prefix + entry in names for entry in entries)
    for file in [PREFIX + n + ".lean" for n in ADDED] + [str((HERE / n).relative_to(ROOT)) for n in
            ["obstruction.lean", "resume1-obstruction.lean", "contracts.lean", "internal-save.lean"]]:
        assert not re.search(r"\bsorry\b|^\s*axiom\b|\bnative_decide\b|\bimplemented_by\b|#eval",
                             (ROOT / file).read_text(), re.M), file
    build = json.loads((HERE / "build-check.json").read_text())
    work = json.loads((HERE / "work-check.json").read_text())
    assert build["command"] == ["lake", "build"] and build["cwd"] == "formal" and build["exit"] == 0
    assert build["runs"] == 1 and build["raw"] == digest(args.tmp / "build.log")
    assert re.search(r"Build completed successfully \(\d+ jobs\)", (args.tmp / "build.log").read_text())
    assert work["command"] == ["scripts/check.sh", "--level", "work", "--base",
                               "e7caabb2a9682b51ffe2e50081e8e3cbd57b3f3f"]
    assert work["exit"] == 0 and work["runs"] == 1 and work["raw"] == digest(args.tmp / "work.log")
    work_text = (args.tmp / "work.log").read_text()
    assert "7 passed; 0 failed; 0 ignored" in work_text
    assert "== spec_examples" in work_text and "== formal_build" in work_text
    assert "selected checks passed" in work_text
    assert len(re.findall(r"^\| O\d{3} \|", (HERE / "obligations.md").read_text(), re.M)) == 33
    assert len(re.findall(r"^\| H\d{2} \|", (HERE / "handoffs.md").read_text(), re.M)) == 31
    spec = importlib.util.spec_from_file_location("readers", HERE / "reader-inventory.py")
    readers = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(readers)
    inventory = readers.collect()
    assert inventory == json.loads((HERE / "reader-inventory.json").read_text())
    links = 0
    forbidden = re.compile(re.escape("/" + "Users/") + "|" + re.escape("/" + "private/tmp/") + r"|\]\([^)]*docs/todo")
    for path in HERE.iterdir():
        if not path.is_file():
            continue
        assert path.stat().st_size <= 100000, path.name
        assert not forbidden.search(path.read_text()), path.name
        if path.suffix == ".py":
            ast.parse(path.read_text())
        if path.suffix == ".md":
            for link in re.findall(r"\[[^\]]+\]\(([^)]+)\)", path.read_text()):
                if link.startswith(("https:", "http:", "#")):
                    continue
                assert not link.startswith("/"), link
                assert (path.parent / link.split("#", 1)[0]).exists(), link
                links += 1
    (args.tmp / "inputs.json").write_text(json.dumps(current, indent=2) + "\n")
    record = {"start_utc": start, "end_utc": datetime.now(timezone.utc).isoformat(),
              "seconds": time.monotonic() - tick, "exit": 0,
              "production_source_files": len(production), "changed_existing_files": changed,
              "resume3_added_production_modules": added, "group_added_modules": ADDED,
              "default_import_modules": len(visited), "new_modules_in_default_import_checked": True,
              "baseline_manifest": digest(args.tmp / "resume3-start-inputs.json"),
              "current_manifest": digest(args.tmp / "inputs.json"),
              "declarations": len(declarations), "production_declarations": summary["production_added_declarations"],
              "obligations": 33, "handoffs": 31, "reader_files": inventory["file_count"],
              "reader_lines": inventory["line_count"],
              "default_build_exit": 0, "work_exit": 0, "work_runs": 1,
              "group_complete": True, "independent_review": "RV-L50.a は可（軽1・情報5）。再開3の処置の受け入れは取りまとめの担当",
              "relative_links": links, "script": digest(Path(__file__))}
    (HERE / "verification.json").write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(record, ensure_ascii=False))


if __name__ == "__main__":
    main()
