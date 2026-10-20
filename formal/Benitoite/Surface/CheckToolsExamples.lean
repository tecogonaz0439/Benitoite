import Benitoite.Surface.CheckTables
import Benitoite.Release.BuiltinTable

/-! 判定と構造的な再帰の写しの評価例。
対応する検査と保証の範囲は設計書 07-04「証明する性質」に従う。
-/
namespace Benitoite.Surface.CheckTools.Examples
open Benitoite.Release

private def atoms : List Atom := [.name "IO", .name "State", .rho 0, .rho 2]
private def intTy : Ty := .base .integer
private def boolTy : Ty := .base .boolean
private def ioEff : Eff := Eff.single "IO"
private def rhoEff : Eff := Eff.ofAtoms fun a => a == .rho 0
private def gotTypes (xs : Option (List Ty)) (ts : List Ty) : Bool :=
  match xs with
  | some us => tysEq atoms us ts
  | none => false

-- エフェクトの包含、等しさ、原子を保持する構築。
example : effSub atoms emptyEff ioEff = true := by decide
example : effSub atoms ioEff emptyEff = false := by decide
example : effEq atoms ioEff (singleEff atoms (.name "IO")) = true := by decide
example : effEq atoms ioEff rhoEff = false := by decide
example : Eff.mem (singleEff atoms (.rho 0)) (.rho 0) := by decide
example : Eff.test (singleEff atoms (.name "Unknown")) (.name "Unknown") = true := by decide
example : Eff.mem (unionEff atoms ioEff rhoEff) (.rho 0) := by decide
example : Eff.test (unionEff atoms ioEff (Eff.single "Unknown")) (.name "Unknown") = true := by decide
example : Eff.test emptyEff (.rho 2) = false := rfl
example : Eff.mem (Eff.substRho [ioEff] rhoEff) (.name "IO") := by decide
example : Eff.mem (Eff.substRho [ioEff] (Eff.ofAtoms fun a => a == .rho 2)) (.rho 2) := by decide

-- 型の全構成、並行した型リスト、外側だけのエフェクトの包含。
private def richTypes : List Ty := [intTy, .opaque "O", .data "D" [intTy], .list intTy,
  .fn ["value"] [intTy] boolTy ioEff, .tvar 1, .reference intTy, .lazy intTy,
  .cont intTy boolTy rhoEff, .map intTy boolTy, .set intTy, .bytes,
  .dict "Eq" intTy, .tapp 0 [intTy], .ctor (.data "D"), .ctor .list,
  .ctor .set, .ctor .map, .ctor .reference, .ctor .lazy]
example : tysEq atoms richTypes richTypes = true := by decide
example : tyEq atoms intTy boolTy = false := by decide
example : tyEq atoms (.fn ["value"] [intTy] boolTy emptyEff) (.fn ["value"] [intTy] boolTy ioEff) = false := by decide
example : tysEq atoms [intTy] [] = false := by decide
example : tyEq atoms (.ctor (.data "D")) (.ctor (.data "E")) = false := by decide
example : tyEq atoms (.ctor .list) (.ctor .map) = false := by decide
example : tyLe atoms (.fn ["value"] [intTy] boolTy emptyEff) (.fn ["value"] [intTy] boolTy ioEff) = true := by decide
example : tyLe atoms (.fn ["value"] [intTy] boolTy ioEff) (.fn ["value"] [intTy] boolTy emptyEff) = false := by decide
example : tyLe atoms (.list (.fn [] [] intTy emptyEff)) (.list (.fn [] [] intTy ioEff)) = false := by decide
example : tyLe atoms intTy intTy = true := by decide

-- shift はFail内部の型も移し、substは行変数も具体化する。ここではFailなしの対照を保つ。
example : tyEq atoms (shiftTy atoms 2 1 (.fn ["a", "b"] [.tvar 0, .tvar 1] (.tapp 2 [.tvar 0]) rhoEff))
    (.fn ["a", "b"] [.tvar 0, .tvar 3] (.tapp 4 [.tvar 0]) rhoEff) = true := by decide
