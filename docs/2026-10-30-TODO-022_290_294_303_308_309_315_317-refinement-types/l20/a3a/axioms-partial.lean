import Lean
import Benitoite.Release.Refinement.Types
import Benitoite.Release.Refinement.TypeRenaming
import Benitoite.Release.Refinement.Declared
import Benitoite.Release.Refinement.DeclaredTransport
import Benitoite.Release.Refinement.KindValues
import Benitoite.Release.Refinement.Admissible
import Benitoite.Release.Refinement.AdmissibleMap
import Benitoite.Release.Refinement.SubstitutionContracts
import Benitoite.Release.Refinement.ConstraintAssumptions
import Benitoite.Release.Refinement.ProgramTyping
import Benitoite.Release.Refinement.External
import Benitoite.Release.Refinement.HandlerContracts
import Benitoite.Release.Refinement.TypeShiftContext
import Benitoite.Release.Refinement.TypeShiftKinds
import Benitoite.Release.Refinement.TypeShiftContracts
import Benitoite.Release.Refinement.TypeShiftExchange
import Benitoite.Release.Refinement.LegacyKinds
import Benitoite.Release.Refinement.LegacyDeclarations

set_option maxHeartbeats 4000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite.Release.Refinement.Types,
    `Benitoite.Release.Refinement.TypeRenaming,
    `Benitoite.Release.Refinement.Declared,
    `Benitoite.Release.Refinement.DeclaredTransport,
    `Benitoite.Release.Refinement.KindValues,
    `Benitoite.Release.Refinement.Admissible,
    `Benitoite.Release.Refinement.AdmissibleMap,
    `Benitoite.Release.Refinement.SubstitutionContracts,
    `Benitoite.Release.Refinement.ConstraintAssumptions,
    `Benitoite.Release.Refinement.ProgramTyping,
    `Benitoite.Release.Refinement.External,
    `Benitoite.Release.Refinement.HandlerContracts,
    `Benitoite.Release.Refinement.TypeShiftContext,
    `Benitoite.Release.Refinement.TypeShiftKinds,
    `Benitoite.Release.Refinement.TypeShiftContracts,
    `Benitoite.Release.Refinement.TypeShiftExchange,
    `Benitoite.Release.Refinement.LegacyKinds,
    `Benitoite.Release.Refinement.LegacyDeclarations
  ] do
    let some idx := env.getModuleIdx? mod | throwError "AUDIT_UNAVAILABLE {mod}"
    let names := (env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some idx then some name else none).mergeSort
        (fun a b => a.toString < b.toString)
    unless names.length > 0 do throwError "AUDIT_EMPTY {mod}"
    logInfo m!"AUDIT_MODULE {mod} {names.length}"
    for name in names do elabCommand (← `(#print axioms $(mkIdent name)))
