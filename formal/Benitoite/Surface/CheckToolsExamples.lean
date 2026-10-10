import Benitoite.Surface.CheckPatterns
import Benitoite.Release.BuiltinTable

/-! 判定と構造的な再帰の写しの評価例。 -/
namespace Benitoite.Surface.CheckTools.Examples
open Benitoite.Release

private def atoms : List Atom := [.name "IO", .name "State", .rho 0, .rho 2]
private def intTy : Ty := .base .integer
private def boolTy : Ty := .base .boolean
private def ioEff : Eff := Eff.single "IO"
private def rhoEff : Eff := fun a => a == .rho 0
private def gotTypes (xs : Option (List Ty)) (ts : List Ty) : Bool :=
  match xs with
  | some us => tysEq atoms us ts
  | none => false

-- エフェクトの包含、等しさ、切り詰めた構築。
example : effSub atoms emptyEff ioEff = true := by decide
example : effSub atoms ioEff emptyEff = false := by decide
example : effEq atoms ioEff (singleEff atoms (.name "IO")) = true := by decide
example : effEq atoms ioEff rhoEff = false := by decide
example : singleEff atoms (.rho 0) (.rho 0) = true := by decide
example : singleEff atoms (.name "Unknown") (.name "Unknown") = false := by decide
example : unionEff atoms ioEff rhoEff (.rho 0) = true := by decide
example : unionEff atoms ioEff (Eff.single "Unknown") (.name "Unknown") = false := by decide
example : emptyEff (.rho 2) = false := rfl
example : Eff.substRho [ioEff] rhoEff (.name "IO") = true := by decide
example : Eff.substRho [ioEff] (fun a => a == .rho 2) (.rho 2) = true := by decide

-- 型の全構成、並行した型リスト、外側だけのエフェクトの包含。
private def richTypes : List Ty := [intTy, .opaque "O", .data "D" [intTy], .list intTy,
  .fn [intTy] boolTy ioEff, .tvar 1, .reference intTy, .lazy intTy,
  .cont intTy boolTy rhoEff, .map intTy boolTy, .set intTy, .bytes,
  .dict "Eq" intTy, .tapp 0 [intTy], .ctor (.data "D"), .ctor .list,
  .ctor .set, .ctor .map, .ctor .reference, .ctor .lazy]
example : tysEq atoms richTypes richTypes = true := by decide
example : tyEq atoms intTy boolTy = false := by decide
example : tyEq atoms (.fn [intTy] boolTy emptyEff) (.fn [intTy] boolTy ioEff) = false := by decide
example : tysEq atoms [intTy] [] = false := by decide
example : tyConEq (.data "D") (.data "E") = false := by decide
example : tyConEq .list .map = false := by decide
example : tyLe atoms (.fn [intTy] boolTy emptyEff) (.fn [intTy] boolTy ioEff) = true := by decide
example : tyLe atoms (.fn [intTy] boolTy ioEff) (.fn [intTy] boolTy emptyEff) = false := by decide
example : tyLe atoms (.list (.fn [] intTy emptyEff)) (.list (.fn [] intTy ioEff)) = false := by decide
example : tyLe atoms intTy intTy = true := by decide

-- shift はエフェクトに触れず、subst はエフェクト変数も具体化する。
example : tyEq atoms (shiftTy 2 1 (.fn [.tvar 0, .tvar 1] (.tapp 2 [.tvar 0]) rhoEff))
    (.fn [.tvar 0, .tvar 3] (.tapp 4 [.tvar 0]) rhoEff) = true := by decide
example : tyEq atoms (substTyAt 1 [intTy] [ioEff] (.fn [.tvar 0, .tvar 1, .tvar 2] (.tvar 1) rhoEff))
    (.fn [.tvar 0, intTy, .tvar 1] intTy ioEff) = true := by decide
example : tyEq atoms (substTyAt 1 [.tvar 0] [] (.tvar 1)) (.tvar 1) = true := by decide
example : tyEq atoms (substTy [.ctor .list] [] (.tapp 0 [intTy])) (.list intTy) = true := by decide
example : tyEq atoms (substTyAt 1 [intTy] [] (.tapp 0 [.tvar 1])) (.tapp 0 [intTy]) = true := by decide
example : tyEq atoms (substTy [intTy] [] (.tapp 2 [.tvar 0])) (.tapp 1 [intTy]) = true := by decide
example : tyEq atoms (applyToTy (.ctor .map) [intTy, boolTy]) (.map intTy boolTy) = true := by decide
example : tyEq atoms (applyToTy (.ctor .map) []) (.map (.base .unit) (.base .unit)) = true := by decide
example : tyEq atoms (applyToTy (.tvar 2) [intTy]) (.tapp 2 [intTy]) = true := by decide
example : tyEq atoms (applyToTy intTy [boolTy]) intTy = true := by decide
example : tyEq atoms (fnTyCheck [.tvar 0] (.tvar 0) rhoEff [intTy] [ioEff])
    (.fn [intTy] intTy ioEff) = true := by decide

-- 既存の整礎再帰の式は、その等式補題で展開してから比較する。
example : shiftTy 2 0 (.list (.tvar 0)) = Ty.shift 2 0 (.list (.tvar 0)) := by
  simp only [Ty.shift]; rfl
