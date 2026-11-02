import Benitoite.Release.Refinement.CertificateKernelBind

/-! # 整数の床丸めと分枝の被覆 -/
namespace Benitoite.Release.Refinement

def keyEnv (η : ObservationEnvModel) (keys : List Term) : Nat → Int :=
  fun i => integerAs η (keys[i]?.getD (.integer 0))

theorem linearTerm_integerAs (η : ObservationEnvModel) (keys : List Term) (cs : List Int)
    (h : keys.length = cs.length) :
    integerAs η (linearTerm keys cs) = linearDot cs (keyEnv η keys) := by
  induction keys generalizing cs with
  | nil => cases cs <;> simp_all [linearTerm, linearDot, integerAs_eq_integerD,
      Term.interpret, Observation.integerD]
  | cons k ks ih =>
    cases cs with
    | nil => simp at h
    | cons c cs =>
      simp only [List.length_cons, Nat.add_right_cancel_iff] at h
      rw [linearTerm]
      have ha := integerAs_bind_add η (fun i => some (.var i)) (.scale c k) (linearTerm ks cs)
      have hc := integerAs_bind_scale η (fun i => some (.var i)) c k
      simp only [termBind_id] at ha hc
      rw [ha, hc, ih cs h]
      rfl

theorem Linear.toPred_sound (η : ObservationEnvModel) (keys : List Term) (l : Linear)
    (h : keys.length = l.coefficients.length) :
    (l.toPred keys).interpret η = true ↔ l.Holds (keyEnv η keys) := by
  simp only [Linear.toPred, Pred.interpret, Pred.atomValue, decide_eq_true_eq,
    linearTerm_integerAs η keys l.coefficients h, Linear.Holds, Linear.eval]
  rfl

theorem Linear.toPred_sound_at (η : ObservationEnvModel) (ν : ObservationEnv)
    (keys : List Term) (l : Linear) (h : keys.length = l.coefficients.length) :
    (predBind ν (l.toPred keys)).interpret η = true ↔
      l.Holds (keyEnv η (keys.map (termBind ν))) := by
  rw [l.encode_bind]
  exact l.toPred_sound η _ (by simpa using h)

theorem integer_round {x b d : Int} (hd : 0 < d) (h : d*x ≤ b) : x ≤ b/d :=
  (Int.le_ediv_iff_mul_le hd).mpr (by simpa only [Int.mul_comm] using h)

theorem linearDot_scale (d : Int) (cs : List Int) (ρ : Nat → Int) :
    linearDot (cs.map (d * ·)) ρ = d * linearDot cs ρ := by
  induction cs generalizing ρ with
  | nil => simp [linearDot]
  | cons c cs ih => simp only [List.map_cons, linearDot, ih, Int.mul_add, Int.mul_assoc]

theorem Linear.round_sound {source result : Linear} (d : Int) (ρ : Nat → Int)
    (hd : 0 < d) (hc : source.coefficients = result.coefficients.map (d * ·))
    (hb : result.bound = source.bound / d) (h : source.Holds ρ) : result.Holds ρ := by
  change linearDot source.coefficients ρ ≤ source.bound at h
  rw [hc, linearDot_scale] at h
  change linearDot result.coefficients ρ ≤ result.bound
  rw [hb]
  exact integer_round hd h

theorem integer_split (x cut : Int) : x ≤ cut ∨ cut+1 ≤ x := by omega

theorem integer_split_refute {x cut : Int}
    (left : x ≤ cut → False) (right : cut+1 ≤ x → False) : False := by
  rcases integer_split x cut with h | h
  · exact left h
  · exact right h

theorem integer_combination {x y b c k l : Int} (hk : 0 ≤ k) (hl : 0 ≤ l)
    (hx : x ≤ b) (hy : y ≤ c) : k*x+l*y ≤ k*b+l*c :=
  Int.add_le_add (Int.mul_le_mul_of_nonneg_left hx hk) (Int.mul_le_mul_of_nonneg_left hy hl)

theorem integerAs_round_at (η : ObservationEnvModel) (ν : ObservationEnv)
    (t : Term) {b d : Int} (hd : 0 < d)
    (h : integerAs η (termBind ν (.scale d t)) ≤ b) :
    integerAs η (termBind ν t) ≤ b/d := by
  rw [integerAs_bind_scale] at h
  exact integer_round hd h

theorem integerAs_split_at (η : ObservationEnvModel) (ν : ObservationEnv) (t : Term) (cut : Int) :
    integerAs η (termBind ν t) ≤ cut ∨ cut+1 ≤ integerAs η (termBind ν t) :=
  integer_split _ cut

end Benitoite.Release.Refinement
