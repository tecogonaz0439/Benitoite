import Benitoite.Release.Refinement.Surface.CheckOpenSoundSupport

/-! 宣言表から得る関数・構成子の値と、直接の頭の検査の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check CheckArguments
open CheckFormation CheckCompare CheckOpenArguments

theorem fun_step {h cs} : ExprSoundAt (.node .E_Fun h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f ts es xs
    split at hc
    · rename_i t ds ht
      have hh := Bool.and_eq_true_iff.mp hc
      have hd : ds = [] := by cases ds <;> first | rfl | cases hh.1
      subst ds
      have hh' := head_sound hq hΓ hs hg.1 ht
      obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .dependentFn t) hh'.2.1 (empty_effect_support _) ha he hh.2
      exact .E_Fun hh'.1
    · cases hc
  · cases hc

theorem prim_step {h cs} : ExprSoundAt (.node .E_Prim h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i b ts es rs
    split at hc
    · rename_i t ds ht
      have hh := Bool.and_eq_true_iff.mp hc
      have hd : ds = [] := by cases ds <;> first | rfl | cases hh.1
      subst ds
      have hh' := head_sound hq hΓ hs hg.1 ht
      obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .dependentFn t) hh'.2.1 (empty_effect_support _) ha he hh.2
      exact .E_Prim hh'.1
    · cases hc
  · cases hc

theorem op_step {h cs} : ExprSoundAt (.node .E_Op h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i o ts
    split at hc
    · rename_i t ds ht
      have hh := Bool.and_eq_true_iff.mp hc
      have hd : ds = [] := by cases ds <;> first | rfl | cases hh.1
      subst ds
      have hh' := head_sound hq hΓ hs hg.1 ht
      obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .dependentFn t) hh'.2.1 (empty_effect_support _) ha he hh.2
      exact .E_Op hh'.1
    · cases hc
  · cases hc

