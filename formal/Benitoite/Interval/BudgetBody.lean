import Benitoite.Interval.BudgetSound

/-!
# 本体入口の正常値・警告・位置の系

入口環境の忘却と全体上限の事前判定を含め、処理系が使う本体入口に
式の入口と同じ保証を与える。根の block 式を番号0から数える
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 忘却が完走した場合だけ、同じ具体環境で根の式へ進む。 -/
theorem bodyWork_normal (fuel : Nat) {seed : BodySeed} {concrete type key outcome trace}
    (models : Models (forget seed.initial) concrete)
    (eval : EvalPartial concrete ⟨bodyRoot seed.body, type, key⟩ outcome trace) :
    SuccessAt key (bodyWork fuel seed) (fun approx => NormalCovered approx outcome) := by
  unfold bodyWork
  apply successAt_scope
  refine successAt_bind (first := scan (BudgetScan.forgetEnv seed.initial))
    (next := fun initial => expr fuel initial (bodyRoot seed.body))
    (indexed_success_scan_agrees _ _ (BudgetScan.forgetEnv_agrees seed.initial)) ?_
  intro initial same
  subst initial
  exact (expr_normal fuel models (ranges_forget seed.initial concrete) eval).rekey

/-- 忘却中の停止は警告を作らず、完走した根だけが警告原因を与える。 -/
theorem bodyWork_causal (fuel : Nat) {seed : BodySeed} {concrete type key outcome trace}
    (models : Models (forget seed.initial) concrete)
    (eval : EvalPartial concrete ⟨bodyRoot seed.body, type, key⟩ outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (bodyWork fuel seed) limits ctx key (surfaceSize (bodyRoot seed.body)) trace := by
  unfold bodyWork
  apply causal_scope_same
  intro entered same
  apply causal_scan_bind _ _ (BudgetScan.forgetEnv_agrees seed.initial)
  intro middle next
  exact expr_causal fuel models (ranges_forget seed.initial concrete) eval limits middle (next.trans (same.trans start))

/-- 入口の計上と忘却は番号を消費せず、根の block を含む位置の列を保つ。 -/
theorem bodyWork_located (fuel : Nat) (seed : BodySeed) :
    Located (bodyWork fuel seed) (surfacePreorder (bodyRoot seed.body)) (fun _ => False) := by
  unfold bodyWork
  apply located_scope
  simpa only [List.nil_append] using
    located_bind (walk_scan _) (located_scan _ _) (fun initial =>
      (analysis_located fuel).1 (fun _ => False) initial (bodyRoot seed.body))

/-- 入口で停止した場合と、実際に走査した本体の性質を同じ出力へ移す。 -/
theorem analyzeBody_property (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) (property : BaseApprox → Prop)
    (stopped : property { baseUnknown with warnings := [] })
    (work : ∀ result ctx,
      bodyWork fuel seed limits { budget := state, next := bodyRootKey definition } = (result, ctx) →
      property (report result ctx).approx) :
    property (analyzeBody limits state fuel definition seed).approx := by
  unfold analyzeBody
  split
  · exact stopped
  · split
    · exact stopped
    · cases run : bodyWork fuel seed limits { budget := state, next := bodyRootKey definition } with
      | mk result ctx => simpa only [run] using work result ctx run

/-- 任意の予算・深さで、正常に評価した本体の値を出力の区間に含む。 -/
theorem analyzeBody_normal (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) {seed : BodySeed} {concrete type outcome trace}
    (models : Models (forget seed.initial) concrete)
    (eval : EvalPartial concrete ⟨bodyRoot seed.body, type, bodyRootKey definition⟩ outcome trace) :
    NormalCovered (analyzeBody limits state fuel definition seed).approx outcome := by
  apply analyzeBody_property limits state fuel definition seed
    (fun approx => NormalCovered approx outcome)
  · intro value _
    exact (contains_warnings baseUnknown [] value).mpr (unknown_contains value)
  · intro result ctx run
    apply report_normal
    intro approx ok
    exact bodyWork_normal fuel models eval limits
      { budget := state, next := bodyRootKey definition } rfl approx (by simpa only [run] using ok)

/-- 本体の全体上限の事前判定と入口の忘却を含め、原因どおりの拒否を保つ。 -/
theorem analyzeBody_warning_sound (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) {seed : BodySeed} {concrete type outcome trace}
    (models : Models (forget seed.initial) concrete)
    (eval : EvalPartial concrete ⟨bodyRoot seed.body, type, bodyRootKey definition⟩ outcome trace)
    (warning : IntervalWarning)
    (member : warning ∈ (analyzeBody limits state fuel definition seed).approx.warnings)
    (event : EvalEvent) (reached : Reached trace warning event) :
    event.result = .rejected warning.cause.toFailure := by
  have all : ∀ warning ∈ (analyzeBody limits state fuel definition seed).approx.warnings,
      ∀ event, Reached trace warning event → event.result = .rejected warning.cause.toFailure := by
    apply analyzeBody_property limits state fuel definition seed
      (fun approx => ∀ warning ∈ approx.warnings, ∀ event,
        Reached trace warning event → event.result = .rejected warning.cause.toFailure)
    · simp
    · intro result ctx run warning member event reached
      have h := bodyWork_causal fuel models eval limits
        { budget := state, next := bodyRootKey definition } rfl
      have cause := h.member (show warning ∈ (bodyWork fuel seed limits
        { budget := state, next := bodyRootKey definition }).2.warningsRev from by
          simpa only [run, report_warnings] using member)
      exact (cause.resolve_left (by simp)).2 event reached
  exact all warning member event reached

end Benitoite.Interval.BudgetAnalysis
