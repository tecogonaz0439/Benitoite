import Benitoite.Release.Refinement.CarrierFacts
import Benitoite.Release.Refinement.RefinementObservation
import Benitoite.Release.Refinement.NumericRepresented

/-! # 型付き定数から型域の事実を供給する入口 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem Const.NumericRepresented.carrierFacts {c : Const} (h : c.NumericRepresented) (η : ObservationEnvModel) :
    ∀ p ∈ c.type.carrierFacts, p.interpret (selfModel η (.const c)) = true := by
  cases c <;> simp_all [Const.type, Ty.carrierFacts, Ty.core, integerBounds,
    Pred.interpret, Pred.atomValue, integerAs, observeAs,
    selfModel, selfObservation, Val.toTerm?, Term.observe,
    Term.interpret, Observation.sort, Observation.default, Const.NumericRepresented]
  case integer n => exact n.property
  case byte n => omega
  case decimal n s =>
    have hl := h.1
    have hu := h.2.1
    omega

end
end Benitoite.Release.Refinement
