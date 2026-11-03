import Benitoite
open Benitoite.Release.Refinement
noncomputable section

-- 固定した型を本番の宣言で満たす。rawの規則の健全性をここで再証明しない。
example (P : Program) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (l : PreparedLeaf) : Bool :=
  PreparedLeaf.checkIn P C Γ Φ l
example {P : Program} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {l : PreparedLeaf}
    (h : l.checkIn P C Γ Φ = true) : Entails (Γ.facts ++ Φ) l.predicate :=
  PreparedLeaf.entailsIn h
example {P : Program} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {l : PreparedLeaf}
    (h : l.checkIn P C Γ Φ = true) (ν : ObservationEnv) :
    Entails ((Γ.facts ++ Φ).map (predBind ν)) (predBind ν l.predicate) :=
  PreparedLeaf.bind_entails h ν
example {P : Program} {Γ : Ctx} {Φ : List Pred} {a b : Ty} {p q : Pred} {c : Certificate}
    (hab : Ty.LeQ P Γ Φ a b) (hp : p.Sorted Γ (some a)) (hq : q.Sorted Γ (some b))
    (hc : CertificateKernel.check (Pred.ofConjuncts (p :: assumptions Γ Φ a)) q c = true) :
    Ty.LeQ P Γ Φ (.refined a p) (.refined b q) := checked_refinement hab hp hq hc
example {Ξ : List Pred} {p : Pred} (h : Entails Ξ p) (ν : ObservationEnv) :
    Entails (Ξ.map (predBind ν)) (predBind ν p) := Entails.bind h ν
example {keys : KeyTable} {t : Term} {cs : List Int} {b : Int}
    (h : linearize keys t = some (cs,b)) (ν : ObservationEnv) (η : ObservationEnvModel) :
    integerAs η (termBind ν t) = linearDot cs (keyEnv η (keys.map (termBind ν)))+b :=
  linearize_sound_at h ν η
example {keys : KeyTable} {p : Pred} {negative : Bool} {q : NNF}
    (h : normalize keys p negative = some q) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (q.toPred keys)).interpret η =
      (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η) :=
  normalize_sound_at h ν η
example {p q : Pred} {c : Certificate} (h : CertificateKernel.check p q c = true) :
    ∀ (ν : ObservationEnv) (η : ObservationEnvModel),
      (predBind ν p).interpret η = true → (predBind ν q).interpret η = true :=
  CertificateKernel.implication_sound_at h

#check @Benitoite.Release.progress
#check @Benitoite.Release.preservation
#check @Benitoite.Release.step_sound
#check @Benitoite.Release.effect_soundness
#check @Benitoite.Release.effect_soundness_noLamNames
#check @HasTypeVQ.subst
#check @HasTypeVQ.subst_under_none
#check @HasTypeVQ.shift_values
#check @HasTypeVQ.shift_types
#check @HasTypeVQ.narrow
#check @HasTypeCQ.subst
#check @HasTypeCQ.subst_under_none
#check @HasTypeCQ.shift_values
#check @HasTypeCQ.shift_types
#check @HasTypeCQ.narrow
#check @ValueMeaning.mk
#check @TypedMeaning.const_meaning
#check @typed_value_meaning_closed
#check @valueMeaning_sub
#check @close_value_typed
#check @CaptureOk.mk
#check @Certificate.Legacy.success_preserved
#check @HasTypeVQ.observed_measure
#check @NumericContracts.binary_normal
#check @Key.code_of_shape
#check @CoefficientRepresented
#check @CoefficientModel.binary_some
#check @CoefficientModel.product_then_save
#check @CoefficientModel.decimal_compare
#check @StepAccounting.stepAction_valid
#check @StepAccounting.runActions_used
#check @StepAccounting.execute_valid
#check @StepAccounting.destroy_once
#check @StepAccounting.rollback_all
#check @StepAccounting.input_certificate_expansion
#check @ProofContract.Accepted.sound
#check @StepAccounting.readCoefficient_eq
#check @StepAccounting.addCoefficients_eq
#check @replay_checked
#check @checkAccounted
#check @checkAccounted_stopped
#check @checkAccounted_proved
end
