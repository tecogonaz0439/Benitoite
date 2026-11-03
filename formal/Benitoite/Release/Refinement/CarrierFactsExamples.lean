import Benitoite.Release.Refinement.LogicSound
import Benitoite.Release.Refinement.TypedMeaning
import Benitoite.Release.Refinement.LegacyPatternExamples
import Benitoite.Release.Refinement.ContextNormEq

/-! # 型域と文脈の事実の適用例 -/
namespace Benitoite.Release.Refinement.CarrierFactsExamples
noncomputable section

def widthCtx : Ctx := [some (.base .integer8)]
def upper : Pred := .le (.var 0) (.integer 127)

theorem width_upper : Entails widthCtx.facts upper :=
  .hyp (Ctx.mem_facts.mpr ⟨0,.base .integer8,upper,rfl,by simp [upper,
    Ty.assume,Ty.carrierFacts,Ty.core,Ty.refinementPredicates,integerBounds],rfl⟩)

/-- 明示した篩だけの列では、値1000のモデルを排除できない。 -/
def explicitFacts (Γ : Ctx) : List Pred :=
  Γ.zipIdx.flatMap fun (a,i) => match a with
    | none => []
    | some a => a.refinementPredicates.map (fun p => p.open (.var i))

theorem explicit_width_upper_unprovable : ¬ Entails (explicitFacts widthCtx) upper := by
  intro h
  have hh := h.sound (fun _ => some (.integer 1000)) (by simp [explicitFacts,widthCtx,Ty.refinementPredicates])
  have hn : upper.interpret (fun _ => some (.integer 1000)) = false := by decide
  rw [hn] at hh
  cases hh

theorem width_128_unprovable : ¬ Entails widthCtx.facts (.le (.integer 128) (.var 0)) := by
  intro h
  have hh := h.sound (fun _ => some (.integer 127)) (by
    simp [widthCtx,Ctx.facts,Ty.assume,Ty.carrierFacts,Ty.core,
      Ty.refinementPredicates,integerBounds,Pred.open,predBind,termBind_var,termBind_integer,
      Pred.interpret,Pred.atomValue,integerAs,observeAs,Term.interpret,Observation.sort])
  have hn : Pred.interpret (fun _ => some (.integer 127)) (.le (.integer 128) (.var 0)) = false := by decide
  rw [hn] at hh
  cases hh

-- 正規化した篩、隠した位置、後続の変数の番号を同じ事実で照合する。
example : Entails (widthCtx.extendNone.facts) upper.lift := by
  apply width_upper.bind (fun i => some (.var (i+1))) |>.weaken
  intro p hp
  obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
  exact Ctx.mem_facts_extendNone.mpr ⟨q,hq,rfl⟩
def upperType : Ty := .refined (.base .integer8) upper

theorem integer8_upper_sub (P : Program) (Γ : Ctx) (Φ : List Pred) :
    Ty.LeQ P Γ Φ (.base .integer8) upperType := by
  apply Ty.LeQ.introduce
  · simp [upper, Pred.Sorted, Term.HasSort, Term.Shape, Term.References, Term.VarsIn,
      Ctx.Readable, Ty.HasSort, Ty.sort?, Ordinary, Ty.core]
  · have allFacts : ∀ p ∈ (Ty.base .integer8).assume,
        Entails (assumptions Γ Φ (.base .integer8)) p :=
      fun _ hp => .hyp (List.mem_append_left _ hp)
    have parts := (Ty.entails_assume_iff _ (.base .integer8)
      (by intro b t e h; cases h)).mp allFacts
    exact parts.1 upper (by simp [upper, Ty.carrierFacts, Ty.core, integerBounds])

private theorem upper_annotation (P : Program) (Γ : Ctx) : Ty.Annotation P [] Γ upperType := by
  constructor
  · simp [upperType, upper, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn,
      Ty.NotContCore, Ty.core]
  · simp [upperType, upper, Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape,
      Term.References, Term.VarsIn, Ctx.Readable, Ty.HasSort, Ty.sort?, Ordinary, Ty.core]
  · simp [upperType, upper, Ty.Declared, Pred.Declared, Term.Declared,
      Ctx.declarationSelf, Ctx.extend, Ctx.Readable, Ty.shiftV, Ordinary, Ty.core]

theorem typed_integer8_upper (P : Program) (B : Builtins) :
    HasTypeVQ P B StoreTy.empty Qempty [] widthCtx [] (.var 0) upperType := by
  have annotation := upper_annotation P widthCtx
  exact .V_Sub (.V_Var rfl (by intro b t e h; cases h))
    (integer8_upper_sub P widthCtx []) annotation.wf annotation.sorted annotation.declared

-- 同じ具体のプログラムと組込み表で、127の値に篩を付けて意味を読む。
private def P : Program :=
  ⟨fun _ => none,fun _ => none,fun _ => none,fun _ => none,
    fun _ => none,fun _ => none,[],fun _ => none⟩
private theorem valid : P.VarianceValid := by
  constructor
  · simp [P]
  · intro c cd hc
    cases hc

private def B : Builtins := LegacyPatternExamples.builtins

theorem closed_integer8_upper :
    HasTypeVQ P B StoreTy.empty Qempty [] [] [] (.const (.integer8 127)) upperType := by
  have annotation := upper_annotation P []
  exact .V_Sub (.V_Const (by constructor <;> decide))
    (integer8_upper_sub P [] []) annotation.wf annotation.sorted annotation.declared

theorem closed_integer8_meaning :
    ValueMeaning P (fun _ => none) upperType (.const (.integer8 127)) :=
  typed_value_meaning_closed valid closed_integer8_upper

theorem closed_integer8_carrier (η : ObservationEnvModel) :
    ∀ p ∈ upperType.carrierFacts,
      p.interpret (selfModel η (.const (.integer8 127))) = true :=
  TypedMeaning.carrierFacts_meaning_closed closed_integer8_upper η

theorem raw_1000_not_meaning (P : Program) (η : ObservationEnvModel) :
    ¬ ValueMeaning P η (.base .integer8) (.const (.integer8 1000)) := by
  intro h
  have hh := h.assume upper (by
    simp [upper,Ty.assume,Ty.carrierFacts,Ty.core,Ty.refinementPredicates,integerBounds])
  have hf : upper.interpret (selfModel η (.const (.integer8 1000))) = false := by
    simp [upper,Pred.interpret,Pred.atomValue,integerAs,observeAs,selfModel,
      selfObservation,Val.toTerm?,Term.observe,Term.interpret,Observation.sort]
  rw [hf] at hh
  cases hh

theorem no_typed_1000 :
    ¬ HasTypeVQ P B StoreTy.empty Qempty [] [] [] (.const (.integer8 1000)) (.base .integer8) := by
  intro h
  exact raw_1000_not_meaning P (fun _ => none) (typed_value_meaning_closed valid h)

-- Decimalの実定数を同じ表で捕捉し、最後の事実の欄に型域を供給する。
theorem captured_decimal : CaptureOk P B StoreTy.empty none
    (Ctx.extend [] (.base .decimal)) [] (Capture.empty.extend (.const (.decimal 1 0))) :=
  (CaptureOk.empty P B StoreTy.empty none).extend
    (a := .base .decimal) ⟨trivial,trivial,trivial⟩
    (.V_Const (by constructor; decide; constructor <;> decide)) (by trivial)

end
end Benitoite.Release.Refinement.CarrierFactsExamples
