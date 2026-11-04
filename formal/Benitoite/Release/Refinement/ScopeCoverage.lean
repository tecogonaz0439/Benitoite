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

/-- 同じ起点を付加した対象の所属を、元のパターンの被覆で広げる。 -/
theorem PathPattern.Covers.mem_atBase {p q : PathPattern} (h : p.Covers q)
    (w : Word) {t : Target} (hm : (Range.path (PathPattern.atBase w q)).Mem t) :
    (Range.path (PathPattern.atBase w p)).Mem t :=
  (show (Range.path (PathPattern.atBase w p)).Covers (.path (PathPattern.atBase w q)) from
    PathPattern.covers_atBase w h).sound t hm

example (w s : Word) :
    (PathPattern.atBase w (.exact s)).Covers (PathPattern.atBase w (.exact s)) :=
  PathPattern.covers_atBase w rfl

example (w s r : Word) :
    (PathPattern.atBase w (.tree s)).Covers (PathPattern.atBase w (.exact (s ++ r))) :=
  PathPattern.covers_atBase w ⟨r, rfl⟩

example (w s r : Word) :
    (PathPattern.atBase w (.tree s)).Covers (PathPattern.atBase w (.tree (s ++ r))) :=
  PathPattern.covers_atBase w ⟨r, rfl⟩

example (w s r : Word) :
    ¬ (PathPattern.atBase w (.exact s)).Covers (PathPattern.atBase w (.tree r)) := by
  simp [PathPattern.atBase, PathPattern.Covers]

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
        exact by simpa [RangeExpr.resolve, hl] using PathPattern.Covers.mem_atBase hc w hh
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

example (σ : PathEnv) {k t} {inner : RangeExpr} (hm : inner.Mem σ k t) :
    RangeExpr.top.Mem σ k t := (RangeExpr.top_covers inner).mem σ hm

example (σ : PathEnv) {r s : Range} (h : r.Covers s) {k t}
    (hm : (RangeExpr.absolute s).Mem σ k t) : (RangeExpr.absolute r).Mem σ k t :=
  ((RangeExpr.covers_absolute r s).mpr h).mem σ hm

example (σ : PathEnv) (b : PathBase) {p q : PathPattern} (h : p.Covers q) {k t}
    (hm : (RangeExpr.based b q).Mem σ k t) : (RangeExpr.based b p).Mem σ k t :=
  (show (RangeExpr.based b p).Covers (.based b q) from .inr ⟨rfl, h⟩).mem σ hm

example (σ : PathEnv) {k t} (hm : RangeExpr.secrets.Mem σ k t) :
    RangeExpr.secrets.Mem σ k t := (RangeExpr.Covers.refl .secrets).mem σ hm

example (σ : PathEnv) (ps : List PathPattern) (hs : σ.secrets = some ps) (k : Kind) (t : Target) :
    RangeExpr.secrets.Mem σ k t ↔ t.kind = k ∧ ∃ p ∈ ps, (Range.path p).Mem t := by
  simp only [RangeExpr.Mem, RangeExpr.resolve, hs, Option.map_some]
  constructor
  · rintro ⟨hk, q, hq, hm⟩
    obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hq
    exact ⟨hk, p, hp, hm⟩
  · rintro ⟨hk, p, hp, hm⟩
    exact ⟨hk, .path p, List.mem_map.mpr ⟨p, hp, rfl⟩, hm⟩

example (σ : PathEnv) (k : Kind) (t : Target) (hs : σ.secrets = none ∨ σ.secrets = some []) :
    ¬ RangeExpr.secrets.Mem σ k t := by
  rcases hs with hs | hs <;> simp [RangeExpr.Mem, RangeExpr.resolve, hs]

example (σ : PathEnv) (b : PathBase) (p : PathPattern) (hl : σ.lookup b = none) (k : Kind) (t : Target) :
    ¬ (RangeExpr.based b p).Mem σ k t := by
  simp [RangeExpr.Mem, RangeExpr.resolve, hl]

