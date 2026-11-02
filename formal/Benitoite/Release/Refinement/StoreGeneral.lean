import Benitoite.Release.Refinement.HandlerGeneral

/-! # 有限なストアの空き場所とセルの更新 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem finite_set_all {μ : Store} (h : ∃ n, ∀ l, n ≤ l → μ l = none)
    (l : Nat) (c : Cell) : ∃ n, ∀ i, n ≤ i → (μ.set l c) i = none := by
  obtain ⟨n,hn⟩ := h
  refine ⟨max n (l+1),?_⟩
  intro i hi
  have hil : i ≠ l := by omega
  simp only [Store.set,hil,↓reduceIte]
  exact hn i (by omega)

theorem StoreOk.write_cell {P B σ Ψ μ l c}
    (h : StoreOk P B σ Ψ μ) (hc : CellOk P B σ Ψ l c) :
    StoreOk P B σ Ψ (μ.set l c) := by
  refine ⟨finite_set_all h.finite l c,h.wf,h.sorted,h.declared,?_,?_⟩
  · intro i x hx
    by_cases hi : i = l
    · simp [Store.set,hi]
    · simpa only [Store.set,hi,↓reduceIte] using h.domain i x hx
  · intro i x hx
    by_cases hi : i = l
    · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hx; subst x; exact hc
    · simp only [Store.set,hi,↓reduceIte] at hx; exact h.cell i x hx

theorem StoreOk.allocate_cell {P B σ Ψ μ l x c}
    (h : StoreOk P B σ Ψ μ) (hB : B.ValueAssumptions P) (hl : μ l = none)
    (hw : x.WF) (hs : x.Sorted) (hd : x.Declared P)
    (hc : CellOk P B σ (Ψ.put l x) l c) :
    StoreOk P B σ (Ψ.put l x) (μ.set l c) := by
  have hn : Ψ l = none := by
    cases hh : Ψ l with
    | none => rfl
    | some y => exact False.elim (h.domain l y hh hl)
  have he := StoreTy.extends_put (x := x) hn
  refine ⟨finite_set_all h.finite l c,?_,?_,?_,?_,?_⟩
  · intro i y hy
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hy; subst y; exact hw
    · simp only [StoreTy.put,hi,↓reduceIte] at hy; exact h.wf i y hy
  · intro i y hy
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hy; subst y; exact hs
    · simp only [StoreTy.put,hi,↓reduceIte] at hy; exact h.sorted i y hy
  · intro i y hy
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hy; subst y; exact hd
    · simp only [StoreTy.put,hi,↓reduceIte] at hy; exact h.declared i y hy
  · intro i y hy
    by_cases hi : i = l
    · simp [Store.set,hi]
    · simp only [StoreTy.put,hi,↓reduceIte] at hy
      simpa only [Store.set,hi,↓reduceIte] using h.domain i y hy
  · intro i y hy
    by_cases hi : i = l
    · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hy; subst y; exact hc
    · simp only [Store.set,hi,↓reduceIte] at hy
      exact (h.cell i y hy).store hB h.wf he

theorem StoreOk.fresh {P B σ Ψ μ} (h : StoreOk P B σ Ψ μ) :
    ∃ l, μ l = none ∧ Ψ l = none := by
  obtain ⟨n,hn⟩ := h.finite
  have hl := hn n (Nat.le_refl n)
  refine ⟨n,hl,?_⟩
  cases hx : Ψ n with
  | none => rfl
  | some x => exact False.elim (h.domain n x hx hl)

theorem Store.Closed.set_cell {μ : Store} {l c} (h : μ.Closed) (hc : c.Closed) :
    (μ.set l c).Closed := by
  intro i x hx
  by_cases hi : i = l
  · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hx; subst x; exact hc
  · simp only [Store.set,hi,↓reduceIte] at hx; exact h i x hx

end
end Benitoite.Release.Refinement
