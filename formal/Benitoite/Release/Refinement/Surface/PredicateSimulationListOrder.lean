import Benitoite.Release.Refinement.Surface.PredicateSimulationListProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantInputs

/-! # List.sortとList.rangeの固定応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open StandardListRemainingResponse
noncomputable section

private theorem scalar_core {a : Ty} {base} (found : StandardScalar.scalarTypeCore a = some base) :
    a.norm.core = .base base := by
  cases a with
  | base tag => cases found; rfl
  | refined a p => exact (Ty.refined_norm_core a p).trans (scalar_core found)
  | _ => cases found

private theorem ordered_core {a} (ordered : orderedType a) : ∃ base, a.norm.core = .base base := by
  cases found : StandardScalar.scalarTypeCore a with
  | none => simp [orderedType,found] at ordered
  | some base => exact ⟨base,scalar_core found⟩

private theorem scalar_elements_equal {P B Ψ source rows xs ys a base}
    (typed : HasTypeEachQ P B Ψ Qempty [] [] [] ys a) (core : a.norm.core = .base base)
    (related : Values source rows xs ys) : xs = ys := by
  match typed with
  | .nil => cases related; rfl
  | .cons value rest =>
    obtain ⟨c,rfl,_,_⟩ := value.canonical_scalar core
    cases related with
    | cons head tail => rw [head.constant_right,scalar_elements_equal rest core tail]

/-- sortが要求する対応先のscalar型の要素列から、元の列全体との等号を得る。 -/
theorem list_sort_delta {P B Ψ source rows xs ys a}
    (typed : HasTypeEachQ P B Ψ Qempty [] [] [] ys a) (ordered : orderedType a)
    (related : Values source rows xs ys) (type : Ty) :
    OptionalOutcomeRel source rows
      (delta .sort "List.sort" [type] [] [] [.list xs])
      (delta .sort "List.sort" [type] [] [] [.list ys]) := by
  obtain ⟨base,core⟩ := ordered_core ordered
  rw [scalar_elements_equal typed core related]
  exact .refl _

/-- sortは元の列の要素を並べ替えるだけであり、禁止名を作らない。 -/
theorem list_sort_noMint {keys xs} (avoid : ValuesAvoid keys xs) (type : Ty) :
    OptionalOutcomeAvoid keys (delta .sort "List.sort" [type] [] [] [.list xs]) := by
  change OutcomeAvoid keys (sortReply xs)
  unfold sortReply
  split
  · exact ValueAvoid.list (fun value member => avoid value ((List.mergeSort_perm xs _).mem_iff.mp member))
  · trivial

private theorem range_instantiated : instantiatedTel (Tel.instR [] rangeSignature.tel) [] [] =
    Ty.toTel ["start","stop"] [.base .integer,.base .integer] (.list (.base .integer)) Eff.empty := by
  simp [rangeSignature,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,
    Eff.shiftV,shiftVTys,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,rawBindTys]

theorem list_range_delta {P B Ψ source rows ts es rs xs ys a e}
    (typed : BuiltinArgs P B Ψ "List.range" rangeSignature ts es rs ys a e)
    (related : Values source rows xs ys) :
    OptionalOutcomeRel source rows (rangeDelta "List.range" ts es rs xs) (rangeDelta "List.range" ts es rs ys) := by
  have same := constant_arguments_equal typed rfl rfl rfl range_instantiated (by simp [NamesWF])
    (by simp [ConstantInputType.base]) related
  rw [same]
  exact .refl _

theorem list_range_noMint {keys name ts es rs values} :
    OptionalOutcomeAvoid keys (rangeDelta name ts es rs values) := by
  unfold rangeDelta
  split
  · split
    · exact pure_reply_noMint _ _
    · trivial
  · trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
