import Benitoite.Scope.TopCompat
import Benitoite.Scope.RepresentationExamplesI

/-!
# 旧 Top との互換の例と、構造の等号の利用側の試し

採用定義 `Scope.TopCompat`（`TopEmbedding`・`GEff`・`lift`）を、原子のモデル（`CandidateI.Atom`）で具体化し、旧の言明を
Top の互換の系として取り戻す例と、意味の被覆の相互包含から等号を導かない反例（`semCovers_not_eq`）を置く。
範囲の位置 `Ix` を持つ原子での具体化は `Scope.SwitchExamples` の 5 節にある。
-/

namespace Benitoite.Scope.CompatExamples

open Benitoite.Release
open Benitoite.Scope.TopCompat

/-- 案 (i) の原子（`Atom.name l r`）の埋め込み。 -/
def embI : TopEmbedding RepresentationExamples.CandidateI.Atom where
  ofRelease := RepresentationExamples.CandidateI.Atom.ofRelease
  toRelease? := RepresentationExamples.CandidateI.Atom.toRelease?
  to_of := RepresentationExamples.CandidateI.Atom.toRelease_ofRelease
  of_to := RepresentationExamples.CandidateI.Atom.toRelease_eq_some

example : (∀ a b : Eff, Eff.union a (Eff.union b Eff.empty) = Eff.union a b) :=
  embI.old_union_empty_right_nested
example : (∀ a b : Eff, Eff.union a (Eff.union Eff.empty b) = Eff.union a b) :=
  embI.old_union_empty_left_nested

/-! ## 意味の被覆の相互包含から等号を導かない（案 (i) の原子の例） -/

namespace SemanticExample

open RepresentationExamples.CandidateI (dataA)

/-- 案 (i) の原子。 -/
abbrev Atom := RepresentationExamples.CandidateI.Atom

/-- 範囲の意味の被覆による包含。左の各原子を、右のいずれか一原子が丸ごと覆う。 -/
def SemCovers (e f : GEff Atom) : Prop := ∀ x, e.mem x → ∃ y, f.mem y ∧ RepresentationExamples.CandidateI.Atom.within x y = true

/-- `File.Read` の Top と `/data/a` の二原子。 -/
def wide : GEff Atom := ⟨fun x => x == .name "File.Read" .top || x == .name "File.Read" dataA, []⟩

/-- `File.Read` の Top の一原子。 -/
def top : GEff Atom := ⟨fun x => x == .name "File.Read" .top, []⟩

theorem wide_canonical : wide.Canonical := by
  simp [GEff.Canonical, GEff.norm, GEff.failPart, wide, Eff.norm, Eff.fails]

theorem top_canonical : top.Canonical := by
  simp [GEff.Canonical, GEff.norm, GEff.failPart, top, Eff.norm, Eff.fails]

theorem wide_covers_top : SemCovers wide top := by
  intro x hx
  refine ⟨.name "File.Read" .top, by simp [GEff.mem, top], ?_⟩
  simp only [GEff.mem, wide, Bool.or_eq_true, beq_iff_eq] at hx
  rcases hx with rfl | rfl <;> decide

theorem top_covers_wide : SemCovers top wide := by
  intro x hx
  refine ⟨x, by simp_all [GEff.mem, top, wide], ?_⟩
  simp only [GEff.mem, top, beq_iff_eq] at hx
  subst hx; decide

/-- 正規形どうしで意味の被覆が相互に成り立っても、構造の等号は成り立たない。構造上の包含は成り立たない。 -/
theorem semCovers_not_eq : SemCovers wide top ∧ SemCovers top wide ∧ wide ≠ top ∧
    ¬ GEff.Sub wide top := by
  refine ⟨wide_covers_top, top_covers_wide, fun h => ?_, fun h => ?_⟩
  · have := congrArg (fun e : GEff Atom => e.atoms (.name "File.Read" dataA)) h
    simp [wide, top, dataA] at this
  · have := h.1 (.name "File.Read" dataA) (by simp [GEff.mem, wide])
    simp [GEff.mem, top, dataA] at this

/-- したがって、意味の被覆の相互包含を前提にした等号の規則は、正規形に限っても偽である。 -/
theorem no_eq_of_semCovers :
    ¬ (∀ e f : GEff Atom, e.Canonical → f.Canonical → SemCovers e f → SemCovers f e → e = f) := by
  intro h
  exact semCovers_not_eq.2.2.1 (h _ _ wide_canonical top_canonical wide_covers_top top_covers_wide)

end SemanticExample

/-! ## 非空の例 -/

open RepresentationExamples in
#guard (embI.lift (Eff.single "File.Read")).atoms (.name "File.Read" .top)
open RepresentationExamples in
#guard !(embI.lift (Eff.single "File.Read")).atoms (.name "File.Read" CandidateI.dataA)

end Benitoite.Scope.CompatExamples
