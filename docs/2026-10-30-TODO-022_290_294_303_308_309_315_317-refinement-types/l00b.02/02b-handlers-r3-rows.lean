import Lean
import Benitoite

namespace Benitoite.Release.Refinement.HandlerRowsR3

def unitTy : Ty := .base .unit
def kTy : Ty := .cont unitTy unitTy Eff.empty
def continuationStore : StoreTy := fun _ => some (.cont unitTy unitTy Eff.empty none)

theorem resumeL {P B Q C Γ Φ L} :
    HasTypeCQ P B continuationStore Q C Γ Φ none (.resume (.loc 0) (.const .unit)) unitTy Eff.empty L :=
  .C_ResumeL rfl (.V_Const trivial) trivial

theorem wrong_R_rejected {P B Q C Γ Φ t e L} :
    ¬ HasTypeCQ P B continuationStore Q C Γ Φ (some (.base .boolean))
      (.resume (.loc 0) (.const .unit)) t e L := by
  intro h
  obtain ⟨b,t,e,hl⟩ := h.resume_location_contract
  simp [continuationStore] at hl

theorem resumeVar {P B Ψ Q C Φ L R} :
    HasTypeCQ P B Ψ Q C [some kTy] Φ R (.resume (.var 0) (.const .unit)) unitTy Eff.empty L :=
  .C_Resume rfl (.V_Const trivial) trivial

theorem var_image {P B Ψ Q C Φ R} :
    ImageOk P B Ψ Q C [none,some kTy] Φ R (fun _ => .var 1) 0 kTy :=
  .contVar rfl rfl (by rw [Ty.subst_values_of_wf_zero (show kTy.WF 0 0 0 from ⟨trivial,trivial,trivial,rfl⟩)]; rfl)

