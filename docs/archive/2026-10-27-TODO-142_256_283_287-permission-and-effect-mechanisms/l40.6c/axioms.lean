import Benitoite

open Benitoite

-- 新しい定理（L40.6c）
#print axioms Benitoite.Release.Eff.Covers.shift
#print axioms Benitoite.Release.Eff.Covers.sub_of_noAtoms
#print axioms Benitoite.Release.Eff.Covers.sub_of_singleFail
#print axioms Benitoite.Release.Atom.covers_fixed_fixed
#print axioms Benitoite.Release.Eff.allows_of_mem_covers
#print axioms Benitoite.Release.HasTypeVQ.widen_instTarget_covers
#print axioms Benitoite.Release.HasTypeVsQ.widen_covers
#print axioms Benitoite.Release.Ty.LeOld.le
#print axioms Benitoite.Release.Ty.le_iff_leOld
#print axioms Benitoite.Release.Eff.covers_iff_sub_old

-- 被覆へ言明を変えた補題
#print axioms Benitoite.Release.ContTy.name_end_ix
#print axioms Benitoite.Release.ContTy.split
#print axioms Benitoite.Release.ContTy.resume_append
#print axioms Benitoite.Release.ContTy.end_of_noHandler_ix
#print axioms Benitoite.Release.ContTy.allows_hole_of_split
#print axioms Benitoite.Release.ContTy.allows_clause_end
#print axioms Benitoite.Release.ContTy.split_failure
#print axioms Benitoite.Release.pres_op_common
#print axioms Benitoite.Release.pres_failure
#print axioms Benitoite.Release.preservationE
#print axioms Benitoite.Release.inv_prim_app
#print axioms Benitoite.Release.Ty.Le.fn_fn'
#print axioms Benitoite.Release.ContTy.toOld
#print axioms Benitoite.Release.contTy_exists_iff_old

-- 例
#print axioms Benitoite.Release.CoverExamples.bound_covers_narrow
#print axioms Benitoite.Release.CoverExamples.not_sub_narrow
#print axioms Benitoite.Release.CoverExamples.narrowCall_bound
#print axioms Benitoite.Release.CoverExamples.progCover_wellTyped
#print axioms Benitoite.Release.CoverExamples.callF_reach
#print axioms Benitoite.Release.CoverExamples.callH_reach
#print axioms Benitoite.Release.CoverExamples.callF_reach_target_sound
#print axioms Benitoite.Release.CoverExamples.callH_reach_target_sound
#print axioms Benitoite.Surface.CoverExamples.writeE_bound
#print axioms Benitoite.Surface.CoverExamples.callGE_bound
#print axioms Benitoite.Surface.CoverExamples.program_wellFormed
#print axioms Benitoite.Surface.CoverExamples.program_wellTyped
#print axioms Benitoite.Surface.CoverExamples.program_target_sound

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
#print axioms Benitoite.Surface.ScopeSound.scope_check_connection
#print axioms Benitoite.Surface.ScopeSound.scope_local_connection
#print axioms Benitoite.Surface.ScopeSound.scope_local_typed
