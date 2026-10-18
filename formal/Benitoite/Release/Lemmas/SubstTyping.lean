import Benitoite.Release.Lemmas.OuterC
import Benitoite.Release.Lemmas.NoFailContext

/-!
# 値の置き換えで型付けが保たれること（契約名を持つコア）

実行中の置き換え（E-Return・E-Lam・E-Fun・E-MatchXBody・E-MatchXGuard・E-Op の `M[W̄/x̄]`）は、閉じた値か継続の場所で
変数を置き換える。閉じた値は、どの型パラメータの並びと環境のもとでも同じ型が付くので、節や
ラムダの内側へ挿入しても型が付く。継続の場所は、`resume` の第一引数に現れ、κ を作った節の R と、
置き換える位置の R が等しい。

値変数の置換では、契約名の綴り・宣言順と名前の整形式を保持する
（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


variable {P : Program} {B : Builtins}

/-- 閉じた値：どの型パラメータの並びと環境のもとでも、型 x が付く。 -/
def ClosedTy (P : Program) (B : Builtins) (Ψ : StoreTy) (v : Val) (x : Ty) : Prop :=
  ∀ Q C Γ, HasTypeVQ P B Ψ Q C Γ v x

theorem upRen_id (k : Nat) : upRen k id = id := by
  funext i; unfold upRen; split <;> simp; omega

mutual
  theorem Val.rename_id : (v : Val) → v.rename id = v
    | .var i => rfl
    | .const _ => rfl
    | .fnRef _ _ _ => rfl
    | .prim _ _ _ => rfl
    | .lam names ps body => by simp only [Val.rename, upRen_id, Comp.rename_id]
    | .con c ts args => by simp only [Val.rename, Val.renameList_id]
    | .list elems => by simp only [Val.rename, Val.renameList_id]
    | .op _ _ => rfl
    | .raise _ _ => rfl
    | .loc _ => rfl
    | .mapV ks vs => by simp only [Val.rename, Val.renameList_id]
    | .setV elems => by simp only [Val.rename, Val.renameList_id]
    | .bytesV _ => rfl
    | .dict _ _ args => by simp only [Val.rename, Val.renameList_id]
    | .super v _ => by simp only [Val.rename, Val.rename_id]

  theorem Val.renameList_id : (vs : List Val) → Val.renameList id vs = vs
    | [] => rfl
    | v :: vs => by simp only [Val.renameList, Val.rename_id, Val.renameList_id]

  theorem Comp.rename_id : (m : Comp) → m.rename id = m
    | .ret v => by simp only [Comp.rename, Val.rename_id]
    | .letIn m n => by simp only [Comp.rename, upRen_id, Comp.rename_id]
    | .app f args => by simp only [Comp.rename, Val.rename_id, Val.renameList_id]
    | .ite v m n => by simp only [Comp.rename, Val.rename_id, Comp.rename_id]
    | .match v arms => by simp only [Comp.rename, Val.rename_id, Arm.renameList_id]
    | .lazyC m => by simp only [Comp.rename, Comp.rename_id]
    | .escape v => by simp only [Comp.rename, Val.rename_id]
    | .use v m => by simp only [Comp.rename, Val.rename_id, Comp.rename_id]
    | .handle m h => by simp only [Comp.rename, Comp.rename_id, Clause.renameList_id]
    | .resume k v => by simp only [Comp.rename, Val.rename_id]
    | .meth d _ _ _ args => by simp only [Comp.rename, Val.rename_id, Val.renameList_id]

  theorem Arm.renameList_id : (arms : List Arm) → Arm.renameList id arms = arms
    | [] => rfl
    | .mk alts none m :: arms => by
        simp only [Arm.renameList, upRen_id, Comp.rename_id, Arm.renameList_id]
    | .mk alts (some g) m :: arms => by
        simp only [Arm.renameList, upRen_id, Comp.rename_id, Arm.renameList_id]

  theorem Clause.renameList_id : (h : List Clause) → Clause.renameList id h = h
    | [] => rfl
    | .mk o n k m :: cs => by simp only [Clause.renameList, upRen_id, Comp.rename_id, Clause.renameList_id]
    | .fail e m :: cs => by simp only [Clause.renameList, upRen_id, Comp.rename_id, Clause.renameList_id]
