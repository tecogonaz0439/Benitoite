"""合成表の29欄・三モデルの87欄・合成表の行の契約96行を四分類で照合する（L60.32）。

29欄は群F2の記録に、群Gが合成表の上で示した前提を満たす入力の定理を重ねる。87欄は群Eの記録を件数と
前提の有無で照合する。96行は群F2の保留の行の集合と、入力の定理の場合の一覧が一致することを確かめる。
前提を持たない三欄（state_effect・ref_get・ref_set）と三モデルの sat_unconstrained は、第2.4節の定義
（充足可能な前提に依存せず、定数の証人等で結論が閉じる）に従い自明に数える（2026-11-05の設計者の決定）。
L50と群Eで受け入れた分類（実質）との差は、各行の `previous` と要約の `difference` に残す。
証人の完全名は records.py の閉包で照合する。
"""
from pathlib import Path
import argparse
import collections
import json
import re

import records

HERE = Path(__file__).resolve().parent
CHANGE = HERE.parents[1]
ROOT = HERE.parents[3]
LEAN = ROOT / "formal/Benitoite/Release/Refinement"
P = records.PREFIX

NO_PREMISE = ["state_effect", "ref_get", "ref_set"]
# 群Eの記録で実質とした三モデルの欄のうち、第2.4節の定義で自明に当たるもの（理由）。
MODEL_TRIVIAL = {
    **{f: "前提を持たない。固定の署名又は定義の値（rfl）で閉じる" for f in NO_PREMISE},
    "sat_unconstrained": "任意のP・C・aについて定義で真（ModelConstraints.sat_unconstrained と同じく rfl）",
}
# detail.md 第2.4節の目標件数（新12欄と87欄）。
TARGET = {"新12": {"実質": 7, "自明": 3, "空疎": 2}, "合計87": {"実質": 76, "自明": 3, "空疎": 8}}

# 群F2で保留とした15欄の、合成表の上の入力の定理と対照。
WITNESS = {
    **{f: ("StandardModel.substitution_inputs",
           "Integerと鍵の制約を持つ型変数・恒等の改名・Integerへの具体化・Map.getの行",
           "Floatは鍵の制約を満たさない（StandardModel.admits_sat_input の第二成分）")
       for f in ["sat_rename", "admits_rename", "sat_values", "admits_values", "sat_renameTypes",
                 "admits_renameTypes", "sat_subst", "admits_subst"]},
    "external_typed": ("StandardModel.positive_inputs",
                       "外部関数 `0 < self` を一つ持つ外部宣言の表と、正常値1の生応答",
                       "同じ入力にerrの応答も属する（positive_inputs の第二成分）"),
    "external_no_targets": ("StandardModel.positive_inputs",
                            "external_typed と同じ入力。結論の空の観測は同じ関係の証拠から読む",
                            "同上"),
    "admits_sat": ("StandardModel.admits_sat_input", "Map.getの行とIntegerの二つの型引数",
                   "Floatは鍵の制約を満たさない"),
    **{f: ("StandardModel.io_field_inputs",
           "File.readTextInの行と保持したパス。応答は合成表のIO応答の存在から選ぶ",
           "なし（IO応答の関係は正常応答の存在を要求しない）")
       for f in ["io_typed", "io_kind", "io_exists", "io_target"]},
}


def core_fields():
    """CoreAssumptionsの28欄（継承の三構造体の欄を含む）とTargetAgreementの1欄を、ソースの順で読む。"""
    def fields(file, structure):
        text = (LEAN / file).read_text()
        body = re.split(r"^(?:structure|theorem|def|namespace|end|/--) ",
                        text.split("structure " + structure, 1)[1], maxsplit=1, flags=re.M)[0]
        return [(n, " ".join(t.split())) for n, t in re.findall(r"^  (\w+) :(.*?)(?=^  (?:/--.*?-/\s*)?\w+ :|\Z)",
                                                             body, re.M | re.S)]
    order = []
    for file, structure, group in [("SubstitutionContracts.lean", "Builtins.ValueAssumptions", "置換8"),
                                   ("SubstitutionContracts.lean", "Builtins.TypeAssumptions", "置換8"),
                                   ("ExternalResponse.lean", "Builtins.ExternalAssumptions", "外部3"),
                                   ("BuiltinResponse.lean", "Builtins.ResponseAssumptions", "応答4"),
                                   ("ConstraintAssumptions.lean", "Builtins.CoreAssumptions", "独自13"),
                                   ("BuiltinResponse.lean", "Builtins.TargetAgreement", "対象1")]:
        order += [(n, t, group) for n, t in fields(file, structure)]
    return order


