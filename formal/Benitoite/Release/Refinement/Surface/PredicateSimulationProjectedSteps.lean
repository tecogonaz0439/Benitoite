import Benitoite.Release.Refinement.Surface.PredicateSimulationInvariant
import Benitoite.Release.Refinement.Surface.PredicateProjectionResponse
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionArgumentsControl
import Benitoite.Release.Refinement.Surface.PredicateSimulationStructure

/-! # getter列の終了後に行う判定の実一段

元の公開呼出しと内部行が読む同じ欄の定数を固定し、実際の標準δを同期させる。
欄の型付けは準備後の受け手と生成行の経路だけから導く。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse PredicateProjection
noncomputable section

theorem projected_overlay_signature {B rows projection key}
    (lookup : rows.lookup key = some (.projected projection)) :
    (Check.predicateOverlay B rows).sig key = some projection.signature := by
  simp only [Check.predicateOverlay,lookup,Row.signature]

theorem projected_overlay_delta {B rows projection key}
    (lookup : rows.lookup key = some (.projected projection)) (types effects ranges values) :
    (Check.predicateOverlay B rows).delta key types effects ranges values =
      projection.delta types effects ranges values := by
  simp only [Check.predicateOverlay,lookup,Row.delta]

private theorem scalar_bind (θ : SubstEnv) (tag : BaseTy) :
    ∀ a : Ty, a.core = .base tag → (a.rawBind θ).core = .base tag
  | .refined a _, h => by rw [Ty.rawBind, Ty.core]; exact scalar_bind θ tag a h
  | .base _, h => h
  | .opaque _ _, h | .data _ _, h | .list _, h | .fn _ _ _ _, h | .tvar _, h | .reference _, h | .lazy _, h
  | .cont _ _ _, h | .map _ _, h | .set _, h | .bytes, h | .dict _ _, h | .tapp _ _, h | .ctor _, h
  | .dependentFn _, h | .external _ _, h | .scoped _ _ _, h | .pathBases, h | .scopePattern _, h => by
    cases h

private theorem scalar_subst {a : Ty} {tag : BaseTy}
    (scalar : a.norm.core = .base tag) (types : List Ty) :
    (a.substAt 0 types []).norm.core = .base tag := by
  simp only [Ty.substAt,substTypeAt,Ty.bind,Ty.norm_idem]
  rw [← Ty.norm_rawBind]
  rw [Ty.core_norm,scalar_bind _ tag a.norm scalar]
  rfl

/-- 実targetの単一引数から、読まれた同じ定数のscalar型を回収する。 -/
theorem projected_target_leaf {Q B σ effect rows projection key cap types receiver constant k μ}
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped (Check.predicateOverlay B rows))
    (core : (Check.predicateOverlay B rows).CoreAssumptions Q) (variance : Q.VarianceValid)
    (valid : Valid Q projection) (lookup : rows.lookup key = some (.projected projection))
    (read : MatchFacts.readPath (closeVal cap receiver) projection.route = some (.const constant))
    (state : StateTyE Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap (.app (.prim key types [] []) [receiver])) k μ)) :
    ∃ Ψ, HasTypeVQ Q (Check.predicateOverlay B rows) Ψ Qempty [] [] [] (.const constant) (.base projection.entry.input) := by
  obtain ⟨Ψ,R,a,e,signature,r,ef,store,closure,found,ranges,admissible,instantiated,arguments,le,covers⟩ :=
    state.primitive_contract_inputs (b := key) (ts := types.map cap.closeTy) (es := []) (rs := [])
      (ws := [closeVal cap receiver]) wellFormed wellTyped core (by rfl)
  have same : signature = projection.signature :=
    Option.some.inj (found.symm.trans (projected_overlay_signature lookup))
  subst signature
  rw [PredicateProjection.instantiated] at arguments
  cases arguments with
  | param annotation receiverTyped rest =>
    obtain ⟨leafType,path,scalar⟩ := valid.path
    have actualPath := path.substAt wellFormed 0 (types.map cap.closeTy) []
    obtain ⟨leaf,selected,leafTyped⟩ := actualPath.select variance receiverTyped.V_Normal
    have equality : leaf = .const constant := Option.some.inj (selected.symm.trans read)
    subst leaf
    obtain ⟨actual,same,ok,tag⟩ := leafTyped.canonical_scalar
      (by simpa only [Ty.norm_idem] using scalar_subst scalar (types.map cap.closeTy))
    cases Val.const.inj same
    have typeEq : constant.type = .base projection.entry.input := by
      cases constant <;> simpa only [Const.type,Ty.norm,Ty.core] using tag
    exact ⟨Ψ,typeEq ▸ HasTypeVQ.V_Const ok⟩

def projectedResult (projection : Projection) (constant : Const) : Val :=
  .const (.boolean (projection.entry.run [.const constant]))

