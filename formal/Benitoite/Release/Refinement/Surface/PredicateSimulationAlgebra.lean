import Benitoite.Release.Refinement.Surface.PredicateSimulationValues
import Benitoite.Release.Refinement.RangeCode

/-! # 判定の書換えと値・型・範囲の操作の対応

値の観測を保ち、束縛の下で同じコードの関係を維持する。新しい実行時の信頼条件は置かない。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

private theorem type_values_length (values : List Val) (index : Nat) (types : List Ty) (effects : List Eff) :
    (Val.substTyAtList index types effects values).length = values.length := by
  induction values <;> simp only [Val.substTyAtList, List.length_nil, List.length_cons, *]

private theorem range_values_length (values : List Val) (ranges : Nat → RangeIx) :
    (Val.mapRangesListN ranges values).length = values.length := by
  induction values <;> simp only [Val.mapRangesListN, List.length_nil, List.length_cons, *]

private theorem subst_values_length (values : List Val) (images : Nat → Val) (locals : Nat → LocalRef) :
    (Val.substList images values locals).length = values.length := by
  induction values <;> simp only [Val.substList, List.length_nil, List.length_cons, *]

private theorem scalar_substitution {source rows api entry key positions values v w}
    (lookup : rows.lookup key = some (.scalar entry)) (count : values.length = api.inputs.length)
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) v)
    (simpleValues : SimpleValues values) (left right : Nat → Val) (locals : Nat → LocalRef)
    (simple : ∀ index, SimpleValue (left index))
    (related : Value source rows (v.subst left locals) (w.subst right locals)) :
    Code source rows ((scalarCall api positions values).subst left locals)
      ((Comp.app (.prim key [] [] []) [w]).subst right locals) := by
  simp only [scalarCall_subst, Comp.subst, Val.subst, Val.substList, List.map_nil]
  exact .scalar lookup (by simpa only [subst_values_length] using count) (inputs.subst left locals) (simpleValues.subst left locals simple) related

private theorem projected_rename {source rows api key projection positions computations symbolic root steps types target}
    (lookup : rows.lookup key = some (.projected projection))
    (route : projection.route = steps.map PredicateAccessorTargets.Step.reference)
    (arguments : ProjectionArguments source root steps computations symbolic)
    (inputs : ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0))
    (count : computations.length = api.inputs.length) (typeCount : types.length = projection.ntys)
    (simple : SimpleValue root) (ξ : Nat → Nat)
    (related : Value source rows (root.rename ξ) (target.rename ξ)) :
    Code source rows ((sourceCall api positions computations).rename ξ)
      ((Comp.app (.prim key types [] []) [target]).rename ξ) := by
  simp only [sourceCall_rename, Comp.rename, Val.rename, Val.renameList, List.map_nil]
  exact Code.projected lookup (by simpa only [step_references] using route) (arguments.rename ξ) inputs
    (by simpa only [List.length_map] using count) (by simpa only [List.length_map] using typeCount)
    (simple.rename ξ) related

private theorem projected_type {source rows api key projection positions computations symbolic root steps types target}
    (lookup : rows.lookup key = some (.projected projection))
    (route : projection.route = steps.map PredicateAccessorTargets.Step.reference)
    (arguments : ProjectionArguments source root steps computations symbolic)
    (inputs : ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0))
    (count : computations.length = api.inputs.length) (typeCount : types.length = projection.ntys)
    (simple : SimpleValue root) (c : Nat) (ts : List Ty) (es : List Eff)
    (related : Value source rows (root.substTyAt c ts es) (target.substTyAt c ts es)) :
    Code source rows ((sourceCall api positions computations).substTyAt c ts es)
      ((Comp.app (.prim key types [] []) [target]).substTyAt c ts es) := by
  simp only [sourceCall_substTy, Comp.substTyAt, Val.substTyAt, Val.substTyAtList, List.map_nil]
  exact Code.projected lookup (by simpa only [step_references] using route) (arguments.substTy c ts es) inputs
    (by simpa only [List.length_map] using count) (by simpa only [List.length_map] using typeCount)
    (simple.substTy c ts es) related

private theorem projected_ranges {source rows api key projection positions computations symbolic root steps types target}
    (lookup : rows.lookup key = some (.projected projection))
    (route : projection.route = steps.map PredicateAccessorTargets.Step.reference)
    (arguments : ProjectionArguments source root steps computations symbolic)
    (inputs : ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0))
    (count : computations.length = api.inputs.length) (typeCount : types.length = projection.ntys)
    (simple : SimpleValue root) (ρ : Nat → RangeIx)
    (related : Value source rows (root.mapRangesN ρ) (target.mapRangesN ρ)) :
    Code source rows ((sourceCall api positions computations).mapRangesN ρ)
      ((Comp.app (.prim key types [] []) [target]).mapRangesN ρ) := by
  simp only [sourceCall_mapRanges, Comp.mapRangesN, Val.mapRangesN, Val.mapRangesListN, List.map_nil]
  exact Code.projected lookup (by simpa only [step_references] using route) (arguments.mapRanges ρ) inputs
    (by simpa only [List.length_map] using count) (by simpa only [List.length_map] using typeCount)
    (simple.mapRanges ρ) related

private theorem projected_shiftE {source rows api key projection positions computations symbolic root steps types target}
    (lookup : rows.lookup key = some (.projected projection))
    (route : projection.route = steps.map PredicateAccessorTargets.Step.reference)
    (arguments : ProjectionArguments source root steps computations symbolic)
    (inputs : ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0))
    (count : computations.length = api.inputs.length) (typeCount : types.length = projection.ntys)
    (simple : SimpleValue root) (k c : Nat)
    (related : Value source rows (root.shiftEAt k c) (target.shiftEAt k c)) :
    Code source rows ((sourceCall api positions computations).shiftEAt k c)
      ((Comp.app (.prim key types [] []) [target]).shiftEAt k c) := by
  simp only [sourceCall_shiftE, Comp.shiftEAt, Val.shiftEAt, Val.shiftEListAt, List.map_nil]
  exact Code.projected lookup (by simpa only [step_references] using route) (arguments.shiftE k c) inputs
    (by simpa only [List.length_map] using count) (by simpa only [List.length_map] using typeCount)
    (simple.shiftE k c) related

