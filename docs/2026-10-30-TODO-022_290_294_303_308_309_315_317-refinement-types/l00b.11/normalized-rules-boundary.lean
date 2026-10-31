import Lean
import Benitoite.Release.Refinement.ClosureTyping
import Benitoite.Release.Refinement.Narrowing

namespace Benitoite.Release.Refinement.NormalizedRulesBoundary
noncomputable section
abbrev U : Ty := .base .unit
abbrev badPred : Pred := .eq (.integer 0) (.boolean false)
abbrev bad : Ty := .refined U badPred
abbrev raw : Ty := .refined bad .truth

theorem raw_wf (nv : Nat) : raw.WF 0 0 nv := by
  simp [raw,bad,badPred,U,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]

theorem raw_declared (P : Program) (Γ : Ctx) : Ty.Declared P [] Γ raw := by
  trivial

theorem normal_not_sorted (Γ : Ctx) : ¬ raw.norm.Sorted Γ := by
  simp [raw,bad,badPred,U,Ty.norm,Ty.refineNorm,Ty.core,Ty.refinementPredicates,
    Ty.packRefinements,Pred.conjuncts,Pred.ofConjuncts,Ty.Sorted,Pred.Sorted,
    Term.HasSort,Term.Shape,Term.References,Term.VarsIn]

theorem raw_not_sorted (Γ : Ctx) : ¬ raw.Sorted Γ := by
  intro h
  exact normal_not_sorted Γ (Ty.sorted_norm h)

/-- V_Sub の要求する Sorted がない、元の V_Var の正規化。 -/
theorem value_normal_entry (P : Program) (B : Builtins) :
    HasTypeVQ P B StoreTy.empty Qempty [] [some raw] [] (.var 0) raw.norm :=
  (HasTypeVQ.V_Var rfl (by simp [Ty.Ordinary,Ty.core])).V_Normal

/-- C_Sub の要求する Sorted がない、再開結果の正規化。 -/
theorem comp_normal_entry (P : Program) (B : Builtins) :
    HasTypeCQ P B StoreTy.empty Qempty [] [some (.cont U raw Eff.empty)] [] none
      (.resume (.var 0) (.const .unit)) raw.norm Eff.empty [] := by
  apply HasTypeCQ.C_Normal
  exact .C_Resume rfl (.V_Const trivial) (raw_declared P _)

abbrev resumeContext : Ctx := [some (.cont raw U Eff.empty),some raw.norm]

/-- 生の入力型に戻す Annotation を仮定せず、正規形の入力で再開する。 -/
theorem resume_normal_entry (P : Program) (B : Builtins) :
    HasTypeCQ P B StoreTy.empty Qempty [] resumeContext [] none
      (.resume (.var 0) (.var 1)) U Eff.empty [] := by
  apply HasTypeCQ.C_ResumeNorm (b := raw) (t := U) (ε := Eff.empty) rfl
  · exact .V_Var rfl (by simp [Ty.Ordinary,Ty.core,Ty.norm,raw,bad])
  · trivial

/-- fn へ畳まれた終端でも、既存の適用から元の結果契約を得る。 -/
theorem dependent_application_derived (P : Program) (B : Builtins) :
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none
      (.app (.lam [] [] (.ret (.const .unit))) []) U Eff.empty [] := by
  have ha : Ty.Annotation P [] [] (.fn [] [] U Eff.empty) :=
    ⟨⟨⟨rfl,List.nodup_nil⟩,trivial,trivial,trivial,rfl⟩,⟨trivial,trivial,trivial⟩,
      ⟨trivial,trivial,trivial⟩⟩
  have hv : HasTypeVQ P B StoreTy.empty Qempty [] [] []
      (.lam [] [] (.ret (.const .unit))) (.fn [] [] U Eff.empty) :=
    .V_Lam ⟨rfl,List.nodup_nil⟩ ha.wf ha.sorted (.C_Return (.V_Const trivial)) ha.declared
  apply HasTypeCQ.C_DependentAppNorm (t := .done U Eff.empty)
  · have he : (Ty.dependentFn (.done U Eff.empty)).norm = .fn [] [] U Eff.empty :=
      Ty.norm_toTel (ns := []) (ps := []) (r := U) (e := Eff.empty) ⟨rfl,List.nodup_nil⟩
    rw [he]
    exact hv
  · exact .done ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

/-- 正規化は適格性の各判断を保ち、WFを固定点と取り違えない。 -/
theorem annotation_preserved {P C Γ a} (ha : Ty.Annotation P C Γ a) :
    Ty.Annotation P C Γ a.norm := ha.norm

theorem resume_result_wf {Γ : Ctx} {C : List TParam} {i : Nat} {b t : Ty} {e : Eff}
    (hΓ : Ctx.WF 0 C.length Γ) (hi : Γ[i]? = some (some (.cont b t e))) :
    t.norm.WF 0 C.length Γ.length := Ty.wf_norm (hΓ i _ hi).2.1

theorem location_resume_result_wf {Ψ : StoreTy} {l : Nat} {b t : Ty} {e : Eff} {R}
    (hΨ : Ψ.WF) (hl : Ψ l = some (.cont b t e R)) :
    t.norm.WF 0 0 0 := Ty.wf_norm (hΨ l _ hl).2.1

/-- hidden は適格な継続でも通常値でも使えず、元から読めない束縛だけを表す。 -/
theorem hidden_not_wf {a : Ty} {nr nt nv : Nat} (ho : ¬a.Ordinary)
    (hc : ∀ b t e, a ≠ .cont b t e) : ¬ a.WF nr nt nv :=
  fun hw => ho (hw.ordinary_of_not_cont hc)

end
end Benitoite.Release.Refinement.NormalizedRulesBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (name, _) in env.constants.toList do
    if (name.toString.splitOn ".NormalizedRulesBoundary.").length > 1 then
      elabCommand (← `(#print axioms $(mkIdent name)))
