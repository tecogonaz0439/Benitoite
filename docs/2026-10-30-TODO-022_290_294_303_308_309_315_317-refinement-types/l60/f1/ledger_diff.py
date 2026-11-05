# -*- coding: utf-8 -*-
"""群Aの台帳（l60/a/ledger-*.json）に対する群F1の差分を作る。前の群の記録は書き換えない。

1. Reference.new・Reference.update・Lazy.forceの三行を仮定側から合成側へ移す。
2. Process.exitの行は仮定側に残し、理由を実際の実行の規則（ioResponseを読む）へ改める。
3. 数値の純粋な行と演算子の行の全275行へ、合成表の行・族の補題・全場合の定理を対応させる。"""
import json
import subprocess
import sys
from support import CHANGE, HERE, PREFIX, write

ledger = []
for part in sorted((CHANGE / "l60/a").glob("ledger-[0-9][0-9].json")):
    ledger.extend(json.loads(part.read_text()))
by_name = {}
for row in ledger:
    by_name.setdefault(row["lean_name"], []).append(row)
store = json.loads((HERE / "store-signatures.json").read_text())
moved = []
for item in store["rows"]:
    [old] = by_name[item["name"]]
    assert old["classification"] == "仮定" and not old["evidence"], old
    moved.append({"id": old["id"], "lean_name": item["name"], "before": "仮定", "after": "合成",
                  "composition_lookup": item["row"].replace("StandardModel.", ""),
                  "signature": item["lean_definition"],
                  "evidence": [PREFIX + n for n in ["StandardModel.row_lookup", "StandardModel.store_transitions",
                                                    "StandardModel.store_shape", "StandardModel.reference_rows"]],
                  "reason": "δ・IO応答を持たず、実行は専用の遷移（%s）が受け持つ。署名とStoreShapeだけを合成表に置く。"
                            "Rustの登録・標準ソースの宣言・StoreShapeと照合した（store-signatures.json）" %
                            "・".join(store["process_exit"]["store_rules_without_response"][
                                {"Reference.new": "refNew", "Reference.update": "refUpdate",
                                 "Lazy.force": "force"}[item["name"]]]),
                  "receivers": ["L60.29", "L70", "R50"]})
[process] = by_name["Process.exit"]
assert process["classification"] == "仮定" and not process["evidence"]
corrected = [{"id": process["id"], "lean_name": "Process.exit", "classification": "仮定",
              "before_reason": process["reason"], "after_reason": store["process_exit_judgement"],
              "receivers": process["receivers"]}]
rows = json.loads(subprocess.run([sys.executable, str(HERE / "rows.py"), "--json"], capture_output=True,
                                 text=True, check=True).stdout)
connected = []
for item in rows["rows"]:
    candidates = [r for r in by_name.get(item["name"], []) if r["classification"] == "合成"]
    assert len(candidates) == 1, (item["name"], candidates)
    old = candidates[0]
    lookups = {c.get("composition_lookup") for c in old["name_correspondence"]}
    assert "StandardModel.Primitive." + item["row"] in lookups, (item, lookups)
    unit = "L60.24" if item["kind"] == "numeric" else "L60.25"
    if item["first_sixteen"]:
        unit = "L60.23"
    connected.append({"id": old["id"], "lean_name": item["name"], "row": "Primitive." + item["row"],
                      "unit": unit, "family": "StandardModel.PureRow." + item["family"],
                      "cover": "StandardModel." + ("numeric_rows" if item["kind"] == "numeric" else "operator_rows")
                      + ("・StandardModel.first_sixteen" if item["first_sixteen"] else ""),
                      "evidence_before": len(old["evidence"])})
# 合成表の子キー（本体・組込みの署名・資源名）。群Aの ledger-summary.json の composition_keys に、
# 加えた三行の署名を足す。丸め方式の構成子は宣言であり、子キーに数えない。
import re
signatures = (CHANGE.parent.parent / "formal/Benitoite/Release/Refinement/StandardModelSignatures.lean").read_text()
declarations = (CHANGE.parent.parent / "formal/Benitoite/Release/Refinement/StandardModelDeclarations.lean").read_text()
primitive_rows = len(set(re.findall(r"^  \| (p\d{3})$", signatures.split("inductive Primitive where", 1)[1].split("\n\n", 1)[0], re.M)))
body_rows = len(set(re.findall(r"\.(b\d{3})", declarations.split("def Body.all : List Body :=", 1)[1].split("\n", 1)[0])))
before_keys = json.loads((CHANGE / "l60/a/ledger-summary.json").read_text())["composition_keys"]
assert before_keys == 504 and primitive_rows == 376 and body_rows == 130
child_keys = {"before": before_keys, "after": body_rows + primitive_rows + 1, "bodies": body_rows,
              "builtin_signatures": primitive_rows, "resource_names": 1, "added": len(moved)}
assert child_keys["after"] == before_keys + len(moved)
summary = {"moved_to_composition": len(moved), "assumption_reason_corrected": len(corrected),
           "connected_rows": len(connected),
           "connected_by_unit": {u: sum(r["unit"] == u for r in connected) for u in ["L60.23", "L60.24", "L60.25"]},
           "classification_after": {"合成": sum(r["classification"] == "合成" for r in ledger) + len(moved),
                                    "仮定": sum(r["classification"] == "仮定" for r in ledger) - len(moved)},
           "ledger_rows": len(ledger), "composition_child_keys": child_keys}
write(HERE / "ledger-diff.json", {"summary": summary, "moved": moved, "corrected": corrected,
                                  "connected": connected})
print(json.dumps(summary, ensure_ascii=False))
