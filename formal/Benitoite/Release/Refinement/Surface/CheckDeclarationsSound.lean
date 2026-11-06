import Benitoite.Release.Refinement.Surface.CheckDeclarations
import Benitoite.Release.Refinement.Surface.CheckSound

/-! 関数・実装の検査の成功は、表層の定義の型付けと実名の契約を導く。 -/
namespace Benitoite.Release.Refinement.Surface.CheckDeclarations

private theorem bodyChecker_sound : BlockCheckerSound bodyChecker := by
  intro q rows C Γ Φ path body a e hq hΓ hb ha he hg h
  exact Check.checkBlockAt_sound hq (by intro i k h; cases i <;> cases h)
    hΓ ha hb ha he hg h

theorem checkDef_sound {q path d} (hq : q.Sound) (hd : DefSupport q d) (hg : GuideTableSupport q)
    (h : checkDef q path d = .ok ()) : d.WellTyped q.D q.B q.opPrim := by
  change (Except.bind (Check.require path "proof step limit must be positive"
    (match d.proofSteps with | none => true | some n => decide (0 < n)))
    (fun _ => checkDefWith bodyChecker (definitionInput q d) path d)) = .ok () at h
  cases hv : Check.require path "proof step limit must be positive"
      (match d.proofSteps with | none => true | some n => decide (0 < n)) with
  | error e => simp only [hv, Except.bind] at h; cases h
  | ok value =>
    have hc : checkDefWith bodyChecker (definitionInput q d) path d = .ok () := by
      simpa only [hv, Except.bind] using h
    exact checkDefWith_sound (q := definitionInput q d) bodyChecker_sound (hq.withProofSteps (d.proofSteps.getD q.proofSteps)) ⟨hd.signature, hd.body⟩ hg hc

theorem checkImpl_sound {q i path id views} (hq : q.Sound) (hi : ImplSupport q id)
    (hn : ImplNamesComplete q id) (hg : GuideTableSupport q)
    (hsg : ∀ s, (q.superGuides i s).Support q.formation.atoms)
    (h : checkImpl q i path id views = .ok ()) : id.WellTyped q.D q.B q.opPrim views :=
  checkImplWith_sound bodyChecker_sound hq hi hn hg hsg h

theorem checkImpl_contracts {q i path id views} (hn : ImplNamesComplete q id)
    (h : checkImpl q i path id views = .ok ()) : ContractsMatch q i id :=
  checkImplWith_contracts hn h

end Benitoite.Release.Refinement.Surface.CheckDeclarations
