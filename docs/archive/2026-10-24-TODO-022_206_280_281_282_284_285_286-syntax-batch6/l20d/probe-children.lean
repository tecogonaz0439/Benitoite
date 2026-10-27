import Benitoite.Interval.BudgetIndependentSound
open Benitoite.Interval Benitoite.Surface Benitoite.Release
open Benitoite.Interval.BudgetAnalysis

-- 既存の14操作の境界を残し、追加の一操作の前後を固定値で確かめるための観察。
#eval
  let one := Expr.literal (.integer ⟨1, by decide⟩)
  let zero := Expr.literal (.integer ⟨0, by decide⟩)
  let division := Expr.binary .intDiv (.base .integer) one zero
  let source := Expr.call .unit [none] [0]
    (.cons (.list (.base .integer) (.cons division (.cons one .nil))) .nil)
  ([14, 15] : List Nat).map fun cap =>
    let result := analyzeExpr ⟨⟨cap, 1000⟩, ⟨1000, 1000⟩⟩ {} 64
      (AbstractEnv.ofLocals []) ⟨"Example.children", 0⟩ source
    (result.context.independentRev.reverse.map fun entry =>
      (entry.key.surfacePreorder, entry.warningsRev.map fun w => (w.key.surfacePreorder, w.cause)),
     result.context.independentRev.head?.map fun entry => entry.result.isOk,
     result.context.next.surfacePreorder, result.context.budget.body.operations,
     result.context.budget.body.saved, result.context.budget.body.temporary)
