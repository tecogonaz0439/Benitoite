import Benitoite.Core.Lemmas.Basic
import Benitoite.Core.WellFormed

/-!
# 型とエフェクトの置き換えの合成

関数の宣言が束縛した変数だけを含む型に、置き換え `[T̄/ᾱ, Ē/ρ̄]` と、さらに別の置き換え θ を続けて
施したものは、`[T̄θ/ᾱ, Ēθ/ρ̄]` を一度施したものに等しい。E-Fun の保存で、呼び出しの型の中の
型引数に、外側の関数の置き換えを施すときに使う。
-/

namespace Benitoite.Core

/-! ## 変数の範囲の述語の単調性 -/

theorem Eff.RhosIn.mono {pe pe' : Nat → Prop} (hpe : ∀ i, pe i → pe' i) {ε : Eff}
    (h : Eff.RhosIn pe ε) : Eff.RhosIn pe' ε := fun i hi => hpe i (h i hi)

mutual
  theorem Ty.VarsIn.mono {pt pe pt' pe' : Nat → Prop} (hpt : ∀ i, pt i → pt' i)
      (hpe : ∀ i, pe i → pe' i) : (a : Ty) → Ty.VarsIn pt pe a → Ty.VarsIn pt' pe' a
    | .base _, _ => trivial
    | .opaque _, _ => trivial
    | .data _ args, h => by
        simp only [Ty.VarsIn] at h ⊢; exact Ty.VarsInList.mono hpt hpe args h
    | .list a, h => by simp only [Ty.VarsIn] at h ⊢; exact Ty.VarsIn.mono hpt hpe a h
    | .fn ps r ε, h => by
        simp only [Ty.VarsIn] at h ⊢
        exact ⟨Ty.VarsInList.mono hpt hpe ps h.1, Ty.VarsIn.mono hpt hpe r h.2.1,
          Eff.RhosIn.mono hpe h.2.2⟩
    | .tvar i, h => by simp only [Ty.VarsIn] at h ⊢; exact hpt i h

  theorem Ty.VarsInList.mono {pt pe pt' pe' : Nat → Prop} (hpt : ∀ i, pt i → pt' i)
      (hpe : ∀ i, pe i → pe' i) : (as : List Ty) → Ty.VarsInList pt pe as →
      Ty.VarsInList pt' pe' as
    | [], _ => trivial
    | a :: as, h => by
        simp only [Ty.VarsInList] at h ⊢
        exact ⟨Ty.VarsIn.mono hpt hpe a h.1, Ty.VarsInList.mono hpt hpe as h.2⟩
end

/-! ## エフェクトの集合の置き換えの合成 -/

/-- `ε[Ē/ρ̄]` の要素の言い換え。 -/
theorem Eff.substRho_true {es : List Eff} {ε : Eff} {a : Atom} :
    Eff.substRho es ε a = true ↔
      ((match a with
        | .io => ε .io = true
        | .rho k => es.length ≤ k ∧ ε (.rho k) = true) ∨
       ∃ i e, es[i]? = some e ∧ ε (.rho i) = true ∧ e a = true) := by
  simp only [Eff.substRho, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true]
  apply or_congr
  · cases a with
    | io => rfl
    | rho k =>
      by_cases hk : k < es.length
      · simp only [hk, ↓reduceIte, Bool.false_eq_true, false_iff, not_and]
        intro h; omega
      · simp only [hk, ↓reduceIte]
        constructor
        · intro h; exact ⟨by omega, h⟩
        · intro h; exact h.2
  · constructor
    · rintro ⟨i, hi, h1, h2⟩
      refine ⟨i, es[i], by simp [hi], h1, ?_⟩
      simpa [List.getElem?_eq_getElem hi] using h2
    · rintro ⟨i, e, he, h1, h2⟩
      have hi : i < es.length := (List.getElem?_eq_some_iff.mp he).1
      refine ⟨i, hi, h1, ?_⟩
      simp [List.getElem?_eq_getElem hi] at he ⊢
      rw [he]; exact h2

/-- `Ē` を置き換えた後の `ε` の要素の、置き換えの合成の両辺に共通の言い換え。 -/
private def CompChar (es es' : List Eff) (ε : Eff) (a : Atom) : Prop :=
  (a = .io ∧ ε .io = true) ∨
    ∃ i e, es[i]? = some e ∧ ε (.rho i) = true ∧ Eff.substRho es' e a = true

theorem Eff.substRho_comp {es es' : List Eff} {ε : Eff} (h : Eff.RhosIn (· < es.length) ε) :
    Eff.substRho es' (Eff.substRho es ε) = Eff.substRho (es.map (Eff.substRho es')) ε := by
  -- ε の中のエフェクト変数はどれも es の長さより小さいので、置き換えずに残る変数はない。
  have hnokeep : ∀ k, es.length ≤ k → ε (.rho k) = false := by
    intro k hk
    cases hε : ε (.rho k)
    · rfl
    · have := h k hε; omega
  -- 内側の置き換えの結果の要素（残る変数がないので、置き換えた先の集合の要素だけ）。
  have hinner : ∀ x, Eff.substRho es ε x = true ↔
      ((x = .io ∧ ε .io = true) ∨ ∃ i e, es[i]? = some e ∧ ε (.rho i) = true ∧ e x = true) := by
    intro x
    rw [Eff.substRho_true]
    cases x with
    | io => simp
    | rho k =>
      simp only [reduceCtorEq, false_and, false_or]
      constructor
      · rintro (⟨hk, hε⟩ | hex)
        · rw [hnokeep k hk] at hε; cases hε
        · exact hex
      · exact Or.inr
  have hL : ∀ a, Eff.substRho es' (Eff.substRho es ε) a = true ↔ CompChar es es' ε a := by
    intro a
    unfold CompChar
    rw [Eff.substRho_true]
    constructor
    · rintro (hkeep | ⟨j, e', he', hj, ha⟩)
      · cases a with
        | io =>
          simp only at hkeep
          rcases (hinner _).mp hkeep with ⟨_, hio⟩ | ⟨i, e, he, hi, hea⟩
          · exact Or.inl ⟨rfl, hio⟩
          · exact Or.inr ⟨i, e, he, hi, Eff.substRho_true.mpr (Or.inl hea)⟩
        | rho k =>
          simp only at hkeep
          rcases (hinner _).mp hkeep.2 with ⟨hc, _⟩ | ⟨i, e, he, hi, hea⟩
          · cases hc
          · exact Or.inr ⟨i, e, he, hi, Eff.substRho_true.mpr (Or.inl ⟨hkeep.1, hea⟩)⟩
      · rcases (hinner _).mp hj with ⟨hc, _⟩ | ⟨i, e, he, hi, hej⟩
        · cases hc
        · exact Or.inr ⟨i, e, he, hi, Eff.substRho_true.mpr (Or.inr ⟨j, e', he', hej, ha⟩)⟩
    · rintro (⟨rfl, hio⟩ | ⟨i, e, he, hi, hea⟩)
      · left; simp only; exact (hinner _).mpr (Or.inl ⟨rfl, hio⟩)
      · rcases Eff.substRho_true.mp hea with hkeep | ⟨j, e', he', hej, ha⟩
        · left
          cases a with
          | io => simp only; exact (hinner _).mpr (Or.inr ⟨i, e, he, hi, hkeep⟩)
          | rho k =>
            simp only at hkeep ⊢
            exact ⟨hkeep.1, (hinner _).mpr (Or.inr ⟨i, e, he, hi, hkeep.2⟩)⟩
        · exact Or.inr ⟨j, e', he', (hinner _).mpr (Or.inr ⟨i, e, he, hi, hej⟩), ha⟩
  have hR : ∀ a, Eff.substRho (es.map (Eff.substRho es')) ε a = true ↔ CompChar es es' ε a := by
    intro a
    unfold CompChar
    rw [Eff.substRho_true]
    constructor
    · rintro (hkeep | ⟨i, e'', he'', hi, ha⟩)
      · cases a with
        | io => exact Or.inl ⟨rfl, hkeep⟩
        | rho k =>
          simp only [List.length_map] at hkeep
          rw [hnokeep k hkeep.1] at hkeep; cases hkeep.2
      · simp only [List.getElem?_map, Option.map_eq_some_iff] at he''
        obtain ⟨e, he, rfl⟩ := he''
        exact Or.inr ⟨i, e, he, hi, ha⟩
    · rintro (⟨rfl, hio⟩ | ⟨i, e, he, hi, hea⟩)
      · exact Or.inl hio
      · exact Or.inr ⟨i, Eff.substRho es' e, by simp [he], hi, hea⟩
  funext a
  apply Bool.eq_iff_iff.mpr
  rw [hL, hR]

/-! ## 型の置き換えの合成 -/

mutual
  theorem Ty.subst_comp {ts : List Ty} {es : List Eff} (ts' : List Ty) (es' : List Eff) :
      (a : Ty) → Ty.VarsIn (· < ts.length) (· < es.length) a →
      Ty.subst ts' es' (Ty.subst ts es a) =
        Ty.subst (ts.map (Ty.subst ts' es')) (es.map (Eff.substRho es')) a
    | .base _, _ => by simp [Ty.subst]
    | .opaque _, _ => by simp [Ty.subst]
    | .data d args, h => by
        simp only [Ty.VarsIn] at h
        simp only [Ty.subst]
        rw [Ty.subst_comp_list ts' es' args h]
    | .list a, h => by
        simp only [Ty.VarsIn] at h
        simp only [Ty.subst]
        rw [Ty.subst_comp ts' es' a h]
    | .fn ps r ε, h => by
        simp only [Ty.VarsIn] at h
        simp only [Ty.subst]
        rw [Ty.subst_comp_list ts' es' ps h.1, Ty.subst_comp ts' es' r h.2.1,
          Eff.substRho_comp h.2.2]
    | .tvar i, h => by
        simp only [Ty.VarsIn] at h
        simp [Ty.subst, List.getElem?_eq_getElem h]

  theorem Ty.subst_comp_list {ts : List Ty} {es : List Eff} (ts' : List Ty) (es' : List Eff) :
      (as : List Ty) → Ty.VarsInList (· < ts.length) (· < es.length) as →
      (as.map (Ty.subst ts es)).map (Ty.subst ts' es') =
        as.map (Ty.subst (ts.map (Ty.subst ts' es')) (es.map (Eff.substRho es')))
    | [], _ => rfl
    | a :: as, h => by
        simp only [Ty.VarsInList] at h
        simp only [List.map_cons]
        rw [Ty.subst_comp ts' es' a h.1, Ty.subst_comp_list ts' es' as h.2]
end

end Benitoite.Core
