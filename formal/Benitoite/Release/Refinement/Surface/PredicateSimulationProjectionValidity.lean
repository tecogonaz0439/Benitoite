import Benitoite.Release.Refinement.Surface.PredicateAccessorPaths
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionInputs
import Benitoite.Release.Refinement.TypeFormation
import Benitoite.Release.Refinement.ConstraintAssumptions
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionDeclared

/-! # 既存の署名形成から得る、生成した投影の経路 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateAccessorTargets PredicateAccessorPaths PredicateProjection PredicateRows
noncomputable section

private def DataShape (type : Ty) (owner : DataName) (count : Nat) : Prop :=
  ∃ types, type.norm.core = .data owner types ∧ types.length = count

private def ObservationShape (P : Refinement.Program) (Γ : Ctx) (term : Term) (type : Ty) : Prop :=
  ∀ owner types, Term.HasData P Γ term owner types → DataShape type owner types.length

private theorem variable_shape {P Γ term owner types index type}
    (observed : Term.HasData P Γ term owner types) (same : term = .var index)
    (found : Γ[index]? = some (some type)) : DataShape type owner types.length := by
  match observed with
  | .var lookup core =>
    cases same
    have equal := Option.some.inj (Option.some.inj (lookup.symm.trans found))
    subst type
    exact ⟨_, core, rfl⟩
  | .value .. => cases same
  | .field .. => cases same
  | .widen child relation =>
    obtain ⟨arguments, core, count⟩ := variable_shape child same found
    exact ⟨arguments, core, count.trans relation.length⟩
termination_by structural observed

private theorem data_core_bind {a : Ty} {owner arguments}
    (core : a.norm.core = .data owner arguments) (images : SubstEnv) :
    (a.bind images).core = .data owner (arguments.map (Ty.bind images)) := by
  cases a <;> simp only [Ty.norm, Ty.core] at core
  case data name values =>
    cases core
    simp only [Ty.bind, Ty.rawBind, Ty.norm, Ty.core, Ty.normTys_eq_map, rawBindTys_eq_map, List.map_map, Function.comp_def]
    congr 2
    funext value
    exact (Ty.norm_rawBind _ value).symm
  case refined a predicate =>
    simp only [Ty.core_refineNorm] at core
    simpa only [Ty.bind, Ty.rawBind, Ty.norm, Ty.core_refineNorm] using data_core_bind core images
  case dependentFn telescope => exact False.elim (Ty.notDataCore_dependentFn core)
  all_goals cases core

private theorem data_sort_shape {type : Ty} (sorted : type.sort? = some .data) :
    ∃ owner arguments, type.norm.core = .data owner arguments := by
  cases type <;> try simp only [Ty.sort?] at sorted
  case base tag => cases tag <;> cases sorted
  case data owner arguments => exact ⟨owner, Ty.normTys arguments, rfl⟩
  case refined type predicate =>
    obtain ⟨owner, arguments, core⟩ := data_sort_shape (type := type) sorted
    exact ⟨owner, arguments, by simpa only [Ty.norm, Ty.core_refineNorm] using core⟩
  all_goals cases sorted
termination_by structural type

