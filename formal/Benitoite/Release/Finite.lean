import Benitoite.Release.TypeSupport
import Benitoite.Release.Order.FiniteAtoms

/-! 再帰的な有限支持の上で計算する型の比較と正規化。 -/
namespace Benitoite.Release
open Order

/-- 効果の構成子を露出せず、再帰的な支持を参照する。 -/
theorem Eff.support_iff {p : Atom → Prop} (e : Eff) :
    Eff.Support p e ↔ (∀ x, Eff.test e x = true → p x) ∧ Ty.SupportList p e.fails := by
  cases e
  rfl

mutual
  /-- 型を構造再帰で比較する。非計算的な選択を使うのは atomsCompareWith s だけである。 -/
  def tyCompareWith (s : List Atom) : Ty → Ty → Ordering
    | .base a, .base b => compare a.rank b.rank
    | .opaque a, .opaque b => stringCompare a b
    | .data d as, .data e bs => (stringCompare d e).then (tysCompareWith s as bs)
    | .list a, .list b => tyCompareWith s a b
    | .fn ns as a e, .fn ms bs b f =>
        (List.compareLex stringCompare ns ms).then
          ((tysCompareWith s as bs).then ((tyCompareWith s a b).then (effCompareWith s e f)))
    | .tvar i, .tvar j => compare i j
    | .reference a, .reference b => tyCompareWith s a b
    | .lazy a, .lazy b => tyCompareWith s a b
    | .cont a b e, .cont c d f =>
        (tyCompareWith s a c).then ((tyCompareWith s b d).then (effCompareWith s e f))
    | .map a b, .map c d => (tyCompareWith s a c).then (tyCompareWith s b d)
    | .set a, .set b => tyCompareWith s a b
    | .bytes, .bytes => .eq
    | .dict cl a, .dict dl b => (stringCompare cl dl).then (tyCompareWith s a b)
    | .tapp i as, .tapp j bs => (compare i j).then (tysCompareWith s as bs)
    | .ctor a, .ctor b => tyConCompare a b
    | a, b => compare a.rank b.rank

  /-- 効果は名前・行の関数、Fail 列の順で比較する。 -/
  def effCompareWith (s : List Atom) : Eff → Eff → Ordering
    | .mk a fs, .mk b gs => (atomsCompareWith s a b).then (tysCompareWith s fs gs)

  /-- 型列の辞書式比較。空列では型の比較を呼ばない。 -/
  def tysCompareWith (s : List Atom) : List Ty → List Ty → Ordering
    | [], [] => .eq
    | [], _ :: _ => .lt
    | _ :: _, [] => .gt
    | a :: as, b :: bs => (tyCompareWith s a b).then (tysCompareWith s as bs)
end

mutual
  theorem compareWith_eq_compare (s : List Atom) (a b : Ty)
      (ha : a.Support (· ∈ s)) (hb : b.Support (· ∈ s)) :
      tyCompareWith s a b = tyCompare a b := by
    cases a <;> cases b <;> first | rfl | skip
    all_goals simp_all only [tyCompareWith, tyCompare, Ty.Support,
      comparesWith_eq_compare, compareWith_eq_compare, effCompareWith_eq_compare]

  theorem comparesWith_eq_compare (s : List Atom) (as bs : List Ty)
      (ha : Ty.SupportList (· ∈ s) as) (hb : Ty.SupportList (· ∈ s) bs) :
      tysCompareWith s as bs = tysCompare as bs := by
    cases as <;> cases bs <;> first | rfl | skip
    simp only [tysCompareWith, tysCompare]
    rw [compareWith_eq_compare s _ _ ha.1 hb.1,
      comparesWith_eq_compare s _ _ ha.2 hb.2]

  theorem effCompareWith_eq_compare (s : List Atom) (e f : Eff)
      (he : Eff.Support (· ∈ s) e) (hf : Eff.Support (· ∈ s) f) :
      effCompareWith s e f = effCompare e f := by
    cases e; cases f
    simp only [effCompareWith, effCompare]
    rw [atomsCompareWith_eq_compare he.1 hf.1,
      comparesWith_eq_compare s _ _ he.2 hf.2]
end

mutual
  /-- 型のすべての子と、埋め込まれた効果を正規化する。 -/
  def Ty.normWith (s : List Atom) : Ty → Ty
    | .base b => .base b
    | .opaque o => .opaque o
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

