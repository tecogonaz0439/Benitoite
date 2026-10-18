import Benitoite.Release.Order.Atoms

/-! 有限支持での比較。入力の順序と重複によらず、符号が最小の相違点を選ぶ。 -/
namespace Benitoite.Release

def firstDifference (s : List Atom) (f g : Atom → Bool) : Option Atom :=
  match s with
  | [] => none
  | a :: s =>
    if f a == g a then firstDifference s f g else
      match firstDifference s f g with
      | none => some a
      | some b => some (if Atom.code a ≤ Atom.code b then a else b)

theorem firstDifference_spec (s : List Atom) (f g : Atom → Bool) :
    match firstDifference s f g with
    | none => ∀ a ∈ s, f a = g a
    | some a => a ∈ s ∧ f a ≠ g a ∧
        ∀ b ∈ s, f b ≠ g b → Atom.code a ≤ Atom.code b := by
  induction s with
  | nil => simp [firstDifference]
  | cons a s ih =>
    simp only [firstDifference]
    by_cases he : (f a == g a) = true
    · rw [ite_eq_left he]
      have he := eq_of_beq he
      cases hd : firstDifference s f g with
      | none => simp only [hd] at ih ⊢; simpa [he] using ih
      | some b =>
        simp only [hd] at ih ⊢
        exact ⟨List.mem_cons_of_mem a ih.1, ih.2.1, fun c hc hn => by
          rcases List.mem_cons.mp hc with rfl | hc
          · exact False.elim (hn he)
          · exact ih.2.2 c hc hn⟩
    · rw [ite_eq_right he]
      have hn : f a ≠ g a := by simpa using he
      cases hd : firstDifference s f g with
      | none =>
        simp only [hd] at ih ⊢
        exact ⟨List.mem_cons_self, hn, fun c hc hne => by
          rcases List.mem_cons.mp hc with rfl | hc
          · exact Nat.le_refl _
          · exact False.elim (hne (ih c hc))⟩
      | some b =>
        simp only [hd] at ih ⊢
        by_cases hab : Atom.code a ≤ Atom.code b
        · rw [ite_eq_left hab]
          exact ⟨List.mem_cons_self, hn, fun c hc hne => by
            rcases List.mem_cons.mp hc with rfl | hc
            · exact Nat.le_refl _
            · exact Nat.le_trans hab (ih.2.2 c hc hne)⟩
        · rw [ite_eq_right hab]
          exact ⟨List.mem_cons_of_mem a ih.1, ih.2.1, fun c hc hne => by
            rcases List.mem_cons.mp hc with rfl | hc
            · omega
            · exact ih.2.2 c hc hne⟩

def atomsCompareWith (s : List Atom) (f g : Atom → Bool) : Ordering :=
  match firstDifference s f g with
  | none => .eq
  | some a => compare (f a) (g a)

theorem atomsCompareWith_eq_compare {s : List Atom} {f g : Atom → Bool}
    (hf : ∀ a, f a = true → a ∈ s) (hg : ∀ a, g a = true → a ∈ s) :
    atomsCompareWith s f g = atomsCompare f g := by
  have outside : ∀ a, a ∉ s → f a = g a := by
    intro a ha
    cases hfa : f a <;> cases hga : g a <;> simp_all
  have hs := firstDifference_spec s f g
  cases hd : firstDifference s f g with
  | none =>
    simp only [atomsCompareWith, hd]
    simp only [hd] at hs
    apply (atomsCompare_eq_iff.mpr (funext (fun a => ?_))).symm
    by_cases ha : a ∈ s
    · exact hs a ha
    · exact outside a ha
  | some a =>
    simp only [atomsCompareWith, hd]
    simp only [hd] at hs
    have hmin : ∀ b, Atom.code b < Atom.code a → f b = g b := by
      intro b hb
      by_cases hm : b ∈ s
      · by_cases he : f b = g b
        · exact he
        · have := hs.2.2 b hm he; omega
      · exact outside b hm
    change compare (f a) (g a) = atomsCompare f g
    cases hfa : f a <;> cases hga : g a
    · exact False.elim (hs.2.1 (hfa.trans hga.symm))
    · exact (atomsCompare_lt_iff.mpr ⟨a, hfa, hga, hmin⟩).symm
    · exact (atomsCompare_gt_iff.mpr (atomsCompare_lt_iff.mpr
        ⟨a, hga, hfa, fun b hb => (hmin b hb).symm⟩)).symm
    · exact False.elim (hs.2.1 (hfa.trans hga.symm))

end Benitoite.Release
