import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarInputs
import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.PredicateStandardSupport

/-! # 実際の判定の解決と脱糖の接続 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

private def pipeCall (full : Bool) : Expr :=
  .pipe (.local 0) (.call (.primName "Float32.isFinite" [] [] [])
    (if full then [none] else []) (if full then [0] else [])
    (if full then .cons (.local 0) .nil else .nil))

private def pipeProgram (full : Bool) : Program where
  defs := fun name => if name = "predicate" then some {
    tparams := [], neffs := 0, names := ["value"], params := [.base .float32],
    ret := .base .unit, eff := Eff.empty, body := .discard (pipeCall full) .empty} else none
  cons := fun _ => none

private def pipeInput (full : Bool) : Check.Input where
  D := (pipeProgram full).declarations
  builtinSource := .standard (pipeProgram full).declarations.core
  opPrim := fun _ _ => none
  formation := ⟨PredicateStandardSupport.atoms, fun _ => [], []⟩
  proofSteps := 4
  defs := ["predicate"]

attribute [local cbv_opaque] StandardModel.builtins

/-- 全引数を持つ呼出しをrhsに置いたパイプは、準備後のBooleanを関数として呼べない。 -/
theorem full_pipe_rejected :
    CheckTables.checkProgram (pipeInput true) (pipeProgram true) =
      .error {path := [0,0,1,0], reason := "expected a function type"} := by cbv

/-- 引数を後から挿入する空の呼出しは、名前解決の候補にならない。 -/
theorem empty_pipe_preserved : CheckPreparation.prepare (pipeInput false) (pipeProgram false) =
    ⟨pipeInput false, pipeProgram false⟩ := by cbv

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
