"""既定import・全宣言の監査・実ソース・義務・一度のworkを照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse, ast, hashlib, json, re, subprocess, sys, time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
BASE = "548d3fd94a5f1a171c9bc749b3408f8a9f3c08f8"
ENGINEERING_ID = r"\b(?:L\d{2}(?:\.\d+[a-z]?)?|B\d{2}(?:-\d+)?|O\d{3}|TODO-\d{3}|RV-[A-Za-z0-9.-]+)\b"


def digest(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()
    args.tmp.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    started = datetime.now(timezone.utc).isoformat()
    new = json.loads((HERE / "modules-r1.json").read_text())
    assert len(new) == len(set(new)) and new
    default = (ROOT / "formal/Benitoite.lean").read_text().splitlines()
    audit = json.loads((HERE / ("audit-summary-" + args.tag + ".json")).read_text())
    assert audit["exit"] == 0 and audit["new_axioms"] == 0 and not audit["inventory_only"]
    assert set(audit["new_modules"]) == set(new) and audit["local_records"] == 0
    baseline = json.loads((HERE / "audit-summary.json").read_text())
    original = set(json.loads((HERE / "modules.json").read_text()))
    frozen = json.loads((HERE / "r1-start.json").read_text())
    updates = json.loads((HERE / "r1-input-updates.json").read_text())
    observed = {item["path"]: item for item in updates["changes"]}
    shared_docs = {str((HERE.parents[1] / "plan.md").relative_to(ROOT)),
                   str((HERE.parent / "detail.md").relative_to(ROOT))}
    assert set(observed) <= shared_docs and not updates["agent_edited"]
    retained = 0
    for relative, expected in frozen["files"].items():
        actual = digest(ROOT / relative)
        if actual == expected:
            retained += 1
        else:
            assert relative in observed, relative
            assert observed[relative]["before"] == expected, relative
            assert observed[relative]["current"] == actual, relative
    assert set(baseline["modules"]) <= set(audit["modules"])
    assert set(audit["modules"]) - set(baseline["modules"]) == {
        "Benitoite.Release.Refinement." + name for name in set(new) - original}
    for key in audit["axiom_sets"]:
        assert set(key.split(" + ")) <= {"none", "propext", "Quot.sound", "Classical.choice"}
    for relative, expected in audit["source_inputs"].items():
        assert digest(ROOT / relative) == expected, relative
    previous_sources = 0
    for checkpoint in HERE.glob("audit-summary-r1-*.json"):
        previous = json.loads(checkpoint.read_text())
        for relative, expected in previous["source_inputs"].items():
            data = (ROOT / relative).read_bytes()
            if relative == "formal/Benitoite.lean":
                data = data[:expected["bytes"]]
            assert len(data) == expected["bytes"], (checkpoint.name, relative)
            assert hashlib.sha256(data).hexdigest() == expected["sha256"], (checkpoint.name, relative)
            previous_sources += 1
    content_path = HERE / ("content-checks-" + args.tag + ".json")
    content_checks = json.loads(content_path.read_text()) if content_path.exists() else {"rows": []}
    content_rows = {row["module"]: row for row in content_checks["rows"]}
    checked_content = []
    declarations = {}
    files = [ROOT / "formal/Benitoite.lean"]
    for name in new:
        module = "Benitoite.Release.Refinement." + name
        assert "import " + module in default, name
        path = ROOT / "formal/Benitoite/Release/Refinement" / (name + ".lean")
        files.append(path)
        source = path.read_text()
        assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval", source), name
        assert not re.search(ENGINEERING_ID + r"|/Users/", source), name
        recorded = json.loads((HERE / ("declarations-" + args.tag + "-" + name + ".json")).read_text())
        assert recorded["module"] == module
        assert recorded["count"] == audit["new_modules"][name] == len(set(recorded["names"]))
        olean = ROOT / "formal/.lake/build/lib/lean/Benitoite/Release/Refinement" / (name + ".olean")
        assert olean.exists(), name
        if olean.stat().st_mtime < path.stat().st_mtime:
            row = content_rows[name]
            setup = ROOT / "formal/.lake/build/ir/Benitoite/Release/Refinement" / (name + ".setup.json")
            assert content_checks["exit"] == 0 and row["source"] == digest(path), name
            assert row["cached"] == row["fresh"] == digest(olean), name
            assert row["setup"] == digest(setup), name
            checked_content.append(row["check_label"])
        named = re.findall(r"^(private )?(theorem|def|inductive|structure) ([^\s{(:]+)", source, re.M)
        declarations[name] = {"environment": recorded["count"],
                              "public": [n for private, _, n in named if not private],
                              "named_private": sum(bool(private) for private, _, _ in named),
                              "anonymous_examples": len(re.findall(r"^example\b", source, re.M))}
    (HERE / ("declarations-" + args.tag + ".json")).write_text(json.dumps(declarations, ensure_ascii=False, indent=2) + "\n")
    obligations = (HERE / "obligations.md").read_text()
    ids = re.findall(r"^\| (O\d{3}) \|", obligations, re.M)
    detail = (HERE.parent / "detail.md").read_text()
    assert len(ids) == len(set(ids)) == 64
    assert set(ids) == set(re.findall(r"^\| (O\d{3}) \|", detail, re.M))
    checks = []
    targeted = []
    for path in sorted(HERE.glob("checks-r1*.json")):
        rows = json.loads(path.read_text())
        assert isinstance(rows, list), path.name
        checks.extend(rows)
        for row in rows:
            command = row["command"]
            if command[:2] == ["lake", "build"]:
                assert row["cwd"] == "formal/"
                if command != ["lake", "build"]:
                    targeted.append((path.name, row["label"], row["start"], tuple(command), row["exit"]))
            if command[:3] == ["lake", "env", "lean"]:
                assert row["cwd"] == "formal/" and command[3:5] == ["-M", "12288"]
    deviations = json.loads((HERE / "command-deviations-r1.json").read_text())
    expected_targets = [(deviations["record"], row["label"], row["start"], tuple(row["command"]), row["exit"])
                        for row in deviations["executions"]]
    assert deviations["count"] == len(expected_targets) == 23
    assert sorted(targeted) == sorted(expected_targets)
    assert deviations["later_deviations"] == 0
    # Repeated labels retain distinct attempts in the append-only record.
    assert len({(row["label"], row["start"]) for row in checks}) == len(checks)
    for label in checked_content:
        rows = [row for row in checks if row["label"] == label]
        assert rows and max(rows, key=lambda row: row["end"])["exit"] == 0, label
    assert not any("check.sh" in arg for row in checks for arg in row["command"])
    audit_runs = [row for row in checks if row["label"].startswith(args.tag + "-axioms")]
    assert audit_runs and max(audit_runs, key=lambda row: row["end"])["exit"] == 0
    old_checks = json.loads((HERE / "checks.json").read_text())
    command = ["scripts/check.sh", "--level", "work", "--base", BASE]
    assert sum(row["command"] == command for row in old_checks) == 1
    source_path = HERE / ("sources-" + args.tag + ".json")
    if not source_path.exists():
        source_path = HERE / "sources-r1.json"
    if not source_path.exists():
        source_path = HERE / "sources.json"
    sources = json.loads(source_path.read_text())
    assert len(sources["rows"]) == 328
    identifiers = [row["api"] if isinstance(row, dict) else row[0] for row in sources["rows"]]
    assert len(set(identifiers)) == 328
    original_sources = json.loads((HERE / "sources.json").read_text())
    assert set(identifiers) == {row[0] for row in original_sources["rows"]}
    for relative, expected in original_sources["inputs"].items():
        assert digest(ROOT / relative) == expected, relative
    original_inputs = json.loads((HERE / "inputs.json").read_text())
    baseline_manifest = HERE / "r1-formal-baseline.txt"
    assert digest(baseline_manifest) == original_inputs["manifest"]
    for line in baseline_manifest.read_text().splitlines():
        sha, relative = line.split("  ", 1)
        current = ROOT / relative
        if relative == "formal/Benitoite.lean":
            count = original_inputs["files"][relative]["bytes"]
            assert hashlib.sha256(current.read_bytes()[:count]).hexdigest() == sha
        else:
            assert digest(current)["sha256"] == sha, relative
    paths = sorted(path for path in (ROOT / "formal").rglob("*.lean") if ".lake" not in path.parts)
    baseline_inputs = original_inputs
    assert len(paths) == baseline_inputs["lean_sources"] + len(set(new) - original)
    manifest = args.tmp / ("source-manifest-" + args.tag + ".txt")
    manifest.write_text("".join(digest(path)["sha256"] + "  " + str(path.relative_to(ROOT)) + "\n" for path in paths))
    files += [ROOT / "docs/design/01-spec/01-12-core-calculus.md",
              ROOT / "docs/design/07-quality/07-04-formal-semantics.md"]
    for path in HERE.iterdir():
        if not path.is_file():
            continue
        assert path.stat().st_size <= 100000, path.name
        text = path.read_text()
        assert str(ROOT) not in text, path.name
        assert not re.search(r"\]\([^)]*docs/todo", text), path.name
        if path.suffix == ".py":
            ast.parse(text, filename=path.name)
        if path.suffix == ".md":
            for link in re.findall(r"\]\(([^)]+)\)", text):
                target = link.split("#")[0]
                if "://" not in link and target:
                    assert (path.parent / target).exists(), (path.name, link)
    brief = {"exit": 0, "new_modules": len(new), "declarations": audit["added_declarations"],
             "retained_frozen_inputs": retained, "updated_document_inputs": len(observed),
             "checkpoint_source_checks": previous_sources,
             "content_checked_artifacts": len(checked_content),
             "recorded_command_deviations": len(targeted), "new_command_deviations": 0,
             "source_record": source_path.name, "source_identification": digest(source_path),
             "ordinary_counts": sources.get("counts", {}), "relation_counts": sources.get("additional_relation_counts", {}),
             "lean_sources": len(paths), "obligations": len(ids), "apis": 328, "resumed_declarations": audit["resumed_declarations"],
             "public": sum(len(item["public"]) for item in declarations.values()),
             "private": sum(item["named_private"] for item in declarations.values()),
             "examples": sum(item["anonymous_examples"] for item in declarations.values())}
    output = args.tmp / "verify.log"
    output.write_text(json.dumps(brief, ensure_ascii=False) + "\n")
    result = {"base": BASE, "command": ["python3", str((HERE / "verify-r1.py").relative_to(ROOT)),
               "--tmp", "<tmp>", "--tag", args.tag], "exit": 0, "started": started,
              "ended": datetime.now(timezone.utc).isoformat(), "seconds": time.monotonic() - start,
              "new_modules": new, "added_declarations": audit["added_declarations"],
              "lean_sources": len(paths), "manifest": digest(manifest), "output": digest(output),
              "obligations": len(ids), "source_record": source_path.name, "source_identification": digest(source_path),
              "ordinary_counts": sources.get("counts", {}), "relation_counts": sources.get("additional_relation_counts", {}),
              "files": {str(path.relative_to(ROOT)): digest(path) for path in files},
              "records": {path.name: digest(path) for path in HERE.iterdir()
                          if path.is_file() and path.name != "global-inputs-" + args.tag + ".json"}}
    (HERE / ("global-inputs-" + args.tag + ".json")).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(brief, ensure_ascii=False))


if __name__ == "__main__":
    main()
