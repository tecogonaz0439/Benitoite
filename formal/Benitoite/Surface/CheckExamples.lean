import Benitoite.Surface.CheckProgramSound
import Benitoite.Release.Examples

/-! 検査全体の公開入口と、実名付きの材料から型付けへの接続の評価例。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。 -/
namespace Benitoite.Surface.Check.Examples
open Benitoite.Release Benitoite.Surface.CheckTools

private def intTy : Ty := .base .integer
private def unitTy : Ty := .base .unit
private def eInt (n : Nat) : Expr := .literal (.integer n)
private def eTrue : Expr := .literal (.boolean true)
private def eFalse : Expr := .literal (.boolean false)
private def atoms : List Atom :=
  [.name "State", .name "Console.Write", .name "A", .name "B"]
private def emptyDecls : Declarations := { funs := fun _ => none, cons := fun _ => none }
private def input (D : Declarations := emptyDecls) : Input :=
  { D, B := Release.Examples.builtins, satDec := fun _ _ _ => true,
    admitsDec := fun _ _ _ => true, opPrim := fun _ _ => none,
    ctors := fun _ => [], atoms }
private def run (e : Expr) (Γ : List (Option Ty) := [])
    (R : Option Ty := none) (p : Position := .other) : Result Inferred :=
  checkExpr (input) .strict [] Γ R p [] e
