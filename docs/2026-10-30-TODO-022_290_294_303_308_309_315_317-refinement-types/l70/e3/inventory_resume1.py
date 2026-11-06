#!/usr/bin/env python3
"""再開1の追加モジュールと、許可した既存入力の変更を列挙する。"""
import json
from inventory import HERE, ROOT, baseline, digest, fingerprint, inputs, write

ALLOWED = {
    "formal/Benitoite.lean",
    "docs/design/01-spec/01-12-core-calculus.md",
    "docs/design/07-quality/07-04-formal-semantics.md",
}
DIAGNOSTICS = ["obstruction.lean", "pattern-context-obstruction.lean"]


def modules():
    old = baseline()
    return sorted(p.removeprefix("formal/").removesuffix(".lean").replace("/", ".")
                  for p in inputs() if p.startswith("formal/") and p.endswith(".lean") and p not in old)


def protected():
    old, current = baseline(), inputs()
    removed = sorted(set(old) - set(current))
    changed = sorted(p for p in old if p in current and old[p] != current[p])
    added = sorted(set(current) - set(old))
    assert not removed, removed
    assert set(changed) <= ALLOWED, changed
    assert all(p.startswith("formal/Benitoite/Release/Refinement/") and p.endswith(".lean") for p in added), added
    return {"changed_existing": changed, "added": {p: current[p] for p in added},
            "changed_digests": {p: {"before": old[p], "after": current[p]} for p in changed},
            "initial_count": len(old), "current_count": len(current),
            "current_sha256": fingerprint(current)}


def local_inputs():
    names = DIAGNOSTICS + ["audit-tail.lean", "inventory_resume1.py", "run_checks_resume1.py", "verify_resume1.py"]
    return {n: digest(HERE / n) for n in names}


def audit_source():
    imports = {"import Lean", "import Benitoite"}
    bodies = []
    for name in DIAGNOSTICS:
        body = []
        for line in (HERE / name).read_text().splitlines():
            if line.startswith("import "):
                imports.add(line)
            else:
                body.append(line)
        bodies.append("\n".join(body))
    return "\n".join(sorted(imports)) + "\n" + "\n".join(bodies) + "\n" + (HERE / "audit-tail.lean").read_text()


if __name__ == "__main__":
    record = protected()
    record["modules"] = modules()
    record["local_inputs"] = local_inputs()
    write(HERE / "resume1-inputs.json", record)
    print(json.dumps({"modules": len(record["modules"]), "inputs": record["current_count"]}))
