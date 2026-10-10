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

/-! ## パターンの照合が束縛する値の型 -/

theorem HasTypeVs.append {Ψ C Γ vs ws as bs} (h₁ : HasTypeVs P B Ψ C Γ vs as)
    (h₂ : HasTypeVs P B Ψ C Γ ws bs) : HasTypeVs P B Ψ C Γ (vs ++ ws) (as ++ bs) := by
  match h₁ with
  | .nil => exact h₂
  | .cons hv hrest => exact .cons hv (HasTypeVs.append hrest h₂)

/-- 型の並びの位置を指定すると、同じ位置の値の型が得られる。 -/
theorem HasTypeVs.lookup {Ψ C Γ vs as} (h : HasTypeVs P B Ψ C Γ vs as)
    (i : Nat) {a} (hi : as[i]? = some a) :
    ∃ v, vs[i]? = some v ∧ HasTypeV P B Ψ C Γ v a := by
  match h, i with
  | .nil, _ => simp at hi
  | .cons hv _, 0 => simp at hi; subst a; exact ⟨_, rfl, hv⟩
  | .cons _ ht, i + 1 => exact ht.lookup i (by simpa using hi)

/-- 同じ位置で型が付く値と型の並びを、同じ番号で選ぶ。 -/
theorem HasTypeVs.selectSlots_typed {Ψ C Γ vs as} (h : HasTypeVs P B Ψ C Γ vs as)
    {slots δ} (hs : selectSlots as slots = some δ) :
    ∃ ws, selectSlots vs slots = some ws ∧ HasTypeVs P B Ψ C Γ ws δ := by
  induction slots generalizing δ with
  | nil => simp [selectSlots] at hs; subst δ; exact ⟨[], rfl, .nil⟩
  | cons i slots ih =>
      cases hi : as[i]? with
      | none => simp [selectSlots, hi] at hs
      | some a =>
          cases ht : selectSlots as slots with
          | none => simp [selectSlots, hi, ht] at hs
          | some ts =>
              simp [selectSlots, hi, ht] at hs; subst δ
              obtain ⟨v, hv, hty⟩ := h.lookup i hi
              obtain ⟨ws, hw, htys⟩ := ih ht
              exact ⟨v :: ws, by simp [selectSlots, hv, hw], .cons hty htys⟩

/-- リストの任意の切り出しで、各要素の型は変わらない。 -/
theorem HasTypeEach.take {Ψ C Γ vs a} (h : HasTypeEach P B Ψ C Γ vs a) (n : Nat) :
    HasTypeEach P B Ψ C Γ (vs.take n) a := by
  match h, n with
  | .nil, _ => simp; exact .nil
  | .cons _ _, 0 => exact .nil
  | .cons hv ht, n + 1 => exact .cons hv (ht.take n)

theorem HasTypeEach.drop {Ψ C Γ vs a} (h : HasTypeEach P B Ψ C Γ vs a) (n : Nat) :
    HasTypeEach P B Ψ C Γ (vs.drop n) a := by
  match h, n with
  | .nil, _ => simp; exact .nil
  | .cons hv ht, 0 => exact .cons hv ht
  | .cons _ ht, n + 1 => exact ht.drop n

theorem HasTypeEach.toVs {Ψ C Γ vs a} (h : HasTypeEach P B Ψ C Γ vs a) :
    HasTypeVs P B Ψ C Γ vs (List.replicate vs.length a) := by
  match h with
  | .nil => exact .nil
  | .cons hv ht => exact .cons hv ht.toVs

