import Benitoite.Release.Refinement.MeasureNonnegative
import Benitoite.Release.Refinement.ObservationSubstitution

/-! # 正常な長さの観測と置換後の対応 -/
namespace Benitoite.Release.Refinement

theorem measure_machine_exact {m : Measure} {o : Observation} {n : Int}
    (h : Observation.measure m o = some (.integer n))
    (η : ObservationEnvModel) (t : Term) (ht : t.observe η = some o) :
    (Term.measure m t).observe η = some (.integer n) ∧
    (Term.measure m t).interpret η = some (.integer n) ∧ 0 ≤ n := by
  have hh : (Term.measure m t).observe η = some (.integer n) := by
    simp [Term.observe, ht, h]
  exact ⟨hh, Term.observe_sound hh, Observation.measure_nonnegative h⟩

theorem measure_stable {m : Measure} {t : Term} {n : Int}
    (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (h : (Term.measure m t).observe η = some (.integer n)) :
    (Term.measure m (termBind ν t)).observe ξ = some (.integer n) := by
  change (termBind ν (Term.measure m t)).observe ξ = some (.integer n)
  have hh := ((Term.measure m t).bind_observe_info ν η ξ hi).2
  rw [h] at hh
  have exact_integer {x : Option Observation}
      (hx : Observation.OptionInfoLE (some (.integer n)) x) : x = some (.integer n) := by
    cases hx with
    | some ho => cases ho; rfl
  exact exact_integer hh

end Benitoite.Release.Refinement
