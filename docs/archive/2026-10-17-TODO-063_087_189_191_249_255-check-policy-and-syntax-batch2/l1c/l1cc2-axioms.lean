import Benitoite
import Benitoite.Release.Theorems
import Benitoite.Surface.Theorems
import Benitoite.Surface.CheckProgramSound
import Benitoite.Release.CoverageExtension
import Benitoite.Release.Lemmas.CoverageRuntime

#print axioms Benitoite.Release.progress
#print axioms Benitoite.Release.preservation
#print axioms Benitoite.Release.effect_soundness
#print axioms Benitoite.Release.step_sound
#print axioms Benitoite.Surface.desugar_typed
#print axioms Benitoite.Surface.surface_effect_soundness
#print axioms Benitoite.Release.checkMatchWithView_exhaustive_sound
#print axioms Benitoite.Release.irrefutableWithView_sound
#print axioms Benitoite.Release.checkMatchWithView_unreachable_sound
#print axioms Benitoite.Release.checkMatchWithView_unreachable_runtime
#print axioms Benitoite.Release.usefulWithView_extension_exhaustive
#print axioms Benitoite.Surface.Check.checkExpr_sound
#print axioms Benitoite.Surface.Check.checkBlock_sound
#print axioms Benitoite.Surface.Check.checkArms_sound
#print axioms Benitoite.Surface.Check.checkClauses_sound
#print axioms Benitoite.Surface.Check.checkTypes_sound
#print axioms Benitoite.Surface.Check.checkEach_sound
#print axioms Benitoite.Surface.Check.checkHoleArgs_sound
#print axioms Benitoite.Surface.Check.checkDict_sound
#print axioms Benitoite.Surface.Check.checkDicts_sound
#print axioms Benitoite.Surface.Check.checkDef_sound
#print axioms Benitoite.Surface.Check.checkImpl_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_sound
#print axioms Benitoite.Surface.CheckTables.checkProgram_empty

#print axioms Benitoite.Release.atomsCompareWith_eq_compare
#print axioms Benitoite.Release.compareWith_eq_compare
#print axioms Benitoite.Release.Eff.normWith_eq_norm_of_fails
#print axioms Benitoite.Release.Ty.normWith_eq_norm
#print axioms Benitoite.Release.Ty.normWith_legacy
#print axioms Benitoite.Release.Ty.normWith_idem
#print axioms Benitoite.Release.Ty.normWith_support_independent
#print axioms Benitoite.Release.Ty.collectAtoms_complete
#print axioms Benitoite.Release.Ty.collectAtoms_sound
#print axioms Benitoite.Release.Ty.support_of_norm
#print axioms Benitoite.Release.Eff.support_of_sub
#print axioms Benitoite.Surface.CheckTools.Finite.tyEq_sound
#print axioms Benitoite.Surface.CheckTools.Finite.effEq_sound
#print axioms Benitoite.Surface.CheckTools.Finite.substTyAt_eq
#print axioms Benitoite.Surface.CheckTools.Finite.substEffAt_eq
#print axioms Benitoite.Surface.CheckTools.Finite.effSub_spec
#print axioms Benitoite.Surface.CheckTools.Finite.effSub_sound_of_fails
#print axioms Benitoite.Surface.CheckTools.Finite.tyJoin_sound
#print axioms Benitoite.Surface.CheckTools.Finite.tyJoin_support
#print axioms Benitoite.Surface.CheckTools.Finite.wfTy_spec
#print axioms Benitoite.Surface.CheckTools.Finite.cleanTy_spec
#check @Benitoite.Surface.CheckTools.Finite.tyEq_sound
#check @Benitoite.Surface.CheckTools.Finite.effEq_sound

#print axioms Benitoite.Surface.Check.nodeComputes
#print axioms Benitoite.Surface.Check.checkExprR_computes
#print axioms Benitoite.Surface.Check.checkBlockR_computes
#print axioms Benitoite.Surface.Check.checkClausesR_computes
#print axioms Benitoite.Surface.Check.inferClauseTypesR_computes
#print axioms Benitoite.Surface.Check.handlerStep_atoms
