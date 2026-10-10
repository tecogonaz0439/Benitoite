import Benitoite.Release.Lemmas.Preservation

/-!
# 保存の定理の補助の補題（段階 B）

保存の定理の本体（`PresMain.lean`）と、辞書とメソッドの呼び出しの補題（`Dict.lean`）が使う補題。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 補助の補題 -/

mutual
  /-- エフェクト変数の範囲の条件を外す。 -/
  theorem Val.VarsIn.toTrue {n : Nat} {pe : Nat → Prop} : (v : Val) → Val.VarsIn n pe v →
      Val.VarsIn n (fun _ => True) v
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ _ es, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Eff.RhosInList.true es⟩
    | .prim _ _ es, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Eff.RhosInList.true es⟩
    | .lam _ body, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Comp.VarsIn.toTrue body h.2⟩
    | .con _ _ args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Val.VarsInList.toTrue args h.2⟩
    | .list elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.toTrue elems h
    | .op _ _, h => by
        simp only [Val.VarsIn] at h ⊢; exact Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Val.VarsInList.toTrue ks h.1, Val.VarsInList.toTrue vs h.2⟩
    | .setV elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.toTrue elems h
    | .bytesV _, _ => by simp [Val.VarsIn]
    | .dict _ _ args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Val.VarsInList.toTrue args h.2⟩
    | .super v _, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsIn.toTrue v h

  theorem Val.VarsInList.toTrue {n : Nat} {pe : Nat → Prop} : (vs : List Val) →
      Val.VarsInList n pe vs → Val.VarsInList n (fun _ => True) vs
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h ⊢; exact ⟨Val.VarsIn.toTrue v h.1, Val.VarsInList.toTrue vs h.2⟩

  theorem Comp.VarsIn.toTrue {n : Nat} {pe : Nat → Prop} : (m : Comp) → Comp.VarsIn n pe m →
      Comp.VarsIn n (fun _ => True) m
    | .ret v, h => by simp only [Comp.VarsIn] at h ⊢; exact Val.VarsIn.toTrue v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Comp.VarsIn.toTrue m h.1, Comp.VarsIn.toTrue k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.toTrue f h.1, Val.VarsInList.toTrue args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h ⊢
        exact ⟨Val.VarsIn.toTrue v h.1, Comp.VarsIn.toTrue m h.2.1, Comp.VarsIn.toTrue k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.toTrue v h.1, Arm.VarsInList.toTrue arms h.2⟩
    | .lazyC m, h => by simp only [Comp.VarsIn] at h ⊢; exact Comp.VarsIn.toTrue m h
    | .escape v, h => by simp only [Comp.VarsIn] at h ⊢; exact Val.VarsIn.toTrue v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.toTrue v h.1, Comp.VarsIn.toTrue m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Comp.VarsIn.toTrue m h.1, Clause.VarsInList.toTrue hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.toTrue k h.1, Val.VarsIn.toTrue v h.2⟩
    | .meth d _ _ es args, h => by
        simp only [Comp.VarsIn] at h ⊢
        exact ⟨Val.VarsIn.toTrue d h.1, Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.2.1,
          Eff.RhosInList.true es, Val.VarsInList.toTrue args h.2.2.2⟩

  theorem Arm.VarsInList.toTrue {n : Nat} {pe : Nat → Prop} : (arms : List Arm) →
      Arm.VarsInList n pe arms → Arm.VarsInList n (fun _ => True) arms
    | [], _ => trivial
    | .mk alts none m :: arms, h => by
        simp only [Arm.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.toTrue m h.1, Arm.VarsInList.toTrue arms h.2⟩
    | .mk alts (some g) m :: arms, h => by
        simp only [Arm.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.toTrue g h.1,
          Comp.VarsIn.toTrue m h.2.1, Arm.VarsInList.toTrue arms h.2.2⟩

  theorem Clause.VarsInList.toTrue {n : Nat} {pe : Nat → Prop} : (hs : List Clause) →
      Clause.VarsInList n pe hs → Clause.VarsInList n (fun _ => True) hs
    | [], _ => trivial
    | .mk _ _ _ m :: cs, h => by
        simp only [Clause.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.toTrue m h.1, Clause.VarsInList.toTrue cs h.2⟩
end

/-- 閉じた値の並びの型は、型の変数を含まない。 -/
theorem HasTypeVs.wf_all (hwf : P.WellFormed) (hb : B.Assumptions P) {Ψ} (hΨ : StoreTy.WF Ψ) :
    {ws : List Val} → {as : List Ty} → HasTypeVs P B Ψ [] [] ws as →
    Val.VarsInList 0 (fun _ => True) ws → ∀ x ∈ as, Ty.WF 0 x
  | _, _, .nil, _, x, hx => by simp at hx
  | _, _, .cons hv hvs, hc, x, hx => by
      rcases List.mem_cons.mp hx with rfl | hx
      · exact HasTypeV.wf hwf hb hv (envWF_nil 0) hΨ hc.1
      · exact HasTypeVs.wf_all hwf hb hΨ hvs hc.2 x hx

theorem envWF_single {a : Ty} (h : Ty.WF 0 a) : EnvWF 0 [some a] := by
  intro i x hx
  cases i with
  | zero => simp at hx; subst hx; exact h
  | succ i => simp at hx

theorem StoreOk.none_of {Ψ σ l} (h : StoreOk P B Ψ σ) (hl : σ l = none) : Ψ l = none := by
  cases h' : Ψ l with
  | none => rfl
  | some x => exact absurd hl (h.2.2.1 _ _ h')

/-- 場所の型を変えずに、中身を置き直す。 -/
theorem StoreOk.set_same {Ψ σ l c x} (h : StoreOk P B Ψ σ) (hl : Ψ l = some x) (hc : CellOk P B Ψ l c) :
    StoreOk P B Ψ (σ.set l c) := by
  have e : Ψ.set l x = Ψ := by
    funext l'
    unfold StoreTy.set
    split
    · rename_i e; subst e; exact hl.symm
    · rfl
  have := h.set (h.wf l x hl) (Or.inr hl) (by rw [e]; exact hc)
  rwa [e] at this

theorem stE_error {Eb rs Ψ R a b ε k σ} (hσ : StoreOk P B Ψ σ) (hk : ContTy P B Ψ R ε k a b Eb none)
    (hkc : Cont.Closed k) (hσc : Store.Closed σ) : StateTyE P B Eb (.error rs k σ) :=
  ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩

theorem stE_exit {Eb n rs Ψ R a b ε k σ} (hσ : StoreOk P B Ψ σ) (hk : ContTy P B Ψ R ε k a b Eb none)
    (hkc : Cont.Closed k) (hσc : Store.Closed σ) : StateTyE P B Eb (.exit n rs k σ) :=
  ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩

theorem stE_ret {Eb Ψ R a a' b ε v k σ} (hσ : StoreOk P B Ψ σ) (hv : HasTypeV P B Ψ [] [] v a')
    (hle : Ty.Le a' a) (hk : ContTy P B Ψ R ε k a b Eb none) (hvc : Val.VarsIn 0 (fun _ => True) v)
    (hkc : Cont.Closed k) (hσc : Store.Closed σ) : StateTyE P B Eb (.run (.ret v) k σ) :=
  ⟨Ψ, R, a, b, ε, Eff.empty, hσ, .C_Sub (.C_Return hv) hle (Eff.Sub.refl _), Eff.empty_sub _, hk, hvc,
    hkc, hσc⟩

/-- `drop κ` の枠で、κ の継続の解放の枠を実行する（E-DropRel など）。 -/
theorem dropRel_common (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {Ψ σ κ k' R ε k a b Eb}
    (hσ : StoreOk P B Ψ σ) (hσκ : σ κ = some (.cont k')) (hk : ContTy P B Ψ R ε (.drop κ :: k) a b Eb none)
    (hkc : Cont.Closed (.drop κ :: k)) (hσc : Store.Closed σ) :
    StoreOk P B Ψ (σ.set κ .used) ∧ ContTy P B Ψ R ε (releases k' ++ k) a b Eb none ∧
      Cont.Closed (releases k' ++ k) ∧ Store.Closed (σ.set κ .used) := by
  obtain ⟨b', t', ε', R', hΨκ, hcond, hk'⟩ := hk.inv_drop
  obtain ⟨b2, t2, ε2, r2, hΨκ2, _, R'', ε'', hcell⟩ := hσ.2.2.2 κ _ hσκ
  rw [hΨκ] at hΨκ2
  simp only [Option.some.injEq, LocTy.cont.injEq] at hΨκ2
  obtain ⟨rfl, rfl, rfl, rfl⟩ := hΨκ2
  have hkc' : Cont.Closed k' := hσc κ _ hσκ
  exact ⟨hσ.set_same hΨκ ⟨_, _, _, _, hΨκ⟩, ContTy.drop_releases hdecl hb hk' hcond hcell,
    Cont.Closed.append.mpr ⟨hkc'.releases, (Cont.Closed.cons.mp hkc).2⟩, hσc.set trivial⟩

/-! ## 可変のセルと明示遅延の組み込みの関数 -/

theorem store_prim_inv (hb : B.Assumptions P) {Ψ R b ts es ws a ε1 s} (hsig : B.sig b = some s)
    (hkd : s.kind ≠ .pure ∧ s.kind ≠ .io ∧ s.kind ≠ .exit)
    (hm : HasTypeC P B Ψ [] [] R (.app (.prim b ts es) ws) a ε1) :
    ∃ t, ts = [t] ∧ es = [] ∧ HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst [t] [])) ∧
      Ty.Le (Ty.subst [t] [] s.ret) a ∧ Eff.Sub s.eff ε1 := by
  obtain ⟨s', hs', htl, hel, _, hargs, hle, hsub⟩ := inv_prim_app hm
  rw [hsig] at hs'; cases hs'
  have hsh := hb.store_shape b s hsig
  have h1 : s.ntys = 1 ∧ s.neffs = 0 := by
    unfold PrimSig.StoreShape at hsh
    cases e : s.kind <;> rw [e] at hsh hkd
    all_goals first
      | exact absurd rfl hkd.1 | exact absurd rfl hkd.2.1 | exact absurd rfl hkd.2.2
      | exact ⟨hsh.1, hsh.2.1⟩
  obtain ⟨t, rfl⟩ := single_of_length (htl.trans h1.1)
  have : es = [] := List.eq_nil_of_length_eq_zero (hel.trans h1.2)
  subst this
  rw [Eff.substRho_nil] at hsub
  exact ⟨t, rfl, rfl, hargs, hle, hsub⟩

theorem ClosedArgs.single {t : Ty} {es : List Eff} (h : Val.VarsIn 0 (fun _ => True) (.prim b [t] es)) :
    ClosedArgs [t] :=
  closedArgs_of (by simp only [Val.VarsIn] at h; exact h.1)

/-- `Reference.update` の遷移した先の計算の型付け。 -/
theorem refUpdate_typed (hb : B.Assumptions P) {Ψ R l t f}
    (hl : Ψ l = some (.ref t)) (hf : HasTypeV P B Ψ [] [] f (.fn [t] t Eff.empty)) (ht : ClosedArgs [t]) :
    HasTypeC P B Ψ [] [] R (.letIn (.app (.prim B.refGet [t] []) [.loc l])
      (.letIn (.app (f.rename (· + 1)) [.var 0]) (.app (.prim B.refSet [t] []) [.loc l, .var 0])))
      (.base .unit) (Eff.single stateEff) := by
  obtain ⟨sg, hsg, hkg⟩ := hb.ref_get
  obtain ⟨ss, hss, hks⟩ := hb.ref_set
  have hshg := hb.store_shape _ _ hsg
  unfold PrimSig.StoreShape at hshg; rw [hkg] at hshg
  obtain ⟨hg1, hg2, hg3, hg4, hg5⟩ := hshg
  have hshs := hb.store_shape _ _ hss
  unfold PrimSig.StoreShape at hshs; rw [hks] at hshs
  obtain ⟨hs1, hs2, hs3, hs4, hs5⟩ := hshs
  have htn : ∀ b' t' ε', t ≠ .cont b' t' ε' := (ht t (by simp)).2
  refine .C_Let (a := t) ?_ (.C_Let (a := t) ?_ ?_)
  · have hv := HasTypeV.V_Prim (P := P) (Ψ := Ψ) (C := []) (Γ := []) (ts := [t]) (es := []) hsg
      (by simp [hg1]) (by simp [hg2])
      (hb.store_admits _ _ [] [t] hsg (by rw [hkg]; decide) (by rw [hkg]; decide) (by rw [hkg]; decide)
        (by simp [hg1]))
    rw [fnTy_eq, hg3, hg4, hg5] at hv
    simp only [List.map_cons, List.map_nil, Ty.subst, Ty.substAt, Eff.substRho_nil] at hv
    simp [Ty.shift_zero] at hv
    exact .C_App hv (.cons (.V_LocRef hl) .nil)
  · have hf' := hf.rename (RenOk.shift [some t] [])
    exact .C_Sub (.C_App hf' (.cons (.V_Var (by simp) htn) .nil)) (Ty.Le.refl _) (Eff.empty_sub _)
  · have hv := HasTypeV.V_Prim (P := P) (Ψ := Ψ) (C := []) (Γ := [some t, some t]) (ts := [t]) (es := []) hss
      (by simp [hs1]) (by simp [hs2])
      (hb.store_admits _ _ [] [t] hss (by rw [hks]; decide) (by rw [hks]; decide) (by rw [hks]; decide)
        (by simp [hs1]))
    rw [fnTy_eq, hs3, hs4, hs5] at hv
    simp only [List.map_cons, List.map_nil, Ty.subst, Ty.substAt, Eff.substRho_nil] at hv
    simp [Ty.shift_zero] at hv
    exact .C_App hv (.cons (.V_LocRef hl) (.cons (.V_Var (by simp) htn) .nil))

end Benitoite.Release
