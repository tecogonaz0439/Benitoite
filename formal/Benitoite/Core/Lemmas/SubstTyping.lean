import Benitoite.Core.Lemmas.Rename

/-!
# 値の置き換えで型付けが保たれること（置き換えの補題）
-/

namespace Benitoite.Core

variable {P : Program} {B : Builtins}

/-! ## 値の並びの型付け -/

theorem HasTypeVs.length_eq {Γ vs as} : HasTypeVs P B Γ vs as → vs.length = as.length
  | .nil => rfl
  | .cons _ h => by simp [HasTypeVs.length_eq h]

theorem HasTypeVs.get {Γ vs as} :
    HasTypeVs P B Γ vs as → ∀ (i : Nat) (a : Ty), as[i]? = some a → ∃ v, vs[i]? = some v ∧ HasTypeV P B Γ v a
  | .nil, i, a, h => by simp at h
  | .cons hv hvs, 0, a, h => by simp at h; subst h; exact ⟨_, rfl, hv⟩
  | .cons _ hvs, i + 1, a, h => by simpa using HasTypeVs.get hvs i a (by simpa using h)

/-! ## 置き換え -/

/-- 置き換え σ が、環境 Γ の変数を、環境 Δ で同じ型を持つ値へ写す。 -/
def SubstOk (P : Program) (B : Builtins) (Γ Δ : List Ty) (σ : Nat → Val) : Prop :=
  ∀ i a, Γ[i]? = some a → HasTypeV P B Δ (σ i) a

theorem SubstOk.up {Γ Δ σ} (xs : List Ty) (h : SubstOk P B Γ Δ σ) :
    SubstOk P B (xs ++ Γ) (xs ++ Δ) (upSubst xs.length σ) := by
  intro i a hi
  unfold upSubst
  by_cases hlt : i < xs.length
  · simp only [hlt, ↓reduceIte]
    rw [List.getElem?_append_left hlt] at hi
    exact .V_Var (by rw [List.getElem?_append_left hlt]; exact hi)
  · simp only [hlt, ↓reduceIte]
    rw [List.getElem?_append_right (by omega)] at hi
    exact (h _ _ hi).rename (RenOk.shift xs Δ)

theorem Comp.substArms_fst (σ : Nat → Val) (arms : List (Pat × Comp)) :
    (Comp.substArms σ arms).map Prod.fst = arms.map Prod.fst := by
  induction arms with
  | nil => simp [Comp.substArms]
  | cons x xs ih => obtain ⟨p, m⟩ := x; simp [Comp.substArms, ih]

