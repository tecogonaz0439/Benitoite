import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionValues
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarControl
import Benitoite.Release.Refinement.Surface.PredicateSimulationAdministrativePath
import Benitoite.Release.Refinement.PatternBindingSupport
import Benitoite.Release.Refinement.CaptureApplicationAlgebra

/-! # getterの構成子照合と、同じ欄の葉への有限実行 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open MatchFacts PatternBindings
noncomputable section

private theorem selected_type {P B Ψ Q C Γ Φ values types value} {index : Nat}
    (typed : HasTypeVsQ P B Ψ Q C Γ Φ values types) (selected : values[index]? = some value) :
    ∃ type, HasTypeVQ P B Ψ Q C Γ Φ value type := by
  match typed with
  | .nil => simp at selected
  | .cons head tail =>
    cases index with
    | zero => cases selected; exact ⟨_, head⟩
    | succ index => exact selected_type (index := index) tail selected
termination_by structural typed

private theorem typed_constructor_fields {P B Ψ value type constructor values declaration}
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] value type)
    (fields : conFields? value = some (constructor, values)) (found : P.cons constructor = some declaration) :
    values.length = declaration.args.length ∧
      ∀ (index : Nat) leaf, values[index]? = some leaf → ∃ type, HasTypeVQ P B Ψ Qempty [] [] [] leaf type := by
  cases value <;> simp only [conFields?] at fields
  all_goals try cases fields
  case con types =>
    obtain ⟨actual, actualFound, count, kinded, annotation, typedFields, rest⟩ := typed.inv_con rfl
    have same : actual = declaration := Option.some.inj (actualFound.symm.trans found)
    subst actual
    exact ⟨by simpa only [List.length_map] using typedFields.length,
      fun index leaf selected => selected_type typedFields selected⟩
  case atError detail =>
    obtain ⟨actual, actualFound, count, arguments, scopePublic⟩ := atError_declaration typed rfl
    have same : actual = declaration := Option.some.inj (actualFound.symm.trans found)
    subst actual
    have typedFields := detail.values_typed P B Ψ Qempty [] [] [] scopePublic
    exact ⟨by rw [arguments]; exact typedFields.length,
      fun index leaf selected => selected_type typedFields selected⟩

private theorem typed_path {P B Ψ value type route leaf}
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] value type) (read : readPath value route = some leaf) :
    ∃ type, HasTypeVQ P B Ψ Qempty [] [] [] leaf type := by
  induction route generalizing value type with
  | nil => cases read; exact ⟨_, typed⟩
  | cons field route ih =>
    cases fields : conFields? value with
    | none => simp [readPath, fields] at read
    | some pair =>
      rcases pair with ⟨constructor, values⟩
      by_cases same : constructor = field.constructor
      · cases selected : values[field.position]? with
        | none => simp [readPath, fields, same, selected] at read
        | some current =>
          have typedField : ∃ type, HasTypeVQ P B Ψ Qempty [] [] [] current type := by
            cases value <;> simp only [conFields?] at fields
            all_goals try cases fields
            case con types =>
              obtain ⟨declaration, found, count, kinded, annotation, typedFields, rest⟩ := typed.inv_con rfl
              exact selected_type typedFields selected
            case atError detail =>
              obtain ⟨declaration, found, count, arguments, scopePublic⟩ := atError_declaration typed rfl
              exact selected_type (detail.values_typed P B Ψ Qempty [] [] [] scopePublic) selected
          obtain ⟨currentType, currentTyped⟩ := typedField
          exact ih currentTyped (by simpa [readPath, fields, same, selected] using read)
      · simp [readPath, fields, same] at read

private theorem accessor_binders_aux (indices : List Nat) (position : Nat) :
    Pat.bindersList (indices.map (fun index => if index = position then Pat.var else Pat.wild)) = indices.count position := by
  induction indices with
  | nil => rfl
  | cons index indices ih =>
    by_cases same : index = position <;> simp [List.map_cons, Pat.bindersList, Pat.binders, same, ih, Nat.add_comm]

