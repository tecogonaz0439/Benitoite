import Benitoite.Surface.CheckSound
import Benitoite.Surface.Examples

/-! 検査全体の評価例。成功の真偽値と、原子集合の上の結果型・エフェクトを比較する。 -/
namespace Benitoite.Surface.Check.Examples
open Benitoite.Release Benitoite.Surface.CheckTools
open Benitoite.Surface.Examples

private def atoms : List Atom :=
  [.name "State", .name "Console.Write", .name "Process.Exit", .name "Identity",
   .name "IO", .name "A", .name "B", .rho 0, .rho 1]

private def constructors : DataName → List ConName
  | "Result" => ["Result.Ok", "Result.Error"]
  | "Option" => ["Option.Some", "Option.None"]
  | "Point" => ["Point"]
  | "Pair" => ["Pair"]
  | _ => []

/-- Release.Examples の表では admits は型引数の個数である。 -/
private def admits (B : Builtins) (b : PrimName) (_ : List TParam) (ts : List Ty) : Bool :=
  match B.sig b with
  | none => false
  | some s => ts.length == s.ntys

private def input (D : Declarations) (op : OpPrim := execOp) : Input :=
  { D, B := Release.Examples.builtins, satDec := fun _ _ _ => true,
    admitsDec := admits Release.Examples.builtins, opPrim := op, ctors := constructors, atoms }

private def defsOk (q : Input) (P : Surface.Program) (names : List FunName) : Bool :=
  names.all fun f => match P.defs f with
    | none => false
    | some d => (checkDef q [] d).toBool

