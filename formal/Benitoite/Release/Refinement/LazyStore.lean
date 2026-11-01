import Benitoite.Release.Refinement.LazyInversion

/-! # 遅延セルの割当てと結果の書戻し -/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

private theorem store_set_finite {μ : Store} (h : ∃ n, ∀ l, n ≤ l → μ l = none)
    (l : Nat) (c : Cell) : ∃ n, ∀ i, n ≤ i → (μ.set l c) i = none := by
  obtain ⟨n,hn⟩ := h
  refine ⟨max n (l+1),?_⟩
  intro i hi
  have hil : i ≠ l := by omega
  simp only [Store.set,hil,↓reduceIte]
  exact hn i (by omega)

theorem StoreOk.write_done {P B σ Ψ μ l a v}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.lazy a))
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    StoreOk P B σ Ψ (μ.set l (.done v)) := by
  refine ⟨store_set_finite h.1 l _,h.wf,h.declared,?_,?_⟩
  · intro i x hx
    by_cases hi : i = l
    · simp [Store.set,hi]
    · simpa only [Store.set,hi,↓reduceIte] using h.2.2.2.1 i x hx
  · intro i c hc
    by_cases hi : i = l
    · subst i
      simp only [Store.set,↓reduceIte,Option.some.injEq] at hc
      subst c
      exact ⟨a,hl,hv,ha⟩
    · simp only [Store.set,hi,↓reduceIte] at hc
      exact h.2.2.2.2 i c hc

theorem StoreOk.allocate_lazy {P B σ Ψ μ l a q}
    (h : StoreOk P B σ Ψ μ) (hA : Builtins.ValueAssumptions P B)
    (hl : μ l = none) (ht : Ty.Annotation P [] [] a)
    (hq : ClosureTy P B (hideBuilders Ψ) [] none q a Eff.empty) (ha : q.Adequate σ) :
    StoreOk P B σ (Ψ.put l (.lazy a)) (μ.set l (.thunk q)) := by
  have hnone : Ψ l = none := by
    cases he : Ψ l with
    | none => rfl
    | some t => exact False.elim (h.2.2.2.1 l t he hl)
  have hext := StoreTy.extends_put (x := LocTy.lazy a) hnone
  refine ⟨store_set_finite h.1 l _,?_,?_,?_,?_⟩
  · intro i x hx
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hx
      subst x; exact ht.wf
    · simp only [StoreTy.put,hi,↓reduceIte] at hx; exact h.wf i x hx
  · intro i x hx
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hx
      subst x; exact ht.declared
    · simp only [StoreTy.put,hi,↓reduceIte] at hx; exact h.declared i x hx
  · intro i x hx
    by_cases hi : i = l
    · simp [Store.set,hi]
    · simp only [StoreTy.put,hi,↓reduceIte] at hx
      simpa only [Store.set,hi,↓reduceIte] using h.2.2.2.1 i x hx
  · intro i c hc
    by_cases hi : i = l
    · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hc
      subst c
      exact ⟨a,by simp [StoreTy.put],hq.store hA h.wf.hide hext.preservesNormals.hide,ha⟩
    · simp only [Store.set,hi,↓reduceIte] at hc
      exact (h.2.2.2.2 i c hc).store hA h.wf hext

theorem ContTy.update_inv {P B σ Ψ R ε k a b Eb Re l}
    (h : ContTy P B σ Ψ R ε (.update l :: k) a b Eb Re) :
    R = none ∧ ∃ x R', Ψ l = some (.lazy x) ∧ Ty.LeQ P [] [] a x ∧
      Ty.Annotation P [] [] x ∧ ContTy P B σ Ψ R' ε k x b Eb Re := by
  generalize heq : (.update l :: k) = frames at h
  induction h with
  | K_Update hl ha hk =>
    cases heq
    exact ⟨rfl,_,_,hl,.refl,ha,hk⟩
  | K_Sub _ hl ih =>
    obtain ⟨rfl,x,R',hx,hle,ha,hk⟩ := ih heq
    exact ⟨rfl,x,R',hx,.trans hl hle,ha,hk⟩
  | _ => cases heq

theorem lazy_no_sort (a : Ty) : (Ty.lazy a).sort? = none := rfl
theorem lazy_no_observation (l : Nat) : (Val.loc l).toTerm? = none := rfl
theorem lazy_no_observed_fact (l : Nat) (tests : List PathTest) :
    pathFacts (Val.loc l).toTerm? tests = [] := rfl

end
end Benitoite.Release.Refinement
