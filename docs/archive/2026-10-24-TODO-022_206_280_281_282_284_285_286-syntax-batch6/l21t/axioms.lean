import Benitoite.Interval.BudgetWhole
import Benitoite.Interval.Sound

#print axioms Benitoite.Interval.analyzeDivMod_normal_sound
#print axioms Benitoite.Interval.analyzeDivMod_warning_sound
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeBody_property
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeBody_normal
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeBody_warning_sound
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeBody_warning_located
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeBody_independent_segment
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeBody_independent_located
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeExpr_independent_sound
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeBody_independent_sound
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeExpr_warning_located
#print axioms Benitoite.Interval.BudgetAnalysis.analyze_warning_located
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeExpr_normal
#print axioms Benitoite.Interval.BudgetAnalysis.analyze_normal_sound
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeExpr_warning_syntactic_reach
#print axioms Benitoite.Interval.BudgetAnalysis.analyze_warning_syntactic_reach
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeBody_warning_syntactic_reach
#print axioms Benitoite.Interval.BudgetAnalysis.analyzeExpr_warning_sound
#print axioms Benitoite.Interval.BudgetAnalysis.analyze_warning_sound
#print axioms Benitoite.Interval.analyzeGuardedBody_unreachable
#print axioms Benitoite.Interval.analyzeBase_warning_located
#print axioms Benitoite.Interval.analyzeBase_normal_sound
#print axioms Benitoite.Interval.analyzeBase_warning_sound
#print axioms Benitoite.Interval.range_save_result_of_eval
#print axioms Benitoite.Interval.range_match_at_evaluated
#print axioms Benitoite.Interval.baseResultArmEnv_ranges
#print axioms Benitoite.Interval.baseRangeCall_normal
#print axioms Benitoite.Interval.range_value_origin_evaluated
#print axioms Benitoite.Interval.range_value_origin_total
#print axioms Benitoite.Interval.BudgetAnalysis.expr_normal
#print axioms Benitoite.Interval.BudgetAnalysis.block_normal
#print axioms Benitoite.Interval.BudgetAnalysis.arguments_normal
#print axioms Benitoite.Interval.BudgetAnalysis.resultArmList_normal
#print axioms Benitoite.Interval.BudgetAnalysis.expr_causal
#print axioms Benitoite.Interval.BudgetAnalysis.block_causal
#print axioms Benitoite.Interval.BudgetAnalysis.arguments_causal
#print axioms Benitoite.Interval.BudgetAnalysis.resultArmList_causal
#print axioms Benitoite.Interval.BudgetAnalysis.bodyWork_normal
#print axioms Benitoite.Interval.BudgetAnalysis.bodyWork_causal
#print axioms Benitoite.Interval.BudgetAnalysis.analysis_walk_all
#print axioms Benitoite.Interval.BudgetAnalysis.analysis_located_all
#print axioms Benitoite.Interval.BudgetAnalysis.analysis_within_all
#print axioms Benitoite.Interval.BudgetAnalysis.analysis_savesInputs_all
#print axioms Benitoite.Interval.BudgetAnalysis.analysis_inputWalk_all
#print axioms Benitoite.Interval.range_positions_three_iff
#print axioms Benitoite.Interval.range_arguments_one_iff
#print axioms Benitoite.Interval.range_arguments_three_iff
#print axioms Benitoite.Interval.borrowRangeArgs_spec
#print axioms Benitoite.Interval.borrowRangeArgs_isSome
#print axioms Benitoite.Interval.borrowRangeArgs_eq
#print axioms Benitoite.Interval.borrowValueArg_isSome
#print axioms Benitoite.Interval.borrow_range_call_eq
#print axioms Benitoite.Interval.borrow_range_origin_eq
#print axioms Benitoite.Interval.borrow_range_value_call_eq
#print axioms Benitoite.Interval.BudgetScan.rangeLength_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeThree_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeOne_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeThreeExprs_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeOneExprs_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeBorrowCheck_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeBorrowValue_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeEntry_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeStandard_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeStandardAt_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeFixed_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeCall_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeOrigin_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeResultSource_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeNames_agrees
#print axioms Benitoite.Interval.BudgetScan.rangePattern_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeOk_agrees
#print axioms Benitoite.Interval.BudgetScan.rangePatterns_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeArms_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeMatch_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeChecked_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeValueSource_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeValue_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeBind_agrees
#print axioms Benitoite.Interval.BudgetScan.readRangeArm_agrees
#print axioms Benitoite.Interval.BudgetScan.rangeArm_agrees

-- 実交換の照合器の期待型が StandardRule の定義と同じであることを確かめる。
open Benitoite.Interval Benitoite.Release
example (names : RangeNames) :
    (StandardRule.rangeCheck names).resultType =
      .data names.result [.data names.owner [], .data names.error []] := rfl
example (owner : DataName) :
    (StandardRule.rangeValue owner).argumentType = .data owner [] := rfl
#print axioms Benitoite.Interval.range_value_total
#print axioms Benitoite.Interval.range_value_exact
#print axioms Benitoite.Interval.range_result_ok_models
