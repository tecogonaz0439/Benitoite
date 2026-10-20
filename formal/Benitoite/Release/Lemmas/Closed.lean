import Benitoite.Release.Lemmas.TyLemmas
import Benitoite.Release.LocalRef

/-!
# 項が閉じていることの保存（段階 B）

状態の型付けは、状態の中の項が型の変数を含まないことを求める（`StateTy`）。値の置き換え、型の置き換え、
番号の付け替えで、この性質が保たれることを示す。エフェクト変数の条件は問わない（`fun _ => True`）。
ラムダの契約名とその整形式も保持する（設計書 01-12「初回リリース版の拡張」）。
-/

namespace Benitoite.Release

/-- 項の中の型の変数の番号が `n` より小さく、継続の型を含まない。 -/
abbrev TyOK (n : Nat) (a : Ty) : Prop := Ty.VarsIn n (fun _ => True) a

/-! ## 型 -/

theorem Ty.applyTo_varsIn {n : Nat} {pe : Nat → Prop} {t : Ty} {as : List Ty} (ht : Ty.VarsIn n pe t)
    (has : Ty.VarsInList n pe as) : Ty.VarsIn n pe (t.applyTo as) := by
  rw [Ty.applyTo_eq_raw_norm]
  apply Ty.norm_VarsIn
  cases t with
  | ctor φ =>
    cases φ <;> cases as <;> simp_all [Ty.rawApplyTo, TyCon.rawApply, Ty.VarsIn, Ty.VarsInList]
    all_goals (rename_i b; cases b <;> simp_all [Ty.VarsIn, Ty.VarsInList])
  | tvar j => exact ⟨ht, has⟩
  | _ => exact ht

mutual
  theorem Ty.VarsIn.substAt {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e) :
      (a : Ty) → TyOK (c + ts.length) a → TyOK c (a.substAt c ts es)
    | .base _, _ => by simp [Ty.substAt, Ty.VarsIn]
    | .opaque _, _ => by simp [Ty.substAt, Ty.VarsIn]
    | .data _ args, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.substTysAt_eq_map, Ty.VarsIn]
        exact Ty.VarsInList.substAt es hts hes args h
    | .list a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts hes a h
    | .fn names ps r e, h => by
        simp only [Ty.VarsIn] at h
        simp only [Ty.substAt, Ty.VarsIn, Ty.substTysAt_eq_map]
        exact ⟨h.1.map _, Ty.VarsInList.substAt es hts hes ps h.2.1,
          Ty.VarsIn.substAt es hts hes r h.2.2.1, Eff.VarsIn.substAt es hts hes e h.2.2.2.1,
          Eff.norm_idem _⟩
    | .tvar i, h => by
        simp only [Ty.VarsIn] at h
        simp only [Ty.substAt]
        by_cases h1 : i < c
        · simp [h1, Ty.VarsIn]
        · have h2 : i - c < ts.length := by omega
          simp only [h1, ↓reduceIte, h2, List.getElem?_eq_getElem h2, Option.getD_some]
          have hu := hts _ (List.getElem_mem h2)
          rw [Ty.shift_of_wf c _ (Ty.WF.mono (Nat.zero_le _) _ (Ty.VarsIn.wf _ hu))]
          exact Ty.VarsIn.mono (Nat.zero_le _) (fun _ h => h) _ hu
    | .reference a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts hes a h
    | .lazy a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts hes a h
    | .cont _ _ _, h => by simp only [Ty.VarsIn] at h
    | .map a b, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]
        exact ⟨Ty.VarsIn.substAt es hts hes a h.1, Ty.VarsIn.substAt es hts hes b h.2⟩
    | .set a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts hes a h
    | .bytes, _ => by simp [Ty.substAt, Ty.VarsIn]
    | .dict _ τ, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts hes τ h
    | .tapp i args, h => by
        simp only [Ty.VarsIn] at h
        have hl := Ty.VarsInList.substAt es hts hes args h.2
        simp only [Ty.substAt, Ty.substTysAt_eq_map]
        by_cases h1 : i < c
        · simp only [h1, ↓reduceIte, Ty.VarsIn]; exact ⟨trivial, hl⟩
        · have h2 : i - c < ts.length := by omega
          simp only [h1, ↓reduceIte, h2, List.getElem?_eq_getElem h2, Option.getD_some]
          have hu := hts _ (List.getElem_mem h2)
          rw [Ty.shift_of_wf c _ (Ty.WF.mono (Nat.zero_le _) _ (Ty.VarsIn.wf _ hu))]
          exact Ty.applyTo_varsIn (Ty.VarsIn.mono (Nat.zero_le _) (fun _ h => h) _ hu) hl
    | .ctor _, _ => by simp [Ty.substAt, Ty.VarsIn]

  theorem Ty.VarsInList.substAt {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e) :
      (as : List Ty) → Ty.VarsInList (c + ts.length) (fun _ => True) as →
      Ty.VarsInList c (fun _ => True) (as.map (Ty.substAt c ts es))
    | [], _ => trivial
    | a :: as, h => by
        simp only [Ty.VarsInList] at h; simp only [List.map_cons, Ty.VarsInList]
        exact ⟨Ty.VarsIn.substAt es hts hes a h.1, Ty.VarsInList.substAt es hts hes as h.2⟩

  theorem Eff.VarsIn.substAt {c : Nat} {ts : List Ty} (es : List Eff)
      (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e)
      (e : Eff) (h : Eff.VarsIn (c + ts.length) (fun _ => True) e) :
      Eff.VarsIn c (fun _ => True) (Eff.substAt c ts es e) := by
    cases e with
    | mk a fs =>
      refine ⟨fun _ _ => trivial, Ty.VarsInList.iff.mpr ?_⟩
      intro t ht
      change t ∈ (Eff.substAt c ts es (EffR.mk a fs)).fails at ht
      rw [Eff.substAt_fails] at ht
      rcases List.mem_append.mp (Order.mem_sortUnique.mp ht) with ht | ht
      · exact Ty.VarsInList.iff.mp (Ty.VarsInList.substAt es hts hes fs h.2) t (by
          simpa only [Ty.substTysAt_eq_map, Eff.fails] using ht)
      · obtain ⟨x, hx, rfl⟩ := List.mem_map.mp (show t ∈ (Eff.rowFails (es.map (Eff.rawShift c 0)) a).map Ty.norm from by
          simpa only [Ty.normTys_eq_map, Eff.atoms] using ht)
        obtain ⟨i, f, hf, _, hxf⟩ := Eff.mem_rowFails.mp hx
        obtain ⟨g, hg, hfg⟩ := Option.map_eq_some_iff.mp (show (es[i]?).map (Eff.rawShift c 0) = some f from by
          simpa only [List.getElem?_map] using hf)
        have hw := hes g (List.mem_of_getElem? hg)
        rw [Eff.rawShift_of_wf c g (Eff.VarsIn.wf g hw)] at hfg
        subst f
        have hfs : Ty.VarsInList 0 (fun _ => True) g.fails := by cases g; exact hw.2
        have hx := Ty.VarsInList.iff.mp hfs x hxf
        exact Ty.VarsIn.mono (Nat.zero_le c) (fun _ h => h) x.norm (Ty.norm_VarsIn x hx)

