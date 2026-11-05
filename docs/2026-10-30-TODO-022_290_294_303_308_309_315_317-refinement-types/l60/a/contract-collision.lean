import Benitoite

namespace Benitoite.RefinementContractCollision
open Benitoite.Release.Refinement

/-- 通常の公開getterは自動getterを呼び、精密getterは直接matchする。 -/
theorem minimum_bodies_differ :
    StandardOrdinaryCoreBodies.Getter.minimum.publicBody ≠ StandardSafe.PreciseGetter.minimum.body := by
  intro equal
  cases equal

/-- 同じlookupが両方の元の実定義を返すという要求は成立しない。 -/
theorem minimum_lookup_incompatible (P : Program) (precise : Def)
    (row : StandardSafe.PreciseGetter.minimum.row.definition = some precise)
    (ordinary : P.defs "Range.minimum" = some StandardOrdinaryCoreBodies.Getter.minimum.publicDefinition)
    (refined : P.defs "Range.minimum" = some precise) : False := by
  have equal := Option.some.inj (ordinary.symm.trans refined)
  have bodies := congrArg (fun d : Def => d.body) equal
  have precise_body : precise.body = StandardSafe.PreciseGetter.minimum.body := by
    cases row
    rfl
  exact minimum_bodies_differ (bodies.trans precise_body)

/-- 通常の入力は裸のdata、精密な子行の入力は篩付きdataである。 -/
theorem minimum_inputs_differ :
    StandardOrdinaryCoreBodies.Getter.minimum.publicDefinition.params ≠
      StandardSafe.PreciseGetter.minimum.row.tel.inputs := by
  intro equal
  cases equal

/-- 元の通常側と精密側の型付けの証拠を、双方そのまま保持する。 -/
example :
    StandardOrdinaryCoreBodies.Getter.minimum.publicDefinition.WellTyped
      StandardOrdinaryCoreProgram.program StandardOrdinaryCoreProgram.builtins ∧
    StandardSafe.PreciseGetter.minimum.row.BodyTyped StandardSafe.safeProgram StandardSafe.builtins :=
  ⟨(StandardOrdinaryCoreProgram.declarations_typed (.projection .minimum)).2,
    StandardSafe.precise_row_typed .minimum⟩

#print axioms minimum_bodies_differ
#print axioms minimum_lookup_incompatible
#print axioms minimum_inputs_differ
end Benitoite.RefinementContractCollision