private theorem projected_subst {source rows api key projection positions computations symbolic root steps types target}
    (lookup : rows.lookup key = some (.projected projection))
    (route : projection.route = steps.map PredicateAccessorTargets.Step.reference)
    (arguments : ProjectionArguments source root steps computations symbolic)
    (inputs : ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0))
    (count : computations.length = api.inputs.length) (typeCount : types.length = projection.ntys)
    (simple : SimpleValue root) (ν ξ : Nat → Val) (ρ : Nat → LocalRef) (imagesSimple : ∀ i, SimpleValue (ν i))
    (related : Value source rows (root.subst ν ρ) (target.subst ξ ρ)) :
    Code source rows ((sourceCall api positions computations).subst ν ρ)
      ((Comp.app (.prim key types [] []) [target]).subst ξ ρ) := by
  simp only [sourceCall_subst, Comp.subst, Val.subst, Val.substList, List.map_nil]
  exact Code.projected lookup (by simpa only [step_references] using route) (arguments.subst ν ρ) inputs
    (by simpa only [List.length_map] using count) (by simpa only [List.length_map] using typeCount)
    (simple.subst ν ρ imagesSimple) related

mutual
  theorem Value.rename {source rows v w} (h : Value source rows v w) (ξ : Nat → Nat) :
      Value source rows (Val.rename ξ v) (Val.rename ξ w) := by
    cases h
    case var i => exact .var _
    case constant c => exact .constant _
    case function f ts es rs => exact .function _ _ _ _
    case primitive b ts es rs => exact .primitive _ _ _ _
    case lam h => exact .lam (Code.rename h _)
    case dependentLam h => exact .dependentLam (Code.rename h _)
    case closure h => exact .closure h
    case con h => exact .con (Values.rename h _)
    case list h => exact .list (Values.rename h _)
    case operation o ts => exact .operation _ _
    case raise a e => exact .raise _ _
    case location l => exact .location _
    case map h g => exact .map (Values.rename h _) (Values.rename g _)
    case set h => exact .set (Values.rename h _)
    case bytes bs => exact .bytes _
    case dictionary h => exact .dictionary (Values.rename h _)
    case super h => exact .super (Value.rename h _)
    case externalFunction f ts => exact .externalFunction _ _
    case externalHandle f ts => exact .externalHandle _ _
    case pathBases s => exact .pathBases _
    case scopePattern r => exact .scopePattern _
    case checkedAt h => exact .checkedAt h
    case atError h => exact .atError h
    case checked t => exact .checked _
    case checkedRequest h => exact .checkedRequest h
  theorem Values.rename {source rows vs ws} (h : Values source rows vs ws) (ξ : Nat → Nat) :
      Values source rows (Val.renameList ξ vs) (Val.renameList ξ ws) := by
    cases h with
    | nil => exact .nil
    | cons h g => exact .cons (Value.rename h _) (Values.rename g _)
  theorem OptionalValue.rename {source rows v w} (h : OptionalValue source rows v w) (ξ : Nat → Nat) :
      OptionalValue source rows (v.map (Val.rename ξ)) (w.map (Val.rename ξ)) := by
    cases h with
    | none => exact .none
    | some h => exact .some (Value.rename h _)
  theorem Code.rename {source rows m n} (h : Code source rows m n) (ξ : Nat → Nat) :
      Code source rows (Comp.rename ξ m) (Comp.rename ξ n) := by
    cases h
    case builder h => exact .builder (Code.rename h _)
    case builderOp h => exact .builderOp (Values.rename h _)
    case ret h => exact .ret (Value.rename h _)
    case letIn h g => exact .letIn (Code.rename h _) (Code.rename g _)
    case app h g => exact .app (Value.rename h _) (Values.rename g _)
    case ite h g k => exact .ite (Value.rename h _) (Code.rename g _) (Code.rename k _)
    case matchC h g => exact .matchC (Value.rename h _) (Arms.rename g _)
    case lazyC h => exact .lazyC (Code.rename h _)
    case escape h => exact .escape (Value.rename h _)
    case use h g => exact .use (Value.rename h _) (Code.rename g _)
    case handle h g => exact .handle (Code.rename h _) (Clauses.rename g _)
    case resume h g => exact .resume (Value.rename h _) (Value.rename g _)
    case externalCall h => exact .externalCall (Values.rename h _)
    case pathBases b => exact .pathBases _
    case checkAt h g k =>
      cases h with
      | none => exact .checkAt .none (Value.rename g ξ) (Value.rename k ξ)
      | some hv => exact .checkAt (.some (Value.rename hv ξ)) (Value.rename g ξ) (Value.rename k ξ)
    case method h g => exact .method (Value.rename h _) (Values.rename g _)
    case scalar hk count inputs simpleValues related =>
      simpa only [scalarCall_rename, Comp.rename, Val.rename, Val.renameList, List.map_nil] using
        Code.scalar hk (by simpa only [Val.renameList_length] using count) (inputs.rename ξ) (simpleValues.rename ξ) (Value.rename related ξ)
    case projected lookup route arguments inputs count typeCount simple related =>
      exact projected_rename lookup route arguments inputs count typeCount simple ξ (Value.rename related ξ)
  theorem Arms.rename {source rows as bs} (h : Arms source rows as bs) (ξ : Nat → Nat) :
      Arms source rows (Arm.renameList ξ as) (Arm.renameList ξ bs) := by
    cases h with
    | nil => exact .nil
    | plain h g => exact .plain (Code.rename h _) (Arms.rename g _)
    | guard h g k => exact .guard (Code.rename h _) (Code.rename g _) (Arms.rename k _)
  theorem Clauses.rename {source rows cs ds} (h : Clauses source rows cs ds) (ξ : Nat → Nat) :
      Clauses source rows (Clause.renameList ξ cs) (Clause.renameList ξ ds) := by
    cases h with
    | nil => exact .nil
    | operation h g => exact .operation (Code.rename h _) (Clauses.rename g _)
    | fail h g => exact .fail (Code.rename h _) (Clauses.rename g _)
