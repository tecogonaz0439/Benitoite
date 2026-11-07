import Benitoite.Interval.BudgetNormal

/-! # 実解析の報告から得る正常値と return の近似 -/
namespace Benitoite.Interval.ReportFlow
open BudgetAnalysis

/-- 同じ報告の正常値・return・失敗成分を読むときの証拠。 -/
structure View (report : Report) (type : Benitoite.Release.Ty) where
  flow : Shared.FlowApprox
  normal : ∀ value, (report.toAnalysisResult type).normal value → flow.NormalMem value.toApprox
  returned : ∀ value, flow.ReturnedMem value
  mayFail : flow.mayFail = report.approx.mayFail

/-- 正常値と失敗成分は実報告から読み、記録されていない return の値は未知に保つ。 -/
def view (report : Report) (type : Benitoite.Release.Ty) : View report type where
  flow := report.sharedFlow type .unknown
  normal := fun _ member => Report.shared_normal report type .unknown member
  returned := fun _ => trivial
  mayFail := rfl

/-- 三成分の証拠を持つ同じ報告から、実行可能な共有近似を取り出す。 -/
def ofReport (report : Report) (type : Benitoite.Release.Ty) : Shared.FlowApprox :=
  (view report type).flow

/-- 上限・初期消費・深さを制限せず、同じ入力の実報告を読む。 -/
def analyze (abstract : AbstractEnv) (input : EvalInput) (parameters : Parameters) : Shared.FlowApprox :=
  ofReport (analyzeExpr parameters.limits parameters.state parameters.fuel abstract input.key input.source)
    input.type

/-- 独立評価の正常値は、実際の予算付き解析の正常成分に属する。 -/
theorem normal {abstract concrete input value trace} (parameters : Parameters)
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.normal value) trace) :
    (analyze abstract input parameters).NormalMem value.toApprox :=
  (view _ _).normal value (analyze_normal_sound abstract concrete input parameters value trace models eval)

/-- return の値を記録していない報告は、どの値も return の候補から落とさない。 -/
theorem returned (report : Report) (type : Benitoite.Release.Ty) (value : Shared.ApproxValue) :
    (ofReport report type).ReturnedMem value :=
  (view report type).returned value

/-- return の保守的な補完は、実解析が返した失敗成分を変えない。 -/
theorem mayFail (report : Report) (type : Benitoite.Release.Ty) :
    (ofReport report type).mayFail = report.approx.mayFail :=
  (view report type).mayFail

end Benitoite.Interval.ReportFlow
