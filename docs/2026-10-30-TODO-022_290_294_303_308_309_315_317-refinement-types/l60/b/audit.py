"""既定環境の監査を照合し、群末一回分の追加宣言・実署名を保存する。"""
import argparse
import collections
import json
from pathlib import Path
import re
from support import HERE, MODULES, closure, digest, write

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--tmp", type=Path, required=True)
args = parser.parse_args()
raw = args.tmp / "axioms.log"
record = json.loads((HERE / "axioms.json").read_text())
assert record["exit"] == 0 and record["raw"] == digest(raw)
text = raw.read_text()
assert not re.search(r"error:|warning:|sorryAx|AUDIT_(MISSING|AXIOM|FIXED_POINT_LIMIT|REQUIRED_MISSING|MODULE_MISSING)", text)
targets = re.findall(r"^AUDIT_TARGET (.+)$", text, re.M)
assert len(targets) == len(set(targets)) == int(re.search(r"^AUDIT_COUNT (\d+)$", text, re.M)[1])
axioms = re.findall(r"^'(.*?)' (?:does not depend on any axioms|depends on axioms: \[([^]]*)\])", text, re.M | re.S)
assert collections.Counter(n for n, _ in axioms) == collections.Counter(targets)
sets = collections.Counter(tuple(sorted(x.strip() for x in ax.split(",") if x.strip())) for _, ax in axioms)
assert all(set(x) <= {"propext", "Quot.sound", "Classical.choice"} for x in sets), sets
declarations = [{"module": m, "kind": k, "line": int(l) or None, "name": n}
                for m, k, l, n in re.findall(r"^AUDIT_DECL (\S+) (\S+) (\d+) (.+)$", text, re.M)]
modules = {m: int(c) for m, c in re.findall(r"^AUDIT_MODULE (\S+) (\d+)$", text, re.M)}
assert set(MODULES) <= set(modules)
assert set(modules) == set(closure()) and sum(modules.values()) == len(targets)
assert len(declarations) == len({r["name"] for r in declarations}) == sum(modules[m] for m in MODULES)
signatures = re.findall(r"^SIGNATURE_BEGIN (\S+) (\S+) (\d+)\n(.*?)^SIGNATURE_END \2$", text, re.M | re.S)
own_signatures = {n: typ.strip() for m, n, l, typ in signatures if m in MODULES}
assert set(own_signatures) == {r["name"] for r in declarations}
assert not any("⋯" in typ or "..." in typ for typ in own_signatures.values())
dependencies = collections.defaultdict(list)
for owner, used in re.findall(r"^DEPENDENCY (\S+) (\S+)$", text, re.M):
    dependencies[owner].append(used)
parts, page = [], []
for row in declarations:
    row["type"] = own_signatures[row["name"]]
    row["type_sha256"] = __import__("hashlib").sha256(row["type"].encode()).hexdigest()
    row["dependencies"] = dependencies[row["name"]]
    if len(json.dumps(page + [row], ensure_ascii=False, indent=2).encode()) > 85000 and page:
        file = HERE / f"declarations-{len(parts)+1:02}.json"
        write(file, page)
        parts.append({"file": file.name, **digest(file)})
        page = []
    page.append(row)
if page:
    file = HERE / f"declarations-{len(parts)+1:02}.json"
    write(file, page)
    parts.append({"file": file.name, **digest(file)})
target_file = args.tmp / "targets.txt"
target_file.write_text("\n".join(targets) + "\n")
summary = {"targets": len(targets), "target_list": digest(target_file), "raw": digest(raw),
           "modules": len(modules), "new_modules": {m: modules[m] for m in MODULES},
           "declarations": len(declarations),
           "private": sum(r["name"].startswith("_private.") for r in declarations),
           "without_source_position": sum(r["line"] is None for r in declarations),
           "closure_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", text, re.M)[1]),
           "axiom_sets": {" + ".join(k) or "none": v for k, v in sorted(sets.items())},
           "sorryAx": 0, "new_axioms": 0, "parts": parts,
           "inputs": {"axioms.lean": digest(HERE / "axioms.lean"), "audit.py": digest(Path(__file__))}}
write(HERE / "audit-summary.json", summary)
print(json.dumps({k: summary[k] for k in ["targets", "modules", "declarations", "private", "axiom_sets"]}, ensure_ascii=False))