end

set_option maxHeartbeats 400000 in
mutual
  theorem Value.substTy {source rows v w} (h : Value source rows v w) (c : Nat) (ts : List Ty) (es : List Eff) :
      Value source rows (Val.substTyAt c ts es v) (Val.substTyAt c ts es w) := by
    cases h
    case var i => exact .var _
    case constant c => exact .constant _
    case function f ts es rs => exact .function _ _ _ _
    case primitive b ts es rs => exact .primitive _ _ _ _
    case lam h => exact .lam (Code.substTy h _ _ _)
    case dependentLam h => exact .dependentLam (Code.substTy h _ _ _)
    case closure h => exact .closure h
    case con h => exact .con (Values.substTy h _ _ _)
    case list h => exact .list (Values.substTy h _ _ _)
    case operation o ts => exact .operation _ _
    case raise a e => exact .raise _ _
    case location l => exact .location _
    case map h g => exact .map (Values.substTy h _ _ _) (Values.substTy g _ _ _)
    case set h => exact .set (Values.substTy h _ _ _)
    case bytes bs => exact .bytes _
    case dictionary h => exact .dictionary (Values.substTy h _ _ _)
    case super h => exact .super (Value.substTy h _ _ _)
    case externalFunction f ts => exact .externalFunction _ _
    case externalHandle f ts => exact .externalHandle _ _
    case pathBases s => exact .pathBases _
    case scopePattern r => exact .scopePattern _
    case checkedAt h => exact .checkedAt h
    case atError h => exact .atError h
    case checked t => exact .checked _
    case checkedRequest h => exact .checkedRequest h
  theorem Values.substTy {source rows vs ws} (h : Values source rows vs ws) (c : Nat) (ts : List Ty) (es : List Eff) :
      Values source rows (Val.substTyAtList c ts es vs) (Val.substTyAtList c ts es ws) := by
    cases h with
    | nil => exact .nil
    | cons h g => exact .cons (Value.substTy h _ _ _) (Values.substTy g _ _ _)
  theorem OptionalValue.substTy {source rows v w} (h : OptionalValue source rows v w) (c : Nat) (ts : List Ty) (es : List Eff) :
      OptionalValue source rows (v.map (Val.substTyAt c ts es)) (w.map (Val.substTyAt c ts es)) := by
    cases h with
    | none => exact .none
    | some h => exact .some (Value.substTy h _ _ _)
  theorem Code.substTy {source rows m n} (h : Code source rows m n) (c : Nat) (ts : List Ty) (es : List Eff) :
      Code source rows (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n) := by
    cases h
    case builder h => exact .builder (Code.substTy h _ _ _)
    case builderOp h => exact .builderOp (Values.substTy h _ _ _)
    case ret h => exact .ret (Value.substTy h _ _ _)
    case letIn h g => exact .letIn (Code.substTy h _ _ _) (Code.substTy g _ _ _)
    case app h g => exact .app (Value.substTy h _ _ _) (Values.substTy g _ _ _)
    case ite h g k => exact .ite (Value.substTy h _ _ _) (Code.substTy g _ _ _) (Code.substTy k _ _ _)
    case matchC h g => exact .matchC (Value.substTy h _ _ _) (Arms.substTy g _ _ _)
    case lazyC h => exact .lazyC (Code.substTy h _ _ _)
    case escape h => exact .escape (Value.substTy h _ _ _)
    case use h g => exact .use (Value.substTy h _ _ _) (Code.substTy g _ _ _)
    case handle h g => exact .handle (Code.substTy h _ _ _) (Clauses.substTy g _ _ _)
    case resume h g => exact .resume (Value.substTy h _ _ _) (Value.substTy g _ _ _)
    case externalCall h => exact .externalCall (Values.substTy h _ _ _)
    case pathBases b => exact .pathBases _
    case checkAt h g k =>
      cases h with
      | none => exact .checkAt .none (Value.substTy g c ts es) (Value.substTy k c ts es)
      | some hv => exact .checkAt (.some (Value.substTy hv c ts es)) (Value.substTy g c ts es) (Value.substTy k c ts es)
    case method h g => exact .method (Value.substTy h _ _ _) (Values.substTy g _ _ _)
    case scalar hk count inputs simpleValues related =>
      simpa only [scalarCall_substTy, Comp.substTyAt, Val.substTyAt, Val.substTyAtList, List.map_nil] using
        Code.scalar hk (by simpa only [type_values_length] using count) (inputs.substTy c ts es) (simpleValues.substTy c ts es) (Value.substTy related c ts es)
    case projected lookup route arguments inputs count typeCount simple related =>
      exact projected_type lookup route arguments inputs count typeCount simple c ts es (Value.substTy related c ts es)
  theorem Arms.substTy {source rows as bs} (h : Arms source rows as bs) (c : Nat) (ts : List Ty) (es : List Eff) :
      Arms source rows (Arm.substTyAtList c ts es as) (Arm.substTyAtList c ts es bs) := by
    cases h with
    | nil => exact .nil
    | plain h g => exact .plain (Code.substTy h _ _ _) (Arms.substTy g _ _ _)
    | guard h g k => exact .guard (Code.substTy h _ _ _) (Code.substTy g _ _ _) (Arms.substTy k _ _ _)
  theorem Clauses.substTy {source rows cs ds} (h : Clauses source rows cs ds) (c : Nat) (ts : List Ty) (es : List Eff) :
      Clauses source rows (Clause.substTyAtList c ts es cs) (Clause.substTyAtList c ts es ds) := by
    cases h with
    | nil => exact .nil
    | operation h g => exact .operation (Code.substTy h _ _ _) (Clauses.substTy g _ _ _)
    | fail h g => exact .fail (Code.substTy h _ _ _) (Clauses.substTy g _ _ _)
