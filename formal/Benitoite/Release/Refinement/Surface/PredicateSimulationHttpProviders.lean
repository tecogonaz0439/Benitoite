import Benitoite.Release.Refinement.Surface.PredicateSimulationScopeProviders

/-! # 保持したHTTP要求の検査・射影・拡大と固定δ -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem check_run_ground {source rows x y} (related : Value source rows x y)
    (range : RangeExpr) (pattern : String) (lo hi : Benitoite.Release.Integer64Value) :
    RequestDelta.run range [.const (.string pattern),.const (.integer lo),.const (.integer hi),x] =
      RequestDelta.run range [.const (.string pattern),.const (.integer lo),.const (.integer hi),y] := by
  by_cases ground : Refinement.groundVal y = true
  · rw [related.eq_of_ground_right ground]
  · have original : Refinement.groundVal x ≠ true := by rwa [related.groundVal]
    simp [RequestDelta.run,ground,original]

/-- 既存の要求検査はground検査を先に行い、成功枝で同じ要求全体を使う。 -/
theorem http_check_run {source rows xs ys} (related : Values source rows xs ys) (range : RangeExpr) :
    RequestDelta.run range xs = RequestDelta.run range ys := by
  cases related with
  | nil => rfl
  | cons first tail => cases first with
    | constant c => cases c with
      | string pattern => cases tail with
        | nil => rfl
        | cons second tail => cases second with
          | constant c => cases c with
            | integer lo => cases tail with
              | nil => rfl
              | cons third tail => cases third with
                | constant c => cases c with
                  | integer hi => cases tail with
                    | nil => rfl
                    | cons request tail => cases tail with
                      | nil => exact check_run_ground request range pattern lo hi
                      | cons _ _ => rfl
                  | _ => rfl
                | _ => rfl
            | _ => rfl
          | _ => rfl
      | _ => rfl
    | _ => rfl

theorem http_check_delta {source rows xs ys} (related : Values source rows xs ys) (name ts es rs) :
    OptionalOutcomeRel source rows (RequestDelta.delta name ts es rs xs) (RequestDelta.delta name ts es rs ys) := by
  unfold RequestDelta.delta
  by_cases active : name = "Http.checkRequestIn" ∧ ts = [] ∧ es = []
  · simp only [ite_eq_left active]
    cases rs with
    | nil => exact .none
    | cons range rest => cases rest with
      | nil =>
        change OptionalOutcomeRel source rows (some (RequestDelta.run range xs)) (some (RequestDelta.run range ys))
        rw [http_check_run related]
        exact .refl _
      | cons _ _ => exact .none
  · simp only [ite_eq_right active]
    exact scope_path_delta related name ts es rs

private theorem retained_value_ground {source rows x y} (related : Value source rows x y)
    (target : Scope.Domain.Target) : ModelHttp.valueRun [.checkedRequest target x] = ModelHttp.valueRun [.checkedRequest target y] := by
  by_cases ground : Refinement.groundVal y = true
  · rw [related.eq_of_ground_right ground]
  · have original : Refinement.groundVal x ≠ true := by rwa [related.groundVal]
    simp [ModelHttp.valueRun,ground,original]

private theorem retained_at_ground {source rows x y} (related : Value source rows x y)
    (range snapshot target) :
    ModelHttp.valueRun [.checkedAt range snapshot target (some x)] = ModelHttp.valueRun [.checkedAt range snapshot target (some y)] := by
  by_cases ground : Refinement.groundVal y = true
  · rw [related.eq_of_ground_right ground]
  · have original : Refinement.groundVal x ≠ true := by rwa [related.groundVal]
    simp [ModelHttp.valueRun,ground,original]

theorem http_value_run {source rows xs ys} (related : Values source rows xs ys) :
    ModelHttp.valueRun xs = ModelHttp.valueRun ys := by
  cases related with
  | nil => rfl
  | cons head tail => cases tail with
    | cons _ _ => cases head with
      | checkedAt request => cases request <;> rfl
      | _ => rfl
    | nil => cases head with
      | checkedRequest request => exact retained_value_ground request _
      | checkedAt request => cases request with
        | none => rfl
        | some request => exact retained_at_ground request _ _ _
      | _ => rfl

