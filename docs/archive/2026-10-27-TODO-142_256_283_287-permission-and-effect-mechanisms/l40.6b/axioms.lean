import Benitoite

open Benitoite

-- 新しい定理（L40.6b）
#print axioms Benitoite.Surface.ClauseIxExamples.wide_clauseIx
#print axioms Benitoite.Surface.ClauseIxExamples.wide_sig
#print axioms Benitoite.Surface.ClauseIxExamples.top_clause_typed
#print axioms Benitoite.Surface.ScopeAccept.acceptRanges_iff
#print axioms Benitoite.Surface.ScopeAccept.acceptRanges_some
#print axioms Benitoite.Surface.ScopeAccept.acceptCall_some
#print axioms Benitoite.Surface.ScopeAccept.acceptBody_some
#print axioms Benitoite.Surface.ScopeSound.scope_check_range
#print axioms Benitoite.Surface.ScopeSound.scope_local_range

-- 定義（acceptRanges）を変えたので証明を検査し直した既存の定理と例
#print axioms Benitoite.Surface.ScopeAccept.acceptRanges_sound
#print axioms Benitoite.Surface.ScopeAccept.acceptCall_sound
#print axioms Benitoite.Surface.ScopeAccept.acceptCall_sound_unrecorded
#print axioms Benitoite.Surface.ScopeAccept.acceptCall_top_of_top
#print axioms Benitoite.Surface.ScopeAccept.acceptBody_sound
#print axioms Benitoite.Surface.ScopeSound.scope_check_connection
#print axioms Benitoite.Surface.ScopeSound.scope_local_connection
#print axioms Benitoite.Surface.ScopeSound.scope_local_typed
#print axioms Benitoite.Surface.ScopeSound.scope_check_core
#print axioms Benitoite.Surface.ScopeSound.http_check_connection
#print axioms Benitoite.Surface.ScopeSoundExamples.body_accepted
#print axioms Benitoite.Surface.ScopeSoundExamples.budget_top_only

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
#print axioms Benitoite.Surface.surface_target_sound
