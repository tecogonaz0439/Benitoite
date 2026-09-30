import Benitoite.Release.Lemmas.Canonical

/-!
# 項が閉じていることの保存（段階 B）

状態の型付けは、状態の中の項が型の変数を含まないことを求める（`StateTy`）。値の置き換え、型の置き換え、
番号の付け替えで、この性質が保たれることを示す。エフェクト変数の条件は問わない（`fun _ => True`）。
-/

namespace Benitoite.Release

/-- 項の中の型の変数の番号が `n` より小さく、継続の型を含まない。 -/
abbrev TyOK (n : Nat) (a : Ty) : Prop := Ty.VarsIn n (fun _ => True) a

/-! ## 型 -/

theorem Ty.applyTo_varsIn {n : Nat} {pe : Nat → Prop} {t : Ty} {as : List Ty} (ht : Ty.VarsIn n pe t)
    (has : Ty.VarsInList n pe as) : Ty.VarsIn n pe (t.applyTo as) := by
  cases t with
  | ctor φ =>
      cases φ <;> cases as <;> simp_all [Ty.applyTo, TyCon.apply, Ty.VarsIn, Ty.VarsInList]
      all_goals (rename_i b; cases b <;> simp_all [Ty.VarsIn, Ty.VarsInList])
  | tvar j => simp_all [Ty.applyTo, Ty.VarsIn]
  | _ => simpa [Ty.applyTo] using ht

mutual
  theorem Ty.VarsIn.substAt {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) :
      (a : Ty) → TyOK (c + ts.length) a → TyOK c (a.substAt c ts es)
    | .base _, _ => by simp [Ty.substAt, Ty.VarsIn]
    | .opaque _, _ => by simp [Ty.substAt, Ty.VarsIn]
    | .data _ args, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]
        exact Ty.VarsInList.substAt es hts args h
    | .list a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts a h
    | .fn ps r _, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts ps h.1, Ty.VarsIn.substAt es hts r h.2.1, fun _ _ => trivial⟩
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
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts a h
    | .lazy a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts a h
    | .cont _ _ _, h => by simp only [Ty.VarsIn] at h
    | .map a b, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]
        exact ⟨Ty.VarsIn.substAt es hts a h.1, Ty.VarsIn.substAt es hts b h.2⟩
    | .set a, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts a h
    | .bytes, _ => by simp [Ty.substAt, Ty.VarsIn]
    | .dict _ τ, h => by
        simp only [Ty.VarsIn] at h; simp only [Ty.substAt, Ty.VarsIn]; exact Ty.VarsIn.substAt es hts τ h
    | .tapp i args, h => by
        simp only [Ty.VarsIn] at h
        have hl := Ty.VarsInList.substAt es hts args h.2
        simp only [Ty.substAt]
        by_cases h1 : i < c
        · simp only [h1, ↓reduceIte, Ty.VarsIn]; exact ⟨trivial, hl⟩
        · have h2 : i - c < ts.length := by omega
          simp only [h1, ↓reduceIte, h2, List.getElem?_eq_getElem h2, Option.getD_some]
          have hu := hts _ (List.getElem_mem h2)
          rw [Ty.shift_of_wf c _ (Ty.WF.mono (Nat.zero_le _) _ (Ty.VarsIn.wf _ hu))]
          exact Ty.applyTo_varsIn (Ty.VarsIn.mono (Nat.zero_le _) (fun _ h => h) _ hu) hl
    | .ctor _, _ => by simp [Ty.substAt, Ty.VarsIn]

  theorem Ty.VarsInList.substAt {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) :
      (as : List Ty) → Ty.VarsInList (c + ts.length) (fun _ => True) as →
      Ty.VarsInList c (fun _ => True) (as.map (Ty.substAt c ts es))
    | [], _ => trivial
    | a :: as, h => by
        simp only [Ty.VarsInList] at h; simp only [List.map_cons, Ty.VarsInList]
        exact ⟨Ty.VarsIn.substAt es hts a h.1, Ty.VarsInList.substAt es hts as h.2⟩
end

theorem Eff.RhosInList.true (es : List Eff) : Eff.RhosInList (fun _ => True) es := by
  induction es with
  | nil => trivial
  | cons e es ih => exact ⟨fun _ _ => trivial, ih⟩

/-! ## 値と計算の型の置き換え -/

