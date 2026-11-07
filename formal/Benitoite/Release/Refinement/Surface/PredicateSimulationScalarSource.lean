import Benitoite.Release.Refinement.Surface.PredicateSimulationSourceRoots
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionInputs

/-! # 値の引数を持つ元の公開呼出しの脱糖 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

/-- 括弧を除いた各引数の構文が、同じソース順の値を直接返す。 -/
inductive ArgumentValues : Exprs → List Val → Prop
  | nil : ArgumentValues .nil []
  | cons {expression value rest values} :
      (PredicateCalls.stripParens expression).valueOf? = some value → ArgumentValues rest values →
      ArgumentValues (.cons expression rest) (value :: values)

/-- 元の解析が受け入れた全引数は、直接値の構文の形を持つ。 -/
theorem ArgumentValues.simple {arguments values} (parsed : ArgumentValues arguments values) : SimpleValues values := by
  induction parsed with
  | nil => intro value member; cases member
  | cons found tail ih =>
    intro value member
    rcases List.mem_cons.mp member with same | member
    · cases same; exact SimpleValue.of_valueOf found
    · exact ih value member

private theorem expression_unchanged {expression value}
    (isValue : (PredicateCalls.stripParens expression).valueOf? = some value)
    (rows : PredicateProjection.Table.Rows) (source : Program) :
    PredicateProjectionCalls.resolveExpr rows source expression = expression := by
  cases expression
  case paren expression => exact congrArg Expr.paren (expression_unchanged (expression := expression) isValue rows source)
  all_goals exact value_source_unchanged isValue rows source
termination_by structural expression

/-- 値だけの元の引数列は、再帰的な解決でも変わらない。 -/
theorem ArgumentValues.unchanged {arguments values} (parsed : ArgumentValues arguments values)
    (rows : PredicateProjection.Table.Rows) (source : Program) :
    PredicateCalls.resolveExprsWith (PredicateProjectionCalls.resolveCall rows source) arguments = arguments := by
  induction parsed with
  | nil => rfl
  | cons value tail ih =>
    change Exprs.cons (PredicateProjectionCalls.resolveExpr rows source _) _ = _
    rw [expression_unchanged value rows source, ih]

/-- 値だけの元の引数列は、ソース順のreturnの列に脱糖する。 -/
theorem ArgumentValues.desugar {arguments values} (parsed : ArgumentValues arguments values) (op : OpPrim) :
    desugarExprs op arguments = values.map Comp.ret := by
  induction parsed with
  | nil => rfl
  | cons value tail ih =>
    simp only [desugarExprs, List.map_cons, ih]
    rw [← PredicateCalls.stripParens_desugar, desugar_valueOf value]

private theorem selected_name {name api} (selected : PredicateCalls.apiOfName name = some api) : api.name = name := by
  unfold PredicateCalls.apiOfName at selected
  split at selected <;> cases selected <;> rfl

/-- ソース順の引数の脱糖の列から、公開呼出し全体の脱糖を組み立てる。 -/
theorem source_call_desugar {api name labels positions arguments computations}
    (op : OpPrim) (position : Position) (selected : PredicateCalls.apiOfName name = some api)
    (argumentsCode : desugarExprs op arguments = computations) (count : computations.length = api.inputs.length) :
    desugarExpr op position (.call (.primName name [] [] []) labels positions arguments) =
      sourceCall api positions computations := by
  rw [desugarExpr, argumentsCode]
  simp only [callComp, directCallee, CallHead.rename, CallHead.apply, Val.renameList, Val.rename, List.map_nil,
    List.length_nil, Nat.zero_add, List.range_zero, List.nil_append]
  rw [← selected_name selected]
  simp only [sourceCall, count]

/-- 解決後に単純な値を返す引数へのコード対応から、元callの同じ内部行への対応を得る。 -/
theorem scalar_resolved_arguments_code {source rows api name labels positions arguments resolvedArguments values entry target value key output}
    (op : OpPrim) (position : Position) (selected : PredicateCalls.apiOfName name = some api)
    (parsed : ArgumentValues resolvedArguments values)
    (argumentsRelated : Codes source rows (desugarExprs op arguments) (desugarExprs op resolvedArguments))
    (count : values.length = api.inputs.length) (lookup : rows.lookup key = some (.scalar entry))
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (isValue : (PredicateCalls.stripParens target).valueOf? = some value)
    (resolved : PredicateCalls.resolvedCall key entry target = some output) :
    Code source rows (desugarExpr op position (.call (.primName name [] [] []) labels positions arguments))
      (desugarExpr op position output) := by
  rw [parsed.desugar op] at argumentsRelated
  have originalArguments := argumentsRelated.simple_returns parsed.simple
  obtain ⟨actual, term, actualValue, observed, encoded, desugared, same⟩ :=
    PredicateCalls.resolvedCall_desugar resolved op position
  have equal : actual = value := Option.some.inj (actualValue.symm.trans isValue)
  subst actual
  rw [source_call_desugar op position selected originalArguments (by simpa only [List.length_map] using count), desugared]
  simpa only [sourceCall, scalarCall, List.length_map] using
    (Code.scalar lookup count inputs parsed.simple (Value.refl value))

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