theorem http_value_delta {source rows xs ys} (related : Values source rows xs ys) (name ts es rs) :
    OptionalOutcomeRel source rows (RequestDelta.valueDelta name ts es rs xs) (RequestDelta.valueDelta name ts es rs ys) := by
  unfold RequestDelta.valueDelta
  by_cases active : ts = [] ∧ es = []
  · simp only [ite_eq_left active]
    by_cases value : name = "Http.requestInValue"
    · simp only [value,ite_true]
      cases rs with
      | nil => exact .none
      | cons range rest => cases rest with
        | nil => rw [http_value_run related]; exact .refl _
        | cons _ _ => exact .none
    · simp only [value,ite_false]
      by_cases widen : name = "Http.widenRequestIn"
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

theorem scope_response_delta {source rows xs ys} (related : Values source rows xs ys) (name ts es rs) :
    OptionalOutcomeRel source rows (ScopeResponse.delta name ts es rs xs) (ScopeResponse.delta name ts es rs ys) := by
  unfold ScopeResponse.delta
  by_cases path : name = "Scope.checkPathIn"
  · simp only [path,ite_true]; exact scope_path_delta related "Scope.checkPathIn" ts es rs
  · simp only [path,ite_false]
    by_cases request : name = "Http.checkRequestIn"
    · simp only [request,ite_true]; exact http_check_delta related "Http.checkRequestIn" ts es rs
    · simp only [request,ite_false]
      by_cases pathValue : name = "Scope.pathInValue" ∨ name = "Scope.widenPathIn"
      · simp only [ite_eq_left pathValue]; exact scope_value_delta related name ts es rs
      · simp only [ite_eq_right pathValue]
        by_cases requestValue : name = "Http.requestInValue" ∨ name = "Http.widenRequestIn"
        · simp only [ite_eq_left requestValue]; exact http_value_delta related name ts es rs
        · simp only [ite_eq_right requestValue]; exact .none

private theorem default_request_noMint {keys} :
    ValueAvoid keys (embedVal Benitoite.Release.ModelHttp.defaultRequest) := by intro name member; cases member

theorem http_value_noMint {keys values} (avoid : ValuesAvoid keys values) : OutcomeAvoid keys (ModelHttp.valueRun values) := by
  cases values with
  | nil => exact default_request_noMint
  | cons head tail => cases tail with
    | cons _ _ => cases head with
      | checkedAt _ _ _ request => cases request <;> exact default_request_noMint
      | _ => exact default_request_noMint
    | nil =>
      have headAvoid := (ValuesAvoid.cons.mp avoid).1
      cases head with
      | checkedRequest target request =>
        change OutcomeAvoid keys (if Refinement.groundVal request then .val request else .val (embedVal Benitoite.Release.ModelHttp.defaultRequest))
        split
        · exact headAvoid
        · exact default_request_noMint
      | checkedAt range snapshot target request => cases request with
        | none => exact default_request_noMint
        | some request =>
          change OutcomeAvoid keys (if Refinement.groundVal request then .val request else .val (embedVal Benitoite.Release.ModelHttp.defaultRequest))
          split
          · exact headAvoid
          · exact default_request_noMint
      | _ => exact default_request_noMint

