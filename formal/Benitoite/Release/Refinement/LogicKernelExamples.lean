import Benitoite.Release.Refinement.CarrierFactsMeaning
import Benitoite.Release.Refinement.LinearSound
import Benitoite.Release.Refinement.EqCertificate
import Benitoite.Release.Refinement.MeasureContracts
import Benitoite.Release.Refinement.LegacyPatternExamples
import Benitoite.Release.Refinement.Context.Capture
import Benitoite.Interval.Arithmetic

/-! # 型域・整数規則・観測の具体の適用 -/
namespace Benitoite.Release.Refinement.LogicKernelExamples
noncomputable section

theorem integer8_facts :
    (Ty.base .integer8).assumeWithCarrier =
      [.le (.integer (-128)) (.var 0), .le (.var 0) (.integer 127)] := by
  change (Ty.base .integer8).assume = _
  rw [Ty.assume_eq_carrier_append (by intro b t e h; cases h)]
  rfl

theorem decimal_facts (η : ObservationEnvModel) :
    ∀ p ∈ (Ty.base .decimal).carrierFacts,
      p.interpret (selfModel η (.const (.decimal 123 2))) = true :=
  Const.NumericRepresented.carrierFacts (c := .decimal 123 2)
    (ConstOK.represented (B := LegacyPatternExamples.builtins) (by constructor; decide; constructor <;> decide)) η

theorem integer8_outside :
    ¬ ConstOK LegacyPatternExamples.builtins (.integer8 1000) := by
  change ¬ (-128 ≤ (1000 : Int) ∧ 1000 ≤ 127)
  decide

theorem integer8_carrier (η : ObservationEnvModel) :
    ∀ p ∈ (Ty.base .integer8).carrierFacts,
      p.interpret (selfModel η (.const (.integer8 5))) = true :=
  Const.NumericRepresented.carrierFacts (c := .integer8 5)
    (ConstOK.represented (B := LegacyPatternExamples.builtins) (by constructor <;> decide)) η

theorem scaled_snapshot (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.le (.add (.measure .setSize (.setValue [some (.var 0)])) (.var 1))
      (.integer 5))).interpret η = true →
    (predBind ν (.le (.scale 2 (.add (.measure .setSize (.setValue [some (.var 0)])) (.var 1)))
      (.integer 10))).interpret η = true := Pred.scaled_le_at _ (by decide) ν η

theorem scaled_snapshot_comp (σ τ : ObservationEnv) (η : ObservationEnvModel) :
    (predBind τ (predBind σ (.le (.add (.measure .setSize (.setValue [some (.var 0)])) (.var 1))
      (.integer 5)))).interpret η = true →
    (predBind τ (predBind σ (.le (.scale 2 (.add (.measure .setSize (.setValue [some (.var 0)])) (.var 1)))
      (.integer 10)))).interpret η = true :=
  Pred.bind_implication_comp scaled_snapshot σ τ η

theorem opposite_snapshot (ν : ObservationEnv) (η : ObservationEnvModel) :
    ¬ ((predBind ν (.eq (.measure .setSize (.setValue [some (.var 0)])) (.var 1))).interpret η = true ∧
      (predBind ν (.not (.eq (.measure .setSize (.setValue [some (.var 0)])) (.var 1)))).interpret η = true) :=
  Pred.opposite_at _ ν η

theorem closed_leaf (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.le (.integer 0) (.integer 1))).interpret η = true :=
  Pred.closed_sound_at (by trivial) (by constructor <;> constructor <;> trivial) (by decide) ν η

theorem encoded_snapshot (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν ((Linear.mk [2] 7).toPred [.measure .setSize (.setValue [some (.var 0)])])).interpret η = true ↔
      (Linear.mk [2] 7).Holds (keyEnv η ([.measure .setSize (.setValue [some (.var 0)])].map (termBind ν))) :=
  Linear.toPred_sound_at η ν _ _

