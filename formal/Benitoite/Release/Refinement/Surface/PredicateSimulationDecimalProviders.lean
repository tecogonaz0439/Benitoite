import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationResponses
import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantResults

/-! # Decimalの固定署名と、標準の丸め方式を持つ入力 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem nullary_equal {source rows x c types} (related : Value source rows x (.con c types [])) :
    x = .con c types [] := by
  cases related with
  | con children => cases children; rfl

private theorem rounding_equal {P B Ψ source rows x y} (declarations : StandardDecimalResponse.Declarations P)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] y (.data "RoundingMode" []))
    (related : Value source rows x y) : x = y := by
  rcases typed.canonical_data rfl with ⟨c,types,values,rfl⟩ | ⟨detail,rfl⟩
  · obtain ⟨cd,found,count,_,_,fields,us,tag,_⟩ := typed.inv_con rfl
    obtain ⟨rfl,mode,rfl⟩ := declarations.modes c cd found (Ty.data.inj tag).1.symm
    have empty : types = [] := List.length_eq_zero_iff.mp count
    subst types
    cases fields
    exact nullary_equal related
  · obtain ⟨shape,declared,tag⟩ := typed.inv_atError rfl
    rw [declared.errorType_eq] at tag
    exact False.elim ((by decide : ("RoundingMode" : String) ≠ "Scope.ScopeError") (Ty.data.inj tag).1)

private theorem decimal_instantiated (api : StandardDecimalResponse.API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.result Eff.empty := by
  cases api <;> simp [StandardDecimalResponse.API.signature,StandardDecimalResponse.API.names,
    StandardDecimalResponse.API.inputs,StandardDecimalResponse.API.result,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys,Eff.norm,Eff.empty,typeEnvAt,
    SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,rawBindTys]

/-- 対応先の型付き入力と、標準表が持つ丸め方式の宣言から同じ実引数列を得る。 -/
theorem decimal_inputs_equal {P B Ψ source rows ts es rs xs ys a e}
    (declarations : StandardDecimalResponse.Declarations P) (api : StandardDecimalResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  have named : NamesWF api.names api.inputs := by
    cases api <;> simp [StandardDecimalResponse.API.names,StandardDecimalResponse.API.inputs,NamesWF]
  have normal : Ty.normTys api.inputs = api.inputs := by cases api <;> rfl
  have values := monomorphic_arguments_values typed rfl rfl rfl (decimal_instantiated api) named normal
  cases api with
  | round =>
    cases values with | cons number rest => cases rest with | cons places rest => cases rest with | cons mode rest =>
      cases rest
      cases related with | cons numberRel restRel => cases restRel with | cons placesRel restRel => cases restRel with | cons modeRel restRel =>
        cases restRel
        rw [constant_input_equal (.base _) number numberRel,
          constant_input_equal (.base _) places placesRel,rounding_equal declarations mode modeRel]
  | absolute | fromInteger | toDecimal | truncate | fromDecimal =>
    apply constant_values_equal values _ related
    simp [StandardDecimalResponse.API.inputs,ConstantInputType.base]

theorem decimal_reply_noMint {P B Ψ keys ts es rs values out a e} (api : StandardDecimalResponse.API)
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  apply constant_arguments_result_noMint options valid typed rfl rfl rfl (decimal_instantiated api) _ _ reply
  · cases api <;> simp [StandardDecimalResponse.API.names,StandardDecimalResponse.API.inputs,NamesWF]
  · cases api <;> simp [StandardDecimalResponse.API.result,ConstantResultType.base,ConstantResultType.option]

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
