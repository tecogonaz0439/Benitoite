# -*- coding: utf-8 -*-
"""一時領域の開始版一覧と現在の変更範囲を照合する。Git は呼ばない。"""
from pathlib import Path
import hashlib
import json
import re

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
B_WORK = "66779f9ca189d0ee780069da2e6146a6b390a220"
DESIGN = {"docs/design/01-spec/01-12-core-calculus.md", "docs/design/07-quality/07-04-formal-semantics.md"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def baseline(tmp):
    meta = json.loads((HERE / "baseline-summary.json").read_text())
    assert meta["b_work"] == B_WORK
    for kind in ["baseline", "root"]:
        item = meta[kind]
        path = tmp / item["file"]
        assert path.stat().st_size == item["bytes"] and digest(path) == item["sha256"], kind
    rows = json.loads((tmp / meta["baseline"]["file"]).read_text())
    assert len(rows) == meta["files"]
    return rows


def module_of(path):
    return path.removeprefix("formal/").removesuffix(".lean").replace("/", ".")


def path_of(module):
    return "formal/" + module.replace(".", "/") + ".lean"


def inspect(tmp):
    old = baseline(tmp)
    assert all((ROOT / p).is_file() for p in old), "開始版のファイルを削除した"
    owned = json.loads((HERE / "owned-at-start.json").read_text())
    assert len(owned) == len(set(owned)) == 60
    allowed = DESIGN | {"formal/Benitoite.lean"} | {path_of(m) for m in owned}
    changed = sorted(p for p, h in old.items() if digest(ROOT / p) != h)
    assert set(changed) <= allowed, sorted(set(changed) - allowed)
    current = {str(p.relative_to(ROOT)) for p in (ROOT / "formal/Benitoite").rglob("*.lean")}
    current |= {str(p.relative_to(ROOT)) for p in (ROOT / "docs/design").rglob("*.md")}
    current.add("formal/Benitoite.lean")
    added = sorted(current - old.keys())
    assert all(re.fullmatch(r"formal/Benitoite/Release/Refinement/Surface/Check[A-Za-z]+\.lean", p)
               for p in added), added
    modules = sorted(set(owned) | {module_of(p) for p in added})
    return {"changed": changed, "added": added, "modules": modules}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    found = inspect(args.tmp)
    (HERE / "audit-modules.json").write_text(json.dumps(found["modules"], indent=1) + "\n")
    print(json.dumps({"baseline_files": len(baseline(args.tmp)), "changed": found["changed"],
                      "new_modules": len(found["added"]), "owned_modules": len(found["modules"])},
                     ensure_ascii=False, indent=1))
