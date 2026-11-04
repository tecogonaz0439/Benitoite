"""群Cの入力・既定import・全宣言・義務・検査の記録を照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, ast, collections, hashlib, json, re, time
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
PREFIX = "formal/Benitoite/Release/Refinement/"
NAMES = ["AtInput", "MembershipTargets", "MembershipWiden", "ShapeTargets", "ScopedCallContracts"]
MODULES = {"Benitoite.Release.Refinement."+name for name in NAMES}
SNAPSHOTS = ["docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"]
BASE = "eb289e60a63a0cb238ad4e2a43aaa5ac1a84676e"
ALLOWED = {"propext", "Quot.sound", "Classical.choice"}
def digest(path):
    b = path.read_bytes()
    return {"bytes": len(b), "sha256": hashlib.sha256(b).hexdigest()}
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--record-prefix", default="")
    args = parser.parse_args()
    tick = time.monotonic()
    baseline = json.loads((args.tmp / "inputs.json").read_text())
    files = [f for f in (ROOT / "formal").rglob("*.lean") if ".lake" not in f.parts]
    files += [ROOT/f for f in SNAPSHOTS]
    current = {str(f.relative_to(ROOT)): digest(f)["sha256"] for f in sorted(files)}
    added = sorted(set(current)-set(baseline))
    removed = sorted(set(baseline)-set(current))
    changed = sorted(f for f in baseline if current.get(f) != baseline[f])
    assert set(added) == {PREFIX+name+".lean" for name in ["MembershipWiden", "ScopedCallContracts"]}
    assert not removed
    assert set(changed) == {PREFIX+name+".lean" for name in ["AtInput", "MembershipTargets", "ShapeTargets"]} | set(SNAPSHOTS) | {"formal/Benitoite.lean"}
    visited = set()
    def visit(module):
        if module in visited: return
        source = ROOT / "formal" / (module.replace(".", "/")+".lean")
        assert source.is_file(), module
        visited.add(module)
        for child in re.findall(r"^import (Benitoite(?:\.[\w]+)*)\s*$", source.read_text(), re.M): visit(child)
    visit("Benitoite")
    affected = MODULES | {f.removeprefix("formal/").removesuffix(".lean").replace("/", ".") for f in added}
    assert affected <= visited, "追加・変更モジュールの既定import漏れ"
    for name in NAMES:
        s = (ROOT / (PREFIX+name+".lean")).read_text()
        assert not re.search(r"\bsorry\b|^\s*axiom\b|\bnative_decide\b|\bimplemented_by\b|#eval", s, re.M)
        assert not re.search(r"L50|L40|U02|/Users/|/home/", s)
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert audit["exit"] == 0 and audit["new_axioms"] == 0
    assert audit["rounds"] == 2 and audit["private_and_generated_included"]
    for key, file in [("raw", args.tmp / "obstruction-audit.log"), ("input", args.tmp / "obstruction-audit.lean"),
                      ("target_list", args.tmp / "targets.txt"), ("added_targets", args.tmp / "added-targets.txt"),
                      ("script", HERE / "audit.py"), ("signatures_file", HERE / "signatures.md"), ("declarations", HERE / "declarations.json")]:
        assert audit[key] == digest(file), key
    assert (args.tmp / "obstruction-audit.lean").read_text() == (HERE / "contracts.lean").read_text()+(HERE / "audit-tail.lean").read_text()
    declarations = json.loads((HERE / "declarations.json").read_text())
    assert len(declarations) == audit["targets"] == (219 if args.record_prefix else 218)
    assert {d["name"] for d in declarations} == set((args.tmp / "targets.txt").read_text().splitlines())
    assert all(set(d["axioms"]) <= ALLOWED for d in declarations)
    assert dict(collections.Counter(d["module"] for d in declarations)) == audit["module_counts"]
    assert set(audit["module_counts"]) == MODULES
    assert any(d["name"].startswith("_private.") for d in declarations)
    assert any(d["line"] == 0 for d in declarations)
    added_names = set((args.tmp / "added-targets.txt").read_text().splitlines())
    recovered = audit["recovered_baseline"]
    assert recovered["exit"] == 0 and recovered["declarations"] == 91
    assert recovered["input"] == digest(args.tmp / "AtInputBefore.lean")
    assert recovered["raw"] == digest(args.tmp / "AtInputBefore.log")
    assert len(added_names) == audit["added_declarations"] == (102 if args.record_prefix else 101)
    assert added_names <= {d["name"] for d in declarations}
    result_text = (HERE / "results.md").read_text().split("## 再開1")[-1] if args.record_prefix else (HERE / "results.md").read_text()
    new_declarations = [d for d in declarations if d["name"] in added_names]
    counts = collections.Counter(d["kind"] for d in new_declarations)
    assert f"定理{counts['theorem']}・定義{counts['definition']}" in result_text
    for module, count in audit["added_module_counts"].items():
        assert f"| {module.rsplit('.',1)[1]} | {count} |" in result_text
    assert f"| 計 | {len(added_names)} |" in result_text
    public_count = sum(d["line"] > 0 and not d["name"].startswith("_private.") for d in new_declarations)
    assert public_count == (17 if args.record_prefix else 16)
    assert f"{public_count}本" in result_text
    for name in ["build", "dry-run", "work"]:
        record = json.loads((HERE / (args.record_prefix+name+"-check.json")).read_text())
        assert record["exit"] == 0
        assert record["raw"] == digest(args.tmp / (name+".log"))
        if name == "build":
            assert record["command"] == ["lake", "build"] and record["cwd"] == "formal"
            start = datetime.fromisoformat(record["start_utc"]).timestamp()
            assert all((ROOT/f).stat().st_mtime <= start for f in added+changed), "ビルド後のソース変更"
        else:
            assert record["base"] == BASE and record["runs"] == 1
            command = ["scripts/check.sh", "--level", "work", "--base", BASE]
            if name == "dry-run": command.append("--dry-run")
            assert record["command"] == command
    work = (args.tmp / "work.log").read_text()
    for text in ["== spec_tally", "== spec_examples", "7 passed; 0 failed; 0 ignored", "== formal_build", "selected checks passed"]:
        assert text in work, text
    for prefix, count in [("O", 33), ("H", 31)]:
        ids = re.findall(r"^\| ("+prefix+r"\d+) \|", (HERE / "obligations.md").read_text(), re.M)
        assert len(ids) == len(set(ids)) == count
    coverage = (HERE / "coverage.md").read_text()
    assert len(re.findall(r"^\| (?:var|const|fnRef|prim|lam|dependentLam|closure|con|list|op|raise|loc|mapV|setV|bytesV|dict|super|externalRef|externalHandle|pathBases|scopePattern|checkedAt|atError|checked|checkedRequest) \|", coverage, re.M)) == 25
    assert len(re.findall(r"^\| (?:V_Sub|V_Normal|V_Refine) \|", coverage, re.M)) == 3
    assert len(re.findall(r"^\| (?:Membership\.|ShapeOk\.)", (HERE / "transplants.md").read_text(), re.M)) == 9
    links = 0
    for f in HERE.iterdir():
        if not f.is_file(): continue
        assert f.stat().st_size <= 100000, f.name
        if f.suffix == ".py": ast.parse(f.read_text())
        if f.suffix != ".md": continue
        s = f.read_text()
        assert not re.search(r"(?<![\w])/(?:Users|home|private/tmp)/|\]\([^)]*docs/todo", s), f.name
        for link in re.findall(r"\]\(([^)]+)\)", s):
            if "://" not in link and not link.startswith("#"):
                assert (f.parent/link.split("#")[0]).exists() or link == "verification.json", link
                links += 1
    total = sum(f.stat().st_size for f in HERE.iterdir() if f.is_file())
    assert total < 3000000
    final = args.tmp / "final-inputs.json"
    final.write_text(json.dumps(current, indent=2)+"\n")
    summary = {"exit": 0, "base": BASE, "date_utc": datetime.now(timezone.utc).isoformat(),
        "seconds": time.monotonic()-tick, "record_prefix": args.record_prefix,
        "inputs": len(current), "baseline": digest(args.tmp / "inputs.json"),
        "final_inputs": digest(final), "added_modules": added, "changed": changed, "removed": removed,
        "default_import_modules": len(visited), "affected_modules_in_default_import": sorted(affected),
        "audited": len(declarations), "added_declarations": len(added_names), "obligations": 33, "handoffs": 31,
        "value_syntax": 25, "typing_rules": 29, "closed_inventory": 9, "remaining_inventory": 1,
        "relative_links": links, "group_bytes": total, "script": digest(Path(__file__))}
    (HERE / "verification.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2)+"\n")
    print(json.dumps(summary, ensure_ascii=False))
if __name__ == "__main__": main()
