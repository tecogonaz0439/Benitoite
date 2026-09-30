import Benitoite.Release.Typing

/-!
# エフェクトの集合と型の包含の基本の補題
-/

namespace Benitoite.Release

/-! ## エフェクトの集合 -/

namespace Eff

theorem Sub.refl (ε : Eff) : Sub ε ε := fun _ h => h

theorem Sub.trans {ε₁ ε₂ ε₃ : Eff} (h₁ : Sub ε₁ ε₂) (h₂ : Sub ε₂ ε₃) : Sub ε₁ ε₃ :=
  fun a h => h₂ a (h₁ a h)

theorem empty_sub (ε : Eff) : Sub empty ε := fun _ h => by simp [empty] at h

theorem sub_empty {ε : Eff} (h : Sub ε empty) : ε = empty := by
  funext a
  cases hε : ε a
  · rfl
  · have := h a hε; simp [empty] at this

theorem substRho_mono (es : List Eff) {ε ε' : Eff} (h : Sub ε ε') :
    Sub (substRho es ε) (substRho es ε') := by
  intro a ha
  simp only [substRho] at ha ⊢
  cases a with
  | name l =>
    simp only [Bool.or_eq_true, List.any_eq_true, Bool.and_eq_true] at ha ⊢
    rcases ha with ha | ⟨i, hi, h1, h2⟩
    · exact Or.inl (h _ ha)
    · exact Or.inr ⟨i, hi, h _ h1, h2⟩
  | rho j =>
    simp only [Bool.or_eq_true, List.any_eq_true, Bool.and_eq_true] at ha ⊢
    rcases ha with ha | ⟨i, hi, h1, h2⟩
    · left
      split at ha
      · simp at ha
      · rename_i hj; simp only [hj, ite_false]; exact h _ ha
    · exact Or.inr ⟨i, hi, h _ h1, h2⟩

theorem substRho_empty (es : List Eff) : substRho es empty = empty := by
  funext a
  cases a <;> simp [substRho, empty]

/-- エフェクトの名前は置き換えで消えない。 -/
theorem substRho_name {es : List Eff} {ε : Eff} {l : EffName} (h : ε (.name l) = true) :
    substRho es ε (.name l) = true := by
  simp [substRho, h]

end Eff

/-! ## 型の包含 -/

namespace Ty.Le

theorem refl (a : Ty) : Ty.Le a a := Or.inl rfl

theorem trans {a b c : Ty} (h₁ : Ty.Le a b) (h₂ : Ty.Le b c) : Ty.Le a c := by
  rcases h₁ with rfl | ⟨ps, r, ε, ε', rfl, rfl, hs⟩
  · exact h₂
  · rcases h₂ with rfl | ⟨ps', r', ε₁, ε₂, h, rfl, hs'⟩
    · exact Or.inr ⟨ps, r, ε, ε', rfl, rfl, hs⟩
    · cases h
      exact Or.inr ⟨ps, r, ε, ε₂, rfl, rfl, hs.trans hs'⟩

/-- 関数の型から広げた型は、引数と結果が同じで、エフェクトだけが広い関数の型である。 -/
theorem fn_left {ps r ε t} (h : Ty.Le (.fn ps r ε) t) :
    ∃ ε', t = .fn ps r ε' ∧ Eff.Sub ε ε' := by
  rcases h with rfl | ⟨ps', r', ε₁, ε₂, h, rfl, hs⟩
  · exact ⟨ε, rfl, Eff.Sub.refl ε⟩
  · cases h; exact ⟨ε₂, rfl, hs⟩

/-- 関数の型に広げた元の型は、引数と結果が同じで、エフェクトだけが狭い関数の型である。 -/
theorem fn_right {a ps r ε} (h : Ty.Le a (.fn ps r ε)) :
    ∃ ε', a = .fn ps r ε' ∧ Eff.Sub ε' ε := by
  rcases h with rfl | ⟨ps', r', ε₁, ε₂, rfl, h, hs⟩
  · exact ⟨ε, rfl, Eff.Sub.refl ε⟩
  · cases h; exact ⟨ε₁, rfl, hs⟩

/-- 関数の型でない型への包含は、等しさである。 -/
theorem eq_of_not_fn {a t : Ty} (h : Ty.Le a t) (ht : ∀ ps r ε, t ≠ .fn ps r ε) : a = t := by
  rcases h with rfl | ⟨ps, r, ε, ε', rfl, rfl, _⟩
  · rfl
  · exact absurd rfl (ht ps r ε')

/-- 関数の型でない型からの包含は、等しさである。 -/
theorem eq_of_not_fn_left {a t : Ty} (h : Ty.Le a t) (ha : ∀ ps r ε, a ≠ .fn ps r ε) : a = t := by
  rcases h with rfl | ⟨ps, r, ε, ε', rfl, rfl, _⟩
  · rfl
  · exact absurd rfl (ha ps r ε)

theorem substAt {a b : Ty} (c : Nat) (ts : List Ty) (es : List Eff) (h : Ty.Le a b) :
    Ty.Le (a.substAt c ts es) (b.substAt c ts es) := by
  rcases h with rfl | ⟨ps, r, ε, ε', rfl, rfl, hs⟩
  · exact refl _
  · simp only [Ty.substAt]
    exact Or.inr ⟨_, _, _, _, rfl, rfl, Eff.substRho_mono es hs⟩

theorem subst {a b : Ty} (ts : List Ty) (es : List Eff) (h : Ty.Le a b) :
    Ty.Le (a.subst ts es) (b.subst ts es) := substAt 0 ts es h

theorem shift {a b : Ty} (k c : Nat) (h : Ty.Le a b) : Ty.Le (a.shift k c) (b.shift k c) := by
  rcases h with rfl | ⟨ps, r, ε, ε', rfl, rfl, hs⟩
  · exact refl _
  · simp only [Ty.shift]
    exact Or.inr ⟨_, _, _, _, rfl, rfl, hs⟩

end Ty.Le

end Benitoite.Release
