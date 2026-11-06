import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarSource
import Benitoite.Release.Refinement.Surface.PredicateSimulationPipeSafety

/-! # 公開の引数の並べ替えと、実際に解析した値の対応 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

private theorem fieldAt_selected {positions : List Nat} {values : List α} {index position : Nat} {value : α}
    (distinct : positions.Nodup) (selectedPosition : positions[index]? = some position)
    (selectedValue : values[index]? = some value) : fieldAt position positions values = some value := by
  induction positions generalizing values index with
  | nil => simp at selectedPosition
  | cons head positions ih =>
    cases values with
    | nil => simp at selectedValue
    | cons first values =>
      cases index with
      | zero =>
        cases selectedPosition
        cases selectedValue
        simp [fieldAt]
      | succ index =>
        simp only [List.getElem?_cons_succ] at selectedPosition selectedValue
        have member : position ∈ positions := List.mem_of_getElem? selectedPosition
        have different : position ≠ head := by
          intro equal
          exact (List.nodup_cons.mp distinct).1 (equal ▸ member)
        simp only [fieldAt, different, ↓reduceIte]
        exact ih (List.nodup_cons.mp distinct).2 selectedPosition selectedValue

private theorem recordFields_contains {positions : List Nat} {values : List α} {count : Nat} {value : α}
    (permutation : positions.Perm (List.range count)) (length : values.length = count)
    (member : value ∈ values) (fallback : α) : value ∈ recordFields count positions values fallback := by
  obtain ⟨index, bound, equal⟩ := List.getElem_of_mem member
  have positionBound : index < positions.length := by
    rw [permutation.length_eq, List.length_range]
    omega
  let position := positions[index]
  have selectedPosition : positions[index]? = some position := List.getElem?_eq_getElem positionBound
  have selectedValue : values[index]? = some value := by simpa only [equal] using List.getElem?_eq_getElem bound
  have selected := fieldAt_selected (permutation.nodup_iff.mpr (List.nodup_range)) selectedPosition selectedValue
  have within : position < count := List.mem_range.mp (permutation.mem_iff.mp (List.mem_of_getElem? selectedPosition))
  exact List.mem_map.mpr ⟨position, List.mem_range.mpr within, by simp only [selected, Option.getD_some]⟩

private theorem stripParens_idem (expression : Expr) :
    PredicateCalls.stripParens (PredicateCalls.stripParens expression) = PredicateCalls.stripParens expression := by
  cases expression <;> try rfl
  case paren expression => exact stripParens_idem expression
termination_by structural expression

private theorem identified_target_member {api arguments entry target}
    (identified : PredicateCalls.identify api arguments = some (entry, target)) :
    target ∈ arguments.map PredicateCalls.stripParens := by
  have specification := PredicateCalls.identify_spec identified
  generalize normalized : arguments.map PredicateCalls.stripParens = normalizedArguments at specification ⊢
  cases specification <;> simp

private theorem identified_target_stripped {api arguments entry target}
    (identified : PredicateCalls.identify api arguments = some (entry, target)) :
    PredicateCalls.stripParens target = target := by
  obtain ⟨expression, member, equal⟩ := List.mem_map.mp (identified_target_member identified)
  rw [← equal]
  exact stripParens_idem expression

private def expressionValue (expression : Expr) : Val :=
  (PredicateCalls.stripParens expression).valueOf?.getD (.const .unit)

