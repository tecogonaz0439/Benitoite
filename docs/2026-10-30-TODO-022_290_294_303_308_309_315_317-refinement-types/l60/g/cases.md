# 四分類の照合（L60.32）

生成物（[conditions.py](conditions.py)）。完全名の接頭辞 `Benitoite.Release.Refinement.` を除く。

## 合成表の29欄

| 欄 | 組 | 前提 | 群F2 | 判定 | 前提を満たす入力（証人） | 対照 |
|---|---|---|---|---|---|---|
| sat_rename | 置換8 | あり | 保留 | 実質 | StandardModel.substitution_inputs | Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分） |
| admits_rename | 置換8 | あり | 保留 | 実質 | StandardModel.substitution_inputs | Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分） |
| sat_values | 置換8 | あり | 保留 | 実質 | StandardModel.substitution_inputs | Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分） |
| admits_values | 置換8 | あり | 保留 | 実質 | StandardModel.substitution_inputs | Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分） |
| sat_renameTypes | 置換8 | あり | 保留 | 実質 | StandardModel.substitution_inputs | Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分） |
| admits_renameTypes | 置換8 | あり | 保留 | 実質 | StandardModel.substitution_inputs | Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分） |
| sat_subst | 置換8 | あり | 保留 | 実質 | StandardModel.substitution_inputs | Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分） |
| admits_subst | 置換8 | あり | 保留 | 実質 | StandardModel.substitution_inputs | Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分） |
| external_typed | 外部3 | あり | 保留 | 実質 | StandardModel.positive_inputs | 同じ入力にerrの応答も属する（positive_inputs の第二成分） |
| external_exists | 外部3 | あり | 自明 | 自明 | 前提は満たせるが結論は前提を読まない |  |
| external_no_targets | 外部3 | あり | 保留 | 実質 | StandardModel.positive_inputs | 同上 |
| delta_typed | 応答4 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.numeric_inputs・Benitoite.Release.Refinement.StandardModel.operator_inputs（数値166行と演算子109行の基本型の定数の入力） |  |
| io_typed | 応答4 | あり | 保留 | 実質 | StandardModel.io_field_inputs | なし（IO応答の関係は正常応答の存在を要求しない） |
| io_kind | 応答4 | あり | 保留 | 実質 | StandardModel.io_field_inputs | なし（IO応答の関係は正常応答の存在を要求しない） |
| io_exists | 応答4 | あり | 保留 | 実質 | StandardModel.io_field_inputs | なし（IO応答の関係は正常応答の存在を要求しない） |
| sig_scoped | 独自13 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.row_lookup（全377行のlookup） |  |
| sat_unconstrained | 独自13 | あり | 自明 | 自明 | 前提は満たせるが結論は入力を読まない |  |
| admits_sat | 独自13 | あり | 保留 | 実質 | StandardModel.admits_sat_input | Floatは鍵の制約を満たさない |
| release_exists | 独自13 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.resource_input（任意のP・ストア・番号の型付きFile.Handle） |  |
| pathBases_shape | 独自13 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.row_lookup の Primitive.p156（種類 pathBases） |  |
| io_op | 独自13 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.row_lookup のIOと終了の10行（Primitive.io） |  |
| opEff_io | 独自13 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.row_lookup の Primitive.p373（Console.Write） |  |
| effect_ops | 独自13 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.effects_member |  |
| state_effect | 独自13 | なし | 実質 | 自明（前: 実質） | 前提なし |  |
| ref_get | 独自13 | なし | 実質 | 自明（前: 実質） | 前提なし |  |
| ref_set | 独自13 | なし | 実質 | 自明（前: 実質） | 前提なし |  |
| store_shape | 独自13 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.row_lookup（発行以外の376行） |  |
| store_admits | 独自13 | あり | 実質 | 実質 | Benitoite.Release.Refinement.StandardModel.row_lookup の参照と明示遅延の5行と、型引数の個数の一致する型引数の列 |  |
| io_target | 対象1 | あり | 保留 | 実質 | StandardModel.io_field_inputs | なし（IO応答の関係は正常応答の存在を要求しない） |

件数: {'実質': 24, '自明': 5}（前の分類: {'実質': 27, '自明': 2}）。

## 三モデルの87欄

群Eの記録で実質とした12欄（三モデルの state_effect・ref_get・ref_set・sat_unconstrained）を自明に数える。

| 列 | 件数 | 群Eの記録 | detail.mdの目標 |
|---|---|---|---|
| 既存75 | {'実質': 57, '空疎': 6, '自明': 12} | {'実質': 69, '空疎': 6} | （なし） |
| 新12 | {'実質': 7, '自明': 3, '空疎': 2} | {'実質': 7, '自明': 3, '空疎': 2} | {'実質': 7, '自明': 3, '空疎': 2} |
| 合計87 | {'実質': 64, '空疎': 8, '自明': 15} | {'実質': 76, '空疎': 8, '自明': 3} | {'実質': 76, '自明': 3, '空疎': 8} |

87欄の目標との差: {'実質': -12, '自明': 12, '空疎': 0}。

## 合成表の行の契約96行

| 集約の定理 | 行数 |
|---|---:|
| `StandardModel.collection_inputs` | 79 |
| `StandardModel.io_inputs` | 10 |
| `StandardModel.scope_inputs` | 7 |

行ごとの族の定理は conditions.json の rows にある。全96行を実質とする。
