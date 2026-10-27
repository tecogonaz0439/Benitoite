import Benitoite.Interval.BudgetAnalyze
namespace Benitoite.Interval.Examples.RangeSurface
open Benitoite.Surface Benitoite.Release

private def names : RangeNames := ⟨"Std.Range.CheckedInteger", "Std.Result.Result", "Std.Range.Error",
  "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
private def key (n : Nat) : OperationKey := ⟨"Example.surfaceRange", n⟩
private def integer (n : Integer64Value) : ConcreteValue := .integer n
private def lit (n : Integer64Literal) : Expr := .literal (.integer n)
private def checkBinding : StandardBinding := ⟨"Std.Range.checkInteger", .rangeCheck names⟩
private def valueBinding : StandardBinding := ⟨"Std.Range.value", .rangeValue names.owner⟩
private def concrete : ConcreteEnv := ⟨[], [checkBinding, valueBinding], fun k =>
  if k.surfacePreorder = 8 ∨ k.surfacePreorder = 10 then some "Std.Range.value"
  else some "Std.Range.checkInteger"⟩
private def abstract : AbstractEnv := ⟨[], concrete.standards, concrete.apiAt, .empty ⟨[], 0⟩⟩
private def resultType : Ty := .data names.result [.opaque names.owner, .data names.error []]
private def checked : Checked.Range.CheckedInteger := ⟨0, 10, 5, by decide⟩
private def payload : ConcreteValue := .checkedRange names.owner (key 1) checked
private def result : ConcreteValue := .con names.result [.opaque names.owner, .data names.error []]
  names.ok [payload]
private def checkCall : Expr := .call (.funName "Std.Range.checkInteger" [] [])
  [some "value", some "maximum", some "minimum"] [2, 1, 0]
  (.cons (.binary .add (.base .integer) (lit ⟨2, by decide⟩) (lit ⟨3, by decide⟩))
    (.cons (lit ⟨10, by decide⟩) (.cons (lit ⟨0, by decide⟩) .nil)))
private def projection : Expr := .call (.funName "Std.Range.value" [] []) [some "checked"] [0]
  (.cons (.local 0) .nil)
private def okAlt : Alternative := ⟨.con (some names.result) names.ok [.var], [0]⟩
private def arms : Arms := .cons [okAlt] none (.last projection)
  (.cons [⟨.wild, []⟩] none (.last (.negInt ⟨1, by decide⟩)) .nil)
private def addEvent : EvalEvent := ⟨key 3, .binary .add (.base .integer),
  [integer ⟨2, by decide⟩, integer ⟨3, by decide⟩], .normal (integer ⟨5, by decide⟩)⟩
private def checkEvent : EvalEvent := ⟨key 1, .standard checkBinding,
  [integer ⟨0, by decide⟩, integer ⟨10, by decide⟩, integer ⟨5, by decide⟩], .normal payload⟩
private def valueEvent (k : OperationKey) (value : ConcreteValue) (out : OperationResult) : EvalEvent :=
  ⟨k, .standard valueBinding, [value], out⟩


private def stoppedSource : Expr := .matchE (.base .integer)
  (.call (.funName "Std.Range.checkInteger" [] []) [none, none, none] [0, 1, 2]
    (.cons (lit ⟨0, by decide⟩) (.cons (lit ⟨10, by decide⟩)
      (.cons (.ite (.local 0)
        (.last (.binary .intDiv (.base .integer) (lit ⟨1, by decide⟩) (lit ⟨0, by decide⟩)))
        (.last (lit ⟨5, by decide⟩))) .nil))))
  (.cons [okAlt] none (.last projection) .nil)
private def stoppedEnv : AbstractEnv := { abstract with
  locals := [.unknown (some (.base .boolean))]
  apiAt := fun k => if k.surfacePreorder = 1 then some "Std.Range.checkInteger" else some "Std.Range.value" }
#eval (List.range 35).map fun cap =>
  let r := BudgetAnalysis.analyzeExpr {body := ⟨10000,cap⟩,whole := ⟨10000,10000⟩} {} 64 stoppedEnv (key 0) stoppedSource
  (cap, r.context.next.surfacePreorder, r.context.warningsRev.map (·.key.surfacePreorder),
    r.context.budget.body.operations, r.context.budget.body.saved, r.context.budget.body.peak,
    r.coverage)
end Benitoite.Interval.Examples.RangeSurface
