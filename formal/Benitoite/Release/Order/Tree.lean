import Std

/-!
# ラベル付きの多分木の辞書式順序

根のラベルを先に、続いて子の列を左から比較する。型から木への単射で
全順序を引き戻すため、型表現には依存しない（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release.Order

open Std

/-- 有限個の子を持つラベル付きの木。 -/
inductive Tree (α : Type u) where
  | node (label : α) (children : List (Tree α))

mutual
  /-- 根のラベル、子の列の順で比較する。 -/
  def treeCompare (cmp : α → α → Ordering) : Tree α → Tree α → Ordering
    | .node a as, .node b bs => (cmp a b).then (treesCompare cmp as bs)

  /-- 子の列の辞書式比較。接頭辞は短い方が先になる。 -/
  def treesCompare (cmp : α → α → Ordering) : List (Tree α) → List (Tree α) → Ordering
    | [], [] => .eq
    | [], _ :: _ => .lt
    | _ :: _, [] => .gt
    | a :: as, b :: bs => (treeCompare cmp a b).then (treesCompare cmp as bs)
end

variable {α : Type u} {cmp : α → α → Ordering}

mutual
  /-- 木の比較の eq は、ラベルと子の列の等号を表す。 -/
  theorem treeCompare_eq_iff [LawfulEqCmp cmp] (a b : Tree α) : treeCompare cmp a b = .eq ↔ a = b := by
    cases a with
    | node a as =>
      cases b with
      | node b bs =>
        simp only [treeCompare, Ordering.then_eq_eq, LawfulEqCmp.compare_eq_iff_eq,
          treesCompare_eq_iff, Tree.node.injEq]

  /-- 子の列の比較の eq は、生の列の等号を表す。 -/
  theorem treesCompare_eq_iff [LawfulEqCmp cmp] (as bs : List (Tree α)) : treesCompare cmp as bs = .eq ↔ as = bs := by
    cases as with
    | nil => cases bs <;> simp [treesCompare]
    | cons a as =>
      cases bs with
      | nil => simp [treesCompare]
      | cons b bs =>
        simp only [treesCompare, Ordering.then_eq_eq, treeCompare_eq_iff,
          treesCompare_eq_iff, List.cons.injEq]
end

mutual
  /-- 木の引数を交換すると比較の向きが反転する。 -/
  theorem treeCompare_swap [OrientedCmp cmp] (a b : Tree α) : treeCompare cmp a b = (treeCompare cmp b a).swap := by
    cases a with
    | node a as =>
      cases b with
      | node b bs =>
        simp only [treeCompare, Ordering.swap_then]
        rw [OrientedCmp.eq_swap (cmp := cmp) (a := a), treesCompare_swap as bs]

  /-- 子の列の引数を交換すると比較の向きが反転する。 -/
  theorem treesCompare_swap [OrientedCmp cmp] (as bs : List (Tree α)) :
      treesCompare cmp as bs = (treesCompare cmp bs as).swap := by
    cases as with
    | nil => cases bs <;> rfl
    | cons a as =>
      cases bs with
      | nil => rfl
      | cons b bs =>
        simp only [treesCompare, Ordering.swap_then]
        rw [treeCompare_swap a b, treesCompare_swap as bs]
end

private theorem then_trans {x y z x' y' z' : Ordering}
    (ht : x.isLE → y.isLE → z.isLE)
    (hl : x = .lt → y.isLE → z = .lt)
    (hr : x.isLE → y = .lt → z = .lt)
    (ht' : x'.isLE → y'.isLE → z'.isLE)
    (hxy : (x.then x').isLE) (hyz : (y.then y').isLE) : (z.then z').isLE := by
  obtain ⟨hx, hx'⟩ := Ordering.isLE_then_iff_and.mp hxy
  obtain ⟨hy, hy'⟩ := Ordering.isLE_then_iff_and.mp hyz
  apply Ordering.isLE_then_iff_and.mpr
  refine ⟨ht hx hy, ?_⟩
  rcases hx' with h | h
  · exact Or.inl (hl h hy)
  · rcases hy' with h' | h'
    · exact Or.inl (hr hx h')
    · exact Or.inr (ht' h h')

mutual
  /-- 木の非狭義比較は推移する。 -/
  theorem treeCompare_isLE_trans [LawfulEqCmp cmp] [TransCmp cmp] (a b c : Tree α)
      (hab : (treeCompare cmp a b).isLE) (hbc : (treeCompare cmp b c).isLE) :
      (treeCompare cmp a c).isLE := by
    cases a with
    | node a as =>
      cases b with
      | node b bs =>
        cases c with
        | node c cs =>
          exact then_trans TransCmp.isLE_trans TransCmp.lt_of_lt_of_isLE TransCmp.lt_of_isLE_of_lt
            (treesCompare_isLE_trans as bs cs) hab hbc

  /-- 子の列の非狭義比較は推移する。 -/
  theorem treesCompare_isLE_trans [LawfulEqCmp cmp] [TransCmp cmp] (as bs cs : List (Tree α))
      (hab : (treesCompare cmp as bs).isLE) (hbc : (treesCompare cmp bs cs).isLE) :
      (treesCompare cmp as cs).isLE := by
    cases as with
    | nil => cases cs <;> rfl
    | cons a as =>
      cases bs with
      | nil => simp [treesCompare] at hab
      | cons b bs =>
        cases cs with
        | nil => simp [treesCompare] at hbc
        | cons c cs =>
          apply then_trans (treeCompare_isLE_trans a b c) ?_ ?_
            (treesCompare_isLE_trans as bs cs) hab hbc
          · intro hlt hle
            have hle' : (treeCompare cmp a b).isLE := by rw [hlt]; rfl
            have hac := treeCompare_isLE_trans a b c hle' hle
            cases he : treeCompare cmp a c with
            | lt => rfl
            | gt => simp [he] at hac
            | eq =>
              have heq := (treeCompare_eq_iff a c).mp he
              subst c
              rw [treeCompare_swap b a, hlt] at hle
              contradiction
          · intro hle hlt
            have hle' : (treeCompare cmp b c).isLE := by rw [hlt]; rfl
            have hac := treeCompare_isLE_trans a b c hle hle'
            cases he : treeCompare cmp a c with
            | lt => rfl
            | gt => simp [he] at hac
            | eq =>
              have heq := (treeCompare_eq_iff a c).mp he
              subst c
              rw [treeCompare_swap a b, hlt] at hle
              contradiction
end

instance [LawfulEqCmp cmp] : LawfulEqCmp (treeCompare cmp) where
  compare_self := (treeCompare_eq_iff _ _).mpr rfl
  eq_of_compare := (treeCompare_eq_iff _ _).mp

instance [LawfulEqCmp cmp] [TransCmp cmp] : TransCmp (treeCompare cmp) where
  eq_swap := treeCompare_swap _ _
  isLE_trans := treeCompare_isLE_trans _ _ _

/-- 木の比較は全域であり、eq は木の等号となる。 -/
theorem treeCompare_total [LawfulEqCmp cmp] [TransCmp cmp] (a b : Tree α) :
    treeCompare cmp a b = .lt ∨ a = b ∨ treeCompare cmp b a = .lt := by
  cases h : treeCompare cmp a b with
  | lt => exact Or.inl rfl
  | eq => exact Or.inr (Or.inl ((treeCompare_eq_iff _ _).mp h))
  | gt => exact Or.inr (Or.inr (OrientedCmp.lt_of_gt h))

end Benitoite.Release.Order
