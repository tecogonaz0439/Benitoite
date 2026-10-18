import Benitoite.Release.Lemmas.Basic
import Benitoite.Release.WellFormed
import Benitoite.Release.TypeScopedSubst

/-!
# 型の正しさ、ずらし、置き換えの補題（段階 B）

一般の同時代入から、型の正規形・範囲・型構成子への適用の保存を導く。
Fail 内部も同じ型と行を用いる（設計書 01-12「コア計算と脱糖」）。
-/

namespace Benitoite.Release

/-- 型構成子か型の変数（型引数を使う形）。 -/
def Ty.IsHead : Ty → Prop
  | .ctor _ | .tvar _ => True
  | _ => False

theorem Ty.applyTo_notHead (t : Ty) (as : List Ty) : ¬ (t.applyTo as).IsHead := by
  cases t with
  | ctor c => cases c <;> simp [Ty.applyTo, TyCon.apply, TyCon.rawApply, Ty.IsHead]
  | _ => simp [Ty.applyTo, Ty.norm, Ty.IsHead]

/-- 非先頭の型への適用は、正規形を仮定すると恒等である。 -/
theorem Ty.applyTo_of_notHead {t : Ty} (h : ¬ t.IsHead) (hc : t.Canonical) (as : List Ty) :
    t.applyTo as = t := by
  cases t <;> simp_all [Ty.applyTo, Ty.IsHead, Ty.Canonical]

theorem Ty.substAt_notHead {c ts es} (t : Ty) (h : ¬ t.IsHead) : ¬ (t.substAt c ts es).IsHead := by
  cases t with
  | tapp i as =>
    simp only [Ty.substAt]
    split
    · trivial
    · split
      · exact Ty.applyTo_notHead _ _
      · trivial
  | _ => simp_all [Ty.substAt, Ty.IsHead]

theorem Ty.shift_notHead {k c} (t : Ty) (h : ¬ t.IsHead) : ¬ (t.shift k c).IsHead := by
  cases t <;> simp_all [Ty.shift, Ty.IsHead]

/-- 型構成子への適用と同時代入の交換。 -/
theorem Ty.substAt_applyTo {c ts es} (t : Ty) (as : List Ty) :
    (t.applyTo as).substAt c ts es = (t.substAt c ts es).applyTo (as.map (Ty.substAt c ts es)) := by
  simp only [Ty.substAt_eq_bind, Ty.bind_applyTo, Ty.bindTys_eq_map]
  congr 1
  exact List.map_congr_left (fun a _ => (Ty.substAt_eq_bind c ts es a).symm)

theorem Ty.shift_applyTo {k c} (t : Ty) (as : List Ty) :
    (t.applyTo as).shift k c = (t.shift k c).applyTo (as.map (Ty.shift k c)) := by
  simp only [Ty.shift_eq_bind, Ty.bind_applyTo, Ty.bindTys_eq_map]
  congr 1
  exact List.map_congr_left (fun a _ => (Ty.shift_eq_bind k c a).symm)

theorem Ty.applyTo_wf {n : Nat} {t : Ty} {as : List Ty} (ht : Ty.WF n t) (has : Ty.WFList n as) :
    Ty.WF n (t.applyTo as) := by
  rw [Ty.applyTo_eq_raw_norm]
  exact Ty.norm_rawWF _ (Ty.rawApplyTo_rawWF t as (Ty.WF.raw t ht) (Ty.WFList.raw as has))

/-- 移動量零の恒等性は、型内部の正規形を前提にする。 -/
theorem Ty.shift_zero (c : Nat) (a : Ty) (h : a.Canonical) : a.shift 0 c = a := by
  rw [Ty.shift_zero_norm, h]

theorem Ty.shiftList_zero (c : Nat) (as : List Ty) (h : ∀ a ∈ as, a.Canonical) :
    as.map (Ty.shift 0 c) = as := by
  calc
    _ = as.map id := List.map_congr_left (fun a ha => Ty.shift_zero c a (h a ha))
    _ = as := List.map_id as

theorem Ty.shiftList_of_wf {c : Nat} (k : Nat) (as : List Ty) (w : Ty.WFList c as) :
    as.map (Ty.shift k c) = as := by
  calc
    _ = as.map id := List.map_congr_left (fun a ha => Ty.shift_of_wf k a (Ty.WFList.iff.mp w a ha))
    _ = as := List.map_id as

theorem Ty.shiftList_wf {n : Nat} (k : Nat) (as : List Ty) (w : Ty.WFList n as) :
    Ty.WFList (n + k) (as.map (Ty.shift k 0)) := by
  apply Ty.WFList.iff.mpr
  rintro t ht
  obtain ⟨a, ha, rfl⟩ := List.mem_map.mp ht
  exact Ty.shift_wf k a (Ty.WFList.iff.mp w a ha)

theorem Ty.substAtList_wf {c : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF 0 t) (hes : ∀ e ∈ es, Eff.WF 0 e)
    (as : List Ty) (w : Ty.WFList (c + ts.length) as) :
    Ty.WFList c (as.map (Ty.substAt c ts es)) := by
  apply Ty.WFList.iff.mpr
  rintro t ht
  obtain ⟨a, ha, rfl⟩ := List.mem_map.mp ht
  exact Ty.substAt_wf es hts hes a (Ty.WFList.iff.mp w a ha)

theorem Ty.shiftList_substAt {c k : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ t ∈ ts, Ty.WF 0 t) (hes : ∀ e ∈ es, Eff.WF 0 e) (as : List Ty) :
    (as.map (Ty.shift k 0)).map (Ty.substAt (c + k) ts es) =
      (as.map (Ty.substAt c ts es)).map (Ty.shift k 0) := by
  simp only [List.map_map]
  exact List.map_congr_left (fun a _ => Ty.shift_substAt es hts hes a)

end Benitoite.Release
