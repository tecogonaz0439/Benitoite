import Benitoite.Release.Refinement.StandardModelSignatures

/-! # 組込みの各キーから合成表へのlookup -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
private theorem lookup_p001 : primitive "%Byte.greater" = some Primitive.p001 := rfl
private theorem lookup_p002 : primitive "%Byte.greaterOrEqual" = some Primitive.p002 := rfl
private theorem lookup_p003 : primitive "%Byte.less" = some Primitive.p003 := rfl
private theorem lookup_p004 : primitive "%Byte.lessOrEqual" = some Primitive.p004 := rfl
private theorem lookup_p005 : primitive "%Character.greater" = some Primitive.p005 := rfl
private theorem lookup_p006 : primitive "%Character.greaterOrEqual" = some Primitive.p006 := rfl
private theorem lookup_p007 : primitive "%Character.less" = some Primitive.p007 := rfl
private theorem lookup_p008 : primitive "%Character.lessOrEqual" = some Primitive.p008 := rfl
private theorem lookup_p009 : primitive "%Decimal.add" = some Primitive.p009 := rfl
private theorem lookup_p010 : primitive "%Decimal.divide" = some Primitive.p010 := rfl
private theorem lookup_p011 : primitive "%Decimal.greater" = some Primitive.p011 := rfl
private theorem lookup_p012 : primitive "%Decimal.greaterOrEqual" = some Primitive.p012 := rfl
private theorem lookup_p013 : primitive "%Decimal.less" = some Primitive.p013 := rfl
private theorem lookup_p014 : primitive "%Decimal.lessOrEqual" = some Primitive.p014 := rfl
private theorem lookup_p015 : primitive "%Decimal.multiply" = some Primitive.p015 := rfl
private theorem lookup_p016 : primitive "%Decimal.negate" = some Primitive.p016 := rfl
private theorem lookup_p017 : primitive "%Decimal.subtract" = some Primitive.p017 := rfl
private theorem lookup_p018 : primitive "%Float.add" = some Primitive.p018 := rfl
private theorem lookup_p019 : primitive "%Float.divide" = some Primitive.p019 := rfl
private theorem lookup_p020 : primitive "%Float.greater" = some Primitive.p020 := rfl
private theorem lookup_p021 : primitive "%Float.greaterOrEqual" = some Primitive.p021 := rfl
private theorem lookup_p022 : primitive "%Float.less" = some Primitive.p022 := rfl
private theorem lookup_p023 : primitive "%Float.lessOrEqual" = some Primitive.p023 := rfl
private theorem lookup_p024 : primitive "%Float.multiply" = some Primitive.p024 := rfl
private theorem lookup_p025 : primitive "%Float.negate" = some Primitive.p025 := rfl
private theorem lookup_p026 : primitive "%Float.subtract" = some Primitive.p026 := rfl
private theorem lookup_p027 : primitive "%Float32.add" = some Primitive.p027 := rfl
private theorem lookup_p028 : primitive "%Float32.divide" = some Primitive.p028 := rfl
private theorem lookup_p029 : primitive "%Float32.greater" = some Primitive.p029 := rfl
private theorem lookup_p030 : primitive "%Float32.greaterOrEqual" = some Primitive.p030 := rfl
private theorem lookup_p031 : primitive "%Float32.less" = some Primitive.p031 := rfl
private theorem lookup_p032 : primitive "%Float32.lessOrEqual" = some Primitive.p032 := rfl
private theorem lookup_p033 : primitive "%Float32.multiply" = some Primitive.p033 := rfl
private theorem lookup_p034 : primitive "%Float32.negate" = some Primitive.p034 := rfl
private theorem lookup_p035 : primitive "%Float32.subtract" = some Primitive.p035 := rfl
private theorem lookup_p036 : primitive "%Integer.add" = some Primitive.p036 := rfl
private theorem lookup_p037 : primitive "%Integer.div" = some Primitive.p037 := rfl
private theorem lookup_p038 : primitive "%Integer.greater" = some Primitive.p038 := rfl
private theorem lookup_p039 : primitive "%Integer.greaterOrEqual" = some Primitive.p039 := rfl
private theorem lookup_p040 : primitive "%Integer.less" = some Primitive.p040 := rfl
private theorem lookup_p041 : primitive "%Integer.lessOrEqual" = some Primitive.p041 := rfl
private theorem lookup_p042 : primitive "%Integer.mod" = some Primitive.p042 := rfl
private theorem lookup_p043 : primitive "%Integer.multiply" = some Primitive.p043 := rfl
private theorem lookup_p044 : primitive "%Integer.negate" = some Primitive.p044 := rfl
private theorem lookup_p045 : primitive "%Integer.subtract" = some Primitive.p045 := rfl
private theorem lookup_p046 : primitive "%Integer16.add" = some Primitive.p046 := rfl
private theorem lookup_p047 : primitive "%Integer16.div" = some Primitive.p047 := rfl
private theorem lookup_p048 : primitive "%Integer16.greater" = some Primitive.p048 := rfl
private theorem lookup_p049 : primitive "%Integer16.greaterOrEqual" = some Primitive.p049 := rfl
private theorem lookup_p050 : primitive "%Integer16.less" = some Primitive.p050 := rfl
private theorem lookup_p051 : primitive "%Integer16.lessOrEqual" = some Primitive.p051 := rfl
private theorem lookup_p052 : primitive "%Integer16.mod" = some Primitive.p052 := rfl
private theorem lookup_p053 : primitive "%Integer16.multiply" = some Primitive.p053 := rfl
private theorem lookup_p054 : primitive "%Integer16.negate" = some Primitive.p054 := rfl
private theorem lookup_p055 : primitive "%Integer16.subtract" = some Primitive.p055 := rfl
private theorem lookup_p056 : primitive "%Integer32.add" = some Primitive.p056 := rfl
private theorem lookup_p057 : primitive "%Integer32.div" = some Primitive.p057 := rfl
private theorem lookup_p058 : primitive "%Integer32.greater" = some Primitive.p058 := rfl
private theorem lookup_p059 : primitive "%Integer32.greaterOrEqual" = some Primitive.p059 := rfl
private theorem lookup_p060 : primitive "%Integer32.less" = some Primitive.p060 := rfl
private theorem lookup_p061 : primitive "%Integer32.lessOrEqual" = some Primitive.p061 := rfl
private theorem lookup_p062 : primitive "%Integer32.mod" = some Primitive.p062 := rfl
private theorem lookup_p063 : primitive "%Integer32.multiply" = some Primitive.p063 := rfl
private theorem lookup_p064 : primitive "%Integer32.negate" = some Primitive.p064 := rfl
private theorem lookup_p065 : primitive "%Integer32.subtract" = some Primitive.p065 := rfl
private theorem lookup_p066 : primitive "%Integer8.add" = some Primitive.p066 := rfl
private theorem lookup_p067 : primitive "%Integer8.div" = some Primitive.p067 := rfl
private theorem lookup_p068 : primitive "%Integer8.greater" = some Primitive.p068 := rfl
private theorem lookup_p069 : primitive "%Integer8.greaterOrEqual" = some Primitive.p069 := rfl
private theorem lookup_p070 : primitive "%Integer8.less" = some Primitive.p070 := rfl
private theorem lookup_p071 : primitive "%Integer8.lessOrEqual" = some Primitive.p071 := rfl
private theorem lookup_p072 : primitive "%Integer8.mod" = some Primitive.p072 := rfl
private theorem lookup_p073 : primitive "%Integer8.multiply" = some Primitive.p073 := rfl
private theorem lookup_p074 : primitive "%Integer8.negate" = some Primitive.p074 := rfl
private theorem lookup_p075 : primitive "%Integer8.subtract" = some Primitive.p075 := rfl
private theorem lookup_p076 : primitive "%Map.replaceValues" = some Primitive.p076 := rfl
private theorem lookup_p077 : primitive "%String.add" = some Primitive.p077 := rfl
private theorem lookup_p078 : primitive "%String.greater" = some Primitive.p078 := rfl
private theorem lookup_p079 : primitive "%String.greaterOrEqual" = some Primitive.p079 := rfl
private theorem lookup_p080 : primitive "%String.less" = some Primitive.p080 := rfl
private theorem lookup_p081 : primitive "%String.lessOrEqual" = some Primitive.p081 := rfl
private theorem lookup_p082 : primitive "%UnsignedInteger16.add" = some Primitive.p082 := rfl
private theorem lookup_p083 : primitive "%UnsignedInteger16.div" = some Primitive.p083 := rfl
private theorem lookup_p084 : primitive "%UnsignedInteger16.greater" = some Primitive.p084 := rfl
private theorem lookup_p085 : primitive "%UnsignedInteger16.greaterOrEqual" = some Primitive.p085 := rfl
private theorem lookup_p086 : primitive "%UnsignedInteger16.less" = some Primitive.p086 := rfl
private theorem lookup_p087 : primitive "%UnsignedInteger16.lessOrEqual" = some Primitive.p087 := rfl
private theorem lookup_p088 : primitive "%UnsignedInteger16.mod" = some Primitive.p088 := rfl
private theorem lookup_p089 : primitive "%UnsignedInteger16.multiply" = some Primitive.p089 := rfl
private theorem lookup_p090 : primitive "%UnsignedInteger16.subtract" = some Primitive.p090 := rfl
private theorem lookup_p091 : primitive "%UnsignedInteger32.add" = some Primitive.p091 := rfl
private theorem lookup_p092 : primitive "%UnsignedInteger32.div" = some Primitive.p092 := rfl
private theorem lookup_p093 : primitive "%UnsignedInteger32.greater" = some Primitive.p093 := rfl
private theorem lookup_p094 : primitive "%UnsignedInteger32.greaterOrEqual" = some Primitive.p094 := rfl
private theorem lookup_p095 : primitive "%UnsignedInteger32.less" = some Primitive.p095 := rfl
private theorem lookup_p096 : primitive "%UnsignedInteger32.lessOrEqual" = some Primitive.p096 := rfl
private theorem lookup_p097 : primitive "%UnsignedInteger32.mod" = some Primitive.p097 := rfl
private theorem lookup_p098 : primitive "%UnsignedInteger32.multiply" = some Primitive.p098 := rfl
private theorem lookup_p099 : primitive "%UnsignedInteger32.subtract" = some Primitive.p099 := rfl
private theorem lookup_p100 : primitive "%UnsignedInteger64.add" = some Primitive.p100 := rfl
private theorem lookup_p101 : primitive "%UnsignedInteger64.div" = some Primitive.p101 := rfl
private theorem lookup_p102 : primitive "%UnsignedInteger64.greater" = some Primitive.p102 := rfl
private theorem lookup_p103 : primitive "%UnsignedInteger64.greaterOrEqual" = some Primitive.p103 := rfl
private theorem lookup_p104 : primitive "%UnsignedInteger64.less" = some Primitive.p104 := rfl
private theorem lookup_p105 : primitive "%UnsignedInteger64.lessOrEqual" = some Primitive.p105 := rfl
private theorem lookup_p106 : primitive "%UnsignedInteger64.mod" = some Primitive.p106 := rfl
private theorem lookup_p107 : primitive "%UnsignedInteger64.multiply" = some Primitive.p107 := rfl
private theorem lookup_p108 : primitive "%UnsignedInteger64.subtract" = some Primitive.p108 := rfl
private theorem lookup_p109 : primitive "%eq" = some Primitive.p109 := rfl
private theorem lookup_p110 : primitive "%ne" = some Primitive.p110 := rfl
private theorem lookup_p111 : primitive "Byte.bitwiseAnd" = some Primitive.p111 := rfl
private theorem lookup_p112 : primitive "Byte.bitwiseExclusiveOr" = some Primitive.p112 := rfl
private theorem lookup_p113 : primitive "Byte.bitwiseNot" = some Primitive.p113 := rfl
private theorem lookup_p114 : primitive "Byte.bitwiseOr" = some Primitive.p114 := rfl
private theorem lookup_p115 : primitive "Byte.fromInteger" = some Primitive.p115 := rfl
private theorem lookup_p116 : primitive "Byte.shiftLeft" = some Primitive.p116 := rfl
private theorem lookup_p117 : primitive "Byte.shiftRight" = some Primitive.p117 := rfl
private theorem lookup_p118 : primitive "Byte.toInteger" = some Primitive.p118 := rfl
private theorem lookup_p119 : primitive "Byte.toString" = some Primitive.p119 := rfl
private theorem lookup_p120 : primitive "Bytes.concatenate" = some Primitive.p120 := rfl
private theorem lookup_p121 : primitive "Bytes.empty" = some Primitive.p121 := rfl
private theorem lookup_p122 : primitive "Bytes.fromBinary" = some Primitive.p122 := rfl
private theorem lookup_p123 : primitive "Bytes.fromHex" = some Primitive.p123 := rfl
private theorem lookup_p124 : primitive "Bytes.fromIntegers" = some Primitive.p124 := rfl
private theorem lookup_p125 : primitive "Bytes.fromList" = some Primitive.p125 := rfl
private theorem lookup_p126 : primitive "Bytes.fromSigned" = some Primitive.p126 := rfl
private theorem lookup_p127 : primitive "Bytes.fromUnsigned" = some Primitive.p127 := rfl
private theorem lookup_p128 : primitive "Bytes.get" = some Primitive.p128 := rfl
private theorem lookup_p129 : primitive "Bytes.length" = some Primitive.p129 := rfl
private theorem lookup_p130 : primitive "Bytes.readSigned" = some Primitive.p130 := rfl
private theorem lookup_p131 : primitive "Bytes.readUnsigned" = some Primitive.p131 := rfl
private theorem lookup_p132 : primitive "Bytes.slice" = some Primitive.p132 := rfl
private theorem lookup_p133 : primitive "Bytes.toBinary" = some Primitive.p133 := rfl
private theorem lookup_p134 : primitive "Bytes.toHex" = some Primitive.p134 := rfl
private theorem lookup_p135 : primitive "Bytes.toList" = some Primitive.p135 := rfl
private theorem lookup_p136 : primitive "Character.fromInteger" = some Primitive.p136 := rfl
private theorem lookup_p137 : primitive "Character.isASCIIDigit" = some Primitive.p137 := rfl
private theorem lookup_p138 : primitive "Character.isASCIIWhitespace" = some Primitive.p138 := rfl
private theorem lookup_p139 : primitive "Character.isAlphabetic" = some Primitive.p139 := rfl
private theorem lookup_p140 : primitive "Character.isLowercase" = some Primitive.p140 := rfl
private theorem lookup_p141 : primitive "Character.isNumeric" = some Primitive.p141 := rfl
private theorem lookup_p142 : primitive "Character.isUppercase" = some Primitive.p142 := rfl
private theorem lookup_p143 : primitive "Character.isWhitespace" = some Primitive.p143 := rfl
private theorem lookup_p144 : primitive "Character.toInteger" = some Primitive.p144 := rfl
private theorem lookup_p145 : primitive "Character.toLowercase" = some Primitive.p145 := rfl
private theorem lookup_p146 : primitive "Character.toString" = some Primitive.p146 := rfl
private theorem lookup_p147 : primitive "Character.toUppercase" = some Primitive.p147 := rfl
private theorem lookup_p148 : primitive "Decimal.absolute" = some Primitive.p148 := rfl
private theorem lookup_p149 : primitive "Decimal.fromFloat" = some Primitive.p149 := rfl
private theorem lookup_p150 : primitive "Decimal.fromInteger" = some Primitive.p150 := rfl
private theorem lookup_p151 : primitive "Decimal.parse" = some Primitive.p151 := rfl
private theorem lookup_p152 : primitive "Decimal.round" = some Primitive.p152 := rfl
private theorem lookup_p153 : primitive "Decimal.toFloat" = some Primitive.p153 := rfl
private theorem lookup_p154 : primitive "Decimal.toString" = some Primitive.p154 := rfl
private theorem lookup_p155 : primitive "Decimal.truncate" = some Primitive.p155 := rfl
private theorem lookup_p156 : primitive "Example.pathBases" = some Primitive.p156 := rfl
private theorem lookup_p157 : primitive "File.appendBytesIn" = some Primitive.p157 := rfl
private theorem lookup_p158 : primitive "File.appendTextIn" = some Primitive.p158 := rfl
private theorem lookup_p159 : primitive "File.readBytesIn" = some Primitive.p159 := rfl
private theorem lookup_p160 : primitive "File.readText" = some Primitive.p160 := rfl
private theorem lookup_p161 : primitive "File.readTextIn" = some Primitive.p161 := rfl
private theorem lookup_p162 : primitive "File.writeBytesIn" = some Primitive.p162 := rfl
private theorem lookup_p163 : primitive "File.writeTextIn" = some Primitive.p163 := rfl
private theorem lookup_p164 : primitive "Float.absolute" = some Primitive.p164 := rfl
private theorem lookup_p165 : primitive "Float.ceiling" = some Primitive.p165 := rfl
private theorem lookup_p166 : primitive "Float.floor" = some Primitive.p166 := rfl
private theorem lookup_p167 : primitive "Float.isNaN" = some Primitive.p167 := rfl
private theorem lookup_p168 : primitive "Float.parse" = some Primitive.p168 := rfl
private theorem lookup_p169 : primitive "Float.round" = some Primitive.p169 := rfl
private theorem lookup_p170 : primitive "Float.squareRoot" = some Primitive.p170 := rfl
private theorem lookup_p171 : primitive "Float.toString" = some Primitive.p171 := rfl
private theorem lookup_p172 : primitive "Float.truncate" = some Primitive.p172 := rfl
private theorem lookup_p173 : primitive "Float32.absolute" = some Primitive.p173 := rfl
private theorem lookup_p174 : primitive "Float32.ceiling" = some Primitive.p174 := rfl
private theorem lookup_p175 : primitive "Float32.floor" = some Primitive.p175 := rfl
private theorem lookup_p176 : primitive "Float32.fromFloat" = some Primitive.p176 := rfl
private theorem lookup_p177 : primitive "Float32.isInfinite" = some Primitive.p177 := rfl
private theorem lookup_p178 : primitive "Float32.isNaN" = some Primitive.p178 := rfl
private theorem lookup_p179 : primitive "Float32.parse" = some Primitive.p179 := rfl
private theorem lookup_p180 : primitive "Float32.round" = some Primitive.p180 := rfl
private theorem lookup_p181 : primitive "Float32.squareRoot" = some Primitive.p181 := rfl
private theorem lookup_p182 : primitive "Float32.toFloat" = some Primitive.p182 := rfl
private theorem lookup_p183 : primitive "Float32.toString" = some Primitive.p183 := rfl
private theorem lookup_p184 : primitive "Float32.truncate" = some Primitive.p184 := rfl
private theorem lookup_p185 : primitive "Http.checkRequestIn" = some Primitive.p185 := rfl
private theorem lookup_p186 : primitive "Http.requestInValue" = some Primitive.p186 := rfl
private theorem lookup_p187 : primitive "Http.sendIn" = some Primitive.p187 := rfl
private theorem lookup_p188 : primitive "Http.widenRequestIn" = some Primitive.p188 := rfl
private theorem lookup_p189 : primitive "Integer.absolute" = some Primitive.p189 := rfl
private theorem lookup_p190 : primitive "Integer.bitwiseAnd" = some Primitive.p190 := rfl
private theorem lookup_p191 : primitive "Integer.bitwiseExclusiveOr" = some Primitive.p191 := rfl
private theorem lookup_p192 : primitive "Integer.bitwiseNot" = some Primitive.p192 := rfl
private theorem lookup_p193 : primitive "Integer.bitwiseOr" = some Primitive.p193 := rfl
private theorem lookup_p194 : primitive "Integer.floorDivide" = some Primitive.p194 := rfl
private theorem lookup_p195 : primitive "Integer.floorModulo" = some Primitive.p195 := rfl
private theorem lookup_p196 : primitive "Integer.maximum" = some Primitive.p196 := rfl
private theorem lookup_p197 : primitive "Integer.minimum" = some Primitive.p197 := rfl
private theorem lookup_p198 : primitive "Integer.parse" = some Primitive.p198 := rfl
private theorem lookup_p199 : primitive "Integer.shiftLeft" = some Primitive.p199 := rfl
private theorem lookup_p200 : primitive "Integer.shiftRight" = some Primitive.p200 := rfl
private theorem lookup_p201 : primitive "Integer.shiftRightUnsigned" = some Primitive.p201 := rfl
private theorem lookup_p202 : primitive "Integer.toFloat" = some Primitive.p202 := rfl
private theorem lookup_p203 : primitive "Integer.toString" = some Primitive.p203 := rfl
private theorem lookup_p204 : primitive "Integer16.absolute" = some Primitive.p204 := rfl
private theorem lookup_p205 : primitive "Integer16.bitwiseAnd" = some Primitive.p205 := rfl
private theorem lookup_p206 : primitive "Integer16.bitwiseExclusiveOr" = some Primitive.p206 := rfl
private theorem lookup_p207 : primitive "Integer16.bitwiseNot" = some Primitive.p207 := rfl
private theorem lookup_p208 : primitive "Integer16.bitwiseOr" = some Primitive.p208 := rfl
private theorem lookup_p209 : primitive "Integer16.floorDivide" = some Primitive.p209 := rfl
private theorem lookup_p210 : primitive "Integer16.floorModulo" = some Primitive.p210 := rfl
private theorem lookup_p211 : primitive "Integer16.fromInteger" = some Primitive.p211 := rfl
private theorem lookup_p212 : primitive "Integer16.maximum" = some Primitive.p212 := rfl
private theorem lookup_p213 : primitive "Integer16.minimum" = some Primitive.p213 := rfl
private theorem lookup_p214 : primitive "Integer16.parse" = some Primitive.p214 := rfl
private theorem lookup_p215 : primitive "Integer16.shiftLeft" = some Primitive.p215 := rfl
private theorem lookup_p216 : primitive "Integer16.shiftRight" = some Primitive.p216 := rfl
private theorem lookup_p217 : primitive "Integer16.shiftRightUnsigned" = some Primitive.p217 := rfl
private theorem lookup_p218 : primitive "Integer16.toFloat" = some Primitive.p218 := rfl
private theorem lookup_p219 : primitive "Integer16.toInteger" = some Primitive.p219 := rfl
private theorem lookup_p220 : primitive "Integer16.toString" = some Primitive.p220 := rfl
private theorem lookup_p221 : primitive "Integer32.absolute" = some Primitive.p221 := rfl
private theorem lookup_p222 : primitive "Integer32.bitwiseAnd" = some Primitive.p222 := rfl
private theorem lookup_p223 : primitive "Integer32.bitwiseExclusiveOr" = some Primitive.p223 := rfl
private theorem lookup_p224 : primitive "Integer32.bitwiseNot" = some Primitive.p224 := rfl
private theorem lookup_p225 : primitive "Integer32.bitwiseOr" = some Primitive.p225 := rfl
private theorem lookup_p226 : primitive "Integer32.floorDivide" = some Primitive.p226 := rfl
private theorem lookup_p227 : primitive "Integer32.floorModulo" = some Primitive.p227 := rfl
private theorem lookup_p228 : primitive "Integer32.fromInteger" = some Primitive.p228 := rfl
private theorem lookup_p229 : primitive "Integer32.maximum" = some Primitive.p229 := rfl
private theorem lookup_p230 : primitive "Integer32.minimum" = some Primitive.p230 := rfl
private theorem lookup_p231 : primitive "Integer32.parse" = some Primitive.p231 := rfl
private theorem lookup_p232 : primitive "Integer32.shiftLeft" = some Primitive.p232 := rfl
private theorem lookup_p233 : primitive "Integer32.shiftRight" = some Primitive.p233 := rfl
private theorem lookup_p234 : primitive "Integer32.shiftRightUnsigned" = some Primitive.p234 := rfl
private theorem lookup_p235 : primitive "Integer32.toFloat" = some Primitive.p235 := rfl
private theorem lookup_p236 : primitive "Integer32.toInteger" = some Primitive.p236 := rfl
private theorem lookup_p237 : primitive "Integer32.toString" = some Primitive.p237 := rfl
private theorem lookup_p238 : primitive "Integer8.absolute" = some Primitive.p238 := rfl
private theorem lookup_p239 : primitive "Integer8.bitwiseAnd" = some Primitive.p239 := rfl
private theorem lookup_p240 : primitive "Integer8.bitwiseExclusiveOr" = some Primitive.p240 := rfl
private theorem lookup_p241 : primitive "Integer8.bitwiseNot" = some Primitive.p241 := rfl
private theorem lookup_p242 : primitive "Integer8.bitwiseOr" = some Primitive.p242 := rfl
private theorem lookup_p243 : primitive "Integer8.floorDivide" = some Primitive.p243 := rfl
private theorem lookup_p244 : primitive "Integer8.floorModulo" = some Primitive.p244 := rfl
private theorem lookup_p245 : primitive "Integer8.fromInteger" = some Primitive.p245 := rfl
private theorem lookup_p246 : primitive "Integer8.maximum" = some Primitive.p246 := rfl
private theorem lookup_p247 : primitive "Integer8.minimum" = some Primitive.p247 := rfl
private theorem lookup_p248 : primitive "Integer8.parse" = some Primitive.p248 := rfl
private theorem lookup_p249 : primitive "Integer8.shiftLeft" = some Primitive.p249 := rfl
private theorem lookup_p250 : primitive "Integer8.shiftRight" = some Primitive.p250 := rfl
private theorem lookup_p251 : primitive "Integer8.shiftRightUnsigned" = some Primitive.p251 := rfl
private theorem lookup_p252 : primitive "Integer8.toFloat" = some Primitive.p252 := rfl
private theorem lookup_p253 : primitive "Integer8.toInteger" = some Primitive.p253 := rfl
private theorem lookup_p254 : primitive "Integer8.toString" = some Primitive.p254 := rfl
private theorem lookup_p255 : primitive "List.append" = some Primitive.p255 := rfl
private theorem lookup_p256 : primitive "List.concatenate" = some Primitive.p256 := rfl
private theorem lookup_p257 : primitive "List.contains" = some Primitive.p257 := rfl
private theorem lookup_p258 : primitive "List.drop" = some Primitive.p258 := rfl
private theorem lookup_p259 : primitive "List.get" = some Primitive.p259 := rfl
private theorem lookup_p260 : primitive "List.head" = some Primitive.p260 := rfl
private theorem lookup_p261 : primitive "List.isEmpty" = some Primitive.p261 := rfl
private theorem lookup_p262 : primitive "List.length" = some Primitive.p262 := rfl
private theorem lookup_p263 : primitive "List.prepend" = some Primitive.p263 := rfl
private theorem lookup_p264 : primitive "List.range" = some Primitive.p264 := rfl
private theorem lookup_p265 : primitive "List.reverse" = some Primitive.p265 := rfl
private theorem lookup_p266 : primitive "List.sort" = some Primitive.p266 := rfl
private theorem lookup_p267 : primitive "List.tail" = some Primitive.p267 := rfl
private theorem lookup_p268 : primitive "List.take" = some Primitive.p268 := rfl
private theorem lookup_p269 : primitive "Map.contains" = some Primitive.p269 := rfl
private theorem lookup_p270 : primitive "Map.empty" = some Primitive.p270 := rfl
private theorem lookup_p271 : primitive "Map.fromList" = some Primitive.p271 := rfl
private theorem lookup_p272 : primitive "Map.get" = some Primitive.p272 := rfl
private theorem lookup_p273 : primitive "Map.keys" = some Primitive.p273 := rfl
private theorem lookup_p274 : primitive "Map.remove" = some Primitive.p274 := rfl
private theorem lookup_p275 : primitive "Map.set" = some Primitive.p275 := rfl
private theorem lookup_p276 : primitive "Map.size" = some Primitive.p276 := rfl
private theorem lookup_p277 : primitive "Map.toList" = some Primitive.p277 := rfl
private theorem lookup_p278 : primitive "Map.values" = some Primitive.p278 := rfl
private theorem lookup_p279 : primitive "Reference.get" = some Primitive.p279 := rfl
private theorem lookup_p280 : primitive "Reference.set" = some Primitive.p280 := rfl
private theorem lookup_p281 : primitive "Scope.checkPathIn" = some Primitive.p281 := rfl
private theorem lookup_p282 : primitive "Scope.pathInValue" = some Primitive.p282 := rfl
private theorem lookup_p283 : primitive "Scope.widenPathIn" = some Primitive.p283 := rfl
private theorem lookup_p284 : primitive "Set.add" = some Primitive.p284 := rfl
private theorem lookup_p285 : primitive "Set.contains" = some Primitive.p285 := rfl
private theorem lookup_p286 : primitive "Set.difference" = some Primitive.p286 := rfl
private theorem lookup_p287 : primitive "Set.empty" = some Primitive.p287 := rfl
private theorem lookup_p288 : primitive "Set.fromList" = some Primitive.p288 := rfl
private theorem lookup_p289 : primitive "Set.intersection" = some Primitive.p289 := rfl
private theorem lookup_p290 : primitive "Set.remove" = some Primitive.p290 := rfl
private theorem lookup_p291 : primitive "Set.size" = some Primitive.p291 := rfl
private theorem lookup_p292 : primitive "Set.toList" = some Primitive.p292 := rfl
private theorem lookup_p293 : primitive "Set.union" = some Primitive.p293 := rfl
private theorem lookup_p294 : primitive "String.byteIndexOf" = some Primitive.p294 := rfl
private theorem lookup_p295 : primitive "String.byteLength" = some Primitive.p295 := rfl
private theorem lookup_p296 : primitive "String.byteSlice" = some Primitive.p296 := rfl
private theorem lookup_p297 : primitive "String.characterAt" = some Primitive.p297 := rfl
private theorem lookup_p298 : primitive "String.characterCount" = some Primitive.p298 := rfl
private theorem lookup_p299 : primitive "String.characterSlice" = some Primitive.p299 := rfl
private theorem lookup_p300 : primitive "String.characters" = some Primitive.p300 := rfl
private theorem lookup_p301 : primitive "String.contains" = some Primitive.p301 := rfl
private theorem lookup_p302 : primitive "String.displayWidth" = some Primitive.p302 := rfl
private theorem lookup_p303 : primitive "String.displayWidthCJK" = some Primitive.p303 := rfl
private theorem lookup_p304 : primitive "String.displayWidthPadEnd" = some Primitive.p304 := rfl
private theorem lookup_p305 : primitive "String.displayWidthPadEndCJK" = some Primitive.p305 := rfl
private theorem lookup_p306 : primitive "String.displayWidthPadStart" = some Primitive.p306 := rfl
private theorem lookup_p307 : primitive "String.displayWidthPadStartCJK" = some Primitive.p307 := rfl
private theorem lookup_p308 : primitive "String.endsWith" = some Primitive.p308 := rfl
private theorem lookup_p309 : primitive "String.fromCharacters" = some Primitive.p309 := rfl
private theorem lookup_p310 : primitive "String.fromUTF8" = some Primitive.p310 := rfl
private theorem lookup_p311 : primitive "String.isEmpty" = some Primitive.p311 := rfl
private theorem lookup_p312 : primitive "String.join" = some Primitive.p312 := rfl
private theorem lookup_p313 : primitive "String.lines" = some Primitive.p313 := rfl
private theorem lookup_p314 : primitive "String.repeat" = some Primitive.p314 := rfl
private theorem lookup_p315 : primitive "String.replace" = some Primitive.p315 := rfl
private theorem lookup_p316 : primitive "String.split" = some Primitive.p316 := rfl
private theorem lookup_p317 : primitive "String.startsWith" = some Primitive.p317 := rfl
private theorem lookup_p318 : primitive "String.toLowercase" = some Primitive.p318 := rfl
private theorem lookup_p319 : primitive "String.toUTF8" = some Primitive.p319 := rfl
private theorem lookup_p320 : primitive "String.toUppercase" = some Primitive.p320 := rfl
private theorem lookup_p321 : primitive "String.trim" = some Primitive.p321 := rfl
private theorem lookup_p322 : primitive "UnsignedInteger16.absolute" = some Primitive.p322 := rfl
private theorem lookup_p323 : primitive "UnsignedInteger16.bitwiseAnd" = some Primitive.p323 := rfl
private theorem lookup_p324 : primitive "UnsignedInteger16.bitwiseExclusiveOr" = some Primitive.p324 := rfl
private theorem lookup_p325 : primitive "UnsignedInteger16.bitwiseNot" = some Primitive.p325 := rfl
private theorem lookup_p326 : primitive "UnsignedInteger16.bitwiseOr" = some Primitive.p326 := rfl
private theorem lookup_p327 : primitive "UnsignedInteger16.floorDivide" = some Primitive.p327 := rfl
private theorem lookup_p328 : primitive "UnsignedInteger16.floorModulo" = some Primitive.p328 := rfl
private theorem lookup_p329 : primitive "UnsignedInteger16.fromInteger" = some Primitive.p329 := rfl
private theorem lookup_p330 : primitive "UnsignedInteger16.maximum" = some Primitive.p330 := rfl
private theorem lookup_p331 : primitive "UnsignedInteger16.minimum" = some Primitive.p331 := rfl
private theorem lookup_p332 : primitive "UnsignedInteger16.parse" = some Primitive.p332 := rfl
private theorem lookup_p333 : primitive "UnsignedInteger16.shiftLeft" = some Primitive.p333 := rfl
private theorem lookup_p334 : primitive "UnsignedInteger16.shiftRight" = some Primitive.p334 := rfl
private theorem lookup_p335 : primitive "UnsignedInteger16.toFloat" = some Primitive.p335 := rfl
private theorem lookup_p336 : primitive "UnsignedInteger16.toInteger" = some Primitive.p336 := rfl
private theorem lookup_p337 : primitive "UnsignedInteger16.toString" = some Primitive.p337 := rfl
private theorem lookup_p338 : primitive "UnsignedInteger32.absolute" = some Primitive.p338 := rfl
private theorem lookup_p339 : primitive "UnsignedInteger32.bitwiseAnd" = some Primitive.p339 := rfl
private theorem lookup_p340 : primitive "UnsignedInteger32.bitwiseExclusiveOr" = some Primitive.p340 := rfl
private theorem lookup_p341 : primitive "UnsignedInteger32.bitwiseNot" = some Primitive.p341 := rfl
private theorem lookup_p342 : primitive "UnsignedInteger32.bitwiseOr" = some Primitive.p342 := rfl
private theorem lookup_p343 : primitive "UnsignedInteger32.floorDivide" = some Primitive.p343 := rfl
private theorem lookup_p344 : primitive "UnsignedInteger32.floorModulo" = some Primitive.p344 := rfl
private theorem lookup_p345 : primitive "UnsignedInteger32.fromInteger" = some Primitive.p345 := rfl
private theorem lookup_p346 : primitive "UnsignedInteger32.maximum" = some Primitive.p346 := rfl
private theorem lookup_p347 : primitive "UnsignedInteger32.minimum" = some Primitive.p347 := rfl
private theorem lookup_p348 : primitive "UnsignedInteger32.parse" = some Primitive.p348 := rfl
private theorem lookup_p349 : primitive "UnsignedInteger32.shiftLeft" = some Primitive.p349 := rfl
private theorem lookup_p350 : primitive "UnsignedInteger32.shiftRight" = some Primitive.p350 := rfl
private theorem lookup_p351 : primitive "UnsignedInteger32.toFloat" = some Primitive.p351 := rfl
private theorem lookup_p352 : primitive "UnsignedInteger32.toInteger" = some Primitive.p352 := rfl
private theorem lookup_p353 : primitive "UnsignedInteger32.toString" = some Primitive.p353 := rfl
private theorem lookup_p354 : primitive "UnsignedInteger64.absolute" = some Primitive.p354 := rfl
private theorem lookup_p355 : primitive "UnsignedInteger64.bitwiseAnd" = some Primitive.p355 := rfl
private theorem lookup_p356 : primitive "UnsignedInteger64.bitwiseExclusiveOr" = some Primitive.p356 := rfl
private theorem lookup_p357 : primitive "UnsignedInteger64.bitwiseNot" = some Primitive.p357 := rfl
private theorem lookup_p358 : primitive "UnsignedInteger64.bitwiseOr" = some Primitive.p358 := rfl
private theorem lookup_p359 : primitive "UnsignedInteger64.floorDivide" = some Primitive.p359 := rfl
private theorem lookup_p360 : primitive "UnsignedInteger64.floorModulo" = some Primitive.p360 := rfl
private theorem lookup_p361 : primitive "UnsignedInteger64.fromDecimal" = some Primitive.p361 := rfl
private theorem lookup_p362 : primitive "UnsignedInteger64.fromInteger" = some Primitive.p362 := rfl
private theorem lookup_p363 : primitive "UnsignedInteger64.maximum" = some Primitive.p363 := rfl
private theorem lookup_p364 : primitive "UnsignedInteger64.minimum" = some Primitive.p364 := rfl
private theorem lookup_p365 : primitive "UnsignedInteger64.parse" = some Primitive.p365 := rfl
private theorem lookup_p366 : primitive "UnsignedInteger64.shiftLeft" = some Primitive.p366 := rfl
private theorem lookup_p367 : primitive "UnsignedInteger64.shiftRight" = some Primitive.p367 := rfl
private theorem lookup_p368 : primitive "UnsignedInteger64.toDecimal" = some Primitive.p368 := rfl
private theorem lookup_p369 : primitive "UnsignedInteger64.toFloat" = some Primitive.p369 := rfl
private theorem lookup_p370 : primitive "UnsignedInteger64.toInteger" = some Primitive.p370 := rfl
private theorem lookup_p371 : primitive "UnsignedInteger64.toString" = some Primitive.p371 := rfl
private theorem lookup_p372 : primitive "exit" = some Primitive.p372 := rfl
private theorem lookup_p373 : primitive "print" = some Primitive.p373 := rfl
private theorem lookup_p374 : primitive "Lazy.force" = some Primitive.p374 := rfl
private theorem lookup_p375 : primitive "Reference.new" = some Primitive.p375 := rfl
private theorem lookup_p376 : primitive "Reference.update" = some Primitive.p376 := rfl
private theorem lookup_p377 : primitive "%List.getFront" = some Primitive.p377 := rfl

