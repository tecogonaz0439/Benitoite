import Lean
import Benitoite.Scope.SwitchExamples
import Benitoite.Release.Lemmas.EffectSound
import Benitoite.Interval.RangeState

/-! L00.08b の一時ファイル: 採用定義と模型の全定理、移した定理の公理の依存を集める。 -/

open Lean Elab Command

#eval show CommandElabM Unit from do
  let env ← getEnv
  let ok : List Name := [``propext, ``Classical.choice, ``Quot.sound]
  let roots : List Name := [`Benitoite.Scope, `Benitoite.Interval.BindingScope]
  let mut total : Nat := 0
  let mut bad : Array (Name × Array Name) := #[]
  let mut perRoot : Std.HashMap String Nat := {}
  for (n, ci) in env.constants.toList do
    let inRoot := roots.any (·.isPrefixOf n) || n == ``Benitoite.Release.stateTyE_init_eff
    if inRoot && !n.isInternal then
      if let .thmInfo _ := ci then
        total := total + 1
        let key := (n.getPrefix.toString.splitOn ".").take 3 |> String.intercalate "."
        perRoot := perRoot.insert key ((perRoot.getD key (0 : Nat)) + 1)
        let axs ← liftCoreM <| Lean.collectAxioms n
        if axs.any (fun a => !ok.contains a) then bad := bad.push (n, axs)
  logInfo m!"theorems: {total}; with non-standard axioms: {bad.size}"
  for (k, c) in perRoot.toList.mergeSort (fun a b => a.1 ≤ b.1) do
    logInfo m!"{k}: {c}"
  for (n, axs) in bad do
    logInfo m!"BAD {n}: {axs}"

#print axioms Benitoite.Release.stateTyE_init_eff
#print axioms Benitoite.Interval.BindingScope.fresh_valid
#print axioms Benitoite.Scope.Domain.Range.memK_iff_mem
#print axioms Benitoite.Scope.Domain.Range.FitsKinds.getElem?
#print axioms Benitoite.Scope.Signature.ShapeTargets.single_memK
#print axioms Benitoite.Scope.Signature.RangeAdmissible.nil_iff
#print axioms Benitoite.Scope.Signature.Ix.inst_wf_zero
#print axioms Benitoite.Scope.Inference.apply_sound
#print axioms Benitoite.Scope.Inference.ScopeState.requiredIndex_fact
#print axioms Benitoite.Scope.TopCompat.TopEmbedding.old_norm_ext
#print axioms Benitoite.Scope.TopCompat.GEff.eq_of_sub_of_sub
#print axioms Benitoite.Scope.SignatureExamples.target_sound
#print axioms Benitoite.Scope.SignatureExamples.writeTextIn_not_endpoint
#print axioms Benitoite.Scope.InferenceExamples.minimal_checked
#print axioms Benitoite.Scope.SwitchExamples.oldTop_union_empty_Ix
#print axioms Benitoite.Scope.SwitchExamples.write_obs_of_shape
#print axioms Benitoite.Scope.SwitchExamples.check_then_write
#print axioms Benitoite.Scope.SwitchExamples.minimal_then_write
#print axioms Benitoite.Scope.SwitchExamples.log_clause_obs
#print axioms Benitoite.Scope.SwitchExamples.save_clause
#print axioms Benitoite.Scope.SwitchExamples.nonTopIx_not_lifted
