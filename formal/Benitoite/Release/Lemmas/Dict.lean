import Benitoite.Release.Lemmas.PresBase

/-!
# 辞書とメソッドの呼び出しの補題（段階 B2）

E-Meth は、実装のメソッドの本体に、メソッドの型引数 S̄ と実装の型引数 T̄ を並べた `S̄ ++ T̄` の置き換えを施す。
本体の型は、D-Impl が型クラスの引数 P を実装の対象 τ に置き換えた型（`ImplDecl.methTy`）なので、置き換えの後の
型は、C-Meth の `θ = [τ[T̄/β̄]/P, S̄/γ̄, Ē/ρ̄]` を施した型と等しい。E-Super は、実装の定義の上位の型クラスの辞書に
`[T̄/β̄][V̄/d̄]` を施す。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 型の置き換えの合成 -/

theorem Eff.substRho_of_noRho (es : List Eff) {e : Eff} (h : Eff.RhosIn (fun _ => False) e) :
    Eff.substRho es e = e := by
  have : Ty.substAt 0 [] es (.fn [] (.base .unit) e) = .fn [] (.base .unit) e :=
    Ty.substAt_of_closed [] es _ (by simp only [Ty.VarsIn, Ty.VarsInList]; exact ⟨trivial, trivial, h⟩)
  simp only [Ty.substAt, List.map_nil] at this
  exact (Ty.fn.inj this).2.2

mutual
  /-- 型の変数の番号を g ずらしてから `S̄ ++ T̄`（S̄ の長さが g）で置き換えるのは、T̄ で置き換えるのと同じである
  （エフェクト変数を含まない型のとき）。 -/
  theorem Ty.shift_subst_append {ts ss : List Ty} {g : Nat} (es : List Eff) (hss : ss.length = g) :
      (u : Ty) → Ty.VarsIn ts.length (fun _ => False) u →
      (u.shift g 0).substAt 0 (ss ++ ts) es = u.substAt 0 ts []
    | .base _, _ => by simp [Ty.shift, Ty.substAt]
    | .opaque _, _ => by simp [Ty.shift, Ty.substAt]
    | .data d args, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.shift, Ty.substAt]
        rw [List.map_map, Ty.shiftList_subst_append es hss args h]
    | .list a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.shift, Ty.substAt]
        rw [Ty.shift_subst_append es hss a h]
    | .fn ps r e, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.shift, Ty.substAt]
        rw [List.map_map, Ty.shiftList_subst_append es hss ps h.1, Ty.shift_subst_append es hss r h.2.1,
          Eff.substRho_of_noRho es h.2.2, Eff.substRho_of_noRho [] h.2.2]
    | .tvar j, h => by
        simp only [Ty.VarsIn] at h
        have h1 : j + g < (ss ++ ts).length := by simp; omega
        simp only [Ty.shift, Nat.not_lt_zero, ↓reduceIte, Ty.substAt, Nat.sub_zero, h1, h,
          Ty.shift_zero]
        rw [List.getElem?_append_right (by omega)]
        simp [hss, List.getElem?_eq_getElem h]
    | .reference a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.shift, Ty.substAt]
        rw [Ty.shift_subst_append es hss a h]
    | .lazy a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.shift, Ty.substAt]
        rw [Ty.shift_subst_append es hss a h]
    | .cont _ _ _, h => by simp only [Ty.VarsIn] at h
    | .map a b, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.shift, Ty.substAt]
        rw [Ty.shift_subst_append es hss a h.1, Ty.shift_subst_append es hss b h.2]
    | .set a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.shift, Ty.substAt]
        rw [Ty.shift_subst_append es hss a h]
    | .bytes, _ => by simp [Ty.shift, Ty.substAt]
    | .dict _ τ, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.shift, Ty.substAt]
        rw [Ty.shift_subst_append es hss τ h]
    | .tapp j args, h => by
        simp only [Ty.VarsIn] at h
        have hl := Ty.shiftList_subst_append es hss args h.2
        have h1 : j + g < (ss ++ ts).length := by simp; omega
        simp only [Ty.shift, Nat.not_lt_zero, ↓reduceIte, Ty.substAt, Nat.sub_zero, h1, h.1,
          Ty.shift_zero, List.map_map]
        rw [hl, List.getElem?_append_right (by omega)]
        simp [hss, List.getElem?_eq_getElem h.1]
    | .ctor _, _ => by simp [Ty.shift, Ty.substAt]

  theorem Ty.shiftList_subst_append {ts ss : List Ty} {g : Nat} (es : List Eff) (hss : ss.length = g) :
      (as : List Ty) → Ty.VarsInList ts.length (fun _ => False) as →
      as.map ((Ty.substAt 0 (ss ++ ts) es) ∘ (Ty.shift g 0)) = as.map (Ty.substAt 0 ts [])
    | [], _ => rfl
    | a :: as, h => by
        simp only [Ty.VarsInList] at h
        have := Ty.shiftList_subst_append es hss as h.2
        simp only [List.map_cons, Function.comp_apply]
        rw [Ty.shift_subst_append es hss a h.1, this]
end

