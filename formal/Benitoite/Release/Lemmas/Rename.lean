import Benitoite.Release.Lemmas.Inversion

/-!
# 環境とストアの型付けの弱化（段階 B）

番号の付け替え、ストアの型付けの拡大（Ψ ⊆ Ψ'）、`hideConts` についての補題。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## パターンが束縛する変数の個数 -/

mutual
  theorem PatTy.length_eq {p a δ} : PatTy P p a δ → δ.length = p.binders
    | .P_Wild => by simp [Pat.binders]
    | .P_Var => by simp [Pat.binders]
    | .P_Const _ _ _ _ => by simp [Pat.binders]
    | .P_Con _ _ h => by simp only [Pat.binders]; exact PatTys.length_eq h
    | .P_RangeInt => by simp [Pat.binders]
    | .P_RangeChar => by simp [Pat.binders]
    | .P_List (rest := rest) hb ha _ => by
        cases rest with
        | none => simp [restTys, Pat.binders, PatTys.length_eq hb, PatTys.length_eq ha]
        | some r => cases r <;> simp [restTys, ListRest.binders, Pat.binders, PatTys.length_eq hb, PatTys.length_eq ha, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]

  theorem PatTys.length_eq {ps as δ} : PatTys P ps as δ → δ.length = Pat.bindersList ps
    | .nil => by simp [Pat.bindersList]
    | .cons h hs => by
        simp only [Pat.bindersList, List.length_append]
        rw [PatTy.length_eq h, PatTys.length_eq hs]
end

theorem Val.renameList_length (ξ : Nat → Nat) (vs : List Val) :
    (Val.renameList ξ vs).length = vs.length := by
  induction vs with
  | nil => simp [Val.renameList]
  | cons v vs ih => simp [Val.renameList, ih]

theorem Val.substList_length (σ : Nat → Val) (vs : List Val) :
    (Val.substList σ vs).length = vs.length := by
  induction vs with
  | nil => simp [Val.substList]
  | cons v vs ih => simp [Val.substList, ih]

theorem Val.substTyAtList_length (c : Nat) (ts : List Ty) (es : List Eff) (vs : List Val) :
    (Val.substTyAtList c ts es vs).length = vs.length := by
  induction vs with
  | nil => simp [Val.substTyAtList]
  | cons v vs ih => simp [Val.substTyAtList, ih]

theorem binds_length (as : List Ty) : (binds as).length = as.length := by simp [binds]

/-! ## 環境の操作 -/

theorem hideConts_length (Γ : List (Option Ty)) : (hideConts Γ).length = Γ.length := by
  simp [hideConts]

theorem shiftEnv_length (k : Nat) (Γ : List (Option Ty)) : (shiftEnv k Γ).length = Γ.length := by
  simp [shiftEnv]

theorem hideConts_get {Γ : List (Option Ty)} {i : Nat} {a : Ty} :
    (hideConts Γ)[i]? = some (some a) ↔ Γ[i]? = some (some a) ∧ ∀ b t ε, a ≠ .cont b t ε := by
  simp only [hideConts, List.getElem?_map]
  cases h : Γ[i]? with
  | none => simp
  | some o =>
      cases o with
      | none => simp
      | some x =>
          cases x <;> simp <;> (rintro rfl; intros; simp)

theorem hideConts_hideConts (Γ : List (Option Ty)) : hideConts (hideConts Γ) = hideConts Γ := by
  simp only [hideConts, List.map_map]
  congr 1
  funext o
  cases o with
  | none => rfl
  | some x => cases x <;> rfl

theorem hideConts_append (xs Γ : List (Option Ty)) :
    hideConts (xs ++ Γ) = hideConts xs ++ hideConts Γ := by
  simp [hideConts]

/-! ## 番号の付け替え -/

/-- 番号の付け替え ξ が、環境 Γ の変数を、環境 Δ の同じ型の変数へ写す。 -/
def RenOk (Γ Δ : List (Option Ty)) (ξ : Nat → Nat) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → Δ[ξ i]? = some (some a)

