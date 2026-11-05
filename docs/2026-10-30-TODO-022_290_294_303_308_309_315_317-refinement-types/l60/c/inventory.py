"""公理監査の対象モジュールと既存・追加の必須入口を再生成する。"""
import json
from support import HERE, MODULES, write

extra = ['Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_adequate', 'Benitoite.Release.Refinement.Builtins.ExternalAssumptions.received_value', 'Benitoite.Release.Refinement.ExternalModel.receive_error_no_exit', 'Benitoite.Release.Refinement.ExternalModel.receive_reject', 'Benitoite.Release.Refinement.ExternalModel.receive_value', 'Benitoite.Release.Refinement.ExternalModel.response_value', 'Benitoite.Release.Refinement.ExternalModels.conditions', 'Benitoite.Release.Refinement.ExternalModels.handle_inputs', 'Benitoite.Release.Refinement.ExternalModels.http_core', 'Benitoite.Release.Refinement.ExternalModels.model_core', 'Benitoite.Release.Refinement.ExternalModels.model_no_response_kind', 'Benitoite.Release.Refinement.ExternalModels.responses', 'Benitoite.Release.Refinement.ExternalModels.shape_inputs', 'Benitoite.Release.Refinement.ExternalModels.targets_core', 'Benitoite.Release.Refinement.ModelScopeConditions.of_responses']
previous = json.loads((HERE.parent / "b/required-names.json").read_text())
write(HERE / "requested-modules.json", MODULES)
write(HERE / "required-names.json", sorted(set(previous + extra)))
write(HERE / "referenced-names.json", [])
names = []
for path in (HERE.parent / "a").glob("declarations-*.json"):
    for row in json.loads(path.read_text()):
        if row["module"] == MODULES[0]:
            names.append(row["name"])
write(HERE / "inherited-declarations.json", sorted(names))
print(json.dumps({"modules": len(MODULES), "inherited": len(names)}, ensure_ascii=False))
