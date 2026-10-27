import Benitoite.Interval.BudgetReach
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release
private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def division : Expr := .binary .intDiv (.base .integer) one zero
-- 未認定の call の引数は親の候補の外であるべきだが、開始版では true になる。
#guard (syntacticReachExpr (.call .unit [none] [0] (.cons division .nil))).all
  (fun slot => !slot.1)
end Benitoite.Interval.BudgetAnalysis