example : tyEq atoms (substTyAt atoms 1 [intTy] [ioEff] (.fn ["a", "b", "c"] [.tvar 0, .tvar 1, .tvar 2] (.tvar 1) rhoEff))
    (.fn ["a", "b", "c"] [.tvar 0, intTy, .tvar 1] intTy ioEff) = true := by decide
example : tyEq atoms (substTyAt atoms 1 [.tvar 0] [] (.tvar 1)) (.tvar 1) = true := by decide
example : tyEq atoms (substTy atoms [.ctor .list] [] (.tapp 0 [intTy])) (.list intTy) = true := by decide
example : tyEq atoms (substTyAt atoms 1 [intTy] [] (.tapp 0 [.tvar 1])) (.tapp 0 [intTy]) = true := by decide
example : tyEq atoms (substTy atoms [intTy] [] (.tapp 2 [.tvar 0])) (.tapp 1 [intTy]) = true := by decide
example : tyEq atoms (applyToTy atoms (.ctor .map) [intTy, boolTy]) (.map intTy boolTy) = true := by decide
example : tyEq atoms (applyToTy atoms (.ctor .map) []) (.map (.base .unit) (.base .unit)) = true := by decide
example : tyEq atoms (applyToTy atoms (.tvar 2) [intTy]) (.tapp 2 [intTy]) = true := by decide
example : tyEq atoms (applyToTy atoms intTy [boolTy]) intTy = true := by decide
example : tyEq atoms (fnTyCheck atoms ["value"] [.tvar 0] (.tvar 0) rhoEff [intTy] [ioEff])
    (.fn ["value"] [intTy] intTy ioEff) = true := by decide

-- 既存の整礎再帰の式は、その等式補題で展開してから比較する。
example : shiftTy atoms 2 0 (.list (.tvar 0)) = Ty.shift 2 0 (.list (.tvar 0)) := by
  simp only [Ty.shift]; rfl
example : substTyAt atoms 1 [intTy] [ioEff] (.list (.tvar 1)) =
    Ty.substAt 1 [intTy] [ioEff] (.list (.tvar 1)) := by
  rfl
example : applyToTy atoms (.ctor .map) [intTy, boolTy] =
    Ty.applyTo (.ctor .map) [intTy, boolTy] := rfl
example : tyEq atoms (substTy atoms [intTy] [] (.list (.tvar 0)))
    (Coverage.substTy [intTy] (.list (.tvar 0))) = true := by decide

