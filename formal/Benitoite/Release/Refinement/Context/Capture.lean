import Benitoite.Release.Refinement.Context.Declarations

/-!
# 文脈の拡張に沿った捕捉の再構成

ソースの継続の行は従来の CaptureWF と同じく読まない。閉じた像の
契約は ImageOk が検査し、新しい facts は追加する値の型付けから導く。
-/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem closeTy_shift_of_env (ν μ : Nat → Val)
    (h : ∀ i, ν (i+1) = μ i) (a : Ty) :
    substTyValues ν (a.shiftV 1 0) = substTyValues μ a := by
  simp only [substTyValues, Ty.bind, ← Ty.rawSubstV_eq_rawBind, valEnv,
    Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV, Ty.rawSubstV_comp]
  congr 2
  funext i
  simp [shiftIndex, termBind?, h]

theorem Capture.closeTy_shift (cap : Capture) (v : Val) (a : Ty) :
    (cap.extend v).closeTy (a.shiftV 1 0) = cap.closeTy a :=
  closeTy_shift_of_env _ _ (fun _ => rfl) a

theorem Ty.CaptureWF.shift {nr nt nv a} (h : Ty.CaptureWF nr nt nv a) (k c : Nat) :
    (a.shiftV k c).CaptureWF nr nt (nv+k) := by
  cases a <;> try exact Ty.wf_shiftV h k c
  case cont b t e => exact ⟨Ty.wf_shiftV h.1 k c, Ty.wf_shiftV h.2 k c⟩

theorem ShiftMap.captureSorted {k c Γ Δ} {a : Ty} (h : ShiftMap k c Γ Δ) (ha : a.CaptureSorted Γ) :
    (a.shiftV k c).CaptureSorted Δ := by
  cases a <;> try exact h.sorted ha
  case cont b t e => exact ⟨h.sorted ha.1, h.sorted ha.2⟩

theorem ShiftMap.captureDeclared {P C k c Γ Δ} {a : Ty} (h : ShiftMap k c Γ Δ)
    (ha : a.CaptureDeclared P C Γ) : (a.shiftV k c).CaptureDeclared P C Δ := by
  cases a <;> try exact h.declared ha
  case cont b t e => exact ⟨h.declared ha.1, h.declared ha.2⟩

private theorem image_shift {P B Ψ R} {cap : Capture} {i : Nat} {a : Ty} (h : ImageOk P B Ψ Qempty [] [] [] R cap.env i a)
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

theorem CaptureOk.extend {P B Ψ R Γ Φ cap a v} (h : CaptureOk P B Ψ R Γ Φ cap)
    (ha : Ty.Annotation P [] Γ a) (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hg : v.Ground) : CaptureOk P B Ψ R (Γ.extend a) (Φ.map Pred.lift) (cap.extend v) := by
  have hm := ShiftMap.outerValue Γ (some (a.shiftV 1 0))
  have hnew := h.facts_extend hv
  have ho : a.Ordinary := (Ty.ordinary_bind_values a cap.env).mp
    (hv.notContCore (by simp [Ctx.WF])).ordinary
  cases h with
  | mk hw hn hh hs hf hground himg _ =>
    apply CaptureOk.mk
    · intro i b hi
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        simpa [Ctx.extend] using ha.wf.capture.shift 1 0
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x => cases hb; simpa [Ctx.extend] using (hw i x hx).shift 1 0
    · simpa [Capture.extend, Capture.values, Ctx.extend] using hn
    · intro i b hi
      cases i with
      | zero => exact ⟨v, rfl⟩
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x => exact hh i x hx
    · intro i b hi
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        exact ⟨(hm.annotation ha).sorted.capture, (hm.annotation ha).declared.capture⟩
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x =>
          cases hb
          exact ⟨hm.captureSorted (hs i x hx).1, hm.captureDeclared (hs i x hx).2⟩
    · intro p hp
      obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
      have hq := hf q hq
      have hp := Pred.WellFormed.shift hm (Pred.WellFormed.mk hq.1 hq.2.1 hq.2.2)
      exact ⟨hp.wf, hp.sorted, hp.declared⟩
    · intro ov hov w he
      rcases List.mem_cons.mp hov with rfl | hov
      · cases he; exact hg
      · exact hground ov hov w he
    · intro i b hi
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        apply ImageOk.ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho)
        rw [show substTyValues (cap.extend v).env (a.shiftV 1 0) = cap.closeTy a from cap.closeTy_shift v a]
        exact hv
      | succ i =>
        rw [Ctx.lookup_extend] at hi
        obtain ⟨x, hx, hb⟩ := Option.map_eq_some_iff.mp hi
        cases x with
        | none => cases hb
        | some x =>
          cases hb
          exact image_shift (himg i x hx) (cap.extend v).env (fun _ => rfl) (cap.closeTy_shift v)
    · exact hnew

