import Benitoite.Interval.EvalClosed
import Benitoite.Interval.BudgetReach

/-!
# 固定域の表層評価と実解析入口の独立例

正常引数の域内・域外・交差、解決済み宣言、記述順、操作の認定の除外を確かめる。
閉じた評価器の固定域内の選択は他の失敗であり、VM の成功値を表さない。
操作の未知の正常値・失敗の導出は、評価関係の構成子から別に組み立てる
（設計書 01-12「区間解析の閉じた対象入力の評価」）。
-/
namespace Benitoite.Interval.DomainExamples
open Benitoite.Surface Benitoite.Release BudgetAnalysis

private def key : OperationKey := ⟨"C4.domain", 10⟩
private def fallback : StandardBinding := ⟨"invalid", .fixedDomain 0 0 0 (.base .unit), []⟩
private def shift (operand : ShiftOperand) (op : ShiftOperation)
    (moduleName : String := "Integer") : StandardBinding :=
  let name := match op with | .left => "shiftLeft" | .right => "shiftRight" | .rightUnsigned => "shiftRightUnsigned"
  ((FixedDomainApi.shift operand op).binding ("resolved:" ++ moduleName ++ "." ++ name)).getD fallback
private def abstract (bindings : List StandardBinding) (locals : List AbstractSlot)
    (declaration : FunName) : AbstractEnv :=
  { (AbstractEnv.ofLocals locals) with standards := bindings, apiAt := fun _ => some declaration }
private def concrete (bindings : List StandardBinding) (locals : List ConcreteValue)
    (declaration : FunName) : ConcreteEnv := ⟨locals.map some, bindings, fun _ => some declaration⟩
private def number (n : Int) : ConcreteValue :=
  if bounded : min64 ≤ n ∧ n ≤ max64 then .integer ⟨n, bounded⟩ else .unit
private def literal (n : Integer64Literal) : Expr := .literal (.integer n)
private def zero : Expr := literal ⟨0, by decide⟩
private def one : Expr := literal ⟨1, by decide⟩
private def bad : Expr := .binary .intDiv (.base .integer) one zero
private def ret : Expr := .returnE (.base .integer) one
private def shiftValue : (operand : ShiftOperand) → ConcreteValue
  | .integer kind => .ofInteger kind ⟨0, by cases kind <;> decide⟩
  | .byte => .other (.base .byte) rfl (by intro h; cases h) (by intro h; cases h)
private def text : ConcreteValue :=
  .other (.base .string) rfl (by intro h; cases h) (by intro h; cases h)

private def call (binding : StandardBinding) (positions : List Nat) (sources : List Expr)
    (labels : List (Option String)) (operation : Bool := false) (primitive : Bool := true) : Expr :=
  .call (if operation then .opName binding.declaration []
    else if primitive then .primName binding.declaration [] [] else .funName binding.declaration [] [])
    labels positions (sources.foldr Exprs.cons .nil)
private def shiftCall (binding : StandardBinding) (reversed : Bool) (primitive : Bool := true) : Expr :=
  if reversed then call binding [1, 0] [.local 0, .local 1] [some "n", some "a"] (primitive := primitive)
  else call binding [0, 1] [.local 1, .local 0] [none, none] (primitive := primitive)
private def warningView (env : AbstractEnv) (source : Expr) :=
  (analyzeExpr {} {} 128 env key source).approx.warnings.map fun w => (w.key, w.cause)
private inductive OutcomeView where
  | normal | failed (reason : Failure) | returned (value : Option Int)
  deriving DecidableEq
private def integerView : ConcreteValue → Option Int
  | .integer n => some n.toInt
  | _ => none
private def outcomeView : EvalOutcome → OutcomeView
  | .normal _ => .normal
  | .failed reason => .failed reason
  | .returned value => .returned (integerView value)
private structure EventView where
  site : Nat
  arguments : List (Option Int)
  outcome : OutcomeView
  deriving DecidableEq
private def observe (env : ConcreteEnv) (source : Expr) (type : Ty) :=
  (evalClosed env ⟨source, type, key⟩ 64).map fun run =>
    (outcomeView run.outcome, run.trace.map fun event =>
      (⟨event.key.surfacePreorder, event.arguments.map integerView,
        match event.result with
        | .normal _ => OutcomeView.normal
        | .rejected reason => OutcomeView.failed reason⟩ : EventView))

-- 宣言の分類と上端は実ソースの契約から独立に指定する。組み込み20宣言、包み7宣言。
private def widths : List (String × ShiftOperand × Int × Bool) :=
  [("Integer", .integer .integer64, 63, true),
   ("Integer8", .integer .integer8, 7, true), ("Integer16", .integer .integer16, 15, true),
   ("Integer32", .integer .integer32, 31, true), ("Integer64", .integer .integer64, 63, false),
   ("UnsignedInteger16", .integer .unsignedInteger16, 15, true),
   ("UnsignedInteger32", .integer .unsignedInteger32, 31, true),
   ("UnsignedInteger64", .integer .unsignedInteger64, 63, true),
   ("UnsignedInteger", .integer .unsignedInteger64, 63, false),
   ("Byte", .byte, 7, true), ("UnsignedInteger8", .byte, 7, false)]