-- 規則の前提に使う構文の判定。
example : wfTys atoms 2 richTypes = true := by decide
example : wfTy atoms 1 (.tvar 1) = false := by decide
example : wfTy atoms 1 (.tapp 1 [intTy]) = false := by decide
example : exprExits (.ite .unit (.last (.returnE intTy .unit)) (.last (.returnE intTy .unit))) = true := by decide
example : exprExits (.constE intTy (.returnE intTy .unit)) = false := by decide
example : exprExits (.paren (.withE "R" .unit (.last (.returnE intTy .unit)))) = true := by decide
example : exprExits (.elseIf .unit (.last (.returnE intTy .unit)) (.returnE intTy .unit)) = true := by decide
example : exprExits (.matchE intTy .unit .nil) = true := by decide
example : blockExits (.seq (.returnE intTy .unit) .empty) = true := by decide
example : blockExits (.lastBind .bind intTy (.returnE intTy .unit)) = false := by decide
example : armsExits (.cons [] none .empty .nil) = false := by decide
example : patternValid (.range (.integer ⟨2, by decide⟩) (.integer ⟨1, by decide⟩)) = false := by decide
example : patternValid (.range (.character 'a') (.character 'z')) = true := by decide
example : patternValid (.list [] none [.wild]) = false := by decide
example : patternValid (.record "C" 1 [0] [.range (.integer ⟨2, by decide⟩) (.integer ⟨1, by decide⟩)]) = false := by decide
example : patternValid (.con none "C" [.list [] (some .skip) [.wild]]) = true := by decide
example : patternsValid [.wild, .var, .unit] = true := by decide
example : alternativesValid [⟨.range (.integer ⟨1, by decide⟩) (.integer ⟨2, by decide⟩), []⟩] = true := by decide
example : alternativesValid [⟨.range (.integer ⟨2, by decide⟩) (.integer ⟨1, by decide⟩), []⟩] = false := by decide
example : isIf (.elseIf .unit .empty (.ifOnly .unit .empty)) = true := by decide
example : isIf (.elseIf .unit .empty (.paren (.ifOnly .unit .empty))) = false := by decide
example : nontrivial .var = false := by decide
example : nontrivial (.boolean true) = true := by decide
example : pipeValue (.call .unit [] [] .nil) = false := by decide
example : pipeValue (.paren (.call .unit [] [] .nil)) = true := by decide
example : isDirect (.funName "f" [] []) = true := by decide
example : isDirect (.paren (.funName "f" [] [])) = false := by decide
example : allDirect (.cons (.funName "f" [] []) (.cons (.primName "p" [] []) .nil)) = true := by decide
example : allDirect (.cons .unit .nil) = false := by decide
example : interpAllowed [.text "", .stringExpr, .converted intTy, .converted (.base .decimal)] = true := by decide
example : interpAllowed [.converted (.list intTy)] = false := by decide
example : convertedAllowed (.base .string) = false := by decide
example : notCont (.cont intTy boolTy ioEff) = false := by decide
example : notCont intTy = true := by decide
example : headNotDict [.dict "C" intTy] = false := by decide
example : headNotDict [intTy, .dict "C" intTy] = true := by decide
example : isUnit (.base .unit) = true := by decide
example : isUnit intTy = false := by decide
example : lamBodyOk (.last (.returnE intTy .unit)) intTy = true := by decide
example : lamBodyOk .empty intTy = false := by decide
example : nonemptyArms .nil = false := by decide
example : nonemptyArms (.cons [] none .empty .nil) = true := by decide
example : nonemptyList ([] : List Nat) = false := by decide
example : nonemptyList [intTy] = true := by decide
example : natPerm [1, 0] [0, 1] = true := by decide
example : natPerm [0, 0] [0, 1] = false := by decide
example : natNodup [0, 0] = false := by decide
example : positionsInRange [0, 1] 2 = true := by decide
example : positionsInRange [0, 2] 2 = false := by decide

-- パターンの束縛はコアにした後の宣言順で求める。
private def decls : Declarations :=
  { funs := fun _ => none,
    cons := fun c =>
      if c == "Pair" then some { data := "PairTy", ntys := 1, args := [.tvar 0, boolTy] }
      else if c == "Ok" then some { data := "Result", ntys := 2, args := [.tvar 0] }
      else if c == "Error" then some { data := "Result", ntys := 2, args := [.tvar 1] }
      else if c == "Some" then some { data := "Option", ntys := 1, args := [.tvar 0] }
      else if c == "None" then some { data := "Option", ntys := 1, args := [] }
      else none }
private def ctors : DataName → List ConName
  | "PairTy" => ["Pair"]
  | "Result" => ["Ok", "Error"]
  | "Option" => ["Some", "None"]
  | _ => []

example : gotTypes (patTy atoms decls.patternProgram .wild intTy) [] = true := by decide
example : gotTypes (patTy atoms decls.patternProgram .var intTy) [intTy] = true := by decide
example : gotTypes (patTy atoms decls.patternProgram (.const (.integer ⟨3, by decide⟩)) intTy) [] = true := by decide
example : (patTy atoms decls.patternProgram (.const (.byte 3)) (.base .byte)).isNone = true := by decide
example : (patTy atoms decls.patternProgram (.const (.integer ⟨3, by decide⟩)) boolTy).isNone = true := by decide
example : gotTypes (patTy atoms decls.patternProgram (.range (.integer ⟨1, by decide⟩) (.integer ⟨3, by decide⟩)) intTy) [] = true := by decide
example : gotTypes (patTy atoms decls.patternProgram (.range (.character 'a') (.character 'z')) (.base .character)) [] = true := by decide
example : gotTypes (patTy atoms decls.patternProgram (.list [.var] (some .bind) [.var]) (.list intTy))
    [intTy, .list intTy, intTy] = true := by decide
