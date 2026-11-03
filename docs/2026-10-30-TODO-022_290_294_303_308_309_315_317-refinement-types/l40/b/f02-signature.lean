import Benitoite
namespace Benitoite.Release.Refinement.F02Signature

-- 固定した全前提から、少ない前提で証明した本番の結論を得る。
example {P B Ψ Q C Γ Φ t u ws a e}
    (_hP : P.WellFormed) (_hB : B.CoreAssumptions P) (_hw : Ψ.WF)
    (hΓ : Ctx.WF 0 C.length Γ)
    (ht : Ty.Annotation P C Γ (.dependentFn t))
    (_hu : Ty.Annotation P C Γ (.dependentFn u))
    (h : TelClosure P Γ Φ t u)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e) :
    ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f :=
  h.apply hΓ ht args

end Benitoite.Release.Refinement.F02Signature