private theorem identified_scalar_inputs {api arguments entry target value}
    (identified : PredicateCalls.identify api arguments = some (entry, target))
    (isValue : (PredicateCalls.stripParens target).valueOf? = some value) :
    ScalarInputs api entry (arguments.map expressionValue) value ∧
      ∀ expression ∈ arguments, ∃ value, (PredicateCalls.stripParens expression).valueOf? = some value := by
  have targetValue : target.valueOf? = some value := by
    simpa only [identified_target_stripped identified] using isValue
  have mapping : arguments.map expressionValue =
      (arguments.map PredicateCalls.stripParens).map (fun expression => expression.valueOf?.getD (.const .unit)) := by
    rw [List.map_map]
    rfl
  have allValues (normalized : List Expr)
      (same : arguments.map PredicateCalls.stripParens = normalized)
      (values : ∀ expression ∈ normalized, ∃ value, expression.valueOf? = some value) :
      ∀ expression ∈ arguments, ∃ value, (PredicateCalls.stripParens expression).valueOf? = some value := by
    intro expression member
    exact values _ (same ▸ List.mem_map.mpr ⟨expression, member, rfl⟩)
  have specification := PredicateCalls.identify_spec identified
  generalize normalized : arguments.map PredicateCalls.stripParens = normalizedArguments at specification
  rw [normalized] at mapping
  cases specification with
  | path parsed =>
    constructor
    · rw [mapping]
      simp only [List.map_cons, List.map_nil, targetValue, Option.getD_some]
      simpa only [Expr.valueOf?, Literal.toConst, Option.getD_some] using (ScalarInputs.path (value := value) parsed)
    · apply allValues _ normalized
      intro expression member
      simp only [List.mem_cons, List.not_mem_nil, or_false] at member
      rcases member with rfl | rfl
      · exact ⟨_, rfl⟩
      · exact ⟨_, targetValue⟩
  | host parsed =>
    constructor
    · rw [mapping]
      simp only [List.map_cons, List.map_nil, targetValue, Option.getD_some]
      simpa only [Expr.valueOf?, Literal.toConst, Option.getD_some] using (ScalarInputs.host (value := value) parsed)
    · apply allValues _ normalized
      intro expression member
      simp only [List.mem_cons, List.not_mem_nil, or_false] at member
      rcases member with rfl | rfl
      · exact ⟨_, rfl⟩
      · exact ⟨_, targetValue⟩
  | characters lo hi target =>
    constructor
    · rw [mapping]
      simp only [List.map_cons, List.map_nil, targetValue, Option.getD_some]
      simpa only [Expr.valueOf?, Literal.toConst, Option.getD_some] using (ScalarInputs.characters lo hi value)
    · apply allValues _ normalized
      intro expression member
      simp only [List.mem_cons, List.not_mem_nil, or_false] at member
      rcases member with rfl | rfl | rfl
      · exact ⟨_, targetValue⟩
      · exact ⟨_, rfl⟩
      · exact ⟨_, rfl⟩
  | floating width test target =>
    constructor
    · rw [mapping]
      simp only [List.map_cons, List.map_nil, targetValue, Option.getD_some]
      simpa only [Expr.valueOf?, Literal.toConst, Option.getD_some] using (ScalarInputs.floating width test value)
    · apply allValues _ normalized
      intro expression member
      have same : expression = target := by simpa only [List.mem_singleton] using member
      subst expression
      exact ⟨_, targetValue⟩

private theorem argumentValues_of_values {arguments}
    (allValues : ∀ expression ∈ PredicateCalls.expressions arguments,
      ∃ value, (PredicateCalls.stripParens expression).valueOf? = some value) :
    ArgumentValues arguments ((PredicateCalls.expressions arguments).map expressionValue) := by
  cases arguments with
  | nil => exact .nil
  | cons expression arguments =>
    obtain ⟨value, found⟩ := allValues expression (by simp [PredicateCalls.expressions])
    have actual : expressionValue expression = value := by simp only [expressionValue, found, Option.getD_some]
    simpa only [PredicateCalls.expressions, List.map_cons, actual] using
      (ArgumentValues.cons found (argumentValues_of_values (by intro expression member; exact allValues expression (List.mem_cons_of_mem _ member))))

termination_by structural arguments

private theorem expressions_length (arguments : Exprs) :
    (PredicateCalls.expressions arguments).length = arguments.length := by
  cases arguments with
  | nil => rfl
  | cons expression rest => exact congrArg Nat.succ (expressions_length rest)
termination_by structural arguments

