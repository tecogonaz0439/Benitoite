import Benitoite.Release.Refinement.FiniteFunctionView

namespace Benitoite.Release.Refinement
open Order

mutual
  /-- 型のすべての子と、埋め込まれた効果を正規化する。 -/
  def Ty.normWith (s : List Atom) : Ty → Ty
    | .base b => .base b
    | .opaque o r => .opaque o r
    | .data d as => .data d (Ty.normTysWith s as)
    | .list a => .list (Ty.normWith s a)
    | .fn ns ps r e => .fn ns (Ty.normTysWith s ps) (Ty.normWith s r) (Eff.normWith s e)
    | .tvar i => .tvar i
    | .reference a => .reference (Ty.normWith s a)
    | .lazy a => .lazy (Ty.normWith s a)
    | .cont b t e => .cont (Ty.normWith s b) (Ty.normWith s t) (Eff.normWith s e)
    | .map a b => .map (Ty.normWith s a) (Ty.normWith s b)
    | .set a => .set (Ty.normWith s a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (Ty.normWith s a)
    | .tapp i as => .tapp i (Ty.normTysWith s as)
    | .ctor c => .ctor c
    | .refined a p => Ty.refineNorm (Ty.normWith s a) p
    | .dependentFn t => Ty.foldFnWith s (Tel.normWith s t)
    | .external id as => .external id (Ty.normTysWith s as)
    | .scoped o k ix => .scoped o k ix
    | .pathBases => .pathBases
    | .scopePattern k => .scopePattern k
  termination_by structural t => t

  def Tel.normWith (s : List Atom) : Tel → Tel
    | .done r e => .done (Ty.normWith s r) (Eff.normWith s e)
    | .param n a t => .param n (Ty.normWith s a) (Tel.normWith s t)
  termination_by structural t => t

  /-- 型列も同じ構造再帰に含める。 -/
  def Ty.normTysWith (s : List Atom) : List Ty → List Ty
    | [] => []
    | a :: as => (Ty.normWith s a) :: Ty.normTysWith s as
  termination_by structural as => as

  /-- 名前と行を保ち、子の正規化後に Fail 列を整列する。 -/
  def Eff.normWith (s : List Atom) : Eff → Eff
    | .mk a fs => .mk a (sortUnique (tyCompareWith s) (Ty.normTysWith s fs))
  termination_by structural e => e
end

private theorem insertUnique_congrOn {p : α → Prop} (c d : α → α → Ordering)
    (hc : ∀ a b, p a → p b → c a b = d a b) (a : α) (ha : p a)
    (bs : List α) (hb : ∀ b ∈ bs, p b) : insertUnique c a bs = insertUnique d a bs := by
  induction bs with
  | nil => rfl
  | cons b bs ih =>
    simp only [insertUnique, hc a b ha (hb b List.mem_cons_self)]
    cases d a b <;> simp_all

private theorem sortUnique_congrOn {p : α → Prop} (c d : α → α → Ordering)
    [Std.LawfulEqCmp d] [Std.TransCmp d]
    (hc : ∀ a b, p a → p b → c a b = d a b)
    (as : List α) (ha : ∀ a ∈ as, p a) : sortUnique c as = sortUnique d as := by
  induction as with
  | nil => rfl
  | cons a as ih =>
    simp only [sortUnique]
    rw [ih (fun b hb => ha b (List.mem_cons_of_mem a hb))]
    exact insertUnique_congrOn c d hc a (ha a List.mem_cons_self) _
      (fun b hb => ha b (List.mem_cons_of_mem a (mem_sortUnique.mp hb)))

mutual
  theorem Ty.normWith_eq_norm (s : List Atom) (t : Ty) (h : t.Support (· ∈ s)) :
      t.normWith s = t.norm := by
    cases t <;> simp only [Ty.Support] at h
    all_goals simp only [Ty.normWith, Ty.norm]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.normWith_eq_norm s _ h)
      | exact congrArg _ (Ty.normTysWith_eq_norm s _ h)
      | skip
    case refined a q => rw [Ty.normWith_eq_norm s a h]
    case dependentFn t =>
      rw [Tel.normWith_eq_norm s t h, Ty.foldFnWith_eq_foldFn s _ (Tel.norm_support t h)]
    case fn ns ps r e => rw [Ty.normTysWith_eq_norm s ps h.1,
      Ty.normWith_eq_norm s r h.2.1, Eff.normWith_eq_norm_of_fails s e ((Eff.support_iff e).mp h.2.2).2]
    case cont a b e => rw [Ty.normWith_eq_norm s a h.1,
      Ty.normWith_eq_norm s b h.2.1, Eff.normWith_eq_norm_of_fails s e ((Eff.support_iff e).mp h.2.2).2]
    case map a b => rw [Ty.normWith_eq_norm s a h.1, Ty.normWith_eq_norm s b h.2]

  theorem Ty.normTysWith_eq_norm (s : List Atom) (ts : List Ty)
      (h : Ty.SupportList (· ∈ s) ts) : Ty.normTysWith s ts = Ty.normTys ts := by
    cases ts with
    | nil => rfl
    | cons t ts =>
      simp only [Ty.normTysWith, Ty.normTys]
      rw [Ty.normWith_eq_norm s t h.1, Ty.normTysWith_eq_norm s ts h.2]

  theorem Eff.normWith_eq_norm_of_fails (s : List Atom) (e : Eff)
      (h : Ty.SupportList (· ∈ s) e.fails) :
      Eff.normWith s e = Eff.norm e := by
    cases e with
    | mk a fs =>
      simp only [Eff.normWith, Eff.norm]
      rw [Ty.normTysWith_eq_norm s fs h]
      congr 1
      exact sortUnique_congrOn _ _ (compareWith_eq_compare s) _
        (Ty.SupportList.iff.mp (Ty.normTys_support fs h))
  theorem Tel.normWith_eq_norm (s : List Atom) (t : Tel) (h : t.Support (· ∈ s)) :
      Tel.normWith s t = Tel.norm t := by
    cases t with
    | done r e =>
      simp only [Tel.normWith, Tel.norm, Ty.normWith_eq_norm s r h.1,
        Eff.normWith_eq_norm_of_fails s e ((Eff.support_iff e).mp h.2).2]
    | param n a t =>
      simp only [Tel.normWith, Tel.norm, Ty.normWith_eq_norm s a h.1, Tel.normWith_eq_norm s t h.2]
