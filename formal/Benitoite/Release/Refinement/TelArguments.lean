import Benitoite.Release.Refinement.Telescope

namespace Benitoite.Release.Refinement

/-- 各引数の型と最終契約を、先行する実引数で順に具体化する。 -/
noncomputable def Tel.arguments : Tel → List Val → Option (List Ty × Ty × Eff)
  | .done r e, [] => some ([], r.norm, Eff.norm e)
  | .param _ a t, v :: vs =>
      (Tel.arguments (Tel.bind (Tel.argumentsEnv v) t) vs).map fun (as, r, e) => (a.norm :: as, r, e)
  | _, _ => none
termination_by _ vs => vs.length

end Benitoite.Release.Refinement