/-- 実identifyと位置表の全域性だけから、元の全引数をscalar根へ接続する。 -/
theorem scalar_identified_arguments_code
    {source rows api name labels positions arguments resolvedArguments entry target key output}
    (op : OpPrim) (position : Position) (selected : PredicateCalls.apiOfName name = some api)
    (allowed : CallOk api.names api.inputs.length false labels positions)
    (count : resolvedArguments.length = api.inputs.length)
    (identified : PredicateCalls.identify api
      (recordFields api.inputs.length positions (PredicateCalls.expressions resolvedArguments) .unit) = some (entry, target))
    (argumentsRelated : Codes source rows (desugarExprs op arguments) (desugarExprs op resolvedArguments))
    (lookup : rows.lookup key = some (.scalar entry))
    (resolved : PredicateCalls.resolvedCall key entry target = some output) :
    Code source rows (desugarExpr op position (.call (.primName name [] [] []) labels positions arguments))
      (desugarExpr op position output) := by
  obtain ⟨value, term, isValue, observed, encoded, desugared, same⟩ :=
    PredicateCalls.resolvedCall_desugar resolved op position
  obtain ⟨inputs, allDeclared⟩ := identified_scalar_inputs identified isValue
  have permutation : positions.Perm (List.range api.inputs.length) := by
    simpa using allowed.2.2.2.1
  have allSource : ∀ expression ∈ PredicateCalls.expressions resolvedArguments,
      ∃ value, (PredicateCalls.stripParens expression).valueOf? = some value := by
    intro expression member
    exact allDeclared expression (recordFields_contains permutation ((expressions_length _).trans count) member .unit)
  have parsed := argumentValues_of_values allSource
  have mappedInputs : ScalarInputs api entry
      (recordFields api.inputs.length positions
        ((PredicateCalls.expressions resolvedArguments).map expressionValue) (.const .unit)) value := by
    simpa only [recordFields_map, expressionValue, PredicateCalls.stripParens, Expr.valueOf?, Option.getD_some] using inputs
  exact scalar_resolved_arguments_code op position selected parsed argumentsRelated
    (by simpa only [List.length_map, expressions_length] using count) lookup mappedInputs isValue resolved

private def projectionSymbol (expression : Expr) : Val :=
  match expression.valueOf? with
  | some (.const constant) => .const constant
  | _ => .var 0

private def ProjectionArgumentShape (target expression : Expr) : Prop :=
  expression = target ∨ ∃ constant, expression.valueOf? = some (.const constant)

private theorem identified_projected_inputs {api arguments entry target}
    (identified : PredicateCalls.identify api arguments = some (entry, target))
    (notValue : target.valueOf? = none) :
    ScalarInputs api entry ((arguments.map PredicateCalls.stripParens).map projectionSymbol) (.var 0) ∧
      ∀ expression ∈ arguments.map PredicateCalls.stripParens, ProjectionArgumentShape target expression := by
  have specification := PredicateCalls.identify_spec identified
  generalize normalized : arguments.map PredicateCalls.stripParens = normalizedArguments at specification ⊢
  cases specification with
  | path parsed =>
    constructor
    · simp only [List.map_cons, List.map_nil, projectionSymbol, notValue]
      simpa only [Expr.valueOf?, Literal.toConst] using
        (ScalarInputs.path (value := .var 0) parsed)
    · intro expression member
      simp only [List.mem_cons, List.not_mem_nil, or_false] at member
      rcases member with rfl | rfl
      · exact .inr ⟨_, rfl⟩
      · exact .inl rfl
  | host parsed =>
    constructor
    · simp only [List.map_cons, List.map_nil, projectionSymbol, notValue]
      simpa only [Expr.valueOf?, Literal.toConst] using
        (ScalarInputs.host (value := .var 0) parsed)
    · intro expression member
      simp only [List.mem_cons, List.not_mem_nil, or_false] at member
      rcases member with rfl | rfl
      · exact .inr ⟨_, rfl⟩
      · exact .inl rfl
  | characters lo hi target =>
    constructor
    · simp only [List.map_cons, List.map_nil, projectionSymbol, notValue]
      simpa only [Expr.valueOf?, Literal.toConst] using
        (ScalarInputs.characters lo hi (.var 0))
    · intro expression member
      simp only [List.mem_cons, List.not_mem_nil, or_false] at member
      rcases member with rfl | rfl | rfl
      · exact .inl rfl
      · exact .inr ⟨_, rfl⟩
      · exact .inr ⟨_, rfl⟩
  | floating width test target =>
    constructor
    · simp only [List.map_cons, List.map_nil, projectionSymbol, notValue]
      simpa only [Expr.valueOf?, Literal.toConst] using
        (ScalarInputs.floating width test (.var 0))
    · intro expression member
      exact .inl (by simpa only [List.mem_singleton] using member)

private theorem getter_not_value {source expression root value term steps}
    (getters : PredicateAccessorTargets.Resolved source expression root value term steps)
    (nonempty : steps ≠ []) : (PredicateCalls.stripParens expression).valueOf? = none := by
  induction getters with
  | value found observed => exact False.elim (nonempty rfl)
  | paren child ih => exact ih nonempty
  | accessor => rfl

