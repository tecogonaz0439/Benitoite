import Benitoite.Release.Refinement.TypeShiftAlgebra

/-! WFによる型移動の恒等式。型全体の正規形はWFとは別に扱う。
設計書01-12「コア計算と脱糖」に対応する。 -/
namespace Benitoite.Release.Refinement

mutual
  theorem Ty.rawShift_of_wf {nr nv c : Nat} (k : Nat) (a : Ty) (h : a.WF nr c nv) :
      shiftTypes k c a = a := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [shiftTypes]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.rawShift_of_wf k _ h)
      | exact congrArg _ (Ty.rawShiftTys_of_wf k _ h)
      | exact congrArg _ (Tel.rawShift_of_wf k _ h)
      | skip
    case fn ns ps r e => rw [Ty.rawShiftTys_of_wf k ps h.2.1,
      Ty.rawShift_of_wf k r h.2.2.1, Eff.rawShift_of_wf k e h.2.2.2.1]
    case tvar i => simp only [h, ↓reduceIte]
    case cont a b e => rw [Ty.rawShift_of_wf k a h.1,
      Ty.rawShift_of_wf k b h.2.1, Eff.rawShift_of_wf k e h.2.2.1]
    case map a b => rw [Ty.rawShift_of_wf k a h.1, Ty.rawShift_of_wf k b h.2]
    case tapp i as => rw [ite_eq_left h.1, Ty.rawShiftTys_of_wf k as h.2]
    case refined a p => rw [Ty.rawShift_of_wf k a h.1]
  theorem Ty.rawShiftTys_of_wf {nr nv c : Nat} (k : Nat) (as : List Ty)
      (h : Ty.WFList nr c nv as) : shiftTypesList k c as = as := by
    cases as with
    | nil => rfl
    | cons a as => rw [shiftTypesList, Ty.rawShift_of_wf k a h.1, Ty.rawShiftTys_of_wf k as h.2]
  theorem Eff.rawShift_of_wf {nr nv c : Nat} (k : Nat) (e : Eff) (h : e.WF nr c nv) :
      shiftRowsTypes k c e = e := by
    cases e
    simp only [shiftRowsTypes, Ty.rawShiftTys_of_wf k _ h]
  theorem Tel.rawShift_of_wf {nr nv c : Nat} (k : Nat) (t : Tel) (h : t.WF nr c nv) :
      shiftTelTypes k c t = t := by
    cases t with
    | done r e => rw [shiftTelTypes, Ty.rawShift_of_wf k r h.1, Eff.rawShift_of_wf k e h.2.1]
    | param n a t => rw [shiftTelTypes, Ty.rawShift_of_wf k a h.1, Tel.rawShift_of_wf k t h.2]
end

theorem Ty.shift_of_wf {nr nv c : Nat} (k : Nat) (a : Ty) (h : a.WF nr c nv) :
    a.shift k c = a.norm := by
  rw [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes, Ty.rawShift_of_wf k a h]

theorem Eff.shift_of_wf {nr nv c : Nat} (k : Nat) (e : Eff) (h : e.WF nr c nv) :
    Eff.shift k c e = e.norm := by
  rw [Eff.shift, Eff.bind, Eff.rawBind_shiftTypes, Eff.rawShift_of_wf k e h]

end Benitoite.Release.Refinement
