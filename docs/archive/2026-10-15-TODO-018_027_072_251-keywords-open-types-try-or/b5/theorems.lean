import Benitoite

/-! B5 の定義・言明のレビュー用。通常のビルドからは参照しない。 -/

#print axioms Benitoite.Core.progress
#print axioms Benitoite.Core.preservation
#print axioms Benitoite.Core.effect_soundness
#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Surface.DieShowOk
#print axioms Benitoite.Surface.DieExitOk
#print axioms Benitoite.Surface.HasType.E_TryResultDie
#print axioms Benitoite.Surface.HasType.E_TryOptionDie
#print axioms Benitoite.Surface.dieFailure
#print axioms Benitoite.Surface.HasTypeC.withReturn
#print axioms Benitoite.Surface.HasTypeArms.withReturn
#print axioms Benitoite.Surface.HasTypeClauses.withReturn
#print axioms Benitoite.Surface.dieMessage_typed
#print axioms Benitoite.Surface.DieExitOk.app_typed
#print axioms Benitoite.Surface.dieFailure_typed
#print axioms Benitoite.Surface.desugar_tryResultDie
#print axioms Benitoite.Surface.desugar_tryOptionDie
#print axioms Benitoite.Surface.tryResultDie_typed
#print axioms Benitoite.Surface.tryOptionDie_typed
#print axioms Benitoite.Surface.HasType.desugar
#print axioms Benitoite.Surface.HasType.desugar_scoped
#print axioms Benitoite.Surface.HasType.clean
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
#print axioms Benitoite.Surface.Check.checkDieShow_sound
#print axioms Benitoite.Surface.Check.checkDieExit_sound
#print axioms Benitoite.Surface.Check.checkDieMessageR_sound
#print axioms Benitoite.Surface.Check.tryResultDie_case
#print axioms Benitoite.Surface.Check.tryOptionDie_case
#print axioms Benitoite.Surface.Check.checkCasesSound
#print axioms Benitoite.Surface.Check.checkExpr_sound
#print axioms Benitoite.Surface.Check.checkDef_sound
#print axioms Benitoite.Surface.Check.checkImpl_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_under
#print axioms Benitoite.Surface.CheckTables.checkProgram_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_empty
#print axioms Benitoite.Surface.CheckTables.checkProgram_sound_contracts
#print axioms Benitoite.Surface.CheckTables.checkProgram_empty_contracts
#print axioms Benitoite.Exchange.readCorpus
#print axioms Benitoite.Exchange.Input.operationProgram
#print axioms Benitoite.Exchange.CheckInput.prepare