/-- 空のリストでも、要素の型の正しさは V-List から得られる。 -/
theorem HasTypeV.inv_list_wf {C Γ v T elems} (h : HasTypeV P B Ψ C Γ v T) (hv : v = .list elems) :
    ∃ a, HasTypeEach P B Ψ C Γ elems a ∧ Ty.WF C.length a ∧ T = .list a := by
  match h with
  | .V_List h hw => cases hv; exact ⟨_, h, hw, rfl⟩
  | .V_Sub h hle =>
      obtain ⟨a, he, hw, rfl⟩ := inv_list_wf h hv
      exact ⟨a, he, hw, (hle.eq_of_not_fn_left (by intros; simp)).symm⟩
  | .V_Var _ _ => cases hv
  | .V_Const => cases hv
  | .V_Fun _ _ _ => cases hv
  | .V_Prim _ _ _ _ => cases hv
  | .V_Op _ _ => cases hv
  | .V_Lam _ => cases hv
  | .V_Con _ _ _ => cases hv
  | .V_LocRef _ => cases hv
  | .V_LocLazy _ => cases hv

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
    | .P_RangeInt | .P_RangeChar =>
        cases v <;> simp only [Pat.matchVal] at hm
        all_goals first
          | cases hm
          | (split at hm
             · simp at hm; subst ws; exact .nil
             · cases hm)
    | .P_List (before := before) (rest := rest) (after := after) (a := t) hb ha _ =>
        cases v with
        | list elems =>
            obtain ⟨u, he, hw, ht⟩ := hv.inv_list_wf rfl
            cases ht
            simp only [Pat.matchVal] at hm
            by_cases hlen : (if rest.isSome then before.length + after.length ≤ elems.length
                else before.length + after.length = elems.length)
            · rw [ite_eq_left hlen] at hm
              have hlen' : before.length + after.length ≤ elems.length := by
                cases rest <;> simp_all
              cases hl : Pat.matchList before (elems.take before.length) with
              | none => simp [hl] at hm
              | some left =>
                  cases hr : Pat.matchList after (elems.drop (elems.length - after.length)) with
                  | none => simp [hl, hr] at hm
                  | some right =>
                      simp [hl, hr] at hm; subst ws
                      have hbv := (he.take before.length).toVs
                      have hav := (he.drop (elems.length - after.length)).toVs
                      rw [List.length_take, Nat.min_eq_left (by omega)] at hbv
                      rw [List.length_drop, show elems.length - (elems.length - after.length) = after.length by omega] at hav
                      have hmids : HasTypeVs P B Ψ C []
                          (match rest with | some .bind => [Val.list ((elems.drop before.length).take
                            (elems.length - (before.length + after.length)))] | _ => []) (restTys rest t) := by
                        cases rest with
                        | none => exact .nil
                        | some r => cases r with
                          | skip => exact .nil
                          | bind => exact .cons (.V_List ((he.drop _).take _) hw) .nil
                      cases rest with
                      | none => simpa only [List.append_assoc] using
                          ((PatTys.match_typed hb hbv hl).append hmids).append (PatTys.match_typed ha hav hr)
                      | some r => cases r <;> simpa only [List.append_assoc] using
                          ((PatTys.match_typed hb hbv hl).append hmids).append (PatTys.match_typed ha hav hr)
            · rw [ite_eq_right hlen] at hm; cases hm
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

theorem Val.VarsInList.mem {n pe vs} (h : Val.VarsInList n pe vs) {v} (hv : v ∈ vs) :
    Val.VarsIn n pe v := by
  induction vs with
  | nil => simp at hv
  | cons x xs ih =>
      rcases List.mem_cons.mp hv with rfl | hv
      · exact h.1
      · exact ih h.2 hv

theorem Val.VarsInList.of_mem {n pe vs} (h : ∀ v ∈ vs, Val.VarsIn n pe v) :
    Val.VarsInList n pe vs := by
  induction vs with
  | nil => trivial
  | cons v vs ih => exact ⟨h v (by simp), ih (fun x hx => h x (by simp [hx]))⟩

theorem Val.VarsInList.take {n pe vs} (h : Val.VarsInList n pe vs) (k : Nat) :
    Val.VarsInList n pe (vs.take k) :=
  .of_mem (fun _ hv => h.mem (List.mem_of_mem_take hv))

