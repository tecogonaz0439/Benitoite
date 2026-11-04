
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
  for n in [``Benitoite.Release.Refinement.parseAtInput_path_text,
      ``Benitoite.Release.Refinement.ScopeDelta.pathValueRun_parseAtInput,
      ``Benitoite.Release.Refinement.ScopeDelta.path_target,
      ``Benitoite.Release.Refinement.ScopeDelta.pathValueRun,
      ``Benitoite.Release.Refinement.ScopeDelta.widenRun,
      ``Benitoite.Release.Refinement.ScopeDelta.valueDelta,
      ``Benitoite.Release.Refinement.ScopeDelta.pathInValue_response,
      ``Benitoite.Release.Refinement.ScopeDelta.widenPathIn_response,
      ``Benitoite.Release.Refinement.RequestDelta.retained_request,
      ``Benitoite.Release.Refinement.RequestDelta.valueDelta,
      ``Benitoite.Release.Refinement.RequestDelta.requestInValue_response,
      ``Benitoite.Release.Refinement.RequestDelta.widenRequestIn_response,
      ``Benitoite.Release.Refinement.ScopeResponse.delta,
      ``Benitoite.Release.Refinement.ScopeResponse.response,
      ``Benitoite.Release.Refinement.ScopeResponse.delta_typed,
      ``Benitoite.Release.Refinement.ScopeResponse.outcome_typed,
      ``Benitoite.Release.Refinement.ScopeResponse.ground,
      ``Benitoite.Release.Refinement.ScopeResponse.normal_facts,
      ``Benitoite.Release.Refinement.ScopeResponse.adequate_externalRef,
      ``Benitoite.Release.Refinement.ScopeResponse.adequate_externalHandle,
      ``Benitoite.Release.Refinement.ScopeResponse.adequate_scopePattern,
      ``Benitoite.Release.Refinement.ScopeResponse.leaves_unobserved,
      ``Benitoite.Release.Refinement.ModelConstraints.sat_rename,
      ``Benitoite.Release.Refinement.ModelConstraints.sat_values,
      ``Benitoite.Release.Refinement.ModelConstraints.admits_rename,
      ``Benitoite.Release.Refinement.ModelConstraints.admits_values,
      ``Benitoite.Release.Refinement.ModelConstraints.sat_renameTypes,
      ``Benitoite.Release.Refinement.ModelConstraints.admits_renameTypes,
      ``Benitoite.Release.Refinement.ModelConstraints.sat_subst,
      ``Benitoite.Release.Refinement.ModelConstraints.admits_subst,
      ``Benitoite.Release.Refinement.ModelConstraints.sat_unconstrained,
      ``Benitoite.Release.Refinement.ScopeSignatures.substitutionAssumptions,
      ``Benitoite.Release.Refinement.ScopeSignatures.admits_sat,
      ``Benitoite.Release.Refinement.ScopeSignatures.sat_unconstrained,
      ``Benitoite.Release.Refinement.Eff.allows_bind_comp] do
    let some ci := env.find? n | throwError "AUDIT_MISSING {n}"
    logInfo m!"SIGNATURE_BEGIN {n}"
    logInfo m!"{ci.type}"
    logInfo m!"SIGNATURE_END {n}"
  logInfo m!"AUDIT_COUNT {seen.size}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
