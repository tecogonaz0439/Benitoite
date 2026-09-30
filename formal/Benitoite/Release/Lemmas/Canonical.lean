import Benitoite.Release.Lemmas.TySubstMain

/-!
# 閉じた値の形と、パターンの照合（段階 B）
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 型の付いた閉じた値は、網羅性の意味での値の形をしている -/

mutual
  theorem HasTypeV.inhabits' {Ψ C Γ v a} (h : HasTypeV P B Ψ C Γ v a) (hΓ : Γ = []) : Inhabits P a v := by
    match h with
    | .V_Var hi _ => subst hΓ; simp at hi
    | .V_Const => exact .const
    | .V_Fun _ _ _ => rw [fnTy_eq]; exact .fn
    | .V_Prim _ _ _ _ => rw [fnTy_eq]; exact .fn
    | .V_Op _ _ => rw [fnTy_eq]; exact .fn
    | .V_Lam _ => exact .fn
    | .V_Con hc hts hargs => exact .con hc hts.symm (HasTypeVs.inhabits' hargs hΓ)
    | .V_List he _ => exact .list (HasTypeEach.inhabits' he hΓ)
    | .V_LocRef _ => exact .reference
    | .V_LocLazy _ => exact .lazy
    | .V_Map _ _ _ _ _ _ => exact .map
    | .V_Set _ _ _ => exact .set
    | .V_Bytes => exact .bytes
    | .V_Dict _ _ _ => exact .dict
    | .V_Super _ _ _ => exact .dict
    | .V_Sub h hle =>
        rcases hle with rfl | ⟨_, _, _, _, _, rfl, _⟩
        · exact HasTypeV.inhabits' h hΓ
        · exact .fn

  theorem HasTypeVs.inhabits' {Ψ C Γ vs as} (h : HasTypeVs P B Ψ C Γ vs as) (hΓ : Γ = []) :
      InhabitsAll P as vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeV.inhabits' hv hΓ) (HasTypeVs.inhabits' hvs hΓ)

  theorem HasTypeEach.inhabits' {Ψ C Γ vs a} (h : HasTypeEach P B Ψ C Γ vs a) (hΓ : Γ = []) :
      InhabitsEach P a vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeV.inhabits' hv hΓ) (HasTypeEach.inhabits' hvs hΓ)
end

theorem HasTypeV.inhabits {Ψ C v a} (h : HasTypeV P B Ψ C [] v a) : Inhabits P a v := h.inhabits' rfl

/-! ## 閉じた値の形 -/

theorem HasTypeV.canonical_boolean {Ψ C v} (h : HasTypeV P B Ψ C [] v (.base .boolean)) :
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
  | op o ts =>
      obtain ⟨_, _, _, hle⟩ := h.inv_op rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | lam ps body =>
      obtain ⟨_, _, _, hle⟩ := h.inv_lam rfl
      have := hle.eq_of_not_fn hnf; simp at this
  | con c ts args => obtain ⟨_, _, _, _, h'⟩ := h.inv_con rfl; simp at h'
  | list elems => obtain ⟨_, _, h'⟩ := h.inv_list rfl; simp at h'
  | mapV ks vs => obtain ⟨_, _, h'⟩ := h.inv_mapV rfl; simp at h'
  | setV _ => obtain ⟨_, h'⟩ := h.inv_setV rfl; simp at h'
  | bytesV _ => have h' := h.inv_bytesV rfl; simp at h'
  | dict _ _ _ => obtain ⟨_, _, _, _, h'⟩ := h.inv_dict rfl; simp at h'
  | super _ _ => obtain ⟨_, _, _, _, _, _, h'⟩ := h.inv_super rfl; simp at h'
  | loc l => rcases h.inv_loc rfl with ⟨_, _, h'⟩ | ⟨_, _, h'⟩ <;> simp at h'

