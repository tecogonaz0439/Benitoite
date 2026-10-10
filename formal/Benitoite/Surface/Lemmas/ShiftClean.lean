import Benitoite.Release.Lemmas.Closed

/-! 節の型パラメータを加えるとき、型変数の範囲と継続型を含まない条件を保つ。 -/
namespace Benitoite.Surface
open Benitoite.Release

mutual
  theorem shift_clean {n : Nat} (ntys : Nat) :
      (a : Ty) → TyOK n a → TyOK (n + ntys) (a.shift ntys 0)
    | .base _, _ => by simp [Ty.shift, TyOK, Ty.VarsIn]
    | .opaque _, _ => by simp [Ty.shift, TyOK, Ty.VarsIn]
    | .data _ args, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact shiftList_clean ntys args h
    | .list a, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact shift_clean ntys a h
    | .fn ps r _, h => by
        simp only [Ty.shift, TyOK, Ty.VarsIn] at h ⊢
        exact ⟨shiftList_clean ntys ps h.1, shift_clean ntys r h.2.1, h.2.2⟩
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
        simp only [Ty.shift, TyOK, Ty.VarsIn, Nat.not_lt_zero, ↓reduceIte]
        exact ⟨by have hi := h.1; omega,
          shiftList_clean ntys args h.2⟩
    | .ctor _, _ => by simp [Ty.shift, TyOK, Ty.VarsIn]

  theorem shiftList_clean {n : Nat} (ntys : Nat) :
      (as : List Ty) → Ty.VarsInList n (fun _ => True) as →
        Ty.VarsInList (n + ntys) (fun _ => True) (as.map (Ty.shift ntys 0))
    | [], _ => trivial
    | a :: as, h => by
        simp only [List.map_cons, Ty.VarsInList] at h ⊢
        exact ⟨shift_clean ntys a h.1, shiftList_clean ntys as h.2⟩
end

end Benitoite.Surface
