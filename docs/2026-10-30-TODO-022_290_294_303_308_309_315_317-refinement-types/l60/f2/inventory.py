# -*- coding: utf-8 -*-
"""公理監査の対象モジュールと必須の入口を再生成する（群F1の同名の台本に倣う）。

新しい12モジュールは全宣言の署名と依存を印字する。既存のモジュールに足した宣言・一般化した宣言と、
接続に使う既存の入口は、必須の名前として署名を印字する。"""
import json
import re
from support import CHANGE, HERE, MODULES, PREFIX, module_path, write

# 既存のモジュールに足した宣言と、一般化して前提を受け取る形にした宣言。
added = ["StandardModel.constructorNames", "StandardModel.Primitive.p377", "StandardModel.byteOrder",
         "StandardAliasBodies.body_typed_of", "StandardOrdinaryListBodies.Inputs",
         "StandardOrdinaryCoreBodies.Records", "StandardOrdinaryCoreBodies.Records.of_table",
         "StandardOrdinaryCoreBodies.getter_typed_of", "StandardOrdinaryCoreBodies.getter_reference_of",
         "StandardOrdinaryCoreBodies.projection_typed_of", "StandardOrdinaryCoreProgram.keyParam",
         "StandardOrdinaryCoreProgram.pair", "StandardOrdinaryCoreProgram.reference_of",
         "StandardOrdinaryCoreProgram.primitive_of", "StandardOrdinaryCoreProgram.Context",
         "StandardOrdinaryCoreProgram.body_typed_of", "StandardOrdinaryCoreProgram.pair_typed_of"]
# 元の署名を保つ適用の形（一般化した宣言の読者）。
kept = ["StandardAliasBodies.body_typed", "StandardOrdinaryCoreBodies.getter_typed",
        "StandardOrdinaryCoreBodies.projection_typed", "StandardOrdinaryCoreProgram.body_typed"]
# 接続に使う既存の入口（実署名を印字する）。
existing = ["StandardModel.Body.definition", "StandardModel.Body.all", "StandardModel.body_lookup",
            "StandardModel.lookup_body", "StandardModel.row_lookup", "StandardModel.PureRow",
            "StandardModel.Primitive.all", "StandardSafe.front_response", "StandardSafe.frontDelta",
            "StandardSafe.frontSig", "ScopeResponse.response", "ScopedIOResponse.response",
            "Builtins.CoreAssumptions", "Builtins.TargetAgreement", "Program.WellTyped", "Program.WellFormed",
            "Program.VarianceValid", "Def.Scoped", "ConDecl.Scoped", "FunctionNames.definition",
            "FunctionNames.rename"]
previous = json.loads((CHANGE / "l60/f1/required-names.json").read_text())
own = []
for module in MODULES:
    text = module_path(module).read_text()
    own.extend(re.findall(r"^(?:theorem|structure|def) ([A-Za-z][\w.]*)", text, re.M))
write(HERE / "requested-modules.json", MODULES)
required = sorted(set(previous + [PREFIX + n for n in added + kept + existing]))
write(HERE / "required-names.json", required)
write(HERE / "referenced-names.json", [])
print(json.dumps({"modules": len(MODULES), "required": len(required), "own_source_names": len(own)},
                 ensure_ascii=False))
