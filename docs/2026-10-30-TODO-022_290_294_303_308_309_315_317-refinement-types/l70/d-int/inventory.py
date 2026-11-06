# -*- coding: utf-8 -*-
"""開始時の指紋から、変更範囲・監査対象・言明の差を作り直す。"""
import argparse
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
CHANGE = HERE.parent.parent
TOOLS = {"__file__": str(HERE.parent / "d/verify.py")}
exec((HERE.parent / "d/verify.py").read_text().split("parser = argparse.ArgumentParser")[0], TOOLS)
headers = TOOLS["theorem_headers"]
signatures = TOOLS["signature_hashes"]
code_only = TOOLS["code_only"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fingerprint(data):
    return hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()


def save(path, obj):
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=1) + "\n")


def sources():
    result = {str(p.relative_to(ROOT)): digest(p)
              for p in (ROOT / "formal").rglob("*.lean") if ".lake" not in p.parts}
    result.update({"formal/" + n: digest(ROOT / "formal" / n)
                   for n in ["lakefile.toml", "lake-manifest.json", "lean-toolchain"]})
    result.update({n: digest(ROOT / n) for n in [
        "docs/design/01-spec/01-12-core-calculus.md",
        "docs/design/07-quality/07-04-formal-semantics.md"]})
    return result


def changed_paths(tmp):
    base = json.loads((tmp / "baseline-files.json").read_text())
    current = {str(p.relative_to(ROOT)): digest(p)
               for prefix in ["formal", "docs/design", "crates", "scripts"]
               for p in (ROOT / prefix).rglob("*")
               if p.is_file() and not any(x in p.parts for x in [".lake", "target", ".git", "__pycache__"])}
    removed = set(base) - set(current)
    assert not removed, ("開始時のファイルの削除", sorted(removed))
    changed = sorted(p for p in base if current[p] != base[p])
    added = sorted(set(current) - set(base))
    prefix = "formal/Benitoite/Release/Refinement/Surface/"
    named = {"OpenPatterns", "OpenBody", "OpenSurface", "OpenSurfaceHandlers", "OpenSurfaceProperty1",
             "OpenSurfaceScoped", "Theorems", "Examples", "RangeClauseExamples", "RangeStandard",
             "ScopeLower", "ScopeAccept", "Identity", "NormalContext", "OpenLeafFormation", "OpenRangeFormationCheck", "RangeLeafExamples"}
    allowed_docs = {"docs/design/01-spec/01-12-core-calculus.md",
                    "docs/design/07-quality/07-04-formal-semantics.md"}
    for p in changed + added:
        allowed = p in allowed_docs or p == "formal/Benitoite.lean"
        if p.startswith(prefix) and "/" not in p[len(prefix):] and p.endswith(".lean"):
            stem = Path(p).stem
            allowed |= stem in named or stem.startswith("Check")
        assert allowed, ("許可範囲の外の変更", p)
    return base, current, changed, added


def reachable():
    found = set()
    pending = ["Benitoite"]
    while pending:
        name = pending.pop()
        if name in found:
            continue
        found.add(name)
        source = (ROOT / "formal" / (name.replace(".", "/") + ".lean")).read_text()
        pending += re.findall(r"^import (Benitoite(?:\.[\w]+)*)$", source, re.M)
    return found


def statements(tmp):
    before = json.loads((tmp / "baseline-signatures.json").read_text())
    current = {str(p.relative_to(ROOT)): signatures(p.read_text())
               for p in (ROOT / "formal/Benitoite/Release/Refinement/Surface").glob("*.lean")}
    result = {}
    for p in sorted(set(before) | set(current)):
        a, b = before.get(p, {}), current.get(p, {})
        kept = sorted(n for n in a.keys() & b.keys() if a[n] == b[n])
        modified = sorted(n for n in a.keys() & b.keys() if a[n] != b[n])
        removed = sorted(a.keys() - b.keys())
        added = sorted(b.keys() - a.keys())
        if modified or removed or added:
            result[p] = dict(unchanged=len(kept), changed=modified, removed=removed, added=added)
    return result, current


def prepare(tmp):
    assert TOOLS["signature_selftest"]() == 8
    base, current, changed, added = changed_paths(tmp)
    lean = [p for p in changed + added if p.startswith("formal/") and p.endswith(".lean")]
    modules = sorted(p[7:-5].replace("/", ".") for p in lean)
    save(HERE / "audit-modules.json", modules)
    # 全言明の差は名前と件数を残し、生の署名一覧は一時領域に一回分だけ置く。
    differences, sigs = statements(tmp)
    save(tmp / "statement-differences.json", differences)
    data = json.dumps(sigs, sort_keys=True).encode()
    (tmp / "current-signatures.json").write_bytes(data)
    summary = {
        p: dict(unchanged=r["unchanged"], changed=r["changed"], removed=r["removed"], added_count=len(r["added"]))
        for p, r in differences.items()}
    save(HERE / "statement-differences.json", summary)
    baseline_files = ["baseline-files.json", "baseline-signatures.json", "protected-records.json", "baseline-root.lean"]
    save(HERE / "baseline-summary.json", {
        "b_work": "b3445f140ee8ddfcd9c95dd1de756ca1dbcaca52",
        "inputs": {name: dict(bytes=(tmp / name).stat().st_size, sha256=digest(tmp / name)) for name in baseline_files},
    })
    save(HERE / "inventory-summary.json", dict(changed=changed, added=added, modules=len(modules),
        current_signatures_bytes=len(data), current_signatures_sha256=hashlib.sha256(data).hexdigest(),
        source_fingerprint=fingerprint(sources())))
    print(json.dumps(dict(changed=len(changed), added=len(added), modules=len(modules)), ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tmp", type=Path, required=True)
    args = parser.parse_args()
    prepare(args.tmp)
