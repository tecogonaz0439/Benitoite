"""全追加宣言の監査、既定 import、変更範囲、写しと検査入力の同一性を照合する。"""
import argparse
import collections
import datetime
import hashlib
import json
from pathlib import Path
import re
import time
from inventory import HERE, ROOT, baseline, digest, inputs, inventory, write

ALLOWED = {"propext", "Classical.choice", "Quot.sound"}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tmp", type=Path, required=True)
    args = ap.parse_args()
    tick = time.monotonic()
    state = inventory()
    imported, pending = set(), ["Benitoite"]
    while pending:
        module = pending.pop()
        if module in imported:
            continue
        path = ROOT / "formal" / (module.replace(".", "/") + ".lean")
        if not path.exists():
            continue
        imported.add(module)
        pending += re.findall(r"^import (\S+)", path.read_text(), re.M)
    owned = json.loads((HERE / "audit-modules.json").read_text())
    assert set(owned) <= imported
    original = (ROOT / "formal/Benitoite.lean").read_text()
    for module in owned:
        line = "import " + module + "\n"
        assert original.count(line) == 1
        original = original.replace(line, "")
    before = baseline()
    assert hashlib.sha256(original.encode()).hexdigest() == before["formal/Benitoite.lean"]
    for path, additions in json.loads((HERE / "doc-additions.json").read_text()).items():
        original = (ROOT / path).read_text()
        for addition in additions:
            assert original.count(addition) == 1
            original = original.replace(addition, "")
        assert hashlib.sha256(original.encode()).hexdigest() == before[path], path

    fingerprint = hashlib.sha256(json.dumps(inputs(), sort_keys=True).encode()).hexdigest()
    for mode in ["build", "audit"]:
        record = json.loads((HERE / (mode + ".json")).read_text())
        assert record["exit"] == 0 and record["unchanged"]
        assert record["raw"] == digest(args.tmp / (mode + ".log"))
        assert record["input_sha256"] == fingerprint
        if mode == "audit":
            assert all(digest(HERE / name) == value for name, value in record["audit_inputs"].items())
    output = (args.tmp / "audit.log").read_text()
    assert not re.search(r"error:|warning:|sorryAx|AUDIT_(?:MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)", output)
    names = re.findall(r"^AUDIT_TARGET (.+)$", output, re.M)
    assert len(set(names)) == len(names) == int(re.search(r"^AUDIT_COUNT (\d+)$", output, re.M)[1])
    dependencies = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", output, re.M | re.S)
    assert collections.Counter(n for n, _ in dependencies) == collections.Counter(names)
    axiom_sets = collections.Counter(tuple(sorted(x.strip() for x in a.split(",") if x.strip()))
                                     for _, a in dependencies)
    assert all(set(a) <= ALLOWED for a in axiom_sets), axiom_sets
    modules = {m: int(n) for m, n in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", output, re.M)}
    assert sum(modules.values()) == len(names)
    assert set(owned) <= modules.keys()
    declarations = [{"module": m, "kind": k, "line": int(l), "name": n}
                    for m, k, l, n in re.findall(r"^OWN_DECL (\S+) (\S+) (\d+) (.+)$", output, re.M)]
    assert len(set(d["name"] for d in declarations)) == len(declarations)
    assert len(declarations) == sum(modules[m] for m in owned)
    catalog = args.tmp / "declarations.json"
    write(catalog, declarations)
    targets = args.tmp / "targets.txt"
    targets.write_text("\n".join(names) + "\n")
    readers = re.findall(r"^OWN_DEP (\S+) (\S+)$", output, re.M)
    required = json.loads((HERE / "required-names.json").read_text())
    declared = {d["name"] for d in declarations}
    assert set(required) <= declared
    witnesses = {"integer_witnesses", "undecided_witness", "integer_observations"}
    public = required
    missing_readers = [name for name in public if name.rsplit(".", 1)[-1] not in witnesses
                       and not any(dep == name and user != name for user, dep in readers)]
    assert not missing_readers, missing_readers
    for path in state["new"]:
        source = (ROOT / path).read_text()
        assert not re.search(r"\bsorry\b|^axiom |#eval|native_decide|set_option (maxHeartbeats|maxRecDepth)|L70|L[0-9]{2}\.[0-9]", source, re.M)
    build = (args.tmp / "build.log").read_text()
    assert "error:" not in build
    assert not any("CheckErasure" in line and ("warning" in line or "⚠" in line)
                   for line in build.splitlines())
    signature_blocks = re.findall(r"^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^SIGNATURE_END \2$", output, re.M | re.S)
    assert {name for _, name, _, _ in signature_blocks} == set(required)
    assert not any("⋯" in typ or "..." in typ for _, _, _, typ in signature_blocks)
    signatures = "# 消去の実署名\n\n既定環境の型を印字し、具体値を評価していない。\n\n"
    for module, name, line, typ in signature_blocks:
        signatures += f"## {name}\n\n`{module}`、行 {line}。\n\n```lean\n{typ.strip()}\n```\n\n"
    (HERE / "signatures.md").write_text(signatures)
    write(HERE / "audit-summary.json", {"modules": len(modules), "declarations": len(names),
        "owned_modules": {m: modules[m] for m in owned}, "owned_declarations": len(declarations),
        "private": sum(d["name"].startswith("_private.") for d in declarations),
        "without_source_line": sum(d["line"] == 0 for d in declarations),
        "axiom_sets": {" + ".join(k) or "none": v for k, v in sorted(axiom_sets.items())},
        "new_axioms": 0, "sorryAx": 0, "rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", output, re.M)[1]),
        "owned_catalog": digest(catalog), "target_list": digest(targets),
        "source_public_declarations": len(public), "reader_pairs": len(readers),
        "signatures": digest(HERE / "signatures.md")})
    files = [p for p in HERE.rglob("*") if p.is_file() and "__pycache__" not in p.parts]
    assert all(p.stat().st_size <= 100000 for p in files)
    assert sum(p.stat().st_size for p in files) <= 3000000
    result = {"exit": 0, "timestamp": datetime.datetime.now().astimezone().isoformat(),
        "seconds": time.monotonic() - tick, "input_sha256": fingerprint,
        "protected": len(before), "changed": state["changed"], "new": state["new"],
        "all_new_modules_in_default_import": True, "owned_declarations": len(declarations),
        "public_readers_checked": len(public), "record_bytes": sum(p.stat().st_size for p in files)}
    write(HERE / "verify.json", result)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
