import Benitoite.Release.Refinement.ScopeSyntax

namespace Benitoite.Release.Refinement

def RangeExpr.Covers (outer inner : RangeExpr) : Prop :=
  outer = .top ∨ match outer, inner with
  | .absolute r, .absolute s => r.Covers s
  | .based b p, .based c q => b = c ∧ (Scope.Domain.Range.path p).Covers (.path q)
  | .secrets, .secrets => True
  | _, _ => False

@[simp] theorem RangeExpr.covers_absolute (r s : Scope.Domain.Range) :
    (RangeExpr.absolute r).Covers (.absolute s) ↔ r.Covers s := by
  by_cases h : r = .top
  · subst r; simp [Covers, Scope.Domain.Range.top_covers]
  · simp [Covers, h]

theorem RangeExpr.Covers.refl (r : RangeExpr) : r.Covers r := by
  cases r <;> simp [RangeExpr.Covers, Scope.Domain.Range.Covers.refl]

theorem RangeExpr.top_covers (r : RangeExpr) : RangeExpr.Covers .top r := Or.inl rfl

@[simp] theorem RangeExpr.covers_top_iff (r : RangeExpr) : r.Covers .top ↔ r = .top := by
  cases r <;> simp [RangeExpr.Covers, Scope.Domain.Range.covers_top_iff]