/-- 同じ解決先で同じパターンへの所属は保たれるが、異なる起点の静的な被覆は成立しない。 -/
example (σ : PathEnv) (a b : PathBase) (hne : a ≠ b) (hl : σ.lookup a = σ.lookup b)
    (q : PathPattern) :
    (∀ k t, (RangeExpr.based b q).Mem σ k t → (RangeExpr.based a q).Mem σ k t) ∧
    ¬ (RangeExpr.based a q).Covers (.based b q) := by
  refine ⟨fun k t h => ?_, by simp [RangeExpr.Covers, hne]⟩
  simpa [RangeExpr.Mem, RangeExpr.resolve, hl] using h

example (b : PathBase) (p : PathPattern) (r : Range) :
    ¬ (RangeExpr.based b p).Covers (.absolute r) ∧
    ¬ (RangeExpr.based b p).Covers .secrets ∧
    ¬ RangeExpr.secrets.Covers (.absolute r) ∧
    ¬ RangeExpr.secrets.Covers (.based b p) := by
  simp [RangeExpr.Covers]

example (r : Range) (b : PathBase) (p : PathPattern) :
    ((RangeExpr.absolute r).Covers (.based b p) ↔ r = .top) ∧
    ((RangeExpr.absolute r).Covers .secrets ↔ r = .top) := by
  simp [RangeExpr.Covers, RangeExpr.top]
/-- snapshot の被覆後の所属を同じ実行の起点で読む。 -/
example {σ k r t} {s : RangeExpr} (h : SnapshotMem (some σ) k r t) (hc : s.Covers r) :
    s.Mem σ k t := (h.mono hc).current rfl

example (σ : PathEnv) {k t} {r s : Range} (h : SnapshotMem none k (.absolute r) t)
    (hc : s.Covers r) : (RangeExpr.absolute s).Mem σ k t :=
  (h.mono ((RangeExpr.covers_absolute s r).mpr hc)).current ⟨s, rfl⟩

/-- 具体化した内側が固定範囲なら、被覆する側も固定範囲で同じ対象を含む。 -/
theorem RangeIx.Covers.inst_mem {outer inner : RangeIx} (h : outer.Covers inner)
    (rs : List RangeExpr) {r : RangeExpr} (hi : inner.inst rs = .fixed r)
    (σ : PathEnv) {k t} (hm : r.Mem σ k t) :
    ∃ s, outer.inst rs = .fixed s ∧ s.Mem σ k t := by
  have hc := h.inst rs
  rw [hi] at hc
  cases ho : outer.inst rs with
  | rvar i => rw [ho] at hc; cases hc
  | fixed s => rw [ho] at hc; exact ⟨s, rfl, hc.mem σ hm⟩

example {r s : RangeExpr} (hc : s.Covers r) (rs : List RangeExpr) (σ : PathEnv)
    {k t} (hm : r.Mem σ k t) :
    ∃ q, (RangeIx.fixed s).inst rs = .fixed q ∧ q.Mem σ k t :=
  RangeIx.Covers.inst_mem (outer := .fixed s) (inner := .fixed r) hc rs rfl σ hm

example (rs : List RangeExpr) (i : Nat) {r : RangeExpr} (hi : rs[i]? = some r)
    (σ : PathEnv) {k t} (hm : r.Mem σ k t) :
    ∃ s, (RangeIx.rvar i).inst rs = .fixed s ∧ s.Mem σ k t :=
  RangeIx.Covers.inst_mem (outer := .rvar i) (inner := .rvar i) rfl rs
    (by simp [RangeIx.inst, hi]) σ hm

example (rs : List RangeExpr) (i : Nat) (hi : rs[i]? = none) :
    (RangeIx.rvar i).inst rs = .rvar i ∧
    ∀ r, (RangeIx.rvar i).inst rs ≠ .fixed r := by
  simp [RangeIx.inst, hi]

example (r : RangeExpr) (i : Nat) :
    ¬ (RangeIx.fixed r).Covers (.rvar i) ∧ ¬ (RangeIx.rvar i).Covers (.fixed r) := by
  simp [RangeIx.Covers]

end Benitoite.Release.Refinement