end

theorem ClosedTy.of (hb : B.Assumptions P) {Ψ v x} (h : HasTypeV P B Ψ [] [] v x)
    (hv : Val.VarsIn 0 (fun _ => True) v) : ClosedTy P B Ψ v x := by
  intro Q C Γ
  have h1 : HasTypeVQ P B Ψ Q ([] ++ C) [] v x := HasTypeVQ.outer hb (h.q_mono (QLe.empty Q)) hv
  simp only [List.nil_append] at h1
  have := h1.rename (Δ := Γ) (ξ := id) (fun i a hi => by simp at hi)
  rwa [Val.rename_id] at this

theorem ClosedTy.rename {Ψ v x} (h : ClosedTy P B Ψ v x) (ξ : Nat → Nat) :
    ClosedTy P B Ψ (v.rename ξ) x := by
  intro Q C Γ
  exact (h Q C []).rename (fun i a hi => by simp at hi)

/-- 置き換え σ が、環境 Γ の変数を、環境 Δ で同じ型を持つ変数、閉じた値、または継続の場所へ写す。
`R0` は置き換える位置の R である。 -/
def SubstOk (P : Program) (B : Builtins) (Ψ : StoreTy) (Γ Δ : List (Option Ty)) (R0 : Option Ty)
    (σ : Nat → Val) : Prop :=
  ∀ (i : Nat) (x : Ty), Γ[i]? = some (some x) →
    (∃ j, σ i = .var j ∧ Δ[j]? = some (some x)) ∨
    ((∀ b t ε, x ≠ .cont b t ε) ∧ Ty.WF 0 x ∧ ClosedTy P B Ψ (σ i) x) ∨
    (∃ b t ε l, x = .cont b t ε ∧ Ty.WF 0 x ∧ σ i = .loc l ∧ Ψ l = some (.cont b t ε R0) ∧
      ∀ r, R0 = some r → Ty.WF 0 r)

theorem SubstOk.up {Ψ Γ Δ R σ} (xs : List (Option Ty)) (h : SubstOk P B Ψ Γ Δ R σ) :
    SubstOk P B Ψ (xs ++ Γ) (xs ++ Δ) R (upSubst xs.length σ) := by
  intro i x hi
  unfold upSubst
  by_cases hlt : i < xs.length
  · simp only [hlt, ↓reduceIte]
    left; refine ⟨i, rfl, ?_⟩
    rw [List.getElem?_append_left hlt] at hi ⊢; exact hi
  · simp only [hlt, ↓reduceIte]
    rw [List.getElem?_append_right (by omega)] at hi
    rcases h _ _ hi with ⟨j, hj, hΔ⟩ | ⟨hc, hw, hcl⟩ | ⟨b, t, ε, l, hx, hw, hl, hΨ, hR⟩
    · left; refine ⟨j + xs.length, by rw [hj]; rfl, ?_⟩
      rw [List.getElem?_append_right (by omega)]; simpa using hΔ
    · right; left; exact ⟨hc, hw, hcl.rename _⟩
    · right; right; exact ⟨b, t, ε, l, hx, hw, by rw [hl]; rfl, hΨ, hR⟩

