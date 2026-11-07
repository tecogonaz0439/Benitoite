import Benitoite.Release.Refinement.Surface.PredicateSimulationSteps
import Benitoite.Release.Refinement.Surface.PredicateSimulationPublicProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationTraces
import Benitoite.Release.Refinement.ApplicationInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationAdministrativeRank

/-! # 公開scalar呼出しと登録行の実行の対応

実際の標準表を読む。定数形を得る型付けの証拠は対応先の入力だけに要求する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

def scalarFinish (api : API) (positions : List Nat) (values : List Val) (cap : Capture) (k : Cont) (μ : Store) : State :=
  .run (.mk (cap.extendMany (closeVals cap values)) (scalarBody api positions values)) k μ

/-- 任意の管理用の段階から、公開appまで有限の無観測実行で到達する。 -/
theorem ScalarPhase.complete_steps {P B σ api positions values cap k μ state rank}
    (phase : ScalarPhase api positions values cap k μ state rank) (simple : SimpleValues values) :
    Steps P B σ state [] (scalarFinish api positions values cap k μ) := by
  induction rank using Nat.strongRecOn generalizing state with
  | ind rank smaller =>
    by_cases positive : 0 < rank
    · have progresses : ∃ next, Step P B σ state none next := by
        cases phase with
        | chain before remaining split =>
          cases remaining with
          | nil => cases positive
          | cons value remaining => exact ⟨_,.E_Let rfl⟩
        | argument before value remaining split => exact ⟨_,.E_Return rfl⟩
      obtain ⟨next,step⟩ := progresses
      obtain ⟨_,nextRank,nextPhase,less⟩ := phase.forward_admin simple positive step
      exact .cons step (smaller nextRank less nextPhase)
    · cases phase with
      | chain before remaining split =>
        have empty : remaining = [] := List.length_eq_zero_iff.mp (by omega)
        subst remaining
        simp only [List.append_nil] at split
        subst before
        exact .nil
      | argument before value remaining split => omega

/-- 対応先の単一scalar入力から、元の公開引数列の型付けを対応先の環境で構成する。 -/
theorem ScalarInputs.arguments {source rows P B Ψ api entry declared value target}
    (inputs : ScalarInputs api entry declared value) (related : Value source rows value target)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] target (.base entry.input)) :
    HasTypeVsQ P B Ψ Qempty [] [] [] declared api.inputs := by
  have same : value = target := by
    obtain ⟨constant,rfl,_,_⟩ := typed.canonical_scalar rfl
    exact related.constant_right
  subst value
  cases inputs with
  | path parsed => exact .cons (.V_Const trivial) (.cons typed .nil)
  | host parsed => exact .cons (.V_Const trivial) (.cons typed .nil)
  | characters lo hi value => exact .cons typed (.cons (.V_Const trivial) (.cons (.V_Const trivial) .nil))
  | floating width test value => cases width <;> exact .cons typed .nil

/-- 条件を固定した公開APIと内部行のδの一致を、実際の同じ入力へ適用する。 -/
theorem ScalarInputs.public_delta {source rows P B Ψ api entry declared value target}
    (inputs : ScalarInputs api entry declared value) (related : Value source rows value target)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] target (.base entry.input)) :
    entry.delta [] [] [] [target] = api.delta api.name [] [] [] declared := by
  have same : value = target := by
    obtain ⟨constant,rfl,_,_⟩ := typed.canonical_scalar rfl
    exact related.constant_right
  subst value
  cases inputs with
  | path parsed =>
    obtain ⟨constant,rfl,_,tag⟩ := typed.canonical_scalar rfl
    cases constant <;> cases tag
    exact PredicateProgramSemantics.public_deltas.path _ _ parsed _
  | host parsed =>
    obtain ⟨constant,rfl,_,tag⟩ := typed.canonical_scalar rfl
    cases constant <;> cases tag
    exact PredicateProgramSemantics.public_deltas.host _ _ parsed _
  | characters lo hi value =>
    obtain ⟨constant,rfl,_,tag⟩ := typed.canonical_scalar rfl
    cases constant <;> cases tag
    exact PredicateProgramSemantics.public_deltas.characters _ _ _
  | floating width test value => exact PredicateProgramSemantics.public_deltas.floating width test _

/-- 公開名の標準表の実δを、型付きの対応先が読む同じ内部行のδへ結ぶ。 -/
theorem scalar_source_delta {source rows P Bsource Btarget Ψ api entry declared value target}
    [StandardModel.RowLookup Bsource]
    (inputs : ScalarInputs api entry declared value) (related : Value source rows value target)
    (typed : HasTypeVQ P Btarget Ψ Qempty [] [] [] target (.base entry.input)) :
    Bsource.delta api.name [] [] [] declared = entry.delta [] [] [] [target] := by
  rw [public_delta_values api (inputs.arguments related typed)]
  exact (inputs.public_delta related typed).symm

