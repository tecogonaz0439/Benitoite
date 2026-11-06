import Benitoite.Release.Refinement.Surface.PredicateSimulationIOProviders
import Benitoite.Release.Refinement.StandardModelGeneral

/-! # 固定台帳のIO応答の事象同一性 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 固定台帳の各providerは、対応する実引数で同じ結果とIO事象を許す。 -/
theorem fixed_io_response {source rows xs ys} (related : Values source rows xs ys)
    (row : StandardModel.Primitive) (name ts es out observations) :
    row.provider.ioResponse name ts es xs out observations ↔
      row.provider.ioResponse name ts es ys out observations := by
  cases row <;> first
    | exact model_targets_io_response related _ _ _ _ _
    | exact model_http_io_response related _ _ _ _ _
    | exact Iff.rfl

/-- 固定台帳のIO応答は、定数とbytesからなる有限結果を返し、禁止名を作らない。 -/
theorem fixed_io_noMint {keys row name ts es values out observations}
    (response : (row : StandardModel.Primitive).provider.ioResponse name ts es values out observations) :
    OutcomeAvoid keys out := by
  cases row <;> first
    | exact model_targets_io_noMint response
    | exact model_http_io_noMint response
    | exact False.elim response

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
