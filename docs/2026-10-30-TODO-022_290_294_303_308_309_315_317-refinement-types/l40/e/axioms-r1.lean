import Lean
import Benitoite
-- LOCAL_INPUTS
set_option maxHeartbeats 20000000

-- 既定の新旧全モジュールを保持し、private・生成宣言も所属モジュールから列挙する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let constants := env.constants.toList
  let mut targets : List Name := []
  for mod in env.header.moduleNames do
    if mod.toString.startsWith "Benitoite" then
      let some idx := env.getModuleIdx? mod | throwError "AUDIT_MODULE_MISSING {mod}"
      let names := constants.filterMap fun (name, _) =>
        if env.getModuleIdxFor? name == some idx then some name else none
      logInfo m!"AUDIT_MODULE {mod} {names.length}"
      if [-- NEW_MODULES
      ].contains mod.toString then
        for name in names do logInfo m!"AUDIT_NEW_DECL {mod} {name}"
      targets := names ++ targets
  let locals := constants.filterMap fun (name, _) =>
    if (env.getModuleIdxFor? name).isNone &&
        (name.toString.splitOn "Benitoite.Release.Refinement.").length > 1
    then some name else none
  logInfo m!"AUDIT_MODULE local_records {locals.length}"
  targets := locals ++ targets
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
    ``Benitoite.Release.Refinement.HasTypeCQ.narrow]
  for name in required do
    unless targets.contains name do throwError "AUDIT_REQUIRED_MISSING {name}"
  let ordered := targets.mergeSort (fun a b => a.toString < b.toString)
  let mut seen : Std.HashSet Name := {}
  let inventoryOnly := (← IO.getEnv "L40_INVENTORY_ONLY") == some "1"
  for name in ordered do
    if seen.contains name then throwError "AUDIT_DUPLICATE {name}"
    seen := seen.insert name
    let some ci := env.find? name | throwError "AUDIT_MISSING {name}"
    if let .axiomInfo _ := ci then throwError "AUDIT_AXIOM {name}"
    logInfo m!"AUDIT_TARGET {name}"
    unless inventoryOnly do elabCommand (← `(#print axioms $(mkIdent name)))
  if let some output ← IO.getEnv "L40_AUDIT_TARGETS" then
    IO.FS.writeFile output (String.intercalate "\n" (ordered.map Name.toString) ++ "\n")
