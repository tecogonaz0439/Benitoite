import Std

/-!
# Listの添字の検査の独立した小モデル

成功値は対象と添字と要素を保持し、失敗値は添字と長さだけを持つ。
実装との対応の条件は設計書 01-12「検査済みの値の独立した小モデル」に従う。
-/
namespace Benitoite.Checked.ListIndex

inductive IndexError where
  | outOfBounds (index length : Int)
  deriving DecidableEq, Repr

structure CheckedIndex (α : Type) where
  values : List α
  index : Int
  element : α
  inBounds : 0 ≤ index ∧ index < (values.length : Int)
  atIndex : values[index.toNat]? = some element

def checkIndex (i : Int) (xs : List α) : Except IndexError (CheckedIndex α) :=
  if h : 0 ≤ i ∧ i < (xs.length : Int) then
    let hn : i.toNat < xs.length := by omega
    .ok ⟨xs, i, xs[i.toNat], h, by simp⟩
  else .error (.outOfBounds i xs.length)

theorem checkIndex_success_iff (i : Int) (xs : List α) :
    (∃ v, checkIndex i xs = .ok v) ↔ 0 ≤ i ∧ i < (xs.length : Int) := by
  unfold checkIndex
  split <;> simp_all

theorem checkIndex_failure_iff (i : Int) (xs : List α) :
    checkIndex i xs = .error (.outOfBounds i xs.length) ↔
      i < 0 ∨ (xs.length : Int) ≤ i := by
  unfold checkIndex
  split <;> simp_all <;> omega

theorem checkIndex_projection (i : Int) (xs : List α) (v : CheckedIndex α)
    (h : checkIndex i xs = .ok v) : v.index = i ∧ v.values = xs := by
  unfold checkIndex at h
  split at h <;> cases h
  exact ⟨rfl, rfl⟩

def get (v : CheckedIndex α) : α := v.element

/-- 保存した対象のその位置を返し、別のListで読み直さない。 -/
theorem checkedIndex_get_eq (i : Int) (xs : List α) (v : CheckedIndex α)
    (h : checkIndex i xs = .ok v) : xs[i.toNat]? = some (get v) := by
  obtain ⟨hi, hx⟩ := checkIndex_projection i xs v h
  simpa [get, hi, hx] using v.atIndex

end Benitoite.Checked.ListIndex