private theorem data_bind_shape {type : Ty} {owner arguments} (sorted : type.sort? = some .data)
    (actual : (type.subst arguments []).norm.core = .data owner arguments') (types : List Ty) :
    DataShape (type.norm.substAt 0 types []) owner arguments'.length := by
  obtain ⟨name, fields, core⟩ := data_sort_shape sorted
  have first := data_core_bind core (typeEnvAt 0 arguments [])
  have second := data_core_bind (a := type.norm) (by simpa only [Ty.norm_idem] using core) (typeEnvAt 0 types [])
  have actualCore : (type.bind (typeEnvAt 0 arguments [])).core = .data owner arguments' := by
    simpa only [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.norm_idem] using actual
  have actual' : Ty.data name (fields.map (Ty.bind (typeEnvAt 0 arguments []))) = Ty.data owner arguments' := by
    exact first.symm.trans actualCore
  obtain ⟨rfl, same⟩ := Ty.data.inj actual'
  refine ⟨fields.map (Ty.bind (typeEnvAt 0 types [])), ?_, ?_⟩
  · simpa only [Ty.substAt, substTypeAt, Ty.bind, Ty.norm_idem] using second
  · simpa only [List.length_map] using congrArg List.length same

private theorem field_shape {P Γ term owner arguments receiver ref declaration field types}
    (observed : Term.HasData P Γ term owner arguments) (same : term = .field ref receiver)
    (found : P.cons ref.constructor = some declaration) (selected : declaration.args[ref.position]? = some field)
    (sorted : field.sort? = some .data) : DataShape (field.norm.substAt 0 types []) owner arguments.length := by
  match observed with
  | .var .. => cases same
  | .value .. => cases same
  | .field input declarationFound ownerEqual count fieldFound closed fieldSort core =>
    cases same
    have equalDeclaration := Option.some.inj (declarationFound.symm.trans found)
    subst declaration
    have equalField := Option.some.inj (fieldFound.symm.trans selected)
    subst field
    exact data_bind_shape sorted core types
  | .widen child relation =>
    obtain ⟨values, core, count⟩ := field_shape child same found selected sorted (types := types)
    exact ⟨values, core, count.trans relation.length⟩
termination_by structural observed

private theorem route_root_declared {P C Γ root route}
    (declared : Term.Declared P C Γ (routeTerm root route)) : Term.Declared P C Γ root := by
  induction route generalizing root with
  | nil => exact declared
  | cons ref rest ih => exact (ih declared).1

private theorem path_append {P a first b rest c} (head : AccessPath P a first b)
    (tail : AccessPath P b rest c) : AccessPath P a (first ++ rest) c := by
  induction head with
  | nil type => exact tail
  | field typed exhaustive binder child ih => exact .field typed exhaustive binder (ih tail)

private theorem path_normal {P a route b} (path : AccessPath P a route b) : AccessPath P a.norm route b.norm := by
  induction path with
  | nil type => exact .nil _
  | @field a b c pattern ref rest typed exhaustive binder child ih =>
    exact .field (by simpa only [List.map_cons, List.map_nil] using
      PatTy.P_Convert (b := a.norm) (Ty.norm_idem a).symm typed)
      (by simpa only [Exhaustive, Ty.norm_idem] using exhaustive) binder ih

private theorem path_refined {P a route b} (path : AccessPath P a route b) (nonempty : route ≠ []) (predicate : Pred) :
    AccessPath P (.refined a predicate) route b.norm := by
  cases path with
  | nil type => exact False.elim (nonempty rfl)
  | field typed exhaustive binder tail =>
    refine .field (by simpa only [List.map_cons, List.map_nil] using
      (PatTy.P_Convert (b := .refined a predicate) rfl (.P_Refined typed))) ?_ binder (path_normal tail)
    intro value inhabited
    have inner := (Inhabits.norm_all_iff (.refined a predicate) value).mp inhabited
    exact exhaustive value ((Inhabits.norm_all_iff a value).mpr (inner.refined_inv a predicate rfl).1)

private theorem path_from_core {P a route b} (path : AccessPath P a.norm.core route b) (nonempty : route ≠ []) :
    AccessPath P a route b.norm := by
  cases a
  case refined type predicate =>
    have inner : AccessPath P type.norm.core route b := by simpa only [Ty.norm, Ty.core_refineNorm] using path
    have lifted := path_refined (path_from_core inner nonempty) nonempty predicate
    simpa only [Ty.norm_idem] using lifted
  all_goals
    simp only [Ty.core_norm, Ty.core] at path
    cases path with
    | nil type => exact False.elim (nonempty rfl)
    | field typed exhaustive binder tail =>
      exact .field (by simpa only [List.map_cons, List.map_nil] using
        (PatTy.P_Convert (by simp only [Ty.norm_idem]) typed))
        (by simpa only [Exhaustive, Ty.norm_idem] using exhaustive) binder (path_normal tail)
termination_by structural a

private theorem genericData_subst (owner : DataName) (count : Nat) (types : List Ty) (length : types.length = count) :
    (Ty.data owner ((List.range count).map Ty.tvar)).substAt 0 types [] = (Ty.data owner types).norm := by
  subst count
  simp only [Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    Ty.normTys_eq_map, rawBindTys_eq_map, List.map_map]
  congr 1
  apply List.ext_getElem
  · simp
  · intro index firstBound secondBound
    simp only [List.getElem_map, List.getElem_range] at firstBound secondBound ⊢
    have bound : index < types.length := by simpa using firstBound
    simp [typeEnvAt, Ty.rawBind, bound]

private theorem field_path {source : Program} {input : Ty} {step : PredicateAccessorTargets.Step} {field types}
    (formed : source.WellFormed) (accessor : AccessorOk source.declarations step.constructor step.declaration step.position)
    (selected : step.declaration.args[step.position]? = some field)
    (core : input.norm.core = .data step.declaration.data types) (count : types.length = step.declaration.ntys) :
    AccessPath source.declarations.core input [step.reference] (field.norm.substAt 0 types []).norm := by
  have path := AccessPath.accessor (P := source.declarations.core)
    (show source.declarations.core.SameTypes source.declarations.core from ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩)
    accessor selected (ref := step.reference) rfl rfl
  have concrete := path.substAt formed.types 0 types []
  rw [genericData_subst _ _ _ count] at concrete
  have normalized : (Ty.data step.declaration.data types).norm = input.norm.core := by
    rw [Ty.norm, Ty.dataCore_args_norm core]
    exact core.symm
  rw [normalized] at concrete
  exact path_from_core concrete (by simp)

private theorem fixed_scalar_core {type : Ty} {tag : BaseTy}
    (allowed : tag = .string ∨ tag = .float ∨ tag = .float32)
    (sorted : type.sort? = (Ty.base tag).sort?) : type.norm.core = .base tag := by
  cases type
  case base actual =>
    rcases allowed with rfl | rfl | rfl
    all_goals cases actual <;> cases sorted <;> rfl
  case refined type predicate =>
    have core := fixed_scalar_core allowed (type := type) sorted
    simpa only [Ty.norm, Ty.core_refineNorm] using core
  all_goals rcases allowed with rfl | rfl | rfl
  all_goals cases sorted
termination_by structural type

private theorem scalar_core (entry : Entry) {type : Ty} (sorted : type.sort? = some entry.sort) :
    type.norm.core = .base entry.input := by
  cases entry with
  | path pattern => exact fixed_scalar_core (.inl rfl) sorted
  | host pattern => exact fixed_scalar_core (.inl rfl) sorted
  | characters lo hi => exact fixed_scalar_core (.inl rfl) sorted
  | floating width test =>
    cases width with
    | binary64 => exact fixed_scalar_core (.inr (.inl rfl)) sorted
    | binary32 => exact fixed_scalar_core (.inr (.inr rfl)) sorted

private theorem scalar_bind {type : Ty} {tag : BaseTy} (core : type.core = .base tag) (images : SubstEnv) :
    (type.rawBind images).core = .base tag := by
  cases type
  case base actual => exact core
  case refined type predicate => exact scalar_bind (type := type) core images
  all_goals cases core
termination_by structural type

private theorem scalar_subst {type : Ty} {tag : BaseTy} (core : type.norm.core = .base tag) (types : List Ty) :
    (type.norm.substAt 0 types []).norm.core = .base tag := by
  simp only [Ty.substAt, substTypeAt, Ty.bind, Ty.norm_idem]
  rw [Ty.core_norm, scalar_bind core]
  rfl

private def StepFields (source : Program) (steps : List PredicateAccessorTargets.Step) : Prop :=
  ∀ step ∈ steps, ∃ field, source.cons step.constructor = some step.declaration ∧
    step.declaration.args[step.position]? = some field ∧ field.sort? = some step.sort

private theorem resolved_fields {source expression root value term steps}
    (resolved : PredicateAccessorTargets.Resolved source expression root value term steps) : StepFields source steps := by
  induction resolved with
  | value found observed => intro step member; cases member
  | paren child ih => exact ih
  | @accessor step labels receiver root value term steps field missing accessor declaration selected sorted count allowed child ih =>
    intro actual member
    rcases List.mem_append.mp member with member | member
    · exact ih actual member
    · have same : actual = step := by simpa only [List.mem_singleton] using member
      subst actual
      exact ⟨field, declaration, selected, sorted⟩

private theorem declared_path {source : Program} {C Γ root input steps} {entry : Entry}
    (formed : source.WellFormed) (fields : StepFields source steps)
    (accessors : ∀ step ∈ steps, AccessorOk source.declarations step.constructor step.declaration step.position)
    (shape : ObservationShape source.declarations.core Γ root input) (nonempty : steps ≠ [])
    (sorted : RouteSorted (steps.map PredicateAccessorTargets.Step.reference) entry.sort)
    (declared : Term.Declared source.declarations.core C Γ
      (routeTerm root (steps.map PredicateAccessorTargets.Step.reference))) :
    ∃ leaf, AccessPath source.declarations.core input (steps.map PredicateAccessorTargets.Step.reference) leaf ∧
      leaf.norm.core = .base entry.input := by
  cases steps with
  | nil => exact False.elim (nonempty rfl)
  | cons step rest =>
    have firstDeclared := route_root_declared (root := .field step.reference root) (route := rest.map PredicateAccessorTargets.Step.reference) declared
    obtain ⟨actualTypes, actualDeclaration, actualField, observed, found, owner, actualCount, actualSelected, closed, actualSorted⟩ := firstDeclared.2
    obtain ⟨field, declaration, selected, fieldSorted⟩ := fields step List.mem_cons_self
    have sameDeclaration : actualDeclaration = step.declaration :=
      Option.some.inj (found.symm.trans declaration)
    subst actualDeclaration
    have sameField : actualField = field := Option.some.inj (actualSelected.symm.trans selected)
    subst actualField
    obtain ⟨types, core, count⟩ := shape step.declaration.data actualTypes observed
    have typeCount : types.length = step.declaration.ntys := count.trans actualCount.symm
    have firstPath := field_path formed (accessors step List.mem_cons_self) selected core typeCount
    cases rest with
    | nil =>
      have sameSort : step.sort = entry.sort := sorted
      have scalar := scalar_subst (scalar_core entry (sameSort ▸ fieldSorted)) types
      exact ⟨_, firstPath, by simpa only [Ty.norm_idem] using scalar⟩
    | cons next rest =>
      have sortedHead : step.sort = .data := sorted.1
      have remainingShape : ObservationShape source.declarations.core Γ (.field step.reference root)
          (field.norm.substAt 0 types []) := by
        intro owner values observed
        exact field_shape observed rfl declaration selected (sortedHead ▸ fieldSorted) (types := types)
      obtain ⟨leaf, tail, scalar⟩ := declared_path formed
        (fun actual member => fields actual (List.mem_cons_of_mem _ member))
        (fun actual member => accessors actual (List.mem_cons_of_mem _ member))
        remainingShape (by simp) sorted.2 declared
      exact ⟨leaf.norm, by simpa only [List.singleton_append, List.map_cons] using
        (path_append firstPath (path_normal tail)), by simpa only [Ty.norm_idem] using scalar⟩
termination_by structural steps

private theorem candidate_geometry {source expression} {parsed : PredicateAccessorTargets.Parsed source expression}
    {projection types entry} (candidate : PredicateProjectionCalls.candidate parsed entry = some (projection, types)) :
    projection.route = parsed.steps.map PredicateAccessorTargets.Step.reference ∧
      projection.entry = entry ∧ parsed.steps ≠ [] := by
  unfold PredicateProjectionCalls.candidate at candidate
  split at candidate
  · cases candidate
  · split at candidate
    · cases candidate
      exact ⟨rfl, rfl, by simp_all⟩
    · cases candidate

/-- 既存の署名形成と実getter条件から、generic入力全体に使える投影経路を構成する。 -/
theorem parsed_valid_of_scoped {source expression}
    (parsed : PredicateAccessorTargets.Parsed source expression) {projection types entry}
    (formed : source.WellFormed)
    (candidate : PredicateProjectionCalls.candidate parsed entry = some (projection, types))
    (entryValid : entry.Valid) (signature : PrimSig.Scoped source.declarations.core projection.signature) :
    Valid source.declarations.core projection := by
  obtain ⟨route, entryEqual, nonempty⟩ := candidate_geometry candidate
  have declared := projection_route_declared projection signature
  rw [route] at declared
  have shape : ObservationShape source.declarations.core
      [some (.base .boolean), some projection.input] (.var 1) projection.input := by
    intro owner values observed
    exact variable_shape observed rfl rfl
  have sorted := PredicateProjectionCalls.candidate_sorted candidate
  have pathSorted : RouteSorted (parsed.steps.map PredicateAccessorTargets.Step.reference) entry.sort := route ▸ sorted
  obtain ⟨leaf, path, scalar⟩ := declared_path formed (resolved_fields parsed.sound)
    (parsed.accessor_conditions formed) shape nonempty pathSorted declared
  rw [← route] at path
  exact ⟨entryEqual ▸ entryValid, ⟨leaf, path, by simpa only [entryEqual] using scalar⟩,
    by rw [route]; simpa using nonempty, by simpa only [entryEqual] using sorted, signature⟩

private theorem scalar_target_shape {entry expression row}
    (selected : ((do
      let value ← (PredicateCalls.stripParens expression).valueOf?
      let _ ← value.toTerm?
      pure (.scalar entry)) : Option Row) = some row) : row = .scalar entry := by
  obtain ⟨value, valued, selected⟩ := Option.bind_eq_some_iff.mp selected
  obtain ⟨term, observed, selected⟩ := Option.bind_eq_some_iff.mp selected
  exact (Option.some.inj selected).symm

private theorem target_row_valid {source entry expression row}
    (formed : source.WellFormed) (entryValid : entry.Valid)
    (selected : PredicateRowCollection.targetRow source entry expression = some row)
    (signature : PrimSig.Scoped source.declarations.core row.signature) : Table.RowValid source.declarations.core row := by
  unfold PredicateRowCollection.targetRow at selected
  cases projected : ((PredicateAccessorTargets.parse source expression).bind (fun parsed =>
      (PredicateProjectionCalls.candidate parsed entry).map (fun pair => Row.projected pair.1))) with
  | none =>
    simp only [projected, Option.orElse] at selected
    have equal := scalar_target_shape selected
    subst row
    exact entryValid
  | some chosen =>
    simp only [projected, Option.orElse, Option.some.injEq] at selected
    subst row
    obtain ⟨parsed, parse, projected⟩ := Option.bind_eq_some_iff.mp projected
    obtain ⟨pair, candidate, equal⟩ := Option.map_eq_some_iff.mp projected
    rcases pair with ⟨projection, types⟩
    cases equal
    exact parsed_valid_of_scoped parsed formed candidate entryValid signature

private theorem candidate_row_valid {source expression row}
    (formed : source.WellFormed) (selected : PredicateRowCollection.candidate source expression = some row)
    (signature : PrimSig.Scoped source.declarations.core row.signature) : Table.RowValid source.declarations.core row := by
  unfold PredicateRowCollection.candidate at selected
  split at selected
  · obtain ⟨api, named, selected⟩ := Option.bind_eq_some_iff.mp selected
    split at selected
    · obtain ⟨pair, identified, selected⟩ := Option.bind_eq_some_iff.mp selected
      rcases pair with ⟨entry, target⟩
      exact target_row_valid formed (PredicateCalls.identify_valid identified) selected signature
    · cases selected
  · cases selected

/-- 既存Coreの署名形成を実lookupで読み、実際に収集した全投影の経路条件を供給する。 -/
theorem collected_valid_of_core {P : Refinement.Program} (source : Program) (input : Check.Input)
    (expressions : List Expr) (forbidden : List PrimName)
    (formed : source.WellFormed) (same : source.declarations.core.SameTypes P)
    (core : Builtins.CoreAssumptions P
      (CheckPreparation.input input (PredicateRowCollection.collectAvoid source expressions forbidden)).B) :
    Table.Rows.Valid P (PredicateRowCollection.collectAvoid source expressions forbidden) := by
  apply PredicateRowCollection.collectAvoid_valid
  intro expression member row selected
  obtain ⟨key, lookup⟩ := PredicateRowCollection.collectAvoid_contains member selected
  have signatureLookup :
      (CheckPreparation.input input (PredicateRowCollection.collectAvoid source expressions forbidden)).B.sig key = some row.signature := by
    change (match (PredicateRowCollection.collectAvoid source expressions forbidden).lookup key with
      | some row => some row.signature | none => input.B.sig key) = some row.signature
    rw [lookup]
  have targetScoped := core.sig_scoped key row.signature signatureLookup
  have sourceScoped : PrimSig.Scoped source.declarations.core row.signature :=
    ⟨targetScoped.names, targetScoped.source, targetScoped.kinds.sameTypes same.symm,
      targetScoped.sorted, targetScoped.declared.sameTypes same.symm, targetScoped.operation⟩
  have valid := candidate_row_valid formed selected sourceScoped
  cases row with
  | scalar entry => exact valid
  | projected projection => exact valid.sameTypes same

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