private theorem accessor_binders (constructor : ConName) (count position : Nat) (within : position < count) :
    (accessorPattern constructor count position).binders = 1 := by
  exact (accessor_binders_aux (List.range count) position).trans
    (List.nodup_range.count_of_mem (List.mem_range.mpr within))

private theorem accessor_matches {value constructor values declaration position leaf}
    (fields : conFields? value = some (constructor, values)) (count : values.length = declaration.args.length)
    (selected : values[position]? = some leaf) :
    firstAlt value [accessorAlt constructor declaration position] = some [leaf] := by
  have within : position < declaration.args.length := by
    obtain ⟨bound, equality⟩ := List.getElem?_eq_some_iff.mp selected
    omega
  have irrefutable : (((List.range declaration.args.length).map
      (fun index => if index = position then Pat.var else Pat.wild)).all irrefutableField) = true := by
    apply List.all_eq_true.mpr
    intro pattern member
    obtain ⟨index, member, rfl⟩ := List.mem_map.mp member
    split <;> rfl
  obtain ⟨matched, matchedFields⟩ := irrefutable_fields_match (vs := values) irrefutable (by simpa only [List.length_map, List.length_range] using count.symm)
  have matchedValue : matchVal (accessorPattern constructor declaration.args.length position) value = some matched := by
    cases value <;> simp only [conFields?] at fields
    all_goals try cases fields
    all_goals simpa only [accessorPattern, matchVal, ite_true] using matchedFields
  have length : matched.length = 1 := (matchVal_binders matchedValue).trans (accessor_binders _ _ _ within)
  cases matched with
  | nil => cases length
  | cons head rest =>
    have restEmpty : rest = [] := List.eq_nil_of_length_eq_zero (by simp only [List.length_cons] at length; omega)
    subst rest
    obtain ⟨actual, selectedActual, readActual⟩ := BinderPath.matched (accessor_binderPath constructor declaration position within) matchedValue
    have sameHead : actual = head := by simpa using selectedActual.symm
    subst actual
    have readLeaf : readPath value [accessorRef constructor declaration position] = some leaf := by
      simp [readPath, fields, accessorRef, selected]
    have same : head = leaf := Option.some.inj (readActual.symm.trans readLeaf)
    subst head
    simp only [firstAlt, accessorAlt, accessor_binders _ _ _ within, matchedValue,
      List.range_succ, List.range_zero, List.nil_append, selectSlots, List.getElem?_cons_zero]
    rfl

private theorem typed_observation_closed {P B Ψ value type term}
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] value type) (observed : value.toTerm? = some term) : term.Closed := by
  exact Term.varsIn_mono (typed.observation_references observed)
    (by intro index readable; obtain ⟨type, found, ordinary⟩ := readable; cases found)

private theorem normalize_observation {P B Ψ value target type}
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] target type) (same : value.toTerm? = target.toTerm?)
    (capture : Capture) : (closeVal capture value).toTerm? = target.toTerm? := by
  rw [closeVal_observation, Val.toTerm_subst_optional, same]
  cases observed : target.toTerm? with
  | none => rfl
  | some term => exact Term.bind_closed (typed_observation_closed typed observed) _

private theorem fields_observation {value constructor values}
    (fields : conFields? value = some (constructor, values)) :
    value.toTerm? = some (.dataValue constructor (Val.toTermSlots values)) := by
  cases value <;> simp only [conFields?] at fields
  all_goals try cases fields
  case con types => rfl
  case atError detail => exact Detail.values_toTerm detail