/-- `Reference[A]` の型の閉じた値は、可変のセルの場所である。 -/
theorem HasTypeV.canonical_ref {Ψ C v a} (h : HasTypeV P B Ψ C [] v (.reference a)) :
    ∃ l, v = .loc l ∧ Ψ l = some (.ref a) := by
  have hnf : ∀ ps r ε, (Ty.reference a) ≠ .fn ps r ε := by intros; simp
  cases v with
  | var i => obtain ⟨_, hi, _⟩ := h.inv_var rfl; simp at hi
  | const c => have := (h.inv_const rfl).eq_of_not_fn hnf; cases c <;> simp [Const.type] at this
  | fnRef f ts es =>
      obtain ⟨_, _, _, _, hle⟩ := h.inv_fnRef rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | prim b ts es =>
      obtain ⟨_, _, _, _, _, hle⟩ := h.inv_prim rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | op o ts =>
      obtain ⟨_, _, _, hle⟩ := h.inv_op rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | lam ps body =>
      obtain ⟨_, _, _, hle⟩ := h.inv_lam rfl
      have := hle.eq_of_not_fn hnf; simp at this
  | con c ts args => obtain ⟨_, _, _, _, h'⟩ := h.inv_con rfl; simp at h'
  | list elems => obtain ⟨_, _, h'⟩ := h.inv_list rfl; simp at h'
  | mapV ks vs => obtain ⟨_, _, h'⟩ := h.inv_mapV rfl; simp at h'
  | setV _ => obtain ⟨_, h'⟩ := h.inv_setV rfl; simp at h'
  | bytesV _ => have h' := h.inv_bytesV rfl; simp at h'
  | dict _ _ _ => obtain ⟨_, _, _, _, h'⟩ := h.inv_dict rfl; simp at h'
  | super _ _ => obtain ⟨_, _, _, _, _, _, h'⟩ := h.inv_super rfl; simp at h'
  | loc l =>
      rcases h.inv_loc rfl with ⟨a', hl, h'⟩ | ⟨_, _, h'⟩
      · simp only [Ty.reference.injEq] at h'; subst h'; exact ⟨l, rfl, hl⟩
      · simp at h'

/-- `Lazy[A]` の型の閉じた値は、明示遅延の場所である。 -/
theorem HasTypeV.canonical_lazy {Ψ C v a} (h : HasTypeV P B Ψ C [] v (.lazy a)) :
    ∃ l, v = .loc l ∧ Ψ l = some (.lazy a) := by
  have hnf : ∀ ps r ε, (Ty.lazy a) ≠ .fn ps r ε := by intros; simp
  cases v with
  | var i => obtain ⟨_, hi, _⟩ := h.inv_var rfl; simp at hi
  | const c => have := (h.inv_const rfl).eq_of_not_fn hnf; cases c <;> simp [Const.type] at this
  | fnRef f ts es =>
      obtain ⟨_, _, _, _, hle⟩ := h.inv_fnRef rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | prim b ts es =>
      obtain ⟨_, _, _, _, _, hle⟩ := h.inv_prim rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | op o ts =>
      obtain ⟨_, _, _, hle⟩ := h.inv_op rfl
      rw [fnTy_eq] at hle; have := hle.eq_of_not_fn hnf; simp at this
  | lam ps body =>
      obtain ⟨_, _, _, hle⟩ := h.inv_lam rfl
      have := hle.eq_of_not_fn hnf; simp at this
  | con c ts args => obtain ⟨_, _, _, _, h'⟩ := h.inv_con rfl; simp at h'
  | list elems => obtain ⟨_, _, h'⟩ := h.inv_list rfl; simp at h'
  | mapV ks vs => obtain ⟨_, _, h'⟩ := h.inv_mapV rfl; simp at h'
  | setV _ => obtain ⟨_, h'⟩ := h.inv_setV rfl; simp at h'
  | bytesV _ => have h' := h.inv_bytesV rfl; simp at h'
  | dict _ _ _ => obtain ⟨_, _, _, _, h'⟩ := h.inv_dict rfl; simp at h'
  | super _ _ => obtain ⟨_, _, _, _, _, _, h'⟩ := h.inv_super rfl; simp at h'
  | loc l =>
      rcases h.inv_loc rfl with ⟨_, _, h'⟩ | ⟨a', hl, h'⟩
      · simp at h'
      · simp only [Ty.lazy.injEq] at h'; subst h'; exact ⟨l, rfl, hl⟩

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

theorem HasTypeArms.mem {Ψ C Γ R arms a b ε p m} (h : HasTypeArms P B Ψ C Γ R arms a b ε)
    (hm : (p, m) ∈ arms) : ∃ δ, PatTy P p a δ ∧ HasTypeC P B Ψ C (binds δ ++ Γ) R m b ε := by
  match h with
  | .nil _ => simp at hm
  | .cons hp hbody hrest =>
      simp only [List.mem_cons, Prod.mk.injEq] at hm
      rcases hm with ⟨rfl, rfl⟩ | hm
      · exact ⟨_, hp, hbody⟩
      · exact HasTypeArms.mem hrest hm