private def directions (operand : ShiftOperand) : List ShiftOperation :=
  match operand with
  | .integer .integer8 | .integer .integer16 | .integer .integer32 | .integer .integer64 =>
      [.left, .right, .rightUnsigned]
  | _ => [.left, .right]

-- 左シフトの捨てるビットを overflow とせず、交差・Top・Bottom には警告しない。
#guard widths.all fun (moduleName, operand, upper, primitive) => (directions operand).all fun direction =>
  let binding := shift operand direction moduleName
  [false, true].all fun reversed =>
    let source := shiftCall binding reversed primitive
    [normalize 0 upper, normalize (-2) (-1), normalize (upper+1) (upper+2),
      normalize (-1) 0, normalize upper (upper+1), top, .bottom].map
        (fun interval => warningView
          (abstract [binding] [.integer interval, .unknown (some operand.type)] binding.declaration) source) =
      [[], [(key, .outsideDomain)], [(key, .outsideDomain)], [], [], [], []]

-- 域内は許された他の失敗、域外は固定域拒否。正常な引数は契約順で trace に残る。
#guard widths.all fun (moduleName, operand, upper, primitive) => (directions operand).all fun direction =>
  let binding := shift operand direction moduleName
  [false, true].all fun reversed =>
    [(-1, Failure.outsideDomain), (0, Failure.unknown), (upper, Failure.unknown),
      (upper+1, Failure.outsideDomain)].all fun (amount, reason) =>
      let env := concrete [binding] [number amount, shiftValue operand] binding.declaration
      match observe env (shiftCall binding reversed primitive) operand.type with
      | some (.failed actual, [⟨10, [value, some actualAmount], .failed eventReason⟩]) =>
          actual = reason ∧ eventReason = reason ∧ actualAmount = amount ∧
            value = (if operand = .integer .integer64 then some 0 else none)
      | _ => False

-- 最大値の左シフトでも、捨てるビットを算術の overflow の原因にしない。
#guard
  let binding := shift (.integer .integer64) .left
  let source := shiftCall binding false
  (warningView (abstract [binding] [.integer (normalize 1 1), .integer (normalize max64 max64)]
      binding.declaration) source).isEmpty &&
    (match observe (concrete [binding] [number 1, number max64] binding.declaration) source (.base .integer) with
     | some (.failed .unknown, [⟨10, [some 9223372036854775807, some 1], .failed .unknown⟩]) => true
     | _ => false)

-- 二表の不在・偽装・別のキーでは認定しない。
private def identityBinding := shift (.integer .integer64) .left
private def identitySource : Expr := call identityBinding [0, 1] [one, literal ⟨64, by decide⟩] [none, none]
private def identityEnvs : List ConcreteEnv :=
  [⟨[], [], fun _ => some identityBinding.declaration⟩,
   ⟨[], [identityBinding], fun _ => none⟩,
   ⟨[], [identityBinding], fun site => if site = childKey key [] then some identityBinding.declaration else none⟩,
   ⟨[], [identityBinding], fun _ => some "user:shift"⟩]
#guard identityEnvs.all fun env =>
  (observe env identitySource (.base .integer)).isNone ∧
    warningView ({ (abstract env.standards [] "unused") with apiAt := env.apiAt }) identitySource = []

-- 同じ表があっても、頭が別の宣言なら認定しない。
#guard
  let env := concrete [identityBinding] [] identityBinding.declaration
  let source := .call (.funName "user:shift" [] []) [none, none] [0, 1]
    (.cons one (.cons (literal ⟨64, by decide⟩) .nil))
  (observe env source (.base .integer)).isNone ∧
    warningView (abstract [identityBinding] [] identityBinding.declaration) source = []

-- 位置の重複・欠落は、域外の整数があっても標準 call の警告を作らない。
#guard [[0, 0], [0], [1, 2]].all fun positions =>
  let binding := shift (.integer .integer64) .left
  let source := call binding positions [.local 1, .local 0] [some "a", some "n"]
  (observe (concrete [binding] [number 64, number 1] binding.declaration) source (.base .integer)).isNone ∧
    warningView (abstract [binding] [.integer (normalize 64 64), .integer (normalize 1 1)]
      binding.declaration) source = []

-- 引数の失敗・return は親の型に依存しない。後続引数と親の事象を作らない。
-- ソース順は n,a と a,n の両方を使う。
#guard
  let binding := shift (.integer .integer64) .left
  let env := concrete [binding] [] binding.declaration
  decide <| [call binding [1, 0] [bad, .funName "unreachable" [] []] [some "n", some "a"],
   call binding [0, 1] [bad, .funName "unreachable" [] []] [none, none]].map
      (fun source => observe env source (.base .boolean)) =
    [some (.failed .zeroDivisor, [⟨12, [some 1, some 0], .failed .zeroDivisor⟩]),
     some (.failed .zeroDivisor, [⟨12, [some 1, some 0], .failed .zeroDivisor⟩])]