example : (patTy atoms decls.patternProgram (.list [] none [.var]) (.list intTy)).isNone = true := by decide
example : gotTypes (patTy atoms decls.patternProgram (.con "Pair" [.var, .var]) (.data "PairTy" [intTy]))
    [intTy, boolTy] = true := by decide
example : (patTy atoms decls.patternProgram (.con "Pair" [.var, .var]) (.data "Wrong" [intTy])).isNone = true := by decide
example : (patTy atoms decls.patternProgram (.con "Pair" [.var, .var]) (.data "PairTy" [])).isNone = true := by decide
example : (patTy atoms decls.patternProgram (.con "Unknown" []) intTy).isNone = true := by decide
example : gotTypes (surfacePatTy atoms decls (.record "Pair" 2 [1, 0] [.var, .var]) (.data "PairTy" [intTy]))
    [intTy, boolTy] = true := by decide
example : gotTypes (surfacePatTy atoms decls (.record "Pair" 2 [1] [.var]) (.data "PairTy" [intTy]))
    [boolTy] = true := by decide
example : gotTypes (patTys atoms decls.patternProgram [.var, .wild] [intTy, boolTy]) [intTy] = true := by decide
example : (patTys atoms decls.patternProgram [.var] []).isNone = true := by decide

private def pairAlts : List Release.Alt :=
  [⟨.con "Pair" [.var, .var], [0, 1]⟩, ⟨.con "Pair" [.var, .var], [0, 1]⟩]
example : gotTypes (altsTy atoms decls.patternProgram pairAlts (.data "PairTy" [intTy]))
    [intTy, boolTy] = true := by decide
example : checkAlts atoms decls.patternProgram pairAlts (.data "PairTy" [intTy]) [intTy, boolTy] = true := by decide
example : checkAlts atoms decls.patternProgram [⟨.var, [1]⟩] intTy [intTy] = false := by decide
example : checkAlts atoms decls.patternProgram [⟨.con "Pair" [.var, .var], [0, 1]⟩,
    ⟨.con "Pair" [.var, .var], [1, 0]⟩] (.data "PairTy" [intTy]) [intTy, boolTy] = false := by decide
example : checkAlts atoms decls.patternProgram [⟨.con "Pair" [.var, .var], [0, 1]⟩,
    ⟨.con "Pair" [.var, .var], [1, 0]⟩] (.data "PairTy" [boolTy]) [boolTy, boolTy] = true := by decide
example : (altsTy atoms decls.patternProgram [] intTy).isNone = true := by decide

-- Boolean の片側だけでは網羅せず、両側で網羅する。ガードのある側は数えない。
private def trueArm : Arms := .single (.boolean true) .empty .nil
private def bothArms : Arms := .single (.boolean true) .empty (.single (.boolean false) .empty .nil)
example : matchExhaustive decls ctors boolTy trueArm = false := by decide
example : matchExhaustive decls ctors boolTy bothArms = true := by decide
example : matchExhaustive decls ctors boolTy
    (.cons [⟨.boolean true, []⟩] (some .unit) .empty (.single (.boolean false) .empty .nil)) = false := by decide
example : exhaustive decls ctors boolTy [.const (.boolean true), .const (.boolean false)] = true := by decide
example : bindingExhaustive decls ctors boolTy (.boolean true) = false := by decide
example : bindingExhaustive decls ctors intTy .var = true := by decide
example : bindingExhaustive decls ctors (.data "PairTy" [intTy])
    (.con none "Pair" [.var, .var]) = true := by decide
