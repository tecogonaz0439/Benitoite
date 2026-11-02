# 追加宣言の一覧

ソースの手書き宣言で数える。生成された再帰子・補助定数は公理監査で別に数える。

| モジュール | 追加宣言（private を含む） |
|---|---|
| `StepLeafSelection` | `Builtins.selectOracle`、`Builtins.selectRelease`、`Store.selectFresh`、`Builtins.selectOracle_response`、`Builtins.selectRelease_response`、`StoreOk.selectFresh_empty`、`step_pure_selected`、`step_io_selected`、`ContTy.selected_release`、`step_builder_new_selected`、`step_lazy_selected`、`SplitAt.splitHandler_some`、`step_ref_new_selected`、`step_op_selected`、`step_raise_selected`、`step_prim_handler_selected`、`FreshStepInputs`、`step_fresh_selected`、`step_release_selected`、`StateTyE.selected_primitive_step`、`ContTy.selected_release_step` |
| `FunctionViewGeneral` | `Tel.function_view_contract`、`CaptureOk.termBind_success`、`HasTypeVQ.captured_observation` |
| `ControlLeafSelection` | `ControlLeafInputs`、`StateTyE.control_leaf`、`control_for_model`、`other_control_for_model`、`concrete_other_control_leaves`、`concrete_control_leaf` |
| `IntervalConnection` | `rangeErrorFields`、`ValueRel`、`ValuesRel`、`EnvValuesRel`、`EnvRel`、`ExprCode`、`BlockCode`、`ArmsCode`、`ResultRel`、`EndState`、`Runs`、`ValueRel.integer`、`ValueRel.toApprox_eq`、`ValueRel.con_inv`、`ValueRel.close`、`ValuesRel.close`、`EnvRel.extend`、`EnvRel.extendMany`、`EnvRel.length`、`EndState.result`、`steps_trans`、`single`、`Runs.let_normal`、`Runs.let_returned`、`Runs.let_failed`、`Runs.return_operand`、`Runs.returned_mark`、`connect_return`、`connect_bind`、`runs_match_body`、`runs_guard_true`、`runs_guard_false`、`runs_guard_failed`、`normal_shared_iff`、`const_integer_exact`、`const_integer_same_value`、`EnvRelAt`、`envValues_lookup`、`EnvRel.at`、`EnvRelAt.insert`、`EnvRelAt.extend`、`upRen_zero`、`upRen_nested`、`EnvRelAt.extendMany`、`ArmBodyConnection`、`MatchRel`、`values_lookup`、`slots_related`、`result_pattern_related`、`firstResultAlt`、`first_result_related`、`result_selection_first`、`result_selection_related`、`connect_integer_arm`、`connect_width_arm`、`connect_result_arm`、`runs_match_skip`、`runs_match_guard`、`ArmInput`、`ArmInput.Eval`、`ArmInput.Selection`、`ArmInput.Miss`、`connect_arm_skip`、`connect_arm_guard_true`、`connect_arm_guard_false`、`TrackedFailure`、`connect_bind_failed`、`arms_code_cons`、`typed_returned_mark` |
| `IntervalConnectionExamples` | `env`、`key`、`op`、`failures`、`body`、`source`、`code`、`unitRel`、`atom`、`binding_and_return`、`integer_values`、`alternative`、`alts`、`integer`、`integerVal`、`integerCore`、`integerRel`、`integer_arm`、`width_arm`、`names`、`result`、`result_arm`、`result_tag_contrast`、`guardArms`、`guardFrame`、`guards`、`sampleInput`、`sampleValue`、`sampleRuntime`、`fallback`、`guardedRuntime`、`sample_selection`、`sample_relation`、`fallback_eval`、`independent_arm_guards`、`missed`、`independent_arm_skip`、`minimum`、`overflowEnv`、`overflowTrace`、`tracked_failure_contrast`、`failedSource`、`failedCode`、`used`、`failed_eval`、`failed_run`、`failure_propagation`、`skipped_arm`、`arm_code_and_environment`、`inserted_scrutinee`、`result_constructors`、`unit_escape`、`concrete_interval_control`、`view_observation_model`、`concrete_view_observation` |
| `IntervalRelationBoundary` | `ValueShape`、`ValueRel.shape`、`ground_signature_obstruction`、`escape_source`、`marked_signature_obstruction` |
| `HandlerGeneral` | `escape_value`、`ClosureTy.escape_view_value`、`ContTy.handler_tail_annotated` |
| `StateLeaves` | `let_result_annotation`、`StateTyE.escape_let`、`StateTyE.escape_handler`、`StateTyE.escape_mark`、`StateTyE.error_let`、`StateTyE.exit_let`、`StateTyE.error_mark`、`StateTyE.exit_mark` |
| `NormalReplyExamples` | `concrete_step_selections` |
| `HandlerStoreExamples` | `concrete_release_selection`、`concrete_fresh_operation`、`concrete_release_frames` |

## 既定ビルドの外の補助 Lean

完全名で示す。同じ H04 の定義を二ファイルで検査し、validate.py がその一致を確かめる。既定モジュールの174宣言には数えない。

### h04-handoff.lean

- `Benitoite.Release.Refinement.IntervalConnection.H04.BeforeError`
- `Benitoite.Release.Refinement.IntervalConnection.H04.BeforeErrorSteps`
- `Benitoite.Release.Refinement.IntervalConnection.H04.FirstFailureHandoff`

### h04-counterexample.lean

- `Benitoite.Release.Refinement.IntervalConnection.H04.BeforeError`
- `Benitoite.Release.Refinement.IntervalConnection.H04.BeforeErrorSteps`
- `Benitoite.Release.Refinement.IntervalConnection.H04.FirstFailureHandoff`
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.OldH04`
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.one`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.minusOne`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.minimum`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.env`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.cap`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.key`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.left`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.right`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.input`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.op`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.sig`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.B`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.P`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.leftEvent`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.rightEvent`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.trace`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.code`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.independent`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.environment`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.tracked`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.runtime`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.no_later_delta`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.old_candidate_false`
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.first_error`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.pure_failure`（private）
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.revised_candidate_valid`
- `Benitoite.Release.Refinement.IntervalConnection.H04Counterexample.revised_counterexample_accepted`

