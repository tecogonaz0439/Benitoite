import Benitoite.Release.Refinement.PathBasesLeaves

/-! # 発行された起点と At が保持する snapshot の一致 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem AtPrepared.current {B σ cap kind name bs p v ix snap pat t bound}
    (had : cap.Adequate σ)
    (hb : ∀ b, bs = some b → b.Adequate σ)
    (hp : AtPrepared B cap kind name bs p v ix snap pat t bound) :
    ∀ ρ, snap = some ρ → ρ = σ := by
  intro ρ hρ
  obtain ⟨b,hb',hc⟩ := hp.snapshot_source hρ
  have h := closeVal_adequate had (hb b hb')
  rw [hc] at h
  exact h

/-- 同じ状態の適格な閉包から、At の snapshot の一致を取り出す。 -/
theorem StateTyE.at_current {P B σ Eb q k μ kind name shape bs p v ix snap pat t bound}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bs p v ix)
    (hp : AtPrepared B q.capture kind name bs p v ix snap pat t bound) :
    ∀ ρ, snap = some ρ → ρ = σ := by
  obtain ⟨_,_,_,_,_,_,_,_,_,_,had,_⟩ := h
  have hc : q.capture.Adequate σ ∧ q.code.Adequate σ := by cases q; exact had
  have hm := hc.2
  rw [hv,Comp.Adequate.eq_def] at hm
  apply hp.current hc.1
  intro b hb
  cases hb
  exact hm.1

/-- 発行の効果は同じ宣言表の membership から得る。 -/
theorem Builtins.CoreAssumptions.pathBases_membership {P : Program} {B : Builtins} {b : PrimName} {s : PrimSig}
    (h : B.CoreAssumptions P) (hs : B.sig b = some s) (hk : s.kind = .pathBases) :
    s.opEff = some processEnvironmentEff ∧
    ∃ bs, B.effects processEnvironmentEff = some bs ∧ b ∈ bs := by
  have sh := h.pathBases_shape b s hs hk
  exact ⟨sh.operation,sh.membership⟩

example {P B σ Eb q b s k μ}
    (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .issuePathBases b)
    (hs : B.sig b = some s) (hk : s.kind = .pathBases) (hσ : σ.Valid) :
    (∃ bs, B.effects processEnvironmentEff = some bs ∧ b ∈ bs) ∧
    Step P B σ (.run q k μ) (some (.pathBases b σ))
      (.run (Closure.pure (.ret (.pathBases σ))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.pathBases σ))) k μ) := by
  obtain ⟨hop,hmem⟩ := hB.pathBases_membership hs hk
  exact ⟨hmem,h.issue_path_bases_all hv hs hk hop hσ⟩

example {P B σ Eb q b s k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b [] [] []) [])
    (hs : B.sig b = some s) (hk : s.kind = .pathBases) (hnh : NoHandler k (.prim b)) :
    Step P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ) ∧
    StateTyE P B σ Eb (.run (.mk q.capture (.issuePathBases b)) k μ) :=
  h.path_bases_apply_all hP hPB hB hv hs hk hnh

end
end Benitoite.Release.Refinement
