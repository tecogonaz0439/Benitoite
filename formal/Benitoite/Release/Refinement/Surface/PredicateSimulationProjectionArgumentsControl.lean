import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionControl
import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarControl

/-! # 投影する公開呼出しの全引数の管理経路

固定条件の定数と同じgetter列をソース順に評価し、公開判定のappへ戻る。
経路は実行時のプログラムや外部応答に依存しない六規則だけから構成する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateResponse PredicateRows PredicateProjection
noncomputable section

def projectionValues (constant : Const) (symbolic : List Val) : List Val :=
  symbolic.map (Val.subst (fun _ => .const constant))

theorem ProjectionArguments.length {source root steps computations symbolic}
    (arguments : ProjectionArguments source root steps computations symbolic) :
    computations.length = symbolic.length := by
  induction arguments <;> simp_all

theorem ProjectionArguments.close_results {source root steps computations symbolic}
    (arguments : ProjectionArguments source root steps computations symbolic) (cap : Capture) (constant : Const) :
    closeVals cap (projectionValues constant symbolic) = projectionValues constant symbolic := by
  induction arguments with
  | nil => rfl
  | constant value tail ih => exact congrArg (List.cons (.const value)) ih
  | target head tail ih => exact congrArg (List.cons (.const constant)) ih

theorem ProjectionArguments.return_path {source rows Q targetB Ψ root steps computations symbolic}
    (arguments : ProjectionArguments source root steps computations symbolic)
    (targetCons : ∀ constructor declaration, source.cons constructor = some declaration → Q.cons constructor = some declaration)
    (simple : SimpleValue root) (cap : Capture) (target : Val) (type : Ty)
    (typed : HasTypeVQ Q targetB Ψ Qempty [] [] [] target type)
    (related : Value source rows (closeVal cap root) target) (constant : Const)
    (read : MatchFacts.readPath target (steps.map PredicateAccessorTargets.Step.reference) = some (.const constant))
    (entry : Entry) (leafType : Ty)
    (leafTyped : HasTypeVQ Q targetB Ψ Qempty [] [] [] (.const constant) leafType)
    (scalar : leafType.norm.core = .base entry.input)
    (before : List Val) (body : Comp) (k : Cont) (μ : Store) :
    AdministrativePath source
      (.run (.mk (cap.extendMany before) (letChain before.length computations body)) k μ)
      (.run (.mk (cap.extendMany (before ++ projectionValues constant symbolic)) body) k μ) := by
  induction arguments generalizing before with
  | nil => simpa only [projectionValues,List.map_nil,List.append_nil,letChain] using
      AdministrativePath.nil (.run (.mk (cap.extendMany before) body) k μ)
  | constant value tail ih =>
    have capture : (cap.extendMany before).extend (.const value) = cap.extendMany (before ++ [.const value]) := by
      rw [Capture.extendMany_append]
      rfl
    refine .cons (.letIn _ _ _ _ _) (.cons (.returnValue rfl) ?_)
    change AdministrativePath source
      (.run (.mk ((cap.extendMany before).extend (.const value)) (letChain (before.length+1) _ body)) k μ) _
    rw [capture]
    have tailPath := ih (before ++ [.const value])
    rw [List.length_append,List.length_singleton] at tailPath
    simpa only [projectionValues,List.map_cons,Val.subst,List.append_assoc,List.singleton_append] using tailPath
  | @target getterBody rest symbols getter tail ih =>
    let current := cap.extendMany before
    let next : Closure := .mk current (letChain (before.length+1) rest body)
    have currentRelated : Value source rows (closeVal current (root.rename (· + before.length))) target := by
      change Value source rows (closeVal (cap.extendMany before) (root.rename (· + before.length))) target
      rw [simple.close_shiftMany]
      exact related
    have currentRead : MatchFacts.readPath target
        ((steps.map (mapStepTypes (renameTy (· + before.length)))).map PredicateAccessorTargets.Step.reference) =
        some (.const constant) := by
      rw [step_references]
      exact read
    obtain ⟨result,actual,headPath,view,same⟩ := (getter.rename (· + before.length)).scalar_return_path
      targetCons current target type typed currentRelated (.const constant) currentRead entry leafType leafTyped scalar next k μ
    cases Val.const.inj same
    have capture : current.extend (.const constant) = cap.extendMany (before ++ [.const constant]) := by
      rw [Capture.extendMany_append]
      rfl
    refine .cons (.letIn _ _ _ _ _) (headPath.append (.cons (.returnValue view) ?_))
    change AdministrativePath source
      (.run (.mk (current.extend (.const constant)) (letChain (before.length+1) _ body)) k μ) _
    rw [capture]
    have tailPath := ih (before ++ [.const constant])
    rw [List.length_append,List.length_singleton] at tailPath
    simpa only [projectionValues,List.map_cons,Val.subst,List.append_assoc,List.singleton_append] using tailPath

/-- 全引数を束縛した公開callは、同じ葉の定数と固定条件を宣言順に読む。 -/
theorem ProjectionArguments.sourceCall_path {source rows Q targetB Ψ root steps computations symbolic}
    (arguments : ProjectionArguments source root steps computations symbolic)
    (targetCons : ∀ constructor declaration, source.cons constructor = some declaration → Q.cons constructor = some declaration)
    (simple : SimpleValue root) (cap : Capture) (target : Val) (type : Ty)
    (typed : HasTypeVQ Q targetB Ψ Qempty [] [] [] target type)
    (related : Value source rows (closeVal cap root) target) (constant : Const)
    (read : MatchFacts.readPath target (steps.map PredicateAccessorTargets.Step.reference) = some (.const constant))
    (entry : Entry) (leafType : Ty)
    (leafTyped : HasTypeVQ Q targetB Ψ Qempty [] [] [] (.const constant) leafType)
    (scalar : leafType.norm.core = .base entry.input)
    (api : API) (positions : List Nat) (k : Cont) (μ : Store) :
    ∃ result, AdministrativePath source (.run (.mk cap (sourceCall api positions computations)) k μ) (.run result k μ) ∧
      result.view = .app (.prim api.name [] [] [])
        (recordFields api.inputs.length positions (projectionValues constant symbolic) (.const .unit)) := by
  let values := projectionValues constant symbolic
  have count : values.length = computations.length := by
    change (symbolic.map _).length = _
    rw [List.length_map,arguments.length]
  have closed : closeVals cap values = values := arguments.close_results cap constant
  have path := arguments.return_path targetCons simple cap target type typed related constant read entry leafType leafTyped scalar []
    (.app (.prim api.name [] [] []) (recordFields api.inputs.length positions (boundVars computations.length) (.const .unit))) k μ
  refine ⟨_,path,?_⟩
  have view := scalarBody_view api positions values cap
  rw [closed] at view
  simpa only [scalarBody,count,values,List.nil_append] using view

theorem ScalarInputs.projection_values {api entry positions symbolic constant}
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0)) :
    ScalarInputs api entry
      (recordFields api.inputs.length positions (projectionValues constant symbolic) (.const .unit)) (.const constant) := by
  have mapped := inputs.map (Val.subst (fun _ => .const constant)) (fun _ => rfl)
  have fields := recordFields_map (Val.subst (fun _ => .const constant)) api.inputs.length positions symbolic (.const .unit)
  simpa only [fields,Val.subst,projectionValues] using mapped

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
