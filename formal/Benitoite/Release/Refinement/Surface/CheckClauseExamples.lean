import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound
import Benitoite.Release.Refinement.ScopeSignatures

/-! # 実入口での操作の節の受理と発行専用の節の拒否 -/
namespace Benitoite.Release.Refinement.Surface.CheckClauseExamples
open Check

private def ordinarySignature : PrimSig where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.single processEnvironmentEff
  admits := fun _ _ => True
  kind := .io
  opEff := some processEnvironmentEff

private def recover : OpDecl where
  tparams := []
  names := []
  params := []
  ret := .base .unit
  eff := "Example.Recover"

private def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none
  ops := fun o => if o = "Example.recover" then some recover else none
  effects := fun l => if l = "Example.Recover" then some ["Example.recover"] else none

private def builtins : Builtins where
  sig := fun b => if b = ScopeSignatures.pathBasesName then some ScopeSignatures.pathBases else
    if b = "Example.environment" then some ordinarySignature else none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun l => if l = processEnvironmentEff then
    some [ScopeSignatures.pathBasesName, "Example.environment"] else none
  sat := fun _ _ _ => False
  refGet := "get"
  refSet := "set"

private def input : Check.Input where
  D := declarations
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [.name processEnvironmentEff (.fixed .top),
      .name "Example.Recover" (.fixed .top)], ctors := fun _ => [] }
  admitsDec := fun _ _ _ => true
  proofSteps := 10

private def handled (o : OpRef) : Expr :=
  .handleE (.last .unit) (.cons o 0 0 (.last .unit) .nil)

/-- 単位値を返す同じ保護本体と節本体で、利用者の操作と通常の IO の節を実入口が受理する。 -/
theorem user_and_ordinary_clauses_checked :
    Check.checkExpr input [] [] [] none .other [] (handled (.user "Example.recover")) =
      .ok (.base .unit, Eff.empty) ∧
    Check.checkExpr input [] [] [] none .other [] (handled (.prim "Example.environment")) =
      .ok (.base .unit, Eff.empty) := by
  with_unfolding_all exact ⟨rfl, rfl⟩

/-- 発行の節は署名と本体の推論を通るが、実入口の節の再検査が拒否する。 -/
theorem issuing_clause_rejected :
    (CheckInfer.inferExpr input ⟨input.logicCertificates⟩ [] [] [] [] [] none .other []
      (handled (.prim ScopeSignatures.pathBasesName))).toCheck.toBool = true ∧
    CheckHandler.clauseAllowed input.B (.prim ScopeSignatures.pathBasesName) = false ∧
    (match Check.checkExpr input [] [] [] none .other [] (handled (.prim ScopeSignatures.pathBasesName)) with
      | .error error => error.kind = .rejected
      | _ => False) := by
  with_unfolding_all exact ⟨rfl, rfl, rfl⟩

end Benitoite.Release.Refinement.Surface.CheckClauseExamples
