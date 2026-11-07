import Benitoite.Release.Refinement.Surface.PredicateSimulationMapReplace
import Benitoite.Release.Refinement.Surface.PredicateSimulationSetProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationHttpProviders

/-! # 固定した純粋応答の合成と禁止名不在 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 実δの引数が同じなら応答も同じであり、その型付き結果の性質を元の応答へ使える。 -/
theorem fixed_inputs_response {source rows keys xs ys}
    (delta : List Val → Option Outcome) (same : xs = ys)
    (safe : ∀ out, delta ys = some out → OutcomeAvoid keys out) :
    OptionalOutcomeRel source rows (delta xs) (delta ys) ∧ OptionalOutcomeAvoid keys (delta xs) := by
  subst xs
  refine ⟨.refl _,?_⟩
  cases answer : delta ys with
  | none => trivial
  | some out => exact safe out answer

/-- 構造比較は任意の実引数列と署名引数について、同じ失敗又は対応するBooleanを返す。 -/
theorem equality_delta {source rows xs ys} (related : Values source rows xs ys)
    (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows (StandardStructuralEqualityResponse.delta name ts es rs xs)
      (StandardStructuralEqualityResponse.delta name ts es rs ys) := by
  unfold StandardStructuralEqualityResponse.delta
  split
  · cases ts with
    | nil => exact .none
    | cons type rest => cases rest with
      | cons _ _ => exact .none
      | nil => cases related with
        | nil => exact .none
        | cons left rest => cases rest with
          | nil => exact .none
          | cons right rest => cases rest with
            | nil => exact .some (equality_reply left right _)
            | cons _ _ => exact .none
  · exact .none

theorem equality_delta_noMint {keys name ts es rs values} :
    OptionalOutcomeAvoid keys (StandardStructuralEqualityResponse.delta name ts es rs values) := by
  unfold StandardStructuralEqualityResponse.delta
  split
  · cases ts with
    | nil => trivial
    | cons type rest => cases rest with
      | cons _ _ => trivial
      | nil => cases values with
        | nil => trivial
        | cons left rest => cases rest with
          | nil => trivial
          | cons right rest => cases rest with
            | nil => exact equality_noMint
            | cons _ _ => trivial
  · trivial

/-- 動的な篩の検査は、任意の実引数列でも元の値の対応を保つ。 -/
theorem check_delta {source rows xs ys} (related : Values source rows xs ys)
    (render : Ty → String) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows (RefinementCheck.delta render name ts es rs xs)
      (RefinementCheck.delta render name ts es rs ys) := by
  unfold RefinementCheck.delta
  split
  · cases ts with
    | nil => exact .none
    | cons input rest => cases rest with
      | nil => exact .none
      | cons output rest => cases rest with
        | cons _ _ => exact .none
        | nil => cases related with
          | nil => exact .none
          | cons value rest => cases rest with
            | nil => exact .some (check_run value render input output)
            | cons _ _ => exact .none
  · exact .none

theorem check_delta_noMint {keys values} (avoid : ValuesAvoid keys values)
    (render : Ty → String) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeAvoid keys (RefinementCheck.delta render name ts es rs values) := by
  unfold RefinementCheck.delta
  split
  · cases ts with
    | nil => trivial
    | cons input rest => cases rest with
      | nil => trivial
      | cons output rest => cases rest with
        | cons _ _ => trivial
        | nil => cases values with
          | nil => trivial
          | cons value rest => cases rest with
            | nil => exact check_run_noMint (ValuesAvoid.cons.mp avoid).1 render input output
            | cons _ _ => trivial
  · trivial

theorem precision_delta {source rows xs ys} (related : Values source rows xs ys)
    (constructors : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows (StandardModel.precisionDelta constructors name ts es rs xs)
      (StandardModel.precisionDelta constructors name ts es rs ys) := by
  unfold StandardModel.precisionDelta
  split
  · rename_i fixed
    subst name
    exact replace_values_delta related constructors ts es rs
  · split
    · exact map_delta related constructors name ts es rs
    · exact set_delta related constructors name ts es rs

theorem precision_delta_noMint {keys values} (avoid : ValuesAvoid keys values)
    (constructors : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeAvoid keys (StandardModel.precisionDelta constructors name ts es rs values) := by
  unfold StandardModel.precisionDelta
  split
  · rename_i fixed
    subst name
    exact replace_values_noMint avoid constructors ts es rs
  · split
    · exact map_noMint avoid constructors name ts es rs
    · exact set_noMint avoid constructors name ts es rs

theorem collection_delta {source rows xs ys} (related : Values source rows xs ys)
    (constructors : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows (StandardModel.collectionDelta constructors name ts es rs xs)
      (StandardModel.collectionDelta constructors name ts es rs ys) := by
  unfold StandardModel.collectionDelta
  split
  · exact map_delta related constructors name ts es rs
  · exact set_delta related constructors name ts es rs

theorem collection_delta_noMint {keys values} (avoid : ValuesAvoid keys values)
    (constructors : List ConName) (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeAvoid keys (StandardModel.collectionDelta constructors name ts es rs values) := by
  unfold StandardModel.collectionDelta
  split
  · exact map_noMint avoid constructors name ts es rs
  · exact set_noMint avoid constructors name ts es rs

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
