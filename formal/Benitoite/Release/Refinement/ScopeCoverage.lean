import Benitoite.Release.Refinement.Adequate
import Benitoite.Release.Refinement.Atoms
import Benitoite.Scope.RangeCover

/-! # 範囲の被覆による同じ起点での所属保存 -/
namespace Benitoite.Release.Refinement
open Scope.Domain

theorem PathPattern.covers_atBase (w : Word) {p q : PathPattern} (h : p.Covers q) :
    (PathPattern.atBase w p).Covers (PathPattern.atBase w q) := by
  cases p <;> cases q <;> simp only [PathPattern.Covers, PathPattern.atBase] at h ⊢
  · exact congrArg (w ++ ·) h
  · obtain ⟨r, hr⟩ := h
    exact ⟨r, by rw [hr, List.append_assoc]⟩
  · obtain ⟨r, hr⟩ := h
    exact ⟨r, by rw [hr, List.append_assoc]⟩

theorem RangeExpr.Covers.mem {outer inner : RangeExpr}
    (h : outer.Covers inner) (σ : PathEnv) {k : Kind} {t : Target}
    (hm : inner.Mem σ k t) : outer.Mem σ k t := by
  rcases h with rfl | h
  · exact ⟨hm.1, .top, by simp [Range.Mem]⟩
  cases outer with
  | absolute r =>
    cases inner with
    | absolute s =>
      obtain ⟨hk,hs⟩ := hm
      simp only [RangeExpr.resolve, List.mem_singleton, exists_eq_left] at hs
      exact ⟨hk, by simpa [RangeExpr.resolve] using h.sound t hs⟩
    | based _ _ | secrets => cases h
  | based b p =>
    cases inner with
    | based c q =>
      obtain ⟨rfl,hc⟩ := h
      refine ⟨hm.1, ?_⟩
      cases hl : σ.lookup b with
      | none => simp [RangeExpr.Mem, RangeExpr.resolve, hl] at hm
      | some w =>
        have hh : (Range.path (PathPattern.atBase w q)).Mem t := by
          simpa [RangeExpr.resolve, hl] using hm.2
        exact by simpa [RangeExpr.resolve, hl] using
          (show (Range.path (PathPattern.atBase w p)).Covers (.path (PathPattern.atBase w q)) from
            PathPattern.covers_atBase w hc).sound t hh
    | absolute _ | secrets => cases h
  | secrets =>
    cases inner with
    | secrets => exact hm
    | absolute _ | based _ _ => cases h

theorem SnapshotMem.mono {snapshot k r s t}
    (h : SnapshotMem snapshot k r t) (hc : s.Covers r) :
    SnapshotMem snapshot k s t := by
  cases snapshot with
  | some σ => exact ⟨h.1, hc.mem σ h.2⟩
  | none =>
    cases r with
    | based _ _ | secrets => cases h
    | absolute r =>
      cases s with
      | absolute s => exact (RangeExpr.covers_absolute _ _ |>.mp hc).sound_memK h
      | based _ _ | secrets => simp [RangeExpr.Covers, RangeExpr.top] at hc
/-- snapshot の被覆後の所属を同じ実行の起点で読む。 -/
example {σ k r t} {s : RangeExpr} (h : SnapshotMem (some σ) k r t) (hc : s.Covers r) :
    s.Mem σ k t := (h.mono hc).current rfl

end Benitoite.Release.Refinement
