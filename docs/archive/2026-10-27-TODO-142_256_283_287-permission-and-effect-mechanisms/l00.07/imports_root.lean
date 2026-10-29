import Benitoite
open Lean

def names : List Name := [
  `Benitoite.Release.progress, `Benitoite.Release.preservation, `Benitoite.Release.effect_soundness,
  `Benitoite.Release.effect_soundness_noLamNames, `Benitoite.Release.step_sound, `Benitoite.Surface.desugar_typed,
  `Benitoite.Scope.SignatureExamples.target_sound, `Benitoite.Scope.TargetExamples.step_target_sound,
  `Benitoite.Scope.TargetExamples.reachable_of_step, `Benitoite.Scope.InferenceExamples.minimal_checked,
  `Benitoite.Scope.CompatExamples.TopEmbedding.old_union_empty_right_nested,
  `Benitoite.Scope.SwitchExamples.check_then_write, `Benitoite.Scope.SwitchExamples.minimal_then_write,
  `Benitoite.Scope.SwitchExamples.widen_then_write_same_target, `Benitoite.Scope.SwitchExamples.log_clause_obs,
  `Benitoite.Scope.SwitchExamples.save_clause, `Benitoite.Scope.SwitchExamples.mixed_reachable,
  `Benitoite.Scope.SwitchExamples.nonTopI_not_lifted, `Benitoite.Scope.SwitchExamples.ValueTyping.tyC_not_tree]

#eval show CoreM Unit from do
  let env ← getEnv
  IO.println s!"root imports {env.allImportedModuleNames.size} modules"
  for n in names do
    match env.getModuleIdxFor? n with
    | some i => IO.println s!"{n} <- {env.allImportedModuleNames[i.toNat]!}"
    | none => IO.println s!"{n} MISSING"
