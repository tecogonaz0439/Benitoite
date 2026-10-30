import Lean
import Benitoite.Release.Refinement.TelTyping
import Benitoite.Release.Refinement.Embedding

namespace Benitoite.Release.Refinement.ExternalBoundary
noncomputable section

def f : ExternalFunctionId := .mk 0
def idA : ExternalId := .mk 0
def idB : ExternalId := .mk 1
def tdA : ExternalTypeDecl := ⟨idA, .mk 0, "Cell", 0, 0⟩
def tdB : ExternalTypeDecl := ⟨idB, .mk 0, "Cell", 0, 1⟩
def pureSig : ExternalSignature := ⟨.mk 0, "same-display", [], [], .done (.base .unit) Eff.empty, []⟩
def P : Program :=
  { defs := fun _ => none
    cons := fun c => if c = "Box" then some ⟨"Box", 1, [.tvar 0]⟩ else none
    ops := fun _ => none
    effects := fun _ => none
    classes := fun _ => none
    impls := fun _ => none
    externals := [(.type idA, .type tdA), (.type idB, .type tdB), (.function f, .function f pureSig)] }
def B : Builtins :=
  { sig := fun _ => none
    delta := fun _ _ _ _ _ => none
    ioResponse := fun _ _ _ _ _ _ => False
    releaseResponse := fun _ _ => True
    isResource := fun _ => false
    effects := fun _ => none
    sat := fun _ _ _ => True
    refGet := "get"
    refSet := "set"
    externalResponse := fun id ts vs out obs =>
      id = f ∧ ts = [] ∧ vs = [] ∧ obs = [] ∧ out = .val (.const .unit) }

theorem pure_annotation (C : List TParam) (Γ : Ctx) :
    Ty.Annotation P C Γ (.dependentFn (.done (.base .unit) Eff.empty)) := by
  constructor
  · simp [Ty.WF, Tel.WF, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.WFList]
  · trivial
  · trivial

theorem pure_wf : pureSig.WF P := by
  refine ⟨rfl, rfl, pure_annotation [] [], ?_, ?_, by simp [pureSig], ?_⟩
  · trivial
  · intro use
    constructor
    · simp [pureSig]
    · intro h; cases h with | result h => cases h
  · exact .done (.unit) rfl

theorem table_wf : P.ExternalWF := by
  constructor
  · decide
  · intro key decl hm
    simp only [P, List.mem_cons, List.not_mem_nil, or_false] at hm
    rcases hm with h | h | h
    all_goals cases h
    · exact ⟨rfl, rfl⟩
    · exact ⟨rfl, rfl⟩
    · exact ⟨rfl, pure_wf⟩

theorem lookupA : P.externalType idA = some tdA := by rfl
theorem lookupF : P.externalFunction f = some pureSig := by rfl
theorem lookupUnknown : P.externalType (.mk 9) = none := by rfl

theorem same_display_distinct_ids : tdA.displayName = tdB.displayName ∧ tdA.id ≠ tdB.id := by decide

theorem unknown_type_rejected : ¬ Ty.Declared P [] [] (.list (.external (.mk 9) [])) := by
  simp only [Ty.Declared, lookupUnknown, reduceCtorEq, false_and, exists_false, not_false_eq_true]

theorem malformed_arity_rejected : ¬ Ty.Declared P [] [] (.external idA [.base .integer]) := by
  simp [Ty.Declared, P, Program.externalType, tdA, idA, idB]

theorem duplicate_key_rejected :
    ¬ ({ P with externals := [(.type idA, .type tdA), (.type idA, .type tdA)] } : Program).ExternalWF := by
  intro h
  have := h.unique
  simp at this

def handleA : ExternalHandle := ⟨idA, .mk 0, 0, 17⟩
theorem handle_typed : HasTypeV P B StoreTy.empty [] [] [] (.externalHandle handleA []) (.external idA []) := by
  apply HasTypeVQ.V_ExternalHandle handleA tdA lookupA rfl rfl rfl
  constructor
  · trivial
  · trivial
  · exact ⟨⟨tdA, lookupA, rfl, rfl⟩, trivial⟩

