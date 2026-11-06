import Benitoite.Release.Refinement.Surface.Check

/-! 検査した結果の型と効果は、全ての子の Fail の一意性と署名の行の条件を満たす。 -/
namespace Benitoite.Release.Refinement.Surface.Check

private theorem resultGuard_sound {q rows a ε}
    (ha : a.Support (· ∈ q.formation.atoms)) (he : ε.Support (· ∈ q.formation.atoms))
    (h : resultGuard q rows a ε = true) :
    SingleTy (CheckAdmissible.NoFailCtxOf rows) a ∧ SingleEff (CheckAdmissible.NoFailCtxOf rows) ε := by
  have hh := Bool.and_eq_true_iff.mp h
  exact ⟨(CheckSingle.singleTyCheck_spec a ha).mp hh.1, (CheckSingle.singleEffCheck_spec ε he).mp hh.2⟩

theorem checkExprAt_single {q rows Δ C Γ Φ R p path e a ε g}
    (ha : a.Support (· ∈ q.formation.atoms)) (he : ε.Support (· ∈ q.formation.atoms))
    (h : checkExprAt q rows Δ C Γ Φ R p path e a ε g = true) :
    SingleTy (CheckAdmissible.NoFailCtxOf rows) a ∧ SingleEff (CheckAdmissible.NoFailCtxOf rows) ε := by
  unfold checkExprAt at h
  exact resultGuard_sound ha he (Bool.and_eq_true_iff.mp h).1

theorem checkBlockAt_single {q rows Δ C Γ Φ R p path body a ε g}
    (ha : a.Support (· ∈ q.formation.atoms)) (he : ε.Support (· ∈ q.formation.atoms))
    (h : checkBlockAt q rows Δ C Γ Φ R p path body a ε g = true) :
    SingleTy (CheckAdmissible.NoFailCtxOf rows) a ∧ SingleEff (CheckAdmissible.NoFailCtxOf rows) ε := by
  unfold checkBlockAt at h
  exact resultGuard_sound ha he (Bool.and_eq_true_iff.mp h).1

end Benitoite.Release.Refinement.Surface.Check