theorem loc_image {P B Q C Φ} :
    ImageOk P B continuationStore Q C [] Φ none (fun _ => .loc 0) 0 kTy := by
  have hw : kTy.WF 0 0 0 := ⟨trivial,trivial,trivial,rfl⟩
  refine .contLoc (b' := unitTy) (t' := unitTy) (e' := Eff.empty) rfl
    (Ty.subst_values_of_wf_zero hw _) ?_ rfl rfl (by intros; contradiction)
  rw [Ty.subst_values_of_wf_zero hw]; exact hw

theorem resume_substituted {P B Q C} (hA : Builtins.SubstitutionAssumptions P B) :
    HasTypeCQ P B continuationStore Q C [] [] none (.resume (.loc 0) (.const .unit)) unitTy Eff.empty [] := by
  have hw : continuationStore.WF := by
    intro l t ht
    cases ht
    exact ⟨trivial,trivial,trivial,rfl,by intros; contradiction⟩
  have ht : SubstOk P B continuationStore Q C [some kTy] [] [] [] none (fun _ => .loc 0) := by
    intro i a hi
    cases i with
    | zero => cases hi; exact loc_image
    | succ i => simp at hi
  have hh := (resumeVar (P := P) (B := B) (Ψ := continuationStore) (Q := Q) (C := C)
    (Φ := []) (L := []) (R := none)).subst (L' := []) hA hw ht (by simp) LocalRef.bound (.empty _ _ _ _)
  simpa only [Comp.subst,Val.subst,Option.map_none,substEffValues_empty,unitTy,substTyValues,Ty.bind,Ty.rawBind,Ty.norm] using hh

theorem empty_images (P B Ψ Q C Φ Δ Ξ R ν) :
    SubstOk P B Ψ Q C [] Φ Δ Ξ R ν := by intro i a hi; simp at hi

theorem none_position (Γ : Ctx) (E : Ty) : (failureContext Γ E)[0]?=some none := rfl

theorem error_position (Γ : Ctx) (E : Ty) :
    (failureContext Γ E)[1]?=some (some ((shiftTypes 1 0 E).shiftV 2 0)) := by
  simp [failureContext,Ctx.extendNone,Ctx.extend,Ty.shiftV_add]

def dependentSig : OpSig :=
  ⟨[TParam.keyC],["x","y"],[.base .integer,.refined (.base .integer) (.eq (.var 0) (.var 1))],
    .refined (.base .integer) (.eq (.var 0) (.var 2)),"Effect"⟩

theorem dependent_local_wf : dependentSig.WF := by
  refine ⟨⟨trivial,⟨?_,trivial⟩⟩,?_⟩ <;>
    simp [dependentSig,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]

theorem poly_outer_position :
    (dependentSig.context [some (.set (.tvar 0))] unitTy Eff.empty)[3]?=
      some (some (.set (.tvar 1))) := rfl

theorem continuation_position (Γ : Ctx) (t : Ty) (e : Eff) :
    (dependentSig.context Γ t e)[0]?=some (some ((dependentSig.continuation t e).shiftV 1 0)) := rfl

theorem all_clause_facts (Φ : List Pred) : liftMany (dependentSig.params.length+1) Φ=Φ.map (Pred.shiftV 3 0) :=
  liftMany_eq _ _

def typeImage : Val := .lam ["z"] [.tvar 0] (.ret (.var 0))

theorem poly_subst_syntax :
    Clause.substList (fun _ => typeImage) [.mk (.user "op") 2 1 (.ret (.var 3))] LocalRef.bound =
      [.mk (.user "op") 2 1 (.ret (.lam ["z"] [.tvar 1] (.ret (.var 0))))] := rfl

theorem failure_subst_syntax :
    Clause.substList (fun _ => typeImage) [.fail unitTy (.ret (.var 2))] LocalRef.bound =
      [.fail unitTy (.ret (.lam ["z"] [.tvar 1] (.ret (.var 0))))] := rfl

def fact : Pred := .eq (.var 0) (.integer 7)

theorem guard_fact_kept (Γ : Ctx) :
    Entails ((hideConts (bindParams Γ [unitTy])).facts++liftMany 1 [fact]) (.eq (.var 1) (.integer 7)) := by
  exact .hyp (List.mem_append_right _ (by simp [liftMany_eq,fact,Pred.shiftV,predBind,termBind,termBind?,shiftIndex]))

theorem clause_fact_kept (Γ : Ctx) :
    Entails ((dependentSig.context Γ unitTy Eff.empty).facts++liftMany 3 [fact]) (.eq (.var 3) (.integer 7)) := by
  exact .hyp (List.mem_append_right _ (by simp [liftMany_eq,fact,Pred.shiftV,predBind,termBind,termBind?,shiftIndex]))

theorem fail_fact_kept (Γ : Ctx) :
    Entails ((failureContext Γ unitTy).facts++liftMany 2 [fact]) (.eq (.var 2) (.integer 7)) := by
  exact .hyp (List.mem_append_right _ (by simp [liftMany_eq,fact,Pred.shiftV,predBind,termBind,termBind?,shiftIndex]))

theorem standard_fields (P B Ψ Q C Γ Φ) (detail : AtError) :
    ∃ vs,matchVal atErrorPattern (.atError detail)=some vs ∧ HasTypeVsQ P B Ψ Q C Γ Φ vs atErrorFields :=
  detail.match_pattern_typed P B Ψ Q C Γ Φ

theorem standard_exhaustive {P shape cs} (hs : ResultShape.StandardError P shape)
    (hc : P.StandardErrorComplete cs) : Exhaustive P atErrorType (atErrorPatterns cs) := .atError hs hc

theorem pathBases_clause {P B b s eb} (h : Builtins.CoreAssumptions P B)
    (hl : B.sig b=some s) (hk : s.kind=.pathBases) :
    ∃ sg,ClauseSig P B eb (.prim b) sg ∧ sg.tparams=[] ∧ sg.params=[] ∧ sg.ret=.pathBases ∧ sg.WF :=
  h.pathBases_clause_signature hl hk

#check HasTypeArmsQ.guarded
#check HasTypeClausesQ.cons
#check HasFailureClause.one
#check HasTypeArmsQ.subst
#check HasTypeClausesQ.subst
#check HasFailureClause.subst
#check HasTypeCQ.subst_under_none
#check HasTypeArmsQ.subst_under_none
#check HasTypeClausesQ.subst_under_none
#check HasFailureClause.subst_under_none
#check SubstOk.up
#check SubstOk.upN
#check SubstOk.shiftE
#check SubstOk.handler_clause
#check SubstOk.handler_failure
#check ImageOk.narrow

end Benitoite.Release.Refinement.HandlerRowsR3

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := env.constants.toList.filterMap fun (name, _) =>
    if (`Benitoite.Release.Refinement.HandlerRowsR3).isPrefixOf name then some name else none
  let names := names.mergeSort (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
