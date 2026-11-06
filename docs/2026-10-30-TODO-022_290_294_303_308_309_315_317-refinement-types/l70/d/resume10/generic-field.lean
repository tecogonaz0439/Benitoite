import Benitoite.Release.Refinement.Surface.CheckPredicateProjectionExamples
import Benitoite.Release.Refinement.Surface.PredicateSimulationPublicProviders
namespace Benitoite.Release.Refinement.Surface
noncomputable section
private def box : ConDecl := ⟨"Generic.Box", 1, [.tvar 0]⟩
private def program : Program where
  defs := fun _ => none
  cons := fun name => if name = "Generic.Box.make" then some box else none
  accessors := fun name => if name = "Generic.Box.value" then some ("Generic.Box.make", 0) else none
private def source : Expr := .call (.funName "Generic.Box.value" [.base .float] [] []) [some "value"] [0] (.cons (.local 0) .nil)
private def condition : Expr := .call (.primName "Float.isFinite" [] [] []) [none] [0] (.cons source .nil)
private def input : Check.Input where
  D := program.declarations
  builtinSource := .standard program.declarations.core
  opPrim := fun _ _ => none
  formation := ⟨PredicateStandardSupport.atoms, fun name => if name = "Generic.Box" then ["Generic.Box.make"] else [], []⟩
  satDec := fun _ _ _ => true
  admitsDec := fun _ _ _ => true
  proofSteps := 4
private theorem finite_signature (P : Refinement.Program) : (StandardModel.builtins P).sig "Float.isFinite" = some (PredicateResponse.API.floating .binary64 .finite).signature :=
  PredicateSimulation.public_signature (B := StandardModel.builtins P) (.floating .binary64 .finite)
attribute [local cbv_opaque] StandardModel.builtins
attribute [local cbv_eval] finite_signature
private theorem no_projection : PredicateAccessorTargets.parse program source = none := by
  unfold source
  rw [PredicateAccessorTargets.parse]
  rfl
private theorem source_strip : PredicateCalls.stripParens source = source := rfl
private theorem source_value : source.valueOf? = none := rfl
private theorem source_resolved : PredicateCalls.resolveExprWith (PredicateProjectionCalls.resolveCall [] program) source = source := rfl
attribute [local cbv_opaque] PredicateAccessorTargets.parse PredicateCalls.resolveExprWith program source
attribute [local cbv_eval] no_projection source_strip source_value source_resolved
example : PredicateRowCollection.candidate program condition = none := by cbv
example : PredicateProjectionCalls.resolveExpr [] program condition = condition := by
  change PredicateProjectionCalls.resolveCall [] program "Float.isFinite" [none] [0] (.cons source .nil) = condition
  cbv
example : (Check.checkExpr input [] [some (.data "Generic.Box" [.base .float])] [] none .other [] condition).toBool = true := by
  unfold input condition source program
  cbv
end
end Benitoite.Release.Refinement.Surface
