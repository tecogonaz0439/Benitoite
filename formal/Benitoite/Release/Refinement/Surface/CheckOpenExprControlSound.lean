import Benitoite.Release.Refinement.Surface.CheckOpenSoundSupport

/-! 論理演算・分岐・束縛・継続と補間の検査の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check CheckArguments
open CheckFormation CheckCompare CheckOpenArguments CheckPatterns

theorem not_step {h cs} (ih : SoundBelow (.node .E_Not h cs)) : ExprSoundAt (.node .E_Not h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i e ge
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    have heq := (rawTyEq_spec (by trivial) ha).mp hc.1
    subst a
    exact .E_Not ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs (hg.1.ty 0) he hg.2.1 hc.2.1)
      hc.2.2.1 (subtype_sound (type_shift_support (hg.1.ty 0) _ _) trivial hg.1 hc.2.2.2)
  · cases hc

private theorem shifted_facts {limit : Nat} {premise goals : List Pred} {proofs : List CheckSubtyping.LogicCertificate}
    (h : factsEntailed limit premise (goals.map (Pred.shiftV 1 0)) proofs = true) :
    ∀ pred ∈ goals, Entails premise (pred.shiftV 1 0) := by
  intro pred hp
  exact factsEntailed_sound h _ (List.mem_map.mpr ⟨pred, hp, rfl⟩)