theorem RenOk.up {Γ Δ ξ} (xs : List (Option Ty)) (h : RenOk Γ Δ ξ) :
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

theorem RenOk.hide {Γ Δ ξ} (h : RenOk Γ Δ ξ) : RenOk (hideConts Γ) (hideConts Δ) ξ := by
  intro i a hi
  rw [hideConts_get] at hi ⊢
  exact ⟨h _ _ hi.1, hi.2⟩

theorem RenOk.shiftE {Γ Δ ξ} (k : Nat) (h : RenOk Γ Δ ξ) :
    RenOk (shiftEnv k Γ) (shiftEnv k Δ) ξ := by
  intro i a hi
  simp only [shiftEnv, List.getElem?_map, Option.map_eq_some_iff] at hi ⊢
  obtain ⟨o, ho, hoa⟩ := hi
  cases o with
  | none => simp at hoa
  | some x =>
      simp only [Option.some.injEq] at hoa
      exact ⟨some x, h _ _ ho, by simp [hoa]⟩

theorem RenOk.shift (xs : List (Option Ty)) (Γ : List (Option Ty)) :
    RenOk Γ (xs ++ Γ) (· + xs.length) := by
  intro i a hi
  show (xs ++ Γ)[i + xs.length]? = some (some a)
  rw [List.getElem?_append_right (by omega)]
  simpa using hi

theorem unguardedPats_rename (ξ : Nat → Nat) (arms : List Arm) :
    unguardedPats (Arm.renameList ξ arms) = unguardedPats arms := by
  induction arms with
  | nil => rfl
  | cons arm arms ih =>
      cases arm with
      | mk alts guard body => cases guard <;> simp [Arm.renameList, unguardedPats, ih]

/-- 節の環境 `k :: x̄ ++ Γ` への持ち上げ。 -/
theorem RenOk.clause {Γ Δ ξ} (c : Option Ty) (ps : List Ty) (k : Nat) (h : RenOk Γ Δ ξ) :
    RenOk (c :: (binds ps ++ shiftEnv k Γ)) (c :: (binds ps ++ shiftEnv k Δ)) (upRen (ps.length + 1) ξ) := by
  have := (RenOk.shiftE k h).up (c :: binds ps)
  simpa [binds_length, Nat.add_comm] using this

theorem Clause.renameList_ops (ξ : Nat → Nat) (h : List Clause) :
    (Clause.renameList ξ h).map Clause.op = h.map Clause.op := by
  induction h with
  | nil => simp [Clause.renameList]
  | cons c cs ih => obtain ⟨o, n, k, m⟩ := c; simp [Clause.renameList, Clause.op, ih]

theorem handles_of_ops {h h' : List Clause} (e : h'.map Clause.op = h.map Clause.op) (o : OpRef) :
    handles h' o = handles h o := by
  unfold handles
  have h1 : (h'.any fun c => c.op == o) = ((h'.map Clause.op).any fun x => x == o) := by
    simp [List.any_map]; rfl
  have h2 : (h.any fun c => c.op == o) = ((h.map Clause.op).any fun x => x == o) := by
    simp [List.any_map]; rfl
  rw [h1, h2, e]

