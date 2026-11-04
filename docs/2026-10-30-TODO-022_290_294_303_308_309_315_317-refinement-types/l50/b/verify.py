"""群Bの変更範囲・既定import・監査と検査の記録・義務を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import ast
import collections
import hashlib
import json
import re
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREFIX = "formal/Benitoite/Release/Refinement/"
NAMES = ["ScopeCoverage", "MembershipTargets", "EffectTargets"]
MODULES = {"Benitoite.Release.Refinement." + n for n in NAMES}
SNAPSHOTS = ["docs/design/01-spec/01-12-core-calculus.md",
             "docs/design/07-quality/07-04-formal-semantics.md"]
BASE = "6c8ec4247893fa0013ec74ffabe8e33bc55a0678"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    tick = time.monotonic()
    baseline = json.loads((args.tmp / "baseline.json").read_text())
    files = [p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts]
    files += [ROOT / p for p in SNAPSHOTS]
    current = {str(p.relative_to(ROOT)): digest(p)["sha256"] for p in sorted(files)}
    added = sorted(set(current) - set(baseline))
    removed = sorted(set(baseline) - set(current))
    changed = sorted(p for p in baseline if current.get(p) != baseline[p])
    assert not added and not removed
    assert set(changed) == {PREFIX + n + ".lean" for n in NAMES} | set(SNAPSHOTS), changed
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
    affected = MODULES | {p.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
                          for p in added if p.endswith(".lean")}
    assert affected <= visited, "今回のモジュールが既定importにない"
    for file in [PREFIX + n + ".lean" for n in NAMES]:
        text = (ROOT / file).read_text()
        assert not re.search(r"\bsorry\b|^\s*axiom\b|\bnative_decide\b|\bimplemented_by\b|#eval", text, re.M)
        assert not re.search(r"L50|L40|U02|/Users/|/home/", text)
    summary = json.loads((HERE / "audit-summary.json").read_text())
    assert summary["exit"] == 0 and summary["new_axioms"] == 0
    assert summary["private_and_generated_included"] and summary["rounds"] == 2
    assert summary["raw"] == digest(args.tmp / "obstruction-audit.log")
    assert summary["input"] == digest(args.tmp / "obstruction-audit.lean")
    assert (args.tmp / "obstruction-audit.lean").read_text() == (
        (HERE / "contracts.lean").read_text() + (HERE / "audit-tail.lean").read_text())
    assert summary["target_list"] == digest(args.tmp / "targets.txt")
    assert summary["script"] == digest(HERE / "audit.py")
    assert summary["signatures_file"] == digest(HERE / "signatures.md")
    assert summary["declarations"] == digest(HERE / "declarations.json")
    declarations = json.loads((HERE / "declarations.json").read_text())
    assert len(declarations) == summary["targets"] == 56
    assert {d["name"] for d in declarations} == set((args.tmp / "targets.txt").read_text().splitlines())
    assert all(set(d["axioms"]) <= ALLOWED for d in declarations)
    assert dict(collections.Counter(d["module"] for d in declarations)) == summary["module_counts"]
    assert set(summary["module_counts"]) == MODULES
    assert any(d["name"].startswith("_private.") for d in declarations)
    assert any(d["kind"] == "recursor" for d in declarations)
    old_names = {d["name"] for d in json.loads((HERE.parent / "a/declarations.json").read_text())}
    new_declarations = [d for d in declarations if d["name"] not in old_names]
    assert len(new_declarations) == 22
    generated = [d for d in new_declarations if d["line"] == 0]
    assert len(generated) == 2
    for kind in ["dry-run", "work", "local-scope", "local-member", "local-effect"]:
        record = json.loads((HERE / (kind + "-check.json")).read_text())
        assert record["exit"] == 0 and record["runs"] == 1
        assert record["base"] == BASE
        assert record["raw"] == digest(args.tmp / (kind + ".log"))
        if kind in ["dry-run", "work"]:
            expected = ["scripts/check.sh", "--level", "work", "--base", BASE]
            if kind == "dry-run":
                expected += ["--dry-run"]
            assert record["command"] == expected
        else:
            assert record["raw"]["bytes"] == 0
            assert record["command"][:5] == ["lake", "env", "lean", "-M", "12288"]
    work = (args.tmp / "work.log").read_text()
    for needle in ["== spec_tally", "== spec_examples", "7 passed; 0 failed; 0 ignored",
                   "== formal_build", "selected checks passed"]:
        assert needle in work, needle
    policy = (ROOT / "scripts/check.sh").read_text()
    assert "cd formal && lake build" in policy
    assert "declaration uses .sorry." in policy
    for prefix, number in [("O", 33), ("H", 31)]:
        ids = re.findall(r"^\| (" + prefix + r"\d+) \|", (HERE / "obligations.md").read_text(), re.M)
        assert len(ids) == len(set(ids)) == number
    tids = re.findall(r"^\| (T\d+) \|", (HERE / "transplants.md").read_text(), re.M)
    assert tids == [f"T{i:02d}" for i in range(1, 15)]
    links = 0
    for file in HERE.iterdir():
        if not file.is_file():
            continue
        assert file.stat().st_size <= 100000, file.name
        if file.suffix == ".py":
            ast.parse(file.read_text())
        if file.suffix != ".md":
            continue
        text = file.read_text()
        assert not re.search(r"(?<![\w])/(?:Users|home|private/tmp)/|\]\([^)]*docs/todo", text), file.name
        for target in re.findall(r"\]\(([^)]+)\)", text):
            if "://" not in target and not target.startswith("#"):
                assert ((file.parent / target.split("#")[0]).exists()
                        or target == "verification.json"), target
                links += 1
    total = sum(p.stat().st_size for p in HERE.iterdir() if p.is_file())
    assert total < 1000000
    final = args.tmp / "final-inputs.json"
    final.write_text(json.dumps(current, indent=2) + "\n")
    result = {"exit": 0, "date_utc": datetime.now(timezone.utc).isoformat(),
              "seconds": time.monotonic() - tick, "base": BASE,
              "inputs": len(current), "baseline": digest(args.tmp / "baseline.json"),
              "final_inputs": digest(final), "added_modules": added, "removed": removed,
              "changed": changed, "default_import_modules": len(visited),
              "affected_modules_in_default_import": sorted(affected),
              "audited": len(declarations), "new_declarations": len(new_declarations),
              "new_public_theorems": len(new_declarations) - len(generated),
              "new_generated_theorems": len(generated),
              "obligations": 33, "handoffs": 31, "transplants": 14,
              "relative_links": links, "group_bytes": total, "script": digest(Path(__file__))}
    (HERE / "verification.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