private theorem getter_type_counts {source expression root value term steps}
    (getters : PredicateAccessorTargets.Resolved source expression root value term steps) :
    ∀ step ∈ steps, step.types.length = step.declaration.ntys := by
  induction getters with
  | value found observed => intro step member; cases member
  | paren child ih => exact ih
  | @accessor step labels receiver root value term steps field missing accessor declaration selected sort count allowed child ih =>
    intro actual member
    rcases List.mem_append.mp member with member | member
    · exact ih actual member
    · have equal : actual = step := by simpa only [List.mem_singleton] using member
      exact equal ▸ count

private theorem projected_candidate_shape {source expression}
    {parsed : PredicateAccessorTargets.Parsed source expression} {entry projection types}
    (candidate : PredicateProjectionCalls.candidate parsed entry = some (projection, types)) :
    parsed.steps ≠ [] ∧ projection.route = parsed.steps.map PredicateAccessorTargets.Step.reference ∧
      projection.entry = entry ∧ types.length = projection.ntys := by
  cases steps : parsed.steps with
  | nil => simp only [PredicateProjectionCalls.candidate, steps] at candidate; cases candidate
  | cons first rest =>
    simp only [PredicateProjectionCalls.candidate, steps] at candidate
    split at candidate
    · cases candidate
      exact ⟨by simp, rfl, rfl, getter_type_counts parsed.sound first (by simp [steps])⟩
    · cases candidate

private theorem projection_arguments_of_shapes {source expression arguments}
    (parsed : PredicateAccessorTargets.Parsed source expression) (notValue : expression.valueOf? = none)
    (shapes : ∀ argument ∈ PredicateCalls.expressions arguments,
      ProjectionArgumentShape expression (PredicateCalls.stripParens argument)) (op : OpPrim) :
    ProjectionArguments source parsed.value parsed.steps (desugarExprs op arguments)
      ((PredicateCalls.expressions arguments).map (fun argument => projectionSymbol (PredicateCalls.stripParens argument))) := by
  cases arguments with
  | nil => exact .nil
  | cons argument arguments =>
    have tail := projection_arguments_of_shapes parsed notValue
      (by intro argument member; exact shapes argument (List.mem_cons_of_mem _ member)) op
    rcases shapes argument (by simp [PredicateCalls.expressions]) with same | ⟨constant, found⟩
    · have getter : GetterCode source (desugarExpr op .other argument) parsed.value parsed.steps := by
        rw [← PredicateCalls.stripParens_desugar, same]
        exact getter_source_code parsed.sound op .other
      have symbol : projectionSymbol (PredicateCalls.stripParens argument) = .var 0 := by
        simp only [same, projectionSymbol, notValue]
      simpa only [desugarExprs, PredicateCalls.expressions, List.map_cons, symbol] using
        (ProjectionArguments.target getter tail)
    · have computation : desugarExpr op .other argument = .ret (.const constant) := by
        rw [← PredicateCalls.stripParens_desugar]
        exact desugar_valueOf found
      have symbol : projectionSymbol (PredicateCalls.stripParens argument) = .const constant := by
        simp only [projectionSymbol, found]
      simpa only [desugarExprs, PredicateCalls.expressions, List.map_cons, computation, symbol] using
        (ProjectionArguments.constant constant tail)
termination_by structural arguments

