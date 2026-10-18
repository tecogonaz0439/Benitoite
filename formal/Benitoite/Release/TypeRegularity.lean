import Benitoite.Release.Typing

/-!
# 型の整形式と正規形

埋め込んだ効果の正規形を整形式から導き、最上位の効果の整形式と区別する。
設計書 01-12「型付け規則」の規則条件に対応する。
-/

namespace Benitoite.Release

open Order

mutual
  /-- 整形式の型は、内部のすべての効果を含めて正規形である。 -/
  theorem Ty.WF.canonical {n : Nat} (t : Ty) (h : Ty.WF n t) : t.Canonical := by
    cases t <;> simp only [Ty.WF] at h <;> unfold Ty.Canonical <;> simp only [Ty.norm]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.WF.canonical _ h)
      | exact congrArg _ (Ty.WFList.norm_eq _ h)
      | skip
    case fn ns ps r e =>
      rw [Ty.WFList.norm_eq ps h.2.1, Ty.WF.canonical r h.2.2.1, h.2.2.2.2]
    case cont b t e => rw [Ty.WF.canonical b h.1, Ty.WF.canonical t h.2.1, h.2.2.2]
    case map a b => rw [Ty.WF.canonical a h.1, Ty.WF.canonical b h.2]
    case tapp i as => rw [Ty.WFList.norm_eq as h.2]

  theorem Ty.WFList.norm_eq {n : Nat} (as : List Ty) (h : Ty.WFList n as) : Ty.normTys as = as := by
    cases as with
    | nil => rfl
    | cons a as => rw [Ty.normTys, Ty.WF.canonical a h.1, Ty.WFList.norm_eq as h.2]
end

/-- 型内部の Canonical の条件は、正規化によって失われない。 -/
theorem Ty.norm_WF {n : Nat} (t : Ty) (h : Ty.WF n t) : Ty.WF n t.norm := by
  rw [h.canonical t]
  exact h

/-- 型列の所属による整形式の表現。 -/
theorem Ty.WFList.iff {n : Nat} {as : List Ty} : Ty.WFList n as ↔ ∀ a ∈ as, Ty.WF n a := by
  induction as with
  | nil => simp [Ty.WFList]
  | cons a as ih => simp [Ty.WFList, ih]

/-- 最上位の効果の列は未整列でもよい。正規化は、列に含まれる型の整形式を保つ。 -/
theorem Eff.norm_WF {n : Nat} (e : Eff) (h : Eff.WF n e) : Eff.WF n (Eff.norm e) := by
  cases e with
  | mk a fs =>
    simp only [Eff.norm, Eff.WF]
    apply Ty.WFList.iff.mpr
    intro t ht
    obtain ⟨u, hu, rfl⟩ := List.mem_map.mp (mem_sortUnique.mp (by
      simpa only [Ty.normTys_eq_map] using ht))
    exact Ty.norm_WF u (Ty.WFList.iff.mp h u hu)

/-- 包含では保存されない、最外の潜在効果の整形式と正規形。 -/
def Ty.LatentWF (n : Nat) : Ty → Prop
  | .fn _ _ _ e => Eff.WF n e ∧ Eff.Canonical e
  | _ => True

/-- 型の包含は、移動先の潜在効果の条件を明示すると整形式を保つ。 -/
theorem Ty.Le.wf {n a b} (h : Ty.Le a b) (w : Ty.WF n a) (wb : Ty.LatentWF n b) : Ty.WF n b := by
  rcases h with rfl | ⟨ns, ps, r, e, f, rfl, rfl, _⟩
  · exact w
  · exact ⟨w.1, w.2.1, w.2.2.1, wb⟩

/-- 逆向きの整形式にも、包含から得られない元の潜在効果の条件を明示する。 -/
theorem Ty.Le.wf_rev {n a b} (h : Ty.Le a b) (w : Ty.WF n b) (wa : Ty.LatentWF n a) : Ty.WF n a := by
  rcases h with rfl | ⟨ns, ps, r, e, f, rfl, rfl, _⟩
  · exact w
  · exact ⟨w.1, w.2.1, w.2.2.1, wa⟩

