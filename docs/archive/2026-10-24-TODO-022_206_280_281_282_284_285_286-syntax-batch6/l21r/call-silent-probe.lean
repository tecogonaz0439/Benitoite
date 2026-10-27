import Benitoite.Interval.BudgetReach
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget
private theorem listExtension_false_eq {before after : List α}
    (h : ListExtension (fun _ => False) before after) : after = before := by
  obtain ⟨added, shape, absent⟩ := h
  cases added with
  | nil => exact shape
  | cons head tail => exact (absent head (by simp)).elim

-- 未認定の call を根とする内部走査は、停止時も入力の候補列を保つ。
theorem expr_unrecognized_call_silent_at (fuel : Nat) (env : AbstractEnv)
    (callee : Expr) (labels : List (Option String)) (positions : List Nat) (arguments : Exprs)
    (limits : Limits) (ctx : Context)
    (unknown : rangeCallAt env ctx.next (.call callee labels positions arguments) = none) :
    (expr fuel env (.call callee labels positions arguments) limits ctx).2.warningsRev =
      ctx.warningsRev := by
  apply listExtension_false_eq
  suffices h : Spec (expr fuel env (.call callee labels positions arguments)) limits ctx
      (fun _ => True) (fun _ => False) (fun _ => True) from h.1.1
  cases fuel with
  | zero => exact spec_throw _ _ _ _ _ _
  | succ fuel =>
    rw [expr.eq_def]
    apply spec_scope
    intro entered ok
    have same : entered.next = ctx.next := by
      simpa only [ok] using (scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx).2.2.1
    apply spec_bind (spec_identify _ limits entered _ _ trivial)
    intro key middle identified keyEq
    apply spec_bind (spec_scan _ limits middle (fun _ => True) _ _ (by intros; trivial))
    intro _ classified classifiedOk _
    dsimp only
    apply spec_bind (spec_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _) limits classified _ _)
    intro recognized ready recognizedOk recognizedEq
    rw [recognizedEq, keyEq, same, unknown]
    apply spec_mono (within_unknown fuel env (.call callee labels positions arguments)
      [] (fun _ => False) limits ready) (by intros; trivial) ?_ (by intros; trivial)
    intro warning member
    rcases member with absent | ⟨source, absent, _⟩
    · exact absent
    · simp [numberSyntacticReach] at absent
#check analyzeExpr_warning_syntactic_reach
#check analyzeBody_warning_syntactic_reach
#print axioms expr_unrecognized_call_silent_at
end Benitoite.Interval.BudgetAnalysis
