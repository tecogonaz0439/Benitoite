import Benitoite.Release.Refinement.Surface.PredicateSimulationObservations
import Benitoite.Release.Refinement.Surface.PredicateSimulationRuntime

/-! # 対応する実行状態の終端観測 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section
open PredicateResponse

private theorem scalar_terminal {api positions values cap k μ state rank}
    (phase : ScalarPhase api positions values cap k μ state rank) : SafeCheckErasure.terminal state = none := by
  cases phase with
  | chain before remaining split => cases k <;> cases remaining <;> rfl
  | argument => rfl

private theorem closed_terminal_equal {source rows q r μ ν} (closure : ClosedCode source rows q r) :
    terminal source rows (.run q [] μ) = terminal source rows (.run r [] ν) := by
  cases closure with
  | mk caps code =>
    cases code with
    | ret value => exact congrArg (fun v => some (TerminalObservation.value v)) (value.close caps).observed
    | @scalar api entry key positions values value target lookup count inputs simple related =>
      cases values <;> rfl
    | @projected api key projection positions computations symbolic root steps types target
        lookup route arguments inputs count typeCount simple related =>
      cases computations <;> rfl
    | _ => rfl

private theorem returned_no_step {P B σ q μ value label destination} (view : q.view = .ret value) :
    ¬ Step P B σ (.run q [] μ) label destination := by
  intro step
  cases step <;> try simp_all
  all_goals subst_vars
  all_goals try simp_all [Closure.view]

private theorem terminal_no_step {source rows P B σ s observation label destination}
    (observed : terminal source rows s = some observation) : ¬ Step P B σ s label destination := by
  change (SafeCheckErasure.terminal s).map _ = some observation at observed
  obtain ⟨raw,observed,_⟩ := Option.map_eq_some_iff.mp observed
  cases s with
  | run q k μ =>
    cases k with
    | nil =>
      simp only [SafeCheckErasure.terminal] at observed
      split at observed
      · next value view => exact returned_no_step view
      · cases observed
    | cons => cases observed
  | matchRun => cases observed
  | error payload k μ => cases k with
    | nil => intro step; cases step
    | cons => cases observed
  | exit code payload k μ => cases k with
    | nil => intro step; cases step
    | cons => cases observed

private theorem terminal_pair_of_equal {source rows s t P B σ}
    (same : terminal source rows s = terminal source rows t) :
    (∀ observation, terminal source rows s = some observation → terminal source rows t = some observation) ∧
      (∀ observation, terminal source rows t = some observation →
        ∃ s', Steps P B σ s [] s' ∧ terminal source rows s' = some observation) :=
  ⟨fun _ observed => same.symm.trans observed,fun _ observed => ⟨s,.nil,same.trans observed⟩⟩

private theorem StateRel.terminal_pair {source rows s t P B σ}
    (related : StateRel source rows s t) (environment : GetterEnvironment source P) :
    (∀ observation, terminal source rows s = some observation → terminal source rows t = some observation) ∧
      (∀ observation, terminal source rows t = some observation →
        ∃ s', Steps P B σ s [] s' ∧ terminal source rows s' = some observation) := by
  induction related with
  | run closure stack store =>
    apply terminal_pair_of_equal
    cases stack with
    | nil => exact closed_terminal_equal closure
    | cons => rfl
  | matchRun => exact terminal_pair_of_equal rfl
  | error stack store => apply terminal_pair_of_equal; cases stack <;> rfl
  | exit stack store => apply terminal_pair_of_equal; cases stack <;> rfl
  | scalarPhase lookup count inputs simple caps value stack store phase =>
    apply terminal_pair_of_equal
    simp only [terminal,scalar_terminal phase,Option.map_none]
    cases stack <;> rfl
  | projectedApplication lookup view inputs count read stack store =>
    apply terminal_pair_of_equal
    cases stack with
    | nil =>
      simp only [terminal,SafeCheckErasure.terminal,view,Option.map_none]
      rfl
    | cons => rfl
  | administrative path related ih =>
    constructor
    · intro observation observed
      cases path with
      | nil => exact ih.1 _ observed
      | cons step rest => exact False.elim (terminal_no_step (P := P) (B := B) (σ := σ) observed (step.realize environment))
    · intro observation observed
      obtain ⟨last,steps,result⟩ := ih.2 _ observed
      exact ⟨last,by simpa only [List.nil_append] using
        SafeCheckErasure.steps_append (path.realize environment) steps,result⟩

/-- 原実行が終端なら、対応先も同じ観測を持つ。 -/
theorem StateRel.terminal_forward {source rows s t P Q D σ observation}
    (related : StateRel source rows s t) (environment : GetterEnvironment source P)
    (observed : terminal source rows s = some observation) :
    ∃ t', Steps Q D σ t [] t' ∧ terminal source rows t' = some observation :=
  ⟨t,.nil,(related.terminal_pair (B := D) (σ := σ) environment).1 _ observed⟩

/-- 対応先の終端へは、原実行の事象を出さない有限の管理経路を経て到達する。 -/
theorem StateRel.terminal_backward {source rows s t P B σ observation}
    (related : StateRel source rows s t) (environment : GetterEnvironment source P)
    (observed : terminal source rows t = some observation) :
    ∃ s', Steps P B σ s [] s' ∧ terminal source rows s' = some observation :=
  (related.terminal_pair (B := B) (σ := σ) environment).2 _ observed

/-- 公開判定を本体に持つ関数を返しても、対応する閉包の正常観測を保つ。 -/
example (p : Program) (op : OpPrim) :
    let rows : PredicateProjection.Table.Rows :=
      [("%Predicate.0",.scalar (.floating .binary64 .finite))]
    let source := Block.last (.lam ["x"] [.base .float] (.base .unit) Eff.empty
      (.lastDiscard (floatingSource .binary64 .finite 0)))
    terminal p rows (.run (.pure (desugarBlock op .tail source)) [] Store.empty) =
      terminal p rows (.run (.pure (desugarBlock op .tail
        (PredicateProjectionCalls.resolveBlock rows p source))) [] Store.empty) := by
  dsimp only
  exact closed_terminal_equal (.mk (.mk .nil)
    (floating_lambda_code _ p op .binary64 .finite "%Predicate.0" rfl))

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