example : tryResultExhaustive decls ctors "Result" intTy (.base .string) "Ok" "Error" = true := by decide
example : tryResultExhaustive decls ctors "Result" intTy (.base .string) "Ok" "Ok" = false := by decide
example : tryOptionExhaustive decls ctors "Option" intTy "Some" "None" = true := by decide
example : tryOptionExhaustive decls ctors "Option" intTy "Some" "Some" = false := by decide
example : recordUpdateExhaustive decls ctors
    { data := "PairTy", ntys := 1, args := [.tvar 0, boolTy] } [intTy] "Pair" 2 [1] = true := by decide

-- 補間の連結演算子は、一般の admitsDec と有限の型比較で判定する。
private def stringAddSig : PrimSig :=
  { tparams := [], neffs := 0, names := ["left", "right"], params := [.base .string, .base .string],
    ret := .base .string, eff := emptyEff, admits := fun _ _ => True,
    kind := .pure, opEff := none }
private def stringBuiltins : Builtins :=
  { sig := fun b => if b == "String.add" then some stringAddSig else none,
    delta := fun _ _ _ _ => none, ioResponse := fun _ _ _ _ _ => False,
    releaseResponse := fun _ _ => False, isResource := fun _ => false,
    effects := fun _ => none, sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
private def stringOp : OpPrim
  | .binary .add, .base .string => some ("String.add", [])
  | _, _ => none
example : stringAddOk atoms stringBuiltins stringOp (fun _ _ _ => true) [] = true := by decide
example : stringAddOk atoms stringBuiltins stringOp (fun _ _ _ => false) [] = false := by decide
example : stringAddOk atoms stringBuiltins (fun _ _ => none) (fun _ _ _ => true) [] = false := by decide
example : stringAddOk atoms { stringBuiltins with sig := fun _ => none }
    stringOp (fun _ _ _ => true) [] = false := by decide
example : stringAddOk atoms
    { stringBuiltins with sig := fun _ => some { stringAddSig with ret := intTy } }
    stringOp (fun _ _ _ => true) [] = false := by decide

-- satDec は表の構成方法に依存せず渡せる。
example : satAll (fun _ _ _ => true) [] [intTy] [{}] = true := by decide
example : satAll (fun _ _ _ => true) [] [intTy] [] = false := by decide
example : satAll (fun _ _ _ => false) [] [intTy] [{}] = false := by decide
example : satAll (satB []) [] [intTy] [{ equality := true }] = true := by decide
example : satAll (satB []) [] [.fn [] [] intTy emptyEff] [{ equality := true }] = false := by decide

namespace Checker
open Benitoite.Surface Check

private def signature : MethSig :=
  { tparams := [], neffs := 0, names := ["a", "b"], params := [intTy, boolTy],
    ret := intTy, eff := emptyEff }
private def classDecl : ClassDecl :=
  { supers := [], methods := fun m => if m == "combine" then some signature else none }
private def q : Input :=
  { D := { decls with
      cons := fun c => if c == "PosPair" then decls.cons "Pair" else decls.cons c,
      conFields := fun c => if c == "Pair" then some ["first", "second"] else none,
      ops := fun o => if o == "ask" then some
        { eff := "Ask", tparams := [], names := ["a", "b"], params := [intTy, boolTy], ret := intTy }
        else none,
      classes := fun c => if c == "Combine" then some classDecl else none },
    B := stringBuiltins, satDec := fun _ _ _ => true, admitsDec := fun _ _ _ => true,
    opPrim := stringOp, ctors := ctors, atoms := .name "Ask" :: atoms }
private def fn : Ty := .fn ["a", "b"] [intTy, boolTy] intTy emptyEff
private def reversed : Exprs := .cons (.literal (.boolean true)) (.cons (.literal (.integer ⟨7, by decide⟩)) .nil)
private def reversedHoles : HoleArgs := .hole (some "b") 1 boolTy (.hole (some "a") 0 intTy .nil)
private def run (env : List (Option Ty)) (e : Expr) : Result Inferred :=
  checkExpr q .strict [] env none .other [] e
private def got (result : Result Inferred) (t : Ty) (ε : Eff := emptyEff) : Bool :=
  match result with
  | .ok (actual, eff) => tyEq q.atoms actual t && effEq q.atoms eff ε
  | .error _ => false

-- 異なる引数型を逆順に指定し、ソース順の期待型を実際に使うことを確かめる。
example : got (run [some fn] (.call (.local 0) [some "b", some "a"] [1, 0] reversed)) intTy = true := by rfl
example : got (run [some (.fn ["value"] [intTy] intTy emptyEff)]
    (.call (.local 0) [none] [0] (.cons (.literal (.integer ⟨7, by decide⟩)) .nil))) intTy = true := by rfl
example : got (run [some (.fn [] [] intTy emptyEff)] (.call (.local 0) [] [] .nil)) intTy = true := by rfl

-- ラベルの誤りは型の検査に進む前に、呼び出しそのものの経路で拒否する。
example : (run [some fn] (.call (.local 0) [some "other", some "a"] [1, 0] reversed)).map (fun _ => ()) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.call (.local 0) [some "b", some "a"] [0, 1] reversed)).map (fun _ => ()) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.call (.local 0) [some "a", some "a"] [0, 0] reversed)).map (fun _ => ()) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.call (.local 0) [some "a"] [0] (.cons (.literal (.integer ⟨7, by decide⟩)) .nil))).map (fun _ => ()) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.call (.local 0) [some "a", some "b"] [0, 2] reversed)).map (fun _ => ()) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.call (.local 0) [some "a", none] [0, 1] reversed)).map (fun _ => ()) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.call (.local 0) [none, none] [0, 1] reversed)).map (fun _ => ()) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.call (.local 0) [some "b", some "a"] [1] reversed)).map (fun _ => ()) =
    .error ⟨[], "call labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.call (.local 0) [some "b", some "a"] [1, 0] .nil)).map (fun _ => ()) =
    .error ⟨[1], "argument count mismatch"⟩ := by rfl
