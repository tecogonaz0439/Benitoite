import Benitoite.Release.Refinement.HostRangeParams
import Benitoite.Release.Refinement.ScopeSignatures

namespace Benitoite.Release.Refinement
namespace RangeArgumentTrial

/-- 同じ種類の、互いに異なる正規な範囲を使う。 -/
def rootOnly : RangeExpr := .absolute (.path (.exact []))

theorem root_valid : rootOnly.FitsKind .path ∧ rootOnly.WF ∧ rootOnly.Canonical := by
  decide

/-- 閉じた範囲の引数には、呼出し元の範囲変数を代入する場所がない。 -/
theorem no_closed_argument : ¬ ∃ r : RangeExpr,
    ∀ s : RangeExpr, s.FitsKind .path → s.WF → s.Canonical →
      (RangeIx.fixed r).inst [s] = (RangeIx.rvar 0).inst [s] := by
  rintro ⟨r, h⟩
  have ht := h .top (by decide) (by trivial) (by trivial)
  have hr := h rootOnly root_valid.1 root_valid.2.1 root_valid.2.2
  simp only [RangeIx.inst, List.getElem?_cons_zero] at ht hr
  have eq : RangeExpr.top = rootOnly :=
    (RangeIx.fixed.inj ht).symm.trans (RangeIx.fixed.inj hr)
  cases eq

/-- 部分型の被覆を許しても、引数と効果の両方を全具体化へ合わせる固定範囲はない。 -/
theorem no_closed_input_and_effect : ¬ ∃ r : RangeExpr,
    ∀ s : RangeExpr, s.FitsKind .path → s.WF → s.Canonical →
      r.Covers s ∧ s.Covers r := by
  rintro ⟨r, h⟩
  have ht := h .top (by decide) (by trivial) (by trivial)
  have he := (RangeExpr.covers_top_iff r).mp ht.1
  subst r
  have hr := h rootOnly root_valid.1 root_valid.2.1 root_valid.2.2
  have eq := (RangeExpr.covers_top_iff rootOnly).mp hr.2
  cases eq

/-- 範囲変数を受ける署名自身は、両方の具体化を区別できる。 -/
theorem parameter_instantiation (s : RangeExpr) :
    Ty.instR [s] (ScopeSignatures.pathIn 0) = .opaque "Scope.PathIn" (.fixed s) := by
  simp [Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges,
    mapIx, rangeAt, Ty.norm]

#print axioms rootOnly
#print axioms root_valid
#print axioms no_closed_argument
#print axioms no_closed_input_and_effect
#print axioms parameter_instantiation

end RangeArgumentTrial
end Benitoite.Release.Refinement