end

mutual
  theorem Value.mapRanges {source rows v w} (h : Value source rows v w) (ρ : Nat → RangeIx) :
      Value source rows (Val.mapRangesN ρ v) (Val.mapRangesN ρ w) := by
    cases h
    case var i => exact .var _
    case constant c => exact .constant _
    case function f ts es rs => exact .function _ _ _ _
    case primitive b ts es rs => exact .primitive _ _ _ _
    case lam h => exact .lam (Code.mapRanges h _)
    case dependentLam h => exact .dependentLam (Code.mapRanges h _)
    case closure h => exact .closure h
    case con h => exact .con (Values.mapRanges h _)
    case list h => exact .list (Values.mapRanges h _)
    case operation o ts => exact .operation _ _
    case raise a e => exact .raise _ _
    case location l => exact .location _
    case map h g => exact .map (Values.mapRanges h _) (Values.mapRanges g _)
    case set h => exact .set (Values.mapRanges h _)
    case bytes bs => exact .bytes _
    case dictionary h => exact .dictionary (Values.mapRanges h _)
    case super h => exact .super (Value.mapRanges h _)
    case externalFunction f ts => exact .externalFunction _ _
    case externalHandle f ts => exact .externalHandle _ _
    case pathBases s => exact .pathBases _
    case scopePattern r => exact .scopePattern _
    case checkedAt h => exact .checkedAt h
    case atError h => exact .atError h
    case checked t => exact .checked _
    case checkedRequest h => exact .checkedRequest h
  theorem Values.mapRanges {source rows vs ws} (h : Values source rows vs ws) (ρ : Nat → RangeIx) :
      Values source rows (Val.mapRangesListN ρ vs) (Val.mapRangesListN ρ ws) := by
    cases h with
    | nil => exact .nil
    | cons h g => exact .cons (Value.mapRanges h _) (Values.mapRanges g _)
  theorem OptionalValue.mapRanges {source rows v w} (h : OptionalValue source rows v w) (ρ : Nat → RangeIx) :
      OptionalValue source rows (v.map (Val.mapRangesN ρ)) (w.map (Val.mapRangesN ρ)) := by
    cases h with
    | none => exact .none
    | some h => exact .some (Value.mapRanges h _)
  theorem Code.mapRanges {source rows m n} (h : Code source rows m n) (ρ : Nat → RangeIx) :
      Code source rows (Comp.mapRangesN ρ m) (Comp.mapRangesN ρ n) := by
    cases h
    case builder h => exact .builder (Code.mapRanges h _)
    case builderOp h => exact .builderOp (Values.mapRanges h _)
    case ret h => exact .ret (Value.mapRanges h _)
    case letIn h g => exact .letIn (Code.mapRanges h _) (Code.mapRanges g _)
    case app h g => exact .app (Value.mapRanges h _) (Values.mapRanges g _)
    case ite h g k => exact .ite (Value.mapRanges h _) (Code.mapRanges g _) (Code.mapRanges k _)
    case matchC h g => exact .matchC (Value.mapRanges h _) (Arms.mapRanges g _)
    case lazyC h => exact .lazyC (Code.mapRanges h _)
    case escape h => exact .escape (Value.mapRanges h _)
    case use h g => exact .use (Value.mapRanges h _) (Code.mapRanges g _)
    case handle h g => exact .handle (Code.mapRanges h _) (Clauses.mapRanges g _)
    case resume h g => exact .resume (Value.mapRanges h _) (Value.mapRanges g _)
    case externalCall h => exact .externalCall (Values.mapRanges h _)
    case pathBases b => exact .pathBases _
    case checkAt h g k =>
      cases h with
      | none => exact .checkAt .none (Value.mapRanges g ρ) (Value.mapRanges k ρ)
      | some hv => exact .checkAt (.some (Value.mapRanges hv ρ)) (Value.mapRanges g ρ) (Value.mapRanges k ρ)
    case method h g => exact .method (Value.mapRanges h _) (Values.mapRanges g _)
    case scalar hk count inputs simpleValues related =>
      simpa only [scalarCall_mapRanges, Comp.mapRangesN, Val.mapRangesN, Val.mapRangesListN, List.map_nil] using
        Code.scalar hk (by simpa only [range_values_length] using count) (inputs.mapRanges ρ) (simpleValues.mapRanges ρ) (Value.mapRanges related ρ)
    case projected lookup route arguments inputs count typeCount simple related =>
      exact projected_ranges lookup route arguments inputs count typeCount simple ρ (Value.mapRanges related ρ)
  theorem Arms.mapRanges {source rows as bs} (h : Arms source rows as bs) (ρ : Nat → RangeIx) :
      Arms source rows (Arm.mapRangesListN ρ as) (Arm.mapRangesListN ρ bs) := by
    cases h with
    | nil => exact .nil
    | plain h g => exact .plain (Code.mapRanges h _) (Arms.mapRanges g _)
    | guard h g k => exact .guard (Code.mapRanges h _) (Code.mapRanges g _) (Arms.mapRanges k _)
  theorem Clauses.mapRanges {source rows cs ds} (h : Clauses source rows cs ds) (ρ : Nat → RangeIx) :
      Clauses source rows (Clause.mapRangesListN ρ cs) (Clause.mapRangesListN ρ ds) := by
    cases h with
    | nil => exact .nil
    | operation h g => exact .operation (Code.mapRanges h _) (Clauses.mapRanges g _)
    | fail h g => exact .fail (Code.mapRanges h _) (Clauses.mapRanges g _)
