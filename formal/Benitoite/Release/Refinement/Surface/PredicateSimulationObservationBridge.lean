import Benitoite.Release.Refinement.Surface.PredicateSimulationInvariant
import Benitoite.Release.Refinement.Surface.PredicateSimulationTraces
import Benitoite.Release.Refinement.Surface.PredicateSimulationTerminal

/-! # 実状態の模倣からの有限観測と効果の同値 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 管理用の有限経路を終端に補い、全事象列と正常値・失敗・終了の同じ観測を得る。 -/
theorem InvariantRel.observations {source rows P B Q D σ effect leftRank rightRank first second}
    (forward : Trace.Forward P B Q D σ (InvariantRel source rows Q D σ effect) leftRank)
    (backward : Trace.Forward Q D P B σ (fun t s => InvariantRel source rows Q D σ effect s t) rightRank)
    (environment : GetterEnvironment source P)
    (related : InvariantRel source rows Q D σ effect first second)
    (events : List Event) (observation : TerminalObservation source rows) :
    (∃ last, Steps P B σ first events last ∧ terminal source rows last = some observation) ↔
      (∃ last, Steps Q D σ second events last ∧ terminal source rows last = some observation) := by
  apply Trace.observations forward backward ?_ ?_ related events observation
  · intro s t obs relation observed
    exact relation.1.terminal_forward environment observed
  · intro t s obs relation observed
    exact relation.1.terminal_backward environment observed

/-- 同じ有限観測に必要な事象の効果も、両表の被覆が同じなら保持する。 -/
theorem InvariantRel.effects {source rows P B Q D σ effect leftRank rightRank first second}
    (forward : Trace.Forward P B Q D σ (InvariantRel source rows Q D σ effect) leftRank)
    (backward : Trace.Forward Q D P B σ (fun t s => InvariantRel source rows Q D σ effect s t) rightRank)
    (environment : GetterEnvironment source P)
    (related : InvariantRel source rows Q D σ effect first second)
    (Γ : Ctx) (Φ : List Pred) (ε : Eff)
    (coverage : ∀ event, Event.Covered B Γ Φ ε event ↔ Event.Covered D Γ Φ ε event)
    (events : List Event) (observation : TerminalObservation source rows) :
    (∃ last, Steps P B σ first events last ∧ terminal source rows last = some observation ∧
      ∀ event ∈ events, Event.Covered B Γ Φ ε event) ↔
      (∃ last, Steps Q D σ second events last ∧ terminal source rows last = some observation ∧
        ∀ event ∈ events, Event.Covered D Γ Φ ε event) := by
  apply Trace.effects forward backward ?_ ?_ related Γ Φ ε coverage events observation
  · intro s t obs relation observed
    exact relation.1.terminal_forward environment observed
  · intro t s obs relation observed
    exact relation.1.terminal_backward environment observed

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