-- 対応は正しいが型が違う場合は、そのソース引数の位置を報告する。
example : (run [some fn] (.call (.local 0) [some "a", some "b"] [0, 1] reversed)).map (fun _ => ()) =
    .error ⟨[1, 0], "type is not included in the expected type"⟩ := by rfl

-- 穴から生成する契約は宣言順へ戻さず、穴が現れた順を保つ。
example : got (run [some fn] (.partialCall (.local 0) ["a", "b"] reversedHoles intTy emptyEff))
    (.fn ["b", "a"] [boolTy, intTy] intTy emptyEff) = true := by rfl
example : (run [some fn] (.partialCall (.local 0) ["b", "a"] reversedHoles intTy emptyEff)).map (fun _ => ()) =
    .error ⟨[], "partial call contract annotation mismatch"⟩ := by rfl
example : (run [some fn] (.partialCall (.local 0) ["a", "b"]
    (.hole (some "b") 0 boolTy (.hole (some "a") 1 intTy .nil)) intTy emptyEff)).map (fun _ => ()) =
    .error ⟨[], "partial call labels and positions do not match the contract"⟩ := by rfl
example : got (run [] (.partialCon "PosPair" [intTy]
    (.hole none 0 intTy (.expr none 1 (.literal (.boolean true)) .nil))))
    (.fn ["arg1"] [intTy] (.data "PairTy" [intTy]) emptyEff) = true := by rfl
-- 直接のレコードの穴は、型と位置が正しくても拒否する。
example : (run [] (.partialCon "Pair" [intTy]
    (.hole none 0 intTy (.expr none 1 (.literal (.boolean true)) .nil)))).map (fun _ => ()) =
    .error ⟨[], "record construction cannot contain holes"⟩ := by rfl
example : (run [] (.partialCon "PosPair" [intTy]
    (.hole (some "first") 0 intTy (.expr none 1 (.literal (.boolean true)) .nil)))).map (fun _ => ()) =
    .error ⟨[], "partial constructor labels or positions are invalid"⟩ := by rfl
