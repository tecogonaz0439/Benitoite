import Benitoite.Release.Refinement.CoverageRefinement
namespace Benitoite.Release.Refinement
noncomputable section

/-! V_Refine の閉じた場合: 開いた述語の解釈と selfModel の一致。G09 の入口が閉じる形かを確かめる。 -/
theorem termBind?_total (ν : ObservationEnv) (h : ∀ i, (ν i).isSome) (x : Term) :
    ∃ y, termBind? ν x = some y := by
  cases x <;> simp [termBind?]
  exact Option.isSome_iff_exists.mp (h _)

mutual
  theorem observe_bind (ν : ObservationEnv) (η ξ : ObservationEnvModel) (ht : ∀ i, (ν i).isSome)
      (hv : ∀ i, ξ i = (ν i).bind (Term.observe η)) (x : Term) :
      (termBind ν x).observe η = x.observe ξ := by
    cases x <;> simp only [termBind_var,termBind_field,termBind_measure,termBind_add,termBind_neg,termBind_scale,
      termBind_listValue,termBind_mapValue,termBind_setValue,termBind_dataValue,termBind_integer,termBind_character,
      termBind_float64,termBind_float32,termBind_decimal,termBind_boolean,termBind_unitValue,termBind_string,
      termBind_bytesValue,termBind_targetValue,Term.observe]
    case var i =>
      obtain ⟨u,hu⟩ := Option.isSome_iff_exists.mp (ht i)
      simp [hu,hv i]
    all_goals first
      | (simp only [observe_bind ν η ξ ht hv]; done)
      | (simp only [observeSlots_bind ν η ξ ht hv]; done)
      | rfl
  theorem observeSlots_bind (ν : ObservationEnv) (η ξ : ObservationEnvModel) (ht : ∀ i, (ν i).isSome)
      (hv : ∀ i, ξ i = (ν i).bind (Term.observe η)) (xs : List (Option Term)) :
      observeSlots η (bindSlots ν xs) = observeSlots ξ xs := by
    cases xs with
    | nil => rfl
    | cons x xs => cases x with
      | none => simp only [bindSlots,slotBind,observeSlots]; rw [observeSlots_bind ν η ξ ht hv]
      | some t =>
        obtain ⟨y,hy⟩ := termBind?_total ν ht t
        have := observe_bind ν η ξ ht hv t
        simp only [termBind,hy,Option.getD_some] at this
        simp only [bindSlots,slotBind,hy,observeSlots,this]
        rw [observeSlots_bind ν η ξ ht hv]
end

theorem interpret_bind (ν : ObservationEnv) (η ξ : ObservationEnvModel) (ht : ∀ i, (ν i).isSome)
    (hv : ∀ i, ξ i = (ν i).bind (Term.observe η))
    (hi : ∀ i u, ν i = some u → u.interpret η = u.observe η) (x : Term) :
    (termBind ν x).interpret η = x.interpret ξ := by
  cases x <;> simp only [termBind_var,termBind_field,termBind_measure,termBind_add,termBind_neg,termBind_scale,
      termBind_listValue,termBind_mapValue,termBind_setValue,termBind_dataValue,termBind_integer,termBind_character,
      termBind_float64,termBind_float32,termBind_decimal,termBind_boolean,termBind_unitValue,termBind_string,
      termBind_bytesValue,termBind_targetValue,Term.interpret]
  case var i =>
    obtain ⟨u,hu⟩ := Option.isSome_iff_exists.mp (ht i)
    simp [hu,hv i,hi i u hu]
  all_goals first
    | (simp only [interpret_bind ν η ξ ht hv hi]; done)
    | (simp only [observeSlots_bind ν η ξ ht hv]; done)
    | rfl

theorem pred_interpret_bind (ν : ObservationEnv) (η ξ : ObservationEnvModel) (ht : ∀ i, (ν i).isSome)
    (hv : ∀ i, ξ i = (ν i).bind (Term.observe η))
    (hi : ∀ i u, ν i = some u → u.interpret η = u.observe η) (p : Pred) :
    (predBind ν p).interpret η = p.interpret ξ := by
  cases p with
  | and p q | or p q => simp only [predBind,Pred.interpret,pred_interpret_bind ν η ξ ht hv hi]
  | not p => simp only [predBind,Pred.interpret,pred_interpret_bind ν η ξ ht hv hi]
  | _ => simp only [predBind,Pred.interpret,Pred.atomValue,integerAs,observeAs,interpret_bind ν η ξ ht hv hi] <;> rfl

/-- 閉じた値項について、V_Refine の開いた述語と意味の self の解釈が一致する。 -/
theorem open_interpret_self (p : Pred) (v : Val) (t : Term) (η : ObservationEnvModel)
    (ht : v.toTerm? = some t) (hc : t.Closed) (hti : t.interpret η = t.observe η) :
    (p.open t).interpret η = p.interpret (selfModel η v) := by
  have hself : selfObservation v = t.observe η := by
    simp only [selfObservation,ht,Option.bind_some]
    exact (Term.observe_closed hc η).symm
  apply pred_interpret_bind (openingEnv (some t)) η (selfModel η v)
  · intro i; cases i <;> rfl
  · intro i; cases i with
    | zero => simpa [openingEnv,selfModel] using hself
    | succ i => simp [openingEnv,selfModel,Term.observe]
  · intro i u hu; cases i with
    | zero => cases hu; exact hti
    | succ i => cases hu; rfl

/-- V_Refine の閉じた場合の意味の真。 -/
theorem closed_refine_true {p : Pred} {v t} (η : ObservationEnvModel)
    (ht : v.toTerm? = some t) (hc : t.Closed) (hti : t.interpret η = t.observe η)
    (he : Entails [] (p.open t)) : p.interpret (selfModel η v) = true := by
  rw [←open_interpret_self p v t η ht hc hti]
  exact he.sound η (by intro q hq; cases hq)

/-- 値から作る項は計算の項を含まず、解釈と観測が一致する。 -/
theorem toTerm_interpret {v : Val} {t : Term} (η : ObservationEnvModel) (h : v.toTerm? = some t) :
    t.interpret η = t.observe η := by
  cases v
  case const c =>
    cases c <;> first
      | (simp only [Val.toTerm?,reduceCtorEq] at h; done)
      | (simp only [Val.toTerm?] at h; obtain rfl := Option.some.inj h; rfl)
  all_goals first
    | (simp only [Val.toTerm?,reduceCtorEq] at h; done)
    | (simp only [Val.toTerm?] at h; obtain rfl := Option.some.inj h; rfl)

end
end Benitoite.Release.Refinement

#print axioms Benitoite.Release.Refinement.closed_refine_true
#print axioms Benitoite.Release.Refinement.toTerm_interpret
