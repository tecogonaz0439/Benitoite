import Benitoite
/-! 固定した σ の下で Covers が Allows を広げる方向に健全であること（旧 Eff.Covers.sound の新形の試行）。 -/
open Benitoite.Release.Refinement
open Benitoite.Scope.Domain
namespace RvT4

theorem atBase_covers (w : Word) {p q : PathPattern} (h : p.Covers q) :
    (PathPattern.atBase w p).Covers (PathPattern.atBase w q) := by
  cases p <;> cases q <;> simp only [PathPattern.atBase, PathPattern.Covers] at h ⊢
  · rw [h]
  · obtain ⟨r, rfl⟩ := h; exact ⟨r, by simp⟩
  · obtain ⟨r, rfl⟩ := h; exact ⟨r, by simp⟩

theorem expr_covers_mem {σ : PathEnv} {k : Kind} {r s : RangeExpr} {t : Target}
    (h : r.Covers s) (hm : s.Mem σ k t) : r.Mem σ k t := by
  refine ⟨hm.1, ?_⟩
  have hm2 := hm.2
  rcases h with rfl | h
  · show ∃ q ∈ [Range.top], q.Mem t
    exact ⟨.top, List.mem_singleton.mpr rfl, by cases t <;> trivial⟩
  · cases r <;> cases s <;> simp only at h
    · simp only [RangeExpr.resolve, List.mem_singleton, exists_eq_left] at hm2 ⊢
      exact Range.Covers.sound h t hm2
    · obtain ⟨rfl, hc⟩ := h
      simp only [RangeExpr.resolve] at hm2 ⊢
      cases hb : σ.lookup _ with
      | none => simp [hb] at hm2
      | some w =>
        simp only [hb, Option.map_some, List.mem_singleton, exists_eq_left] at hm2 ⊢
        exact Range.Covers.sound (r := .path _) (s := .path _) (atBase_covers w hc) t hm2
    · exact hm2

theorem allows_of_covers {σ κ Γ Φ outer inner l t} (h : Eff.Covers Γ Φ outer inner)
    (ha : Eff.Allows σ κ inner l t) : Eff.Allows σ κ outer l t := by
  obtain ⟨k, s, hk, hm, ht⟩ := ha
  obtain ⟨b, hb, hc⟩ := h.1 _ hm
  rcases b with ⟨l', r | i⟩ | i
  · obtain ⟨rfl, hrs⟩ := hc
    exact ⟨k, r, hk, hb, expr_covers_mem hrs ht⟩
  · exact hc.elim
  · exact hc.elim

end RvT4
#print axioms RvT4.allows_of_covers
