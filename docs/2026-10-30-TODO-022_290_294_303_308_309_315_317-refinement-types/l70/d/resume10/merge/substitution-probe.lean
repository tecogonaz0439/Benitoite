import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.CheckMaterialsSound
namespace Benitoite.Release.Refinement.Surface.Probe
open CheckTables
noncomputable section
private def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => False,
    refGet := "get", refSet := "set" }
private def getter : Expr := .call (.funName "Box.value" [] []) [some "value"] [0] (.cons (.local 0) .nil)
private def cd (a : Ty) : ConDecl := ⟨"Box", 0, [a]⟩
/-- 戻り値の契約が、結果と引数の受け手の欄の関係そのものである。 -/
private def related (a : Ty) : Def where
  tparams := []
  neffs := 0
  names := ["record"]
  params := [.data "Box" []]
  ret := accessorRet "Box" (cd a) 0 []
  eff := .empty
  body := .last getter
private def materials (a : Ty) : Materials where
  defs := [("related", related a)]
  cons := [("Box", cd a)]
  conFields := [("Box", ["value"])]
  accessors := [("Box.value", ("Box", 0))]
private def baseInput : Check.Input where
  D := { funs := fun _ => none, cons := fun _ => none }
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  proofSteps := 100
example : (checkProgram ((materials (.base .string)).input baseInput) (materials (.base .string)).program).toBool = false := by cbv
example : (checkProgram ((materials (.base .integer)).input baseInput) (materials (.base .integer)).program).toBool = false := by cbv
-- 実引数と外側の値の等号を前提に足しても、自動の候補は欄の関係を移さない。
private def relS (r : Term) : Pred := .compare .string .eq (.var 0) (.field ⟨"Box","Box",0,.string⟩ r)
example : (CheckPropositional.candidate [relS (.var 1), .compare .data .eq (.var 1) (.var 2)] (relS (.var 2))).isNone = true := by cbv
example : (CheckPropositional.candidate [.eq (.var 0) (.field ⟨"Box","Box",0,.integer⟩ (.var 1)), .compare .data .eq (.var 1) (.var 2)]
  (.eq (.var 0) (.field ⟨"Box","Box",0,.integer⟩ (.var 2)))).isNone = true := by cbv
end
end Benitoite.Release.Refinement.Surface.Probe
