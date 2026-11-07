import Benitoite.Release.Refinement.Surface.PredicateSimulationReplyAvoid

/-! # 有限リストの固定応答と内部名の保存 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open StandardCollections
noncomputable section

theorem option_value {source rows x y} (related : OptionalValue source rows x y) (type : Ty) :
    Value source rows (optionValue type x) (optionValue type y) := by
  cases related with
  | none => exact .con .nil
  | some value => exact .con (.cons value .nil)

theorem option_value_noMint {keys value} (avoid : ∀ v, value = some v → ValueAvoid keys v) (type : Ty) :
    ValueAvoid keys (optionValue type value) := by
  cases value with
  | none => exact ValueAvoid.con (ValuesAvoid.nil _) _ _
  | some value => exact ValueAvoid.con (ValuesAvoid.cons.mpr ⟨avoid _ rfl, ValuesAvoid.nil _⟩) _ _

theorem count_noMint {keys} (count : Nat) : OutcomeAvoid keys (countReply count) := by
  unfold countReply
  split
  · exact ValueAvoid.constant _ _
  · trivial

/-- 要素を追加する実δは、その位置の値の対応を保つ。 -/
theorem list_insert_delta {source rows xs ys x y} (related : Values source rows xs ys)
    (element : Value source rows x y) (append : Bool) (type : Ty) :
    OptionalOutcomeRel source rows
      (insertDelta (if append then "List.append" else "List.prepend") [type] [] [] [.list xs,x])
      (insertDelta (if append then "List.append" else "List.prepend") [type] [] [] [.list ys,y]) := by
  cases append
  · exact .some (.value (.list (.cons element related)))
  · exact .some (.value (.list (related.append (.cons element .nil))))

theorem list_insert_noMint {keys xs x} (avoid : ValuesAvoid keys xs) (element : ValueAvoid keys x)
    (append : Bool) (type : Ty) : OptionalOutcomeAvoid keys
      (insertDelta (if append then "List.append" else "List.prepend") [type] [] [] [.list xs,x]) := by
  cases append
  · exact ValueAvoid.list (ValuesAvoid.cons.mpr ⟨element,avoid⟩)
  · exact ValueAvoid.list (ValuesAvoid.append.mpr ⟨avoid,ValuesAvoid.cons.mpr ⟨element,ValuesAvoid.nil _⟩⟩)

theorem list_concatenate_delta {source rows xs ys us vs} (left : Values source rows xs ys)
    (right : Values source rows us vs) (type : Ty) :
    OptionalOutcomeRel source rows
      (sequenceDelta "List.concatenate" [type] [] [] [.list xs,.list us])
      (sequenceDelta "List.concatenate" [type] [] [] [.list ys,.list vs]) :=
  .some (.value (.list (left.append right)))

theorem list_concatenate_noMint {keys xs ys} (left : ValuesAvoid keys xs) (right : ValuesAvoid keys ys)
    (type : Ty) : OptionalOutcomeAvoid keys
      (sequenceDelta "List.concatenate" [type] [] [] [.list xs,.list ys]) :=
  ValueAvoid.list (ValuesAvoid.append.mpr ⟨left,right⟩)

theorem list_reverse_delta {source rows xs ys} (related : Values source rows xs ys) (type : Ty) :
    OptionalOutcomeRel source rows
      (sequenceDelta "List.reverse" [type] [] [] [.list xs])
      (sequenceDelta "List.reverse" [type] [] [] [.list ys]) :=
  .some (.value (.list related.reverse))

theorem list_reverse_noMint {keys xs} (avoid : ValuesAvoid keys xs) (type : Ty) :
    OptionalOutcomeAvoid keys (sequenceDelta "List.reverse" [type] [] [] [.list xs]) :=
  ValueAvoid.list avoid.reverse

theorem list_length_delta {source rows xs ys} (related : Values source rows xs ys) (type : Ty) :
    OptionalOutcomeRel source rows
      (lengthDelta "List.length" [type] [] [] [.list xs])
      (lengthDelta "List.length" [type] [] [] [.list ys]) := by
  change OptionalOutcomeRel source rows (some (countReply xs.length)) (some (countReply ys.length))
  rw [related.length]
  exact .refl _

theorem list_length_noMint {keys xs} (type : Ty) :
    OptionalOutcomeAvoid keys (lengthDelta "List.length" [type] [] [] [.list xs]) :=
  count_noMint _

