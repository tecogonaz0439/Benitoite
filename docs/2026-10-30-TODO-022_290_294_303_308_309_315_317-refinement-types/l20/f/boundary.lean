import Lean
import Benitoite.Release.Refinement.CapturedFacts
import Benitoite.Release.Refinement.LogicSound

/-! 捕捉した環境を捨てる場合の反例。-/
namespace Benitoite.Release.Refinement.CapturedFactsBoundary
noncomputable section

abbrev I : Ty := .base .integer

def nonneg : Pred := .le (.integer 0) (.var 0)

def argument : Ty := .refined I nonneg

def phi : Pred := .lt (.var 0) (.integer 8)

def Γ : Ctx := Ctx.extend [] I

def result : Ty := .refined argument (.lt (.var 2) (.integer 8))

def tel : Tel := .param "x" argument (.done result Eff.empty)

def seven : Val := .const (.integer ⟨7,by decide⟩)

def zero : Val := .const (.integer ⟨0,by decide⟩)

def cap : Capture := Capture.empty.extend seven

def code (c : Bool) : Comp := .ite (.const (.boolean c)) (.ret (.var 0)) (.ret zero)

def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }

def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }

macro "ann" : tactic => `(tactic| simp [Ty.Annotation,I,nonneg,argument,phi,Γ,result,tel,
  hideConts,Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,
  Ty.Sorted,sortedTys,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.Readable,
  Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,declaredTys,declaredEff,Pred.Declared,
  Term.Declared,Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Eff.empty,Eff.norm,Eff.WF,
  Eff.Canonical,sortedEff,Ty.norm,Ty.refineNorm,Ty.packRefinements,
  Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Ty.normTys,Order.sortUnique,
  Tel.WF,Tel.Sorted,Tel.Declared])

theorem argument_ann : Ty.Annotation P [] (hideConts Γ) argument := by
  refine ⟨?_,?_,?_⟩ <;> ann

theorem result_ann : Ty.Annotation P [] ((hideConts Γ).extend argument)
    (.dependentFn (.done result Eff.empty)) := by
  refine ⟨?_,?_,?_⟩ <;> ann

theorem phi_wf : Pred.WellFormed P [] Γ phi := by
  refine ⟨?_,?_,?_⟩ <;> ann

theorem images_only : CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] cap :=
  (CaptureOk.empty P B _ _).extend ⟨trivial,trivial,trivial⟩ (.V_Const trivial) trivial

theorem phi_evaluates : (predBind (valEnv cap.env).values phi).evalClosed = some true := by
  decide

theorem captured : CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] cap :=
  images_only.addEvaluated phi_wf phi_evaluates

theorem return_argument : HasTypeC P B (hideBuilders StoreTy.empty) []
    ((hideConts Γ).extend argument) [phi.lift] (some result) (.ret (.var 0)) result Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Var rfl (by trivial)) (sort := .integer) rfl rfl ?_ ?_ ?_ ?_ ?_
  · exact result_ann.sorted.1.2
  · exact result_ann.wf.1.2.1
  · exact .hyp (List.mem_append_right _ List.mem_cons_self)
  · exact argument_ann.declared
  · exact result_ann.declared.1.2

theorem return_zero : HasTypeC P B (hideBuilders StoreTy.empty) []
    ((hideConts Γ).extend argument) [phi.lift] (some result) (.ret zero) result Eff.empty := by
  apply HasTypeCQ.C_Return
  have hv : HasTypeV P B (hideBuilders StoreTy.empty) []
      ((hideConts Γ).extend argument) [phi.lift] zero argument := by
    refine .V_Refine (.V_Const trivial) (sort := .integer) rfl rfl ?_ ?_ ?_ trivial ?_
    · ann
    · trivial
    · exact .le_refl
    · ann
  refine .V_Refine hv (sort := .integer) rfl rfl ?_ ?_ ?_ ?_ ?_
  · exact result_ann.sorted.1.2
  · exact result_ann.wf.1.2.1
  · exact .hyp (List.mem_append_right _ List.mem_cons_self)
  · exact argument_ann.declared
  · exact result_ann.declared.1.2

theorem value_assumptions : Builtins.ValueAssumptions P B := by
  constructor
  · intros; trivial
  · intro b sg C Γ Δ ts ξ hs; cases hs
  · intros; trivial
  · intro b sg Ψ Q C Γ Δ Ξ ν ts hs; cases hs

theorem body_typed (c : Bool) : TelBodyTy P B (hideBuilders StoreTy.empty) Qempty []
    (hideConts Γ) [phi] tel (code c) :=
  .param (.done (.C_If (.V_Const trivial) rfl
    (return_argument.weaken_conditions value_assumptions StoreTy.WF.empty.hide
      (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp))))
    (return_zero.weaken_conditions value_assumptions StoreTy.WF.empty.hide
      (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp))))))

theorem body_requires_phi : ¬ HasTypeV P B (hideBuilders StoreTy.empty) []
    ((hideConts Γ).extend argument) [] (.var 0) result := by
  intro h
  have hf := h.facts rfl (.lt (.var 2) (.integer 8)) (by change _ ∈ [_, _]; simp)
  have hm := hf.sound (fun _ => some (.integer 8)) (by
    intro p hp
    change p ∈ [nonneg] at hp
    cases List.mem_singleton.mp hp
    rfl)
  change false = true at hm
  cases hm

def eight : Val := .const (.integer ⟨8,by decide⟩)

def otherCap : Capture := Capture.empty.extend eight

theorem other_images_only : CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] otherCap :=
  (CaptureOk.empty P B _ _).extend ⟨trivial,trivial,trivial⟩ (.V_Const trivial) trivial

theorem other_cannot_capture :
    ¬ CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] otherCap := by
  intro h
  have hf := (h.conditions phi (List.mem_append_right _ List.mem_cons_self)).sound
    (fun _ => none) (by simp)
  change false = true at hf
  cases hf

theorem environment_cannot_be_forgotten :
    ¬ (∀ q, CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] q →
      CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] q) := by
  intro h
  exact other_cannot_capture (h otherCap other_images_only)

theorem open_phi_is_not_closed_fact : ¬ Entails [] phi := by
  intro h
  have hf := h.sound (fun _ => some (.integer 8)) (by simp)
  change false = true at hf
  cases hf

theorem discarded_capture_changes_view :
    (Closure.mk cap (.ret (.var 0))).view = .ret seven ∧
    (Closure.mk Capture.empty (.ret (.var 0))).view = .ret (.const .unit) := ⟨rfl,rfl⟩

theorem discarded_capture_evaluation_fails :
    (predBind (valEnv Capture.empty.env).values phi).evalClosed = none := by decide

theorem environment_counterexample :
    CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] cap ∧
    CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] otherCap ∧
    CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] cap ∧
    ¬ CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] otherCap :=
  ⟨images_only,other_images_only,captured,other_cannot_capture⟩

end
end Benitoite.Release.Refinement.CapturedFactsBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "CapturedFactsBoundary").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