/-- 任意の台帳行を同じ合成表でlookupできる。 -/
private theorem lookup_p378 : primitive "Scope.pathMatches" = some Primitive.p378 := rfl
private theorem lookup_p379 : primitive "Scope.hostMatches" = some Primitive.p379 := rfl
private theorem lookup_p380 : primitive "String.charactersIn" = some Primitive.p380 := rfl
private theorem lookup_p381 : primitive "Float.isFinite" = some Primitive.p381 := rfl
private theorem lookup_p382 : primitive "Float.isInfinite" = some Primitive.p382 := rfl
private theorem lookup_p383 : primitive "Float.isPositiveInfinity" = some Primitive.p383 := rfl
private theorem lookup_p384 : primitive "Float.isNegativeInfinity" = some Primitive.p384 := rfl
private theorem lookup_p385 : primitive "Float.isPositiveZero" = some Primitive.p385 := rfl
private theorem lookup_p386 : primitive "Float.isNegativeZero" = some Primitive.p386 := rfl
private theorem lookup_p387 : primitive "Float32.isFinite" = some Primitive.p387 := rfl
private theorem lookup_p388 : primitive "Float32.isPositiveInfinity" = some Primitive.p388 := rfl
private theorem lookup_p389 : primitive "Float32.isNegativeInfinity" = some Primitive.p389 := rfl
private theorem lookup_p390 : primitive "Float32.isPositiveZero" = some Primitive.p390 := rfl
private theorem lookup_p391 : primitive "Float32.isNegativeZero" = some Primitive.p391 := rfl
private theorem lookup_p392 : primitive "Refinement.check" = some Primitive.p392 := rfl

