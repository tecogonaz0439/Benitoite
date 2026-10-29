import Benitoite.Release.Lemmas.Closed

/-! 節の型パラメータを加えるとき、型変数の範囲と継続型を含まない条件を保つ。 -/
namespace Benitoite.Surface
open Benitoite.Release

mutual
  theorem shift_clean {n : Nat} (ntys : Nat) :
      (a : Ty) → TyOK n a → TyOK (n + ntys) (a.shift ntys 0)
    | .base _, _ => by simp [Ty.shift, TyOK, Ty.VarsIn]
    | .opaque _ _, h => by simpa [Ty.shift, TyOK, Ty.VarsIn] using h
    | .data _ args, h => by
        simp only [Ty.shift, Ty.shiftTys_eq_map, TyOK, Ty.VarsIn] at h ⊢
        exact shiftList_clean ntys args h
    | .list a, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact shift_clean ntys a h
    | .fn names ps r e, h => by
        simp only [Ty.shift, Ty.shiftTys_eq_map, TyOK, Ty.VarsIn] at h ⊢
        exact ⟨by simpa only [NamesWF, List.length_map] using h.1, shiftList_clean ntys ps h.2.1, shift_clean ntys r h.2.2.1, shiftEff_clean ntys e h.2.2.2.1, Eff.shift_canonical ntys 0 e⟩
    | .tvar i, h => by
        simp only [TyOK, Ty.VarsIn] at h
        simp only [Ty.shift, TyOK, Ty.VarsIn, Nat.not_lt_zero, ↓reduceIte]
        omega
    | .reference a, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact shift_clean ntys a h
    | .lazy a, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact shift_clean ntys a h
    | .cont _ _ _, h => by exact False.elim h
    | .map a b, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact ⟨shift_clean ntys a h.1, shift_clean ntys b h.2⟩
    | .set a, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact shift_clean ntys a h
    | .bytes, _ => by simp [Ty.shift, TyOK, Ty.VarsIn]
    | .dict _ a, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact shift_clean ntys a h
    | .tapp i args, h => by
        simp only [TyOK, Ty.VarsIn] at h
        simp only [Ty.shift, Ty.shiftTys_eq_map, TyOK, Ty.VarsIn, Nat.not_lt_zero, ↓reduceIte]
        exact ⟨by have hi := h.1; omega,
          shiftList_clean ntys args h.2⟩
    | .ctor _, _ => by simp [Ty.shift, TyOK, Ty.VarsIn]

  theorem shiftList_clean {n : Nat} (ntys : Nat) :
      (as : List Ty) → Ty.VarsInList 0 n (fun _ => True) as →
        Ty.VarsInList 0 (n + ntys) (fun _ => True) (as.map (Ty.shift ntys 0))
    | [], _ => trivial
    | a :: as, h => by
        simp only [List.map_cons, Ty.VarsInList] at h ⊢
        exact ⟨shift_clean ntys a h.1, shiftList_clean ntys as h.2⟩
  theorem shiftEff_clean {n : Nat} (ntys : Nat) (e : Eff)
      (h : Eff.VarsIn 0 n (fun _ => True) e) :
      Eff.VarsIn 0 (n + ntys) (fun _ => True) (Eff.shift ntys 0 e) := by
    cases e with
    | mk a fs =>
      refine ⟨fun _ _ => trivial, Ty.VarsInList.iff.mpr ?_, h.2.2⟩
      intro t ht
      obtain ⟨x, hx, rfl⟩ := List.mem_map.mp (show t ∈ fs.map (Ty.shift ntys 0) from by
        change t ∈ Order.sortUnique tyCompare (Ty.normTys (Ty.rawShiftTys ntys 0 fs)) at ht
        have hm := Order.mem_sortUnique.mp ht
        rw [← Ty.shiftTys_eq_norm_rawShift, Ty.shiftTys_eq_map] at hm
        exact hm)
      exact shift_clean ntys x (Ty.VarsInList.iff.mp h.2.1 x hx)

end

/-- 行の像の最上位は整列せず、その中の型だけを移動する。 -/
theorem rawShiftEff_clean {n : Nat} (k : Nat) (e : Eff)
    (h : Eff.VarsIn 0 n (fun _ => True) e) :
    Eff.VarsIn 0 (n + k) (fun _ => True) (Eff.rawShift k 0 e) := by
  cases e with
  | mk a fs =>
    refine ⟨fun _ _ => trivial, Ty.VarsInList.iff.mpr ?_, h.2.2⟩
    intro t ht
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp
      (show t ∈ fs.map (Ty.rawShift k 0) from by simpa only [Ty.rawShiftTys_eq_map] using ht)
    have hclean := Ty.VarsInList.iff.mp h.2.1 x hx
    have he : x.shift k 0 = x.rawShift k 0 := by
      rw [Ty.shift_eq_norm_rawShift]
      exact Ty.rawShift_canonical k 0 ((Ty.VarsIn.wf x hclean).canonical x)
    rw [← he]
    exact shift_clean k x hclean

end Benitoite.Surface
