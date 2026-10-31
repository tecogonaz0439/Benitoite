import Benitoite.Release.Refinement.MatchPaths
/-! guarded の結果の注釈は hideConts の文脈にあり、GuardBodyTy.mk は本体の文脈の注釈を読む。
    一般の E_MatchGuard で K_Guard を組むときに要る橋渡しを確かめる。 -/
namespace Benitoite.Release.Refinement
noncomputable section
theorem images_unhide (Γ : Ctx) : Term.ImagesSorted (hideConts Γ) Γ (fun i => some (.var i)) := by
  intro i a sort hi ht
  simp only [hideConts,List.getElem?_map] at hi
  cases hg : Γ[i]? with
  | none => simp [hg] at hi
  | some x =>
    cases x with
    | none => simp [hg] at hi
    | some t =>
      simp only [hg,Option.map_some] at hi
      split at hi
      · cases hi
      · cases Option.some.inj (Option.some.inj hi)
        exact ⟨.var i,rfl,⟨a,hg,ht.ordinary⟩,a,hg,ht⟩
end
end Benitoite.Release.Refinement
