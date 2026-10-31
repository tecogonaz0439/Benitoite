import Std

/-!
# 型と項から独立した整数の定数

旧公開名とその定義を保つため、64ビット整数の宣言は Release の名前空間に残す。
このモジュールは Release の型・項・評価を import しない。
-/
namespace Benitoite.Release

/-- Integer の下端（設計書 01-12「構文」）。 -/
def min64 : Int := -9223372036854775808
/-- Integer の上端。別幅の整数の表現は変えない。 -/
def max64 : Int := 9223372036854775807

/-- Integer の全値は構文の時点で範囲内である。 -/
abbrev Integer64Value := { n : Int // min64 ≤ n ∧ n ≤ max64 }

/-- 区間の計算に使う数学的な整数への射影。 -/
def Integer64Value.toInt (n : Integer64Value) : Int := n.val

/-- 射影した数学的な整数も Integer の両端の内側にある。 -/
theorem Integer64Value.toInt_bounds (n : Integer64Value) :
    min64 ≤ n.toInt ∧ n.toInt ≤ max64 := n.property

/-- 正のリテラルの大きさ。 -/
abbrev Integer64Literal := { n : Nat // n ≤ 9223372036854775807 }
/-- 直接負号の大きさは、正のリテラルより一つ大きい値まで許す。 -/
abbrev Integer64Magnitude := { n : Nat // n ≤ 9223372036854775808 }

/-- 正のリテラルを全域に変換する。 -/
def Integer64Literal.toValue (n : Integer64Literal) : Integer64Value :=
  ⟨Int.ofNat n.val, by have h := n.property; simp only [min64, max64, Int.ofNat_eq_natCast]; omega⟩

/-- 直接負号は最小値の大きさも受理する。 -/
def Integer64Magnitude.negValue (n : Integer64Magnitude) : Integer64Value :=
  ⟨-Int.ofNat n.val, by have h := n.property; simp only [min64, max64, Int.ofNat_eq_natCast]; omega⟩

end Benitoite.Release
