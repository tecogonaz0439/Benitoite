import Benitoite.Release.Lemmas.ContLemmas

/-!
# ストアの更新と、状態の型付けの補助の補題（段階 B）
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- ストアの型付けに場所を一つ加える（あるいは同じ型で置き直す）。 -/
def StoreTy.set (Ψ : StoreTy) (l : Nat) (x : LocTy) : StoreTy := fun l' => if l' = l then some x else Ψ l'

theorem StoreTy.set_sub {Ψ : StoreTy} {l x} (h : Ψ l = none ∨ Ψ l = some x) :
    StoreTy.Sub Ψ (Ψ.set l x) := by
  intro l' y hy
  unfold StoreTy.set
  by_cases e : l' = l
  · subst e; rcases h with h | h
    · rw [h] at hy; cases hy
    · rw [h] at hy; simp [hy]
  · simp [e, hy]

theorem CellOk.store {Ψ Ψ' l c} (h : CellOk P B Ψ l c) (hΨ : StoreTy.Sub Ψ Ψ') : CellOk P B Ψ' l c := by
  cases c with
  | val v => obtain ⟨a, ha, hv⟩ := h; exact ⟨a, hΨ _ _ ha, hv.store hΨ⟩
  | thunk m => obtain ⟨a, ha, hm⟩ := h; exact ⟨a, hΨ _ _ ha, hm.store hΨ⟩
  | done v => obtain ⟨a, ha, hv⟩ := h; exact ⟨a, hΨ _ _ ha, hv.store hΨ⟩
  | cont k =>
      obtain ⟨b, t, ε, r, ha, hend, R', ε', hk⟩ := h
      exact ⟨b, t, ε, r, hΨ _ _ ha, hend, R', ε', hk.store hΨ⟩
  | used => obtain ⟨b, t, ε, r, ha⟩ := h; exact ⟨b, t, ε, r, hΨ _ _ ha⟩

/-- ストアの場所 l に中身 c を置き、その場所の型を x とする。 -/
theorem StoreOk.set {Ψ σ l c x} (h : StoreOk P B Ψ σ) (hx : x.WF) (hl : Ψ l = none ∨ Ψ l = some x)
    (hc : CellOk P B (Ψ.set l x) l c) : StoreOk P B (Ψ.set l x) (σ.set l c) := by
  obtain ⟨⟨n, hn⟩, hwf, hdom, hcells⟩ := h
  have hsub := StoreTy.set_sub hl
  refine ⟨⟨max n (l + 1), fun l' hl' => ?_⟩, fun l' y hy => ?_, fun l' y hy => ?_, fun l' c' hc' => ?_⟩
  · have e : l' ≠ l := by omega
    simp only [Store.set, e, ↓reduceIte]
    exact hn l' (by omega)
  · unfold StoreTy.set at hy
    split at hy
    · cases hy; exact hx
    · exact hwf _ _ hy
  · unfold StoreTy.set at hy
    simp only [Store.set]
    split
    · simp
    · rename_i e; simp only [e, ↓reduceIte] at hy; exact hdom _ _ hy
  · simp only [Store.set] at hc'
    split at hc'
    · rename_i e; subst e; cases hc'; exact hc
    · exact (hcells _ _ hc').store hsub

theorem Store.Closed.set {σ : Store} {l c} (h : Store.Closed σ) (hc : c.Closed) :
    Store.Closed (σ.set l c) := by
  intro l' c' hc'
  simp only [Store.set] at hc'
  split at hc'
  · cases hc'; exact hc
  · exact h _ _ hc'

theorem StoreOk.wf {Ψ σ} (h : StoreOk P B Ψ σ) : StoreTy.WF Ψ := h.2.1

/-- 有限のストアには、中身のない場所がある。 -/
theorem StoreOk.fresh {Ψ σ} (h : StoreOk P B Ψ σ) : ∃ l, σ l = none ∧ Ψ l = none := by
  obtain ⟨⟨n, hn⟩, _, hdom, _⟩ := h
  refine ⟨n, hn n (Nat.le_refl _), ?_⟩
  cases hΨ : Ψ n with
  | none => rfl
  | some x => exact absurd (hn n (Nat.le_refl _)) (hdom _ _ hΨ)

/-- Ψ が型を与える場所には、その型に合う中身がある。 -/
theorem StoreOk.cell {Ψ σ l x} (h : StoreOk P B Ψ σ) (hl : Ψ l = some x) :
    ∃ c, σ l = some c ∧ CellOk P B Ψ l c := by
  obtain ⟨_, _, hdom, hcells⟩ := h
  cases hσ : σ l with
  | none => exact absurd hσ (hdom _ _ hl)
  | some c => exact ⟨c, rfl, hcells _ _ hσ⟩

/-! ## 値の型は継続の型にならない -/

theorem HasTypeV.notCont {Ψ C Γ v a} (h : HasTypeV P B Ψ C Γ v a) : a.NotCont := by
  match h with
  | .V_Var _ hc => exact hc
  | .V_Const (c := c) => intro b t ε e; cases c <;> simp [Const.type] at e
  | .V_Fun _ _ _ => intro b t ε e; rw [fnTy_eq] at e; cases e
  | .V_Prim _ _ _ _ => intro b t ε e; rw [fnTy_eq] at e; cases e
  | .V_Op _ _ => intro b t ε e; rw [fnTy_eq] at e; cases e
  | .V_Lam _ => intro b t ε e; cases e
  | .V_Con _ _ _ => intro b t ε e; cases e
  | .V_List _ _ => intro b t ε e; cases e
  | .V_LocRef _ => intro b t ε e; cases e
  | .V_LocLazy _ => intro b t ε e; cases e
  | .V_Map _ _ _ _ _ _ => intro b t ε e; cases e
  | .V_Set _ _ _ => intro b t ε e; cases e
  | .V_Bytes => intro b t ε e; cases e
  | .V_Dict _ _ _ => intro b t ε e; cases e
  | .V_Super _ _ _ => intro b t ε e; cases e
  | .V_Sub h hle =>
      rcases hle with rfl | ⟨_, _, _, _, _, rfl, _⟩
      · exact HasTypeV.notCont h
      · intro b t ε e; cases e

end Benitoite.Release
