# -*- coding: utf-8 -*-
"""合成表の全28+1欄と、群F2が接続した行の契約を四分類（不成立・空疎・自明・実質）と保留で記録する。

欄の分類は、前提の否定で閉じるか（空疎）、結論が入力を読まずに成り立つか（自明）、前提を満たす
入力の証人が合成表の上で確認済みか（実質）を見る。証人が合成表の上で未確認の欄・行は保留とし、
実質に数えない。全欄の四分類の照合は群Gの単位が行う。"""
import collections
import json
import subprocess
import sys
from support import HERE, PREFIX, write

M = PREFIX + "StandardModel."
CORE = M + "core"
rows = []


def field(name, group, judgment, premise, conclusion, witness, reader=CORE):
    rows.append({"field": name, "group": group, "judgment": judgment, "reader": reader,
                 "premise_negation": premise, "conclusion_trivial": conclusion, "satisfiable_input": witness})


NO = "なし。前提の否定は導出していない"
for name in ["sat_rename", "admits_rename", "sat_values", "admits_values", "sat_renameTypes",
             "admits_renameTypes", "sat_subst", "admits_subst"]:
    field(name, "置換8", "保留", NO, "結論は合成プログラムの宣言の要約による制約の判定を読む",
          "未確認。合成表の上の正常値の入力（改名・値の像・置換）を示していない")
field("external_typed", "外部3", "保留", NO, "結論は生応答の証拠（carrier・非exit、又は空観測）を読む",
      "未確認。合成プログラムの外部宣言の表での入力を示していない（三モデルの表の入力は群Eの記録）")
field("external_exists", "外部3", "自明", NO,
      "結論は入力を読まない定数のerrと空の観測で成り立つ（ExternalModel.external_assumptions）",
      "前提は満たせるが結論は前提を読まない")
field("external_no_targets", "外部3", "保留", NO, "結論は生応答の証拠を読む", "未確認（external_typed と同じ）")
field("delta_typed", "応答4", "実質", NO, "結論は合成表のδの値を型付きの非exitの応答として返す",
      M + "numeric_inputs・" + M + "operator_inputs（数値166行と演算子109行の基本型の定数の入力）")
for name in ["io_typed", "io_kind", "io_exists"]:
    field(name, "応答4", "保留", NO, "結論はIO応答の関係と対象の条件を読む",
          "未確認。IOと終了の10行の BuiltinArgs を満たす入力を合成表の上で示していない")
field("sig_scoped", "独自13", "実質", NO, "結論は行の署名の形成（PrimSig.Scoped）を読む",
      M + "row_lookup（全377行のlookup）")
field("sat_unconstrained", "独自13", "自明", NO,
      "空の制約の判定は定義で真になる（ModelConstraints.sat_unconstrained が rfl）", "前提は満たせるが結論は入力を読まない")
field("admits_sat", "独自13", "保留", NO, "結論は許容の判定から制約の判定を導く",
      "未確認。許容を満たす型引数の入力を合成表の上で示していない")
field("release_exists", "独自13", "実質", NO, "全結果の関係所属は型付き値の正準形と資源の分類を読む",
      M + "resource_input（任意のP・ストア・番号の型付きFile.Handle）")
field("pathBases_shape", "独自13", "実質", NO, "結論は発行の八欄とEnvironmentの所属を読む",
      M + "row_lookup の Primitive.p156（種類 pathBases）")
field("io_op", "独自13", "実質", NO, "結論は効果の表の所属と範囲の形を読む",
      M + "row_lookup のIOと終了の10行（Primitive.io）")
field("opEff_io", "独自13", "実質", NO, "結論は署名の種類を読む", M + "row_lookup の Primitive.p373（Console.Write）")
field("effect_ops", "独自13", "実質", NO, "結論は効果の表の所属の名前の署名を読む", M + "effects_member")
field("state_effect", "独自13", "実質", "前提を持たない", "前提を持たない閉じた命題。結論は表の効果の内容を読む", "前提なし")
field("ref_get", "独自13", "実質", "前提を持たない", "前提を持たない閉じた命題。結論は表の署名を読む", "前提なし")
field("ref_set", "独自13", "実質", "前提を持たない", "前提を持たない閉じた命題。結論は表の署名を読む", "前提なし")
field("store_shape", "独自13", "実質", NO, "結論は参照と明示遅延の形（StoreShape）を読む",
      M + "row_lookup（発行以外の376行）")
field("store_admits", "独自13", "実質", NO, "結論は許容の定義で型引数の個数の一致に帰着する",
      M + "row_lookup の参照と明示遅延の5行と、型引数の個数の一致する型引数の列")
field("io_target", "対象1", "保留", NO, "結論は署名の形の対象の条件を読む", "未確認（io_typed と同じ）",
      reader=M + "targets")
assert len(rows) == 29 and len({r["field"] for r in rows}) == 29

diff = json.loads(subprocess.run([sys.executable, str(HERE / "ledger_diff.py"), "--json"], capture_output=True,
                                 text=True, check=True).stdout)
contracts = []
for entry in diff["connected"]:
    if entry["group"] in ("collection", "scope"):
        contracts.append({"row": entry["row"], "name": entry["lookup_name"], "unit": entry["unit"],
                          "contract": "StandardModel.PureRow", "class": "保留",
                          "reason": "契約は全BuiltinArgsで示した。前提を満たす入力の証人は示していない"})
    elif entry["group"] == "io":
        contracts.append({"row": entry["row"], "name": entry["lookup_name"], "unit": entry["unit"],
                          "contract": "StandardModel.IORow", "class": "保留",
                          "reason": "契約は全BuiltinArgsと全応答で示した。前提を満たす入力の証人は示していない"})
counts = dict(collections.Counter(r["judgment"] for r in rows))
summary = {"fields": len(rows), "classes": counts,
           "by_group": {g: dict(collections.Counter(r["judgment"] for r in rows if r["group"] == g))
                        for g in ["置換8", "外部3", "応答4", "独自13", "対象1"]},
           "row_contracts": len(contracts),
           "row_classes": dict(collections.Counter(r["class"] for r in contracts)),
           "row_contracts_by_unit": dict(collections.Counter(r["unit"] for r in contracts))}
write(HERE / "conditions.json", {"summary": summary, "fields": rows, "rows": contracts})
print(json.dumps(summary, ensure_ascii=False))
