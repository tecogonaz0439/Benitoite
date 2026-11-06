import Benitoite.Release.Refinement.Surface.PredicateSimulationListOrder

/-! # 固定したList署名の対応先の型付き入力と、元の応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

local macro "ordinaryArgumentsImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardListResponse
    `Benitoite.Release.Refinement.StandardListResponse.arguments))
local macro "remainingArgumentsImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardListRemainingResponse
    `Benitoite.Release.Refinement.StandardListRemainingResponse.arguments))
local macro "remainingDispatchImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardListRemainingResponse
    `Benitoite.Release.Refinement.StandardListRemainingResponse.dispatch_name))
local macro "optionSignatureImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardHeadTailResponse
    `Benitoite.Release.Refinement.StandardHeadTail.optionSignature))
local macro "optionTelImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardHeadTailResponse
    `Benitoite.Release.Refinement.StandardHeadTail.option_tel))
local macro "appendTelImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardHeadTailResponse
    `Benitoite.Release.Refinement.StandardHeadTail.append_tel))
local macro "frontTelImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.StandardSafeAccess
    `Benitoite.Release.Refinement.StandardSafe.front_tel))

/-- 実署名の対応先の型付き引数から、通常List行の実応答と禁止名不在を得る。 -/
theorem ordinary_list_response {P B Ψ source rows keys ts es rs xs ys r e} (api : StandardListResponse.API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys r e)
    (related : Values source rows xs ys) (avoid : ValuesAvoid keys xs) :
    OptionalOutcomeRel source rows
      ((StandardListResponse.table StandardModel.signatureBase).delta api.name ts es rs xs)
      ((StandardListResponse.table StandardModel.signatureBase).delta api.name ts es rs ys) ∧
      OptionalOutcomeAvoid keys ((StandardListResponse.table StandardModel.signatureBase).delta api.name ts es rs xs) := by
  obtain ⟨a,rfl,rfl,rfl,ann,normal,_ordinary,values,_result,_effect⟩ := ordinaryArgumentsImpl api typed
  cases api with
  | length | isEmpty | reverse =>
    cases values with | cons first rest =>
      cases rest
      obtain ⟨ys,_,rfl,_,_⟩ := first.canonical_list rfl
      cases related with | cons head tail =>
        cases tail
        cases head with | list children =>
          have sourceAvoid := (ValuesAvoid.cons.mp avoid).1.list_inv
          first
          | exact ⟨list_length_delta children a,list_length_noMint a⟩
          | exact ⟨list_empty_delta children a,list_empty_noMint a⟩
          | exact ⟨list_reverse_delta children a,list_reverse_noMint sourceAvoid a⟩
  | prepend | append =>
    cases values with | cons first rest => cases rest with | cons second rest =>
      cases rest
      obtain ⟨ys,_,rfl,_,_⟩ := first.canonical_list rfl
      cases related with | cons head tail => cases tail with | cons element tail =>
        cases tail
        cases head with | list children =>
          have sourceAvoid := (ValuesAvoid.cons.mp avoid).1.list_inv
          have elementAvoid := (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp avoid).2).1
          first
          | exact ⟨list_insert_delta children element false a,list_insert_noMint sourceAvoid elementAvoid false a⟩
          | exact ⟨list_insert_delta children element true a,list_insert_noMint sourceAvoid elementAvoid true a⟩
  | concatenate =>
    cases values with | cons first rest => cases rest with | cons second rest =>
      cases rest
      obtain ⟨ys,_,rfl,_,_⟩ := first.canonical_list rfl
      obtain ⟨zs,_,rfl,_,_⟩ := second.canonical_list rfl
      cases related with | cons head tail => cases tail with | cons second tail =>
        cases tail
        cases head with | list left => cases second with | list right =>
          exact ⟨list_concatenate_delta left right a,
            list_concatenate_noMint (ValuesAvoid.cons.mp avoid).1.list_inv
              (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp avoid).2).1.list_inv a⟩

private theorem remaining_table_delta (api : StandardListRemainingResponse.API) (base : Builtins) :
    (StandardListRemainingResponse.table base).delta api.name = StandardListRemainingResponse.delta api api.name := by
  funext ts es rs values
  have different : api.name ≠ "List.range" := by cases api <;> decide
  simp only [StandardListRemainingResponse.table,ite_eq_right different,remainingDispatchImpl api,Option.bind_some]

theorem remaining_list_response {P B Ψ source rows keys ts es rs xs ys r e} (api : StandardListRemainingResponse.API)
    (typed : BuiltinArgs P B Ψ api.name (api.signature B.sat) ts es rs ys r e)
    (related : Values source rows xs ys) (avoid : ValuesAvoid keys xs) :
    OptionalOutcomeRel source rows
      ((StandardListRemainingResponse.table StandardModel.signatureBase).delta api.name ts es rs xs)
      ((StandardListRemainingResponse.table StandardModel.signatureBase).delta api.name ts es rs ys) ∧
      OptionalOutcomeAvoid keys ((StandardListRemainingResponse.table StandardModel.signatureBase).delta api.name ts es rs xs) := by
  rw [remaining_table_delta]
  obtain ⟨a,rfl,rfl,rfl,ann,normal,_ordinary,_kinded,values,_result,_effect⟩ := remainingArgumentsImpl api typed
  cases api with
  | head | tail | sort =>
    cases values with | cons first rest =>
      cases rest
      obtain ⟨ys,rfl,each⟩ := StandardHeadTail.list_elements first ann
      cases related with | cons head tail =>
        cases tail
        cases head with | list children =>
          have sourceAvoid := (ValuesAvoid.cons.mp avoid).1.list_inv
          first
          | exact ⟨list_head_delta children a,list_head_noMint sourceAvoid a⟩
          | exact ⟨list_tail_delta children a,list_tail_noMint sourceAvoid a⟩
          | exact ⟨list_sort_delta each (typed.admissible.admits.2.2 rfl a (by simp [normal])) children a,list_sort_noMint sourceAvoid a⟩
  | get | take | drop =>
    cases values with | cons first rest => cases rest with | cons index rest =>
      cases rest
      obtain ⟨ys,_,rfl,_,_⟩ := first.canonical_list rfl
      obtain ⟨c,rfl,_,tag⟩ := index.canonical_scalar rfl
      cases c <;> cases tag
      rename_i number valid
      cases related with | cons head tail => cases tail with | cons index tail =>
        cases tail
        cases head with | list children =>
          cases index
          have sourceAvoid := (ValuesAvoid.cons.mp avoid).1.list_inv
          first
          | exact ⟨list_get_delta children a number,list_get_noMint sourceAvoid a number⟩
          | exact ⟨list_take_delta children a number,list_take_noMint sourceAvoid a number⟩
          | exact ⟨list_drop_delta children a number,list_drop_noMint sourceAvoid a number⟩
  | contains =>
    cases values with | cons first rest => cases rest with | cons second rest =>
      cases rest
      obtain ⟨ys,_,rfl,_,_⟩ := first.canonical_list rfl
      cases related with | cons head tail => cases tail with | cons element tail =>
        cases tail
        cases head with | list children =>
          exact ⟨list_contains_delta children element a,list_contains_noMint a⟩

theorem head_tail_response {P B Ψ source rows keys ts es rs xs ys r e} (tail : Bool)
    (typed : BuiltinArgs P B Ψ (if tail then "List.tail" else "List.head")
      (if tail then StandardHeadTail.tailSignature else StandardHeadTail.headSignature) ts es rs ys r e)
    (related : Values source rows xs ys) (avoid : ValuesAvoid keys xs) :
    OptionalOutcomeRel source rows
      (StandardHeadTail.builtins.delta (if tail then "List.tail" else "List.head") ts es rs xs)
      (StandardHeadTail.builtins.delta (if tail then "List.tail" else "List.head") ts es rs ys) ∧
      OptionalOutcomeAvoid keys (StandardHeadTail.builtins.delta (if tail then "List.tail" else "List.head") ts es rs xs) := by
  have count : ts.length = 1 := by cases tail <;> exact typed.admissible.typeCount
  obtain ⟨a,rfl⟩ := List.length_eq_one_iff.mp count
  have effects : es = [] := List.length_eq_zero_iff.mp (by cases tail <;> exact typed.admissible.rowCount)
  have ranges : rs = [] := List.length_eq_zero_iff.mp (by cases tail <;> exact typed.ranges.1)
  subst es; subst rs
  have ann := typed.signature.types a (by simp)
  have normal := (typed.types a (by simp)).2
  have arguments := typed.arguments
  change HasTypeTelArgsQ P B Ψ Qempty [] [] [] ys
    (instantiatedTel (Tel.instR [] (optionSignatureImpl tail).tel) [a] []) r e at arguments
  rw [optionTelImpl tail ann.wf,normal] at arguments
  cases arguments with | param _ first rest =>
    obtain ⟨ys,_,rfl,_,_⟩ := first.canonical_list rfl
    cases rest
    cases related with | cons head rest =>
      cases rest
      cases head with | list children =>
        have sourceAvoid := (ValuesAvoid.cons.mp avoid).1.list_inv
        cases tail
        · exact ⟨list_head_delta children a,list_head_noMint sourceAvoid a⟩
        · exact ⟨list_tail_delta children a,list_tail_noMint sourceAvoid a⟩

theorem refined_append_response {P B Ψ source rows keys ts es rs xs ys r e}
    (typed : BuiltinArgs P B Ψ "List.append" StandardHeadTail.appendSignature ts es rs ys r e)
    (related : Values source rows xs ys) (avoid : ValuesAvoid keys xs) :
    OptionalOutcomeRel source rows (StandardHeadTail.builtins.delta "List.append" ts es rs xs)
      (StandardHeadTail.builtins.delta "List.append" ts es rs ys) ∧
      OptionalOutcomeAvoid keys (StandardHeadTail.builtins.delta "List.append" ts es rs xs) := by
  obtain ⟨a,rfl⟩ := List.length_eq_one_iff.mp typed.admissible.typeCount
  have effects : es = [] := List.length_eq_zero_iff.mp typed.admissible.rowCount
  have ranges : rs = [] := List.length_eq_zero_iff.mp typed.ranges.1
  subst es; subst rs
  have ann := typed.signature.types a (by simp)
  have normal := (typed.types a (by simp)).2
  have arguments := typed.arguments
  rw [appendTelImpl ann.wf,normal] at arguments
  cases arguments with | param _ first rest =>
    obtain ⟨ys,_,rfl,_,_⟩ := first.canonical_list rfl
    cases rest with | param _ second rest =>
      cases rest
      cases related with | cons head rest => cases rest with | cons element rest =>
        cases rest
        cases head with | list children =>
          exact ⟨list_insert_delta children element true a,
            list_insert_noMint (ValuesAvoid.cons.mp avoid).1.list_inv
              (ValuesAvoid.cons.mp (ValuesAvoid.cons.mp avoid).2).1 true a⟩

theorem safe_front_response {P B Ψ source rows keys ts es rs xs ys r e}
    (typed : BuiltinArgs P B Ψ "%List.getFront" StandardSafe.frontSig ts es rs ys r e)
    (related : Values source rows xs ys) (avoid : ValuesAvoid keys xs) :
    OptionalOutcomeRel source rows (StandardSafe.builtins.delta "%List.getFront" ts es rs xs)
      (StandardSafe.builtins.delta "%List.getFront" ts es rs ys) ∧
      OptionalOutcomeAvoid keys (StandardSafe.builtins.delta "%List.getFront" ts es rs xs) := by
  obtain ⟨a,rfl⟩ := List.length_eq_one_iff.mp typed.admissible.typeCount
  have effects : es = [] := List.length_eq_zero_iff.mp typed.admissible.rowCount
  have ranges : rs = [] := List.length_eq_zero_iff.mp typed.ranges.1
  subst es; subst rs
  have ann := typed.signature.types a (by simp)
  have arguments := typed.arguments
  rw [frontTelImpl ann.wf] at arguments
  cases arguments with | param _ first rest =>
    obtain ⟨ys,_,rfl,_,_⟩ := first.canonical_list rfl
    cases rest with | param _ index done =>
      obtain ⟨c,rfl,_,tag⟩ := index.canonical_scalar rfl
      cases c <;> cases tag
      rename_i number valid
      cases done
      cases related with | cons head rest => cases rest with | cons index rest =>
        cases rest
        cases head with | list children =>
          cases index
          exact ⟨list_front_delta children a number,list_front_noMint (ValuesAvoid.cons.mp avoid).1.list_inv a number⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
