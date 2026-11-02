import Benitoite.Release.Refinement.CertificateKernelBind
import Benitoite.Release.Refinement.TermStructuralEq
import Benitoite.Release.Refinement.EqualityMode

/-! # 構造の一致と整数射影の等号の有限な証拠 -/
namespace Benitoite.Release.Refinement

inductive EqProof where
  | refl
  | symm (proof : EqProof)
  | trans (middle : Term) (left right : EqProof)
  | add (left right : EqProof)
  | neg (proof : EqProof)
  | scale (coefficient : Int) (proof : EqProof)
  | hyp (index : Nat)
  | field (proof : EqProof)
  | measure (proof : EqProof)

def EqProof.checkRaw (Φ : List Pred) (mode : EqualityMode) (t u : Term) : EqProof → Bool
  | .refl => termEq t u
  | .symm c => c.checkRaw Φ mode u t
  | .trans m l r => l.checkRaw Φ mode t m && r.checkRaw Φ mode m u
  | .add l r => match t,u with
    | .add a b, .add c d => l.checkRaw Φ mode a c && r.checkRaw Φ mode b d
    | _,_ => false
  | .neg c => match mode,t,u with
    | .integer, .neg a, .neg b => c.checkRaw Φ .integer a b
    | _,_,_ => false
  | .scale k c => match mode,t,u with
    | .integer, .scale m a, .scale n b => decide (k = m ∧ k = n) && c.checkRaw Φ .integer a b
    | _,_,_ => false
  | .hyp i => match mode,Φ[i]? with
    | .integer, some (.eq a b) => termEq t a && termEq u b
    | _,_ => false
  | .field c => match t,u with
    | .field r a, .field s b => decide (r = s) && c.checkRaw Φ .structural a b
    | _,_ => false
  | .measure c => match t,u with
    | .measure m a, .measure n b => decide (m = n) && c.checkRaw Φ .structural a b
    | _,_ => false

theorem EqProof.structural_sound {Φ : List Pred} {t u : Term} {c : EqProof}
    (h : EqProof.checkRaw Φ .structural t u c = true) : t = u := by
  induction c generalizing t u with
  | refl => exact (termEq_spec t u).mp h
  | symm c ih => exact (ih h).symm
  | trans m l r ihl ihr =>
    simp only [checkRaw, Bool.and_eq_true] at h
    exact (ihl h.1).trans (ihr h.2)
  | add l r ihl ihr =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    rename_i a b c d
    simp only [Bool.and_eq_true] at h
    rw [ihl h.1, ihr h.2]
  | neg c ih | scale k c ih | hyp i => simp [checkRaw] at h
  | field c ih | measure c ih =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    all_goals
      simp only [Bool.and_eq_true, decide_eq_true_eq] at h
      rw [h.1, ih h.2]

theorem EqProof.integer_sound_at {Φ : List Pred} {t u : Term} {c : EqProof}
    (h : EqProof.checkRaw Φ .integer t u c = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
    integerAs η (termBind ν t) = integerAs η (termBind ν u) := by
  induction c generalizing t u with
  | refl => rw [(termEq_spec t u).mp h]
  | symm c ih => exact (ih h).symm
  | trans m l r ihl ihr =>
    simp only [checkRaw, Bool.and_eq_true] at h
    exact (ihl h.1).trans (ihr h.2)
  | add l r ihl ihr =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    rename_i a b c d
    simp only [Bool.and_eq_true] at h
    rw [integerAs_bind_add, integerAs_bind_add, ihl h.1, ihr h.2]
  | neg c ih =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    rw [integerAs_bind_neg, integerAs_bind_neg, ih h]
  | scale k c ih =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    rename_i m a n b
    simp only [Bool.and_eq_true, decide_eq_true_eq] at h
    rw [← h.1.1, ← h.1.2, integerAs_bind_scale, integerAs_bind_scale, ih h.2]
  | hyp i =>
    simp only [checkRaw] at h
    split at h
    · rename_i a b hi
      simp only [Bool.and_eq_true, termEq_spec] at h
      rcases h with ⟨rfl,rfl⟩
      have he := facts _ (List.mem_of_getElem? hi)
      simpa only [predBind, Pred.interpret, Pred.atomValue, decide_eq_true_eq] using he
    · cases h
  | field c ih | measure c ih =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    all_goals
      simp only [Bool.and_eq_true, decide_eq_true_eq] at h
      rw [h.1, structural_sound h.2]

def EqProof.check (t u : Term) (c : EqProof) : Bool := c.checkRaw [] .structural t u

theorem EqProof.sound {t u : Term} {c : EqProof} (h : EqProof.check t u c = true) : t = u :=
  structural_sound h

end Benitoite.Release.Refinement
