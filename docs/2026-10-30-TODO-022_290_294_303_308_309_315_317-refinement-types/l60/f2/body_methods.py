# -*- coding: utf-8 -*-
"""全130本体を、群Aの本体の証拠の三種（任意のP/B・副条件付き・固定のP/B）と、合成表での証明の方法で
分ける。証明は StandardModel.body_typed の各枝の本文から読む。"""
import collections
import json
import re
from support import CHANGE, HERE, LEAN, write

source = (LEAN / "StandardModelProgram.lean").read_text()
body = source.split("theorem body_typed", 1)[1].split("theorem definition_typed", 1)[0]
cases = dict(re.findall(r"^  case (b\d{3}) => exact (.+)$", body, re.M))
classes = {r["body"]: r for r in json.loads((CHANGE / "l60/a/resume3-body-classification.json").read_text())}
assert len(cases) == 130 and set(cases) == set(classes)

# 合成表での証明の方法。
#  一般化: 元の証明の固定のP/Bを前提（宣言・署名・lookupの条件）へ置き換えた `_of` の定理を合成表へ適用する。
#  副条件の供給: 元の副条件付きの定理へ、合成表の宣言・署名・lookupの条件を供給する。
#  写し: 元の証明の構成を、合成表の名前（写した関数参照・内部の組込み）の上で閉じた定理を使う。
#  直接: 元の任意のP/Bの定理をそのまま使う。
METHODS = [
    (r"aliases_typed|core_bodies_typed|getters_typed .+\)\.1|pairs_typed", "一般化"),
    (r"getters_typed .+\)\.2", "一般化"),
    (r"list_helpers_typed", "副条件の供給"),
    (r"StandardSafe\.(head_row_typed|toList_row_typed)", "直接"),
    (r"list_bodies_typed|nonempty_map_typed|StandardSafe\.Composed|ordinary_collection_typed|refined_collection_typed",
     "写し"),
]
rows = []
for key in sorted(cases):
    proof = cases[key]
    method = next(m for pattern, m in METHODS if re.search(pattern, proof))
    rows.append({"body": key, "name": classes[key]["name"], "kind": classes[key]["kind"],
                 "original_proof": classes[key]["proof"], "composed_proof": proof, "method": method})
table = collections.Counter((r["kind"], r["method"]) for r in rows)
summary = {"bodies": len(rows), "by_kind": dict(collections.Counter(r["kind"] for r in rows)),
           "by_method": dict(collections.Counter(r["method"] for r in rows)),
           "by_kind_and_method": {f"{k}／{m}": v for (k, m), v in sorted(table.items())}}
assert summary["by_kind"] == {"lookupなどの副条件付き": 51, "固定のP/B": 77, "任意のP/B": 2}
write(HERE / "body-methods.json", {"summary": summary, "rows": rows})
print(json.dumps(summary, ensure_ascii=False))