theorem list_empty_delta {source rows xs ys} (related : Values source rows xs ys) (type : Ty) :
    OptionalOutcomeRel source rows
      (lengthDelta "List.isEmpty" [type] [] [] [.list xs])
      (lengthDelta "List.isEmpty" [type] [] [] [.list ys]) := by
  cases related <;> exact .some (.value (.constant _))

theorem list_empty_noMint {keys xs} (type : Ty) :
    OptionalOutcomeAvoid keys (lengthDelta "List.isEmpty" [type] [] [] [.list xs]) :=
  ValueAvoid.constant _ _

theorem Values.head? {source rows xs ys} (related : Values source rows xs ys) :
    OptionalValue source rows xs.head? ys.head? := by
  cases related with
  | nil => exact .none
  | cons head _ => exact .some head

theorem Values.tail? {source rows xs ys} (related : Values source rows xs ys) :
    OptionalValue source rows (StandardListRemainingResponse.tail? xs) (StandardListRemainingResponse.tail? ys) := by
  cases related with
  | nil => exact .none
  | cons _ tail => exact .some (.list tail)

theorem list_head_delta {source rows xs ys} (related : Values source rows xs ys) (type : Ty) :
    OptionalOutcomeRel source rows
      (StandardListRemainingResponse.delta .head "List.head" [type] [] [] [.list xs])
      (StandardListRemainingResponse.delta .head "List.head" [type] [] [] [.list ys]) := by
  exact .some (.value (option_value related.head? type))

theorem list_tail_delta {source rows xs ys} (related : Values source rows xs ys) (type : Ty) :
    OptionalOutcomeRel source rows
      (StandardListRemainingResponse.delta .tail "List.tail" [type] [] [] [.list xs])
      (StandardListRemainingResponse.delta .tail "List.tail" [type] [] [] [.list ys]) := by
  exact .some (.value (option_value related.tail? (.list type)))

theorem list_get_delta {source rows xs ys} (related : Values source rows xs ys)
    (type : Ty) (index : Benitoite.Release.Integer64Value) :
    OptionalOutcomeRel source rows
      (StandardListRemainingResponse.delta .get "List.get" [type] [] [] [.list xs,.const (.integer index)])
      (StandardListRemainingResponse.delta .get "List.get" [type] [] [] [.list ys,.const (.integer index)]) := by
  apply OptionalOutcomeRel.some
  apply OutcomeRel.value
  apply option_value
  unfold StandardListRemainingResponse.at?
  split
  · exact related.getElem? _
  · exact .none

theorem list_take_delta {source rows xs ys} (related : Values source rows xs ys)
    (type : Ty) (count : Benitoite.Release.Integer64Value) :
    OptionalOutcomeRel source rows
      (StandardListRemainingResponse.delta .take "List.take" [type] [] [] [.list xs,.const (.integer count)])
      (StandardListRemainingResponse.delta .take "List.take" [type] [] [] [.list ys,.const (.integer count)]) :=
  .some (.value (.list (related.take _)))

theorem list_drop_delta {source rows xs ys} (related : Values source rows xs ys)
    (type : Ty) (count : Benitoite.Release.Integer64Value) :
    OptionalOutcomeRel source rows
      (StandardListRemainingResponse.delta .drop "List.drop" [type] [] [] [.list xs,.const (.integer count)])
      (StandardListRemainingResponse.delta .drop "List.drop" [type] [] [] [.list ys,.const (.integer count)]) :=
  .some (.value (.list (related.drop _)))

theorem contains_result {source rows xs ys x y} (related : Values source rows xs ys)
    (element : Value source rows x y) :
    StandardListRemainingResponse.containsResult xs x = StandardListRemainingResponse.containsResult ys y := by
  cases related with
  | nil => rfl
  | cons head tail =>
    simp only [StandardListRemainingResponse.containsResult, structural_equal head element,
      contains_result tail element]

theorem list_contains_delta {source rows xs ys x y} (related : Values source rows xs ys)
    (element : Value source rows x y) (type : Ty) :
    OptionalOutcomeRel source rows
      (StandardListRemainingResponse.delta .contains "List.contains" [type] [] [] [.list xs,x])
      (StandardListRemainingResponse.delta .contains "List.contains" [type] [] [] [.list ys,y]) := by
  change OptionalOutcomeRel source rows (some (StandardListRemainingResponse.containsReply xs x))
    (some (StandardListRemainingResponse.containsReply ys y))
  unfold StandardListRemainingResponse.containsReply
  rw [contains_result related element]
  exact .refl _

