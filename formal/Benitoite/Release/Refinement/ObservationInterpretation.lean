import Benitoite.Release.Refinement.RefinementObservation

namespace Benitoite.Release.Refinement

mutual
  theorem Term.observe_rename_model (t : Term) (f : Nat → Nat) (η : ObservationEnvModel) :
      ((termBind? (fun i => some (.var (f i))) t).getD (.integer 0)).observe η =
        t.observe (fun i => η (f i)) := by
    cases t <;> simp only [termBind?,Option.getD_some,Term.observe]
    all_goals first | rfl | simp only [Term.observe_rename_model,observeSlots_rename_model]
  theorem observeSlots_rename_model (xs : List (Option Term)) (f : Nat → Nat) (η : ObservationEnvModel) :
      observeSlots η (bindSlots (fun i => some (.var (f i))) xs) = observeSlots (fun i => η (f i)) xs := by
    cases xs with
    | nil => rfl
    | cons x xs => cases x with
      | none => simp only [bindSlots,slotBind,observeSlots]; rw [observeSlots_rename_model]
      | some t =>
        simp only [bindSlots,slotBind,termBind?_renaming,observeSlots]
        simp only [termBind]
        rw [Term.observe_rename_model,observeSlots_rename_model]
end

theorem Term.interpret_rename_model (t : Term) (f : Nat → Nat) (η : ObservationEnvModel) :
    ((termBind? (fun i => some (.var (f i))) t).getD (.integer 0)).interpret η =
      t.interpret (fun i => η (f i)) := by
  cases t <;> simp only [termBind?,Option.getD_some,Term.interpret]
  all_goals first | rfl | simp only [Term.interpret_rename_model,observeSlots_rename_model]

theorem Pred.interpret_rename_model (p : Pred) (f : Nat → Nat) (η : ObservationEnvModel) :
    (predBind (fun i => some (.var (f i))) p).interpret η = p.interpret (fun i => η (f i)) := by
  cases p with
  | and p q | or p q => simp only [predBind,Pred.interpret,Pred.interpret_rename_model]
  | not p => simp only [predBind,Pred.interpret,Pred.interpret_rename_model]
  | _ => simp only [predBind,Pred.interpret,Pred.atomValue,integerAs,observeAs,termBind,Term.interpret_rename_model] <;> rfl

theorem Pred.interpret_lift_self (p : Pred) (η : ObservationEnvModel) (v : Val) :
    p.lift.interpret (selfModel η v) = p.interpret η := by
  simpa only [Pred.lift,Pred.shiftV,shiftIndex,Nat.not_lt_zero,↓reduceIte,Nat.add_comm,selfModel]
    using p.interpret_rename_model (fun i => i+1) (selfModel η v)

end Benitoite.Release.Refinement
