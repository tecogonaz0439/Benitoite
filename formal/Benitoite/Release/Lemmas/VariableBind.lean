import Benitoite.Release.Lemmas.Closed

/-!
# 開いた型の像による代入と整形式

同じ外側の型パラメータを参照する型と行の像から、代入後の型の範囲と正規形を得る。
Fail内部も同時に代入する（設計書 01-12「型付け規則」）。
-/
namespace Benitoite.Release

mutual
  theorem Ty.bind_clean {n m : Nat} (θ : SubstEnv)
      (ht : ∀ i < m, TyOK n (θ.types i))
      (he : ∀ e ∈ θ.rows, Eff.VarsIn 0 n (fun _ => True) e)
      (t : Ty) (h : TyOK m t) : TyOK n (Ty.bind θ t) := by
    cases t <;> simp only [TyOK, Ty.VarsIn] at h <;>
      simp only [Ty.bind, Ty.rawBind, Ty.norm, TyOK, Ty.VarsIn]
    all_goals first
      | trivial
      | exact Ty.bind_clean θ ht he _ h
      | exact Ty.bindTys_clean θ ht he _ h
      | skip
    case tvar i => exact Ty.norm_VarsIn _ (ht i h)
    case fn ns ps r e =>
      refine ⟨?_, Ty.bindTys_clean θ ht he ps h.2.1,
        Ty.bind_clean θ ht he r h.2.2.1, Eff.bind_clean θ ht he e h.2.2.2.1, Eff.norm_idem _⟩
      simpa only [NamesWF, Ty.normTys_eq_map, Ty.rawBindTys_eq_map, List.length_map] using h.1
    case map a b => exact ⟨Ty.bind_clean θ ht he a h.1, Ty.bind_clean θ ht he b h.2⟩
    case tapp i ts =>
      have hh := Ty.applyTo_varsIn (Ty.norm_VarsIn _ (ht i h.1))
        (Ty.bindTys_clean θ ht he ts h.2)
      rw [Ty.applyTo_eq_raw_norm, Ty.norm_rawApplyTo] at hh
      exact hh

  theorem Ty.bindTys_clean {n m : Nat} (θ : SubstEnv)
      (ht : ∀ i < m, TyOK n (θ.types i))
      (he : ∀ e ∈ θ.rows, Eff.VarsIn 0 n (fun _ => True) e)
      (ts : List Ty) (h : Ty.VarsInList 0 m (fun _ => True) ts) :
      Ty.VarsInList 0 n (fun _ => True) (Ty.normTys (Ty.rawBindTys θ ts)) := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.bind_clean θ ht he t h.1, Ty.bindTys_clean θ ht he ts h.2⟩

  theorem Eff.bind_clean {n m : Nat} (θ : SubstEnv)
      (ht : ∀ i < m, TyOK n (θ.types i))
      (he : ∀ e ∈ θ.rows, Eff.VarsIn 0 n (fun _ => True) e)
      (e : Eff) (h : Eff.VarsIn 0 m (fun _ => True) e) :
      Eff.VarsIn 0 n (fun _ => True) (Eff.bind θ e) := by
    cases e with
    | mk a fs =>
      refine ⟨fun _ _ => trivial, Ty.VarsInList.iff.mpr ?_,
        Eff.substAtoms_wf h.2.2 (fun f hf => by cases f; exact (he _ hf).2.2)⟩
      intro t hm
      change t ∈ Order.sortUnique tyCompare
        (Ty.normTys (Ty.rawBindTys θ fs ++ Eff.rowFails θ.rows a)) at hm
      rw [Ty.normTys_append] at hm
      rcases List.mem_append.mp (Order.mem_sortUnique.mp hm) with hm | hm
      · exact Ty.VarsInList.iff.mp (Ty.bindTys_clean θ ht he fs h.2.1) t hm
      · obtain ⟨x, hx, rfl⟩ := List.mem_map.mp (show t ∈ (Eff.rowFails θ.rows a).map Ty.norm from by
          simpa only [Ty.normTys_eq_map] using hm)
        obtain ⟨i, e, hi, _, hx⟩ := Eff.mem_rowFails.mp hx
        cases e with
        | mk b gs =>
          exact Ty.norm_VarsIn x
            (Ty.VarsInList.iff.mp (he (.mk b gs) (List.mem_of_getElem? hi)).2.1 x hx)
end

theorem Ty.subst_clean {n : Nat} (ts : List Ty) (es : List Eff)
    (ht : Ty.VarsInList 0 n (fun _ => True) ts)
    (he : ∀ e ∈ es, Eff.VarsIn 0 n (fun _ => True) e) (t : Ty) (h : TyOK ts.length t) :
    TyOK n (t.subst ts es) := by
  rw [Ty.subst, Ty.substAt_eq_bind]
  apply Ty.bind_clean (m := ts.length)
  · intro i hi
    simpa [SubstEnv.at, hi, Ty.rawShift_zero] using
      Ty.VarsInList.iff.mp ht ts[i] (List.getElem_mem hi)
  · intro e hm
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp hm
    rw [Eff.rawShift_zero]
    exact he f hf
  · exact h

theorem Eff.subst_clean {n : Nat} (ts : List Ty) (es : List Eff)
    (ht : Ty.VarsInList 0 n (fun _ => True) ts)
    (he : ∀ e ∈ es, Eff.VarsIn 0 n (fun _ => True) e) (e : Eff)
    (h : Eff.VarsIn 0 ts.length (fun _ => True) e) :
    Eff.VarsIn 0 n (fun _ => True) (Eff.substAt 0 ts es e) := by
  apply Eff.bind_clean (m := ts.length)
  · intro i hi
    simpa [SubstEnv.at, hi, Ty.rawShift_zero] using
      Ty.VarsInList.iff.mp ht ts[i] (List.getElem_mem hi)
  · intro f hm
    obtain ⟨g, hg, rfl⟩ := List.mem_map.mp hm
    rw [Eff.rawShift_zero]
    exact he g hg
  · exact h

end Benitoite.Release
