
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
  for n in [``Benitoite.Release.Refinement.Model.entries,
      ``Benitoite.Release.Refinement.Model.builtins,
      ``Benitoite.Release.Refinement.Model.sig_cases,
      ``Benitoite.Release.Refinement.Model.substitutionAssumptions,
      ``Benitoite.Release.Refinement.Model.sig_scoped,
      ``Benitoite.Release.Refinement.Model.sat_unconstrained,
      ``Benitoite.Release.Refinement.Model.admits_sat,
      ``Benitoite.Release.Refinement.Model.pathBases_shape,
      ``Benitoite.Release.Refinement.Model.io_op,
      ``Benitoite.Release.Refinement.Model.opEff_io,
      ``Benitoite.Release.Refinement.Model.effect_ops,
      ``Benitoite.Release.Refinement.Model.state_effect,
      ``Benitoite.Release.Refinement.Model.ref_get,
      ``Benitoite.Release.Refinement.Model.ref_set,
      ``Benitoite.Release.Refinement.Model.store_shape,
      ``Benitoite.Release.Refinement.Model.store_admits,
      ``Benitoite.Release.Refinement.Model.delta_typed,
      ``Benitoite.Release.Refinement.Model.io_typed,
      ``Benitoite.Release.Refinement.Model.io_kind,
      ``Benitoite.Release.Refinement.Model.io_exists,
      ``Benitoite.Release.Refinement.Model.responseAssumptions,
      ``Benitoite.Release.Refinement.Model.targetAgreement,
      ``Benitoite.Release.Refinement.Model.scopeConditions,
      ``Benitoite.Release.Refinement.AtPrepared.of_path_bases,
      ``Benitoite.Release.Refinement.ModelTargetsExamples.call_arguments,
      ``Benitoite.Release.Refinement.ModelTargetsExamples.call_typed,
      ``Benitoite.Release.Refinement.ModelTargetsExamples.issue,
      ``Benitoite.Release.Refinement.ModelTargetsExamples.issue_to_at,
      ``Benitoite.Release.Refinement.ModelTargetsExamples.issued_current,
      ``Benitoite.Release.Refinement.ModelTargetsExamples.required_base,
      ``Benitoite.Release.Refinement.ModelTargetsExamples.issued_at] do
    let some ci := env.find? n | throwError "AUDIT_MISSING {n}"
    logInfo m!"SIGNATURE_BEGIN {n}"
    logInfo m!"{ci.type}"
    logInfo m!"SIGNATURE_END {n}"
  logInfo m!"AUDIT_COUNT {seen.size}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
