import Benitoite.Release.Refinement.Codes

namespace Benitoite.Release.Refinement
open Order

def RangeIx.code (ix : RangeIx) : Nat :=
  match ix.toOld? with
  | some old => 2 * Order.ixCode old
  | none => 2 * Benitoite.Release.Refinement.code ix + 1

theorem RangeIx.code_injective {a b : RangeIx} (h : a.code = b.code) : a = b := by
  unfold RangeIx.code at h
  cases ha : a.toOld? <;> cases hb : b.toOld? <;> simp only [ha, hb] at h
  · exact Benitoite.Release.Refinement.code_injective (by omega)
  · omega
  · omega
  · rename_i olda oldb
    have he : olda = oldb := Order.ixCode_injective (by omega)
    exact (RangeIx.toOld?_sound ha).symm.trans (he ▸ RangeIx.toOld?_sound hb)

@[simp] theorem RangeIx.code_embed (ix : Scope.Signature.Ix) : (embedIx ix).code = 2 * Order.ixCode ix := by
  simp [RangeIx.code]

def Atom.code (a : Atom) : Nat :=
  match a.toOld? with
  | some old => 2 * Benitoite.Release.Atom.code old
  | none => 2 * Benitoite.Release.Refinement.code a + 1

theorem Atom.code_injective {a b : Atom} (h : a.code = b.code) : a = b := by
  unfold Atom.code at h
  cases ha : a.toOld? <;> cases hb : b.toOld? <;> simp only [ha, hb] at h
  · exact Benitoite.Release.Refinement.code_injective (by omega)
  · omega
  · omega
  · rename_i olda oldb
    have he : olda = oldb := Benitoite.Release.Atom.code_injective (by omega)
    exact (Atom.toOld?_sound ha).symm.trans (he ▸ Atom.toOld?_sound hb)

@[simp] theorem Atom.code_embed (a : Benitoite.Release.Atom) : (embedAtom a).code = 2 * a.code := by
  simp [Atom.code]

/-- 既存の関数ラベルへ単射に写す。使わない符号の所属はfalseである。 -/
noncomputable def encodeAtoms (f : Atom → Bool) : Benitoite.Release.Atom → Bool
  | .name _ _ => false
  | .rho n => by
    classical
    exact if h : ∃ a : Atom, a.code = n then f (Classical.choose h) else false

@[simp] theorem encodeAtoms_at (f : Atom → Bool) (a : Atom) :
    encodeAtoms f (.rho a.code) = f a := by
  classical
  simp only [encodeAtoms]
  split
  · rename_i h
    rw [Atom.code_injective (Classical.choose_spec h)]
  · rename_i h
    exact False.elim (h ⟨a, rfl⟩)

theorem encodeAtoms_injective : Function.Injective encodeAtoms := by
  intro f g h
  funext a
  simpa only [encodeAtoms_at] using congrFun h (.rho a.code)

private theorem before_embed {f g : Benitoite.Release.Atom → Bool} {a : Benitoite.Release.Atom}
    (h : Benitoite.Release.AtomsBefore f g a) :
    Benitoite.Release.AtomsBefore (encodeAtoms (embedAtoms f)) (encodeAtoms (embedAtoms g))
      (.rho (embedAtom a).code) := by
  refine ⟨by rw [encodeAtoms_at, embedAtoms_embed]; exact h.1,
    by rw [encodeAtoms_at, embedAtoms_embed]; exact h.2.1, ?_⟩
  intro b hb
  cases b with
  | name _ _ => rfl
  | rho n =>
    classical
    simp only [encodeAtoms]
    split
    · rename_i hn
      let x := Classical.choose hn
      have hx : x.code = n := Classical.choose_spec hn
      cases ho : x.toOld? with
      | none =>
        change embedAtoms f x = embedAtoms g x
        simp [embedAtoms, ho]
      | some old =>
        have hxo : embedAtom old = x := Atom.toOld?_sound ho
        have hn' : n = 2 * old.code := by rw [← hx, ← hxo, Atom.code_embed]
        have hsmall : old.code < a.code := by
          rw [Atom.code_embed] at hb
          change 2*n+1 < 2*(2*a.code)+1 at hb
          omega
        change embedAtoms f x = embedAtoms g x
        rw [← hxo, embedAtoms_embed, embedAtoms_embed]
        exact h.2.2 old hsmall
    · rfl

private theorem compare_embed_lt {f g : Benitoite.Release.Atom → Bool}
    (h : Benitoite.Release.atomsCompare f g = .lt) :
    Benitoite.Release.atomsCompare (encodeAtoms (embedAtoms f)) (encodeAtoms (embedAtoms g)) = .lt := by
  obtain ⟨a, ha⟩ := Benitoite.Release.atomsCompare_lt_iff.mp h
  exact Benitoite.Release.atomsCompare_lt_iff.mpr ⟨_, before_embed ha⟩

theorem atomsCompare_embed (f g : Benitoite.Release.Atom → Bool) :
    Benitoite.Release.atomsCompare (encodeAtoms (embedAtoms f)) (encodeAtoms (embedAtoms g)) =
      Benitoite.Release.atomsCompare f g := by
  cases h : Benitoite.Release.atomsCompare f g with
  | lt => exact compare_embed_lt h
  | eq =>
    have he := Benitoite.Release.atomsCompare_eq_iff.mp h
    cases he
    exact Benitoite.Release.atomsCompare_eq_iff.mpr rfl
  | gt => exact (Benitoite.Release.atomsCompare_gt_iff.mpr
      (compare_embed_lt (Benitoite.Release.atomsCompare_gt_iff.mp h)))

end Benitoite.Release.Refinement
