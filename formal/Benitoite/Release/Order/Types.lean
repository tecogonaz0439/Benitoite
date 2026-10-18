import Benitoite.Release.Types
import Benitoite.Release.Order.Labels
import Benitoite.Release.Order.Tree
import Benitoite.Release.Order.SortUnique

/-!
# 共有する型の辞書式順序

構成子とその欄を宣言順に比較し、ラベル付きの木への単射から全順序を得る。
型付けの等号を変えず、型の列の整列に使う（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release

open Std Order

/-- 基本型の順位。構成子の宣言順を固定する。 -/
def BaseTy.rank : BaseTy → Nat
  | .integer => 0 | .float => 1 | .string => 2 | .character => 3
  | .boolean => 4 | .unit => 5 | .byte => 6 | .decimal => 7
  | .integer8 => 8 | .integer16 => 9 | .integer32 => 10
  | .unsignedInteger16 => 11 | .unsignedInteger32 => 12
  | .unsignedInteger64 => 13 | .float32 => 14

/-- 順位は基本型を区別する。 -/
theorem BaseTy.rank_injective {a b : BaseTy} (h : a.rank = b.rank) : a = b := by
  cases a <;> cases b <;> simp_all [BaseTy.rank]

/-- 型構成子の順位。data の名前は順位の後に比較する。 -/
def TyCon.rank : TyCon → Nat
  | .data _ => 0 | .list => 1 | .set => 2 | .map => 3 | .reference => 4 | .lazy => 5

/-- 型の順位。同じ構成子の中では、欄を宣言順に比較する。 -/
def Ty.rank : Ty → Nat
  | .base _ => 0 | .opaque _ => 1 | .data _ _ => 2 | .list _ => 3
  | .fn _ _ _ _ => 4 | .tvar _ => 5 | .reference _ => 6 | .lazy _ => 7
  | .cont _ _ _ => 8 | .map _ _ => 9 | .set _ => 10 | .bytes => 11
  | .dict _ _ => 12 | .tapp _ _ => 13 | .ctor _ => 14

/-- 型構成子も、順位と data の名前を落とさず木へ写す。 -/
def TyCon.toTree : TyCon → Tree Label
  | .data d => .node (.rank 0) [.node (.text d) []]
  | c => .node (.rank c.rank) []

/-- 型構成子の写像の単射性。 -/
theorem TyCon.toTree_injective {a b : TyCon} (h : a.toTree = b.toTree) : a = b := by
  cases a <;> cases b <;> simp_all [TyCon.toTree, TyCon.rank, Tree.node.injEq]

mutual
  /-- 欄の境界を子の木で区切り、名前・引数・結果・潜在効果をすべて保持する。 -/
  def Ty.toTree : Ty → Tree Label
    | .base b => .node (.rank 0) [.node (.nat b.rank) []]
    | .opaque o => .node (.rank 1) [.node (.text o) []]
    | .data d args => .node (.rank 2) [.node (.text d) [], .node (.rank 0) (Ty.toTrees args)]
    | .list a => .node (.rank 3) [a.toTree]
    | .fn names params ret eff => .node (.rank 4)
        [.node (.texts names) [], .node (.rank 0) (Ty.toTrees params), ret.toTree,
          Eff.toTree eff]
    | .tvar i => .node (.rank 5) [.node (.nat i) []]
    | .reference a => .node (.rank 6) [a.toTree]
    | .lazy a => .node (.rank 7) [a.toTree]
    | .cont b t eff => .node (.rank 8) [b.toTree, t.toTree, Eff.toTree eff]
    | .map k v => .node (.rank 9) [k.toTree, v.toTree]
    | .set a => .node (.rank 10) [a.toTree]
    | .bytes => .node (.rank 11) []
    | .dict cl a => .node (.rank 12) [.node (.text cl) [], a.toTree]
    | .tapp i args => .node (.rank 13) [.node (.nat i) [], .node (.rank 0) (Ty.toTrees args)]
    | .ctor c => .node (.rank 14) [c.toTree]

  /-- 効果の欄と Fail 列の順序を保持する。 -/
  def Eff.toTree : Eff → Tree Label
    | .mk a fs => .node (.atoms a) (Ty.toTrees fs)

  /-- 型列をそのままの順序で木の列へ写す。 -/
  def Ty.toTrees : List Ty → List (Tree Label)
    | [] => []
    | a :: as => a.toTree :: Ty.toTrees as
end

