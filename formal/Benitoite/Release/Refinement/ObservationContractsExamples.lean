import Benitoite.Release.Refinement.NumericContracts
import Benitoite.Release.Refinement.KeyContracts
import Benitoite.Release.Refinement.BuiltinLogicExamples
import Benitoite.Release.Refinement.LegacyPatternExamples

/-! # 正常観測、幅付き算術、欠けた鍵の対照 -/
namespace Benitoite.Release.Refinement.ObservationContractsExamples
open Benitoite.Interval NumericContracts

private def measures : List (Measure × Observation × Int) :=
  [(.stringBytes, .string "é", 2), (.stringCharacters, .string "é", 1),
   (.listLength, .listValue [none], 1), (.bytesLength, .bytesValue [0,255], 2),
   (.mapSize, .mapValue [some (.decimal 1 0),some (.decimal 10 1)] [none,none], 1),
   (.setSize, .setValue [some (.integer 3),some (.integer 3)], 1),
   (.characterCode, .character 'A', 65)]

private theorem measure_observations : ∀ row ∈ measures,
    Observation.measure row.1 row.2.1 = some (.integer row.2.2)  := by
  intro row hr
  simp only [measures, List.mem_cons, List.not_mem_nil, or_false] at hr
  rcases hr with rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals cbv

theorem measures_machine_exact (η : ObservationEnvModel) (t : Term) :
    ∀ row ∈ measures, t.observe η = some row.2.1 →
      (Term.measure row.1 t).observe η = some (.integer row.2.2) ∧
      (Term.measure row.1 t).interpret η = some (.integer row.2.2) ∧ 0 ≤ row.2.2 := by
  intro row hr ht
  exact measure_machine_exact (measure_observations row hr) η t ht

example : Observation.measure .bytesLength (.bytesValue [256]) = none ∧
    Observation.measure .mapSize (.mapValue [none] [none]) = none ∧
    Observation.measure .setSize (.setValue [none]) = none := by cbv

example (η : ObservationEnvModel) :
    Observation.measure .listLength (.listValue (observeSlots η [none,some (.var 0)])) =
      some (.integer 2) := by
  have len := observeSlots_length η [none,some (.var 0)]
  simpa [len] using Observation.measure_exact.2.2.1 (observeSlots η [none,some (.var 0)])

private def small (k : IntKind) (n : Nat) (h : n ≤ 6) : IntegerValue k :=
  ⟨n, by cases k <;> simp only [IntKind.min, IntKind.max,
    Benitoite.Release.min64, Benitoite.Release.max64] <;> omega⟩

/-- 同じ 2,3,5,6 を七幅で使い、21の正常演算から実定数を得る。 -/
theorem seven_integer_normal (k : IntKind) :
    (∃ v : IntegerValue k, k.checkedAdd (small k 2 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k v) ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented) ∧
    (∃ v : IntegerValue k, k.checkedSub (small k 5 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k v) ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented) ∧
    (∃ v : IntegerValue k, k.checkedMul (small k 2 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k v) ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented) := by
  have ha : k.checkedAdd (small k 2 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k (small k 5 (by decide))) := by cases k <;> rfl
  have hs : k.checkedSub (small k 5 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k (small k 2 (by decide))) := by cases k <;> rfl
  have hm : k.checkedMul (small k 2 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k (small k 6 (by decide))) := by cases k <;> rfl
  exact ⟨⟨_,ha,(binary_normal k .add _ _ _ (Or.inl rfl) ha).2.1⟩,
    ⟨_,hs,(binary_normal k .sub _ _ _ (Or.inr (Or.inl rfl)) hs).2.1⟩,
    ⟨_,hm,(binary_normal k .mul _ _ _ (Or.inr (Or.inr rfl)) hm).2.1⟩⟩

example : IntKind.checkedAdd .integer8 ⟨127,by decide⟩ ⟨1,by decide⟩ = .rejected .overflow ∧
    ∀ v, IntKind.checkedAdd .integer8 ⟨127,by decide⟩ ⟨1,by decide⟩ ≠ .normal v :=
  ⟨rfl, rejected_not_normal (why := .overflow) rfl⟩

example : (Const.byte 255).NumericRepresented ∧
    (Val.const (.byte 255)).toTerm? = some (.integer 255) ∧
    (Const.unsignedInteger16 255).NumericRepresented := byte_and_u16_represented 255 (by decide)

example : Key.normalizeMap [some (.decimal 1 0),some (.decimal 10 1)]
    [some (.integer 7),some (.integer 9)] = some [(.decimal 1 0,some (.integer 9))] ∧
    Key.normalizeSet [some (.decimal 1 0),some (.decimal 10 1)] = some [.decimal 1 0] := by cbv

example : (Observation.decimal 1 0).compare .eq (.decimal 10 1) = true :=
  decimal_key_compare (by cbv)

