import Benitoite.Release.Refinement.RefinementObservation

namespace Benitoite.Release.Refinement

private theorem fallback_info {o : Option Observation} (u : Option Term) (ξ : ObservationEnvModel)
    (h : Observation.OptionInfoLE o (u.bind (Term.observe ξ))) :
    Observation.OptionInfoLE o ((u.getD (.integer 0)).observe ξ) := by
  cases u with
  | some t => exact h
  | none =>
    cases o with
    | none => exact .none _
    | some o => cases h

mutual
  theorem Term.bind_observe_info (t : Term) (ν : ObservationEnv) (η ξ : ObservationEnvModel)
      (h : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ))) :
      Observation.OptionInfoLE (t.observe η) ((termBind? ν t).bind (Term.observe ξ)) ∧
      Observation.OptionInfoLE (t.observe η) ((termBind ν t).observe ξ) := by
    cases t with
    | var i => exact ⟨h i,fallback_info (ν i) ξ (h i)⟩
    | field r t =>
      have hh := (t.bind_observe_info ν η ξ h).2
      -- field の成功は、受け手の constructor と同じ位置・sort の slot だけを読む。
      have env : ObservationEnvModel.InfoLE
          (fun _ => t.observe η) (fun _ => (termBind ν t).observe ξ) := fun _ => hh
      have hh' := (Term.field r (.var 0)).observe_mono _ _ env
      exact ⟨hh',hh'⟩
    | measure m t =>
      have env : ObservationEnvModel.InfoLE
          (fun _ => t.observe η) (fun _ => (termBind ν t).observe ξ) := fun _ => (t.bind_observe_info ν η ξ h).2
      have hh := (Term.measure m (.var 0)).observe_mono _ _ env
      exact ⟨hh,hh⟩
    | add a b =>
      let η' : ObservationEnvModel := fun | 0 => a.observe η | _ => b.observe η
      let ξ' : ObservationEnvModel := fun | 0 => (termBind ν a).observe ξ | _ => (termBind ν b).observe ξ
      have env : ObservationEnvModel.InfoLE η' ξ' := by
        intro i; cases i
        · exact (a.bind_observe_info ν η ξ h).2
        · exact (b.bind_observe_info ν η ξ h).2
      have hh := (Term.add (.var 0) (.var 1)).observe_mono η' ξ' env
      exact ⟨hh,hh⟩
    | neg a =>
      have env : ObservationEnvModel.InfoLE
          (fun _ => a.observe η) (fun _ => (termBind ν a).observe ξ) := fun _ => (a.bind_observe_info ν η ξ h).2
      have hh := (Term.neg (.var 0)).observe_mono _ _ env
      exact ⟨hh,hh⟩
    | scale c a =>
      have env : ObservationEnvModel.InfoLE
          (fun _ => a.observe η) (fun _ => (termBind ν a).observe ξ) := fun _ => (a.bind_observe_info ν η ξ h).2
      have hh := (Term.scale c (.var 0)).observe_mono _ _ env
      exact ⟨hh,hh⟩
    | listValue xs =>
      have hh := Observation.OptionInfoLE.some (Observation.InfoLE.list (observeSlots_bind_info xs ν η ξ h))
      exact ⟨hh,hh⟩
    | mapValue ks vs =>
      have hh := Observation.OptionInfoLE.some (Observation.InfoLE.map
        (observeSlots_bind_info ks ν η ξ h) (observeSlots_bind_info vs ν η ξ h))
      exact ⟨hh,hh⟩
    | setValue xs =>
      have hh := Observation.OptionInfoLE.some (Observation.InfoLE.set (observeSlots_bind_info xs ν η ξ h))
      exact ⟨hh,hh⟩
    | dataValue c xs =>
      have hh := Observation.OptionInfoLE.some (Observation.InfoLE.data (c := c) (observeSlots_bind_info xs ν η ξ h))
      exact ⟨hh,hh⟩
    | _ => exact ⟨.some (.refl _),.some (.refl _)⟩
  theorem observeSlots_bind_info (xs : List (Option Term)) (ν : ObservationEnv) (η ξ : ObservationEnvModel)
      (h : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ))) :
      Observation.SlotsInfoLE (observeSlots η xs) (observeSlots ξ (bindSlots ν xs)) := by
    cases xs with
    | nil => exact .nil
    | cons x xs =>
      cases x with
      | none => exact .cons (.none _) (observeSlots_bind_info xs ν η ξ h)
      | some t =>
        have ht : Observation.OptionInfoLE (t.observe η) ((slotBind ν (some t)).bind (Term.observe ξ)) :=
          (t.bind_observe_info ν η ξ h).1
        change Observation.SlotsInfoLE (t.observe η :: observeSlots η xs)
          (observeSlots ξ (slotBind ν (some t) :: bindSlots ν xs))
        cases hs : slotBind ν (some t) <;> simp only [hs,Option.bind_none,Option.bind_some] at ht
        all_goals exact .cons ht (observeSlots_bind_info xs ν η ξ h)

