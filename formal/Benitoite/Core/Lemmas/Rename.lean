import Benitoite.Core.Lemmas.Inversion

/-!
# 番号の付け替えで型付けが保たれること（弱化）
-/

namespace Benitoite.Core

variable {P : Program} {B : Builtins}

/-! ## パターンが束縛する変数の個数 -/

mutual
  theorem PatTy.length_eq {p a δ} : PatTy P p a δ → δ.length = p.binders
    | .P_Wild => by simp [Pat.binders]
    | .P_Var => by simp [Pat.binders]
    | .P_Const _ _ => by simp [Pat.binders]
    | .P_Con _ _ h => by simp only [Pat.binders]; exact PatTys.length_eq h

  theorem PatTys.length_eq {ps as δ} : PatTys P ps as δ → δ.length = Pat.bindersList ps
    | .nil => by simp [Pat.bindersList]
    | .cons h hs => by
        simp only [Pat.bindersList, List.length_append]
        rw [PatTy.length_eq h, PatTys.length_eq hs]
end

/-! ## 番号の付け替え -/

/-- 番号の付け替え ξ が、環境 Γ の変数の型を環境 Δ の同じ型の変数へ写す。 -/
def RenOk (Γ Δ : List Ty) (ξ : Nat → Nat) : Prop :=
  ∀ i a, Γ[i]? = some a → Δ[ξ i]? = some a

theorem RenOk.up {Γ Δ ξ} (xs : List Ty) (h : RenOk Γ Δ ξ) :
    RenOk (xs ++ Γ) (xs ++ Δ) (upRen xs.length ξ) := by
  intro i a hi
  unfold upRen
  by_cases hlt : i < xs.length
  · simp only [hlt, ↓reduceIte]
    rw [List.getElem?_append_left hlt]
    rwa [List.getElem?_append_left hlt] at hi
  · simp only [hlt, ↓reduceIte]
    rw [List.getElem?_append_right (by omega)] at hi
    rw [List.getElem?_append_right (by omega)]
    simpa using h _ _ hi

theorem Comp.renameArms_fst (ξ : Nat → Nat) (arms : List (Pat × Comp)) :
    (Comp.renameArms ξ arms).map Prod.fst = arms.map Prod.fst := by
  induction arms with
  | nil => simp [Comp.renameArms]
  | cons x xs ih => obtain ⟨p, m⟩ := x; simp [Comp.renameArms, ih]

mutual
  theorem HasTypeV.rename {Γ Δ ξ v a} (h : HasTypeV P B Γ v a) (hξ : RenOk Γ Δ ξ) :
      HasTypeV P B Δ (v.rename ξ) a := by
    match h with
    | .V_Var hi => simp only [Val.rename]; exact .V_Var (hξ _ _ hi)
    | .V_Const => simp only [Val.rename]; exact .V_Const
    | .V_Fun hd hts hes => simp only [Val.rename]; exact .V_Fun hd hts hes
    | .V_Prim hs hts hes had => simp only [Val.rename]; exact .V_Prim hs hts hes had
    | .V_Lam (ps := ps) hb =>
        simp only [Val.rename]
        refine .V_Lam ?_
        have := hξ.up ps.reverse
        rw [List.length_reverse] at this
        exact HasTypeC.rename hb this
    | .V_Con hc hts hargs => simp only [Val.rename]; exact .V_Con hc hts (HasTypeVs.rename hargs hξ)
    | .V_List he => simp only [Val.rename]; exact .V_List (HasTypeEach.rename he hξ)
    | .V_Sub h hle => exact .V_Sub (HasTypeV.rename h hξ) hle

  theorem HasTypeVs.rename {Γ Δ ξ vs as} (h : HasTypeVs P B Γ vs as) (hξ : RenOk Γ Δ ξ) :
      HasTypeVs P B Δ (Val.renameList ξ vs) as := by
    match h with
    | .nil => simp only [Val.renameList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.renameList]; exact .cons (HasTypeV.rename hv hξ) (HasTypeVs.rename hvs hξ)

  theorem HasTypeEach.rename {Γ Δ ξ vs a} (h : HasTypeEach P B Γ vs a) (hξ : RenOk Γ Δ ξ) :
      HasTypeEach P B Δ (Val.renameList ξ vs) a := by
    match h with
    | .nil => simp only [Val.renameList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.renameList]; exact .cons (HasTypeV.rename hv hξ) (HasTypeEach.rename hvs hξ)

  theorem HasTypeC.rename {Γ Δ ξ m a ε} (h : HasTypeC P B Γ m a ε) (hξ : RenOk Γ Δ ξ) :
      HasTypeC P B Δ (m.rename ξ) a ε := by
    match h with
    | .C_Return hv => simp only [Comp.rename]; exact .C_Return (HasTypeV.rename hv hξ)
    | .C_Sub h hle hs => exact .C_Sub (HasTypeC.rename h hξ) hle hs
    | .C_Let (a := a) hm hn =>
        simp only [Comp.rename]
        exact .C_Let (HasTypeC.rename hm hξ) (HasTypeC.rename hn (hξ.up [a]))
    | .C_App hf hargs =>
        simp only [Comp.rename]; exact .C_App (HasTypeV.rename hf hξ) (HasTypeVs.rename hargs hξ)
    | .C_If hv hm hn =>
        simp only [Comp.rename]
        exact .C_If (HasTypeV.rename hv hξ) (HasTypeC.rename hm hξ) (HasTypeC.rename hn hξ)
    | .C_Match (arms := arms) hv harms hex =>
        simp only [Comp.rename]
        refine .C_Match (HasTypeV.rename hv hξ) (HasTypeArms.rename harms hξ) ?_
        rwa [Comp.renameArms_fst]

  theorem HasTypeArms.rename {Γ Δ ξ arms a b ε} (h : HasTypeArms P B Γ arms a b ε)
      (hξ : RenOk Γ Δ ξ) : HasTypeArms P B Δ (Comp.renameArms ξ arms) a b ε := by
    match h with
    | .nil => simp only [Comp.renameArms]; exact .nil
    | .cons (δ := δ) hp hm harms =>
        simp only [Comp.renameArms]
        refine .cons hp ?_ (HasTypeArms.rename harms hξ)
        have := hξ.up δ.reverse
        rw [List.length_reverse, PatTy.length_eq hp] at this
        exact HasTypeC.rename hm this
end

/-- 閉じた値は、どの環境でも同じ型を持つ（番号 0 から始まる変数を持たないので、付け替えで変わらない）。 -/
theorem RenOk.shift (xs : List Ty) (Γ : List Ty) : RenOk Γ (xs ++ Γ) (· + xs.length) := by
  intro i a hi
  show (xs ++ Γ)[i + xs.length]? = some a
  rw [List.getElem?_append_right (by omega)]
  simpa using hi

end Benitoite.Core
