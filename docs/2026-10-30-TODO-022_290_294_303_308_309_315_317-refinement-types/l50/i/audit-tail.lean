
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
  for n in [``Benitoite.Release.Refinement.ModelTargets.entries,
      ``Benitoite.Release.Refinement.ModelTargets.effects,
      ``Benitoite.Release.Refinement.ModelTargets.readObs,
      ``Benitoite.Release.Refinement.ModelTargets.exitCode,
      ``Benitoite.Release.Refinement.ModelTargets.ioResponse,
      ``Benitoite.Release.Refinement.ModelTargets.builtins,
      ``Benitoite.Release.Refinement.ModelTargets.sig_cases,
      ``Benitoite.Release.Refinement.ModelTargets.substitutionAssumptions,
      ``Benitoite.Release.Refinement.ModelTargets.sig_scoped,
      ``Benitoite.Release.Refinement.ModelTargets.sourceTelRows,
      ``Benitoite.Release.Refinement.ModelTargets.sat_unconstrained,
      ``Benitoite.Release.Refinement.ModelTargets.admits_sat,
      ``Benitoite.Release.Refinement.ModelTargets.pathBases_shape,
      ``Benitoite.Release.Refinement.ModelTargets.io_op,
      ``Benitoite.Release.Refinement.ModelTargets.opEff_io,
      ``Benitoite.Release.Refinement.ModelTargets.effect_ops,
      ``Benitoite.Release.Refinement.ModelTargets.state_effect,
      ``Benitoite.Release.Refinement.ModelTargets.ref_get,
      ``Benitoite.Release.Refinement.ModelTargets.ref_set,
      ``Benitoite.Release.Refinement.ModelTargets.store_shape,
      ``Benitoite.Release.Refinement.ModelTargets.store_admits,
      ``Benitoite.Release.Refinement.ModelTargets.pure_response,
      ``Benitoite.Release.Refinement.ModelTargets.delta_typed,
      ``Benitoite.Release.Refinement.ModelTargets.pure_outcome,
      ``Benitoite.Release.Refinement.ModelTargets.normal_facts,
      ``Benitoite.Release.Refinement.ModelTargets.io_typed,
      ``Benitoite.Release.Refinement.ModelTargets.io_kind,
      ``Benitoite.Release.Refinement.ModelTargets.io_exists,
      ``Benitoite.Release.Refinement.ModelTargets.responseAssumptions,
      ``Benitoite.Release.Refinement.ModelTargets.targetAgreement,
      ``Benitoite.Release.Refinement.ModelTargets.obs_allowed,
      ``Benitoite.Release.Refinement.ModelTargets.scopeConditions] do
    let some ci := env.find? n | throwError "AUDIT_MISSING {n}"
    logInfo m!"SIGNATURE_BEGIN {n}"
    logInfo m!"{ci.type}"
    logInfo m!"SIGNATURE_END {n}"
  logInfo m!"AUDIT_COUNT {seen.size}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
