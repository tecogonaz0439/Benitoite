import Benitoite.Release.Lemmas.Rename

/-!
# 利用不能な変数の位置と値置換

型を持つ位置で二つの置換が一致すれば、型付きの項への値置換は等しい。
任意の none の位置の無関係性を導き、Fail 節の予約した継続の禁止に使う。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


/-- 型を持つ環境の位置だけでの、値置換の一致。継続の位置も含む。 -/
def SubstAgree (Γ : List (Option Ty)) (σ τ : Nat → Val) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → σ i = τ i

theorem SubstAgree.up {Γ σ τ} (h : SubstAgree Γ σ τ) (xs : List (Option Ty)) :
    SubstAgree (xs ++ Γ) (upSubst xs.length σ) (upSubst xs.length τ) := by
  intro i a hi
  by_cases hl : i < xs.length
  · simp only [upSubst, hl, ↓reduceIte]
  · have ha : Γ[i - xs.length]? = some (some a) := by
      rwa [List.getElem?_append_right (by omega)] at hi
    simp only [upSubst, hl, ↓reduceIte, h _ _ ha]

theorem SubstAgree.hide {Γ σ τ} (h : SubstAgree Γ σ τ) :
    SubstAgree (hideConts Γ) σ τ := by
  intro i a hi
  exact h i a (hideConts_get.mp hi).1

theorem SubstAgree.shiftEnv {Γ σ τ} (h : SubstAgree Γ σ τ) (k : Nat) :
    SubstAgree (shiftEnv k Γ) σ τ := by
  intro i a hi
  simp only [Benitoite.Release.shiftEnv, List.getElem?_map, Option.map_eq_some_iff] at hi
  obtain ⟨o, ho, hoa⟩ := hi
  cases o with
  | none => simp at hoa
  | some b => exact h i b ho

/-- 分類された局所番号での、専用置換の一致。 -/
def LocalSubstAgree (Δ : LocalCtx) (ρ η : Nat → LocalRef) : Prop :=
  ∀ i k, Δ.kindAt i = some k → ρ i = η i

theorem LocalSubstAgree.empty (ρ η : Nat → LocalRef) : LocalSubstAgree [] ρ η := by
  intro i k hi; simp [LocalCtx.kindAt] at hi

theorem LocalSubstAgree.refl (Δ : LocalCtx) (ρ : Nat → LocalRef) : LocalSubstAgree Δ ρ ρ := by
  intro i k hi; rfl

theorem LocalSubstAgree.extend {Δ ρ η} (h : LocalSubstAgree Δ ρ η) (n : Nat) :
    LocalSubstAgree (Δ.extend n) (upLocalSubst n ρ) (upLocalSubst n η) := by
  intro i k hi
  rw [LocalCtx.kindAt_extend] at hi
  by_cases hn : i < n
  · simp [hn] at hi
  · simp only [hn, ↓reduceIte] at hi
    simp [upLocalSubst, hn, h _ _ hi]

theorem LocalSubstAgree.builder {Δ ρ η} (h : LocalSubstAgree Δ ρ η) (kind : BuilderKind) :
    LocalSubstAgree (some kind :: Δ) (upLocalSubst 1 ρ) (upLocalSubst 1 η) := by
  intro i k hi
  cases i with
  | zero => rfl
  | succ i => simp [upLocalSubst, h i k (by simpa [LocalCtx.kindAt] using hi)]

theorem LocalRef.HasKind.subst_congr {Ψ Δ r k ρ η} (h : HasKind Ψ Δ r k)
    (hL : LocalSubstAgree Δ ρ η) : r.subst ρ = r.subst η := by
  cases h with
  | bound hi => exact hL _ _ hi
  | loc hl => rfl

