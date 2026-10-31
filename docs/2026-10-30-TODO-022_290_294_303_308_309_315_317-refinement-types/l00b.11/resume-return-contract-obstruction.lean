import Lean
import Benitoite.Release.Refinement.SubstTyping

/-! 継続の格納型の生の R と、型付けが読む R の正規形の境界。 -/
namespace Benitoite.Release.Refinement.ResumeReturnBoundary
noncomputable section
abbrev U : Ty := .base .unit
abbrev raw : Ty := .refined U .truth
abbrev storedR : Option Ty := some raw
abbrev normalR : Option Ty := some U

def prog : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none,
    sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def store : StoreTy := fun _ => some (.cont U U Eff.empty storedR)

theorem assumptions : Builtins.SubstitutionAssumptions prog builtins := by
  constructor <;> constructor <;> intros <;> simp_all [builtins]

theorem store_wf : store.WF := by
  intro l t ht
  cases Option.some.inj ht
  refine ⟨trivial,trivial,trivial,rfl,?_⟩
  intro r hr
  cases Option.some.inj hr
  exact ⟨trivial,trivial,by simp [Ty.NotContCore,Ty.core]⟩

theorem source_typed : HasTypeCQ prog builtins store Qempty [] [] [] storedR
    (.resume (.loc 0) (.const .unit)) U Eff.empty [] :=
  .C_ResumeL rfl (.V_Const trivial) trivial

theorem normalized_return_typed : HasTypeCQ prog builtins store Qempty [] [] [] normalR
    (.resume (.loc 0) (.const .unit)) U Eff.empty [] := by
  apply HasTypeCQ.C_ResumeLNorm (R := normalR) (R' := storedR) (b := U) (t := U) (ε := Eff.empty) rfl rfl
  · exact .V_Const trivial
  · trivial

theorem exact_return_lookup_false :
    ¬ ∃ b t e, store 0 = some (.cont b t e normalR) := by
  rintro ⟨b,t,e,he⟩
  have hr := (LocTy.cont.inj (Option.some.inj he)).2.2.2
  cases hr

/-- 元の resume_location_contract の結論は、型付け・WF のある入力でも偽。 -/
theorem old_resume_location_contract_false :
    store.WF ∧ HasTypeCQ prog builtins store Qempty [] [] [] normalR
      (.resume (.loc 0) (.const .unit)) U Eff.empty [] ∧
      ¬ ∃ b t e, store 0 = some (.cont b t e normalR) :=
  ⟨store_wf,normalized_return_typed,exact_return_lookup_false⟩

/-- 正規化した R は、新しい規則だけでなく元の置換主定理の結論にも現れる。 -/
theorem full_substitution_entry : HasTypeCQ prog builtins store Qempty [] [] [] normalR
    (.resume (.loc 0) (.const .unit)) U Eff.empty [] := by
  have hs : SubstOk prog builtins store Qempty [] [] [] [] [] normalR Val.var := by
    intro i a hi; cases hi
  have hf : ∀ p ∈ ([] : List Pred), Entails ([] : List Pred) (predBind (valEnv Val.var).values p) := by
    intro p hp; cases hp
  have hh := source_typed.subst (L' := []) assumptions store_wf hs hf LocalRef.bound (.empty _ _ _ _)
  simpa [storedR,normalR,raw,U,Comp.subst,Val.subst,substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Ty.refineNorm,Ty.packRefinements,Ty.core,Ty.refinementPredicates,Pred.conjuncts,valEnv,predBind] using hh

end
end Benitoite.Release.Refinement.ResumeReturnBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (name, _) in env.constants.toList do
    if (name.toString.splitOn ".ResumeReturnBoundary.").length > 1 then
      elabCommand (← `(#print axioms $(mkIdent name)))
