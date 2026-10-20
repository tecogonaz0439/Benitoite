import Benitoite.Release.Lemmas.PresBase

/-!
# 辞書とメソッドの呼び出しの補題（契約名を持つコア）

E-Meth は、実装のメソッドの本体に、メソッドの型引数 S̄ と実装の型引数 T̄ を並べた `S̄ ++ T̄` の置き換えを施す。
本体の型は、D-Impl が型クラスの引数 P を実装の対象 τ に置き換えた型（`ImplDecl.methTy`）なので、置き換えの後の
型は、C-Meth の `θ = [τ[T̄/β̄]/P, S̄/γ̄, Ē/ρ̄]` を施した型と等しい。E-Super は、実装の定義の上位の型クラスの辞書に
`[T̄/β̄][V̄/d̄]` を施す。

契約名を含む型のまま補題を示す（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 型の置き換えの合成 -/

theorem Eff.substRho_of_noRho (es : List Eff) {e : Eff}
    (h : Eff.RhosIn (fun _ => False) e) (hc : Eff.Canonical e) : Eff.substRho es e = e := by
  rw [Eff.substRho_eq_bind]
  have he : Eff.bind (SubstEnv.rowsOnly es) e = Eff.bind SubstEnv.identity e := by
    apply Eff.bind_congr_rows (SubstEnv.rowsOnly es) SubstEnv.identity rfl
    exact Eff.RowsIn.mono (fun _ hi => hi.elim) e h
  rw [he, Eff.bind_identity, hc]

/-- 移動してから前置した引数列で置き換えると、元の引数列での代入になる。 -/
theorem Ty.shift_subst_append {ts ss : List Ty} {g : Nat} (es : List Eff) (hss : ss.length = g)
    (u : Ty) (h : Ty.VarsIn ts.length (fun _ => False) u) :
    (u.shift g 0).substAt 0 (ss ++ ts) es = u.substAt 0 ts [] := by
  rw [Ty.shift_eq_bind, Ty.substAt_eq_bind, Ty.bind_comp, Ty.substAt_eq_bind]
  apply Ty.bind_congr_scoped (n := ts.length)
  · intro i hi
    have hidx : i + g < (ss ++ ts).length := by simp; omega
    change (Ty.bind (SubstEnv.at 0 (ss ++ ts) es) (.tvar (i + g))).norm = _
    rw [← Ty.substAt_eq_bind]
    simp only [Ty.substAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, hidx,
      SubstEnv.at, hi, Ty.shift_zero_norm, Ty.rawShift_zero, Ty.norm_idem]
    rw [List.getElem?_append_right (by omega)]
    simp [hss, List.getElem?_eq_getElem hi]
  · exact Ty.WF.raw u (Ty.VarsIn.wf u h)
  · exact Ty.RowsIn.mono (fun _ hi => hi.elim) u (Ty.VarsIn.rows u h)

theorem Ty.shiftList_subst_append {ts ss : List Ty} {g : Nat} (es : List Eff) (hss : ss.length = g)
    (as : List Ty) (h : Ty.VarsInList ts.length (fun _ => False) as) :
    as.map ((Ty.substAt 0 (ss ++ ts) es) ∘ (Ty.shift g 0)) = as.map (Ty.substAt 0 ts []) :=
  List.map_congr_left (fun a ha => Ty.shift_subst_append es hss a (Ty.VarsInList.iff.mp h a ha))

