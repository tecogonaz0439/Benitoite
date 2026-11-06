import Benitoite.Release.Refinement.Surface.CheckSoundSupport
import Benitoite.Release.Refinement.Surface.CheckValueSupport

/-! 呼出しとパイプの検査を、依存列と引数の判断へ接続する。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckFormation CheckCompare CheckArguments

theorem callDirect_step {h cs} (ih : SoundBelow (.node .E_CallDirect h cs)) : ExprSoundAt (.node .E_CallDirect h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f labels positions args ga
    split at hc
    · rename_i t ds ht
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hhead := head_sound hq hΓ (source_head_inputs hs.1) hg.1 ht
      have hds : DictsSupport q.formation.atoms ds := by rw [hhead.2.2]; exact source_head_dictionaries hs.1
      have hΓ' := CtxSupport.bind hΓ (hg.1.tys 0)
      have hvs := values_append_support (dicts_renamed_support hds (h.tys 0).length)
        (recordFields_support (n := (h.tys 0).length) (positions := positions) (fallback := .const .unit) (boundVars_support _ (h.tys 0).length) trivial)
      exact .E_CallDirect hhead.1 hc.1
        ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.1 hc.2.1)
        (valsTel_sound hq hΓ hΓ' hvs (tel_shift_support hhead.2.1 _ _) (hg.1.ty 0) (hg.1.eff 0) hg.1 hc.2.2.1)
        (subtype_sound (hg.1.ty 0) (type_shift_support ha _ _) hg.1 hc.2.2.2.1)
        (covers_sound (hg.1.eff 0) (effect_fails_support (effect_shift_support he _ _)) hc.2.2.2.2.1)
        (annotation_sound hq hΓ ha hc.2.2.2.2.2)
    · cases hc
  · cases hc

theorem call_step {h cs} (ih : SoundBelow (.node .E_Call h cs)) : ExprSoundAt (.node .E_Call h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f labels positions args gf ga
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq, Option.isNone_iff_eq_none] at hc
    have hΓ' := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) (.dependentFn (h.tel 0) :: h.tys 0) from ⟨hg.1.tel 0, hg.1.tys 0⟩)
    exact .E_Call hc.1
      ((ih gf (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.tel 0) he hg.2.1 hc.2.1) hc.2.2.1
      ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.2.1 hc.2.2.2.1)
      (valsTel_sound hq hΓ hΓ' (recordFields_support (n := (h.tys 0).length) (positions := positions) (fallback := .const .unit) (boundVars_support _ (h.tys 0).length) trivial)
        (tel_shift_support (hg.1.tel 0) _ _) (hg.1.ty 0) (hg.1.eff 0) hg.1 hc.2.2.2.2.1)
      (subtype_sound (hg.1.ty 0) (type_shift_support ha _ _) hg.1 hc.2.2.2.2.2.1)
      (covers_sound (hg.1.eff 0) (effect_fails_support (effect_shift_support he _ _)) hc.2.2.2.2.2.2.1)
      (annotation_sound hq hΓ ha hc.2.2.2.2.2.2.2)
  · cases hc

theorem callExternal_step {h cs} (ih : SoundBelow (.node .E_CallExternal h cs)) : ExprSoundAt (.node .E_CallExternal h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f ts labels positions args ga
    split at hc
    · rename_i t ds ht
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hhead := head_sound hq hΓ hs.1 hg.1 ht
      have hΓ' := CtxSupport.bind hΓ (hg.1.tys 0)
      have hv := valsTel_sound hq hΓ hΓ' (recordFields_support (n := (h.tys 0).length) (positions := positions) (fallback := .const .unit) (boundVars_support _ (h.tys 0).length) trivial)
        hhead.2.1 (hg.1.ty 0) (hg.1.eff 0) hg.1 hc.2.2.2.1
      have hargs := (ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.1 hc.2.2.1
      have hsub := subtype_sound (hg.1.ty 0) (type_shift_support ha _ _) hg.1 hc.2.2.2.2.1
      have hcover := covers_sound (Γ := bindParams Γ (h.tys 0)) (Φ := liftMany (h.tys 0).length Φ) (hg.1.eff 0) (effect_fails_support (effect_shift_support he _ _)) hc.2.2.2.2.2.1
      have hann := annotation_sound hq hΓ ha hc.2.2.2.2.2.2
      cases hhead.1 with
      | external hd hadmiss =>
        apply HasTypeQ.E_CallExternal hd hadmiss
        · simpa only [instantiatedTel, Tel.names_bind, telBinders_bind] using hc.2.1
        · exact hargs
        · exact hv
        · exact hsub
        · exact hcover
        · exact hann
    · cases hc
  · cases hc

theorem pipeConCall_step {h cs} (ih : SoundBelow (.node .E_PipeConCall h cs)) : ExprSoundAt (.node .E_PipeConCall h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i lhs c ts args gl ga
    split at hc
    · rename_i cd hcd
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hfields := hq.formation.fields c cd hcd
      have hΓ' := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) (h.ty 0 :: h.tys 0) from ⟨hg.1.ty 0, hg.1.tys 0⟩)
      have htshift := types_support_shift hs.2.1 ((h.tys 0).length + 1)
      have hv := valsTys_sound hq hΓ hΓ' (show ValuesSupport q.formation.atoms (.var (h.tys 0).length :: boundVars (h.tys 0).length) from ⟨trivial, boundVars_support _ _⟩) (substituted_types_support hfields htshift) hg.1 hc.2.2.2.2.2.2.2
      rw [substituted_types_eq hfields htshift] at hv
      have hwf : ∀ t ∈ cd.args, t.WF 0 cd.ntys 0 := by
        intro t ht
        exact CheckFormation.wfTy_sound (Ty.SupportList.iff.mp hfields t ht) (List.all_eq_true.mp hc.2.2.2.1 t ht)
      have hann := annotation_sound (a := .data cd.data ts) hq hΓ hs.2.1 hc.2.2.2.2.1
      have heq := (rawTyEq_spec (a := .data cd.data ts) hs.2.1 ha).mp hc.1
      subst a
      exact .E_PipeConCall hcd hc.2.1 (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.1) hwf hann
        ((ih gl (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.2.2.2.2.1)
        ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2.2 (hg.1.tys 0) he hg.2.2.1 hc.2.2.2.2.2.2.1) hv
    · cases hc
  · cases hc

theorem pipeConValue_step {h cs} (ih : SoundBelow (.node .E_PipeConValue h cs)) : ExprSoundAt (.node .E_PipeConValue h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i lhs c ts names ps gl
    split at hc
    · rename_i cd hcd
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hfields := hq.formation.fields c cd hcd
      have hΓ' := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [h.ty 0] from ⟨hg.1.ty 0, trivial⟩)
      have htshift := types_support_shift hs.2.1 1
      have hv := valsTys_sound hq hΓ hΓ' (show ValuesSupport q.formation.atoms [.var 0] from ⟨trivial, trivial⟩) (substituted_types_support hfields htshift) hg.1 hc.2.2.2.2.2.2
      rw [substituted_types_eq hfields htshift] at hv
      have hwf : ∀ t ∈ cd.args, t.WF 0 cd.ntys 0 := by
        intro t ht
        exact CheckFormation.wfTy_sound (Ty.SupportList.iff.mp hfields t ht) (List.all_eq_true.mp hc.2.2.2.1 t ht)
      have hann := annotation_sound (a := .data cd.data ts) hq hΓ hs.2.1 hc.2.2.2.2.1
      have heq := (rawTyEq_spec (a := .data cd.data ts) hs.2.1 ha).mp hc.1
      subst a
      exact .E_PipeConValue hcd hc.2.1 (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.1) hwf hann
        ((ih gl (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.2.2.2.2.1) hv
    · cases hc
  · cases hc

theorem pipeCallDirect_step {h cs} (ih : SoundBelow (.node .E_PipeCallDirect h cs)) : ExprSoundAt (.node .E_PipeCallDirect h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i lhs f labels positions args gl ga
    split at hc
    · rename_i t ds ht
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hhead := head_sound hq hΓ (source_head_inputs hs.2.1) hg.1 ht
      have hds : DictsSupport q.formation.atoms ds := by rw [hhead.2.2]; exact source_head_dictionaries hs.2.1
      have hΓ' := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) (h.ty 0 :: h.tys 0) from ⟨hg.1.ty 0, hg.1.tys 0⟩)
      have hvs := values_append_support (dicts_renamed_support hds ((h.tys 0).length + 1))
        (recordFields_support (n := (h.tys 0).length + 1) (positions := 0 :: positions) (vs := .var (h.tys 0).length :: boundVars (h.tys 0).length) (fallback := .const .unit) ⟨trivial, boundVars_support _ _⟩ trivial)
      exact .E_PipeCallDirect hhead.1 hc.1
        ((ih gl (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.1)
        ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2.2 (hg.1.tys 0) he hg.2.2.1 hc.2.2.1)
        (valsTel_sound hq hΓ hΓ' hvs (tel_shift_support hhead.2.1 _ _) (hg.1.ty 1) (hg.1.eff 0) hg.1 hc.2.2.2.1)
        (subtype_sound (hg.1.ty 1) (type_shift_support ha _ _) hg.1 hc.2.2.2.2.1)
        (covers_sound (hg.1.eff 0) (effect_fails_support (effect_shift_support he _ _)) hc.2.2.2.2.2.1)
        (annotation_sound hq hΓ ha hc.2.2.2.2.2.2)
    · cases hc
  · cases hc

theorem pipeCall_step {h cs} (ih : SoundBelow (.node .E_PipeCall h cs)) : ExprSoundAt (.node .E_PipeCall h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i lhs f labels positions args gl gf ga
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq, Option.isNone_iff_eq_none] at hc
    have hΓ' := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) (h.ty 0 :: .dependentFn (h.tel 0) :: h.tys 0) from ⟨hg.1.ty 0, hg.1.tel 0, hg.1.tys 0⟩)
    exact .E_PipeCall hc.1
      ((ih gl (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.1)
      ((ih gf (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2.1 (hg.1.tel 0) he hg.2.2.1 hc.2.2.1) hc.2.2.2.1
      ((ih ga (by simp_wf; omega)).types hq hΔ hΓ hR hs.2.2 (hg.1.tys 0) he hg.2.2.2.1 hc.2.2.2.2.1)
      (valsTel_sound hq hΓ hΓ' (recordFields_support (n := (h.tys 0).length + 1) (positions := 0 :: positions) (vs := .var ((h.tys 0).length + 1) :: boundVars (h.tys 0).length) (fallback := .const .unit) ⟨trivial, boundVars_support _ _⟩ trivial)
        (tel_shift_support (hg.1.tel 0) _ _) (hg.1.ty 1) (hg.1.eff 0) hg.1 hc.2.2.2.2.2.1)
      (subtype_sound (hg.1.ty 1) (type_shift_support ha _ _) hg.1 hc.2.2.2.2.2.2.1)
      (covers_sound (hg.1.eff 0) (effect_fails_support (effect_shift_support he _ _)) hc.2.2.2.2.2.2.2.1)
      (annotation_sound hq hΓ ha hc.2.2.2.2.2.2.2.2)
  · cases hc

theorem pipeApplyDirect_step {h cs} (ih : SoundBelow (.node .E_PipeApplyDirect h cs)) : ExprSoundAt (.node .E_PipeApplyDirect h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i lhs rhs gl
    split at hc
    · rename_i t ds ht
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hhead := head_sound hq hΓ (source_head_inputs hs.2) hg.1 ht
      have hds : DictsSupport q.formation.atoms ds := by rw [hhead.2.2]; exact source_head_dictionaries hs.2
      have hΓ' := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [h.ty 0] from ⟨hg.1.ty 0, trivial⟩)
      have hvs := values_append_support (dicts_renamed_support hds 1) (show ValuesSupport q.formation.atoms [.var 0] from ⟨trivial, trivial⟩)
      exact .E_PipeApplyDirect hc.1 hhead.1
        ((ih gl (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.1)
        (valsTel_sound hq hΓ hΓ' hvs (tel_shift_support hhead.2.1 _ _) (hg.1.ty 1) (hg.1.eff 0) hg.1 hc.2.2.1)
        (subtype_sound (hg.1.ty 1) (type_shift_support ha _ _) hg.1 hc.2.2.2.1)
        (covers_sound (hg.1.eff 0) (effect_fails_support (effect_shift_support he _ _)) hc.2.2.2.2.1)
        (annotation_sound hq hΓ ha hc.2.2.2.2.2)
    · cases hc
  · cases hc

theorem pipeApply_step {h cs} (ih : SoundBelow (.node .E_PipeApply h cs)) : ExprSoundAt (.node .E_PipeApply h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i lhs rhs gl gr
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq, Option.isNone_iff_eq_none] at hc
    have hΓ' := CtxSupport.bind hΓ (show Ty.SupportList (· ∈ q.formation.atoms) [h.ty 0, .dependentFn (h.tel 0)] from ⟨hg.1.ty 0, hg.1.tel 0, trivial⟩)
    exact .E_PipeApply hc.1 hc.2.1
      ((ih gl (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 (hg.1.ty 0) he hg.2.1 hc.2.2.1)
      ((ih gr (by simp_wf; omega)).expr hq hΔ hΓ hR hs.2 (hg.1.tel 0) he hg.2.2.1 hc.2.2.2.1)
      (valsTel_sound hq hΓ hΓ' (show ValuesSupport q.formation.atoms [.var 1] from ⟨trivial, trivial⟩)
        (tel_shift_support (hg.1.tel 0) _ _) (hg.1.ty 1) (hg.1.eff 0) hg.1 hc.2.2.2.2.1)
      (subtype_sound (hg.1.ty 1) (type_shift_support ha _ _) hg.1 hc.2.2.2.2.2.1)
      (covers_sound (hg.1.eff 0) (effect_fails_support (effect_shift_support he _ _)) hc.2.2.2.2.2.2.1)
      (annotation_sound hq hΓ ha hc.2.2.2.2.2.2.2)
  · cases hc

end Benitoite.Release.Refinement.Surface.Check