mutual
  /-- 木の等号から、元の共有型の生の等号を導く。 -/
  theorem Ty.toTree_injective {a b : Ty} (h : a.toTree = b.toTree) : a = b := by
    cases a <;> cases b <;>
      simp only [Ty.toTree, Tree.node.injEq, List.cons.injEq,
        Label.rank.injEq, Label.nat.injEq, Label.text.injEq, Label.texts.injEq,
        Nat.reduceEqDiff, and_true, true_and, false_and] at h
    all_goals first
      | contradiction
      | exact congrArg Ty.base (BaseTy.rank_injective h)
      | exact congrArg Ty.opaque h
      | exact congrArg Ty.list (Ty.toTree_injective h)
      | exact congrArg Ty.tvar h
      | exact congrArg Ty.reference (Ty.toTree_injective h)
      | exact congrArg Ty.lazy (Ty.toTree_injective h)
      | exact congrArg Ty.set (Ty.toTree_injective h)
      | exact congrArg Ty.ctor (TyCon.toTree_injective h)
      | rfl
      | skip
    case data.data =>
      obtain ⟨rfl, h⟩ := h
      exact congrArg (Ty.data _) (Ty.toTrees_injective h)
    case fn.fn =>
      obtain ⟨rfl, hp, hr, he⟩ := h
      have he := Eff.toTree_injective he
      cases he
      have hp := Ty.toTrees_injective hp
      have hr := Ty.toTree_injective hr
      cases hp; cases hr; rfl
    case cont.cont =>
      obtain ⟨hb, ht, he⟩ := h
      have he := Eff.toTree_injective he
      cases he
      have hb := Ty.toTree_injective hb
      have ht := Ty.toTree_injective ht
      cases hb; cases ht; rfl
    case map.map =>
      obtain ⟨hk, hv⟩ := h
      have hk := Ty.toTree_injective hk
      have hv := Ty.toTree_injective hv
      cases hk; cases hv; rfl
    case dict.dict =>
      obtain ⟨rfl, h⟩ := h
      exact congrArg (Ty.dict _) (Ty.toTree_injective h)
    case tapp.tapp =>
      obtain ⟨rfl, h⟩ := h
      exact congrArg (Ty.tapp _) (Ty.toTrees_injective h)

  /-- 効果の写像も、生の Fail 列を区別する。 -/
  theorem Eff.toTree_injective {e f : Eff} (h : e.toTree = f.toTree) : e = f := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs =>
        have h := Tree.node.inj h
        have ha := Label.atoms.inj h.1
        have hf := Ty.toTrees_injective h.2
        cases ha; cases hf; rfl

  /-- 木の列への写像も、型列の順序と長さを区別する。 -/
  theorem Ty.toTrees_injective {as bs : List Ty} (h : Ty.toTrees as = Ty.toTrees bs) : as = bs := by
    cases as with
    | nil => cases bs <;> simp_all [Ty.toTrees]
    | cons a as =>
      cases bs with
      | nil => simp [Ty.toTrees] at h
      | cons b bs =>
        obtain ⟨ha, ht⟩ := List.cons.inj h
        have ha := Ty.toTree_injective ha
        have ht := Ty.toTrees_injective ht
        cases ha; cases ht; rfl
end

/-- 型構成子を宣言順で比較する。 -/
def tyConCompare : TyCon → TyCon → Ordering
  | .data a, .data b => stringCompare a b
  | a, b => compare a.rank b.rank

mutual
  /-- 型を構造再帰で比較する。非計算的な選択を使うのは atomsCompare だけである。 -/
  noncomputable def tyCompare : Ty → Ty → Ordering
    | .base a, .base b => compare a.rank b.rank
    | .opaque a, .opaque b => stringCompare a b
    | .data d as, .data e bs => (stringCompare d e).then (tysCompare as bs)
    | .list a, .list b => tyCompare a b
    | .fn ns as a e, .fn ms bs b f =>
        (List.compareLex stringCompare ns ms).then
          ((tysCompare as bs).then ((tyCompare a b).then (effCompare e f)))
    | .tvar i, .tvar j => compare i j
    | .reference a, .reference b => tyCompare a b
    | .lazy a, .lazy b => tyCompare a b
    | .cont a b e, .cont c d f =>
        (tyCompare a c).then ((tyCompare b d).then (effCompare e f))
    | .map a b, .map c d => (tyCompare a c).then (tyCompare b d)
    | .set a, .set b => tyCompare a b
    | .bytes, .bytes => .eq
    | .dict cl a, .dict dl b => (stringCompare cl dl).then (tyCompare a b)
    | .tapp i as, .tapp j bs => (compare i j).then (tysCompare as bs)
    | .ctor a, .ctor b => tyConCompare a b
    | a, b => compare a.rank b.rank

  /-- 効果は名前・行の関数、Fail 列の順で比較する。 -/
  noncomputable def effCompare : Eff → Eff → Ordering
    | .mk a fs, .mk b gs => (atomsCompare a b).then (tysCompare fs gs)

  /-- 型列の辞書式比較。空列では型の比較を呼ばない。 -/
  noncomputable def tysCompare : List Ty → List Ty → Ordering
    | [], [] => .eq
    | [], _ :: _ => .lt
    | _ :: _, [] => .gt
    | a :: as, b :: bs => (tyCompare a b).then (tysCompare as bs)
end

/-- 型構成子の直接比較は、木の比較と一致する。 -/
theorem tyConCompare_eq_treeCompare (a b : TyCon) :
    tyConCompare a b = treeCompare labelCompare a.toTree b.toTree := by
  cases a <;> cases b <;>
    simp [tyConCompare, TyCon.rank, TyCon.toTree, treeCompare, treesCompare,
      labelCompare, Nat.compare_eq_ite_lt]

