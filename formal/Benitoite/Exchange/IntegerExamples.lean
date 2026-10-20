import Benitoite.Exchange.Convert

/-!
# Integer の交換境界の例

範囲外を型付き構文へ入れず、正のリテラルと直接負号の上限を分ける
（設計書 01-12「構文」、07-04「01-12 との対応」）。
既存の交換例には i64 を越す値と最小値の直接負号の対照がないため、変換の入口で確認する。
-/
namespace Benitoite.Exchange.IntegerExamples

open Benitoite.Release

/-- 丸めや切り詰めをせず、両端を保って往復する。 -/
private def roundTrip (n : Int) : Except String Int := do
  let c ← Const.toRelease (.integer n)
  let .integer m ← fromConst c | throw "expected integer"
  return m

example : [-9223372036854775808, 0, 9223372036854775807].map (fun n => (roundTrip n).toOption) =
    [some (-9223372036854775808), some 0, some 9223372036854775807] := by decide
example : [-9223372036854775809, 9223372036854775808].map
    (fun n => (Const.toRelease (.integer n)).isOk) = [false, false] := by decide
example : (integer64Literal 9223372036854775807).isOk = true ∧
    (integer64Literal 9223372036854775808).isOk = false ∧
    (integer64Magnitude 9223372036854775808).isOk = true ∧
    (integer64Magnitude 9223372036854775809).isOk = false := by decide

/-- 成功した表層のパターンを全域の toCore まで通す。 -/
private def patternValue (n : Int) : Except String Int := do
  let p ← Pattern.toSurface (.const (.integer n))
  let .const (.integer v) := p.toCore | throw "expected integer pattern"
  return v.toInt

#guard [-9223372036854775808, 0, 9223372036854775807].map (fun n => (patternValue n).toOption) ==
  [some (-9223372036854775808), some 0, some 9223372036854775807]
#guard [-9223372036854775809, 9223372036854775808].map
  (fun n => (patternValue n).isOk) == [false, false]
#guard (Pattern.toSurface (.range (.integer (-9223372036854775808))
  (.integer 9223372036854775807))).isOk
#guard !(Pattern.toSurface (.range (.integer (-9223372036854775809))
  (.integer 9223372036854775807))).isOk
#guard !(Pattern.toSurface (.range (.integer (-9223372036854775808))
  (.integer 9223372036854775808))).isOk

/-- 直接負号から作った最小値を、通常の脱糖で同じ定数にする。 -/
private def expressionValue (n : Int) : Except String Int := do
  let e ← Expr.toSurface [] (.literal (.integer n))
  let .ret (.const (.integer v)) := Benitoite.Surface.desugarExpr (fun _ _ => none) .other e
    | throw "expected integer expression"
  return v.toInt

#guard [-9223372036854775808, 0, 9223372036854775807].map (fun n => (expressionValue n).toOption) ==
  [some (-9223372036854775808), some 0, some 9223372036854775807]
#guard [-9223372036854775809, 9223372036854775808].map
  (fun n => (expressionValue n).isOk) == [false, false]

-- 別幅の表現の変更をこの境界に混ぜない。
#guard (Const.toRelease (.integer8 128)).isOk

end Benitoite.Exchange.IntegerExamples
