import Benitoite.Release.Refinement.Surface.PredicateSimulationStateAvoid
import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarSteps
import Benitoite.Release.Refinement.FiniteStepPreservation

/-! # 実状態の対応と準備後の型付け

元の状態には生成名の不在を課し、型付けは準備後の状態だけから使う。
管理用経路の省略と、事象を含む実一段を同じ有限実行の返値へ持ち上げる。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

def InvariantRel (source : Program) (rows : PredicateProjection.Table.Rows)
    (Q : Refinement.Program) (D : Builtins) (σ : PathEnv) (effect : Eff) (first second : State) : Prop :=
  StateRel source rows first second ∧ NoGeneratedKeys rows first ∧ StateTyE Q D σ effect second

def ForwardResult (source : Program) (rows : PredicateProjection.Table.Rows)
    (Q : Refinement.Program) (D : Builtins) (σ : PathEnv) (effect : Eff)
    (first second : State) (label : Option Event) (destination : State) : Prop :=
  ∃ next, Steps Q D σ second label.toList next ∧ InvariantRel source rows Q D σ effect destination next ∧
    (SafeCheckErasure.Descends Q D σ next second ∨
      (label = none ∧ next = second ∧ administrativeRank source destination < administrativeRank source first))

def BackwardResult (source : Program) (rows : PredicateProjection.Table.Rows)
    (P Q : Refinement.Program) (B D : Builtins) (σ : PathEnv) (effect : Eff)
    (first _second : State) (label : Option Event) (destination : State) : Prop :=
  ∃ next, Steps P B σ first label.toList next ∧ InvariantRel source rows Q D σ effect next destination ∧
    SafeCheckErasure.Descends P B σ next first

theorem ForwardResult.of_step {source rows Q D σ effect first second label destination next}
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped D) (effects : Q.EffectsOk D)
    (core : D.CoreAssumptions Q) (pathEnvironment : σ.Valid)
    (typed : StateTyE Q D σ effect second) (step : Step Q D σ second label next)
    (related : StateRel source rows destination next) (avoid : NoGeneratedKeys rows destination) :
    ForwardResult source rows Q D σ effect first second label destination := by
  refine ⟨next,?_,⟨related,avoid,typed.step_preserved wellFormed wellTyped effects core pathEnvironment step⟩,
    Or.inl (.one step)⟩
  simpa only [List.append_nil] using Steps.cons step Steps.nil

theorem ForwardResult.administrative {source rows P Q B D σ effect first ready second label destination}
    (environment : GetterEnvironment source P) (control : AdministrativeStep source first ready)
    (related : StateRel source rows ready second) (avoid : NoGeneratedKeys rows first)
    (typed : StateTyE Q D σ effect second) (step : Step P B σ first label destination) :
    ForwardResult source rows Q D σ effect first second label destination := by
  obtain ⟨rfl,rfl⟩ := control.unique environment step
  exact ⟨second,.nil,⟨related,control.noMint avoid,typed⟩,Or.inr ⟨rfl,rfl,control.decreases⟩⟩

theorem BackwardResult.of_step {source rows P Q B D σ effect first second label destination next}
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped D) (effects : Q.EffectsOk D)
    (core : D.CoreAssumptions Q) (pathEnvironment : σ.Valid)
    (typed : StateTyE Q D σ effect second) (targetStep : Step Q D σ second label destination)
    (sourceStep : Step P B σ first label next)
    (related : StateRel source rows next destination) (avoid : NoGeneratedKeys rows next) :
    BackwardResult source rows P Q B D σ effect first second label destination := by
  refine ⟨next,?_,⟨related,avoid,typed.step_preserved wellFormed wellTyped effects core pathEnvironment targetStep⟩,
    .one sourceStep⟩
  simpa only [List.append_nil] using Steps.cons sourceStep Steps.nil

theorem BackwardResult.prepend {source rows P Q B D σ effect first ready second label destination}
    (environment : GetterEnvironment source P) (path : AdministrativePath source first ready)
    (matched : BackwardResult source rows P Q B D σ effect ready second label destination) :
    BackwardResult source rows P Q B D σ effect first second label destination := by
  obtain ⟨next,steps,related,nonempty⟩ := matched
  have beginning := path.realize (B := B) (σ := σ) environment
  exact ⟨next,by simpa only [List.nil_append] using SafeCheckErasure.steps_append beginning steps,
    related,Steps.prepend_descends beginning nonempty⟩

theorem ScalarPhase.cont_store_avoid {keys api positions values cap k μ state rank}
    (phase : ScalarPhase api positions values cap k μ state rank) (avoid : StateAvoid keys state) :
    ContAvoid keys k ∧ StoreAvoid keys μ := by
  cases phase with
  | chain => exact avoid.2
  | argument => exact ⟨(ContAvoid.cons.mp avoid.2.1).2,avoid.2.2⟩

