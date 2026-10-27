import Benitoite.Interval.BudgetReach
import Benitoite.Interval.CallReachWhole

/-!
# 構文的な到達可能性の独立例

未知の形の内側に対象演算があっても親の範囲には入れず、
後続の元のキーを保つ。腕・guard と const の具体規則も確認する。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release

private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def division : Expr := .binary .intDiv (.base .integer) one zero
private def root : OperationKey := ⟨"Example.syntacticReach", 7⟩

-- 位置だけの契約では未知の内側の除算も対象になるため、範囲の印も観察する。
private def targets (source : Expr) : List (Nat × Option BinOp) :=
  (numberSyntacticReach root (syntacticReachExpr source)).filterMap fun (key, eligible, node) =>
    if eligible then (targetOperationAt node).map fun op => (key.surfacePreorder, match op with
      | .binary op (.base .integer) => some op | _ => none) else none

-- list の内側のキー9は除外するが、後続の除算のキー12は詰めない。
-- 未対応の Boolean の等値の内側も除外し、const・括弧の内側には具体規則で進む。
example :
    targets (.block (.seq (.list (.base .integer) (.cons division .nil)) (.last division))) =
      [(12, some .intDiv)] ∧
    targets (.binary .eq (.base .boolean)
      (.binary .eq (.base .integer) division zero) (.literal (.boolean true))) = [] ∧
    targets (.constE (.base .integer) (.paren division)) =
      [(9, some .intDiv)] := by
  simp only [targets, division, one, zero, syntacticReachExpr, syntacticReachChildren, syntacticReachBlock]
  decide +kernel

-- 範囲は実行の到達を要求しない。整数の可能性がある腕の guard と本体を含める。
example :
    targets (.matchE (.base .integer) (.local 0)
      (.cons [] (some (.binary .eq (.base .integer) division zero)) (.last division) .nil)) =
      [(9, some .eq), (10, some .intDiv),
       (14, some .intDiv)] := by
  simp only [targets, division, one, zero, syntacticReachExpr, syntacticReachChildren, syntacticReachBlock, syntacticReachArms]
  decide +kernel

-- 同じ部分木を独立した入力にすれば、その根からの範囲となる。
-- 親の with/handle の範囲を広げることとは区別する。
example :
    targets (.withE "Example.Resource" division (.last division)) = [] ∧
    targets (.handleE (.last division) .nil) = [] ∧
    targets division = [(7, some .intDiv)] := by
  simp only [targets, division, one, zero, syntacticReachExpr, syntacticReachChildren]
  decide +kernel

private def rangeNames : RangeNames := ⟨"Std.Range.CheckedInteger", "Std.Result.Result", "Std.Range.Error",
  "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
private def checkBinding : StandardBinding := ⟨"Std.Range.checkInteger", .rangeCheck rangeNames⟩
private def callWithDivision : Expr := .call (.funName checkBinding.declaration [] [])
  [none, none, none] [0, 1, 2] (.cons division (.cons zero (.cons one .nil)))
private def recognized : AbstractEnv :=
  ⟨[], [checkBinding], fun key => if key = root then some checkBinding.declaration else none, .empty ⟨[], 0⟩⟩
private def divisionWarning : IntervalWarning :=
  ⟨⟨"Example.syntacticReach", 9⟩, .binary .intDiv (.base .integer), .zeroDivisor⟩

-- 構文だけの候補では引数の除算が残る。追加の保証は同じ構文・元キーで二表を使う。
-- Scope の述語全体の Decidable を展開せず、認定の有限表だけを kernel で確かめる。
example :
    ¬ (CallReach.expr { recognized with standards := [] } callWithDivision).allows root divisionWarning ∧
    ¬ (CallReach.expr { recognized with apiAt := fun _ => none } callWithDivision).allows root divisionWarning ∧
    ¬ (CallReach.expr recognized callWithDivision).allows (advanceKey root 1) divisionWarning := by
  refine ⟨?_, ?_, ?_⟩
  all_goals apply CallReach.unrecognized_call_excluded
  all_goals decide +kernel

example : (CallReach.expr recognized callWithDivision).allows root divisionWarning := by
  simp only [callWithDivision, CallReach.exprTables, CallReach.gate]
  change rangeCallAt recognized root callWithDivision ≠ none ∧ _
  refine ⟨by decide +kernel, Or.inr ?_⟩
  rw [CallReach.exprsTables]
  change (CallReach.expr recognized division ++ CallReach.exprs recognized (.cons zero (.cons one .nil))).allows _ _
  apply Or.inl
  simp only [division, CallReach.exprTables]
  change (CallReach.root division ++ CallReach.children recognized division).allows _ _
  exact Or.inl ⟨rfl, rfl⟩

#guard targets callWithDivision = [(9, some .intDiv)]

#guard
  let missing : AbstractEnv := { recognized with apiAt := fun _ => none }
  let nested := analyzeExpr {} {} 64 missing ⟨"Example.syntacticReach", 6⟩
    (.list (.base .integer) (.cons callWithDivision .nil))
  let entries : Context → List (Nat × List Nat) := fun ctx => ctx.independentRev.reverse.map fun entry =>
    (entry.key.surfacePreorder, entry.warningsRev.map (fun w => w.key.surfacePreorder))
  entries nested.context == [(8, []), (9, [9]), (12, []), (13, []), (7, [])]

end Benitoite.Interval.BudgetAnalysis
