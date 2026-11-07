import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound
import Benitoite.Release.Refinement.Surface.CheckDeclarations

/-!
# Log の操作の検査器の受理と拒否

組込みの効果 `Log` の二つの操作（`Log.emit`・`Log.enabled`）と `Console.Write` の操作を持つ表で、篩付きの表層の
検査器が、操作の呼出しを効果 `{Log}` で受理し、全ての操作を処理する handle で効果を除き、操作の一部だけを処理する
handle では効果を残すことを確かめる。同じ表で、処理した後の `Console.Write` を空の効果の宣言で隠す関数は拒否する
（設計書 01-12「ハンドラ」）。
-/
namespace Benitoite.Release.Refinement.Surface.LogExamples
open Check

private def operation (eff : String) (ns : List String) (ps : List Ty) (ret : Ty) : PrimSig where
  tparams := []
  neffs := 0
  names := ns
  params := ps
  ret := ret
  eff := Eff.single eff
  admits := fun _ _ => True
  kind := .io
  opEff := some eff

private def builtins : Builtins where
  sig := fun b =>
    if b = "Log.emit" then some (operation "Log" ["message"] [.base .string] (.base .unit))
    else if b = "Log.enabled" then some (operation "Log" ["level"] [.base .integer] (.base .boolean))
    else if b = "Console.writeError" then some (operation "Console.Write" ["text"] [.base .string] (.base .unit))
    else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun l => if l = "Log" then some ["Log.emit", "Log.enabled"]
    else if l = "Console.Write" then some ["Console.writeError"] else none
  sat := fun _ _ _ => False
  refGet := "get"
  refSet := "set"

private def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none

private def input : Check.Input where
  D := declarations
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [.name "Log" (.fixed .top), .name "Console.Write" (.fixed .top)], ctors := fun _ => [] }
  admitsDec := fun _ _ _ => true
  proofSteps := 10

private def call1 (name arg : String) (value : Expr) : Expr :=
  .call (.primName name [] [] []) [some arg] [0] (.cons value .nil)

private def emit : Expr := call1 "Log.emit" "message" (.literal (.string "done"))
private def write : Expr := call1 "Console.writeError" "text" (.literal (.string "done"))

private def handled (output : Bool) : Expr :=
  .handleE (.last emit)
    (.cons (.prim "Log.emit") 1 0 (if output then .seq write (.last (.resume 0 .unit)) else .last (.resume 0 .unit))
      (.cons (.prim "Log.enabled") 1 0 (.last (.resume 0 (.literal (.boolean false)))) .nil))

private def partialHandled : Expr :=
  .handleE (.last emit) (.cons (.prim "Log.emit") 1 0 (.last (.resume 0 .unit)) .nil)

private def effectOf (e : Expr) : Option (Bool × Bool) :=
  match Check.checkExpr input [] [] [] none .other [] e with
  | .ok (_, ε) => some (ε.test (.name "Log" (.fixed .top)), ε.test (.name "Console.Write" (.fixed .top)))
  | .error _ => none

/-- 操作の呼出しは効果 `{Log}` で受理する。 -/
theorem emit_checked : effectOf emit = some (true, false) := by
  cbv

/-- 二つの操作を処理する handle は `Log` を除く。節で `Console.Write` の操作を呼べば、その効果だけが残る。 -/
theorem handled_checked :
    effectOf (handled false) = some (false, false) ∧ effectOf (handled true) = some (false, true) := by
  constructor <;> cbv

/-- 操作の一部だけを処理する handle は `Log` を除かない。 -/
theorem partial_retains_log : effectOf partialHandled = some (true, false) := by
  cbv

private def entryDef (e : Expr) (eff : Eff) : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := eff
  body := .last e

/-- 処理した後の `Console.Write` を空の効果の宣言で隠す関数は拒否し、同じ本体を `{Console.Write}` の宣言で受理する。 -/
theorem console_pure_rejected :
    (CheckDeclarations.checkDef input [] (entryDef (handled true) Eff.empty)).toBool = false ∧
    (CheckDeclarations.checkDef input [] (entryDef (handled true) (Eff.single "Console.Write"))).toBool = true := by
  constructor <;> cbv

end Benitoite.Release.Refinement.Surface.LogExamples
