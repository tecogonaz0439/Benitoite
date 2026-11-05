# -*- coding: utf-8 -*-
"""tables.md「L60.04とL60.29で行う照合」の四照合を、群Aの台帳・群F1と群F2の差分・Leanのソースで行う。

1. 全既存証拠 → 合成行: E01〜E15の552出典行の出典別件数、各出典行の台帳の行が合成であること、
   その出典行のlookupが合成表の行・本体・資源名にあり、群F1か群F2の差分が定理へ対応させていること。
   三モデルの75欄は、群Eの条件の記録（l60/e/conditions.json の既存75）の同じ欄へ全件を対応させる。
2. 仮定側の行: 証拠の完全名と出典行が空であること。独立に、仮定側の名前（Lean名・Rust名）と同じ名前を
   持つ552出典行が0件、合成表の行の名前・本体のキーが0件であること。
3. 台帳の合成行 ↔ 合成表のlookup: 各合成行のlookupが合成表に同じ名前であり、合成表の全377行・
   全130本体・資源名に合成行があること。
4. Rust登録 → 台帳: 61部分523参照の全てが台帳の行へ対応し、合成/仮定の分類を持ち、仮定の行は理由を
   持つこと。"""
import collections
import json
import re
import subprocess
import sys
from support import CHANGE, HERE, LEAN, write

EXPECTED = {"E01": 328, "E02": 73, "E03": 34, "E04": 2, "E05": 6, "E06": 7, "E07": 3, "E08": 15, "E09": 7,
            "E10": 1, "E11": 7, "E12": 9, "E13": 11, "E14": 1, "E15": 48}


def pages(prefix):
    rows = []
    for part in sorted((CHANGE / "l60/a").glob(prefix + "-[0-9][0-9].json")):
        rows.extend(json.loads(part.read_text()))
    return rows


ledger = pages("ledger")
evidence = pages("evidence")
rust = pages("rust")
conditions = json.loads((CHANGE / "l60/a/conditions-01.json").read_text())
f1 = json.loads((CHANGE / "l60/f1/ledger-diff.json").read_text())
f2 = json.loads(subprocess.run([sys.executable, str(HERE / "ledger_diff.py"), "--json"], capture_output=True,
                               text=True, check=True).stdout)
classification = {r["id"]: r["classification"] for r in ledger}
for diff in (f1, f2):
    for row in diff["moved"]:
        classification[row["id"]] = row["after"]
# 群F1の訂正（Process.exit の仮定の種類と理由をIO応答の仮定へ改めた）を重ねる。
corrections = {}
for row in f1["corrected"]:
    assert classification[row["id"]] == row["classification"] == "仮定"
    corrections[row["id"]] = {"assumption_kind": "IO 応答", "reason": row["after_reason"],
                              "assumption_detail": "kind=exit。ハンドラのない呼出しはE_Exit・E_IOErrが同じ表のioResponseを読む"}
ledger = [dict(r, **corrections.get(r["id"], {})) for r in ledger]
by_id = {r["id"]: r for r in ledger}
signatures = (LEAN / "StandardModelSignatures.lean").read_text()
names = dict(re.findall(r'^  \| \.(p\d{3}) => "([^"]+)"$',
                        signatures.split("def Primitive.name", 1)[1].split("\n\n", 1)[0], re.M))
declarations = (LEAN / "StandardModelDeclarations.lean").read_text()
keys = dict(re.findall(r'^  \| \.(b\d{3}) => "([^"]+)"$',
                       declarations.split("def Body.key", 1)[1].split("\n\n", 1)[0], re.M))
# 群F1・F2の差分が定理へ対応させた合成表の子キー。
covered = {r["row"] for r in f1["connected"]} | {r["row"] for r in f2["connected"]}
for row in f1["moved"]:
    covered.add(row["composition_lookup"])


def lookup_exists(lookup):
    kind, key = lookup.split(".")[1], lookup.split(".")[-1]
    if kind == "Primitive":
        return key in names and "Primitive." + key in covered
    if kind == "Body":
        return key in keys and "Body." + key in covered
    return lookup == "StandardModel.resource_iff" and "resource_iff" in covered


# 1. 全既存証拠 → 合成行。
counts = collections.Counter(e["id"].split(".")[0] for e in evidence)
assert dict(counts) == EXPECTED and sum(counts.values()) == 552
unmapped, to_assumption, missing_lookup = [], [], []
for e in evidence:
    row = by_id.get(e["ledger"])
    if row is None:
        unmapped.append(e["id"])
        continue
    if classification[row["id"]] != "合成":
        to_assumption.append(e["id"])
    if not e.get("composition_lookup") or not lookup_exists(e["composition_lookup"]):
        missing_lookup.append(e["id"])
    names_in_row = {c["source"] for c in row.get("name_correspondence", [])}
    if e["id"] not in names_in_row:
        unmapped.append(e["id"])
