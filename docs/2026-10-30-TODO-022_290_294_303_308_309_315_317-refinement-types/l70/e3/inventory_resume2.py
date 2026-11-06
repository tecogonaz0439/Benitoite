#!/usr/bin/env python3
"""再開2の入力・全追加モジュール・監査の入力を、開始版の記録と照合する。"""
import hashlib
import json
import re
from inventory import HERE, ROOT, baseline, digest, fingerprint, inputs, write

B_WORK = "73585979113c7acf25b38673f9c2c52d1d38dfaf"
ALLOWED = {
    "formal/Benitoite.lean",
    "docs/design/01-spec/01-12-core-calculus.md",
    "docs/design/07-quality/07-04-formal-semantics.md",
}
DIAGNOSTICS = ["obstruction.lean", "pattern-context-obstruction.lean"]
# 今回渡された読み取り専用のレビューは、初回の開始記録より後に追加された入力である。
GIVEN_INPUTS = {
    "docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-L70.e3.md": {
        "bytes": 22927,
        "sha256": "b90ff7986a01ef919637e65f13f2c9ac459ae5dedc6f19cb997c76cc115fcf37",
    },
}


def modules():
    old = baseline()
    return sorted(p.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
                  for p in inputs() if p.startswith("formal/") and p.endswith(".lean") and p not in old)


def import_closure():
    seen, pending = set(), ["Benitoite"]
    while pending:
        name = pending.pop()
        if name in seen or not name.startswith("Benitoite"):
            continue
        seen.add(name)
        source = ROOT / "formal" / (name.replace(".", "/") + ".lean")
        assert source.is_file(), name
        for line in source.read_text().splitlines():
            match = re.match(r"\s*import\s+(.+)", line)
            if match:
                pending.extend(n for n in match[1].split() if n.startswith("Benitoite"))
    return seen


def protected():
    old, current = baseline(), inputs()
    removed = sorted(set(old) - set(current))
    changed = sorted(p for p in old if p in current and old[p] != current[p])
    added = sorted(set(current) - set(old))
    assert not removed, removed
    assert set(changed) <= ALLOWED, changed
    assert all(current.get(p) == expected for p, expected in GIVEN_INPUTS.items()), GIVEN_INPUTS
    production = [p for p in added if p not in GIVEN_INPUTS]
    assert all(p.startswith("formal/Benitoite/Release/Refinement/") and p.endswith(".lean")
               for p in production), production
    added_modules = set(modules())
    closure = import_closure()
    assert added_modules and added_modules <= closure, sorted(added_modules - closure)
    # 根では追加モジュールの import 行だけを増やせる。既存 import の削除・並べ替えも拒否する。
    root = ROOT / "formal/Benitoite.lean"
    previous = b"".join(line for line in root.read_bytes().splitlines(keepends=True)
                        if line.strip().decode() not in {"import " + m for m in added_modules})
    assert {"bytes": len(previous), "sha256": hashlib.sha256(previous).hexdigest()} == old["formal/Benitoite.lean"]
    return {"base": B_WORK, "changed_existing": changed,
            "given_inputs": GIVEN_INPUTS, "added": {p: current[p] for p in production},
            "changed_digests": {p: {"before": old[p], "after": current[p]} for p in changed},
            "initial_count": len(old), "current_count": len(current),
            "current_sha256": fingerprint(current)}


def local_inputs():
    names = DIAGNOSTICS + ["audit-tail.lean", "inventory.py", "inventory_resume2.py",
                           "run_checks_resume2.py", "verify_resume2.py"]
    return {n: digest(HERE / n) for n in names}


def audit_source():
    imports, bodies = {"import Lean", "import Benitoite"}, []
    for name in DIAGNOSTICS:
        body = []
        for line in (HERE / name).read_text().splitlines():
            if line.startswith("import "):
                imports.add(line)
            else:
                body.append(line)
        bodies.append("\n".join(body))
    return "\n".join(sorted(imports)) + "\n" + "\n".join(bodies) + "\n" + (HERE / "audit-tail.lean").read_text()


def snapshot():
    return dict(protected(), modules=modules(), local_inputs=local_inputs())


if __name__ == "__main__":
    path = HERE / "resume2-inputs.json"
    assert not path.exists(), "既存の開始記録は上書きしない"
    record = snapshot()
    write(path, record)
    print(json.dumps({"base": B_WORK, "modules": len(record["modules"]), "inputs": record["current_count"]}))