theorem list_head_noMint {keys xs} (avoid : ValuesAvoid keys xs) (type : Ty) :
    OptionalOutcomeAvoid keys
      (StandardListRemainingResponse.delta .head "List.head" [type] [] [] [.list xs]) := by
  apply option_value_noMint
  intro value found
  exact avoid value (List.mem_of_head? found)

theorem list_tail_noMint {keys xs} (avoid : ValuesAvoid keys xs) (type : Ty) :
    OptionalOutcomeAvoid keys
      (StandardListRemainingResponse.delta .tail "List.tail" [type] [] [] [.list xs]) := by
  apply option_value_noMint
  cases xs with
  | nil => intro value found; cases found
  | cons head rest =>
    intro value found
    cases found
    exact ValueAvoid.list (ValuesAvoid.cons.mp avoid).2

theorem list_get_noMint {keys xs} (avoid : ValuesAvoid keys xs)
    (type : Ty) (index : Benitoite.Release.Integer64Value) : OptionalOutcomeAvoid keys
      (StandardListRemainingResponse.delta .get "List.get" [type] [] [] [.list xs,.const (.integer index)]) := by
  apply option_value_noMint
  unfold StandardListRemainingResponse.at?
  split
  · intro value found; exact avoid.getElem? found
  · intro value found; cases found

theorem list_take_noMint {keys xs} (avoid : ValuesAvoid keys xs)
    (type : Ty) (count : Benitoite.Release.Integer64Value) : OptionalOutcomeAvoid keys
      (StandardListRemainingResponse.delta .take "List.take" [type] [] [] [.list xs,.const (.integer count)]) :=
  ValueAvoid.list (avoid.take _)

theorem list_drop_noMint {keys xs} (avoid : ValuesAvoid keys xs)
    (type : Ty) (count : Benitoite.Release.Integer64Value) : OptionalOutcomeAvoid keys
      (StandardListRemainingResponse.delta .drop "List.drop" [type] [] [] [.list xs,.const (.integer count)]) :=
  ValueAvoid.list (avoid.drop _)

theorem list_contains_noMint {keys xs x} (type : Ty) : OptionalOutcomeAvoid keys
      (StandardListRemainingResponse.delta .contains "List.contains" [type] [] [] [.list xs,x]) := by
  change OutcomeAvoid keys (StandardListRemainingResponse.containsReply xs x)
  unfold StandardListRemainingResponse.containsReply
  split
  · exact ValueAvoid.constant _ _
  · trivial

theorem list_front_reply {source rows xs ys} (related : Values source rows xs ys)
    (index : Benitoite.Release.Integer64Value) :
    OutcomeRel source rows (StandardSafe.frontReply xs index) (StandardSafe.frontReply ys index) := by
  unfold StandardSafe.frontReply
  split
  · exact .error _
  · have selected := related.getElem? index.toInt.toNat
    generalize left : xs[index.toInt.toNat]? = original at selected
    generalize right : ys[index.toInt.toNat]? = target at selected
    cases selected with
    | none => exact .error _
    | some value => exact .value value

theorem list_front_delta {source rows xs ys} (related : Values source rows xs ys)
    (type : Ty) (index : Benitoite.Release.Integer64Value) :
    OptionalOutcomeRel source rows
      (StandardSafe.frontDelta "%List.getFront" [type] [] [] [.list xs,.const (.integer index)])
      (StandardSafe.frontDelta "%List.getFront" [type] [] [] [.list ys,.const (.integer index)]) :=
  .some (list_front_reply related index)

theorem list_front_reply_noMint {keys xs} (avoid : ValuesAvoid keys xs) (index : Benitoite.Release.Integer64Value) :
    OutcomeAvoid keys (StandardSafe.frontReply xs index) := by
  unfold StandardSafe.frontReply
  split
  · trivial
  · split
    · rename_i value found
      exact avoid.getElem? found
    · trivial

theorem list_front_noMint {keys xs} (avoid : ValuesAvoid keys xs)
    (type : Ty) (index : Benitoite.Release.Integer64Value) : OptionalOutcomeAvoid keys
      (StandardSafe.frontDelta "%List.getFront" [type] [] [] [.list xs,.const (.integer index)]) :=
  list_front_reply_noMint avoid index

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
