import Benitoite.Release.Lemmas.Basic

/-!
# 環境とストアの型付けの弱化（段階 B）

番号の付け替え、ストアの型付けの拡大（Ψ ⊆ Ψ'）、`hideConts` についての補題。
契約名の整形式の証拠を保持し、環境とストアだけを変える
（設計書 01-12「型付け規則」「ハンドラ」）。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


variable {P : Program} {B : Builtins}

/-! ## パターンが束縛する変数の個数 -/

mutual
  theorem PatTy.length_eq {p a δ} : PatTy P p a δ → δ.length = p.binders
    | .P_Wild => by simp [Pat.binders]
    | .P_Var => by simp [Pat.binders]
    | .P_Const _ => by simp [Pat.binders]
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
  | cons c cs ih => cases c <;> simp [Clause.renameList, Clause.op, ih]

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
  apply Eff.ext_test
  · intro a
    simp only [Eff.test, Eff.ofAtoms, handled, Eff.atoms]
    cases a with
    | rho _ => rfl
    | name l =>
      simp only
      have : handles h' = handles h := funext (handles_of_ops e)
      rw [this]
  · rfl

theorem handled_renameList {P : Program} {B : Builtins} (ξ : Nat → Nat) (h : List Clause) :
    handled P B (Clause.renameList ξ h) = handled P B h :=
  handled_of_ops (Clause.renameList_ops ξ h)

