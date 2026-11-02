import Benitoite.Release.Refinement.Observation

namespace Benitoite.Release.Refinement

/-- 正常なmeasure結果は有限な個数又は文字コードである。 -/
theorem Observation.measure_nonnegative {m o n} (h : Observation.measure m o = some (.integer n)) :
    0 ≤ n := by
  cases m <;> cases o <;> simp_all [Observation.measure]
  all_goals first | omega | skip
  case bytesLength.bytesValue bs => split at h <;> simp_all <;> omega
  case mapSize.mapValue ks vs => cases he : mapKeys ks vs <;> simp_all <;> omega
  case setSize.setValue xs => cases he : keySetCodes xs [] <;> simp_all <;> omega

end Benitoite.Release.Refinement
