import Benitoite.Release.Refinement.StandardModelPureRows

/-! # 合成表の数値の純粋な行

Byte・Character・Float・Float32・Decimal・整数の各幅の公開モジュールの組込みの行は、既存の
数値の応答の補題（任意のP/B、又は合成プログラムが供給する同じOption・丸め方式の宣言）から、
合成表の同じlookupと同じBuiltinArgsの応答を得る。Decimal.fromFloatの正常値は、同じbitsから
作る既存のδを読む。別名の本体（Def）はこの表の行に数えない。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
open Benitoite.Interval StandardScalar

private theorem scalar_delta (api : StandardScalarResponse.API) (ts es rs ws) :
    (StandardScalarResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> simp [StandardScalarResponse.table, StandardScalarResponse.API.name,
    StandardScalarResponse.API.delta]

/-- Byte・Character・Floatの変換・ビット演算・分類の行。 -/
theorem PureRow.scalar {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (api : StandardScalarResponse.API)
    (hname : row.name = api.name) (hsig : row.signatureWith B.sat = api.signature)
    (hprovider : row.provider.delta = (StandardScalarResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider]; exact scalar_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardScalarResponse.response api env.options.some_decl
      env.options.none_decl env.options.arity args)

/-- Byte.toStringの行。 -/
theorem PureRow.byteString {P : Program} {B : Builtins} [RowLookup B] (row : Primitive) (hname : row.name = "Byte.toString")
    (hsig : row.signatureWith B.sat = StandardByteStringResponse.signature)
    (hprovider : row.provider.delta = StandardByteStringResponse.delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider])
    (fun _ _ _ _ _ _ _ args => StandardByteStringResponse.response args)

private theorem character_delta (api : StandardCharacterResponse.API) (ts es rs ws) :
    (StandardCharacterResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> simp [StandardCharacterResponse.table, StandardCharacterResponse.API.all,
    StandardCharacterResponse.API.delta, StandardCharacterResponse.API.name, List.findSome?] <;>
    split <;> rename_i heq <;> exact heq.symm

/-- Characterの分類と文字列の行。 -/
theorem PureRow.character {P : Program} {B : Builtins} [RowLookup B] (row : Primitive) (api : StandardCharacterResponse.API)
    (hname : row.name = api.name) (hsig : row.signatureWith B.sat = api.signature)
    (hprovider : row.provider.delta = (StandardCharacterResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig
    (fun ts es rs ws => by rw [hprovider]; exact character_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardCharacterResponse.response api args)

private theorem numericRemaining_delta (api : StandardNumericRemainingResponse.API) (ts es rs ws) :
    (StandardNumericRemainingResponse.table signatureBase).delta api.name ts es rs ws =
      api.delta api.name ts es rs ws := by
  cases api <;> rfl

/-- Float・Float32・Decimalの文字列・相互の変換の行。Decimal.fromFloatは同じbitsから正常値を作る。 -/
theorem PureRow.numericRemaining {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (api : StandardNumericRemainingResponse.API)
    (hname : row.name = api.name) (hsig : row.signatureWith B.sat = api.signature)
    (hprovider : row.provider.delta = (StandardNumericRemainingResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig
    (fun ts es rs ws => by rw [hprovider]; exact numericRemaining_delta api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardNumericRemainingResponse.response api
      env.options.some_decl env.options.none_decl
      env.options.arity args)

/-- 整数の各幅の床除算・絶対値・ビット演算・シフトの行。 -/
theorem PureRow.integerAPI {P : Program} {B : Builtins} [RowLookup B] (row : Primitive) (k : IntKind) (api : StandardIntegerAPI.API)
    (available : StandardIntegerAPI.API.available k api)
    (hname : row.name = StandardIntegerAPI.API.name k api)
    (hsig : row.signatureWith B.sat = StandardIntegerAPI.API.signature k api)
    (hprovider : row.provider.delta = integerDelta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider])
    (fun _ _ _ _ _ _ _ args => StandardIntegerAPI.response k api available args)

private theorem integerText_delta (k : IntKind) (api : StandardIntegerTextResponse.API) (ts es rs ws) :
    (StandardIntegerTextResponse.table signatureBase).delta (StandardIntegerTextResponse.name k api)
      ts es rs ws = StandardIntegerTextResponse.delta k api (StandardIntegerTextResponse.name k api) ts es rs ws := by
  cases k <;> cases api <;> rfl

/-- 整数の各幅の文字列・Floatへの変換と解析の行。 -/
theorem PureRow.integerText {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (k : IntKind) (api : StandardIntegerTextResponse.API)
    (hname : row.name = StandardIntegerTextResponse.name k api)
    (hsig : row.signatureWith B.sat = StandardIntegerTextResponse.signature k api)
    (hprovider : row.provider.delta = (StandardIntegerTextResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig
    (fun ts es rs ws => by rw [hprovider]; exact integerText_delta k api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardIntegerTextResponse.response k api
      env.options.some_decl env.options.none_decl
      env.options.arity args)

/-- 整数の各幅とIntegerの相互の変換の行。 -/
theorem PureRow.conversion {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (k : IntKind) (fromInteger : Bool)
    (available : k ≠ .integer64)
    (hname : row.name = StandardConversionResponse.name k fromInteger)
    (hsig : row.signatureWith B.sat = StandardConversionResponse.signature k fromInteger)
    (hprovider : row.provider.delta = integerDelta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider])
    (fun _ _ _ _ _ _ _ args => StandardConversionResponse.response k fromInteger available
      env.options.some_decl env.options.none_decl
      env.options.arity args)

/-- Decimalの丸め・絶対値・切り捨てと、IntegerとUnsignedInteger64との変換の行。丸め方式の
宣言は合成プログラムが供給する。 -/
theorem PureRow.decimal {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (api : StandardDecimalResponse.API)
    (hname : row.name = api.name) (hsig : row.signatureWith B.sat = api.signature)
    (hprovider : row.provider.delta = decimalDelta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider])
    (fun _ _ _ _ _ _ _ args => StandardDecimalResponse.response_of env.rounding api args)

private theorem floatMath_delta (single : Bool) (api : StandardFloatMathResponse.API) (ts es rs ws) :
    (StandardFloatMathResponse.table signatureBase).delta (StandardFloatMathResponse.name single api)
      ts es rs ws =
      StandardFloatMathResponse.delta single api (StandardFloatMathResponse.name single api) ts es rs ws := by
  cases single <;> cases api <;> rfl

/-- FloatとFloat32の丸め・絶対値・平方根の行。 -/
theorem PureRow.floatMath {P : Program} {B : Builtins} [env : RowEnv P B] (row : Primitive) (single : Bool) (api : StandardFloatMathResponse.API)
    (hname : row.name = StandardFloatMathResponse.name single api)
    (hsig : row.signatureWith B.sat = StandardFloatMathResponse.signature single api)
    (hprovider : row.provider.delta = (StandardFloatMathResponse.table signatureBase).delta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig
    (fun ts es rs ws => by rw [hprovider]; exact floatMath_delta single api ts es rs ws)
    (fun _ _ _ _ _ _ _ args => StandardFloatMathResponse.response single api
      env.options.some_decl env.options.none_decl
      env.options.arity args)

/-- 整数の各幅の最小・最大の行。 -/
theorem PureRow.minMax {P : Program} {B : Builtins} [RowLookup B] (row : Primitive) (k : IntKind) (maximum : Bool)
    (hname : row.name = StandardIntegerResponse.minMaxName k maximum)
    (hsig : row.signatureWith B.sat = StandardIntegerResponse.minMaxSig k)
    (hprovider : row.provider.delta = integerDelta)
    (hrow : row.readsKeys = false := by decide) :
    PureRowOn P B row.name :=
  PureRow.of_response (hrow := hrow) row hname hsig (fun ts es rs ws => by rw [hprovider])
    (fun _ _ _ _ _ _ _ args => by
      obtain ⟨out, delta, typed, adequate, nonexit, _⟩ := StandardIntegerResponse.minMax_response k maximum args
      exact ⟨out, delta, typed, adequate, nonexit⟩)

/-- 数値の公開モジュール（Byte・Character・Float・Float32・Decimal・Integer・Integer8・Integer16・
Integer32・UnsignedInteger16・UnsignedInteger32・UnsignedInteger64）の組込みの行。 -/
def Primitive.numeric : Primitive → Bool
  | .p111 | .p112 | .p113 | .p114 | .p115 | .p116 | .p117 | .p118 | .p119 | .p136 | .p137 | .p138 | .p139 | .p140 | .p141 | .p142 | .p143 | .p144 | .p145 | .p146 | .p147 | .p148 | .p149 | .p150 | .p151 | .p152 | .p153 | .p154 | .p155 | .p164 | .p165 | .p166 | .p167 | .p168 | .p169 | .p170 | .p171 | .p172 | .p173 | .p174 | .p175 | .p176 | .p177 | .p178 | .p179 | .p180 | .p181 | .p182 | .p183 | .p184 | .p189 | .p190 | .p191 | .p192 | .p193 | .p194 | .p195 | .p196 | .p197 | .p198 | .p199 | .p200 | .p201 | .p202 | .p203 | .p204 | .p205 | .p206 | .p207 | .p208 | .p209 | .p210 | .p211 | .p212 | .p213 | .p214 | .p215 | .p216 | .p217 | .p218 | .p219 | .p220 | .p221 | .p222 | .p223 | .p224 | .p225 | .p226 | .p227 | .p228 | .p229 | .p230 | .p231 | .p232 | .p233 | .p234 | .p235 | .p236 | .p237 | .p238 | .p239 | .p240 | .p241 | .p242 | .p243 | .p244 | .p245 | .p246 | .p247 | .p248 | .p249 | .p250 | .p251 | .p252 | .p253 | .p254 | .p322 | .p323 | .p324 | .p325 | .p326 | .p327 | .p328 | .p329 | .p330 | .p331 | .p332 | .p333 | .p334 | .p335 | .p336 | .p337 | .p338 | .p339 | .p340 | .p341 | .p342 | .p343 | .p344 | .p345 | .p346 | .p347 | .p348 | .p349 | .p350 | .p351 | .p352 | .p353 | .p354 | .p355 | .p356 | .p357 | .p358 | .p359 | .p360 | .p361 | .p362 | .p363 | .p364 | .p365 | .p366 | .p367 | .p368 | .p369 | .p370 | .p371 => true
  | _ => false

/-- 数値の公開モジュールの全166行の全BuiltinArgsは、合成表の同じlookupで型付きの非exitの応答を持つ。 -/
theorem numeric_rows_of {P : Program} {B : Builtins} [RowEnv P B] (row : Primitive)
    (numeric : row.numeric = true) : PureRowOn P B row.name := by
  cases row
  case p111 => exact PureRow.scalar .p111 .byteAnd rfl rfl rfl
  case p112 => exact PureRow.scalar .p112 .byteXor rfl rfl rfl
  case p113 => exact PureRow.scalar .p113 .byteNot rfl rfl rfl
  case p114 => exact PureRow.scalar .p114 .byteOr rfl rfl rfl
  case p115 => exact PureRow.scalar .p115 .byteFrom rfl rfl rfl
  case p116 => exact PureRow.scalar .p116 .byteLeft rfl rfl rfl
  case p117 => exact PureRow.scalar .p117 .byteRight rfl rfl rfl
  case p118 => exact PureRow.scalar .p118 .byteTo rfl rfl rfl
  case p119 => exact PureRow.byteString .p119 rfl rfl rfl
  case p136 => exact PureRow.scalar .p136 .characterFrom rfl rfl rfl
  case p137 => exact PureRow.character .p137 .isASCIIDigit rfl rfl rfl
  case p138 => exact PureRow.character .p138 .isASCIIWhitespace rfl rfl rfl
  case p139 => exact PureRow.character .p139 .isAlphabetic rfl rfl rfl
  case p140 => exact PureRow.character .p140 .isLowercase rfl rfl rfl
  case p141 => exact PureRow.character .p141 .isNumeric rfl rfl rfl
  case p142 => exact PureRow.character .p142 .isUppercase rfl rfl rfl
  case p143 => exact PureRow.character .p143 .isWhitespace rfl rfl rfl
  case p144 => exact PureRow.scalar .p144 .characterTo rfl rfl rfl
  case p145 => exact PureRow.character .p145 .toLowercase rfl rfl rfl
  case p146 => exact PureRow.character .p146 .toString rfl rfl rfl
  case p147 => exact PureRow.character .p147 .toUppercase rfl rfl rfl
  case p148 => exact PureRow.decimal .p148 .absolute rfl rfl rfl
  case p149 => exact PureRow.numericRemaining .p149 .Decimal_fromFloat rfl rfl rfl
  case p150 => exact PureRow.decimal .p150 .fromInteger rfl rfl rfl
  case p151 => exact PureRow.numericRemaining .p151 .Decimal_parse rfl rfl rfl
  case p152 => exact PureRow.decimal .p152 .round rfl rfl rfl
  case p153 => exact PureRow.numericRemaining .p153 .Decimal_toFloat rfl rfl rfl
  case p154 => exact PureRow.numericRemaining .p154 .Decimal_toString rfl rfl rfl
  case p155 => exact PureRow.decimal .p155 .truncate rfl rfl rfl
  case p164 => exact PureRow.floatMath .p164 false .absolute rfl rfl rfl
  case p165 => exact PureRow.floatMath .p165 false .ceiling rfl rfl rfl
  case p166 => exact PureRow.floatMath .p166 false .floor rfl rfl rfl
  case p167 => exact PureRow.scalar .p167 .floatNaN rfl rfl rfl
  case p168 => exact PureRow.numericRemaining .p168 .Float_parse rfl rfl rfl
  case p169 => exact PureRow.floatMath .p169 false .round rfl rfl rfl
  case p170 => exact PureRow.floatMath .p170 false .squareRoot rfl rfl rfl
  case p171 => exact PureRow.numericRemaining .p171 .Float_toString rfl rfl rfl
  case p172 => exact PureRow.floatMath .p172 false .truncate rfl rfl rfl
  case p173 => exact PureRow.floatMath .p173 true .absolute rfl rfl rfl
  case p174 => exact PureRow.floatMath .p174 true .ceiling rfl rfl rfl
  case p175 => exact PureRow.floatMath .p175 true .floor rfl rfl rfl
  case p176 => exact PureRow.numericRemaining .p176 .Float32_fromFloat rfl rfl rfl
  case p177 => exact PureRow.scalar .p177 .float32Infinite rfl rfl rfl
  case p178 => exact PureRow.scalar .p178 .float32NaN rfl rfl rfl
  case p179 => exact PureRow.numericRemaining .p179 .Float32_parse rfl rfl rfl
  case p180 => exact PureRow.floatMath .p180 true .round rfl rfl rfl
  case p181 => exact PureRow.floatMath .p181 true .squareRoot rfl rfl rfl
  case p182 => exact PureRow.numericRemaining .p182 .Float32_toFloat rfl rfl rfl
  case p183 => exact PureRow.numericRemaining .p183 .Float32_toString rfl rfl rfl
  case p184 => exact PureRow.floatMath .p184 true .truncate rfl rfl rfl
  case p189 => exact PureRow.integerAPI .p189 .integer64 .absolute (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p190 => exact PureRow.integerAPI .p190 .integer64 .bitwiseAnd (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p191 => exact PureRow.integerAPI .p191 .integer64 .bitwiseExclusiveOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p192 => exact PureRow.integerAPI .p192 .integer64 .bitwiseNot (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p193 => exact PureRow.integerAPI .p193 .integer64 .bitwiseOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p194 => exact PureRow.integerAPI .p194 .integer64 .floorDivide (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p195 => exact PureRow.integerAPI .p195 .integer64 .floorModulo (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p196 => exact PureRow.minMax .p196 .integer64 true rfl rfl rfl
  case p197 => exact PureRow.minMax .p197 .integer64 false rfl rfl rfl
  case p198 => exact PureRow.integerText .p198 .integer64 .parse rfl rfl rfl
  case p199 => exact PureRow.integerAPI .p199 .integer64 .shiftLeft (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p200 => exact PureRow.integerAPI .p200 .integer64 .shiftRight (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p201 => exact PureRow.integerAPI .p201 .integer64 .shiftRightUnsigned (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p202 => exact PureRow.integerText .p202 .integer64 .toFloat rfl rfl rfl
  case p203 => exact PureRow.integerText .p203 .integer64 .toString rfl rfl rfl
  case p204 => exact PureRow.integerAPI .p204 .integer16 .absolute (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p205 => exact PureRow.integerAPI .p205 .integer16 .bitwiseAnd (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p206 => exact PureRow.integerAPI .p206 .integer16 .bitwiseExclusiveOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p207 => exact PureRow.integerAPI .p207 .integer16 .bitwiseNot (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p208 => exact PureRow.integerAPI .p208 .integer16 .bitwiseOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p209 => exact PureRow.integerAPI .p209 .integer16 .floorDivide (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p210 => exact PureRow.integerAPI .p210 .integer16 .floorModulo (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p211 => exact PureRow.conversion .p211 .integer16 true (by decide) rfl rfl rfl
  case p212 => exact PureRow.minMax .p212 .integer16 true rfl rfl rfl
  case p213 => exact PureRow.minMax .p213 .integer16 false rfl rfl rfl
  case p214 => exact PureRow.integerText .p214 .integer16 .parse rfl rfl rfl
  case p215 => exact PureRow.integerAPI .p215 .integer16 .shiftLeft (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p216 => exact PureRow.integerAPI .p216 .integer16 .shiftRight (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p217 => exact PureRow.integerAPI .p217 .integer16 .shiftRightUnsigned (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p218 => exact PureRow.integerText .p218 .integer16 .toFloat rfl rfl rfl
  case p219 => exact PureRow.conversion .p219 .integer16 false (by decide) rfl rfl rfl
  case p220 => exact PureRow.integerText .p220 .integer16 .toString rfl rfl rfl
  case p221 => exact PureRow.integerAPI .p221 .integer32 .absolute (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p222 => exact PureRow.integerAPI .p222 .integer32 .bitwiseAnd (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p223 => exact PureRow.integerAPI .p223 .integer32 .bitwiseExclusiveOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p224 => exact PureRow.integerAPI .p224 .integer32 .bitwiseNot (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p225 => exact PureRow.integerAPI .p225 .integer32 .bitwiseOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p226 => exact PureRow.integerAPI .p226 .integer32 .floorDivide (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p227 => exact PureRow.integerAPI .p227 .integer32 .floorModulo (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p228 => exact PureRow.conversion .p228 .integer32 true (by decide) rfl rfl rfl
  case p229 => exact PureRow.minMax .p229 .integer32 true rfl rfl rfl
  case p230 => exact PureRow.minMax .p230 .integer32 false rfl rfl rfl
  case p231 => exact PureRow.integerText .p231 .integer32 .parse rfl rfl rfl
  case p232 => exact PureRow.integerAPI .p232 .integer32 .shiftLeft (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p233 => exact PureRow.integerAPI .p233 .integer32 .shiftRight (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p234 => exact PureRow.integerAPI .p234 .integer32 .shiftRightUnsigned (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p235 => exact PureRow.integerText .p235 .integer32 .toFloat rfl rfl rfl
  case p236 => exact PureRow.conversion .p236 .integer32 false (by decide) rfl rfl rfl
  case p237 => exact PureRow.integerText .p237 .integer32 .toString rfl rfl rfl
  case p238 => exact PureRow.integerAPI .p238 .integer8 .absolute (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p239 => exact PureRow.integerAPI .p239 .integer8 .bitwiseAnd (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p240 => exact PureRow.integerAPI .p240 .integer8 .bitwiseExclusiveOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p241 => exact PureRow.integerAPI .p241 .integer8 .bitwiseNot (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p242 => exact PureRow.integerAPI .p242 .integer8 .bitwiseOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p243 => exact PureRow.integerAPI .p243 .integer8 .floorDivide (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p244 => exact PureRow.integerAPI .p244 .integer8 .floorModulo (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p245 => exact PureRow.conversion .p245 .integer8 true (by decide) rfl rfl rfl
  case p246 => exact PureRow.minMax .p246 .integer8 true rfl rfl rfl
  case p247 => exact PureRow.minMax .p247 .integer8 false rfl rfl rfl
  case p248 => exact PureRow.integerText .p248 .integer8 .parse rfl rfl rfl
  case p249 => exact PureRow.integerAPI .p249 .integer8 .shiftLeft (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p250 => exact PureRow.integerAPI .p250 .integer8 .shiftRight (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p251 => exact PureRow.integerAPI .p251 .integer8 .shiftRightUnsigned (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p252 => exact PureRow.integerText .p252 .integer8 .toFloat rfl rfl rfl
  case p253 => exact PureRow.conversion .p253 .integer8 false (by decide) rfl rfl rfl
  case p254 => exact PureRow.integerText .p254 .integer8 .toString rfl rfl rfl
  case p322 => exact PureRow.integerAPI .p322 .unsignedInteger16 .absolute (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p323 => exact PureRow.integerAPI .p323 .unsignedInteger16 .bitwiseAnd (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p324 => exact PureRow.integerAPI .p324 .unsignedInteger16 .bitwiseExclusiveOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p325 => exact PureRow.integerAPI .p325 .unsignedInteger16 .bitwiseNot (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p326 => exact PureRow.integerAPI .p326 .unsignedInteger16 .bitwiseOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p327 => exact PureRow.integerAPI .p327 .unsignedInteger16 .floorDivide (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p328 => exact PureRow.integerAPI .p328 .unsignedInteger16 .floorModulo (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p329 => exact PureRow.conversion .p329 .unsignedInteger16 true (by decide) rfl rfl rfl
  case p330 => exact PureRow.minMax .p330 .unsignedInteger16 true rfl rfl rfl
  case p331 => exact PureRow.minMax .p331 .unsignedInteger16 false rfl rfl rfl
  case p332 => exact PureRow.integerText .p332 .unsignedInteger16 .parse rfl rfl rfl
  case p333 => exact PureRow.integerAPI .p333 .unsignedInteger16 .shiftLeft (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p334 => exact PureRow.integerAPI .p334 .unsignedInteger16 .shiftRight (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p335 => exact PureRow.integerText .p335 .unsignedInteger16 .toFloat rfl rfl rfl
  case p336 => exact PureRow.conversion .p336 .unsignedInteger16 false (by decide) rfl rfl rfl
  case p337 => exact PureRow.integerText .p337 .unsignedInteger16 .toString rfl rfl rfl
  case p338 => exact PureRow.integerAPI .p338 .unsignedInteger32 .absolute (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p339 => exact PureRow.integerAPI .p339 .unsignedInteger32 .bitwiseAnd (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p340 => exact PureRow.integerAPI .p340 .unsignedInteger32 .bitwiseExclusiveOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p341 => exact PureRow.integerAPI .p341 .unsignedInteger32 .bitwiseNot (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p342 => exact PureRow.integerAPI .p342 .unsignedInteger32 .bitwiseOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p343 => exact PureRow.integerAPI .p343 .unsignedInteger32 .floorDivide (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p344 => exact PureRow.integerAPI .p344 .unsignedInteger32 .floorModulo (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p345 => exact PureRow.conversion .p345 .unsignedInteger32 true (by decide) rfl rfl rfl
  case p346 => exact PureRow.minMax .p346 .unsignedInteger32 true rfl rfl rfl
  case p347 => exact PureRow.minMax .p347 .unsignedInteger32 false rfl rfl rfl
  case p348 => exact PureRow.integerText .p348 .unsignedInteger32 .parse rfl rfl rfl
  case p349 => exact PureRow.integerAPI .p349 .unsignedInteger32 .shiftLeft (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p350 => exact PureRow.integerAPI .p350 .unsignedInteger32 .shiftRight (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p351 => exact PureRow.integerText .p351 .unsignedInteger32 .toFloat rfl rfl rfl
  case p352 => exact PureRow.conversion .p352 .unsignedInteger32 false (by decide) rfl rfl rfl
  case p353 => exact PureRow.integerText .p353 .unsignedInteger32 .toString rfl rfl rfl
  case p354 => exact PureRow.integerAPI .p354 .unsignedInteger64 .absolute (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p355 => exact PureRow.integerAPI .p355 .unsignedInteger64 .bitwiseAnd (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p356 => exact PureRow.integerAPI .p356 .unsignedInteger64 .bitwiseExclusiveOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p357 => exact PureRow.integerAPI .p357 .unsignedInteger64 .bitwiseNot (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p358 => exact PureRow.integerAPI .p358 .unsignedInteger64 .bitwiseOr (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p359 => exact PureRow.integerAPI .p359 .unsignedInteger64 .floorDivide (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p360 => exact PureRow.integerAPI .p360 .unsignedInteger64 .floorModulo (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p361 => exact PureRow.decimal .p361 .fromDecimal rfl rfl rfl
  case p362 => exact PureRow.conversion .p362 .unsignedInteger64 true (by decide) rfl rfl rfl
  case p363 => exact PureRow.minMax .p363 .unsignedInteger64 true rfl rfl rfl
  case p364 => exact PureRow.minMax .p364 .unsignedInteger64 false rfl rfl rfl
  case p365 => exact PureRow.integerText .p365 .unsignedInteger64 .parse rfl rfl rfl
  case p366 => exact PureRow.integerAPI .p366 .unsignedInteger64 .shiftLeft (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p367 => exact PureRow.integerAPI .p367 .unsignedInteger64 .shiftRight (by unfold StandardIntegerAPI.API.available; decide) rfl rfl rfl
  case p368 => exact PureRow.decimal .p368 .toDecimal rfl rfl rfl
  case p369 => exact PureRow.integerText .p369 .unsignedInteger64 .toFloat rfl rfl rfl
  case p370 => exact PureRow.conversion .p370 .unsignedInteger64 false (by decide) rfl rfl rfl
  case p371 => exact PureRow.integerText .p371 .unsignedInteger64 .toString rfl rfl rfl
  all_goals cases numeric

theorem numeric_rows (externals : List (ExternalKey × ExternalDecl)) (row : Primitive)
    (numeric : row.numeric = true) : PureRow (program externals) row.name :=
  numeric_rows_of row numeric

/-- 合成プログラムの宣言を読むDecimal.roundと、同じbitsを読むDecimal.fromFloatの行。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    PureRow (program externals) "Decimal.round" ∧ PureRow (program externals) "Decimal.fromFloat" :=
  ⟨numeric_rows externals .p152 rfl, numeric_rows externals .p149 rfl⟩

end
end Benitoite.Release.Refinement.StandardModel