theorem negative_floor (ρ : Nat → Int) (h : (Linear.mk [2] (-3)).Holds ρ) :
    (Linear.mk [1] (-2)).Holds ρ := Linear.round_sound 2 ρ (by decide) rfl (by decide) h

theorem odd_equality_rejected (x : Int) (h : 2*x = 1) : False := by
  have upper := integer_round (x := x) (d := 2) (b := 1) (by decide) (by omega)
  have lower := integer_round (x := -x) (d := 2) (b := -1) (by decide) (by omega)
  change x ≤ 0 at upper
  change -x ≤ -1 at lower
  omega

theorem split_both (x cut : Int) (left : x ≤ cut → False) (right : cut+1 ≤ x → False) : False :=
  integer_split_refute left right

theorem split_second_needed (cut : Int) : ¬ (cut+1 ≤ cut) ∧ cut+1 ≤ cut+1 := by omega

theorem combination (x y : Int) (hx : x ≤ 3) (hy : y ≤ -2) : 2*x+3*y ≤ 0 :=
  integer_combination (by decide) (by decide) hx hy

theorem round_image (ν : ObservationEnv) (η : ObservationEnvModel) (t : Term)
    (h : integerAs η (termBind ν (.scale 2 t)) ≤ -3) :
    integerAs η (termBind ν t) ≤ -2 := integerAs_round_at η ν t (by decide) h

theorem split_image (ν : ObservationEnv) (η : ObservationEnvModel) (t : Term) :
    integerAs η (termBind ν t) ≤ 7 ∨ 8 ≤ integerAs η (termBind ν t) := integerAs_split_at η ν t 7

theorem snapshot_rewrite_rejected :
    ¬ RewritePosition (.le (.measure .setSize (.setValue [some (.var 0)])) (.integer 7)) .integer := by
  simp [RewritePosition, Term.IntegerRewritePosition, Term.VarsIn, varsInSlots, varsInSlot]

theorem snapshot_integer_equality_insufficient :
    (.eq (.var 0) (.integer 0) : Pred).interpret (fun _ => none) = true ∧
    (Term.measure .setSize (.setValue [some (.var 0)])).interpret (fun _ => none) = some (.integer 0) ∧
    (Term.measure .setSize (.setValue [some (.integer 0)])).interpret (fun _ => none) = some (.integer 1) := by
  constructor
  · decide
  · simp [Term.interpret, Term.observe, Observation.measure, observeSlots, keySetCodes, Observation.keyCode?]

theorem integer_position (σ τ : ObservationEnv) (η : ObservationEnvModel)
    (h0 : integerAs η ((σ 0).getD (.integer 0)) = integerAs η ((τ 0).getD (.integer 0)))
    (hr : ∀ i, i ≠ 0 → σ i = τ i) :
    (predBind σ (.le (.scale 2 (.neg (.var 0))) (.var 1))).interpret η =
      (predBind τ (.le (.scale 2 (.neg (.var 0))) (.var 1))).interpret η :=
  RewritePosition.integer_sound (by trivial) σ τ η h0 hr

private def P : Program :=
  embedProgramWithKinds LegacyPatternExamples.kinds LegacyPatternExamples.oldProgram
private def B : Builtins := LegacyPatternExamples.builtins
private def five : Val := .const (.integer8 5)
private def cap : Capture := (Capture.empty.extend five).extend five
private def Γ : Ctx := (Ctx.extend [] (.base .integer8)).extend (.base .integer8)

theorem captured_integer8 : CaptureOk P B StoreTy.empty none Γ [] cap ∧
    termBind (valEnv cap.env).values (.var 0) = termBind (valEnv cap.env).values (.var 1) ∧
    (∀ p ∈ Γ.factsWithCarrier ++ [], Entails [] (predBind (valEnv cap.env).values p)) := by
  have h1 := (CaptureOk.empty P B StoreTy.empty none).extend
    (a := .base .integer8) ⟨trivial,trivial,trivial⟩ (v := five)
    (.V_Const (by constructor <;> decide)) (by trivial)
  have h2 := h1.extend (a := .base .integer8) ⟨trivial,trivial,trivial⟩ (v := five)
    (.V_Const (by constructor <;> decide)) (by trivial)
  refine ⟨h2, rfl, ?_⟩
  intro p hp
  have facts : Γ.factsWithCarrier ++ [] =
      [.le (.integer (-128)) (.var 0), .le (.var 0) (.integer 127),
       .le (.integer (-128)) (.var 1), .le (.var 1) (.integer 127)] := rfl
  rw [facts] at hp
  simp only [List.mem_cons, List.not_mem_nil, or_false] at hp
  rcases hp with rfl | rfl | rfl | rfl
  all_goals exact Entails.integer_le (by decide)

