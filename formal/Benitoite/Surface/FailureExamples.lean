import Benitoite.Surface.CheckProgramSound
import Benitoite.Surface.Theorems

/-!
# 表層の型付きの失敗の正負例

検査の公開入口で、具体化・捕捉・非再開・再raiseを確かめる。
効果の期待値は検査器から作らず、閉じた型と有限支持から独立に与える。
-/
namespace Benitoite.Surface.Check.FailureExamples
open Benitoite.Release Benitoite.Surface.CheckTools
private def intTy : Ty := .base .integer
private def strTy : Ty := .base .string
private def failString : Eff := .mk (fun _ => false) [strTy]
private def failInt : Eff := .mk (fun _ => false) [intTy]
private def rows : Eff := .mk (fun a => a == .rho 0 || a == .rho 1) []
private def value : Expr := .literal (.integer ⟨7, by decide⟩)
private def errorValue : Expr := .literal (.string "bad")
private def raiseAt (T E : Ty) (e : Expr) : Expr :=
  .call (.raise T E) [none] [0] (.cons e .nil)
private def raised : Expr := raiseAt intTy strTy errorValue
private def caught : Expr := .handleFail strTy intTy (.last raised) (.last value)
private def declarations : Declarations := {
  funs := fun n =>
    if n == "Other.twoRows" then some {
      tparams := [], neffs := 2, names := [], params := [], ret := intTy, eff := rows }
    else if n == "Other.oneRow" then some {
      tparams := [], neffs := 1, names := ["value"], params := [intTy], ret := intTy,
      eff := .mk (fun a => a == .rho 0) [] }
    else if n == "Other.fixed" then some {
      tparams := [], neffs := 1, names := [], params := [], ret := intTy,
      eff := .mk (fun a => a == .rho 0) [strTy] }
    else if n == "Other.apply" then some {
      tparams := [], neffs := 1, names := ["body"],
      params := [.fn [] [] intTy (.mk (fun a => a == .rho 0) [])], ret := intTy,
      eff := .mk (fun a => a == .rho 0) [] }
    else if n == "Other.arbitrary" then some {
      tparams := [{}], neffs := 0, names := [], params := [], ret := .tvar 0, eff := emptyEff }
    else none,
  cons := fun _ => none }
private def builtins : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
  refGet := "get", refSet := "set" }
private def input : Input := {
  D := declarations, B := builtins, satDec := fun _ _ _ => true,
  admitsDec := fun _ _ _ => false, opPrim := fun _ _ => none, ctors := fun _ => [],
  atoms := [.nameTop "State", .nameTop "IO", .rho 0, .rho 1] }
private def check (e : Expr) := checkExpr input .strict [] [] none .other [] e
private def hasResult (e : Expr) (t : Ty) (eff : Eff) : Bool :=
  match check e with
  | .ok (actual, effects) => tyEq input.atoms actual t && effEq input.atoms effects eff
  | .error _ => false

private def call0 (f : Expr) : Expr := .call f [] [] .nil
private def partialValue (eff : Eff) : Expr :=
  .partialCall (.funName "Other.oneRow" [] [eff]) ["value"]
    (.hole (some "value") 0 intTy .nil) intTy eff

-- 直接のraise、同じEの捕捉、節の別型への再raiseの効果をそれぞれ固定する。
example : hasResult raised intTy failString = true := by decide
example : hasResult caught intTy emptyEff = true := by decide
example : hasResult (.handleFail strTy intTy (.last raised)
    (.last (raiseAt intTy intTy value))) intTy failInt = true := by decide
-- 同じEを再raiseしても、節のFailを捕捉済みとして除去しない。
example : hasResult (.handleFail strTy intTy (.last raised)
    (.last (raiseAt intTy strTy (.local 1)))) intTy failString = true := by decide
-- 予約した0番は、通常のresume・値の持ち出しのどちらにも使えない。
example : (check (.handleFail strTy intTy (.last raised) (.last (.resume 0 value)))).isOk = false := by decide
example : (check (.handleFail strTy intTy (.last raised) (.last (.local 0)))).isOk = false := by decide
-- 捕捉するEを取り違えると、bodyの効果の包含で拒否される。
example : (check (.handleFail intTy intTy (.last raised) (.last value))).isOk = false := by decide
-- 通常の節の列はFailを受け入れず、普通の節との混在も型付けできない。
example : (check (.handleE (.last raised)
    (.cons .fail 1 1 (.last value) (.cons (.user "other") 0 0 (.last value) .nil)))).isOk = false := by decide
-- 異なるFailを二つの無制約の行へ渡す。単一化前には署名にFailがなくても拒否する。
example : (check (.funName "Other.twoRows" [] [failString, failInt])).isOk = false := by decide
example : (check (call0 (.funName "Other.twoRows" [] [failString, failInt]))).isOk = false := by decide
-- 同じ型のFailの重複と、Failを持たない通常の行多相は受理する。
example : (check (.funName "Other.twoRows" [] [failString, failString])).isOk = true := by decide
example : (check (.funName "Other.twoRows" []
    [.mk (fun a => a == .rho 0) [], .mk (fun a => a == .rho 1) []])).isOk = true := by decide