/-- 型クラスの引数の代入と、呼び出し時の同時代入の合成。 -/
theorem Ty.methTy_subst {ts ss : List Ty} {g : Nat} {pe : Nat → Prop} (u : Ty) (es : List Eff)
    (hss : ss.length = g) (t : Ty) (h : Ty.VarsIn (g + 1) pe t) :
    (t.substAt g [u] []).substAt 0 (ss ++ ts) es =
      t.substAt 0 (ss ++ [(u.shift g 0).substAt 0 (ss ++ ts) es]) es := by
  let v := (u.shift g 0).substAt 0 (ss ++ ts) es
  let θ := SubstEnv.at g [u] []
  let φ := SubstEnv.at 0 (ss ++ ts) es
  let ψ := SubstEnv.at 0 (ss ++ [v]) es
  change (t.substAt g [u] []).substAt 0 (ss ++ ts) es = t.substAt 0 (ss ++ [v]) es
  rw [Ty.substAt_eq_bind, Ty.substAt_eq_bind, Ty.substAt_eq_bind]
  change Ty.bind φ (Ty.bind θ t) = Ty.bind ψ t
  rw [Ty.bind_comp]
  apply Ty.bind_congr_scoped_norm (n := g + 1)
  · intro i hi
    change (Ty.bind φ (θ.types i)).norm = (ψ.types i).norm
    by_cases hig : i < g
    · have hidx : i < (ss ++ ts).length := by simp; omega
      have hidx' : i < (ss ++ [v]).length := by simp; omega
      change (Ty.bind φ (if i < g then Ty.tvar i else _)).norm = _
      simp only [hig, ↓reduceIte]
      change (φ.types i).norm.norm = (ψ.types i).norm
      simp only [φ, ψ, SubstEnv.at, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, hidx,
        hidx', Ty.rawShift_zero, Ty.norm_idem]
      rw [List.getElem?_append_left (by omega), List.getElem?_append_left (by omega)]
    · have he : i = g := by omega
      subst i
      have hθ : θ.types g = u.rawShift g 0 := by simp [θ, SubstEnv.at]
      rw [hθ]
      have hidx : g < (ss ++ [v]).length := by simp; omega
      simp only [ψ, SubstEnv.at, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero, hidx, Ty.rawShift_zero]
      rw [List.getElem?_append_right (by omega)]
      simp only [hss, Nat.sub_self, List.getElem?_cons_zero, Option.getD_some]
      rw [← Ty.bind_norm φ (u.rawShift g 0), ← Ty.shift_eq_norm_rawShift]
      dsimp only [v]
      rw [Ty.substAt_eq_bind]
  · exact Ty.WF.raw t (Ty.VarsIn.wf t h)
  · apply Ty.RowsIn.mono (h := Ty.VarsIn.rows t h)
    intro i _
    rw [Eff.rowImage_compose]
    change Eff.norm (Eff.bind φ (Eff.row i)) = _
    rw [Eff.bind_row]
    simp only [φ, ψ, SubstEnv.at, List.map_id,
      show Eff.rawShift 0 0 = id from funext (Eff.rawShift_zero 0), Eff.norm_idem]

theorem Ty.methTyList_subst {ts ss : List Ty} {g : Nat} {pe : Nat → Prop} (u : Ty) (es : List Eff)
    (hss : ss.length = g) (as : List Ty) (h : Ty.VarsInList (g + 1) pe as) :
    as.map ((Ty.substAt 0 (ss ++ ts) es) ∘ (Ty.substAt g [u] [])) =
      as.map (Ty.substAt 0 (ss ++ [(u.shift g 0).substAt 0 (ss ++ ts) es]) es) :=
  List.map_congr_left (fun a ha => Ty.methTy_subst u es hss a (Ty.VarsInList.iff.mp h a ha))

/-- E-Meth の後のメソッドの型。 -/
theorem ImplDecl.methTy_subst {id : ImplDecl} (hsc : id.Scoped P) {ms : MethSig} (hms : ms.Scoped)
    {ts ss : List Ty} {es : List Eff} (hts : ts.length = id.tparams.length) (hss : ss.length = ms.tparams.length) :
    (ms.params.map (id.methTy ms)).map (Ty.subst (ss ++ ts) es) =
      ms.params.map (Ty.subst (ss ++ [id.target.subst ts []]) es) ∧
    (id.methTy ms ms.ret).subst (ss ++ ts) es = ms.ret.subst (ss ++ [id.target.subst ts []]) es := by
  have ht : (id.target.shift ms.tparams.length 0).substAt 0 (ss ++ ts) es = id.target.subst ts [] := by
    rw [Ty.shift_subst_append es hss]; rfl
    rw [hts]; exact hsc.2.1
  have e : id.methTy ms = Ty.substAt ms.tparams.length [id.target] [] := rfl
  simp only [Ty.subst] at ht ⊢
  rw [e]
  constructor
  · have := Ty.methTyList_subst (ts := ts) id.target es hss ms.params hms.2.1
    rw [List.map_map, this, ht]
  · have := Ty.methTy_subst (ts := ts) id.target es hss ms.ret hms.2.2.1
    rw [this, ht]

/-- メソッドの効果に含まれる型にも、型クラスの引数の同じ具体化を行う。 -/
theorem Eff.methTy_subst {ts ss : List Ty} {g : Nat} {pe : Nat → Prop} (u : Ty) (es : List Eff)
    (hss : ss.length = g) (e : Eff) (h : Eff.VarsIn (g + 1) pe e) :
    Eff.substAt 0 (ss ++ ts) es (Eff.substAt g [u] [] e) =
      Eff.substAt 0 (ss ++ [(u.shift g 0).substAt 0 (ss ++ ts) es]) es e := by
  have hw : Ty.VarsIn (g + 1) pe (.fn [] [] (.base .unit) (Eff.norm e)) :=
    ⟨⟨rfl, by simp⟩, trivial, trivial, Eff.norm_VarsIn e h, Eff.norm_idem e⟩
  have ht := Ty.methTy_subst (ts := ts) u es hss _ hw
  simp only [Ty.substAt, Ty.substTysAt] at ht
  exact (by simpa only [Eff.substAt_norm] using (Ty.fn.inj ht).2.2.2)

theorem ImplDecl.methEff_subst {id : ImplDecl} (hsc : id.Scoped P) {ms : MethSig} (hms : ms.Scoped)
    {ts ss : List Ty} {es : List Eff} (hts : ts.length = id.tparams.length) (hss : ss.length = ms.tparams.length) :
    Eff.substAt 0 (ss ++ ts) es (Eff.substAt ms.tparams.length [id.target] [] ms.eff) =
      Eff.substAt 0 (ss ++ [id.target.subst ts []]) es ms.eff := by
  have ht : (id.target.shift ms.tparams.length 0).substAt 0 (ss ++ ts) es = id.target.subst ts [] := by
    rw [Ty.shift_subst_append es hss]; rfl
    rw [hts]; exact hsc.2.1
  rw [Eff.methTy_subst (ts := ts) id.target es hss ms.eff hms.2.2.2, ht]

/-- E-Meth の後の辞書の引数の型。 -/
theorem ImplDecl.dictTys_subst {id : ImplDecl} (hsc : id.Scoped P) {ts ss : List Ty} {g : Nat}
    (es : List Eff) (hts : ts.length = id.tparams.length) (hss : ss.length = g) :
    (id.dictTys.map (Ty.shift g 0)).map (Ty.subst (ss ++ ts) es) = id.dictTys.map (Ty.subst ts []) := by
  have := Ty.shiftList_subst_append (ts := ts) es hss id.dictTys (by rw [hts]; exact ImplDecl.dictTys_varsIn hsc _)
  simp only [Ty.subst, List.map_map]
  exact this

/-! ## 制約 -/

theorem SatAll.append {C : List TParam} {ss ts : List Ty} {ps qs : List TParam}
    (h1 : SatAll B C ss ps) (h2 : SatAll B C ts qs) : SatAll B C (ss ++ ts) (ps ++ qs) := by
  refine ⟨by simp [h1.1, h2.1], fun i t p hi hp => ?_⟩
  by_cases hlt : i < ss.length
  · rw [List.getElem?_append_left hlt] at hi
    rw [List.getElem?_append_left (by rw [← h1.1]; exact hlt)] at hp
    exact h1.2 i t p hi hp
  · rw [List.getElem?_append_right (by omega)] at hi
    rw [List.getElem?_append_right (by rw [← h1.1]; omega), ← h1.1] at hp
    exact h2.2 _ t p hi hp

/-! ## 実装の定義の型付けの取り出し -/

theorem Program.WellTyped.impl (hwt : P.WellTyped B) {i id} (hi : P.impls i = some id) :
    id.WellTyped P B := hwt.2 i id hi

theorem Program.WellFormed.impl (hwf : P.WellFormed) {i id} (hi : P.impls i = some id) :
    id.Scoped P := hwf.2.2.2.2 i id hi

theorem Program.WellFormed.meth (hwf : P.WellFormed) {cl cd m ms} (hc : P.classes cl = some cd)
    (hm : cd.methods m = some ms) : ms.Scoped := hwf.2.2.2.1 cl cd hc m ms hm

/-! ## E-Super -/

theorem Val.superStep_super_of_not_dict {w : Val} {s : ClassName} (h : ∀ i ts vs, w ≠ .dict i ts vs) :
    (Val.super w s).superStep P = (w.superStep P).map fun v' => .super v' s := by
  cases w <;> simp_all [Val.superStep]

/-- 上位の型クラスの辞書 `I[T̄](V̄)↑S` から取り出した辞書 `U[T̄/β̄][V̄/d̄]` に、型 `Dict[S, τ[T̄/β̄]]` が付く。 -/
theorem superStep_dict_typed (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P) {Ψ}
    (hΨ : StoreTy.WF Ψ) {i ts vs s id u cl τ}
    (hv : HasTypeV P B Ψ [] [] (.super (.dict i ts vs) s) (.dict cl τ))
    (hc : Val.VarsIn 0 (fun _ => True) (.super (.dict i ts vs) s))
    (hi : P.impls i = some id) (hu : id.supers s = some u) :
    HasTypeV P B Ψ [] [] ((u.substTy ts []).instantiate vs) (.dict cl τ) ∧
      Val.VarsIn 0 (fun _ => True) ((u.substTy ts []).instantiate vs) := by
  obtain ⟨cl0, τ0, cd0, hw, hcl0, hs, he⟩ := hv.inv_super rfl
  simp only [Ty.dict.injEq] at he
  obtain ⟨rfl, rfl⟩ := he
  obtain ⟨id', hi', hsat, hvs, he'⟩ := hw.inv_dict rfl
  rw [hi] at hi'; cases hi'
  simp only [Ty.dict.injEq] at he'
  obtain ⟨rfl, rfl⟩ := he'
  obtain ⟨cd, hcd, _, _, _, hsup⟩ := hwt.impl hi
  rw [hcl0] at hcd; cases hcd
  obtain ⟨u', hu', hut⟩ := hsup _ hs
  rw [hu] at hu'; cases hu'
  simp only [Val.VarsIn] at hc
  have htsC : ClosedArgs ts := closedArgs_of hc.1
  have hsc := hwf.impl hi
  have hθ := HasTypeVQ.substTy (c := 0) (es' := []) hwf hb hut (Nat.zero_le _) htsC (by simp) (by simpa using hsat)
    (StoreFix.empty ts []) (RowTransport.refl Qempty)
  simp only [List.take_zero, envSubst] at hθ
  rw [← binds_map] at hθ
  have hθ' := hθ.store (Ψ' := Ψ) (fun l x h => by simp [StoreTy.empty] at h)
  simp only [Ty.substAt] at hθ'
  refine ⟨?_, ?_⟩
  · have := hθ'.instantiate (R := none)
      (InstOk.of_values hb hvs (hvs.wf_all hwf hb hΨ hc.2) hc.2)
    simpa [Val.substTy, Ty.subst] using this
  · refine Val.VarsIn.instantiate (depth := 0) hc.2 (Val.VarsIn.substTyAt (c := 0) [] (fun x hx => varsInList_mem hc.1 hx) (by simp) u ?_)
    rw [Nat.zero_add, hsat.1]
    exact Val.VarsIn.toTrue _ (hsc.2.2.1 _ u hu)

theorem superStep_super_typed (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P) {Ψ}
    (hΨ : StoreTy.WF Ψ) :
    (w : Val) → (s : ClassName) → ∀ {v' cl τ}, (Val.super w s).superStep P = some v' →
      HasTypeV P B Ψ [] [] (.super w s) (.dict cl τ) → Val.VarsIn 0 (fun _ => True) (.super w s) →
      HasTypeV P B Ψ [] [] v' (.dict cl τ) ∧ Val.VarsIn 0 (fun _ => True) v'
  | .dict i ts vs, s, v', cl, τ, h, hv, hc => by
      simp only [Val.superStep] at h
      split at h
      · rename_i id hi
        simp only [Option.map_eq_some_iff] at h
        obtain ⟨u, hu, rfl⟩ := h
        exact superStep_dict_typed hwf hwt hb hΨ hv hc hi hu
      · cases h
  | .super w2 s2, s, v', cl, τ, h, hv, hc => by
      simp only [Val.superStep, Option.map_eq_some_iff] at h
      obtain ⟨w', hw', rfl⟩ := h
      obtain ⟨cl0, τ0, cd0, hw, hcl0, hs, he⟩ := hv.inv_super rfl
      simp only [Val.VarsIn] at hc
      obtain ⟨hw'', hc''⟩ := superStep_super_typed hwf hwt hb hΨ w2 s2 hw' hw hc
      simp only [Ty.dict.injEq] at he
      obtain ⟨rfl, rfl⟩ := he
      exact ⟨.V_Super hw'' hcl0 hs, hc''⟩
  | .var _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .const _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .fnRef _ _ _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .prim _ _ _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .lam _ _ _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .con _ _ _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .list _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .op _ _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .loc _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .mapV _ _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .setV _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
  | .bytesV _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h

/-- E-Super の一歩は、辞書の型と、型の変数を含まないことを保つ。 -/
theorem superStep_typed (hwf : P.WellFormed) (hwt : P.WellTyped B) (hb : B.Assumptions P) {Ψ}
    (hΨ : StoreTy.WF Ψ) {v v' cl τ} (h : v.superStep P = some v')
    (hv : HasTypeV P B Ψ [] [] v (.dict cl τ)) (hc : Val.VarsIn 0 (fun _ => True) v) :
    HasTypeV P B Ψ [] [] v' (.dict cl τ) ∧ Val.VarsIn 0 (fun _ => True) v' := by
  cases v with
  | super w s => exact superStep_super_typed hwf hwt hb hΨ w s h hv hc
  | _ => simp [Val.superStep] at h

end Benitoite.Release
