import Lean
import Benitoite
namespace L50DContracts
open Benitoite.Release.Refinement

example {P B σ Ψ R Γ Φ cap kind name bs p v ix snap pat t bound}
    (_hc : CaptureOk P B Ψ R Γ Φ cap) (had : cap.Adequate σ)
    (hb : ∀ b, bs = some b → b.Adequate σ)
    (hp : AtPrepared B cap kind name bs p v ix snap pat t bound) :
    ∀ ρ, snap = some ρ → ρ = σ := hp.current had hb

example (d : AtError) (ws : List Val) : AdequateResult ws (.val (.atError d)) :=
  AtTargets.adequate_atError d ws
end L50DContracts
