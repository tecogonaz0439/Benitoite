import Benitoite.Interval.BudgetIndependentSound

/-!
# 未知の構成子を経由した独立入力の例

実際の解析入口から、忘却・元キー・入れ子・途中停止を固定期待値と照合する。
独立入口を直接呼ぶ例と区別し、親へ値や候補を混ぜる退行を検出する。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def division : Expr := .binary .intDiv (.base .integer) one zero
private def overflow : Expr := .binary .add (.base .integer)
  (.literal (.integer ⟨9223372036854775807, by decide⟩)) one
private def env := AbstractEnv.ofLocals []
private def key : OperationKey := ⟨"Example.children", 0⟩
private def call (argument : Expr) : Expr := .call .unit [none] [0] (.cons argument .nil)
private def warningKeys (warnings : List IntervalWarning) := warnings.map fun w =>
  (w.key.surfacePreorder, w.cause)
private def entries (ctx : Context) := ctx.independentRev.reverse.map fun entry =>
  (entry.key.surfacePreorder, warningKeys entry.warningsRev)
private def output (source : Expr) := analyzeExpr {} {} 64 env key source

-- フィールド順・容器順・穴と任意のメッセージを、同じ入口の表で照合する。
-- 期待番号は先行順を手で数え、解析や surfacePreorder から生成しない。
#guard
  let cases : List (Expr × List (Nat × List (Nat × WarningCause))) := [
    (call division, [(1, []), (2, [(2, .zeroDivisor)])]),
    (.list (.base .integer) (.cons division (.cons overflow .nil)),
      [(1, [(1, .zeroDivisor)]), (4, [(4, .overflow)])]),
    (.record "Example.Record" [] [0] (.cons division .nil), [(1, [(1, .zeroDivisor)])]),
    (.recordUpdate "Example.Record" [] 1 [0] .unit (.cons division .nil),
      [(1, []), (2, [(2, .zeroDivisor)])]),
    (.interpolation [] (.cons division .nil) (.cons overflow .nil),
      [(1, [(1, .zeroDivisor)]), (4, [(4, .overflow)])]),
    (.partialCall .unit ["x", "y"]
      (.hole none 0 (.base .integer) (.expr none 1 division .nil)) (.base .integer) .empty,
      [(1, []), (2, [(2, .zeroDivisor)])]),
    (.tryOptionDie (.base .integer) "Some" "None" "exit" division (some overflow),
      [(1, [(1, .zeroDivisor)]), (4, [(4, .overflow)])]),
    (.tryOption [.base .integer] "Some" "None" division, [(1, [(1, .zeroDivisor)])]),
    (.binary .eq (.base .boolean)
      (.binary .eq (.base .integer) division zero)
      (.binary .eq (.base .integer) overflow zero),
      [(1, [(2, .zeroDivisor)]), (6, [(7, .overflow)])])]
  cases.all fun (source, expected) =>
    let result := output source
    result.approx.warnings.isEmpty && decide (entries result.context = expected) &&
      decide (result.approx.integer = top)

-- 呼び出しの引数のリストの内側へ再び入る。同じ番号を解析前の skip で消費しない。
#guard
  let result := output (call (.list (.base .integer) (.cons division .nil)))
  entries result.context = [(1, []), (3, [(3, .zeroDivisor)]), (2, [])] ∧
    result.context.next.surfacePreorder = 6 ∧
    result.context.identitiesRev.reverse.map (fun pair => pair.1.surfacePreorder) = [0, 1, 2, 3, 4, 5] ∧
    result.approx.warnings = []

-- 外で既知の0を忘れ、子の Block の内側で bind した0だけを利用する。
#guard
  let outside := AbstractEnv.ofLocals [.integer (normalize 0 0)]
  let localDivision := .binary .intDiv (.base .integer) one (.local 0)
  let external := analyzeExpr {} {} 64 outside key (call localDivision)
  let internal := analyzeExpr {} {} 64 outside key
    (call (.block (.bind .bind (.base .integer) zero (.last localDivision))))
  entries external.context = [(1, []), (2, [])] ∧
    entries internal.context = [(1, []), (2, [(4, .zeroDivisor)])] ∧
    (external.context.independentRev.head?.bind fun entry =>
      entry.initial.map fun initial => integerAt initial 0) = some top

-- 独立入力の return は親の後続の子を止めず、親の正常値は Top のままにする。
#guard
  let result := output (.pipe (.returnE (.base .unit) .unit) division)
  entries result.context = [(1, []), (3, [(3, .zeroDivisor)])] ∧
    result.approx.live = true ∧ result.approx.integer = top ∧ result.approx.warnings = []

