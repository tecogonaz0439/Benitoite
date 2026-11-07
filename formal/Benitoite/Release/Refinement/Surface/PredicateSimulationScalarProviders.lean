import Benitoite.Release.Refinement.Surface.PredicateSimulationResponses
import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantResults

/-! # 定数を受ける固定providerの型付き入力と応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem base_values_equal {P B Ψ source rows xs ys types}
    (typed : HasTypeVsQ P B Ψ Qempty [] [] [] ys types)
    (bases : ∀ type ∈ types, ∃ tag, type = .base tag)
    (related : Values source rows xs ys) : xs = ys := by
  match typed with
  | .nil => cases related; rfl
  | .cons value rest =>
    obtain ⟨tag, same⟩ := bases _ List.mem_cons_self
    subst same
    obtain ⟨constant, same, _, _⟩ := value.canonical_scalar rfl
    subst same
    cases related with
    | cons head tail =>
      rw [head.constant_right,
        base_values_equal rest (fun type member => bases type (List.mem_cons_of_mem _ member)) tail]

private theorem scalar_instantiated (api : StandardScalarResponse.API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.result Eff.empty := by
  cases api <;> simp [StandardScalarResponse.API.signature, StandardScalarResponse.API.inputs,
    StandardScalarResponse.API.result, StandardScalarResponse.API.names, PrimSig.tel, signatureTel,
    instantiatedTel, Tel.instR, Tel.substRAt, Tel.mapRanges,
    Tel.bind, Tel.rawBind, Ty.rawBind, rawBindTys, Eff.rawBind,
    Tel.norm, Ty.norm, Ty.normTys, Eff.norm, Eff.empty, typeEnvAt, SubstEnv.up,
    substAtoms_nil, instAtoms_nil, rowFails, Ty.toTel, Ty.shiftV, Eff.shiftV, shiftVTys]

private theorem scalar_arguments {P B Ψ ts es rs ys a e} (api : StandardScalarResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ HasTypeVsQ P B Ψ Qempty [] [] [] ys api.inputs := by
  have types : ts = [] := List.length_eq_zero_iff.mp typed.admissible.typeCount
  have effects : es = [] := List.length_eq_zero_iff.mp typed.admissible.rowCount
  have ranges : rs = [] := List.length_eq_zero_iff.mp typed.ranges.1
  subst ts; subst es; subst rs
  have arguments := typed.arguments
  rw [scalar_instantiated] at arguments
  have names : NamesWF api.names api.inputs := by
    cases api <;> simp [StandardScalarResponse.API.names, StandardScalarResponse.API.inputs, NamesWF]
  obtain ⟨values, _, _⟩ := arguments.toTelValues names
  have normal : Ty.normTys api.inputs = api.inputs := by cases api <;> rfl
  exact ⟨rfl, rfl, rfl, normal ▸ values⟩

/-- 対応先の十三行の型付き実引数から、元の実引数列が同じ定数列であることを得る。 -/
theorem scalar_inputs_equal {P B Ψ source rows ts es rs xs ys a e} (api : StandardScalarResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨_, _, _, values⟩ := scalar_arguments api typed
  apply base_values_equal values _ related
  cases api <;> simp [StandardScalarResponse.API.inputs, List.mem_cons, List.not_mem_nil]

theorem scalar_reply_noMint {P B Ψ keys ts es rs values out a e} (api : StandardScalarResponse.API)
    (options : StandardActualListBodies.ListOptionDeclarations P) (valid : P.VarianceValid)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs values a e)
    (reply : Outcome.Typed P B Ψ out a) : OutcomeAvoid keys out := by
  apply constant_arguments_result_noMint options valid typed rfl rfl rfl (scalar_instantiated api) _ _ reply
  · cases api <;> simp [StandardScalarResponse.API.names,StandardScalarResponse.API.inputs,NamesWF]
  · cases api <;> simp [StandardScalarResponse.API.result,ConstantResultType.base,ConstantResultType.option]

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
