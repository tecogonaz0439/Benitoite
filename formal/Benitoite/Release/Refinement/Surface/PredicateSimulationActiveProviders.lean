import Benitoite.Release.Refinement.Surface.PredicateSimulationFixedProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationRowProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationLookup
import Benitoite.Release.Refinement.Surface.PredicateSimulationFixedEffects

/-! # 有効な構成元の実表から得る純粋応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 有効な構成元の署名は、固定した標準行又は有限の判定行から来る。 -/
theorem active_signature_cases {config : Check.BuiltinSource} {name signature}
    (active : CheckPreparation.enabled config = true)
    (found : config.builtins.sig name = some signature) :
    (∃ row : StandardModel.Primitive, name = row.name ∧ signature = row.signatureWith config.builtins.sat) ∨
    (∃ row : PredicateProjection.Row, signature = row.signature ∧ config.builtins.delta name = row.delta) := by
  induction config with
  | custom _ | unrestrictedRanges _ => cases active
  | standard P =>
    obtain ⟨row,_member,rfl,rfl⟩ := (StandardModel.builtins_lookup_iff P name signature).mp found
    exact Or.inl ⟨row,rfl,(StandardModel.Primitive.signatureWith_base row).symm⟩
  | predicates data entries =>
    change (if name ∈ StandardModel.nameLists.composed then
      (StandardModel.primitive name).map (StandardModel.Primitive.signatureWith data.sat)
      else if name ∈ (PredicateProjection.Table.names entries).assumed then
        (entries.lookup name).map PredicateProjection.Row.signature else none) = some signature at found
    split at found
    · obtain ⟨row,selected,rfl⟩ := Option.map_eq_some_iff.mp found
      exact Or.inl ⟨row,StandardModel.primitive_name selected,rfl⟩
    · rename_i absent
      split at found
      · obtain ⟨row,selected,rfl⟩ := Option.map_eq_some_iff.mp found
        refine Or.inr ⟨row,rfl,?_⟩
        funext ts es rs values
        change ((if name ∈ StandardModel.nameLists.composed then data.base.delta name else
          (PredicateProjection.Table.assumed entries).delta name) ts es rs values) = _
        rw [ite_eq_right absent]
        change ((entries.lookup name).bind fun entry => entry.delta ts es rs values) = _
        rw [selected]
        rfl
      · cases found
  | resolved base entries ih =>
    change (match entries.lookup name with
      | some row => some row.signature | none => base.builtins.sig name) = some signature at found
    cases selected : entries.lookup name with
    | none =>
      rw [selected] at found
      rcases ih (CheckPreparation.enabled_resolved_base active) found with standard | predicate
      · exact Or.inl standard
      · obtain ⟨row,rfl,delta⟩ := predicate
        refine Or.inr ⟨row,rfl,?_⟩
        funext ts es rs values
        change (match entries.lookup name with
          | some entry => entry.delta ts es rs values | none => base.builtins.delta name ts es rs values) = _
        rw [selected,delta]
    | some row =>
      rw [selected] at found
      cases Option.some.inj found
      refine Or.inr ⟨row,rfl,?_⟩
      funext ts es rs values
      change (match entries.lookup name with
        | some entry => entry.delta ts es rs values | none => base.builtins.delta name ts es rs values) = _
      rw [selected]

/-- 実入口で有効な表の純粋応答は、対応先だけの型付けから値の対応と元の禁止名不在を保つ。 -/
theorem active_pure_response {P Ψ source rows keys ts es rs xs ys a e name signature}
    {config : Check.BuiltinSource} (active : CheckPreparation.enabled config = true)
    [StandardModel.RowEnv P config.builtins] (core : config.builtins.CoreAssumptions P)
    (found : config.builtins.sig name = some signature) (pure : signature.kind = .pure)
    (typed : BuiltinArgs P config.builtins Ψ name signature ts es rs ys a e)
    (related : Values source rows xs ys) (avoid : ValuesAvoid keys xs) :
    OptionalOutcomeRel source rows (config.builtins.delta name ts es rs xs)
      (config.builtins.delta name ts es rs ys) ∧
      OptionalOutcomeAvoid keys (config.builtins.delta name ts es rs xs) := by
  rcases active_signature_cases active found with ⟨row,rfl,rfl⟩ | ⟨row,_signature,delta⟩
  · simpa only [StandardModel.RowEnv.keyDelta (P := P) row] using fixed_pure_response core row pure typed related avoid
  · simpa only [delta] using And.intro (row_delta related row ts es rs) (row_noMint (keys := keys) row ts es rs xs)

/-- 有効な表のIO応答は、対応する実引数で同じ結果と事象列を許す。 -/
theorem active_io_response {source rows xs ys config}
    (active : CheckPreparation.enabled config = true) (related : Values source rows xs ys)
    (name ts es out observations) :
    config.builtins.ioResponse name ts es xs out observations ↔
      config.builtins.ioResponse name ts es ys out observations := by
  induction config with
  | custom _ | unrestrictedRanges _ => cases active
  | standard P =>
    change (∃ row, StandardModel.primitive name = some row ∧ row.provider.ioResponse name ts es xs out observations) ↔
      (∃ row, StandardModel.primitive name = some row ∧ row.provider.ioResponse name ts es ys out observations)
    constructor <;> rintro ⟨row,selected,response⟩
    · exact ⟨row,selected,(fixed_io_response related row _ _ _ _ _).mp response⟩
    · exact ⟨row,selected,(fixed_io_response related row _ _ _ _ _).mpr response⟩
  | predicates data entries =>
    change ((if name ∈ StandardModel.nameLists.composed then data.base.ioResponse name else fun _ _ _ _ _ => False)
      ts es xs out observations) ↔
      ((if name ∈ StandardModel.nameLists.composed then data.base.ioResponse name else fun _ _ _ _ _ => False)
      ts es ys out observations)
    split
    · change (∃ row, StandardModel.primitive name = some row ∧ row.provider.ioResponse name ts es xs out observations) ↔
        (∃ row, StandardModel.primitive name = some row ∧ row.provider.ioResponse name ts es ys out observations)
      constructor <;> rintro ⟨row,selected,response⟩
      · exact ⟨row,selected,(fixed_io_response related row _ _ _ _ _).mp response⟩
      · exact ⟨row,selected,(fixed_io_response related row _ _ _ _ _).mpr response⟩
    · exact Iff.rfl
  | resolved base _ ih => exact ih (CheckPreparation.enabled_resolved_base active)

/-- 有効な表のIO応答は、内部の組込み名を作らない。 -/
theorem active_io_noMint {keys config name ts es values out observations}
    (active : CheckPreparation.enabled config = true)
    (response : config.builtins.ioResponse name ts es values out observations) : OutcomeAvoid keys out := by
  induction config with
  | custom _ | unrestrictedRanges _ => cases active
  | standard P =>
    obtain ⟨row,_selected,response⟩ := response
    exact fixed_io_noMint response
  | predicates data entries =>
    change ((if name ∈ StandardModel.nameLists.composed then data.base.ioResponse name else fun _ _ _ _ _ => False)
      ts es values out observations) at response
    split at response
    · obtain ⟨row,_selected,response⟩ := response
      exact fixed_io_noMint response
    · exact False.elim response
  | resolved base _ ih => exact ih (CheckPreparation.enabled_resolved_base active) response

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