end

mutual
  theorem Value.shiftE {source rows v w} (h : Value source rows v w) (k c : Nat) :
      Value source rows (Val.shiftEAt k c v) (Val.shiftEAt k c w) := by
    cases h
    case var i => exact .var _
    case constant c => exact .constant _
    case function f ts es rs => exact .function _ _ _ _
    case primitive b ts es rs => exact .primitive _ _ _ _
    case lam h => exact .lam (Code.shiftE h _ _)
    case dependentLam h => exact .dependentLam (Code.shiftE h _ _)
    case closure h => exact .closure h
    case con h => exact .con (Values.shiftE h _ _)
    case list h => exact .list (Values.shiftE h _ _)
    case operation o ts => exact .operation _ _
    case raise a e => exact .raise _ _
    case location l => exact .location _
    case map h g => exact .map (Values.shiftE h _ _) (Values.shiftE g _ _)
    case set h => exact .set (Values.shiftE h _ _)
    case bytes bs => exact .bytes _
    case dictionary h => exact .dictionary (Values.shiftE h _ _)
    case super h => exact .super (Value.shiftE h _ _)
    case externalFunction f ts => exact .externalFunction _ _
    case externalHandle f ts => exact .externalHandle _ _
    case pathBases s => exact .pathBases _
    case scopePattern r => exact .scopePattern _
    case checkedAt h => exact .checkedAt h
    case atError h => exact .atError h
    case checked t => exact .checked _
    case checkedRequest h => exact .checkedRequest h
  theorem Values.shiftE {source rows vs ws} (h : Values source rows vs ws) (k c : Nat) :
      Values source rows (Val.shiftEListAt k c vs) (Val.shiftEListAt k c ws) := by
    cases h with
    | nil => exact .nil
    | cons h g => exact .cons (Value.shiftE h _ _) (Values.shiftE g _ _)
  theorem OptionalValue.shiftE {source rows v w} (h : OptionalValue source rows v w) (k c : Nat) :
      OptionalValue source rows (v.map (Val.shiftEAt k c)) (w.map (Val.shiftEAt k c)) := by
    cases h with
    | none => exact .none
    | some h => exact .some (Value.shiftE h _ _)
  theorem Code.shiftE {source rows m n} (h : Code source rows m n) (k c : Nat) :
      Code source rows (Comp.shiftEAt k c m) (Comp.shiftEAt k c n) := by
    cases h
    case builder h => exact .builder (Code.shiftE h _ _)
    case builderOp h => exact .builderOp (Values.shiftE h _ _)
    case ret h => exact .ret (Value.shiftE h _ _)
    case letIn h g => exact .letIn (Code.shiftE h _ _) (Code.shiftE g _ _)
    case app h g => exact .app (Value.shiftE h _ _) (Values.shiftE g _ _)
    case ite h g k => exact .ite (Value.shiftE h _ _) (Code.shiftE g _ _) (Code.shiftE k _ _)
    case matchC h g => exact .matchC (Value.shiftE h _ _) (Arms.shiftE g _ _)
    case lazyC h => exact .lazyC (Code.shiftE h _ _)
    case escape h => exact .escape (Value.shiftE h _ _)
    case use h g => exact .use (Value.shiftE h _ _) (Code.shiftE g _ _)
    case handle h g => exact .handle (Code.shiftE h _ _) (Clauses.shiftE g _ _)
    case resume h g => exact .resume (Value.shiftE h _ _) (Value.shiftE g _ _)
    case externalCall h => exact .externalCall (Values.shiftE h _ _)
    case pathBases b => exact .pathBases _
    case checkAt h g hw =>
      cases h with
      | none => exact .checkAt .none (Value.shiftE g k c) (Value.shiftE hw k c)
      | some hv => exact .checkAt (.some (Value.shiftE hv k c)) (Value.shiftE g k c) (Value.shiftE hw k c)
    case method h g => exact .method (Value.shiftE h _ _) (Values.shiftE g _ _)
    case scalar hk count inputs simpleValues related =>
      simpa only [scalarCall_shiftE, Comp.shiftEAt, Val.shiftEAt, Val.shiftEListAt, List.map_nil] using
        Code.scalar hk (by simpa only [Val.shiftEListAt_length] using count) (inputs.shiftE k c) (simpleValues.shiftE k c) (Value.shiftE related k c)
    case projected lookup route arguments inputs count typeCount simple related =>
      exact projected_shiftE lookup route arguments inputs count typeCount simple k c (Value.shiftE related k c)
  theorem Arms.shiftE {source rows as bs} (h : Arms source rows as bs) (k c : Nat) :
      Arms source rows (Arm.shiftEListAt k c as) (Arm.shiftEListAt k c bs) := by
    cases h with
    | nil => exact .nil
    | plain h g => exact .plain (Code.shiftE h _ _) (Arms.shiftE g _ _)
    | guard h g k => exact .guard (Code.shiftE h _ _) (Code.shiftE g _ _) (Arms.shiftE k _ _)
  theorem Clauses.shiftE {source rows cs ds} (h : Clauses source rows cs ds) (k c : Nat) :
      Clauses source rows (Clause.shiftEListAt k c cs) (Clause.shiftEListAt k c ds) := by
    cases h with
    | nil => exact .nil
    | operation h g => exact .operation (Code.shiftE h _ _) (Clauses.shiftE g _ _)
    | fail h g => exact .fail (Code.shiftE h _ _) (Clauses.shiftE g _ _)
