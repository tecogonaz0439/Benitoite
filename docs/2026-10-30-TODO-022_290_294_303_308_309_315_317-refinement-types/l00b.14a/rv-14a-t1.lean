import Benitoite.Release.Refinement.DependentBeta
namespace Benitoite.Release.Refinement
noncomputable section

/-- R が some のときも含め、先頭の mark を逆転する。 -/
theorem ContTy.mark_inv {P B σ Ψ R ε k0 a b Eb Re}
    (h : ContTy P B σ Ψ R ε k0 a b Eb Re) :
    ∀ k, k0 = .mark :: k → ∃ r R', R = some r ∧ Ty.LeQ [] [] a r ∧ ContTy P B σ Ψ R' ε k r b Eb Re := by
  induction h with
  | K_Mark h ha => 
    intro k he; cases he
    exact ⟨_,_,rfl,.refl,h⟩
  | K_Sub _ hl ih =>
    intro k he
    obtain ⟨r,R',hR,hle,hk⟩ := ih k he
    exact ⟨r,R',hR,.trans hl hle,hk⟩
  | _ => intro k he; cases he

/-- 一般の R の下の markPush。 -/
theorem ContTy.markPush_any {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (ha : Ty.Annotation P [] [] a) :
    ∃ _ : True, ContTy P B σ Ψ (some a) ε (Refinement.markPush k) a b Eb Re := by
  refine ⟨trivial,?_⟩
  cases k with
  | nil => exact .K_Mark h ha
  | cons f k =>
    cases f with
    | mark =>
      obtain ⟨r,R',_,hle,hk⟩ := h.mark_inv k rfl
      exact .K_Mark (.K_Sub hk hle) ha
    | _ => exact .K_Mark h ha
end
end Benitoite.Release.Refinement