mutual
  /-- 旧型では、支持の有限性によらず同じ型を保持する。 -/
  theorem Ty.normWith_legacy (s : List Atom) (t : Ty) (h : t.Legacy) : t.normWith s = t := by
    cases t <;> simp only [Ty.Legacy] at h <;> simp only [Ty.normWith]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.normWith_legacy s _ h)
      | exact congrArg _ (Ty.normTysWith_legacy s _ h)
      | skip
    case fn ns ps r e => rw [Ty.normTysWith_legacy s ps h.1,
      Ty.normWith_legacy s r h.2.1, Eff.normWith_legacy s e h.2.2]
    case cont a b e => rw [Ty.normWith_legacy s a h.1,
      Ty.normWith_legacy s b h.2.1, Eff.normWith_legacy s e h.2.2]
    case map a b => rw [Ty.normWith_legacy s a h.1, Ty.normWith_legacy s b h.2]
  theorem Ty.normTysWith_legacy (s : List Atom) (ts : List Ty) (h : Ty.LegacyTys ts) :
      Ty.normTysWith s ts = ts := by
    cases ts with
    | nil => rfl
    | cons t ts => simp only [Ty.normTysWith, Ty.normWith_legacy s t h.1,
        Ty.normTysWith_legacy s ts h.2]
  theorem Eff.normWith_legacy (s : List Atom) (e : Eff) (h : Eff.Legacy e) :
      Eff.normWith s e = e := by
    cases e with
    | mk a fs => cases h; rfl
end

theorem Ty.normWith_support {s t} (h : Ty.Support (· ∈ s) t) :
    Ty.Support (· ∈ s) (t.normWith s) := by
  rw [Ty.normWith_eq_norm s t h]
  exact Ty.norm_support t h

theorem Eff.normWith_support {s e} (h : Eff.Support (· ∈ s) e) :
    Eff.Support (· ∈ s) (Eff.normWith s e) := by
  rw [Eff.normWith_eq_norm s e h]
  exact Eff.norm_support e h

theorem Ty.normWith_canonical {s t} (h : Ty.Support (· ∈ s) t) : (t.normWith s).Canonical := by
  rw [Ty.normWith_eq_norm s t h]
  exact Ty.norm_idem t

theorem Eff.normWith_canonical {s e} (h : Eff.Support (· ∈ s) e) :
    Eff.Canonical (Eff.normWith s e) := by
  rw [Eff.normWith_eq_norm s e h]
  exact Eff.norm_idem e

theorem Ty.normWith_idem {s t} (h : Ty.Support (· ∈ s) t) :
    (t.normWith s).normWith s = t.normWith s := by
  rw [Ty.normWith_eq_norm s _ (Ty.normWith_support h), Ty.normWith_eq_norm s t h,
    Ty.norm_idem]

theorem Eff.normWith_idem {s e} (h : Eff.Support (· ∈ s) e) :
    Eff.normWith s (Eff.normWith s e) = Eff.normWith s e := by
  rw [Eff.normWith_eq_norm s _ (Eff.normWith_support h), Eff.normWith_eq_norm s e h,
    Eff.norm_idem]

/-- 支持が両方を覆えば、集合の順序・重複・余分な原子によらない。 -/
theorem compareWith_support_independent {s u a b}
    (ha : Ty.Support (· ∈ s) a) (hb : Ty.Support (· ∈ s) b)
    (ha' : Ty.Support (· ∈ u) a) (hb' : Ty.Support (· ∈ u) b) :
    tyCompareWith s a b = tyCompareWith u a b :=
  (compareWith_eq_compare s a b ha hb).trans (compareWith_eq_compare u a b ha' hb').symm

theorem Ty.normWith_support_independent {s u t} (h : Ty.Support (· ∈ s) t)
    (h' : Ty.Support (· ∈ u) t) : t.normWith s = t.normWith u :=
  (Ty.normWith_eq_norm s t h).trans (Ty.normWith_eq_norm u t h').symm

theorem Eff.normWith_support_independent {s u e} (h : Eff.Support (· ∈ s) e)
    (h' : Eff.Support (· ∈ u) e) : Eff.normWith s e = Eff.normWith u e :=
  (Eff.normWith_eq_norm s e h).trans (Eff.normWith_eq_norm u e h').symm

end Benitoite.Release
