
-- 追加モジュールの全宣言とローカルの生成宣言を固定点まで列挙する。
set_option maxHeartbeats 20000000
open Lean Elab Command in
run_cmd do
  let requested : List String := __MODULES__
  let initial ← getEnv
  for mod in requested do
    unless initial.header.moduleNames.any (fun n => n.toString == mod) do
      throwError "AUDIT_MODULE_MISSING {mod}"
  let mut seen : Std.HashSet Name := {}
  let mut rounds : Nat := 0
  repeat
    rounds := rounds + 1
    if rounds > 20 then throwError "AUDIT_FIXED_POINT_LIMIT"
    let env ← getEnv
    let pending := env.constants.toList.filterMap fun (n, _) =>
      let selected := match env.getModuleIdxFor? n with
        | none => true
        | some idx => requested.contains env.header.moduleNames[idx.toNat]!.toString
      if selected && !seen.contains n then some n else none
    if pending.isEmpty then break
    for n in pending.mergeSort (fun a b => a.toString < b.toString) do
      let env ← getEnv
      let some ci := env.find? n | throwError "AUDIT_MISSING {n}"
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {n}"
      seen := seen.insert n
      let mod := match env.getModuleIdxFor? n with
        | none => "local_records"
        | some idx => env.header.moduleNames[idx.toNat]!.toString
      let kind := match ci with
        | .thmInfo _ => "theorem" | .defnInfo _ => "definition" | .opaqueInfo _ => "opaque"
        | .inductInfo _ => "inductive" | .ctorInfo _ => "constructor" | .recInfo _ => "recursor"
        | .quotInfo _ => "quotient" | .axiomInfo _ => "axiom"
      let range ← findDeclarationRanges? n
      let line := range.map (fun r => r.range.pos.line) |>.getD 0
      logInfo m!"AUDIT_TARGET {n}"
      logInfo m!"AUDIT_DECL {mod} {kind} {line} {n}"
      elabCommand (← `(#print axioms $(mkIdent n)))
  let env ← getEnv
  for n in [``Benitoite.Release.Refinement.ModelHttp.entries,
      ``Benitoite.Release.Refinement.ModelHttp.effects,
      ``Benitoite.Release.Refinement.ModelHttp.ioResponse,
      ``Benitoite.Release.Refinement.ModelHttp.builtins,
      ``Benitoite.Release.Refinement.ModelHttp.sig_cases,
      ``Benitoite.Release.Refinement.ModelHttp.substitutionAssumptions,
      ``Benitoite.Release.Refinement.ModelHttp.sig_scoped,
      ``Benitoite.Release.Refinement.ModelHttp.sourceTelRows,
      ``Benitoite.Release.Refinement.ModelHttp.sat_unconstrained,
      ``Benitoite.Release.Refinement.ModelHttp.admits_sat,
      ``Benitoite.Release.Refinement.ModelHttp.pathBases_shape,
      ``Benitoite.Release.Refinement.ModelHttp.io_op,
      ``Benitoite.Release.Refinement.ModelHttp.opEff_io,
      ``Benitoite.Release.Refinement.ModelHttp.effect_ops,
      ``Benitoite.Release.Refinement.ModelHttp.state_effect,
      ``Benitoite.Release.Refinement.ModelHttp.ref_get,
      ``Benitoite.Release.Refinement.ModelHttp.ref_set,
      ``Benitoite.Release.Refinement.ModelHttp.store_shape,
      ``Benitoite.Release.Refinement.ModelHttp.store_admits,
      ``Benitoite.Release.Refinement.ModelHttp.pure_response,
      ``Benitoite.Release.Refinement.ModelHttp.delta_typed,
      ``Benitoite.Release.Refinement.ModelHttp.pure_outcome,
      ``Benitoite.Release.Refinement.ModelHttp.normal_facts,
      ``Benitoite.Release.Refinement.ModelHttp.send_response,
      ``Benitoite.Release.Refinement.ModelHttp.io_typed,
      ``Benitoite.Release.Refinement.ModelHttp.io_kind,
      ``Benitoite.Release.Refinement.ModelHttp.io_exists,
      ``Benitoite.Release.Refinement.ModelHttp.sent_request,
      ``Benitoite.Release.Refinement.ModelHttp.targetAgreement,
      ``Benitoite.Release.Refinement.ModelHttp.obs_allowed,
      ``Benitoite.Release.Refinement.ModelHttp.pathBases_no_io,
      ``Benitoite.Release.Refinement.ModelHttp.send_held,
      ``Benitoite.Release.Refinement.ModelHttp.send_without_request,
      ``Benitoite.Release.Refinement.ModelHttp.send_mismatch,
      ``Benitoite.Release.Refinement.ModelHttp.responseAssumptions,
      ``Benitoite.Release.Refinement.ModelHttp.scopeConditions,
      ``Benitoite.Release.Refinement.ScopeModels.conditions,
      ``Benitoite.Release.Refinement.Model.scopeConditions,
      ``Benitoite.Release.Refinement.ModelTargets.scopeConditions,
      ``Benitoite.Release.Refinement.ModelScopeConditions.core,
      ``Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_typed,
      ``Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_exists,
      ``Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_no_targets,
      ``Benitoite.Release.Refinement.Builtins.CoreAssumptions.release_exists] do
    let some ci := env.find? n | throwError "AUDIT_MISSING {n}"
    logInfo m!"SIGNATURE_BEGIN {n}"
    logInfo m!"{ci.type}"
    logInfo m!"SIGNATURE_END {n}"
  logInfo m!"AUDIT_COUNT {seen.size}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
