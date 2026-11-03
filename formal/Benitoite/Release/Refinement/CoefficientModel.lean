import Benitoite.Release.Refinement.ClosedEvaluation

/-! # 保存する係数と正確な一時計算 -/
namespace Benitoite.Release.Refinement

def CoefficientRepresented (bits : Nat) (n : Int) : Prop :=
  0 < bits ∧ -(2^(bits-1) : Int) ≤ n ∧ n < (2^(bits-1) : Int)

instance (bits : Nat) (n : Int) : Decidable (CoefficientRepresented bits n) :=
  inferInstanceAs (Decidable (_ ∧ _ ∧ _))

namespace CoefficientModel

def storageBits : Nat := 128

def save (bits : Nat) (n : Int) : Option Int :=
  if CoefficientRepresented bits n then some n else none

theorem save_some {bits : Nat} {n result : Int} :
    save bits n = some result ↔ result = n ∧ CoefficientRepresented bits n := by
  unfold save
  split <;> simp_all [eq_comm]

inductive Binary where
  | add | sub | mul | divide
  deriving DecidableEq, Repr

def Binary.eval (op : Binary) (a b : Int) : Int :=
  match op with
  | .add => a+b | .sub => a-b | .mul => a*b | .divide => a/b

def binary (bits : Nat) (op : Binary) (a b : Int) : Option Int :=
  if CoefficientRepresented bits a ∧ CoefficientRepresented bits b ∧
      ¬ (op = .divide ∧ b = 0) then save bits (op.eval a b) else none

theorem binary_some {bits : Nat} {op : Binary} {a b result : Int}
    (h : binary bits op a b = some result) :
    result = op.eval a b ∧ CoefficientRepresented bits result ∧
      CoefficientRepresented bits a ∧ CoefficientRepresented bits b ∧
      ¬ (op = .divide ∧ b = 0) := by
  unfold binary at h
  split at h
  · rename_i hn
    obtain ⟨rfl, hr⟩ := save_some.mp h
    exact ⟨rfl, hr, hn.1, hn.2.1, hn.2.2⟩
  · cases h

def neg (bits : Nat) (a : Int) : Option Int :=
  if CoefficientRepresented bits a then save bits (-a) else none

theorem neg_some {bits : Nat} {a result : Int} (h : neg bits a = some result) :
    result = -a ∧ CoefficientRepresented bits result ∧ CoefficientRepresented bits a := by
  unfold neg at h
  split at h
  · rename_i ha
    obtain ⟨rfl, hr⟩ := save_some.mp h
    exact ⟨rfl, hr, ha⟩
  · cases h

/-- 一時積は保存時の幅と独立に、数学の正確な値を返す。 -/
def temporaryProduct (a b : Int) : Int := a*b

/-- 一時積の表現可能性を前提として受け取り、保存成功と合わせる。一時の幅で計算する定義ではない。 -/
theorem product_then_save {bits temporaryBits : Nat} {a b result : Int}
    (ht : CoefficientRepresented temporaryBits (temporaryProduct a b))
    (hs : save bits (temporaryProduct a b) = some result) :
    result = a*b ∧ CoefficientRepresented bits result ∧
      CoefficientRepresented temporaryBits result := by
  obtain ⟨rfl, h⟩ := save_some.mp hs
  exact ⟨rfl, h, ht⟩

/-- Decimal の比較用の桁合わせを係数の保存域から分ける。 -/
def decimalAligned (c : Int) (s : Nat) (d : Int) (t : Nat) : Int × Int :=
  (c * (10:Int)^t, d * (10:Int)^s)

theorem decimal_compare (c d : Int) (s t : Nat) (op : Comparison) :
    (Observation.decimal c s).compare op (.decimal d t) =
      op.fromEqLt (decide ((decimalAligned c s d t).1 = (decimalAligned c s d t).2))
        (decide ((decimalAligned c s d t).1 < (decimalAligned c s d t).2))
        (decide ((decimalAligned c s d t).2 < (decimalAligned c s d t).1)) := rfl

end CoefficientModel
end Benitoite.Release.Refinement
