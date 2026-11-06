import Benitoite.Release.Refinement.Surface.PredicateSimulationCongruence

/-! # 成功した判定の単純な引数とgetter列の剛性 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem simple_value_equal {source rows value target} (related : Value source rows value target)
    (simple : SimpleValue target) : value = target := by
  cases simple with
  | var index => cases related; rfl
  | constant value => cases related; rfl
  | con name types =>
    cases related with
    | con fields => cases fields; rfl

private theorem simple_return_equal {source rows computation value}
    (related : Code source rows computation (.ret value)) (simple : SimpleValue value) : computation = .ret value := by
  cases related with
  | ret related => exact congrArg Comp.ret (simple_value_equal related simple)

private theorem getter_call_equal {source rows computation} (step : PredicateAccessorTargets.Step)
    (related : Code source rows computation (getterCall step)) : computation = getterCall step := by
  cases related with
  | app function arguments =>
    cases function
    cases arguments with
    | cons value rest => cases value; cases rest; rfl

/-- 単純な根からなるgetterの脱糖は、コード対応の右側に現れたとき元の計算と同じである。 -/
theorem GetterCode.rigid {source rows computation target root steps}
    (getters : GetterCode source target root steps) (simple : SimpleValue root)
    (related : Code source rows computation target) : computation = target := by
  induction getters generalizing computation with
  | value value => exact simple_return_equal related simple
  | @accessor step body root steps field missing accessor declaration selected sort count child ih =>
    cases related with
    | letIn head tail =>
      congr 1
      · exact ih simple head
      · exact getter_call_equal step tail

/-- 解決後の全引数が単純な値を返すなら、元の引数の計算も同じreturnの列である。 -/
theorem Codes.simple_returns {source rows computations values}
    (related : Codes source rows computations (values.map Comp.ret)) (simple : SimpleValues values) :
    computations = values.map Comp.ret := by
  induction values generalizing computations with
  | nil => cases related; rfl
  | cons value values ih =>
    cases related with
    | cons head tail =>
      have first := simple_return_equal head (simple value List.mem_cons_self)
      have rest := ih tail (fun value member => simple value (List.mem_cons_of_mem _ member))
      simp only [List.map_cons]
      rw [first, rest]

/-- 成功した投影の固定条件とgetter列は、元の引数の計算でも同じままである。 -/
theorem ProjectionArguments.rigid {source rows root steps computations targets symbolic}
    (arguments : ProjectionArguments source root steps targets symbolic) (simple : SimpleValue root)
    (related : Codes source rows computations targets) : computations = targets := by
  induction arguments generalizing computations with
  | nil => cases related; rfl
  | constant value tail ih =>
    cases related with
    | cons head rest =>
      have first := simple_return_equal head (SimpleValue.constant value)
      have others := ih rest
      rw [first, others]
  | target getter tail ih =>
    cases related with
    | cons head rest =>
      have first := getter.rigid simple head
      have others := ih rest
      rw [first, others]

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
