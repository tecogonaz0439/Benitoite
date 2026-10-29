import Benitoite

-- L40.2: Benitoite/Surface/ScopeState.lean の全ての theorem（Benitoite.Surface.ScopeState）
#print axioms Benitoite.Surface.ScopeState.checkedModels_iff
#print axioms Benitoite.Surface.ScopeState.checkedModels_hasTypeV
#print axioms Benitoite.Surface.ScopeState.argIndex_readLocal
#print axioms Benitoite.Surface.ScopeState.argIndex_sound
#print axioms Benitoite.Surface.ScopeState.requiredIndex_checked
#print axioms Benitoite.Surface.ScopeState.requiredIndex_hasTypeV
#print axioms Benitoite.Surface.ScopeState.checkRule_sound
#print axioms Benitoite.Surface.ScopeState.checkRule_index_agrees
#print axioms Benitoite.Surface.ScopeState.checkDelta_contract
#print axioms Benitoite.Surface.ScopeState.checkDelta_ok_mem
#print axioms Benitoite.Surface.ScopeState.checkDelta_known_redundant
#print axioms Benitoite.Surface.ScopeState.pathCheck_boundSound
#print axioms Benitoite.Surface.ScopeState.requestCheck_unknown_boundSound
#print axioms Benitoite.Surface.ScopeState.projectRule_sound
#print axioms Benitoite.Surface.ScopeState.widenRule_sound
#print axioms Benitoite.Surface.ScopeState.widenRun_same
#print axioms Benitoite.Surface.ScopeState.widenRun_memK
#print axioms Benitoite.Surface.ScopeState.widenRun_hasTypeV
#print axioms Benitoite.Surface.ScopeState.standardTable_apiAt
#print axioms Benitoite.Surface.ScopeState.standardTable_user_ruleAt
#print axioms Benitoite.Surface.ScopeState.standardTable_user
#print axioms Benitoite.Surface.ScopeState.Rules.lookup_mem
#print axioms Benitoite.Surface.ScopeState.Rules.lookup_sound
#print axioms Benitoite.Surface.ScopeState.standardTable_apply_sound
#print axioms Benitoite.Surface.ScopeState.Boundary.rules_sound
#print axioms Benitoite.Surface.ScopeState.absArgs_models
#print axioms Benitoite.Surface.ScopeState.absStep_sound
#print axioms Benitoite.Surface.ScopeState.absSteps_sound
#print axioms Benitoite.Surface.ScopeState.Budget.admit_ok
#print axioms Benitoite.Surface.ScopeState.Budget.admit_error
#print axioms Benitoite.Surface.ScopeState.Budget.enter_whole
#print axioms Benitoite.Surface.ScopeState.Budget.leave_whole
#print axioms Benitoite.Surface.ScopeState.Budget.leave_body
#print axioms Benitoite.Surface.ScopeState.noFacts_forgetAll
#print axioms Benitoite.Surface.ScopeState.noFacts_empty
#print axioms Benitoite.Surface.ScopeState.noFacts_blindStep
#print axioms Benitoite.Surface.ScopeState.noFacts_requiredIndex
#print axioms Benitoite.Surface.ScopeState.Run.step_good
#print axioms Benitoite.Surface.ScopeState.Run.steps_good
#print axioms Benitoite.Surface.ScopeState.Run.enter_good
#print axioms Benitoite.Surface.ScopeState.Run.leave_good
#print axioms Benitoite.Surface.ScopeState.Run.exceeded_requiredIndex
#print axioms Benitoite.Surface.ScopeState.Run.steps_stopped
#print axioms Benitoite.Surface.ScopeState.Run.steps_running
#print axioms Benitoite.Surface.ScopeState.blindStep_models
#print axioms Benitoite.Surface.ScopeState.Run.step_models
#print axioms Benitoite.Surface.ScopeState.Run.steps_models
#print axioms Benitoite.Surface.ScopeState.Run.enter_models
#print axioms Benitoite.Surface.ScopeState.Run.leave_models
#print axioms Benitoite.Surface.ScopeState.Run.leave_exceeded
#print axioms Benitoite.Surface.ScopeState.Analyses.toLocalState_toScope
#print axioms Benitoite.Surface.ScopeState.Analyses.required_range_independent
#print axioms Benitoite.Surface.ScopeState.Analyses.stepScope_separate
#print axioms Benitoite.Surface.ScopeState.Analyses.chargeRange_scope
#print axioms Benitoite.Surface.ScopeState.Analyses.localState_range_independent

-- L40.2: Benitoite/Surface/ScopeStateExamples.lean の全ての theorem（Benitoite.Surface.ScopeStateExamples）
#print axioms Benitoite.Surface.ScopeStateExamples.table_sound
#print axioms Benitoite.Surface.ScopeStateExamples.user_not_identified
#print axioms Benitoite.Surface.ScopeStateExamples.check_checked
#print axioms Benitoite.Surface.ScopeStateExamples.delta_ok
#print axioms Benitoite.Surface.ScopeStateExamples.delta_outside
#print axioms Benitoite.Surface.ScopeStateExamples.delta_top_same
#print axioms Benitoite.Surface.ScopeStateExamples.widen_root
#print axioms Benitoite.Surface.ScopeStateExamples.widen_not_covered
#print axioms Benitoite.Surface.ScopeStateExamples.budgeted_sound

-- 旧の主定理（変えていないことの確かめ）
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