end

private theorem substTy_fn_eq {source rows ν ξ} (hv : ∀ i, Value source rows (ν i) (ξ i)) :
    substTyValues ν = substTyValues ξ := funext (substTyValues_eq hv)

private theorem substEff_fn_eq {source rows ν ξ} (hv : ∀ i, Value source rows (ν i) (ξ i)) :
    substEffValues ν = substEffValues ξ := funext (substEffValues_eq hv)

private theorem substKind_fn_eq {source rows ν ξ} (hv : ∀ i, Value source rows (ν i) (ξ i)) :
    substKind ν = substKind ξ := by
  funext kind
  cases kind <;> simp only [substKind, substTy_fn_eq hv]

theorem related_upSubst {source rows ν ξ} (hv : ∀ i, Value source rows (ν i) (ξ i)) (k i : Nat) :
    Value source rows (upSubst k ν i) (upSubst k ξ i) := by
  unfold upSubst
  split
  · exact .var _
  · exact (hv _).rename _

set_option maxHeartbeats 400000 in
mutual
  /-- 同じ観測を持つ値の置換像を、本体と捕捉した閉包へ対応させる。 -/
  theorem Value.subst {source rows v w} (h : Value source rows v w)
      (ν ξ : Nat → Val) (ρ : Nat → LocalRef) (hv : ∀ i, Value source rows (ν i) (ξ i)) (simple : ∀ i, SimpleValue (ν i)) :
      Value source rows (v.subst ν ρ) (w.subst ξ ρ) := by
    cases h with
    | var i => exact hv i
    | constant c => exact .constant c
    | function f ts es rs =>
      simp only [Val.subst, substTy_fn_eq hv, substEff_fn_eq hv]
      exact .function _ _ _ _
    | primitive b ts es rs =>
      simp only [Val.subst, substTy_fn_eq hv, substEff_fn_eq hv]
      exact .primitive _ _ _ _
    | lam h =>
      simp only [Val.subst, substTy_fn_eq hv]
      exact .lam (Code.subst h _ _ _ (related_upSubst hv _) (simple_upSubst simple _))
    | dependentLam h =>
      simp only [Val.subst, valueEnvs hv]
      exact .dependentLam (Code.subst h _ _ _ (related_upSubst hv _) (simple_upSubst simple _))
    | closure h => exact .closure h
    | con h =>
      simp only [Val.subst, substTy_fn_eq hv]
      exact .con (Values.subst h ν ξ ρ hv simple)
    | list h => exact .list (Values.subst h ν ξ ρ hv simple)
    | operation o ts =>
      simp only [Val.subst, substTy_fn_eq hv]
      exact .operation _ _
    | raise a e =>
      simp only [Val.subst, substTy_fn_eq hv]
      exact .raise _ _
    | location l => exact .location l
    | map h g => exact .map (Values.subst h ν ξ ρ hv simple) (Values.subst g ν ξ ρ hv simple)
    | set h => exact .set (Values.subst h ν ξ ρ hv simple)
    | bytes bs => exact .bytes bs
    | dictionary h =>
      simp only [Val.subst, substTy_fn_eq hv]
      exact .dictionary (Values.subst h ν ξ ρ hv simple)
    | super h => exact .super (Value.subst h ν ξ ρ hv simple)
    | externalFunction f ts =>
      simp only [Val.subst, substTy_fn_eq hv]
      exact .externalFunction _ _
    | externalHandle f ts =>
      simp only [Val.subst, substTy_fn_eq hv]
      exact .externalHandle _ _
    | pathBases s => exact .pathBases s
    | scopePattern r => exact .scopePattern r
    | checkedAt h => exact .checkedAt h
    | atError h => exact .atError h
    | checked t => exact .checked t
    | checkedRequest h => exact .checkedRequest h
  theorem Values.subst {source rows vs ws} (h : Values source rows vs ws)
      (ν ξ : Nat → Val) (ρ : Nat → LocalRef) (hv : ∀ i, Value source rows (ν i) (ξ i)) (simple : ∀ i, SimpleValue (ν i)) :
      Values source rows (Val.substList ν vs ρ) (Val.substList ξ ws ρ) := by
    cases h with
    | nil => exact .nil
    | cons h g => exact .cons (Value.subst h ν ξ ρ hv simple) (Values.subst g ν ξ ρ hv simple)
  theorem Code.subst {source rows m n} (h : Code source rows m n)
      (ν ξ : Nat → Val) (ρ : Nat → LocalRef) (hv : ∀ i, Value source rows (ν i) (ξ i)) (simple : ∀ i, SimpleValue (ν i)) :
      Code source rows (m.subst ν ρ) (n.subst ξ ρ) := by
    cases h with
    | builder h =>
      simp only [Comp.subst, substKind_fn_eq hv]
      exact .builder (Code.subst h _ _ _ (related_upSubst hv _) (simple_upSubst simple _))
    | builderOp h =>
      simp only [Comp.subst, substKind_fn_eq hv]
      exact .builderOp (Values.subst h ν ξ ρ hv simple)
    | ret h => exact .ret (Value.subst h ν ξ ρ hv simple)
    | letIn h g => exact .letIn (Code.subst h ν ξ ρ hv simple) (Code.subst g _ _ _ (related_upSubst hv _) (simple_upSubst simple _))
    | app h g => exact .app (Value.subst h ν ξ ρ hv simple) (Values.subst g ν ξ ρ hv simple)
    | ite h g k => exact .ite (Value.subst h ν ξ ρ hv simple) (Code.subst g ν ξ ρ hv simple) (Code.subst k ν ξ ρ hv simple)
    | matchC h g => exact .matchC (Value.subst h ν ξ ρ hv simple) (Arms.subst g ν ξ ρ hv simple)
    | lazyC h => exact .lazyC (Code.subst h ν ξ ρ hv simple)
    | escape h => exact .escape (Value.subst h ν ξ ρ hv simple)
    | use h g => exact .use (Value.subst h ν ξ ρ hv simple) (Code.subst g ν ξ ρ hv simple)
    | handle h g => exact .handle (Code.subst h ν ξ ρ hv simple) (Clauses.subst g ν ξ ρ hv simple)
    | resume h g => exact .resume (Value.subst h ν ξ ρ hv simple) (Value.subst g ν ξ ρ hv simple)
    | externalCall h =>
      simp only [Comp.subst, substTy_fn_eq hv]
      exact .externalCall (Values.subst h ν ξ ρ hv simple)
    | pathBases b => exact .pathBases b
    | checkAt hb hp hw =>
      cases hb with
      | none =>
        simp only [Comp.subst, substTy_fn_eq hv]
        exact .checkAt .none (Value.subst hp ν ξ ρ hv simple) (Value.subst hw ν ξ ρ hv simple)
      | some h =>
        simp only [Comp.subst, substTy_fn_eq hv]
        exact .checkAt (.some (Value.subst h ν ξ ρ hv simple)) (Value.subst hp ν ξ ρ hv simple) (Value.subst hw ν ξ ρ hv simple)
    | method h g =>
      simp only [Comp.subst, substTy_fn_eq hv, substEff_fn_eq hv]
      exact .method (Value.subst h ν ξ ρ hv simple) (Values.subst g ν ξ ρ hv simple)
    | scalar hk count inputs simpleValues related =>
      exact scalar_substitution hk count inputs simpleValues ν ξ ρ simple (Value.subst related ν ξ ρ hv simple)
    | projected lookup route arguments inputs count typeCount rootSimple related =>
      exact projected_subst lookup route arguments inputs count typeCount rootSimple ν ξ ρ simple
        (Value.subst related ν ξ ρ hv simple)
  theorem Arms.subst {source rows as bs} (h : Arms source rows as bs)
      (ν ξ : Nat → Val) (ρ : Nat → LocalRef) (hv : ∀ i, Value source rows (ν i) (ξ i)) (simple : ∀ i, SimpleValue (ν i)) :
      Arms source rows (Arm.substList ν as ρ) (Arm.substList ξ bs ρ) := by
    cases h with
    | nil => exact .nil
    | plain h g => exact .plain (Code.subst h _ _ _ (related_upSubst hv _) (simple_upSubst simple _)) (Arms.subst g ν ξ ρ hv simple)
    | @guard alts _ _ _ _ _ _ h g k =>
      have lifted := related_upSubst hv (Benitoite.Release.Arm.bindersOf alts)
      apply Arms.guard
      · exact Code.subst h (upSubst (Benitoite.Release.Arm.bindersOf alts) ν)
          (upSubst (Benitoite.Release.Arm.bindersOf alts) ξ) (upLocalSubst (Benitoite.Release.Arm.bindersOf alts) ρ) lifted (simple_upSubst simple _)
      · exact Code.subst g (upSubst (Benitoite.Release.Arm.bindersOf alts) ν)
          (upSubst (Benitoite.Release.Arm.bindersOf alts) ξ) (upLocalSubst (Benitoite.Release.Arm.bindersOf alts) ρ) lifted (simple_upSubst simple _)
      · exact Arms.subst k ν ξ ρ hv simple
  theorem Clauses.subst {source rows cs ds} (h : Clauses source rows cs ds)
      (ν ξ : Nat → Val) (ρ : Nat → LocalRef) (hv : ∀ i, Value source rows (ν i) (ξ i)) (simple : ∀ i, SimpleValue (ν i)) :
      Clauses source rows (Clause.substList ν cs ρ) (Clause.substList ξ ds ρ) := by
    cases h with
    | nil => exact .nil
    | operation h g =>
      exact .operation (Code.subst h _ _ _ (related_upSubst (fun i => Value.shiftE (hv i) _ _) _)
        (simple_upSubst (fun i => (simple i).shiftE _ _) _)) (Clauses.subst g ν ξ ρ hv simple)
    | fail h g =>
      simp only [Clause.substList, substTy_fn_eq hv]
      exact .fail (Code.subst h _ _ _ (related_upSubst (fun i => Value.shiftE (hv i) _ _) _)
        (simple_upSubst (fun i => (simple i).shiftE _ _) _)) (Clauses.subst g ν ξ ρ hv simple)
