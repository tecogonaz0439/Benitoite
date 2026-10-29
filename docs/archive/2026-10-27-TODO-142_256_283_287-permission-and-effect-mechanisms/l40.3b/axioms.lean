import Benitoite

-- L40.3b: 主定理と、追加・変更した定理の公理の依存。
open Benitoite.Release in
section
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
#print axioms Benitoite.Release.step_target_sound
#print axioms Benitoite.Release.reachable_target_sound
-- 逆転・標準形・拡大
#print axioms Benitoite.Release.HasTypeVQ.inv_checkedRequest
#print axioms Benitoite.Release.HasTypeVQ.inv_checked
#print axioms Benitoite.Release.HasTypeVQ.checkedRequest_iff
#print axioms Benitoite.Release.HasTypeVQ.checkedRequest_widen
#print axioms Benitoite.Release.HasTypeVQ.canonical_opaque
#print axioms Benitoite.Release.HasTypeVQ.widen_opaque
#print axioms Benitoite.Release.HasTypeVQ.widen_opaque_top
-- 旧の像
#print axioms Benitoite.Release.HasTypeVQ.not_checkedRequest_of_noValKind
#print axioms Benitoite.Release.HasTypeVQ.not_checkedRequest_of_noValContent
#print axioms Benitoite.Release.HasTypeVQ.canonical_opaque_of_noValKind
#print axioms Benitoite.Release.release_exists_iff_old
#print axioms Benitoite.Release.Inhabits.opaque_iff
#print axioms Benitoite.Release.Exhaustive.opaqueTop_iff
#print axioms Benitoite.Release.Pat.catchAll_of_matches_checked
#print axioms Benitoite.Release.Exhaustive.opaque_iff_noRequest
#print axioms Benitoite.Release.ModelHttp.model_noValContent
#print axioms Benitoite.Release.ModelHttp.modelTargets_noValContent
-- 観測の許可
#print axioms Benitoite.Release.Builtins.TargetAgreement.obs_allowed
-- Http の実例
#print axioms Benitoite.Release.ModelHttp.checkRun_typed
#print axioms Benitoite.Release.ModelHttp.checkRun_contract
#print axioms Benitoite.Release.ModelHttp.valueRun_typed
#print axioms Benitoite.Release.ModelHttp.assumptions
#print axioms Benitoite.Release.ModelHttp.check_send_preserves
#print axioms Benitoite.Release.ModelHttp.Examples.check_ok
#print axioms Benitoite.Release.ModelHttp.Examples.check_range_rejects
#print axioms Benitoite.Release.ModelHttp.Examples.check_invalid_url
#print axioms Benitoite.Release.ModelHttp.Examples.value_ok
#print axioms Benitoite.Release.ModelHttp.Examples.check_then_send
#print axioms Benitoite.Release.ModelHttp.Examples.httpProg_wellFormed
#print axioms Benitoite.Release.ModelHttp.Examples.httpProg_assumptions
#print axioms Benitoite.Release.ModelHttp.Examples.checkedReq_typed
#print axioms Benitoite.Release.ModelHttp.Examples.checkedReq_not_other
#print axioms Benitoite.Release.ModelHttp.Examples.sendCall_typed
#print axioms Benitoite.Release.ModelHttp.Examples.sendState_typedE
#print axioms Benitoite.Release.ModelHttp.Examples.sendState_step
#print axioms Benitoite.Release.ModelHttp.Examples.check_step
#print axioms Benitoite.Release.ModelHttp.Examples.value_step
#print axioms Benitoite.Release.ModelHttp.Examples.send_io_target
#print axioms Benitoite.Release.ModelHttp.Examples.sendState_target_sound
#print axioms Benitoite.Release.ModelHttp.Examples.sendState_reachable_target_sound
#print axioms Benitoite.Release.ModelHttp.Examples.other_not_allows
#print axioms Benitoite.Release.ModelTargets.assumptions
-- 場合を足した宣言（抜き取り）
#print axioms Benitoite.Release.HasTypeVQ.rename
#print axioms Benitoite.Release.HasTypeVQ.subst
#print axioms Benitoite.Release.HasTypeVQ.substTy
#print axioms Benitoite.Release.HasTypeVQ.inhabits'
#print axioms Benitoite.Release.HasTypeVQ.inv_lam_wf
#print axioms Benitoite.Release.HasTypeVQ.inv_list_wf
#print axioms Benitoite.Release.HasTypeVQ.inv_raise
#print axioms Benitoite.Release.superStep_super_typed
#print axioms Benitoite.Release.Pat.matchVal_closed
#print axioms Benitoite.Release.Coverage.inhabits_erase_transfer
#print axioms Benitoite.Release.Inhabits.of_substAt
#print axioms Benitoite.Surface.Inhabits.consCongr
#print axioms Benitoite.Release.Model.lambda_names_wellFormed
end
