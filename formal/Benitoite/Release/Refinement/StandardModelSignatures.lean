import Benitoite.Release.Refinement.StandardModelDeclarations
import Benitoite.Release.Refinement.StandardScalarResponse
import Benitoite.Release.Refinement.StandardByteStringResponse
import Benitoite.Release.Refinement.StandardCharacterResponse
import Benitoite.Release.Refinement.StandardStringOrdinaryResponse
import Benitoite.Release.Refinement.StandardBytesOrdinaryResponse
import Benitoite.Release.Refinement.StandardBytesResponse
import Benitoite.Release.Refinement.StandardListRemainingResponse
import Benitoite.Release.Refinement.StandardListResponse
import Benitoite.Release.Refinement.StandardNumericRemainingResponse
import Benitoite.Release.Refinement.StandardIntegerAPI
import Benitoite.Release.Refinement.StandardIntegerTextResponse
import Benitoite.Release.Refinement.StandardConversionResponse
import Benitoite.Release.Refinement.StandardArithmeticResponse
import Benitoite.Release.Refinement.StandardDecimalResponse
import Benitoite.Release.Refinement.StandardFloatMathResponse
import Benitoite.Release.Refinement.StandardIntegerResponse
import Benitoite.Release.Refinement.StandardOperatorResponse
import Benitoite.Release.Refinement.StandardOrderResponse
import Benitoite.Release.Refinement.StandardStructuralEqualityResponse
import Benitoite.Release.Refinement.StandardHeadTailBodies
import Benitoite.Release.Refinement.StandardCollectionRefinedBodies
import Benitoite.Release.Refinement.ModelTargets
import Benitoite.Release.Refinement.ModelHttpConditions
import Benitoite.Release.Refinement.Model

/-! # 既存署名と応答の参照から作る標準の組込み表 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

def signatureBase : Builtins := {ModelTargets.builtins with
  sat := ModelConstraints.sat (Benitoite.Release.dataSummaries (declarations.map StandardKeyTyping.DataDecl.summaryInput))}

/-- 鍵の符号化が読む構成子の並びは、合成プログラムの全構成子である。 -/
def constructorNames : List String := constructors.map Prod.fst

/-- 精密なコレクション署名も、同じ制約の表を参照する。δは同じ算法を、合成プログラムの構成子の並びで読む。 -/
def precisionProvider : Builtins := {StandardCollectionRefinedBodies.builtins with
  delta := fun name ts es rs ws =>
    if name = "%Map.replaceValues" then StandardMapReplaceValues.delta constructorNames name ts es rs ws
    else if name = "Map.fromList" ∨ name = "Map.toList" then StandardCollections.mapDelta constructorNames name ts es rs ws
    else StandardCollections.setDelta constructorNames name ts es rs ws
  sig := fun n => if n = "Map.fromList" then some (StandardCollectionPrecision.signature signatureBase.sat true true)
    else if n = "Map.toList" then some (StandardCollectionPrecision.signature signatureBase.sat true false)
    else if n = "Set.fromList" then some (StandardCollectionPrecision.signature signatureBase.sat false true)
    else if n = "Set.toList" then some (StandardCollectionPrecision.signature signatureBase.sat false false)
    else if n = "%Map.replaceValues" then some (StandardMapReplaceValues.signature signatureBase.sat)
    else StandardHeadTail.builtins.sig n}

/-- MapとSetの通常の行。δは同じ算法を、合成プログラムの構成子の並びで読む。 -/
def collectionProvider : Builtins := {StandardCollectionModel.builtins with
  delta := fun name ts es rs ws =>
    if name.startsWith "Map." then StandardCollections.mapDelta constructorNames name ts es rs ws
    else StandardCollections.setDelta constructorNames name ts es rs ws
  sig := fun n =>
    ((StandardCollectionModel.mapAPIs.find? (fun api => api.name == n)).map
      (fun api => api.signature signatureBase.sat)).orElse (fun _ =>
    (StandardCollectionModel.setAPIs.find? (fun api => api.name == n)).map
      (fun api => api.signature signatureBase.sat))}

/-- セルの作成。δ・IO応答を持たず、実行は専用の遷移が受け持つ（`PrimSig.StoreShape` の形）。 -/
def refNewSig : PrimSig :=
  ⟨[TypeCtx.valueParam],0,["value"],[.tvar 0],.reference (.tvar 0),Eff.single stateEff,
    (fun _ ts => ts.length = 1),.refNew,none,[],.untargeted⟩