def scalarResult (entry : Entry) (cap : Capture) (value : Val) : Val :=
  .const (.boolean (entry.run [closeVal cap value]))

theorem scalar_overlay_signature {B rows entry key} (lookup : rows.lookup key = some (.scalar entry)) :
    (Check.predicateOverlay B rows).sig key = some entry.signature := by
  simp only [Check.predicateOverlay,lookup,PredicateProjection.Row.signature]

theorem scalar_overlay_delta {B rows entry key} (lookup : rows.lookup key = some (.scalar entry)) (ts es rs values) :
    (Check.predicateOverlay B rows).delta key ts es rs values = entry.delta ts es rs values := by
  simp only [Check.predicateOverlay,lookup,PredicateProjection.Row.delta]

/-- 準備後の実状態の型付けから、内部行が読む同じ単一値の型付けを取り出す。 -/
theorem scalar_target_input {P B σ Eb rows entry key cap value k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped (Check.predicateOverlay B rows))
    (hB : (Check.predicateOverlay B rows).CoreAssumptions P)
    (lookup : rows.lookup key = some (.scalar entry))
    (state : StateTyE P (Check.predicateOverlay B rows) σ Eb (.run (.mk cap (.app (.prim key [] [] []) [value])) k μ)) :
    ∃ Ψ, HasTypeVQ P (Check.predicateOverlay B rows) Ψ Qempty [] [] [] (closeVal cap value) (.base entry.input) := by
  obtain ⟨Ψ,R,a,e,signature,r,ef,store,closure,found,ranges,admissible,instantiated,arguments,le,covers⟩ :=
    state.primitive_contract_inputs (b := key) (ts := []) (es := []) (rs := []) (ws := [closeVal cap value]) hP hPB hB (by rfl)
  have same : signature = entry.signature := Option.some.inj (found.symm.trans (scalar_overlay_signature lookup))
  subst signature
  rw [PredicateRows.instantiated] at arguments
  cases arguments with
  | param annotation valueTyped rest => exact ⟨Ψ,valueTyped⟩

