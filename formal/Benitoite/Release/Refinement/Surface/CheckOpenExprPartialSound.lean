import Benitoite.Release.Refinement.Surface.CheckOpenSoundSupport
import Benitoite.Release.Refinement.Surface.CheckValueSupport

/-! 穴を持つ呼出しの検査と、依存する結果を持つ部分適用の検査の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check CheckArguments
open CheckCompare CheckFormation CheckOpenArguments

/-- 穴の束縛を取り除いて戻せない結果型か効果は、一斉に移した外側の型と効果ではない。 -/
theorem dependentCheck_sound {q k ret eff}
    (hr : ret.Support (· ∈ q.formation.atoms)) (he : eff.Support (· ∈ q.formation.atoms))
    (h : dependentCheck q k ret eff = true) :
    ¬ ∃ (r0 : Ty) (e0 : Eff), ret = r0.shiftV k 0 ∧ eff = Eff.shiftV k 0 e0 := by
  rintro ⟨r0, e0, hret, heff⟩
  have hrt : ((ret.renameValues (unshiftValue k 0)).shiftV k 0).Support (· ∈ q.formation.atoms) :=
    type_shift_support ((Ty.support_renameValues_iff _ _ _).mpr hr) k 0
  have het : ((eff.renameValues (unshiftValue k 0)).shiftV k 0).Support (· ∈ q.formation.atoms) :=
    effect_shift_support ((Eff.support_renameValues_iff _ _ _).mpr he) k 0
  have hrr : (ret.renameValues (unshiftValue k 0)).shiftV k 0 = ret := by rw [hret, Ty.unshift_shift]
  have hee : (eff.renameValues (unshiftValue k 0)).shiftV k 0 = eff := by rw [heff, Eff.unshift_shift]
  have hrc := (rawTyEq_spec hrt hr).mpr hrr
  have hec := (rawEffEq_spec het he).mpr hee
  simp only [dependentCheck, hrc, hec, Bool.and_self, Bool.not_true, Bool.false_eq_true] at h

theorem partialCallDirect_step {h children} (ih : SoundBelow (.node .E_PartialCallDirect h children)) :
    ExprSoundAt (.node .E_PartialCallDirect h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f names args ret eff ga
    split at hc
    · rename_i t ds hhead
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      obtain ⟨holes, hr, hef, hout, call, hn, hann, hfixed, hvals, hle, hcover⟩ := hc
      have hp := holeTypes_support hsrc.2.1
      have hret := (rawTyEq_spec hsrc.2.2.1 (type_shift_support (hg.1.ty 0) _ _)).mp hr
      have heff := (rawEffEq_spec hsrc.2.2.2 (effect_shift_support (hg.1.eff 0) _ _)).mp hef
      obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .fn (args.holeNames names) args.holeTypes (h.ty 0) (h.eff 0)) ⟨hp, hg.1.ty 0, hg.1.eff 0⟩ (empty_effect_support _) ha he hout
      have hh := head_sound hq hΓ (source_head_inputs hsrc.1) hg.1 hhead
      have hd : DictsSupport q.formation.atoms ds := by rw [hh.2.2]; exact source_head_dictionaries hsrc.1
      have hΓ' := CtxSupport.bind (CtxSupport.bind (CtxSupport.hide hΓ) hp) (types_support_shift (hg.1.tys 0) args.holeTypes.length)
      have hb := (ih ga (by simp_wf; omega)).fixed (R := some (h.ty 0)) hq (by intro i k h; cases i <;> cases h)
        (CtxSupport.hide hΓ) (hg.1.ty 0) hsrc.2.1 (hg.1.tys 0) (hg.1.eff 0) hg.2.1 hfixed
      have hv := valsTel_sound hq hΓ hΓ'
        (values_append_support (dicts_renamed_support hd _)
          (recordFields_support (argVals_support _ args _) (by trivial)))
        (tel_shift_support hh.2.1 _ _) (hg.1.ty 1) (hg.1.eff 1) hg.1 hvals
      rw [hret, heff]
      exact .E_PartialCallDirect (by simpa using holes) hh.1 call hn
        (annotation_sound (a := .fn (args.holeNames names) args.holeTypes (h.ty 0) (h.eff 0)) hq hΓ ⟨hp, hg.1.ty 0, hg.1.eff 0⟩ hann) hb hv
        (subtype_sound (hg.1.ty 1) (type_shift_support (hg.1.ty 0) _ _) hg.1 hle)
        (covers_sound (hg.1.eff 1) (effect_fails_support (effect_shift_support (hg.1.eff 0) _ _)) hcover)
    · cases hc
  · cases hc