example : (run [] (.partialCon "PosPair" [intTy]
    (.hole none 1 boolTy (.hole none 0 intTy .nil)))).map (fun _ => ()) =
    .error ⟨[], "partial constructor labels or positions are invalid"⟩ := by rfl

-- パイプ挿入は位置 0 を占める。括弧付きの穴は生成された一引数関数への適用になる。
example : got (run [some fn] (.pipe (.literal (.integer ⟨7, by decide⟩))
    (.call (.local 0) [some "b"] [1] (.cons (.literal (.boolean true)) .nil)))) intTy = true := by rfl
example : (run [some fn] (.pipe (.literal (.integer ⟨7, by decide⟩))
    (.call (.local 0) [some "a"] [0] (.cons (.literal (.integer ⟨8, by decide⟩)) .nil)))).map (fun _ => ()) =
    .error ⟨[1], "pipe labels and positions do not match the contract"⟩ := by rfl
example : (run [some fn] (.pipe (.literal (.integer ⟨7, by decide⟩))
    (.call (.local 0) [none] [1] (.cons (.literal (.boolean true)) .nil)))).map (fun _ => ()) =
    .error ⟨[1], "pipe labels and positions do not match the contract"⟩ := by rfl
example : got (run [some fn] (.pipe (.literal (.boolean true))
    (.paren (.partialCall (.local 0) ["a", "b"]
      (.hole (some "b") 1 boolTy (.expr (some "a") 0 (.literal (.integer ⟨7, by decide⟩)) .nil)) intTy emptyEff)))) intTy = true := by rfl

-- ラムダの整形式、高階の期待名、レコード構成子の関数値の名前を検査する。
example : got (run [] (.lam ["value"] [intTy] intTy emptyEff (.last (.returnE intTy (.local 0)))))
    (.fn ["value"] [intTy] intTy emptyEff) = true := by rfl
example : (run [] (.lam ["value", "value"] [intTy, intTy] (.base .unit) emptyEff .empty)).map (fun _ => ()) =
    .error ⟨[], "lambda contract names are not well formed"⟩ := by rfl
example : (run [] (.lam [] [intTy] (.base .unit) emptyEff .empty)).map (fun _ => ()) =
    .error ⟨[], "lambda contract names are not well formed"⟩ := by rfl
example : (run [some (.fn ["f"] [.fn ["value"] [intTy] intTy emptyEff] intTy emptyEff)]
    (.call (.local 0) [some "f"] [0]
      (.cons (.lam ["x"] [intTy] intTy emptyEff (.last (.returnE intTy (.local 0)))) .nil))).map (fun _ => ()) =
    .error ⟨[1, 0], "type is not included in the expected type"⟩ := by rfl
example : got (run [] (.conValue "Pair" [intTy] ["first", "second"] [intTy, boolTy]))
    (.fn ["first", "second"] [intTy, boolTy] (.data "PairTy" [intTy]) emptyEff) = true := by rfl
example : (run [] (.conValue "Pair" [intTy] ["arg1", "arg2"] [intTy, boolTy])).map (fun _ => ()) =
    .error ⟨[], "constructor contract annotation mismatch"⟩ := by rfl

-- 操作と辞書を通るメソッドも、同じ逆順呼び出しを受け入れる。
example : got (run [] (.call (.opName "ask" []) [some "b", some "a"] [1, 0] reversed))
    intTy (Eff.single "Ask") = true := by rfl
example : got (run [some (.dict "Combine" intTy)]
    (.call (.methName (.local 0) "combine" [] [] [] ["a", "b"] [intTy, boolTy])
      [some "b", some "a"] [1, 0] reversed)) intTy = true := by rfl
example : (run [some (.dict "Combine" intTy)]
    (.methName (.local 0) "combine" [] [] [] ["b", "a"] [intTy, boolTy])).map (fun _ => ()) =
    .error ⟨[], "method contract annotation mismatch"⟩ := by rfl

