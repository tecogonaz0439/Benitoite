import Benitoite.Interval.ReportFlow
import Benitoite.Release.Refinement.IntervalFailure
import Benitoite.Release.Refinement.IntervalControlLeaves
import Benitoite.Release.Refinement.StandardModelApplication

/-! # 同じ実報告の所属と型付きの有限実行 -/
namespace Benitoite.Release.Refinement.IntervalReport
open Benitoite.Interval IntervalConnection

/-- 同じ独立評価が追跡した失敗を、実解析のフローの失敗成分へ入れる。 -/
theorem failed {abstract concrete input reason trace} (parameters : BudgetAnalysis.Parameters)
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.failed reason) trace)
    (tracked : TrackedFailure reason trace) :
    (ReportFlow.analyze abstract input parameters).mayFail = true :=
  tracked_failure_sound abstract concrete input parameters reason trace models eval tracked

/-- 同じ独立評価の三成分を、実報告の共有近似へ写す。失敗は実際の trace にあるものを使う。 -/
theorem result {abstract concrete input outcome trace} (parameters : BudgetAnalysis.Parameters)
    (models : Models abstract concrete) (eval : EvalPartial concrete input outcome trace)
    (tracked : ∀ reason, outcome = .failed reason → TrackedFailure reason trace) :
    (ReportFlow.analyze abstract input parameters).ResultMem outcome.toApprox := by
  cases outcome with
  | normal value => exact ReportFlow.normal parameters models eval
  | returned value => exact ReportFlow.returned _ _ value.toApprox
  | failed reason => exact failed parameters models eval (tracked reason rfl)

/-- 主定理の同じ有限実行の保存と、実報告の正常値の所属を同時に読む。 -/
theorem normal_run {P B σ abstract concrete source type key value trace events op position cap startK startStore k μ v}
    (guarantees : ProgramGuarantees P B σ)
    (typed : StateTy P B σ
      (.run (.mk cap (Surface.desugarExpr op position source)) startK startStore))
    (run : Steps P B σ
      (.run (.mk cap (Surface.desugarExpr op position source)) startK startStore) events
      (.run (Closure.pure (.ret v)) k μ))
    (parameters : BudgetAnalysis.Parameters)
    (models : Models abstract concrete)
    (eval : EvalPartial concrete ⟨SurfaceSyntax.eraseExpr source,type,key⟩ (.normal value) trace)
    (related : ValueRel value v) :
    StateTy P B σ (.run (Closure.pure (.ret v)) k μ) ∧
      (ReportFlow.analyze abstract ⟨SurfaceSyntax.eraseExpr source,type,key⟩ parameters).NormalMem v.toApprox :=
  ⟨guarantees.steps_preservation _ _ _ typed run,
    IntervalFlowLeaves.normal_mem_of_related related
      (result parameters models eval (fun reason bad => by cases bad))⟩

/-- mark に届いた return は、実報告の未知の成分から所属を得る。 -/
theorem returned_mark {P B σ Eb q k μ c v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eb (.run q (.mark :: k) μ)) (view : q.view = .escape v)
    (related : ValueRel c v) (report : BudgetAnalysis.Report) (type : Benitoite.Release.Ty) :
    Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) ∧
    EndState (fun _ _ => False) (.normal c) k (.run (Closure.pure (.ret v)) k μ) ∧
    (IntervalFlowLeaves.normalF (ReportFlow.ofReport report type).returned).NormalMem
      (closeVal Capture.empty v).toApprox ∧
    (∃ Ψ R a e, StoreOk P B σ Ψ μ ∧
      ClosureTy P B Ψ [] R (Closure.pure (.ret v)) a e ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (closeVal Capture.empty v) a) :=
  IntervalControlLeaves.escape_mark_member hP hPB hB source view related
    (ReportFlow.returned report type c.toApprox)

