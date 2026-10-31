import Benitoite.Release.Refinement.Context.Capture
namespace Benitoite.Release.Refinement.RV03
noncomputable section

theorem image_shift' {P B Ψ R} {cap : Capture} {i : Nat} {a : Ty} (h : ImageOk P B Ψ Qempty [] [] [] R cap.env i a)
    (ν : Nat → Val) (he : ∀ j, ν (j+1) = cap.env j)
    (ht : ∀ b : Ty, substTyValues ν (b.shiftV 1 0) = cap.closeTy b) :
    ImageOk P B Ψ Qempty [] [] [] R ν (i+1) (a.shiftV 1 0) := by
  cases h with
  | ordinary ho hv =>
    apply ImageOk.ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho)
    rw [ht, he]
    exact hv
  | contLoc hs hc hw hv hl hr =>
    subst a
    exact .contLoc rfl (by rw [ht]; exact hc) (by rw [ht]; exact hw)
      (by rw [he]; exact hv) hl hr
  | contVar _ _ hl => cases hl

/-- E_OpFail の None の位置には値 .loc κ が残る。Γ.extendNone と cap.extend w の組。 -/
theorem extendHidden {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) (w : Val) (hgw : w.Ground) :
    CaptureOk P B Ψ R Γ.extendNone (Φ.map Pred.lift) (cap.extend w) := by
  have hm := ShiftMap.outerValue Γ none
  cases h with
  | mk hw hn hh hs hf hground himg hfact =>
    apply CaptureOk.mk
    · intro i b hi
      cases i with
      | zero => cases hi
      | succ i =>
        rw [Ctx.lookup_extendNone] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x => cases hb; simpa [Ctx.extendNone] using (hw i x hx).shift 1 0
    · simpa [Capture.extend, Capture.values, Ctx.extendNone] using hn
    · intro i b hi
      cases i with
      | zero => cases hi
      | succ i =>
        rw [Ctx.lookup_extendNone] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x => exact hh i x hx
    · intro i b hi
      cases i with
      | zero => cases hi
      | succ i =>
        rw [Ctx.lookup_extendNone] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x =>
          cases hb
          exact ⟨hm.captureSorted (hs i x hx).1, hm.captureDeclared (hs i x hx).2⟩
    · intro p hp
      obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
      have hq := hf q hq
      have hp := Pred.Valid.shift hm (Pred.Valid.mk hq.1 hq.2.1 hq.2.2)
      exact ⟨hp.wf, hp.sorted, hp.declared⟩
    · intro ov hov x he
      rcases List.mem_cons.mp hov with rfl | hov
      · cases he; exact hgw
      · exact hground ov hov x he
    · intro i b hi
      cases i with
      | zero => cases hi
      | succ i =>
        rw [Ctx.lookup_extendNone] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x =>
          cases hb
          exact image_shift' (himg i x hx) (cap.extend w).env (fun _ => rfl) (cap.closeTy_shift w)
    · intro p hp
      rcases List.mem_append.mp hp with hp | hp
      · obtain ⟨q, hq, rfl⟩ := Ctx.mem_facts_extendNone.mp hp
        rw [Capture.bind_extend_lift]
        exact hfact q (List.mem_append_left _ hq)
      · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        rw [Capture.bind_extend_lift]
        exact hfact q (List.mem_append_right _ hq)

/-- E_Op は継続の場所 .loc κ を some の継続の位置へ加える。 -/
theorem extendCont {P B Ψ R Γ Φ cap b t e b' t' e' l} (h : CaptureOk P B Ψ R Γ Φ cap)
    (hcw : (Ty.cont b t e).CaptureWF 0 0 Γ.length)
    (hcs : (Ty.cont b t e).CaptureSorted Γ)
    (hcd : (Ty.cont b t e).CaptureDeclared P [] Γ)
    (hc : cap.closeTy (.cont b t e) = .cont b' t' e')
    (hcc : (cap.closeTy (.cont b t e)).WF 0 0 0)
    (hl : Ψ l = some (.cont b' t' e' R)) (hr : ∀ r, R = some r → r.WF 0 0 0) :
    CaptureOk P B Ψ R (Γ.extend (.cont b t e)) (Φ.map Pred.lift) (cap.extend (.loc l)) := by
  have hm := ShiftMap.outerValue Γ (some ((Ty.cont b t e).shiftV 1 0))
  cases h with
  | mk hw hn hh hs hf hground himg hfact =>
    apply CaptureOk.mk
    · intro i x hi
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        simpa [Ctx.extend] using hcw.shift 1 0
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨y, hy, hb⟩ := Option.map_eq_some_iff.mp hi
        cases y with
        | none => cases hb
        | some y => cases hb; simpa [Ctx.extend] using (hw i y hy).shift 1 0
    · simpa [Capture.extend, Capture.values, Ctx.extend] using hn
    · intro i x hi
      cases i with
      | zero => exact ⟨.loc l, rfl⟩
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨y, hy, hb⟩ := Option.map_eq_some_iff.mp hi
        cases y with
        | none => cases hb
        | some y => exact hh i y hy
    · intro i x hi
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        exact ⟨hm.captureSorted hcs, hm.captureDeclared hcd⟩
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨y, hy, hb⟩ := Option.map_eq_some_iff.mp hi
        cases y with
        | none => cases hb
        | some y =>
          cases hb
          exact ⟨hm.captureSorted (hs i y hy).1, hm.captureDeclared (hs i y hy).2⟩
    · intro p hp
      obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
      have hq := hf q hq
      have hp := Pred.Valid.shift hm (Pred.Valid.mk hq.1 hq.2.1 hq.2.2)
      exact ⟨hp.wf, hp.sorted, hp.declared⟩
    · intro ov hov x he
      rcases List.mem_cons.mp hov with rfl | hov
      · cases he; trivial
      · exact hground ov hov x he
    · intro i x hi
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        have hce := cap.closeTy_shift (.loc l) (.cont b t e)
        refine ImageOk.contLoc (b := _) (t := _) (e := _) (l := l) rfl ?_ ?_ rfl hl hr
        · exact hce.trans hc
        · change ((cap.extend (.loc l)).closeTy _).WF 0 0 0
          rw [hce]; exact hcc
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨y, hy, hb⟩ := Option.map_eq_some_iff.mp hi
        cases y with
        | none => cases hb
        | some y =>
          cases hb
          exact image_shift' (himg i y hy) (cap.extend (.loc l)).env (fun _ => rfl) (cap.closeTy_shift (.loc l))
    · intro p hp
      rcases List.mem_append.mp hp with hp | hp
      · rcases Ctx.mem_facts_extend.mp hp with hp | ⟨q, hq, rfl⟩
        · cases hp
        · rw [Capture.bind_extend_lift]
          exact hfact q (List.mem_append_left _ hq)
      · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        rw [Capture.bind_extend_lift]
        exact hfact q (List.mem_append_right _ hq)
#print axioms extendHidden
#print axioms extendCont
end
end Benitoite.Release.Refinement.RV03
