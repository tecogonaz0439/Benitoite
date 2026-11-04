# 群 C の在庫の判定

完全名の先頭は `Benitoite.Release.Refinement`。全ての名前は signatures.md と declarations.json に対応する。旧の全型等号や opaque 間の新しい共変規則を前提にしない。

| 在庫の目的 | 完了単位 | 実定理・実読者 | 判定 |
|---|---|---|---|
| Membership.canonical_opaque | .11/.13 | HasTypeVQ.canonical_opaque。通常定数を含む全閉じた値から元scopedを再構成 | 担当分完了 |
| Membership.widen_opaque | .13 | HasTypeVQ.widen_opaque。scoped の共変と scoped_forget、同じ要求の例 | 担当分完了 |
| Membership.widen_instTarget_covers | .13 | HasTypeVQ.widen_instTarget_covers。opaque/scoped の fixed/rvar、他の全型 | 担当分完了 |
| Membership.HasTypeVsQ.widen_covers | .13 | HasTypeVsQ.widen_covers。全長の列と opSigAt の実 clause.params | 担当分完了 |
| ShapeOk.common | .14 | Builtins.ShapeOk.common、全shapeの効果原子の読者 | 一般目的の担当分完了 |
| ShapeOk.eff_eq | .14 | Builtins.ShapeOk.eff_eq、inst_eff_mem の本番読者 | 一般目的の担当分完了 |
| ShapeOk.inst_eff_mem | .14 | Builtins.ShapeOk.inst_eff_mem、任意範囲列の既定の例 | 一般目的の担当分完了 |
| ShapeOk.single | .14 | Builtins.ShapeOk.single、single_inst/single_request の本番読者 | 一般目的の担当分完了 |
| ShapeOk.single_inst | .14 | Builtins.ShapeOk.single_inst、非Topの File.readTextIn の全前提の例 | 一般目的の担当分完了 |

群 B の在庫27目的の17完了を継承し、Membership4とShapeOk5の9目的を閉じた。合計26完了、残件1は `allows_bind_comp`（.30）のままである。ShapeOk の16実署名への適用とIO7行の応答・存在は .23/.35 のままであり、一般目的の完了から表全体の充足を推測しない。

群全体の外側の時間から、この9目的だけの能動時間は分離できない。一件当たり係数は未取得とし、未実証の群の旧見込みへ一律に掛けない。
