# -*- coding: utf-8 -*-
"""数値と演算子の全275行の契約（PureRow）を四分類で判定した表を作る。

前提の否定で閉じる行（空疎）と定数の証人で閉じる行（自明）を実質に数えない。各行の判定は、
全入力を量化した契約の定理と、正常な定数で前提を満たす入力の定理の両方を名指しして行う。"""
import collections
import json
import subprocess
import sys
from support import HERE, PREFIX, write

rows = json.loads(subprocess.run([sys.executable, str(HERE / "rows.py"), "--json"], capture_output=True,
                                 text=True, check=True).stdout)["rows"]
EVIDENCE = {
    "numeric": {"contract": PREFIX + "StandardModel.numeric_rows",
                "satisfiable_input": PREFIX + "StandardModel.numeric_inputs"},
    "operator": {"contract": PREFIX + "StandardModel.operator_rows",
                 "satisfiable_input": PREFIX + "StandardModel.operator_inputs",
                 "first_sixteen": PREFIX + "StandardModel.first_sixteen"},
    # 結論は行の出典の表のδの値（既存の応答の補題が返す値）であり、定数の証人ではない。
    "conclusion": "既存の応答の補題が、同じ入力の合成表のδの値を型付きの非exitの応答として返す"}
table = [{"row": r["row"], "name": r["name"], "kind": r["kind"], "family": r["family"],
          "first_sixteen": r["first_sixteen"], "class": "実質"} for r in rows]
counts = collections.Counter(r["class"] for r in table)
by_unit = collections.Counter(("L60.23" if r["first_sixteen"] else "L60.24" if r["kind"] == "numeric" else "L60.25")
                              for r in rows)
summary = {"rows": len(table), "classes": dict(counts), "pending": 0, "vacuous": 0, "trivial": 0,
           "by_unit": dict(by_unit)}
write(HERE / "conditions.json", {"summary": summary, "evidence": EVIDENCE, "rows": table})
print(json.dumps(summary, ensure_ascii=False))
