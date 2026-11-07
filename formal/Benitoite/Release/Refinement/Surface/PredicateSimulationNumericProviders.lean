import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantResults
import Benitoite.Release.Refinement.Surface.PredicateSimulationResponses

/-! # 数値と文字の固定行で用いる実署名と入力同一性 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private def monomorphicSignature (names : List String) (inputs : List Ty) (result : Ty) : PrimSig :=
  ⟨[],0,names,inputs,result,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private def integerSignature (kind : Benitoite.Interval.IntKind) (api : StandardIntegerAPI.API) : PrimSig :=
  match api with
  | .absolute => monomorphicSignature ["n"] [embedTy kind.type] (embedTy kind.type)
  | .bitwiseNot => monomorphicSignature ["a"] [embedTy kind.type] (embedTy kind.type)
  | .shiftLeft | .shiftRight | .shiftRightUnsigned =>
      monomorphicSignature ["a","n"] [embedTy kind.type,.base .integer] (embedTy kind.type)
  | _ => monomorphicSignature ["a","b"] [embedTy kind.type,embedTy kind.type] (embedTy kind.type)

private theorem integerSignature_eq (kind : Benitoite.Interval.IntKind) (api : StandardIntegerAPI.API) :
    StandardIntegerAPI.API.signature kind api = integerSignature kind api := by cases api <;> rfl

private def arithmeticSignature (kind : Benitoite.Interval.IntKind) (api : StandardArithmeticResponse.API) : PrimSig :=
  match api with
  | .negate => monomorphicSignature ["value"] [embedTy kind.type] (embedTy kind.type)
  | _ => monomorphicSignature ["left","right"] [embedTy kind.type,embedTy kind.type] (embedTy kind.type)

private theorem arithmeticSignature_eq (kind : Benitoite.Interval.IntKind) (api : StandardArithmeticResponse.API) :
    StandardArithmeticResponse.API.signature kind api = arithmeticSignature kind api := by cases api <;> rfl

private theorem conversionSignature_eq (kind : Benitoite.Interval.IntKind) (fromInteger : Bool) :
    StandardConversionResponse.signature kind fromInteger =
      monomorphicSignature ["n"] [if fromInteger then .base .integer else embedTy kind.type]
        (StandardConversionResponse.result kind fromInteger) := by cases fromInteger <;> rfl

