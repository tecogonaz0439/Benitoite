import Benitoite.Interval.BudgetIndependentSound

/-!
# 独立入力の保存と境界の独立例

親と子の候補の分離、元の番号、環境の一時保持、途中停止での保持を確認する。
未知の構成子への振り分けとは区別する。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def division : Expr := .binary .intDiv (.base .integer) one zero
private def emptyEnv := AbstractEnv.ofLocals []
private def key : OperationKey := ⟨"Example.independent", 7⟩
private def oldWarning : IntervalWarning :=
  ⟨⟨"Example.parent", 2⟩, .binary .add (.base .integer), .overflow⟩
private def cap (operations items : Nat) : Limits := ⟨⟨operations, items⟩, ⟨1000, 1000⟩⟩
private def status (result : Except Halt Unit) : Option Halt :=
  match result with | .ok _ => none | .error reason => some reason
private def parentWarnings (ctx : Context) := ctx.warningsRev.map fun warning =>
  (warning.key.definition, warning.key.surfacePreorder, warning.cause)
private def entries (ctx : Context) := ctx.independentRev.map fun entry =>
  (entry.key.surfacePreorder, entry.warningsRev.map fun warning =>
    (warning.key.surfacePreorder, warning.cause))

-- 保存列の不変条件は一般の定理で証明し、逐次実行の固定期待値は #guard で比較する。
-- 非空の保存列から Expr と Block を逐次解析する。Block の容器は数えず、
-- 親の候補と未対応を保ち、同じ本体の累積操作・保存項目を引き継ぐ。
private def parent : Context := {
  budget := ⟨⟨2, 0, 3, 3⟩, ⟨5, 2, 5⟩⟩
  next := key
  warningsRev := [oldWarning]
  identitiesRev := [(⟨"Example.parent", 2⟩, .unit)]
  independentRev := [⟨.expr .unit, ⟨"Example.previous", 3⟩, none,
    .error (.budget (.exceeded ⟨.body, .operations⟩)), [], false⟩]
  unsupported := true }

#guard
    let work := do
      independent 12 emptyEnv (.expr division)
      independent 12 emptyEnv (.block (.last division))
    let output := work {} parent
    let result := output.1
    let final := output.2
    result.isOk = true ∧ parentWarnings final = [("Example.parent", 2, .overflow)] ∧ final.unsupported = true ∧
    entries final = [(10, [(10, .zeroDivisor)]), (7, [(7, .zeroDivisor)]), (3, [])] ∧
    final.next.surfacePreorder = 13 ∧
    final.identitiesRev.map (fun pair => pair.1.surfacePreorder) = [12, 11, 10, 9, 8, 7, 2] ∧
    final.budget.body.operations = 15 ∧ final.budget.whole.operations = 18 ∧
    final.budget.body.saved = 13 ∧ final.budget.whole.saved = 2 ∧
    final.budget.body.temporary = 0

-- 外の0は忘れるが、独立した Block の内側の bind から得た0は利用する。
-- 忘却した入口環境の一項は、作業枠の返却とともに返す。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 0)]
    let source := .binary .intDiv (.base .integer) one (.local 0)
    let outside := independent 12 env (.expr source) {} { next := key }
    let inside := independent 12 env
      (.block (.bind .bind (.base .integer) zero (.last source))) {} { next := key }
    entries outside.2 = [(7, [])] ∧ entries inside.2 = [(7, [(8, .zeroDivisor)])] ∧
    (outside.2.independentRev.head?.bind fun entry => entry.initial.map fun initial => integerAt initial 0) =
      some top ∧ outside.2.budget.body.saved = 4 ∧ outside.2.budget.body.temporary = 0 ∧
    outside.2.budget.body.operations = 9

-- 候補の保存後、後続の Block の分類で操作上限に達する。
-- 停止後は次の独立入力を呼ばず、既存入力・子の候補・実消費をすべて残す。
#guard
    let work := do
      independent 12 emptyEnv (.block (.seq division (.last one)))
      independent 12 emptyEnv (.expr one)
    let output := work (cap 9 100) parent
    let result := output.1
    let final := output.2
    status result = some (.budget (.exceeded ⟨.body, .operations⟩)) ∧
    parentWarnings final = [("Example.parent", 2, .overflow)] ∧
    entries final = [(7, [(7, .zeroDivisor)]), (3, [])] ∧ final.next.surfacePreorder = 10 ∧
    final.budget.body.operations = 9 ∧ final.budget.body.saved = 8 ∧
    final.budget.body.temporary = 0 ∧
    (final.independentRev.head?.map fun entry => entry.approx.integer) = some top

-- 保存枠の拒否では入力を追加しない。忘却の途中と深さでの停止では、
-- 確保済みの記録と停止理由を残す。未取得の環境を正常な入口に見せない。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 0)]
    let noSlot := independent 12 env (.expr one) (cap 100 1) { next := key }
    let forgetting := independent 12 env (.expr one) (cap 0 100) { next := key }
    let depth := independent 0 env (.expr one) {} { next := key }
    status noSlot.1 = some (.budget (.exceeded ⟨.body, .items⟩)) ∧
    noSlot.2.independentRev.length = 0 ∧ noSlot.2.budget.body.saved = 0 ∧
    (noSlot.2.next == key) = true ∧ noSlot.2.budget.body.temporary = 0 ∧
    status forgetting.1 = some (.budget (.exceeded ⟨.body, .operations⟩)) ∧
    entries forgetting.2 = [(7, [])] ∧
    (forgetting.2.independentRev.head?.map fun entry => entry.initial.isNone) = some true ∧
    forgetting.2.budget.body.saved = 1 ∧ forgetting.2.budget.body.temporary = 0 ∧
    status depth.1 = some .depth ∧ entries depth.2 = [(7, [])] ∧
    depth.2.budget.body.saved = 1 ∧ depth.2.budget.body.temporary = 0

end Benitoite.Interval.BudgetAnalysis
