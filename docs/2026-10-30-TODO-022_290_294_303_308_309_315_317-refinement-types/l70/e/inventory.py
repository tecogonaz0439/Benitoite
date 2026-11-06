# -*- coding: utf-8 -*-
"""開始時のハッシュ一覧から追加モジュールと変更範囲を求める。Git は呼ばない。"""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DESIGN = {
    "docs/design/01-spec/01-12-core-calculus.md",
    "docs/design/07-quality/07-04-formal-semantics.md",
}
ALLOWED_EXISTING = DESIGN | {"formal/Benitoite.lean"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def baseline():
    rows = [r for p in sorted(HERE.glob("baseline-*.json")) for r in json.loads(p.read_text())]
    assert len(rows) == len(dict(rows)), "開始時一覧の重複"
    return dict(rows)


def module_of(path):
    return path.removeprefix("formal/").removesuffix(".lean").replace("/", ".")


def inspect():
    old = baseline()
    missing = [p for p in old if not (ROOT / p).is_file()]
    assert not missing, missing
    changed = sorted(p for p, h in old.items() if digest(ROOT / p) != h)
    assert set(changed) <= ALLOWED_EXISTING, changed
    new = sorted(str(p.relative_to(ROOT)) for p in (ROOT / "formal/Benitoite").rglob("*.lean")
                 if str(p.relative_to(ROOT)) not in old)
    allowed_coverage = {"Coverage", "CoverageExtension", "CoverageInitial", "CoverageExamples"}
    for p in new:
        assert p.startswith("formal/Benitoite/Release/Refinement/"), p
        tail = p.removeprefix("formal/Benitoite/Release/Refinement/").removesuffix(".lean")
        assert tail in allowed_coverage or tail.startswith("Surface/"), p
    modules = [module_of(p) for p in new]
    return {"changed": changed, "added": new, "modules": modules}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--append-imports", action="store_true")
    args = parser.parse_args()
    found = inspect()
    (HERE / "audit-modules.json").write_text(json.dumps(found["modules"], indent=1) + "\n")
    if args.append_imports:
        root = ROOT / "formal/Benitoite.lean"
        source = root.read_text()
        for module in found["modules"]:
            line = "import " + module
            if line not in source.splitlines():
                source += line + "\n"
        root.write_text(source)
    print(json.dumps({"baseline_files": len(baseline()), "changed": found["changed"],
                      "new_modules": len(found["modules"])}, ensure_ascii=False, indent=1))
