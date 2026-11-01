import Benitoite
open Benitoite
namespace RVL10
open Benitoite.Interval
def possible : Shared.ValueApprox → Bool
  | .bottom => false
  | .integer _ .bottom => false
  | .integer _ (.closed _ _ _) => true
  | .boolean f t => f || t
  | .unknown => true
theorem possible_bool (f t : Bool) : possible (.boolean f t) = true ↔ ∃ v, (Shared.ValueApprox.boolean f t).Mem v := by
  cases f <;> cases t
  case false.false =>
    simp only [possible, Bool.or_false, Bool.false_eq_true, false_iff]
    rintro ⟨v, hv⟩
    cases v with
    | boolean b => cases b <;> simp [Shared.ValueApprox.Mem] at hv
    | integer k n => exact hv
    | other => exact hv
  case false.true => exact ⟨fun _ => ⟨.boolean true, rfl⟩, fun _ => rfl⟩
  case true.false => exact ⟨fun _ => ⟨.boolean false, rfl⟩, fun _ => rfl⟩
  case true.true => exact ⟨fun _ => ⟨.boolean true, rfl⟩, fun _ => rfl⟩
theorem normalToShared_iff {type : Benitoite.Release.Ty}
    {range : NormalRange type} {value : ConcreteValue} (typed : value.type = type) :
    (normalToShared type range).Mem value.toApprox ↔ NormalMem type range value := by
  refine ⟨?_, normalToShared_mem⟩
  subst typed
  intro h
  refine ⟨rfl, ?_⟩
  cases value <;> simp_all [NormalContains, normalToShared, ConcreteValue.type, ConcreteValue.toApprox, Shared.ValueApprox.Mem, NormalRange, IntegerValue.toInt, Release.Integer64Value.toInt]
  all_goals (cases h; try trivial)
end RVL10
#print axioms RVL10.possible_bool
