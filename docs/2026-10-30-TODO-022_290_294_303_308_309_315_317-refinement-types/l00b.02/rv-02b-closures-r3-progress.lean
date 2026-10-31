import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.ClosureTyping

/-! 進行: 型付きの builderOp の参照は、ρ で場所へ解決され、その場所は builder である。 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem HasTypeCQ.builderRef_aux {P B Ψ Q C Γ Φ R m a e L ν ρ}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hl : CaptureLocals Ψ ν L ρ) :
    ∀ kind op r args, m = .builderOp kind op r args →
    ∃ l b, r.subst ρ = .loc l ∧ Ψ l = some (.builder b) := by
  match h with
  | .C_BuilderOp _ _ hr _ =>
    intro kind op r args he
    cases he
    cases hr with
    | bound hi => obtain ⟨l,he,ht⟩ := hl _ _ hi; exact ⟨l,_,he,ht⟩
    | loc ht => exact ⟨_,_,rfl,ht⟩
  | .C_Sub hm _ _ _ _ _ => exact HasTypeCQ.builderRef_aux hm hl
  | .C_Eff hm _ => exact HasTypeCQ.builderRef_aux hm hl
  | .C_BuilderLet .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match ..
  | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL ..
  | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. =>
    intro kind op r args he; cases he
termination_by structural h

theorem HasTypeCQ.builderRef_resolved {P B Ψ Q C Γ Φ R kind op r args a e L ν ρ}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.builderOp kind op r args) a e L)
    (hl : CaptureLocals Ψ ν L ρ) :
    ∃ l b, r.subst ρ = .loc l ∧ Ψ l = some (.builder b) :=
  HasTypeCQ.builderRef_aux h hl _ _ _ _ rfl

/-- 実行の閉包についての形: bound が残らない。 -/
theorem ClosureTy.builderOp_ref {P B Ψ ss R cap kind op r args a e}
    (h : ClosureTy P B Ψ ss R (.mk cap (.builderOp kind op r args)) a e) :
    ∃ l b, r = .loc l ∧ Ψ l = some (.builder b) := by
  cases h with
  | mk hc hb hl heq h5 h6 h7 h8 h9 h10 h11 =>
    rename_i ss0 c0 Γ0 Φ0 Rs0 a0 e0 L0 ρ
    cases c0
    case builderOp k0 op0 r0 as0 =>
      simp only [Comp.resolveLocals,Comp.builderOp.injEq] at heq
      obtain ⟨_,_,h3,_⟩ := heq
      subst h3
      exact hb.builderRef_resolved hl
    case checkAt _ _ _ bs _ _ _ =>
      cases bs <;> exact absurd heq (by intro hh; simp only [Comp.resolveLocals] at hh; cases hh)
    all_goals exact absurd heq (by intro hh; simp only [Comp.resolveLocals] at hh; cases hh)

/-- 隠したストアでは L に構築器を置けない（旧 NoBuilders の役割）。 -/
theorem CaptureLocals.hide_none {Ψ : StoreTy} {ν} {L : LocalCtx} {ρ} (h : CaptureLocals (hideBuilders Ψ) ν L ρ) :
    ∀ (i : Nat) (b : BuilderKind), L[i]? ≠ some (some b) := by
  intro i b hi
  obtain ⟨l,_,ht⟩ := h i b hi
  unfold hideBuilders at ht
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp [hl] at ht

#print axioms ClosureTy.builderOp_ref
#print axioms CaptureLocals.hide_none
end
end Benitoite.Release.Refinement
