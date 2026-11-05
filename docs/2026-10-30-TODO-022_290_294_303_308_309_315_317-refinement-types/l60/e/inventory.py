# -*- coding: utf-8 -*-
"""公理監査の対象モジュールと、既存・追加の必須入口を再生成する。"""
import json
import re
from support import CHANGE, HERE, MODULES, PREFIX, module_path, write

# 解放の八遷移・選択・useの既存の葉と、群Cの三モデルの入口（実署名を印字する）。
existing = ["StateTyE.return_release", "StateTyE.return_release_failure", "StateTyE.escape_release",
            "StateTyE.escape_release_failure", "StateTyE.error_release", "StateTyE.error_release_failure",
            "StateTyE.exit_release", "StateTyE.exit_release_failure", "ContTy.release_response_exists",
            "ContTy.selected_release", "ContTy.selected_release_step", "step_release_selected",
            "Builtins.selectRelease_response", "StateTyE.use_all", "ResourceRelease.response",
            "ResourceRelease.canonical", "ResourceRelease.typed_response",
            "ResourceRelease.targets_classification", "ModelScopeConditions.core",
            "ExternalModels.model_core", "ExternalModels.targets_core", "ExternalModels.http_core",
            "ExternalModels.conditions", "ExternalModels.shape_inputs", "ExternalModels.handle_inputs",
            "ExternalModels.model_no_response_kind", "ExternalModel.response_err",
            "ExternalSignatureLeaves.handle_not_release", "StandardModel.resource_iff",
            "StandardModel.builtins_lookup_iff", "ModelTargets.store_shape",
            "PrimSig.StoreShape.sourceTelRows", "BuiltinArgs.of_fields",
            "ExternalModel.scope_conditions", "ModelScopeConditions.of_responses"]
own = []
for module in MODULES:
    text = module_path(module).read_text()
    for name in re.findall(r"^(?:theorem|structure|def) ([A-Za-z][\w.]*)", text, re.M):
        own.append(name)
previous = json.loads((CHANGE / "l60/c/required-names.json").read_text())
write(HERE / "requested-modules.json", MODULES)
write(HERE / "required-names.json", sorted(set(previous + [PREFIX + n for n in existing])))
write(HERE / "referenced-names.json", [])
print(json.dumps({"modules": len(MODULES), "required": len(set(previous + existing)), "own_source_names": len(own)},
                 ensure_ascii=False))
