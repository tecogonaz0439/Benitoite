import Benitoite.Interval.BudgetCallReach
import Benitoite.Interval.BudgetBody

/-!
# call の認定を伴う範囲の公開保証

構文だけの候補範囲とは別に、未認定 call の内側を除く保証を各入口へ接続する。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

theorem CallReach.unrecognized_call_excluded (env : AbstractEnv) (key : OperationKey)
    (callee : Expr) (labels : List (Option String)) (positions : List Nat) (arguments : Exprs)
    (unknown : rangeCallAt env key (.call callee labels positions arguments) = none)
    (warning : IntervalWarning) :
    ¬ (CallReach.expr env (.call callee labels positions arguments)).allows key warning := by
  simp only [CallReach.expr, CallReach.exprTables, CallReach.gate]
  exact fun h => h.1 unknown

/-- 既存の警告には条件を加えず、今回加えた分だけを認定した call の範囲に制限する。 -/
theorem expr_warning_call_reach (fuel : Nat) (env : AbstractEnv) (source : Expr)
    (limits : Limits) (ctx : Context) :
    ListExtension ((CallReach.expr env source).allows ctx.next)
      ctx.warningsRev (expr fuel env source limits ctx).2.warningsRev :=
  ((CallExclusion.analysis_within_all fuel).1 (fun _ => False) env source limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

theorem block_warning_call_reach (fuel : Nat) (env : AbstractEnv) (body : Block)
    (limits : Limits) (ctx : Context) :
    ListExtension ((CallReach.block env body).allows ctx.next)
      ctx.warningsRev (block fuel env body limits ctx).2.warningsRev :=
  ((CallExclusion.analysis_within_all fuel).2.2.1 (fun _ => False) env body limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

/-- 式の公開入口は、任意予算・停止時にも未認定 call の内側を親の警告から除く。 -/
theorem analyzeExpr_warning_call_reach (limits : Limits) (state : Budget.State) (fuel : Nat)
    (env : AbstractEnv) (key : OperationKey) (source : Expr) (warning : IntervalWarning)
    (member : warning ∈ (analyzeExpr limits state fuel env key source).approx.warnings) :
    (CallReach.expr env source).allows key warning := by
  have h := expr_warning_call_reach fuel (resetRanges env) source limits { budget := state, next := key }
  have inside := (h.member member).resolve_left (by simp)
  simpa only [CallReach.expr, CallReach.tables_reset] using inside

/-- 中心命題と同じ入口の別契約。評価導出の存在を前提にしない。 -/
def WarningsInCallReach {Parameters : Type}
    (analyze : AbstractEnv → EvalInput → Parameters → AnalysisResult) : Prop :=
  ∀ env input parameters warning, warning ∈ (analyze env input parameters).warnings →
    (CallReach.expr env input.source).allows input.key warning

theorem analyze_warning_call_reach : WarningsInCallReach analyze := by
  intro env input parameters warning member
  exact analyzeExpr_warning_call_reach parameters.limits parameters.state parameters.fuel
    env input.key input.source warning member

theorem bodyWork_warning_call_reach (fuel : Nat) (seed : BodySeed) :
    CallExclusion.Within (bodyWork fuel seed) (CallReach.expr seed.initial (bodyRoot seed.body))
      (fun _ => False) := by
  unfold bodyWork
  apply CallExclusion.within_scope
  apply CallExclusion.within_scan_bind (BudgetScan.forgetEnv_agrees _)
  intro initial eq
  apply CallExclusion.within_expr_tables (left := initial) (by rw [eq]; exact CallReach.tables_forget _)
  exact (CallExclusion.analysis_within_all fuel).1 (fun _ => False) initial (bodyRoot seed.body)

/-- 本体の事前停止と入口の忘却中の停止も、空の追加分として保証する。 -/
theorem analyzeBody_warning_call_reach (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) (warning : IntervalWarning)
    (member : warning ∈ (analyzeBody limits state fuel definition seed).approx.warnings) :
    (CallReach.expr seed.initial (bodyRoot seed.body)).allows (bodyRootKey definition) warning := by
  have all : ∀ warning ∈ (analyzeBody limits state fuel definition seed).approx.warnings,
      (CallReach.expr seed.initial (bodyRoot seed.body)).allows (bodyRootKey definition) warning := by
    apply analyzeBody_property limits state fuel definition seed
      (fun approx => ∀ warning ∈ approx.warnings,
        (CallReach.expr seed.initial (bodyRoot seed.body)).allows (bodyRootKey definition) warning)
    · simp
    · intro result ctx run warning member
      have h := (bodyWork_warning_call_reach fuel seed limits
        { budget := state, next := bodyRootKey definition }).1.1
      have added := h.member (show warning ∈ (bodyWork fuel seed limits
        { budget := state, next := bodyRootKey definition }).2.warningsRev from by
          simpa only [run, report_warnings] using member)
      exact (added.resolve_left (by simp)).resolve_left id
  exact all warning member

/-- 未認定 call を式入口の根にした場合、その全引数を含め親の警告は空である。 -/
theorem analyzeExpr_unrecognized_call_warnings (limits : Limits) (state : Budget.State) (fuel : Nat)
    (env : AbstractEnv) (key : OperationKey) (callee : Expr) (labels : List (Option String))
    (positions : List Nat) (arguments : Exprs)
    (unknown : rangeCallAt env key (.call callee labels positions arguments) = none) :
    (analyzeExpr limits state fuel env key (.call callee labels positions arguments)).approx.warnings = [] := by
  apply List.eq_nil_iff_forall_not_mem.mpr
  intro warning member
  exact CallReach.unrecognized_call_excluded env key callee labels positions arguments unknown warning
    (analyzeExpr_warning_call_reach limits state fuel env key _ warning member)

/-- 空の警告列から始める入口では、停止した出力の全警告について位置を得られる。 -/
theorem analyzeExpr_warning_located (limits : Limits) (state : Budget.State) (fuel : Nat)
    (env : AbstractEnv) (key : OperationKey) (source : Expr) (warning : IntervalWarning)
    (member : warning ∈ (analyzeExpr limits state fuel env key source).approx.warnings) :
    ∃ node, (warning.key, node) ∈ numbered key source ∧
      targetOperationAt env warning.key node = some warning.operation := by
  have inside := analyzeExpr_warning_call_reach limits state fuel env key source warning member
  obtain ⟨node, atNode, target⟩ := CallReach.expr_located env source key warning inside
  exact ⟨node, by simpa only [CallReach.expr_sources, numberFrom_numbered] using atNode, target⟩

/-- 上限・初期消費・深さを制限せず、既存の WarningLocated を同じ解析入口で満たす。 -/
theorem analyze_warning_located : WarningLocated analyze := by
  intro env input parameters warning member
  exact analyzeExpr_warning_located parameters.limits parameters.state parameters.fuel
    env input.key input.source warning member

/-- 本体入口の警告も、根を番号0とする同じ numbered に属する。 -/
theorem analyzeBody_warning_located (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) (warning : IntervalWarning)
    (member : warning ∈ (analyzeBody limits state fuel definition seed).approx.warnings) :
    ∃ node, (warning.key, node) ∈ numbered (bodyRootKey definition) (bodyRoot seed.body) ∧
      targetOperationAt seed.initial warning.key node = some warning.operation := by
  have inside := analyzeBody_warning_call_reach limits state fuel definition seed warning member
  obtain ⟨node, atNode, target⟩ := CallReach.expr_located seed.initial (bodyRoot seed.body)
    (bodyRootKey definition) warning inside
  exact ⟨node, by simpa only [CallReach.expr_sources, numberFrom_numbered] using atNode, target⟩

end Benitoite.Interval.BudgetAnalysis