end

theorem termReady_bind_mono {η ξ s t} (ν : ObservationEnv) (h : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (hr : termReady η s t = true) :
    termReady ξ s (termBind ν t) = true ∧ Observation.InfoLE (observeAs η s t) (observeAs ξ s (termBind ν t)) := by
  obtain ⟨o,ho,hs,_,he⟩ := termReady_observation hr
  have hi := (t.bind_observe_info ν η ξ h).2
  rw [ho] at hi
  cases hp : (termBind ν t).observe ξ with
  | none => rw [hp] at hi; cases hi
  | some p =>
    rw [hp] at hi
    have hh : o.InfoLE p := by cases hi; assumption
    have hps : p.sort = s := hh.sort.symm.trans hs
    have hpr : termReady ξ s (termBind ν t) = true := by simp [termReady,hp,hps]
    have he' : observeAs ξ s (termBind ν t) = p := by simp [observeAs,Term.observe_sound hp,hps]
    exact ⟨hpr,by rw [he,he']; exact hh⟩

private theorem observeAs_bind_scalar_mono {η ξ s t} (ν : ObservationEnv) (h : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (hr : termReady η s t = true)
    (hs : s ≠ .list ∧ s ≠ .map ∧ s ≠ .set ∧ s ≠ .data) :
    observeAs η s t = observeAs ξ s (termBind ν t) := by
  obtain ⟨_,hi⟩ := termReady_bind_mono ν h hr
  obtain ⟨o,_,ho,_,he⟩ := termReady_observation hr
  rw [he] at hi
  have hh := Observation.OptionInfoLE.scalar (.some hi) (ho ▸ hs)
  exact he.trans (Option.some.inj hh).symm

private theorem memberReady_bind_interpret_mono {η ξ k t r} (ν : ObservationEnv) (h : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (hr : memberReady η k t r = true) : memberReady ξ k (termBind ν t) r = true ∧
      t.interpret η = (termBind ν t).interpret ξ := by
  cases ht : t.observe η with
  | none => simp [memberReady,ht] at hr
  | some o =>
    cases o <;> simp only [memberReady,ht] at hr <;> try cases hr
    all_goals
      have hi := (t.bind_observe_info ν η ξ h).2
      have hh : (termBind ν t).observe ξ = t.observe η := by
        exact (Observation.OptionInfoLE.scalar (by simpa only [ht] using hi)
          (by simp [Observation.sort])).trans ht.symm
      rw [ht] at hh
      exact ⟨by simpa only [memberReady,hh] using hr,
        (Term.observe_sound ht).trans (Term.observe_sound hh).symm⟩

private theorem memberReady_bind_mono {η ξ k t r} (ν : ObservationEnv)
    (h : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (hr : memberReady η k t r = true) :
    memberReady ξ k (termBind ν t) r = true ∧
      observeAs η (.target k) t = observeAs ξ (.target k) (termBind ν t) := by
  obtain ⟨ready, same⟩ := memberReady_bind_interpret_mono ν h hr
  exact ⟨ready, by simp only [observeAs, same]⟩

private theorem Pred.atom_bind_mono {p : Pred} {η ξ : ObservationEnvModel} (ν : ObservationEnv)
    (h : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ))) (ha : p.atomReady η = true) :
    (predBind ν p).atomReady ξ = true ∧ p.atomValue η = (predBind ν p).atomValue ξ := by
  cases p with
  | truth | falsity => exact ⟨rfl,rfl⟩
  | and _ _ | or _ _ | not _ => cases ha
  | eq a b | le a b | lt a b =>
    have hs : termReady η .integer a = true ∧ termReady η .integer b = true := by simpa only [predBind,Pred.atomReady,Bool.and_eq_true] using ha
    have ea := observeAs_bind_scalar_mono ν h hs.1 (by decide)
    have eb := observeAs_bind_scalar_mono ν h hs.2 (by decide)
    exact ⟨by simp [predBind,Pred.atomReady,(termReady_bind_mono ν h hs.1).1,(termReady_bind_mono ν h hs.2).1],
      by simp only [predBind,Pred.atomValue,integerAs,ea,eb]; rfl⟩
  | compare s o a b =>
    have hs : Comparison.Allowed s o ∧ termReady η s a = true ∧ termReady η s b = true := by
      simpa only [predBind,Pred.atomReady,Bool.and_eq_true,decide_eq_true_eq,and_assoc] using ha
    have scalar : s ≠ .list ∧ s ≠ .map ∧ s ≠ .set ∧ s ≠ .data := by
      cases s <;> cases o <;> simp_all [Comparison.Allowed]
    exact ⟨by simp [predBind,Pred.atomReady,show decide (Comparison.Allowed s o) = true from decide_eq_true hs.1,
        (termReady_bind_mono ν h hs.2.1).1,(termReady_bind_mono ν h hs.2.2).1],
      by simp only [predBind,Pred.atomValue,observeAs_bind_scalar_mono ν h hs.2.1 scalar,observeAs_bind_scalar_mono ν h hs.2.2 scalar]⟩
  | floatClass w c a =>
    cases w <;>
      exact ⟨(termReady_bind_mono ν h ha).1,by simp only [predBind,Pred.atomValue,observeAs_bind_scalar_mono ν h ha (by decide)]⟩
  | decimalRepresented a | charactersIn a lo hi =>
    exact ⟨(termReady_bind_mono ν h ha).1,by simp only [predBind,Pred.atomValue,observeAs_bind_scalar_mono ν h ha (by decide)]⟩
  | member k a r =>
    have hr := (memberReady_bind_mono ν h ha).1
    have he := (memberReady_bind_interpret_mono ν h ha).2
    exact ⟨hr,by simp only [predBind,Pred.atomValue,observeAs,he]⟩
  | constructorIs a c =>
    obtain ⟨hr,hi⟩ := termReady_bind_mono ν h ha
    refine ⟨hr,?_⟩
    simp only [predBind,Pred.atomValue]
    generalize observeAs η .data a = o at hi ⊢
    generalize observeAs ξ .data (termBind ν a) = p at hi ⊢
    cases hi <;> rfl

theorem Pred.evalWith_bind_mono (p : Pred) (ν : ObservationEnv) (η ξ : ObservationEnvModel) (b : Bool)
    (h : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (hp : p.evalWith η = some b) : (predBind ν p).evalWith ξ = some b := by
  induction p generalizing b with
  | and p q ihp ihq | or p q ihp ihq =>
    cases ep : p.evalWith η <;> cases eq : q.evalWith η
    all_goals try (simp only [Pred.evalWith,ep,eq,reduceCtorEq] at hp)
    all_goals first
      | contradiction
      | (rename_i bq; cases bq <;> simp_all [predBind,Pred.evalWith])
      | (rename_i bp; cases bp <;> simp_all [predBind,Pred.evalWith])
      | (rename_i bp bq; cases bp <;> cases bq <;> simp_all [predBind,Pred.evalWith])
    all_goals cases (predBind ν p).evalWith ξ with
      | none => rfl
      | some c => cases c <;> rfl
  | not p ih =>
    change (p.evalWith η).map Bool.not = some b at hp
    cases ep : p.evalWith η with
    | none => simp [ep] at hp
    | some c =>
      have he := ih c ep
      simpa only [predBind,Pred.evalWith,he] using (by simpa only [ep] using hp)
  | _ =>
    simp only [Pred.evalWith] at hp
    simp only [predBind,Pred.evalWith]
    split at hp
    · rename_i hr
      obtain ⟨hr',he⟩ := Pred.atom_bind_mono ν h hr
      simp only [predBind] at hr' he
      simpa only [hr',↓reduceIte,←he] using hp
    · cases hp



theorem Pred.close_preserves_decided (p : Pred) (ν : Nat → Val) (w : Val) (b : Bool)
    (hp : p.evalWith (selfModel (fun _ => none) w) = some b) :
    (predBind (valEnv ν).up.values p).evalWith (selfModel (fun _ => none) w) = some b := by
  apply Pred.evalWith_bind_mono p (valEnv ν).up.values _ _ b _ hp
  intro i
  cases i with
  | zero => exact .refl _
  | succ i => exact .none _

theorem Pred.shift_self_preserves_decided (p : Pred) (w : Val) (k c : Nat) (b : Bool)
    (hp : p.evalWith (selfModel (fun _ => none) w) = some b) :
    (p.shiftV k (c+1)).evalWith (selfModel (fun _ => none) w) = some b := by
  apply Pred.evalWith_bind_mono p _ _ _ b _ hp
  intro i
  cases i with
  | zero => simpa [shiftIndex,termBind?,Term.observe,selfModel] using
      (Observation.OptionInfoLE.refl (selfObservation w))
  | succ i => exact .none _

end Benitoite.Release.Refinement