theorem partialCall_step {h children} (ih : SoundBelow (.node .E_PartialCall h children)) :
    ExprSoundAt (.node .E_PartialCall h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f names args ret eff gf ga
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    obtain ⟨direct, holes, hr, hef, hout, hfun, call, hn, hann, hfixed, hvals, hle, hcover⟩ := hc
    have hp := holeTypes_support hsrc.2.1
    have hret := (rawTyEq_spec hsrc.2.2.1 (type_shift_support (hg.1.ty 0) _ _)).mp hr
    have heff := (rawEffEq_spec hsrc.2.2.2 (effect_shift_support (hg.1.eff 0) _ _)).mp hef
    obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .fn (args.holeNames names) args.holeTypes (h.ty 0) (h.eff 0))
      ⟨hp, hg.1.ty 0, hg.1.eff 0⟩ (empty_effect_support _) ha he hout
    have hΓ' := CtxSupport.bind (CtxSupport.bind (CtxSupport.hide hΓ) hp)
      (types_support_shift (show Ty.SupportList (· ∈ q.formation.atoms) (.dependentFn (h.tel 0) :: h.tys 0) from ⟨hg.1.tel 0, hg.1.tys 0⟩) args.holeTypes.length)
    have hf := (ih gf (by simp_wf; omega)).expr (a := .dependentFn (h.tel 0)) (R := some (h.ty 0)) hq (by intro i k h; cases i <;> cases h)
      (CtxSupport.hide hΓ) (hg.1.ty 0) hsrc.1 (hg.1.tel 0) (hg.1.eff 0) hg.2.1 hfun
    have hb := (ih ga (by simp_wf; omega)).fixed (R := some (h.ty 0)) hq (by intro i k h; cases i <;> cases h)
      (CtxSupport.hide hΓ) (hg.1.ty 0) hsrc.2.1 (hg.1.tys 0) (hg.1.eff 0) hg.2.2.1 hfixed
    have hv := valsTel_sound hq hΓ hΓ' (recordFields_support (argVals_support _ args _) (by trivial))
      (tel_shift_support (hg.1.tel 0) _ _) (hg.1.ty 1) (hg.1.eff 1) hg.1 hvals
    rw [hret, heff]
    exact .E_PartialCall (by simpa using direct) (by simpa using holes) hf call hn
      (annotation_sound (a := .fn (args.holeNames names) args.holeTypes (h.ty 0) (h.eff 0)) hq hΓ
        ⟨hp, hg.1.ty 0, hg.1.eff 0⟩ hann) hb hv
      (subtype_sound (hg.1.ty 1) (type_shift_support (hg.1.ty 0) _ _) hg.1 hle)
      (covers_sound (hg.1.eff 1) (effect_fails_support (effect_shift_support (hg.1.eff 0) _ _)) hcover)
  · cases hc