-- 元の14操作では候補の保存前、追加の分類一操作を含む15操作では保存後に止まる。
-- 両境界で停止した外側の入力を残し、未訪問の番号を詰めない。
#guard
  let source := call (.list (.base .integer) (.cons division (.cons one .nil)))
  let cases : List (Nat × List (Nat × WarningCause) × Nat) :=
    [(14, [], 9), (15, [(3, .zeroDivisor)], 10)]
  cases.all fun (cap, warnings, saved) =>
    let result := analyzeExpr ⟨⟨cap, 1000⟩, ⟨1000, 1000⟩⟩ {} 64 env key source
    decide (result.coverage = .stopped (.budget (.exceeded ⟨.body, .operations⟩)) ∧
      entries result.context = [(1, []), (3, warnings), (2, [])] ∧
      (result.context.independentRev.head?.map fun entry => entry.result.isOk) = some false ∧
      result.context.next.surfacePreorder = 6 ∧ result.approx.warnings = [] ∧
      result.approx.integer = top ∧ result.context.budget.body.operations = cap ∧
      result.context.budget.body.saved = saved ∧ result.context.budget.body.temporary = 0)

-- with の束縛式と本体は別入力。本体には位置0のリソースと、忘却した外の位置1がある。
-- 束縛式の値を本体へ渡さず、本体内の定数の除算だけを候補とする。
#guard
  let outside := AbstractEnv.ofLocals [.integer (normalize 0 0)]
  let source := .withE "Example.Resource" .unit
    (.seq division (.last (.binary .intDiv (.base .integer) one (.local 1))))
  let result := analyzeExpr {} {} 64 outside key source
  entries result.context = [(1, []), (2, [(2, .zeroDivisor)])] ∧
    (result.context.independentRev.head?.bind fun entry => entry.initial.map fun initial =>
      (initial.locals.length, integerAt initial 1)) = some (2, top) ∧
    (result.context.independentRev.head?.bind fun entry => entry.initial.map fun initial =>
      match lookup initial 0 with
      | some (.unknown (some (.opaqueTop owner))) => owner == "Example.Resource"
      | _ => false) = some true ∧
    result.context.next.surfacePreorder = 8 ∧ result.approx.warnings = []

-- 保護本体を解析し、failure 節・通常の節・ラムダ・lazy の本体は番号だけ辿る。
-- 保護本体から未知の call に入る場合も、子の候補をその独立入力にだけ保存する。
#guard
  let sources : List (Expr × List (Nat × List (Nat × WarningCause)) × Nat) := [
    (.handleFail (.base .unit) (.base .integer) (.last division) (.last overflow),
      [(1, [(1, .zeroDivisor)])], 7),
    (.handleE (.last division) (.cons .fail 0 0 (.last overflow) .nil),
      [(1, [(1, .zeroDivisor)])], 7),
    (.handleE (.last (call division)) .nil,
      [(2, []), (3, [(3, .zeroDivisor)]), (1, [])], 6),
    (.lam [] [] (.base .integer) .empty (.last division), [], 4),
    (.lazyE (.last overflow), [], 4)]
  sources.all fun (source, expected, next) =>
    let result := output source
    decide (entries result.context = expected) && decide (result.context.next.surfacePreorder = next) &&
      result.approx.warnings.isEmpty

-- 本体の根は番号0。with の本体に合成した block 式を挿入せず、内容は元の番号3から始まる。
#guard
  let seed : BodySeed := ⟨.function, .last (.withE "Example.Resource" .unit (.last division)), env⟩
  let result := analyzeBody {} {} 64 "Example.bodyChildren" seed
  entries result.context = [(2, []), (3, [(3, .zeroDivisor)])] ∧
    result.context.next.surfacePreorder = 6 ∧ result.approx.warnings = [] ∧
    result.context.independentRev.all (fun entry => entry.key.definition == "Example.bodyChildren")

-- with の本体で候補を保存した直後に、後続 Block の分類で停止する。
-- Block 自身の結果は停止でも、取得済みの候補を入力へ残す。
#guard
  let source := .withE "Example.Resource" .unit (.seq division (.last one))
  let result := analyzeExpr ⟨⟨14, 1000⟩, ⟨1000, 1000⟩⟩ {} 64 env key source
  result.coverage = .stopped (.budget (.exceeded ⟨.body, .operations⟩)) ∧
    entries result.context = [(1, []), (2, [(2, .zeroDivisor)])] ∧
    (result.context.independentRev.head?.map fun entry => entry.result.isOk) = some false ∧
    result.context.next.surfacePreorder = 5 ∧ result.approx.warnings = [] ∧
    result.context.budget.body.saved = 8 ∧ result.context.budget.body.temporary = 0

end Benitoite.Interval.BudgetAnalysis
