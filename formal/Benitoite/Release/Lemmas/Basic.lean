import Benitoite.Release.TypeRegularity
import Benitoite.Release.TypeSubstLemmas

/-!
# エフェクトの集合と型の包含の基本の補題

契約名を持つ関数型について、包含・置換・変数移動で同じ名前の並びを保持する。
型付けの基礎となる包含の性質を示す（設計書 01-12「型付け規則」）。
-/

namespace Benitoite.Release

variable {Q : NoFailCtx}


/-! ## エフェクトの集合 -/

namespace Eff

theorem Sub.refl (ε : Eff) : Sub ε ε := ⟨fun _ h => h, fun _ h => h⟩

theorem Sub.trans {ε₁ ε₂ ε₃ : Eff} (h₁ : Sub ε₁ ε₂) (h₂ : Sub ε₂ ε₃) : Sub ε₁ ε₃ :=
  ⟨fun a h => h₂.1 a (h₁.1 a h), fun t h => h₂.2 t (h₁.2 t h)⟩

theorem empty_sub (ε : Eff) : Sub empty ε :=
  ⟨fun a h => (mem_empty a).mp h |>.elim, fun t h => (memFail_empty t).mp h |>.elim⟩

theorem sub_empty {ε : Eff} (h : Sub ε empty) : ε = empty := by
  apply Eff.ext
  · intro a
    exact ⟨fun ha => (mem_empty a).mp (h.1 a ha) |>.elim, fun ha => (mem_empty a).mp ha |>.elim⟩
  · apply List.eq_nil_iff_forall_not_mem.mpr
    intro t ht
    exact (memFail_empty t).mp (h.2 t ⟨t, ht, rfl⟩)

theorem substRho_mono (es : List Eff) {ε ε' : Eff} (h : Sub ε ε') :
    Sub (substRho es ε) (substRho es ε') := Eff.substAt_mono 0 [] es h

theorem substRho_empty (es : List Eff) : substRho es empty = empty := by
  simp only [substRho, substAt, rawSubstAt, rawBind, empty, SubstEnv.at,
    substAtoms_false, rowFails_false, Ty.rawBindTys, List.nil_append, norm, Ty.normTys,
    Order.sortUnique_nil]

@[simp] theorem substAt_empty (c : Nat) (ts : List Ty) (es : List Eff) :
    substAt c ts es empty = empty := by
  simp only [substAt, rawSubstAt, rawBind, empty, SubstEnv.at,
    substAtoms_false, rowFails_false, Ty.rawBindTys, List.nil_append, norm, Ty.normTys,
    Order.sortUnique_nil]

/-- エフェクトの名前は置き換えで消えない。 -/
theorem substRho_name {es : List Eff} {ε : Eff} {l : EffName} (h : Eff.mem ε (.name l)) :
    Eff.mem (substRho es ε) (.name l) := by
  change Eff.mem (Eff.norm (Eff.rawBind (SubstEnv.at 0 [] es) ε)) (.name l)
  rw [Eff.mem_norm, Eff.mem_rawBind, Eff.mem_substAtoms]
  exact Or.inl h

end Eff

/-! ## 型の包含 -/

namespace Ty.Le

theorem refl (a : Ty) : Ty.Le a a := Or.inl rfl

theorem trans {a b c : Ty} (h₁ : Ty.Le a b) (h₂ : Ty.Le b c) : Ty.Le a c := by
  rcases h₁ with rfl | ⟨names, ps, r, ε, ε', rfl, rfl, hs⟩
  · exact h₂
  · rcases h₂ with rfl | ⟨names', ps', r', ε₁, ε₂, h, rfl, hs'⟩
    · exact Or.inr ⟨names, ps, r, ε, ε', rfl, rfl, hs⟩
    · cases h
      exact Or.inr ⟨names, ps, r, ε, ε₂, rfl, rfl, hs.trans hs'⟩

/-- 関数の型から広げた型は、契約名・引数・結果が同じで、エフェクトだけが広い関数の型である。 -/
theorem fn_left {names ps r ε t} (h : Ty.Le (.fn names ps r ε) t) :
    ∃ ε', t = .fn names ps r ε' ∧ Eff.Sub ε ε' := by
  rcases h with rfl | ⟨names', ps', r', ε₁, ε₂, h, rfl, hs⟩
  · exact ⟨ε, rfl, Eff.Sub.refl ε⟩
  · cases h; exact ⟨ε₂, rfl, hs⟩

/-- 関数の型に広げた元の型は、契約名・引数・結果が同じで、エフェクトだけが狭い関数の型である。 -/
theorem fn_right {a names ps r ε} (h : Ty.Le a (.fn names ps r ε)) :
    ∃ ε', a = .fn names ps r ε' ∧ Eff.Sub ε' ε := by
  rcases h with rfl | ⟨names', ps', r', ε₁, ε₂, rfl, h, hs⟩
  · exact ⟨ε, rfl, Eff.Sub.refl ε⟩
  · cases h; exact ⟨ε₁, rfl, hs⟩

/-- 関数の型でない型への包含は、等しさである。 -/
theorem eq_of_not_fn {a t : Ty} (h : Ty.Le a t) (ht : ∀ names ps r ε, t ≠ .fn names ps r ε) : a = t := by
  rcases h with rfl | ⟨names, ps, r, ε, ε', rfl, rfl, _⟩
  · rfl
  · exact absurd rfl (ht names ps r ε')

/-- 関数の型でない型からの包含は、等しさである。 -/
theorem eq_of_not_fn_left {a t : Ty} (h : Ty.Le a t) (ha : ∀ names ps r ε, a ≠ .fn names ps r ε) : a = t := by
  rcases h with rfl | ⟨names, ps, r, ε, ε', rfl, rfl, _⟩
  · rfl
  · exact absurd rfl (ha names ps r ε)

theorem substAt {a b : Ty} (c : Nat) (ts : List Ty) (es : List Eff) (h : Ty.Le a b) :
    Ty.Le (a.substAt c ts es) (b.substAt c ts es) := by
  rcases h with rfl | ⟨names, ps, r, ε, ε', rfl, rfl, hs⟩
  · exact refl _
  · simp only [Ty.substAt, Eff.substAt]
    exact Or.inr ⟨_, _, _, _, _, rfl, rfl, Eff.substAt_mono c ts es hs⟩

theorem subst {a b : Ty} (ts : List Ty) (es : List Eff) (h : Ty.Le a b) :
    Ty.Le (a.subst ts es) (b.subst ts es) := substAt 0 ts es h

theorem shift {a b : Ty} (k c : Nat) (h : Ty.Le a b) : Ty.Le (a.shift k c) (b.shift k c) := by
  rcases h with rfl | ⟨names, ps, r, ε, ε', rfl, rfl, hs⟩
  · exact refl _
  · simp only [Ty.shift]
    exact Or.inr ⟨_, _, _, _, _, rfl, rfl, Eff.shift_mono k c hs⟩

end Ty.Le

end Benitoite.Release
