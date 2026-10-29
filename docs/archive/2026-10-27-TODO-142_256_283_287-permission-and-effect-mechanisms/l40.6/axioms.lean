import Benitoite

open Benitoite

-- 新しい定理（L40.6）
#print axioms Benitoite.Surface.ScopeSound.deltaRun_eq_some
#print axioms Benitoite.Surface.ScopeSound.evalScope_core_step
#print axioms Benitoite.Surface.ScopeSound.evalScope_of_delta
#print axioms Benitoite.Surface.ScopeSound.okPayload_eq_some
#print axioms Benitoite.Surface.ScopeSound.mem_kind
#print axioms Benitoite.Surface.ScopeSound.rhsEval_prim
#print axioms Benitoite.Surface.ScopeSound.scope_check_connection
#print axioms Benitoite.Surface.ScopeSound.scope_local_connection
#print axioms Benitoite.Surface.ScopeSound.projectRule_index
#print axioms Benitoite.Surface.ScopeSound.widenRule_index
#print axioms Benitoite.Surface.ScopeSound.scope_local_typed
#print axioms Benitoite.Surface.ScopeSound.pathInValue_inst_params
#print axioms Benitoite.Surface.ScopeSound.requestInValue_inst_params
#print axioms Benitoite.Surface.ScopeSound.widenRequestIn_inst_params
#print axioms Benitoite.Surface.ScopeSound.checkPathIn_inst_ret
#print axioms Benitoite.Surface.ScopeSound.scope_check_core
#print axioms Benitoite.Surface.ScopeSound.requestCheck_pattern_hostPatOf
#print axioms Benitoite.Surface.ScopeSound.modelTargets_contract
#print axioms Benitoite.Surface.ScopeSound.modelHttp_contract
#print axioms Benitoite.Surface.ScopeSound.modelHttp_ok_request
#print axioms Benitoite.Surface.ScopeSound.productionRules_sound
#print axioms Benitoite.Surface.ScopeSound.http_check_connection
#print axioms Benitoite.Surface.ScopeSound.CheckedPath.hasTypeV
#print axioms Benitoite.Surface.ScopeSound.CheckedPath.hasTypeV_of_covers
#print axioms Benitoite.Surface.ScopeSound.CheckedEndpoint.hasTypeV
#print axioms Benitoite.Surface.ScopeSound.CheckedEndpoint.hasTypeV_of_covers
#print axioms Benitoite.Surface.ScopeSound.makePath_checkRun
#print axioms Benitoite.Surface.ScopeSound.makeEndpoint_checkRun
#print axioms Benitoite.Surface.surface_target_sound
#print axioms Benitoite.Surface.main_typed_eff
#print axioms Benitoite.Surface.ScopeState.target_hasTypeV
-- 例（L40.6）
#print axioms Benitoite.Surface.ScopeSoundExamples.table_sound
#print axioms Benitoite.Surface.ScopeSoundExamples.ok_of_reasonOf
#print axioms Benitoite.Surface.ScopeSoundExamples.body_accepted
#print axioms Benitoite.Surface.ScopeSoundExamples.occ_check
#print axioms Benitoite.Surface.ScopeSoundExamples.occ_proj
#print axioms Benitoite.Surface.ScopeSoundExamples.proj_args
#print axioms Benitoite.Surface.ScopeSoundExamples.record7
#print axioms Benitoite.Surface.ScopeSoundExamples.rule7
#print axioms Benitoite.Surface.ScopeSoundExamples.rule1
#print axioms Benitoite.Surface.ScopeSoundExamples.proj_arg_in_data
#print axioms Benitoite.Surface.ScopeSoundExamples.proj_arg_typed
#print axioms Benitoite.Surface.ScopeSoundExamples.check_ok_in_data
#print axioms Benitoite.Surface.ScopeSoundExamples.check_core_step
#print axioms Benitoite.Surface.ScopeSoundExamples.old_ip_inside
#print axioms Benitoite.Surface.ScopeSoundExamples.old_ip_outside
#print axioms Benitoite.Surface.ScopeSoundExamples.new_ip_inside
#print axioms Benitoite.Surface.ScopeSoundExamples.new_ip_outside
#print axioms Benitoite.Surface.ScopeSoundExamples.old_ip_typed
#print axioms Benitoite.Surface.ScopeSoundExamples.budget_top_only
#print axioms Benitoite.Surface.ScopeSoundExamples.required_independent_of_range
-- 言明を変えた既存の定理（L40.6）
#print axioms Benitoite.Surface.ScopeState.checkedModels_iff
#print axioms Benitoite.Surface.ScopeState.checkedModels_hasTypeV
#print axioms Benitoite.Surface.ScopeState.argIndex_sound
#print axioms Benitoite.Surface.ScopeState.requiredIndex_checked
#print axioms Benitoite.Surface.ScopeState.requiredIndex_hasTypeV
#print axioms Benitoite.Surface.ScopeState.checkRule_sound
#print axioms Benitoite.Surface.ScopeState.checkDelta_contract
#print axioms Benitoite.Surface.ScopeState.checkDelta_ok_mem
#print axioms Benitoite.Surface.ScopeLower.analyzeBody_requiredIndex
#print axioms Benitoite.Surface.ScopeStateExamples.check_checked
#print axioms Benitoite.Surface.ScopeLowerExamples.body1_checked
#print axioms Benitoite.Surface.desugar_checkDelta_mem
-- 主定理
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.step_target_sound
#print axioms Benitoite.Release.reachable_target_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