theorem RangeExpr.Covers.trans {a b c : RangeExpr} (h : a.Covers b) (h' : b.Covers c) : a.Covers c := by
  rcases h with ha | h
  · exact Or.inl ha
  rcases h' with hb | h'
  · have ha : a = .top := (RangeExpr.covers_top_iff a).mp (hb ▸ Or.inr h)
    exact Or.inl ha
  apply Or.inr
  cases a <;> cases b <;> cases c <;> simp only at h h' ⊢
  all_goals first
    | contradiction
    | trivial
    | exact h.trans h'
    | exact ⟨h.1.trans h'.1, h.2.trans h'.2⟩

def RangeIx.Covers : RangeIx → RangeIx → Prop
  | .fixed r, .fixed s => r.Covers s
  | .rvar i, .rvar j => i = j
  | _, _ => False

theorem RangeIx.Covers.inst {r s : RangeIx} (h : r.Covers s) (rs : List RangeExpr) :
    (r.inst rs).Covers (s.inst rs) := by
  cases r <;> cases s <;> simp only [RangeIx.Covers] at h
  · exact h
  · rename_i i j
    cases h
    cases he : rs[i]? <;> simp [RangeIx.inst, he, RangeIx.Covers, RangeExpr.Covers.refl]

def Atom.Covers : Atom → Atom → Prop
  | .name l (.fixed r), .name m (.fixed s) => l = m ∧ r.Covers s
  | .name l (.rvar i), .name m (.rvar j) => l = m ∧ i = j
  | .rho i, .rho j => i = j
  | _, _ => False

theorem Atom.Covers.refl (a : Atom) : a.Covers a := by
  rcases a with ⟨l, r | i⟩ | i <;> simp [Atom.Covers, RangeExpr.Covers.refl]

theorem Atom.Covers.trans {a b c : Atom} (h₁ : a.Covers b) (h₂ : b.Covers c) : a.Covers c := by
  rcases a with ⟨l, r | i⟩ | i <;> rcases b with ⟨m, s | j⟩ | j <;> rcases c with ⟨n, u | k⟩ | k <;>
    simp only [Atom.Covers] at h₁ h₂ ⊢
  · exact ⟨h₁.1.trans h₂.1, h₁.2.trans h₂.2⟩
  · exact ⟨h₁.1.trans h₂.1, h₁.2.trans h₂.2⟩
  · exact h₁.trans h₂

theorem Atom.covers_rho_iff {a : Atom} {j : Nat} : a.Covers (.rho j) ↔ a = .rho j := by
  rcases a with ⟨m, r | i⟩ | i <;> simp [Atom.Covers]

theorem Atom.Covers.name_right {a : Atom} {l : EffName} {ix : RangeIx}
    (h : a.Covers (.name l ix)) : ∃ jx, a = .name l jx := by
  cases a with
  | rho _ => cases ix <;> cases h
  | name m jx =>
    cases ix <;> cases jx <;> simp only [Atom.Covers] at h
    all_goals exact ⟨_, by rw [h.1]⟩

theorem Atom.nameTop_covers_iff {l : EffName} {b : Atom} :
    (Atom.nameTop l).Covers b ↔ ∃ s, b = .name l (.fixed s) := by
  rcases b with ⟨m, s | j⟩ | j <;> simp only [Atom.Covers]
  · constructor
    · rintro ⟨rfl, -⟩; exact ⟨s, rfl⟩
    · rintro ⟨s', h⟩; cases h; exact ⟨rfl, RangeExpr.top_covers _⟩
  · simp
  · simp

def Atom.instR (rs : List RangeExpr) : Atom → Atom
  | .name l ix => .name l (ix.inst rs)
  | .rho i => .rho i

theorem rangeIx_inst_eq_fixed_iff {rs : List RangeExpr} {ix : RangeIx} {r : RangeExpr} :
    ix.inst rs = .fixed r ↔ ix = .fixed r ∨ ∃ i, ix = .rvar i ∧ rs[i]? = some r := by
  cases ix with
  | fixed r' => simp [RangeIx.inst]
  | rvar i =>
    constructor
    · intro h
      right
      refine ⟨i, rfl, ?_⟩
      cases hi : rs[i]? with
      | none => simp [RangeIx.inst, hi] at h
      | some r' => simp only [RangeIx.inst, hi, RangeIx.fixed.injEq] at h; rw [h]
    · rintro (h | ⟨j, hj, hr⟩)
      · cases h
      · cases hj; simp [RangeIx.inst, hr]

/-- 具体化の結果が範囲の変数として残るのは、元が同じ範囲の変数で、具体化の列が短いときだけである。 -/
theorem rangeIx_inst_eq_rvar_iff {rs : List RangeExpr} {ix : RangeIx} {i : Nat} :
    ix.inst rs = .rvar i ↔ ix = .rvar i ∧ rs[i]? = none := by
  cases ix with
  | fixed r' => simp [RangeIx.inst]
  | rvar j =>
    constructor
    · intro h
      cases hj : rs[j]? with
      | none =>
        simp only [RangeIx.inst, hj, RangeIx.rvar.injEq] at h
        subst h; exact ⟨rfl, hj⟩
      | some r' => simp [RangeIx.inst, hj] at h
    · rintro ⟨hj, hr⟩
      cases hj; simp [RangeIx.inst, hr]

def instAtoms (rs : List RangeExpr) (a : Atom → Bool) : Atom → Bool
  | .name l (.fixed r) => a (.name l (.fixed r)) ||
      (List.range rs.length).any (fun i => a (.name l (.rvar i)) && decide (rs[i]? = some r))
  | .name l (.rvar i) => a (.name l (.rvar i)) && rs[i]?.isNone
  | .rho i => a (.rho i)

theorem instAtoms_spec (rs : List RangeExpr) (a : Atom → Bool) (x : Atom) :
    instAtoms rs a x = true ↔ ∃ y, a y = true ∧ y.instR rs = x := by
  cases x with
  | rho i =>
    simp only [instAtoms]
    constructor
    · intro h; exact ⟨.rho i, h, rfl⟩
    · rintro ⟨y, hy, he⟩
      cases y with
      | name l ix => simp [Atom.instR] at he
      | rho j => simp only [Atom.instR, Atom.rho.injEq] at he; subst he; exact hy
  | name l ix =>
    cases ix with
    | fixed r =>
      simp only [instAtoms, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true,
        decide_eq_true_eq]
      constructor
      · rintro (h | ⟨i, _, h, hi⟩)
        · exact ⟨_, h, rfl⟩
        · exact ⟨.name l (.rvar i), h, by simp [Atom.instR, RangeIx.inst, hi]⟩
      · rintro ⟨y, hy, he⟩
        cases y with
        | rho j => simp [Atom.instR] at he
        | name l' ix' =>
          simp only [Atom.instR, Atom.name.injEq] at he
          obtain ⟨rfl, he⟩ := he
          rcases rangeIx_inst_eq_fixed_iff.mp he with rfl | ⟨i, rfl, hi⟩
          · exact Or.inl hy
          · exact Or.inr ⟨i, (List.getElem?_eq_some_iff.mp hi).1, hy, hi⟩
    | rvar i =>
      simp only [instAtoms, Bool.and_eq_true, Option.isNone_iff_eq_none]
      constructor
      · rintro ⟨h, hi⟩
        exact ⟨_, h, by simp [Atom.instR, RangeIx.inst, hi]⟩
      · rintro ⟨y, hy, he⟩
        cases y with
        | rho j => simp [Atom.instR] at he
        | name l' ix' =>
          simp only [Atom.instR, Atom.name.injEq] at he
          obtain ⟨rfl, he⟩ := he
          obtain ⟨rfl, hi⟩ := rangeIx_inst_eq_rvar_iff.mp he
          exact ⟨hy, hi⟩

@[simp] theorem Atom.instR_nil (a : Atom) : a.instR [] = a := by
  cases a <;> simp [Atom.instR]

theorem embedAtom_covers {a b : Benitoite.Release.Atom} (h : a.Covers b) :
    (embedAtom a).Covers (embedAtom b) := by
  rcases a with ⟨l, r | i⟩ | i <;> rcases b with ⟨m, s | j⟩ | j <;>
    simp only [Benitoite.Release.Atom.Covers] at h
  · exact ⟨h.1, (RangeExpr.covers_absolute _ _).mpr h.2⟩
  · exact h
  · exact h

end Benitoite.Release.Refinement
