import Benitoite.Interval.BudgetAnalyze
open Benitoite.Interval Benitoite.Surface Benitoite.Release
open Budget BudgetAnalysis
private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def division : Expr := .binary .intDiv (.base .integer) one zero
private def source : Expr := .ite (.local 0) (.last division) (.last (.paren one))
#eval ([14,17].map fun cap =>
 let output := analyzeExpr ⟨⟨cap,100⟩,⟨10000,10000⟩⟩ {} 100 (AbstractEnv.ofLocals []) ⟨"observe",0⟩ source
 (output.coverage, output.context.budget.body.operations,
  output.approx.warnings.map (fun w => (w.key.surfacePreorder,w.cause))))