example (η : ObservationEnvModel) :
    ∃ c d, (Observation.listValue [some (.decimal 1 0)]).keyCode? = some c ∧
      (Observation.listValue [some (.decimal 10 1)]).keyCode? = some d ∧
      Key.equal (.listValue [some (.decimal 1 0)]) (.listValue [some (.decimal 10 1)]) =
        some (decide (c = d)) := by
  exact Key.equal_of_shapes (by trivial) (by trivial) η rfl rfl
    (.list (.cons (.decimal 1 0) .nil)) (.list (.cons (.decimal 10 1) .nil))

/-- Mapのsizeは値なしでも成功するが、同じMapの鍵化には値も要る。 -/
example : mapKeys [some (.integer 1)] [none] = some [([0,0,1],none)] ∧
    (Observation.mapValue [some (.integer 1)] [none]).keyCode? = none := by cbv

example : (Observation.mapValue [some (.integer 1)] [some (.string "x")]).KeyShape :=
  .map (.cons (.integer 1) (.string "x") .nil)

example (η : ObservationEnvModel) :
    Observation.measure .mapSize (.mapValue (observeSlots η [some (.integer 1),some (.integer 1)])
      (observeSlots η [none,none])) = some (.integer 1) :=
by
  apply Key.map_measure (entries := [(.integer 1,none)]) η
  · intro o h t ht
    simp only [List.mem_cons, List.not_mem_nil, or_false, or_self] at h
    rw [h] at ht
    cases ht
    trivial
  · cbv

example (η : ObservationEnvModel) :
    Observation.measure .setSize (.setValue (observeSlots η [some (.integer 1),some (.integer 1)])) =
      some (.integer 1) :=
by
  apply Key.set_measure (entries := [.integer 1]) η
  · intro o h t ht
    simp only [List.mem_cons, List.not_mem_nil, or_false, or_self] at h
    rw [h] at ht
    cases ht
    trivial
  · cbv

example (vs : List (Option Observation)) (len : vs.length = 2) :
    ∃ entries, mapKeys [some (.integer 1),some (.integer 1)] vs = some entries :=
  Observation.KeySlots.mapKeys (.cons (.integer 1) (.cons (.integer 1) .nil)) vs len.symm []

example : (Observation.float64 0).keyCode? = none ∧
    (Observation.float32 0).keyCode? = none ∧
    (Observation.targetValue none (.path [])).keyCode? = none :=
  Observation.key_unsupported 0 0 none (.path [])

example (k : IntKind) (signed : k.min < 0) :
    ∃ a v : IntegerValue k, a.toInt = -1 ∧ v.toInt = 1 ∧
      k.checkedNeg signed a = .normal (.ofInteger k v) ∧
      (embedConst (IntegerValue.toConst k v)).NumericRepresented := by
  let a : IntegerValue k := ⟨-1, by
    cases k <;> simp only [IntKind.min, IntKind.max, Benitoite.Release.min64,
      Benitoite.Release.max64] at signed ⊢ <;> omega⟩
  have normal : k.checkedNeg signed a = .normal (.ofInteger k (small k 1 (by decide))) := by
    cases k <;> rfl
  exact ⟨a, small k 1 (by decide), rfl, rfl, normal, (neg_normal k signed a _ normal).2.1⟩

example (η : ObservationEnvModel) :
    (Const.decimal 1 0).NumericRepresented ∧
    (Val.const (.decimal 1 0)).toTerm? = some (.decimal 1 0) ∧
    (Term.decimal 1 0).observe η = some (.decimal 1 0) ∧
    ∀ p ∈ (Const.decimal 1 0).type.carrierFacts,
      p.interpret (selfModel η (.const (.decimal 1 0))) = true :=
  decimal_result (B := LegacyPatternExamples.builtins) (by constructor <;> decide) η

example (η : ObservationEnvModel) (op : Comparison) :
    (Pred.compare .character op (.character 'a') (.character 'b')).interpret η =
      (Observation.character 'a').compare op (.character 'b') :=
  compare_exact (t := .character 'a') (u := .character 'b') η rfl rfl rfl rfl op

-- 12分類の全件はBuiltinLogicExamples.classes_12。同じ本番bitsの入口も読む。
example (η : ObservationEnvModel) :
    (Pred.floatClass .binary32 .nan (.float32 2143289344)).interpret η = true ∧
    (Pred.floatClass .binary64 .negativeZero (.float64 9223372036854775808)).interpret η = true := by
  constructor
  · exact (float_class_exact η (.float32 2143289344) .nan).1 _ rfl
  · exact (float_class_exact η (.float64 9223372036854775808) .negativeZero).2 _ rfl

-- 実際の制約表の成功と有限構造の証拠を別々に供給する。
example : Benitoite.Release.satB [] []
    (.map (.base .integer8) (.list (.base .decimal))) Benitoite.Release.TParam.keyC = true ∧
    ∃ code, (Observation.mapValue [some (.integer 1)]
      [some (.listValue [some (.decimal 10 1)])]).keyCode? = some code := by
  exact ⟨by decide, (Observation.KeyShape.map
    (.cons (.integer 1) (.list (.cons (.decimal 10 1) .nil)) .nil)).code⟩

end Benitoite.Release.Refinement.ObservationContractsExamples