theorem wrong_component_rejected :
    ¬ (∃ td, P.externalType handleA.typeId = some td ∧ td.component = .mk 8 ∧ td.resource = handleA.resource) := by
  simp [P, Program.externalType, handleA, tdA, idA, idB]

theorem nested_borrow : ExternalUseAt P 0
    (.param "cells" (.list (.external idA [])) (.done (.base .unit) Eff.empty))
    ⟨.argument 0, [.element], .borrow, idA⟩ := .argument (.element .root)

theorem nested_own : ExternalUseAt P 0
    (.done (.map (.base .string) (.external idA [])) Eff.empty)
    ⟨.result, [.value], .own, idA⟩ := .result (.value .root)

theorem result_cannot_borrow : ¬ ExternalUseAt P 0 (.done (.external idA []) Eff.empty)
    ⟨.result, [], .borrow, idA⟩ := by intro h; cases h

theorem nominality_under_bind (θ : SubstEnv) :
    ((Ty.list (.external idA [])).bind θ).norm ≠ ((Ty.list (.external idB [])).bind θ).norm := by
  simp [Ty.bind, Ty.rawBind, Ty.norm, rawBindTys, Ty.normTys, idA, idB]

theorem external_has_no_observation : (.externalHandle handleA [] : Val).toTerm? = none := rfl

theorem pure_admissible : ExternalCallAdmissible P B [] pureSig [] := by
  refine ⟨rfl, ⟨rfl, [], rfl, ?_⟩, ⟨rfl, ?_⟩, ?_⟩
  · intro i a k h; simp at h
  · intro i a p h; simp at h
  · intro t h; simp at h

theorem pure_arguments : HasTypeTelArgs P B StoreTy.empty [] [] [] []
    (Tel.bind (typeEnv []) pureSig.parameters) (.base .unit) Eff.empty := by
  have he : Tel.bind (typeEnv []) pureSig.parameters = .done (.base .unit) Eff.empty := by
    simp [pureSig, Tel.bind, Tel.rawBind, Tel.norm, Ty.rawBind, Ty.norm, Eff.rawBind,
      Eff.norm, Eff.empty, rowFails, rawBindTys, Ty.normTys, typeEnv, typeEnvAt, instAtoms_nil, substAtoms_nil]
  rw [he]
  exact .done (pure_annotation [] [])

theorem pure_call_typed : HasTypeC P B StoreTy.empty [] [] [] none
    (.externalCall f [] []) (.base .unit) Eff.empty :=
  .C_External lookupF pure_wf pure_admissible pure_arguments

theorem pure_response : B.externalResponse f [] [] (.val (.const .unit)) [] := by
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

theorem pure_external_label_none (σ : PathEnv) : Step P B σ
    (.run (.pure (.externalCall f [] [])) [] Store.empty) none
    (.run (.pure (.ret (.const .unit))) [] Store.empty) :=
  .E_External rfl lookupF pure_response

theorem pure_apply_label_none (σ : PathEnv) : Step P B σ
    (.run (.pure (.app (.externalRef f []) [])) [] Store.empty) none
    (.run (.pure (.externalCall f [] [])) [] Store.empty) := .E_ExternalApply rfl

theorem no_exit {Ψ ts vs a e n obs} (hA : Builtins.ExternalAssumptions P B)
    (hargs : ExternalArgs P B Ψ pureSig ts vs a e) : ¬ B.externalResponse f ts vs (.exit n) obs := by
  intro hr
  exact (hA.external_typed Ψ f pureSig ts vs a e (.exit n) obs table_wf lookupF hargs hr).2 n rfl

/-- 変数がなくても型注釈が開いている外部ハンドルはGroundにならない。 -/
theorem open_annotation_not_ground : ¬ (Val.externalHandle handleA [.tvar 0]).Ground := by
  simp [Val.Ground, Val.ClosedAt, Ty.WF]

/-- 先行する実引数を結果型の外側参照へ代入する。 -/
def seven : Val := .const (.integer ⟨7, by decide⟩)
def dependent : Tel := .param "x" (.base .integer)
  (.done (.refined (.base .integer) (.eq (.var 0) (.var 1))) Eff.empty)