def row_witnesses():
    """入力の定理の場合の一覧から、行ごとの族の定理を読む。"""
    found = {}
    for file, theorem in [("StandardModelCollectionInputs.lean", "collection_inputs"),
                          ("StandardModelIOInputs.lean", "scope_inputs"),
                          ("StandardModelIOInputs.lean", "io_inputs")]:
        text = (LEAN / file).read_text()
        body = text.split(f"theorem {theorem} ", 1)[1].split("\n\n", 1)[0]
        for row, name in re.findall(r"case (p\d+) => exact ((?:PureRow|IORow)\.Satisfiable\.\w+)", body):
            assert row not in found, row
            found[row] = {"family": "StandardModel." + name, "aggregate": "StandardModel." + theorem}
    return found


def build(nodes):
    f2 = json.loads((CHANGE / "l60/f2/conditions.json").read_text())
    e = json.loads((CHANGE / "l60/e/conditions.json").read_text())
    order = core_fields()
    assert [n for n, _, _ in order] == [r["field"] for r in f2["fields"]], "29欄の並び"
    fields = []
    for (name, text, group), old in zip(order, f2["fields"]):
        assert old["group"] == group, name
        premise = "→" in text or "∀" in text
        assert premise == (name not in NO_PREMISE), name
        row = {"field": name, "group": group, "premises": premise, "f2": old["judgment"],
               "reader": old["reader"], "premise_negation": old["premise_negation"]}
        if old["judgment"] == "保留":
            witness, normal, reject = WITNESS[name]
            assert P + witness in nodes and nodes[P + witness]["kind"] == "theorem", witness
            row.update(judgment="実質", witness=witness, normal_input=normal, contrast=reject,
                       conclusion_trivial=old["conclusion_trivial"] + "。入力の型・形又は応答の証拠を使う")
        elif name in NO_PREMISE:
            assert old["judgment"] == "実質", name
            row.update(judgment="自明", previous=old["judgment"],
                       conclusion_trivial=MODEL_TRIVIAL[name],
                       note="第2.4節の定義に従い自明に数える（2026-11-05の設計者の決定）。L50の受け入れの分類は実質")
        else:
            row.update(judgment=old["judgment"], witness=old["satisfiable_input"],
                       conclusion_trivial=old["conclusion_trivial"])
        fields.append(row)
    assert not WITNESS.keys() - {r["field"] for r in fields if r.get("witness") in {w for w, _, _ in WITNESS.values()}}
    # 87欄の照合
    models = e["rows"]
    count = collections.Counter((r["column"], r["judgment"]) for r in models)
    assert count == {("既存75", "実質"): 69, ("新12", "実質"): 7, ("既存75", "空疎"): 6,
                     ("新12", "自明"): 3, ("新12", "空疎"): 2}, count
    assert e["pending"] == 0 and e["not_satisfied"] == 0 and sorted(e["no_premise_fields"]) == sorted(NO_PREMISE)
    no_premise_models = [r for r in models if r["field"] in NO_PREMISE]
    assert len(no_premise_models) == 9 and all(r["judgment"] == "実質" and not r["premises"] for r in no_premise_models)
    reclassified = []
    for r in models:
        if r["column"] == "既存75" and r["field"] in MODEL_TRIVIAL:
            assert r["judgment"] == "実質", (r["model"], r["field"])
            reclassified.append({"model": r["model"], "field": r["field"], "previous": "実質", "judgment": "自明",
                                 "reason": MODEL_TRIVIAL[r["field"]], "source": "l60/e/conditions.json"})
    assert len(reclassified) == 12
    changed = {(r["model"], r["field"]) for r in reclassified}
    models = [r | {"judgment": "自明"} if (r["model"], r["field"]) in changed else r for r in models]
    # 96行
    witnesses = row_witnesses()
    pending = {r["row"].split(".")[1]: r for r in f2["rows"]}
    assert set(witnesses) == set(pending) and len(witnesses) == 96, set(witnesses) ^ set(pending)
    rows = []
    for row, w in sorted(witnesses.items()):
        for n in w.values():
            assert P + n in nodes, n
            assert records.closure_path(nodes, P + w["aggregate"], P + w["family"]), (row, w)
        old = pending[row]
        rows.append({"row": old["row"], "name": old["name"], "unit": old["unit"], "contract": old["contract"],
                     "f2": old["class"], "judgment": "実質", "witness": w["family"], "aggregate": w["aggregate"]})

    def tally(items, key="judgment"):
        return dict(collections.Counter(r[key] for r in items))
    summary = {
        "composite29": tally(fields),
        "composite29_previous": dict(collections.Counter(r.get("previous", r["judgment"]) for r in fields)),
        "models87": {column: tally([r for r in models if r["column"] == column]) for column in ["既存75", "新12"]}
        | {"合計87": tally(models)},
        "models87_previous": e["counts"],
        "target": TARGET,
        "rows96": tally(rows),
        "rows96_by_aggregate": tally(rows, "aggregate"),
        "resolved_fields": sorted(WITNESS),
        "no_premise_fields": NO_PREMISE,
    }
    total = summary["models87"]["合計87"]
    summary["difference_from_target"] = {k: total.get(k, 0) - TARGET["合計87"].get(k, 0) for k in ["実質", "自明", "空疎"]}
    assert summary["composite29"] == {"実質": 24, "自明": 5}
    assert summary["models87"]["既存75"] == {"実質": 57, "自明": 12, "空疎": 6}
    assert summary["models87"]["新12"] == TARGET["新12"]
    assert summary["models87"]["合計87"] == {"実質": 64, "自明": 15, "空疎": 8}
    return {"summary": summary, "fields": fields, "model_reclassified": reclassified, "rows": rows}


