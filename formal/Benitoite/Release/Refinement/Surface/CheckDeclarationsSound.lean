import Benitoite.Release.Refinement.Surface.CheckDeclarations
import Benitoite.Release.Refinement.Surface.CheckSound

/-! 関数・実装の検査の成功は、表層の定義の型付けと実名の契約を導く。 -/
namespace Benitoite.Release.Refinement.Surface.CheckDeclarations

private theorem bodyChecker_sound : BlockCheckerSound bodyChecker := by
  intro q rows C Γ Φ path body a e hq hΓ hb ha he h
  cases hs : (CheckInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e).toCheck with
  | error err => simp only [bodyChecker, bodyResult, hs, Except.toBool] at h; cases h
  | ok result =>
    have hc : Check.checkBlockAt q rows [] C Γ Φ (some a) .tail path body a e
        (CheckFinite.guide q.formation.atoms result.guide) = true := by
      by_cases hc : Check.checkBlockAt q rows [] C Γ Φ (some a) .tail path body a e
          (CheckFinite.guide q.formation.atoms result.guide) = true
      · exact hc
      · simp [bodyChecker, bodyResult, hs, hc, Except.toBool] at h
    exact Check.checkBlockAt_sound hq (by intro i k h; cases i <;> cases h)
      hΓ ha hb ha he (CheckFinite.guide_support _ _) hc

theorem checkDef_sound {q path d} (hq : q.Sound) (hd : DefSupport q d)
    (h : checkDef q path d = .ok ()) : d.WellTyped q.D q.B q.opPrim := by
  exact checkDefWith_sound (q := definitionInput q d) bodyChecker_sound
    (hq.withProofSteps (d.proofSteps.getD q.proofSteps)) ⟨hd.signature, hd.body⟩ (checkDef_ok h)

theorem checkImpl_sound {q i path id views} (hq : q.Sound) (hi : ImplSupport q id)
    (hn : ImplNamesComplete q id)
    (h : checkImpl q i path id views = .ok ()) : id.WellTyped q.D q.B q.opPrim views :=
  checkImplWith_sound bodyChecker_sound hq hi hn (checkImpl_ok h)

theorem checkImpl_contracts {q i path id views} (hn : ImplNamesComplete q id)
    (h : checkImpl q i path id views = .ok ()) : ContractsMatch q i id :=
  checkImplWith_contracts hn (checkImpl_ok h)

end Benitoite.Release.Refinement.Surface.CheckDeclarations