mutual
  theorem Ty.WF.mono {n m : Nat} (hn : n ≤ m) (t : Ty) (h : Ty.WF n t) : Ty.WF m t := by
    cases t <;> simp only [Ty.WF] at h ⊢
    all_goals first
      | exact h
      | exact Ty.WF.mono hn _ h
      | exact Ty.WFList.mono hn _ h
      | skip
    case fn ns ps r e => exact ⟨h.1, Ty.WFList.mono hn ps h.2.1, Ty.WF.mono hn r h.2.2.1,
      Eff.WF.mono hn e h.2.2.2.1, h.2.2.2.2⟩
    case tvar i => omega
    case cont b t e => exact ⟨Ty.WF.mono hn b h.1, Ty.WF.mono hn t h.2.1,
      Eff.WF.mono hn e h.2.2.1, h.2.2.2⟩
    case map a b => exact ⟨Ty.WF.mono hn a h.1, Ty.WF.mono hn b h.2⟩
    case tapp i as => exact ⟨by omega, Ty.WFList.mono hn as h.2⟩

  theorem Ty.WFList.mono {n m : Nat} (hn : n ≤ m) (as : List Ty) (h : Ty.WFList n as) : Ty.WFList m as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.WF.mono hn a h.1, Ty.WFList.mono hn as h.2⟩

  theorem Eff.WF.mono {n m : Nat} (hn : n ≤ m) (e : Eff) (h : Eff.WF n e) : Eff.WF m e := by
    cases e with
    | mk a fs => exact Ty.WFList.mono hn fs h
end

mutual
  /-- 入力が cutoff より内側の変数だけを使うとき、生の移動は恒等である。 -/
  theorem Ty.rawShift_of_wf {c : Nat} (k : Nat) (t : Ty) (h : Ty.WF c t) : t.rawShift k c = t := by
    cases t <;> simp only [Ty.WF] at h <;> simp only [Ty.rawShift]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.rawShift_of_wf k _ h)
      | exact congrArg _ (Ty.rawShiftTys_of_wf k _ h)
      | skip
    case fn ns ps r e => rw [Ty.rawShiftTys_of_wf k ps h.2.1, Ty.rawShift_of_wf k r h.2.2.1,
      Eff.rawShift_of_wf k e h.2.2.2.1]
    case tvar i => simp only [h, ↓reduceIte]
    case cont b t e => rw [Ty.rawShift_of_wf k b h.1, Ty.rawShift_of_wf k t h.2.1,
      Eff.rawShift_of_wf k e h.2.2.1]
    case map a b => rw [Ty.rawShift_of_wf k a h.1, Ty.rawShift_of_wf k b h.2]
    case tapp i as => rw [ite_eq_left h.1, Ty.rawShiftTys_of_wf k as h.2]

  theorem Ty.rawShiftTys_of_wf {c : Nat} (k : Nat) (as : List Ty) (h : Ty.WFList c as) :
      Ty.rawShiftTys k c as = as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.rawShiftTys, Ty.rawShift_of_wf k a h.1, Ty.rawShiftTys_of_wf k as h.2]

  theorem Eff.rawShift_of_wf {c : Nat} (k : Nat) (e : Eff) (h : Eff.WF c e) : Eff.rawShift k c e = e := by
    cases e with
    | mk a fs => simp only [Eff.rawShift, Ty.rawShiftTys_of_wf k fs h]
end

/-- 公開する移動の恒等式には、入力の正規形も必要である。 -/
theorem Ty.shift_of_wf {c : Nat} (k : Nat) (t : Ty) (h : Ty.WF c t) : t.shift k c = t := by
  rw [Ty.shift_eq_norm_rawShift, Ty.rawShift_of_wf k t h, Ty.WF.canonical t h]

theorem Eff.shift_of_wf {c : Nat} (k : Nat) (e : Eff) (h : Eff.WF c e) (hc : Eff.Canonical e) :
    Eff.shift k c e = e := by
  rw [Eff.shift, Eff.rawShift_of_wf k e h, hc]

end Benitoite.Release
