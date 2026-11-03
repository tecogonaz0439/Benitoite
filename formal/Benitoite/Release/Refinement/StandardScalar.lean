import Benitoite.Release.Refinement.NumericContracts

/-! # Decimal の丸めの有限表と係数の演算 -/
namespace Benitoite.Release.Refinement.StandardScalar

/-- 標準の RoundingMode と同じ五つの選択肢。 -/
inductive DecimalRounding where
  | halfToEven | halfAwayFromZero | towardZero
  | towardNegativeInfinity | towardPositiveInfinity
  deriving DecidableEq

def DecimalRounding.all : List DecimalRounding :=
  [.halfToEven, .halfAwayFromZero, .towardZero, .towardNegativeInfinity, .towardPositiveInfinity]

def DecimalRounding.name : DecimalRounding → String
  | .halfToEven => "HalfToEven"
  | .halfAwayFromZero => "HalfAwayFromZero"
  | .towardZero => "TowardZero"
  | .towardNegativeInfinity => "TowardNegativeInfinity"
  | .towardPositiveInfinity => "TowardPositiveInfinity"

/-- 余りがあるときだけ、商の絶対値を一増やすかを決める。 -/
def DecimalRounding.increment (mode : DecimalRounding) (negative : Bool)
    (quotient remainder divisor : Nat) : Bool :=
  remainder != 0 && match mode with
    | .halfToEven => decide (divisor - remainder < remainder ∨
        (remainder = divisor - remainder ∧ quotient % 2 = 1))
    | .halfAwayFromZero => decide (divisor - remainder ≤ remainder)
    | .towardZero => false
    | .towardNegativeInfinity => negative
    | .towardPositiveInfinity => !negative

inductive DecimalRoundResult where
  | normal (coefficient : Int) (scale : Nat)
  | invalidPlaces | overflow
  deriving DecidableEq

/-- 同じ係数から一回丸め、places と出力の表現可能性を別に検査する。 -/
def decimalRound (coefficient : Int) (scale : Nat) (places : Int)
    (mode : DecimalRounding) : DecimalRoundResult :=
  if places < 0 ∨ 28 < places then .invalidPlaces else
    let p := places.toNat
    let magnitude := coefficient.natAbs
    let rounded := if scale ≤ p then magnitude * 10^(p-scale) else
      let divisor := 10^(scale-p)
      let quotient := magnitude / divisor
      let remainder := magnitude % divisor
      quotient + if mode.increment (coefficient < 0) quotient remainder divisor then 1 else 0
    if rounded ≤ 79228162514264337593543950335 then
      .normal (if coefficient < 0 then -(rounded : Int) else rounded) p
    else .overflow

/-- 同率・符号・余りなしを同じ五行の表へ渡す。 -/
theorem rounding_table :
    DecimalRounding.all.map DecimalRounding.name =
      ["HalfToEven", "HalfAwayFromZero", "TowardZero", "TowardNegativeInfinity", "TowardPositiveInfinity"] ∧
    DecimalRounding.all.map (decimalRound 25 1 0) =
      [.normal 2 0, .normal 3 0, .normal 2 0, .normal 2 0, .normal 3 0] ∧
    DecimalRounding.all.map (decimalRound (-25) 1 0) =
      [.normal (-2) 0, .normal (-3) 0, .normal (-2) 0, .normal (-3) 0, .normal (-2) 0] := by decide

end Benitoite.Release.Refinement.StandardScalar
