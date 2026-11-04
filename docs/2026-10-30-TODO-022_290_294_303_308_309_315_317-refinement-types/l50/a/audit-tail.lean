
-- 追加モジュールの全宣言とローカルの生成宣言を固定点まで列挙する。
set_option maxHeartbeats 20000000
open Lean Elab Command in
run_cmd do
  let requested : List String := ["Benitoite.Release.Refinement.ScopeCoverage",
    "Benitoite.Release.Refinement.MembershipTargets", "Benitoite.Release.Refinement.ShapeTargets",
    "Benitoite.Release.Refinement.EffectTargets", "Benitoite.Release.Refinement.ModelConstraints",
    "Benitoite.Release.Refinement.ScopeDeclarations", "Benitoite.Release.Refinement.TargetModelConditions"]
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
  for n in [``Benitoite.Release.Refinement.PathPattern.covers_atBase,
      ``Benitoite.Release.Refinement.RangeExpr.Covers.mem,
      ``Benitoite.Release.Refinement.SnapshotMem.mono,
      ``Benitoite.Release.Refinement.HasTypeVQ.target_member,
      ``Benitoite.Release.Refinement.PrimSig.Scoped.namesWF,
      ``Benitoite.Release.Refinement.Builtins.ShapeOk.single_target,
      ``Benitoite.Release.Refinement.Builtins.TargetAgreement.obs_allowed,
      ``Benitoite.Release.Refinement.ModelConstraints.sat_bind_values,
      ``Benitoite.Release.Refinement.ModelConstraints.admits_bind_values,
      ``Benitoite.Release.Refinement.ScopeDeclarations.HasHttp.file,
      ``Benitoite.Release.Refinement.ModelScopeConditions.core] do
    let some ci := env.find? n | throwError "AUDIT_MISSING {n}"
    logInfo m!"SIGNATURE_BEGIN {n}"
    logInfo m!"{ci.type}"
    logInfo m!"SIGNATURE_END {n}"
  for n in [``L50Contracts.F01Path, ``L50Contracts.F01Range, ``L50Contracts.F01Snapshot,
      ``L50Contracts.F02, ``L50Contracts.F03, ``L50Contracts.F04, ``L50Contracts.F05,
      ``L50Contracts.F06Current, ``L50Contracts.F06Resolve,
      ``L50Contracts.F07Pure, ``L50Contracts.F07IO, ``L50Contracts.F07Ground,
      ``L50Contracts.F07ExternalRef, ``L50Contracts.F07ExternalHandle,
      ``L50Contracts.F07ScopePattern, ``L50Contracts.F07AtError,
      ``L50Contracts.F08, ``L50Contracts.F09Model, ``L50Contracts.F09File, ``L50Contracts.F09Http,
      ``L50InternalSave.Detail, ``L50InternalSave.save, ``L50InternalSave.save_exact,
      ``Benitoite.Release.Refinement.ModelScopeConditions] do
    logInfo m!"CONTRACT_BEGIN {n}"
    elabCommand (← `(#print $(mkIdent n)))
    logInfo m!"CONTRACT_END {n}"
  logInfo m!"AUDIT_COUNT {seen.size}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
