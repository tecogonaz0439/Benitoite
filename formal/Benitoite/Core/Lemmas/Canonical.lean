import Benitoite.Core.Lemmas.TySubst

/-!
# 閉じた値の形と、パターンの照合

進行の証明で使う、型の付いた閉じた値の形（正準形）と網羅性、保存の証明で使う、パターンの照合が
束縛する値の型付けを示す。
-/

namespace Benitoite.Core

variable {P : Program} {B : Builtins}

/-! ## 型の付いた閉じた値は、網羅性の意味での値の形をしている -/

mutual
  theorem HasTypeV.inhabits' {Γ v a} (h : HasTypeV P B Γ v a) (hΓ : Γ = []) : Inhabits P a v := by
    match h with
    | .V_Var hi => subst hΓ; simp at hi
    | .V_Const => exact .const
    | .V_Fun _ _ _ => rw [fnTy_eq]; exact .fn
    | .V_Prim _ _ _ _ => rw [fnTy_eq]; exact .fn
    | .V_Lam _ => exact .fn
    | .V_Con hc hts hargs => exact .con hc hts.symm (HasTypeVs.inhabits' hargs hΓ)
    | .V_List he => exact .list (HasTypeEach.inhabits' he hΓ)
    | .V_Sub h hle =>
        rcases hle with rfl | ⟨_, _, _, _, _, rfl, _⟩
        · exact HasTypeV.inhabits' h hΓ
        · exact .fn

  theorem HasTypeVs.inhabits' {Γ vs as} (h : HasTypeVs P B Γ vs as) (hΓ : Γ = []) :
      InhabitsAll P as vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeV.inhabits' hv hΓ) (HasTypeVs.inhabits' hvs hΓ)

  theorem HasTypeEach.inhabits' {Γ vs a} (h : HasTypeEach P B Γ vs a) (hΓ : Γ = []) :
      InhabitsEach P a vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeV.inhabits' hv hΓ) (HasTypeEach.inhabits' hvs hΓ)
end

theorem HasTypeV.inhabits {v a} (h : HasTypeV P B [] v a) : Inhabits P a v := h.inhabits' rfl

/-! ## 真偽値の型の閉じた値 -/

theorem HasTypeV.canonical_boolean {v} (h : HasTypeV P B [] v (.base .boolean)) :
    ∃ b, v = .const (.boolean b) := by
  have hnf : ∀ ps r ε, (Ty.base .boolean) ≠ .fn ps r ε := by intros; simp
  cases v with
  | var i => obtain ⟨_, hi, _⟩ := h.inv_var rfl; simp at hi
  | const c =>
      have := (h.inv_const rfl).eq_of_not_fn hnf
      cases c <;> simp [Const.type] at this
      exact ⟨_, rfl⟩
  | fnRef f ts es =>
      obtain ⟨_, _, _, _, hle⟩ := h.inv_fnRef rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | prim b ts es =>
      obtain ⟨_, _, _, _, _, hle⟩ := h.inv_prim rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | lam ps body =>
      obtain ⟨_, _, _, hle⟩ := h.inv_lam rfl
      have := hle.eq_of_not_fn hnf; simp at this
  | con c ts args => obtain ⟨_, _, _, _, h'⟩ := h.inv_con rfl; simp at h'
  | list elems => obtain ⟨_, _, h'⟩ := h.inv_list rfl; simp at h'

/-! ## 分岐の選択 -/

theorem firstMatch_exists {v : Val} {arms : List (Pat × Comp)}
    (h : ∃ p ∈ arms.map Prod.fst, (Pat.matchVal p v).isSome) :
    ∃ m ws, firstMatch v arms = some (m, ws) := by
  induction arms with
  | nil => simp at h
  | cons x arms ih =>
      obtain ⟨p, m⟩ := x
      simp only [firstMatch]
      cases hm : Pat.matchVal p v with
      | some ws => exact ⟨m, ws, rfl⟩
      | none =>
          apply ih
          obtain ⟨q, hq, hs⟩ := h
          simp only [List.map_cons, List.mem_cons] at hq
          rcases hq with rfl | hq
          · simp [hm] at hs
          · exact ⟨q, hq, hs⟩