mutual
  /-- 型クラスの引数 P（番号 g）を u に置き換えてから `S̄ ++ T̄` で置き換えるのは、P を u の置き換えの結果にして
  `S̄` とともに置き換えるのと同じである。 -/
  theorem Ty.methTy_subst {ts ss : List Ty} {g : Nat} {pe : Nat → Prop} (u : Ty) (es : List Eff)
      (hss : ss.length = g) :
      (t : Ty) → Ty.VarsIn (g + 1) pe t →
      (t.substAt g [u] []).substAt 0 (ss ++ ts) es =
        t.substAt 0 (ss ++ [(u.shift g 0).substAt 0 (ss ++ ts) es]) es
    | .base _, _ => by simp [Ty.substAt]
    | .opaque _, _ => by simp [Ty.substAt]
    | .data d args, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt]
        rw [List.map_map, Ty.methTyList_subst (ts := ts) u es hss args h]
    | .list a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt]
        rw [Ty.methTy_subst u es hss a h]
    | .fn ps r e, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt]
        rw [List.map_map, Ty.methTyList_subst (ts := ts) u es hss ps h.1, Ty.methTy_subst u es hss r h.2.1,
          Eff.substRho_nil]
    | .tvar i, h => by
        simp only [Ty.VarsIn] at h
        by_cases hi : i < g
        · have h1 : i < (ss ++ ts).length := by simp; omega
          have h2 : i < (ss ++ [(u.shift g 0).substAt 0 (ss ++ ts) es]).length := by simp; omega
          simp only [Ty.substAt, hi, ↓reduceIte, Nat.not_lt_zero, Nat.sub_zero, h1, h2, Ty.shift_zero]
          rw [List.getElem?_append_left (by omega), List.getElem?_append_left (by omega)]
        · have hig : i = g := by omega
          subst hig
          have h2 : i < (ss ++ [(u.shift i 0).substAt 0 (ss ++ ts) es]).length := by simp; omega
          simp only [Ty.substAt, Nat.lt_irrefl, ↓reduceIte, Nat.sub_self, List.length_singleton,
            Nat.zero_lt_one, List.getElem?_cons_zero, Option.getD_some, Nat.not_lt_zero, Nat.sub_zero, h2,
            Ty.shift_zero]
          rw [List.getElem?_append_right (by omega)]
          simp [hss]
    | .reference a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt]
        rw [Ty.methTy_subst u es hss a h]
    | .lazy a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt]
        rw [Ty.methTy_subst u es hss a h]
    | .cont _ _ _, h => by simp only [Ty.VarsIn] at h
    | .map a b, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt]
        rw [Ty.methTy_subst u es hss a h.1, Ty.methTy_subst u es hss b h.2]
    | .set a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt]
        rw [Ty.methTy_subst u es hss a h]
    | .bytes, _ => by simp [Ty.substAt]
    | .dict _ τ, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt]
        rw [Ty.methTy_subst u es hss τ h]
    | .tapp i args, h => by
        simp only [Ty.VarsIn] at h
        have hl := Ty.methTyList_subst (ts := ts) u es hss args h.2
        by_cases hi : i < g
        · have h1 : i < (ss ++ ts).length := by simp; omega
          have h2 : i < (ss ++ [(u.shift g 0).substAt 0 (ss ++ ts) es]).length := by simp; omega
          simp only [Ty.substAt, hi, ↓reduceIte, Nat.not_lt_zero, Nat.sub_zero, h1, h2, Ty.shift_zero,
            List.map_map]
          rw [hl, List.getElem?_append_left (by omega), List.getElem?_append_left (by omega)]
        · have hig : i = g := by omega
          subst hig
          have h2 : i < (ss ++ [(u.shift i 0).substAt 0 (ss ++ ts) es]).length := by simp; omega
          simp only [Ty.substAt, Nat.lt_irrefl, ↓reduceIte, Nat.sub_self, List.length_singleton,
            Nat.zero_lt_one, List.getElem?_cons_zero, Option.getD_some, Nat.not_lt_zero, Nat.sub_zero, h2,
            Ty.shift_zero]
          rw [Ty.substAt_applyTo, List.map_map, hl, List.getElem?_append_right (by omega)]
          simp [hss]
    | .ctor _, _ => by simp [Ty.substAt]

  theorem Ty.methTyList_subst {ts ss : List Ty} {g : Nat} {pe : Nat → Prop} (u : Ty) (es : List Eff)
      (hss : ss.length = g) :
      (as : List Ty) → Ty.VarsInList (g + 1) pe as →
      as.map ((Ty.substAt 0 (ss ++ ts) es) ∘ (Ty.substAt g [u] [])) =
        as.map (Ty.substAt 0 (ss ++ [(u.shift g 0).substAt 0 (ss ++ ts) es]) es)
    | [], _ => rfl
    | a :: as, h => by
        simp only [Ty.VarsInList] at h
        have := Ty.methTyList_subst (ts := ts) u es hss as h.2
        simp only [List.map_cons, Function.comp_apply]
        rw [Ty.methTy_subst u es hss a h.1, this]
end

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
  · have := Ty.methTyList_subst (ts := ts) id.target es hss ms.params hms.1
    rw [List.map_map, this, ht]
  · have := Ty.methTy_subst (ts := ts) id.target es hss ms.ret hms.2.1
    rw [this, ht]

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
  have hθ := HasTypeV.substTy (c := 0) (es' := []) hwf hb hut (Nat.zero_le _) htsC (by simpa using hsat)
    (StoreFix.empty ts [])
  simp only [List.take_zero, envSubst] at hθ
  rw [← binds_map] at hθ
  have hθ' := hθ.store (Ψ' := Ψ) (fun l x h => by simp [StoreTy.empty] at h)
  simp only [Ty.substAt] at hθ'
  refine ⟨?_, ?_⟩
  · have := hθ'.instantiate (R := none)
      (InstOk.of_values hb hvs (hvs.wf_all hwf hb hΨ hc.2) hc.2)
    simpa [Val.substTy, Ty.subst] using this
  · refine Val.VarsIn.instantiate hc.2 (Val.VarsIn.substTyAt (c := 0) [] (fun x hx => varsInList_mem hc.1 hx) u ?_)
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
  | .lam _ _, _, _, _, _, h, _, _ => by simp [Val.superStep] at h
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