theorem and_step {h cs} (ih : SoundBelow (.node .E_And h cs)) : ExprSoundAt (.node .E_And h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i lhs rhs gl gr
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    have heq := (rawTyEq_spec (by trivial) ha).mp hc.1
    subst a
    exact .E_And
      ((ih gl (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.1)
      hc.2.2.1 (subtype_sound (type_shift_support (hg.1.ty 0) _ _) trivial hg.1 hc.2.2.2.1)
      (shifted_facts hc.2.2.2.2.1)
      ((ih gr (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2 trivial he hg.2.2.1 hc.2.2.2.2.2)
  · cases hc

theorem or_step {h cs} (ih : SoundBelow (.node .E_Or h cs)) : ExprSoundAt (.node .E_Or h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i lhs rhs gl gr
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    have heq := (rawTyEq_spec (by trivial) ha).mp hc.1
    subst a
    exact .E_Or
      ((ih gl (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.1)
      hc.2.2.1 (subtype_sound (type_shift_support (hg.1.ty 0) _ _) trivial hg.1 hc.2.2.2.1)
      (shifted_facts hc.2.2.2.2.1)
      ((ih gr (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2 trivial he hg.2.2.1 hc.2.2.2.2.2)
  · cases hc

theorem if_step {h cs} (ih : SoundBelow (.node .E_If h cs)) : ExprSoundAt (.node .E_If h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i cond yes no gc gy gn
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    exact .E_If
      ((ih gc (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.1)
      hc.2.1 (subtype_sound (type_shift_support (hg.1.ty 0) _ _) trivial hg.1 hc.2.2.1)
      (shifted_facts hc.2.2.2.1) (shifted_facts hc.2.2.2.2.1)
      ((ih gy (by simp_wf; omega)).block hq hΔ hΓ hR hs.2.1 ha he hg.2.2.1 hc.2.2.2.2.2.1)
      ((ih gn (by simp_wf; omega)).block hq hΔ hΓ hR hs.2.2 ha he hg.2.2.2.1 hc.2.2.2.2.2.2.1)
      (CheckFormation.declaredTy_sound hq.formation hΓ ha hc.2.2.2.2.2.2.2)
  · cases hc

theorem elseIf_step {h cs} (ih : SoundBelow (.node .E_ElseIf h cs)) : ExprSoundAt (.node .E_ElseIf h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i cond yes no gc gy gn
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    exact .E_ElseIf
      ((ih gc (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.1)
      hc.2.1 (subtype_sound (type_shift_support (hg.1.ty 0) _ _) trivial hg.1 hc.2.2.1)
      (shifted_facts hc.2.2.2.1) (shifted_facts hc.2.2.2.2.1)
      ((ih gy (by simp_wf; omega)).block hq hΔ hΓ hR hs.2.1 ha he hg.2.2.1 hc.2.2.2.2.2.1)
      ((ih gn (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2.2 ha he hg.2.2.2.1 hc.2.2.2.2.2.2.1)
      (CheckFormation.declaredTy_sound hq.formation hΓ ha hc.2.2.2.2.2.2.2)
  · cases hc

theorem ifOnly_step {h cs} (ih : SoundBelow (.node .E_IfOnly h cs)) : ExprSoundAt (.node .E_IfOnly h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i cond yes gc gy
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    have heq := (rawTyEq_spec (by trivial) ha).mp hc.1
    subst a
    exact .E_IfOnly
      ((ih gc (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.1)
      hc.2.2.1 (subtype_sound (type_shift_support (hg.1.ty 0) _ _) trivial hg.1 hc.2.2.2.1)
      (shifted_facts hc.2.2.2.2.1)
      ((ih gy (by simp_wf; omega)).block hq hΔ hΓ hR hs.2 trivial he hg.2.2.1 hc.2.2.2.2.2)
  · cases hc

theorem match_step {h cs} (ih : SoundBelow (.node .E_Match h cs)) : ExprSoundAt (.node .E_Match h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i result e arms ge ga
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    have heq := (rawTyEq_spec hs.1 ha).mp hc.2.2.1
    subst a
    have hn : arms ≠ .nil := by intro hn; subst arms; cases hc.1
    exact .E_Match hq.patterns hn hc.2.1
      ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2.1 (hg.1.ty 0) he hg.2.1 hc.2.2.2.1)
      ((ih ga (by simp_wf; omega)).arms hq (hΔ.localExtend 1) (hΓ.extend (hg.1.ty 0)) (hR.shift 1)
        hs.2.2 (type_shift_support (hg.1.ty 0) _ _) (type_shift_support hs.1 _ _)
        (effect_shift_support he _ _) hg.2.2.1 hc.2.2.2.2.1)
      (exhaustiveWithView_view hq.formation.ctors hc.2.2.2.2.2.1)
      (annotation_sound hq hΓ (hg.1.ty 0) hc.2.2.2.2.2.2.1)
      (annotation_sound hq hΓ hs.1 hc.2.2.2.2.2.2.2)
  · cases hc

theorem returnTail_step {h cs} (ih : SoundBelow (.node .E_ReturnTail h cs)) : ExprSoundAt (.node .E_ReturnTail h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i annotated e ge
    split at hc
    · rename_i r
      have hh := Bool.and_eq_true_iff.mp hc
      have heq := (rawTyEq_spec hR ha).mp hh.1
      subst a
      exact .E_ReturnTail ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2 hR he hg.2.1 hh.2)
    · cases hc
  · cases hc

theorem returnOther_step {h cs} (ih : SoundBelow (.node .E_ReturnOther h cs)) : ExprSoundAt (.node .E_ReturnOther h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i annotated e ge
    split at hc
    · rename_i r
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have heq := (rawTyEq_spec hs.1 ha).mp hc.1
      subst a
      exact .E_ReturnOther (annotation_sound hq hΓ hs.1 hc.2.1) hc.2.2.1
        ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2 hR he hg.2.1 hc.2.2.2)
    · cases hc
  · cases hc

theorem with_step {h cs} (ih : SoundBelow (.node .E_With h cs)) : ExprSoundAt (.node .E_With h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i o e body ge gb
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    exact .E_With hc.1
      ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 trivial he hg.2.1 hc.2.1)
      ((ih gb (by simp_wf; omega)).block hq (hΔ.localExtend 1) (hΓ.extend (by trivial)) (hR.shift 1)
        hs.2 (type_shift_support ha _ _) (effect_shift_support he _ _) hg.2.2.1 hc.2.2.1)
      hc.2.2.2.1 (CheckFormation.declaredTy_sound hq.formation hΓ ha hc.2.2.2.2)
  · cases hc

theorem lazy_step {h cs} (ih : SoundBelow (.node .E_Lazy h cs)) : ExprSoundAt (.node .E_Lazy h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i body gb
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .lazy (h.ty 0)) (hg.1.ty 0) (empty_effect_support _) ha he hc.1
    exact .E_Lazy
      ((ih gb (by simp_wf; omega)).block hq (by intro i kind hi; cases i <;> cases hi)
        (CtxSupport.hide hΓ) trivial hs (hg.1.ty 0) (empty_effect_support _) hg.2.1 hc.2.1)
      (annotation_sound hq hΓ (hg.1.ty 0) hc.2.2)
  · cases hc

theorem handle_step {h cs} (ih : SoundBelow (.node .E_Handle h cs)) : ExprSoundAt (.node .E_Handle h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i body clauses gb gc
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    have hu : union q ε (handled q.D.core q.B clauses.skeleton) = Eff.union ε (handled q.D.core q.B clauses.skeleton) :=
      CheckHandler.union_eq ((Eff.support_iff ε).mp he).2 trivial
    have hf : Ty.SupportList (· ∈ q.formation.atoms) (Eff.union ε (handled q.D.core q.B clauses.skeleton)).fails :=
      Eff.norm_fails_support _ (by
        change Ty.SupportList (· ∈ q.formation.atoms) (ε.fails ++ [])
        simpa only [List.append_nil] using ((Eff.support_iff ε).mp he).2)
    have hh := includes_sound (hg.1.eff 0) (by rw [hu]; exact hf) hc.2.1
    rw [hu] at hh
    exact .E_Handle
      ((ih gb (by simp_wf; omega)).block hq hΔ hΓ hR hs.1 ha (hg.1.eff 0) hg.2.1 hc.1) hh
      ((ih gc (by simp_wf; omega)).clauses hq hΔ hΓ hR hs.2 (hg.1.eff 0) ha he hg.2.2.1 hc.2.2)
  · cases hc

theorem resume_step {h cs} (ih : SoundBelow (.node .E_Resume h cs)) : ExprSoundAt (.node .E_Resume h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i k e ge
    split at hc
    · rename_i b t ec hi
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have ht := hΓ k (.cont b t ec) hi
      obtain ⟨rfl, rfl⟩ := resultEq_sound ht.2.1 ht.2.2 ha he hc.1
      exact .E_Resume hi hc.2.1
        ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs ht.1 ht.2.2 hg.2.1 hc.2.2.1)
        (CheckFormation.declaredTy_sound hq.formation hΓ ht.2.1 hc.2.2.2)
    · cases hc
  · cases hc

theorem lam_step {h cs} (ih : SoundBelow (.node .E_Lam h cs)) : ExprSoundAt (.node .E_Lam h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i names ps r ec body gb
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    have ht : (Ty.fn names ps r ec).Support (· ∈ q.formation.atoms) := ⟨hs.1, hs.2.1, hs.2.2.1⟩
    obtain ⟨rfl, rfl⟩ := resultEq_sound ht (empty_effect_support _) ha he hc.1
    exact .E_Lam hc.2.1 (annotation_sound hq hΓ ht hc.2.2.1)
      ((ih gb (by simp_wf; omega)).block hq (by intro i kind hi; cases i <;> cases hi)
        (CtxSupport.bind (CtxSupport.hide hΓ) hs.1) (type_shift_support hs.2.1 _ _) hs.2.2.2
        (type_shift_support hs.2.1 _ _) (effect_shift_support hs.2.2.1 _ _) hg.2.1 hc.2.2.2)
  · cases hc

private theorem interpolation_types_support {s ps} (h : CheckSource.PartsSupport s ps) :
    Ty.SupportList (· ∈ s) (InterpPart.exprTypes ps) := by
  induction ps with
  | nil => trivial
  | cons part ps ih =>
    cases part with
    | text _ => exact ih h
    | stringExpr => exact ⟨trivial, ih h⟩
    | converted t => exact ⟨h.1, ih h.2⟩
    | formatted t spec => exact ⟨h.1, ih h.2⟩

theorem interpolation_step {h cs} (ih : SoundBelow (.node .E_Interpolation h cs)) : ExprSoundAt (.node .E_Interpolation h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i parts es fs ges gu
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    have heq := (rawTyEq_spec (by trivial) ha).mp hc.1
    subst a
    have has := interpolation_types_support hs.1
    exact .E_Interpolation (interpAllowed_sound hc.2.1) rfl
      ((ih ges (by simp_wf; omega)).types hq hΔ hΓ hR hs.2.1 has he hg.2.1 hc.2.2.1)
      (checkInterpAt_sound hq hΓ (CtxSupport.bind hΓ has) (boundVars_support _ _) hs.2.2 trivial
        (effect_shift_support he _ _) hg.2.2.1 hc.2.2.2)
  · cases hc

end Benitoite.Release.Refinement.Surface.CheckOpen
