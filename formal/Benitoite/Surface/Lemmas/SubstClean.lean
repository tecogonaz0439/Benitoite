import Benitoite.Surface.Lemmas.Invariants

/-! メソッドの型パラメータの内側で対象型を置き換えるときの範囲保存。 -/
namespace Benitoite.Surface
open Benitoite.Release


theorem substAt_clean {n ts} (c : Nat) (es : List Eff)
    (hts : Ty.VarsInList n (fun _ => True) ts)
    (hes : ∀ e ∈ es, Eff.VarsIn n (fun _ => True) e)
    (a : Ty) (ha : TyOK (c + ts.length) a) : TyOK (c + n) (a.substAt c ts es) := by
  rw [Ty.substAt_eq_bind]
  apply Ty.bind_clean (m := c + ts.length) _ _ _ a ha
  · intro i hi
    by_cases hic : i < c
    · simp only [SubstEnv.at, hic, ↓reduceIte, TyOK, Ty.VarsIn]
      omega
    · have hit : i - c < ts.length := by omega
      simp only [SubstEnv.at, hic, hit, ↓reduceIte, List.getElem?_eq_getElem hit, Option.getD_some]
      have hx := Ty.VarsInList.iff.mp hts _ (List.getElem_mem hit)
      have he : (ts[i-c]).shift c 0 = (ts[i-c]).rawShift c 0 := by
        rw [Ty.shift_eq_norm_rawShift]
        exact Ty.rawShift_canonical c 0 ((Ty.VarsIn.wf _ hx).canonical _)
      rw [← he]
      simpa only [Nat.add_comm] using shift_clean c _ hx
  · intro e hm
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp hm
    simpa only [Nat.add_comm] using rawShiftEff_clean c f (hes f hf)

theorem substAtList_clean {n ts} (c : Nat) (es : List Eff)
    (hts : Ty.VarsInList n (fun _ => True) ts)
    (hes : ∀ e ∈ es, Eff.VarsIn n (fun _ => True) e)
    (as : List Ty) (h : Ty.VarsInList (c + ts.length) (fun _ => True) as) :
    Ty.VarsInList (c + n) (fun _ => True) (as.map (Ty.substAt c ts es)) := by
  apply Ty.VarsInList.iff.mpr
  intro t ht
  obtain ⟨a, ha, rfl⟩ := List.mem_map.mp ht
  exact substAt_clean c es hts hes a (Ty.VarsInList.iff.mp h a ha)

end Benitoite.Surface
