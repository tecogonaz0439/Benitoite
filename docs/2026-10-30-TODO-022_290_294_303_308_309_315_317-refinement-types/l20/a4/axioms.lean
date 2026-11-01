import Lean
import Benitoite

open Benitoite.Release.Refinement

#check @MeaningTransport.MOrder
#check @MeaningTransport.Outer
#check @MeaningTransport.Below
#check @MeaningTransport.field_order
#check @MeaningTransport.order_data
#check @MeaningTransport.order_trans
#check @MeaningTransport.order_refine
#check @MeaningTransport.valueMeaning_field_mono
#check (valueMeaning_sub : ∀ {P : Program} {Γ : Ctx} {Φ : List Pred}
    {a b : Ty} {v : Val} {η : ObservationEnvModel},
    P.VarianceValid → Ty.LeQ P Γ Φ a b →
    (∀ p ∈ Γ.facts ++ Φ, p.interpret η = true) →
    ValueMeaning P η a v → ValueMeaning P η b v)

-- Ordinary の供給の反例に、前提を足さず完成した S07 を適用する。
theorem a4_nonordinary_transport (η : ObservationEnvModel) :
    ValueMeaning MeaningTransportObstruction.boxProgram η
      (.data "MeaningBox" [MeaningTransportObstruction.continuation])
      (.con "MeaningBox.mk" [] [.const .unit]) :=
  valueMeaning_sub MeaningTransportObstruction.box_variance
    MeaningTransportObstruction.data_sub (by simp [Ctx.facts])
    (MeaningTransportObstruction.source_meaning η)

#print axioms a4_nonordinary_transport

-- formal/ から lake env lean -M 12288 で実行する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for mod in [
    `Benitoite.Release.Refinement.MeaningOrder,
    `Benitoite.Release.Refinement.MeaningTransport,
    `Benitoite.Release.Refinement.MeaningTransportObstruction
  ] do
    let some idx := env.getModuleIdx? mod | throwError "AUDIT_UNAVAILABLE {mod}"
    let names := (env.constants.toList.filterMap fun (name, _) =>
      if env.getModuleIdxFor? name == some idx then some name else none).mergeSort
        (fun a b => a.toString < b.toString)
    unless names.length > 0 do throwError "AUDIT_EMPTY {mod}"
    logInfo m!"AUDIT_MODULE {mod} {names.length}"
    for name in names do elabCommand (← `(#print axioms $(mkIdent name)))

#print axioms Benitoite.Release.Refinement.ValueMeaning
#print axioms Benitoite.Release.Refinement.Program.VarianceValid
#print axioms Benitoite.Release.Refinement.variance_field_mono
#print axioms Benitoite.Release.Refinement.valueMeaning_refine
#print axioms Benitoite.Release.Refinement.valueMeaning_inhabits_normal
#print axioms Benitoite.Release.Refinement.valueMeaning_sub
#print axioms Benitoite.Release.Refinement.HasTypeVQ.shift_values
#print axioms Benitoite.Release.Refinement.HasTypeCQ.shift_values
#print axioms Benitoite.Release.Refinement.HasTypeVQ.shift_types
#print axioms Benitoite.Release.Refinement.HasTypeCQ.shift_types
#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst_under_none
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst_under_none
#print axioms Benitoite.Release.Refinement.HasTypeVQ.narrow
#print axioms Benitoite.Release.Refinement.HasTypeCQ.narrow
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
