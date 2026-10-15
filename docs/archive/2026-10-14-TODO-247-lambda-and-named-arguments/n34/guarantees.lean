import Benitoite

-- 正式化後の名前で同じ結論を参照し、公理依存を確認するための独立した検査。
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.effect_soundness_noLamNames
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
#print axioms Benitoite.Surface.Check.checkExpr_sound
#print axioms Benitoite.Surface.Check.checkBlock_sound
#print axioms Benitoite.Surface.Check.checkImpl_contracts
#print axioms Benitoite.Surface.CheckTables.checkProgram_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_contracts
#print axioms Benitoite.Release.checkMatch_exhaustive_sound
#print axioms Benitoite.Release.checkMatch_unreachable_sound
#print axioms Benitoite.Release.irrefutable_sound
#print axioms Benitoite.Surface.CallOk.recordFields_source
