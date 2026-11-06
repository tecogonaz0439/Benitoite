import Benitoite.Release.Refinement.Surface.CheckOpenSoundSupport

/-! 変数・定数と、型の注釈を持つ基本の式の検査の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check CheckArguments
open CheckCompare CheckFormation CheckOpenArguments

theorem local_step {h cs} : ExprSoundAt (.node .E_Local h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i i
    cases hi : Γ[i]? with
    | none => simp [hi] at hc
    | some x => cases x with
      | none => simp [hi] at hc
      | some t =>
        simp only [hi, Bool.and_eq_true, decide_eq_true_eq] at hc
        obtain ⟨rfl, rfl⟩ := resultEq_sound (hΓ i t hi) (empty_effect_support _) ha he hc.2
        exact .E_Local hi hc.1
  · cases hc

theorem literal_step {h cs} : ExprSoundAt (.node .E_Literal h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i l
    have hh := Bool.and_eq_true_iff.mp hc
    obtain ⟨rfl, rfl⟩ := resultEq_sound (const_type_support _ l.toConst) (empty_effect_support _) ha he hh.2
    exact .E_Literal (CheckArguments.constOK_sound hh.1)
  · cases hc

theorem negInt_step {h cs} : ExprSoundAt (.node .E_NegInt h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i n
    obtain ⟨rfl, rfl⟩ := resultEq_sound (by trivial) (empty_effect_support _) ha he hc
    exact .E_NegInt
  · cases hc

theorem negFloat_step {h cs} : ExprSoundAt (.node .E_NegFloat h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i x
    obtain ⟨rfl, rfl⟩ := resultEq_sound (by trivial) (empty_effect_support _) ha he hc
    exact .E_NegFloat
  · cases hc

theorem negDecimal_step {h cs} : ExprSoundAt (.node .E_NegDecimal h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i n scale
    have hh := Bool.and_eq_true_iff.mp hc
    obtain ⟨rfl, rfl⟩ := resultEq_sound (by trivial) (empty_effect_support _) ha he hh.2
    exact .E_NegDecimal (CheckArguments.constOK_sound hh.1)
  · cases hc

theorem negInteger8_step {h cs} : ExprSoundAt (.node .E_NegInteger8 h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i n
    have hh := Bool.and_eq_true_iff.mp hc
    obtain ⟨rfl, rfl⟩ := resultEq_sound (by trivial) (empty_effect_support _) ha he hh.2
    exact .E_NegInteger8 (CheckArguments.constOK_sound hh.1)
  · cases hc

theorem negInteger16_step {h cs} : ExprSoundAt (.node .E_NegInteger16 h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i n
    have hh := Bool.and_eq_true_iff.mp hc
    obtain ⟨rfl, rfl⟩ := resultEq_sound (by trivial) (empty_effect_support _) ha he hh.2
    exact .E_NegInteger16 (CheckArguments.constOK_sound hh.1)
  · cases hc

theorem negInteger32_step {h cs} : ExprSoundAt (.node .E_NegInteger32 h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i n
    have hh := Bool.and_eq_true_iff.mp hc
    obtain ⟨rfl, rfl⟩ := resultEq_sound (by trivial) (empty_effect_support _) ha he hh.2
    exact .E_NegInteger32 (CheckArguments.constOK_sound hh.1)
  · cases hc

theorem negFloat32_step {h cs} : ExprSoundAt (.node .E_NegFloat32 h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i bits
    obtain ⟨rfl, rfl⟩ := resultEq_sound (by trivial) (empty_effect_support _) ha he hc
    exact .E_NegFloat32
  · cases hc

theorem unit_step {h cs} : ExprSoundAt (.node .E_Unit h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  ·
    obtain ⟨rfl, rfl⟩ := resultEq_sound (by trivial) (empty_effect_support _) ha he hc
    exact .E_Unit
  · cases hc

theorem const_step {h cs} (ih : SoundBelow (.node .E_Const h cs)) : ExprSoundAt (.node .E_Const h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i t body gb
    have hh := Bool.and_eq_true_iff.mp hc
    have hb := (ih gb (by simp_wf; omega)).expr hq (by intro i k h; cases i <;> cases h)
      (CtxSupport.hidden _ _) hR hs.2 hs.1 (empty_effect_support _) hg.2.1 hh.2
    obtain ⟨rfl, rfl⟩ := resultEq_sound hs.1 (empty_effect_support _) ha he hh.1
    exact .E_Const hb
  · cases hc

theorem block_step {h cs} (ih : SoundBelow (.node .E_Block h cs)) : ExprSoundAt (.node .E_Block h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i body gb
    exact .E_Block ((ih gb (by simp_wf; omega)).block hq hΔ hΓ hR hs ha he hg.2.1 hc)
  · cases hc

theorem paren_step {h cs} (ih : SoundBelow (.node .E_Paren h cs)) : ExprSoundAt (.node .E_Paren h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i inner ge
    exact .E_Paren ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs ha he hg.2.1 hc)
  · cases hc

theorem sub_step {h cs} (ih : SoundBelow (.node .E_Sub h cs)) : ExprSoundAt (.node .E_Sub h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i ge
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    exact .E_Sub ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs (hg.1.ty 0) (hg.1.eff 0) hg.2.1 hc.1)
      (subtype_sound (hg.1.ty 0) ha hg.1 hc.2.1)
      (covers_sound (hg.1.eff 0) (effect_fails_support he) hc.2.2.1)
      (annotation_sound hq hΓ ha hc.2.2.2)
  · cases hc

theorem refine_step {h cs} (ih : SoundBelow (.node .E_Refine h cs)) : ExprSoundAt (.node .E_Refine h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i ge
    split at hc
    · rename_i v hv
      split at hc
      · rename_i t sort ht hsort
        simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
        have heq := (rawTyEq_spec (show (Ty.refined (h.ty 0) (h.pred 0)).Support (· ∈ q.formation.atoms) from hg.1.ty 0) ha).mp hc.1
        cases heq
        exact .E_Refine
          ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs (hg.1.ty 0) he hg.2.1 hc.2.1)
          hv ht hsort hc.2.2.1.1 hc.2.2.1.2 ((h.proof 0).sound hc.2.2.2.1)
          (annotation_sound hq hΓ (hg.1.ty 0) hc.2.2.2.2.1)
          (CheckFormation.declaredPred_sound hq.formation hΓ (by intro b hb; cases hb; exact hg.1.ty 0) hc.2.2.2.2.2)
      · cases hc
    · cases hc
  · cases hc

end Benitoite.Release.Refinement.Surface.CheckOpen
