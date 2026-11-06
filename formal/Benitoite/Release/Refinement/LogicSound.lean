import Benitoite.Release.Refinement.Logic
import Benitoite.Release.Refinement.FieldAtomSound

namespace Benitoite.Release.Refinement

theorem Entails.sound {Φ : List Pred} {p : Pred} (h : Entails Φ p) :
    ∀ η : ObservationEnvModel, (∀ q ∈ Φ, q.interpret η = true) → p.interpret η = true := by
  induction h with
  | hyp h => exact fun _ hm => hm _ h
  | truth => exact fun _ _ => rfl
  | false_elim _ ih => intro η hm; have := ih η hm; simp [Pred.interpret, Pred.atomValue] at this
  | and_intro _ _ ih₁ ih₂ => intro η hm; simp [Pred.interpret, ih₁ η hm, ih₂ η hm]
  | and_left _ ih => intro η hm; have ht := ih η hm; simp only [Pred.interpret, Bool.and_eq_true] at ht; exact ht.1
  | and_right _ ih => intro η hm; have ht := ih η hm; simp only [Pred.interpret, Bool.and_eq_true] at ht; exact ht.2
  | or_left _ ih => intro η hm; simp [Pred.interpret, ih η hm]
  | or_right _ ih => intro η hm; simp [Pred.interpret, ih η hm]
  | @or_elim Φ p q r _ _ _ ih₀ ih₁ ih₂ =>
    intro η hm
    have hm' (s : Pred) (hs : s.interpret η = true) : ∀ t ∈ s::Φ, t.interpret η = true := by
      intro t ht; rcases List.mem_cons.mp ht with rfl | ht
      · exact hs
      · exact hm _ ht
    have ht := ih₀ η hm
    simp only [Pred.interpret, Bool.or_eq_true] at ht
    rcases ht with hp | hq
    · exact ih₁ η (hm' p hp)
    · exact ih₂ η (hm' q hq)
  | @not_intro Φ p _ ih =>
    intro η hm
    cases hp : p.interpret η with
    | false => simp [Pred.interpret, hp]
    | true =>
      have hf := ih η (fun q hq => by
        rcases List.mem_cons.mp hq with rfl | hq
        · exact hp
        · exact hm _ hq)
      simp [Pred.interpret, Pred.atomValue] at hf
  | not_elim _ _ ih₁ ih₂ =>
    intro η hm
    have := ih₂ η hm
    simp [Pred.interpret, ih₁ η hm] at this
  | not_not_elim _ ih => intro η hm; simpa [Pred.interpret] using ih η hm
  | eq_refl => intro η _; simp [Pred.interpret, Pred.atomValue]
  | le_refl => intro η _; simp [Pred.interpret, Pred.atomValue]
  | integer_eq h => intro η _; simp [Pred.interpret, Pred.atomValue, integerAs, observeAs, Term.interpret, Observation.sort, h]
  | integer_le h => intro η _; simpa [Pred.interpret, Pred.atomValue, integerAs, observeAs, Term.interpret, Observation.sort] using h
  | integer_lt h => intro η _; simpa [Pred.interpret, Pred.atomValue, integerAs, observeAs, Term.interpret, Observation.sort] using h
  | closed hw hs he =>
    intro η _
    rw [Pred.interpret_closed hw η]
    exact Pred.evalClosed_sound hw hs he
  | measured ha hb oa ob =>
    intro η _
    have hai := Term.observe_sound ((Term.observe_closed ha η).trans oa)
    have hbi := Term.observe_sound ((Term.observe_closed hb η).trans ob)
    simp [Pred.interpret, Pred.atomValue, integerAs, observeAs, Term.interpret, hai, hbi]
  | fieldAtom atom _ _ ih₁ ih₂ =>
    intro η hm
    exact (atom.sound η (ih₁ η hm)).symm.trans (ih₂ η hm)
  | checkedAt ν hc _ ih =>
    intro η hm
    exact CertificateKernel.implication_sound_at hc ν η (ih η hm)

end Benitoite.Release.Refinement