/-- セルの更新。取得・設定の名前の行へ展開する専用の遷移が受け持つ。 -/
def refUpdateSig : PrimSig :=
  ⟨[TypeCtx.valueParam],0,["reference","f"],
    [.reference (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty],.base .unit,Eff.single stateEff,
    (fun _ ts => ts.length = 1),.refUpdate,none,[],.untargeted⟩
/-- 明示遅延の評価。完了済みと未評価の二つの専用の遷移が受け持つ。 -/
def forceSig : PrimSig :=
  ⟨[TypeCtx.valueParam],0,["value"],[.lazy (.tvar 0)],.tvar 0,Eff.empty,
    (fun _ ts => ts.length = 1),.force,none,[],.untargeted⟩

inductive Primitive where
  | p001
  | p002
  | p003
  | p004
  | p005
  | p006
  | p007
  | p008
  | p009
  | p010
  | p011
  | p012
  | p013
  | p014
  | p015
  | p016
  | p017
  | p018
  | p019
  | p020
  | p021
  | p022
  | p023
  | p024
  | p025
  | p026
  | p027
  | p028
  | p029
  | p030
  | p031
  | p032
  | p033
  | p034
  | p035
  | p036
  | p037
  | p038
  | p039
  | p040
  | p041
  | p042
  | p043
  | p044
  | p045
  | p046
  | p047
  | p048
  | p049
  | p050
  | p051
  | p052
  | p053
  | p054
  | p055
  | p056
  | p057
  | p058
  | p059
  | p060
  | p061
  | p062
  | p063
  | p064
  | p065
  | p066
  | p067
  | p068
  | p069
  | p070
  | p071
  | p072
  | p073
  | p074
  | p075
  | p076
  | p077
  | p078
  | p079
  | p080
  | p081
  | p082
  | p083
  | p084
  | p085
  | p086
  | p087
  | p088
  | p089
  | p090
  | p091
  | p092
  | p093
  | p094
  | p095
  | p096
  | p097
  | p098
  | p099
  | p100
  | p101
  | p102
  | p103
  | p104
  | p105
  | p106
  | p107
  | p108
  | p109
  | p110
  | p111
  | p112
  | p113
  | p114
  | p115
  | p116
  | p117
  | p118
  | p119
  | p120
  | p121
  | p122
  | p123
  | p124
  | p125
  | p126
  | p127
  | p128
  | p129
  | p130
  | p131
  | p132
  | p133
  | p134
  | p135
  | p136
  | p137
  | p138
  | p139
  | p140
  | p141
  | p142
  | p143
  | p144
  | p145
  | p146
  | p147
  | p148
  | p149
  | p150
  | p151
  | p152
  | p153
  | p154
  | p155
  | p156
  | p157
  | p158
  | p159
  | p160
  | p161
  | p162
  | p163
  | p164
  | p165
  | p166
  | p167
  | p168
  | p169
  | p170
  | p171
  | p172
  | p173
  | p174
  | p175
  | p176
  | p177
  | p178
  | p179
  | p180
  | p181
  | p182
  | p183
  | p184
  | p185
  | p186
  | p187
  | p188
  | p189
  | p190
  | p191
  | p192
  | p193
  | p194
  | p195
  | p196
  | p197
  | p198
  | p199
  | p200
  | p201
  | p202
  | p203
  | p204
  | p205
  | p206
  | p207
  | p208
  | p209
  | p210
  | p211
  | p212
  | p213
  | p214
  | p215
  | p216
  | p217
  | p218
  | p219
  | p220
  | p221
  | p222
  | p223
  | p224
  | p225
  | p226
  | p227
  | p228
  | p229
  | p230
  | p231
  | p232
  | p233
  | p234
  | p235
  | p236
  | p237
  | p238
  | p239
  | p240
  | p241
  | p242
  | p243
  | p244
  | p245
  | p246
  | p247
  | p248
  | p249
  | p250
  | p251
  | p252
  | p253
  | p254
  | p255
  | p256
  | p257
  | p258
  | p259
  | p260
  | p261
  | p262
  | p263
  | p264
  | p265
  | p266
  | p267
  | p268
  | p269
  | p270
  | p271
  | p272
  | p273
  | p274
  | p275
  | p276
  | p277
  | p278
  | p279
  | p280
  | p281
  | p282
  | p283
  | p284
  | p285
  | p286
  | p287
  | p288
  | p289
  | p290
  | p291
  | p292
  | p293
  | p294
  | p295
  | p296
  | p297
  | p298
  | p299
  | p300
  | p301
  | p302
  | p303
  | p304
  | p305
  | p306
  | p307
  | p308
  | p309
  | p310
  | p311
  | p312
  | p313
  | p314
  | p315
  | p316
  | p317
  | p318
  | p319
  | p320
  | p321
  | p322
  | p323
  | p324
  | p325
  | p326
  | p327
  | p328
  | p329
  | p330
  | p331
  | p332
  | p333
  | p334
  | p335
  | p336
  | p337
  | p338
  | p339
  | p340
  | p341
  | p342
  | p343
  | p344
  | p345
  | p346
  | p347
  | p348
  | p349
  | p350
  | p351
  | p352
  | p353
  | p354
  | p355
  | p356
  | p357
  | p358
  | p359
  | p360
  | p361
  | p362
  | p363
  | p364
  | p365
  | p366
  | p367
  | p368
  | p369
  | p370
  | p371
  | p372
  | p373
  | p374
  | p375
  | p376
  | p377

def Primitive.name : Primitive → String
  | .p001 => "%Byte.greater"
  | .p002 => "%Byte.greaterOrEqual"
  | .p003 => "%Byte.less"
  | .p004 => "%Byte.lessOrEqual"
  | .p005 => "%Character.greater"
  | .p006 => "%Character.greaterOrEqual"
  | .p007 => "%Character.less"
  | .p008 => "%Character.lessOrEqual"
  | .p009 => "%Decimal.add"
  | .p010 => "%Decimal.divide"
  | .p011 => "%Decimal.greater"
  | .p012 => "%Decimal.greaterOrEqual"
  | .p013 => "%Decimal.less"
  | .p014 => "%Decimal.lessOrEqual"
  | .p015 => "%Decimal.multiply"
  | .p016 => "%Decimal.negate"
  | .p017 => "%Decimal.subtract"
  | .p018 => "%Float.add"
  | .p019 => "%Float.divide"
  | .p020 => "%Float.greater"
  | .p021 => "%Float.greaterOrEqual"
  | .p022 => "%Float.less"
  | .p023 => "%Float.lessOrEqual"
  | .p024 => "%Float.multiply"
  | .p025 => "%Float.negate"
  | .p026 => "%Float.subtract"
  | .p027 => "%Float32.add"
  | .p028 => "%Float32.divide"
  | .p029 => "%Float32.greater"
  | .p030 => "%Float32.greaterOrEqual"
  | .p031 => "%Float32.less"
  | .p032 => "%Float32.lessOrEqual"
  | .p033 => "%Float32.multiply"
  | .p034 => "%Float32.negate"
  | .p035 => "%Float32.subtract"
  | .p036 => "%Integer.add"
  | .p037 => "%Integer.div"
  | .p038 => "%Integer.greater"
  | .p039 => "%Integer.greaterOrEqual"
  | .p040 => "%Integer.less"
  | .p041 => "%Integer.lessOrEqual"
  | .p042 => "%Integer.mod"
  | .p043 => "%Integer.multiply"
  | .p044 => "%Integer.negate"
  | .p045 => "%Integer.subtract"
  | .p046 => "%Integer16.add"
  | .p047 => "%Integer16.div"
  | .p048 => "%Integer16.greater"
  | .p049 => "%Integer16.greaterOrEqual"
  | .p050 => "%Integer16.less"
  | .p051 => "%Integer16.lessOrEqual"
  | .p052 => "%Integer16.mod"
  | .p053 => "%Integer16.multiply"
  | .p054 => "%Integer16.negate"
  | .p055 => "%Integer16.subtract"
  | .p056 => "%Integer32.add"
  | .p057 => "%Integer32.div"
  | .p058 => "%Integer32.greater"
  | .p059 => "%Integer32.greaterOrEqual"
  | .p060 => "%Integer32.less"
  | .p061 => "%Integer32.lessOrEqual"
  | .p062 => "%Integer32.mod"
  | .p063 => "%Integer32.multiply"
  | .p064 => "%Integer32.negate"
  | .p065 => "%Integer32.subtract"
  | .p066 => "%Integer8.add"
  | .p067 => "%Integer8.div"
  | .p068 => "%Integer8.greater"
  | .p069 => "%Integer8.greaterOrEqual"
  | .p070 => "%Integer8.less"
  | .p071 => "%Integer8.lessOrEqual"
  | .p072 => "%Integer8.mod"
  | .p073 => "%Integer8.multiply"
  | .p074 => "%Integer8.negate"
  | .p075 => "%Integer8.subtract"
  | .p076 => "%Map.replaceValues"
  | .p077 => "%String.add"
  | .p078 => "%String.greater"
  | .p079 => "%String.greaterOrEqual"
  | .p080 => "%String.less"
  | .p081 => "%String.lessOrEqual"
  | .p082 => "%UnsignedInteger16.add"
  | .p083 => "%UnsignedInteger16.div"
  | .p084 => "%UnsignedInteger16.greater"
  | .p085 => "%UnsignedInteger16.greaterOrEqual"
  | .p086 => "%UnsignedInteger16.less"
  | .p087 => "%UnsignedInteger16.lessOrEqual"
  | .p088 => "%UnsignedInteger16.mod"
  | .p089 => "%UnsignedInteger16.multiply"
  | .p090 => "%UnsignedInteger16.subtract"
  | .p091 => "%UnsignedInteger32.add"
  | .p092 => "%UnsignedInteger32.div"
  | .p093 => "%UnsignedInteger32.greater"
  | .p094 => "%UnsignedInteger32.greaterOrEqual"
  | .p095 => "%UnsignedInteger32.less"
  | .p096 => "%UnsignedInteger32.lessOrEqual"
  | .p097 => "%UnsignedInteger32.mod"
  | .p098 => "%UnsignedInteger32.multiply"
  | .p099 => "%UnsignedInteger32.subtract"
  | .p100 => "%UnsignedInteger64.add"
  | .p101 => "%UnsignedInteger64.div"
  | .p102 => "%UnsignedInteger64.greater"
  | .p103 => "%UnsignedInteger64.greaterOrEqual"
  | .p104 => "%UnsignedInteger64.less"
  | .p105 => "%UnsignedInteger64.lessOrEqual"
  | .p106 => "%UnsignedInteger64.mod"
  | .p107 => "%UnsignedInteger64.multiply"
  | .p108 => "%UnsignedInteger64.subtract"
  | .p109 => "%eq"
  | .p110 => "%ne"
  | .p111 => "Byte.bitwiseAnd"
  | .p112 => "Byte.bitwiseExclusiveOr"
  | .p113 => "Byte.bitwiseNot"
  | .p114 => "Byte.bitwiseOr"
  | .p115 => "Byte.fromInteger"
  | .p116 => "Byte.shiftLeft"
  | .p117 => "Byte.shiftRight"
  | .p118 => "Byte.toInteger"
  | .p119 => "Byte.toString"
  | .p120 => "Bytes.concatenate"
  | .p121 => "Bytes.empty"
  | .p122 => "Bytes.fromBinary"
  | .p123 => "Bytes.fromHex"
  | .p124 => "Bytes.fromIntegers"
  | .p125 => "Bytes.fromList"
  | .p126 => "Bytes.fromSigned"
  | .p127 => "Bytes.fromUnsigned"
  | .p128 => "Bytes.get"
  | .p129 => "Bytes.length"
  | .p130 => "Bytes.readSigned"
  | .p131 => "Bytes.readUnsigned"
  | .p132 => "Bytes.slice"
  | .p133 => "Bytes.toBinary"
  | .p134 => "Bytes.toHex"
  | .p135 => "Bytes.toList"
  | .p136 => "Character.fromInteger"
  | .p137 => "Character.isASCIIDigit"
  | .p138 => "Character.isASCIIWhitespace"
  | .p139 => "Character.isAlphabetic"
  | .p140 => "Character.isLowercase"
  | .p141 => "Character.isNumeric"
  | .p142 => "Character.isUppercase"
  | .p143 => "Character.isWhitespace"
  | .p144 => "Character.toInteger"
  | .p145 => "Character.toLowercase"
  | .p146 => "Character.toString"
  | .p147 => "Character.toUppercase"
  | .p148 => "Decimal.absolute"
  | .p149 => "Decimal.fromFloat"
  | .p150 => "Decimal.fromInteger"
  | .p151 => "Decimal.parse"
  | .p152 => "Decimal.round"
  | .p153 => "Decimal.toFloat"
  | .p154 => "Decimal.toString"
  | .p155 => "Decimal.truncate"
  | .p156 => "Example.pathBases"
  | .p157 => "File.appendBytesIn"
  | .p158 => "File.appendTextIn"
  | .p159 => "File.readBytesIn"
  | .p160 => "File.readText"
  | .p161 => "File.readTextIn"
  | .p162 => "File.writeBytesIn"
  | .p163 => "File.writeTextIn"
  | .p164 => "Float.absolute"
  | .p165 => "Float.ceiling"
  | .p166 => "Float.floor"
  | .p167 => "Float.isNaN"
  | .p168 => "Float.parse"
  | .p169 => "Float.round"
  | .p170 => "Float.squareRoot"
  | .p171 => "Float.toString"
  | .p172 => "Float.truncate"
  | .p173 => "Float32.absolute"
  | .p174 => "Float32.ceiling"
  | .p175 => "Float32.floor"
  | .p176 => "Float32.fromFloat"
  | .p177 => "Float32.isInfinite"
  | .p178 => "Float32.isNaN"
  | .p179 => "Float32.parse"
  | .p180 => "Float32.round"
  | .p181 => "Float32.squareRoot"
  | .p182 => "Float32.toFloat"
  | .p183 => "Float32.toString"
  | .p184 => "Float32.truncate"
  | .p185 => "Http.checkRequestIn"
  | .p186 => "Http.requestInValue"
  | .p187 => "Http.sendIn"
  | .p188 => "Http.widenRequestIn"
  | .p189 => "Integer.absolute"
  | .p190 => "Integer.bitwiseAnd"
  | .p191 => "Integer.bitwiseExclusiveOr"
  | .p192 => "Integer.bitwiseNot"
  | .p193 => "Integer.bitwiseOr"
  | .p194 => "Integer.floorDivide"
  | .p195 => "Integer.floorModulo"
  | .p196 => "Integer.maximum"
  | .p197 => "Integer.minimum"
  | .p198 => "Integer.parse"
  | .p199 => "Integer.shiftLeft"
  | .p200 => "Integer.shiftRight"
  | .p201 => "Integer.shiftRightUnsigned"
  | .p202 => "Integer.toFloat"
  | .p203 => "Integer.toString"
  | .p204 => "Integer16.absolute"
  | .p205 => "Integer16.bitwiseAnd"
  | .p206 => "Integer16.bitwiseExclusiveOr"
  | .p207 => "Integer16.bitwiseNot"
  | .p208 => "Integer16.bitwiseOr"
  | .p209 => "Integer16.floorDivide"
  | .p210 => "Integer16.floorModulo"
  | .p211 => "Integer16.fromInteger"
  | .p212 => "Integer16.maximum"
  | .p213 => "Integer16.minimum"
  | .p214 => "Integer16.parse"
  | .p215 => "Integer16.shiftLeft"
  | .p216 => "Integer16.shiftRight"
  | .p217 => "Integer16.shiftRightUnsigned"
  | .p218 => "Integer16.toFloat"
  | .p219 => "Integer16.toInteger"
  | .p220 => "Integer16.toString"
  | .p221 => "Integer32.absolute"
  | .p222 => "Integer32.bitwiseAnd"
  | .p223 => "Integer32.bitwiseExclusiveOr"
  | .p224 => "Integer32.bitwiseNot"
  | .p225 => "Integer32.bitwiseOr"
  | .p226 => "Integer32.floorDivide"
  | .p227 => "Integer32.floorModulo"
  | .p228 => "Integer32.fromInteger"
  | .p229 => "Integer32.maximum"
  | .p230 => "Integer32.minimum"
  | .p231 => "Integer32.parse"
  | .p232 => "Integer32.shiftLeft"
  | .p233 => "Integer32.shiftRight"
  | .p234 => "Integer32.shiftRightUnsigned"
  | .p235 => "Integer32.toFloat"
  | .p236 => "Integer32.toInteger"
  | .p237 => "Integer32.toString"
  | .p238 => "Integer8.absolute"
  | .p239 => "Integer8.bitwiseAnd"
  | .p240 => "Integer8.bitwiseExclusiveOr"
  | .p241 => "Integer8.bitwiseNot"
  | .p242 => "Integer8.bitwiseOr"
  | .p243 => "Integer8.floorDivide"
  | .p244 => "Integer8.floorModulo"
  | .p245 => "Integer8.fromInteger"
  | .p246 => "Integer8.maximum"
  | .p247 => "Integer8.minimum"
  | .p248 => "Integer8.parse"
  | .p249 => "Integer8.shiftLeft"
  | .p250 => "Integer8.shiftRight"
  | .p251 => "Integer8.shiftRightUnsigned"
  | .p252 => "Integer8.toFloat"
  | .p253 => "Integer8.toInteger"
  | .p254 => "Integer8.toString"
  | .p255 => "List.append"
  | .p256 => "List.concatenate"
  | .p257 => "List.contains"
  | .p258 => "List.drop"
  | .p259 => "List.get"
  | .p260 => "List.head"
  | .p261 => "List.isEmpty"
  | .p262 => "List.length"
  | .p263 => "List.prepend"
  | .p264 => "List.range"
  | .p265 => "List.reverse"
  | .p266 => "List.sort"
  | .p267 => "List.tail"
  | .p268 => "List.take"
  | .p269 => "Map.contains"
  | .p270 => "Map.empty"
  | .p271 => "Map.fromList"
  | .p272 => "Map.get"
  | .p273 => "Map.keys"
  | .p274 => "Map.remove"
  | .p275 => "Map.set"
  | .p276 => "Map.size"
  | .p277 => "Map.toList"
  | .p278 => "Map.values"
  | .p279 => "Reference.get"
  | .p280 => "Reference.set"
  | .p281 => "Scope.checkPathIn"
  | .p282 => "Scope.pathInValue"
  | .p283 => "Scope.widenPathIn"
  | .p284 => "Set.add"
  | .p285 => "Set.contains"
  | .p286 => "Set.difference"
  | .p287 => "Set.empty"
  | .p288 => "Set.fromList"
  | .p289 => "Set.intersection"
  | .p290 => "Set.remove"
  | .p291 => "Set.size"
  | .p292 => "Set.toList"
  | .p293 => "Set.union"
  | .p294 => "String.byteIndexOf"
  | .p295 => "String.byteLength"
  | .p296 => "String.byteSlice"
  | .p297 => "String.characterAt"
  | .p298 => "String.characterCount"
  | .p299 => "String.characterSlice"
  | .p300 => "String.characters"
  | .p301 => "String.contains"
  | .p302 => "String.displayWidth"
  | .p303 => "String.displayWidthCJK"
  | .p304 => "String.displayWidthPadEnd"
  | .p305 => "String.displayWidthPadEndCJK"
  | .p306 => "String.displayWidthPadStart"
  | .p307 => "String.displayWidthPadStartCJK"
  | .p308 => "String.endsWith"
  | .p309 => "String.fromCharacters"
  | .p310 => "String.fromUTF8"
  | .p311 => "String.isEmpty"
  | .p312 => "String.join"
  | .p313 => "String.lines"
  | .p314 => "String.repeat"
  | .p315 => "String.replace"
  | .p316 => "String.split"
  | .p317 => "String.startsWith"
  | .p318 => "String.toLowercase"
  | .p319 => "String.toUTF8"
  | .p320 => "String.toUppercase"
  | .p321 => "String.trim"
  | .p322 => "UnsignedInteger16.absolute"
  | .p323 => "UnsignedInteger16.bitwiseAnd"
  | .p324 => "UnsignedInteger16.bitwiseExclusiveOr"
  | .p325 => "UnsignedInteger16.bitwiseNot"
  | .p326 => "UnsignedInteger16.bitwiseOr"
  | .p327 => "UnsignedInteger16.floorDivide"
  | .p328 => "UnsignedInteger16.floorModulo"
  | .p329 => "UnsignedInteger16.fromInteger"
  | .p330 => "UnsignedInteger16.maximum"
  | .p331 => "UnsignedInteger16.minimum"
  | .p332 => "UnsignedInteger16.parse"
  | .p333 => "UnsignedInteger16.shiftLeft"
  | .p334 => "UnsignedInteger16.shiftRight"
  | .p335 => "UnsignedInteger16.toFloat"
  | .p336 => "UnsignedInteger16.toInteger"
  | .p337 => "UnsignedInteger16.toString"
  | .p338 => "UnsignedInteger32.absolute"
  | .p339 => "UnsignedInteger32.bitwiseAnd"
  | .p340 => "UnsignedInteger32.bitwiseExclusiveOr"
  | .p341 => "UnsignedInteger32.bitwiseNot"
  | .p342 => "UnsignedInteger32.bitwiseOr"
  | .p343 => "UnsignedInteger32.floorDivide"
  | .p344 => "UnsignedInteger32.floorModulo"
  | .p345 => "UnsignedInteger32.fromInteger"
  | .p346 => "UnsignedInteger32.maximum"
  | .p347 => "UnsignedInteger32.minimum"
  | .p348 => "UnsignedInteger32.parse"
  | .p349 => "UnsignedInteger32.shiftLeft"
  | .p350 => "UnsignedInteger32.shiftRight"
  | .p351 => "UnsignedInteger32.toFloat"
  | .p352 => "UnsignedInteger32.toInteger"
  | .p353 => "UnsignedInteger32.toString"
  | .p354 => "UnsignedInteger64.absolute"
  | .p355 => "UnsignedInteger64.bitwiseAnd"
  | .p356 => "UnsignedInteger64.bitwiseExclusiveOr"
  | .p357 => "UnsignedInteger64.bitwiseNot"
  | .p358 => "UnsignedInteger64.bitwiseOr"
  | .p359 => "UnsignedInteger64.floorDivide"
  | .p360 => "UnsignedInteger64.floorModulo"
  | .p361 => "UnsignedInteger64.fromDecimal"
  | .p362 => "UnsignedInteger64.fromInteger"
  | .p363 => "UnsignedInteger64.maximum"
  | .p364 => "UnsignedInteger64.minimum"
  | .p365 => "UnsignedInteger64.parse"
  | .p366 => "UnsignedInteger64.shiftLeft"
  | .p367 => "UnsignedInteger64.shiftRight"
  | .p368 => "UnsignedInteger64.toDecimal"
  | .p369 => "UnsignedInteger64.toFloat"
  | .p370 => "UnsignedInteger64.toInteger"
  | .p371 => "UnsignedInteger64.toString"
  | .p372 => "exit"
  | .p373 => "print"
  | .p374 => "Lazy.force"
  | .p375 => "Reference.new"
  | .p376 => "Reference.update"
  | .p377 => "%List.getFront"

private def source0 : Builtins := StandardHeadTail.builtins

private def source1 : Builtins := precisionProvider

private def source2 : Builtins := StandardScalarResponse.table signatureBase

private def source3 : Builtins := StandardByteStringResponse.table signatureBase

private def source4 : Builtins := StandardCharacterResponse.table signatureBase

private def source5 : Builtins := StandardStringOrdinaryResponse.table signatureBase

private def source6 : Builtins := StandardBytesOrdinaryResponse.table signatureBase

private def source7 : Builtins := StandardBytesResponse.table signatureBase

private def source8 : Builtins := StandardListRemainingResponse.table signatureBase

private def source9 : Builtins := StandardListResponse.table signatureBase

private def source10 : Builtins := StandardNumericRemainingResponse.table signatureBase

private def source11 : Builtins := StandardIntegerAPI.table signatureBase

private def source12 : Builtins := StandardIntegerTextResponse.table signatureBase

private def source13 : Builtins := StandardConversionResponse.table signatureBase

private def source14 : Builtins := StandardArithmeticResponse.table signatureBase

private def source15 : Builtins := StandardDecimalResponse.table signatureBase

private def source16 : Builtins := StandardFloatMathResponse.table signatureBase

private def source17 : Builtins := StandardIntegerResponse.minMaxTable signatureBase

private def source18 : Builtins := StandardOperatorResponse.table signatureBase

private def source19 : Builtins := StandardOrderResponse.table signatureBase

private def source20 : Builtins := StandardStructuralEqualityResponse.table signatureBase

private def source22 : Builtins := collectionProvider

private def source23 : Builtins := signatureBase

private def source24 : Builtins := ModelHttp.builtins

private def source25 : Builtins := StandardSafe.builtins

def Primitive.provider : Primitive → Builtins
  | .p001 => source19
  | .p002 => source19
  | .p003 => source19
  | .p004 => source19
  | .p005 => source19
  | .p006 => source19
  | .p007 => source19
  | .p008 => source19
  | .p009 => source18
  | .p010 => source18
  | .p011 => source19
  | .p012 => source19
  | .p013 => source19
  | .p014 => source19
  | .p015 => source18
  | .p016 => source18
  | .p017 => source18
  | .p018 => source18
  | .p019 => source18
  | .p020 => source19
  | .p021 => source19
  | .p022 => source19
  | .p023 => source19
  | .p024 => source18
  | .p025 => source18
  | .p026 => source18
  | .p027 => source18
  | .p028 => source18
  | .p029 => source19
  | .p030 => source19
  | .p031 => source19
  | .p032 => source19
  | .p033 => source18
  | .p034 => source18
  | .p035 => source18
  | .p036 => source14
  | .p037 => source18
  | .p038 => source19
  | .p039 => source19
  | .p040 => source19
  | .p041 => source19
  | .p042 => source18
  | .p043 => source14
  | .p044 => source14
  | .p045 => source14
  | .p046 => source14
  | .p047 => source18
  | .p048 => source19
  | .p049 => source19
  | .p050 => source19
  | .p051 => source19
  | .p052 => source18
  | .p053 => source14
  | .p054 => source14
  | .p055 => source14
  | .p056 => source14
  | .p057 => source18
  | .p058 => source19
  | .p059 => source19
  | .p060 => source19
  | .p061 => source19
  | .p062 => source18
  | .p063 => source14
  | .p064 => source14
  | .p065 => source14
  | .p066 => source14
  | .p067 => source18
  | .p068 => source19
  | .p069 => source19
  | .p070 => source19
  | .p071 => source19
  | .p072 => source18
  | .p073 => source14
  | .p074 => source14
  | .p075 => source14
  | .p076 => source1
  | .p077 => source18
  | .p078 => source18
  | .p079 => source18
  | .p080 => source18
  | .p081 => source18
  | .p082 => source14
  | .p083 => source18
  | .p084 => source19
  | .p085 => source19
  | .p086 => source19
  | .p087 => source19
  | .p088 => source18
  | .p089 => source14
  | .p090 => source14
  | .p091 => source14
  | .p092 => source18
  | .p093 => source19
  | .p094 => source19
  | .p095 => source19
  | .p096 => source19
  | .p097 => source18
  | .p098 => source14
  | .p099 => source14
  | .p100 => source14
  | .p101 => source18
  | .p102 => source19
  | .p103 => source19
  | .p104 => source19
  | .p105 => source19
  | .p106 => source18
  | .p107 => source14
  | .p108 => source14
  | .p109 => source20
  | .p110 => source20
  | .p111 => source2
  | .p112 => source2
  | .p113 => source2
  | .p114 => source2
  | .p115 => source2
  | .p116 => source2
  | .p117 => source2
  | .p118 => source2
  | .p119 => source3
  | .p120 => source6
  | .p121 => source6
  | .p122 => source6
  | .p123 => source6
  | .p124 => source6
  | .p125 => source7
  | .p126 => source6
  | .p127 => source6
  | .p128 => source6
  | .p129 => source7
  | .p130 => source6
  | .p131 => source6
  | .p132 => source6
  | .p133 => source6
  | .p134 => source6
  | .p135 => source7
  | .p136 => source2
  | .p137 => source4
  | .p138 => source4
  | .p139 => source4
  | .p140 => source4
  | .p141 => source4
  | .p142 => source4
  | .p143 => source4
  | .p144 => source2
  | .p145 => source4
  | .p146 => source4
  | .p147 => source4
  | .p148 => source15
  | .p149 => source10
  | .p150 => source15
  | .p151 => source10
  | .p152 => source15
  | .p153 => source10
  | .p154 => source10
  | .p155 => source15
  | .p156 => source23
  | .p157 => source23
  | .p158 => source23
  | .p159 => source23
  | .p160 => source23
  | .p161 => source23
  | .p162 => source23
  | .p163 => source23
  | .p164 => source16
  | .p165 => source16
  | .p166 => source16
  | .p167 => source2
  | .p168 => source10
  | .p169 => source16
  | .p170 => source16
  | .p171 => source10
  | .p172 => source16
  | .p173 => source16
  | .p174 => source16
  | .p175 => source16
  | .p176 => source10
  | .p177 => source2
  | .p178 => source2
  | .p179 => source10
  | .p180 => source16
  | .p181 => source16
  | .p182 => source10
  | .p183 => source10
  | .p184 => source16
  | .p185 => source24
  | .p186 => source24
  | .p187 => source24
  | .p188 => source24
  | .p189 => source11
  | .p190 => source11
  | .p191 => source11
  | .p192 => source11
  | .p193 => source11
  | .p194 => source11
  | .p195 => source11
  | .p196 => source17
  | .p197 => source17
  | .p198 => source12
  | .p199 => source11
  | .p200 => source11
  | .p201 => source11
  | .p202 => source12
  | .p203 => source12
  | .p204 => source11
  | .p205 => source11
  | .p206 => source11
  | .p207 => source11
  | .p208 => source11
  | .p209 => source11
  | .p210 => source11
  | .p211 => source13
  | .p212 => source17
  | .p213 => source17
  | .p214 => source12
  | .p215 => source11
  | .p216 => source11
  | .p217 => source11
  | .p218 => source12
  | .p219 => source13
  | .p220 => source12
  | .p221 => source11
  | .p222 => source11
  | .p223 => source11
  | .p224 => source11
  | .p225 => source11
  | .p226 => source11
  | .p227 => source11
  | .p228 => source13
  | .p229 => source17
  | .p230 => source17
  | .p231 => source12
  | .p232 => source11
  | .p233 => source11
  | .p234 => source11
  | .p235 => source12
  | .p236 => source13
  | .p237 => source12
  | .p238 => source11
  | .p239 => source11
  | .p240 => source11
  | .p241 => source11
  | .p242 => source11
  | .p243 => source11
  | .p244 => source11
  | .p245 => source13
  | .p246 => source17
  | .p247 => source17
  | .p248 => source12
  | .p249 => source11
  | .p250 => source11
  | .p251 => source11
  | .p252 => source12
  | .p253 => source13
  | .p254 => source12
  | .p255 => source0
  | .p256 => source9
  | .p257 => source8
  | .p258 => source8
  | .p259 => source8
  | .p260 => source0
  | .p261 => source9
  | .p262 => source9
  | .p263 => source9
  | .p264 => source8
  | .p265 => source9
  | .p266 => source8
  | .p267 => source0
  | .p268 => source8
  | .p269 => source22
  | .p270 => source22
  | .p271 => source1
  | .p272 => source22
  | .p273 => source22
  | .p274 => source22
  | .p275 => source22
  | .p276 => source22
  | .p277 => source1
  | .p278 => source22
  | .p279 => source23
  | .p280 => source23
  | .p281 => source23
  | .p282 => source23
  | .p283 => source23
  | .p284 => source22
  | .p285 => source22
  | .p286 => source22
  | .p287 => source22
  | .p288 => source1
  | .p289 => source22
  | .p290 => source22
  | .p291 => source22
  | .p292 => source1
  | .p293 => source22
  | .p294 => source5
  | .p295 => source7
  | .p296 => source5
  | .p297 => source5
  | .p298 => source7
  | .p299 => source5
  | .p300 => source5
  | .p301 => source5
  | .p302 => source5
  | .p303 => source5
  | .p304 => source5
  | .p305 => source5
  | .p306 => source5
  | .p307 => source5
  | .p308 => source5
  | .p309 => source5
  | .p310 => source5
  | .p311 => source5
  | .p312 => source5
  | .p313 => source5
  | .p314 => source5
  | .p315 => source5
  | .p316 => source5
  | .p317 => source5
  | .p318 => source5
  | .p319 => source5
  | .p320 => source5
  | .p321 => source5
  | .p322 => source11
  | .p323 => source11
  | .p324 => source11
  | .p325 => source11
  | .p326 => source11
  | .p327 => source11
  | .p328 => source11
  | .p329 => source13
  | .p330 => source17
  | .p331 => source17
  | .p332 => source12
  | .p333 => source11
  | .p334 => source11
  | .p335 => source12
  | .p336 => source13
  | .p337 => source12
  | .p338 => source11
  | .p339 => source11
  | .p340 => source11
  | .p341 => source11
  | .p342 => source11
  | .p343 => source11
  | .p344 => source11
  | .p345 => source13
  | .p346 => source17
  | .p347 => source17
  | .p348 => source12
  | .p349 => source11
  | .p350 => source11
  | .p351 => source12
  | .p352 => source13
  | .p353 => source12
  | .p354 => source11
  | .p355 => source11
  | .p356 => source11
  | .p357 => source11
  | .p358 => source11
  | .p359 => source11
  | .p360 => source11
  | .p361 => source15
  | .p362 => source13
  | .p363 => source17
  | .p364 => source17
  | .p365 => source12
  | .p366 => source11
  | .p367 => source11
  | .p368 => source15
  | .p369 => source12
  | .p370 => source13
  | .p371 => source12
  | .p372 => source23
  | .p373 => source23
  | .p374 => source23
  | .p375 => source23
  | .p376 => source23
  | .p377 => source25

set_option maxHeartbeats 1600000 in
def Primitive.signature : Primitive → PrimSig
  | .p001 => (source19.sig "%Byte.greater").get (by rfl)
  | .p002 => (source19.sig "%Byte.greaterOrEqual").get (by rfl)
  | .p003 => (source19.sig "%Byte.less").get (by rfl)
  | .p004 => (source19.sig "%Byte.lessOrEqual").get (by rfl)
  | .p005 => (source19.sig "%Character.greater").get (by rfl)
  | .p006 => (source19.sig "%Character.greaterOrEqual").get (by rfl)
  | .p007 => (source19.sig "%Character.less").get (by rfl)
  | .p008 => (source19.sig "%Character.lessOrEqual").get (by rfl)
  | .p009 => (source18.sig "%Decimal.add").get (by rfl)
  | .p010 => (source18.sig "%Decimal.divide").get (by rfl)
  | .p011 => (source19.sig "%Decimal.greater").get (by rfl)
  | .p012 => (source19.sig "%Decimal.greaterOrEqual").get (by rfl)
  | .p013 => (source19.sig "%Decimal.less").get (by rfl)
  | .p014 => (source19.sig "%Decimal.lessOrEqual").get (by rfl)
  | .p015 => (source18.sig "%Decimal.multiply").get (by rfl)
  | .p016 => (source18.sig "%Decimal.negate").get (by rfl)
  | .p017 => (source18.sig "%Decimal.subtract").get (by rfl)
  | .p018 => (source18.sig "%Float.add").get (by rfl)
  | .p019 => (source18.sig "%Float.divide").get (by rfl)
  | .p020 => (source19.sig "%Float.greater").get (by rfl)
  | .p021 => (source19.sig "%Float.greaterOrEqual").get (by rfl)
  | .p022 => (source19.sig "%Float.less").get (by rfl)
  | .p023 => (source19.sig "%Float.lessOrEqual").get (by rfl)
  | .p024 => (source18.sig "%Float.multiply").get (by rfl)
  | .p025 => (source18.sig "%Float.negate").get (by rfl)
  | .p026 => (source18.sig "%Float.subtract").get (by rfl)
  | .p027 => (source18.sig "%Float32.add").get (by rfl)
  | .p028 => (source18.sig "%Float32.divide").get (by rfl)
  | .p029 => (source19.sig "%Float32.greater").get (by rfl)
  | .p030 => (source19.sig "%Float32.greaterOrEqual").get (by rfl)
  | .p031 => (source19.sig "%Float32.less").get (by rfl)
  | .p032 => (source19.sig "%Float32.lessOrEqual").get (by rfl)
  | .p033 => (source18.sig "%Float32.multiply").get (by rfl)
  | .p034 => (source18.sig "%Float32.negate").get (by rfl)
  | .p035 => (source18.sig "%Float32.subtract").get (by rfl)
  | .p036 => (source14.sig "%Integer.add").get (by rfl)
  | .p037 => (source18.sig "%Integer.div").get (by rfl)
  | .p038 => (source19.sig "%Integer.greater").get (by rfl)
  | .p039 => (source19.sig "%Integer.greaterOrEqual").get (by rfl)
  | .p040 => (source19.sig "%Integer.less").get (by rfl)
  | .p041 => (source19.sig "%Integer.lessOrEqual").get (by rfl)
  | .p042 => (source18.sig "%Integer.mod").get (by rfl)
  | .p043 => (source14.sig "%Integer.multiply").get (by rfl)
  | .p044 => (source14.sig "%Integer.negate").get (by rfl)
  | .p045 => (source14.sig "%Integer.subtract").get (by rfl)
  | .p046 => (source14.sig "%Integer16.add").get (by rfl)
  | .p047 => (source18.sig "%Integer16.div").get (by rfl)
  | .p048 => (source19.sig "%Integer16.greater").get (by rfl)
  | .p049 => (source19.sig "%Integer16.greaterOrEqual").get (by rfl)
  | .p050 => (source19.sig "%Integer16.less").get (by rfl)
  | .p051 => (source19.sig "%Integer16.lessOrEqual").get (by rfl)
  | .p052 => (source18.sig "%Integer16.mod").get (by rfl)
  | .p053 => (source14.sig "%Integer16.multiply").get (by rfl)
  | .p054 => (source14.sig "%Integer16.negate").get (by rfl)
  | .p055 => (source14.sig "%Integer16.subtract").get (by rfl)
  | .p056 => (source14.sig "%Integer32.add").get (by rfl)
  | .p057 => (source18.sig "%Integer32.div").get (by rfl)
  | .p058 => (source19.sig "%Integer32.greater").get (by rfl)
  | .p059 => (source19.sig "%Integer32.greaterOrEqual").get (by rfl)
  | .p060 => (source19.sig "%Integer32.less").get (by rfl)
  | .p061 => (source19.sig "%Integer32.lessOrEqual").get (by rfl)
  | .p062 => (source18.sig "%Integer32.mod").get (by rfl)
  | .p063 => (source14.sig "%Integer32.multiply").get (by rfl)
  | .p064 => (source14.sig "%Integer32.negate").get (by rfl)
  | .p065 => (source14.sig "%Integer32.subtract").get (by rfl)
  | .p066 => (source14.sig "%Integer8.add").get (by rfl)
  | .p067 => (source18.sig "%Integer8.div").get (by rfl)
  | .p068 => (source19.sig "%Integer8.greater").get (by rfl)
  | .p069 => (source19.sig "%Integer8.greaterOrEqual").get (by rfl)
  | .p070 => (source19.sig "%Integer8.less").get (by rfl)
  | .p071 => (source19.sig "%Integer8.lessOrEqual").get (by rfl)
  | .p072 => (source18.sig "%Integer8.mod").get (by rfl)
  | .p073 => (source14.sig "%Integer8.multiply").get (by rfl)
  | .p074 => (source14.sig "%Integer8.negate").get (by rfl)
  | .p075 => (source14.sig "%Integer8.subtract").get (by rfl)
  | .p076 => (source1.sig "%Map.replaceValues").get (by rfl)
  | .p077 => (source18.sig "%String.add").get (by rfl)
  | .p078 => (source18.sig "%String.greater").get (by rfl)
  | .p079 => (source18.sig "%String.greaterOrEqual").get (by rfl)
  | .p080 => (source18.sig "%String.less").get (by rfl)
  | .p081 => (source18.sig "%String.lessOrEqual").get (by rfl)
  | .p082 => (source14.sig "%UnsignedInteger16.add").get (by rfl)
  | .p083 => (source18.sig "%UnsignedInteger16.div").get (by rfl)
  | .p084 => (source19.sig "%UnsignedInteger16.greater").get (by rfl)
  | .p085 => (source19.sig "%UnsignedInteger16.greaterOrEqual").get (by rfl)
  | .p086 => (source19.sig "%UnsignedInteger16.less").get (by rfl)
  | .p087 => (source19.sig "%UnsignedInteger16.lessOrEqual").get (by rfl)
  | .p088 => (source18.sig "%UnsignedInteger16.mod").get (by rfl)
  | .p089 => (source14.sig "%UnsignedInteger16.multiply").get (by rfl)
  | .p090 => (source14.sig "%UnsignedInteger16.subtract").get (by rfl)
  | .p091 => (source14.sig "%UnsignedInteger32.add").get (by rfl)
  | .p092 => (source18.sig "%UnsignedInteger32.div").get (by rfl)
  | .p093 => (source19.sig "%UnsignedInteger32.greater").get (by rfl)
  | .p094 => (source19.sig "%UnsignedInteger32.greaterOrEqual").get (by rfl)
  | .p095 => (source19.sig "%UnsignedInteger32.less").get (by rfl)
  | .p096 => (source19.sig "%UnsignedInteger32.lessOrEqual").get (by rfl)
  | .p097 => (source18.sig "%UnsignedInteger32.mod").get (by rfl)
  | .p098 => (source14.sig "%UnsignedInteger32.multiply").get (by rfl)
  | .p099 => (source14.sig "%UnsignedInteger32.subtract").get (by rfl)
  | .p100 => (source14.sig "%UnsignedInteger64.add").get (by rfl)
  | .p101 => (source18.sig "%UnsignedInteger64.div").get (by rfl)
  | .p102 => (source19.sig "%UnsignedInteger64.greater").get (by rfl)
  | .p103 => (source19.sig "%UnsignedInteger64.greaterOrEqual").get (by rfl)
  | .p104 => (source19.sig "%UnsignedInteger64.less").get (by rfl)
  | .p105 => (source19.sig "%UnsignedInteger64.lessOrEqual").get (by rfl)
  | .p106 => (source18.sig "%UnsignedInteger64.mod").get (by rfl)
  | .p107 => (source14.sig "%UnsignedInteger64.multiply").get (by rfl)
  | .p108 => (source14.sig "%UnsignedInteger64.subtract").get (by rfl)
  | .p109 => (source20.sig "%eq").get (by rfl)
  | .p110 => (source20.sig "%ne").get (by rfl)
  | .p111 => (source2.sig "Byte.bitwiseAnd").get (by rfl)
  | .p112 => (source2.sig "Byte.bitwiseExclusiveOr").get (by rfl)
  | .p113 => (source2.sig "Byte.bitwiseNot").get (by rfl)
  | .p114 => (source2.sig "Byte.bitwiseOr").get (by rfl)
  | .p115 => (source2.sig "Byte.fromInteger").get (by rfl)
  | .p116 => (source2.sig "Byte.shiftLeft").get (by rfl)
  | .p117 => (source2.sig "Byte.shiftRight").get (by rfl)
  | .p118 => (source2.sig "Byte.toInteger").get (by rfl)
  | .p119 => (source3.sig "Byte.toString").get (by rfl)
  | .p120 => (source6.sig "Bytes.concatenate").get (by rfl)
  | .p121 => (source6.sig "Bytes.empty").get (by rfl)
  | .p122 => (source6.sig "Bytes.fromBinary").get (by rfl)
  | .p123 => (source6.sig "Bytes.fromHex").get (by rfl)
  | .p124 => (source6.sig "Bytes.fromIntegers").get (by rfl)
  | .p125 => (source7.sig "Bytes.fromList").get (by rfl)
  | .p126 => (source6.sig "Bytes.fromSigned").get (by rfl)
  | .p127 => (source6.sig "Bytes.fromUnsigned").get (by rfl)
  | .p128 => (source6.sig "Bytes.get").get (by rfl)
  | .p129 => (source7.sig "Bytes.length").get (by rfl)
  | .p130 => (source6.sig "Bytes.readSigned").get (by rfl)
  | .p131 => (source6.sig "Bytes.readUnsigned").get (by rfl)
  | .p132 => (source6.sig "Bytes.slice").get (by rfl)
  | .p133 => (source6.sig "Bytes.toBinary").get (by rfl)
  | .p134 => (source6.sig "Bytes.toHex").get (by rfl)
  | .p135 => (source7.sig "Bytes.toList").get (by rfl)
  | .p136 => (source2.sig "Character.fromInteger").get (by rfl)
  | .p137 => (source4.sig "Character.isASCIIDigit").get (by rfl)
  | .p138 => (source4.sig "Character.isASCIIWhitespace").get (by rfl)
  | .p139 => (source4.sig "Character.isAlphabetic").get (by rfl)
  | .p140 => (source4.sig "Character.isLowercase").get (by rfl)
  | .p141 => (source4.sig "Character.isNumeric").get (by rfl)
  | .p142 => (source4.sig "Character.isUppercase").get (by rfl)
  | .p143 => (source4.sig "Character.isWhitespace").get (by rfl)
  | .p144 => (source2.sig "Character.toInteger").get (by rfl)
  | .p145 => (source4.sig "Character.toLowercase").get (by rfl)
  | .p146 => (source4.sig "Character.toString").get (by rfl)
  | .p147 => (source4.sig "Character.toUppercase").get (by rfl)
  | .p148 => (source15.sig "Decimal.absolute").get (by rfl)
  | .p149 => (source10.sig "Decimal.fromFloat").get (by rfl)
  | .p150 => (source15.sig "Decimal.fromInteger").get (by rfl)
  | .p151 => (source10.sig "Decimal.parse").get (by rfl)
  | .p152 => (source15.sig "Decimal.round").get (by rfl)
  | .p153 => (source10.sig "Decimal.toFloat").get (by rfl)
  | .p154 => (source10.sig "Decimal.toString").get (by rfl)
  | .p155 => (source15.sig "Decimal.truncate").get (by rfl)
  | .p156 => (source23.sig "Example.pathBases").get (by rfl)
  | .p157 => (source23.sig "File.appendBytesIn").get (by rfl)
  | .p158 => (source23.sig "File.appendTextIn").get (by rfl)
  | .p159 => (source23.sig "File.readBytesIn").get (by rfl)
  | .p160 => (source23.sig "File.readText").get (by rfl)
  | .p161 => (source23.sig "File.readTextIn").get (by rfl)
  | .p162 => (source23.sig "File.writeBytesIn").get (by rfl)
  | .p163 => (source23.sig "File.writeTextIn").get (by rfl)
  | .p164 => (source16.sig "Float.absolute").get (by rfl)
  | .p165 => (source16.sig "Float.ceiling").get (by rfl)
  | .p166 => (source16.sig "Float.floor").get (by rfl)
  | .p167 => (source2.sig "Float.isNaN").get (by rfl)
  | .p168 => (source10.sig "Float.parse").get (by rfl)
  | .p169 => (source16.sig "Float.round").get (by rfl)
  | .p170 => (source16.sig "Float.squareRoot").get (by rfl)
  | .p171 => (source10.sig "Float.toString").get (by rfl)
  | .p172 => (source16.sig "Float.truncate").get (by rfl)
  | .p173 => (source16.sig "Float32.absolute").get (by rfl)
  | .p174 => (source16.sig "Float32.ceiling").get (by rfl)
  | .p175 => (source16.sig "Float32.floor").get (by rfl)
  | .p176 => (source10.sig "Float32.fromFloat").get (by rfl)
  | .p177 => (source2.sig "Float32.isInfinite").get (by rfl)
  | .p178 => (source2.sig "Float32.isNaN").get (by rfl)
  | .p179 => (source10.sig "Float32.parse").get (by rfl)
  | .p180 => (source16.sig "Float32.round").get (by rfl)
  | .p181 => (source16.sig "Float32.squareRoot").get (by rfl)
  | .p182 => (source10.sig "Float32.toFloat").get (by rfl)
  | .p183 => (source10.sig "Float32.toString").get (by rfl)
  | .p184 => (source16.sig "Float32.truncate").get (by rfl)
  | .p185 => (source24.sig "Http.checkRequestIn").get (by rfl)
  | .p186 => (source24.sig "Http.requestInValue").get (by rfl)
  | .p187 => (source24.sig "Http.sendIn").get (by rfl)
  | .p188 => (source24.sig "Http.widenRequestIn").get (by rfl)
  | .p189 => (source11.sig "Integer.absolute").get (by rfl)
  | .p190 => (source11.sig "Integer.bitwiseAnd").get (by rfl)
  | .p191 => (source11.sig "Integer.bitwiseExclusiveOr").get (by rfl)
  | .p192 => (source11.sig "Integer.bitwiseNot").get (by rfl)
  | .p193 => (source11.sig "Integer.bitwiseOr").get (by rfl)
  | .p194 => (source11.sig "Integer.floorDivide").get (by rfl)
  | .p195 => (source11.sig "Integer.floorModulo").get (by rfl)
  | .p196 => (source17.sig "Integer.maximum").get (by rfl)
  | .p197 => (source17.sig "Integer.minimum").get (by rfl)
  | .p198 => (source12.sig "Integer.parse").get (by rfl)
  | .p199 => (source11.sig "Integer.shiftLeft").get (by rfl)
  | .p200 => (source11.sig "Integer.shiftRight").get (by rfl)
  | .p201 => (source11.sig "Integer.shiftRightUnsigned").get (by rfl)
  | .p202 => (source12.sig "Integer.toFloat").get (by rfl)
  | .p203 => (source12.sig "Integer.toString").get (by rfl)
  | .p204 => (source11.sig "Integer16.absolute").get (by rfl)
  | .p205 => (source11.sig "Integer16.bitwiseAnd").get (by rfl)
  | .p206 => (source11.sig "Integer16.bitwiseExclusiveOr").get (by rfl)
  | .p207 => (source11.sig "Integer16.bitwiseNot").get (by rfl)
  | .p208 => (source11.sig "Integer16.bitwiseOr").get (by rfl)
  | .p209 => (source11.sig "Integer16.floorDivide").get (by rfl)
  | .p210 => (source11.sig "Integer16.floorModulo").get (by rfl)
  | .p211 => (source13.sig "Integer16.fromInteger").get (by rfl)
  | .p212 => (source17.sig "Integer16.maximum").get (by rfl)
  | .p213 => (source17.sig "Integer16.minimum").get (by rfl)
  | .p214 => (source12.sig "Integer16.parse").get (by rfl)
  | .p215 => (source11.sig "Integer16.shiftLeft").get (by rfl)
  | .p216 => (source11.sig "Integer16.shiftRight").get (by rfl)
  | .p217 => (source11.sig "Integer16.shiftRightUnsigned").get (by rfl)
  | .p218 => (source12.sig "Integer16.toFloat").get (by rfl)
  | .p219 => (source13.sig "Integer16.toInteger").get (by rfl)
  | .p220 => (source12.sig "Integer16.toString").get (by rfl)
  | .p221 => (source11.sig "Integer32.absolute").get (by rfl)
  | .p222 => (source11.sig "Integer32.bitwiseAnd").get (by rfl)
  | .p223 => (source11.sig "Integer32.bitwiseExclusiveOr").get (by rfl)
  | .p224 => (source11.sig "Integer32.bitwiseNot").get (by rfl)
  | .p225 => (source11.sig "Integer32.bitwiseOr").get (by rfl)
  | .p226 => (source11.sig "Integer32.floorDivide").get (by rfl)
  | .p227 => (source11.sig "Integer32.floorModulo").get (by rfl)
  | .p228 => (source13.sig "Integer32.fromInteger").get (by rfl)
  | .p229 => (source17.sig "Integer32.maximum").get (by rfl)
  | .p230 => (source17.sig "Integer32.minimum").get (by rfl)
  | .p231 => (source12.sig "Integer32.parse").get (by rfl)
  | .p232 => (source11.sig "Integer32.shiftLeft").get (by rfl)
  | .p233 => (source11.sig "Integer32.shiftRight").get (by rfl)
  | .p234 => (source11.sig "Integer32.shiftRightUnsigned").get (by rfl)
  | .p235 => (source12.sig "Integer32.toFloat").get (by rfl)
  | .p236 => (source13.sig "Integer32.toInteger").get (by rfl)
  | .p237 => (source12.sig "Integer32.toString").get (by rfl)
  | .p238 => (source11.sig "Integer8.absolute").get (by rfl)
  | .p239 => (source11.sig "Integer8.bitwiseAnd").get (by rfl)
  | .p240 => (source11.sig "Integer8.bitwiseExclusiveOr").get (by rfl)
  | .p241 => (source11.sig "Integer8.bitwiseNot").get (by rfl)
  | .p242 => (source11.sig "Integer8.bitwiseOr").get (by rfl)
  | .p243 => (source11.sig "Integer8.floorDivide").get (by rfl)
  | .p244 => (source11.sig "Integer8.floorModulo").get (by rfl)
  | .p245 => (source13.sig "Integer8.fromInteger").get (by rfl)
  | .p246 => (source17.sig "Integer8.maximum").get (by rfl)
  | .p247 => (source17.sig "Integer8.minimum").get (by rfl)
  | .p248 => (source12.sig "Integer8.parse").get (by rfl)
  | .p249 => (source11.sig "Integer8.shiftLeft").get (by rfl)
  | .p250 => (source11.sig "Integer8.shiftRight").get (by rfl)
  | .p251 => (source11.sig "Integer8.shiftRightUnsigned").get (by rfl)
  | .p252 => (source12.sig "Integer8.toFloat").get (by rfl)
  | .p253 => (source13.sig "Integer8.toInteger").get (by rfl)
  | .p254 => (source12.sig "Integer8.toString").get (by rfl)
  | .p255 => (source0.sig "List.append").get (by rfl)
  | .p256 => (source9.sig "List.concatenate").get (by rfl)
  | .p257 => (source8.sig "List.contains").get (by rfl)
  | .p258 => (source8.sig "List.drop").get (by rfl)
  | .p259 => (source8.sig "List.get").get (by rfl)
  | .p260 => (source0.sig "List.head").get (by rfl)
  | .p261 => (source9.sig "List.isEmpty").get (by rfl)
  | .p262 => (source9.sig "List.length").get (by rfl)
  | .p263 => (source9.sig "List.prepend").get (by rfl)
  | .p264 => (source8.sig "List.range").get (by rfl)
  | .p265 => (source9.sig "List.reverse").get (by rfl)
  | .p266 => (source8.sig "List.sort").get (by rfl)
  | .p267 => (source0.sig "List.tail").get (by rfl)
  | .p268 => (source8.sig "List.take").get (by rfl)
  | .p269 => (source22.sig "Map.contains").get (by rfl)
  | .p270 => (source22.sig "Map.empty").get (by rfl)
  | .p271 => (source1.sig "Map.fromList").get (by rfl)
  | .p272 => (source22.sig "Map.get").get (by rfl)
  | .p273 => (source22.sig "Map.keys").get (by rfl)
  | .p274 => (source22.sig "Map.remove").get (by rfl)
  | .p275 => (source22.sig "Map.set").get (by rfl)
  | .p276 => (source22.sig "Map.size").get (by rfl)
  | .p277 => (source1.sig "Map.toList").get (by rfl)
  | .p278 => (source22.sig "Map.values").get (by rfl)
  | .p279 => (source23.sig "Reference.get").get (by rfl)
  | .p280 => (source23.sig "Reference.set").get (by rfl)
  | .p281 => (source23.sig "Scope.checkPathIn").get (by rfl)
  | .p282 => (source23.sig "Scope.pathInValue").get (by rfl)
  | .p283 => (source23.sig "Scope.widenPathIn").get (by rfl)
  | .p284 => (source22.sig "Set.add").get (by rfl)
  | .p285 => (source22.sig "Set.contains").get (by rfl)
  | .p286 => (source22.sig "Set.difference").get (by rfl)
  | .p287 => (source22.sig "Set.empty").get (by rfl)
  | .p288 => (source1.sig "Set.fromList").get (by rfl)
  | .p289 => (source22.sig "Set.intersection").get (by rfl)
  | .p290 => (source22.sig "Set.remove").get (by rfl)
  | .p291 => (source22.sig "Set.size").get (by rfl)
  | .p292 => (source1.sig "Set.toList").get (by rfl)
  | .p293 => (source22.sig "Set.union").get (by rfl)
  | .p294 => (source5.sig "String.byteIndexOf").get (by rfl)
  | .p295 => (source7.sig "String.byteLength").get (by rfl)
  | .p296 => (source5.sig "String.byteSlice").get (by rfl)
  | .p297 => (source5.sig "String.characterAt").get (by rfl)
  | .p298 => (source7.sig "String.characterCount").get (by rfl)
  | .p299 => (source5.sig "String.characterSlice").get (by rfl)
  | .p300 => (source5.sig "String.characters").get (by rfl)
  | .p301 => (source5.sig "String.contains").get (by rfl)
  | .p302 => (source5.sig "String.displayWidth").get (by rfl)
  | .p303 => (source5.sig "String.displayWidthCJK").get (by rfl)
  | .p304 => (source5.sig "String.displayWidthPadEnd").get (by rfl)
  | .p305 => (source5.sig "String.displayWidthPadEndCJK").get (by rfl)
  | .p306 => (source5.sig "String.displayWidthPadStart").get (by rfl)
  | .p307 => (source5.sig "String.displayWidthPadStartCJK").get (by rfl)
  | .p308 => (source5.sig "String.endsWith").get (by rfl)
  | .p309 => (source5.sig "String.fromCharacters").get (by rfl)
  | .p310 => (source5.sig "String.fromUTF8").get (by rfl)
  | .p311 => (source5.sig "String.isEmpty").get (by rfl)
  | .p312 => (source5.sig "String.join").get (by rfl)
  | .p313 => (source5.sig "String.lines").get (by rfl)
  | .p314 => (source5.sig "String.repeat").get (by rfl)
  | .p315 => (source5.sig "String.replace").get (by rfl)
  | .p316 => (source5.sig "String.split").get (by rfl)
  | .p317 => (source5.sig "String.startsWith").get (by rfl)
  | .p318 => (source5.sig "String.toLowercase").get (by rfl)
  | .p319 => (source5.sig "String.toUTF8").get (by rfl)
  | .p320 => (source5.sig "String.toUppercase").get (by rfl)
  | .p321 => (source5.sig "String.trim").get (by rfl)
  | .p322 => (source11.sig "UnsignedInteger16.absolute").get (by rfl)
  | .p323 => (source11.sig "UnsignedInteger16.bitwiseAnd").get (by rfl)
  | .p324 => (source11.sig "UnsignedInteger16.bitwiseExclusiveOr").get (by rfl)
  | .p325 => (source11.sig "UnsignedInteger16.bitwiseNot").get (by rfl)
  | .p326 => (source11.sig "UnsignedInteger16.bitwiseOr").get (by rfl)
  | .p327 => (source11.sig "UnsignedInteger16.floorDivide").get (by rfl)
  | .p328 => (source11.sig "UnsignedInteger16.floorModulo").get (by rfl)
  | .p329 => (source13.sig "UnsignedInteger16.fromInteger").get (by rfl)
  | .p330 => (source17.sig "UnsignedInteger16.maximum").get (by rfl)
  | .p331 => (source17.sig "UnsignedInteger16.minimum").get (by rfl)
  | .p332 => (source12.sig "UnsignedInteger16.parse").get (by rfl)
  | .p333 => (source11.sig "UnsignedInteger16.shiftLeft").get (by rfl)
  | .p334 => (source11.sig "UnsignedInteger16.shiftRight").get (by rfl)
  | .p335 => (source12.sig "UnsignedInteger16.toFloat").get (by rfl)
  | .p336 => (source13.sig "UnsignedInteger16.toInteger").get (by rfl)
  | .p337 => (source12.sig "UnsignedInteger16.toString").get (by rfl)
  | .p338 => (source11.sig "UnsignedInteger32.absolute").get (by rfl)
  | .p339 => (source11.sig "UnsignedInteger32.bitwiseAnd").get (by rfl)
  | .p340 => (source11.sig "UnsignedInteger32.bitwiseExclusiveOr").get (by rfl)
  | .p341 => (source11.sig "UnsignedInteger32.bitwiseNot").get (by rfl)
  | .p342 => (source11.sig "UnsignedInteger32.bitwiseOr").get (by rfl)
  | .p343 => (source11.sig "UnsignedInteger32.floorDivide").get (by rfl)
  | .p344 => (source11.sig "UnsignedInteger32.floorModulo").get (by rfl)
  | .p345 => (source13.sig "UnsignedInteger32.fromInteger").get (by rfl)
  | .p346 => (source17.sig "UnsignedInteger32.maximum").get (by rfl)
  | .p347 => (source17.sig "UnsignedInteger32.minimum").get (by rfl)
  | .p348 => (source12.sig "UnsignedInteger32.parse").get (by rfl)
  | .p349 => (source11.sig "UnsignedInteger32.shiftLeft").get (by rfl)
  | .p350 => (source11.sig "UnsignedInteger32.shiftRight").get (by rfl)
  | .p351 => (source12.sig "UnsignedInteger32.toFloat").get (by rfl)
  | .p352 => (source13.sig "UnsignedInteger32.toInteger").get (by rfl)
  | .p353 => (source12.sig "UnsignedInteger32.toString").get (by rfl)
  | .p354 => (source11.sig "UnsignedInteger64.absolute").get (by rfl)
  | .p355 => (source11.sig "UnsignedInteger64.bitwiseAnd").get (by rfl)
  | .p356 => (source11.sig "UnsignedInteger64.bitwiseExclusiveOr").get (by rfl)
  | .p357 => (source11.sig "UnsignedInteger64.bitwiseNot").get (by rfl)
  | .p358 => (source11.sig "UnsignedInteger64.bitwiseOr").get (by rfl)
  | .p359 => (source11.sig "UnsignedInteger64.floorDivide").get (by rfl)
  | .p360 => (source11.sig "UnsignedInteger64.floorModulo").get (by rfl)
  | .p361 => (source15.sig "UnsignedInteger64.fromDecimal").get (by rfl)
  | .p362 => (source13.sig "UnsignedInteger64.fromInteger").get (by rfl)
  | .p363 => (source17.sig "UnsignedInteger64.maximum").get (by rfl)
  | .p364 => (source17.sig "UnsignedInteger64.minimum").get (by rfl)
  | .p365 => (source12.sig "UnsignedInteger64.parse").get (by rfl)
  | .p366 => (source11.sig "UnsignedInteger64.shiftLeft").get (by rfl)
  | .p367 => (source11.sig "UnsignedInteger64.shiftRight").get (by rfl)
  | .p368 => (source15.sig "UnsignedInteger64.toDecimal").get (by rfl)
  | .p369 => (source12.sig "UnsignedInteger64.toFloat").get (by rfl)
  | .p370 => (source13.sig "UnsignedInteger64.toInteger").get (by rfl)
  | .p371 => (source12.sig "UnsignedInteger64.toString").get (by rfl)
  | .p372 => (source23.sig "exit").get (by rfl)
  | .p373 => (source23.sig "print").get (by rfl)
  | .p374 => forceSig
  | .p375 => refNewSig
  | .p376 => refUpdateSig
  | .p377 => StandardSafe.frontSig



private inductive SignatureTree where
  | empty
  | node (key : String) (row : Primitive) (same : key = row.name) (left right : SignatureTree)

private def SignatureTree.rows : SignatureTree → List Primitive
  | .empty => []
  | .node _ row _ left right => left.rows ++ row :: right.rows

private def SignatureTree.lookup (name : String) : SignatureTree → Option Primitive
  | .empty => none
  | .node key row _ left right => if name = key then some row
      else if name < key then left.lookup name else right.lookup name

private theorem SignatureTree.lookup_row {tree : SignatureTree} {name : String} {row : Primitive} (lookup : tree.lookup name = some row) :
    row ∈ tree.rows ∧ name = row.name := by
  induction tree with
  | empty => cases lookup
  | node key current same left right ihl ihr =>
    simp only [SignatureTree.lookup] at lookup
    split at lookup
    · rename_i eq
      cases Option.some.inj lookup
      exact ⟨List.mem_append_right _ List.mem_cons_self,eq.trans same⟩
    · split at lookup
      · obtain ⟨member,eq⟩ := ihl lookup
        exact ⟨List.mem_append_left _ member,eq⟩
      · obtain ⟨member,eq⟩ := ihr lookup
        exact ⟨List.mem_append_right _ (List.mem_cons_of_mem _ member),eq⟩

private def primitiveTree : SignatureTree := (.node "Http.sendIn" .p187 rfl (.node "%UnsignedInteger32.greaterOrEqual" .p094 rfl (.node "%Integer16.div" .p047 rfl (.node "%Float.multiply" .p024 rfl (.node "%Decimal.greaterOrEqual" .p012 rfl (.node "%Character.greaterOrEqual" .p006 rfl (.node "%Byte.less" .p003 rfl (.node "%Byte.greaterOrEqual" .p002 rfl (.node "%Byte.greater" .p001 rfl .empty .empty) .empty) (.node "%Character.greater" .p005 rfl (.node "%Byte.lessOrEqual" .p004 rfl .empty .empty) .empty)) (.node "%Decimal.add" .p009 rfl (.node "%Character.lessOrEqual" .p008 rfl (.node "%Character.less" .p007 rfl .empty .empty) .empty) (.node "%Decimal.greater" .p011 rfl (.node "%Decimal.divide" .p010 rfl .empty .empty) .empty))) (.node "%Float.add" .p018 rfl (.node "%Decimal.multiply" .p015 rfl (.node "%Decimal.lessOrEqual" .p014 rfl (.node "%Decimal.less" .p013 rfl .empty .empty) .empty) (.node "%Decimal.subtract" .p017 rfl (.node "%Decimal.negate" .p016 rfl .empty .empty) .empty)) (.node "%Float.greaterOrEqual" .p021 rfl (.node "%Float.greater" .p020 rfl (.node "%Float.divide" .p019 rfl .empty .empty) .empty) (.node "%Float.lessOrEqual" .p023 rfl (.node "%Float.less" .p022 rfl .empty .empty) .empty)))) (.node "%Integer.add" .p036 rfl (.node "%Float32.greaterOrEqual" .p030 rfl (.node "%Float32.add" .p027 rfl (.node "%Float.subtract" .p026 rfl (.node "%Float.negate" .p025 rfl .empty .empty) .empty) (.node "%Float32.greater" .p029 rfl (.node "%Float32.divide" .p028 rfl .empty .empty) .empty)) (.node "%Float32.multiply" .p033 rfl (.node "%Float32.lessOrEqual" .p032 rfl (.node "%Float32.less" .p031 rfl .empty .empty) .empty) (.node "%Float32.subtract" .p035 rfl (.node "%Float32.negate" .p034 rfl .empty .empty) .empty))) (.node "%Integer.mod" .p042 rfl (.node "%Integer.greaterOrEqual" .p039 rfl (.node "%Integer.greater" .p038 rfl (.node "%Integer.div" .p037 rfl .empty .empty) .empty) (.node "%Integer.lessOrEqual" .p041 rfl (.node "%Integer.less" .p040 rfl .empty .empty) .empty)) (.node "%Integer.subtract" .p045 rfl (.node "%Integer.negate" .p044 rfl (.node "%Integer.multiply" .p043 rfl .empty .empty) .empty) (.node "%Integer16.add" .p046 rfl .empty .empty))))) (.node "%Integer8.lessOrEqual" .p071 rfl (.node "%Integer32.greaterOrEqual" .p059 rfl (.node "%Integer16.multiply" .p053 rfl (.node "%Integer16.less" .p050 rfl (.node "%Integer16.greaterOrEqual" .p049 rfl (.node "%Integer16.greater" .p048 rfl .empty .empty) .empty) (.node "%Integer16.mod" .p052 rfl (.node "%Integer16.lessOrEqual" .p051 rfl .empty .empty) .empty)) (.node "%Integer32.add" .p056 rfl (.node "%Integer16.subtract" .p055 rfl (.node "%Integer16.negate" .p054 rfl .empty .empty) .empty) (.node "%Integer32.greater" .p058 rfl (.node "%Integer32.div" .p057 rfl .empty .empty) .empty))) (.node "%Integer32.subtract" .p065 rfl (.node "%Integer32.mod" .p062 rfl (.node "%Integer32.lessOrEqual" .p061 rfl (.node "%Integer32.less" .p060 rfl .empty .empty) .empty) (.node "%Integer32.negate" .p064 rfl (.node "%Integer32.multiply" .p063 rfl .empty .empty) .empty)) (.node "%Integer8.greater" .p068 rfl (.node "%Integer8.div" .p067 rfl (.node "%Integer8.add" .p066 rfl .empty .empty) .empty) (.node "%Integer8.less" .p070 rfl (.node "%Integer8.greaterOrEqual" .p069 rfl .empty .empty) .empty)))) (.node "%UnsignedInteger16.div" .p083 rfl (.node "%String.add" .p077 rfl (.node "%Integer8.negate" .p074 rfl (.node "%Integer8.multiply" .p073 rfl (.node "%Integer8.mod" .p072 rfl .empty .empty) .empty) (.node "%Map.replaceValues" .p076 rfl (.node "%Integer8.subtract" .p075 rfl .empty (.node "%List.getFront" .p377 rfl .empty .empty)) .empty)) (.node "%String.less" .p080 rfl (.node "%String.greaterOrEqual" .p079 rfl (.node "%String.greater" .p078 rfl .empty .empty) .empty) (.node "%UnsignedInteger16.add" .p082 rfl (.node "%String.lessOrEqual" .p081 rfl .empty .empty) .empty))) (.node "%UnsignedInteger16.multiply" .p089 rfl (.node "%UnsignedInteger16.less" .p086 rfl (.node "%UnsignedInteger16.greaterOrEqual" .p085 rfl (.node "%UnsignedInteger16.greater" .p084 rfl .empty .empty) .empty) (.node "%UnsignedInteger16.mod" .p088 rfl (.node "%UnsignedInteger16.lessOrEqual" .p087 rfl .empty .empty) .empty)) (.node "%UnsignedInteger32.div" .p092 rfl (.node "%UnsignedInteger32.add" .p091 rfl (.node "%UnsignedInteger16.subtract" .p090 rfl .empty .empty) .empty) (.node "%UnsignedInteger32.greater" .p093 rfl .empty .empty)))))) (.node "Character.isNumeric" .p141 rfl (.node "Byte.toInteger" .p118 rfl (.node "%UnsignedInteger64.mod" .p106 rfl (.node "%UnsignedInteger64.add" .p100 rfl (.node "%UnsignedInteger32.mod" .p097 rfl (.node "%UnsignedInteger32.lessOrEqual" .p096 rfl (.node "%UnsignedInteger32.less" .p095 rfl .empty .empty) .empty) (.node "%UnsignedInteger32.subtract" .p099 rfl (.node "%UnsignedInteger32.multiply" .p098 rfl .empty .empty) .empty)) (.node "%UnsignedInteger64.greaterOrEqual" .p103 rfl (.node "%UnsignedInteger64.greater" .p102 rfl (.node "%UnsignedInteger64.div" .p101 rfl .empty .empty) .empty) (.node "%UnsignedInteger64.lessOrEqual" .p105 rfl (.node "%UnsignedInteger64.less" .p104 rfl .empty .empty) .empty))) (.node "Byte.bitwiseExclusiveOr" .p112 rfl (.node "%eq" .p109 rfl (.node "%UnsignedInteger64.subtract" .p108 rfl (.node "%UnsignedInteger64.multiply" .p107 rfl .empty .empty) .empty) (.node "Byte.bitwiseAnd" .p111 rfl (.node "%ne" .p110 rfl .empty .empty) .empty)) (.node "Byte.fromInteger" .p115 rfl (.node "Byte.bitwiseOr" .p114 rfl (.node "Byte.bitwiseNot" .p113 rfl .empty .empty) .empty) (.node "Byte.shiftRight" .p117 rfl (.node "Byte.shiftLeft" .p116 rfl .empty .empty) .empty)))) (.node "Bytes.readSigned" .p130 rfl (.node "Bytes.fromIntegers" .p124 rfl (.node "Bytes.empty" .p121 rfl (.node "Bytes.concatenate" .p120 rfl (.node "Byte.toString" .p119 rfl .empty .empty) .empty) (.node "Bytes.fromHex" .p123 rfl (.node "Bytes.fromBinary" .p122 rfl .empty .empty) .empty)) (.node "Bytes.fromUnsigned" .p127 rfl (.node "Bytes.fromSigned" .p126 rfl (.node "Bytes.fromList" .p125 rfl .empty .empty) .empty) (.node "Bytes.length" .p129 rfl (.node "Bytes.get" .p128 rfl .empty .empty) .empty))) (.node "Character.fromInteger" .p136 rfl (.node "Bytes.toBinary" .p133 rfl (.node "Bytes.slice" .p132 rfl (.node "Bytes.readUnsigned" .p131 rfl .empty .empty) .empty) (.node "Bytes.toList" .p135 rfl (.node "Bytes.toHex" .p134 rfl .empty .empty) .empty)) (.node "Character.isAlphabetic" .p139 rfl (.node "Character.isASCIIWhitespace" .p138 rfl (.node "Character.isASCIIDigit" .p137 rfl .empty .empty) .empty) (.node "Character.isLowercase" .p140 rfl .empty .empty))))) (.node "Float.absolute" .p164 rfl (.node "Decimal.toFloat" .p153 rfl (.node "Character.toUppercase" .p147 rfl (.node "Character.toInteger" .p144 rfl (.node "Character.isWhitespace" .p143 rfl (.node "Character.isUppercase" .p142 rfl .empty .empty) .empty) (.node "Character.toString" .p146 rfl (.node "Character.toLowercase" .p145 rfl .empty .empty) .empty)) (.node "Decimal.fromInteger" .p150 rfl (.node "Decimal.fromFloat" .p149 rfl (.node "Decimal.absolute" .p148 rfl .empty .empty) .empty) (.node "Decimal.round" .p152 rfl (.node "Decimal.parse" .p151 rfl .empty .empty) .empty))) (.node "File.readBytesIn" .p159 rfl (.node "Example.pathBases" .p156 rfl (.node "Decimal.truncate" .p155 rfl (.node "Decimal.toString" .p154 rfl .empty .empty) .empty) (.node "File.appendTextIn" .p158 rfl (.node "File.appendBytesIn" .p157 rfl .empty .empty) .empty)) (.node "File.writeBytesIn" .p162 rfl (.node "File.readTextIn" .p161 rfl (.node "File.readText" .p160 rfl .empty .empty) .empty) (.node "File.writeTextIn" .p163 rfl .empty .empty)))) (.node "Float32.fromFloat" .p176 rfl (.node "Float.squareRoot" .p170 rfl (.node "Float.isNaN" .p167 rfl (.node "Float.floor" .p166 rfl (.node "Float.ceiling" .p165 rfl .empty .empty) .empty) (.node "Float.round" .p169 rfl (.node "Float.parse" .p168 rfl .empty .empty) .empty)) (.node "Float32.absolute" .p173 rfl (.node "Float.truncate" .p172 rfl (.node "Float.toString" .p171 rfl .empty .empty) .empty) (.node "Float32.floor" .p175 rfl (.node "Float32.ceiling" .p174 rfl .empty .empty) .empty))) (.node "Float32.toFloat" .p182 rfl (.node "Float32.parse" .p179 rfl (.node "Float32.isNaN" .p178 rfl (.node "Float32.isInfinite" .p177 rfl .empty .empty) .empty) (.node "Float32.squareRoot" .p181 rfl (.node "Float32.round" .p180 rfl .empty .empty) .empty)) (.node "Http.checkRequestIn" .p185 rfl (.node "Float32.truncate" .p184 rfl (.node "Float32.toString" .p183 rfl .empty .empty) .empty) (.node "Http.requestInValue" .p186 rfl .empty .empty))))))) (.node "Scope.checkPathIn" .p281 rfl (.node "Integer32.shiftRightUnsigned" .p234 rfl (.node "Integer16.fromInteger" .p211 rfl (.node "Integer.shiftLeft" .p199 rfl (.node "Integer.bitwiseOr" .p193 rfl (.node "Integer.bitwiseAnd" .p190 rfl (.node "Integer.absolute" .p189 rfl (.node "Http.widenRequestIn" .p188 rfl .empty .empty) .empty) (.node "Integer.bitwiseNot" .p192 rfl (.node "Integer.bitwiseExclusiveOr" .p191 rfl .empty .empty) .empty)) (.node "Integer.maximum" .p196 rfl (.node "Integer.floorModulo" .p195 rfl (.node "Integer.floorDivide" .p194 rfl .empty .empty) .empty) (.node "Integer.parse" .p198 rfl (.node "Integer.minimum" .p197 rfl .empty .empty) .empty))) (.node "Integer16.bitwiseAnd" .p205 rfl (.node "Integer.toFloat" .p202 rfl (.node "Integer.shiftRightUnsigned" .p201 rfl (.node "Integer.shiftRight" .p200 rfl .empty .empty) .empty) (.node "Integer16.absolute" .p204 rfl (.node "Integer.toString" .p203 rfl .empty .empty) .empty)) (.node "Integer16.bitwiseOr" .p208 rfl (.node "Integer16.bitwiseNot" .p207 rfl (.node "Integer16.bitwiseExclusiveOr" .p206 rfl .empty .empty) .empty) (.node "Integer16.floorModulo" .p210 rfl (.node "Integer16.floorDivide" .p209 rfl .empty .empty) .empty)))) (.node "Integer32.bitwiseExclusiveOr" .p223 rfl (.node "Integer16.shiftRightUnsigned" .p217 rfl (.node "Integer16.parse" .p214 rfl (.node "Integer16.minimum" .p213 rfl (.node "Integer16.maximum" .p212 rfl .empty .empty) .empty) (.node "Integer16.shiftRight" .p216 rfl (.node "Integer16.shiftLeft" .p215 rfl .empty .empty) .empty)) (.node "Integer16.toString" .p220 rfl (.node "Integer16.toInteger" .p219 rfl (.node "Integer16.toFloat" .p218 rfl .empty .empty) .empty) (.node "Integer32.bitwiseAnd" .p222 rfl (.node "Integer32.absolute" .p221 rfl .empty .empty) .empty))) (.node "Integer32.maximum" .p229 rfl (.node "Integer32.floorDivide" .p226 rfl (.node "Integer32.bitwiseOr" .p225 rfl (.node "Integer32.bitwiseNot" .p224 rfl .empty .empty) .empty) (.node "Integer32.fromInteger" .p228 rfl (.node "Integer32.floorModulo" .p227 rfl .empty .empty) .empty)) (.node "Integer32.shiftLeft" .p232 rfl (.node "Integer32.parse" .p231 rfl (.node "Integer32.minimum" .p230 rfl .empty .empty) .empty) (.node "Integer32.shiftRight" .p233 rfl .empty .empty))))) (.node "List.drop" .p258 rfl (.node "Integer8.maximum" .p246 rfl (.node "Integer8.bitwiseExclusiveOr" .p240 rfl (.node "Integer32.toString" .p237 rfl (.node "Integer32.toInteger" .p236 rfl (.node "Integer32.toFloat" .p235 rfl .empty .empty) .empty) (.node "Integer8.bitwiseAnd" .p239 rfl (.node "Integer8.absolute" .p238 rfl .empty .empty) .empty)) (.node "Integer8.floorDivide" .p243 rfl (.node "Integer8.bitwiseOr" .p242 rfl (.node "Integer8.bitwiseNot" .p241 rfl .empty .empty) .empty) (.node "Integer8.fromInteger" .p245 rfl (.node "Integer8.floorModulo" .p244 rfl .empty .empty) .empty))) (.node "Integer8.toFloat" .p252 rfl (.node "Integer8.shiftLeft" .p249 rfl (.node "Integer8.parse" .p248 rfl (.node "Integer8.minimum" .p247 rfl .empty .empty) .empty) (.node "Integer8.shiftRightUnsigned" .p251 rfl (.node "Integer8.shiftRight" .p250 rfl .empty .empty) .empty)) (.node "List.append" .p255 rfl (.node "Integer8.toString" .p254 rfl (.node "Integer8.toInteger" .p253 rfl .empty .empty) (.node "Lazy.force" .p374 rfl .empty .empty)) (.node "List.contains" .p257 rfl (.node "List.concatenate" .p256 rfl .empty .empty) .empty)))) (.node "Map.empty" .p270 rfl (.node "List.range" .p264 rfl (.node "List.isEmpty" .p261 rfl (.node "List.head" .p260 rfl (.node "List.get" .p259 rfl .empty .empty) .empty) (.node "List.prepend" .p263 rfl (.node "List.length" .p262 rfl .empty .empty) .empty)) (.node "List.tail" .p267 rfl (.node "List.sort" .p266 rfl (.node "List.reverse" .p265 rfl .empty .empty) .empty) (.node "Map.contains" .p269 rfl (.node "List.take" .p268 rfl .empty .empty) .empty))) (.node "Map.size" .p276 rfl (.node "Map.keys" .p273 rfl (.node "Map.get" .p272 rfl (.node "Map.fromList" .p271 rfl .empty .empty) .empty) (.node "Map.set" .p275 rfl (.node "Map.remove" .p274 rfl .empty .empty) .empty)) (.node "Reference.get" .p279 rfl (.node "Map.values" .p278 rfl (.node "Map.toList" .p277 rfl .empty .empty) .empty) (.node "Reference.set" .p280 rfl (.node "Reference.new" .p375 rfl .empty .empty) (.node "Reference.update" .p376 rfl .empty .empty))))))) (.node "UnsignedInteger16.floorModulo" .p328 rfl (.node "String.displayWidthPadEndCJK" .p305 rfl (.node "Set.union" .p293 rfl (.node "Set.empty" .p287 rfl (.node "Set.add" .p284 rfl (.node "Scope.widenPathIn" .p283 rfl (.node "Scope.pathInValue" .p282 rfl .empty .empty) .empty) (.node "Set.difference" .p286 rfl (.node "Set.contains" .p285 rfl .empty .empty) .empty)) (.node "Set.remove" .p290 rfl (.node "Set.intersection" .p289 rfl (.node "Set.fromList" .p288 rfl .empty .empty) .empty) (.node "Set.toList" .p292 rfl (.node "Set.size" .p291 rfl .empty .empty) .empty))) (.node "String.characterSlice" .p299 rfl (.node "String.byteSlice" .p296 rfl (.node "String.byteLength" .p295 rfl (.node "String.byteIndexOf" .p294 rfl .empty .empty) .empty) (.node "String.characterCount" .p298 rfl (.node "String.characterAt" .p297 rfl .empty .empty) .empty)) (.node "String.displayWidth" .p302 rfl (.node "String.contains" .p301 rfl (.node "String.characters" .p300 rfl .empty .empty) .empty) (.node "String.displayWidthPadEnd" .p304 rfl (.node "String.displayWidthCJK" .p303 rfl .empty .empty) .empty)))) (.node "String.startsWith" .p317 rfl (.node "String.isEmpty" .p311 rfl (.node "String.endsWith" .p308 rfl (.node "String.displayWidthPadStartCJK" .p307 rfl (.node "String.displayWidthPadStart" .p306 rfl .empty .empty) .empty) (.node "String.fromUTF8" .p310 rfl (.node "String.fromCharacters" .p309 rfl .empty .empty) .empty)) (.node "String.repeat" .p314 rfl (.node "String.lines" .p313 rfl (.node "String.join" .p312 rfl .empty .empty) .empty) (.node "String.split" .p316 rfl (.node "String.replace" .p315 rfl .empty .empty) .empty))) (.node "UnsignedInteger16.bitwiseAnd" .p323 rfl (.node "String.toUppercase" .p320 rfl (.node "String.toUTF8" .p319 rfl (.node "String.toLowercase" .p318 rfl .empty .empty) .empty) (.node "UnsignedInteger16.absolute" .p322 rfl (.node "String.trim" .p321 rfl .empty .empty) .empty)) (.node "UnsignedInteger16.bitwiseOr" .p326 rfl (.node "UnsignedInteger16.bitwiseNot" .p325 rfl (.node "UnsignedInteger16.bitwiseExclusiveOr" .p324 rfl .empty .empty) .empty) (.node "UnsignedInteger16.floorDivide" .p327 rfl .empty .empty))))) (.node "UnsignedInteger32.toFloat" .p351 rfl (.node "UnsignedInteger32.bitwiseExclusiveOr" .p340 rfl (.node "UnsignedInteger16.shiftRight" .p334 rfl (.node "UnsignedInteger16.minimum" .p331 rfl (.node "UnsignedInteger16.maximum" .p330 rfl (.node "UnsignedInteger16.fromInteger" .p329 rfl .empty .empty) .empty) (.node "UnsignedInteger16.shiftLeft" .p333 rfl (.node "UnsignedInteger16.parse" .p332 rfl .empty .empty) .empty)) (.node "UnsignedInteger16.toString" .p337 rfl (.node "UnsignedInteger16.toInteger" .p336 rfl (.node "UnsignedInteger16.toFloat" .p335 rfl .empty .empty) .empty) (.node "UnsignedInteger32.bitwiseAnd" .p339 rfl (.node "UnsignedInteger32.absolute" .p338 rfl .empty .empty) .empty))) (.node "UnsignedInteger32.maximum" .p346 rfl (.node "UnsignedInteger32.floorDivide" .p343 rfl (.node "UnsignedInteger32.bitwiseOr" .p342 rfl (.node "UnsignedInteger32.bitwiseNot" .p341 rfl .empty .empty) .empty) (.node "UnsignedInteger32.fromInteger" .p345 rfl (.node "UnsignedInteger32.floorModulo" .p344 rfl .empty .empty) .empty)) (.node "UnsignedInteger32.shiftLeft" .p349 rfl (.node "UnsignedInteger32.parse" .p348 rfl (.node "UnsignedInteger32.minimum" .p347 rfl .empty .empty) .empty) (.node "UnsignedInteger32.shiftRight" .p350 rfl .empty .empty)))) (.node "UnsignedInteger64.maximum" .p363 rfl (.node "UnsignedInteger64.bitwiseNot" .p357 rfl (.node "UnsignedInteger64.absolute" .p354 rfl (.node "UnsignedInteger32.toString" .p353 rfl (.node "UnsignedInteger32.toInteger" .p352 rfl .empty .empty) .empty) (.node "UnsignedInteger64.bitwiseExclusiveOr" .p356 rfl (.node "UnsignedInteger64.bitwiseAnd" .p355 rfl .empty .empty) .empty)) (.node "UnsignedInteger64.floorModulo" .p360 rfl (.node "UnsignedInteger64.floorDivide" .p359 rfl (.node "UnsignedInteger64.bitwiseOr" .p358 rfl .empty .empty) .empty) (.node "UnsignedInteger64.fromInteger" .p362 rfl (.node "UnsignedInteger64.fromDecimal" .p361 rfl .empty .empty) .empty))) (.node "UnsignedInteger64.toFloat" .p369 rfl (.node "UnsignedInteger64.shiftLeft" .p366 rfl (.node "UnsignedInteger64.parse" .p365 rfl (.node "UnsignedInteger64.minimum" .p364 rfl .empty .empty) .empty) (.node "UnsignedInteger64.toDecimal" .p368 rfl (.node "UnsignedInteger64.shiftRight" .p367 rfl .empty .empty) .empty)) (.node "exit" .p372 rfl (.node "UnsignedInteger64.toString" .p371 rfl (.node "UnsignedInteger64.toInteger" .p370 rfl .empty .empty) .empty) (.node "print" .p373 rfl .empty .empty))))))))

def Primitive.all : List Primitive := primitiveTree.rows

def primitive (name : String) : Option Primitive := primitiveTree.lookup name
def signature (name : String) : Option PrimSig := (primitive name).map Primitive.signature

/-- 署名の成功した全lookupを有限台帳へ戻す。 -/
theorem lookup_primitive {name s} (lookup : signature name = some s) :
    ∃ row ∈ Primitive.all, name = row.name ∧ s = row.signature := by
  obtain ⟨row,found,eq⟩ := Option.map_eq_some_iff.mp lookup
  have member := SignatureTree.lookup_row found
  change row ∈ Primitive.all ∧ name = row.name at member
  exact ⟨row,member.1,member.2,eq.symm⟩


end
end Benitoite.Release.Refinement.StandardModel