mutual
  theorem Val.VarsIn.substTyAt {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) :
      (v : Val) → Val.VarsIn (c + ts.length) (fun _ => True) v →
      Val.VarsIn c (fun _ => True) (v.substTyAt c ts es)
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ tys _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts tys h.1, Eff.RhosInList.true _⟩
    | .prim _ tys _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts tys h.1, Eff.RhosInList.true _⟩
    | .lam ps body, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts ps h.1, Comp.VarsIn.substTyAt es hts body h.2⟩
    | .con _ tys args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts tys h.1, Val.VarsInList.substTyAt es hts args h.2⟩
    | .list elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact Val.VarsInList.substTyAt es hts elems h
    | .op _ tys, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact Ty.VarsInList.substAt es hts tys h
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Val.VarsInList.substTyAt es hts ks h.1, Val.VarsInList.substTyAt es hts vs h.2⟩
    | .setV elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact Val.VarsInList.substTyAt es hts elems h
    | .bytesV _, _ => by simp [Val.substTyAt, Val.VarsIn]
    | .dict _ tys args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact ⟨Ty.VarsInList.substAt es hts tys h.1, Val.VarsInList.substTyAt es hts args h.2⟩
    | .super v _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.substTyAt, Val.VarsIn]
        exact Val.VarsIn.substTyAt es hts v h

  theorem Val.VarsInList.substTyAt {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) :
      (vs : List Val) → Val.VarsInList (c + ts.length) (fun _ => True) vs →
      Val.VarsInList c (fun _ => True) (Val.substTyAtList c ts es vs)
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h; simp only [Val.substTyAtList, Val.VarsInList]
        exact ⟨Val.VarsIn.substTyAt es hts v h.1, Val.VarsInList.substTyAt es hts vs h.2⟩

  theorem Comp.VarsIn.substTyAt {c : Nat} {ts : List Ty} (es : List Eff) (hts : ∀ u ∈ ts, TyOK 0 u) :
      (m : Comp) → Comp.VarsIn (c + ts.length) (fun _ => True) m →
      Comp.VarsIn c (fun _ => True) (m.substTyAt c ts es)
    | .ret v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact Val.VarsIn.substTyAt es hts v h
    | .letIn m n, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Comp.VarsIn.substTyAt es hts m h.1, Comp.VarsIn.substTyAt es hts n h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts f h.1, Val.VarsInList.substTyAt es hts args h.2⟩
    | .ite v m n, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts v h.1, Comp.VarsIn.substTyAt es hts m h.2.1,
          Comp.VarsIn.substTyAt es hts n h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts v h.1, Comp.VarsInArms.substTyAt es hts arms h.2⟩
    | .lazyC m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact Comp.VarsIn.substTyAt es hts m h
    | .escape v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact Val.VarsIn.substTyAt es hts v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts v h.1, Comp.VarsIn.substTyAt es hts m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Comp.VarsIn.substTyAt es hts m h.1, Clause.VarsInList.substTyAt es hts hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts k h.1, Val.VarsIn.substTyAt es hts v h.2⟩
    | .meth d _ tys _ args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.substTyAt, Comp.VarsIn]
        exact ⟨Val.VarsIn.substTyAt es hts d h.1, Ty.VarsInList.substAt es hts tys h.2.1,
          Eff.RhosInList.true _, Val.VarsInList.substTyAt es hts args h.2.2.2⟩

  theorem Comp.VarsInArms.substTyAt {c : Nat} {ts : List Ty} (es : List Eff)
      (hts : ∀ u ∈ ts, TyOK 0 u) :
      (arms : List (Pat × Comp)) → Comp.VarsInArms (c + ts.length) (fun _ => True) arms →
      Comp.VarsInArms c (fun _ => True) (Comp.substTyAtArms c ts es arms)
    | [], _ => trivial
    | (p, m) :: arms, h => by
        simp only [Comp.VarsInArms] at h; simp only [Comp.substTyAtArms, Comp.VarsInArms]
        exact ⟨Comp.VarsIn.substTyAt es hts m h.1, Comp.VarsInArms.substTyAt es hts arms h.2⟩

  theorem Clause.VarsInList.substTyAt {c : Nat} {ts : List Ty} (es : List Eff)
      (hts : ∀ u ∈ ts, TyOK 0 u) :
      (hs : List Clause) → Clause.VarsInList (c + ts.length) (fun _ => True) hs →
      Clause.VarsInList c (fun _ => True) (Clause.substTyAtList c ts es hs)
    | [], _ => trivial
    | .mk o n k m :: cs, h => by
        simp only [Clause.VarsInList] at h; simp only [Clause.substTyAtList, Clause.VarsInList]
        refine ⟨?_, Clause.VarsInList.substTyAt es hts cs h.2⟩
        have := Comp.VarsIn.substTyAt (c := c + k) es hts m (by
          have := h.1; rwa [show c + ts.length + k = c + k + ts.length by omega] at this)
        exact this
