import Benitoite

-- 主定理（四主定理と step_sound・effect_soundness_noLamNames・表層の二定理）
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness

-- 一段の対象健全性（L30.4）と到達先の対象健全性（L30.5）
#print axioms Benitoite.Release.step_target_sound
#print axioms Benitoite.Release.step_target_sound_of_assumptions
#print axioms Benitoite.Release.step_target_sound_event
#print axioms Benitoite.Release.reachable_target_sound
#print axioms Benitoite.Release.reachable_target_sound_event
#print axioms Benitoite.Release.reachable_target_sound_of_assumptions

-- L30.5 の例と反例
#print axioms Benitoite.Release.TargetReachExamples.ioCall_reach_target_sound
#print axioms Benitoite.Release.TargetReachExamples.ioCall_no_passwd
#print axioms Benitoite.Release.TargetReachExamples.handleLog_reach_target_sound
#print axioms Benitoite.Release.TargetReachExamples.handleLog_never_observes_data
#print axioms Benitoite.Release.TargetReachExamples.clauseIxOk_bodyData_iff
#print axioms Benitoite.Release.TargetReachExamples.etc_not_clauseIxOk
#print axioms Benitoite.Release.TargetReachExamples.wrong_of_clauseSig
#print axioms Benitoite.Release.TargetReachExamples.opSigAt_etc
#print axioms Benitoite.Release.TargetReachExamples.write_admissible_etc
#print axioms Benitoite.Release.TargetReachExamples.wrong_rule_admits
#print axioms Benitoite.Release.TargetReachExamples.handleEtc_closed
#print axioms Benitoite.Release.TargetReachExamples.etcCall_inst
#print axioms Benitoite.Release.TargetReachExamples.reach_etc
#print axioms Benitoite.Release.TargetReachExamples.sEtc_step
#print axioms Benitoite.Release.TargetReachExamples.etcBound_not_allows_data
#print axioms Benitoite.Release.TargetReachExamples.wrong_rule_unsound
#print axioms Benitoite.Release.TargetReachExamples.handleEtc_typed_allows
#print axioms Benitoite.Release.TargetReachExamples.handleEtc_rejected