end

theorem Eff.RhosInList.true (es : List Eff) : Eff.RhosInList (fun _ => True) es := by
  induction es with
  | nil => trivial
  | cons e es ih => exact ⟨Eff.rowsIn_true e, ih⟩

theorem Eff.VarsInList.substAt {c : Nat} {ts : List Ty} (es : List Eff)
    (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e)
    (fs : List Eff) (h : Eff.VarsInList (c + ts.length) (fun _ => True) fs) :
    Eff.VarsInList c (fun _ => True) (fs.map (Eff.substAt c ts es)) := by
  apply Eff.VarsInList.iff.mpr
  rintro f hf
  obtain ⟨e, he, rfl⟩ := List.mem_map.mp hf
  exact Eff.VarsIn.substAt es hts hes e (Eff.VarsInList.iff.mp h e he)

/-! ## 値と計算の型の置き換え -/

mutual
  theorem Val.VarsIn.substTyAt {depth : Nat} {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e) :
      (v : Val) → Val.VarsIn (c + ts.length) (fun _ => True) v depth →
      Val.VarsIn c (fun _ => True) (v.substTyAt c ts es) depth
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ tys _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts hes tys h.1, Eff.VarsInList.substAt es hts hes _ h.2⟩
    | .prim _ tys _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts hes tys h.1, Eff.VarsInList.substAt es hts hes _ h.2⟩
    | .lam names ps body, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨h.1.map _, Ty.VarsInList.substAt es hts hes ps h.2.1, (by simpa only [List.length_map] using Comp.VarsIn.substTyAt es hts hes body h.2.2)⟩
    | .con _ tys args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts hes tys h.1, Val.VarsInList.substTyAt es hts hes args h.2⟩
    | .list elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact Val.VarsInList.substTyAt es hts hes elems h
    | .op _ tys, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact Ty.VarsInList.substAt es hts hes tys h
    | .raise t e, h => by
        exact ⟨Ty.VarsIn.substAt es hts hes t h.1, Ty.VarsIn.substAt es hts hes e h.2⟩
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Val.VarsInList.substTyAt es hts hes ks h.1, Val.VarsInList.substTyAt es hts hes vs h.2⟩
    | .setV elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact Val.VarsInList.substTyAt es hts hes elems h
    | .bytesV _, _ => by simp [Val.substTyAt, Val.VarsIn]
    | .dict _ tys args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts hes tys h.1, Val.VarsInList.substTyAt es hts hes args h.2⟩
    | .super v _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact Val.VarsIn.substTyAt es hts hes v h

  theorem Val.VarsInList.substTyAt {depth : Nat} {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e) :
      (vs : List Val) → Val.VarsInList (c + ts.length) (fun _ => True) vs depth →
      Val.VarsInList c (fun _ => True) (Val.substTyAtList c ts es vs) depth
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h; simp only [Val.substTyAtList, Val.VarsInList]
        exact ⟨Val.VarsIn.substTyAt es hts hes v h.1, Val.VarsInList.substTyAt es hts hes vs h.2⟩

  theorem Comp.VarsIn.substTyAt {depth : Nat} {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e) :
      (m : Comp) → Comp.VarsIn (c + ts.length) (fun _ => True) m depth →
      Comp.VarsIn c (fun _ => True) (m.substTyAt c ts es) depth
    | .builderLet k body, h => by
        cases k <;> simp only [Comp.VarsIn, Comp.substTyAt, BuilderKind.substTyAt] at h ⊢
        · exact ⟨trivial, Comp.VarsIn.substTyAt es hts hes body h.2⟩
        · exact ⟨Ty.VarsIn.substAt es hts hes _ h.1, Comp.VarsIn.substTyAt es hts hes body h.2⟩
        · exact ⟨trivial, Comp.VarsIn.substTyAt es hts hes body h.2⟩
    | .builderOp k op r args, h => by
        cases k <;> simp only [Comp.VarsIn, Comp.substTyAt, BuilderKind.substTyAt] at h ⊢
        · exact ⟨trivial, h.2.1, Val.VarsInList.substTyAt es hts hes args h.2.2⟩
        · exact ⟨Ty.VarsIn.substAt es hts hes _ h.1, h.2.1, Val.VarsInList.substTyAt es hts hes args h.2.2⟩
        · exact ⟨trivial, h.2.1, Val.VarsInList.substTyAt es hts hes args h.2.2⟩
    | .ret v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact Val.VarsIn.substTyAt es hts hes v h
    | .letIn m n, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Comp.VarsIn.substTyAt es hts hes m h.1, Comp.VarsIn.substTyAt es hts hes n h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts hes f h.1, Val.VarsInList.substTyAt es hts hes args h.2⟩
    | .ite v m n, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts hes v h.1, Comp.VarsIn.substTyAt es hts hes m h.2.1,
          Comp.VarsIn.substTyAt es hts hes n h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts hes v h.1, Arm.VarsInList.substTyAt es hts hes arms h.2⟩
    | .lazyC m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact Comp.VarsIn.substTyAt es hts hes m h
    | .escape v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact Val.VarsIn.substTyAt es hts hes v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts hes v h.1, Comp.VarsIn.substTyAt es hts hes m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Comp.VarsIn.substTyAt es hts hes m h.1, Clause.VarsInList.substTyAt es hts hes hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts hes k h.1, Val.VarsIn.substTyAt es hts hes v h.2⟩
    | .meth d _ tys _ args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts hes d h.1, Ty.VarsInList.substAt es hts hes tys h.2.1,
          Eff.VarsInList.substAt es hts hes _ h.2.2.1, Val.VarsInList.substTyAt es hts hes args h.2.2.2⟩

  theorem Arm.VarsInList.substTyAt {depth : Nat} {c : Nat} {ts : List Ty} (es : List Eff)
      (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e) :
      (arms : List Arm) → Arm.VarsInList (c + ts.length) (fun _ => True) arms depth →
      Arm.VarsInList c (fun _ => True) (Arm.substTyAtList c ts es arms) depth
    | [], _ => trivial
    | .mk alts none m :: arms, h => by
        simp only [Arm.VarsInList] at h; simp only [Arm.substTyAtList, Arm.VarsInList]
        exact ⟨Comp.VarsIn.substTyAt es hts hes m h.1, Arm.VarsInList.substTyAt es hts hes arms h.2⟩
    | .mk alts (some g) m :: arms, h => by
        simp only [Arm.VarsInList] at h; simp only [Arm.substTyAtList, Arm.VarsInList]
        exact ⟨Comp.VarsIn.substTyAt es hts hes g h.1,
          Comp.VarsIn.substTyAt es hts hes m h.2.1, Arm.VarsInList.substTyAt es hts hes arms h.2.2⟩

  theorem Clause.VarsInList.substTyAt {depth : Nat} {c : Nat} {ts : List Ty} (es : List Eff)
      (hts : ∀ u ∈ ts, TyOK 0 u) (hes : ∀ e ∈ es, Eff.VarsIn 0 (fun _ => True) e) :
      (hs : List Clause) → Clause.VarsInList (c + ts.length) (fun _ => True) hs depth →
      Clause.VarsInList c (fun _ => True) (Clause.substTyAtList c ts es hs) depth
    | [], _ => trivial
    | .mk o n k m :: cs, h => by
        simp only [Clause.VarsInList] at h; simp only [Clause.substTyAtList, Clause.VarsInList]
        refine ⟨?_, Clause.VarsInList.substTyAt es hts hes cs h.2⟩
        have := Comp.VarsIn.substTyAt (c := c + k) es hts hes m (by
          have := h.1; rwa [show c + ts.length + k = c + k + ts.length by omega] at this)
        exact this
    | .fail e m :: cs, h => by
        refine ⟨Ty.VarsIn.substAt es hts hes e h.1, ?_, Clause.VarsInList.substTyAt es hts hes cs h.2.2⟩
        exact Comp.VarsIn.substTyAt (c := c + 1) es hts hes m (by
          have hm := h.2.1
          rwa [show c + ts.length + 1 = c + 1 + ts.length by omega] at hm)