end

/-- 準備後の型付けが定数を示す場合、元の値も同じ定数である。 -/
theorem Value.constant_right {source rows v c} (h : Value source rows v (.const c)) : v = .const c := by
  cases h
  rfl

theorem Value.instR {source rows v w} (h : Value source rows v w) (rs : List RangeExpr) :
    Value source rows (v.instR rs) (w.instR rs) := by
  cases rs with
  | nil => exact h
  | cons r rs => exact h.mapRanges _

theorem Code.instR {source rows m n} (h : Code source rows m n) (rs : List RangeExpr) :
    Code source rows (m.instR rs) (n.instR rs) := by
  cases rs with
  | nil => exact h
  | cons r rs => exact h.mapRanges _

mutual
  theorem Value.refl {source rows} (v : Val) : Value source rows v v := by
    cases v with
    | var i => exact .var i
    | const c => exact .constant c
    | fnRef f ts es rs => exact .function f ts es rs
    | prim b ts es rs => exact .primitive b ts es rs
    | lam ns ps m => exact .lam (Code.refl m)
    | dependentLam t m => exact .dependentLam (Code.refl m)
    | closure t q => exact .closure (ClosedCode.refl q)
    | con c ts vs => exact .con (Values.refl vs)
    | list vs => exact .list (Values.refl vs)
    | op o ts => exact .operation o ts
    | raise a e => exact .raise a e
    | loc l => exact .location l
    | mapV ks vs => exact .map (Values.refl ks) (Values.refl vs)
    | setV vs => exact .set (Values.refl vs)
    | bytesV bs => exact .bytes bs
    | dict i ts vs => exact .dictionary (Values.refl vs)
    | super v s => exact .super (Value.refl v)
    | externalRef f ts => exact .externalFunction f ts
    | externalHandle h ts => exact .externalHandle h ts
    | pathBases s => exact .pathBases s
    | scopePattern r => exact .scopePattern r
    | checkedAt r s t v => exact .checkedAt (OptionalValue.refl v)
    | atError d => exact .atError d
    | checked t => exact .checked t
    | checkedRequest t v => exact .checkedRequest (Value.refl v)
  theorem Values.refl {source rows} (vs : List Val) : Values source rows vs vs := by
    cases vs with
    | nil => exact .nil
    | cons v vs => exact .cons (Value.refl v) (Values.refl vs)
  theorem OptionalValue.refl {source rows} (v : Option Val) : OptionalValue source rows v v := by
    cases v with
    | none => exact .none
    | some v => exact .some (Value.refl v)
  theorem Slots.refl {source rows} (vs : List (Option Val)) : Slots source rows vs vs := by
    cases vs with
    | nil => exact .nil
    | cons v vs => exact .cons (OptionalValue.refl v) (Slots.refl vs)
  theorem Captures.refl {source rows} (cap : Capture) : Captures source rows cap cap := by
    cases cap with
    | mk vs => exact .mk (Slots.refl vs)
  theorem ClosedCode.refl {source rows} (q : Closure) : ClosedCode source rows q q := by
    cases q with
    | mk cap m => exact .mk (Captures.refl cap) (Code.refl m)
  theorem Code.refl {source rows} (m : Comp) : Code source rows m m := by
    cases m with
    | builderLet k m => exact .builder (Code.refl m)
    | builderOp k o r vs => exact .builderOp (Values.refl vs)
    | ret v => exact .ret (Value.refl v)
    | letIn m n => exact .letIn (Code.refl m) (Code.refl n)
    | app f vs => exact .app (Value.refl f) (Values.refl vs)
    | ite v m n => exact .ite (Value.refl v) (Code.refl m) (Code.refl n)
    | «match» v as => exact .matchC (Value.refl v) (Arms.refl as)
    | lazyC m => exact .lazyC (Code.refl m)
    | escape v => exact .escape (Value.refl v)
    | use v m => exact .use (Value.refl v) (Code.refl m)
    | handle m cs => exact .handle (Code.refl m) (Clauses.refl cs)
    | resume k v => exact .resume (Value.refl v) (Value.refl k)
    | externalCall f ts vs => exact .externalCall (Values.refl vs)
    | issuePathBases b => exact .pathBases b
    | checkAt k o sh bs p v ix => exact .checkAt (OptionalValue.refl bs) (Value.refl p) (Value.refl v)
    | meth d m ts es vs => exact .method (Value.refl d) (Values.refl vs)
  theorem Arms.refl {source rows} (as : List Arm) : Arms source rows as as := by
    cases as with
    | nil => exact .nil
    | cons a as =>
      cases a with
      | mk alts guard body =>
        cases guard with
        | none => exact .plain (Code.refl body) (Arms.refl as)
        | some g => exact .guard (Code.refl g) (Code.refl body) (Arms.refl as)
  theorem Clauses.refl {source rows} (cs : List Clause) : Clauses source rows cs cs := by
    cases cs with
    | nil => exact .nil
    | cons c cs =>
      cases c with
      | mk o a nt m => exact .operation (Code.refl m) (Clauses.refl cs)
      | fail e m => exact .fail (Code.refl m) (Clauses.refl cs)