theorem partialCallDirectDep_step {h children} (ih : SoundBelow (.node .E_PartialCallDirectDep h children)) :
    ExprSoundAt (.node .E_PartialCallDirectDep h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f names args ret eff ga
    split at hc
    · rename_i t ds hhead
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      obtain ⟨holes, hout, call, hn, hdep, hann, hretann, hfixed, hfcover, hvals, hle, hcover⟩ := hc
      have hp := holeTypes_support hsrc.2.1
      have ht := holeTel_support hp hsrc.2.2.1 hsrc.2.2.2 (args.holeNames names) 0
      obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff))
        ht (empty_effect_support _) ha he hout
      have hΓhole := CtxSupport.bind (CtxSupport.hide hΓ) hp
      have hh := head_sound hq hΓ (source_head_inputs hsrc.1) hg.1 hhead
      have hd : DictsSupport q.formation.atoms ds := by rw [hh.2.2]; exact source_head_dictionaries hsrc.1
      have hΓ' := CtxSupport.bind hΓhole (types_support_shift (hg.1.tys 0) args.holeTypes.length)
      have hb := (ih ga (by simp_wf; omega)).fixed (R := none) hq (by intro i k h; cases i <;> cases h)
        (CtxSupport.hide hΓ) (by trivial) hsrc.2.1 (hg.1.tys 0) (hg.1.eff 0) hg.2.1 hfixed
      have hv := valsTel_sound hq hΓ hΓ' (values_append_support (dicts_renamed_support hd _) (recordFields_support (argVals_support _ args _) (by trivial)))
        (tel_shift_support hh.2.1 _ _) (hg.1.ty 0) (hg.1.eff 1) hg.1 hvals
      exact .E_PartialCallDirectDep (by simpa using holes) hh.1 call hn
        (dependentCheck_sound hsrc.2.2.1 hsrc.2.2.2 hdep)
        (annotation_sound (a := .dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)) hq hΓ ht hann)
        (annotation_sound hq hΓhole hsrc.2.2.1 hretann) hb
        (covers_sound (effect_shift_support (hg.1.eff 0) _ _) (effect_fails_support hsrc.2.2.2) hfcover) hv
        (subtype_sound (hg.1.ty 0) (type_shift_support hsrc.2.2.1 _ _) hg.1 hle)
        (covers_sound (hg.1.eff 1) (effect_fails_support (effect_shift_support hsrc.2.2.2 _ _)) hcover)
    · cases hc
  · cases hc

theorem partialCallDep_step {h children} (ih : SoundBelow (.node .E_PartialCallDep h children)) :
    ExprSoundAt (.node .E_PartialCallDep h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i f names args ret eff gf ga
    simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
    obtain ⟨direct, holes, hout, hfun, call, hn, hdep, hann, hretann, hfixed, hfcover, hvals, hle, hcover⟩ := hc
    have hp := holeTypes_support hsrc.2.1
    have ht := holeTel_support hp hsrc.2.2.1 hsrc.2.2.2 (args.holeNames names) 0
    obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff))
      ht (empty_effect_support _) ha he hout
    have hΓhole := CtxSupport.bind (CtxSupport.hide hΓ) hp
    have hΓ' := CtxSupport.bind hΓhole
      (types_support_shift (show Ty.SupportList (· ∈ q.formation.atoms) (.dependentFn (h.tel 0) :: h.tys 0) from ⟨hg.1.tel 0, hg.1.tys 0⟩) args.holeTypes.length)
    have hf := (ih gf (by simp_wf; omega)).expr (a := .dependentFn (h.tel 0)) (R := none) hq (by intro i k h; cases i <;> cases h)
      (CtxSupport.hide hΓ) (by trivial) hsrc.1 (hg.1.tel 0) (hg.1.eff 0) hg.2.1 hfun
    have hb := (ih ga (by simp_wf; omega)).fixed (R := none) hq (by intro i k h; cases i <;> cases h)
      (CtxSupport.hide hΓ) (by trivial) hsrc.2.1 (hg.1.tys 0) (hg.1.eff 0) hg.2.2.1 hfixed
    have hv := valsTel_sound hq hΓ hΓ' (recordFields_support (argVals_support _ args _) (by trivial))
      (tel_shift_support (hg.1.tel 0) _ _) (hg.1.ty 0) (hg.1.eff 1) hg.1 hvals
    exact .E_PartialCallDep (by simpa using direct) (by simpa using holes) hf call hn
      (dependentCheck_sound hsrc.2.2.1 hsrc.2.2.2 hdep)
      (annotation_sound (a := .dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)) hq hΓ ht hann)
      (annotation_sound hq hΓhole hsrc.2.2.1 hretann) hb
      (covers_sound (effect_shift_support (hg.1.eff 0) _ _) (effect_fails_support hsrc.2.2.2) hfcover) hv
      (subtype_sound (hg.1.ty 0) (type_shift_support hsrc.2.2.1 _ _) hg.1 hle)
      (covers_sound (hg.1.eff 1) (effect_fails_support (effect_shift_support hsrc.2.2.2 _ _)) hcover)
  · cases hc

