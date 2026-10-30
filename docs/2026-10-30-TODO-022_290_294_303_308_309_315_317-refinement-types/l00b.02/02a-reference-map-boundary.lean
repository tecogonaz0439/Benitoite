import Benitoite.Release.Refinement.SubstTyping

/- 本番の文脈関係と、新しい参照の判断との関係を検査する。 -/
namespace Benitoite.Release.Refinement.ReferenceMapBoundary

def functionType : Ty := .fn [] [] (.base .unit) Eff.empty
def continuationType : Ty := .cont (.base .unit) (.base .unit) Eff.empty
def image : SubstEnv := ⟨Ty.tvar, [], [], fun _ => .var 0⟩

theorem transport_accepts_nonvalue_position :
    Transport image [some functionType] [] [none] [] ∧
    Term.References [some functionType] (.var 0) ∧
    ¬ Term.References [none] (.var 0) := by
  refine ⟨⟨?_, ?_⟩, ⟨functionType, rfl⟩, ?_⟩
  · intro i a hi hc
    cases i with
    | zero => simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
              subst a; cases hc
    | succ i => simp at hi
  · intro p hp
    simp [Ctx.facts, Ty.assume, functionType] at hp
  · rintro ⟨a, h⟩
    cases h

theorem shiftMap_can_hide_a_referenced_position :
    ShiftMap 0 0 [some continuationType] [none] ∧
    Term.References [some continuationType] (.var 0) ∧
    ¬ Term.References [none] (.var 0) := by
  refine ⟨⟨rfl, ?_⟩, ⟨continuationType, rfl⟩, ?_⟩
  · intro i a hi ho
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
      subst a
      exact False.elim (ho _ _ _ rfl)
    | succ i => simp at hi
  · rintro ⟨a, h⟩
    cases h

theorem hideConts_erases_continuation :
    hideConts [some continuationType] = [none] := rfl

theorem no_transport_reference_preservation :
    ¬ (∀ {Γ Δ : Ctx} {θ : SubstEnv}, Transport θ Γ [] Δ [] →
      ∀ {t : Term}, t.References Γ → (termBind θ.values t).References Δ) := by
  intro h
  obtain ⟨ht, hs, hn⟩ := transport_accepts_nonvalue_position
  exact hn (h ht hs)

theorem no_shiftMap_reference_preservation :
    ¬ (∀ {Γ Δ : Ctx}, ShiftMap 0 0 Γ Δ →
      ∀ {t : Term}, t.References Γ → t.References Δ) := by
  intro h
  obtain ⟨hm, hs, hn⟩ := shiftMap_can_hide_a_referenced_position
  exact hn (h hm hs)

#print axioms transport_accepts_nonvalue_position
#print axioms shiftMap_can_hide_a_referenced_position
#print axioms hideConts_erases_continuation
#print axioms no_transport_reference_preservation
#print axioms no_shiftMap_reference_preservation
end Benitoite.Release.Refinement.ReferenceMapBoundary