end

/-! ## 値の範囲の単調性と、番号の付け替えと値の置き換え -/

mutual
  theorem Val.VarsIn.mono {depth : Nat} {n n' : Nat} (hn : n ≤ n') : (v : Val) → Val.VarsIn n (fun _ => True) v depth →
      Val.VarsIn n' (fun _ => True) v depth
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ tys _, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Eff.VarsInList.mono hn (fun _ h => h) _ h.2⟩
    | .prim _ tys _, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Eff.VarsInList.mono hn (fun _ h => h) _ h.2⟩
    | .lam names ps body, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨h.1, Ty.VarsInList.mono hn (fun _ h => h) _ h.2.1, Comp.VarsIn.mono hn body h.2.2⟩
    | .con _ tys args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Val.VarsInList.mono hn args h.2⟩
    | .list elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.mono hn elems h
    | .op _ tys, h => by simp only [Val.VarsIn] at h ⊢; exact Ty.VarsInList.mono hn (fun _ h => h) _ h
    | .raise t e, h => ⟨Ty.VarsIn.mono hn (fun _ h => h) t h.1, Ty.VarsIn.mono hn (fun _ h => h) e h.2⟩
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Val.VarsInList.mono hn ks h.1, Val.VarsInList.mono hn vs h.2⟩
    | .setV elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.mono hn elems h
    | .bytesV _, _ => by simp [Val.VarsIn]
    | .dict _ tys args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Val.VarsInList.mono hn args h.2⟩
    | .super v _, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsIn.mono hn v h

  theorem Val.VarsInList.mono {depth : Nat} {n n' : Nat} (hn : n ≤ n') : (vs : List Val) →
      Val.VarsInList n (fun _ => True) vs depth → Val.VarsInList n' (fun _ => True) vs depth
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h ⊢; exact ⟨Val.VarsIn.mono hn v h.1, Val.VarsInList.mono hn vs h.2⟩

  theorem Comp.VarsIn.mono {depth : Nat} {n n' : Nat} (hn : n ≤ n') : (m : Comp) → Comp.VarsIn n (fun _ => True) m depth →
      Comp.VarsIn n' (fun _ => True) m depth
    | .builderLet k body, h => by
        cases k <;> simp only [Comp.VarsIn] at h ⊢
        · exact ⟨trivial, Comp.VarsIn.mono hn body h.2⟩
        · exact ⟨Ty.VarsIn.mono hn (fun _ h => h) _ h.1, Comp.VarsIn.mono hn body h.2⟩
        · exact ⟨trivial, Comp.VarsIn.mono hn body h.2⟩
    | .builderOp k op r args, h => by
        cases k <;> simp only [Comp.VarsIn] at h ⊢
        · exact ⟨trivial, h.2.1, Val.VarsInList.mono hn args h.2.2⟩
        · exact ⟨Ty.VarsIn.mono hn (fun _ h => h) _ h.1, h.2.1, Val.VarsInList.mono hn args h.2.2⟩
        · exact ⟨trivial, h.2.1, Val.VarsInList.mono hn args h.2.2⟩
    | .ret v, h => by simp only [Comp.VarsIn] at h ⊢; exact Val.VarsIn.mono hn v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Comp.VarsIn.mono hn m h.1, Comp.VarsIn.mono hn k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.mono hn f h.1, Val.VarsInList.mono hn args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h ⊢
        exact ⟨Val.VarsIn.mono hn v h.1, Comp.VarsIn.mono hn m h.2.1, Comp.VarsIn.mono hn k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.mono hn v h.1, Arm.VarsInList.mono hn arms h.2⟩
    | .lazyC m, h => by simp only [Comp.VarsIn] at h ⊢; exact Comp.VarsIn.mono hn m h
    | .escape v, h => by simp only [Comp.VarsIn] at h ⊢; exact Val.VarsIn.mono hn v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.mono hn v h.1, Comp.VarsIn.mono hn m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Comp.VarsIn.mono hn m h.1, Clause.VarsInList.mono hn hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.mono hn k h.1, Val.VarsIn.mono hn v h.2⟩
    | .meth d _ tys _ args, h => by
        simp only [Comp.VarsIn] at h ⊢
        exact ⟨Val.VarsIn.mono hn d h.1, Ty.VarsInList.mono hn (fun _ h => h) _ h.2.1, Eff.VarsInList.mono hn (fun _ h => h) _ h.2.2.1,
          Val.VarsInList.mono hn args h.2.2.2⟩

  theorem Arm.VarsInList.mono {depth : Nat} {n n' : Nat} (hn : n ≤ n') : (arms : List Arm) →
      Arm.VarsInList n (fun _ => True) arms depth → Arm.VarsInList n' (fun _ => True) arms depth
    | [], _ => trivial
    | .mk alts none m :: arms, h => by
        simp only [Arm.VarsInList] at h ⊢; exact ⟨Comp.VarsIn.mono hn m h.1, Arm.VarsInList.mono hn arms h.2⟩
    | .mk alts (some g) m :: arms, h => by
        simp only [Arm.VarsInList] at h ⊢; exact ⟨Comp.VarsIn.mono hn g h.1,
          Comp.VarsIn.mono hn m h.2.1, Arm.VarsInList.mono hn arms h.2.2⟩

  theorem Clause.VarsInList.mono {depth : Nat} {n n' : Nat} (hn : n ≤ n') : (hs : List Clause) →
      Clause.VarsInList n (fun _ => True) hs depth → Clause.VarsInList n' (fun _ => True) hs depth
    | [], _ => trivial
    | .mk _ _ k m :: cs, h => by
        simp only [Clause.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.mono (by omega) m h.1, Clause.VarsInList.mono hn cs h.2⟩
    | .fail e m :: cs, h =>
        ⟨Ty.VarsIn.mono hn (fun _ h => h) e h.1,
          Comp.VarsIn.mono (by omega) m h.2.1, Clause.VarsInList.mono hn cs h.2.2⟩

end

mutual
  theorem Val.VarsIn.widen {pe : Nat → Prop} {depth depth2 : Nat} {n n' : Nat} (hn : n ≤ n') (hd : depth ≤ depth2) : (v : Val) → Val.VarsIn n pe v depth →
      Val.VarsIn n' pe v depth2
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ tys _, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Eff.VarsInList.mono hn (fun _ h => h) _ h.2⟩
    | .prim _ tys _, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Eff.VarsInList.mono hn (fun _ h => h) _ h.2⟩
    | .lam names ps body, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨h.1, Ty.VarsInList.mono hn (fun _ h => h) _ h.2.1, Comp.VarsIn.widen hn (by omega) body h.2.2⟩
    | .con _ tys args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Val.VarsInList.widen hn hd args h.2⟩
    | .list elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.widen hn hd elems h
    | .op _ tys, h => by simp only [Val.VarsIn] at h ⊢; exact Ty.VarsInList.mono hn (fun _ h => h) _ h
    | .raise t e, h => ⟨Ty.VarsIn.mono hn (fun _ h => h) t h.1, Ty.VarsIn.mono hn (fun _ h => h) e h.2⟩
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Val.VarsInList.widen hn hd ks h.1, Val.VarsInList.widen hn hd vs h.2⟩
    | .setV elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.widen hn hd elems h
    | .bytesV _, _ => by simp [Val.VarsIn]
    | .dict _ tys args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Val.VarsInList.widen hn hd args h.2⟩
    | .super v _, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsIn.widen hn hd v h

  theorem Val.VarsInList.widen {pe : Nat → Prop} {depth depth2 : Nat} {n n' : Nat} (hn : n ≤ n') (hd : depth ≤ depth2) : (vs : List Val) →
      Val.VarsInList n pe vs depth → Val.VarsInList n' pe vs depth2
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h ⊢; exact ⟨Val.VarsIn.widen hn hd v h.1, Val.VarsInList.widen hn hd vs h.2⟩

  theorem Comp.VarsIn.widen {pe : Nat → Prop} {depth depth2 : Nat} {n n' : Nat} (hn : n ≤ n') (hd : depth ≤ depth2) : (m : Comp) → Comp.VarsIn n pe m depth →
      Comp.VarsIn n' pe m depth2
    | .builderLet k body, h => by
        cases k <;> simp only [Comp.VarsIn] at h ⊢
        · exact ⟨trivial, Comp.VarsIn.widen hn (by omega) body h.2⟩
        · exact ⟨Ty.VarsIn.mono hn (fun _ h => h) _ h.1, Comp.VarsIn.widen hn (by omega) body h.2⟩
        · exact ⟨trivial, Comp.VarsIn.widen hn (by omega) body h.2⟩
    | .builderOp k op r args, h => by
        cases k <;> simp only [Comp.VarsIn] at h ⊢
        · exact ⟨trivial, h.2.1.mono hd, Val.VarsInList.widen hn hd args h.2.2⟩
        · exact ⟨Ty.VarsIn.mono hn (fun _ h => h) _ h.1, h.2.1.mono hd, Val.VarsInList.widen hn hd args h.2.2⟩
        · exact ⟨trivial, h.2.1.mono hd, Val.VarsInList.widen hn hd args h.2.2⟩
    | .ret v, h => by simp only [Comp.VarsIn] at h ⊢; exact Val.VarsIn.widen hn hd v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Comp.VarsIn.widen hn (by omega) m h.1, Comp.VarsIn.widen hn (by omega) k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.widen hn hd f h.1, Val.VarsInList.widen hn hd args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h ⊢
        exact ⟨Val.VarsIn.widen hn hd v h.1, Comp.VarsIn.widen hn (by omega) m h.2.1, Comp.VarsIn.widen hn (by omega) k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.widen hn hd v h.1, Arm.VarsInList.widen hn hd arms h.2⟩
    | .lazyC m, h => by simp only [Comp.VarsIn] at h ⊢; exact Comp.VarsIn.widen hn hd m h
    | .escape v, h => by simp only [Comp.VarsIn] at h ⊢; exact Val.VarsIn.widen hn hd v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.widen hn hd v h.1, Comp.VarsIn.widen hn (by omega) m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Comp.VarsIn.widen hn (by omega) m h.1, Clause.VarsInList.widen hn hd hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.widen hn hd k h.1, Val.VarsIn.widen hn hd v h.2⟩
    | .meth d _ tys _ args, h => by
        simp only [Comp.VarsIn] at h ⊢
        exact ⟨Val.VarsIn.widen hn hd d h.1, Ty.VarsInList.mono hn (fun _ h => h) _ h.2.1, Eff.VarsInList.mono hn (fun _ h => h) _ h.2.2.1,
          Val.VarsInList.widen hn hd args h.2.2.2⟩

  theorem Arm.VarsInList.widen {pe : Nat → Prop} {depth depth2 : Nat} {n n' : Nat} (hn : n ≤ n') (hd : depth ≤ depth2) : (arms : List Arm) →
      Arm.VarsInList n pe arms depth → Arm.VarsInList n' pe arms depth2
    | [], _ => trivial
    | .mk alts none m :: arms, h => by
        simp only [Arm.VarsInList] at h ⊢; exact ⟨Comp.VarsIn.widen hn (by omega) m h.1, Arm.VarsInList.widen hn hd arms h.2⟩
    | .mk alts (some g) m :: arms, h => by
        simp only [Arm.VarsInList] at h ⊢; exact ⟨Comp.VarsIn.widen hn (by omega) g h.1,
          Comp.VarsIn.widen hn (by omega) m h.2.1, Arm.VarsInList.widen hn hd arms h.2.2⟩

  theorem Clause.VarsInList.widen {pe : Nat → Prop} {depth depth2 : Nat} {n n' : Nat} (hn : n ≤ n') (hd : depth ≤ depth2) : (hs : List Clause) →
      Clause.VarsInList n pe hs depth → Clause.VarsInList n' pe hs depth2
    | [], _ => trivial
    | .mk _ _ k m :: cs, h => by
        simp only [Clause.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.widen (by omega) (by omega) m h.1, Clause.VarsInList.widen hn hd cs h.2⟩
    | .fail e m :: cs, h =>
        ⟨Ty.VarsIn.mono hn (fun _ h => h) e h.1,
          Comp.VarsIn.widen (by omega) (by omega) m h.2.1, Clause.VarsInList.widen hn hd cs h.2.2⟩

end

mutual
  theorem Val.VarsIn.renameLocal {pe : Nat → Prop} {n d e : Nat} (ξ : Nat → Nat) (hξ : ∀ i, i < d → ξ i < e) : (v : Val) → Val.VarsIn n pe v d →
      Val.VarsIn n pe (v.rename ξ) e
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ _ _, h => h
    | .prim _ _ _, h => h
    | .lam names ps body, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, h.2.1, Comp.VarsIn.renameLocal _ (by simpa [Nat.add_comm, Nat.add_assoc] using upRen_scoped hξ _) body h.2.2⟩
    | .con _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.renameLocal ξ hξ args h.2⟩
    | .list elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsInList.renameLocal ξ hξ elems h
    | .op _ _, h => h
    | .raise _ _, h => h
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨Val.VarsInList.renameLocal ξ hξ ks h.1, Val.VarsInList.renameLocal ξ hξ vs h.2⟩
    | .setV elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsInList.renameLocal ξ hξ elems h
    | .bytesV _, _ => by simp [Val.rename, Val.VarsIn]
    | .dict _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.renameLocal ξ hξ args h.2⟩
    | .super v _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsIn.renameLocal ξ hξ v h

  theorem Val.VarsInList.renameLocal {pe : Nat → Prop} {n d e : Nat} (ξ : Nat → Nat) (hξ : ∀ i, i < d → ξ i < e) : (vs : List Val) →
      Val.VarsInList n pe vs d → Val.VarsInList n pe (Val.renameList ξ vs) e
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h; simp only [Val.renameList, Val.VarsInList]
        exact ⟨Val.VarsIn.renameLocal ξ hξ v h.1, Val.VarsInList.renameLocal ξ hξ vs h.2⟩

  theorem Comp.VarsIn.renameLocal {pe : Nat → Prop} {n d e : Nat} (ξ : Nat → Nat) (hξ : ∀ i, i < d → ξ i < e) : (m : Comp) → Comp.VarsIn n pe m d →
      Comp.VarsIn n pe (m.rename ξ) e
    | .builderLet k body, h => by
        exact ⟨h.1, Comp.VarsIn.renameLocal _ (by simpa [Nat.add_comm] using upRen_scoped hξ 1) body h.2⟩
    | .builderOp k op r args, h => by
        exact ⟨h.1, h.2.1.rename hξ, Val.VarsInList.renameLocal ξ hξ args h.2.2⟩
    | .ret v, h => by simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Val.VarsIn.renameLocal ξ hξ v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Comp.VarsIn.renameLocal ξ hξ m h.1, Comp.VarsIn.renameLocal _ (by simpa [Nat.add_comm, Nat.add_assoc] using upRen_scoped hξ _) k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameLocal ξ hξ f h.1, Val.VarsInList.renameLocal ξ hξ args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameLocal ξ hξ v h.1, Comp.VarsIn.renameLocal ξ hξ m h.2.1, Comp.VarsIn.renameLocal ξ hξ k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameLocal ξ hξ v h.1, Arm.VarsInList.renameLocal ξ hξ arms h.2⟩
    | .lazyC m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Comp.VarsIn.renameLocal ξ hξ m h
    | .escape v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Val.VarsIn.renameLocal ξ hξ v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameLocal ξ hξ v h.1, Comp.VarsIn.renameLocal ξ hξ m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Comp.VarsIn.renameLocal ξ hξ m h.1, Clause.VarsInList.renameLocal ξ hξ hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameLocal ξ hξ k h.1, Val.VarsIn.renameLocal ξ hξ v h.2⟩
    | .meth d _ _ _ args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameLocal ξ hξ d h.1, h.2.1, h.2.2.1, Val.VarsInList.renameLocal ξ hξ args h.2.2.2⟩

  theorem Arm.VarsInList.renameLocal {pe : Nat → Prop} {n d e : Nat} (ξ : Nat → Nat) (hξ : ∀ i, i < d → ξ i < e) : (arms : List Arm) →
      Arm.VarsInList n pe arms d →
      Arm.VarsInList n pe (Arm.renameList ξ arms) e
    | [], _ => trivial
    | .mk alts none m :: arms, h => by
        simp only [Arm.VarsInList] at h; simp only [Arm.renameList, Arm.VarsInList]
        exact ⟨Comp.VarsIn.renameLocal _ (by simpa [Nat.add_comm, Nat.add_assoc] using upRen_scoped hξ _) m h.1, Arm.VarsInList.renameLocal ξ hξ arms h.2⟩
    | .mk alts (some g) m :: arms, h => by
        simp only [Arm.VarsInList] at h; simp only [Arm.renameList, Arm.VarsInList]
        exact ⟨Comp.VarsIn.renameLocal _ (by simpa [Nat.add_comm, Nat.add_assoc] using upRen_scoped hξ _) g h.1,
          Comp.VarsIn.renameLocal _ (by simpa [Nat.add_comm, Nat.add_assoc] using upRen_scoped hξ _) m h.2.1, Arm.VarsInList.renameLocal ξ hξ arms h.2.2⟩

  theorem Clause.VarsInList.renameLocal {pe : Nat → Prop} {n d e : Nat} (ξ : Nat → Nat) (hξ : ∀ i, i < d → ξ i < e) : (hs : List Clause) →
      Clause.VarsInList n pe hs d →
      Clause.VarsInList n pe (Clause.renameList ξ hs) e
    | [], _ => trivial
    | .mk o a k m :: cs, h => by
        simp only [Clause.VarsInList] at h; simp only [Clause.renameList, Clause.VarsInList]
        exact ⟨Comp.VarsIn.renameLocal _ (by simpa [Nat.add_comm, Nat.add_assoc] using upRen_scoped hξ _) m h.1, Clause.VarsInList.renameLocal ξ hξ cs h.2⟩
    | .fail e m :: cs, h =>
        ⟨h.1, Comp.VarsIn.renameLocal _ (by simpa [Nat.add_comm, Nat.add_assoc] using upRen_scoped hξ _) m h.2.1, Clause.VarsInList.renameLocal ξ hξ cs h.2.2⟩

end

theorem Val.VarsIn.rename {depth n : Nat} (ξ : Nat → Nat) (v : Val)
    (h : Val.VarsIn n pe v) :
    Val.VarsIn n pe (v.rename ξ) depth :=
  Val.VarsIn.renameLocal ξ (by omega) v h

theorem Val.VarsInList.rename {depth n : Nat} (ξ : Nat → Nat) (vs : List Val)
    (h : Val.VarsInList n pe vs) :
    Val.VarsInList n pe (Val.renameList ξ vs) depth :=
  Val.VarsInList.renameLocal ξ (by omega) vs h

theorem Comp.VarsIn.rename {depth n : Nat} (ξ : Nat → Nat) (m : Comp)
    (h : Comp.VarsIn n pe m) :
    Comp.VarsIn n pe (m.rename ξ) depth :=
  Comp.VarsIn.renameLocal ξ (by omega) m h

theorem Arm.VarsInList.rename {depth n : Nat} (ξ : Nat → Nat) (arms : List Arm)
    (h : Arm.VarsInList n pe arms) :
    Arm.VarsInList n pe (Arm.renameList ξ arms) depth :=
  Arm.VarsInList.renameLocal ξ (by omega) arms h

theorem Clause.VarsInList.rename {depth n : Nat} (ξ : Nat → Nat) (hs : List Clause)
    (h : Clause.VarsInList n pe hs) :
    Clause.VarsInList n pe (Clause.renameList ξ hs) depth :=
  Clause.VarsInList.renameLocal ξ (by omega) hs h

/-- 置き換える値がどれも閉じている。 -/
def ClosedSubst (σ : Nat → Val) : Prop := ∀ i, Val.VarsIn 0 (fun _ => True) (σ i)

theorem ClosedSubst.up {σ} (k : Nat) (h : ClosedSubst σ) : ClosedSubst (upSubst k σ) := by
  intro i; unfold upSubst; split
  · trivial
  · exact Val.VarsIn.rename _ _ (h _)

mutual
  theorem Val.VarsIn.substScoped {n d e : Nat} {σ ρ} (hσ : ClosedSubst σ) (hρ : ∀ i, i < d → (ρ i).Scoped e) : (v : Val) →
      Val.VarsIn n (fun _ => True) v d → Val.VarsIn n (fun _ => True) (v.subst σ ρ) e
    | .var i, _ => by simp only [Val.subst]; exact Val.VarsIn.widen (Nat.zero_le _) (Nat.zero_le _) _ (hσ i)
    | .const _, _ => trivial
    | .fnRef _ _ _, h => h
    | .prim _ _ _, h => h
    | .lam names ps body, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]
        exact ⟨h.1, h.2.1, Comp.VarsIn.substScoped (hσ.up _) (by simpa [Nat.add_comm, Nat.add_assoc] using upLocalSubst_scoped hρ _) body h.2.2⟩
    | .con _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.substScoped hσ hρ args h.2⟩
    | .list elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]; exact Val.VarsInList.substScoped hσ hρ elems h
    | .op _ _, h => h
    | .raise _ _, h => h
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]
        exact ⟨Val.VarsInList.substScoped hσ hρ ks h.1, Val.VarsInList.substScoped hσ hρ vs h.2⟩
    | .setV elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]; exact Val.VarsInList.substScoped hσ hρ elems h
    | .bytesV _, _ => by simp [Val.subst, Val.VarsIn]
    | .dict _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.substScoped hσ hρ args h.2⟩
    | .super v _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]; exact Val.VarsIn.substScoped hσ hρ v h

  theorem Val.VarsInList.substScoped {n d e : Nat} {σ ρ} (hσ : ClosedSubst σ) (hρ : ∀ i, i < d → (ρ i).Scoped e) : (vs : List Val) →
      Val.VarsInList n (fun _ => True) vs d → Val.VarsInList n (fun _ => True) (Val.substList σ vs ρ) e
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h; simp only [Val.substList, Val.VarsInList]
        exact ⟨Val.VarsIn.substScoped hσ hρ v h.1, Val.VarsInList.substScoped hσ hρ vs h.2⟩

  theorem Comp.VarsIn.substScoped {n d e : Nat} {σ ρ} (hσ : ClosedSubst σ) (hρ : ∀ i, i < d → (ρ i).Scoped e) : (m : Comp) →
      Comp.VarsIn n (fun _ => True) m d → Comp.VarsIn n (fun _ => True) (m.subst σ ρ) e
    | .builderLet k body, h => by
        exact ⟨h.1, Comp.VarsIn.substScoped (hσ.up 1)
          (by simpa [Nat.add_comm] using upLocalSubst_scoped hρ 1) body h.2⟩
    | .builderOp k op r args, h => by
        exact ⟨h.1, h.2.1.subst hρ, Val.VarsInList.substScoped hσ hρ args h.2.2⟩
    | .ret v, h => by simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]; exact Val.VarsIn.substScoped hσ hρ v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Comp.VarsIn.substScoped hσ hρ m h.1, Comp.VarsIn.substScoped (hσ.up _) (by simpa [Nat.add_comm, Nat.add_assoc] using upLocalSubst_scoped hρ _) k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.substScoped hσ hρ f h.1, Val.VarsInList.substScoped hσ hρ args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.substScoped hσ hρ v h.1, Comp.VarsIn.substScoped hσ hρ m h.2.1, Comp.VarsIn.substScoped hσ hρ k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.substScoped hσ hρ v h.1, Arm.VarsInList.substScoped hσ hρ arms h.2⟩
    | .lazyC m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]; exact Comp.VarsIn.substScoped hσ hρ m h
    | .escape v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]; exact Val.VarsIn.substScoped hσ hρ v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.substScoped hσ hρ v h.1, Comp.VarsIn.substScoped hσ hρ m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Comp.VarsIn.substScoped hσ hρ m h.1, Clause.VarsInList.substScoped hσ hρ hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.substScoped hσ hρ k h.1, Val.VarsIn.substScoped hσ hρ v h.2⟩
    | .meth d _ _ _ args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.substScoped hσ hρ d h.1, h.2.1, h.2.2.1, Val.VarsInList.substScoped hσ hρ args h.2.2.2⟩

  theorem Arm.VarsInList.substScoped {n d e : Nat} {σ ρ} (hσ : ClosedSubst σ) (hρ : ∀ i, i < d → (ρ i).Scoped e) : (arms : List Arm) →
      Arm.VarsInList n (fun _ => True) arms d →
      Arm.VarsInList n (fun _ => True) (Arm.substList σ arms ρ) e
    | [], _ => trivial
    | .mk alts none m :: arms, h => by
        simp only [Arm.VarsInList] at h; simp only [Arm.substList, Arm.VarsInList]
        exact ⟨Comp.VarsIn.substScoped (hσ.up _) (by simpa [Nat.add_comm, Nat.add_assoc] using upLocalSubst_scoped hρ _) m h.1, Arm.VarsInList.substScoped hσ hρ arms h.2⟩
    | .mk alts (some g) m :: arms, h => by
        simp only [Arm.VarsInList] at h; simp only [Arm.substList, Arm.VarsInList]
        exact ⟨Comp.VarsIn.substScoped (hσ.up _) (by simpa [Nat.add_comm, Nat.add_assoc] using upLocalSubst_scoped hρ _) g h.1,
          Comp.VarsIn.substScoped (hσ.up _) (by simpa [Nat.add_comm, Nat.add_assoc] using upLocalSubst_scoped hρ _) m h.2.1, Arm.VarsInList.substScoped hσ hρ arms h.2.2⟩

  theorem Clause.VarsInList.substScoped {n d e : Nat} {σ ρ} (hσ : ClosedSubst σ) (hρ : ∀ i, i < d → (ρ i).Scoped e) : (hs : List Clause) →
      Clause.VarsInList n (fun _ => True) hs d →
      Clause.VarsInList n (fun _ => True) (Clause.substList σ hs ρ) e
    | [], _ => trivial
    | .mk o a k m :: cs, h => by
        simp only [Clause.VarsInList] at h; simp only [Clause.substList, Clause.VarsInList]
        exact ⟨Comp.VarsIn.substScoped (hσ.up _) (by simpa [Nat.add_comm, Nat.add_assoc] using upLocalSubst_scoped hρ _) m h.1, Clause.VarsInList.substScoped hσ hρ cs h.2⟩
    | .fail e m :: cs, h =>
        ⟨h.1, Comp.VarsIn.substScoped (hσ.up _) (by simpa [Nat.add_comm, Nat.add_assoc] using upLocalSubst_scoped hρ _) m h.2.1, Clause.VarsInList.substScoped hσ hρ cs h.2.2⟩