private def got (q : Input) (x : Result Inferred) (a : Ty) (ε : Eff := emptyEff) : Bool :=
  match x with
  | .error _ => false
  | .ok (b, ε') => tyEq q.atoms a b && effEq q.atoms ε ε'

private def run (q : Input) (e : Expr) (Γ : List (Option Ty) := [])
    (R : Option Ty := none) (p : Position := .other) : Result Inferred :=
  checkExpr q .strict [] Γ R p [] e

private def emptyDecls : Declarations := { funs := fun _ => none, cons := fun _ => none }
private def basic : Input := input emptyDecls

-- try の成功型は、関数の戻り値の成功型と異なってもよい。
example : defsOk (input c4Program.declarations) c4Program
    ["tryResult", "tryOption", "tryCaller", "withNormal", "withReturn", "loop", "lazyUnused", "lazyForced"] = true := by decide

-- 多相な操作を再開する節と、再開しない節。
example : defsOk (input handlerProgram.declarations) handlerProgram ["resumed", "aborted"] = true := by decide
example : got (input handlerProgram.declarations)
    (run (input handlerProgram.declarations) (identityHandled true)) intTy = true := by decide
example : got (input handlerProgram.declarations)
    (run (input handlerProgram.declarations) (identityHandled false)) intTy = true := by decide

-- 辞書の実装・局所・上位、関数・メソッドの値化と実装全体。
example : (checkDef (input c5Program.declarations) [] constrainedDef).toBool = true := by decide
example : (checkDef (input c5ValueProgram.declarations) [] c5ValueDef).toBool = true := by decide
example : (checkImpl (input c5Program.declarations) ["combine", "choose"] ["BoxSemigroup"] [] c5Impl).toBool = true := by decide
example : (checkImpl (input c5Program.declarations) [] [] [] c5SemigroupImpl).toBool = true := by decide
example : (checkDict (input c5Program.declarations) [] [] [] (.impl "ShowInteger" [] [])).toBool = true := by decide
example : (checkDict (input c5Program.declarations) [{}] [some (.dict "Monoid" (.tvar 0))] []
    (.super (.local 0) "Semigroup")).toBool = true := by decide
example : (run (input c5Program.declarations)
    (.methName (.local 0) "choose" [intTy] [emptyEff] [.local 1] [.data "Box" [intTy], intTy])
    [some (.dict "BoxMonoid" (.data "Box" [intTy])), some (.dict "Show" intTy)]).toBool = true := by decide
example : (run (input c5Program.declarations)
    (.funDicts "renderPair" [intTy, intTy] [] [.local 0, .local 1] [intTy, intTy])
    [some (.dict "Show" intTy), some (.dict "Order" intTy)]).toBool = true := by decide
example : (checkImpl (input higherProgram.declarations) ["identity"] [] [] higherImpl).toBool = true := by decide
example : (run (input higherProgram.declarations) higherName).toBool = true := by decide

-- レコードの構築・更新・生成された取得関数、入れ子の定数。
example : (run (input pointProgram.declarations)
    (.record "Point" [] [1, 0] (.cons (eInt 3) (.cons (eInt 2) .nil)))).toBool = true := by decide
example : got (input pointProgram.declarations)
    (run (input pointProgram.declarations)
      (.recordUpdate "Point" [] 2 [0] (.local 0) (.cons (eInt 7) .nil))
      [some (.data "Point" [])]) (.data "Point" []) = true := by decide
example : (run (input pointProgram.declarations) (.funName "Point.y" [] [])).toBool = true := by decide
example : got basic (run basic nestedConstant) (.list intTy) = true := by decide
example : (run basic (.constE intTy (.local 0)) [some intTy]).toBool = false := by decide

-- 原子集合上の結びと差。
example : (tyJoin atoms (.fn [intTy] intTy (Eff.single "A"))
    (.fn [intTy] intTy (Eff.single "B"))).isSome = true := by decide
example : (tyJoin atoms intTy (.base .boolean)).isNone = true := by decide
example : effEq atoms (diffEff atoms (Eff.union (Eff.single "A") (Eff.single "B")) (Eff.single "A"))
    (Eff.single "B") = true := by decide

-- ite と elseIf の結びは外側の関数型のエフェクトを広げる。
private def fnA : Expr := .lam [] intTy (Eff.single "A") (.last (.returnE unitTy (eInt 1)))
private def fnB : Expr := .lam [] intTy (Eff.single "B") (.last (.returnE unitTy (eInt 2)))
example : got basic (run basic (.ite eTrue (.last fnA) (.last fnB)))
    (.fn [] intTy (Eff.union (Eff.single "A") (Eff.single "B"))) = true := by decide
example : got basic (run basic (.elseIf eFalse (.last fnA) (.ite eTrue (.last fnB) (.last fnA))))
    (.fn [] intTy (Eff.union (Eff.single "A") (Eff.single "B"))) = true := by decide
example : (run basic (.ite eTrue (.last (eInt 1)) (.last eFalse))).toBool = false := by decide

-- handle の節も外側の関数型のエフェクトを結ぶ。
private def joinDecls : Declarations :=
  { emptyDecls with ops := fun o => if o == "Join.op" then some ({ eff := "A", tparams := [], params := [], ret := unitTy } : OpDecl) else none }
example : got (input joinDecls)
    (run (input joinDecls) (.handleE (.last fnA) (.cons (.user "Join.op") 0 0 (.last fnB) .nil)))
    (.fn [] intTy (Eff.union (Eff.single "A") (Eff.single "B"))) = true := by decide

-- 再開の引数に Console.Write があり、空の初期値から一回増える不動点。
private def effectfulResume : Expr :=
  .handleE (.last (eInt 7))
    (.cons (.prim "print") 1 0
      (.last (.resume 0 (.call (.primName "print" [] []) (.cons (eInt 8) .nil)))) .nil)
example : got basic (run basic effectfulResume) intTy (Eff.single "Console.Write") = true := by decide
example : (checkClauses basic .strict [] [] none []
    (.cons (.prim "print") 1 0
      (.last (.resume 0 (.call (.primName "print" [] []) (.cons (eInt 8) .nil)))) .nil)
    intTy emptyEff).toBool = false := by decide
example : (fixedEffects basic [] (fun _ => pure (Eff.single "A")) 1 emptyEff).toBool = false := by decide
example : effEq atoms ((fixedEffects basic [] (fun _ => pure (Eff.single "A")) 2 emptyEff).toOption.getD emptyEff)
    (Eff.single "A") = true := by decide

-- Opus 1 と Astra 1 の再現入力は同じ。内側の本体で外側の継続を再開する。
-- 内側の handle が Console.Write を処理しても、外側の継続への要求は残る。
private def printEight : Expr := .call (.primName "print" [] []) (.cons (eInt 8) .nil)
private def nestedResume : Expr :=
  .handleE (.last (eInt 7))
    (.cons (.prim "print") 1 0
      (.last (.handleE (.last (.resume 0 printEight))
        (.cons (.prim "print") 1 0 (.last (.resume 0 .unit)) .nil))) .nil)
example : got basic (run basic nestedResume) intTy (Eff.single "Console.Write") = true := by decide

-- 文法より広い形: 内側の節から外側の継続（添字 2）を再開する。
-- 内側の継続は確定した ε で検査し、外側への要求は外側の反復に返す。
private def outerResumeFromClause : Expr :=
  .handleE (.last (eInt 7))
    (.cons (.prim "print") 1 0
      (.last (.handleE (.last (eInt 1))
        (.cons (.prim "print") 1 0 (.last (.resume 2 printEight)) .nil))) .nil)
example : got basic (run basic outerResumeFromClause) intTy (Eff.single "Console.Write") = true := by decide

-- 三つの指定された反例。末尾 return は R の型、ガードでは継続を隠す。
private def f04 : Surface.Def :=
  { tparams := [], neffs := 0, params := [], ret := .list intTy, eff := emptyEff,
    body := .last (.matchE unitTy eTrue
      (.single (.boolean true) (.last (.returnE unitTy (.list intTy .nil)))
        (.single (.boolean false) (.last (.returnE unitTy (.list intTy .nil))) .nil))) }
example : (checkDef basic [] f04).toBool = false := by decide
example : (checkDef basic [] { f04 with body := .last (.matchE (.list intTy) eTrue
    (.single (.boolean true) (.last (.returnE unitTy (.list intTy .nil)))
      (.single (.boolean false) (.last (.returnE unitTy (.list intTy .nil))) .nil))) }).toBool = true := by decide
private def guardResume : Expr :=
  .handleE (.last eTrue) (.cons (.prim "print") 1 0
    (.last (.matchE (.base .boolean) eTrue
      (.cons [⟨.wild, []⟩] (some (.resume 0 .unit)) (.last eTrue)
        (.single .wild (.last eFalse) .nil)))) .nil)
example : (run basic guardResume).toBool = false := by decide
example : (run basic (.matchE intTy eTrue (.single (.boolean true) (.last (eInt 1)) .nil))).toBool = false := by decide
example : (run basic (.matchE intTy eTrue (.single (.boolean true) (.last (eInt 1))
    (.single (.boolean false) (.last (eInt 2)) .nil)))).toBool = true := by decide

-- 失敗の箇所は外側から子の番号を積む。
example : (run basic guardResume).toOption.isNone = true := by decide
example : (run basic (.paren (.local 0))) = .error ⟨[0], "local is missing or hidden"⟩ := by rfl
example : (checkBlock basic .strict [] [] none .other [4]
    (.discard .unit (.last (.local 0)))).toBool = false := by decide

-- パイプ右辺の関数の型の失敗は、検査した関数の子 [1, 0] を指す。
example : run basic (.pipe .unit (.call (eInt 1) .nil)) =
    .error ⟨[1, 0], "expected a function type"⟩ := by rfl
-- 並びの第 3 要素は cons の深さによらず添字 2 を持つ。
example : checkTypes basic .strict [] [] none [4]
    (.cons .unit (.cons .unit (.cons (eInt 1) .nil))) [unitTy, unitTy, unitTy] =
    .error ⟨[4, 2], "type is not included in the expected type"⟩ := by rfl
example : checkEach basic .strict [] [] none [4]
    (.cons .unit (.cons .unit (.cons (eInt 1) .nil))) unitTy =
    .error ⟨[4, 2], "type is not included in the expected type"⟩ := by rfl
example : checkHoleArgs basic .strict [] [] none [4]
    (.hole unitTy (.expr .unit (.hole intTy .nil))) [unitTy, unitTy, unitTy] =
    .error ⟨[4, 2], "hole annotation type mismatch"⟩ := by rfl

-- 末尾 return は注釈を無視し、非末尾 return は注釈の WF を検査する。
example : got basic (run basic (.returnE unitTy (eInt 1)) [] (some intTy) .tail) intTy = true := by decide
example : got basic (run basic (.returnE unitTy (eInt 1)) [] (some intTy)) unitTy = true := by decide
example : (run basic (.returnE (.tvar 0) (eInt 1)) [] (some intTy)).toBool = false := by decide
example : (run basic (.returnE unitTy (eInt 1))).toBool = false := by decide

-- リストの注釈・穴・環境の境界。
example : (run basic (.list (.base .boolean) (.cons (eInt 1) .nil))).toBool = false := by decide
example : (run basic (.list (.tvar 0) .nil)).toBool = false := by decide
example : (run basic (.local 0) [some (.cont intTy intTy emptyEff)]).toBool = false := by decide
example : (run basic (.lazyE (.last (.returnE intTy (eInt 1)))) [] (some intTy)).toBool = false := by decide
example : (run basic (.lam [] intTy emptyEff (.last (eInt 1)))).toBool = false := by decide
example : (checkBlock basic .strict [] [] none .other [] (.lastBind .bind (.base .boolean) (eInt 1))).toBool = false := by decide
example : (checkBlock basic .strict [] [] none .other [] (.lastDiscard (eInt 1))).toBool = true := by decide

end Benitoite.Surface.Check.Examples

namespace Benitoite.Surface.Check.Examples
open Benitoite.Release Benitoite.Surface.CheckTools
open Benitoite.Surface.Examples

private def richBuiltins : Builtins :=
  { Release.Examples.builtins with sig := fun b => match b with
      | "concat" => some (Release.Examples.sig [{}] [.list (.tvar 0), .list (.tvar 0)]
          (.list (.tvar 0)) emptyEff .pure)
      | "str_Integer" => some (Release.Examples.sig [] [intTy] (.base .string) emptyEff .pure)
      | "add_String" => some (Release.Examples.sig [] [.base .string, .base .string] (.base .string) emptyEff .pure)
      | "add_Integer" => some (Release.Examples.sig [] [intTy, intTy] intTy emptyEff .pure)
      | "eq" => some (Release.Examples.sig [{}] [.tvar 0, .tvar 0] (.base .boolean) emptyEff .pure)
      | "neg_Integer" => some (Release.Examples.sig [] [intTy] intTy emptyEff .pure)
      | _ => Release.Examples.builtins.sig b }

private def rich (D : Declarations := emptyDecls) : Input :=
  { input D c6OpPrim with B := richBuiltins, admitsDec := admits richBuiltins }

-- 演算子、純粋な直接の変換関数、リストの展開。
example : got (rich) (run (rich) (.binary .add intTy (eInt 1) (eInt 2))) intTy = true := by decide
example : got (rich) (run (rich) (.binary .eq intTy (eInt 1) (eInt 2))) (.base .boolean) = true := by decide
example : got (rich) (run (rich) (.neg intTy (eInt 1))) intTy = true := by decide
example : got (rich) (run (rich) (.interpolation [.text "n=", .converted intTy]
    (.cons (eInt 7) .nil) (.cons strInt .nil))) (.base .string) = true := by decide
example : got (rich) (run (rich) (.interpolation [.text "a", .stringExpr, .text "b"]
    (.cons (eStr "x") .nil) .nil)) (.base .string) = true := by decide
example : got basic (run basic (.interpolation [.text ""] .nil .nil)) (.base .string) = true := by decide
example : got (rich) (run (rich) (.listSpread intTy concatInt (.cons (eInt 1) .nil)
    (.list intTy (.cons (eInt 2) .nil)) (.cons (eInt 3) .nil))) (.list intTy) = true := by decide
example : (run (rich) (.interpolation [.converted (.list intTy)]
    (.cons (.list intTy .nil) .nil) (.cons strInt .nil))).toBool = false := by decide

-- 呼び出し・パイプの四場合・穴と最小の構成子戻り値。
example : defsOk (rich execProgram.declarations) execProgram
    ["pick", "capture", "early", "and", "or", "emit", "matchPair", "pipeCall", "pipeValue",
     "partialUnused", "partialCalled", "main"] = true := by decide
example : (run (input c4Program.declarations) (.nullCon "Option.None" [intTy])).toBool = true := by decide
example : (run (input c4Program.declarations) (.conValue "Option.Some" [intTy] [intTy])).toBool = true := by decide
example : (run (input c4Program.declarations)
    (.pipe (eInt 1) (.conCall "Option.Some" [intTy] .nil))).toBool = true := by decide
example : (run (input c4Program.declarations)
    (.pipe (eInt 1) (.conValue "Option.Some" [intTy] [intTy]))).toBool = true := by decide
example : got (input c4Program.declarations)
    (run (input c4Program.declarations) (.partialCon "Option.Some" [intTy] (.hole intTy .nil)))
    (.fn [intTy] (.data "Option" [intTy]) emptyEff) = true := by decide
example : (run (input c4Program.declarations) (.partialCon "Option.Some" [intTy]
    (.expr (.returnE intTy (eInt 1)) (.hole intTy .nil)))).toBool = false := by decide

-- 引数は二つで一致する。非穴の return の値は、外側の R でなく Pair である。
private def pairIntTy : Ty := .data "Pair" [intTy, intTy]
private def partialPair (value : Expr) : Expr :=
  .partialCon "Pair" [intTy, intTy]
    (.expr (.returnE intTy value) (.hole intTy .nil))
example : got (input execProgram.declarations)
    (run (input execProgram.declarations)
      (partialPair (.conCall "Pair" [intTy, intTy] (.cons (eInt 1) (.cons (eInt 2) .nil))))
      [] (some intTy))
    (.fn [intTy] pairIntTy emptyEff) = true := by decide
-- 個数検査に到達する前に、return の値 Integer が Pair に含まれず失敗する。
example : run (input execProgram.declarations) (partialPair (eInt 1)) [] (some intTy) =
    .error ⟨[0, 0, 0], "type is not included in the expected type"⟩ := by rfl

-- パターンの Valid、束縛、ガードの純粋性と宣言した網羅性。
example : (checkBlock (rich execProgram.declarations) .strict [] [] none .other []
    (.lastPat .bind (.con none "Pair" [.var, .var]) (.data "Pair" [intTy, intTy])
      (.conCall "Pair" [intTy, intTy] (.cons (eInt 1) (.cons (eInt 2) .nil))))).toBool = true := by decide
example : (run basic (.matchE intTy eTrue
    (.cons [⟨.wild, []⟩] (some eTrue) (.last (eInt 1))
      (.single .wild (.last (eInt 2)) .nil)))).toBool = true := by decide
example : (run basic (.matchE intTy eTrue
    (.cons [⟨.wild, []⟩] (some eTrue) (.last (eInt 1)) .nil))).toBool = false := by decide
example : (run basic (.matchE intTy (eInt 0)
    (.single (.range (.integer 2) (.integer 1)) (.last (eInt 1))
      (.single .wild (.last (eInt 2)) .nil)))).toBool = false := by decide

-- 宣言の制約の判定を検査関数の引数から使う。
example : (run { input handlerProgram.declarations with satDec := fun _ _ _ => false }
    (.opName "Identity.identity" [intTy])).toBool = false := by decide
example : (run { basic with admitsDec := fun _ _ _ => false }
    (.primName "add" [] [])).toBool = false := by decide
example : (run (input c5Program.declarations) (.funName "renderPair" [intTy, intTy] [])).toBool = false := by decide
example : (run { input handlerProgram.declarations with atoms := [] }
    (.opName "Identity.identity" [intTy])).toBool = false := by decide
example : (run { input c4Program.declarations with atoms := [] }
    (.withE "File" (.local 0) (.last (eInt 1))) [some fileTy]).toBool = false := by decide
-- choose を省いた一覧は ImplNamesComplete を満たさないが、検査は成功する。
example : (checkImpl (input c5Program.declarations) ["combine"] ["BoxSemigroup"] [] c5Impl).toBool = true := by decide
-- choose の本体がなくても、一覧が combine だけなら検査は成功する。
-- BoxMonoid は choose を宣言しているため、この実装の ImplDecl.WellTyped は偽である。
-- checkImpl_sound には ImplNamesComplete の前提が要る。
private def missingChoose : ImplDecl :=
  { c5Impl with methods := fun m => if m == "choose" then none else c5Impl.methods m }
example : (checkImpl (input c5Program.declarations) ["combine"] ["BoxSemigroup"] [] missingChoose).toBool = true := by decide
-- 宣言した上位クラスを一覧から省いた場合は拒否する。
example : (checkImpl (input c5Program.declarations) ["combine", "choose"] [] [] c5Impl).toBool = false := by decide
-- 宣言にないメソッドの本体を一覧に含めた場合は拒否する。
example : (checkImpl (input c5Program.declarations) ["combine", "choose", "missing"] ["BoxSemigroup", "extra"] []
    { c5Impl with methods := fun m => if m == "missing" then some .empty else c5Impl.methods m }).toBool = false := by decide

-- 型パラメータをずらして戻す節。新しい型パラメータの漏出は拒否する。
example : got (input handlerProgram.declarations)
    (checkExpr (input handlerProgram.declarations) .strict [{}] [some (.tvar 0)] none .other []
      (.handleE (.last (.local 0))
        (.cons (.user "Identity.identity") 1 1 (.last (.resume 0 (.local 1))) .nil)))
    (.tvar 0) = true := by decide
example : (run (input handlerProgram.declarations)
    (.handleE (.last (eInt 1)) (.cons (.user "Identity.identity") 1 1 (.last (.local 1)) .nil))).toBool = false := by decide

-- 原子を段階的に追加し、安定を確認する一回も燃料に数える。
private def twoStep (ε : Eff) : Result Eff :=
  pure (if ε (.name "A") then Eff.single "B" else Eff.single "A")
example : (fixedEffects basic [] twoStep 2 emptyEff).toBool = false := by decide
example : effEq atoms ((fixedEffects basic [] twoStep 3 emptyEff).toOption.getD emptyEff)
    (Eff.union (Eff.single "A") (Eff.single "B")) = true := by decide

end Benitoite.Surface.Check.Examples
