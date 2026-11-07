import Benitoite.Release.Refinement.Surface.PredicateSimulationAlgebra
import Benitoite.Release.Refinement.MatchFacts

/-! # 同じ構成子の欄を読む値の対応 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open MatchFacts
noncomputable section

private theorem selected_value {source rows values targets target} {index : Nat}
    (related : Values source rows values targets) (found : targets[index]? = some target) :
    ∃ value, values[index]? = some value ∧ Value source rows value target := by
  match related with
  | .nil => simp at found
  | .cons head tail =>
    cases index with
    | zero => cases found; exact ⟨_, rfl, head⟩
    | succ index => exact selected_value (index := index) tail found

termination_by structural related

/-- 同じ構成子の欄列は、値の対応を欄ごとに保つ。 -/
theorem Value.conFields {source rows value target constructor targets}
    (related : Value source rows value target) (found : conFields? target = some (constructor, targets)) :
    ∃ values, conFields? value = some (constructor, values) ∧ Values source rows values targets := by
  cases related <;> simp only [conFields?] at found
  all_goals try cases found
  case con related => exact ⟨_, rfl, related⟩
  case atError detail => exact ⟨_, rfl, Values.refl _⟩

/-- 欄の経路の読取りは、元の値と準備後の値の対応を葉まで保つ。 -/
theorem Value.readPath {source rows value target leaf} {route : List FieldRef}
    (related : Value source rows value target) (found : MatchFacts.readPath target route = some leaf) :
    ∃ original, MatchFacts.readPath value route = some original ∧ Value source rows original leaf := by
  induction route generalizing value target with
  | nil => cases found; exact ⟨_, rfl, related⟩
  | cons field route ih =>
    cases fields : conFields? target with
    | none => simp [MatchFacts.readPath, fields] at found
    | some pair =>
      rcases pair with ⟨constructor, targets⟩
      obtain ⟨values, originals, hvalues⟩ := related.conFields fields
      by_cases same : constructor = field.constructor
      · simp only [MatchFacts.readPath, fields, same] at found
        cases selected : targets[field.position]? with
        | none => simp [selected] at found
        | some targetField =>
          obtain ⟨valueField, selectedOriginal, relatedField⟩ := selected_value hvalues selected
          obtain ⟨original, readOriginal, leafRelated⟩ := ih relatedField (by simpa [selected] using found)
          exact ⟨original, by simp [MatchFacts.readPath, originals, same, selectedOriginal, readOriginal], leafRelated⟩
      · simp [MatchFacts.readPath, fields, same] at found

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