end

/-! ## 値の範囲の単調性と、番号の付け替えと値の置き換え -/

mutual
  theorem Val.VarsIn.mono {n n' : Nat} (hn : n ≤ n') : (v : Val) → Val.VarsIn n (fun _ => True) v →
      Val.VarsIn n' (fun _ => True) v
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ tys _, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, h.2⟩
    | .prim _ tys _, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, h.2⟩
    | .lam ps body, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Comp.VarsIn.mono hn body h.2⟩
    | .con _ tys args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Val.VarsInList.mono hn args h.2⟩
    | .list elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.mono hn elems h
    | .op _ tys, h => by simp only [Val.VarsIn] at h ⊢; exact Ty.VarsInList.mono hn (fun _ h => h) _ h
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h ⊢; exact ⟨Val.VarsInList.mono hn ks h.1, Val.VarsInList.mono hn vs h.2⟩
    | .setV elems, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsInList.mono hn elems h
    | .bytesV _, _ => by simp [Val.VarsIn]
    | .dict _ tys args, h => by
        simp only [Val.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hn (fun _ h => h) _ h.1, Val.VarsInList.mono hn args h.2⟩
    | .super v _, h => by simp only [Val.VarsIn] at h ⊢; exact Val.VarsIn.mono hn v h

  theorem Val.VarsInList.mono {n n' : Nat} (hn : n ≤ n') : (vs : List Val) →
      Val.VarsInList n (fun _ => True) vs → Val.VarsInList n' (fun _ => True) vs
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h ⊢; exact ⟨Val.VarsIn.mono hn v h.1, Val.VarsInList.mono hn vs h.2⟩

  theorem Comp.VarsIn.mono {n n' : Nat} (hn : n ≤ n') : (m : Comp) → Comp.VarsIn n (fun _ => True) m →
      Comp.VarsIn n' (fun _ => True) m
    | .ret v, h => by simp only [Comp.VarsIn] at h ⊢; exact Val.VarsIn.mono hn v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Comp.VarsIn.mono hn m h.1, Comp.VarsIn.mono hn k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.mono hn f h.1, Val.VarsInList.mono hn args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h ⊢
        exact ⟨Val.VarsIn.mono hn v h.1, Comp.VarsIn.mono hn m h.2.1, Comp.VarsIn.mono hn k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h ⊢; exact ⟨Val.VarsIn.mono hn v h.1, Comp.VarsInArms.mono hn arms h.2⟩
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
        exact ⟨Val.VarsIn.mono hn d h.1, Ty.VarsInList.mono hn (fun _ h => h) _ h.2.1, h.2.2.1,
          Val.VarsInList.mono hn args h.2.2.2⟩

  theorem Comp.VarsInArms.mono {n n' : Nat} (hn : n ≤ n') : (arms : List (Pat × Comp)) →
      Comp.VarsInArms n (fun _ => True) arms → Comp.VarsInArms n' (fun _ => True) arms
    | [], _ => trivial
    | (_, m) :: arms, h => by
        simp only [Comp.VarsInArms] at h ⊢; exact ⟨Comp.VarsIn.mono hn m h.1, Comp.VarsInArms.mono hn arms h.2⟩

  theorem Clause.VarsInList.mono {n n' : Nat} (hn : n ≤ n') : (hs : List Clause) →
      Clause.VarsInList n (fun _ => True) hs → Clause.VarsInList n' (fun _ => True) hs
    | [], _ => trivial
    | .mk _ _ k m :: cs, h => by
        simp only [Clause.VarsInList] at h ⊢
        exact ⟨Comp.VarsIn.mono (by omega) m h.1, Clause.VarsInList.mono hn cs h.2⟩
end

mutual
  theorem Val.VarsIn.rename {n : Nat} (ξ : Nat → Nat) : (v : Val) → Val.VarsIn n (fun _ => True) v →
      Val.VarsIn n (fun _ => True) (v.rename ξ)
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ _ _, h => h
    | .prim _ _ _, h => h
    | .lam ps body, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, Comp.VarsIn.rename _ body h.2⟩
    | .con _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.rename ξ args h.2⟩
    | .list elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsInList.rename ξ elems h
    | .op _ _, h => h
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨Val.VarsInList.rename ξ ks h.1, Val.VarsInList.rename ξ vs h.2⟩
    | .setV elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsInList.rename ξ elems h
    | .bytesV _, _ => by simp [Val.rename, Val.VarsIn]
    | .dict _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.rename ξ args h.2⟩
    | .super v _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsIn.rename ξ v h

  theorem Val.VarsInList.rename {n : Nat} (ξ : Nat → Nat) : (vs : List Val) →
      Val.VarsInList n (fun _ => True) vs → Val.VarsInList n (fun _ => True) (Val.renameList ξ vs)
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h; simp only [Val.renameList, Val.VarsInList]
        exact ⟨Val.VarsIn.rename ξ v h.1, Val.VarsInList.rename ξ vs h.2⟩

  theorem Comp.VarsIn.rename {n : Nat} (ξ : Nat → Nat) : (m : Comp) → Comp.VarsIn n (fun _ => True) m →
      Comp.VarsIn n (fun _ => True) (m.rename ξ)
    | .ret v, h => by simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Val.VarsIn.rename ξ v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Comp.VarsIn.rename ξ m h.1, Comp.VarsIn.rename _ k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.rename ξ f h.1, Val.VarsInList.rename ξ args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.rename ξ v h.1, Comp.VarsIn.rename ξ m h.2.1, Comp.VarsIn.rename ξ k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.rename ξ v h.1, Comp.VarsInArms.rename ξ arms h.2⟩
    | .lazyC m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Comp.VarsIn.rename ξ m h
    | .escape v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Val.VarsIn.rename ξ v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.rename ξ v h.1, Comp.VarsIn.rename ξ m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Comp.VarsIn.rename ξ m h.1, Clause.VarsInList.rename ξ hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.rename ξ k h.1, Val.VarsIn.rename ξ v h.2⟩
    | .meth d _ _ _ args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.rename ξ d h.1, h.2.1, h.2.2.1, Val.VarsInList.rename ξ args h.2.2.2⟩

  theorem Comp.VarsInArms.rename {n : Nat} (ξ : Nat → Nat) : (arms : List (Pat × Comp)) →
      Comp.VarsInArms n (fun _ => True) arms →
      Comp.VarsInArms n (fun _ => True) (Comp.renameArms ξ arms)
    | [], _ => trivial
    | (p, m) :: arms, h => by
        simp only [Comp.VarsInArms] at h; simp only [Comp.renameArms, Comp.VarsInArms]
        exact ⟨Comp.VarsIn.rename _ m h.1, Comp.VarsInArms.rename ξ arms h.2⟩

  theorem Clause.VarsInList.rename {n : Nat} (ξ : Nat → Nat) : (hs : List Clause) →
      Clause.VarsInList n (fun _ => True) hs →
      Clause.VarsInList n (fun _ => True) (Clause.renameList ξ hs)
    | [], _ => trivial
    | .mk o a k m :: cs, h => by
        simp only [Clause.VarsInList] at h; simp only [Clause.renameList, Clause.VarsInList]
        exact ⟨Comp.VarsIn.rename _ m h.1, Clause.VarsInList.rename ξ cs h.2⟩
end

/-- 置き換える値がどれも閉じている。 -/
def ClosedSubst (σ : Nat → Val) : Prop := ∀ i, Val.VarsIn 0 (fun _ => True) (σ i)

theorem ClosedSubst.up {σ} (k : Nat) (h : ClosedSubst σ) : ClosedSubst (upSubst k σ) := by
  intro i; unfold upSubst; split
  · trivial
  · exact Val.VarsIn.rename _ _ (h _)

mutual
  theorem Val.VarsIn.subst {n : Nat} {σ} (hσ : ClosedSubst σ) : (v : Val) →
      Val.VarsIn n (fun _ => True) v → Val.VarsIn n (fun _ => True) (v.subst σ)
    | .var i, _ => by simp only [Val.subst]; exact Val.VarsIn.mono (Nat.zero_le _) _ (hσ i)
    | .const _, _ => trivial
    | .fnRef _ _ _, h => h
    | .prim _ _ _, h => h
    | .lam ps body, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]
        exact ⟨h.1, Comp.VarsIn.subst (hσ.up _) body h.2⟩
    | .con _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.subst hσ args h.2⟩
    | .list elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]; exact Val.VarsInList.subst hσ elems h
    | .op _ _, h => h
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]
        exact ⟨Val.VarsInList.subst hσ ks h.1, Val.VarsInList.subst hσ vs h.2⟩
    | .setV elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]; exact Val.VarsInList.subst hσ elems h
    | .bytesV _, _ => by simp [Val.subst, Val.VarsIn]
    | .dict _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.subst hσ args h.2⟩
    | .super v _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.subst, Val.VarsIn]; exact Val.VarsIn.subst hσ v h

  theorem Val.VarsInList.subst {n : Nat} {σ} (hσ : ClosedSubst σ) : (vs : List Val) →
      Val.VarsInList n (fun _ => True) vs → Val.VarsInList n (fun _ => True) (Val.substList σ vs)
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h; simp only [Val.substList, Val.VarsInList]
        exact ⟨Val.VarsIn.subst hσ v h.1, Val.VarsInList.subst hσ vs h.2⟩

  theorem Comp.VarsIn.subst {n : Nat} {σ} (hσ : ClosedSubst σ) : (m : Comp) →
      Comp.VarsIn n (fun _ => True) m → Comp.VarsIn n (fun _ => True) (m.subst σ)
    | .ret v, h => by simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]; exact Val.VarsIn.subst hσ v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Comp.VarsIn.subst hσ m h.1, Comp.VarsIn.subst (hσ.up _) k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.subst hσ f h.1, Val.VarsInList.subst hσ args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.subst hσ v h.1, Comp.VarsIn.subst hσ m h.2.1, Comp.VarsIn.subst hσ k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.subst hσ v h.1, Comp.VarsInArms.subst hσ arms h.2⟩
    | .lazyC m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]; exact Comp.VarsIn.subst hσ m h
    | .escape v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]; exact Val.VarsIn.subst hσ v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.subst hσ v h.1, Comp.VarsIn.subst hσ m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Comp.VarsIn.subst hσ m h.1, Clause.VarsInList.subst hσ hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.subst hσ k h.1, Val.VarsIn.subst hσ v h.2⟩
    | .meth d _ _ _ args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.subst, Comp.VarsIn]
        exact ⟨Val.VarsIn.subst hσ d h.1, h.2.1, h.2.2.1, Val.VarsInList.subst hσ args h.2.2.2⟩

  theorem Comp.VarsInArms.subst {n : Nat} {σ} (hσ : ClosedSubst σ) : (arms : List (Pat × Comp)) →
      Comp.VarsInArms n (fun _ => True) arms →
      Comp.VarsInArms n (fun _ => True) (Comp.substArms σ arms)
    | [], _ => trivial
    | (p, m) :: arms, h => by
        simp only [Comp.VarsInArms] at h; simp only [Comp.substArms, Comp.VarsInArms]
        exact ⟨Comp.VarsIn.subst (hσ.up _) m h.1, Comp.VarsInArms.subst hσ arms h.2⟩

  theorem Clause.VarsInList.subst {n : Nat} {σ} (hσ : ClosedSubst σ) : (hs : List Clause) →
      Clause.VarsInList n (fun _ => True) hs →
      Clause.VarsInList n (fun _ => True) (Clause.substList σ hs)
    | [], _ => trivial
    | .mk o a k m :: cs, h => by
        simp only [Clause.VarsInList] at h; simp only [Clause.substList, Clause.VarsInList]
        exact ⟨Comp.VarsIn.subst (hσ.up _) m h.1, Clause.VarsInList.subst hσ cs h.2⟩
end

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

theorem Val.VarsIn.instantiate {n : Nat} {ws : List Val} {v : Val}
    (hws : Val.VarsInList 0 (fun _ => True) ws) (hv : Val.VarsIn n (fun _ => True) v) :
    Val.VarsIn n (fun _ => True) (v.instantiate ws) :=
  Val.VarsIn.subst (ClosedSubst.inst hws) v hv

theorem Comp.VarsIn.instantiate {n : Nat} {ws : List Val} {m : Comp}
    (hws : Val.VarsInList 0 (fun _ => True) ws) (hm : Comp.VarsIn n (fun _ => True) m) :
    Comp.VarsIn n (fun _ => True) (m.instantiate ws) :=
  Comp.VarsIn.subst (ClosedSubst.inst hws) m hm

end Benitoite.Release