theorem sequential_instantiation : Tel.instantiate dependent [seven] =
    some (.refined (.base .integer) (.eq (.var 0) (.integer 7)), Eff.empty) := by
  simp only [dependent, Tel.instantiate, Tel.bind, Tel.rawBind, Tel.norm]
  simp [Integer64Value.toInt, Ty.rawBind, Ty.norm, Eff.rawBind, Eff.norm,
    Tel.argumentsEnv, valEnv, seven, Val.toTerm?, predBind, upValues, termBind, termBind?,
    Eff.empty, rowFails, rawBindTys, Ty.normTys, instAtoms_nil, substAtoms_nil]


theorem result_annotation : Ty.Annotation P [] []
    (.refined (.base .integer) (.eq (.var 0) (.integer 7))) := by
  constructor
  · simp [Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]
  · simp [Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape, Ty.HasSort, Ty.sort?,
      Term.References, Term.VarsIn, Ctx.Readable]
  · simp [Ty.Declared, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.extend,
      Ty.shiftV, Ctx.Readable]

theorem dependent_typed : HasTypeTelArgs P B StoreTy.empty [] [] [] [seven] dependent
    (.refined (.base .integer) (.eq (.var 0) (.integer 7))) Eff.empty := by
  unfold dependent
  apply HasTypeTelArgsQ.param (v := seven) (a := .base .integer) (by constructor <;> trivial) (.V_Const trivial)
  have ht : HasTypeTelArgs P B StoreTy.empty [] [] [] []
      (.done (.refined (.base .integer) (.eq (.var 0) (.integer 7))) Eff.empty)
      (.refined (.base .integer) (.eq (.var 0) (.integer 7))) Eff.empty :=
    .done ⟨⟨result_annotation.wf, by simp [Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.WFList]⟩,
      ⟨result_annotation.sorted, trivial⟩, ⟨result_annotation.declared, trivial⟩⟩
  simpa [Tel.bind, Tel.rawBind, Tel.norm, Ty.rawBind, Ty.norm, Eff.rawBind, Eff.norm,
    Tel.argumentsEnv, valEnv, seven, Val.toTerm?, predBind, upValues, termBind, termBind?,
    Eff.empty, rowFails, rawBindTys, Ty.normTys, instAtoms_nil, substAtoms_nil, Integer64Value.toInt] using ht

theorem concrete_step_none (σ : PathEnv) :
    step P B σ (fun _ _ _ _ => (.val (.const .unit), []))
      (fun _ _ _ => (.val (.const .unit), [])) (fun _ => none) (fun _ => 0)
      (.run (.pure (.externalCall f [] [])) [] Store.empty) =
      some (none, .run (.pure (.ret (.const .unit))) [] Store.empty) := rfl

theorem trap_label_none (σ : PathEnv) :
    Step P { B with externalResponse := fun _ _ _ out obs => out = .err "trap" ∧ obs = [] } σ
      (.run (.pure (.externalCall f [] [])) [] Store.empty) none (.error ["trap"] [] Store.empty) :=
    .E_ExternalErr rfl lookupF ⟨rfl, rfl⟩

def exitTable : Builtins := { B with externalResponse := fun _ _ _ out obs => out = .exit 0 ∧ obs = [] }

theorem exit_input : ExternalArgs P exitTable StoreTy.empty pureSig [] [] (.base .unit) Eff.empty := by
  refine ⟨?_, ?_, by simp, by simp, ⟨trivial, rfl⟩, ?_⟩
  · exact ⟨rfl, pure_admissible.kinds, ⟨rfl, by intro i a p h; simp at h⟩, by simp [TypeAnnotations]⟩
  · have ht : HasTypeTelArgs P exitTable StoreTy.empty [] [] [] []
        (.done (.base .unit) Eff.empty) (.base .unit) Eff.empty := .done (pure_annotation [] [])
    simpa [pureSig, Tel.bind, Tel.rawBind, Tel.norm, Ty.rawBind, Ty.norm, Eff.rawBind,
      Eff.norm, Eff.empty, rowFails, rawBindTys, Ty.normTys, typeEnv, typeEnvAt, instAtoms_nil, substAtoms_nil] using ht
  · simp [Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.WFList]

