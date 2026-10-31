import Lean
import Benitoite.Shared.Approximation

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [`Benitoite.Release.Syntax, `Benitoite.Release.Types,
      `Benitoite.Release.Typing, `Benitoite.Release.Refinement.Syntax,
      `Benitoite.Interval.Domain, `Benitoite.Interval.Eval, `Benitoite.Interval.Flow] do
    if (env.getModuleIdx? mod).isSome then
      throwError "unexpected dependency of shared approximation: {mod}"
  for name in [`Benitoite.Release.min64, `Benitoite.Release.max64,
      `Benitoite.Interval.IntKind, `Benitoite.Interval.IntegerValue,
      `Benitoite.Interval.Interval, `Benitoite.Shared.ValueApprox,
      `Benitoite.Shared.ApproxValue, `Benitoite.Shared.FlowApprox,
      `Benitoite.Shared.EvalResult] do
    unless (env.find? name).isSome do throwError "missing shared declaration: {name}"
  logInfo "SHARED_IMPORTS_OK"