-- Qは署名由来であり、固定Failと併記した行へFailを渡せない。
example : (check (.funName "Other.fixed" [] [failInt])).isOk = false := by decide
example : (check (.funName "Other.fixed" [] [emptyEff])).isOk = true := by decide
-- 部分適用と、持ち出したラムダでも潜在効果を失わない。
example : (check (partialValue failString)).isOk = true := by decide
example : (check (.lam [] [] intTy failString
    (.last (.returnE intTy raised)))).isOk = true := by decide
-- 合流の一方のFailだけを残す退行を、式の結果で拒否する。
example : (check (.ite (.literal (.boolean true)) (.last raised)
    (.last (raiseAt intTy intTy value)))).isOk = false := by decide

-- 高階の行は呼び出し時にFailを保持し、外側の捕捉でだけ除く。
private def failingLambda : Expr := .lam [] [] intTy failString (.last (.returnE intTy raised))
private def higherCall : Expr := .call (.funName "Other.apply" [] [failString])
  [none] [0] (.cons failingLambda .nil)
example : hasResult higherCall intTy failString = true := by decide
example : hasResult (.handleFail strTy intTy (.last higherCall) (.last value)) intTy emptyEff = true := by decide
-- 本体だけがNoFailを必要とする署名は、Qを後付けせず拒否する。
private def callsFixed (eff : Eff) : Def := {
  tparams := [], neffs := 1, names := [], params := [], ret := intTy, eff,
  body := .last (.returnE intTy (call0 (.funName "Other.fixed" [] [.mk (fun a => a == .rho 0) []]))) }
private def reason {α : Type} : Result α → Option String
  | .ok _ => none
  | .error e => some e.reason
example : reason (checkDef input [] (callsFixed (.mk (fun a => a == .rho 0) []))) =
    some "function instantiation violates scope or NoFail" := by decide
example : (checkDef input [] (callsFixed (.mk (fun a => a == .rho 0) [strTy]))).isOk = true := by decide
-- 型の束縛TをFailのエラー型にして節の外へ漏らすと、shiftし直す検査が拒否する。
private def leaksRigid : Expr := .handleFail strTy intTy (.last raised)
  (.last (raiseAt intTy (.tvar 0) (call0 (.funName "Other.arbitrary" [.tvar 0] []))))
example : reason (check leaksRigid) = some "Fail clause effect mentions its rigid result type" := by decide
-- 通常の効果は捕捉後にも残す。節のFailとの合流も失わない。
private def ioBody : Expr := call0 (.funName "Other.twoRows" [] [failString, .mk (fun a => a == .nameTop "IO") []])
example : hasResult (.handleFail strTy intTy (.last ioBody) (.last value))
    intTy (.mk (fun a => a == .nameTop "IO") []) = true := by decide

-- Showや等値の制約を持たないエラー値でも捕捉できる。
example : (checkExpr input .strict [] [some (.opaqueTop "Secret")] none .other []
    (.handleFail (.opaqueTop "Secret") intTy
      (.last (raiseAt intTy (.opaqueTop "Secret") (.local 0))) (.last value))).isOk = true := by decide
-- 節から持ち出すラムダはエラー値を捕え、利用不能な継続には触れない。
private def escapedTy : Ty := .fn [] [] strTy emptyEff
example : (check (.handleFail strTy escapedTy
    (.last (raiseAt escapedTy strTy errorValue))
    (.last (.lam [] [] strTy emptyEff (.last (.returnE strTy (.local 1))))))).isOk = true := by decide
-- ほかの検査による偶然の拒否を避け、単一Failと非再開の拒否理由も固定する。
example : reason (check (.funName "Other.twoRows" [] [failString, failInt])) =
    some "multiple Fail types or an unrestricted row at a Fail position" := by decide
example : reason (check (.handleFail strTy intTy (.last raised) (.last (.resume 0 value)))) =
    some "continuation is missing or hidden" := by decide

-- 関数型の結びと、コレクション内の潜在効果も再帰的に検査する。
example : (check (.ite (.literal (.boolean true))
    (.last (.funName "Other.oneRow" [] [failString]))
    (.last (.funName "Other.oneRow" [] [failInt])))).isOk = false := by decide
example : (checkExpr input .strict []
    [some (.list (.fn [] [] intTy (.mk (fun _ => false) [strTy, intTy])))]
    none .other [] (.local 0)).isOk = false := by decide
-- 探索中だけ不正な具体化を許すこともない。
example : [ResumeMode.strict, .relaxed].all (fun mode =>
    !(checkExpr input mode [] [] none .other []
      (.funName "Other.twoRows" [] [failString, failInt])).isOk) = true := by decide

end Benitoite.Surface.Check.FailureExamples
