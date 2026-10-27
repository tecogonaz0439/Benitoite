import Benitoite.Interval.FixedDomain
import Benitoite.Interval.Sound
import Benitoite.Interval.BudgetReach

/-!
# 固定域と解決済み標準束縛の独立例

定義域の端・不交差・空区間と、同じ表示名の別宣言を区別する。
評価関係を実際に合成し、定義域内で他の失敗が残ることも確かめる
（設計書 01-12「区間解析の直接引数と固定の定義域」）。
-/
namespace Benitoite.Interval.FixedDomainExamples
open Benitoite.Release Benitoite.Surface

private def summary (api : FixedDomainApi) : Option (Nat × List String × Int × Int) :=
  api.contract.map fun contract => (contract.argument, contract.parameters, contract.lo, contract.hi)

-- 七種と Byte の幅を、期待する十進の上端から独立に照合する。
#guard ([.integer .integer8, .integer .integer16, .integer .integer32, .integer .integer64,
    .integer .unsignedInteger16, .integer .unsignedInteger32, .integer .unsignedInteger64, .byte] :
    List ShiftOperand).map (fun operand => summary (.shift operand .left)) =
  [some (1, ["a", "n"], 0, 7), some (1, ["a", "n"], 0, 15),
   some (1, ["a", "n"], 0, 31), some (1, ["a", "n"], 0, 63),
   some (1, ["a", "n"], 0, 15), some (1, ["a", "n"], 0, 31),
   some (1, ["a", "n"], 0, 63), some (1, ["a", "n"], 0, 7)]

#guard ([.integer .integer8, .integer .integer16, .integer .integer32, .integer .integer64,
    .integer .unsignedInteger16, .integer .unsignedInteger32, .integer .unsignedInteger64, .byte] :
    List ShiftOperand).all (fun operand =>
      summary (.shift operand .right) == summary (.shift operand .left))

#guard ([.integer .integer8, .integer .integer16, .integer .integer32, .integer .integer64,
    .integer .unsignedInteger16, .integer .unsignedInteger32, .integer .unsignedInteger64, .byte] :
    List ShiftOperand).map (fun operand => summary (.shift operand .rightUnsigned)) =
  [some (1, ["a", "n"], 0, 7), some (1, ["a", "n"], 0, 15),
   some (1, ["a", "n"], 0, 31), some (1, ["a", "n"], 0, 63), none, none, none, none]

example : FixedDomainApi.argumentTypes (.shift .byte .left) = [.base .byte, .base .integer] := rfl

private def shiftByte : FixedDomainContract := ⟨1, ["a", "n"], 0, 7, by decide⟩
#guard [shiftByte.disjoint (normalize (-20) (-1)), shiftByte.disjoint (normalize 8 100),
    shiftByte.disjoint (normalize (-1) 0), shiftByte.disjoint (normalize 7 8),
    shiftByte.disjoint top, shiftByte.disjoint .bottom] =
  [true, true, false, false, false, false]

-- 不交差から、同じシフト量を持つ標準事象の失敗までを合成する。
example (env : ConcreteEnv) (key : OperationKey) (binding : StandardBinding)
    (args : List ConcreteValue) (value : Integer64Value) (outcome : EvalOutcome)
    (identified : env.standardAt key = some binding)
    (rule : binding.rule = shiftByte.rule (.base .byte))
    (atPosition : args[1]? = some (.integer value))
    (member : Mem value.toInt (normalize 8 max64))
    (evaluated : EvalStandardAt env key args outcome) :
    outcome = .failed .outsideDomain :=
  fixed_at_disjoint_failed identified rule (by decide) member atPosition evaluated

private def binding : StandardBinding := ⟨"resolved:Byte.shiftLeft", shiftByte.rule (.base .byte), [.base .byte, .base .integer]⟩
private def key : OperationKey := ⟨"FixedDomain.identity", 9⟩
private def env : AbstractEnv :=
  { (AbstractEnv.ofLocals []) with
    standards := [binding]
    apiAt := fun site => if site = key then some binding.declaration else none }
private def call (declaration : FunName) : Expr :=
  .call (.primName declaration [] []) ["a", "n"] [0, 1] (.cons (.local 1) (.cons (.local 0) .nil))
private def operationCall : Expr :=
  .call (.primName "resolved:Console.writeLine" [] []) [some "text"] [0]
    (.cons (.literal (.string "x")) .nil)
private def target (environment : AbstractEnv) (site : OperationKey) (source : Expr) : Option String :=
  (targetOperationAt environment site source).map fun operation => match operation with
    | .standard found => found.declaration
    | .binary _ _ => "binary"
    | .neg _ => "neg"

-- 位置の同定は標準表と元キーを使う。固定域の認定は rangeCallBinding が別に行う。
#guard [target env key (call binding.declaration), target env key operationCall,
    target env key (call "user:Byte.shiftLeft"),
    target { env with apiAt := fun _ => some "user:Byte.shiftLeft" } key (call "user:Byte.shiftLeft"),
    target env (advanceKey key 1) (call binding.declaration),
    target { env with standards := [] } key (call binding.declaration),
    target { env with apiAt := fun _ => none } key (call binding.declaration),
    target env key (.partialCall (.funName binding.declaration [] []) [] .nil (.base .unit) (.mk (fun _ => false) [])),
    target env key (.pipe (.local 0) (call binding.declaration))] =
  [some "resolved:Byte.shiftLeft", none, none, none, none, none, none, none, none]

-- 組み込みの操作は primName で照会しても、固定域の項を持たず W0404 を作らない。
#guard
  let operations := { env with apiAt := fun _ => some "resolved:Console.writeLine" }
  (BudgetAnalysis.analyzeExpr {} {} 128 operations key operationCall).approx.warnings = [] ∧
    (targetOperationAt operations key operationCall).isNone

end Benitoite.Interval.FixedDomainExamples
