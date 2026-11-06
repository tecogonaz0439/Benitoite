import Benitoite.Release.Refinement.Surface.CheckOpenSoundSupport
import Benitoite.Release.Refinement.Surface.CheckValueSupport

/-! レコードの構築・更新と構成子の呼び出しの検査の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check CheckArguments
open CheckFormation CheckCompare CheckOpenArguments CheckPatterns

private theorem checked_fields_wf {q : CheckFormation.Input} {nt : Nat} {as : List Ty}
    (ha : Ty.SupportList (· ∈ q.atoms) as) (h : as.all (CheckFormation.wfTy q 0 nt 0) = true) :
    ∀ a ∈ as, a.WF 0 nt 0 := by
  intro a hm
  exact CheckFormation.wfTy_sound (Ty.SupportList.iff.mp ha a hm) (List.all_eq_true.mp h a hm)

theorem record_step {h cs} (ih : SoundBelow (.node .E_Record h cs)) : ExprSoundAt (.node .E_Record h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i c ts positions args ga
    split at hc
    · rename_i cd hcd
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hf := hq.formation.fields c cd hcd
      have heq := (rawTyEq_spec (a := .data cd.data ts) hs.1 ha).mp hc.1
      subst a
      have hv := valsTys_sound hq hΓ (CtxSupport.bind hΓ (hg.1.tys 0))
        (recordFields_support (fallback := .const .unit) (boundVars_support _ _) trivial)
        (substituted_types_support (q := q) hf (types_support_shift hs.1 _)) hg.1 hc.2.2.2.2.2.2
      rw [substituted_types_eq (q := q) hf (types_support_shift hs.1 _)] at hv
      exact .E_Record hcd hc.2.1 (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.1)
        (checked_fields_wf hf hc.2.2.2.1) (hq.patterns c cd hcd) (annotation_sound hq hΓ hs.1 hc.2.2.2.2.1)
        ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.1 hc.2.2.2.2.2.1) hv
    · cases hc
  · cases hc

theorem recordRefined_step {h cs} (ih : SoundBelow (.node .E_RecordRefined h cs)) : ExprSoundAt (.node .E_RecordRefined h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i c ts positions args ga
    split at hc
    · rename_i rd cd hrd hcd
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hf := hq.formation.fields c cd hcd
      have heq := (rawTyEq_spec (a := .refined (.data cd.data ts) (rd.refinement c)) hs.1 ha).mp hc.1
      subst a
      have hv := valsTys_sound hq hΓ (CtxSupport.bind hΓ (hg.1.tys 0))
        (recordFields_support (fallback := .const .unit) (boundVars_support _ _) trivial)
        (substituted_types_support (q := q) hf (types_support_shift hs.1 _)) hg.1 hc.2.2.2.2.2.2.1
      rw [substituted_types_eq (q := q) hf (types_support_shift hs.1 _)] at hv
      exact .E_RecordRefined hrd hcd hc.2.1 (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.1)
        (checked_fields_wf hf hc.2.2.2.1) (hq.patterns c cd hcd) (annotation_sound hq hΓ hs.1 hc.2.2.2.2.1)
        ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.1 hc.2.2.2.2.2.1)
        hv ((h.proof 0).sound hc.2.2.2.2.2.2.2)
    · cases hc
  · cases hc

theorem conCall_step {h cs} (ih : SoundBelow (.node .E_ConCall h cs)) : ExprSoundAt (.node .E_ConCall h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i c ts args ga
    split at hc
    · rename_i cd hcd
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hf := hq.formation.fields c cd hcd
      have heq := (rawTyEq_spec (a := .data cd.data ts) hs.1 ha).mp hc.1
      subst a
      have hv := valsTys_sound hq hΓ (CtxSupport.bind hΓ (hg.1.tys 0))
        (boundVars_support _ _) (substituted_types_support (q := q) hf (types_support_shift hs.1 _)) hg.1 hc.2.2.2.2.2.2
      rw [substituted_types_eq (q := q) hf (types_support_shift hs.1 _)] at hv
      exact .E_ConCall hcd hc.2.1 (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.1)
        (checked_fields_wf hf hc.2.2.2.1) (hq.patterns c cd hcd) (annotation_sound hq hΓ hs.1 hc.2.2.2.2.1)
        ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.1 hc.2.2.2.2.2.1) hv
    · cases hc
  · cases hc

