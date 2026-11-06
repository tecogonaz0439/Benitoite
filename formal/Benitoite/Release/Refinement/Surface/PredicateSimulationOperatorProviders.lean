import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationResponses

/-! # 固定演算子・Byte.toString・Bytes変換の実入力 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem operator_arguments_equal {P B Ψ source rows name ts es rs xs ys a e}
    (input output : BaseTy) (unary : Bool)
    (typed : BuiltinArgs P B Ψ name (StandardOperatorArguments.signature input output unary) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨_,_,_,_,_,values⟩ := StandardOperatorArguments.arguments input output unary typed
  apply constant_values_equal values _ related
  cases unary <;> simp [ConstantInputType.base]

private theorem operator_arguments_noMint {P B Ψ keys name ts es rs values out a e}
    (input output : BaseTy) (unary : Bool)
    (typed : BuiltinArgs P B Ψ name (StandardOperatorArguments.signature input output unary) ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  obtain ⟨_,_,_,result,_,_⟩ := StandardOperatorArguments.arguments input output unary typed
  subst a
  exact constant_outcome_noMint (.base _) reply

/-- 演算子の34行は、対応先の型付き実引数から同じ定数入力列を得る。 -/
theorem operator_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (entry : StandardOperatorResponse.Entry)
    (typed : BuiltinArgs P B Ψ entry.name entry.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  cases entry with
  | integer kind modulo =>
    exact operator_arguments_equal (StandardIntegerOperatorResponse.base kind)
      (StandardIntegerOperatorResponse.base kind) false typed related
  | floating single api =>
    exact operator_arguments_equal (StandardFloatOperatorResponse.base single)
      (StandardFloatOperatorResponse.base single) (api = .negate) typed related
  | decimal api => exact operator_arguments_equal .decimal .decimal (api = .negate) typed related
  | string api => exact operator_arguments_equal .string (StandardStringOperatorResponse.result api) false typed related

theorem operator_reply_noMint {P B Ψ keys ts es rs values out a e} (entry : StandardOperatorResponse.Entry)
    (typed : BuiltinArgs P B Ψ entry.name entry.signature ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  cases entry with
  | integer kind modulo =>
    exact operator_arguments_noMint (StandardIntegerOperatorResponse.base kind)
      (StandardIntegerOperatorResponse.base kind) false typed reply
  | floating single api =>
    exact operator_arguments_noMint (StandardFloatOperatorResponse.base single)
      (StandardFloatOperatorResponse.base single) (api = .negate) typed reply
  | decimal api => exact operator_arguments_noMint .decimal .decimal (api = .negate) typed reply
  | string api => exact operator_arguments_noMint .string (StandardStringOperatorResponse.result api) false typed reply

private theorem byte_string_instantiated :
    instantiatedTel (Tel.instR [] StandardByteStringResponse.signature.tel) [] [] =
      Ty.toTel ["b"] [.base .byte] (.base .string) Eff.empty := by
  simp [StandardByteStringResponse.signature,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails]

theorem byte_string_inputs_equal {P B Ψ source rows ts es rs xs ys a e}
    (typed : BuiltinArgs P B Ψ "Byte.toString" StandardByteStringResponse.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  exact constant_arguments_equal typed rfl rfl rfl byte_string_instantiated
    (by simp [NamesWF]) (by simp [ConstantInputType.base]) related

theorem byte_string_reply_noMint {P B Ψ keys ts es rs values out a e}
    (typed : BuiltinArgs P B Ψ "Byte.toString" StandardByteStringResponse.signature ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  have result := monomorphic_result_eq typed rfl rfl rfl byte_string_instantiated (by simp [NamesWF]) rfl
  subst a
  exact constant_outcome_noMint (.base _) reply

private theorem bytes_instantiated (api : StandardBytesResponse.API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.result Eff.empty := by
  cases api <;> simp [StandardBytesResponse.API.signature,StandardBytesResponse.API.names,
    StandardBytesResponse.API.inputs,StandardBytesResponse.API.result,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys,Eff.norm,Eff.empty,typeEnvAt,
    SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,rawBindTys]

theorem bytes_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (api : StandardBytesResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  apply constant_arguments_equal typed rfl rfl rfl (bytes_instantiated api) _ _ related
  · cases api <;> simp [StandardBytesResponse.API.names,StandardBytesResponse.API.inputs,NamesWF]
  · cases api <;> simp [StandardBytesResponse.API.inputs,ConstantInputType.base,ConstantInputType.bytes,ConstantInputType.list]

theorem bytes_reply_noMint {P B Ψ keys ts es rs values out a e} (api : StandardBytesResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  have named : NamesWF api.names api.inputs := by
    cases api <;> simp [StandardBytesResponse.API.names,StandardBytesResponse.API.inputs,NamesWF]
  have normal : api.result.norm = api.result := by cases api <;> rfl
  have result := monomorphic_result_eq typed rfl rfl rfl (bytes_instantiated api) named normal
  subst a
  apply constant_outcome_noMint _ reply
  cases api <;> simp [StandardBytesResponse.API.result,ConstantInputType.base,ConstantInputType.bytes,ConstantInputType.list]

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
