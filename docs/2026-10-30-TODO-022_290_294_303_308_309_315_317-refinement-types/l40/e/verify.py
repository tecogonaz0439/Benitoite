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
    parser.add_argument("--tag", help="再開後の監査タグ。省略時は累積モジュール数が最大の監査を使う")
    args = parser.parse_args()
    if (HERE / "sources-r4-u28.json").exists():
        subprocess.run([sys.executable, str(HERE / "verify-r4.py"),
                        "--tmp", str(args.tmp), "--tag", args.tag or "r4-final"], check=True)
        return
    if (HERE / "modules-r3.json").exists():
        subprocess.run([sys.executable, str(HERE / "verify-r3.py"),
                        "--tmp", str(args.tmp), "--tag", args.tag or "r3-final"], check=True)
        return
    if (HERE / "sources-r2-u28.json").exists():
        subprocess.run([sys.executable, str(HERE / "verify-r2.py"),
                        "--tmp", str(args.tmp), "--tag", args.tag or "r2-final"], check=True)
        return
    if args.tag or (HERE / "modules-r1.json").exists():
        summaries = [json.loads(path.read_text()) for path in HERE.glob("audit-summary-r1-*.json")]
        tag = args.tag or max(summaries, key=lambda item: (item["module_count"], item["tag"]))["tag"]
        subprocess.run([sys.executable, str(HERE / "verify-r1.py"),
                        "--tmp", str(args.tmp), "--tag", tag], check=True)
        return
    args.tmp.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    started = datetime.now(timezone.utc).isoformat()
    subprocess.run([sys.executable, str(HERE / "sources.py")], check=True, capture_output=True)
    new = json.loads((HERE / "modules.json").read_text())
    assert len(new) == len(set(new)) and new
    default = (ROOT / "formal/Benitoite.lean").read_text().splitlines()
    audit = json.loads((HERE / "audit-summary.json").read_text())
    assert audit["exit"] == 0 and audit["new_axioms"] == 0 and not audit["inventory_only"]
    assert set(audit["new_modules"]) == set(new) and audit["local_records"] == 0
    baseline = json.loads((HERE.parent / "d/audit-summary.json").read_text())
    assert set(baseline["modules"]) <= set(audit["modules"])
    assert set(audit["modules"]) - set(baseline["modules"]) == {
        "Benitoite.Release.Refinement." + name for name in new}
    for key in audit["axiom_sets"]:
        assert set(key.split(" + ")) <= {"none", "propext", "Quot.sound", "Classical.choice"}
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
        recorded = json.loads((HERE / ("declarations-" + name + ".json")).read_text())
        assert recorded["module"] == module
        assert recorded["count"] == audit["new_modules"][name] == len(set(recorded["names"]))
        olean = ROOT / "formal/.lake/build/lib/lean/Benitoite/Release/Refinement" / (name + ".olean")
        assert olean.exists() and olean.stat().st_mtime >= path.stat().st_mtime, name
        named = re.findall(r"^(private )?(theorem|def|inductive|structure) ([^\s{(:]+)", source, re.M)
        declarations[name] = {"environment": recorded["count"],
                              "public": [n for private, _, n in named if not private],
                              "named_private": sum(bool(private) for private, _, _ in named),
                              "anonymous_examples": len(re.findall(r"^example\b", source, re.M))}
    (HERE / "declarations.json").write_text(json.dumps(declarations, ensure_ascii=False, indent=2) + "\n")
    obligations = (HERE / "obligations.md").read_text()
    ids = re.findall(r"^\| (O\d{3}) \|", obligations, re.M)
    detail = (HERE.parent / "detail.md").read_text()
    assert len(ids) == len(set(ids)) == 64
    assert set(ids) == set(re.findall(r"^\| (O\d{3}) \|", detail, re.M))
    checks = []
    for path in sorted(HERE.glob("checks*.json")):
        rows = json.loads(path.read_text())
        assert isinstance(rows, list), path.name
        checks.extend(rows)
    assert len({row["label"] for row in checks}) == len(checks)
    command = ["scripts/check.sh", "--level", "work", "--base", BASE]
    work = [row for row in checks if row["command"] == command]
    assert len(work) == 1 and work[0]["exit"] == 0
    assert next(row for row in checks if row["label"] == "axioms")["exit"] == 0
    sources = json.loads((HERE / "sources.json").read_text())
    assert sources["counts"]["apis"] == len(sources["rows"]) == 328
    assert sources["counts"]["modules"] == len(sources["source_modules"]) == 23
    assert sources["counts"]["builtin"] + sources["counts"]["core"] == 328
    assert len({row[0] for row in sources["rows"]}) == 328
    paths = sorted(path for path in (ROOT / "formal").rglob("*.lean") if ".lake" not in path.parts)
    baseline_inputs = json.loads((HERE.parent / "d/inputs.json").read_text())
    assert len(paths) == baseline_inputs["lean_sources"] + len(new)
    manifest = args.tmp / "source-manifest.txt"
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
             "lean_sources": len(paths), "obligations": len(ids), "apis": 328,
             "public": sum(len(item["public"]) for item in declarations.values()),
             "private": sum(item["named_private"] for item in declarations.values()),
             "examples": sum(item["anonymous_examples"] for item in declarations.values())}
    output = args.tmp / "verify.log"
    output.write_text(json.dumps(brief, ensure_ascii=False) + "\n")
    result = {"base": BASE, "command": ["python3", str((HERE / "verify.py").relative_to(ROOT)),
               "--tmp", "<tmp>"], "exit": 0, "started": started,
              "ended": datetime.now(timezone.utc).isoformat(), "seconds": time.monotonic() - start,
              "new_modules": new, "added_declarations": audit["added_declarations"],
              "lean_sources": len(paths), "manifest": digest(manifest), "output": digest(output),
              "obligations": len(ids),
              "files": {str(path.relative_to(ROOT)): digest(path) for path in files},
              "records": {path.name: digest(path) for path in HERE.iterdir()
                          if path.is_file() and path.name != "inputs.json"}}
    (HERE / "inputs.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(brief, ensure_ascii=False))


if __name__ == "__main__":
    main()
