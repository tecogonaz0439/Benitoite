
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
  for n in [``Benitoite.Release.Refinement.ScopedTargetExamples.one,``Benitoite.Release.Refinement.ScopedTargetExamples.single_io,``Benitoite.Release.Refinement.ScopedTargetExamples.request_io,``Benitoite.Release.Refinement.ScopedTargetExamples.selected_io,``Benitoite.Release.Refinement.ScopedTargetExamples.selected_request,``Benitoite.Release.Refinement.ScopedTargetExamples.widened_input,``Benitoite.Release.Refinement.ScopedTargetExamples.incomparable,``Benitoite.Release.Refinement.ScopedTargetExamples.equal_resolution_distinct_base,``Benitoite.Release.Refinement.ScopedTargetExamples.no_collective_cover,``Benitoite.Release.Refinement.ScopedTargetExamples.split_endpoint,``Benitoite.Release.Refinement.ScopedTargetExamples.secrets_members,``Benitoite.Release.Refinement.ScopedTargetExamples.absolute_projection,``Benitoite.Release.Refinement.AtErrorReaders.observed,``Benitoite.Release.Refinement.AtErrorReaders.prepare_reader,``Benitoite.Release.Refinement.AtErrorReaders.check_reader,``Benitoite.Release.Refinement.ScopedTargetInputs.response_inputs,``Benitoite.Release.Refinement.ScopedTargetInputs.destination,``Benitoite.Release.Refinement.ScopedTargetInputs.pure_steps,``Benitoite.Release.Refinement.ScopedTargetInputs.io_steps,``Benitoite.Release.Refinement.ScopedTargetInputs.handled_step,``Benitoite.Release.Refinement.ScopedTargetInputs.at_prepare,``Benitoite.Release.Refinement.ScopedTargetInputs.at_error,``Benitoite.Release.Refinement.ScopedTargetInputs.at_ok,``Benitoite.Release.Refinement.ScopedTargetInputs.at_steps,``Benitoite.Release.Refinement.ScopedTargetInputs.path_bases_apply,``Benitoite.Release.Refinement.ScopedTargetInputs.issue,``Benitoite.Release.Refinement.StateTyE.inputs,``Benitoite.Release.Refinement.StateTyE.primitive_contract_inputs,``Benitoite.Release.Refinement.BuiltinArgs.normalized,``Benitoite.Release.Refinement.AtError.save_exact,``Benitoite.Release.Refinement.AtPrepare.error_saved,``Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_typed,``Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_exists,``Benitoite.Release.Refinement.Builtins.ExternalAssumptions.external_no_targets,``Benitoite.Release.Refinement.Builtins.CoreAssumptions.release_exists,``Benitoite.Release.Refinement.ModelScopeConditions.core] do
    let some ci := env.find? n | throwError "AUDIT_MISSING {n}"
    logInfo m!"SIGNATURE_BEGIN {n}"
    logInfo m!"{ci.type}"
    logInfo m!"SIGNATURE_END {n}"
  logInfo m!"AUDIT_COUNT {seen.size}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
