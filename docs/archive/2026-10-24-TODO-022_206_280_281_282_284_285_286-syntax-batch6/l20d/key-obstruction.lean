import Benitoite.Interval.Range
import Benitoite.Interval.BudgetBody

/-!
開始キーを対応させない内部補題と Range 精密化の両立の点検。
公開入口の主定理への反例ではない。実行定義と既存の言明は変更しない。
-/
namespace Benitoite.Interval.L20dKeyCheck
open Benitoite.Surface Benitoite.Release BudgetAnalysis

private def names : RangeNames := ⟨"Std.Range.CheckedInteger", "Std.Result.Result", "Std.Range.Error",
  "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
private def key (n : Nat) : OperationKey := ⟨"Example.rangeKey", n⟩
private def checkBinding : StandardBinding := ⟨"Std.Range.checkInteger", .rangeCheck names⟩
private def valueBinding : StandardBinding := ⟨"Std.Range.value", .rangeValue names.owner⟩
private def concrete : ConcreteEnv := ⟨[], [checkBinding, valueBinding], fun k =>
  if k.surfacePreorder = 2 then some "Std.Range.checkInteger"
  else if k.surfacePreorder = 7 ∨ k.surfacePreorder = 107 then some "Std.Range.value"
  else none⟩
private def abstract : AbstractEnv := ⟨[], concrete.standards, concrete.apiAt⟩
private def resultType : Ty := .data names.result [.opaque names.owner, .data names.error []]
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def checkCall : Expr := .call (.funName "Std.Range.checkInteger" [] [])
  [some "minimum", some "maximum", some "value"] [0, 1, 2]
  (.cons zero (.cons zero (.cons zero .nil)))
private def projection : Expr := .call (.funName "Std.Range.value" [] []) [some "checked"] [0]
  (.cons (.local 0) .nil)
private def okAlt : Alternative := ⟨.con (some names.result) names.ok [.var], [0]⟩
private def arms : Arms := .cons [okAlt] none (.last projection)
  (.cons [⟨.wild, []⟩] none (.last zero) .nil)
private def body : Block := .last (.matchE (.base .integer) checkCall arms)
private def seed : BodySeed := ⟨.function, body, abstract⟩
private def checked : Checked.Range.CheckedInteger := ⟨1, 1, 1, by decide⟩
private def payload : ConcreteValue := .checkedRange names.owner (key 999) checked
private def result : ConcreteValue := .con names.result [.opaque names.owner, .data names.error []]
  names.ok [payload]
private def one : ConcreteValue := .integer ⟨1, by decide⟩
private def event : EvalEvent := ⟨key 107, .standard valueBinding, [payload], .normal one⟩

private theorem models : Models abstract concrete := ⟨.nil, rfl, rfl⟩

/-- キー2では固定端点0/0の検査、キー102では同じ構文が未認定である。 -/
theorem recognition_differs :
    (rangeCallOrigin abstract ⟨checkCall, resultType, key 2⟩).isSome = true ∧
    rangeCallBinding concrete ⟨checkCall, resultType, key 102⟩ = none := by
  decide +kernel

/-- キー100からの同じ本体には、外の検査によらない正常値1の評価導出がある。 -/
theorem shifted_evaluation : EvalPartial concrete
    ⟨bodyRoot body, .base .integer, key 100⟩ (.normal one) [event] := by
  have read : EvalPartial {concrete with locals := [some payload]}
      ⟨projection, .base .integer, key 107⟩ (.normal one) [event] := by
    refine .standardCall _ (key 107) _ _ _ _ valueBinding [payload] [payload]
      (.normal one) [] ?_ ?_ rfl ?_
    · rfl
    · apply EvalArguments.cons (ht := []) (rt := [])
      · exact .local _ _ 0 payload rfl
      · exact .nil ..
    · exact .rangeValue names.owner (key 107) (key 999) checked (by decide)
  have selection : ResultSelection names result names.ok payload [okAlt] [payload] :=
    ⟨[], okAlt, [], [payload], rfl, by simp, rfl, rfl, rfl⟩
  have chosen : EvalResultArms concrete (key 107) names result names.ok payload arms
      (.base .integer) (.normal one) [event] :=
    .body _ _ _ _ _ _ _ _ _ _ _ _ _ selection (.last _ _ _ _ _ _ read)
  apply EvalPartial.block
  apply EvalBlock.last
  exact .matchResult concrete (key 101) checkCall arms (.base .integer) resultType result names
    names.ok payload (.normal one) [] [event] rfl (.ok payload rfl)
    (.unknownNormal _ _ result (by
      change UnknownAt concrete ⟨checkCall, resultType, key 102⟩
      exact Or.inr (Or.inr recognition_differs.2)) rfl) chosen

/-- 現言明を残す限り、キー0から解析しても成功時に範囲外の1を含める必要がある。 -/
theorem expr_normal_requires_one (fuel : Nat) :
    Success (expr fuel abstract (bodyRoot body))
      (fun approx => approx.Contains one) := by
  intro limits ctx approx ok
  exact expr_normal fuel models shifted_evaluation limits ctx approx ok one rfl

/-- 本体の内部補題も、解析と評価の開始キーを結び付けていない。 -/
theorem bodyWork_normal_requires_one (fuel : Nat) :
    Success (bodyWork fuel seed) (fun approx => approx.Contains one) := by
  intro limits ctx approx ok
  exact bodyWork_normal fuel (by exact models) shifted_evaluation limits ctx approx ok one rfl

/-- 従って両補題の現言明を保存したまま、この成功値を[0,0]に精密化できない。 -/
theorem no_precise_zero (fuel : Nat) (limits : Budget.Limits) (ctx : Context)
    (approx : BaseApprox) (ok : (bodyWork fuel seed limits ctx).1 = .ok approx) :
    approx.integer ≠ normalize 0 0 := by
  have member := bodyWork_normal_requires_one fuel limits ctx approx ok
  change Mem 1 approx.integer at member
  intro precise
  rw [precise] at member
  have bounds := (mem_normalize 1 0 0).mp member
  omega

/-- 現実行定義は十分な予算で成功する。停止だけによる空虚な例ではない。 -/
example :
    (match (bodyWork 32 seed {} { next := key 0 }).1 with
      | .ok approx => decide (approx.integer = top)
      | .error _ => false) = true := by
  decide +kernel

#print axioms recognition_differs
#print axioms shifted_evaluation
#print axioms expr_normal_requires_one
#print axioms bodyWork_normal_requires_one
#print axioms no_precise_zero
end Benitoite.Interval.L20dKeyCheck