private theorem observation_fields {value constructor slots}
    (observed : value.toTerm? = some (.dataValue constructor slots)) :
    ∃ values, conFields? value = some (constructor, values) ∧ Val.toTermSlots values = slots := by
  cases value
  case const constant => cases constant <;> cases observed
  case con name types values => cases observed; exact ⟨_, rfl, rfl⟩
  case atError detail =>
    rw [Detail.values_toTerm] at observed
    cases observed
    exact ⟨_, rfl, rfl⟩
  all_goals cases observed

private theorem observation_selected {values targets target} {index : Nat}
    (same : Val.toTermSlots values = Val.toTermSlots targets) (selected : targets[index]? = some target) :
    ∃ value, values[index]? = some value ∧ value.toTerm? = target.toTerm? := by
  have observed := congrArg (fun slots : List (Option Term) => slots[index]?) same
  simp only [Val.toTermSlots_eq_map, List.getElem?_map, selected, Option.map_some] at observed
  cases sourceSelected : values[index]? with
  | none => simp [sourceSelected] at observed
  | some value =>
    refine ⟨value, rfl, ?_⟩
    simpa only [sourceSelected, Option.map_some, Option.some.injEq] using observed

private theorem path_append (value : Val) (routePrefix routeSuffix : List FieldRef) :
    readPath value (routePrefix ++ routeSuffix) = (readPath value routePrefix).bind (fun current => readPath current routeSuffix) := by
  induction routePrefix generalizing value with
  | nil => rfl
  | cons field routePrefix ih =>
    cases fields : conFields? value with
    | none => simp [readPath, fields]
    | some pair =>
      rcases pair with ⟨constructor, values⟩
      by_cases same : constructor = field.constructor
      · cases selected : values[field.position]? with
        | none => simp [readPath, fields, same, selected]
        | some next => simpa [readPath, fields, same, selected] using ih next
      · simp [readPath, fields, same]

private theorem getter_call_view (step : PredicateAccessorTargets.Step) (capture : Capture) (receiver : Val) :
    (Closure.mk (capture.extend receiver) (getterCall step)).view =
      .app (.fnRef step.function (step.types.map capture.closeTy) [] []) [receiver] := by
  simp only [Closure.view, Closure.code, Closure.capture, getterCall, closeVal, closeVals, List.map_nil, Capture.extend_env_zero,
    shiftTs, List.map_map, Function.comp_def, Capture.closeTy_shift]

