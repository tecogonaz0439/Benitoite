import Benitoite.Release.Refinement.Surface.PredicateSimulationIOProviders

/-! # パスの検査・射影・拡大の固定応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

theorem scope_path_run {source rows xs ys} (related : Values source rows xs ys) (range : RangeExpr) :
    ScopeDelta.run range xs = ScopeDelta.run range ys := by
  cases related with
  | nil => rfl
  | cons first tail =>
    cases tail with
    | nil => cases first <;> rfl
    | cons second tail =>
      cases tail with
      | nil =>
        cases first with
        | constant c => cases c <;> first | rfl | cases second <;> rfl
        | _ => rfl
      | cons _ _ =>
        cases first with
        | constant c =>
          cases c with
          | string text => cases second with
            | constant d => cases d <;> rfl
            | _ => rfl
          | _ => rfl
        | _ => rfl

theorem scope_path_delta {source rows xs ys} (related : Values source rows xs ys)
    (name ts es rs) : OptionalOutcomeRel source rows
      (ScopeDelta.delta name ts es rs xs) (ScopeDelta.delta name ts es rs ys) := by
  unfold ScopeDelta.delta
  by_cases active : name = "Scope.checkPathIn" ∧ ts = [] ∧ es = []
  · simp only [ite_eq_left active]
    cases rs with
    | nil => exact .none
    | cons range rest => cases rest with
      | nil =>
        change OptionalOutcomeRel source rows (some (ScopeDelta.run range xs)) (some (ScopeDelta.run range ys))
        rw [scope_path_run related]
        exact .refl _
      | cons _ _ => exact .none
  · simp only [ite_eq_right active]; exact .none

theorem scope_path_value_run {source rows xs ys} (related : Values source rows xs ys) :
    ScopeDelta.pathValueRun xs = ScopeDelta.pathValueRun ys := by
  cases related with
  | nil => rfl
  | cons head tail =>
    cases tail with
    | nil => simp only [ScopeDelta.pathValueRun,head.target]
    | cons _ _ => rfl

theorem scope_widen_run {source rows xs ys} (related : Values source rows xs ys) :
    OutcomeRel source rows (ScopeDelta.widenRun xs) (ScopeDelta.widenRun ys) := by
  cases related with
  | nil => exact .error _
  | cons head tail => cases tail with
    | nil => exact .value head
    | cons _ _ => exact .error _

theorem scope_value_delta {source rows xs ys} (related : Values source rows xs ys)
    (name ts es rs) : OptionalOutcomeRel source rows
      (ScopeDelta.valueDelta name ts es rs xs) (ScopeDelta.valueDelta name ts es rs ys) := by
  unfold ScopeDelta.valueDelta
  by_cases active : ts = [] ∧ es = []
  · simp only [ite_eq_left active]
    by_cases path : name = "Scope.pathInValue"
    · simp only [path,ite_true]
      cases rs with
      | nil => exact .none
      | cons range rest => cases rest with
        | nil => rw [scope_path_value_run related]; exact .refl _
        | cons _ _ => exact .none
    · simp only [path,ite_false]
      by_cases widen : name = "Scope.widenPathIn"
      · simp only [widen,ite_true]
        cases rs with
        | nil => exact .none
        | cons range rest => cases rest with
          | nil => exact .none
          | cons target rest => cases rest with
            | nil => exact .some (scope_widen_run related)
            | cons _ _ => exact .none
      · simp only [widen,ite_false]; exact .none
  · simp only [ite_eq_right active]; exact .none

/-- Resultの一欄への格納は、元の値の禁止名不在を保つ。 -/
theorem result_value_noMint {keys value} (avoid : ValueAvoid keys value) (ok : Bool) (a e : Ty) :
    ValueAvoid keys (ScopeDelta.resultValue ok a e value) :=
  ValueAvoid.con (ValuesAvoid.cons.mpr ⟨avoid,ValuesAvoid.nil _⟩) _ _

private theorem scope_error_noMint {keys value} (avoid : ValueAvoid keys value) (range : RangeExpr) :
    OutcomeAvoid keys (ScopeDelta.error range value) := result_value_noMint avoid _ _ _

private theorem scope_ok_noMint {keys target} (range : RangeExpr) :
    OutcomeAvoid keys (ScopeDelta.ok range (.checked target)) :=
  result_value_noMint (fun name member => by cases member) _ _ _

/-- 範囲検査の六診断は文字列・整数の欄から作り、禁止名を含まない。 -/
theorem scope_payload_noMint {keys} (pattern target : String) (lo hi port : Benitoite.Release.Integer64Value)
    (error : Checked.Scope.ScopeError) (reason : String) :
    ValueAvoid keys (ScopeDelta.errorValue pattern target lo hi port error reason) := by
  cases error <;> intro name member <;> cases member

private theorem invalid_pattern_noMint {keys} (raw reason : String) :
    ValueAvoid keys (ScopeDelta.invalidPattern raw reason) := by intro name member; cases member

private theorem invalid_target_noMint {keys} (raw reason : String) :
    ValueAvoid keys (ScopeDelta.invalidTarget raw reason) := by intro name member; cases member

theorem scope_path_run_noMint {keys} (range : RangeExpr) (values : List Val) :
    OutcomeAvoid keys (ScopeDelta.run range values) := by
  unfold ScopeDelta.run
  repeat' first
    | exact scope_error_noMint (invalid_pattern_noMint _ _) _
    | exact scope_error_noMint (invalid_target_noMint _ _) _
    | exact scope_error_noMint (scope_payload_noMint _ _ _ _ _ _ _) _
    | exact scope_ok_noMint _
    | split

theorem scope_path_noMint {keys name ts es rs values} :
    OptionalOutcomeAvoid keys (ScopeDelta.delta name ts es rs values) := by
  unfold ScopeDelta.delta
  split
  · cases rs with
    | nil => trivial
    | cons range rest => cases rest with
      | nil => exact scope_path_run_noMint _ _
      | cons _ _ => trivial
  · trivial

theorem scope_path_value_noMint {keys} (values : List Val) : OutcomeAvoid keys (ScopeDelta.pathValueRun values) := by
  unfold ScopeDelta.pathValueRun
  split
  · split
    · exact ValueAvoid.constant _ _
    · trivial
  · trivial

theorem scope_widen_noMint {keys values} (avoid : ValuesAvoid keys values) : OutcomeAvoid keys (ScopeDelta.widenRun values) := by
  cases values with
  | nil => trivial
  | cons head tail => cases tail with
    | nil => exact avoid head List.mem_cons_self
    | cons _ _ => trivial

theorem scope_value_noMint {keys name ts es rs values} (avoid : ValuesAvoid keys values) :
    OptionalOutcomeAvoid keys (ScopeDelta.valueDelta name ts es rs values) := by
  unfold ScopeDelta.valueDelta
  split
  · split
    · cases rs with
      | nil => trivial
      | cons range rest => cases rest with
        | nil => exact scope_path_value_noMint _
        | cons _ _ => trivial
    · split
      · cases rs with
        | nil => trivial
        | cons range rest => cases rest with
          | nil => trivial
          | cons target rest => cases rest with
            | nil => exact scope_widen_noMint avoid
            | cons _ _ => trivial
      · trivial
  · trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