end

theorem Val.VarsIn.subst {n : Nat} {σ} (hσ : ClosedSubst σ) (v : Val)
    (h : Val.VarsIn n (fun _ => True) v) :
    Val.VarsIn n (fun _ => True) (v.subst σ) :=
  Val.VarsIn.substScoped hσ (by omega) v h

theorem Val.VarsInList.subst {n : Nat} {σ} (hσ : ClosedSubst σ) (vs : List Val)
    (h : Val.VarsInList n (fun _ => True) vs) :
    Val.VarsInList n (fun _ => True) (Val.substList σ vs) :=
  Val.VarsInList.substScoped hσ (by omega) vs h

theorem Comp.VarsIn.subst {n : Nat} {σ} (hσ : ClosedSubst σ) (m : Comp)
    (h : Comp.VarsIn n (fun _ => True) m) :
    Comp.VarsIn n (fun _ => True) (m.subst σ) :=
  Comp.VarsIn.substScoped hσ (by omega) m h

theorem Arm.VarsInList.subst {n : Nat} {σ} (hσ : ClosedSubst σ) (arms : List Arm)
    (h : Arm.VarsInList n (fun _ => True) arms) :
    Arm.VarsInList n (fun _ => True) (Arm.substList σ arms) :=
  Arm.VarsInList.substScoped hσ (by omega) arms h

