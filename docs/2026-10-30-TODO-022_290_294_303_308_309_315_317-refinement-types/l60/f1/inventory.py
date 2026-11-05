# -*- coding: utf-8 -*-
"""公理監査の対象モジュールと必須の入口を再生成する。

新しい四つのモジュールと、宣言を変えたResourceReleaseLeavesは全宣言の署名と依存を印字する。
既存のモジュールに足した宣言と、接続に使う既存の入口は必須の名前として署名を印字する。"""
import json
import re
from support import CHANGE, HERE, MODULES, PREFIX, module_path, write

REQUESTED = MODULES + [
                       "Benitoite.Release.Refinement.ResourceReleaseLeaves"]
# 既存のモジュールに足した宣言（構成子と署名の行、宣言の条件、一般化した応答）。
added = ["StandardModel.refNewSig", "StandardModel.refUpdateSig", "StandardModel.forceSig",
         "StandardModel.Primitive.p374", "StandardModel.Primitive.p375", "StandardModel.Primitive.p376",
         "StandardModel.roundingMode", "StandardDecimalResponse.Declarations",
         "StandardDecimalResponse.program_declarations", "StandardDecimalResponse.response_of"]
# 接続に使う既存の入口（実署名を印字する）。
existing = ["StandardModel.builtins", "StandardModel.program", "StandardModel.primitive_lookup",
            "StandardModel.builtins_lookup_iff", "StandardModel.option_declarations",
            "StandardModel.Primitive.signature", "StandardModel.Primitive.provider",
            "StandardModel.Primitive.name", "StandardModel.declarations",
            "StandardOperatorResponse.response", "StandardOperatorResponse.dispatch_name",
            "StandardArithmeticResponse.response_math", "StandardOrderResponse.response_math",
            "StandardStructuralEqualityResponse.response", "StandardScalarResponse.response",
            "StandardByteStringResponse.response", "StandardCharacterResponse.response",
            "StandardNumericRemainingResponse.response", "StandardIntegerAPI.response",
            "StandardIntegerTextResponse.response", "StandardConversionResponse.response",
            "StandardDecimalResponse.response", "StandardFloatMathResponse.response",
            "StandardIntegerResponse.minMax_response", "Builtins.ResponseAssumptions",
            "BuiltinArgs", "HasTypeVsQ.toTel_normal", "ModelTargets.store_shape",
            "PrimSig.StoreShape", "ScopeDeclarations.HasHttp"]
previous = json.loads((CHANGE / "l60/e/required-names.json").read_text())
own = []
for module in REQUESTED:
    text = module_path(module).read_text()
    own.extend(re.findall(r"^(?:theorem|structure|def) ([A-Za-z][\w.]*)", text, re.M))
write(HERE / "requested-modules.json", REQUESTED)
write(HERE / "required-names.json", sorted(set(previous + [PREFIX + n for n in added + existing])))
write(HERE / "referenced-names.json", [])
print(json.dumps({"modules": len(REQUESTED), "required": len(set(previous + added + existing)),
                  "own_source_names": len(own)}, ensure_ascii=False))
