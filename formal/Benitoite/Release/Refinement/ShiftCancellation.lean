import Benitoite.Release.Refinement.ValueClosed

namespace Benitoite.Release.Refinement

private theorem up_cancels {σ : ObservationEnv} {k c : Nat}
    (h : ∀ i, σ (shiftIndex k c i) = some (.var i)) :
    ∀ i, upValues σ (shiftIndex k (c+1) i) = some (.var i) := by
  intro i
  cases i with
  | zero => simp [shiftIndex, upValues]
  | succ i =>
    have he : shiftIndex k (c+1) (i+1) = shiftIndex k c i + 1 := by
      unfold shiftIndex; split <;> split <;> simp_all <;> omega
    rw [he]
    simp only [upValues, h, Option.map_some, termBind_var, Option.getD_some]

theorem Pred.bind_shift_cancel (p : Pred) {σ : ObservationEnv} {k c : Nat}
    (h : ∀ i, σ (shiftIndex k c i) = some (.var i)) :
    predBind σ (p.shiftV k c) = p := by
  rw [Pred.shiftV, predBind_comp]
  have he : (fun i => (some (.var (shiftIndex k c i))).bind (termBind? σ)) =
      (fun i => some (.var i)) := by
    funext i
    simpa only [Option.bind_some, termBind?] using h i
  rw [he, predBind_id]

mutual
  theorem Ty.substV_shift_cancel (a : Ty) {σ : ObservationEnv} {k c : Nat}
      (h : ∀ i, σ (shiftIndex k c i) = some (.var i)) :
      (a.shiftV k c).rawSubstV σ = a := by
    cases a <;> simp only [Ty.shiftV, Ty.rawSubstV, Ty.substV_shift_cancel _ h,
      substVTys_shift_cancel _ h, Eff.substV_shift_cancel _ h, Tel.substV_shift_cancel _ h]
    case refined a p =>
      congr 1
      exact Pred.bind_shift_cancel p (up_cancels h)
  theorem substVTys_shift_cancel (as : List Ty) {σ : ObservationEnv} {k c : Nat}
      (h : ∀ i, σ (shiftIndex k c i) = some (.var i)) :
      substVTys σ (shiftVTys k c as) = as := by
    cases as <;> simp only [shiftVTys, substVTys, Ty.substV_shift_cancel _ h, substVTys_shift_cancel _ h]
  theorem Tel.substV_shift_cancel (t : Tel) {σ : ObservationEnv} {k c : Nat}
      (h : ∀ i, σ (shiftIndex k c i) = some (.var i)) :
      Tel.rawSubstV σ (t.shiftV k c) = t := by
    cases t with
    | done r e => simp only [Tel.shiftV, Tel.rawSubstV, Ty.substV_shift_cancel _ h, Eff.substV_shift_cancel _ h]
    | param n a t => simp only [Tel.shiftV, Tel.rawSubstV, Ty.substV_shift_cancel _ h,
        Tel.substV_shift_cancel _ (up_cancels h)]
  theorem Eff.substV_shift_cancel (e : Eff) {σ : ObservationEnv} {k c : Nat}
      (h : ∀ i, σ (shiftIndex k c i) = some (.var i)) :
      Eff.rawSubstV σ (e.shiftV k c) = e := by
    cases e; simp only [Eff.shiftV, Eff.rawSubstV, substVTys_shift_cancel _ h]
end

def dropValue (t : Term) : ObservationEnv
  | 0 => some t
  | i+1 => some (.var i)

theorem dropValue_shift (t : Term) (i : Nat) : dropValue t (shiftIndex 1 0 i) = some (.var i) := rfl

end Benitoite.Release.Refinement