end

theorem OptionalValue.instR {source rows v w} (h : OptionalValue source rows v w) (rs : List RangeExpr) :
    OptionalValue source rows (v.map (Val.instR rs)) (w.map (Val.instR rs)) := by
  cases h with
  | none => exact .none
  | some h => exact .some (h.instR rs)

theorem Slots.instR {source rows vs ws} (h : Slots source rows vs ws) (rs : List RangeExpr) :
    Slots source rows (vs.map (Option.map (Val.instR rs))) (ws.map (Option.map (Val.instR rs))) := by
  cases h with
  | nil => exact .nil
  | cons h g => exact .cons (h.instR rs) (Slots.instR g rs)

theorem Captures.instR {source rows cap cap'} (h : Captures source rows cap cap') (rs : List RangeExpr) :
    Captures source rows (cap.instR rs) (cap'.instR rs) := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    cases h with
    | mk h => exact .mk (h.instR (r :: rs))

theorem ClosedCode.instR {source rows q r} (h : ClosedCode source rows q r) (rs : List RangeExpr) :
    ClosedCode source rows (q.instR rs) (r.instR rs) := by
  cases rs with
  | nil => exact h
  | cons s rs =>
    cases h with
    | mk hc hcode => exact .mk (hc.instR (s :: rs)) (hcode.instR (s :: rs))

theorem ClosedCode.instantiate {source rows q r vs ws} (h : ClosedCode source rows q r)
    (ts : List Ty) (es : List Eff) (hv : Values source rows vs ws) :
    ClosedCode source rows (q.instantiate ts es vs) (r.instantiate ts es ws) := by
  cases h with
  | mk hc hcode => exact .mk (hc.extendMany hv) (hcode.substTy 0 ts es)

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
