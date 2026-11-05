# -*- coding: utf-8 -*-
"""群Aの台帳（l60/a/ledger-*.json）と群F1の差分（l60/f1/ledger-diff.json）に対する群F2の差分を作る。
前の群の記録は書き換えない。

1. %List.getFront の行を仮定側から合成側へ移す。安全な入口の本体（E11）の参照先であり、既存の
   応答の証拠（StandardSafe.front_response）を持つ。合成表の行は Primitive.p377。
2. 群F1が接続していない合成行の全lookup（純粋な行・範囲付きの行・IOと終了・参照と明示遅延・発行・
   本体・資源名）へ、合成表の行・族の補題・全場合の定理と担当単位を対応させる。
3. 合成表の子キー（本体・組込みの署名・資源名）の件数を、Leanのソースから数え直す。"""
import json
import re
import sys
from support import CHANGE, HERE, LEAN, PREFIX, write


def lean(name):
    return (LEAN / (name + ".lean")).read_text()


def rows_of(text, head):
    """`def <head> : Primitive → Bool` の真の行を読む。"""
    body = text.split("def " + head + " : Primitive → Bool", 1)[1].split("| _ => false", 1)[0]
    return set(re.findall(r"\.(p\d{3})", body))


signatures = lean("StandardModelSignatures")
names = dict(re.findall(r'^  \| \.(p\d{3}) => "([^"]+)"$',
                        signatures.split("def Primitive.name", 1)[1].split("\n\n", 1)[0], re.M))
declarations = lean("StandardModelDeclarations")
keys = dict(re.findall(r'^  \| \.(b\d{3}) => "([^"]+)"$',
                       declarations.split("def Body.key", 1)[1].split("\n\n", 1)[0], re.M))
collection = rows_of(lean("StandardModelCollectionRows"), "Primitive.collection")
io_rows = lean("StandardModelIORows")
io = rows_of(io_rows, "Primitive.io")
scope = rows_of(io_rows, "Primitive.scopePure")
numeric = rows_of(lean("StandardModelNumericRows"), "Primitive.numeric")
operator = rows_of(lean("StandardModelOperatorRows"), "Primitive.operator")
store = {"p279", "p280", "p374", "p375", "p376"}
issue = {"p156"}
families = dict(re.findall(r"^  case (p\d{3}) => exact (PureRow\.\w+|IORow\.\w+)",
                           lean("StandardModelCollectionRows") + io_rows, re.M))
assert len(names) == 377 and len(keys) == 130
assert len(collection) == 79 and len(io) == 10 and len(scope) == 7
assert len(numeric) == 166 and len(operator) == 109
groups = [collection, io, scope, numeric, operator, store, issue]
assert sum(map(len, groups)) == 377 and set().union(*groups) == set(names)

ledger = []
for part in sorted((CHANGE / "l60/a").glob("ledger-[0-9][0-9].json")):
    ledger.extend(json.loads(part.read_text()))
f1 = json.loads((CHANGE / "l60/f1/ledger-diff.json").read_text())
classification = {r["id"]: r["classification"] for r in ledger}
for row in f1["moved"]:
    classification[row["id"]] = row["after"]
f1_connected = {(r["id"], r["row"]) for r in f1["connected"]}
by_name = {}
for row in ledger:
    by_name.setdefault(row["lean_name"], []).append(row)

[front] = by_name["%List.getFront"]
assert classification[front["id"]] == "仮定" and not front["evidence"] and names["p377"] == "%List.getFront"
moved = [{"id": front["id"], "lean_name": "%List.getFront", "before": "仮定", "after": "合成",
          "composition_lookup": "StandardModel.Primitive.p377", "signature": "StandardSafe.frontSig",
          "evidence": [PREFIX + n for n in ["StandardSafe.front_response", "StandardModel.PureRow.front",
                                            "StandardModel.scope_rows", "StandardModel.row_lookup"]],
          "reason": "安全な入口の本体（E11の safeGetBody・sameLengthBody）と精密なgetterの本体が参照する内部の組込み。"
                    "既存の応答の証拠（StandardSafe.front_response）が全BuiltinArgsで型付きの非exitの応答を返す。"
                    "群Aの台帳はE01〜E15の出典行に名前がないことから仮定側へ置いた",
          "receivers": ["L60.29", "L70", "R50"]}]
