import Benitoite.Release.Refinement.Surface.CheckEntrypoints
import Benitoite.Release.Refinement.Surface.CheckSound
import Benitoite.Release.Refinement.Surface.CheckResultSound

/-! 公開入口の成功は、表層の型付けと Fail・署名の行の条件を同時に導く。 -/
namespace Benitoite.Release.Refinement.Surface.Check

/-- 式の実入口の成功から、型付けと受理に使う型・効果の条件を得る。 -/
theorem checkExpr_sound {q C Γ Φ R p path e a ε} (hq : q.Sound)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ) (hR : ReturnSupport q.formation.atoms R)
    (hs : ExprSupport q e) (ha : a.Support (· ∈ q.formation.atoms)) (he : ε.Support (· ∈ q.formation.atoms))
    (hg : (q.guide path).Support q.formation.atoms) (h : checkExpr q C Γ Φ R p path e = .ok (a, ε)) :
    HasTypeQ q.D q.B q.opPrim Qempty [] C Γ Φ R p e a ε ∧ SingleTy Qempty a ∧ SingleEff Qempty ε := by
  have hc := checkExpr_ok h
  have ht := checkExprAt_sound hq (by intro i k h; cases i <;> cases h) hΓ hR hs ha he hg hc
  have hf := checkExprAt_single ha he hc
  exact ⟨by simpa only [CheckAdmissible.NoFailCtxOf_nil] using ht,
    by simpa only [CheckAdmissible.NoFailCtxOf_nil] using hf⟩

theorem checkBlock_sound {q C Γ Φ R p path body a ε} (hq : q.Sound)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ) (hR : ReturnSupport q.formation.atoms R)
    (hs : BlockSupport q body) (ha : a.Support (· ∈ q.formation.atoms)) (he : ε.Support (· ∈ q.formation.atoms))
    (hg : (q.guide path).Support q.formation.atoms) (h : checkBlock q C Γ Φ R p path body = .ok (a, ε)) :
    HasBlockQ q.D q.B q.opPrim Qempty [] C Γ Φ R p body a ε ∧ SingleTy Qempty a ∧ SingleEff Qempty ε := by
  have hc := checkBlock_ok h
  have ht := checkBlockAt_sound hq (by intro i k h; cases i <;> cases h) hΓ hR hs ha he hg hc
  have hf := checkBlockAt_single ha he hc
  exact ⟨by simpa only [CheckAdmissible.NoFailCtxOf_nil] using ht,
    by simpa only [CheckAdmissible.NoFailCtxOf_nil] using hf⟩

end Benitoite.Release.Refinement.Surface.Check