end

/-- 最上位の原子関数は変更しないので、正規化の一致にはFail内部の支持だけで足りる。 -/
theorem Eff.normWith_eq_norm (s : List Atom) (e : Eff) (h : Eff.Support (· ∈ s) e) :
    Eff.normWith s e = Eff.norm e :=
  Eff.normWith_eq_norm_of_fails s e ((Eff.support_iff e).mp h).2


@[simp] theorem Ty.normTysWith_eq_map (s : List Atom) (ts : List Ty) :
    Ty.normTysWith s ts = ts.map (Ty.normWith s) := by
  induction ts with
  | nil => rfl
  | cons t ts ih => simp only [Ty.normTysWith, List.map_cons, ih]

theorem Ty.normWith_support (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) :
    (a.normWith s).Support (· ∈ s) := by
  rw [Ty.normWith_eq_norm s a h]
  exact Ty.norm_support a h

theorem Ty.normWith_canonical (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) :
    (a.normWith s).Canonical := by
  rw [Ty.normWith_eq_norm s a h]
  exact Ty.norm_idem a

theorem Ty.normWith_idem (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) :
    (a.normWith s).normWith s = a.normWith s := by
  rw [Ty.normWith_eq_norm s _ (Ty.normWith_support s a h), Ty.normWith_eq_norm s a h, Ty.norm_idem]

theorem Ty.normWith_support_independent (s t : List Atom) (a : Ty)
    (hs : a.Support (· ∈ s)) (ht : a.Support (· ∈ t)) : a.normWith s = a.normWith t :=
  (Ty.normWith_eq_norm s a hs).trans (Ty.normWith_eq_norm t a ht).symm

theorem Eff.normWith_support (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) :
    (a.normWith s).Support (· ∈ s) := by
  rw [Eff.normWith_eq_norm s a h]
  exact Eff.norm_support a h

theorem Eff.normWith_canonical (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) :
    (a.normWith s).Canonical := by
  rw [Eff.normWith_eq_norm s a h]
  exact Eff.norm_idem a

theorem Eff.normWith_idem (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) :
    (a.normWith s).normWith s = a.normWith s := by
  rw [Eff.normWith_eq_norm s _ (Eff.normWith_support s a h), Eff.normWith_eq_norm s a h, Eff.norm_idem]

theorem Eff.normWith_support_independent (s t : List Atom) (a : Eff)
    (hs : a.Support (· ∈ s)) (ht : a.Support (· ∈ t)) : a.normWith s = a.normWith t :=
  (Eff.normWith_eq_norm s a hs).trans (Eff.normWith_eq_norm t a ht).symm

end Benitoite.Release.Refinement
