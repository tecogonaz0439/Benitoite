import Benitoite.Release.Refinement.Surface.CheckSoundSupport

/-! 専用の構築器の位置と、型を束縛する Fail 節の検査の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckCompare CheckFormation CheckArguments

private theorem kind_of_contents {a b : BuilderKind} (h : a.contents = b.contents) : a = b := by
  cases a <;> cases b <;> simp_all [BuilderKind.contents]

private theorem kind_shift_support {s : List Atom} {k : BuilderKind}
    (hk : k.contents.Support (· ∈ s)) (n : Nat) :
    (renameKind (· + n) k).contents.Support (· ∈ s) := by
  cases k <;> try trivial
  case list a =>
    have hξ : (· + n) = shiftIndex n 0 := by funext i; simp [shiftIndex]
    change (renameTy (· + n) a).Support (· ∈ s)
    rw [hξ, ← Ty.shiftV_eq_renameTy]
    exact type_shift_support hk n 0

private theorem builder_parameters_support {s : List Atom} {k : BuilderKind}
    (hk : k.contents.Support (· ∈ s)) (op : BuilderOp) : Ty.SupportList (· ∈ s) (op.parameters k) := by
  cases op <;> cases k <;> first | exact ⟨hk,trivial⟩ | trivial

private theorem builder_result_support {s : List Atom} {k : BuilderKind}
    (hk : k.contents.Support (· ∈ s)) (op : BuilderOp) : (op.resultType k).Support (· ∈ s) := by
  cases op <;> first | exact hk | trivial

theorem builderOp_step {h cs} (ih : SoundBelow (.node .E_BuilderOp h cs)) : ExprSoundAt (.node .E_BuilderOp h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i op i args kind ga
    split at hc
    · rename_i actual hlookup
      simp only [allChecks, Bool.and_eq_true, and_true] at hc
      have hk := kind_of_contents ((rawTyEq_spec (hΔ i actual hlookup) hs.1).mp hc.1)
      have hlookup' : Δ[i]? = some (some kind) := hk ▸ hlookup
      have hta := (rawTyEq_spec (builder_result_support hs.1 op) ha).mp hc.2.2.2.2.2
      rw [← hta]
      exact .E_BuilderOp hlookup' (annotation_sound hq hΓ hs.1 hc.2.1)
        (CheckFormation.argsKinded_sound hq.formation.ctors hc.2.2.1)
        ((ih ga (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).types
          hq hΔ hΓ hR hs.2 (hg.1.tys 0) he hg.2.1 hc.2.2.2.1)
        (valsTys_sound hq hΓ (CtxSupport.bind hΓ (hg.1.tys 0)) (boundVars_support _ _)
          (builder_parameters_support (kind_shift_support hs.1 _) op) hg.1 hc.2.2.2.2.1)
    · cases hc
  · cases hc

theorem handleFail_step {h cs} (ih : SoundBelow (.node .E_HandleFail h cs)) : ExprSoundAt (.node .E_HandleFail h cs) := by
  intro q rows Δ C Γ Φ R p path e a ε hq hΔ hΓ hR hs ha he hg hc
  rw [checkExprAt.eq_def] at hc
  dsimp only at hc
  replace hc := (Bool.and_eq_true_iff.mp hc).2
  split at hc
  · rename_i E t body clause gb gc
    simp only [allChecks, Bool.and_eq_true, and_true] at hc
    have hr := hg.1.eff 0
    have hec := hg.1.eff 1
    have heb := hg.1.eff 2
    have hres := resultEq_sound hs.2.1 (union_support hr hec) ha he hc.1
    have hout : Eff.union (h.eff 0) (h.eff 1) = ε :=
      (CheckHandler.union_eq (effect_fails_support hr) (effect_fails_support hec)).symm.trans hres.2
    have hsub := includes_sound heb (effect_fails_support (union_support (singleFailure_support hs.1) hr)) hc.2.2.1
    have hinner : union q (singleFailure q E) (h.eff 0) = Eff.union (Eff.singleFail E) (h.eff 0) := by
      rw [union, CheckHandler.union_eq (effect_fails_support (singleFailure_support hs.1)) (effect_fails_support hr),
        singleFailure_eq hs.1]
    rw [hinner] at hsub
    have hfc : CheckFormation.CtxSupport q.formation.atoms (failureContext Γ E) :=
      CtxSupport.extendNone ((CtxSupport.shiftTypes hΓ 1 0).extend (Ty.rawShift_support _ _ _ hs.1))
    have hret : ReturnSupport q.formation.atoms (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) := by
      simpa only [Option.map_map, Function.comp_def] using (hR.shiftTypes 1 0).shift 2
    rw [← hres.1, ← hout]
    exact .E_HandleFail
      ((ih gb (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).block
        hq hΔ hΓ hR hs.2.2.1 hs.2.1 heb hg.2.1 hc.2.1)
      hsub ((CheckAdmissible.noFailCheck_spec ((Eff.support_iff _).mp hr).1).mp hc.2.2.2.1)
      (annotation_sound hq hΓ hs.1 hc.2.2.2.2.1)
      (annotation_sound hq hΓ hs.2.1 hc.2.2.2.2.2.1)
      (CheckFormation.rowAnnotations_sound hq.formation hΓ (by intro f hf; cases List.mem_singleton.mp hf; exact hec)
        hc.2.2.2.2.2.2.1)
      ((ih gc (by simp only [Guide.node.sizeOf_spec, List.cons.sizeOf_spec, List.nil.sizeOf_spec]; omega)).block
        hq (by intro i k hi; cases i <;> cases hi) hfc hret hs.2.2.2
        (type_shift_support (Ty.rawShift_support _ _ _ hs.2.1) 2 0)
        (effect_shift_support (Eff.rawShift_support _ _ _ hec) 2 0) hg.2.2.1 hc.2.2.2.2.2.2.2)
  · cases hc

end Benitoite.Release.Refinement.Surface.Check