theorem projected_target_reply {B rows projection key cap receiver constant} {types : List Ty}
    (lookup : rows.lookup key = some (.projected projection)) (count : types.length = projection.ntys)
    (read : MatchFacts.readPath (closeVal cap receiver) projection.route = some (.const constant)) :
    (Check.predicateOverlay B rows).delta key (Ty.normTys (types.map cap.closeTy)) [] [] [closeVal cap receiver] =
      some (.val (projectedResult projection constant)) := by
  rw [projected_overlay_delta lookup]
  rw [PredicateProgramSemantics.public_deltas.projected projection _ _ _
    (by simpa only [Ty.normTys_eq_map,List.length_map] using count) read]
  rfl

theorem projected_source_reply {source : Program} {rows : Table.Rows} {Q B D Ψ api projection arguments constant}
    [StandardModel.RowLookup B]
    (inputs : ScalarInputs api projection.entry arguments (.const constant))
    (typed : HasTypeVQ Q D Ψ Qempty [] [] [] (.const constant) (.base projection.entry.input)) :
    B.delta api.name [] [] [] arguments = some (.val (projectedResult projection constant)) := by
  rw [scalar_source_delta inputs (Value.refl (source := source) (rows := rows) (.const constant)) typed]
  rfl

theorem projected_target_step (Q : Refinement.Program) (B : Builtins) (σ : PathEnv)
    {rows projection key cap types receiver constant k μ}
    (lookup : rows.lookup key = some (.projected projection)) (count : types.length = projection.ntys)
    (read : MatchFacts.readPath (closeVal cap receiver) projection.route = some (.const constant)) :
    Step Q (Check.predicateOverlay B rows) σ
      (.run (.mk cap (.app (.prim key types [] []) [receiver])) k μ) none
      (.run (.pure (.ret (projectedResult projection constant))) k μ) := by
  exact .E_Prim (ts := types.map cap.closeTy) (es := []) (rs := [])
    rfl (projected_overlay_signature lookup) rfl (projected_target_reply lookup count read)

theorem projected_source_step (P : Refinement.Program) (B : Builtins) (σ : PathEnv)
    [StandardModel.RowLookup B] {source : Program} {rows : Table.Rows} {Q D Ψ api projection arguments constant q k μ}
    (view : q.view = .app (.prim api.name [] [] []) arguments)
    (inputs : ScalarInputs api projection.entry arguments (.const constant))
    (typed : HasTypeVQ Q D Ψ Qempty [] [] [] (.const constant) (.base projection.entry.input)) :
    Step P B σ (.run q k μ) none (.run (.pure (.ret (projectedResult projection constant))) k μ) :=
  .E_Prim (ts := []) (es := []) (rs := []) view (public_signature api) rfl
    (projected_source_reply (B := B) (source := source) (rows := rows) inputs typed)

private theorem projected_result_avoid {keys q k μ projection constant}
    (avoid : StateAvoid keys (.run q k μ)) :
    StateAvoid keys (.run (.pure (.ret (projectedResult projection constant))) k μ) :=
  ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,ValueAvoid.constant _ _⟩,avoid.2⟩

theorem projected_application_forward (P Q : Refinement.Program) (B : Builtins) (σ : PathEnv)
    [StandardModel.RowLookup B] {source rows effect api projection key q cap arguments types receiver constant k l μ ν label destination}
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped (Check.predicateOverlay B rows))
    (effects : Q.EffectsOk (Check.predicateOverlay B rows))
    (core : (Check.predicateOverlay B rows).CoreAssumptions Q) (pathEnvironment : σ.Valid)
    (variance : Q.VarianceValid) (valid : Valid Q projection)
    (lookup : rows.lookup key = some (.projected projection))
    (view : q.view = .app (.prim api.name [] [] []) arguments)
    (inputs : ScalarInputs api projection.entry arguments (.const constant))
    (count : types.length = projection.ntys)
    (read : MatchFacts.readPath (closeVal cap receiver) projection.route = some (.const constant))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (typed : StateTyE Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap (.app (.prim key types [] []) [receiver])) l ν))
    (avoid : NoGeneratedKeys rows (.run q k μ)) (actual : Step P B σ (.run q k μ) label destination) :
    ForwardResult source rows Q (Check.predicateOverlay B rows) σ effect (.run q k μ)
      (.run (.mk cap (.app (.prim key types [] []) [receiver])) l ν) label destination := by
  obtain ⟨Ψ,leafTyped⟩ := projected_target_leaf wellFormed wellTyped core variance valid lookup read typed
  have sourceReply := projected_source_reply (B := B) (source := source) (rows := rows) inputs leafTyped
  obtain ⟨rfl,rfl⟩ := pure_step_unique view (public_signature api) rfl sourceReply actual
  exact ForwardResult.of_step wellFormed wellTyped effects core pathEnvironment typed
    (projected_target_step Q B σ lookup count read)
    (.run (.mk (.mk .nil) (.ret (.constant _))) continuation store) (projected_result_avoid avoid)

