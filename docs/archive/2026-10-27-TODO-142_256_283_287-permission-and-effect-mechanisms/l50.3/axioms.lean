import Benitoite

-- L50.3 で加えた・言明を変えた定理
#print axioms Benitoite.Release.PrimSig.scoped_iff
#print axioms Benitoite.Surface.ScopeState.checkedOk_target
#print axioms Benitoite.Surface.ScopeState.requestOk_target
#print axioms Benitoite.Surface.ScopeState.checkDelta_contract
#print axioms Benitoite.Surface.ScopeState.checkDelta_ok_mem
#print axioms Benitoite.Surface.ScopeState.checkDelta_known_redundant
#print axioms Benitoite.Surface.ScopeState.Boundary.rules_sound
#print axioms Benitoite.Surface.ScopeState.Boundary.rules_sound_lit
#print axioms Benitoite.Surface.desugar_checkDelta_mem
#print axioms Benitoite.Surface.ScopeSound.modelTargets_checkRun_checkedOk
#print axioms Benitoite.Surface.ScopeSound.modelHttp_checkRun_requestOk
#print axioms Benitoite.Surface.ScopeSound.scope_local_typed_of_typed
#print axioms Benitoite.Release.ModelTargets.ok_typed
#print axioms Benitoite.Release.ModelTargets.err_typed
#print axioms Benitoite.Release.ModelTargets.singleton_of_admissible
#print axioms Benitoite.Release.ModelTargets.assumptions
#print axioms Benitoite.Release.ModelHttp.assumptions
#print axioms Benitoite.Release.ModelHttp.Examples.sendState_target_sound
#print axioms Benitoite.Release.ContTyOld.toNew

-- 主定理と接続定理（字面は L50.2 の後と同じ）
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.step_target_sound
#print axioms Benitoite.Release.reachable_target_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
#print axioms Benitoite.Surface.surface_target_sound
#print axioms Benitoite.Surface.ScopeSound.scope_check_connection
#print axioms Benitoite.Surface.ScopeSound.scope_local_connection
#print axioms Benitoite.Surface.ScopeSound.scope_local_typed
#print axioms Benitoite.Surface.CheckAccept.checkProgramAccepted_sound