theorem firstMatch_mem {v : Val} {arms : List (Pat × Comp)} {m ws}
    (h : firstMatch v arms = some (m, ws)) :
    ∃ p, (p, m) ∈ arms ∧ Pat.matchVal p v = some ws := by
  induction arms with
  | nil => simp [firstMatch] at h
  | cons x arms ih =>
      obtain ⟨p, m'⟩ := x
      simp only [firstMatch] at h
      cases hm : Pat.matchVal p v with
      | some ws' =>
          rw [hm] at h; simp at h
          obtain ⟨rfl, rfl⟩ := h
          exact ⟨p, by simp, hm⟩
      | none =>
          rw [hm] at h
          obtain ⟨q, hq, hs⟩ := ih h
          exact ⟨q, by simp [hq], hs⟩

theorem HasTypeArms.mem {Γ arms a b ε p m} (h : HasTypeArms P B Γ arms a b ε) (hm : (p, m) ∈ arms) :
    ∃ δ, PatTy P p a δ ∧ HasTypeC P B (δ.reverse ++ Γ) m b ε := by
  match h with
  | .nil => simp at hm
  | .cons hp hbody hrest =>
      simp only [List.mem_cons, Prod.mk.injEq] at hm
      rcases hm with ⟨rfl, rfl⟩ | hm
      · exact ⟨_, hp, hbody⟩
      · exact HasTypeArms.mem hrest hm

/-! ## パターンの照合が束縛する値の型 -/

theorem HasTypeVs.append {Γ vs ws as bs} (h₁ : HasTypeVs P B Γ vs as) (h₂ : HasTypeVs P B Γ ws bs) :
    HasTypeVs P B Γ (vs ++ ws) (as ++ bs) := by
  match h₁ with
  | .nil => exact h₂
  | .cons hv hrest => exact .cons hv (HasTypeVs.append hrest h₂)

mutual
  theorem PatTy.match_typed {p a δ} (hp : PatTy P p a δ) {v ws}
      (hv : HasTypeV P B [] v a) (hm : Pat.matchVal p v = some ws) : HasTypeVs P B [] ws δ := by
    match hp with
    | .P_Wild => simp [Pat.matchVal] at hm; subst hm; exact .nil
    | .P_Var => simp [Pat.matchVal] at hm; subst hm; exact .cons hv .nil
    | .P_Const _ _ =>
        cases v with
        | const c' =>
            simp only [Pat.matchVal] at hm
            split at hm
            · simp at hm; subst hm; exact .nil
            · cases hm
        | _ => simp [Pat.matchVal] at hm
    | .P_Con (cd := cd) (ts := ts) hc hts hps =>
        cases v with
        | con c' ts' args =>
            simp only [Pat.matchVal] at hm
            split at hm
            · rename_i hcc
              subst hcc
              obtain ⟨cd', hc', _, hargs, hty⟩ := hv.inv_con rfl
              rw [hc] at hc'; cases hc'
              simp only [Ty.data.injEq] at hty
              obtain ⟨_, rfl⟩ := hty
              exact PatTys.match_typed hps hargs hm
            · cases hm
        | _ => simp [Pat.matchVal] at hm

  theorem PatTys.match_typed {ps as δ} (hps : PatTys P ps as δ) {vs ws}
      (hvs : HasTypeVs P B [] vs as) (hm : Pat.matchList ps vs = some ws) :
      HasTypeVs P B [] ws δ := by
    match hps, hvs with
    | .nil, .nil => simp [Pat.matchList] at hm; subst hm; exact .nil
    | .cons (p := p) (ps := qs) hp hps', .cons (v := v) (vs := us) hv hvs' =>
        simp only [Pat.matchList, Option.bind_eq_bind] at hm
        cases h1 : Pat.matchVal p v with
        | none => rw [h1] at hm; simp at hm
        | some a =>
            rw [h1] at hm
            cases h2 : Pat.matchList qs us with
            | none => simp [h2] at hm
            | some b =>
                simp [h2] at hm
                subst hm
                exact (PatTy.match_typed hp hv h1).append (PatTys.match_typed hps' hvs' h2)
end

end Benitoite.Core