example : substTyAt 1 [intTy] [ioEff] (.list (.tvar 1)) =
    Ty.substAt 1 [intTy] [ioEff] (.list (.tvar 1)) := by
  simp [substTyAt, Ty.substAt, intTy, shiftTy, Ty.shift]
example : applyToTy (.ctor .map) [intTy, boolTy] =
    Ty.applyTo (.ctor .map) [intTy, boolTy] := rfl
example : tyEq atoms (substTy [intTy] [] (.list (.tvar 0)))
    (Coverage.substTy [intTy] (.list (.tvar 0))) = true := by decide

-- 規則の前提に使う構文の判定。
example : wfTys 2 richTypes = true := by decide
example : wfTy 1 (.tvar 1) = false := by decide
example : wfTy 1 (.tapp 1 [intTy]) = false := by decide
example : exprExits (.ite .unit (.last (.returnE intTy .unit)) (.last (.returnE intTy .unit))) = true := by decide
example : exprExits (.constE intTy (.returnE intTy .unit)) = false := by decide
example : exprExits (.paren (.withE "R" .unit (.last (.returnE intTy .unit)))) = true := by decide
example : exprExits (.elseIf .unit (.last (.returnE intTy .unit)) (.returnE intTy .unit)) = true := by decide
example : exprExits (.matchE intTy .unit .nil) = true := by decide
example : blockExits (.seq (.returnE intTy .unit) .empty) = true := by decide
example : blockExits (.lastBind .bind intTy (.returnE intTy .unit)) = false := by decide
example : armsExits (.cons [] none .empty .nil) = false := by decide
example : patternValid (.range (.integer 2) (.integer 1)) = false := by decide
example : patternValid (.range (.character 'a') (.character 'z')) = true := by decide
example : patternValid (.list [] none [.wild]) = false := by decide
example : patternValid (.record "C" 1 [0] [.range (.integer 2) (.integer 1)]) = false := by decide
example : patternValid (.con none "C" [.list [] (some .skip) [.wild]]) = true := by decide
example : patternsValid [.wild, .var, .unit] = true := by decide
example : alternativesValid [⟨.range (.integer 1) (.integer 2), []⟩] = true := by decide
example : alternativesValid [⟨.range (.integer 2) (.integer 1), []⟩] = false := by decide
example : isIf (.elseIf .unit .empty (.ifOnly .unit .empty)) = true := by decide
example : isIf (.elseIf .unit .empty (.paren (.ifOnly .unit .empty))) = false := by decide
example : nontrivial .var = false := by decide
example : nontrivial (.boolean true) = true := by decide
example : pipeValue (.call .unit .nil) = false := by decide
example : pipeValue (.paren (.call .unit .nil)) = true := by decide
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

example : gotTypes (patTy decls.patternProgram .wild intTy) [] = true := by decide
example : gotTypes (patTy decls.patternProgram .var intTy) [intTy] = true := by decide
example : gotTypes (patTy decls.patternProgram (.const (.integer 3)) intTy) [] = true := by decide
example : (patTy decls.patternProgram (.const (.byte 3)) (.base .byte)).isNone = true := by decide
example : (patTy decls.patternProgram (.const (.integer 3)) boolTy).isNone = true := by decide
example : gotTypes (patTy decls.patternProgram (.range (.integer 1) (.integer 3)) intTy) [] = true := by decide
example : gotTypes (patTy decls.patternProgram (.range (.character 'a') (.character 'z')) (.base .character)) [] = true := by decide
example : gotTypes (patTy decls.patternProgram (.list [.var] (some .bind) [.var]) (.list intTy))
    [intTy, .list intTy, intTy] = true := by decide
example : (patTy decls.patternProgram (.list [] none [.var]) (.list intTy)).isNone = true := by decide
example : gotTypes (patTy decls.patternProgram (.con "Pair" [.var, .var]) (.data "PairTy" [intTy]))
    [intTy, boolTy] = true := by decide
example : (patTy decls.patternProgram (.con "Pair" [.var, .var]) (.data "Wrong" [intTy])).isNone = true := by decide
example : (patTy decls.patternProgram (.con "Pair" [.var, .var]) (.data "PairTy" [])).isNone = true := by decide
example : (patTy decls.patternProgram (.con "Unknown" []) intTy).isNone = true := by decide
example : gotTypes (surfacePatTy decls (.record "Pair" 2 [1, 0] [.var, .var]) (.data "PairTy" [intTy]))
    [intTy, boolTy] = true := by decide
example : gotTypes (surfacePatTy decls (.record "Pair" 2 [1] [.var]) (.data "PairTy" [intTy]))
    [boolTy] = true := by decide
example : gotTypes (patTys decls.patternProgram [.var, .wild] [intTy, boolTy]) [intTy] = true := by decide
example : (patTys decls.patternProgram [.var] []).isNone = true := by decide

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
  { tparams := [], neffs := 0, params := [.base .string, .base .string],
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
example : satAll (satB []) [] [.fn [] intTy emptyEff] [{ equality := true }] = false := by decide

end Benitoite.Surface.CheckTools.Examples
