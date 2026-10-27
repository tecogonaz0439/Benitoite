import Benitoite.Interval.Analyze
import Benitoite.Interval.Flow

/-!
L07b の停止理由を再現する資料。既定の形式化の定義を変更せずに読む。
解析器の代用品は作らず、外側の演算へ予定どおり警告する任意の解析器が、
現行の評価関係に対する WarningSoundness を満たせないことを示す。
実行: formal/ で lake env lean ../docs/2026-10-24-TODO-022_206_280_281_282_284_285_286-syntax-batch6/l07b/key-collision.lean
-/

open Benitoite.Release Benitoite.Surface Benitoite.Interval

-- (1 intDiv 1) intDiv 0 の外側に除数0を警告すると、自由な子のキーによって
-- 正常終了する内側の記録も Reached を満たす。環境は空で Models を満たす。
example {Budget : Type}
    (analyze : AbstractEnv → EvalInput → Budget → AnalysisResult) (budget : Budget) :
    let key : OperationKey := ⟨"L07b.collision", 0⟩
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let input : EvalInput := ⟨.binary .intDiv (.base .integer)
      (.binary .intDiv (.base .integer) one one) zero, .base .integer, key⟩
    let warning : IntervalWarning := ⟨key, .binary .intDiv (.base .integer), .zeroDivisor⟩
    warning ∈ (analyze [] input budget).warnings → ¬ WarningSoundness Models analyze := by
  dsimp only
  intro warned sound
  let key : OperationKey := ⟨"L07b.collision", 0⟩
  let env : ConcreteEnv := ⟨[], [], fun _ => none⟩
  let one : Expr := .literal (.integer ⟨1, by decide⟩)
  let zero : Expr := .literal (.integer ⟨0, by decide⟩)
  let value : Integer64Value := ⟨1, by decide⟩
  let zeroValue : Integer64Value := ⟨0, by decide⟩
  let successful : EvalEvent := ⟨key, .binary .intDiv (.base .integer),
    [.integer value, .integer value], .normal (.integer value)⟩
  let rejected : EvalEvent := ⟨key, .binary .intDiv (.base .integer),
    [.integer value, .integer zeroValue], .rejected .zeroDivisor⟩
  have child : EvalPartial env
      ⟨.binary .intDiv (.base .integer) one one, .base .integer, key⟩
      (.normal (.integer value)) [successful] := by
    exact EvalPartial.divMod env key key key .intDiv one one value value [] []
      (Or.inl rfl) (.integer env key ⟨1, by decide⟩) (.integer env key ⟨1, by decide⟩)
  have parent : EvalPartial env
      ⟨.binary .intDiv (.base .integer)
        (.binary .intDiv (.base .integer) one one) zero, .base .integer, key⟩
      (.failed .zeroDivisor) [successful, rejected] := by
    exact EvalPartial.divMod env key key key .intDiv _ zero value zeroValue
      [successful] [] (Or.inl rfl) child (.integer env key ⟨0, by decide⟩)
  have wrong := sound [] env _ budget _ _ LocalsModels.nil parent _ warned successful
    ⟨by simp, rfl, rfl⟩
  cases wrong

-- 分類が base でも、Block と単一ifには現在どの結果への導出もない。
-- これらを根とする中心命題の評価の前提は満たせない。
example (env : ConcreteEnv) (key : OperationKey) (type : Ty)
    (body : Block) (outcome : EvalOutcome) (trace : EvalTrace) :
    ¬ EvalPartial env ⟨.block body, type, key⟩ outcome trace := by
  intro eval
  cases eval <;> simp_all [UnknownAt, Unsupported, classify]

example (env : ConcreteEnv) (key : OperationKey) (type : Ty)
    (condition : Expr) (yes no : Block) (outcome : EvalOutcome) (trace : EvalTrace) :
    ¬ EvalPartial env ⟨.ite condition yes no, type, key⟩ outcome trace := by
  intro eval
  cases eval <;> simp_all [UnknownAt, Unsupported, classify]
