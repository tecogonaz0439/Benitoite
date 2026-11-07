import Benitoite.Release.Refinement.Surface.PredicateProjectionCalls

/-! # 公開の判定と特殊化した内部行の応答の一致 -/
namespace Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
open PredicateRows PredicateResponse PredicateProjection MatchFacts
noncomputable section

/-- 条件を固定した公開行と内部行は、同じ入力で同じδを持つ。 -/
structure PublicDeltaAgreement : Prop where
  path : ∀ pattern path, parseAtPattern .path (.const (.string pattern)) = some (.path path) → ∀ value,
    (Entry.path path).delta [] [] [] [.const (.string value)] =
      API.path.delta API.path.name [] [] [] [.const (.string pattern), .const (.string value)]
  host : ∀ pattern host, parseAtPattern .host (.const (.string pattern)) = some (.host host) → ∀ value,
    (Entry.host host).delta [] [] [] [.const (.string value)] =
      API.host.delta API.host.name [] [] [] [.const (.string pattern), .const (.string value)]
  characters : ∀ lo hi value, (Entry.characters lo hi).delta [] [] [] [.const (.string value)] =
    API.characters.delta API.characters.name [] [] [] [.const (.string value), .const (.character lo), .const (.character hi)]
  floating : ∀ width test values, (Entry.floating width test).delta [] [] [] values =
    (API.floating width test).delta (API.floating width test).name [] [] [] values
  projected : ∀ (projection : Projection) types root leaf,
    types.length = projection.ntys → readPath root projection.route = some leaf →
    projection.delta types [] [] [root] = projection.entry.delta [] [] [] [leaf]

theorem public_deltas : PublicDeltaAgreement := by
  refine ⟨fun _ _ h => PredicateCalls.path_delta h, fun _ _ h => PredicateCalls.host_delta h,
    PredicateCalls.characters_delta, PredicateCalls.floating_delta, ?_⟩
  intro projection types root leaf count read
  simp [Projection.delta, Projection.run, count, read, Entry.delta]

end
end Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