/-- 実投影の解析と宣言順identifyから、元の引数の全計算をprojected根へ接続する。 -/
theorem projected_identified_arguments_code
    {source rows api name labels positions arguments resolvedArguments entry target output}
    (op : OpPrim) (position : Position) (selected : PredicateCalls.apiOfName name = some api)
    (allowed : CallOk api.names api.inputs.length false labels positions)
    (count : resolvedArguments.length = api.inputs.length)
    (identified : PredicateCalls.identify api
      (recordFields api.inputs.length positions (PredicateCalls.expressions resolvedArguments) .unit) = some (entry, target))
    (argumentsRelated : Codes source rows (desugarExprs op arguments) (desugarExprs op resolvedArguments))
    (resolved : PredicateProjectionCalls.resolve rows source entry target = some output) :
    Code source rows (desugarExpr op position (.call (.primName name [] [] []) labels positions arguments))
      (desugarExpr op position output) := by
  obtain ⟨parsed, projection, types, key, term, parse, candidate, lookup, observed, rfl⟩ :=
    PredicateProjectionCalls.resolve_spec resolved
  obtain ⟨nonempty, route, entryEqual, typeCount⟩ := projected_candidate_shape candidate
  have targetNone : target.valueOf? = none := by
    simpa only [identified_target_stripped identified] using getter_not_value parsed.sound nonempty
  obtain ⟨inputs, allDeclared⟩ := identified_projected_inputs identified targetNone
  have permutation : positions.Perm (List.range api.inputs.length) := by
    simpa using allowed.2.2.2.1
  have allSource : ∀ expression ∈ PredicateCalls.expressions resolvedArguments,
      ProjectionArgumentShape target (PredicateCalls.stripParens expression) := by
    intro expression member
    exact allDeclared _ (List.mem_map.mpr ⟨expression,
      recordFields_contains permutation ((expressions_length _).trans count) member .unit, rfl⟩)
  have parsedArguments := projection_arguments_of_shapes parsed targetNone allSource op
  have simple : SimpleValue parsed.value := SimpleValue.of_valueOf parsed.root_value
  have computationsEqual := parsedArguments.rigid simple argumentsRelated
  have mappedInputs : ScalarInputs api projection.entry
      (recordFields api.inputs.length positions
        ((PredicateCalls.expressions resolvedArguments).map (fun argument => projectionSymbol (PredicateCalls.stripParens argument)))
        (.const .unit)) (.var 0) := by
    have mapping :
        ((recordFields api.inputs.length positions (PredicateCalls.expressions resolvedArguments) Expr.unit).map
          PredicateCalls.stripParens).map projectionSymbol =
        recordFields api.inputs.length positions
          ((PredicateCalls.expressions resolvedArguments).map (fun argument => projectionSymbol (PredicateCalls.stripParens argument)))
          (.const .unit) := by
      rw [List.map_map, recordFields_map]
      rfl
    rw [mapping] at inputs
    simpa only [entryEqual] using inputs
  rw [source_call_desugar op position selected computationsEqual (by simpa only [desugarExprs_length] using count)]
  unfold PredicateProjectionCalls.encodedCall
  rw [desugar_predicateProject parsed.root_value]
  exact .projected lookup route parsedArguments mappedInputs
    (by simpa only [desugarExprs_length] using count) typeCount simple (Value.refl parsed.value)

private theorem scalarName_lookup {rows entry key}
    (selected : PredicateProjectionCalls.scalarName rows entry = some key) :
    rows.lookup key = some (.scalar entry) := by
  unfold PredicateProjectionCalls.scalarName at selected
  obtain ⟨row, found, equal⟩ := Option.map_eq_some_iff.mp selected
  have valid : row.2 = .scalar entry ∧ rows.lookup row.1 = some (.scalar entry) :=
    of_decide_eq_true (List.find?_some
      (p := fun (row : PrimName × PredicateProjection.Row) =>
        decide (row.2 = .scalar entry ∧ rows.lookup row.1 = some (.scalar entry))) found)
  cases equal
  exact valid.2

/-- 全公開呼出しの実resolverは、子のコード対応から元call全体のコード対応を作る。 -/
theorem resolveCall_source_code {source rows name labels positions arguments resolvedArguments}
    (op : OpPrim) (position : Position)
    (argumentsRelated : Codes source rows (desugarExprs op arguments) (desugarExprs op resolvedArguments)) :
    Code source rows (desugarExpr op position (.call (.primName name [] [] []) labels positions arguments))
      (desugarExpr op position (PredicateProjectionCalls.resolveCall rows source name labels positions resolvedArguments)) := by
  have fallback : Code source rows
      (desugarExpr op position (.call (.primName name [] [] []) labels positions arguments))
      (desugarExpr op position (.call (.primName name [] [] []) labels positions resolvedArguments)) :=
    Code.callComp rfl (.refl _) argumentsRelated 0 [] positions
  unfold PredicateProjectionCalls.resolveCall
  split
  · exact fallback
  · rename_i api selected
    split
    · rename_i allowed
      split
      · exact fallback
      · rename_i entry target identified
        cases projected : PredicateProjectionCalls.resolve rows source entry target with
        | some output =>
          simpa only [Option.orElse, Option.getD] using
            projected_identified_arguments_code op position selected allowed.1 allowed.2 identified argumentsRelated projected
        | none =>
          cases chosen : PredicateProjectionCalls.scalarName rows entry with
          | none => simpa only [Option.orElse, Option.bind, Option.getD] using fallback
          | some key =>
            cases scalar : PredicateCalls.resolvedCall key entry target with
            | none => simpa only [Option.orElse, Option.bind, Option.getD, scalar] using fallback
            | some output =>
              simpa only [Option.orElse, Option.bind, Option.getD, scalar] using
                scalar_identified_arguments_code op position selected allowed.1 allowed.2 identified
                  argumentsRelated (scalarName_lookup chosen) scalar
    · exact fallback

