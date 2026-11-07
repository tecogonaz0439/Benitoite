import Benitoite.Release.Refinement.Surface.PredicateSimulationResponses
import Benitoite.Release.Refinement.Surface.PredicateSimulationInvariants
import Benitoite.Release.Refinement.Surface.PredicateProjectionTable

/-! # 登録したscalar行と欄の行の固定応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open MatchFacts
noncomputable section

private inductive FieldsRel (source : Program) (rows : PredicateProjection.Table.Rows) :
    Option (ConName × List Val) → Option (ConName × List Val) → Prop where
  | none : FieldsRel source rows none none
  | some {c xs ys} : Values source rows xs ys → FieldsRel source rows (some (c,xs)) (some (c,ys))

private theorem fields_relation {source rows x y} (related : Value source rows x y) :
    FieldsRel source rows (conFields? x) (conFields? y) := by
  cases related
  all_goals first | exact .none | exact .some ‹Values source rows _ _› | exact .some (Values.refl _)

/-- 成功・不在の両方について、同じ欄の経路の読取りが値の対応を保つ。 -/
theorem Value.readPath_option {source rows x y} (related : Value source rows x y) (route : List FieldRef) :
    OptionalValue source rows (readPath x route) (readPath y route) := by
  induction route generalizing x y with
  | nil => exact .some related
  | cons field route ih =>
    have fields := fields_relation related
    generalize left : conFields? x = original at fields
    generalize right : conFields? y = target at fields
    cases fields with
    | none => simp only [readPath,left,right]; exact .none
    | @some c xs ys children =>
      simp only [readPath,left,right]
      change OptionalValue source rows
        (if c = field.constructor then xs[field.position]?.bind (fun v => readPath v route) else none)
        (if c = field.constructor then ys[field.position]?.bind (fun v => readPath v route) else none)
      by_cases same : c = field.constructor
      · simp only [same,ite_true]
        have selected := children.getElem? field.position
        generalize a : xs[field.position]? = original at selected
        generalize b : ys[field.position]? = target at selected
        cases selected with
        | none => exact .none
        | some element => simpa only [a,b,Option.bind_some] using ih element
      · simp only [same,ite_false]; exact .none

theorem row_scalar_run {source rows xs ys} (related : Values source rows xs ys) (entry : PredicateRows.Entry) :
    entry.run xs = entry.run ys := by
  cases entry with
  | floating width test => exact floating_run related width test
  | path pattern | host pattern | characters minimum maximum =>
    cases related with
    | nil => rfl
    | cons head tail =>
      cases tail with
      | nil => cases head <;> rfl
      | cons next rest =>
        cases head with
        | constant c => cases c <;> rfl
        | _ => rfl

theorem row_projection_run {source rows xs ys} (related : Values source rows xs ys)
    (projection : PredicateProjection.Projection) : projection.run xs = projection.run ys := by
  cases related with
  | nil => rfl
  | cons head tail =>
    cases tail with
    | cons _ _ => rfl
    | nil =>
      unfold PredicateProjection.Projection.run
      have path := head.readPath_option projection.route
      generalize a : readPath _ projection.route = x at path
      generalize b : readPath _ projection.route = y at path
      cases path with
      | none => simp only [a,b]
      | some leaf => simpa only [a,b,Option.elim] using row_scalar_run (.cons leaf .nil) projection.entry

/-- 登録済みの行も、生成した行も、固定した行の定義から応答の対応を得る。 -/
theorem row_delta {source rows xs ys} (related : Values source rows xs ys)
    (row : PredicateProjection.Row) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows (row.delta ts es rs xs) (row.delta ts es rs ys) := by
  cases row with
  | scalar entry =>
    simp only [PredicateProjection.Row.delta,PredicateRows.Entry.delta]
    rw [row_scalar_run related entry]
    exact .refl _
  | projected projection =>
    simp only [PredicateProjection.Row.delta,PredicateProjection.Projection.delta]
    rw [row_projection_run related projection]
    exact .refl _

/-- 内部行の結果はBoolean定数だけであり、どの禁止名も含まない。 -/
theorem row_noMint {keys} (row : PredicateProjection.Row)
    (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (values : List Val) :
    OptionalOutcomeAvoid keys (row.delta ts es rs values) := by
  cases row with
  | scalar entry =>
    simp only [PredicateProjection.Row.delta,PredicateRows.Entry.delta]
    split
    · exact ValueAvoid.constant _ _
    · trivial
  | projected projection =>
    simp only [PredicateProjection.Row.delta,PredicateProjection.Projection.delta]
    split
    · exact ValueAvoid.constant _ _
    · trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