assert not unmapped and not to_assumption and not missing_lookup, (unmapped, to_assumption, missing_lookup)
group_e = json.loads((CHANGE / "l60/e/conditions.json").read_text())["rows"]
model = {"Model.builtins": "model", "ModelTargets.builtins": "targets", "ModelHttp.builtins": "http"}
existing75 = {(r["model"], r["field"]): r for r in group_e if r["column"] == "既存75"}
condition_map = [(c["id"], existing75.get((model[c["model"]], c["field"]))) for c in conditions]
assert len(conditions) == 75 and all(r and r["reader"] for _, r in condition_map)
assert len({(model[c["model"]], c["field"]) for c in conditions}) == 75

# 2. 仮定側の行に証拠名がない。
assumption = [r for r in ledger if classification[r["id"]] == "仮定"]
assert all(not r["evidence"] and not r["evidence_rows"] and not r["name_correspondence"] for r in assumption)
evidence_names = set()
for e in evidence:
    evidence_names.update({e["lean_name"], e.get("public_name"), e.get("internal_name")} | set(e.get("rust_names", [])))
evidence_names.discard(None)
lookup_names = set(names.values()) | set(keys.values())
overlap_evidence = sorted({n for r in assumption for n in [r["lean_name"]] + r["rust_names"] if n in evidence_names})
overlap_lookup = sorted({n for r in assumption for n in [r["lean_name"]] + r["rust_names"] if n in lookup_names})
assert not overlap_evidence and not overlap_lookup, (overlap_evidence, overlap_lookup)
assert all(r["reason"] for r in assumption)

# 3. 台帳の合成行 ↔ 合成表のlookup。
composition = [r for r in ledger if classification[r["id"]] == "合成"]
row_lookups = collections.defaultdict(set)
for r in composition:
    for c in r.get("name_correspondence", []) + r.get("helper_correspondence", []):
        if c.get("composition_lookup"):
            row_lookups[r["id"]].add(c["composition_lookup"])
for diff in (f1, f2):
    for m in diff["moved"]:
        row_lookups[m["id"]].add(m["composition_lookup"] if m["composition_lookup"].startswith("StandardModel.")
                                 else "StandardModel." + m["composition_lookup"])
no_lookup = [r["id"] for r in composition if not row_lookups[r["id"]]]
bad_lookup = sorted((i, l) for i, ls in row_lookups.items() for l in ls if not lookup_exists(l))
reached = set()
for ls in row_lookups.values():
    for l in ls:
        reached.add(l.split(".", 1)[1])
primitive_missing = sorted(k for k in names if "Primitive." + k not in reached)
body_missing = sorted(k for k in keys if "Body." + k not in reached)
assert not no_lookup and not bad_lookup and not primitive_missing and not body_missing, \
    (no_lookup, bad_lookup, primitive_missing, body_missing)
assert "resource_iff" in reached

# 4. Rust登録 → 台帳。
assert len(rust) == 523 and len({r["id"] for r in rust}) == 523
rust_unmapped = [r["id"] for r in rust if r["ledger"] not in by_id]
assert not rust_unmapped
rust_classes = collections.Counter(classification[r["ledger"]] for r in rust)
parts = {r["part"] for r in rust}
assert len(parts) == 61, len(parts)

result = {
    "check1_evidence_to_composition": {"source_counts": dict(sorted(counts.items())), "evidence_rows": 552,
                                       "unmapped": 0, "to_assumption": 0, "without_covered_lookup": 0,
                                       "model_conditions": len(conditions), "model_conditions_unmapped": 0},
    "check2_assumption_without_evidence": {"assumption_rows": len(assumption), "with_evidence": 0,
                                           "names_shared_with_evidence_rows": 0,
                                           "names_with_composition_lookup": 0},
    "check3_composition_lookup": {"composition_rows": len(composition), "without_lookup": 0,
                                  "lookups_not_in_table": 0, "primitive_rows": len(names), "bodies": len(keys),
                                  "primitive_rows_without_ledger": 0, "bodies_without_ledger": 0,
                                  "resource_names": 1, "lookups": sum(map(len, row_lookups.values()))},
    "check4_rust_to_ledger": {"parts": len(parts), "references": len(rust), "unmapped": 0,
                              "classification": dict(rust_classes)},
}
write(HERE / "tables-check.json", result)
write(HERE / "assumptions.json", {
    "rows": len(assumption),
    "by_kind": dict(collections.Counter(r.get("assumption_kind", "") for r in assumption)),
    "names": [{"id": r["id"], "lean_name": r["lean_name"], "rust_names": r["rust_names"],
               "kind": r.get("assumption_kind"), "detail": r.get("assumption_detail"), "reason": r["reason"]}
              for r in assumption]})
print(json.dumps(result, ensure_ascii=False))