theorem Val.VarsInList.drop {n pe vs} (h : Val.VarsInList n pe vs) (k : Nat) :
    Val.VarsInList n pe (vs.drop k) :=
  .of_mem (fun _ hv => h.mem (List.mem_of_mem_drop hv))

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
    | .range lo hi, v =>
        cases v <;> simp only [Pat.matchVal] at hm
        all_goals first
          | cases hm
          | (split at hm
             · simp at hm; subst ws; trivial
             · cases hm)
    | .list before rest after, v =>
        cases v with
        | list elems =>
            simp only [Val.VarsIn] at hv
            simp only [Pat.matchVal] at hm
            by_cases hlen : (if rest.isSome then before.length + after.length ≤ elems.length
                else before.length + after.length = elems.length)
            · rw [ite_eq_left hlen] at hm
              cases hl : Pat.matchList before (elems.take before.length) with
              | none => simp [hl] at hm
              | some left =>
                  cases hr : Pat.matchList after (elems.drop (elems.length - after.length)) with
                  | none => simp [hl, hr] at hm
                  | some right =>
                      simp [hl, hr] at hm; subst ws
                      have hmids : Val.VarsInList 0 (fun _ => True)
                          (match rest with | some .bind => [Val.list ((elems.drop before.length).take
                            (elems.length - (before.length + after.length)))] | _ => []) := by
                        cases rest with
                        | none => trivial
                        | some r => cases r with
                          | skip => trivial
                          | bind => exact ⟨(hv.drop _).take _, trivial⟩
                      have hb := Pat.matchList_closed (hv.take _) hl
                      have ha := Pat.matchList_closed (hv.drop _) hr
                      cases rest with
                      | none => simpa only [List.append_assoc] using (hb.append hmids).append ha
                      | some r => cases r <;> simpa only [List.append_assoc] using (hb.append hmids).append ha
            · rw [ite_eq_right hlen] at hm; cases hm
        | _ => simp [Pat.matchVal] at hm
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

/-- 照合する型付きの選択肢では、対応で並べ替えた束縛も分岐の型の並びを持つ。 -/
theorem AltsTy.select_match {Ψ C alts a δ alt v ws} (h : AltsTy P alts a δ)
    (halt : alt ∈ alts) (hv : HasTypeV P B Ψ C [] v a)
    (hm : Pat.matchVal alt.pat v = some ws) :
    ∃ zs, selectSlots ws alt.slots = some zs ∧ HasTypeVs P B Ψ C [] zs δ := by
  obtain ⟨γ, hp, _, hs⟩ := h.2.2.2 alt halt
  exact (hp.match_typed hv hm).selectSlots_typed hs

/-- 選択肢の先頭が恒等である条件は、尾の走査には要らない。 -/
theorem firstAlt_typed {Ψ C alts a δ v ws}
    (h : ∀ alt ∈ alts, ∃ γ, PatTy P alt.pat a γ ∧ selectSlots γ alt.slots = some δ)
    (hv : HasTypeV P B Ψ C [] v a) (hm : firstAlt v alts = some ws) :
    HasTypeVs P B Ψ C [] ws δ := by
  induction alts with
  | nil => simp [firstAlt] at hm
  | cons alt alts ih =>
      cases hp : Pat.matchVal alt.pat v with
      | none => exact ih (fun x hx => h x (by simp [hx])) (by simpa [firstAlt, hp] using hm)
      | some zs =>
          obtain ⟨γ, ht, hs⟩ := h alt (by simp)
          obtain ⟨us, hu, hut⟩ := (ht.match_typed hv hp).selectSlots_typed hs
          have he : us = ws := by simpa [firstAlt, hp, hu] using hm
          subst ws; exact hut

theorem AltsTy.firstAlt_typed {Ψ C alts a δ v ws} (h : AltsTy P alts a δ)
    (hv : HasTypeV P B Ψ C [] v a) (hm : firstAlt v alts = some ws) :
    HasTypeVs P B Ψ C [] ws δ :=
  Benitoite.Release.firstAlt_typed (fun alt halt => by
    obtain ⟨γ, hp, _, hs⟩ := h.2.2.2 alt halt
    exact ⟨γ, hp, hs⟩) hv hm

theorem firstAlt_exists {Ψ C alts a δ v}
    (h : ∀ alt ∈ alts, ∃ γ, PatTy P alt.pat a γ ∧ selectSlots γ alt.slots = some δ)
    (hv : HasTypeV P B Ψ C [] v a)
    (hm : ∃ alt ∈ alts, (Pat.matchVal alt.pat v).isSome) :
    ∃ ws, firstAlt v alts = some ws := by
  induction alts with
  | nil => simp at hm
  | cons alt alts ih =>
      cases hp : Pat.matchVal alt.pat v with
      | none =>
          obtain ⟨other, ho, hm⟩ := hm
          rcases List.mem_cons.mp ho with rfl | ho
          · simp [hp] at hm
          · obtain ⟨ws, hs⟩ := ih (fun x hx => h x (by simp [hx])) ⟨other, ho, hm⟩
            exact ⟨ws, by simp [firstAlt, hp, hs]⟩
      | some zs =>
          obtain ⟨γ, ht, hs⟩ := h alt (by simp)
          obtain ⟨ws, hw, _⟩ := (ht.match_typed hv hp).selectSlots_typed hs
          exact ⟨ws, by simp [firstAlt, hp, hw]⟩