/-! ## パターンの照合が束縛する値の型 -/

theorem HasTypeVs.append {Ψ C Γ vs ws as bs} (h₁ : HasTypeVs P B Ψ C Γ vs as)
    (h₂ : HasTypeVs P B Ψ C Γ ws bs) : HasTypeVs P B Ψ C Γ (vs ++ ws) (as ++ bs) := by
  match h₁ with
  | .nil => exact h₂
  | .cons hv hrest => exact .cons hv (HasTypeVs.append hrest h₂)

mutual
  theorem PatTy.match_typed {Ψ C p a δ} (hp : PatTy P p a δ) {v ws}
      (hv : HasTypeV P B Ψ C [] v a) (hm : Pat.matchVal p v = some ws) : HasTypeVs P B Ψ C [] ws δ := by
    match hp with
    | .P_Wild => simp [Pat.matchVal] at hm; subst hm; exact .nil
    | .P_Var => simp [Pat.matchVal] at hm; subst hm; exact .cons hv .nil
    | .P_Const _ _ _ _ =>
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

  theorem PatTys.match_typed {Ψ C ps as δ} (hps : PatTys P ps as δ) {vs ws}
      (hvs : HasTypeVs P B Ψ C [] vs as) (hm : Pat.matchList ps vs = some ws) :
      HasTypeVs P B Ψ C [] ws δ := by
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

theorem Val.VarsInList.append {n pe} : {vs ws : List Val} → Val.VarsInList n pe vs →
    Val.VarsInList n pe ws → Val.VarsInList n pe (vs ++ ws)
  | [], _, _, h => by simpa using h
  | v :: vs, ws, h1, h2 => by
      simp only [Val.VarsInList, List.cons_append] at h1 ⊢
      exact ⟨h1.1, Val.VarsInList.append h1.2 h2⟩

-- パターンの照合が束縛する値は、照合した値の部分の値である（型の変数を含まない）。
mutual
  theorem Pat.matchVal_closed {p v ws} (hv : Val.VarsIn 0 (fun _ => True) v)
      (hm : Pat.matchVal p v = some ws) : Val.VarsInList 0 (fun _ => True) ws := by
    match p, v with
    | .wild, _ => simp [Pat.matchVal] at hm; subst hm; trivial
    | .var, v => simp [Pat.matchVal] at hm; subst hm; exact ⟨hv, trivial⟩
    | .const c, .const c' =>
        simp only [Pat.matchVal] at hm; split at hm
        · simp at hm; subst hm; trivial
        · cases hm
    | .con c ps, .con c' ts args =>
        simp only [Pat.matchVal] at hm; split at hm
        · simp only [Val.VarsIn] at hv; exact Pat.matchList_closed hv.2 hm
        · cases hm
    | .const _, .var _ | .const _, .fnRef _ _ _ | .const _, .prim _ _ _ | .const _, .lam _ _
    | .const _, .con _ _ _ | .const _, .list _ | .const _, .op _ _ | .const _, .loc _ =>
        simp [Pat.matchVal] at hm
    | .con _ _, .var _ | .con _ _, .const _ | .con _ _, .fnRef _ _ _ | .con _ _, .prim _ _ _
    | .con _ _, .lam _ _ | .con _ _, .list _ | .con _ _, .op _ _ | .con _ _, .loc _ =>
        simp [Pat.matchVal] at hm

  theorem Pat.matchList_closed {ps vs ws} (hv : Val.VarsInList 0 (fun _ => True) vs)
      (hm : Pat.matchList ps vs = some ws) : Val.VarsInList 0 (fun _ => True) ws := by
    match ps, vs with
    | [], [] => simp [Pat.matchList] at hm; subst hm; trivial
    | p :: ps, v :: vs =>
        simp only [Val.VarsInList] at hv
        simp only [Pat.matchList, Option.bind_eq_bind] at hm
        cases h1 : Pat.matchVal p v with
        | none => rw [h1] at hm; simp at hm
        | some a =>
            rw [h1] at hm
            cases h2 : Pat.matchList ps vs with
            | none => simp [h2] at hm
            | some b =>
                simp [h2] at hm
                subst hm
                exact Val.VarsInList.append (Pat.matchVal_closed hv.1 h1) (Pat.matchList_closed hv.2 h2)
    | [], _ :: _ => simp [Pat.matchList] at hm
    | _ :: _, [] => simp [Pat.matchList] at hm
end

end Benitoite.Release
