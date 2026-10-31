import Benitoite.Release.Refinement.ShiftOrder
import Benitoite.Release.Refinement.Bind

namespace Benitoite.Release.Refinement

theorem Ty.bind_up (a : Ty) (θ : SubstEnv) :
    (a.shiftV 1 0).bind θ.up = (a.bind θ).shiftV 1 0 := by
  simp only [Ty.bind, Ty.rawBind_up, Ty.norm_shiftV]
theorem Tel.bind_up (t : Tel) (θ : SubstEnv) :
    Tel.bind θ.up (Tel.shiftV 1 0 t) = Tel.shiftV 1 0 (Tel.bind θ t) := by
  simp only [Tel.bind, Tel.rawBind_up, Tel.norm_shiftV]
theorem Eff.bind_up (e : Eff) (θ : SubstEnv) :
    Eff.bind θ.up (Eff.shiftV 1 0 e) = Eff.shiftV 1 0 (Eff.bind θ e) := by
  simp only [Eff.bind, Eff.rawBind_up, Eff.norm_shiftV]

end Benitoite.Release.Refinement
