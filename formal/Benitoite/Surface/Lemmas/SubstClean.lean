import Benitoite.Surface.Lemmas.Invariants

/-! メソッドの型パラメータの内側で対象型を置き換えるときの範囲保存。 -/
namespace Benitoite.Surface
open Benitoite.Release

mutual
  theorem substAt_clean {n ts} (c : Nat) (es : List Eff) (hts : Ty.VarsInList n (fun _ => True) ts) :
      (a : Ty) → TyOK (c + ts.length) a → TyOK (c + n) (a.substAt c ts es)
    | .base _, _ => by simp [TyOK, Ty.substAt, Ty.VarsIn]
    | .opaque _, _ => by simp [TyOK, Ty.substAt, Ty.VarsIn]
    | .data _ as, h => by
        simpa [TyOK, Ty.substAt, Ty.VarsIn] using substAtList_clean c es hts as h
    | .list a, h => by simpa [TyOK, Ty.substAt, Ty.VarsIn] using substAt_clean c es hts a h
    | .fn ps r _, h => by
        simp only [TyOK, Ty.substAt, Ty.VarsIn] at h ⊢
        exact ⟨substAtList_clean c es hts ps h.1, substAt_clean c es hts r h.2.1, fun _ _ => trivial⟩
    | .tvar i, h => by
        simp only [TyOK, Ty.VarsIn] at h
        by_cases hi : i < c
        · simp only [Ty.substAt, hi, ↓reduceIte, TyOK, Ty.VarsIn]; omega
        · have hit : i - c < ts.length := by omega
          simp only [Ty.substAt, hi, hit, ↓reduceIte, List.getElem?_eq_getElem hit, Option.getD_some]
          simpa only [Nat.add_comm] using shift_clean c _ (varsInList_mem hts (List.getElem_mem hit))
    | .reference a, h => by simpa [TyOK, Ty.substAt, Ty.VarsIn] using substAt_clean c es hts a h
    | .lazy a, h => by simpa [TyOK, Ty.substAt, Ty.VarsIn] using substAt_clean c es hts a h
    | .cont _ _ _, h => by exact False.elim h
    | .map a b, h => by
        simp only [TyOK, Ty.substAt, Ty.VarsIn] at h ⊢
        exact ⟨substAt_clean c es hts a h.1, substAt_clean c es hts b h.2⟩
    | .set a, h => by simpa [TyOK, Ty.substAt, Ty.VarsIn] using substAt_clean c es hts a h
    | .bytes, _ => by simp [TyOK, Ty.substAt, Ty.VarsIn]
    | .dict _ a, h => by simpa [TyOK, Ty.substAt, Ty.VarsIn] using substAt_clean c es hts a h
    | .tapp i as, h => by
        have hh := substAtList_clean c es hts as h.2
        by_cases hi : i < c
        · simp only [Ty.substAt, hi, ↓reduceIte, TyOK, Ty.VarsIn]
          exact ⟨by omega, hh⟩
        · have hit : i - c < ts.length := by have := h.1; omega
          simp only [Ty.substAt, hi, hit, ↓reduceIte, List.getElem?_eq_getElem hit, Option.getD_some]
          apply Ty.applyTo_varsIn _ hh
          simpa only [Nat.add_comm] using shift_clean c _ (varsInList_mem hts (List.getElem_mem hit))
    | .ctor _, _ => by simp [TyOK, Ty.substAt, Ty.VarsIn]

  theorem substAtList_clean {n ts} (c : Nat) (es : List Eff) (hts : Ty.VarsInList n (fun _ => True) ts) :
      (as : List Ty) → Ty.VarsInList (c + ts.length) (fun _ => True) as →
        Ty.VarsInList (c + n) (fun _ => True) (as.map (Ty.substAt c ts es))
    | [], _ => trivial
    | a :: as, h => by exact ⟨substAt_clean c es hts a h.1, substAtList_clean c es hts as h.2⟩
end

end Benitoite.Surface
