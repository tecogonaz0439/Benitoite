import Lean
import Benitoite
set_option maxHeartbeats 10000000
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let suffixes := [".q_mono", ".store", ".store_extend", ".shift_values", ".subst_under_none", ".hideConts_any", ".localRefs", ".withReturn", ".local_zero", ".subst_congr", ".K_Sub", "SubstOk.hide", ".resolve_id", ".closeVal_resolved", ".hideBuilders", ".HasTypeVQ.subst", ".HasTypeVQ.rename", ".HasTypeVQ.hide", ".HasTypeVsQ.subst", ".HasTypeVsQ.rename", ".HasTypeVsQ.hide", ".HasTypeEachQ.subst", ".HasTypeEachQ.rename", ".HasTypeEachQ.hide", ".HasTypeCQ.subst", ".HasTypeCQ.rename", ".HasTypeCQ.hide", ".HasTypeTelArgsQ.subst", ".HasTypeTelArgsQ.rename", ".HasTypeTelArgsQ.hide", ".TelBodyTy.subst", ".TelBodyTy.rename", ".TelBodyTy.hide", ".AtCallAdmissible.subst", ".AtCallAdmissible.rename", ".AtCallAdmissible.hide", ".HasTypeArmsQ.subst", ".HasTypeArmsQ.rename", ".HasTypeArmsQ.hide", ".HasTypeClausesQ.subst", ".HasTypeClausesQ.rename", ".HasTypeClausesQ.hide", ".HasFailureClause.subst", ".HasFailureClause.rename", ".HasFailureClause.hide", "StoreTy.WF.hide", "StoreTy.preserves_hide", "StoreTy.hide_extends"]
  let targets := env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.startsWith "Benitoite." || name.toString.startsWith "_private.Benitoite.") && suffixes.any (fun s => name.toString.endsWith s) then some name else none
  logInfo m!"READER_TARGETS {targets.length}"
  for (name, ci) in env.constants.toList do
    if name.toString.startsWith "Benitoite." || name.toString.startsWith "_private.Benitoite." then
      let used := ci.type.getUsedConstants ++ ((ci.value? (allowOpaque := true)).map (·.getUsedConstants)).getD #[]
      for target in targets do
        if used.contains target then
          let mod : Name := match env.getModuleIdxFor? name with
            | some idx => env.header.moduleNames[idx.toNat]!
            | none => .anonymous
          logInfo m!"READER {target} {mod} {name}"
