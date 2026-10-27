import Benitoite.Interval.BudgetWhole

/-! # 検査全体の入口による順序・予算・深さ停止の独立期待値 -/
namespace Benitoite.Interval.BudgetWhole
open Benitoite.Surface Benitoite.Release Budget

private def division : Expr := .binary .intDiv (.base .integer)
  (.literal (.integer ⟨1, by decide⟩)) (.literal (.integer ⟨0, by decide⟩))
private def input (name : String) (body : Block) : Definition :=
  ⟨name, .function, [], body, AbstractEnv.ofLocals []⟩
private def sources : List Module := [⟨[
  input "First.a" (.seq division (.last (.lazyE (.last division)))),
  input "First.b" (.last division)]⟩,
  ⟨[input "Second.c" (.last division)]⟩]

private def warningKeys (body : BodyOutput) : List (Nat × WarningCause) :=
  body.output.context.warningsRev.reverse.map fun w => (w.key.surfacePreorder, w.cause)
private def summary (r : Report) : List (String × List (Nat × WarningCause)) :=
  r.definitionsRev.reverse.flatMap fun d =>
    d.root.toList.map (fun b => (b.definition, warningKeys b)) ++
      d.embedded.bodiesRev.reverse.map (fun b => (b.definition, warningKeys b))

-- モジュール順・定義順、親の後の別本体。元の定義から一度だけ発見する。
#guard summary (analyze {} {} 100 sources) = [
  ("First.a", [(1, .zeroDivisor)]),
  ("First.a%body:4:0", [(1, .zeroDivisor)]),
  ("First.b", [(1, .zeroDivisor)]),
  ("Second.c", [(1, .zeroDivisor)])]

-- 深さ0を予算超過と数えず、交換の比較対象から外す。後続定義も同じfuelを使う。
#guard ((analyze {} {} 0 sources).definitionsRev.reverse.map fun d =>
    d.root.map fun b => match b.output.coverage with
      | .stopped reason => some (classify reason) | _ => none) =
  [some (some .depth), some (some .depth), some (some .depth)]

-- 全体上限0なら、入力の先頭を残し、新しい出力枠・環境・番号を作らない。
#guard
  let r := analyze { whole := ⟨0, 1000⟩ } {} 100 sources
  r.definitionsRev.length = 0 ∧ r.remainingModules.length = 2 ∧
    r.after = ({} : Budget.State)

-- 境界ごとの全体予算。発見済み未解析・次の定義・次のモジュールを区別する。
#guard
  let rows := ([40, 50, 71] : List Nat).map fun cap =>
    let r := analyze { whole := ⟨cap, 10000⟩ } {} 100 sources
    (r.definitionsRev.reverse.map fun d => d.input.name,
      (r.definitionsRev.map fun d => d.embedded.pending.length).foldl (· + ·) 0,
      r.remainingDefinitions.map Definition.name, r.remainingModules.length)
  rows = [(["First.a"], 1, ["First.b"], 1),
    (["First.a"], 0, ["First.b"], 1), (["First.a", "First.b"], 0, [], 1)]

#guard summary (analyze { whole := ⟨40, 10000⟩ } {} 100 sources) =
  [("First.a", [(1, .zeroDivisor)])]

-- 本体上限を使い切っても次の定義は独立した本体予算を使う。
#guard ((analyze { body := ⟨30, 10000⟩ } {} 100 sources).definitionsRev.reverse.map
  fun d => d.input.name) = ["First.a", "First.b", "Second.c"]
#guard (analyze {} {} 100 sources).after.whole.operations = 93

-- モジュールの分類を先頭本体へ残すと、本体上限11で先頭だけ候補を失う。
-- 分類の消費は全体へ残し、元定義の先頭と二番目で同じ本体予算を使う。
#guard
  let sample := input "First.sample" (.last division)
  let unrelated := input "First.unrelated" .empty
  let rows := ([10, 11, 12] : List Nat).map fun cap =>
    ([[sample], [unrelated, sample]] : List (List Definition)).map fun inputs =>
      let r := analyze { body := ⟨cap, 1000⟩ } {} 100 [⟨inputs⟩]
      (bodyOutputs r).filterMap fun b =>
        if b.definition == sample.name then
          some (b.output.context.budget.body.operations, warningKeys b)
        else none
  rows = [ [[(10, [])], [(10, [])]],
    [[(11, [(1, .zeroDivisor)])], [(11, [(1, .zeroDivisor)])]],
    [[(11, [(1, .zeroDivisor)])], [(11, [(1, .zeroDivisor)])]] ]
#guard (excludedBodies (analyze {} {} 0 sources)).length = 3
#guard stopCount .depth (bodyStops (analyze {} {} 0 sources)) = 3
#guard stopCount .depth (phaseStops (analyze {} {} 0 sources)) = 3

-- 一本体のfuel不足で、後の浅い本体まで比較から除外しない。
#guard ((bodyOutputs (analyze {} {} 4 sources)).map fun b => (b.definition, comparisonEligible b)) =
  [("First.a", false), ("First.a%body:4:0", true), ("First.b", true), ("Second.c", true)]

-- 全体停止の事象数を本体の件数として重ねず、未着手の元定義も報告する。
-- 通常完走、入口作成前の停止、入口作成中の停止を同じ報告境界で確かめる。
#guard
  let reports := [analyze {} {} 100 sources,
    analyze { whole := ⟨0, 10000⟩ } {} 100 sources,
    analyze { whole := ⟨2, 10000⟩ } {} 100 sources,
    analyze { whole := ⟨6, 10000⟩ } {} 100 sources,
    analyze { body := ⟨7, 10000⟩ } {} 100 sources]
  (reports.map fun r => (inputDefinitionCount r, unsupportedBodies r,
    bodyBudgetExceeded r, wholeBudgetSkipped r, unidentifiedBodies r)) =
    [(3, 1, 0, 0, 0), (3, 0, 0, 3, 0), (3, 0, 0, 3, 0),
      (3, 0, 0, 2, 1), (3, 0, 0, 0, 3)]

end Benitoite.Interval.BudgetWhole