mutual
  theorem HasTypeV.subst {Γ Δ σ v a} (h : HasTypeV P B Γ v a) (hσ : SubstOk P B Γ Δ σ) :
      HasTypeV P B Δ (v.subst σ) a := by
    match h with
    | .V_Var hi => simp only [Val.subst]; exact hσ _ _ hi
    | .V_Const => simp only [Val.subst]; exact .V_Const
    | .V_Fun hd hts hes => simp only [Val.subst]; exact .V_Fun hd hts hes
    | .V_Prim hs hts hes had => simp only [Val.subst]; exact .V_Prim hs hts hes had
    | .V_Lam (ps := ps) hb =>
        simp only [Val.subst]
        refine .V_Lam ?_
        have := hσ.up ps.reverse
        rw [List.length_reverse] at this
        exact HasTypeC.subst hb this
    | .V_Con hc hts hargs => simp only [Val.subst]; exact .V_Con hc hts (HasTypeVs.subst hargs hσ)
    | .V_List he => simp only [Val.subst]; exact .V_List (HasTypeEach.subst he hσ)
    | .V_Sub h hle => exact .V_Sub (HasTypeV.subst h hσ) hle

  theorem HasTypeVs.subst {Γ Δ σ vs as} (h : HasTypeVs P B Γ vs as) (hσ : SubstOk P B Γ Δ σ) :
      HasTypeVs P B Δ (Val.substList σ vs) as := by
    match h with
    | .nil => simp only [Val.substList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substList]; exact .cons (HasTypeV.subst hv hσ) (HasTypeVs.subst hvs hσ)

  theorem HasTypeEach.subst {Γ Δ σ vs a} (h : HasTypeEach P B Γ vs a) (hσ : SubstOk P B Γ Δ σ) :
      HasTypeEach P B Δ (Val.substList σ vs) a := by
    match h with
    | .nil => simp only [Val.substList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substList]; exact .cons (HasTypeV.subst hv hσ) (HasTypeEach.subst hvs hσ)

  theorem HasTypeC.subst {Γ Δ σ m a ε} (h : HasTypeC P B Γ m a ε) (hσ : SubstOk P B Γ Δ σ) :
      HasTypeC P B Δ (m.subst σ) a ε := by
    match h with
    | .C_Return hv => simp only [Comp.subst]; exact .C_Return (HasTypeV.subst hv hσ)
    | .C_Sub h hle hs => exact .C_Sub (HasTypeC.subst h hσ) hle hs
    | .C_Let (a := a) hm hn =>
        simp only [Comp.subst]
        exact .C_Let (HasTypeC.subst hm hσ) (HasTypeC.subst hn (hσ.up [a]))
    | .C_App hf hargs =>
        simp only [Comp.subst]; exact .C_App (HasTypeV.subst hf hσ) (HasTypeVs.subst hargs hσ)
    | .C_If hv hm hn =>
        simp only [Comp.subst]
        exact .C_If (HasTypeV.subst hv hσ) (HasTypeC.subst hm hσ) (HasTypeC.subst hn hσ)
    | .C_Match hv harms hex =>
        simp only [Comp.subst]
        refine .C_Match (HasTypeV.subst hv hσ) (HasTypeArms.subst harms hσ) ?_
        rwa [Comp.substArms_fst]

  theorem HasTypeArms.subst {Γ Δ σ arms a b ε} (h : HasTypeArms P B Γ arms a b ε)
      (hσ : SubstOk P B Γ Δ σ) : HasTypeArms P B Δ (Comp.substArms σ arms) a b ε := by
    match h with
    | .nil => simp only [Comp.substArms]; exact .nil
    | .cons (δ := δ) hp hm harms =>
        simp only [Comp.substArms]
        refine .cons hp ?_ (HasTypeArms.subst harms hσ)
        have := hσ.up δ.reverse
        rw [List.length_reverse, PatTy.length_eq hp] at this
        exact HasTypeC.subst hm this
end

/-! ## 束縛した変数を値の並びで置き換える -/

/-- 型 `as` の値の並び `ws` で、環境 `as.reverse` の変数を置き換えられる。 -/
theorem SubstOk.inst {ws as} (h : HasTypeVs P B [] ws as) :
    SubstOk P B as.reverse [] (instSubst ws) := by
  intro i a hi
  have hlen := h.length_eq
  have hi' : i < as.length := by
    have := List.getElem?_eq_some_iff.mp hi
    simpa using this.1
  rw [List.getElem?_reverse hi'] at hi
  obtain ⟨w, hw, hwt⟩ := h.get _ _ hi
  unfold instSubst
  have hlt : i < ws.length := by omega
  simp only [hlt, ↓reduceIte]
  rw [List.getElem?_reverse hlt]
  rw [hlen, hw]
  exact hwt

/-- 01-12 の `M[W̄/x̄]`：束縛した変数の型の値で置き換えても、型が保たれる。 -/
theorem HasTypeC.instantiate {ws as m b ε} (hm : HasTypeC P B as.reverse m b ε)
    (hws : HasTypeVs P B [] ws as) : HasTypeC P B [] (m.instantiate ws) b ε :=
  hm.subst (SubstOk.inst hws)

end Benitoite.Core