mutual
  theorem HasTypeVQ.rename {Ψ C Γ Δ ξ v a} (h : HasTypeVQ P B Ψ Q C Γ v a) (hξ : RenOk Γ Δ ξ) :
      HasTypeVQ P B Ψ Q C Δ (v.rename ξ) a := by
    match h with
    | .V_Var hi hc => simp only [Val.rename]; exact .V_Var (hξ _ _ hi) hc
    | .V_Const => simp only [Val.rename]; exact .V_Const
    | .V_Fun hd hn had => simp only [Val.rename]; exact .V_Fun hd hn had
    | .V_Prim hs hn had => simp only [Val.rename]; exact .V_Prim hs hn had
    | .V_Op hod hn hts => simp only [Val.rename]; exact .V_Op hod hn hts
    | .V_Raise ht he => simp only [Val.rename]; exact .V_Raise ht he
    | .V_Lam (ps := ps) hn hw hb =>
        simp only [Val.rename]
        refine .V_Lam hn hw ?_
        have := hξ.hide.up (binds ps)
        rw [binds_length] at this
        exact HasTypeCQ.rename hb this
    | .V_Con hc hts hargs => simp only [Val.rename]; exact .V_Con hc hts (HasTypeVsQ.rename hargs hξ)
    | .V_List he hw => simp only [Val.rename]; exact .V_List (HasTypeEachQ.rename he hξ) hw
    | .V_LocRef hl => simp only [Val.rename]; exact .V_LocRef hl
    | .V_LocLazy hl => simp only [Val.rename]; exact .V_LocLazy hl
    | .V_Map hk hv hl hkey hwa hwb =>
        simp only [Val.rename]
        exact .V_Map (HasTypeEachQ.rename hk hξ) (HasTypeEachQ.rename hv hξ)
          (by rw [Val.renameList_length, Val.renameList_length, hl]) hkey hwa hwb
    | .V_Set he hkey hw => simp only [Val.rename]; exact .V_Set (HasTypeEachQ.rename he hξ) hkey hw
    | .V_Bytes => simp only [Val.rename]; exact .V_Bytes
    | .V_Dict hi hts hvs => simp only [Val.rename]; exact .V_Dict hi hts (HasTypeVsQ.rename hvs hξ)
    | .V_Super hv hc hs => simp only [Val.rename]; exact .V_Super (HasTypeVQ.rename hv hξ) hc hs
    | .V_Sub h hle hw => exact .V_Sub (HasTypeVQ.rename h hξ) hle hw

  theorem HasTypeVsQ.rename {Ψ C Γ Δ ξ vs as} (h : HasTypeVsQ P B Ψ Q C Γ vs as) (hξ : RenOk Γ Δ ξ) :
      HasTypeVsQ P B Ψ Q C Δ (Val.renameList ξ vs) as := by
    match h with
    | .nil => simp only [Val.renameList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.renameList]; exact .cons (HasTypeVQ.rename hv hξ) (HasTypeVsQ.rename hvs hξ)

  theorem HasTypeEachQ.rename {Ψ C Γ Δ ξ vs a} (h : HasTypeEachQ P B Ψ Q C Γ vs a) (hξ : RenOk Γ Δ ξ) :
      HasTypeEachQ P B Ψ Q C Δ (Val.renameList ξ vs) a := by
    match h with
    | .nil => simp only [Val.renameList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.renameList]; exact .cons (HasTypeVQ.rename hv hξ) (HasTypeEachQ.rename hvs hξ)

  theorem HasTypeCQ.rename {Ψ C Γ Δ ξ R m a ε} (h : HasTypeCQ P B Ψ Q C Γ R m a ε) (hξ : RenOk Γ Δ ξ) :
      HasTypeCQ P B Ψ Q C Δ R (m.rename ξ) a ε := by
    match h with
    | .C_Return hv => simp only [Comp.rename]; exact .C_Return (HasTypeVQ.rename hv hξ)
    | .C_Sub h hle hs hw => exact .C_Sub (HasTypeCQ.rename h hξ) hle hs hw
    | .C_Eff h hs => exact .C_Eff (HasTypeCQ.rename h hξ) hs
    | .C_Let (a := a) hm hn =>
        simp only [Comp.rename]
        exact .C_Let (HasTypeCQ.rename hm hξ) (HasTypeCQ.rename hn (hξ.up [some a]))
    | .C_App hf hargs =>
        simp only [Comp.rename]; exact .C_App (HasTypeVQ.rename hf hξ) (HasTypeVsQ.rename hargs hξ)
    | .C_If hv hm hn =>
        simp only [Comp.rename]
        exact .C_If (HasTypeVQ.rename hv hξ) (HasTypeCQ.rename hm hξ) (HasTypeCQ.rename hn hξ)
    | .C_Match hv harms hex =>
        simp only [Comp.rename]
        refine .C_Match (HasTypeVQ.rename hv hξ) (HasTypeArmsQ.rename harms hξ) ?_
        rwa [unguardedPats_rename]
    | .C_Lazy hm => simp only [Comp.rename]; exact .C_Lazy (HasTypeCQ.rename hm hξ.hide)
    | .C_Escape hv hw => simp only [Comp.rename]; exact .C_Escape (HasTypeVQ.rename hv hξ) hw
    | .C_Use hv hr hm hs =>
        simp only [Comp.rename]; exact .C_Use (HasTypeVQ.rename hv hξ) hr (HasTypeCQ.rename hm hξ) hs
    | .C_Handle hm hs hc =>
        simp only [Comp.rename]
        refine .C_Handle (HasTypeCQ.rename hm hξ) ?_ (HasTypeClausesQ.rename hc hξ)
        rwa [handled_renameList]
    | .C_Handle_Fail hm hs hn hc =>
        simp only [Comp.rename]
        exact .C_Handle_Fail (HasTypeCQ.rename hm hξ) hs hn (HasFailureClause.rename hc hξ)
    | .C_Resume hi hv =>
        simp only [Comp.rename, Val.rename]; exact .C_Resume (hξ _ _ hi) (HasTypeVQ.rename hv hξ)
    | .C_ResumeL hl hv =>
        simp only [Comp.rename, Val.rename]; exact .C_ResumeL hl (HasTypeVQ.rename hv hξ)
    | .C_Meth hv hc hm hnames hts hscope hes hws =>
        simp only [Comp.rename]
        exact .C_Meth (HasTypeVQ.rename hv hξ) hc hm hnames hts hscope hes (HasTypeVsQ.rename hws hξ)

  theorem HasTypeArmsQ.rename {Ψ C Γ Δ ξ R arms a b ε} (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε)
      (hξ : RenOk Γ Δ ξ) : HasTypeArmsQ P B Ψ Q C Δ R (Arm.renameList ξ arms) a b ε := by
    match h with
    | .nil hw => simp only [Arm.renameList]; exact .nil hw
    | .plain (δ := δ) hp hm ht =>
        simp only [Arm.renameList]
        have hξ' := hξ.up (binds δ)
        rw [binds_length, hp.2.1] at hξ'
        exact .plain hp (HasTypeCQ.rename hm hξ') (HasTypeArmsQ.rename ht hξ)
    | .guarded (δ := δ) hp hg hm ht =>
        simp only [Arm.renameList]
        have hξ' := hξ.up (binds δ)
        rw [binds_length, hp.2.1] at hξ'
        exact .guarded hp (HasTypeCQ.rename hg hξ'.hide) (HasTypeCQ.rename hm hξ') (HasTypeArmsQ.rename ht hξ)

  theorem HasTypeClausesQ.rename {Ψ C Γ Δ ξ R h t ε} (hc : HasTypeClausesQ P B Ψ Q C Γ R h t ε)
      (hξ : RenOk Γ Δ ξ) : HasTypeClausesQ P B Ψ Q C Δ R (Clause.renameList ξ h) t ε := by
    match hc with
    | .nil => simp only [Clause.renameList]; exact .nil
    | .cons (sg := sg) (k := k) hsg hnames hn hk hew hbody hrest =>
        simp only [Clause.renameList]
        refine .cons hsg hnames hn hk hew ?_ (HasTypeClausesQ.rename hrest hξ)
        have := RenOk.clause (some (.cont sg.ret (t.shift k 0) (Eff.shift k 0 ε))) sg.params k hξ
        rw [← hn] at this
        exact HasTypeCQ.rename hbody this
  theorem HasFailureClause.rename {Ψ C Γ Δ ξ E R h t ε}
      (hc : HasFailureClause P B Ψ Q C Γ E R h t ε) (hξ : RenOk Γ Δ ξ) :
      HasFailureClause P B Ψ Q C Δ E R (Clause.renameList ξ h) t ε := by
    match hc with
    | .one he ht hew hb =>
        simp only [Clause.renameList]
        refine .one he ht hew ?_
        exact HasTypeCQ.rename hb ((hξ.shiftE 1).up [none, some (E.shift 1 0)])

end

/-! ## ストアの型付けの拡大 -/

/-- Ψ' は Ψ を広げたもの。 -/
def StoreTy.Sub (Ψ Ψ' : StoreTy) : Prop := ∀ l x, Ψ l = some x → Ψ' l = some x

theorem StoreTy.Sub.refl (Ψ : StoreTy) : StoreTy.Sub Ψ Ψ := fun _ _ h => h

theorem StoreTy.Sub.trans {Ψ₁ Ψ₂ Ψ₃ : StoreTy} (h₁ : StoreTy.Sub Ψ₁ Ψ₂) (h₂ : StoreTy.Sub Ψ₂ Ψ₃) :
    StoreTy.Sub Ψ₁ Ψ₃ := fun l x h => h₂ l x (h₁ l x h)

mutual
  theorem HasTypeVQ.store {Ψ Ψ' C Γ v a} (h : HasTypeVQ P B Ψ Q C Γ v a) (hΨ : StoreTy.Sub Ψ Ψ') :
      HasTypeVQ P B Ψ' Q C Γ v a := by
    match h with
    | .V_Var hi hc => exact .V_Var hi hc
    | .V_Const => exact .V_Const
    | .V_Fun hd hn had => exact .V_Fun hd hn had
    | .V_Prim hs hn had => exact .V_Prim hs hn had
    | .V_Op hod hn hts => exact .V_Op hod hn hts
    | .V_Raise ht he => exact .V_Raise ht he
    | .V_Lam hn hw hb => exact .V_Lam hn hw (HasTypeCQ.store hb hΨ)
    | .V_Con hc hts hargs => exact .V_Con hc hts (HasTypeVsQ.store hargs hΨ)
    | .V_List he hw => exact .V_List (HasTypeEachQ.store he hΨ) hw
    | .V_LocRef hl => exact .V_LocRef (hΨ _ _ hl)
    | .V_LocLazy hl => exact .V_LocLazy (hΨ _ _ hl)
    | .V_Map hk hv hl hkey hwa hwb =>
        exact .V_Map (HasTypeEachQ.store hk hΨ) (HasTypeEachQ.store hv hΨ) hl hkey hwa hwb
    | .V_Set he hkey hw => exact .V_Set (HasTypeEachQ.store he hΨ) hkey hw
    | .V_Bytes => exact .V_Bytes
    | .V_Dict hi hts hvs => exact .V_Dict hi hts (HasTypeVsQ.store hvs hΨ)
    | .V_Super hv hc hs => exact .V_Super (HasTypeVQ.store hv hΨ) hc hs
    | .V_Sub h hle hw => exact .V_Sub (HasTypeVQ.store h hΨ) hle hw

  theorem HasTypeVsQ.store {Ψ Ψ' C Γ vs as} (h : HasTypeVsQ P B Ψ Q C Γ vs as) (hΨ : StoreTy.Sub Ψ Ψ') :
      HasTypeVsQ P B Ψ' Q C Γ vs as := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeVQ.store hv hΨ) (HasTypeVsQ.store hvs hΨ)

  theorem HasTypeEachQ.store {Ψ Ψ' C Γ vs a} (h : HasTypeEachQ P B Ψ Q C Γ vs a)
      (hΨ : StoreTy.Sub Ψ Ψ') : HasTypeEachQ P B Ψ' Q C Γ vs a := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeVQ.store hv hΨ) (HasTypeEachQ.store hvs hΨ)

  theorem HasTypeCQ.store {Ψ Ψ' C Γ R m a ε} (h : HasTypeCQ P B Ψ Q C Γ R m a ε)
      (hΨ : StoreTy.Sub Ψ Ψ') : HasTypeCQ P B Ψ' Q C Γ R m a ε := by
    match h with
    | .C_Return hv => exact .C_Return (HasTypeVQ.store hv hΨ)
    | .C_Sub h hle hs hw => exact .C_Sub (HasTypeCQ.store h hΨ) hle hs hw
    | .C_Eff h hs => exact .C_Eff (HasTypeCQ.store h hΨ) hs
    | .C_Let hm hn => exact .C_Let (HasTypeCQ.store hm hΨ) (HasTypeCQ.store hn hΨ)
    | .C_App hf hargs => exact .C_App (HasTypeVQ.store hf hΨ) (HasTypeVsQ.store hargs hΨ)
    | .C_If hv hm hn =>
        exact .C_If (HasTypeVQ.store hv hΨ) (HasTypeCQ.store hm hΨ) (HasTypeCQ.store hn hΨ)
    | .C_Match hv harms hex => exact .C_Match (HasTypeVQ.store hv hΨ) (HasTypeArmsQ.store harms hΨ) hex
    | .C_Lazy hm => exact .C_Lazy (HasTypeCQ.store hm hΨ)
    | .C_Escape hv hw => exact .C_Escape (HasTypeVQ.store hv hΨ) hw
    | .C_Use hv hr hm hs => exact .C_Use (HasTypeVQ.store hv hΨ) hr (HasTypeCQ.store hm hΨ) hs
    | .C_Handle hm hs hc => exact .C_Handle (HasTypeCQ.store hm hΨ) hs (HasTypeClausesQ.store hc hΨ)
    | .C_Handle_Fail hm hs hn hc =>

        exact .C_Handle_Fail (HasTypeCQ.store hm hΨ) hs hn (HasFailureClause.store hc hΨ)
    | .C_Resume hi hv => exact .C_Resume hi (HasTypeVQ.store hv hΨ)
    | .C_ResumeL hl hv => exact .C_ResumeL (hΨ _ _ hl) (HasTypeVQ.store hv hΨ)
    | .C_Meth hv hc hm hnames hts hscope hes hws =>
        exact .C_Meth (HasTypeVQ.store hv hΨ) hc hm hnames hts hscope hes (HasTypeVsQ.store hws hΨ)

  theorem HasTypeArmsQ.store {Ψ Ψ' C Γ R arms a b ε} (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε)
      (hΨ : StoreTy.Sub Ψ Ψ') : HasTypeArmsQ P B Ψ' Q C Γ R arms a b ε := by
    match h with
    | .nil hw => exact .nil hw
    | .plain hp hm ht => exact .plain hp (HasTypeCQ.store hm hΨ) (HasTypeArmsQ.store ht hΨ)
    | .guarded hp hg hm ht =>
        exact .guarded hp (HasTypeCQ.store hg hΨ) (HasTypeCQ.store hm hΨ) (HasTypeArmsQ.store ht hΨ)

  theorem HasTypeClausesQ.store {Ψ Ψ' C Γ R h t ε} (hc : HasTypeClausesQ P B Ψ Q C Γ R h t ε)
      (hΨ : StoreTy.Sub Ψ Ψ') : HasTypeClausesQ P B Ψ' Q C Γ R h t ε := by
    match hc with
    | .nil => exact .nil
    | .cons hsg hnames hn hk hew hbody hrest =>
        exact .cons hsg hnames hn hk hew (HasTypeCQ.store hbody hΨ) (HasTypeClausesQ.store hrest hΨ)
  theorem HasFailureClause.store {Ψ Ψ' C Γ E R h t ε}
      (hc : HasFailureClause P B Ψ Q C Γ E R h t ε) (hΨ : StoreTy.Sub Ψ Ψ') :
      HasFailureClause P B Ψ' Q C Γ E R h t ε := by
    match hc with
    | .one he ht hew hb => exact .one he ht hew (HasTypeCQ.store hb hΨ)

end

/-! ## 値の型付けは、継続の型の変数を使わない -/

mutual
  theorem HasTypeVQ.hide {Ψ C Γ v a} (h : HasTypeVQ P B Ψ Q C Γ v a) :
      HasTypeVQ P B Ψ Q C (hideConts Γ) v a := by
    match h with
    | .V_Var hi hc => exact .V_Var (hideConts_get.mpr ⟨hi, hc⟩) hc
    | .V_Const => exact .V_Const
    | .V_Fun hd hn had => exact .V_Fun hd hn had
    | .V_Prim hs hn had => exact .V_Prim hs hn had
    | .V_Op hod hn hts => exact .V_Op hod hn hts
    | .V_Raise ht he => exact .V_Raise ht he
    | .V_Lam hn hw hb => refine .V_Lam hn hw ?_; rw [hideConts_hideConts]; exact hb
    | .V_Con hc hts hargs => exact .V_Con hc hts (HasTypeVsQ.hide hargs)
    | .V_List he hw => exact .V_List (HasTypeEachQ.hide he) hw
    | .V_LocRef hl => exact .V_LocRef hl
    | .V_LocLazy hl => exact .V_LocLazy hl
    | .V_Map hk hv hl hkey hwa hwb =>
        exact .V_Map (HasTypeEachQ.hide hk) (HasTypeEachQ.hide hv) hl hkey hwa hwb
    | .V_Set he hkey hw => exact .V_Set (HasTypeEachQ.hide he) hkey hw
    | .V_Bytes => exact .V_Bytes
    | .V_Dict hi hts hvs => exact .V_Dict hi hts (HasTypeVsQ.hide hvs)
    | .V_Super hv hc hs => exact .V_Super (HasTypeVQ.hide hv) hc hs
    | .V_Sub h hle hw => exact .V_Sub (HasTypeVQ.hide h) hle hw

  theorem HasTypeVsQ.hide {Ψ C Γ vs as} (h : HasTypeVsQ P B Ψ Q C Γ vs as) :
      HasTypeVsQ P B Ψ Q C (hideConts Γ) vs as := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeVQ.hide hv) (HasTypeVsQ.hide hvs)

  theorem HasTypeEachQ.hide {Ψ C Γ vs a} (h : HasTypeEachQ P B Ψ Q C Γ vs a) :
      HasTypeEachQ P B Ψ Q C (hideConts Γ) vs a := by
    match h with
    | .nil => exact .nil
    | .cons hv hvs => exact .cons (HasTypeVQ.hide hv) (HasTypeEachQ.hide hvs)
end

end Benitoite.Release