private theorem value_safe {expression value} (valued : expression.valueOf? = some value) : SafeExpr expression := by
  cases expression <;> simp_all only [Expr.valueOf?, SafeExpr, reduceCtorEq]

private theorem strip_safe (expression : Expr) (safe : SafeExpr (PredicateCalls.stripParens expression)) : SafeExpr expression := by
  cases expression <;> try exact safe
  case paren expression => exact strip_safe expression safe
termination_by structural expression

private theorem getter_safe {source expression root value term steps}
    (getters : PredicateAccessorTargets.Resolved source expression root value term steps) : SafeExpr expression := by
  induction getters with
  | value valued observed => exact value_safe valued
  | paren child ih => exact ih
  | accessor missing accessor declaration selected sort count allowed child ih => exact ⟨True.intro, ih, True.intro⟩

private theorem arguments_safe {arguments : Exprs}
    (safe : ∀ expression ∈ PredicateCalls.expressions arguments, SafeExpr (PredicateCalls.stripParens expression)) :
    SafeExprs arguments := by
  cases arguments with
  | nil => exact True.intro
  | cons expression arguments =>
    exact ⟨strip_safe expression (safe expression List.mem_cons_self),
      arguments_safe (fun expression member => safe expression (List.mem_cons_of_mem _ member))⟩
termination_by structural arguments

private theorem scalar_arguments_safe {api labels positions arguments entry target value}
    (allowed : CallOk api.names api.inputs.length false labels positions) (count : arguments.length = api.inputs.length)
    (identified : PredicateCalls.identify api
      (recordFields api.inputs.length positions (PredicateCalls.expressions arguments) .unit) = some (entry, target))
    (valued : (PredicateCalls.stripParens target).valueOf? = some value) : SafeExprs arguments := by
  obtain ⟨inputs, allDeclared⟩ := identified_scalar_inputs identified valued
  have permutation : positions.Perm (List.range api.inputs.length) := by simpa using allowed.2.2.2.1
  apply arguments_safe
  intro expression member
  obtain ⟨value, found⟩ := allDeclared expression
    (recordFields_contains permutation ((expressions_length _).trans count) member .unit)
  exact value_safe found

private theorem projected_arguments_safe {source rows api labels positions arguments entry target output}
    (allowed : CallOk api.names api.inputs.length false labels positions) (count : arguments.length = api.inputs.length)
    (identified : PredicateCalls.identify api
      (recordFields api.inputs.length positions (PredicateCalls.expressions arguments) .unit) = some (entry, target))
    (resolved : PredicateProjectionCalls.resolve rows source entry target = some output) : SafeExprs arguments := by
  obtain ⟨parsed, projection, types, key, term, parse, candidate, lookup, observed, encoded⟩ :=
    PredicateProjectionCalls.resolve_spec resolved
  obtain ⟨nonempty, route, entryEqual, typeCount⟩ := projected_candidate_shape candidate
  have notValue : target.valueOf? = none := by
    simpa only [identified_target_stripped identified] using getter_not_value parsed.sound nonempty
  obtain ⟨inputs, allDeclared⟩ := identified_projected_inputs identified notValue
  have permutation : positions.Perm (List.range api.inputs.length) := by simpa using allowed.2.2.2.1
  apply arguments_safe
  intro expression member
  have shape := allDeclared _ (List.mem_map.mpr ⟨expression,
    recordFields_contains permutation ((expressions_length _).trans count) member .unit, rfl⟩)
  rcases shape with same | ⟨constant, found⟩
  · rw [same]
    exact getter_safe parsed.sound
  · exact value_safe found

