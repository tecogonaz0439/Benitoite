import Benitoite.Release.Refinement.Surface.CheckSoundBase

/-! 引数列・穴・照合の腕・ハンドラの節の検査の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckFormation CheckPatterns CheckCompare

theorem checkTypesAt_step {g : Guide} (ih : SoundBelow g) : TypesSoundAt g := by
  intro q rows Δ C Γ Φ R path es as ε hq hΔ hΓ hR hs ha he hg h
  unfold checkTypesAt at h
  split at h
  · exact .nil
  · rename_i e es a as hints ge gs
    have hh := Bool.and_eq_true_iff.mp h
    exact .cons
      ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 ha.1 he hg.2.1 hh.1)
      ((ih gs (by simp_wf; omega)).types hq hΔ hΓ hR hs.2 ha.2 he hg.2.2.1 hh.2)
  · cases h

theorem checkEachAt_step {g : Guide} (ih : SoundBelow g) : EachSoundAt g := by
  intro q rows Δ C Γ Φ R path es a ε hq hΔ hΓ hR hs ha he hg h
  unfold checkEachAt at h
  split at h
  · exact .nil
  · rename_i e es hints ge gs
    have hh := Bool.and_eq_true_iff.mp h
    exact .cons
      ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 ha he hg.2.1 hh.1)
      ((ih gs (by simp_wf; omega)).each hq hΔ hΓ hR hs.2 ha he hg.2.2.1 hh.2)
  · cases h

theorem checkFixedAt_step {g : Guide} (ih : SoundBelow g) : FixedSoundAt g := by
  intro q rows Δ C Γ Φ R path args as ε hq hΔ hΓ hR hs ha he hg h
  unfold checkFixedAt at h
  split at h
  · exact .nil
  · rename_i label position e rest a as hints ge gr
    have hh := Bool.and_eq_true_iff.mp h
    exact .expr
      ((ih ge (by simp_wf; omega)).expr hq hΔ hΓ hR hs.1 ha.1 he hg.2.1 hh.1)
      ((ih gr (by simp_wf; omega)).fixed hq hΔ hΓ hR hs.2 ha.2 he hg.2.2.1 hh.2)
  · rename_i label position t rest hints gr
    exact .hole ((ih gr (by simp_wf; omega)).fixed hq hΔ hΓ hR hs.2 ha he hg.2.1 h)
  · cases h

theorem checkArmsAt_step {g : Guide} (ih : SoundBelow g) : ArmsSoundAt g := by
  intro q rows Δ C Γ Φ R p path arms a b ε hq hΔ hΓ hR hs ha hb he hg h
  unfold checkArmsAt at h
  split at h
  · exact .nil
  · rename_i alts body rest hints gb gr
    split at h
    · rename_i δ hδ
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq, scrutObservation_eq] at h
      have hδs := altsTy_support hq.formation ha hδ
      have hΓ' := CtxSupport.bind hΓ hδs
      exact .plain h.1 (altsTy_sound hq.formation ha hδ)
        ((linksValid_spec _ _ _).mp h.2.1)
        (factsWF_sound hq.formation hΓ' h.2.2.1)
        (factsWF_sound hq.formation hΓ h.2.2.2.1)
        ((ih gb (by simp_wf; omega)).block hq (hΔ.localExtend δ.length) hΓ' (hR.shift δ.length)
          hs.2.1 (type_shift_support hb _ _) (effect_shift_support he _ _) hg.2.1 h.2.2.2.2.1)
        ((ih gr (by simp_wf; omega)).arms hq hΔ hΓ hR hs.2.2 ha hb he hg.2.2.1 h.2.2.2.2.2)
    · cases h
  · rename_i alts guard body rest hints gg gb gr
    split at h
    · rename_i δ hδ
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq, scrutObservation_eq] at h
      have hδs := altsTy_support hq.formation ha hδ
      have hΓ' := CtxSupport.bind hΓ hδs
      exact .guarded h.1 (altsTy_sound hq.formation ha hδ)
        ((linksValid_spec _ _ _).mp h.2.1)
        (factsWF_sound hq.formation hΓ' h.2.2.1)
        (factsWF_sound hq.formation hΓ h.2.2.2.1)
        (annotation_sound hq (CtxSupport.hide hΓ') trivial h.2.2.2.2.1)
        ((ih gg (by simp_wf; omega)).expr hq (hΔ.localExtend δ.length) (CtxSupport.hide hΓ') trivial
          hs.1 trivial (empty_effect_support _) hg.2.1 h.2.2.2.2.2.1)
        ((ih gb (by simp_wf; omega)).block hq (hΔ.localExtend δ.length) hΓ' (hR.shift δ.length)
          hs.2.1 (type_shift_support hb _ _) (effect_shift_support he _ _) hg.2.2.1 h.2.2.2.2.2.2.1)
        ((ih gr (by simp_wf; omega)).arms hq hΔ hΓ hR hs.2.2 ha hb he hg.2.2.2.1 h.2.2.2.2.2.2.2)
    · cases h
  · cases h

theorem checkClausesAt_step {g : Guide} (ih : SoundBelow g) : ClausesSoundAt g := by
  intro q rows Δ C Γ Φ R εbody path cs a ε hq hΔ hΓ hR hs heb ha he hg h
  unfold checkClausesAt at h
  split at h
  · exact .nil
  · rename_i o n ntys body rest ndicts hints gb gr
    split at h
    · rename_i sg hsg
      simp only [allChecks, Bool.and_eq_true, and_true, decide_eq_true_eq] at h
      have hsig := CheckHandler.clauseSig_sound heb
        (fun b s hb => (hq.tables.prims b s hb).2.2.2) hsg
      have hfields := CheckHandler.opSigAt_support
        (fun o d hd => ⟨(hq.tables.ops o d hd).1, (hq.tables.ops o d hd).2.1⟩)
        (fun b s hb => ⟨(hq.tables.prims b s hb).1, (hq.tables.prims b s hb).2.1⟩)
        hsig.choose_spec.2.1
      have hR' : ReturnSupport q.formation.atoms
          (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length + 1) 0)) := by
        simpa only [Option.map_map, Function.comp_def] using
          (hR.shiftTypes sg.tparams.length 0).shift (sg.params.length + 1)
      exact .cons hsig h.1.1 h.1.2.1 h.1.2.2 (CheckHandler.sigWF_sound hfields.1 hfields.2 h.2.1)
        ((ih gb (by simp_wf; omega)).block hq (by intro i kind hi; cases i <;> cases hi)
          (clause_context_support hΓ hfields.1 hfields.2 ha he) hR' hs.1
          (type_shift_support (Ty.rawShift_support _ _ _ ha) _ _)
          (effect_shift_support (Eff.rawShift_support _ _ _ he) _ _) hg.2.1 h.2.2.1)
        ((ih gr (by simp_wf; omega)).clauses hq hΔ hΓ hR hs.2 heb ha he hg.2.2.1 h.2.2.2)
    · cases h
  · cases h

end Benitoite.Release.Refinement.Surface.Check