theorem ScalarPhase.admin_noMint {source : Program} {keys P B σ api positions values cap k μ state rank label destination}
    (phase : ScalarPhase api positions values cap k μ state rank) (positive : 0 < rank)
    (avoid : StateAvoid keys state) (actual : Step P B σ state label destination) :
    StateAvoid keys destination := by
  cases phase with
  | chain before remaining split => cases remaining with
    | nil => simp only [List.length_nil] at positive; omega
    | cons value rest =>
      obtain ⟨rfl,rfl⟩ := let_step_unique rfl actual
      exact (AdministrativeStep.letIn (source := source) _ _ _ _ _).noMint avoid
  | argument before value remaining split =>
    obtain ⟨rfl,rfl⟩ := return_let_step_unique rfl actual
    exact (AdministrativeStep.returnValue (source := source) rfl).noMint avoid

theorem ScalarPhase.forward_invariant (P Q : Refinement.Program) (B : Builtins) (σ : PathEnv)
    [StandardModel.RowLookup B]
    {source rows effect api entry positions values key cap cap' value target k l μ ν state rank label destination}
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped (Check.predicateOverlay B rows))
    (effects : Q.EffectsOk (Check.predicateOverlay B rows))
    (core : (Check.predicateOverlay B rows).CoreAssumptions Q) (pathEnvironment : σ.Valid)
    (phase : ScalarPhase api positions values cap k μ state rank)
    (lookup : rows.lookup key = some (.scalar entry)) (count : values.length = api.inputs.length)
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (simple : SimpleValues values) (captures : Captures source rows cap cap')
    (related : Value source rows value target) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (typed : StateTyE Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν))
    (avoid : NoGeneratedKeys rows state) (actual : Step P B σ state label destination) :
    ForwardResult source rows Q (Check.predicateOverlay B rows) σ effect state
      (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν) label destination := by
  obtain ⟨Ψ,inputTyped⟩ := scalar_target_input wellFormed wellTyped core lookup typed
  have destinationAvoid : NoGeneratedKeys rows destination := by
    by_cases positive : 0 < rank
    · exact phase.admin_noMint (source := source) positive avoid actual
    · have held := phase.cont_store_avoid avoid
      cases phase with
      | argument => omega
      | chain before remaining split =>
        have empty : remaining = [] := List.length_eq_zero_iff.mp (by omega)
        subst remaining
        simp only [List.append_nil] at split
        subst before
        have reply := scalar_source_delta (Bsource := B) (inputs.close cap) (related.close captures) inputTyped
        have answer : B.delta api.name [] [] []
            (recordFields api.inputs.length positions (closeVals cap values) (.const .unit)) =
            some (.val (scalarResult entry cap' target)) := by
          rw [reply]
          rfl
        obtain ⟨rfl,rfl⟩ := pure_step_unique (scalarBody_view api positions values cap) (public_signature api) rfl answer actual
        exact ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,ValueAvoid.constant _ _⟩,held⟩
  obtain ⟨next,steps,nextRelated,progress⟩ :=
    phase.forward P Q B σ lookup count inputs simple captures related continuation store inputTyped actual
  exact ⟨next,steps,⟨nextRelated,destinationAvoid,
    typed.steps_preserved wellFormed wellTyped effects core pathEnvironment steps⟩,progress⟩

theorem ScalarPhase.backward_invariant (P Q : Refinement.Program) (B : Builtins) (σ : PathEnv)
    [StandardModel.RowLookup B]
    {source rows effect api entry positions values key cap cap' value target k l μ ν state rank label destination}
    (wellFormed : Q.WellFormed) (wellTyped : Q.WellTyped (Check.predicateOverlay B rows))
    (effects : Q.EffectsOk (Check.predicateOverlay B rows))
    (core : (Check.predicateOverlay B rows).CoreAssumptions Q) (pathEnvironment : σ.Valid)
    (phase : ScalarPhase api positions values cap k μ state rank)
    (lookup : rows.lookup key = some (.scalar entry))
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (simple : SimpleValues values) (captures : Captures source rows cap cap')
    (related : Value source rows value target) (continuation : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (typed : StateTyE Q (Check.predicateOverlay B rows) σ effect
      (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν))
    (avoid : NoGeneratedKeys rows state)
    (actual : Step Q (Check.predicateOverlay B rows) σ
      (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν) label destination) :
    BackwardResult source rows P Q B (Check.predicateOverlay B rows) σ effect state
      (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν) label destination := by
  obtain ⟨Ψ,inputTyped⟩ := scalar_target_input wellFormed wellTyped core lookup typed
  have reply : (Check.predicateOverlay B rows).delta key [] [] [] [closeVal cap' target] =
      some (.val (scalarResult entry cap' target)) := by
    rw [scalar_overlay_delta lookup]
    rfl
  obtain ⟨rfl,rfl⟩ := pure_step_unique rfl (scalar_overlay_signature lookup) rfl reply actual
  have finish := scalar_source_step P B σ (k := k) (μ := μ) inputs captures related inputTyped
  have beginning := phase.complete_steps (P := P) (B := B) (σ := σ) simple
  have held := phase.cont_store_avoid avoid
  exact ⟨_,SafeCheckErasure.steps_append beginning (.cons finish .nil),
    ⟨scalar_output_related continuation store,
      ⟨ClosureAvoid.mk.mpr ⟨CaptureAvoid.empty _,ValueAvoid.constant _ _⟩,held⟩,
      typed.step_preserved wellFormed wellTyped effects core pathEnvironment actual⟩,
    Steps.prepend_descends beginning (.one finish)⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