/-- E_OpFail の None の位置には値 .loc κ が残る。Γ.extendNone と cap.extend w の組。 -/
theorem CaptureOk.extendHidden {P B Ψ R Γ Φ cap} (h : CaptureOk P B Ψ R Γ Φ cap) (w : Val) (hgw : w.Ground) :
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
      have hp := Pred.WellFormed.shift hm (Pred.WellFormed.mk hq.1 hq.2.1 hq.2.2)
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
          exact image_shift (himg i x hx) (cap.extend w).env (fun _ => rfl) (cap.closeTy_shift w)
    · intro p hp
      rcases List.mem_append.mp hp with hp | hp
      · obtain ⟨q, hq, rfl⟩ := Ctx.mem_facts_extendNone.mp hp
        rw [Capture.bind_extend_lift]
        exact hfact q (List.mem_append_left _ hq)
      · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        rw [Capture.bind_extend_lift]
        exact hfact q (List.mem_append_right _ hq)

/-- E_Op は継続の場所 .loc κ を some の継続の位置へ加える。 -/
theorem CaptureOk.extendCont {P B Ψ R Γ Φ cap b t e b' t' e' l} (h : CaptureOk P B Ψ R Γ Φ cap)
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
      have hp := Pred.WellFormed.shift hm (Pred.WellFormed.mk hq.1 hq.2.1 hq.2.2)
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
          exact image_shift (himg i y hy) (cap.extend (.loc l)).env (fun _ => rfl) (cap.closeTy_shift (.loc l))
    · intro p hp
      rcases List.mem_append.mp hp with hp | hp
      · rcases Ctx.mem_facts_extend.mp hp with hp | ⟨q, hq, rfl⟩
        · cases hp
        · rw [Capture.bind_extend_lift]
          exact hfact q (List.mem_append_left _ hq)
      · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        rw [Capture.bind_extend_lift]
        exact hfact q (List.mem_append_right _ hq)

theorem CaptureOk.extendTel {P B Ψ R Γ Φ cap t vs a e} (h : CaptureOk P B Ψ R Γ Φ cap)
    (ht : Ty.Annotation P [] Γ (.dependentFn t))
    (hs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (cap.closeTel t) a e)
    (hg : ∀ v ∈ vs, v.Ground) :
    CaptureOk P B Ψ R (t.context Γ) (liftMany t.arity Φ) (cap.extendMany vs) := by
  cases t with
  | done r f =>
    cases hs
    exact h
  | param n x t =>
    change HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs
      (.param n (cap.closeTy x) (Tel.bind (valEnv cap.env).up t)) a e at hs
    cases hs with
    | param _ hv hs =>
      have ht' : Ty.Annotation P [] (Γ.extend x) (.dependentFn t) :=
        ⟨by simpa [Ty.WF, Ctx.extend] using ht.wf.2, ht.sorted.2, ht.declared.2⟩
      have hs' := hs
      rw [Capture.openTel] at hs'
      have hrec := CaptureOk.extendTel (h.extend ⟨ht.wf.1, ht.sorted.1, ht.declared.1⟩ hv
        (hg _ List.mem_cons_self)) ht' hs' (fun v hv => hg v (List.mem_cons_of_mem _ hv))
      have hl : liftMany (t.arity+1) Φ = liftMany t.arity (Φ.map Pred.lift) := by
        rw [← liftMany_one, liftMany_add]
        congr 1
        omega
      simpa only [Capture.extendMany, List.foldl_cons, Tel.context, Tel.arity, Tel.names,
        List.length_cons, Tel.arity] using (hl.symm ▸ hrec)

end
end Benitoite.Release.Refinement
