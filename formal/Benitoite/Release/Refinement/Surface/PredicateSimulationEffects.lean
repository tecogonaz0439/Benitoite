import Benitoite.Release.Refinement.Surface.CheckPreparation
import Benitoite.Release.Refinement.Surface.PredicateSimulationTraces

/-! # 新鮮な純粋行の追加による事象の効果の保持 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateProjection
noncomputable section

/-- 未登録の名前へ純粋な判定行を加えても、各事象に必要な効果は変わらない。 -/
theorem overlay_coverage (B : Builtins) (rows : Table.Rows)
    (fresh : ∀ key row, (key, row) ∈ rows → B.sig key = none)
    (Γ : Ctx) (Φ : List Pred) (ε : Eff) (event : Event) :
    Event.Covered B Γ Φ ε event ↔
      Event.Covered (Check.predicateOverlay B rows) Γ Φ ε event := by
  cases event with
  | io name args outcome observation =>
    cases selected : rows.lookup name with
    | none => simp only [Event.Covered,Check.predicateOverlay,selected]
    | some row =>
      have absent := fresh name row (ScopeSignatures.lookup_mem selected)
      have pure : row.signature.opEff = none := by cases row <;> rfl
      simp [Event.Covered,Check.predicateOverlay,selected,absent,pure]
  | release => rfl
  | pathBases => rfl

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