private theorem integer_metadata (kind : Benitoite.Interval.IntKind) (api : StandardIntegerAPI.API) :
    let signature := StandardIntegerAPI.API.signature kind api
    signature.tparams = [] ∧ signature.neffs = 0 ∧ signature.rkinds = [] ∧
      NamesWF signature.names signature.params ∧
      (∀ input ∈ signature.params, ConstantInputType input) ∧
      instantiatedTel (Tel.instR [] signature.tel) [] [] =
        Ty.toTel signature.names signature.params signature.ret Eff.empty := by
  rw [integerSignature_eq]
  cases kind <;> cases api <;> simp [integerSignature, monomorphicSignature, embedTy, Benitoite.Interval.IntKind.type, NamesWF, ConstantInputType.base, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 固定行の実署名から、対応先だけが型付く両実引数列の等号を得る。 -/
theorem integer_fixed_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (kind : Benitoite.Interval.IntKind) (api : StandardIntegerAPI.API) 
    (typed : BuiltinArgs P B Ψ (StandardIntegerAPI.API.name kind api) (StandardIntegerAPI.API.signature kind api) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨types,effects,ranges,named,shapes,instantiated⟩ := integer_metadata kind api
  exact constant_arguments_equal typed types effects ranges instantiated named shapes related

private theorem arithmetic_metadata (kind : Benitoite.Interval.IntKind) (api : StandardArithmeticResponse.API) :
    let signature := StandardArithmeticResponse.API.signature kind api
    signature.tparams = [] ∧ signature.neffs = 0 ∧ signature.rkinds = [] ∧
      NamesWF signature.names signature.params ∧
      (∀ input ∈ signature.params, ConstantInputType input) ∧
      instantiatedTel (Tel.instR [] signature.tel) [] [] =
        Ty.toTel signature.names signature.params signature.ret Eff.empty := by
  rw [arithmeticSignature_eq]
  cases kind <;> cases api <;> simp [arithmeticSignature, monomorphicSignature, embedTy, Benitoite.Interval.IntKind.type, NamesWF, ConstantInputType.base, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 固定行の実署名から、対応先だけが型付く両実引数列の等号を得る。 -/
theorem arithmetic_fixed_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (kind : Benitoite.Interval.IntKind) (api : StandardArithmeticResponse.API) 
    (typed : BuiltinArgs P B Ψ (StandardArithmeticResponse.API.name kind api) (StandardArithmeticResponse.API.signature kind api) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨types,effects,ranges,named,shapes,instantiated⟩ := arithmetic_metadata kind api
  exact constant_arguments_equal typed types effects ranges instantiated named shapes related

private theorem integer_text_metadata (kind : Benitoite.Interval.IntKind) (api : StandardIntegerTextResponse.API) :
    let signature := StandardIntegerTextResponse.signature kind api
    signature.tparams = [] ∧ signature.neffs = 0 ∧ signature.rkinds = [] ∧
      NamesWF signature.names signature.params ∧
      (∀ input ∈ signature.params, ConstantInputType input) ∧
      instantiatedTel (Tel.instR [] signature.tel) [] [] =
        Ty.toTel signature.names signature.params signature.ret Eff.empty := by
  cases kind <;> cases api <;> simp [StandardIntegerTextResponse.signature, StandardIntegerTextResponse.input, StandardIntegerTextResponse.result, embedTy, Benitoite.Interval.IntKind.type, NamesWF, ConstantInputType.base, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 固定行の実署名から、対応先だけが型付く両実引数列の等号を得る。 -/
theorem integer_text_fixed_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (kind : Benitoite.Interval.IntKind) (api : StandardIntegerTextResponse.API) 
    (typed : BuiltinArgs P B Ψ (StandardIntegerTextResponse.name kind api) (StandardIntegerTextResponse.signature kind api) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨types,effects,ranges,named,shapes,instantiated⟩ := integer_text_metadata kind api
  exact constant_arguments_equal typed types effects ranges instantiated named shapes related

private theorem conversion_metadata (kind : Benitoite.Interval.IntKind) (fromInteger : Bool) :
    let signature := StandardConversionResponse.signature kind fromInteger
    signature.tparams = [] ∧ signature.neffs = 0 ∧ signature.rkinds = [] ∧
      NamesWF signature.names signature.params ∧
      (∀ input ∈ signature.params, ConstantInputType input) ∧
      instantiatedTel (Tel.instR [] signature.tel) [] [] =
        Ty.toTel signature.names signature.params signature.ret Eff.empty := by
  rw [conversionSignature_eq]
  cases kind <;> cases fromInteger <;> simp [monomorphicSignature, StandardConversionResponse.result, embedTy, Benitoite.Interval.IntKind.type, NamesWF, ConstantInputType.base, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 固定行の実署名から、対応先だけが型付く両実引数列の等号を得る。 -/
theorem conversion_fixed_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (kind : Benitoite.Interval.IntKind) (fromInteger : Bool) 
    (typed : BuiltinArgs P B Ψ (StandardConversionResponse.name kind fromInteger) (StandardConversionResponse.signature kind fromInteger) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨types,effects,ranges,named,shapes,instantiated⟩ := conversion_metadata kind fromInteger
  exact constant_arguments_equal typed types effects ranges instantiated named shapes related

private theorem float_math_metadata (single : Bool) (api : StandardFloatMathResponse.API) :
    let signature := StandardFloatMathResponse.signature single api
    signature.tparams = [] ∧ signature.neffs = 0 ∧ signature.rkinds = [] ∧
      NamesWF signature.names signature.params ∧
      (∀ input ∈ signature.params, ConstantInputType input) ∧
      instantiatedTel (Tel.instR [] signature.tel) [] [] =
        Ty.toTel signature.names signature.params signature.ret Eff.empty := by
  cases single <;> cases api <;> simp [StandardFloatMathResponse.signature, StandardFloatMathResponse.base, StandardFloatMathResponse.result, NamesWF, ConstantInputType.base, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 固定行の実署名から、対応先だけが型付く両実引数列の等号を得る。 -/
theorem float_math_fixed_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (single : Bool) (api : StandardFloatMathResponse.API) 
    (typed : BuiltinArgs P B Ψ (StandardFloatMathResponse.name single api) (StandardFloatMathResponse.signature single api) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨types,effects,ranges,named,shapes,instantiated⟩ := float_math_metadata single api
  exact constant_arguments_equal typed types effects ranges instantiated named shapes related

private theorem order_metadata (kind : StandardOrderResponse.Kind) :
    let signature := StandardOrderResponse.signature kind
    signature.tparams = [] ∧ signature.neffs = 0 ∧ signature.rkinds = [] ∧
      NamesWF signature.names signature.params ∧
      (∀ input ∈ signature.params, ConstantInputType input) ∧
      instantiatedTel (Tel.instR [] signature.tel) [] [] =
        Ty.toTel signature.names signature.params signature.ret Eff.empty := by
  cases kind <;> simp [StandardOrderResponse.signature, StandardOrderResponse.Kind.base, NamesWF, ConstantInputType.base, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 固定行の実署名から、対応先だけが型付く両実引数列の等号を得る。 -/
theorem order_fixed_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (kind : StandardOrderResponse.Kind) (comparison : Comparison)
    (typed : BuiltinArgs P B Ψ (StandardOrderResponse.name kind comparison) (StandardOrderResponse.signature kind) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨types,effects,ranges,named,shapes,instantiated⟩ := order_metadata kind
  exact constant_arguments_equal typed types effects ranges instantiated named shapes related

private theorem character_metadata (api : StandardCharacterResponse.API) :
    let signature := api.signature
    signature.tparams = [] ∧ signature.neffs = 0 ∧ signature.rkinds = [] ∧
      NamesWF signature.names signature.params ∧
      (∀ input ∈ signature.params, ConstantInputType input) ∧
      instantiatedTel (Tel.instR [] signature.tel) [] [] =
        Ty.toTel signature.names signature.params signature.ret Eff.empty := by
  cases api <;> simp [StandardCharacterResponse.API.signature, StandardCharacterResponse.API.result, NamesWF, ConstantInputType.base, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 固定行の実署名から、対応先だけが型付く両実引数列の等号を得る。 -/
theorem character_fixed_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (api : StandardCharacterResponse.API) 
    (typed : BuiltinArgs P B Ψ (api.name) (api.signature) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨types,effects,ranges,named,shapes,instantiated⟩ := character_metadata api
  exact constant_arguments_equal typed types effects ranges instantiated named shapes related

private theorem minmax_metadata (kind : Benitoite.Interval.IntKind) :
    let signature := StandardIntegerResponse.minMaxSig kind
    signature.tparams = [] ∧ signature.neffs = 0 ∧ signature.rkinds = [] ∧
      NamesWF signature.names signature.params ∧
      (∀ input ∈ signature.params, ConstantInputType input) ∧
      instantiatedTel (Tel.instR [] signature.tel) [] [] =
        Ty.toTel signature.names signature.params signature.ret Eff.empty := by
  cases kind <;> simp [StandardIntegerResponse.minMaxSig, embedTy, Benitoite.Interval.IntKind.type, NamesWF, ConstantInputType.base, PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 固定行の実署名から、対応先だけが型付く両実引数列の等号を得る。 -/
theorem minmax_fixed_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (kind : Benitoite.Interval.IntKind) (maximum : Bool)
    (typed : BuiltinArgs P B Ψ (StandardIntegerResponse.minMaxName kind maximum) (StandardIntegerResponse.minMaxSig kind) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨types,effects,ranges,named,shapes,instantiated⟩ := minmax_metadata kind
  exact constant_arguments_equal typed types effects ranges instantiated named shapes related

private theorem integer_result_shape (kind : Benitoite.Interval.IntKind) (api : StandardIntegerAPI.API) : ConstantResultType (StandardIntegerAPI.API.signature kind api).ret := by
  rw [integerSignature_eq]
  cases kind <;> cases api <;> simp [integerSignature,monomorphicSignature,embedTy,Benitoite.Interval.IntKind.type,ConstantResultType.base]

/-- 固定した実署名の結果型と、対応先の結果の型付けから内部名不生成を得る。 -/
theorem integer_fixed_reply_noMint {P B Ψ keys ts es rs values out a e} (kind : Benitoite.Interval.IntKind) (api : StandardIntegerAPI.API) 
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ (StandardIntegerAPI.API.name kind api) (StandardIntegerAPI.API.signature kind api) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨types,effects,ranges,named,_shapes,instantiated⟩ := integer_metadata kind api
  exact constant_arguments_result_noMint options valid typed types effects ranges instantiated named
    (integer_result_shape kind api) reply

private theorem arithmetic_result_shape (kind : Benitoite.Interval.IntKind) (api : StandardArithmeticResponse.API) : ConstantResultType (StandardArithmeticResponse.API.signature kind api).ret := by
  rw [arithmeticSignature_eq]
  cases kind <;> cases api <;> simp [arithmeticSignature,monomorphicSignature,embedTy,Benitoite.Interval.IntKind.type,ConstantResultType.base]

/-- 固定した実署名の結果型と、対応先の結果の型付けから内部名不生成を得る。 -/
theorem arithmetic_fixed_reply_noMint {P B Ψ keys ts es rs values out a e} (kind : Benitoite.Interval.IntKind) (api : StandardArithmeticResponse.API) 
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ (StandardArithmeticResponse.API.name kind api) (StandardArithmeticResponse.API.signature kind api) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨types,effects,ranges,named,_shapes,instantiated⟩ := arithmetic_metadata kind api
  exact constant_arguments_result_noMint options valid typed types effects ranges instantiated named
    (arithmetic_result_shape kind api) reply

private theorem integer_text_result_shape (kind : Benitoite.Interval.IntKind) (api : StandardIntegerTextResponse.API) : ConstantResultType (StandardIntegerTextResponse.signature kind api).ret := by
  cases kind <;> cases api <;> simp [StandardIntegerTextResponse.signature,StandardIntegerTextResponse.result,embedTy,Benitoite.Interval.IntKind.type,ConstantResultType.base,ConstantResultType.option]

/-- 固定した実署名の結果型と、対応先の結果の型付けから内部名不生成を得る。 -/
theorem integer_text_fixed_reply_noMint {P B Ψ keys ts es rs values out a e} (kind : Benitoite.Interval.IntKind) (api : StandardIntegerTextResponse.API) 
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ (StandardIntegerTextResponse.name kind api) (StandardIntegerTextResponse.signature kind api) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨types,effects,ranges,named,_shapes,instantiated⟩ := integer_text_metadata kind api
  exact constant_arguments_result_noMint options valid typed types effects ranges instantiated named
    (integer_text_result_shape kind api) reply

private theorem conversion_result_shape (kind : Benitoite.Interval.IntKind) (fromInteger : Bool) : ConstantResultType (StandardConversionResponse.signature kind fromInteger).ret := by
  rw [conversionSignature_eq]
  cases kind <;> cases fromInteger <;> simp [monomorphicSignature,StandardConversionResponse.result,embedTy,Benitoite.Interval.IntKind.type,ConstantResultType.base,ConstantResultType.option]

/-- 固定した実署名の結果型と、対応先の結果の型付けから内部名不生成を得る。 -/
theorem conversion_fixed_reply_noMint {P B Ψ keys ts es rs values out a e} (kind : Benitoite.Interval.IntKind) (fromInteger : Bool) 
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ (StandardConversionResponse.name kind fromInteger) (StandardConversionResponse.signature kind fromInteger) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨types,effects,ranges,named,_shapes,instantiated⟩ := conversion_metadata kind fromInteger
  exact constant_arguments_result_noMint options valid typed types effects ranges instantiated named
    (conversion_result_shape kind fromInteger) reply

private theorem float_math_result_shape (single : Bool) (api : StandardFloatMathResponse.API) : ConstantResultType (StandardFloatMathResponse.signature single api).ret := by
  cases single <;> cases api <;> simp [StandardFloatMathResponse.signature,StandardFloatMathResponse.result,StandardFloatMathResponse.base,ConstantResultType.base,ConstantResultType.option]

/-- 固定した実署名の結果型と、対応先の結果の型付けから内部名不生成を得る。 -/
theorem float_math_fixed_reply_noMint {P B Ψ keys ts es rs values out a e} (single : Bool) (api : StandardFloatMathResponse.API) 
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ (StandardFloatMathResponse.name single api) (StandardFloatMathResponse.signature single api) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨types,effects,ranges,named,_shapes,instantiated⟩ := float_math_metadata single api
  exact constant_arguments_result_noMint options valid typed types effects ranges instantiated named
    (float_math_result_shape single api) reply

private theorem order_result_shape (kind : StandardOrderResponse.Kind) : ConstantResultType (StandardOrderResponse.signature kind).ret := by
  exact .base _

/-- 固定した実署名の結果型と、対応先の結果の型付けから内部名不生成を得る。 -/
theorem order_fixed_reply_noMint {P B Ψ keys ts es rs values out a e} (kind : StandardOrderResponse.Kind) (comparison : Comparison)
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ (StandardOrderResponse.name kind comparison) (StandardOrderResponse.signature kind) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨types,effects,ranges,named,_shapes,instantiated⟩ := order_metadata kind
  exact constant_arguments_result_noMint options valid typed types effects ranges instantiated named
    (order_result_shape kind) reply

private theorem character_result_shape (api : StandardCharacterResponse.API) : ConstantResultType (api.signature).ret := by
  cases api <;> exact .base _

/-- 固定した実署名の結果型と、対応先の結果の型付けから内部名不生成を得る。 -/
theorem character_fixed_reply_noMint {P B Ψ keys ts es rs values out a e} (api : StandardCharacterResponse.API) 
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ (api.name) (api.signature) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨types,effects,ranges,named,_shapes,instantiated⟩ := character_metadata api
  exact constant_arguments_result_noMint options valid typed types effects ranges instantiated named
    (character_result_shape api) reply

private theorem minmax_result_shape (kind : Benitoite.Interval.IntKind) : ConstantResultType (StandardIntegerResponse.minMaxSig kind).ret := by
  cases kind <;> exact .base _

/-- 固定した実署名の結果型と、対応先の結果の型付けから内部名不生成を得る。 -/
theorem minmax_fixed_reply_noMint {P B Ψ keys ts es rs values out a e} (kind : Benitoite.Interval.IntKind) (maximum : Bool)
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ (StandardIntegerResponse.minMaxName kind maximum) (StandardIntegerResponse.minMaxSig kind) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨types,effects,ranges,named,_shapes,instantiated⟩ := minmax_metadata kind
  exact constant_arguments_result_noMint options valid typed types effects ranges instantiated named
    (minmax_result_shape kind) reply

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation

