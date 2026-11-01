import Benitoite.Release.Refinement.HandlerContinuation

/-! # 継続セルの割当てと使用済みへの更新 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem store_set_finite {μ : Store} (h : ∃ n, ∀ l, n ≤ l → μ l = none)
    (l : Nat) (c : Cell) : ∃ n, ∀ i, n ≤ i → (μ.set l c) i = none := by
  obtain ⟨n,hn⟩ := h
  refine ⟨max n (l+1),?_⟩
  intro i hi
  have hil : i ≠ l := by omega
  simp only [Store.set,hil,↓reduceIte]
  exact hn i (by omega)

theorem StoreOk.use_continuation {P B σ Ψ μ l a t ec R}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont a t ec R)) :
    StoreOk P B σ Ψ (μ.set l .used) := by
  refine ⟨store_set_finite h.finite l _,h.wf,h.sorted,h.declared,?_,?_⟩
  · intro i x hx
    by_cases hi : i = l
    · simp [Store.set,hi]
    · simpa only [Store.set,hi,↓reduceIte] using h.domain i x hx
  · intro i c hc
    by_cases hi : i = l
    · subst i
      simp only [Store.set,↓reduceIte,Option.some.injEq] at hc
      subst c
      exact ⟨a,t,ec,R,hl⟩
    · simp only [Store.set,hi,↓reduceIte] at hc
      exact h.cell i c hc

theorem StoreOk.allocate_continuation {P B σ Ψ μ l a t ec R saved}
    (h : StoreOk P B σ Ψ μ) (hA : Builtins.ValueAssumptions P B)
    (hl : μ l = none) (hw : LocTy.WF (.cont a t ec R))
    (ha : a.Sorted []) (ht : t.Sorted []) (he : sortedEff [] ec)
    (hd : LocTy.Declared P (.cont a t ec R)) (hend : EndsWithHandle saved)
    (hk : ∃ R0 e0, ContTy P B σ Ψ R0 e0 saved a t ec R) :
    StoreOk P B σ (Ψ.put l (.cont a t ec R)) (μ.set l (.cont saved)) := by
  have hnone : Ψ l = none := by
    cases he : Ψ l with
    | none => rfl
    | some t => exact False.elim (h.domain l t he hl)
  have hext := StoreTy.extends_put (x := LocTy.cont a t ec R) hnone
  refine ⟨store_set_finite h.finite l _,?_,?_,?_,?_,?_⟩
  · intro i x hx
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hx
      subst x; exact hw
    · simp only [StoreTy.put,hi,↓reduceIte] at hx; exact h.wf i x hx
  · intro i x hx
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hx
      subst x; exact ⟨ha,ht,he⟩
    · simp only [StoreTy.put,hi,↓reduceIte] at hx; exact h.sorted i x hx
  · intro i x hx
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hx
      subst x; exact hd
    · simp only [StoreTy.put,hi,↓reduceIte] at hx; exact h.declared i x hx
  · intro i x hx
    by_cases hi : i = l
    · simp [Store.set,hi]
    · simp only [StoreTy.put,hi,↓reduceIte] at hx
      simpa only [Store.set,hi,↓reduceIte] using h.domain i x hx
  · intro i c hc
    by_cases hi : i = l
    · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hc
      subst c
      obtain ⟨R0,e0,hk⟩ := hk
      exact ⟨a,t,ec,R,by simp [StoreTy.put],hend,R0,e0,hk.store hA h.wf hext⟩
    · simp only [Store.set,hi,↓reduceIte] at hc
      exact (h.cell i c hc).store hA h.wf hext

end
end Benitoite.Release.Refinement