local macro "staticErrorImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.RequestDelta
    `Benitoite.Release.Refinement.RequestDelta.staticError))

local macro "unfoldStaticError" : tactic => do
  let implementation := Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.RequestDelta
    `Benitoite.Release.Refinement.RequestDelta.staticError)
  `(tactic| unfold $implementation:ident)

private abbrev providerStaticError : String → Benitoite.Release.Integer64Value → Benitoite.Release.Integer64Value →
    Val → Checked.Scope.CheckedEndpoint → Scope.Domain.Endpoint → RangeExpr → Val := staticErrorImpl

private theorem request_static_noMint {keys} (pattern : String) (lo hi : Benitoite.Release.Integer64Value)
    (request : Val) (checked : Checked.Scope.CheckedEndpoint) (endpoint : Scope.Domain.Endpoint) (range : RangeExpr) :
    ValueAvoid keys (providerStaticError pattern lo hi request checked endpoint range) := by
  unfold providerStaticError
  unfoldStaticError
  repeat' first | exact scope_payload_noMint _ _ _ _ _ _ _ | split

private theorem request_error_noMint {keys value} (avoid : ValueAvoid keys value) (range : RangeExpr) :
    OutcomeAvoid keys (RequestDelta.error range value) := result_value_noMint avoid _ _ _

private theorem request_ok_noMint {keys request} (ground : Refinement.groundVal request = true)
    (range : RangeExpr) (target : Scope.Domain.Target) : OutcomeAvoid keys (RequestDelta.ok range (.checkedRequest target request)) := by
  have held : ValueAvoid keys (.checkedRequest target request) := ground_value_noMint (value := request) ground
  exact result_value_noMint held _ _ _

private theorem request_scope_noMint {keys value} (avoid : ValueAvoid keys value) :
    ValueAvoid keys (RequestDelta.scopeError value) :=
  ValueAvoid.con (ValuesAvoid.cons.mpr ⟨avoid,ValuesAvoid.nil _⟩) _ _

private theorem invalid_url_noMint {keys} : ValueAvoid keys RequestDelta.invalidUrl := by intro name member; cases member
private theorem pattern_noMint {keys} (raw reason : String) : ValueAvoid keys (ScopeDelta.invalidPattern raw reason) := by intro name member; cases member
private theorem target_noMint {keys} (raw reason : String) : ValueAvoid keys (ScopeDelta.invalidTarget raw reason) := by intro name member; cases member

/-- 既存のHTTP検査は定数の診断又はground検査済み要求を返し、禁止名を作らない。 -/
theorem http_check_run_noMint {keys} (range : RangeExpr) (values : List Val) :
    OutcomeAvoid keys (RequestDelta.run range values) := by
  unfold RequestDelta.run
  repeat' first
    | exact request_error_noMint invalid_url_noMint _
    | exact request_error_noMint (request_scope_noMint (pattern_noMint _ _)) _
    | exact request_error_noMint (request_scope_noMint (target_noMint _ _)) _
    | exact request_error_noMint (request_scope_noMint (scope_payload_noMint _ _ _ _ _ _ _)) _
    | exact request_error_noMint (request_scope_noMint (request_static_noMint _ _ _ _ _ _ _)) _
    | exact request_ok_noMint (by assumption) _ _
    | split

theorem http_check_noMint {keys name ts es rs values} : OptionalOutcomeAvoid keys (RequestDelta.delta name ts es rs values) := by
  unfold RequestDelta.delta
  split
  · cases rs with
    | nil => trivial
    | cons range rest => cases rest with
      | nil => exact http_check_run_noMint _ _
      | cons _ _ => trivial
  · exact scope_path_noMint

theorem http_value_delta_noMint {keys name ts es rs values} (avoid : ValuesAvoid keys values) :
    OptionalOutcomeAvoid keys (RequestDelta.valueDelta name ts es rs values) := by
  unfold RequestDelta.valueDelta
  split
  · split
    · cases rs with
      | nil => trivial
      | cons range rest => cases rest with
        | nil => exact http_value_noMint avoid
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

theorem scope_response_noMint {keys name ts es rs values} (avoid : ValuesAvoid keys values) :
    OptionalOutcomeAvoid keys (ScopeResponse.delta name ts es rs values) := by
  unfold ScopeResponse.delta
  split
  · exact scope_path_noMint
  · split
    · exact http_check_noMint
    · split
      · exact scope_value_noMint avoid
      · split
        · exact http_value_delta_noMint avoid
        · trivial

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