theorem exit_response_assumptions_rejected : ¬ Builtins.ExternalAssumptions P exitTable := by
  intro h
  exact (h.external_typed StoreTy.empty f pureSig [] [] (.base .unit) Eff.empty (.exit 0) []
    table_wf lookupF exit_input ⟨rfl, rfl⟩).2 0 rfl

theorem exit_oracle_not_a_process_exit (σ : PathEnv) :
    step P exitTable σ (fun _ _ _ _ => (.exit 0, []))
      (fun _ _ _ => (.exit 0, [])) (fun _ => none) (fun _ => 0)
      (.run (.pure (.externalCall f [] [])) [] Store.empty) = none := rfl

theorem box_shape (unit : Bool) (a : Ty) (ha : a.norm = a)
    (h : ExternalValueType P (.mk 0) true a) :
    ExternalValueType P (.mk 0) unit (.data "Box" [a]) := by
  refine .data ["Box"] (by decide) (by decide) ?_ ?_ ?_
  · intro c
    by_cases he : c = "Box" <;> simp [P, he]
  · refine ⟨⟨"Box", ⟨"Box", 1, [.tvar 0]⟩, by simp [P], rfl⟩, ?_⟩
    intro c cd hc _
    by_cases he : c = "Box"
    · subst c; simp only [P, ↓reduceIte, Option.some.injEq] at hc; cases hc; rfl
    · simp [P, he] at hc
  · intro c cd hc _ field hm
    by_cases he : c = "Box"
    · subst c
      simp only [P, ↓reduceIte, Option.some.injEq] at hc
      cases hc
      simp only [List.mem_singleton] at hm
      cases hm
      simpa [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, typeEnvAt, shiftTypes_zero, ha] using h
    · simp [P, he] at hc

theorem finite_repeated_data_accepted :
    ExternalValueType P (.mk 0) false (.data "Box" [.data "Box" [.base .integer]]) :=
  box_shape false _ rfl (box_shape true _ rfl (.scalar trivial))

theorem refined_map_key_accepted : ExternalValueType P (.mk 0) false
    (.map (.refined (.base .integer) (.le (.integer 0) (.var 0))) (.base .string)) :=
  .map ⟨trivial, by decide, by decide⟩ (.scalar trivial)


/- 非空のuses・Stateの行・ハンドルの実引数を同じ署名で照合する。 -/
namespace Stateful

def getId : ExternalFunctionId := .mk 1
def stateRow : Eff := .mk (fun a => match a with
  | .name n (.fixed .top) => decide (n = stateEff)
  | _ => false) []
def getSig : ExternalSignature :=
  ⟨.mk 0, "get", [], [], .param "c" (.external idA []) (.done (.base .integer) stateRow),
    [⟨.argument 0, [], .borrow, idA⟩]⟩
def getProgram : Program :=
  { P with externals := P.externals ++ [(.function getId, .function getId getSig)] }

theorem get_annotation : Ty.Annotation getProgram [] [] (.dependentFn getSig.parameters) := by
  constructor
  · simp [getSig, Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.Canonical, stateRow, Eff.norm, Ty.normTys]
  · trivial
  · exact ⟨⟨⟨tdA, rfl, rfl, rfl⟩, trivial⟩, trivial, trivial⟩

theorem get_wf : getSig.WF getProgram := by
  refine ⟨rfl, rfl, get_annotation, ?_, ?_, by simp [getSig], ?_⟩
  · trivial
  · intro use
    constructor
    · intro h
      simp only [getSig, List.mem_singleton] at h
      cases h
      exact .argument .root
    · intro h
      cases h with
      | argument h => cases h; simp [getSig]
      | next h => cases h with | result h => cases h
  · exact .param (.handle rfl rfl rfl rfl rfl) (.done (.scalar trivial) rfl)