mutual
  /-- 構造再帰の型比較を、証明済みの木の全順序へ接続する。 -/
  theorem tyCompare_eq_treeCompare (a b : Ty) :
      tyCompare a b = treeCompare labelCompare a.toTree b.toTree := by
    cases a <;> cases b <;> first | rfl |
      simp [tyCompare, Ty.toTree, treeCompare, treesCompare,
        labelCompare, Nat.compare_eq_ite_lt,
        tyCompare_eq_treeCompare, tysCompare_eq_treesCompare, effCompare_eq_treeCompare, tyConCompare_eq_treeCompare]

  /-- 効果の直接比較も、同じ木の順序と一致する。 -/
  theorem effCompare_eq_treeCompare (e f : Eff) :
      effCompare e f = treeCompare labelCompare e.toTree f.toTree := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs =>
        simp only [effCompare, Eff.toTree, treeCompare, labelCompare, tysCompare_eq_treesCompare]

  /-- 型列の直接比較も、木の列の比較と一致する。 -/
  theorem tysCompare_eq_treesCompare (as bs : List Ty) :
      tysCompare as bs = treesCompare labelCompare (Ty.toTrees as) (Ty.toTrees bs) := by
    cases as with
    | nil => cases bs <;> rfl
    | cons a as =>
      cases bs with
      | nil => rfl
      | cons b bs =>
        simp only [tysCompare, Ty.toTrees, treesCompare,
          tyCompare_eq_treeCompare, tysCompare_eq_treesCompare]
end

/-- 型列の比較も、列の生の等号を返す。 -/
theorem tysCompare_eq_iff (as bs : List Ty) : tysCompare as bs = .eq ↔ as = bs := by
  rw [tysCompare_eq_treesCompare, treesCompare_eq_iff]
  exact ⟨Ty.toTrees_injective, congrArg Ty.toTrees⟩

instance : LawfulEqCmp tysCompare where
  compare_self := (tysCompare_eq_iff _ _).mpr rfl
  eq_of_compare := (tysCompare_eq_iff _ _).mp

instance : TransCmp tysCompare where
  eq_swap {as bs} := by
    simpa only [tysCompare_eq_treesCompare] using
      (treesCompare_swap (cmp := labelCompare) (Ty.toTrees as) (Ty.toTrees bs))
  isLE_trans {as bs cs} hab hbc := by
    simpa only [tysCompare_eq_treesCompare] using
      (treesCompare_isLE_trans (cmp := labelCompare) (Ty.toTrees as) (Ty.toTrees bs) (Ty.toTrees cs)
        (by simpa only [tysCompare_eq_treesCompare] using hab)
        (by simpa only [tysCompare_eq_treesCompare] using hbc))

/-- 比較の eq は、型の生の等号と同値である。 -/
theorem tyCompare_eq_iff (a b : Ty) : tyCompare a b = .eq ↔ a = b := by
  rw [tyCompare_eq_treeCompare, treeCompare_eq_iff]
  exact ⟨Ty.toTree_injective, congrArg Ty.toTree⟩

instance : LawfulEqCmp tyCompare where
  compare_self := (tyCompare_eq_iff _ _).mpr rfl
  eq_of_compare := (tyCompare_eq_iff _ _).mp

instance : TransCmp tyCompare where
  eq_swap {a b} := by
    simpa only [tyCompare_eq_treeCompare] using
      (treeCompare_swap (cmp := labelCompare) a.toTree b.toTree)
  isLE_trans {a b c} hab hbc := by
    simpa only [tyCompare_eq_treeCompare] using
      (treeCompare_isLE_trans (cmp := labelCompare) a.toTree b.toTree c.toTree
        (by simpa only [tyCompare_eq_treeCompare] using hab)
        (by simpa only [tyCompare_eq_treeCompare] using hbc))

/-- 型の比較は全域であり、有限支持を仮定しない。 -/
theorem tyCompare_total (a b : Ty) :
    tyCompare a b = .lt ∨ a = b ∨ tyCompare b a = .lt := by
  cases h : tyCompare a b with
  | lt => exact Or.inl rfl
  | eq => exact Or.inr (Or.inl ((tyCompare_eq_iff a b).mp h))
  | gt => exact Or.inr (Or.inr (OrientedCmp.lt_of_gt h))

/-- 狭義比較は推移する。 -/
theorem tyCompare_lt_trans {a b c : Ty}
    (hab : tyCompare a b = .lt) (hbc : tyCompare b c = .lt) : tyCompare a c = .lt :=
  TransCmp.lt_trans hab hbc

/-- 双方向の非狭義比較から、型の生の等号を導く。 -/
theorem tyCompare_antisymm {a b : Ty}
    (hab : (tyCompare a b).isLE) (hba : (tyCompare b a).isLE) : a = b :=
  (tyCompare_eq_iff a b).mp (Ordering.eq_eq_of_isLE_of_isLE_swap hab
    (by simpa only [← OrientedCmp.eq_swap] using hba))

end Benitoite.Release