private theorem getter_call_path {source Q targetB Ψ} (step : PredicateAccessorTargets.Step)
    (targetCons : ∀ constructor declaration, source.cons constructor = some declaration → Q.cons constructor = some declaration)
    (missing : source.defs step.function = none)
    (accessor : source.accessors step.function = some (step.constructor, step.position))
    (declaration : source.cons step.constructor = some step.declaration)
    (count : step.types.length = step.declaration.ntys)
    (capture : Capture) (receiver target : Val) (type : Ty) (leaf : Val)
    (typed : HasTypeVQ Q targetB Ψ Qempty [] [] [] target type)
    (same : receiver.toTerm? = target.toTerm?)
    (read : readPath target [step.reference] = some leaf) (next : Closure) (continuation : Cont) (store : Store) :
    ∃ result value,
      AdministrativePath source (.run (.mk (capture.extend receiver) (getterCall step)) (.letF next :: continuation) store)
        (.run result (.letF next :: continuation) store) ∧
      result.view = .ret value ∧ value.toTerm? = leaf.toTerm? := by
  have targetDeclaration : Q.cons step.constructor = some step.declaration :=
    targetCons step.constructor step.declaration declaration
  cases fields : conFields? target with
  | none => simp [readPath, fields] at read
  | some pair =>
    rcases pair with ⟨constructor, values⟩
    by_cases equalConstructor : constructor = step.constructor
    · subst constructor
      cases selected : values[step.position]? with
      | none => simp [readPath, fields, PredicateAccessorTargets.Step.reference, selected] at read
      | some selectedLeaf =>
        have sameLeaf : selectedLeaf = leaf := by
          simpa [readPath, fields, PredicateAccessorTargets.Step.reference, selected] using read
        subst selectedLeaf
        obtain ⟨arity, types⟩ := typed_constructor_fields typed fields targetDeclaration
        obtain ⟨leafType, leafTyped⟩ := types step.position leaf selected
        have observed : receiver.toTerm? = some (.dataValue step.constructor (Val.toTermSlots values)) :=
          same.trans (fields_observation fields)
        obtain ⟨sourceFields, sourceConstructor, sourceSlots⟩ := observation_fields observed
        have sourceArity : sourceFields.length = step.declaration.args.length := by
          have lengths := congrArg List.length sourceSlots
          simp only [Val.toTermSlots_eq_map, List.length_map] at lengths
          exact lengths.trans arity
        obtain ⟨sourceLeaf, sourceSelected, leafObserved⟩ := observation_selected sourceSlots selected
        have matched := accessor_matches sourceConstructor sourceArity sourceSelected
        have call : AdministrativeStep source
            (.run (.mk (capture.extend receiver) (getterCall step)) (.letF next :: continuation) store)
            (.run (.mk (Capture.empty.extendMany [receiver]) (getterMatch step))
              (.mark :: .letF next :: continuation) store) :=
          .getter step missing accessor declaration count capture receiver next continuation store
            (getter_call_view step capture receiver)
        refine ⟨.pure (.ret sourceLeaf), closeVal Capture.empty sourceLeaf, ?_,
          rfl, normalize_observation leafTyped leafObserved Capture.empty⟩
        exact .cons call (.cons (.matchStart rfl) (.cons (.matchBody rfl matched rfl) (.cons (.mark rfl) (.nil _))))
    · simp [readPath, fields, PredicateAccessorTargets.Step.reference, equalConstructor] at read

private theorem getter_return_path {source Q targetB Ψ body root steps}
    (getters : GetterCode source body root steps) (targetCons : ∀ constructor declaration, source.cons constructor = some declaration → Q.cons constructor = some declaration) (capture : Capture) (target : Val) (type : Ty)
    (typed : HasTypeVQ Q targetB Ψ Qempty [] [] [] target type)
    (same : (closeVal capture root).toTerm? = target.toTerm?) (leaf : Val)
    (read : readPath target (steps.map PredicateAccessorTargets.Step.reference) = some leaf)
    (next : Closure) (continuation : Cont) (store : Store) :
    ∃ result value,
      AdministrativePath source (.run (.mk capture body) (.letF next :: continuation) store)
        (.run result (.letF next :: continuation) store) ∧
      result.view = .ret value ∧ value.toTerm? = leaf.toTerm? := by
  induction getters generalizing leaf next continuation with
  | value value =>
    cases read
    exact ⟨.mk capture (.ret value), closeVal capture value, .nil _, rfl, same⟩
  | @accessor step body root steps field missing accessor declaration selected sort count child ih =>
    rw [List.map_append, List.map_cons, List.map_nil, path_append] at read
    obtain ⟨middle, prefixRead, lastRead⟩ := Option.bind_eq_some_iff.mp read
    obtain ⟨middleType, middleTyped⟩ := typed_path typed prefixRead
    obtain ⟨middleClosure, middleValue, childSteps, childView, observed⟩ :=
      ih same middle prefixRead (.mk capture (getterCall step)) (.letF next :: continuation)
    obtain ⟨result, value, callSteps, resultView, resultObserved⟩ :=
      getter_call_path step targetCons missing accessor declaration count capture middleValue middle
        middleType leaf middleTyped observed lastRead next continuation store
    refine ⟨result, value, .cons (.letIn _ _ _ _ _) ?_, resultView, resultObserved⟩
    exact childSteps.append (.cons (.returnValue childView) callSteps)

