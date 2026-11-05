# -*- coding: utf-8 -*-
"""三モデルの87欄を、既存75欄と新12欄の別の列で四分類し、欄ごとの根拠を出す。"""
import collections
import json
import re
from support import CHANGE, HERE, PREFIX, ROOT, write

models = ["model", "targets", "http"]
old_name = {"Model.builtins": "model", "ModelTargets.builtins": "targets", "ModelHttp.builtins": "http"}
previous = {(r["model"], r["field"]): r for r in json.loads((CHANGE / "l60/c/conditions.json").read_text())}
l50 = {(old_name[r["model"]], r["field"]): r
       for r in json.loads((CHANGE / "l50/l/condition-judgments.json").read_text())}
assert len(previous) == 87 and len(l50) == 75

def fields(file, structure):
    text = (ROOT / "formal/Benitoite/Release/Refinement" / file).read_text()
    body = re.split(r"^(?:structure|theorem|def|namespace|end|/--) ", text.split("structure " + structure, 1)[1],
                    maxsplit=1, flags=re.M)[0]
    found = re.findall(r"^  (\w+) :(.*?)(?=^  \w+ :|\Z)", body, re.M | re.S)
    return {name: " ".join(kind.split()) for name, kind in found}

source = {}
for file, structure in [("SubstitutionContracts.lean", "Builtins.ValueAssumptions"),
                        ("SubstitutionContracts.lean", "Builtins.TypeAssumptions"),
                        ("BuiltinResponse.lean", "Builtins.ResponseAssumptions"),
                        ("BuiltinResponse.lean", "Builtins.TargetAgreement"),
                        ("TargetModelConditions.lean", "ModelScopeConditions")]:
    source.update(fields(file, structure))
inherited_fields = sorted({f for _, f in l50})
assert set(source) == set(inherited_fields), set(source) ^ set(inherited_fields)
external = fields("ExternalResponse.lean", "Builtins.ExternalAssumptions")
assert set(external) == {"external_typed", "external_exists", "external_no_targets"}, external
core_text = (ROOT / "formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean").read_text()
release = re.search(r"^  release_exists :(.*?)(?=^  \w+ :)", core_text, re.M | re.S)[1]
source.update(external)
source["release_exists"] = " ".join(release.split())

vacuous_model = {"delta_typed": 1, "io_typed": 2, "io_kind": 3, "io_exists": 4, "io_op": 5, "io_target": 6}
projection = {"model": "ExternalModels.model_core", "targets": "ExternalModels.targets_core",
              "http": "ExternalModels.http_core"}
rows = []
for model in models:
    for field in inherited_fields + ["external_typed", "external_exists", "external_no_targets", "release_exists"]:
        old = previous[(model, field)]
        premised = "→" in source[field]
        row = {"model": model, "field": field, "column": "既存75" if field in inherited_fields else "新12",
               "premises": premised,
               "reader": PREFIX + "ExternalModels.ModelCase.composition"}
        if field in inherited_fields:
            judgment = "空疎" if l50[(model, field)]["premises_prove_false"] else "実質"
            if judgment == "空疎":
                assert model == "model" and field in vacuous_model
                row["premise_negation"] = "%sExternalModels.model_vacuous_premises の第%d成分（拡張表）、L50の %s" % (
                    PREFIX, vacuous_model[field], l50[(model, field)]["theorem"])
                row["conclusion_trivial"] = "判定不要（前提の否定で閉じる）"
                row["satisfiable_input"] = "なし（前提がFalse）"
            else:
                row["premise_negation"] = "なし。L50の前提検査（同じ前提からFalseの導出を試す）で閉じない"
                row["conclusion_trivial"] = ("前提を持たない閉じた命題。結論は表の署名・効果の内容を読む" if not premised
                                             else "結論は入力の型・置換・応答の証拠を読む。定数の証人では閉じない")
                row["satisfiable_input"] = ("L50の到達枝の証拠（%s）を、同じPの七射影とδ/IO/refGet/refSet/effKindの一致"
                                            "（ExternalModel.scope_conditions・ModelScopeConditions.of_responses・"
                                            "BuiltinArgs.of_fields）で拡張表へ移す" % l50[(model, field)]["theorem"])
            row["source"] = "l50/l/condition-judgments.json"
        else:
            if field == "external_exists":
                judgment = "自明"
                row["premise_negation"] = "なし"
                row["conclusion_trivial"] = PREFIX + "ExternalModels.ModelCase.external_constant（入力を読まない定数errと空観測）"
                row["satisfiable_input"] = PREFIX + "ExternalModels.ModelCase.new_field_inputs（前提は満たせるが結論は前提を読まない）"
            elif field == "release_exists" and model != "targets":
                judgment = "空疎"
                row["premise_negation"] = PREFIX + "ExternalModels.ModelCase.release_premise_false（資源名なし）"
                row["conclusion_trivial"] = "判定不要（前提の否定で閉じる）"
                row["satisfiable_input"] = "なし（前提がFalse）"
            elif field == "release_exists":
                judgment = "実質"
                row["premise_negation"] = "なし"
                row["conclusion_trivial"] = ("全結果の関係所属は型付き値のcanonicalと分類を読む（"
                                             + PREFIX + "ResourceRelease.Table.release_all）。関係はopaque資源定数以外を断る（"
                                             + PREFIX + "ResourceRelease.Table.release_value）")
                row["satisfiable_input"] = PREFIX + "ExternalModels.targets_resource_input（任意のP・Ψ・番号の型付きFile.Handle）"
            else:
                judgment = "実質"
                row["premise_negation"] = "なし"
                row["conclusion_trivial"] = "生応答の証拠（carrier・非exit、又は空観測）を読む。定数の証人では閉じない"
                row["satisfiable_input"] = (PREFIX + "ExternalModels.ModelCase.new_field_inputs・"
                                            + PREFIX + "ExternalModels.shape_inputs・handle_inputs（正常値・任意ストア）")
            row["source"] = "l60/c/conditions.json"
        assert judgment == old["judgment"], (model, field, judgment, old["judgment"])
        row["judgment"] = judgment
        rows.append(row)

assert len(rows) == 87
counts = {}
for column in ["既存75", "新12"]:
    counts[column] = dict(collections.Counter(r["judgment"] for r in rows if r["column"] == column))
counts["合計87"] = dict(collections.Counter(r["judgment"] for r in rows))
assert counts["既存75"] == {"実質": 69, "空疎": 6}
assert counts["新12"] == {"実質": 7, "自明": 3, "空疎": 2}
assert counts["合計87"] == {"実質": 76, "自明": 3, "空疎": 8}
no_premise = sorted({r["field"] for r in rows if not r["premises"]})
write(HERE / "conditions.json", {"counts": counts, "pending": 0, "not_satisfied": 0,
                                 "no_premise_fields": no_premise, "rows": rows})
print(json.dumps({"counts": counts, "no_premise_fields": no_premise}, ensure_ascii=False))
