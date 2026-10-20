import Std

/-!
# Listの長さの検査の独立した小モデル

数学上のListとIntを使う。実装の長さ上限、Integerの表現可能性、不透明型の
公開境界は別途照合する（設計書 01-12「検査済みの値の独立した小モデル」）。
-/
namespace Benitoite.Checked.ListLength

inductive LengthError where
  | invalidBounds (minimum maximum : Int)
  | outOfRange (minimum maximum length : Int)
  deriving DecidableEq, Repr

/-- 検査した対象と実長を、条件の証拠とともに保存する。 -/
structure CheckedLength (α : Type) where
  minimum : Int
  maximum : Int
  length : Int
  values : List α
  actualLength : length = (values.length : Int)
  bounded : 0 ≤ minimum ∧ minimum ≤ maximum ∧ minimum ≤ length ∧ length ≤ maximum

def checkLength (lo hi : Int) (xs : List α) : Except LengthError (CheckedLength α) :=
  if hb : 0 ≤ lo ∧ lo ≤ hi then
    if hr : lo ≤ (xs.length : Int) ∧ (xs.length : Int) ≤ hi then
      .ok ⟨lo, hi, xs.length, xs, rfl, hb.1, hb.2, hr⟩
    else .error (.outOfRange lo hi xs.length)
  else .error (.invalidBounds lo hi)

theorem checkLength_success_iff (lo hi : Int) (xs : List α) :
    (∃ v, checkLength lo hi xs = .ok v) ↔
      0 ≤ lo ∧ lo ≤ hi ∧ lo ≤ (xs.length : Int) ∧ (xs.length : Int) ≤ hi := by
  unfold checkLength
  split <;> (try split) <;> simp_all <;> omega

theorem checkLength_invalid_iff (lo hi : Int) (xs : List α) :
    checkLength lo hi xs = .error (.invalidBounds lo hi) ↔ lo < 0 ∨ hi < lo := by
  unfold checkLength
  split <;> (try split) <;> simp_all <;> omega

/-- 対象が範囲外でも、端点の不正を先に報告する。 -/
theorem checkLength_invalid_first (lo hi : Int) (xs : List α)
    (h : lo < 0 ∨ hi < lo) :
    checkLength lo hi xs = .error (.invalidBounds lo hi) :=
  (checkLength_invalid_iff lo hi xs).mpr h

theorem checkLength_outOfRange_iff (lo hi : Int) (xs : List α) :
    checkLength lo hi xs = .error (.outOfRange lo hi xs.length) ↔
      0 ≤ lo ∧ lo ≤ hi ∧ ((xs.length : Int) < lo ∨ hi < (xs.length : Int)) := by
  unfold checkLength
  split <;> (try split) <;> simp_all <;> omega

theorem checkLength_projection (lo hi : Int) (xs : List α) (v : CheckedLength α)
    (h : checkLength lo hi xs = .ok v) :
    v.minimum = lo ∧ v.maximum = hi ∧ v.length = (xs.length : Int) ∧ v.values = xs := by
  unfold checkLength at h
  split at h <;> (try split at h) <;> cases h
  exact ⟨rfl, rfl, rfl, rfl⟩

end Benitoite.Checked.ListLength