theorem SubstOk.hide {Ψ Γ Δ R σ} (R' : Option Ty) (h : SubstOk P B Ψ Γ Δ R σ) :
    SubstOk P B Ψ (hideConts Γ) (hideConts Δ) R' σ := by
  intro i x hi
  obtain ⟨hi, hc⟩ := hideConts_get.mp hi
  rcases h _ _ hi with ⟨j, hj, hΔ⟩ | ⟨hc', hw, hcl⟩ | ⟨b, t, ε, l, hx, _, _, _, _⟩
  · left; exact ⟨j, hj, hideConts_get.mpr ⟨hΔ, hc⟩⟩
  · right; left; exact ⟨hc', hw, hcl⟩
  · exact absurd hx (hc b t ε)

theorem SubstOk.shiftE {Ψ Γ Δ R σ} (k : Nat) (h : SubstOk P B Ψ Γ Δ R σ) :
    SubstOk P B Ψ (shiftEnv k Γ) (shiftEnv k Δ) (R.map (Ty.shift k 0)) σ := by
  intro i x hi
  simp only [shiftEnv, List.getElem?_map, Option.map_eq_some_iff] at hi
  obtain ⟨o, ho, hox⟩ := hi
  cases o with
  | none => simp at hox
  | some y =>
      simp only [Option.some.injEq] at hox
      obtain ⟨y', rfl, rfl⟩ := hox
      rcases h _ _ ho with ⟨j, hj, hΔ⟩ | ⟨hc, hw, hcl⟩ | ⟨b, t, ε, l, hx, hw, hl, hΨ, hR⟩
      · left; refine ⟨j, hj, ?_⟩
        simp [shiftEnv, List.getElem?_map, hΔ]
      · right; left
        rw [Ty.shift_of_wf k _ hw]; exact ⟨hc, hw, hcl⟩
      · right; right
        refine ⟨b, t, ε, l, by rw [Ty.shift_of_wf k _ hw]; exact hx, by rw [Ty.shift_of_wf k _ hw]; exact hw,
          hl, ?_, ?_⟩
        · cases hR' : R with
          | none => subst hR'; simpa using hΨ
          | some r =>
              subst hR'
              simp only [Option.map_some]; rw [Ty.shift_of_wf k _ (hR r rfl)]; exact hΨ
        · intro r hr
          cases hR' : R with
          | none => subst hR'; simp at hr
          | some r' =>
              subst hR'
              simp only [Option.map_some, Option.some.injEq] at hr
              subst hr; rw [Ty.shift_of_wf k _ (hR r' rfl)]; exact hR r' rfl

theorem SubstOk.clause {Ψ Γ Δ R σ} (c : Option Ty) (ps : List Ty) (k : Nat)
    (h : SubstOk P B Ψ Γ Δ R σ) :
    SubstOk P B Ψ (c :: (binds ps ++ shiftEnv k Γ)) (c :: (binds ps ++ shiftEnv k Δ))
      (R.map (Ty.shift k 0)) (upSubst (ps.length + 1) σ) := by
  have := (h.shiftE k).up (c :: binds ps)
  simpa [binds_length, Nat.add_comm] using this

theorem unguardedPats_subst (σ : Nat → Val) (arms : List Arm) :
    unguardedPats (Arm.substList σ arms) = unguardedPats arms := by
  induction arms with
  | nil => rfl
  | cons arm arms ih =>
      cases arm with
      | mk alts guard body => cases guard <;> simp [Arm.substList, unguardedPats, ih]

theorem Clause.substList_ops (σ : Nat → Val) (h : List Clause) :
    (Clause.substList σ h).map Clause.op = h.map Clause.op := by
  induction h with
  | nil => simp [Clause.substList]
  | cons c cs ih => cases c <;> simp [Clause.substList, Clause.op, ih]

mutual
  theorem HasTypeVQ.subst {Ψ C Γ Δ R0 σ v a} (h : HasTypeVQ P B Ψ Q C Γ v a)
      (hσ : SubstOk P B Ψ Γ Δ R0 σ) : HasTypeVQ P B Ψ Q C Δ (v.subst σ) a := by
    match h with
    | .V_Var hi hc =>
        simp only [Val.subst]
        rcases hσ _ _ hi with ⟨j, hj, hΔ⟩ | ⟨_, _, hcl⟩ | ⟨b, t, ε, l, hx, _, _, _, _⟩
        · rw [hj]; exact .V_Var hΔ hc
        · exact hcl Q C Δ
        · exact absurd hx (hc b t ε)
    | .V_Const => simp only [Val.subst]; exact .V_Const
    | .V_Fun hd hnames had => simp only [Val.subst]; exact .V_Fun hd hnames had
    | .V_Prim hs hnames had => simp only [Val.subst]; exact .V_Prim hs hnames had
    | .V_Op hod hnames hts => simp only [Val.subst]; exact .V_Op hod hnames hts
    | .V_Raise ht he => exact .V_Raise ht he
    | .V_Lam (ps := ps) (r := r) hnames hw hbody =>
        simp only [Val.subst]
        refine .V_Lam hnames hw ?_
        have := (hσ.hide (some r)).up (binds ps)
        rw [binds_length] at this
        exact HasTypeCQ.subst hbody this
    | .V_Con hc hts hargs => simp only [Val.subst]; exact .V_Con hc hts (HasTypeVsQ.subst hargs hσ)
    | .V_List he hw => simp only [Val.subst]; exact .V_List (HasTypeEachQ.subst he hσ) hw
    | .V_LocRef hl => simp only [Val.subst]; exact .V_LocRef hl
    | .V_LocLazy hl => simp only [Val.subst]; exact .V_LocLazy hl
    | .V_Map hk hv hl hkey hwa hwb =>
        simp only [Val.subst]
        exact .V_Map (HasTypeEachQ.subst hk hσ) (HasTypeEachQ.subst hv hσ)
          (by rw [Val.substList_length, Val.substList_length, hl]) hkey hwa hwb
    | .V_Set he hkey hw => simp only [Val.subst]; exact .V_Set (HasTypeEachQ.subst he hσ) hkey hw
    | .V_Bytes => simp only [Val.subst]; exact .V_Bytes
    | .V_Dict hi hts hvs => simp only [Val.subst]; exact .V_Dict hi hts (HasTypeVsQ.subst hvs hσ)
    | .V_Super hv hc hs => simp only [Val.subst]; exact .V_Super (HasTypeVQ.subst hv hσ) hc hs
    | .V_Sub h hle hw => exact .V_Sub (HasTypeVQ.subst h hσ) hle hw

  theorem HasTypeVsQ.subst {Ψ C Γ Δ R0 σ vs as} (h : HasTypeVsQ P B Ψ Q C Γ vs as)
      (hσ : SubstOk P B Ψ Γ Δ R0 σ) : HasTypeVsQ P B Ψ Q C Δ (Val.substList σ vs) as := by
    match h with
    | .nil => simp only [Val.substList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substList]; exact .cons (HasTypeVQ.subst hv hσ) (HasTypeVsQ.subst hvs hσ)

  theorem HasTypeEachQ.subst {Ψ C Γ Δ R0 σ vs a} (h : HasTypeEachQ P B Ψ Q C Γ vs a)
      (hσ : SubstOk P B Ψ Γ Δ R0 σ) : HasTypeEachQ P B Ψ Q C Δ (Val.substList σ vs) a := by
    match h with
    | .nil => simp only [Val.substList]; exact .nil
    | .cons hv hvs =>
        simp only [Val.substList]; exact .cons (HasTypeVQ.subst hv hσ) (HasTypeEachQ.subst hvs hσ)

  theorem HasTypeCQ.subst {Ψ C Γ Δ R σ m a ε} (h : HasTypeCQ P B Ψ Q C Γ R m a ε)
      (hσ : SubstOk P B Ψ Γ Δ R σ) : HasTypeCQ P B Ψ Q C Δ R (m.subst σ) a ε := by
    match h with
    | .C_Return hv => simp only [Comp.subst]; exact .C_Return (HasTypeVQ.subst hv hσ)
    | .C_Sub h hle hs hw => exact .C_Sub (HasTypeCQ.subst h hσ) hle hs hw
    | .C_Eff h hs => exact .C_Eff (HasTypeCQ.subst h hσ) hs
    | .C_Let (a := a) hm hn =>
        simp only [Comp.subst]
        exact .C_Let (HasTypeCQ.subst hm hσ) (HasTypeCQ.subst hn (hσ.up [some a]))
    | .C_App hf hargs =>
        simp only [Comp.subst]; exact .C_App (HasTypeVQ.subst hf hσ) (HasTypeVsQ.subst hargs hσ)
    | .C_If hv hm hn =>
        simp only [Comp.subst]
        exact .C_If (HasTypeVQ.subst hv hσ) (HasTypeCQ.subst hm hσ) (HasTypeCQ.subst hn hσ)
    | .C_Match hv harms hex =>
        simp only [Comp.subst]
        refine .C_Match (HasTypeVQ.subst hv hσ) (HasTypeArmsQ.subst harms hσ) ?_
        rwa [unguardedPats_subst]
    | .C_Lazy hm => simp only [Comp.subst]; exact .C_Lazy (HasTypeCQ.subst hm (hσ.hide none))
    | .C_Escape hv hw => simp only [Comp.subst]; exact .C_Escape (HasTypeVQ.subst hv hσ) hw
    | .C_Use hv hr hm hs =>
        simp only [Comp.subst]; exact .C_Use (HasTypeVQ.subst hv hσ) hr (HasTypeCQ.subst hm hσ) hs
    | .C_Handle hm hs hc =>
        simp only [Comp.subst]
        refine .C_Handle (HasTypeCQ.subst hm hσ) ?_ (HasTypeClausesQ.subst hc hσ)
        rwa [handled_of_ops (Clause.substList_ops σ _)]
    | .C_Handle_Fail hm hs hn hc =>
        exact .C_Handle_Fail (HasTypeCQ.subst hm hσ) hs hn (HasFailureClause.subst hc hσ)
    | .C_Resume hi hv =>
        simp only [Comp.subst, Val.subst]
        rcases hσ _ _ hi with ⟨j, hj, hΔ⟩ | ⟨hc, _, _⟩ | ⟨b, t, ε, l, hx, _, hl, hΨ, _⟩
        · rw [hj]; exact .C_Resume hΔ (HasTypeVQ.subst hv hσ)
        · exact absurd rfl (hc _ _ _)
        · cases hx; rw [hl]; exact .C_ResumeL hΨ (HasTypeVQ.subst hv hσ)
    | .C_ResumeL hl hv =>
        simp only [Comp.subst, Val.subst]; exact .C_ResumeL hl (HasTypeVQ.subst hv hσ)
    | .C_Meth hv hc hmeth hnames hts hscope hes hws =>
        simp only [Comp.subst]
        exact .C_Meth (HasTypeVQ.subst hv hσ) hc hmeth hnames hts hscope hes (HasTypeVsQ.subst hws hσ)

  theorem HasTypeArmsQ.subst {Ψ C Γ Δ R σ arms a b ε} (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b ε)
      (hσ : SubstOk P B Ψ Γ Δ R σ) : HasTypeArmsQ P B Ψ Q C Δ R (Arm.substList σ arms) a b ε := by
    match h with
    | .nil hw => simp only [Arm.substList]; exact .nil hw
    | .plain (δ := δ) hp hm ht =>
        simp only [Arm.substList]
        have hσ' := hσ.up (binds δ)
        rw [binds_length, hp.2.1] at hσ'
        exact .plain hp (HasTypeCQ.subst hm hσ') (HasTypeArmsQ.subst ht hσ)
    | .guarded (δ := δ) hp hg hm ht =>
        simp only [Arm.substList]
        have hσ' := hσ.up (binds δ)
        rw [binds_length, hp.2.1] at hσ'
        exact .guarded hp (HasTypeCQ.subst hg (hσ'.hide none)) (HasTypeCQ.subst hm hσ')
          (HasTypeArmsQ.subst ht hσ)

  theorem HasTypeClausesQ.subst {Ψ C Γ Δ R σ h t ε} (hc : HasTypeClausesQ P B Ψ Q C Γ R h t ε)
      (hσ : SubstOk P B Ψ Γ Δ R σ) : HasTypeClausesQ P B Ψ Q C Δ R (Clause.substList σ h) t ε := by
    match hc with
    | .nil => simp only [Clause.substList]; exact .nil
    | .cons (sg := sg) (k := k) hsg hnames hn hk hew hbody hrest =>
        simp only [Clause.substList]
        refine .cons hsg hnames hn hk hew ?_ (HasTypeClausesQ.subst hrest hσ)
        have := hσ.clause (some (.cont sg.ret (t.shift k 0) (Eff.shift k 0 ε))) sg.params k
        rw [← hn] at this
        exact HasTypeCQ.subst hbody this
  theorem HasFailureClause.subst {Ψ C Γ Δ E R σ h t ε}
      (hc : HasFailureClause P B Ψ Q C Γ E R h t ε) (hσ : SubstOk P B Ψ Γ Δ R σ) :
      HasFailureClause P B Ψ Q C Δ E R (Clause.substList σ h) t ε := by
    match hc with
    | .one he ht hew hb =>
        simp only [Clause.substList]
        exact .one he ht hew (HasTypeCQ.subst hb ((hσ.shiftE 1).up [none, some (E.shift 1 0)]))

end

/-! ## 束縛した変数を値の並びで置き換える -/

theorem HasTypeVsQ.length_eq {Ψ C Γ vs as} : HasTypeVsQ P B Ψ Q C Γ vs as → vs.length = as.length
  | .nil => rfl
  | .cons _ h => by simp [HasTypeVsQ.length_eq h]

/-- `instantiate` の置き換えについての条件。束縛する変数ごとに、閉じた値か継続の場所を与える。 -/
def InstOk (P : Program) (B : Builtins) (Ψ : StoreTy) (R0 : Option Ty) (as : List Ty)
    (ws : List Val) : Prop :=
  ws.length = as.length ∧
  ∀ (i : Nat) (x : Ty) (w : Val), as[i]? = some x → ws[i]? = some w →
    ((∀ b t ε, x ≠ .cont b t ε) ∧ Ty.WF 0 x ∧ ClosedTy P B Ψ w x) ∨
    (∃ b t ε l, x = .cont b t ε ∧ Ty.WF 0 x ∧ w = .loc l ∧ Ψ l = some (.cont b t ε R0) ∧
      ∀ r, R0 = some r → Ty.WF 0 r)

theorem SubstOk.inst {Ψ R0 as ws} (h : InstOk P B Ψ R0 as ws) :
    SubstOk P B Ψ (binds as) [] R0 (instSubst ws) := by
  intro i x hi
  obtain ⟨hlen, hpt⟩ := h
  simp only [binds, List.getElem?_map, Option.map_eq_some_iff, Option.some.injEq] at hi
  obtain ⟨y, hy, rfl⟩ := hi
  have hi' : i < as.length := by
    have := (List.getElem?_eq_some_iff.mp hy).1; simpa using this
  rw [List.getElem?_reverse hi'] at hy
  have hlt : i < ws.length := by omega
  have hw : ws.reverse[i]? = ws[ws.length - 1 - i]? := List.getElem?_reverse hlt
  have hws : ∃ w, ws[as.length - 1 - i]? = some w :=
    ⟨ws[as.length - 1 - i], List.getElem?_eq_getElem (by omega)⟩
  obtain ⟨w, hw'⟩ := hws
  right
  unfold instSubst
  have e : ws.reverse[i]? = some w := by rw [hw, hlen]; exact hw'
  simp only [hlt, ↓reduceIte, e, Option.getD_some]
  exact hpt _ _ _ hy hw'

/-- 01-12 の `M[W̄/x̄]`：型の付いた計算に、束縛した変数の型の閉じた値か継続の場所を入れても、型が保たれる。 -/
theorem HasTypeCQ.instantiate {Ψ C R as ws m a ε} (hm : HasTypeCQ P B Ψ Q C (binds as) R m a ε)
    (hws : InstOk P B Ψ R as ws) : HasTypeCQ P B Ψ Q C [] R (m.instantiate ws) a ε :=
  hm.subst (SubstOk.inst hws)

theorem HasTypeVQ.instantiate {Ψ C R as ws v a} (hv : HasTypeVQ P B Ψ Q C (binds as) v a)
    (hws : InstOk P B Ψ R as ws) : HasTypeVQ P B Ψ Q C [] (v.instantiate ws) a :=
  hv.subst (SubstOk.inst hws)

end Benitoite.Release
