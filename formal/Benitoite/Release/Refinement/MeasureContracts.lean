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

/-- 各 measure の正常結果を、実際に読んだ大きさへ同定する。
機械整数の上限はこの結論には含めない。 -/
theorem Observation.measure_exact :
    (∀ s : String, Observation.measure .stringBytes (.string s) =
      some (.integer s.utf8ByteSize)) ∧
    (∀ s : String, Observation.measure .stringCharacters (.string s) =
      some (.integer s.toList.length)) ∧
    (∀ xs, Observation.measure .listLength (.listValue xs) =
      some (.integer xs.length)) ∧
    (∀ xs : List Nat, xs.all (· ≤ 255) = true →
      Observation.measure .bytesLength (.bytesValue xs) = some (.integer xs.length)) ∧
    (∀ ks vs entries, mapKeys ks vs = some entries →
      Observation.measure .mapSize (.mapValue ks vs) = some (.integer entries.length)) ∧
    (∀ xs codes, keySetCodes xs [] = some codes →
      Observation.measure .setSize (.setValue xs) = some (.integer codes.length)) ∧
    (∀ c : Char, Observation.measure .characterCode (.character c) =
      some (.integer c.toNat)) := by
  refine ⟨fun _ => rfl, fun _ => rfl, fun _ => rfl, ?_, ?_, ?_, fun _ => rfl⟩
  · intro xs h; simp [Observation.measure, h]
  · intro ks vs entries h; simp [Observation.measure, h]
  · intro xs codes h; simp [Observation.measure, h]

/-- 観測のないスロットも List の要素数には数える。 -/
theorem observeSlots_length (η : ObservationEnvModel) (xs : List (Option Term)) :
    (observeSlots η xs).length = xs.length := by
  induction xs with
  | nil => rfl
  | cons x xs ih => cases x <;> simp [observeSlots, ih]

/-- 不変欄の正常観測と整数の measure 結果を、それぞれ置換像で読む。 -/
theorem field_measure_stable {r : FieldRef} {t : Term} {o : Observation}
    {m : Measure} {n : Int} (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (field : (Term.field r t).observe η = some o)
    (normal : Observation.measure m o = some (.integer n)) :
    Observation.OptionInfoLE (some o) ((Term.field r (termBind ν t)).observe ξ) ∧
      (Term.measure m (Term.field r (termBind ν t))).observe ξ = some (.integer n) := by
  constructor
  · have h := ((Term.field r t).bind_observe_info ν η ξ hi).2
    simpa only [field, termBind_field] using h
  · exact measure_stable ν η ξ hi (measure_machine_exact normal η (.field r t) field).1

end Benitoite.Release.Refinement