def write_markdown(data):
    s = data["summary"]
    lines = ["# 四分類の照合（L60.32）", "",
             "生成物（[conditions.py](conditions.py)）。完全名の接頭辞 `Benitoite.Release.Refinement.` を除く。", "",
             "## 合成表の29欄", "",
             "| 欄 | 組 | 前提 | 群F2 | 判定 | 前提を満たす入力（証人） | 対照 |", "|---|---|---|---|---|---|---|"]
    for r in data["fields"]:
        lines.append(f"| {r['field']} | {r['group']} | {'あり' if r['premises'] else 'なし'} | {r['f2']} | "
                     f"{r['judgment']}{'（前: ' + r['previous'] + '）' if 'previous' in r else ''} | "
                     f"{r.get('witness', '前提なし')} | {r.get('contrast', '')} |")
    lines += ["", f"件数: {s['composite29']}（前の分類: {s['composite29_previous']}）。", "",
              "## 三モデルの87欄", "",
              "群Eの記録で実質とした12欄（三モデルの state_effect・ref_get・ref_set・sat_unconstrained）を自明に数える。", "",
              "| 列 | 件数 | 群Eの記録 | detail.mdの目標 |", "|---|---|---|---|"]
    for column in ["既存75", "新12", "合計87"]:
        lines.append(f"| {column} | {s['models87'][column]} | {s['models87_previous'][column]} | {s['target'].get(column, '（なし）')} |")
    lines += ["", f"87欄の目標との差: {s['difference_from_target']}。", "",
              "## 合成表の行の契約96行", "",
              "| 集約の定理 | 行数 |", "|---|---:|"]
    for k, v in sorted(s["rows96_by_aggregate"].items()):
        lines.append(f"| `{k}` | {v} |")
    lines += ["", "行ごとの族の定理は conditions.json の rows にある。全96行を実質とする。"]
    (HERE / "cases.md").write_text("\n".join(lines) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True, help="graph.lean の出力")
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    data = build(records.load_graph(args.log))
    if args.verify:
        assert json.loads((HERE / "conditions.json").read_text()) == data
        print(json.dumps({"verified": True, **data["summary"]["composite29"]}, ensure_ascii=False))
        return
    (HERE / "conditions.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    write_markdown(data)
    print(json.dumps(data["summary"], ensure_ascii=False))


if __name__ == "__main__":
    main()
