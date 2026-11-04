import Lean
import Benitoite
set_option maxHeartbeats 20000000

-- 輸入済みの本番の全宣言を列挙し、印字時の実体化も最新の環境から追う。
open Lean Elab Command in
run_cmd do
  let requested : List String := [-- NEW_MODULES
  ]
  let mut seen : Std.HashSet Name := {}
  let mut ordered : List Name := []
  let mut rounds : Nat := 0
  repeat
    rounds := rounds + 1
    let env ← getEnv
    let pending := env.constants.toList.filterMap fun (name, _) =>
      let owned := match env.getModuleIdxFor? name with
        | some idx => env.header.moduleNames[idx.toNat]!.toString.startsWith "Benitoite"
        | none => (name.toString.splitOn "Benitoite.Release.Refinement.").length > 1
      if owned && !seen.contains name then some name else none
    if pending.isEmpty then break
    if rounds > 20 then throwError "AUDIT_FIXED_POINT_LIMIT"
    for name in pending.mergeSort (fun a b => a.toString < b.toString) do
      let env ← getEnv
      let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
      if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
      seen := seen.insert name
      ordered := name :: ordered
      logInfo m!"AUDIT_TARGET {name}"
      elabCommand (← `(#print axioms $(mkIdent name)))
  let env ← getEnv
  let targets := ordered.reverse
  let required := [``Benitoite.Release.Refinement.StandardScalar.integerDelta_floor,
    ``Benitoite.Release.Refinement.StandardScalar.integerDelta_absolute,
    ``Benitoite.Release.Refinement.StandardScalar.integerDelta_minMax,
    ``Benitoite.Release.Refinement.StandardScalar.integerDelta_bitwise,
    ``Benitoite.Release.Refinement.StandardScalar.integerDelta_bitwiseNot,
    ``Benitoite.Release.Refinement.StandardScalar.integerDelta_shift,
    ``Benitoite.Release.Refinement.StandardScalar.integerDelta_negate,
    ``Benitoite.Release.Refinement.StandardScalar.scalarOption_typed,
    ``Benitoite.Release.Refinement.StandardScalar.integerDelta_fromInteger_typed,
    ``Benitoite.Release.Refinement.StandardScalar.byte_compare,
    ``Benitoite.Release.Refinement.StandardScalar.byte_fromInteger_typed,
    ``Benitoite.Release.Refinement.StandardScalar.character_fromInteger_typed,
    ``Benitoite.Release.Refinement.StandardScalar.decimalFromFloat_typed,
    ``Benitoite.Release.Refinement.StandardScalar.decimalTruncate_typed,
    ``Benitoite.Release.Refinement.StandardScalar.decimalToUnsigned64_typed,
    ``Benitoite.Release.Refinement.StandardScalar.integerDelta_binary_facts,
    ``Benitoite.Release.Refinement.StandardScalar.byteConvert_some,
    ``Benitoite.Release.Refinement.StandardScalar.characterConvert_some,
    ``Benitoite.Release.Refinement.StandardScalar.float32_compare_reply,
    ``Benitoite.Release.Refinement.StandardScalar.float64_compare_reply,
    ``Benitoite.Release.Refinement.StandardScalar.decimalRound_represented,
    ``Benitoite.Release.Refinement.StandardFactExamples.length_le,
    ``Benitoite.Release.Refinement.StandardFactExamples.false_fact_typing,
    ``Benitoite.Release.Refinement.StandardFactExamples.guard_body_typing,
    ``Benitoite.Release.Refinement.StateTyE.lambda_beta_all,
    ``Benitoite.Release.Refinement.StateTyE.lambda_inputs,
    ``Benitoite.Release.Refinement.StateTyE.inputs,
    ``Benitoite.Release.Refinement.step_lambda,
    ``Benitoite.Release.Refinement.HasTypeCQ.inputs,
    ``Benitoite.Release.Refinement.LambdaApplicationExamples.captured_and_direct,
    ``Benitoite.Release.Refinement.LambdaApplicationExamples.two_steps,
    ``Benitoite.Release.Refinement.LambdaApplicationExamples.delta_return_path,
    ``Benitoite.Release.Refinement.HasTypeCQ.inv_match,
``Benitoite.Release.progress, ``Benitoite.Release.preservation,
    ``Benitoite.Release.step_sound, ``Benitoite.Release.effect_soundness,
    ``Benitoite.Release.effect_soundness_noLamNames, ``Benitoite.Release.Model.assumptions,
    ``Benitoite.Release.ModelTargets.assumptions, ``Benitoite.Release.ModelHttp.assumptions,
    ``Benitoite.Release.Refinement.HasTypeVQ.subst,
    ``Benitoite.Release.Refinement.HasTypeVQ.subst_under_none,
    ``Benitoite.Release.Refinement.HasTypeVQ.shift_values,
    ``Benitoite.Release.Refinement.HasTypeVQ.shift_types,
    ``Benitoite.Release.Refinement.HasTypeVQ.narrow,
    ``Benitoite.Release.Refinement.HasTypeCQ.subst,
    ``Benitoite.Release.Refinement.HasTypeCQ.subst_under_none,
    ``Benitoite.Release.Refinement.HasTypeCQ.shift_values,
    ``Benitoite.Release.Refinement.HasTypeCQ.shift_types,
    ``Benitoite.Release.Refinement.HasTypeCQ.narrow,
    ``Benitoite.Release.Refinement.CaptureOk.field_facts,
    ``Benitoite.Release.Refinement.MatchFacts.field_equality_true,
    ``Benitoite.Release.Refinement.StateTyE.match_body,
    ``Benitoite.Release.Refinement.StateTyE.match_guard,
    ``Benitoite.Release.Refinement.StandardSafe.precise_rows_typed,
    ``Benitoite.Release.Refinement.StandardHeadTail.concrete_nonempty_public_typed,
    ``Benitoite.Release.Refinement.StandardCollectionRefinedBodies.seven_public_rows,
    ``Benitoite.Release.Refinement.StandardCollectionRefinedBodies.program_typed,
    ``Benitoite.Release.Refinement.StandardCollectionRefinedBodies.response_assumptions,
    ``Benitoite.Release.Refinement.StandardMapReplaceValues.response,
    ``Benitoite.Release.Refinement.StandardMapReplaceValues.delta_aligned]
  for name in required do
    unless seen.contains name do throwError "AUDIT_REQUIRED_MISSING {name}"
  for mod in env.header.moduleNames do
    if mod.toString.startsWith "Benitoite" then
      let some idx := env.getModuleIdx? mod | throwError "AUDIT_MODULE_MISSING {mod}"
      let names := targets.filter fun name => env.getModuleIdxFor? name == some idx
      logInfo m!"AUDIT_MODULE {mod} {names.length}"
      if requested.contains mod.toString then
        for name in names do logInfo m!"AUDIT_NEW_DECL {mod} {name}"
  let locals := targets.filter fun name => (env.getModuleIdxFor? name).isNone
  logInfo m!"AUDIT_MODULE local_records {locals.length}"
  logInfo m!"AUDIT_ROUNDS {rounds}"
  if let some output ← IO.getEnv "L40_AUDIT_TARGETS" then
    IO.FS.writeFile output (String.intercalate "\n" (targets.map Name.toString) ++ "\n")