/-- 型付きの解決後の受け手と対応するgetter列を、六管理規則の有限経路として構成する。 -/
theorem GetterCode.return_path {source rows Q targetB Ψ body root steps}
    (getters : GetterCode source body root steps)
    (targetCons : ∀ constructor declaration, source.cons constructor = some declaration → Q.cons constructor = some declaration)
    (capture : Capture) (target : Val) (type : Ty)
    (typed : HasTypeVQ Q targetB Ψ Qempty [] [] [] target type)
    (related : Value source rows (closeVal capture root) target) (leaf : Val)
    (read : readPath target (steps.map PredicateAccessorTargets.Step.reference) = some leaf)
    (next : Closure) (continuation : Cont) (store : Store) :
    ∃ result value,
      AdministrativePath source (.run (.mk capture body) (.letF next :: continuation) store)
        (.run result (.letF next :: continuation) store) ∧
      result.view = .ret value ∧ value.toTerm? = leaf.toTerm? :=
  getter_return_path getters targetCons capture target type typed related.toTerm
    leaf read next continuation store

private theorem string_snapshot {value : Val} {text} (observed : value.toTerm? = some (.string text)) :
    value = .const (.string text) := by
  cases value
  case const constant => cases constant <;> cases observed; rfl
  all_goals cases observed

private theorem float64_snapshot {value : Val} {bits} (observed : value.toTerm? = some (.float64 bits)) :
    value = .const (.float64 bits) := by
  cases value
  case const constant => cases constant <;> cases observed; rfl
  all_goals cases observed

private theorem float32_snapshot {value : Val} {bits} (observed : value.toTerm? = some (.float32 bits)) :
    value = .const (.float32 bits) := by
  cases value
  case const constant => cases constant <;> cases observed; rfl
  all_goals cases observed

private theorem scalar_snapshot {value : Val} (entry : PredicateRows.Entry) (constant : Const)
    (tag : constant.type.norm.core = .base entry.input)
    (observed : value.toTerm? = (Val.const constant).toTerm?) : value = .const constant := by
  cases entry
  case floating width test =>
    cases width <;> cases constant <;> cases tag
    all_goals first | exact float64_snapshot observed | exact float32_snapshot observed
  all_goals cases constant <;> cases tag
  all_goals first | exact string_snapshot observed | exact float64_snapshot observed | exact float32_snapshot observed

/-- scalarの葉を返すgetter経路は、元の公開判定へ渡す同じ定数へ到達する。 -/
theorem GetterCode.scalar_return_path {source rows Q targetB Ψ body root steps}
    (getters : GetterCode source body root steps)
    (targetCons : ∀ constructor declaration, source.cons constructor = some declaration → Q.cons constructor = some declaration)
    (capture : Capture) (target : Val) (type : Ty)
    (typed : HasTypeVQ Q targetB Ψ Qempty [] [] [] target type)
    (related : Value source rows (closeVal capture root) target) (leaf : Val)
    (read : readPath target (steps.map PredicateAccessorTargets.Step.reference) = some leaf)
    (entry : PredicateRows.Entry) (leafType : Ty) (leafTyped : HasTypeVQ Q targetB Ψ Qempty [] [] [] leaf leafType)
    (scalar : leafType.norm.core = .base entry.input)
    (next : Closure) (continuation : Cont) (store : Store) :
    ∃ result constant,
      AdministrativePath source (.run (.mk capture body) (.letF next :: continuation) store)
        (.run result (.letF next :: continuation) store) ∧
      result.view = .ret (.const constant) ∧ leaf = .const constant := by
  obtain ⟨constant, sameLeaf, valid, tag⟩ := leafTyped.canonical_scalar scalar
  subst leaf
  obtain ⟨result, value, path, view, observed⟩ :=
    getters.return_path targetCons capture target type typed related (.const constant) read next continuation store
  have same : value = .const constant := scalar_snapshot entry constant tag observed
  exact ⟨result, constant, path, by rw [view, same], rfl⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