theorem partialCon_step {h children} (ih : SoundBelow (.node .E_PartialCon h children)) :
    ExprSoundAt (.node .E_PartialCon h children) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hsrc ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i c ts args ga
    split at hc
    · rename_i cd hcd
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at hc
      obtain ⟨hnt, holes, constructor, hout, hn, hk, hw, hdata, hann, hfixed, hvals, hle⟩ := hc
      have hp := holeTypes_support hsrc.2
      let hnames := args.holeNames (positionalNames args.positions.length)
      obtain ⟨rfl, rfl⟩ := resultEq_sound (actual := .fn hnames args.holeTypes (h.ty 0) (h.eff 0))
        ⟨hp, hg.1.ty 0, hg.1.eff 0⟩ (empty_effect_support _) ha he hout
      have hΓ' := CtxSupport.bind (CtxSupport.bind (CtxSupport.hide hΓ) hp) (types_support_shift (hg.1.tys 0) args.holeTypes.length)
      have hb := (ih ga (by simp_wf; omega)).fixed (R := some (h.ty 0)) hq (by intro i k h; cases i <;> cases h)
        (CtxSupport.hide hΓ) (hg.1.ty 0) hsrc.2 (hg.1.tys 0) (hg.1.eff 0) hg.2.1 hfixed
      have hts : Ty.SupportList (· ∈ q.formation.atoms) (shiftTs (args.holeTypes.length + (h.tys 0).length) ts) :=
        types_support_shift hsrc.1 _
      have hfields := hq.formation.fields c cd hcd
      have hsargs : Ty.SupportList (· ∈ q.formation.atoms)
          (cd.args.map (CheckFormation.substTy q.formation (shiftTs (args.holeTypes.length + (h.tys 0).length) ts) [])) := by
        apply Ty.SupportList.iff.mpr
        intro a ha
        obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
        exact CheckFormation.substTy_support (Ty.SupportList.iff.mp hfields b hb) hts (by simp)
      have heq : cd.args.map (CheckFormation.substTy q.formation (shiftTs (args.holeTypes.length + (h.tys 0).length) ts) []) =
          cd.args.map (Ty.subst (shiftTs (args.holeTypes.length + (h.tys 0).length) ts) []) :=
        List.map_congr_left fun a ha => CheckFormation.substTy_eq (Ty.SupportList.iff.mp hfields a ha) hts (by simp)
      have hv := valsTys_sound hq hΓ hΓ' (argVals_support _ args _) hsargs hg.1 hvals
      rw [heq] at hv
      exact .E_PartialCon hcd hnt (by simpa using holes) constructor hn
        (CheckFormation.argsKinded_sound hq.formation.ctors hk)
        (fun a ha => CheckFormation.wfTy_sound (Ty.SupportList.iff.mp hfields a ha) (List.all_eq_true.mp hw a ha))
        (hq.patterns c cd hcd)
        (annotation_sound hq hΓ hsrc.1 hdata)
        (annotation_sound (a := .fn hnames args.holeTypes (h.ty 0) (h.eff 0)) hq hΓ ⟨hp, hg.1.ty 0, hg.1.eff 0⟩ hann) hb hv
        (subtype_sound hts (type_shift_support (hg.1.ty 0) _ _) hg.1 hle)
    · cases hc
  · cases hc

end Benitoite.Release.Refinement.Surface.CheckOpen
