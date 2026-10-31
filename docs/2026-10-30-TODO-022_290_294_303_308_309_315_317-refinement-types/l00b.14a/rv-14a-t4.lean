import Benitoite.Release.Refinement.DependentBeta
namespace Benitoite.Release.Refinement
noncomputable section

theorem hideMap (Γ : Ctx) : ShiftMap 0 0 Γ (Refinement.hideConts Γ) := by
  refine ⟨by simp [Refinement.hideConts], ?_⟩
  intro i a hi ho
  simpa [shiftIndex_zero, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩

/-- DependentClosureTy の捕捉（Γ・R=none）を、本体の hideConts Γ と任意の R へ移す。 -/
theorem CaptureOk.hideConts_any {P B Ψ R R' Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R' (Refinement.hideConts Γ) Φ cap := by
  have hm := hideMap Γ
  cases h with
  | mk hw hn hh hs hf hg himg he =>
    have hlen : (Refinement.hideConts Γ).length = Γ.length := by simp [Refinement.hideConts]
    refine .mk ?_ (hn.trans hlen.symm) ?_ ?_ ?_ hg ?_ ?_
    · intro i a hi
      obtain ⟨hl,_⟩ := hideConts_lookup.mp hi
      rw [hlen]; exact hw i a hl
    · intro i a hi
      exact hh i a (hideConts_lookup.mp hi).1
    · intro i a hi
      obtain ⟨hl,_⟩ := hideConts_lookup.mp hi
      have := hs i a hl
      have h1 := hm.captureSorted this.1
      have h2 := hm.captureDeclared this.2
      simpa only [Ty.shiftV_zero] using And.intro h1 h2
    · intro p hp
      have hq := hf p hp
      have hx := Pred.WellFormed.shift hm (Pred.WellFormed.mk hq.1 hq.2.1 hq.2.2)
      rw [Pred.shiftV_zero] at hx
      exact ⟨hx.wf,hx.sorted,hx.declared⟩
    · intro i a hi
      obtain ⟨hl,ho⟩ := hideConts_lookup.mp hi
      cases himg i a hl with
      | ordinary _ hv => exact .ordinary ho hv
      | hidden hno _ => exact absurd ho hno
      | contLoc h0 _ _ _ _ _ => subst h0; simp_all [Ty.Ordinary,Ordinary,Ty.core]
      | contVar h0 _ _ => subst h0; simp_all [Ty.Ordinary,Ordinary,Ty.core]
    · intro p hp
      apply he
      rcases List.mem_append.mp hp with hp | hp
      · exact List.mem_append_left _ (Ctx.mem_facts_hide.mp hp)
      · exact List.mem_append_right _ hp

theorem HasTypeCQ.store_ext {P B store Q C Γ Φ R m a e L} (hb : HasTypeCQ P B store Q C Γ Φ R m a e L) {store'}
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.Extends store') :
    HasTypeCQ P B store' Q C Γ Φ R m a e L := by
  have hh := HasTypeCQ.shift_values hb (k := 0) (c := 0) hA hw hp
      ⟨rfl,by intro i a hi; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
      (LocalCtx.Shift.refl _) (Ξ := _) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [Ty.shiftV_zero,Eff.shiftV_zero,shiftIndex_zero,Comp.rename_identity,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,id_eq] using hh

theorem hide_extends (Ψ : StoreTy) : (hideBuilders Ψ).Extends Ψ := by
  intro l t ht
  unfold hideBuilders at ht
  cases hl : Ψ l with
  | none => simp [hl] at ht
  | some x => cases x <;> simp only [hl] at ht <;> cases ht <;> rfl


/-- 評価済みの閉包（捕捉 cap・Γ/Φ を持つ）の一引数の適用を、DependentClosureTy の中身から型付ける。 -/
theorem ClosureTy.closure_one {P B Ψ Γ Φ cap n x a e code v}
    (hA : Builtins.ValueAssumptions P B) (hW : Ψ.WF)
    (hc : CaptureOk P B (hideBuilders Ψ) none Γ Φ cap)
    (hb : TelBodyTy P B (hideBuilders Ψ) Qempty [] (hideConts Γ) Φ (.param n x (.done a e)) code)
    (ha : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.param n x (.done a e))))
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy x)) (hg : v.Ground) :
    ClosureTy P B Ψ [] (some ((cap.extend v).closeTy a)) (.mk (cap.extend v) code)
      ((cap.extend v).closeTy a) ((cap.extend v).closeEff e) := by
  have hc1 : CaptureOk P B (hideBuilders Ψ) (some ((cap.extend v).closeTy a)) (hideConts Γ) Φ cap :=
    hc.hideConts_any
  have hc2 := CaptureOk.store hc1 hA hW.hide (hide_extends Ψ).preservesNormals
  have hx : Ty.Annotation P [] (hideConts Γ) x := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
  have hc3 := hc2.extend hx hv hg
  have hr : Ty.Annotation P [] ((hideConts Γ).extend x) (.dependentFn (.done a e)) :=
    ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ha.wf.2,
      ha.sorted.2,ha.declared.2⟩
  cases hb with
  | param hb =>
    cases hb with
    | done hb =>
      have hb' := hb.store_ext hA hW.hide (hide_extends Ψ)
      exact ClosureTy.capture hc3 hb' hr rfl (fun r h => by cases h; exact hr.declared.1)

#print axioms ClosureTy.closure_one
end
end Benitoite.Release.Refinement
