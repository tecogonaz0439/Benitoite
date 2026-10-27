import Benitoite.Interval.BudgetWhole

/- A11 の停止理由の再現。既定値・既存定義・中心定理は変更しない。 -/
open Benitoite.Surface Benitoite.Release Benitoite.Interval
open Budget BudgetAnalysis BudgetWhole

private def intTy : Ty := .base .integer
private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def body : Block := Id.run do
  let last := Block.last (.returnE intTy (.binary .intDiv intTy one (.local 440)))
  let parens := (List.range 2).foldr (fun _ rest => Block.discard (.paren .unit) rest) last
  let filler := (List.range 102).foldr (fun _ rest => Block.discard .unit rest) parens
  let aliases := (List.range 440).foldr
    (fun i rest => Block.bind .bind intTy (.local (i + 1)) rest) filler
  return .bind .bind intTy zero aliases
private def sample : Definition := ⟨".sample", .function, [intTy], body, AbstractEnv.ofLocals []⟩
private def unrelated : Definition := ⟨".unrelated", .function, [], .empty, AbstractEnv.ofLocals []⟩

private def showBody (b : BudgetWhole.BodyOutput) : String :=
  s!"coverage={repr b.output.coverage}; warnings={b.output.context.warningsRev.length}; body={repr b.output.context.budget.body}"

#eval ([[sample], [unrelated, sample]] : List (List Definition)).map fun inputs =>
  let r := BudgetWhole.analyze {} {} 4096 [⟨inputs⟩]
  ((BudgetWhole.bodyOutputs r).filterMap fun (b : BudgetWhole.BodyOutput) =>
    if b.definition == ".sample" then some (showBody b) else none, repr r.after.whole)
