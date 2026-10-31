import Benitoite.Release.Refinement.Context.Capture
namespace Benitoite.Release.Refinement.RV03
noncomputable section

theorem hide_length (Γ : Ctx) : (hideConts Γ).length = Γ.length := by simp [hideConts]

theorem hideMap (Γ : Ctx) : ShiftMap 0 0 Γ (hideConts Γ) := by
  refine ⟨by simp [hide_length], ?_⟩
  intro i a hi ho
  simpa [shiftIndex_zero, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩

/-- 閉包の本体の文脈へ捕捉を移す。本番に同等の補題はない。 -/
theorem CaptureOk.hide {P B Ψ R R' Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R' (hideConts Γ) Φ cap := by
  have hm := hideMap Γ
  cases h with
  | mk hw hn hh hs hf hg hi he =>
    apply CaptureOk.mk
    · intro i a hx
      have hc := (Ty.CaptureWF.shift (hw i a (hideConts_lookup.mp hx).1) 0 0)
      simpa [Ty.shiftV_zero, hide_length] using hc
    · simpa [hide_length] using hn
    · intro i a hx; exact hh i a (hideConts_lookup.mp hx).1
    · intro i a hx
      have hy := hs i a (hideConts_lookup.mp hx).1
      have h1 := hm.captureSorted hy.1
      have h2 := hm.captureDeclared hy.2
      simpa [Ty.shiftV_zero] using And.intro h1 h2
    · intro p hp
      have hq := hf p hp
      have hv := Pred.Valid.shift hm (Pred.Valid.mk hq.1 hq.2.1 hq.2.2)
      simp only [Pred.shiftV_zero] at hv
      exact ⟨hv.wf, hv.sorted, hv.declared⟩
    · exact hg
    · intro i a hx
      obtain ⟨hl, ho⟩ := hideConts_lookup.mp hx
      cases hi i a hl with
      | ordinary o v => exact .ordinary o v
      | contLoc e => exact absurd e (ho _ _ _)
      | contVar e => exact absurd e (ho _ _ _)
    · intro p hp
      apply he
      rcases List.mem_append.mp hp with hp | hp
      · exact List.mem_append_left _ (Ctx.mem_facts_hide.mp hp)
      · exact List.mem_append_right _ hp

/-- 実際の DependentClosureTy の成分から、遷移先の本体の文脈の捕捉を作る。 -/
theorem beta_target {P B Ψ R Γ Φ cap t vs a e}
    (hc : CaptureOk P B Ψ none Γ Φ cap)
    (ht : Ty.Annotation P [] (hideConts Γ) (.dependentFn t))
    (hs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) a e)
    (hg : ∀ v ∈ vs, v.Ground) :
    CaptureOk P B Ψ R (t.context (hideConts Γ)) (liftMany t.arity Φ) (cap.extendMany vs) :=
  (CaptureOk.hide hc).extendTel ht hs hg
theorem hide_preserves (Ψ : StoreTy) : (hideBuilders Ψ).PreservesNormals Ψ := by
  intro l t ht hn
  unfold hideBuilders at ht
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp_all

/-- DependentClosureTy の成分（hideBuilders の店・R none・hideConts の本体）から E_Lam の先の捕捉へ。 -/
theorem full_target {P B Ψ R Γ Φ cap t vs a e}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (ht : Ty.Annotation P [] (hideConts Γ) (.dependentFn t))
    (hs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) a e)
    (hg : ∀ v ∈ vs, v.Ground) :
    CaptureOk P B Ψ R (t.context (hideConts Γ)) (liftMany t.arity Φ) (cap.extendMany vs) :=
  beta_target (hc.store hA hw.hide (hide_preserves Ψ)) ht hs hg

#print axioms beta_target
#print axioms full_target
end
end Benitoite.Release.Refinement.RV03
