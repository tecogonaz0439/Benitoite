import Lean
import Benitoite.Scope.SwitchExamples
open Lean

#eval show CoreM Unit from do
  let env ← getEnv
  IO.println s!"SwitchExamples closure: {env.allImportedModuleNames.size} modules"
  for m in [`Benitoite.Release.Theorems, `Benitoite.Release.Lemmas.EffectSound, `Benitoite.Release.Lemmas.StepSound,
            `Benitoite.Surface.Theorems, `Benitoite.Release.Semantics, `Benitoite.Release.Assumptions,
            `Benitoite.Interval.RangeState, `Benitoite.Interval.Flow, `Benitoite.Interval.Sound] do
    IO.println s!"{m}: {env.allImportedModuleNames.contains m}"
  for n in [`Benitoite.Release.progress, `Benitoite.Release.preservation, `Benitoite.Release.effect_soundness,
            `Benitoite.Release.steps_preserve, `Benitoite.Surface.desugar_typed] do
    IO.println s!"{n}: {env.contains n}"
