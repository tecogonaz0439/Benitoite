import Benitoite.Interval.BudgetWhole

/- 本体上限100,000の境界。A11と同じ入力・既定上限で候補と本体消費の不変を確かめる。 -/
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

private def reports : List BudgetWhole.Report :=
  ([[sample], [unrelated, sample]] : List (List Definition)).map fun inputs =>
    BudgetWhole.analyze {} {} 4096 [⟨inputs⟩]

private def sampleSummary (r : BudgetWhole.Report) :=
  (BudgetWhole.bodyOutputs r).filterMap fun b =>
    if b.definition == ".sample" then
      some (b.output.coverage, b.output.context.warningsRev.length,
        b.output.context.budget.body)
    else none

-- 先頭も二番目も同じ完全な本体消費で候補を一件保存する。
#guard reports.map sampleSummary = [
  [(.complete, 1, ⟨100000, 0, 555, 1988⟩)],
  [(.complete, 1, ⟨100000, 0, 555, 1988⟩)]]

-- モジュールの一操作は全体へ残す。空関数の追加分だけ全体消費が増える。
#guard reports.map (fun r => r.after.whole) = [
  ⟨100001, 555, 1988⟩, ⟨100010, 557, 1990⟩]
#guard reports.all fun r => r.stopped.isNone && r.remainingDefinitions.isEmpty &&
  r.remainingModules.isEmpty && r.after.whole.operations < 1000000 &&
  r.after.whole.peak < 1000000

#eval reports.map fun r => (repr (sampleSummary r), repr r.after.whole)