/-- 成功根で省略する引数も固定値かgetterだけであり、全ての元引数に構文上の安全性を戻せる。 -/
theorem resolveCall_arguments_safe {source rows name labels positions arguments}
    (safe : SafeExpr (PredicateProjectionCalls.resolveCall rows source name labels positions arguments)) :
    SafeExprs arguments := by
  unfold PredicateProjectionCalls.resolveCall at safe
  split at safe
  · exact safe.2
  · rename_i api selected
    split at safe
    · rename_i allowed
      split at safe
      · exact safe.2
      · rename_i entry target identified
        cases projected : PredicateProjectionCalls.resolve rows source entry target with
        | some output => exact projected_arguments_safe allowed.1 allowed.2 identified projected
        | none =>
          cases chosen : PredicateProjectionCalls.scalarName rows entry with
          | none =>
            have fallback := safe
            simp only [projected, chosen, Option.orElse, Option.bind, Option.getD] at fallback
            exact fallback.2
          | some key =>
            cases scalar : PredicateCalls.resolvedCall key entry target with
            | none =>
              have fallback := safe
              simp only [projected, chosen, scalar, Option.orElse, Option.bind, Option.getD] at fallback
              exact fallback.2
            | some output =>
              obtain ⟨value, term, valued, observed, encoded, desugared, same⟩ :=
                PredicateCalls.resolvedCall_desugar scalar (fun _ _ => none) .other
              exact scalar_arguments_safe allowed.1 allowed.2 identified valued
    · exact safe.2

private theorem projected_pipe_impossible {source rows entry target output}
    (resolved : PredicateProjectionCalls.resolve rows source entry target = some output) (safe : PipeHeadSafe output) : False := by
  obtain ⟨parsed, projection, types, key, term, parse, candidate, lookup, observed, rfl⟩ :=
    PredicateProjectionCalls.resolve_spec resolved
  exact safe _ _ _ _ _ _ _ rfl rfl rfl

private theorem scalar_pipe_impossible {key entry target output}
    (resolved : PredicateCalls.resolvedCall key entry target = some output) (safe : PipeHeadSafe output) : False := by
  obtain ⟨value, term, valued, observed, rfl, desugared, same⟩ :=
    PredicateCalls.resolvedCall_desugar resolved (fun _ _ => none) .other
  exact safe _ _ _ _ _ _ _ rfl rfl rfl

private theorem resolveCall_pipe_unchanged {source rows name labels positions arguments}
    (safe : PipeHeadSafe (PredicateProjectionCalls.resolveCall rows source name labels positions arguments)) :
    PredicateProjectionCalls.resolveCall rows source name labels positions arguments =
      .call (.primName name [] [] []) labels positions arguments := by
  unfold PredicateProjectionCalls.resolveCall at safe ⊢
  split
  · rfl
  · rename_i api named
    simp only [named] at safe
    split
    · rename_i allowed
      simp only [allowed, and_self, ite_true] at safe
      split
      · rfl
      · rename_i entry target identified
        simp only [identified] at safe
        cases projected : PredicateProjectionCalls.resolve rows source entry target with
        | some output =>
          exact False.elim (projected_pipe_impossible projected (by simpa only [projected, Option.orElse, Option.getD] using safe))
        | none =>
          cases chosen : PredicateProjectionCalls.scalarName rows entry with
          | none => rfl
          | some key =>
            cases scalar : PredicateCalls.resolvedCall key entry target with
            | none => simp only [Option.orElse, Option.bind, scalar, Option.getD]
            | some output =>
              exact False.elim (scalar_pipe_impossible scalar (by
                simpa only [projected, chosen, Option.orElse, Option.bind, scalar, Option.getD] using safe))
    · rfl

/-- 型付きパイプのrhsがcallなら、実解決後にも同じcallの形が残る。 -/
theorem pipe_call_resolution {source rows head labels positions arguments}
    (safe : PipeHeadSafe (PredicateProjectionCalls.resolveExpr rows source (.call head labels positions arguments))) :
    PredicateProjectionCalls.resolveExpr rows source (.call head labels positions arguments) =
      .call (PredicateProjectionCalls.resolveExpr rows source head) labels positions
        (PredicateCalls.resolveExprsWith (PredicateProjectionCalls.resolveCall rows source) arguments) := by
  cases head <;> try rfl
  case primName name types effects ranges =>
    cases types <;> cases effects <;> cases ranges <;> try rfl
    exact resolveCall_pipe_unchanged safe

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
