import Benitoite.Release.Refinement.AtInput
import Benitoite.Release.Refinement.ClosedEvaluation

/-! # String の所属の閉じた評価

文字列の対象と解析済みの対象を区別し、At と同じ解析を使う。 -/
namespace Benitoite.Release.Refinement
open Scope.Domain

/-- 起点なしで解決できる整形式の範囲では、任意の String の所属を真偽まで評価できる。 -/
theorem Pred.evalClosed_stringMember {k : Kind} {r : RangeExpr}
    (hk : k = .path ∨ k = .host) (hw : r.WF) (hf : r.FitsKind k)
    (hr : (resolveSnapshot none r).isSome = true) (s : String) :
    (Pred.member k (.string s) r).evalClosed = some (stringMember k r s) := by
  simp [Pred.evalClosed, Pred.WF, Pred.VarsIn, Pred.Sorted, Term.HasSort,
    Term.References, Term.VarsIn, Term.Shape, hk, Pred.evalWith, Pred.atomReady,
    memberReady, Term.observe, hw, hf, hr, Pred.atomValue, Term.interpret]

/-- 絶対形のパスの任意の文字列の対象に同じ解析を当てる。 -/
example {p : PathPattern} (hw : p.WF) (s : String) :
    (Pred.member .path (.string s) (.path p)).evalClosed = some (stringMember .path (.path p) s) :=
  Pred.evalClosed_stringMember (k := .path) (r := .path p) (Or.inl rfl) hw
    (by simp [RangeExpr.FitsKind, Range.FitsKind, Range.kind?]) rfl s

/-- ホストの任意の文字列の対象に同じ解析を当てる。 -/
example {p : HostPattern} (hw : p.WF) (s : String) :
    (Pred.member .host (.string s) (.host p)).evalClosed = some (stringMember .host (.host p) s) :=
  Pred.evalClosed_stringMember (k := .host) (r := .host p) (Or.inr rfl) hw
    (by simp [RangeExpr.FitsKind, Range.FitsKind, Range.kind?]) rfl s

/-- 受理、範囲外、相対形、解析失敗をそれぞれ観測する。 -/
theorem string_path_cases :
    (Pred.member .path (.string "/") (.path (.exact []))).evalClosed = some true ∧
    (Pred.member .path (.string "/x") (.path (.exact []))).evalClosed = some false ∧
    (Pred.member .path (.string "x") (.path (.tree []))).evalClosed = some false ∧
    (Pred.member .path (.string "/a/../b") (.path (.tree []))).evalClosed = some false := by
  simp +decide [Pred.evalClosed, Pred.evalWith, Pred.atomValue, Term.interpret,
    stringMember, parseTargetInput, splitText, splitChars, PathWordWF]

end Benitoite.Release.Refinement
