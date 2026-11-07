import Benitoite.Release.Refinement.Surface.PredicateSimulationIdentification
import Benitoite.Release.Refinement.Surface.PredicateSimulationPublicProviders
import Benitoite.Release.Refinement.Surface.PredicateStandardSupport
namespace Benitoite.Release.Refinement.Surface.PredicateMismatchedProjectionBoundary
open PredicateRows PredicateProjection
noncomputable section
private def aDecl : ConDecl := ⟨"Mismatch.A", 0, [.data "Mismatch.B" []]⟩
private def bDecl : ConDecl := ⟨"Mismatch.B", 0, []⟩
private def cDecl : ConDecl := ⟨"Mismatch.C", 0, [.base .float]⟩
private def aRef : FieldRef := ⟨"Mismatch.A", "Mismatch.A.make", 0, .data⟩
private def cRef : FieldRef := ⟨"Mismatch.C", "Mismatch.C.make", 0, .float64⟩
private def getter (name : FunName) (receiver : Expr) : Expr :=
  .call (.funName name [] [] []) [some "value"] [0] (.cons receiver .nil)
private def target : Expr := getter "Mismatch.C.number" (getter "Mismatch.A.inner" (.local 0))
private def condition : Expr := .call (.primName "Float.isFinite" [] [] []) [none] [0] (.cons target .nil)
private def body : Block := .last (.ite (.literal (.boolean false)) (.lastDiscard condition) .empty)
private def program : Program where
  defs := fun name => if name = "probe" then some {
    tparams := [], neffs := 0, names := ["value"], params := [.data "Mismatch.A" []],
    ret := .base .unit, eff := Eff.empty, body := body } else none
  cons := fun name => if name = "Mismatch.A.make" then some aDecl else if name = "Mismatch.B.make" then some bDecl else if name = "Mismatch.C.make" then some cDecl else none
  accessors := fun name => if name = "Mismatch.A.inner" then some ("Mismatch.A.make", 0) else if name = "Mismatch.C.number" then some ("Mismatch.C.make", 0) else none
private def aStep : PredicateAccessorTargets.Step := ⟨"Mismatch.A.inner", "Mismatch.A.make", aDecl, 0, [], .data⟩
private def cStep : PredicateAccessorTargets.Step := ⟨"Mismatch.C.number", "Mismatch.C.make", cDecl, 0, [], .float64⟩
private def parsed : PredicateAccessorTargets.Parsed program target :=
  ⟨.local 0, .var 0, .field cRef (.field aRef (.var 0)), [aStep,cStep],
    .accessor (s := cStep) rfl rfl rfl rfl rfl rfl (by decide)
      (.accessor (s := aStep) rfl rfl rfl rfl rfl rfl (by decide) (.value rfl rfl))⟩
private def projection : Projection := ⟨0,"Mismatch.A",[aRef,cRef],.floating .binary64 .finite⟩
private def rows : Table.Rows := [("%Predicate.0",.projected projection)]
private def input : Check.Input where
  D := program.declarations
  builtinSource := .standard program.declarations.core
  opPrim := fun _ _ => none
  formation := ⟨PredicateStandardSupport.atoms, fun name =>
    if name = "Mismatch.A" then ["Mismatch.A.make"] else if name = "Mismatch.B" then ["Mismatch.B.make"] else if name = "Mismatch.C" then ["Mismatch.C.make"] else [], []⟩
  satDec := fun _ _ param => !param.equality && !param.key
  admitsDec := fun name _ types => decide (name = "Float.isFinite" ∧ types = [])
  proofSteps := 4
  defs := ["probe"]
  dataNames := ["Mismatch.A","Mismatch.B","Mismatch.C"]
  ctorNames := ["Mismatch.A.make","Mismatch.B.make","Mismatch.C.make"]
private def required : CheckAccept.AcceptInput := {
  ok := "Ok", rules := fun _ => none, limits := ⟨⟨100,100⟩,⟨100,100⟩⟩,
  methodKey := fun i m => i ++ "." ++ m }