theorem Clause.VarsInList.subst {n : Nat} {σ} (hσ : ClosedSubst σ) (hs : List Clause)
    (h : Clause.VarsInList n (fun _ => True) hs) :
    Clause.VarsInList n (fun _ => True) (Clause.substList σ hs) :=
  Clause.VarsInList.substScoped hσ (by omega) hs h

theorem ClosedSubst.inst {ws : List Val} (h : Val.VarsInList 0 (fun _ => True) ws) :
    ClosedSubst (instSubst ws) := by
  intro i
  unfold instSubst
  split
  · rename_i hi
    have hi' : i < ws.reverse.length := by simpa using hi
    simp only [List.getElem?_eq_getElem hi', Option.getD_some]
    have hmem : ws.reverse[i] ∈ ws := List.mem_reverse.mp (List.getElem_mem hi')
    generalize ws.reverse[i] = w at hmem ⊢
    clear hi hi'
    induction ws with
    | nil => simp at hmem
    | cons w' ws ih =>
        simp only [Val.VarsInList] at h
        rcases List.mem_cons.mp hmem with e | e
        · rw [e]; exact h.1
        · exact ih h.2 e
  · trivial

theorem Val.VarsIn.instantiate {n depth : Nat} {ws : List Val} {v : Val}
    (hws : Val.VarsInList 0 (fun _ => True) ws) (hv : Val.VarsIn n (fun _ => True) v depth)
    (hd : depth ≤ ws.length := by omega) :
    Val.VarsIn n (fun _ => True) (v.instantiate ws) := by
  exact Val.VarsIn.substScoped (ClosedSubst.inst hws)
    (fun i hi => by simp [instLocalSubst, show i < ws.length by omega, LocalRef.Scoped]) v hv

theorem Comp.VarsIn.instantiate {n depth : Nat} {ws : List Val} {m : Comp}
    (hws : Val.VarsInList 0 (fun _ => True) ws) (hm : Comp.VarsIn n (fun _ => True) m depth)
    (hd : depth ≤ ws.length := by omega) :
    Comp.VarsIn n (fun _ => True) (m.instantiate ws) := by
  exact Comp.VarsIn.substScoped (ClosedSubst.inst hws)
    (fun i hi => by simp [instLocalSubst, show i < ws.length by omega, LocalRef.Scoped]) m hm

end Benitoite.Release