private theorem record_update_values_support {s vs} (hv : ValuesSupport s vs)
    (c : ConName) (n : Nat) (positions : List Nat) : ValuesSupport s (recordUpdateValues c n positions vs) := by
  have go : ∀ (is : List Nat) (f : Nat → Val), (∀ i ∈ is, ValueSupport s (f i)) → ValuesSupport s (is.map f) := by
    intro is f hf
    induction is with
    | nil => trivial
    | cons i is ih => exact ⟨hf i (by simp), ih (fun j hj => hf j (by simp [hj]))⟩
  apply go
  intro i hi
  have hf := value_support_member
    (recordFields_support (n := n) (positions := positions) (fallback := .const .unit) hv trivial)
    (List.mem_map.mpr ⟨i, hi, rfl⟩)
  cases he : fieldAt i positions vs with
  | none => trivial
  | some v =>
    simp only [he, Option.getD_some] at hf
    exact value_shift_support hf _

theorem recordUpdate_step {h cs} (ih : SoundBelow (.node .E_RecordUpdate h cs)) : ExprSoundAt (.node .E_RecordUpdate h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i c ts n positions base args gb ga
    split at hc
    · rename_i cd hcd
      split at hc
      · rename_i δ hδ
        simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
        have hf := hq.formation.fields c cd hcd
        have heq := (rawTyEq_spec (a := .data cd.data ts) hs.1 ha).mp hc.1
        subst a
        have hδs := altsTy_support hq.formation (type_shift_support (a := .data cd.data ts) hs.1 _ _) hδ
        have hΓ' := CtxSupport.bind (CtxSupport.bind hΓ (ps := .data cd.data ts :: h.tys 0) ⟨hs.1, hg.1.tys 0⟩) hδs
        have hv := valsTys_sound hq hΓ' hΓ'
          (record_update_values_support (boundVars_support _ _) c n positions)
          (substituted_types_support (q := q) hf (types_support_shift hs.1 _)) hg.1 hc.2.2.2.2.2.1
        rw [substituted_types_eq (q := q) hf (types_support_shift hs.1 _)] at hv
        exact .E_RecordUpdate hq.patterns hcd hc.2.1.1 hc.2.1.2.1 hc.2.1.2.2
          (annotation_sound hq hΓ hs.1 hc.2.2.1)
          ((ih gb (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2.1 hs.1 he hg.2.1 hc.2.2.2.1)
          ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2.2 (hg.1.tys 0) he hg.2.2.1 hc.2.2.2.2.1)
          (altsTy_sound hq.formation (type_shift_support (a := .data cd.data ts) hs.1 _ _) hδ) hv
          (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.2.2.2.2.1)
          (checked_fields_wf hf hc.2.2.2.2.2.2.2.1)
          (exhaustiveWithView_sound hq.formation.ctors hc.2.2.2.2.2.2.2.2)
      · cases hc
    · cases hc
  · cases hc

theorem recordUpdateRefined_step {h cs} (ih : SoundBelow (.node .E_RecordUpdateRefined h cs)) : ExprSoundAt (.node .E_RecordUpdateRefined h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i c ts n positions base args gb ga
    split at hc
    · rename_i rd cd hrd hcd
      split at hc
      · rename_i δ hδ
        simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
        have hf := hq.formation.fields c cd hcd
        have heq := (rawTyEq_spec (a := .refined (.data cd.data ts) (rd.refinement c)) hs.1 ha).mp hc.1
        subst a
        have hδs := altsTy_support hq.formation (type_shift_support (a := .data cd.data ts) hs.1 _ _) hδ
        have hΓ' := CtxSupport.bind (CtxSupport.bind hΓ (ps := .data cd.data ts :: h.tys 0) ⟨hs.1, hg.1.tys 0⟩) hδs
        have hv := valsTys_sound hq hΓ' hΓ'
          (record_update_values_support (boundVars_support _ _) c n positions)
          (substituted_types_support (q := q) hf (types_support_shift hs.1 _)) hg.1 hc.2.2.2.2.2.1
        rw [substituted_types_eq (q := q) hf (types_support_shift hs.1 _)] at hv
        exact .E_RecordUpdateRefined hq.patterns hrd hcd hc.2.1.1 hc.2.1.2.1 hc.2.1.2.2
          (annotation_sound hq hΓ hs.1 hc.2.2.1)
          ((ih gb (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2.1 hs.1 he hg.2.1 hc.2.2.2.1)
          ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2.2 (hg.1.tys 0) he hg.2.2.1 hc.2.2.2.2.1)
          (altsTy_sound hq.formation (type_shift_support (a := .data cd.data ts) hs.1 _ _) hδ) hv
          (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.2.2.2.2.1)
          (checked_fields_wf hf hc.2.2.2.2.2.2.2.1)
          (exhaustiveWithView_sound hq.formation.ctors hc.2.2.2.2.2.2.2.2.1)
          ((h.proof 0).sound hc.2.2.2.2.2.2.2.2.2)
      · cases hc
    · cases hc
  · cases hc

end Benitoite.Release.Refinement.Surface.CheckOpen
