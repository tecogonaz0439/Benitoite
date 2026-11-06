import Benitoite.Release.Refinement.Surface.CheckDeclarationsSound
import Benitoite.Release.Refinement.Surface.RangeFunctionExamples

/-! # 範囲パラメータを持つ関数の実入口の受理 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpenExamples
open Check Scope.Domain
open RangeFunctionExamples

def input (k : Kind) : Check.Input where
  D := declarations k
  builtinSource := .unrestrictedRanges (builtins k)
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  satDec := fun _ _ _ => true
  admitsDec := fun _ _ ts => decide (ts = [])
  admitsRDec := fun _ _ => true
  proofSteps := 10

/-- 引数の範囲変数を、同じ種類の利用者の関数へ転送する。 -/
theorem function_forward :
    CheckDeclarations.checkDef (input .path) [] (forwardDef .path) = .ok () := by
  cbv

/-- host と endpoint の開いた範囲は、同種の組込みへ渡せる。 -/
theorem primitive_forward :
    CheckDeclarations.checkDef (input .host) [] (inspectDef .host) = .ok () ∧
    CheckDeclarations.checkDef (input .endpoint) [] (inspectDef .endpoint) = .ok () := by
  constructor <;> cbv

private def aliasType : Ty := .scoped "Scope.PathIn" .path (.rvar 0)

private theorem alias_expands : pathAlias.expandOpen [] [] [.rvar 0] = aliasType := by
  simp [AliasDecl.expandOpen, pathAlias, Ty.subst, Ty.substAt, substTypeAt,
    Ty.bind, Ty.rawBind, Ty.mapRanges, Ty.rawMapRanges, Ty.norm, typeEnvAt, RangeIx.inst,
    SubstEnv.valuesOnly, aliasRangeEnv, mapIx, aliasType]

private noncomputable def aliasDefinition : Def where
  tparams := []
  neffs := 0
  names := ["path"]
  params := [pathAlias.expandOpen [] [] [.rvar 0]]
  ret := pathAlias.expandOpen [] [] [.rvar 0]
  eff := Eff.empty
  rangeParams := [.path]
  body := .last (.local 0)

/-- 別名へ関数由来の開いた path 範囲を渡した注釈を、定義の検査で受け付ける。 -/
theorem alias_annotation :
    CheckDeclarations.checkDef (input .path) [] aliasDefinition = .ok () := by
  unfold aliasDefinition
  rw [alias_expands]
  cbv

end Benitoite.Release.Refinement.Surface.CheckOpenExamples