theorem projected_application_backward (P Q : Refinement.Program) (B : Builtins) (σ : PathEnv)
    [StandardModel.RowLookup B] {source rows effect api projection key q cap arguments types receiver constant k l μ ν label destination}
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped (Check.predicateOverlay B rows))
    (effects : Q.EffectsOk (Check.predicateOverlay B rows))
    (core : (Check.predicateOverlay B rows).CoreAssumptions Q) (pathEnvironment : σ.Valid)
    (variance : Q.VarianceValid) (valid : Valid Q projection)
    (lookup : rows.lookup key = some (.projected projection))
    (view : q.view = .app (.prim api.name [] [] []) arguments)
    (inputs : ScalarInputs api projection.entry arguments (.const constant))
    (count : types.length = projection.ntys)
    (read : MatchFacts.readPath (closeVal cap receiver) projection.route = some (.const constant))
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (typed : StateTyE Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap (.app (.prim key types [] []) [receiver])) l ν))
    (avoid : NoGeneratedKeys rows (.run q k μ))
    (actual : Step Q (Check.predicateOverlay B rows) σ
      (.run (.mk cap (.app (.prim key types [] []) [receiver])) l ν) label destination) :
    BackwardResult source rows P Q B (Check.predicateOverlay B rows) σ effect (.run q k μ)
      (.run (.mk cap (.app (.prim key types [] []) [receiver])) l ν) label destination := by
  obtain ⟨Ψ,leafTyped⟩ := projected_target_leaf wellFormed wellTyped core variance valid lookup read typed
  obtain ⟨rfl,rfl⟩ := pure_step_unique_with_types
    (ts := types.map cap.closeTy) (es := []) (rs := []) (ws := [closeVal cap receiver]) rfl
    (projected_overlay_signature lookup) rfl (projected_target_reply lookup count read) actual
  exact BackwardResult.of_step wellFormed wellTyped effects core pathEnvironment typed actual
    (projected_source_step P B σ (source := source) (rows := rows) view inputs leafTyped)
    (.run (.mk (.mk .nil) (.ret (.constant _))) continuation store) (projected_result_avoid avoid)