mutual
  theorem HasTypeVQ.subst_congr {ρ η : Nat → LocalRef} {P B Ψ C Γ v a σ τ}
      (h : HasTypeVQ P B Ψ Q C Γ v a) (hs : SubstAgree Γ σ τ) : v.subst σ ρ = v.subst τ η := by
    match h with
    | .V_Var hi _ => exact hs _ _ hi
    | .V_Const | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes => rfl
    | .V_Lam (ps := ps) _ _ hb =>
      simp only [Val.subst]
      have h := hs.hide.up (binds ps)
      rw [binds_length] at h
      rw [HasTypeCQ.subst_congr (ρ := upLocalSubst ps.length ρ) (η := upLocalSubst ps.length η) hb h]
    | .V_Con _ _ ha => simp only [Val.subst, HasTypeVsQ.subst_congr (ρ := ρ) (η := η) ha hs]
    | .V_List he _ => simp only [Val.subst, HasTypeEachQ.subst_congr (ρ := ρ) (η := η) he hs]
    | .V_Map hk hv .. =>
      simp only [Val.subst, HasTypeEachQ.subst_congr (ρ := ρ) (η := η) hk hs, HasTypeEachQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .V_Set he .. => simp only [Val.subst, HasTypeEachQ.subst_congr (ρ := ρ) (η := η) he hs]
    | .V_Dict _ _ ha => simp only [Val.subst, HasTypeVsQ.subst_congr (ρ := ρ) (η := η) ha hs]
    | .V_Super hv _ _ => simp only [Val.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .V_Sub hv _ _ => exact HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs

  theorem HasTypeVsQ.subst_congr {ρ η : Nat → LocalRef} {P B Ψ C Γ vs as σ τ}
      (h : HasTypeVsQ P B Ψ Q C Γ vs as) (hs : SubstAgree Γ σ τ) :
      Val.substList σ vs ρ = Val.substList τ vs η := by
    match h with
    | .nil => rfl
    | .cons hv hvs => simp only [Val.substList, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs, HasTypeVsQ.subst_congr (ρ := ρ) (η := η) hvs hs]

  theorem HasTypeEachQ.subst_congr {ρ η : Nat → LocalRef} {P B Ψ C Γ vs a σ τ}
      (h : HasTypeEachQ P B Ψ Q C Γ vs a) (hs : SubstAgree Γ σ τ) :
      Val.substList σ vs ρ = Val.substList τ vs η := by
    match h with
    | .nil => rfl
    | .cons hv hvs => simp only [Val.substList, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs, HasTypeEachQ.subst_congr (ρ := ρ) (η := η) hvs hs]

  theorem HasTypeCQ.subst_congr {Δl : LocalCtx} {ρ η : Nat → LocalRef} {P B Ψ C Γ R m a e σ τ}
      (h : HasTypeCQ P B Ψ Q C Γ R m a e Δl) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree Δl ρ η := by exact LocalSubstAgree.empty _ _) : m.subst σ ρ = m.subst τ η := by
    match h with
    | .C_BuilderLet (kind := kind) _ hb =>
      simp only [Comp.subst]
      exact congrArg (Comp.builderLet kind) (HasTypeCQ.subst_congr hb (hs.up [none]) (hL.builder kind))
    | .C_BuilderOp _ hr ha =>
      simp only [Comp.subst, hr.subst_congr hL, HasTypeVsQ.subst_congr (ρ := ρ) (η := η) ha hs]
    | .C_Return hv => simp only [Comp.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_Sub hm .. | .C_Eff hm .. => exact HasTypeCQ.subst_congr (ρ := ρ) (η := η) hm hs hL
    | .C_Let (a := a) hm hn =>
      have hs' : SubstAgree (some a :: Γ) (upSubst 1 σ) (upSubst 1 τ) := hs.up [some a]
      simp only [Comp.subst, HasTypeCQ.subst_congr (ρ := ρ) (η := η) hm hs hL, HasTypeCQ.subst_congr (ρ := upLocalSubst 1 ρ) (η := upLocalSubst 1 η) hn hs' (hL.extend 1)]
    | .C_App hf ha => simp only [Comp.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hf hs, HasTypeVsQ.subst_congr (ρ := ρ) (η := η) ha hs]
    | .C_If hv hm hn =>
      simp only [Comp.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs, HasTypeCQ.subst_congr (ρ := ρ) (η := η) hm hs hL,
        HasTypeCQ.subst_congr (ρ := ρ) (η := η) hn hs hL]
    | .C_Match hv ha _ =>
      simp only [Comp.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs, HasTypeArmsQ.subst_congr (ρ := ρ) (η := η) ha hs hL]
    | .C_Lazy hm => simp only [Comp.subst, HasTypeCQ.subst_congr (ρ := ρ) (η := η) hm hs.hide]
    | .C_Escape hv _ => simp only [Comp.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_Use hv _ hm _ => simp only [Comp.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs, HasTypeCQ.subst_congr (ρ := ρ) (η := η) hm hs hL]
    | .C_Handle hm _ hc =>
      simp only [Comp.subst, HasTypeCQ.subst_congr (ρ := ρ) (η := η) hm hs hL, HasTypeClausesQ.subst_congr (ρ := ρ) (η := η) hc hs hL]
    | .C_Handle_Fail hm _ _ hc =>
      simp only [Comp.subst, HasTypeCQ.subst_congr (ρ := ρ) (η := η) hm hs hL, HasFailureClause.subst_congr (ρ := ρ) (η := η) hc hs hL]
    | .C_Resume hi hv => simp only [Comp.subst, Val.subst, hs _ _ hi, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_ResumeL _ hv => simp only [Comp.subst, Val.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_Meth hv _ _ _ _ _ _ ha =>
      simp only [Comp.subst, HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs, HasTypeVsQ.subst_congr (ρ := ρ) (η := η) ha hs]

  theorem HasTypeArmsQ.subst_congr {Δl : LocalCtx} {ρ η : Nat → LocalRef} {P B Ψ C Γ R arms a b e σ τ}
      (h : HasTypeArmsQ P B Ψ Q C Γ R arms a b e Δl) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree Δl ρ η := by exact LocalSubstAgree.empty _ _) :
      Arm.substList σ arms ρ = Arm.substList τ arms η := by
    match h with
    | .nil _ => rfl
    | .plain (alts := alts) (δ := δ) hp hm ht =>
      have hs' := hs.up (binds δ)
      rw [binds_length, hp.2.1] at hs'
      simp only [Arm.substList, HasTypeCQ.subst_congr (ρ := upLocalSubst (Arm.bindersOf alts) ρ) (η := upLocalSubst (Arm.bindersOf alts) η) hm hs' (by simpa [hp.2.1] using hL.extend δ.length), HasTypeArmsQ.subst_congr (ρ := ρ) (η := η) ht hs hL]
    | .guarded (alts := alts) (δ := δ) hp hg hm ht =>
      have hs' := hs.up (binds δ)
      rw [binds_length, hp.2.1] at hs'
      simp only [Arm.substList, HasTypeCQ.subst_congr (ρ := upLocalSubst (Arm.bindersOf alts) ρ) (η := upLocalSubst (Arm.bindersOf alts) η) hg hs'.hide (by simpa [hp.2.1] using hL.extend δ.length),
        HasTypeCQ.subst_congr (ρ := upLocalSubst (Arm.bindersOf alts) ρ) (η := upLocalSubst (Arm.bindersOf alts) η) hm hs' (by simpa [hp.2.1] using hL.extend δ.length), HasTypeArmsQ.subst_congr (ρ := ρ) (η := η) ht hs hL]

  theorem HasTypeClausesQ.subst_congr {Δl : LocalCtx} {ρ η : Nat → LocalRef} {P B Ψ C Γ R cs t e σ τ}
      (h : HasTypeClausesQ P B Ψ Q C Γ R cs t e Δl) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree Δl ρ η := by exact LocalSubstAgree.empty _ _) :
      Clause.substList σ cs ρ = Clause.substList τ cs η := by
    match h with
    | .nil => rfl
    | .cons (sg := sg) (k := k) (n := n) _ _ hn _ _ hb ht =>
      have hs'' := (hs.shiftEnv k).up
        (some (.cont sg.ret (t.shift k 0) (Eff.shift k 0 e)) :: binds sg.params)
      simp only [List.cons_append] at hs''
      simp only [List.length_cons, binds_length, ← hn] at hs''
      simp only [Clause.substList, HasTypeCQ.subst_congr (ρ := upLocalSubst (n + 1) ρ) (η := upLocalSubst (n + 1) η) hb hs'', HasTypeClausesQ.subst_congr (ρ := ρ) (η := η) ht hs hL]
  theorem HasFailureClause.subst_congr {Δl : LocalCtx} {ρ η : Nat → LocalRef} {P B Ψ C Γ E R h t e σ τ}
      (hc : HasFailureClause P B Ψ Q C Γ E R h t e Δl) (hs : SubstAgree Γ σ τ)
      (_hL : LocalSubstAgree Δl ρ η := by exact LocalSubstAgree.empty _ _) :
      Clause.substList σ h ρ = Clause.substList τ h η := by
    match hc with
    | .one _ _ _ hb =>
      have hs' := (hs.shiftEnv 1).up [none, some (E.shift 1 0)]
      simp only [List.length_cons, List.length_nil, List.cons_append, List.nil_append] at hs'
      simp only [Clause.substList, HasTypeCQ.subst_congr (ρ := upLocalSubst 2 ρ) (η := upLocalSubst 2 η) hb hs']

end

/-- i 番以外で一致する置換は、環境の none の位置での値によらない。 -/
theorem SubstAgree.of_none {Γ : List (Option Ty)} {i : Nat} {σ τ : Nat → Val}
    (hi : Γ[i]? = some none) (h : ∀ j, j ≠ i → σ j = τ j) : SubstAgree Γ σ τ := by
  intro j a hj
  apply h j
  intro heq
  subst j
  rw [hi] at hj
  cases hj

/-- 任意の位置での置換不変性。Fail 節では i=0 に適用する。 -/
def IrrelevantSlot (m : Comp) (i : Nat) : Prop :=
  ∀ σ τ : Nat → Val, (∀ j, j ≠ i → σ j = τ j) → m.subst σ = m.subst τ

theorem HasTypeCQ.irrelevant_slot {Δl : LocalCtx} {P B Ψ C Γ R m a e i}
    (h : HasTypeCQ P B Ψ Q C Γ R m a e Δl) (hi : Γ[i]? = some none) : IrrelevantSlot m i :=
  fun _ _ hs => h.subst_congr (SubstAgree.of_none hi hs) (LocalSubstAgree.refl _ _)

end Benitoite.Release