#guard
  let binding := shift (.integer .integer64) .left
  let env := concrete [binding] [] binding.declaration
  decide <| [call binding [0, 1] [ret, bad] [none, none],
   call binding [1, 0] [ret, .funName "unreachable" [] []] [some "n", some "a"]].map
      (fun source => observe env source (.base .boolean)) =
    [some (.returned (some 1), []), some (.returned (some 1), [])]
#guard
  let binding := shift (.integer .integer64) .left
  let source := call binding [0, 1] [.binary .add (.base .integer) one one, bad] [none, none]
  decide <| observe (concrete [binding] [] binding.declaration) source (.base .unit) =
    some (.failed .zeroDivisor,
      [⟨12, [some 1, some 1], .normal⟩, ⟨15, [some 1, some 0], .failed .zeroDivisor⟩]) ∧
    warningView (abstract [binding] [] binding.declaration) source =
      [(⟨"C4.domain", 15⟩, .zeroDivisor)]

-- 操作はハンドラで差し替わる。域外の code/port も固定域の具体規則を持たない。
private def exitSource : Expr :=
  .call (.primName "resolved:Process.exit" [.base .unit] []) [some "code"] [0]
    (.cons (literal ⟨300, by decide⟩) .nil)
private def listenSource : Expr :=
  .call (.primName "resolved:Http.Listen.listen" [] []) [some "host", some "port"] [0, 1]
    (.cons (.local 0) (.cons (literal ⟨65536, by decide⟩) .nil))
-- 組み込みの操作の primName も単相なら照会するが、操作の固定域の項は渡さない。
#guard [(exitSource, "resolved:Process.exit"), (listenSource, "resolved:Http.Listen.listen")].all fun (source, declaration) =>
  let env := abstract [identityBinding] [.unknown (some (.base .string))] declaration
  warningView env source = [] ∧
    (rangeCallBinding (rangeTables env) ⟨source, .base .unit, key⟩).isNone
#guard standardCallHead (.primName "resolved:Http.Listen.listen" [] []) =
  some "resolved:Http.Listen.listen"

-- 利用者の操作の opName は、固定域を持つ表が渡されても認定しない。
#guard
  let binding := identityBinding
  let source := call binding [0, 1] [one, literal ⟨64, by decide⟩] [none, none] true
  warningView (abstract [binding] [] binding.declaration) source = [] ∧
    (observe (concrete [binding] [] binding.declaration) source (.base .integer)).isNone

-- 型引数・エフェクト引数・辞書付きの頭とメソッド・操作は、同じ有効な二表でも除外する。
#guard
  let binding := identityBinding
  let heads : List Expr :=
    [.primName binding.declaration [.base .unit] [],
     .primName binding.declaration [] [.mk (fun _ => false) []],
     .funName binding.declaration [.base .unit] [],
     .funName binding.declaration [] [.mk (fun _ => false) []],
     .opName binding.declaration [], .opName binding.declaration [.base .unit],
     .funDicts binding.declaration [] [] [.local 0] ["a", "n"] [.base .integer, .base .integer],
     .opDicts binding.declaration [] [.local 0] ["a", "n"] [.base .integer, .base .integer],
     .methName (.local 0) binding.declaration [] [] [] ["a", "n"] [.base .integer, .base .integer]]
  heads.all fun head =>
    let source := .call head [none, none] [0, 1] (.cons one (.cons (literal ⟨64, by decide⟩) .nil))
    let env := abstract [binding] [] binding.declaration
    (rangeCallBinding (rangeTables env) ⟨source, .base .integer, key⟩).isNone ∧
      (targetOperationAt env key source).isNone ∧ warningView env source = [] ∧
      (observe (concrete [binding] [] binding.declaration) source (.base .integer)).isNone

-- 任意の型内の正常値と任意の失敗を既存の未知規則で許す。子の事象は作らない。
example (locals : List (Option ConcreteValue)) (value : ConcreteValue) :
    let env : ConcreteEnv := ⟨locals, [], fun _ => none⟩;
    EvalPartial env ⟨exitSource, value.type, key⟩ (.normal value) [] ∧
    EvalPartial env ⟨exitSource, value.type, key⟩ (.failed .unknown) [] ∧
    EvalPartial env ⟨listenSource, value.type, key⟩ (.normal value) [] ∧
    EvalPartial env ⟨listenSource, value.type, key⟩ (.failed .unknown) [] := by
  dsimp only
  let env : ConcreteEnv := ⟨locals, [], fun _ => none⟩
  have exitUnknown : UnknownAt env ⟨exitSource, value.type, key⟩ := Or.inr (Or.inr rfl)
  have listenUnknown : UnknownAt env ⟨listenSource, value.type, key⟩ := Or.inr (Or.inr rfl)
  exact ⟨.unknownNormal _ _ _ exitUnknown rfl, .unknownFailed _ _ exitUnknown,
    .unknownNormal _ _ _ listenUnknown rfl, .unknownFailed _ _ listenUnknown⟩

end Benitoite.Interval.DomainExamples
