# -*- coding: utf-8 -*-
"""既定環境の監査を照合し、群末一回分の追加宣言・実署名を保存する（群E・F1の同名の台本に倣う）。"""
import argparse
import collections
import json
from pathlib import Path
import re
from support import CHANGE, HERE, closure, digest, write

MODULES = json.loads((HERE / "requested-modules.json").read_text())
GENERATED = r"\.(match_\d+|_sparseCasesOn_\d+|eq_\d+|eq_def|_unfold|proof_\d+|splitter)$"

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
own_names = {r["name"] for r in declarations}
parts, page = [], []
for row in declarations:
    typ = own_signatures[row["name"]]
    row["type_sha256"] = __import__("hashlib").sha256(typ.encode()).hexdigest()
    # 生成された宣言（照合の補助 match_・_sparseCasesOn_、その等式 eq_、展開の補題、証明の補助 proof_、
    # splitter）は、型と依存を大きさ・個数とハッシュだけで残す。名前付きの宣言の依存は、全件の個数と
    # ハッシュに加え、今回のモジュールの宣言への依存（読者の照合に使う）だけを一覧に残す。
    generated = re.search(GENERATED, row["name"]) is not None
    row["generated"] = generated
    if generated:
        row["type"], row["type_bytes"] = None, len(typ.encode())
    else:
        assert len(typ.encode()) <= 20000, row["name"]
        row["type"] = typ
    used = dependencies[row["name"]]
    row["dependency_count"] = len(used)
    row["dependency_sha256"] = __import__("hashlib").sha256("\n".join(used).encode()).hexdigest()
    row["dependencies"] = None if generated else [d for d in used if d in own_names]
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
# 群A〜F1の記録にある宣言は引き継いだ宣言とし、名前と型のハッシュで変化を分ける。
inherited = {}
for group in ["a", "b", "c", "d", "e", "f1"]:
    for part in sorted((CHANGE / "l60" / group).glob("declarations-[0-9][0-9].json")):
        for row in json.loads(part.read_text()):
            if "type_sha256" in row:
                inherited[row["name"]] = row["type_sha256"]
added = [row for row in declarations if row["name"] not in inherited]
changed = [row["name"] for row in declarations if row["name"] in inherited and
           inherited[row["name"]] != row["type_sha256"]]
removed = []
write(HERE / "added-declarations.json", {
    "added": len(added), "generated": sum(r["generated"] for r in added),
    "by_module": dict(collections.Counter(r["module"] for r in added)),
    "named": [r["name"] for r in added if not r["generated"]]})
target_file = args.tmp / "targets.txt"
target_file.write_text("\n".join(targets) + "\n")
summary = {"targets": len(targets), "target_list": digest(target_file), "raw": digest(raw),
           "modules": len(modules), "new_modules": {m: modules[m] for m in MODULES},
           "declarations": len(declarations), "added_declarations": len(added),
           "inherited_declarations": len(declarations) - len(added),
           "inherited_type_changed": changed, "inherited_removed": removed,
           "private": sum(r["name"].startswith("_private.") for r in declarations),
           "without_source_position": sum(r["line"] is None for r in declarations),
           "closure_rounds": int(re.search(r"^AUDIT_ROUNDS (\d+)$", text, re.M)[1]),
           "axiom_sets": {" + ".join(k) or "none": v for k, v in sorted(sets.items())},
           "sorryAx": 0, "new_axioms": 0, "parts": parts,
           "inputs": {"axioms.lean": digest(HERE / "axioms.lean"), "audit.py": digest(Path(__file__))}}
write(HERE / "audit-summary.json", summary)
print(json.dumps({k: summary[k] for k in ["targets", "modules", "declarations", "private", "axiom_sets"]}, ensure_ascii=False))
