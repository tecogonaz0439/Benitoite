import Benitoite.Release.Refinement.Basic

/-!
# 値の移動と正規形

Nat/cutoff の単調な移動は述語と型の辞書式比較を保つ。
-/
namespace Benitoite.Release.Refinement
open Std Order



mutual
  theorem Ty.wf_shiftV {nr nt nv : Nat} {a : Ty} (h : a.WF nr nt nv) (k c : Nat) :
      (a.shiftV k c).WF nr nt (nv+k) := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Ty.shiftV, Ty.WF]
    all_goals first | exact h | exact Ty.wf_shiftV h k c | exact Ty.wfList_shiftV h k c | exact Tel.wf_shiftV h k c | skip
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF, shiftVTys_eq_map, List.length_map] using h.1,
        Ty.wfList_shiftV h.2.1 k c, Ty.wf_shiftV h.2.2.1 k c,
        Eff.wf_shiftV h.2.2.2.1 k c, by
          unfold Eff.Canonical
          rw [Eff.norm_shiftV, h.2.2.2.2]⟩
    case cont b t e =>
      exact ⟨Ty.wf_shiftV h.1 k c, Ty.wf_shiftV h.2.1 k c, Eff.wf_shiftV h.2.2.1 k c,
        by unfold Eff.Canonical; rw [Eff.norm_shiftV, h.2.2.2]⟩
    case map a b => exact ⟨Ty.wf_shiftV h.1 k c, Ty.wf_shiftV h.2 k c⟩
    case tapp i as => exact ⟨h.1, Ty.wfList_shiftV h.2 k c⟩
    case refined a p =>
      refine ⟨Ty.wf_shiftV h.1 k c, ?_, (Ty.notContCore_shiftV _ _ _).mpr h.2.2⟩
      have hp := Pred.wf_shiftV h.2.1 k (c+1)
      simpa only [Pred.shiftV, shiftIndex, Nat.add_right_comm nv k 1] using hp
  theorem Tel.wf_shiftV {nr nt nv : Nat} {t : Tel} (h : Tel.WF nr nt nv t) (k c : Nat) :
      Tel.WF nr nt (nv+k) (Tel.shiftV k c t) := by
    cases t with
    | done r e => exact ⟨Ty.wf_shiftV h.1 k c, Eff.wf_shiftV h.2.1 k c,
        by unfold Eff.Canonical; rw [Eff.norm_shiftV, h.2.2]⟩
    | param n a t => exact ⟨Ty.wf_shiftV h.1 k c,
        by simpa only [Nat.add_right_comm nv k 1] using Tel.wf_shiftV h.2 k (c+1)⟩
  theorem Ty.wfList_shiftV {nr nt nv : Nat} {as : List Ty} (h : Ty.WFList nr nt nv as) (k c : Nat) :
      Ty.WFList nr nt (nv+k) (shiftVTys k c as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.wf_shiftV h.1 k c, Ty.wfList_shiftV h.2 k c⟩
  theorem Eff.wf_shiftV {nr nt nv : Nat} {e : Eff} (h : e.WF nr nt nv) (k c : Nat) :
      (Eff.shiftV k c e).WF nr nt (nv+k) := by
    cases e
    exact Ty.wfList_shiftV h k c
end

end Benitoite.Release.Refinement
