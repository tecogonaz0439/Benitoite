import Benitoite.Release.Refinement.Surface.CheckPreparation
import Benitoite.Release.Refinement.SurfaceLibrary
import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarInputs

/-! # getterの元の脱糖と、宣言に照合した欄の列 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateAccessorTargets
noncomputable section

/-- getter呼出しの、引数を一つ束縛した後の本体。 -/
def getterCall (step : PredicateAccessorTargets.Step) : Comp :=
  .app (.fnRef step.function (shiftTs 1 step.types) [] []) [.var 0]

/-- 元のgetter名・構成子・欄の位置を、同じsourceの表へ照合した呼出しの列。 -/
inductive GetterCode (source : Program) : Comp → Val → List PredicateAccessorTargets.Step → Prop
  | value (v) : GetterCode source (.ret v) v []
  | accessor {step : PredicateAccessorTargets.Step} {body root steps field} :
      source.defs step.function = none → source.accessors step.function = some (step.constructor, step.position) →
      source.cons step.constructor = some step.declaration →
      step.declaration.args[step.position]? = some field → field.sort? = some step.sort →
      step.types.length = step.declaration.ntys → GetterCode source body root steps →
      GetterCode source (.letIn body (getterCall step)) root (steps ++ [step])

/-- 同じsourceが生成したgetterを実行時の定義表が保持する。 -/
structure GetterEnvironment (source : Program) (P : Refinement.Program) : Prop where
  constructors : ∀ constructor declaration, source.cons constructor = some declaration → P.cons constructor = some declaration
  lookup : ∀ function constructor position declaration,
    source.defs function = none → source.accessors function = some (constructor, position) →
    source.cons constructor = some declaration → P.defs function = some (accessorDef constructor declaration position)

/-- 通常の脱糖は、sourceのgetter表と同じ定義を生成する。 -/
theorem getter_environment (source : Program) (op : OpPrim) : GetterEnvironment source (desugarProgram op source) where
  constructors := by intro constructor declaration found; exact found
  lookup := by
    intro function constructor position declaration missing accessor found
    simp [desugarProgram, Program.lookupFun, missing, accessor, found]

/-- 同じbaseを結合しても、元のsourceが生成したgetterのlookupを保持する。 -/
theorem GetterEnvironment.link {source program : Program} {op : OpPrim}
    (environment : GetterEnvironment source (desugarProgram op program)) (base : Refinement.Program) :
    GetterEnvironment source (linkProgram base op program) where
  constructors := environment.constructors
  lookup := by
    intro function constructor position declaration missing accessor found
    exact link_lookup (environment.lookup function constructor position declaration missing accessor found)

private theorem accessor_desugar (op : OpPrim) (position : Position) (step : PredicateAccessorTargets.Step)
    (labels : List (Option String)) (receiver : Expr) :
    desugarExpr op position (.call (.funName step.function step.types [] []) labels [0] (.cons receiver .nil)) =
      .letIn (desugarExpr op .other receiver) (getterCall step) := by
  simp only [desugarExpr, desugarExprs, callComp, directCallee, letChain,
    List.length_nil, List.length_cons, Nat.zero_add, Nat.add_zero, List.nil_append, boundVars,
    List.range_succ, List.range_zero, List.map_cons, List.map_nil, List.reverse_cons, List.reverse_nil,
    List.nil_append, CallHead.rename, CallHead.apply,
    Val.rename, Val.renameList, getterCall, shiftTs, recordFields, fieldAt]
  congr 2
  · exact Comp.rename_identity _
  · congr 1
    apply List.map_congr_left
    intro type _
    rw [Ty.shiftV_eq_renameTy]
    congr 1

/-- 実際のgetter解析の証拠から、元の全呼出しの脱糖の列を得る。 -/
theorem getter_source_code {source expression root value term steps}
    (resolved : Resolved source expression root value term steps) (op : OpPrim) (position : Position) :
    GetterCode source (desugarExpr op position expression) value steps := by
  induction resolved generalizing position with
  | value value term =>
    rw [desugar_valueOf value]
    exact .value _
  | paren child ih => exact ih position
  | @accessor step labels receiver root value term steps field missing accessor found fieldFound sort count allowed child ih =>
    rw [accessor_desugar]
    exact .accessor missing accessor found fieldFound sort count (ih .other)


/-- valueOf?が受け入れる構文自体は、再帰的な判定の呼出しを持たない。 -/
theorem value_source_unchanged {expression value} (isValue : expression.valueOf? = some value)
    (rows : PredicateProjection.Table.Rows) (source : Program) :
    PredicateProjectionCalls.resolveExpr rows source expression = expression := by
  cases expression <;> first | rfl | cases isValue

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