theorem captured_snapshot :
    (.le (.measure .setSize (.setValue [some (.var 0)])) (.integer 7) : Pred).open
      (termBind (valEnv cap.env).values (.var 0)) =
    (.le (.measure .setSize (.setValue [some (.var 0)])) (.integer 7) : Pred).open
      (termBind (valEnv cap.env).values (.var 1)) :=
  RewritePosition.structural_sound _ captured_integer8.2.1

private def textSlots : List (Option Term) := List.replicate 2 (some (.string "x"))
private def field : FieldRef := ⟨"Scope.ScopeError", "Scope.ScopeError.InvalidPattern", 0, .string⟩
private def dataCapture : Capture :=
  ⟨[some (.con "Scope.ScopeError.InvalidPattern" [] (List.replicate 2 (.const (.string "x"))))]⟩

theorem declared_field :
    FieldRef.Declared P [] [] (.dataValue "Scope.ScopeError.InvalidPattern" textSlots) field := by
  refine ⟨[], _, .base .string, Term.HasData.value (by rfl) rfl rfl rfl, rfl, rfl, rfl, rfl, trivial, rfl⟩

theorem captured_field :
    termBind (valEnv dataCapture.env).values (.field field (.var 0)) =
      .field field (.dataValue "Scope.ScopeError.InvalidPattern" textSlots) ∧
    (termBind (valEnv dataCapture.env).values (.field field (.var 0))).observe (fun _ => none) =
      some (.string "x") := by
  constructor <;> rfl

theorem captured_measure :
    termBind (valEnv dataCapture.env).values (.measure .stringCharacters (.field field (.var 0))) =
      .measure .stringCharacters (.field field (.dataValue "Scope.ScopeError.InvalidPattern" textSlots)) ∧
    (termBind (valEnv dataCapture.env).values
      (.measure .stringCharacters (.field field (.var 0)))).observe (fun _ => none) = some (.integer 1) := by
  constructor <;> rfl

theorem list_length_image (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.and (.eq (.measure .listLength (.var 0)) (.var 1)) (.lt (.integer 0) (.var 1)))).interpret η = true →
    (predBind ν (.lt (.integer 0) (.measure .listLength (.var 0)))).interpret η = true :=
  Pred.eq_positive_at _ _ ν η

theorem measure_length :
    (Term.measure .listLength (.listValue [none, none])).observe (fun _ => none) = some (.integer 2) ∧
    (Term.measure .listLength (.listValue [none, none])).interpret (fun _ => none) = some (.integer 2) ∧ 0 ≤ (2 : Int) :=
  measure_machine_exact (by rfl) _ _ rfl

theorem measure_length_stable (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (h : (Term.measure .listLength (.var 0)).observe η = some (.integer 2)) :
    (Term.measure .listLength (termBind ν (.var 0))).observe ξ = some (.integer 2) :=
  measure_stable ν η ξ hi h

theorem normal_and_stop :
    Benitoite.Interval.IntKind.checkedAdd .integer8 ⟨126, by decide⟩ ⟨1, by decide⟩ =
      .normal (.integer8 ⟨127, by decide⟩) ∧
    Benitoite.Interval.IntKind.checkedAdd .integer8 ⟨127, by decide⟩ ⟨1, by decide⟩ =
      .rejected .overflow := by constructor <;> rfl

end
end Benitoite.Release.Refinement.LogicKernelExamples
