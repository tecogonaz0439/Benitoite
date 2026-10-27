import Benitoite.Interval.BudgetChildren
import Benitoite.Interval.BudgetRange

/-! # 契約位置の値を保持するソース順の解析

全引数を記述順に解析する。親が使う契約位置の値だけを保持し、
引数値の可変長の列や宣言順への並べ替えは作らない。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 一つの契約位置の正常値を選ぶ。途中の Bottom では後続の番号だけを消費する。 -/
def selectArguments (run : Expr → Analysis BaseApprox) (skip : Exprs → Analysis Unit)
    (target : Nat) (positions : List Nat) (sources : Exprs) : Analysis BaseApprox :=
  scope fun _ => do
    scan (BudgetScan.tick .classification)
    match sources with
    | .nil => pure baseUnit
    | .cons source rest =>
      let head ← run source
      if !head.live then do skip rest; pure head.abrupt else do
        let tail ← selectArguments run skip target positions.tail rest
        pure (baseThen head (baseThen tail
          (if positions.head? = some target then head else tail)))

/-- 固定域が検査する契約位置。 -/
def bindingArgument (binding : StandardBinding) : Nat :=
  match binding.rule with
  | .fixedDomain argument .. => argument
  | _ => 0

/-- 選んだ引数についてだけ、固定域の候補を作る。位置列は固定の一項である。 -/
def selectedFixedOwn (binding : StandardBinding) (key : OperationKey)
    (selected : BaseApprox) : BaseApprox :=
  baseFixedOwn binding key [bindingArgument binding] [selected]

end Benitoite.Interval.BudgetAnalysis