theorem primitive_lookup (row : Primitive) : primitive row.name = some row := by
  cases row with
  | p001 => exact lookup_p001
  | p002 => exact lookup_p002
  | p003 => exact lookup_p003
  | p004 => exact lookup_p004
  | p005 => exact lookup_p005
  | p006 => exact lookup_p006
  | p007 => exact lookup_p007
  | p008 => exact lookup_p008
  | p009 => exact lookup_p009
  | p010 => exact lookup_p010
  | p011 => exact lookup_p011
  | p012 => exact lookup_p012
  | p013 => exact lookup_p013
  | p014 => exact lookup_p014
  | p015 => exact lookup_p015
  | p016 => exact lookup_p016
  | p017 => exact lookup_p017
  | p018 => exact lookup_p018
  | p019 => exact lookup_p019
  | p020 => exact lookup_p020
  | p021 => exact lookup_p021
  | p022 => exact lookup_p022
  | p023 => exact lookup_p023
  | p024 => exact lookup_p024
  | p025 => exact lookup_p025
  | p026 => exact lookup_p026
  | p027 => exact lookup_p027
  | p028 => exact lookup_p028
  | p029 => exact lookup_p029
  | p030 => exact lookup_p030
  | p031 => exact lookup_p031
  | p032 => exact lookup_p032
  | p033 => exact lookup_p033
  | p034 => exact lookup_p034
  | p035 => exact lookup_p035
  | p036 => exact lookup_p036
  | p037 => exact lookup_p037
  | p038 => exact lookup_p038
  | p039 => exact lookup_p039
  | p040 => exact lookup_p040
  | p041 => exact lookup_p041
  | p042 => exact lookup_p042
  | p043 => exact lookup_p043
  | p044 => exact lookup_p044
  | p045 => exact lookup_p045
  | p046 => exact lookup_p046
  | p047 => exact lookup_p047
  | p048 => exact lookup_p048
  | p049 => exact lookup_p049
  | p050 => exact lookup_p050
  | p051 => exact lookup_p051
  | p052 => exact lookup_p052
  | p053 => exact lookup_p053
  | p054 => exact lookup_p054
  | p055 => exact lookup_p055
  | p056 => exact lookup_p056
  | p057 => exact lookup_p057
  | p058 => exact lookup_p058
  | p059 => exact lookup_p059
  | p060 => exact lookup_p060
  | p061 => exact lookup_p061
  | p062 => exact lookup_p062
  | p063 => exact lookup_p063
  | p064 => exact lookup_p064
  | p065 => exact lookup_p065
  | p066 => exact lookup_p066
  | p067 => exact lookup_p067
  | p068 => exact lookup_p068
  | p069 => exact lookup_p069
  | p070 => exact lookup_p070
  | p071 => exact lookup_p071
  | p072 => exact lookup_p072
  | p073 => exact lookup_p073
  | p074 => exact lookup_p074
  | p075 => exact lookup_p075
  | p076 => exact lookup_p076
  | p077 => exact lookup_p077
  | p078 => exact lookup_p078
  | p079 => exact lookup_p079
  | p080 => exact lookup_p080
  | p081 => exact lookup_p081
  | p082 => exact lookup_p082
  | p083 => exact lookup_p083
  | p084 => exact lookup_p084
  | p085 => exact lookup_p085
  | p086 => exact lookup_p086
  | p087 => exact lookup_p087
  | p088 => exact lookup_p088
  | p089 => exact lookup_p089
  | p090 => exact lookup_p090
  | p091 => exact lookup_p091
  | p092 => exact lookup_p092
  | p093 => exact lookup_p093
  | p094 => exact lookup_p094
  | p095 => exact lookup_p095
  | p096 => exact lookup_p096
  | p097 => exact lookup_p097
  | p098 => exact lookup_p098
  | p099 => exact lookup_p099
  | p100 => exact lookup_p100
  | p101 => exact lookup_p101
  | p102 => exact lookup_p102
  | p103 => exact lookup_p103
  | p104 => exact lookup_p104
  | p105 => exact lookup_p105
  | p106 => exact lookup_p106
  | p107 => exact lookup_p107
  | p108 => exact lookup_p108
  | p109 => exact lookup_p109
  | p110 => exact lookup_p110
  | p111 => exact lookup_p111
  | p112 => exact lookup_p112
  | p113 => exact lookup_p113
  | p114 => exact lookup_p114
  | p115 => exact lookup_p115
  | p116 => exact lookup_p116
  | p117 => exact lookup_p117
  | p118 => exact lookup_p118
  | p119 => exact lookup_p119
  | p120 => exact lookup_p120
  | p121 => exact lookup_p121
  | p122 => exact lookup_p122
  | p123 => exact lookup_p123
  | p124 => exact lookup_p124
  | p125 => exact lookup_p125
  | p126 => exact lookup_p126
  | p127 => exact lookup_p127
  | p128 => exact lookup_p128
  | p129 => exact lookup_p129
  | p130 => exact lookup_p130
  | p131 => exact lookup_p131
  | p132 => exact lookup_p132
  | p133 => exact lookup_p133
  | p134 => exact lookup_p134
  | p135 => exact lookup_p135
  | p136 => exact lookup_p136
  | p137 => exact lookup_p137
  | p138 => exact lookup_p138
  | p139 => exact lookup_p139
  | p140 => exact lookup_p140
  | p141 => exact lookup_p141
  | p142 => exact lookup_p142
  | p143 => exact lookup_p143
  | p144 => exact lookup_p144
  | p145 => exact lookup_p145
  | p146 => exact lookup_p146
  | p147 => exact lookup_p147
  | p148 => exact lookup_p148
  | p149 => exact lookup_p149
  | p150 => exact lookup_p150
  | p151 => exact lookup_p151
  | p152 => exact lookup_p152
  | p153 => exact lookup_p153
  | p154 => exact lookup_p154
  | p155 => exact lookup_p155
  | p156 => exact lookup_p156
  | p157 => exact lookup_p157
  | p158 => exact lookup_p158
  | p159 => exact lookup_p159
  | p160 => exact lookup_p160
  | p161 => exact lookup_p161
  | p162 => exact lookup_p162
  | p163 => exact lookup_p163
  | p164 => exact lookup_p164
  | p165 => exact lookup_p165
  | p166 => exact lookup_p166
  | p167 => exact lookup_p167
  | p168 => exact lookup_p168
  | p169 => exact lookup_p169
  | p170 => exact lookup_p170
  | p171 => exact lookup_p171
  | p172 => exact lookup_p172
  | p173 => exact lookup_p173
  | p174 => exact lookup_p174
  | p175 => exact lookup_p175
  | p176 => exact lookup_p176
  | p177 => exact lookup_p177
  | p178 => exact lookup_p178
  | p179 => exact lookup_p179
  | p180 => exact lookup_p180
  | p181 => exact lookup_p181
  | p182 => exact lookup_p182
  | p183 => exact lookup_p183
  | p184 => exact lookup_p184
  | p185 => exact lookup_p185
  | p186 => exact lookup_p186
  | p187 => exact lookup_p187
  | p188 => exact lookup_p188
  | p189 => exact lookup_p189
  | p190 => exact lookup_p190
  | p191 => exact lookup_p191
  | p192 => exact lookup_p192
  | p193 => exact lookup_p193
  | p194 => exact lookup_p194
  | p195 => exact lookup_p195
  | p196 => exact lookup_p196
  | p197 => exact lookup_p197
  | p198 => exact lookup_p198
  | p199 => exact lookup_p199
  | p200 => exact lookup_p200
  | p201 => exact lookup_p201
  | p202 => exact lookup_p202
  | p203 => exact lookup_p203
  | p204 => exact lookup_p204
  | p205 => exact lookup_p205
  | p206 => exact lookup_p206
  | p207 => exact lookup_p207
  | p208 => exact lookup_p208
  | p209 => exact lookup_p209
  | p210 => exact lookup_p210
  | p211 => exact lookup_p211
  | p212 => exact lookup_p212
  | p213 => exact lookup_p213
  | p214 => exact lookup_p214
  | p215 => exact lookup_p215
  | p216 => exact lookup_p216
  | p217 => exact lookup_p217
  | p218 => exact lookup_p218
  | p219 => exact lookup_p219
  | p220 => exact lookup_p220
  | p221 => exact lookup_p221
  | p222 => exact lookup_p222
  | p223 => exact lookup_p223
  | p224 => exact lookup_p224
  | p225 => exact lookup_p225
  | p226 => exact lookup_p226
  | p227 => exact lookup_p227
  | p228 => exact lookup_p228
  | p229 => exact lookup_p229
  | p230 => exact lookup_p230
  | p231 => exact lookup_p231
  | p232 => exact lookup_p232
  | p233 => exact lookup_p233
  | p234 => exact lookup_p234
  | p235 => exact lookup_p235
  | p236 => exact lookup_p236
  | p237 => exact lookup_p237
  | p238 => exact lookup_p238
  | p239 => exact lookup_p239
  | p240 => exact lookup_p240
  | p241 => exact lookup_p241
  | p242 => exact lookup_p242
  | p243 => exact lookup_p243
  | p244 => exact lookup_p244
  | p245 => exact lookup_p245
  | p246 => exact lookup_p246
  | p247 => exact lookup_p247
  | p248 => exact lookup_p248
  | p249 => exact lookup_p249
  | p250 => exact lookup_p250
  | p251 => exact lookup_p251
  | p252 => exact lookup_p252
  | p253 => exact lookup_p253
  | p254 => exact lookup_p254
  | p255 => exact lookup_p255
  | p256 => exact lookup_p256
  | p257 => exact lookup_p257
  | p258 => exact lookup_p258
  | p259 => exact lookup_p259
  | p260 => exact lookup_p260
  | p261 => exact lookup_p261
  | p262 => exact lookup_p262
  | p263 => exact lookup_p263
  | p264 => exact lookup_p264
  | p265 => exact lookup_p265
  | p266 => exact lookup_p266
  | p267 => exact lookup_p267
  | p268 => exact lookup_p268
  | p269 => exact lookup_p269
  | p270 => exact lookup_p270
  | p271 => exact lookup_p271
  | p272 => exact lookup_p272
  | p273 => exact lookup_p273
  | p274 => exact lookup_p274
  | p275 => exact lookup_p275
  | p276 => exact lookup_p276
  | p277 => exact lookup_p277
  | p278 => exact lookup_p278
  | p279 => exact lookup_p279
  | p280 => exact lookup_p280
  | p281 => exact lookup_p281
  | p282 => exact lookup_p282
  | p283 => exact lookup_p283
  | p284 => exact lookup_p284
  | p285 => exact lookup_p285
  | p286 => exact lookup_p286
  | p287 => exact lookup_p287
  | p288 => exact lookup_p288
  | p289 => exact lookup_p289
  | p290 => exact lookup_p290
  | p291 => exact lookup_p291
  | p292 => exact lookup_p292
  | p293 => exact lookup_p293
  | p294 => exact lookup_p294
  | p295 => exact lookup_p295
  | p296 => exact lookup_p296
  | p297 => exact lookup_p297
  | p298 => exact lookup_p298
  | p299 => exact lookup_p299
  | p300 => exact lookup_p300
  | p301 => exact lookup_p301
  | p302 => exact lookup_p302
  | p303 => exact lookup_p303
  | p304 => exact lookup_p304
  | p305 => exact lookup_p305
  | p306 => exact lookup_p306
  | p307 => exact lookup_p307
  | p308 => exact lookup_p308
  | p309 => exact lookup_p309
  | p310 => exact lookup_p310
  | p311 => exact lookup_p311
  | p312 => exact lookup_p312
  | p313 => exact lookup_p313
  | p314 => exact lookup_p314
  | p315 => exact lookup_p315
  | p316 => exact lookup_p316
  | p317 => exact lookup_p317
  | p318 => exact lookup_p318
  | p319 => exact lookup_p319
  | p320 => exact lookup_p320
  | p321 => exact lookup_p321
  | p322 => exact lookup_p322
  | p323 => exact lookup_p323
  | p324 => exact lookup_p324
  | p325 => exact lookup_p325
  | p326 => exact lookup_p326
  | p327 => exact lookup_p327
  | p328 => exact lookup_p328
  | p329 => exact lookup_p329
  | p330 => exact lookup_p330
  | p331 => exact lookup_p331
  | p332 => exact lookup_p332
  | p333 => exact lookup_p333
  | p334 => exact lookup_p334
  | p335 => exact lookup_p335
  | p336 => exact lookup_p336
  | p337 => exact lookup_p337
  | p338 => exact lookup_p338
  | p339 => exact lookup_p339
  | p340 => exact lookup_p340
  | p341 => exact lookup_p341
  | p342 => exact lookup_p342
  | p343 => exact lookup_p343
  | p344 => exact lookup_p344
  | p345 => exact lookup_p345
  | p346 => exact lookup_p346
  | p347 => exact lookup_p347
  | p348 => exact lookup_p348
  | p349 => exact lookup_p349
  | p350 => exact lookup_p350
  | p351 => exact lookup_p351
  | p352 => exact lookup_p352
  | p353 => exact lookup_p353
  | p354 => exact lookup_p354
  | p355 => exact lookup_p355
  | p356 => exact lookup_p356
  | p357 => exact lookup_p357
  | p358 => exact lookup_p358
  | p359 => exact lookup_p359
  | p360 => exact lookup_p360
  | p361 => exact lookup_p361
  | p362 => exact lookup_p362
  | p363 => exact lookup_p363
  | p364 => exact lookup_p364
  | p365 => exact lookup_p365
  | p366 => exact lookup_p366
  | p367 => exact lookup_p367
  | p368 => exact lookup_p368
  | p369 => exact lookup_p369
  | p370 => exact lookup_p370
  | p371 => exact lookup_p371
  | p372 => exact lookup_p372
  | p373 => exact lookup_p373
  | p374 => exact lookup_p374
  | p375 => exact lookup_p375
  | p376 => exact lookup_p376
  | p377 => exact lookup_p377
  | p378 => exact lookup_p378
  | p379 => exact lookup_p379
  | p380 => exact lookup_p380
  | p381 => exact lookup_p381
  | p382 => exact lookup_p382
  | p383 => exact lookup_p383
  | p384 => exact lookup_p384
  | p385 => exact lookup_p385
  | p386 => exact lookup_p386
  | p387 => exact lookup_p387
  | p388 => exact lookup_p388
  | p389 => exact lookup_p389
  | p390 => exact lookup_p390
  | p391 => exact lookup_p391
  | p392 => exact lookup_p392

theorem signatures_iff (name : String) (s : PrimSig) : signature name = some s ↔
    ∃ row ∈ Primitive.all, name = row.name ∧ s = row.signature := by
  constructor
  · exact lookup_primitive
  · rintro ⟨row,_,rfl,rfl⟩
    simp only [signature,primitive_lookup,Option.map_some]
end
end Benitoite.Release.Refinement.StandardModel
