import Benitoite

open Benitoite

-- 新しい定理（L50.2）: 型検査器の入口への受理の組み込みとプログラム全体の受理の述語
#print axioms Benitoite.Surface.CheckAccept.entryScope_valid
#print axioms Benitoite.Surface.CheckAccept.allOk_of_forall
#print axioms Benitoite.Surface.CheckAccept.acceptProgram_sound
#print axioms Benitoite.Surface.CheckAccept.impls_complete
#print axioms Benitoite.Surface.CheckAccept.acceptProgram_sound_names
#print axioms Benitoite.Surface.CheckAccept.acceptFn_noRules
#print axioms Benitoite.Surface.CheckAccept.acceptProgram_noRules
#print axioms Benitoite.Surface.CheckAccept.checkProgramAccepted_ok
#print axioms Benitoite.Surface.CheckAccept.checkProgramAccepted_noRules
#print axioms Benitoite.Surface.CheckAccept.checkProgramAccepted_sound
#print axioms Benitoite.Surface.CheckAccept.checkProgramAccepted_empty
#print axioms Benitoite.Surface.CheckAccept.tableFor_sound
#print axioms Benitoite.Surface.CheckAccept.Accepted.def_body
#print axioms Benitoite.Surface.CheckAccept.accepted_check_connection

-- 新しい定理（L50.2）: 検査器の効果の上限の被覆による受理
#print axioms Benitoite.Surface.CheckTools.Finite.effCovers_sound_of_fails
#print axioms Benitoite.Surface.CheckTools.Finite.effCovers_sound
#print axioms Benitoite.Surface.CheckTools.Finite.effCovers_of_effSub
#print axioms Benitoite.Surface.Check.acceptEffCover_ok
#print axioms Benitoite.Surface.Check.acceptEffCover_sound
#print axioms Benitoite.Surface.Check.acceptEffCover_of_acceptEff
#print axioms Benitoite.Surface.Check.accept_block_effCover

-- 新しい定理（L50.2）: 交換の観測・拒否の理由・必須の判定の入力・範囲の入力の検査
#print axioms Benitoite.Exchange.decodeHostTarget_encode
#print axioms Benitoite.Exchange.decodeTarget_encode
#print axioms Benitoite.Exchange.decodeTargetStrict_ok
#print axioms Benitoite.Exchange.observationAllowed_sound
#print axioms Benitoite.Exchange.decodeCoverFailure_encode
#print axioms Benitoite.Exchange.encodeCoverFailure_injective
#print axioms Benitoite.Exchange.ScopeAcceptanceEntry.acceptInput_sound
#print axioms Benitoite.Exchange.ScopeAcceptanceEntry.acceptInput_none_noRules
#print axioms Benitoite.Exchange.checkRangeInput_sound
#print axioms Benitoite.Exchange.checkRangeInput_complete
#print axioms Benitoite.Exchange.checkIxInput_sound
#print axioms Benitoite.Exchange.checkIxInput_zero
#print axioms Benitoite.Exchange.checkAdmitsRuleInput_sound

-- 証明を変えた既存の定理（検査器の被覆による受理の追随）
#print axioms Benitoite.Surface.CheckTools.Finite.tyLe_sound
#print axioms Benitoite.Surface.CheckTools.tyLe_sound
#print axioms Benitoite.Surface.Check.checkExpr_sound
#print axioms Benitoite.Surface.Check.checkBlock_sound
#print axioms Benitoite.Surface.Check.checkDef_sound
#print axioms Benitoite.Surface.Check.checkImpl_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_under
#print axioms Benitoite.Surface.CheckTables.checkProgram_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_empty

-- 主定理と接続定理（字面は L40.6c の後と同じ）
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