theorem scalar_source_step (P : Refinement.Program) (B : Builtins) (σ : PathEnv) [StandardModel.RowLookup B]
    {source rows Q Ψ api entry positions values value target cap cap' k μ}
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (hc : Captures source rows cap cap') (hv : Value source rows value target)
    (typed : HasTypeVQ Q (Check.predicateOverlay B rows) Ψ Qempty [] [] [] (closeVal cap' target) (.base entry.input)) :
    Step P B σ (scalarFinish api positions values cap k μ) none
      (.run (.pure (.ret (scalarResult entry cap' target))) k μ) := by
  have reply := scalar_source_delta (Bsource := B) (inputs.close cap) (hv.close hc) typed
  refine .E_Prim (b := api.name) (ts := []) (es := []) (rs := []) (s := api.signature)
    (scalarBody_view api positions values cap) (public_signature api) rfl ?_
  change B.delta api.name [] [] [] (recordFields api.inputs.length positions (closeVals cap values) (.const .unit)) = _
  rw [reply]
  simp [Entry.delta,scalarResult]

theorem scalar_target_step (Q : Refinement.Program) (B : Builtins) (σ : PathEnv)
    {rows entry key cap target l ν} (lookup : rows.lookup key = some (.scalar entry)) :
    Step Q (Check.predicateOverlay B rows) σ (.run (.mk cap (.app (.prim key [] [] []) [target])) l ν) none
      (.run (.pure (.ret (scalarResult entry cap target))) l ν) := by
  refine .E_Prim (b := key) (ts := []) (es := []) (rs := []) (s := entry.signature)
    rfl (scalar_overlay_signature lookup) rfl ?_
  change (Check.predicateOverlay B rows).delta key [] [] [] [closeVal cap target] = _
  rw [scalar_overlay_delta lookup]
  simp [Entry.delta,scalarResult]

theorem scalar_output_related {source rows entry cap target k l μ ν}
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν) :
    StateRel source rows (.run (.pure (.ret (scalarResult entry cap target))) k μ)
      (.run (.pure (.ret (scalarResult entry cap target))) l ν) :=
  .run (.mk (.mk .nil) (.ret (.constant _))) hk hμ

theorem Steps.prepend_descends {P B σ first middle last events}
    (steps : Steps P B σ first events middle) (tail : SafeCheckErasure.Descends P B σ last middle) :
    SafeCheckErasure.Descends P B σ last first := by
  induction steps with
  | nil => exact tail
  | cons step rest ih => exact .more step (ih tail)

/-- sourceの管理段階の全てで、実一段はtargetの有限実行又は順位を下げる省略に対応する。 -/
theorem ScalarPhase.forward (P Q : Refinement.Program) (B : Builtins) (σ : PathEnv) [StandardModel.RowLookup B]
    {source rows Ψ api entry positions values key cap cap' value target k l μ ν state rank label destination}
    (phase : ScalarPhase api positions values cap k μ state rank)
    (lookup : rows.lookup key = some (.scalar entry)) (count : values.length = api.inputs.length)
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (simple : SimpleValues values) (hc : Captures source rows cap cap') (hv : Value source rows value target)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (typed : HasTypeVQ Q (Check.predicateOverlay B rows) Ψ Qempty [] [] [] (closeVal cap' target) (.base entry.input))
    (step : Step P B σ state label destination) :
    ∃ next, Steps Q (Check.predicateOverlay B rows) σ (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν) label.toList next ∧
      StateRel source rows destination next ∧
      (SafeCheckErasure.Descends Q (Check.predicateOverlay B rows) σ next (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν) ∨
        (label = none ∧ next = .run (.mk cap' (.app (.prim key [] [] []) [target])) l ν ∧
          PredicateSimulation.administrativeRank source destination < PredicateSimulation.administrativeRank source state)) := by
  by_cases positive : 0 < rank
  · obtain ⟨rfl,nextRank,nextPhase,less⟩ := phase.forward_admin simple positive step
    refine ⟨_,.nil,nextPhase.related lookup count inputs simple hc hv hk hμ,Or.inr ⟨rfl,rfl,?_⟩⟩
    rw [nextPhase.administrativeRank,phase.administrativeRank]
    omega
  · cases phase with
    | argument before value remaining split => omega
    | chain before remaining split =>
      have empty : remaining = [] := List.length_eq_zero_iff.mp (by omega)
      subst remaining
      simp only [List.append_nil] at split
      subst before
      have reply := scalar_source_delta (Bsource := B) (inputs.close cap) (hv.close hc) typed
      have answer : B.delta api.name [] [] [] (recordFields api.inputs.length positions (closeVals cap values) (.const .unit)) =
          some (.val (scalarResult entry cap' target)) := by rw [reply]; simp [Entry.delta,scalarResult]
      obtain ⟨rfl,rfl⟩ := pure_step_unique (scalarBody_view api positions values cap) (public_signature api) rfl answer step
      have targetStep := scalar_target_step Q B σ (cap := cap') (target := target) (l := l) (ν := ν) lookup
      exact ⟨_,.cons targetStep .nil,scalar_output_related hk hμ,Or.inl (.one targetStep)⟩

/-- targetの一段は、任意のsource管理段階から少なくとも一段を持つ有限実行へ反射する。 -/
theorem ScalarPhase.backward (P Q : Refinement.Program) (B : Builtins) (σ : PathEnv) [StandardModel.RowLookup B]
    {source rows Ψ api entry positions values key cap cap' value target k l μ ν state rank label destination}
    (phase : ScalarPhase api positions values cap k μ state rank)
    (lookup : rows.lookup key = some (.scalar entry))
    (inputs : ScalarInputs api entry (recordFields api.inputs.length positions values (.const .unit)) value)
    (simple : SimpleValues values) (hc : Captures source rows cap cap') (hv : Value source rows value target)
    (hk : ContRel source rows k l) (hμ : StoreRel source rows μ ν)
    (typed : HasTypeVQ Q (Check.predicateOverlay B rows) Ψ Qempty [] [] [] (closeVal cap' target) (.base entry.input))
    (step : Step Q (Check.predicateOverlay B rows) σ (.run (.mk cap' (.app (.prim key [] [] []) [target])) l ν) label destination) :
    ∃ next, Steps P B σ state label.toList next ∧ StateRel source rows next destination ∧ SafeCheckErasure.Descends P B σ next state := by
  have reply : (Check.predicateOverlay B rows).delta key [] [] [] [closeVal cap' target] = some (.val (scalarResult entry cap' target)) := by
    rw [scalar_overlay_delta lookup]
    simp [Entry.delta,scalarResult]
  obtain ⟨rfl,rfl⟩ := pure_step_unique rfl (scalar_overlay_signature lookup) rfl reply step
  have finish := scalar_source_step P B σ (k := k) (μ := μ) inputs hc hv typed
  have controlSteps := phase.complete_steps (P := P) (B := B) (σ := σ) simple
  exact ⟨_,SafeCheckErasure.steps_append controlSteps (.cons finish .nil),scalar_output_related hk hμ,
    Steps.prepend_descends controlSteps (.one finish)⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