classification[front["id"]] = "合成"

covers = {"collection": "StandardModel.collection_rows", "scope": "StandardModel.scope_rows",
          "io": "StandardModel.io_rows",
          "store": "StandardModel.Primitive.store_rows・StandardModel.store_shape・StandardModel.reference_rows",
          "issue": "StandardModel.pathBases_shape", "body": "StandardModel.body_typed・StandardModel.body_scoped",
          "resource": "StandardModel.resource_table・StandardModel.release_exists"}
connected = []
for row in ledger:
    if classification[row["id"]] != "合成":
        continue
    lookups = [c.get("composition_lookup") for c in row.get("name_correspondence", [])] + \
              [c.get("composition_lookup") for c in row.get("helper_correspondence", [])]
    if row["id"] == front["id"]:
        lookups = ["StandardModel.Primitive.p377"]
    lookups += ["StandardModel." + m["composition_lookup"] for m in f1["moved"] if m["id"] == row["id"]]
    for lookup in sorted({x for x in lookups if x}):
        kind, key = lookup.split(".")[1], lookup.split(".")[-1]
        if kind == "Primitive":
            if (row["id"], "Primitive." + key) in f1_connected:
                continue
            assert key not in numeric | operator, (row["id"], key)
            group = next(g for g, s in [("collection", collection), ("scope", scope), ("io", io),
                                        ("store", store), ("issue", issue)] if key in s)
            unit = "L60.26" if group == "collection" else "L60.28"
            entry = {"id": row["id"], "lean_name": row["lean_name"], "row": "Primitive." + key,
                     "lookup_name": names[key], "unit": unit, "group": group, "cover": covers[group]}
            if key in families:
                entry["family"] = "StandardModel." + families[key]
        elif kind == "Body":
            entry = {"id": row["id"], "lean_name": row["lean_name"], "row": "Body." + key,
                     "lookup_name": keys[key], "unit": "L60.27", "group": "body", "cover": covers["body"]}
        else:
            assert lookup == "StandardModel.resource_iff", lookup
            entry = {"id": row["id"], "lean_name": row["lean_name"], "row": "resource_iff",
                     "lookup_name": "File.Handle", "unit": "L60.28", "group": "resource",
                     "cover": covers["resource"]}
        connected.append(entry)

before_keys = f1["summary"]["composition_child_keys"]["after"]
child_keys = {"before": before_keys, "after": len(keys) + len(names) + 1, "bodies": len(keys),
              "builtin_signatures": len(names), "resource_names": 1, "added": len(moved)}
assert child_keys["after"] == before_keys + len(moved)
summary = {"moved_to_composition": len(moved), "connected_entries": len(connected),
           "connected_by_unit": {u: sum(r["unit"] == u for r in connected) for u in ["L60.26", "L60.27", "L60.28"]},
           "connected_by_group": {g: sum(r["group"] == g for r in connected) for g in covers},
           "connected_rows": len({r["id"] for r in connected}),
           "classification_after": {c: sum(v == c for v in classification.values()) for c in ["合成", "仮定"]},
           "ledger_rows": len(ledger), "composition_child_keys": child_keys,
           "declarations_added": ["StandardModel.byteOrder（ByteOrder.BigEndian・ByteOrder.LittleEndian）"]}
result = {"summary": summary, "moved": moved, "connected": connected}
if "--json" in sys.argv:
    print(json.dumps(result, ensure_ascii=False))
else:
    write(HERE / "ledger-diff.json", result)
    print(json.dumps(summary, ensure_ascii=False))