/-- 実報告とその型に添える、新しい核との条件付きの接続。 -/
structure Connection (report : BudgetAnalysis.Report) (type : Benitoite.Release.Ty) where
  view : ReportFlow.View report type
  normal : ∀ {P B σ abstract concrete source key value trace events op position cap startK startStore k μ v}
    (parameters : BudgetAnalysis.Parameters),
    report = BudgetAnalysis.analyzeExpr parameters.limits parameters.state parameters.fuel
      abstract key (SurfaceSyntax.eraseExpr source) →
    ProgramGuarantees P B σ →
    StateTy P B σ (.run (.mk cap (Surface.desugarExpr op position source)) startK startStore) →
    Steps P B σ (.run (.mk cap (Surface.desugarExpr op position source)) startK startStore)
      events (.run (Closure.pure (.ret v)) k μ) →
    Models abstract concrete →
    EvalPartial concrete ⟨SurfaceSyntax.eraseExpr source,type,key⟩ (.normal value) trace → ValueRel value v →
    StateTy P B σ (.run (Closure.pure (.ret v)) k μ) ∧ view.flow.NormalMem v.toApprox
  returned : ∀ {P B σ Eb q k μ c v},
    P.WellFormed → P.WellTyped B → B.CoreAssumptions P →
    StateTyE P B σ Eb (.run q (.mark :: k) μ) → q.view = .escape v → ValueRel c v →
    Step P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) ∧
    EndState (fun _ _ => False) (.normal c) k (.run (Closure.pure (.ret v)) k μ) ∧
    (IntervalFlowLeaves.normalF view.flow.returned).NormalMem (closeVal Capture.empty v).toApprox ∧
    (∃ Ψ R a e, StoreOk P B σ Ψ μ ∧
      ClosureTy P B Ψ [] R (Closure.pure (.ret v)) a e ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (closeVal Capture.empty v) a)
  failed : ∀ {abstract concrete input reason trace} (parameters : BudgetAnalysis.Parameters),
    report = BudgetAnalysis.analyzeExpr parameters.limits parameters.state parameters.fuel
      abstract input.key input.source →
    Models abstract concrete → EvalPartial concrete input (.failed reason) trace →
    TrackedFailure reason trace → view.flow.mayFail = true

/-- 実報告から構成し、独立評価と型付きの同じコードに使う接続を証明する。 -/
def connect (report : BudgetAnalysis.Report) (type : Benitoite.Release.Ty) : Connection report type where
  view := ReportFlow.view report type
  normal := by
    intro P B σ abstract concrete source key value trace events op position cap startK startStore k μ v
      parameters same guarantees typed run models eval related
    subst report
    exact normal_run guarantees typed run parameters models eval related
  returned := by
    intro P B σ Eb q k μ c v hP hPB hB source view related
    exact returned_mark hP hPB hB source view related report type
  failed := by
    intro abstract concrete input reason trace parameters same models eval tracked
    subst report
    exact IntervalFailure.analyzeExpr_failure parameters.limits parameters.state parameters.fuel
      models eval reason rfl tracked.1

/-- 閉じた unit の同じ正常値について、予算を制限せず実接続を適用する。 -/
example {P B σ} (guarantees : ProgramGuarantees P B σ) (parameters : BudgetAnalysis.Parameters)
    (key : OperationKey)
    (typed : StateTy P B σ (.run (.mk Capture.empty
      (Surface.desugarExpr (fun _ _ => none) .other .unit)) [] Store.empty)) :
    StateTy P B σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      (ReportFlow.analyze (AbstractEnv.ofLocals [])
        ⟨SurfaceSyntax.eraseExpr .unit,.base .unit,key⟩ parameters).NormalMem (.other) := by
  apply (connect _ _).normal parameters rfl guarantees typed
    (op := fun _ _ => none) (position := .other) (source := .unit) (key := key)
    (abstract := AbstractEnv.ofLocals []) (concrete := ⟨[],[],fun _ => none⟩)
    (value := .unit) (trace := []) (events := [])
  · exact .nil
  · exact ⟨.nil,rfl,rfl⟩
  · rw [SurfaceSyntax.eraseExpr_unit]; exact .unit _ _
  · exact .unit

/-- 型付きの unit の return は、同じ実報告に添えた接続で mark を通る。 -/
example {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (source : StateTyE P B σ Eff.empty
      (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty))
    (parameters : BudgetAnalysis.Parameters) (key : OperationKey) :=
  (connect (BudgetAnalysis.analyzeExpr parameters.limits parameters.state parameters.fuel
    (AbstractEnv.ofLocals []) key (.returnE (.base .unit) .unit)) (.base .unit)).returned
    hP hPB hB source rfl (.unit : ValueRel .unit (.const .unit))

end Benitoite.Release.Refinement.IntervalReport
