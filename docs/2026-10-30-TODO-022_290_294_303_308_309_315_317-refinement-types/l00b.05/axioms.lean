import Lean
import Benitoite

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.EqProof | throwError "missing EqProof"
  unless info.ctors.length == 4 do throwError "count mismatch EqProof"
  logInfo m!"CONSTRUCTORS EqProof: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.BuiltinLemma | throwError "missing BuiltinLemma"
  unless info.ctors.length == 2 do throwError "count mismatch BuiltinLemma"
  logInfo m!"CONSTRUCTORS BuiltinLemma: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.Certificate | throwError "missing Certificate"
  unless info.ctors.length == 6 do throwError "count mismatch Certificate"
  logInfo m!"CONSTRUCTORS Certificate: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.PreparedLeaf | throwError "missing PreparedLeaf"
  unless info.ctors.length == 1 do throwError "count mismatch PreparedLeaf"
  logInfo m!"CONSTRUCTORS PreparedLeaf: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.ExternalCarrier | throwError "missing ExternalCarrier"
  unless info.ctors.length == 8 do throwError "count mismatch ExternalCarrier"
  logInfo m!"CONSTRUCTORS ExternalCarrier: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.ExternalCarrierEach | throwError "missing ExternalCarrierEach"
  unless info.ctors.length == 2 do throwError "count mismatch ExternalCarrierEach"
  logInfo m!"CONSTRUCTORS ExternalCarrierEach: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.ExternalCarrierFields | throwError "missing ExternalCarrierFields"
  unless info.ctors.length == 2 do throwError "count mismatch ExternalCarrierFields"
  logInfo m!"CONSTRUCTORS ExternalCarrierFields: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.Step | throwError "missing Step"
  unless info.ctors.length == 76 do throwError "count mismatch Step"
  logInfo m!"CONSTRUCTORS Step: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.Entails | throwError "missing Entails"
  unless info.ctors.length == 18 do throwError "count mismatch Entails"
  logInfo m!"CONSTRUCTORS Entails: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.HasTypeVQ | throwError "missing HasTypeVQ"
  unless info.ctors.length == 28 do throwError "count mismatch HasTypeVQ"
  logInfo m!"CONSTRUCTORS HasTypeVQ: {info.ctors.length}: {info.ctors}"
  let some (.inductInfo info) := env.find? `Benitoite.Release.Refinement.HasTypeCQ | throwError "missing HasTypeCQ"
  unless info.ctors.length == 21 do throwError "count mismatch HasTypeCQ"
  logInfo m!"CONSTRUCTORS HasTypeCQ: {info.ctors.length}: {info.ctors}"
  for mod in [`Benitoite.Release.Refinement.Certificate, `Benitoite.Release.Refinement.ExternalObservation, `Benitoite.Release.Refinement.ExternalConnection, `Benitoite.Release.Refinement.ExternalCheck, `Benitoite.Release.Refinement.ExternalResponse, `Benitoite.Release.Refinement.Semantics, `Benitoite.Release.Refinement.Step] do
    let some idx := env.getModuleIdx? mod | throwError "module not imported: {mod}"
    let names := (env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some idx then some name else none).mergeSort (fun a b => a.toString < b.toString)
    logInfo m!"MODULE {mod}: {names.length}"
    for name in names do
      logInfo m!"TARGET {name}"
      elabCommand (← `(#print axioms $(mkIdent name)))

#print axioms Benitoite.Release.Model.assumptions
#print axioms Benitoite.Release.ModelTargets.assumptions
#print axioms Benitoite.Release.ModelHttp.assumptions
#print axioms Benitoite.Release.Ty.le_iff_leOld
#print axioms Benitoite.Release.Ty.wf_iff_old
#print axioms Benitoite.Release.Ty.varsIn_iff_old
#print axioms Benitoite.Release.Eff.covers_iff_sub_old
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
