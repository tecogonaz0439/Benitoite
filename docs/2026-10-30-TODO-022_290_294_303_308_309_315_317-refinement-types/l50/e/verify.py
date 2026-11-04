"""全入力の変更、全追加モジュールの既定 import、監査と検査の記録を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import ast
import collections
import json
import re
import time
from audit import HERE, ROOT, ALLOWED, digest, inputs

BASE = "7ece2393f5585203556d07d4851b6b946abb0e92"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--record-prefix", default="")
    args = parser.parse_args()
    tick = time.monotonic()
    baseline = json.loads((args.tmp / "inputs.json").read_text())
    current = inputs()
    added = sorted(set(current) - set(baseline))
    removed = sorted(set(baseline) - set(current))
    changed = sorted(p for p in baseline if current.get(p) != baseline[p])
    assert not removed
    resume_changed = []
    resume_baseline = None
    if args.record_prefix:
        resume_source = args.tmp / "resume-start-inputs.json"
        previous = json.loads((args.tmp / "resume-start-verification.json").read_text())
        assert digest(resume_source) == previous["final_inputs"]
        resume_baseline = digest(resume_source)
        resume_start = json.loads(resume_source.read_text())
        assert set(current) == set(resume_start)
        resume_changed = sorted(p for p in current if current[p] != resume_start[p])
        expected_resume = {"formal/Benitoite/Release/Refinement/" + n + ".lean" for n in
                           ["AtInput", "ScopeDelta", "RequestDelta"]}
        expected_resume |= {"docs/design/01-spec/01-12-core-calculus.md",
                            "docs/design/07-quality/07-04-formal-semantics.md"}
        assert set(resume_changed) == expected_resume
    new_names = {"ScopeSignatures", "ScopeSignatureFormation", "ScopeDelta", "RequestDelta"}
    expected_new = {"formal/Benitoite/Release/Refinement/" + n + ".lean" for n in new_names}
    assert set(added) == expected_new
    allowed = {"formal/Benitoite.lean", "docs/design/01-spec/01-12-core-calculus.md",
               "docs/design/07-quality/07-04-formal-semantics.md"}
    allowed |= {"formal/Benitoite/Release/Refinement/" + n + ".lean" for n in
                ["AtInput", "TargetTable", "ScopeDeclarations"]}
    assert set(changed) == allowed
    affected = {p.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
                for p in added + changed if p.startswith("formal/Benitoite/Release/Refinement/")}
    assert affected == set(json.loads((HERE / "modules.json").read_text()))
    new_modules = {p.removeprefix("formal/").removesuffix(".lean").replace("/", ".") for p in added}
    assert new_modules == set(json.loads((HERE / "new-modules.json").read_text()))
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
    assert affected <= visited, "全追加・変更モジュールが既定 import に入っていない"
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert audit["exit"] == 0 and audit["new_axioms"] == 0 and audit["private_and_generated_included"]
    for key, path in [("raw", args.tmp / "audit.log"), ("input", args.tmp / "audit.lean"),
                      ("target_list", args.tmp / "targets.txt"), ("new_module_targets", args.tmp / "new-module-targets.txt"),
                      ("modules", HERE / "modules.json"), ("script", HERE / "audit.py"),
                      ("signatures_file", HERE / "actual-signatures.md")]:
        assert audit[key] == digest(path), key
    declarations = []
    for name, record in audit["declarations"].items():
        assert record == digest(HERE / name)
        declarations += json.loads((HERE / name).read_text())
    assert len(declarations) == audit["targets"]
    assert {d["name"] for d in declarations} == set((args.tmp / "targets.txt").read_text().splitlines())
    assert all(set(d["axioms"]) <= ALLOWED for d in declarations)
    assert dict(collections.Counter(d["module"] for d in declarations)) == audit["module_counts"]
    assert affected <= set(audit["module_counts"])
    assert audit["new_modules"] == digest(HERE / "new-modules.json")
    assert audit["new_module_declarations"] == sum(audit["module_counts"][m] for m in new_modules)
    assert any(d["name"].startswith("_private.") for d in declarations)
    expected_input = (HERE / "contracts.lean").read_text() + (HERE / "audit-tail.lean").read_text().replace(
        "__MODULES__", json.dumps(sorted(affected)))
    assert (args.tmp / "audit.lean").read_text() == expected_input
    for kind in (["build", "work"] if args.record_prefix else ["build", "dry-run", "work"]):
        record = json.loads((HERE / (args.record_prefix + kind + "-check.json")).read_text())
        assert record["exit"] == 0 and record["runs"] == 1 and record["base"] == BASE
        assert record["raw"] == digest(args.tmp / (args.record_prefix + kind + ".log"))
        command = ["lake", "build"] if kind == "build" else ["scripts/check.sh", "--level", "work", "--base", BASE]
        if kind == "dry-run":
            command.append("--dry-run")
        assert command == record["command"]
        if kind == "build":
            stamp = datetime.fromisoformat(record["start_utc"]).timestamp()
            assert all((ROOT / p).stat().st_mtime <= stamp for p in added + changed), "最終 build 後の変更"
    log = (args.tmp / (args.record_prefix + "work.log")).read_text()
    assert "== formal_build" in log and "selected checks passed" in log
    for prefix, count in [("O", 33), ("H", 31)]:
        ids = re.findall(r"^\| (" + prefix + r"\d+) \|", (HERE / "obligations.md").read_text(), re.M)
        assert len(ids) == len(set(ids)) == count
    signatures = (HERE / "signatures.md").read_text()
    assert len(re.findall(r"^\| (?:Reference|File|Http|Scope|Example)\.", signatures, re.M)) == 16
    source_path = ROOT / "formal/Benitoite/Release/Refinement"
    for name in new_names:
        text = (source_path / (name + ".lean")).read_text()
        assert not re.search(r"\b(?:sorry|axiom|native_decide)\b|#eval|L50\.\d", text)
    links = 0
    for path in HERE.iterdir():
        if not path.is_file():
            continue
        assert path.stat().st_size <= 100000, path.name
        if path.suffix == ".py":
            ast.parse(path.read_text())
        if path.suffix == ".md":
            text = path.read_text()
            assert not re.search(r"(?<![\w])/(?:Users|home|private/tmp)/|\]\([^)]*docs/todo", text), path.name
            for link in re.findall(r"\]\(([^)]+)\)", text):
                if "://" not in link and not link.startswith("#"):
                    assert (path.parent / link.split("#")[0]).exists() or link == "verification.json", link
                    links += 1
    total = sum(p.stat().st_size for p in HERE.iterdir() if p.is_file())
    assert total < 3000000
    final = args.tmp / "final-inputs.json"
    final.write_text(json.dumps(current, indent=2) + "\n")
    summary = {"exit": 0, "base": BASE, "date_utc": datetime.now(timezone.utc).isoformat(),
        "seconds": time.monotonic() - tick, "record_prefix": args.record_prefix, "baseline": digest(args.tmp / "inputs.json"),
        "final_inputs": digest(final), "added": added, "changed": changed, "removed": removed,
        "resume_changed": resume_changed, "resume_baseline": resume_baseline,
        "default_import_modules": len(visited), "affected_in_default_import": sorted(affected),
        "declarations": len(declarations), "new_module_declarations": audit["new_module_declarations"],
        "obligations": 33, "handoffs": 31, "signature_rows": 16,
        "relative_links": links, "group_bytes": total, "script": digest(Path(__file__))}
    (HERE / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
