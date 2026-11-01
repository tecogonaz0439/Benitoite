import Benitoite.Release.Refinement.ObservationOrder
import Benitoite.Release.Refinement.Subst

namespace Benitoite.Release.Refinement

noncomputable def selfObservation (v : Val) : Option Observation :=
  v.toTerm?.bind (Term.observe (fun _ => none))
noncomputable def selfModel (η : ObservationEnvModel) (v : Val) : ObservationEnvModel :=
  fun | 0 => selfObservation v | i+1 => η i
noncomputable def RefinementPossible (p : Pred) (v : Val) : Prop :=
  p.evalWith (selfModel (fun _ => none) v) ≠ some false

end Benitoite.Release.Refinement
