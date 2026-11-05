"""外部除外の二つの理由の境界と後段の契約を照合する（L60.33）。

理由ごとに、除外を作る書き出し器、比較の台本と読者、除外の単位（元定義・別本体・独立入力・入力）、
L60の支持の葉、L70の受け口、R50の実の件数を別の欄に置く。ソースの引用は文字列の出現で、
Leanの葉は records.py の閉包で照合する。R50の実の件数はまだ数えていないので「未実施」と書く。
"""
from pathlib import Path
import argparse
import json

import records

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
P = records.PREFIX

# (ファイル, そのファイルに現れる文字列)
REASONS = [
    {
        "reason": "externalType",
        "comparison": "区間の比較（全10系統の全比較と manifest 系統）",
        "producer": [("crates/benitoite/tests/desugar_export/exchange.rs", 'TyCon::External(_) => self.outside("external type")'),
                     ("crates/benitoite/tests/desugar_export/interval/manifest.rs",
                      '"definition":name,"reason":"externalType","bodies":bodies')],
        "readers": [("scripts/check/formal_interval.py", "externalType exemption has excluded definitions"),
                    ("formal/Benitoite/Interval/Exchange.lean", "readEvaluationExpected")],
        "unit": "元定義とそれに属する全別本体（manifest の definition・bodies）。独立入力の正常値は比較済みに数えない",
        "design": ("docs/design/07-quality/07-04-formal-semantics.md", "理由 `externalType` として全定義の manifest と比較報告へ残す"),
        "l60_leaves": ["ExternalNominal.transformations", "ExternalNominal.table_wf_iff", "ExternalNominal.unknown_handle",
                       "ExternalSurface.type_declared_iff", "ExternalSurface.ref_typed",
                       "ExternalSignatureLeaves.collected_contract"],
        "l70": "外部型を表せる全表層と区間の解析の読者への切替。外部型の型ID・入れ子・宣言表を元定義の型から読む",
        "r50": "未実施（両理由の実の件数は数えていない）。0件を確かめた記録はない",
    },
    {
        "reason": "external function",
        "comparison": "脱糖の差分・型検査の出力の検査（surfaceCheckAll）・網羅性の比較",
        "producer": [("crates/benitoite/tests/desugar_export.rs", '"excluded":["external function"]')],
        "readers": [("formal/DesugarDiff/Main.lean", "excluded input has definitions"),
                    ("formal/SurfaceCheck/Batch.lean", "excluded := r.excluded + 1"),
                    ("formal/SurfaceCheck/Main.lean", "Rust check excluded input")],
        "unit": "外部の宣言（関数と型）の表が空でないプログラム全体（入力単位）",
        "design": ("docs/design/07-quality/07-04-formal-semantics.md", '`excluded: ["external function"]` として除く'),
        "l60_leaves": ["ExternalSurface.ref_typed", "ExternalSurface.call_typed", "ExternalSurface.named_call",
                       "ExternalSurface.partial_call", "StateTyE.external_response_step", "step_external_selected",
                       "StandardModel.positive_inputs", "StandardModel.core"],
        "l70": "外部の宣言表を持つ利用者Pの収集、全表層の検査器・脱糖・網羅性への組込み、交換の版の切替",
        "r50": "未実施（両理由の実の件数は数えていない）。0件を確かめた記録はない",
    },
]

# O168 の名目性・不透明性の内側の葉（受理と拒否の対）。
OPACITY = ["ExternalSignatureLeaves.handle_not_source", "ExternalSignatureLeaves.non_binding_pattern_rejected",
           "ExternalSignatureLeaves.constructor_value_rejected", "ExternalSignatureLeaves.mismatched_handle",
           "ExternalSignatureLeaves.handle_typed_iff", "ExternalNominal.transformed_distinct"]

# 後段へ渡す契約（受け手・完全名・受け口）。
CONTRACTS = [
    ("L70", ["StandardModel.collection_inputs", "StandardModel.scope_inputs", "StandardModel.io_inputs"],
     "合成表の96行の契約の前提を満たす入力。利用者Pへの収集の後も同じ署名の形で読む"),
    ("L70", ["StandardModel.substitution_inputs", "StandardModel.admits_sat_input", "StandardModel.io_field_inputs",
             "StandardModel.positive_inputs"], "28+1欄の前提を満たす正常な入力"),
    ("L70", ["StandardModel.normal_facts"], "純粋な正常応答の結果型の篩の事実"),
    ("R50", ["StandardModel.collection_rows", "StandardModel.pure_rows", "StandardModel.io_rows"],
     "合成表のδ・IO応答の行と、仮定側150名の台帳（群F2の assumptions.json）"),
    ("R50", ["StandardModel.collection_rows", "StandardModel.store_transitions", "StandardModel.store_lookup"],
     "関数値が到達しうる27行（function-values.json）。生lambdaとclosureの二表現について、値を保存・射影する"
     "22行は同じ値を返すか、値の形を調べる5行は同じ結果を返すかを、処理系の応答と比較する入力に含める"),
]


def check(nodes):
    out = []
    for row in REASONS:
        for rel, needle in row["producer"] + row["readers"] + [row["design"]]:
            text = (ROOT / rel).read_text()
            assert needle in text, (rel, needle)
        for name in row["l60_leaves"]:
            assert P + name in nodes and nodes[P + name]["kind"] == "theorem", name
        out.append(row | {"producer": [f"{r}: {n}" for r, n in row["producer"]],
                          "readers": [f"{r}: {n}" for r, n in row["readers"]],
                          "design": f"{row['design'][0]}: {row['design'][1]}"})
    for name in OPACITY:
        assert P + name in nodes and nodes[P + name]["kind"] == "theorem", name
    contracts = []
    for receiver, names, note in CONTRACTS:
        for name in names:
            assert P + name in nodes, name
        contracts.append({"receiver": receiver, "names": names, "contract": note})
    function_values = json.loads((HERE / "function-values.json").read_text())
    assert len(function_values["rows"]) == 27
    return {"reasons": out, "opacity": OPACITY, "contracts": contracts,
            "function_values": {"rows": [r["name"] for r in function_values["rows"]], "counts": function_values["counts"]}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    data = check(records.load_graph(args.log))
    if args.verify:
        assert json.loads((HERE / "boundary.json").read_text()) == data
        print(json.dumps({"verified": True}))
        return
    (HERE / "boundary.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print(json.dumps({"reasons": len(data["reasons"]), "contracts": len(data["contracts"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
