import Std

/-!
# 整数の閉区間の独立した小モデル

比較だけを使い、上端の加算を行わない。Intと符号付き64ビットIntegerとの
対応は入力の表現可能性を条件に別途照合する（設計書 01-12「検査済みの値の独立した小モデル」）。
-/
namespace Benitoite.Checked.Range

def InRange (lo hi value : Int) : Prop := lo ≤ value ∧ value ≤ hi

instance (lo hi value : Int) : Decidable (InRange lo hi value) :=
  inferInstanceAs (Decidable (lo ≤ value ∧ value ≤ hi))

inductive RangeError where
  | invalidBounds (lo hi : Int)
  | outOfRange (lo hi value : Int)
  deriving DecidableEq, Repr

structure CheckedInteger where
  minimum : Int
  maximum : Int
  value : Int
  bounded : InRange minimum maximum value

structure RawInteger where
  minimum : Int
  maximum : Int
  value : Int
  deriving DecidableEq, Repr

def erase (v : CheckedInteger) : RawInteger := ⟨v.minimum, v.maximum, v.value⟩

def make (lo hi value : Int) : Except RangeError CheckedInteger :=
  if lo ≤ hi then
    if h : InRange lo hi value then .ok ⟨lo, hi, value, h⟩
    else .error (.outOfRange lo hi value)
  else .error (.invalidBounds lo hi)

def rawMake (lo hi value : Int) : Except RangeError RawInteger :=
  if lo ≤ hi then
    if InRange lo hi value then .ok ⟨lo, hi, value⟩
    else .error (.outOfRange lo hi value)
  else .error (.invalidBounds lo hi)

theorem make_ok (lo hi value : Int) (v : CheckedInteger)
    (h : make lo hi value = .ok v) :
    v.minimum = lo ∧ v.maximum = hi ∧ v.value = value ∧ InRange lo hi value := by
  unfold make at h
  split at h <;> (try split at h) <;> cases h
  exact ⟨rfl, rfl, rfl, ‹InRange lo hi value›⟩

theorem make_invalidBounds_iff (lo hi value : Int) :
    make lo hi value = .error (.invalidBounds lo hi) ↔ hi < lo := by
  unfold make
  split <;> rename_i hb
  · split <;> simp <;> omega
  · simp; omega

theorem make_outOfRange_iff (lo hi value : Int) :
    make lo hi value = .error (.outOfRange lo hi value) ↔
      lo ≤ hi ∧ ¬ InRange lo hi value := by
  unfold make
  split <;> rename_i hb
  · split <;> simp_all
  · simp_all; omega

theorem erase_make (lo hi value : Int) :
    (make lo hi value).map erase = rawMake lo hi value := by
  unfold make rawMake
  split <;> (try split) <;> rfl

def minimum (v : CheckedInteger) : Int := v.minimum
def maximum (v : CheckedInteger) : Int := v.maximum
def value (v : CheckedInteger) : Int := v.value

theorem project_minimum (v : CheckedInteger) : minimum v = (erase v).minimum := rfl
theorem project_maximum (v : CheckedInteger) : maximum v = (erase v).maximum := rfl
theorem project_value (v : CheckedInteger) : value v = (erase v).value := rfl

theorem singleton_ok (n : Int) :
    (make n n n).map erase = .ok ⟨n, n, n⟩ := by
  rw [erase_make]; simp [rawMake, InRange]

def minInteger : Int := -9223372036854775808
def maxInteger : Int := 9223372036854775807
def IntegerRepresentable (n : Int) : Prop := minInteger ≤ n ∧ n ≤ maxInteger

theorem maxInteger_endpoint_ok :
    (make minInteger maxInteger maxInteger).map erase =
      .ok ⟨minInteger, maxInteger, maxInteger⟩ := by
  rw [erase_make]; simp [rawMake, InRange, minInteger, maxInteger]

theorem minInteger_endpoint_ok :
    (make minInteger maxInteger minInteger).map erase =
      .ok ⟨minInteger, maxInteger, minInteger⟩ := by
  rw [erase_make]; simp [rawMake, InRange, minInteger, maxInteger]

-- 逆転を範囲外より先に報告し、閉じた上端とその直後を区別する。
example : rawMake 10 0 5 = .error (.invalidBounds 10 0) ∧
    rawMake 0 10 10 = .ok ⟨0, 10, 10⟩ ∧
    rawMake 0 10 11 = .error (.outOfRange 0 10 11) := by simp [rawMake, InRange]

end Benitoite.Checked.Range