theorem funDicts_step {h cs} : ExprSoundAt (.node .E_FunDicts h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f ts es ds names ps xs
    split at hc
    · rename_i t returned ht
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hhead := head_sound hq hΓ hs.1 hg.1 ht
      have hds : returned = ds := hhead.2.2
      subst returned
      have hp := hs.2.2
      have hΓ' := CtxSupport.bind (CtxSupport.hide hΓ) hp
      have hv := values_append_support (dicts_renamed_support hs.2.1 ps.length) (boundVars_support q.formation.atoms ps.length)
      have ht' := tel_shift_support hhead.2.1 ps.length 0
      have hb := valsTel_sound hq (CtxSupport.hide hΓ) hΓ' hv ht' (hg.1.ty 1) (hg.1.eff 1) hg.1 hc.2.2.2.1
      have hsub := subtype_sound (hg.1.ty 1) (type_shift_support (hg.1.ty 0) _ _) hg.1 hc.2.2.2.2.1
      have hcover := covers_sound (Γ := bindParams (hideConts Γ) ps) (Φ := liftMany ps.length Φ) (hg.1.eff 1) (effect_fails_support (effect_shift_support (hg.1.eff 0) _ _)) hc.2.2.2.2.2
      have hfn : (Ty.fn names ps (h.ty 0) (h.eff 0)).Support (· ∈ q.formation.atoms) := ⟨hp, hg.1.ty 0, hg.1.eff 0⟩
      obtain ⟨rfl, rfl⟩ := resultEq_sound hfn (empty_effect_support _) ha he hc.1
      exact .E_FunDicts hhead.1 hc.2.1 (annotation_sound hq hΓ hfn hc.2.2.1) hb hsub hcover
    · cases hc
  · cases hc

theorem methName_step {h cs} : ExprSoundAt (.node .E_MethName h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i dictionary method ts es ds names ps
    split at hc
    · rename_i t returned ht
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hhead := head_sound hq hΓ hs.1 hg.1 ht
      have hds : returned = ds := hhead.2.2
      subst returned
      have hp := hs.2.2
      have hΓ' := CtxSupport.bind (CtxSupport.hide hΓ) hp
      have hv := values_append_support (dicts_renamed_support hs.2.1 ps.length) (boundVars_support q.formation.atoms ps.length)
      have ht' := tel_shift_support hhead.2.1 ps.length 0
      have hb := valsTel_sound hq (CtxSupport.hide hΓ) hΓ' hv ht' (hg.1.ty 1) (hg.1.eff 1) hg.1 hc.2.2.2.1
      have hsub := subtype_sound (hg.1.ty 1) (type_shift_support (hg.1.ty 0) _ _) hg.1 hc.2.2.2.2.1
      have hcover := covers_sound (Γ := bindParams (hideConts Γ) ps) (Φ := liftMany ps.length Φ) (hg.1.eff 1) (effect_fails_support (effect_shift_support (hg.1.eff 0) _ _)) hc.2.2.2.2.2
      have hfn : (Ty.fn names ps (h.ty 0) (h.eff 0)).Support (· ∈ q.formation.atoms) := ⟨hp, hg.1.ty 0, hg.1.eff 0⟩
      obtain ⟨rfl, rfl⟩ := resultEq_sound hfn (empty_effect_support _) ha he hc.1
      exact .E_MethName hhead.1 hc.2.1 (annotation_sound hq hΓ hfn hc.2.2.1) hb hsub hcover
    · cases hc
  · cases hc

theorem opDicts_step {h cs} : ExprSoundAt (.node .E_OpDicts h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i o ts ds names ps
    split at hc
    · rename_i t returned ht
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hhead := head_sound hq hΓ hs.1 hg.1 ht
      have hds : returned = ds := hhead.2.2
      subst returned
      have hp := hs.2.2
      have hΓ' := CtxSupport.bind (CtxSupport.hide hΓ) hp
      have hv := values_append_support (dicts_renamed_support hs.2.1 ps.length) (boundVars_support q.formation.atoms ps.length)
      have ht' := tel_shift_support hhead.2.1 ps.length 0
      have hb := valsTel_sound hq (CtxSupport.hide hΓ) hΓ' hv ht' (hg.1.ty 1) (hg.1.eff 1) hg.1 hc.2.2.2.1
      have hsub := subtype_sound (hg.1.ty 1) (type_shift_support (hg.1.ty 0) _ _) hg.1 hc.2.2.2.2.1
      have hcover := covers_sound (Γ := bindParams (hideConts Γ) ps) (Φ := liftMany ps.length Φ) (hg.1.eff 1) (effect_fails_support (effect_shift_support (hg.1.eff 0) _ _)) hc.2.2.2.2.2
      have hfn : (Ty.fn names ps (h.ty 0) (h.eff 0)).Support (· ∈ q.formation.atoms) := ⟨hp, hg.1.ty 0, hg.1.eff 0⟩
      obtain ⟨rfl, rfl⟩ := resultEq_sound hfn (empty_effect_support _) ha he hc.1
      exact .E_OpDicts hhead.1 hc.2.1 (annotation_sound hq hΓ hfn hc.2.2.1) hb hsub hcover
    · cases hc
  · cases hc

theorem nullCon_step {h cs} : ExprSoundAt (.node .E_NullCon h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i c ts
    split at hc
    · rename_i cd hcd
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hdata : (Ty.data cd.data ts).Support (· ∈ q.formation.atoms) := hs
      obtain ⟨rfl, rfl⟩ := resultEq_sound hdata (empty_effect_support _) ha he hc.1
      exact .E_NullCon hcd hc.2.1.1 hc.2.1.2 (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.1)
        (annotation_sound hq hΓ hdata hc.2.2.2)
    · cases hc
  · cases hc

theorem externalName_step {h cs} : ExprSoundAt (.node .E_ExternalName h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f ts
    split at hc
    · rename_i d hd
      have hdecl := (Bool.and_eq_true_iff.mp hc).1
      replace hc := (Bool.and_eq_true_iff.mp hc).2
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hts : Ty.SupportList (· ∈ q.formation.atoms) ts := hs
      have ht := hq.tables.externals f d hd
      have hit := CheckFormation.instTel_support (es := []) ht hts (by intro e he; cases he)
      have hcall : ExternalCallAdmissible q.D.core q.B C d ts := ⟨hc.2.1,
        CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.1,
        CheckArguments.satAll_sound hq.sat hts hc.2.2.2.1,
        CheckFormation.annotations_sound hq.formation (CtxSupport.empty _) hts hc.2.2.2.2.1⟩
      have hsig := CheckOpenFormation.signatureInstance_sound hq.formation hΓ ht hts (by intro e he; cases he) hc.2.2.2.2.2
      obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .dependentFn (CheckFormation.instTel q.formation d.parameters ts [])) hit (empty_effect_support _) ha he hc.1
      rw [CheckFormation.instTel_eq ht hts (by intro e he; cases he)]
      exact .E_ExternalName hd
        (OpenRangeFormationCheck.tel_sound ht (Bool.and_eq_true_iff.mp hdecl).2)
        (OpenLeafFormation.external_of_check (of_decide_eq_true (Bool.and_eq_true_iff.mp hdecl).1) hcall) hsig.sound
    · cases hc
  · cases hc

theorem raise_step {h cs} : ExprSoundAt (.node .E_Raise h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i t error
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    have hfn : (Ty.fn ["error"] [error] t (singleFailure q error)).Support (· ∈ q.formation.atoms) :=
      ⟨⟨hs.2, trivial⟩, hs.1, singleFailure_support hs.2⟩
    have hann := annotation_sound hq hΓ hfn hc.2.1
    obtain ⟨rfl, rfl⟩ := resultEq_sound hfn (empty_effect_support _) ha he hc.1
    rw [singleFailure_eq hs.2] at hann ⊢
    exact .E_Raise hann hc.2.2.1 hc.2.2.2.1 (CheckFormation.kindTy_sound hq.formation.ctors hc.2.2.2.2)
  · cases hc

theorem conValue_step {h cs} : ExprSoundAt (.node .E_ConValue h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i c ts names ps
    split at hc
    · rename_i cd hcd
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      have hargs := hq.formation.fields c cd hcd
      have hinst := substituted_types_support hargs hs.1
      have hps := CheckArguments.tysEq_sound hs.2 hinst hc.2.2.1
      rw [substituted_types_eq hargs hs.1] at hps
      have hshift := types_support_shift hs.1 ps.length
      have hvals := valsTys_sound hq hΓ (CtxSupport.bind (CtxSupport.hide hΓ) hs.2)
        (boundVars_support _ _) (substituted_types_support hargs hshift) hg.1 hc.2.2.2.2.2.2
      rw [substituted_types_eq hargs hshift] at hvals
      have hwf : ∀ a ∈ cd.args, a.WF 0 cd.ntys 0 := by
        intro b hb
        exact CheckFormation.wfTy_sound (Ty.SupportList.iff.mp hargs b hb) (List.all_eq_true.mp hc.2.2.2.2.1 b hb)
      have hfn : (Ty.fn names ps (.data cd.data ts) Eff.empty).Support (· ∈ q.formation.atoms) :=
        ⟨hs.2, hs.1, empty_effect_support _⟩
      have hann := annotation_sound hq hΓ hfn hc.2.2.2.2.2.1
      obtain ⟨rfl, rfl⟩ := resultEq_sound hfn (empty_effect_support _) ha he hc.1
      exact .E_ConValue hcd hc.2.1.1 hc.2.1.2.1 hc.2.1.2.2.1 hps hc.2.1.2.2.2
        (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.2.1) hwf (hq.patterns c cd hcd) hann hvals
    · cases hc
  · cases hc

end Benitoite.Release.Refinement.Surface.CheckOpen
