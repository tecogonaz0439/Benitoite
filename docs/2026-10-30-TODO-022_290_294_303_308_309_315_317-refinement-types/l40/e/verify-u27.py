"""旧740Leanと静的な全型位置の読者・写し・検査記録を局所照合する。"""
from pathlib import Path
from datetime import datetime, timezone
import ast
import hashlib
import json
import re
import runpy

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
MODULE = "StandardHigherPositions"


def digest(data):
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    initial = json.loads((HERE / "baseline-r1-u27.json").read_text())
    captured = {}
    for part in initial["files_parts"]:
        data = (HERE / part["file"]).read_bytes()
        assert digest(data) == {key: part[key] for key in ("bytes", "sha256")}
        captured.update(json.loads(data))
    assert len(captured) == initial["lean_sources"] == 740
    for relative, expected in captured.items():
        data = (ROOT / relative).read_bytes()
        if relative == "formal/Benitoite.lean":
            data = data[:expected["bytes"]]
        assert digest(data) == expected, relative
    paths = [p for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts]
    assert len(paths) == 741
    relative = f"formal/Benitoite/Release/Refinement/{MODULE}.lean"
    path = ROOT / relative
    code = path.read_text()
    oldroot = captured["formal/Benitoite.lean"]["bytes"]
    assert (ROOT / "formal/Benitoite.lean").read_bytes()[oldroot:] == (
        f"import Benitoite.Release.Refinement.{MODULE}\n".encode())
    modules = json.loads((HERE / "modules-r1.json").read_text())
    assert modules == initial["old_modules"] + [MODULE]
    olean = ROOT / f"formal/.lake/build/lib/lean/Benitoite/Release/Refinement/{MODULE}.olean"
    assert olean.exists() and olean.stat().st_mtime >= path.stat().st_mtime
    assert not re.search(r"\b(sorry|axiom|admit|native_decide|implemented_by)\b|#eval", code)
    assert not re.search(r"\b(?:L\d{2}(?:\.\d+)?|O\d{3}|TODO-\d{3}|H\d{2})\b|/Users/", code)
    entries = []
    for match in re.finditer(r"(?m)^(private )?(?:def|theorem|structure) ([A-Za-z_][A-Za-z0-9_]*)", code):
        name = match[2]
        count = len(re.findall(r"\b" + re.escape(name) + r"\b", code))
        assert count > 1, name
        if not match[1]:
            entries.append({"name": name, "line": code.count("\n", 0, match.start()) + 1,
                            "textual_occurrences": count})
    readers = ["callback_checked", "result_checked", "effect_checked", "list_checked",
               "option_checked", "consumer_checked", "reference_checked", "fail_checked",
               "names_arity_checked", "dep_apply", "length_all_images"]
    # Each anonymous reader is elaborated by the same default build.
    examples = re.split(r"(?m)^example\b", code)[1:]
    for name in readers:
        assert any(re.search(r"\b" + name + r"\b", block) for block in examples), name
    for relative_doc in ["docs/design/01-spec/01-12-core-calculus.md",
                         "docs/design/07-quality/07-04-formal-semantics.md"]:
        assert MODULE in (ROOT / relative_doc).read_text()
    ids = re.findall(r"^\| (O\d{3}) \|", (HERE / "obligations.md").read_text(), re.M)
    assert len(ids) == len(set(ids)) == 64
    assert set(ids) == set(re.findall(r"^\| (O\d{3}) \|", (HERE.parent / "detail.md").read_text(), re.M))
    validate = runpy.run_path(str(HERE / "run-r1.py"))["validate_command"]
    checks = json.loads((HERE / "checks-r1-u27.json").read_text())
    for check in checks:
        validate(check["command"], check["cwd"] == "formal/")
    build = [c for c in checks if c["command"] == ["lake", "build"]]
    assert len(build) == 1 and build[0]["exit"] == 0
    assert next(c for c in checks if c["label"] == "r1-u27-readers01")["raw"]["bytes"] == 0
    deviations = json.loads((HERE / "command-deviations-r1.json").read_text())
    targeted = []
    for p in HERE.glob("checks-r1*.json"):
        for c in json.loads(p.read_text()):
            if c["command"][:2] == ["lake", "build"] and c["command"] != ["lake", "build"]:
                targeted.append((p.name, c["label"], c["start"], c["command"], c["exit"]))
    expected = [(deviations["record"], c["label"], c["start"], c["command"], c["exit"])
                for c in deviations["executions"]]
    assert sorted(targeted) == sorted(expected) and len(targeted) == deviations["count"] == 23
    for p in HERE.iterdir():
        if not p.is_file():
            continue
        assert p.stat().st_size <= 100000, p.name
        text = p.read_text()
        assert str(ROOT) not in text and not re.search(r"\]\([^)]*docs/todo", text), p.name
        if p.suffix == ".py":
            ast.parse(text, filename=p.name)
        if p.suffix == ".md":
            for link in re.findall(r"\]\(([^)]+)\)", text):
                target = link.split("#")[0]
                if target and "://" not in target:
                    assert (p.parent / target).exists(), (p.name, target)
    evidence = {"observed_utc": datetime.now(timezone.utc).isoformat(), "exit": 0,
                "scope": "局所照合。全公理監査・独立レビュー・Rust/Lean交換は含まない",
                "retained_lean_sources": 740, "current_lean_sources": 741,
                "modules": [MODULE], "source": digest(path.read_bytes()),
                "old_root_prefix": captured["formal/Benitoite.lean"],
                "public_entries": entries, "concrete_readers": readers,
                "anonymous_readers": len(examples), "obligations": 64,
                "earlier_targeted_build_deviations": 23, "additional_targeted_build_deviations": 0,
                "records_under_100KB": True, "default_build": build[0]["label"]}
    (HERE / "source-evidence-u27.json").write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: v for k, v in evidence.items() if k not in ("public_entries", "concrete_readers")}, ensure_ascii=False))


if __name__ == "__main__":
    main()