-- 本体を位置で表した後では実名を復元できない。同じ型の二引数でも並び全体を比較する。
private def unitSig : MethSig :=
  { tparams := [], neffs := 0, names := ["a", "b"], params := [intTy, intTy],
    ret := .base .unit, eff := emptyEff }
private def unitClass : ClassDecl :=
  { supers := [], methods := fun m => if m == "method" then some unitSig else none }
private def unitQ : Input := { q with D := { q.D with classes := fun _ => some unitClass } }
private def impl (names : List String) : ImplInput :=
  { tparams := [], dictParams := [], cls := "UnitClass", target := intTy,
    supers := fun _ => none, methods := fun m => if m == "method" then some ⟨names, .empty⟩ else none }
example : checkImpl unitQ ["method"] [] [] (impl ["a", "b"]) = .ok () := by rfl
example : checkImpl unitQ ["method"] [] [] (impl ["b", "a"]) =
    .error ⟨[0, 0], "implementation method parameter names mismatch"⟩ := by rfl
example : checkImpl unitQ ["method"] [] [] (impl []) =
    .error ⟨[0, 0], "implementation method parameter names mismatch"⟩ := by rfl

private def materials (names : List String) : CheckTables.Materials :=
  { defs := [], conFields := [], accessors := [], data := [], ops := [], effects := [],
    classes := [("UnitClass", ⟨[], [("method", unitSig)]⟩)],
    impls := [("impl", ⟨⟨[], [], "UnitClass", intTy⟩, [], [("method", ⟨names, .empty⟩)]⟩)],
    trustedFuns := [], trustedImpls := [] }
private def materialQ (m : CheckTables.Materials) : Input :=
  m.input stringBuiltins (fun _ _ _ => true) (fun _ _ _ => true) stringOp atoms
example : CheckTables.checkProgram (materialQ (materials ["a", "b"]))
    (materials ["a", "b"]) (materials ["a", "b"]).names = .ok () := by rfl
example : CheckTables.checkProgram (materialQ (materials ["b", "a"]))
    (materials ["b", "a"]) (materials ["b", "a"]).names =
    .error ⟨[1, 0, 0, 0], "implementation method parameter names mismatch"⟩ := by rfl

-- 分岐の合流と入れ子の型の整形式も、契約名を比較・検査する。
example : (run [some (.fn ["a"] [intTy] intTy emptyEff), some (.fn ["b"] [intTy] intTy emptyEff)]
    (.ite (.literal (.boolean true)) (.last (.local 0)) (.last (.local 1)))).map (fun _ => ()) =
    .error ⟨[], "branch types have no join"⟩ := by rfl
example : (run [] (.list (.fn ["x", "x"] [intTy, intTy] intTy emptyEff) .nil)).map (fun _ => ()) =
    .error ⟨[], "list element type is not well formed"⟩ := by rfl

private def polyDecl : FunDecl :=
  { tparams := [{}], neffs := 0, names := ["value"], params := [.tvar 0], ret := .tvar 0,
    eff := emptyEff, dictParams := [("C", 0)] }
private def polyQ : Input :=
  { q with D := { q.D with funs := fun _ => some polyDecl } }
example : got (checkExpr polyQ .strict [] [some (.dict "C" intTy)] none .other []
    (.funDicts "poly" [intTy] [] [.local 0] ["value"] [intTy]))
    (.fn ["value"] [intTy] intTy emptyEff) = true := by rfl
example : (checkExpr polyQ .strict [] [some (.dict "C" intTy)] none .other []
    (.funDicts "poly" [intTy] [] [.local 0] ["other"] [intTy])).map (fun _ => ()) =
    .error ⟨[], "function contract annotation mismatch"⟩ := by rfl
example : got (run [] (.primName "String.add" [] []))
    (.fn ["left", "right"] [.base .string, .base .string] (.base .string) emptyEff) = true := by rfl

end Checker

end Benitoite.Surface.CheckTools.Examples