theorem AltsTy.firstAlt_exists {Ψ C alts a δ v} (h : AltsTy P alts a δ)
    (hv : HasTypeV P B Ψ C [] v a)
    (hm : ∃ alt ∈ alts, (Pat.matchVal alt.pat v).isSome) :
    ∃ ws, firstAlt v alts = some ws :=
  Benitoite.Release.firstAlt_exists (fun alt halt => by
    obtain ⟨γ, hp, _, hs⟩ := h.2.2.2 alt halt
    exact ⟨γ, hp, hs⟩) hv hm

theorem firstAlt_closed {alts v ws} (hv : Val.VarsIn 0 (fun _ => True) v)
    (hm : firstAlt v alts = some ws) : Val.VarsInList 0 (fun _ => True) ws := by
  induction alts with
  | nil => simp [firstAlt] at hm
  | cons alt alts ih =>
      cases hp : Pat.matchVal alt.pat v with
      | none => exact ih (by simpa [firstAlt, hp] using hm)
      | some zs =>
          have hs : selectSlots zs alt.slots = some ws := by simpa [firstAlt, hp] using hm
          exact .of_mem (fun x hx => (Pat.matchVal_closed hv hp).mem (selectSlots_mem hs x hx))

/-- 分岐全体の型付けから、選択された分岐の本体とガードを取り出す。 -/
theorem HasTypeArms.mem {Ψ C Γ R arms a b ε arm}
    (h : HasTypeArms P B Ψ C Γ R arms a b ε) (hm : arm ∈ arms) :
    ∃ δ, AltsTy P arm.alts a δ ∧ HasTypeC P B Ψ C (binds δ ++ Γ) R arm.body b ε ∧
      ∀ g, arm.guard = some g →
        HasTypeC P B Ψ C (hideConts (binds δ ++ Γ)) none g (.base .boolean) Eff.empty := by
  match h with
  | .nil _ => simp at hm
  | .plain ha hb ht =>
      rcases List.mem_cons.mp hm with rfl | hm
      · exact ⟨_, ha, hb, by intro g hg; cases hg⟩
      · exact ht.mem hm
  | .guarded ha hg hb ht =>
      rcases List.mem_cons.mp hm with rfl | hm
      · exact ⟨_, ha, hb, by intro g he; cases he; exact hg⟩
      · exact ht.mem hm

theorem Arm.VarsInList.mem {n pe arms arm} (h : Arm.VarsInList n pe arms) (hm : arm ∈ arms) :
    Comp.VarsIn n pe arm.body ∧ ∀ g, arm.guard = some g → Comp.VarsIn n pe g := by
  induction arms with
  | nil => simp at hm
  | cons ar arms ih =>
      rcases List.mem_cons.mp hm with heq | htail
      · subst arm
        cases ar with
        | mk alts guard body => cases guard with
          | none => exact ⟨h.1, by intro g hg; cases hg⟩
          | some g => exact ⟨h.2.1, by intro g hg; cases hg; exact h.1⟩
      · cases ar with
        | mk alts guard body => cases guard with
          | none => exact ih h.2 htail
          | some g => exact ih h.2.2 htail

/-- 網羅性に数えたパターンは、ガードのない分岐の選択肢にある。 -/
theorem unguardedPats_mem {arms p} (hp : p ∈ unguardedPats arms) :
    ∃ arm ∈ arms, arm.guard = none ∧ ∃ alt ∈ arm.alts, alt.pat = p := by
  induction arms with
  | nil => simp [unguardedPats] at hp
  | cons ar arms ih =>
      cases ar with
      | mk alts guard body =>
          cases guard with
          | none =>
              rcases List.mem_append.mp hp with hp | hp
              · obtain ⟨alt, ha, he⟩ := List.mem_map.mp hp
                exact ⟨.mk alts none body, by simp, rfl, alt, ha, he⟩
              · obtain ⟨ar, ha, hg, hs⟩ := ih hp
                exact ⟨ar, by simp [ha], hg, hs⟩
          | some g =>
              obtain ⟨ar, ha, hg, hs⟩ := ih hp
              exact ⟨ar, by simp [ha], hg, hs⟩

end Benitoite.Release
