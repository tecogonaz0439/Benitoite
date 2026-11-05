# -*- coding: utf-8 -*-
"""公理監査の対象モジュールと必須の入口を再生成する（群F2の同名の台本に倣う）。

新しい3モジュールは全宣言の署名と依存を印字する。証人を渡す先の既存の入口は、必須の名前として署名を印字する。"""
import json
import re
from support import CHANGE, HERE, MODULES, PREFIX, module_path, write

# 証人を渡す先と、証人が読む既存の入口（実署名を印字する）。
existing = ["StandardModel.core", "StandardModel.targets", "StandardModel.program_typed",
            "StandardModel.program_wellFormed", "StandardModel.collection_rows", "StandardModel.scope_rows",
            "StandardModel.io_rows", "StandardModel.pure_rows", "StandardModel.row_lookup",
            "StandardModel.PureRow", "StandardModel.IORow", "StandardModel.PureRow.Satisfiable",
            "StandardModel.numeric_inputs", "StandardModel.operator_inputs", "StandardModel.arities",
            "StandardModel.option_declarations", "StandardModel.http_declarations", "Tel.annotation_open",
            "Tel.annotation_substAt", "PrimSig.Scoped.inst", "HasTypeVsQ.toTel_normal", "Ty.Annotation.toTel",
            "Builtins.CoreAssumptions", "Builtins.TargetAgreement", "Builtins.ExternalAssumptions",
            "Builtins.ResponseAssumptions", "BuiltinArgs", "ExternalModel.response_value",
            "ExternalModel.response_err", "ExternalModelExamples.positiveSignature",
            "StandardHeadTail.refine_value", "HasTypeVQ.checked_opaque", "HasTypeVQ.checkedRequest_opaque",
            "parseUrlTarget_https_loopback", "groundVal_ground"]
previous = json.loads((CHANGE / "l60/f2/required-names.json").read_text())
own = []
for module in MODULES:
    text = module_path(module).read_text()
    own.extend(re.findall(r"^(?:theorem|structure|def) ([A-Za-z][\w.]*)", text, re.M))
write(HERE / "requested-modules.json", MODULES)
required = sorted(set(previous + [PREFIX + n for n in existing]))
write(HERE / "required-names.json", required)
write(HERE / "referenced-names.json", [])
print(json.dumps({"modules": len(MODULES), "required": len(required), "own_source_names": len(own)},
                 ensure_ascii=False))
