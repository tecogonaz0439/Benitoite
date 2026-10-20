import Std

/-!
# 非空Listの独立した小モデル

headとtailを別に保存する。mapは純粋な関数を対象とし、効果を持つ通常コードの
実行は別途照合する（設計書 01-12「検査済みの値の独立した小モデル」）。
-/
namespace Benitoite.Checked.NonEmptyList

inductive EmptyListError where
  | emptyList
  deriving DecidableEq, Repr

structure NonEmptyList (α : Type) where
  head : α
  tail : List α

def fromList : List α → Except EmptyListError (NonEmptyList α)
  | [] => .error .emptyList
  | x :: xs => .ok ⟨x, xs⟩

def toList (v : NonEmptyList α) : List α := v.head :: v.tail
def head (v : NonEmptyList α) : α := v.head
def tail (v : NonEmptyList α) : List α := v.tail

theorem nonEmpty_success_iff (xs : List α) :
    (∃ v, fromList xs = .ok v) ↔ xs ≠ [] := by
  cases xs <;> simp [fromList]

theorem nonEmpty_failure_iff (xs : List α) :
    fromList xs = .error .emptyList ↔ xs = [] := by
  cases xs <;> simp [fromList]

theorem nonEmpty_from_to (xs : List α) (v : NonEmptyList α)
    (h : fromList xs = .ok v) : toList v = xs ∧ xs ≠ [] := by
  cases xs with
  | nil => cases h
  | cons x xs => cases h; exact ⟨rfl, by simp⟩

theorem nonEmpty_to_from (v : NonEmptyList α) : fromList (toList v) = .ok v := rfl

theorem nonEmpty_head_tail (v : NonEmptyList α) : toList v = head v :: tail v := rfl

def map (f : α → β) (v : NonEmptyList α) : NonEmptyList β :=
  ⟨f v.head, v.tail.map f⟩

theorem nonEmpty_map (f : α → β) (v : NonEmptyList α) :
    toList (map f v) = List.map f (toList v) := rfl

end Benitoite.Checked.NonEmptyList