private theorem target_parse : PredicateAccessorTargets.parse program target = some parsed := parsed.sound.parse
private theorem target_strip : PredicateCalls.stripParens target = target := rfl
private theorem target_resolved : PredicateCalls.resolveExprWith (PredicateProjectionCalls.resolveCall rows program) target = target := rfl
private theorem source_names : PredicateGeneratedNames.sourceNames input program = ["Float.isFinite"] := rfl
private theorem sources_list : CheckPreparation.sources input program =
    [.ite (.literal (.boolean false)) (.lastDiscard condition) .empty,
      .literal (.boolean false), condition, .primName "Float.isFinite" [] [] [], target,
      .funName "Mismatch.C.number" [] [] [], getter "Mismatch.A.inner" (.local 0),
      .funName "Mismatch.A.inner" [] [] [], .local 0] := rfl
private theorem target_candidate : PredicateRowCollection.candidate program target = none := rfl
private theorem finite_signature (P : Refinement.Program) : (StandardModel.builtins P).sig "Float.isFinite" = some (PredicateResponse.API.floating .binary64 .finite).signature :=
  PredicateSimulation.public_signature (B := StandardModel.builtins P) (.floating .binary64 .finite)
attribute [local cbv_opaque] PredicateAccessorTargets.parse StandardModel.builtins CheckPreparation.sources program target
attribute [local cbv_eval] target_parse target_strip finite_signature source_names sources_list target_candidate
example : PredicateRowCollection.candidate program condition = some (.projected projection) := by cbv
private theorem collected : PredicateRowCollection.collectAvoid program (CheckPreparation.sources input program) (PredicateGeneratedNames.forbidden input program) = rows := by
  rw [sources_list]
  unfold PredicateGeneratedNames.forbidden
  rw [source_names]
  cbv
private def encoded : Expr := PredicateProjectionCalls.encodedCall "%Predicate.0" [] projection (.local 0) target (.var 0)
private theorem condition_resolved : PredicateProjectionCalls.resolveExpr rows program condition = encoded := by
  change PredicateProjectionCalls.resolveCall rows program "Float.isFinite" [none] [0] (.cons target .nil) = encoded
  cbv
private theorem body_resolved : PredicateProjectionCalls.resolveBlock rows program body =
    .last (.ite (.literal (.boolean false)) (.lastDiscard encoded) .empty) := by
  change Block.last (Expr.ite (.literal (.boolean false)) (.lastDiscard (PredicateProjectionCalls.resolveExpr rows program condition)) .empty) = _
  rw [condition_resolved]
private def resolvedProgram : Program := {program with defs := fun name => if name = "probe" then some {
  tparams := [], neffs := 0, names := ["value"], params := [.data "Mismatch.A" []], ret := .base .unit, eff := Eff.empty,
  body := .last (.ite (.literal (.boolean false)) (.lastDiscard encoded) .empty) } else none }
private theorem program_resolved : CheckPreparation.resolveProgram rows program = resolvedProgram := by
  unfold CheckPreparation.resolveProgram resolvedProgram
  congr 1
  funext name
  by_cases same : name = "probe"
  · have selected : program.defs name = some {
      tparams := [], neffs := 0, names := ["value"], params := [.data "Mismatch.A" []],
      ret := .base .unit, eff := Eff.empty, body := body } := by simp only [program, same, ite_true]
    rw [selected]
    simp only [same, ite_true, Option.map_some]
    congr 2
    exact body_resolved
  · have missing : program.defs name = none := by simp only [program, same, ite_false]
    rw [missing]
    simp only [same, ite_false, Option.map_none]
private theorem prepared : CheckPreparation.prepare input program =
    ⟨CheckPreparation.input input rows, resolvedProgram⟩ := by
  unfold CheckPreparation.prepare
  simp only [collected]
  rw [program_resolved]
  rfl
example : (CheckAccept.checkProgramAccepted input required program).toBool = false := by
  unfold CheckAccept.checkProgramAccepted CheckTables.checkProgram
  rw [prepared]
  unfold input resolvedProgram program encoded body condition target getter
  cbv
example : CheckAccept.checkProgramAccepted input required program =
    .error (.typing { path := [0,0,1,0,1,0], reason := "call signature is invalid" }) := by
  unfold CheckAccept.checkProgramAccepted CheckTables.checkProgram
  rw [prepared]
  unfold input resolvedProgram program encoded body condition target getter
  cbv
end
end Benitoite.Release.Refinement.Surface.PredicateMismatchedProjectionBoundary