/-- 実Code.projectedの受け手の型から、公開appまでの全管理経路を具体的に生成する。 -/
theorem projected_root_ready {source rows P Q B σ effect api projection key positions computations symbolic root receiver
    steps cap cap' types k l μ ν}
    (program : ProgramRel source rows P Q)
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped (Check.predicateOverlay B rows))
    (core : (Check.predicateOverlay B rows).CoreAssumptions Q) (variance : Q.VarianceValid)
    (valid : Valid Q projection) (lookup : rows.lookup key = some (.projected projection))
    (route : projection.route = steps.map PredicateAccessorTargets.Step.reference)
    (arguments : ProjectionArguments source root steps computations symbolic)
    (inputs : ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0))
    (simple : SimpleValue root) (captures : Captures source rows cap cap') (related : Value source rows root receiver)
    (typed : StateTyE Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap' (.app (.prim key types [] []) [receiver])) l ν)) :
    ∃ constant declared result,
      AdministrativePath source (.run (.mk cap (sourceCall api positions computations)) k μ) (.run result k μ) ∧
      result.view = .app (.prim api.name [] [] []) declared ∧
      ScalarInputs api projection.entry declared (.const constant) ∧
      MatchFacts.readPath (closeVal cap' receiver) projection.route = some (.const constant) := by
  obtain ⟨Ψ,R,a,e,signature,r,ef,store,closure,found,ranges,admissible,instantiated,actualArguments,le,covers⟩ :=
    typed.primitive_contract_inputs (b := key) (ts := types.map cap'.closeTy) (es := []) (rs := [])
      (ws := [closeVal cap' receiver]) wellFormed wellTyped core (by rfl)
  have same : signature = projection.signature :=
    Option.some.inj (found.symm.trans (projected_overlay_signature lookup))
  subst signature
  rw [PredicateProjection.instantiated] at actualArguments
  cases actualArguments with
  | param annotation receiverTyped rest =>
    obtain ⟨leafType,path,scalar⟩ := valid.path
    have actualPath := path.substAt wellFormed 0 (types.map cap'.closeTy) []
    obtain ⟨leaf,read,leafTyped⟩ := actualPath.select variance receiverTyped.V_Normal
    have scalarType : ((leafType.substAt 0 (types.map cap'.closeTy) []).norm).norm.core = .base projection.entry.input := by
      simpa only [Ty.norm_idem] using scalar_subst scalar (types.map cap'.closeTy)
    obtain ⟨constant,rfl,ok,tag⟩ := leafTyped.canonical_scalar scalarType
    have targetCons : ∀ constructor declaration,
        source.cons constructor = some declaration → Q.cons constructor = some declaration := by
      intro constructor declaration selected
      rw [← program.types.cons]
      exact program.getters.constructors constructor declaration selected
    have getterRead : MatchFacts.readPath (closeVal cap' receiver)
        (steps.map PredicateAccessorTargets.Step.reference) = some (.const constant) := by
      rw [← route]
      exact read
    obtain ⟨result,control,view⟩ := arguments.sourceCall_path targetCons simple cap (closeVal cap' receiver)
      _ receiverTyped (related.close captures) constant getterRead projection.entry _ leafTyped scalarType api positions k μ
    exact ⟨constant,_,result,control,view,inputs.projection_values,read⟩

theorem projected_root_forward {source rows P Q B σ effect api projection key positions computations symbolic root receiver
    steps cap cap' types k l μ ν label destination} [StandardModel.RowLookup B]
    (program : ProgramRel source rows P Q)
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped (Check.predicateOverlay B rows))
    (effects : Q.EffectsOk (Check.predicateOverlay B rows))
    (core : (Check.predicateOverlay B rows).CoreAssumptions Q) (pathEnvironment : σ.Valid)
    (variance : Q.VarianceValid) (valid : Valid Q projection)
    (lookup : rows.lookup key = some (.projected projection))
    (route : projection.route = steps.map PredicateAccessorTargets.Step.reference)
    (arguments : ProjectionArguments source root steps computations symbolic)
    (inputs : ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0))
    (count : types.length = projection.ntys) (simple : SimpleValue root)
    (captures : Captures source rows cap cap') (related : Value source rows root receiver)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (typed : StateTyE Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap' (.app (.prim key types [] []) [receiver])) l ν))
    (avoid : NoGeneratedKeys rows (.run (.mk cap (sourceCall api positions computations)) k μ))
    (actual : Step P B σ (.run (.mk cap (sourceCall api positions computations)) k μ) label destination) :
    ForwardResult source rows Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap (sourceCall api positions computations)) k μ)
      (.run (.mk cap' (.app (.prim key types [] []) [receiver])) l ν) label destination := by
  obtain ⟨constant,declared,result,path,view,actualInputs,read⟩ := projected_root_ready program wellFormed wellTyped core
    variance valid lookup route arguments inputs simple captures related typed
  cases path with
  | nil =>
    exact projected_application_forward P Q B σ wellFormed wellTyped effects core pathEnvironment variance valid
      lookup view actualInputs count read continuation store typed avoid actual
  | cons first rest =>
    exact ForwardResult.administrative program.getters first
      (.administrative rest (.projectedApplication lookup view actualInputs count read continuation store)) avoid typed actual

theorem projected_root_backward {source rows P Q B σ effect api projection key positions computations symbolic root receiver
    steps cap cap' types k l μ ν label destination} [StandardModel.RowLookup B]
    (program : ProgramRel source rows P Q)
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped (Check.predicateOverlay B rows))
    (effects : Q.EffectsOk (Check.predicateOverlay B rows))
    (core : (Check.predicateOverlay B rows).CoreAssumptions Q) (pathEnvironment : σ.Valid)
    (variance : Q.VarianceValid) (valid : Valid Q projection)
    (lookup : rows.lookup key = some (.projected projection))
    (route : projection.route = steps.map PredicateAccessorTargets.Step.reference)
    (arguments : ProjectionArguments source root steps computations symbolic)
    (inputs : ScalarInputs api projection.entry (recordFields api.inputs.length positions symbolic (.const .unit)) (.var 0))
    (count : types.length = projection.ntys) (simple : SimpleValue root)
    (captures : Captures source rows cap cap') (related : Value source rows root receiver)
    (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (typed : StateTyE Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap' (.app (.prim key types [] []) [receiver])) l ν))
    (avoid : NoGeneratedKeys rows (.run (.mk cap (sourceCall api positions computations)) k μ))
    (actual : Step Q (Check.predicateOverlay B rows) σ
      (.run (.mk cap' (.app (.prim key types [] []) [receiver])) l ν) label destination) :
    BackwardResult source rows P Q B (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap (sourceCall api positions computations)) k μ)
      (.run (.mk cap' (.app (.prim key types [] []) [receiver])) l ν) label destination := by
  obtain ⟨constant,declared,result,path,view,actualInputs,read⟩ := projected_root_ready program wellFormed wellTyped core
    variance valid lookup route arguments inputs simple captures related typed
  have matched := projected_application_backward P Q B σ wellFormed wellTyped effects core pathEnvironment variance valid
    lookup view actualInputs count read continuation store typed (path.noMint avoid) actual
  exact matched.prepend program.getters path

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