private def got (x : Result Inferred) (a : Ty) (ε : Eff := emptyEff) : Bool :=
  match x with
  | .error _ => false
  | .ok (b, ε') => tyEq atoms a b && effEq atoms ε ε'

-- ラムダの型の名前と、条件分岐による外側のエフェクトの結び。
private def fn (eff : Eff) : Expr :=
  .lam ["value"] [intTy] intTy eff (.last (.returnE unitTy (.local 0)))
example : got (run (.ite eTrue (.last (fn (Eff.single "A"))) (.last (fn (Eff.single "B")))))
    (.fn ["value"] [intTy] intTy (Eff.union (Eff.single "A") (Eff.single "B"))) = true := by decide
example : got (run (.elseIf eFalse (.last (fn (Eff.single "A")))
    (.ite eTrue (.last (fn (Eff.single "B"))) (.last (fn emptyEff)))))
    (.fn ["value"] [intTy] intTy (Eff.union (Eff.single "A") (Eff.single "B"))) = true := by decide
example : got (run (.ifOnly eFalse (.lastDiscard (eInt 1)))) unitTy = true := by decide

-- return の末尾と非末尾、および遅延境界での遮蔽。
example : got (run (.returnE unitTy (eInt 1)) [] (some intTy) .tail) intTy = true := by decide
example : got (run (.returnE unitTy (eInt 1)) [] (some intTy)) unitTy = true := by decide
example : run (.returnE unitTy (eInt 1)) = .error ⟨[], "return is outside a function"⟩ := by rfl
example : got (run (.lazyE (.last (eInt 1)))) (.lazy intTy) = true := by decide
example : run (.lazyE (.last (.returnE intTy (eInt 1)))) [] (some intTy) =
    .error ⟨[0, 0], "return is outside a function"⟩ := by rfl

-- 一覧・パターン・ガードを通した型と、失敗する要素のソース位置。
example : got (run (.list intTy (.cons (eInt 1) (.cons (eInt 2) .nil)))) (.list intTy) = true := by decide
example : run (.list intTy (.cons (eInt 1) (.cons eFalse .nil))) =
    .error ⟨[0, 1], "type is not included in the expected type"⟩ := by rfl
example : got (run (.matchE intTy eTrue
    (.cons [⟨.wild, []⟩] (some eTrue) (.last (eInt 1))
      (.single .wild (.last (eInt 2)) .nil)))) intTy = true := by decide
example : run (.matchE intTy eTrue (.single (.boolean true) (.last (eInt 1)) .nil)) =
    .error ⟨[], "match is not exhaustive"⟩ := by rfl

-- 位置を入れ替えたレコードの構築・更新。独立した引数の誤りの位置も保つ。
private def pointDecls : Declarations :=
  { emptyDecls with
    cons := fun c => if c == "Point" then some ⟨"Point", 0, [intTy, intTy]⟩ else none,
    conFields := fun c => if c == "Point" then some ["x", "y"] else none }
private def pointInput : Input :=
  { input pointDecls with ctors := fun n => if n == "Point" then ["Point"] else [] }
example : got (checkExpr pointInput .strict [] [] none .other []
    (.record "Point" [] [1, 0] (.cons (eInt 3) (.cons (eInt 2) .nil)))) (.data "Point" []) = true := by decide
example : got (checkExpr pointInput .strict [] [some (.data "Point" [])] none .other []
    (.recordUpdate "Point" [] 2 [0] (.local 0) (.cons (eInt 7) .nil))) (.data "Point" []) = true := by decide
example : checkExpr pointInput .strict [] [] none .other []
    (.record "Point" [] [1, 0] (.cons (eInt 3) (.cons eFalse .nil))) =
    .error ⟨[0, 1], "type is not included in the expected type"⟩ := by rfl

-- 名前を持つ利用者の操作。節のローカルな継続と、外側の型を接続する。
private def opDecls : Declarations :=
  { emptyDecls with
    ops := fun o => if o == "A.id" then some {
      eff := "A", tparams := [], names := ["value"], params := [intTy], ret := intTy } else none
    effects := fun e => if e == "A" then some ["A.id"] else none }
private def opInput : Input := { input opDecls with ctors := fun _ => [] }
private def handled : Expr :=
  .handleE (.last (.call (.opName "A.id" []) [some "value"] [0] (.cons (eInt 7) .nil)))
    (.cons (.user "A.id") 1 0 (.last (.resume 0 (.local 1))) .nil)
example : got (checkExpr opInput .strict [] [] none .other [] handled) intTy = true := by decide
example : checkExpr opInput .strict [] [] none .other []
    (.handleE (.last (eInt 1)) (.cons (.user "A.id") 0 0 (.last (eInt 2)) .nil)) =
    .error ⟨[1], "handler operation arity mismatch"⟩ := by rfl

-- リソースの State と、純粋な補間・直接の連結関数の契約。
example : got (checkExpr (input) .strict [] [some (.opaque "File")] none .other []
    (.withE "File" (.local 0) (.last (eInt 1)))) intTy (Eff.single "State") = true := by decide
private def collectionBuiltins : Builtins :=
  { Release.Examples.builtins with sig := fun b => match b with
      | "concat" => some (Release.Examples.sig [] ["xs", "ys"] [.list intTy, .list intTy]
          (.list intTy) emptyEff .pure)
      | "toString" => some (Release.Examples.sig [] ["n"] [intTy] (.base .string) emptyEff .pure)
      | "addString" => some (Release.Examples.sig [] ["left", "right"] [.base .string, .base .string]
          (.base .string) emptyEff .pure)
      | _ => Release.Examples.builtins.sig b }
private def collectionInput : Input :=
  { (input) with
    B := collectionBuiltins,
    opPrim := CheckTables.makeOpPrim (fun op _ => match op with
      | .binary .add => some "addString" | _ => none) }
example : got (checkExpr collectionInput .strict [] [] none .other []
    (.listSpread intTy (.primName "concat" [] []) (.cons (eInt 1) .nil)
      (.list intTy (.cons (eInt 2) .nil)) (.cons (eInt 3) .nil))) (.list intTy) = true := by decide
example : got (checkExpr collectionInput .strict [] [] none .other []
    (.interpolation [.text "n=", .converted intTy] (.cons (eInt 7) .nil)
      (.cons (.primName "toString" [] []) .nil))) (.base .string) = true := by decide

-- 実名を保持したクラス・上位辞書・実装と、全プログラムの検査。
private def methodSig : MethSig :=
  { tparams := [], neffs := 0, names := ["left", "right"], params := [intTy, intTy],
    ret := intTy, eff := emptyEff }
private def methodBody : Block := .last (.returnE intTy (.local 1))
private def mainDef : Def :=
  { tparams := [], neffs := 0, names := [], params := [], ret := unitTy,
    eff := emptyEff, body := .last .unit }
private def materials : CheckTables.Materials :=
  { defs := [("main", mainDef)], conFields := [], accessors := [], data := [], ops := [], effects := [],
    classes := [("Choose", ⟨["Base"], [("choose", methodSig)]⟩), ("Base", ⟨[], []⟩)],
    impls := [("ChooseInt", ⟨⟨[], [], "Choose", intTy⟩, [("Base", .impl "BaseInt" [] [])],
      [("choose", ⟨["left", "right"], methodBody⟩)]⟩),
      ("BaseInt", ⟨⟨[], [], "Base", intTy⟩, [], []⟩)],
    trustedFuns := [], trustedImpls := [] }
private def builtinMaterial : CheckTables.BuiltinMaterial := ⟨[], [], "get", "set"⟩
private def selectOp : Operator → Ty → Option PrimName := fun _ _ => none
private def programInput : Input :=
  materials.input (CheckTables.builtins [] [] builtinMaterial) (satB [])
    (CheckTables.admitsDec [] []) (CheckTables.makeOpPrim selectOp) []

example : CheckTables.checkProgram programInput materials materials.names = .ok () := by rfl
example : (checkDict programInput [] [] [] (.super (.impl "ChooseInt" [] []) "Base")).map
    (fun t => tyEq [] t (.dict "Base" intTy)) = .ok true := by rfl
example : (checkExpr programInput .strict [] [] none .other []
    (.call (.methName (.impl "ChooseInt" [] []) "choose" [] [] [] ["left", "right"] [intTy, intTy])
      [some "right", some "left"] [1, 0] (.cons (eInt 2) (.cons (eInt 1) .nil)))).map
    (fun (t, ε) => tyEq [] t intTy && effEq [] ε emptyEff) = .ok true := by rfl

-- 全実装の実名の保証は、検査と有限の一覧の成功から得る。
example : ∀ n id, CheckTables.lookup (materials.impls.map fun (n,i) => (n,i.input)) n = some id →
    id.ContractsMatch materials.declarations := by
  exact CheckTables.checkProgram_contracts (by decide)
    (show CheckTables.checkProgram programInput materials materials.names = .ok () from rfl)

end Benitoite.Surface.Check.Examples