theorem handled_of_ops {P : Program} {B : Builtins} {h h' : List Clause}
    (e : h'.map Clause.op = h.map Clause.op) : handled P B h' = handled P B h := by
  funext a
  unfold handled
  cases a with
  | rho _ => rfl
  | name l =>
      simp only
      have : handles h' = handles h := funext (handles_of_ops e)
      rw [this]

theorem handled_renameList {P : Program} {B : Builtins} (ξ : Nat → Nat) (h : List Clause) :
    handled P B (Clause.renameList ξ h) = handled P B h :=
  handled_of_ops (Clause.renameList_ops ξ h)

mutual
  theorem HasTypeV.rename {Ψ C Γ Δ ξ v a} (h : HasTypeV P B Ψ C Γ v a) (hξ : RenOk Γ Δ ξ) :
      HasTypeV P B Ψ C Δ (v.rename ξ) a := by
    match h with
    | .V_Var hi hc => simp only [Val.rename]; exact .V_Var (hξ _ _ hi) hc
    | .V_Const => simp only [Val.rename]; exact .V_Const
    | .V_Fun hd hts hes => simp only [Val.rename]; exact .V_Fun hd hts hes
    | .V_Prim hs hts hes had => simp only [Val.rename]; exact .V_Prim hs hts hes had
    | .V_Op hod hts => simp only [Val.rename]; exact .V_Op hod hts
    | .V_Lam (ps := ps) hb =>
        simp only [Val.rename]
        refine .V_Lam ?_
        have := hξ.hide.up (binds ps)
        rw [binds_length] at this
        exact HasTypeC.rename hb this
    | .V_Con hc hts hargs => simp only [Val.rename]; exact .V_Con hc hts (HasTypeVs.rename hargs hξ)
    | .V_List he hw => simp only [Val.rename]; exact .V_List (HasTypeEach.rename he hξ) hw
    | .V_LocRef hl => simp only [Val.rename]; exact .V_LocRef hl
    | .V_LocLazy hl => simp only [Val.rename]; exact .V_LocLazy hl
    | .V_Map hk hv hl hkey hwa hwb =>
        simp only [Val.rename]
        exact .V_Map (HasTypeEach.rename hk hξ) (HasTypeEach.rename hv hξ)
          (by rw [Val.renameList_length, Val.renameList_length, hl]) hkey hwa hwb
    | .V_Set he hkey hw => simp only [Val.rename]; exact .V_Set (HasTypeEach.rename he hξ) hkey hw
    | .V_Bytes => simp only [Val.rename]; exact .V_Bytes
    | .V_Dict hi hts hvs => simp only [Val.rename]; exact .V_Dict hi hts (HasTypeVs.rename hvs hξ)
    | .V_Super hv hc hs => simp only [Val.rename]; exact .V_Super (HasTypeV.rename hv hξ) hc hs
    | .V_Sub h hle => exact .V_Sub (HasTypeV.rename h hξ) hle

  theorem HasTypeVs.rename {Ψ C Γ Δ ξ vs as} (h : HasTypeVs P B Ψ C Γ vs as) (hξ : RenOk Γ Δ ξ) :
      HasTypeVs P B Ψ C Δ (Val.renameList ξ vs) as := by
    match h with
    | .nil => simp only [Val.renameList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.renameList]; exact .cons (HasTypeV.rename hv hξ) (HasTypeVs.rename hvs hξ)

  theorem HasTypeEach.rename {Ψ C Γ Δ ξ vs a} (h : HasTypeEach P B Ψ C Γ vs a) (hξ : RenOk Γ Δ ξ) :
      HasTypeEach P B Ψ C Δ (Val.renameList ξ vs) a := by
    match h with
    | .nil => simp only [Val.renameList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.renameList]; exact .cons (HasTypeV.rename hv hξ) (HasTypeEach.rename hvs hξ)

  theorem HasTypeC.rename {Ψ C Γ Δ ξ R m a ε} (h : HasTypeC P B Ψ C Γ R m a ε) (hξ : RenOk Γ Δ ξ) :
      HasTypeC P B Ψ C Δ R (m.rename ξ) a ε := by
    match h with
    | .C_Return hv => simp only [Comp.rename]; exact .C_Return (HasTypeV.rename hv hξ)
    | .C_Sub h hle hs => exact .C_Sub (HasTypeC.rename h hξ) hle hs
    | .C_Let (a := a) hm hn =>
        simp only [Comp.rename]
        exact .C_Let (HasTypeC.rename hm hξ) (HasTypeC.rename hn (hξ.up [some a]))
    | .C_App hf hargs =>
        simp only [Comp.rename]; exact .C_App (HasTypeV.rename hf hξ) (HasTypeVs.rename hargs hξ)
    | .C_If hv hm hn =>
        simp only [Comp.rename]
        exact .C_If (HasTypeV.rename hv hξ) (HasTypeC.rename hm hξ) (HasTypeC.rename hn hξ)
    | .C_Match hv harms hex =>
        simp only [Comp.rename]
        refine .C_Match (HasTypeV.rename hv hξ) (HasTypeArms.rename harms hξ) ?_
        rwa [unguardedPats_rename]
    | .C_Lazy hm => simp only [Comp.rename]; exact .C_Lazy (HasTypeC.rename hm hξ.hide)
    | .C_Escape hv hw => simp only [Comp.rename]; exact .C_Escape (HasTypeV.rename hv hξ) hw
    | .C_Use hv hr hm hs =>
        simp only [Comp.rename]; exact .C_Use (HasTypeV.rename hv hξ) hr (HasTypeC.rename hm hξ) hs
    | .C_Handle hm hs hc =>
        simp only [Comp.rename]
        refine .C_Handle (HasTypeC.rename hm hξ) ?_ (HasTypeClauses.rename hc hξ)
        rwa [handled_renameList]
    | .C_Resume hi hv =>
        simp only [Comp.rename, Val.rename]; exact .C_Resume (hξ _ _ hi) (HasTypeV.rename hv hξ)
    | .C_ResumeL hl hv =>
        simp only [Comp.rename, Val.rename]; exact .C_ResumeL hl (HasTypeV.rename hv hξ)
    | .C_Meth hv hc hm hts hes hws =>
        simp only [Comp.rename]
        exact .C_Meth (HasTypeV.rename hv hξ) hc hm hts hes (HasTypeVs.rename hws hξ)

  theorem HasTypeArms.rename {Ψ C Γ Δ ξ R arms a b ε} (h : HasTypeArms P B Ψ C Γ R arms a b ε)
      (hξ : RenOk Γ Δ ξ) : HasTypeArms P B Ψ C Δ R (Arm.renameList ξ arms) a b ε := by
    match h with
    | .nil hw => simp only [Arm.renameList]; exact .nil hw
    | .plain (δ := δ) hp hm ht =>
        simp only [Arm.renameList]
        have hξ' := hξ.up (binds δ)
        rw [binds_length, hp.2.1] at hξ'
        exact .plain hp (HasTypeC.rename hm hξ') (HasTypeArms.rename ht hξ)
    | .guarded (δ := δ) hp hg hm ht =>
        simp only [Arm.renameList]
        have hξ' := hξ.up (binds δ)
        rw [binds_length, hp.2.1] at hξ'
        exact .guarded hp (HasTypeC.rename hg hξ'.hide) (HasTypeC.rename hm hξ') (HasTypeArms.rename ht hξ)

  theorem HasTypeClauses.rename {Ψ C Γ Δ ξ R h t ε} (hc : HasTypeClauses P B Ψ C Γ R h t ε)
      (hξ : RenOk Γ Δ ξ) : HasTypeClauses P B Ψ C Δ R (Clause.renameList ξ h) t ε := by
    match hc with
    | .nil => simp only [Clause.renameList]; exact .nil
    | .cons (sg := sg) (k := k) hsg hn hk hbody hrest =>
        simp only [Clause.renameList]
        refine .cons hsg hn hk ?_ (HasTypeClauses.rename hrest hξ)
        have := RenOk.clause (some (.cont sg.ret (t.shift k 0) ε)) sg.params k hξ
        rw [← hn] at this
        exact HasTypeC.rename hbody this
end

/-! ## ストアの型付けの拡大 -/

/-- Ψ' は Ψ を広げたもの。 -/
def StoreTy.Sub (Ψ Ψ' : StoreTy) : Prop := ∀ l x, Ψ l = some x → Ψ' l = some x

theorem StoreTy.Sub.refl (Ψ : StoreTy) : StoreTy.Sub Ψ Ψ := fun _ _ h => h

theorem StoreTy.Sub.trans {Ψ₁ Ψ₂ Ψ₃ : StoreTy} (h₁ : StoreTy.Sub Ψ₁ Ψ₂) (h₂ : StoreTy.Sub Ψ₂ Ψ₃) :
    StoreTy.Sub Ψ₁ Ψ₃ := fun l x h => h₂ l x (h₁ l x h)

mutual
  theorem HasTypeV.store {Ψ Ψ' C Γ v a} (h : HasTypeV P B Ψ C Γ v a) (hΨ : StoreTy.Sub Ψ Ψ') :
      HasTypeV P B Ψ' C Γ v a := by
    match h with
    | .V_Var hi hc => exact .V_Var hi hc
    | .V_Const => exact .V_Const
    | .V_Fun hd hts hes => exact .V_Fun hd hts hes
    | .V_Prim hs hts hes had => exact .V_Prim hs hts hes had
    | .V_Op hod hts => exact .V_Op hod hts
    | .V_Lam hb => exact .V_Lam (HasTypeC.store hb hΨ)
    | .V_Con hc hts hargs => exact .V_Con hc hts (HasTypeVs.store hargs hΨ)
    | .V_List he hw => exact .V_List (HasTypeEach.store he hΨ) hw
    | .V_LocRef hl => exact .V_LocRef (hΨ _ _ hl)
    | .V_LocLazy hl => exact .V_LocLazy (hΨ _ _ hl)
    | .V_Map hk hv hl hkey hwa hwb =>
        exact .V_Map (HasTypeEach.store hk hΨ) (HasTypeEach.store hv hΨ) hl hkey hwa hwb
    | .V_Set he hkey hw => exact .V_Set (HasTypeEach.store he hΨ) hkey hw
    | .V_Bytes => exact .V_Bytes
    | .V_Dict hi hts hvs => exact .V_Dict hi hts (HasTypeVs.store hvs hΨ)
    | .V_Super hv hc hs => exact .V_Super (HasTypeV.store hv hΨ) hc hs
    | .V_Sub h hle => exact .V_Sub (HasTypeV.store h hΨ) hle

  theorem HasTypeVs.store {Ψ Ψ' C Γ vs as} (h : HasTypeVs P B Ψ C Γ vs as) (hΨ : StoreTy.Sub Ψ Ψ') :
      HasTypeVs P B Ψ' C Γ vs as := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeV.store hv hΨ) (HasTypeVs.store hvs hΨ)

  theorem HasTypeEach.store {Ψ Ψ' C Γ vs a} (h : HasTypeEach P B Ψ C Γ vs a)
      (hΨ : StoreTy.Sub Ψ Ψ') : HasTypeEach P B Ψ' C Γ vs a := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeV.store hv hΨ) (HasTypeEach.store hvs hΨ)

  theorem HasTypeC.store {Ψ Ψ' C Γ R m a ε} (h : HasTypeC P B Ψ C Γ R m a ε)
      (hΨ : StoreTy.Sub Ψ Ψ') : HasTypeC P B Ψ' C Γ R m a ε := by
    match h with
    | .C_Return hv => exact .C_Return (HasTypeV.store hv hΨ)
    | .C_Sub h hle hs => exact .C_Sub (HasTypeC.store h hΨ) hle hs
    | .C_Let hm hn => exact .C_Let (HasTypeC.store hm hΨ) (HasTypeC.store hn hΨ)
    | .C_App hf hargs => exact .C_App (HasTypeV.store hf hΨ) (HasTypeVs.store hargs hΨ)
    | .C_If hv hm hn =>
        exact .C_If (HasTypeV.store hv hΨ) (HasTypeC.store hm hΨ) (HasTypeC.store hn hΨ)
    | .C_Match hv harms hex => exact .C_Match (HasTypeV.store hv hΨ) (HasTypeArms.store harms hΨ) hex
    | .C_Lazy hm => exact .C_Lazy (HasTypeC.store hm hΨ)
    | .C_Escape hv hw => exact .C_Escape (HasTypeV.store hv hΨ) hw
    | .C_Use hv hr hm hs => exact .C_Use (HasTypeV.store hv hΨ) hr (HasTypeC.store hm hΨ) hs
    | .C_Handle hm hs hc => exact .C_Handle (HasTypeC.store hm hΨ) hs (HasTypeClauses.store hc hΨ)
    | .C_Resume hi hv => exact .C_Resume hi (HasTypeV.store hv hΨ)
    | .C_ResumeL hl hv => exact .C_ResumeL (hΨ _ _ hl) (HasTypeV.store hv hΨ)
    | .C_Meth hv hc hm hts hes hws =>
        exact .C_Meth (HasTypeV.store hv hΨ) hc hm hts hes (HasTypeVs.store hws hΨ)

  theorem HasTypeArms.store {Ψ Ψ' C Γ R arms a b ε} (h : HasTypeArms P B Ψ C Γ R arms a b ε)
      (hΨ : StoreTy.Sub Ψ Ψ') : HasTypeArms P B Ψ' C Γ R arms a b ε := by
    match h with
    | .nil hw => exact .nil hw
    | .plain hp hm ht => exact .plain hp (HasTypeC.store hm hΨ) (HasTypeArms.store ht hΨ)
    | .guarded hp hg hm ht =>
        exact .guarded hp (HasTypeC.store hg hΨ) (HasTypeC.store hm hΨ) (HasTypeArms.store ht hΨ)

  theorem HasTypeClauses.store {Ψ Ψ' C Γ R h t ε} (hc : HasTypeClauses P B Ψ C Γ R h t ε)
      (hΨ : StoreTy.Sub Ψ Ψ') : HasTypeClauses P B Ψ' C Γ R h t ε := by
    match hc with
    | .nil => exact .nil
    | .cons hsg hn hk hbody hrest =>
        exact .cons hsg hn hk (HasTypeC.store hbody hΨ) (HasTypeClauses.store hrest hΨ)
end

/-! ## 値の型付けは、継続の型の変数を使わない -/

mutual
  theorem HasTypeV.hide {Ψ C Γ v a} (h : HasTypeV P B Ψ C Γ v a) :
      HasTypeV P B Ψ C (hideConts Γ) v a := by
    match h with
    | .V_Var hi hc => exact .V_Var (hideConts_get.mpr ⟨hi, hc⟩) hc
    | .V_Const => exact .V_Const
    | .V_Fun hd hts hes => exact .V_Fun hd hts hes
    | .V_Prim hs hts hes had => exact .V_Prim hs hts hes had
    | .V_Op hod hts => exact .V_Op hod hts
    | .V_Lam hb => refine .V_Lam ?_; rw [hideConts_hideConts]; exact hb
    | .V_Con hc hts hargs => exact .V_Con hc hts (HasTypeVs.hide hargs)
    | .V_List he hw => exact .V_List (HasTypeEach.hide he) hw
    | .V_LocRef hl => exact .V_LocRef hl
    | .V_LocLazy hl => exact .V_LocLazy hl
    | .V_Map hk hv hl hkey hwa hwb =>
        exact .V_Map (HasTypeEach.hide hk) (HasTypeEach.hide hv) hl hkey hwa hwb
    | .V_Set he hkey hw => exact .V_Set (HasTypeEach.hide he) hkey hw
    | .V_Bytes => exact .V_Bytes
    | .V_Dict hi hts hvs => exact .V_Dict hi hts (HasTypeVs.hide hvs)
    | .V_Super hv hc hs => exact .V_Super (HasTypeV.hide hv) hc hs
    | .V_Sub h hle => exact .V_Sub (HasTypeV.hide h) hle

  theorem HasTypeVs.hide {Ψ C Γ vs as} (h : HasTypeVs P B Ψ C Γ vs as) :
      HasTypeVs P B Ψ C (hideConts Γ) vs as := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeV.hide hv) (HasTypeVs.hide hvs)

  theorem HasTypeEach.hide {Ψ C Γ vs a} (h : HasTypeEach P B Ψ C Γ vs a) :
      HasTypeEach P B Ψ C (hideConts Γ) vs a := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeV.hide hv) (HasTypeEach.hide hvs)
end

end Benitoite.Release
