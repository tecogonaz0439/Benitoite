import Benitoite.Release.Lemmas.Preservation
import Benitoite.Release.RangeInst

/-!
# 保存の定理の補助の補題（契約名を持つコア）

保存の定理の本体と辞書の型付けで使い、契約名の綴り・順序と整形式を保持する
（設計書 01-12「型付け規則」「確かめる性質」）。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

mutual
  /-- エフェクト変数の範囲の条件を外す。 -/
  theorem Val.VarsIn.toTrue {depth n : Nat} {pe : Nat → Prop} : (v : Val) → Val.VarsIn n pe v depth →
      Val.VarsIn n (fun _ => True) v depth
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ _ es, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Eff.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) es h.2⟩
    | .prim _ _ es _, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Eff.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) es h.2⟩
    | .lam _ _ body, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨h.1, Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.2.1, Comp.VarsIn.toTrue body h.2.2⟩
    | .con _ _ args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Val.VarsInList.toTrue args h.2⟩
    | .list elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.toTrue elems h
    | .op _ _, h => by
        simp only [Val.VarsIn] at h ⊢; exact Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h
    | .raise T E, h => by
        exact ⟨Ty.VarsIn.mono (Nat.le_refl _) (fun _ _ => trivial) T h.1,
          Ty.VarsIn.mono (Nat.le_refl _) (fun _ _ => trivial) E h.2⟩
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Val.VarsInList.toTrue ks h.1, Val.VarsInList.toTrue vs h.2⟩
    | .setV elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.toTrue elems h
    | .bytesV _, _ => by simp [Val.VarsIn]
    | .checked _, _ => by simp [Val.VarsIn]
    | .checkedRequest _ _, _ => by simp [Val.VarsIn]
    | .dict _ _ args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) _ h.1, Val.VarsInList.toTrue args h.2⟩
    | .super v _, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsIn.toTrue v h

  theorem Val.VarsInList.toTrue {depth n : Nat} {pe : Nat → Prop} : (vs : List Val) →
      Val.VarsInList n pe vs depth → Val.VarsInList n (fun _ => True) vs depth
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h ⊢; exact ⟨Val.VarsIn.toTrue v h.1, Val.VarsInList.toTrue vs h.2⟩

  theorem Comp.VarsIn.toTrue {depth n : Nat} {pe : Nat → Prop} : (m : Comp) → Comp.VarsIn n pe m depth →
      Comp.VarsIn n (fun _ => True) m depth
    | .builderLet k body, h => by
        refine ⟨?_, Comp.VarsIn.toTrue body h.2⟩
        cases k with
        | list a => exact Ty.VarsIn.mono (Nat.le_refl _) (fun _ _ => trivial) a h.1
        | string | bytes => trivial
    | .builderOp k op ref args, h => by
        refine ⟨?_, h.2.1, Val.VarsInList.toTrue args h.2.2⟩
        cases k with
        | list a => exact Ty.VarsIn.mono (Nat.le_refl _) (fun _ _ => trivial) a h.1
        | string | bytes => trivial
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
          Eff.VarsInList.mono (Nat.le_refl _) (fun _ _ => trivial) es h.2.2.1, Val.VarsInList.toTrue args h.2.2.2⟩

  theorem Arm.VarsInList.toTrue {depth n : Nat} {pe : Nat → Prop} : (arms : List Arm) →
      Arm.VarsInList n pe arms depth → Arm.VarsInList n (fun _ => True) arms depth
    | [], _ => trivial
    | .mk alts none m :: arms, h => by
        simp only [Arm.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.toTrue m h.1, Arm.VarsInList.toTrue arms h.2⟩
    | .mk alts (some g) m :: arms, h => by
        simp only [Arm.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.toTrue g h.1,
          Comp.VarsIn.toTrue m h.2.1, Arm.VarsInList.toTrue arms h.2.2⟩

  theorem Clause.VarsInList.toTrue {depth n : Nat} {pe : Nat → Prop} : (hs : List Clause) →
      Clause.VarsInList n pe hs depth → Clause.VarsInList n (fun _ => True) hs depth
    | [], _ => trivial
    | .mk _ _ _ m :: cs, h => by
        simp only [Clause.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.toTrue m h.1, Clause.VarsInList.toTrue cs h.2⟩
    | .fail E m :: cs, h => by
        exact ⟨Ty.VarsIn.mono (Nat.le_refl _) (fun _ _ => trivial) E h.1,
          Comp.VarsIn.toTrue m h.2.1, Clause.VarsInList.toTrue cs h.2.2⟩
end

/-- 閉じた値の並びの型は、型の変数を含まない。 -/
theorem HasTypeVsQ.wf_all (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {Ψ} (hΨ : StoreTy.WF Ψ) :
    {ws : List Val} → {as : List Ty} → HasTypeVs P B Ψ [] [] ws as →
    Val.VarsInList 0 (fun _ => True) ws → ∀ x ∈ as, Ty.WF 0 0 x
  | _, _, .nil, _, x, hx => by simp at hx
  | _, _, .cons hv hvs, hc, x, hx => by
      rcases List.mem_cons.mp hx with rfl | hx
      · exact HasTypeVQ.wf hwf hb hv (envWF_nil 0) hΨ hc.1
      · exact HasTypeVsQ.wf_all hwf hb hΨ hvs hc.2 x hx

theorem envWF_single {a : Ty} (h : Ty.WF 0 0 a) : EnvWF 0 [some a] := by
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

theorem stE_ret {Eb Ψ R a a' b ε v k σ} (ha : Ty.WF 0 0 a) (hσ : StoreOk P B Ψ σ) (hv : HasTypeV P B Ψ [] [] v a')
    (hle : Ty.Le a' a) (hk : ContTy P B Ψ R ε k a b Eb none) (hvc : Val.VarsIn 0 (fun _ => True) v)
    (hkc : Cont.Closed k) (hσc : Store.Closed σ) : StateTyE P B Eb (.run (.ret v) k σ) :=
  ⟨Ψ, R, a, b, ε, Eff.empty, hσ, .C_Sub (.C_Return hv) hle (Eff.Covers.refl _) ha, Eff.empty_sub _, hk, hvc,
    hkc, hσc⟩

/-- `drop κ` の枠で、κ の継続の解放の枠を実行する（E-DropRel など）。 -/
theorem dropRel_common (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P) {Ψ σ κ k' R ε k a b Eb}
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

theorem store_prim_inv (hb : B.CoreAssumptions P) {Ψ R b ts es rs ws a ε1 s} (hsig : B.sig b = some s)
    (hkd : s.kind ≠ .pure ∧ s.kind ≠ .io ∧ s.kind ≠ .exit)
    (hm : HasTypeC P B Ψ [] [] R (.app (.prim b ts es rs) ws) a ε1) :
    ∃ t, ts = [t] ∧ es = [] ∧ HasTypeVs P B Ψ [] [] ws (s.params.map (Ty.subst [t] [])) ∧
      Ty.Le (Ty.subst [t] [] s.ret) a ∧ Eff.Covers ε1 s.eff := by
  obtain ⟨s', hs', htl, hel, _, hargs, hle, hsub, hrs⟩ := inv_prim_app hm
  rw [hsig] at hs'; cases hs'
  have hsh := hb.store_shape b s hsig
  -- 可変のセルと明示遅延の項目は範囲の変数を持たないので、範囲の列は空で、具体化は署名を変えない。
  have h0 : s.nranges = 0 := by
    unfold PrimSig.StoreShape at hsh
    simp only [PrimSig.nranges]
    cases e : s.kind <;> rw [e] at hsh hkd
    all_goals first
      | exact absurd rfl hkd.1 | exact absurd rfl hkd.2.1 | exact absurd rfl hkd.2.2
      | simp [hsh.2.2.2.2.2.2]
  obtain rfl := (Builtins.rangeAdmissible_iff_nil h0 rs).mp hrs
  rw [PrimSig.inst_nil_of_scoped (hb.sig_scoped _ _ hsig) h0] at hargs hle hsub
  have h1 : s.ntys = 1 ∧ s.neffs = 0 := by
    unfold PrimSig.StoreShape at hsh
    cases e : s.kind <;> rw [e] at hsh hkd
    all_goals first
      | exact absurd rfl hkd.1 | exact absurd rfl hkd.2.1 | exact absurd rfl hkd.2.2
      | exact ⟨hsh.2.1, hsh.2.2.1⟩
  obtain ⟨t, rfl⟩ := single_of_length (htl.trans h1.1)
  have : es = [] := List.eq_nil_of_length_eq_zero (hel.trans h1.2)
  subst this
  have hid : Eff.substAt 0 [t] [] s.eff = s.eff := by
    unfold PrimSig.StoreShape at hsh
    cases hk : s.kind <;> rw [hk] at hsh hkd
    all_goals first
      | exact absurd rfl hkd.1
      | exact absurd rfl hkd.2.1
      | exact absurd rfl hkd.2.2
      | (rw [hsh.2.2.2.2.2.1]; first | exact Eff.substAt_single _ _ _ _ | exact Eff.substAt_empty _ _ _)
  rw [hid] at hsub
  exact ⟨t, rfl, rfl, hargs, hle, hsub⟩

theorem ClosedArgs.single {t : Ty} {es : List Eff} {rs} (h : Val.VarsIn 0 (fun _ => True) (.prim b [t] es rs)) :
    ClosedArgs [t] :=
  closedArgs_of (by simp only [Val.VarsIn] at h; exact h.1)

/-- `Reference.update` の遷移した先の計算の型付け。 -/
theorem refUpdate_typed (hb : B.CoreAssumptions P) {Ψ R l t f}
    (hl : Ψ l = some (.ref t)) (hf : HasTypeV P B Ψ [] [] f (.fn ["value"] [t] t Eff.empty)) (ht : ClosedArgs [t]) :
    HasTypeC P B Ψ [] [] R (.letIn (.app (.prim B.refGet [t] [] []) [.loc l])
      (.letIn (.app (f.rename (· + 1)) [.var 0]) (.app (.prim B.refSet [t] [] []) [.loc l, .var 0])))
      (.base .unit) (Eff.single stateEff) := by
  obtain ⟨sg, hsg, hkg⟩ := hb.ref_get
  obtain ⟨ss, hss, hks⟩ := hb.ref_set
  have hshg := hb.store_shape _ _ hsg
  unfold PrimSig.StoreShape at hshg; rw [hkg] at hshg
  obtain ⟨hgn, hg1, hg2, hg3, hg4, hg5, hg6⟩ := hshg
  have hshs := hb.store_shape _ _ hss
  unfold PrimSig.StoreShape at hshs; rw [hks] at hshs
  obtain ⟨hsn, hs1, hs2, hs3, hs4, hs5, hs6⟩ := hshs
  have htn : ∀ b' t' ε', t ≠ .cont b' t' ε' := (ht t (by simp)).2
  refine .C_Let (a := t) ?_ (.C_Let (a := t) ?_ ?_)
  · have h0 : sg.nranges = 0 := by simp [PrimSig.nranges, hg6]
    have hinst := PrimSig.inst_nil_of_scoped (hb.sig_scoped _ _ hsg) h0
    have hpa := PrimitiveAdmissible.of_noRows (Q := Qempty) (hb.sig_scoped _ _ hsg) hg2 (by simp [hg1])
      (hb.store_admits _ _ [] [t] hsg (by rw [hkg]; decide) (by rw [hkg]; decide) (by rw [hkg]; decide)
        (by simp [hg1])) ht
    have hv := HasTypeVQ.V_Prim (Q := Qempty) (P := P) (Ψ := Ψ) (C := []) (Γ := []) (ts := [t]) (es := []) (rs := [])
      hsg ((Builtins.rangeAdmissible_iff_nil h0 []).mpr rfl) (by rw [hinst]; exact (hb.sig_scoped _ _ hsg).1)
      (by rw [hinst]; exact hpa)
    rw [hinst, fnTy_eq, hg3, hg4, hg5] at hv
    simp only [List.map_cons, List.map_nil, Ty.subst, Ty.substAt] at hv
    simp [Ty.shift_of_wf (c := 0) 0 t (ht t (by simp)).1, Eff.substAt_single] at hv
    exact .C_App hv (.cons (.V_LocRef hl) .nil)
  · have hf' := hf.rename (RenOk.shift [some t] [])
    exact .C_Eff (.C_App hf' (.cons (.V_Var (i := 0) (by simp) htn) .nil)) (Eff.covers_empty _)
  · have h0 : ss.nranges = 0 := by simp [PrimSig.nranges, hs6]
    have hinst := PrimSig.inst_nil_of_scoped (hb.sig_scoped _ _ hss) h0
    have hpa := PrimitiveAdmissible.of_noRows (Q := Qempty) (hb.sig_scoped _ _ hss) hs2 (by simp [hs1])
      (hb.store_admits _ _ [] [t] hss (by rw [hks]; decide) (by rw [hks]; decide) (by rw [hks]; decide)
        (by simp [hs1])) ht
    have hv := HasTypeVQ.V_Prim (Q := Qempty) (P := P) (Ψ := Ψ) (C := []) (Γ := [some t, some t]) (ts := [t]) (es := [])
      (rs := []) hss ((Builtins.rangeAdmissible_iff_nil h0 []).mpr rfl) (by rw [hinst]; exact (hb.sig_scoped _ _ hss).1)
      (by rw [hinst]; exact hpa)
    rw [hinst, fnTy_eq, hs3, hs4, hs5] at hv
    simp only [List.map_cons, List.map_nil, Ty.subst, Ty.substAt] at hv
    simp [Ty.shift_of_wf (c := 0) 0 t (ht t (by simp)).1, Eff.substAt_single] at hv
    exact .C_App hv (.cons (.V_LocRef hl) (.cons (.V_Var (by simp) htn) .nil))

end Benitoite.Release