theorem get_admissible : ExternalCallAdmissible getProgram B [] getSig [] := by
  refine ⟨rfl, ⟨rfl, [], rfl, ?_⟩, ⟨rfl, ?_⟩, ?_⟩
  · intro i a k h; simp at h
  · intro i a p h; simp at h
  · intro t h; simp at h

theorem get_handle_typed : HasTypeV getProgram B StoreTy.empty [] [] []
    (.externalHandle handleA []) (.external idA []) := by
  apply HasTypeVQ.V_ExternalHandle handleA tdA rfl rfl rfl rfl
  exact ⟨trivial, trivial, ⟨⟨tdA, rfl, rfl, rfl⟩, trivial⟩⟩

theorem get_result_annotation : Ty.Annotation getProgram [] [] (.dependentFn (.done (.base .integer) stateRow)) := by
  constructor
  · simp [Ty.WF, Tel.WF, Eff.WF, stateRow, Eff.Canonical, Eff.norm, Ty.normTys, Ty.WFList]
  · trivial
  · trivial

theorem get_arguments : HasTypeTelArgs getProgram B StoreTy.empty [] [] [] [.externalHandle handleA []]
    (Tel.bind (typeEnv []) getSig.parameters) (.base .integer) stateRow := by
  have ht : HasTypeTelArgs getProgram B StoreTy.empty [] [] [] [.externalHandle handleA []]
      getSig.parameters (.base .integer) stateRow := by
    apply HasTypeTelArgsQ.param (v := .externalHandle handleA []) (a := .external idA [])
      ⟨trivial, trivial, ⟨⟨tdA, rfl, rfl, rfl⟩, trivial⟩⟩ get_handle_typed
    have hd : HasTypeTelArgs getProgram B StoreTy.empty [] [] [] []
        (.done (.base .integer) stateRow) (.base .integer) stateRow := .done get_result_annotation
    simpa [getSig, Tel.bind, Tel.rawBind, Tel.norm, Ty.rawBind, Ty.norm, Eff.rawBind, Eff.norm,
      Tel.argumentsEnv, valEnv, stateRow, rowFails, rawBindTys, Ty.normTys, instAtoms_nil, substAtoms_nil] using hd
  simpa [getSig, Tel.bind, Tel.rawBind, Tel.norm, Ty.rawBind, Ty.norm, Eff.rawBind, Eff.norm,
    stateRow, rowFails, rawBindTys, Ty.normTys, typeEnv, typeEnvAt, instAtoms_nil, substAtoms_nil] using ht

theorem get_call_typed : HasTypeC getProgram B StoreTy.empty [] [] [] none
    (.externalCall getId [] [.externalHandle handleA []]) (.base .integer) stateRow :=
  .C_External rfl get_wf get_admissible get_arguments

end Stateful

/- Nil | Cons(L)では、具体化後にも同じdataへの導出が必要になる。 -/
namespace Recursive

def recursiveProgram : Program :=
  { P with cons := fun c => if c = "Nil" then some ⟨"L", 0, []⟩
    else if c = "Cons" then some ⟨"L", 0, [.data "L" []]⟩ else none }

private theorem recursive_origin {component unit a}
    (h : ExternalValueType recursiveProgram component unit a) : a = .data "L" [] → False := by
  induction h with
  | data cs _ _ _ _ fields ih =>
    intro he
    cases he
    apply ih "Cons" ⟨"L", 0, [.data "L" []]⟩ (by simp [recursiveProgram]) rfl
      (.data "L" []) (by simp)
    simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, rawBindTys, Ty.normTys]
  | scalar _ | unit | bytes | handle _ _ _ _ _ | list _ _ | map _ _ _
  | flags _ _ _ _ _ _ _ | refined _ _ => intro he; cases he

theorem recursive_rejected (component : ComponentId) (unit : Bool) :
    ¬ ExternalValueType recursiveProgram component unit (.data "L" []) :=
  fun h => recursive_origin h rfl

end Recursive

end
end Benitoite.Release.Refinement.ExternalBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  for (name, _) in env.constants.toList do
    if name.toString.startsWith "Benitoite.Release.Refinement.ExternalBoundary." then
      elabCommand (← `(#print axioms $(mkIdent name)))
