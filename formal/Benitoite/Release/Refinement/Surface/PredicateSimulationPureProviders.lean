import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationReplyAvoid

/-! # 純粋な固定行の入力同一性と実providerの応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem string_instantiated (api : StandardStringOrdinaryResponse.API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.resultKind.type Eff.empty := by
  cases api <;> simp [StandardStringOrdinaryResponse.API.signature, StandardStringOrdinaryResponse.API.inputs,
    StandardStringOrdinaryResponse.API.resultKind, StandardStringOrdinaryResponse.API.names, StandardPureResults.Kind.type,
    PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 実署名の定数・bytes・有限リストの型付けから、両実引数列の等号を得る。 -/
theorem string_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (api : StandardStringOrdinaryResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  apply constant_arguments_equal typed rfl rfl rfl (string_instantiated api) _ _ related
  · cases api <;> simp [StandardStringOrdinaryResponse.API.names, StandardStringOrdinaryResponse.API.inputs, NamesWF]
  · cases api <;> simp [StandardStringOrdinaryResponse.API.inputs, ConstantInputType.base, ConstantInputType.bytes, ConstantInputType.list]

/-- 固定表の実providerは、対応先だけが型付く両入力に同じ応答を返す。 -/
theorem string_provider_delta {P B Ψ source rows ts es rs xs ys a e} (api : StandardStringOrdinaryResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) :
    OptionalOutcomeRel source rows
      ((StandardStringOrdinaryResponse.table StandardModel.signatureBase).delta api.name ts es rs xs)
      ((StandardStringOrdinaryResponse.table StandardModel.signatureBase).delta api.name ts es rs ys) := by
  rw [string_inputs_equal api typed related]
  exact .refl _

private theorem numeric_instantiated (api : StandardNumericRemainingResponse.API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.resultKind.type Eff.empty := by
  cases api <;> simp [StandardNumericRemainingResponse.API.signature, StandardNumericRemainingResponse.API.inputs,
    StandardNumericRemainingResponse.API.resultKind, StandardNumericRemainingResponse.API.names, StandardPureResults.Kind.type,
    PrimSig.tel, signatureTel, instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.bind, Tel.rawBind, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Ty.normTys, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up, substAtoms_nil, instAtoms_nil, rowFails, rawBindTys]

/-- 実署名の定数・bytes・有限リストの型付けから、両実引数列の等号を得る。 -/
theorem numeric_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (api : StandardNumericRemainingResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  apply constant_arguments_equal typed rfl rfl rfl (numeric_instantiated api) _ _ related
  · cases api <;> simp [StandardNumericRemainingResponse.API.names, StandardNumericRemainingResponse.API.inputs, NamesWF]
  · cases api <;> simp [StandardNumericRemainingResponse.API.inputs, ConstantInputType.base]

/-- 固定表の実providerは、対応先だけが型付く両入力に同じ応答を返す。 -/
theorem numeric_provider_delta {P B Ψ source rows ts es rs xs ys a e} (api : StandardNumericRemainingResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) :
    OptionalOutcomeRel source rows
      ((StandardNumericRemainingResponse.table StandardModel.signatureBase).delta api.name ts es rs xs)
      ((StandardNumericRemainingResponse.table StandardModel.signatureBase).delta api.name ts es rs ys) := by
  rw [numeric_inputs_equal api typed related]
  exact .refl _

/-- 公開判定の実署名を持つ対応先から、同じ定数入力列を得る。 -/
theorem public_predicate_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (api : PredicateResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  apply constant_arguments_equal typed rfl rfl rfl (PredicateResponse.instantiated api) _ _ related
  · cases api <;> try (rename_i width test; cases width)
    all_goals simp [PredicateResponse.API.names,PredicateResponse.API.inputs,NamesWF]
  · cases api <;> try (rename_i width test; cases width)
    all_goals simp [PredicateResponse.API.inputs,ConstantInputType.base]

/-- 公開判定の固定出典は、同じ入力に同じBooleanを返す。 -/
theorem public_predicate_provider_delta {P B Ψ source rows ts es rs xs ys a e} (api : PredicateResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) :
    OptionalOutcomeRel source rows
      ((StandardModel.predicateProvider api).delta api.name ts es rs xs)
      ((StandardModel.predicateProvider api).delta api.name ts es rs ys) := by
  rw [public_predicate_inputs_equal api typed related]
  exact .refl _

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation

