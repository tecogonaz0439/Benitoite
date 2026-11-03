import Benitoite.Release.Refinement.Syntax

namespace Benitoite.Release.Refinement

/-- 数値の表現可能性。保持対象の条件はここへ混ぜない。 -/
def Const.NumericRepresented : Const → Prop
  | .integer8 n => -128 ≤ n ∧ n ≤ 127
  | .integer16 n => -32768 ≤ n ∧ n ≤ 32767
  | .integer32 n => -2147483648 ≤ n ∧ n ≤ 2147483647
  | .unsignedInteger16 n => 0 ≤ n ∧ n ≤ 65535
  | .unsignedInteger32 n => 0 ≤ n ∧ n ≤ 4294967295
  | .unsignedInteger64 n => 0 ≤ n ∧ n ≤ 18446744073709551615
  | .byte n => n ≤ 255
  | .decimal n scale => -79228162514264337593543950335 ≤ n ∧
      n ≤ 79228162514264337593543950335 ∧ scale ≤ 28
  | _ => True

theorem ConstOK.represented {B c} (h : ConstOK B c) : c.NumericRepresented := by
  cases c <;> first | exact h | trivial

end Benitoite.Release.Refinement
