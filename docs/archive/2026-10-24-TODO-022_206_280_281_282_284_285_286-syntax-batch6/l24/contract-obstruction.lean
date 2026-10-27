import Benitoite.Interval.BudgetIndependentSound
import Benitoite.Interval.FixedDomain

/-!
L24 の停止条件の確認。既存の実行定義や言明を変えず、公開の構文的な
到達可能性の定理から、標準 call の警告を出せないことを導く。
解析器・評価器を具体入力で計算する証明ではない。
-/
namespace Benitoite.Interval.L24Obstruction
open Benitoite.Surface Benitoite.Release Budget BudgetAnalysis

/-- 現在の位置の認定は、どの式でも standard を返さない。 -/
theorem arithmetic_excludes_standard (source : Expr) (binding : StandardBinding) :
    arithmeticOperationAt source ≠ some (.standard binding) := by
  cases source <;> simp only [arithmeticOperationAt] <;> try { intro h; cases h }
  case neg type child =>
    cases found : IntKind.ofType type with
    | none => simp
    | some kind => split <;> simp
  case binary op type left right => split <;> simp

/-- キー・構文・予算に関係なく、既存の範囲は標準警告を許さない。 -/
theorem reach_excludes_standard {key slots warning} (binding : StandardBinding)
    (operation : warning.operation = .standard binding) :
    ¬ InSyntacticReach key slots warning := by
  intro ⟨source, _, target⟩
  rw [operation] at target
  exact arithmetic_excludes_standard source binding target

/-- 中心二命題と同じ公開入口の既存定理から、標準警告の不在が従う。 -/
theorem public_analyze_excludes_standard (env : AbstractEnv) (input : EvalInput)
    (parameters : Parameters) (warning : IntervalWarning) (binding : StandardBinding)
    (operation : warning.operation = .standard binding) :
    warning ∉ (analyze env input parameters).warnings := by
  intro member
  exact reach_excludes_standard binding operation
    (analyze_warning_syntactic_reach env input parameters warning member)

/-- 本体入口にも同じ制約があり、式入口だけを迂回しても解消しない。 -/
theorem public_body_excludes_standard (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) (warning : IntervalWarning) (binding : StandardBinding)
    (operation : warning.operation = .standard binding) :
    warning ∉ (analyzeBody limits state fuel definition seed).approx.warnings := by
  intro member
  exact reach_excludes_standard binding operation
    (analyzeBody_warning_syntactic_reach limits state fuel definition seed warning member)

/-- 独立入力へ移しても、公開された Sound の範囲から除外される。 -/
theorem independent_excludes_standard {entry : IndependentResult} (sound : entry.Sound)
    (warning : IntervalWarning) (binding : StandardBinding)
    (operation : warning.operation = .standard binding) : warning ∉ entry.warningsRev := by
  intro member
  exact reach_excludes_standard binding operation (sound.1 warning member)

#print axioms public_analyze_excludes_standard
#print axioms public_body_excludes_standard
#print axioms independent_excludes_standard
end Benitoite.Interval.L24Obstruction
