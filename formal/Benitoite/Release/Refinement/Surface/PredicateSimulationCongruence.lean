import Benitoite.Release.Refinement.Surface.PredicateSimulationAlgebra

/-! # 脱糖が組み立てる管理用の束縛の合同性 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- ソース順の計算の列を、一つずつコードの対応で比較する。 -/
inductive Codes (source : Program) (rows : PredicateProjection.Table.Rows) : List Comp → List Comp → Prop
  | nil : Codes source rows [] []
  | cons {body target rest targets} : Code source rows body target → Codes source rows rest targets →
      Codes source rows (body :: rest) (target :: targets)

private theorem Codes.length {source rows computations targets} (related : Codes source rows computations targets) :
    computations.length = targets.length := by
  induction related with
  | nil => rfl
  | cons head tail ih => exact congrArg Nat.succ ih

/-- 同じソース順の計算の列を、同じ深さから順に束縛する。 -/
theorem Code.letChain {source rows computations targets body targetBody}
    (related : Codes source rows computations targets)
    (finish : Code source rows body targetBody) (depth : Nat) :
    Code source rows (letChain depth computations body) (letChain depth targets targetBody) := by
  induction related generalizing depth with
  | nil => exact finish
  | cons head tail ih =>
    exact .letIn (head.rename _) (ih (depth+1))

/-- 束縛後の同じ参照列を使う脱糖は、引数の計算の対応を保つ。 -/
theorem Code.sequence {source rows computations targets finish targetFinish}
    (related : Codes source rows computations targets)
    (body : ∀ values, Code source rows (finish values) (targetFinish values)) :
    Code source rows (sequence computations finish) (sequence targets targetFinish) := by
  have same : computations.length = targets.length := related.length
  simp only [Surface.sequence, ← same]
  exact Code.letChain related (body _) 0

/-- 同じ直接の頭と位置表を使い、計算する引数と非直接のcalleeを対応させる。 -/
theorem Code.callComp {source rows f targetF callee targetCallee computations targets}
    (heads : directCallee f = directCallee targetF)
    (calleeRelated : Code source rows callee targetCallee)
    (arguments : Codes source rows computations targets)
    (shift : Nat) (inserted : List Val) (positions : List Nat) :
    Code source rows (callComp shift inserted f callee positions computations)
      (callComp shift inserted targetF targetCallee positions targets) := by
  have same : computations.length = targets.length := arguments.length
  simp only [Surface.callComp, heads, ← same]
  cases directCallee targetF with
  | some head => exact Code.letChain arguments (.refl _) _
  | none => exact .letIn (calleeRelated.rename _) (Code.letChain arguments (.refl _) _)

/-- 穴の直接参照を保ち、固定式の計算だけを対応させる。 -/
inductive Plans (source : Program) (rows : PredicateProjection.Table.Rows) : List ArgPlan → List ArgPlan → Prop
  | nil : Plans source rows [] []
  | direct {value rest targets} : Plans source rows rest targets →
      Plans source rows (.direct value :: rest) (.direct value :: targets)
  | evaluate {computation target rest targets} : Code source rows computation target → Plans source rows rest targets →
      Plans source rows (.evaluate computation :: rest) (.evaluate target :: targets)

private theorem plans_evaluations {source rows plans targets} (related : Plans source rows plans targets) :
    Codes source rows (argEvals plans) (argEvals targets) := by
  induction related with
  | nil => exact .nil
  | direct tail ih => exact ih
  | evaluate head tail ih => exact .cons head ih

private theorem plans_values {source rows plans targets} (related : Plans source rows plans targets) (shift : Nat) :
    argValues shift plans = argValues shift targets := by
  induction related with
  | nil => rfl
  | direct tail ih => exact congrArg (List.cons _) ih
  | evaluate head tail ih =>
    simp only [argValues, (plans_evaluations tail).length, ih]

/-- 部分適用の固定式も、同じ穴の直接参照を残して順に束縛する。 -/
theorem Code.sequenceArgs {source rows plans targets finish targetFinish}
    (related : Plans source rows plans targets)
    (body : ∀ values, Code source rows (finish values) (targetFinish values)) (depth : Nat) :
    Code source rows (sequenceArgs depth plans finish) (sequenceArgs depth targets targetFinish) := by
  have same : (argEvals plans).length = (argEvals targets).length := (plans_evaluations related).length
  simp only [Surface.sequenceArgs, ← same, ← plans_values related]
  exact Code.letChain (plans_evaluations related) (body _) depth

/-- 部分適用のcalleeと固定式を対応させ、直接参照と位置表を保つ。 -/
theorem Code.callArgs {source rows f targetF callee targetCallee plans targets}
    (heads : directCallee f = directCallee targetF)
    (calleeRelated : Code source rows callee targetCallee) (arguments : Plans source rows plans targets)
    (shift : Nat) (positions : List Nat) :
    Code source rows (callArgs shift f callee positions plans) (callArgs shift targetF targetCallee positions targets) := by
  have same : (argEvals plans).length = (argEvals targets).length := (plans_evaluations arguments).length
  simp only [Surface.callArgs, heads, ← same]
  cases directCallee targetF with
  | some head => exact Code.sequenceArgs arguments (fun _ => .refl _) 0
  | none => exact .letIn (calleeRelated.rename _) (Code.sequenceArgs arguments (fun _ => .refl _) 1)

/-- 同じ型・効果の穴ラムダは、本体の計算の対応を値の対応へ写す。 -/
theorem Value.holeLam {source rows names parameters result effect body target}
    (related : Code source rows body target) :
    Value source rows (holeLam names parameters result effect body) (holeLam names parameters result effect target) := by
  unfold Surface.holeLam
  split
  · exact .lam related
  · exact .dependentLam related

/-- 原因・任意の説明の計算を対応させ、既存の終了呼出しを保つ。 -/
theorem Code.dieFailure {source rows cause targetCause message targetMessage}
    (related : Code source rows cause targetCause)
    (messages : Option.Rel (Code source rows) message targetMessage)
    (type : Ty) (exit : PrimName) (depth : Nat) :
    Code source rows (dieFailure type exit depth cause message) (dieFailure type exit depth targetCause targetMessage) := by
  cases messages with
  | none => exact .letIn related (.refl _)
  | some messageRelated => exact .letIn (messageRelated.rename _) (.letIn (related.rename _) (.refl _))

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
