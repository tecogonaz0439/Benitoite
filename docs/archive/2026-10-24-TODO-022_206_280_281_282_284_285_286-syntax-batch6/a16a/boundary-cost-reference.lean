import Benitoite.Interval.BudgetWhole

/- 本体上限100,000の境界。束縛441件の認定分を最後の局所読出し441回と相殺し、既定上限と入力の大きさを保つ。 -/
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
    (fun i rest => Block.bind .bind intTy (if i == 439 then zero else .local (i + 1)) rest) filler
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

-- 大きい具体計算は評価器で実行し、kernel の等号判定へ渡さない。
#eval reports.map fun r => (repr (sampleSummary r), repr r.after.whole)
