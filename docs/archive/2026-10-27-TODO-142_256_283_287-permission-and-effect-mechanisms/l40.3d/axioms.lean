import Benitoite

-- L40.3d: 直した・置いた定理と、それに依る定理と主定理の公理の依存。
section
-- 主定理（言明は B_WORK と同じ）
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
#print axioms Benitoite.Release.step_target_sound
#print axioms Benitoite.Release.reachable_target_sound
-- 直した定理と置いた定理
#print axioms Benitoite.Surface.ScopeState.requestLitBound_boundSound
#print axioms Benitoite.Surface.ScopeState.requestLitBound_known_ports_wf
#print axioms Benitoite.Surface.ScopeState.requestLitBound_known_wf
-- requestLitBound_boundSound に依る定理
#print axioms Benitoite.Surface.ScopeState.Boundary.rules_sound_lit
#print axioms Benitoite.Surface.ScopeSound.productionRules_sound
#print axioms Benitoite.Surface.ScopeSound.http_check_connection
#print axioms Benitoite.Exchange.ScopeAcceptanceEntry.acceptInput_sound
end
