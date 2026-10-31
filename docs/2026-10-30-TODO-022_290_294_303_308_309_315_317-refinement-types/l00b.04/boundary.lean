import Lean
import Benitoite.Release.Refinement.ExternalCheck
import Benitoite.Release.Refinement.ClosedKeys
import Benitoite.Release.Refinement.LogicSound
import Benitoite.Release.Refinement.Context.Capture

namespace Benitoite.Release.Refinement.ClosedBoundary
noncomputable section

def scalar : Ty := .base .integer8
def seven : Val := .const (.integer8 7)
def zero : Val := .const (.integer8 0)
def condition : Pred := .and (.not (.le (.var 0) (.add (.integer 1) (.integer 2))))
  (.eq (.add (.var 0) (.integer 1)) (.integer 8))
def positive : Ty := .refined scalar condition

macro "check_external" : tactic => `(tactic| (simp only [externalCheck, externalCheckEach,
  externalCheckFields, seven, zero, positive, scalar, condition, Val.toTerm?, Const.type,
  Ty.sort?, Pred.open, predBind, termBind, termBind?]; decide))

theorem scalar_ann (P : Program) : Ty.Annotation P [] [] scalar := ⟨trivial,trivial,trivial⟩
theorem positive_ann (P : Program) : Ty.Annotation P [] [] positive := by
  refine ⟨?_, ?_, ?_⟩
  · simp [positive, scalar, condition, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]
  · refine ⟨trivial, ?_⟩
    simp [condition, scalar, Pred.Sorted, Term.HasSort, Term.References, Term.VarsIn,
      Term.Shape, Ctx.Readable, Ty.HasSort, Ty.sort?, Ordinary]
  · simp [positive, scalar, condition, Ty.Declared, Pred.Declared, Term.Declared,
      Ctx.declarationSelf, Ctx.extend, Ty.shiftV, Ordinary, Ctx.Readable]

theorem closed_not_add : (condition.open (.integer 7)).evalClosed = some true := by decide
theorem not_add_ground : Entails [] (condition.open (.integer 7)) :=
  .ground (by decide) (by decide) closed_not_add

theorem seven_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] [] [] seven positive := by
  have ha := positive_ann P
  exact .V_Refine (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide)) rfl rfl ha.sorted.2 ha.wf.2.1 not_add_ground trivial ha.declared.2

def initial : Ctx := Ctx.extend [] positive
def cap : Capture := Capture.empty.extend seven

theorem captured_fact (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∀ p ∈ initial.facts, Entails [] (predBind (valEnv cap.env).values p) := by
  have hv : HasTypeV P B Ψ [] [] [] seven (Capture.empty.closeTy positive) := by
    simpa [Capture.closeTy, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, positive, scalar,
      condition, predBind, upValues, termBind, termBind?, valEnv, Capture.env, Capture.empty,
      Capture.values] using seven_typed P B Ψ
  have hc := (CaptureOk.empty P B Ψ none).extend (positive_ann P) hv (by trivial)
  intro p hp
  exact hc.conditions p (List.mem_append_left _ hp)

theorem actual_fact : condition ∈ initial.facts := by
  apply Ctx.mem_facts_extend.mpr
  exact Or.inl List.mem_cons_self

theorem capture_condition (P : Program) (B : Builtins) (Ψ : StoreTy) :
    Entails [] (predBind (valEnv cap.env).values condition) := captured_fact P B Ψ condition actual_fact

def unknownField : Term := .field ⟨"Box","Box",0,.integer⟩ (.dataValue "Box" [none])
def missing : Pred := .eq unknownField (.integer 0)

theorem missing_wf_sorted : missing.WF 0 ∧ missing.Sorted [] none := by decide
theorem missing_observation : missing.evalClosed = none := by decide
theorem not_missing_is_failure : missing.not.evalClosed = none := Pred.evalClosed_not_failure missing_observation
theorem invalid_sort : (Pred.not (.eq (.boolean false) (.integer 0))).evalClosed = none := by decide
theorem residual_variable : (Pred.eq (.var 0) (.integer 0)).evalClosed = none := by decide
theorem nested_residual_variable :
    (Pred.eq (.measure .listLength (.listValue [some (.var 0)])) (.integer 1)).evalClosed = none := by decide
theorem failure_and_false : (Pred.and .falsity missing).evalClosed = some false := by decide
theorem failure_or_true : (Pred.or .truth missing).evalClosed = some true := by decide

theorem list_none_length :
    (Pred.eq (.measure .listLength (.listValue [none,none])) (.integer 2)).evalClosed = some true := by decide
theorem utf8_lengths :
    (Pred.and (.eq (.measure .stringBytes (.string "あ")) (.integer 3))
      (.eq (.measure .stringCharacters (.string "あ")) (.integer 1))).evalClosed = some true := by decide
theorem bytes_length :
    (Pred.eq (.measure .bytesLength (.bytesValue [0,255])) (.integer 2)).evalClosed = some true := by decide
theorem character_code :
    (Pred.eq (.measure .characterCode (.character 'A')) (.integer 65)).evalClosed = some true := by decide
theorem neg_scale :
    (Pred.eq (.add (.neg (.integer 4)) (.scale 3 (.integer 2))) (.integer 2)).evalClosed = some true := by decide

def dec1 : Term := .decimal 10 1
def dec2 : Term := .decimal 100 2

theorem decimal_equal : (Pred.compare .decimal .eq dec1 dec2).evalClosed = some true := by decide
theorem decimal_key_equal : Key.equal dec1 dec2 = some true := by decide +kernel

theorem map_last_value : Key.normalizeMap [some dec1,some dec2]
    [some (.integer 1),some (.integer 2)] = some [(dec1,some (.integer 2))] := by cbv

theorem map_size :
    (Pred.eq (.measure .mapSize (.mapValue [some dec1,some dec2] [none,none])) (.integer 1)).evalClosed = some true  := by decide +kernel

theorem set_size :
    (Pred.eq (.measure .setSize (.setValue [some dec1,some dec2])) (.integer 1)).evalClosed = some true  := by decide +kernel

theorem missing_key_rejected :
    (Pred.eq (.measure .mapSize (.mapValue [none] [none])) (.integer 1)).evalClosed = none := by decide
theorem key_none_rejected : Key.normalizeSet [none,none] = none := by decide
theorem float_key_rejected : Key.equal (.float64 0) (.float64 0) = none := by decide +kernel

theorem float_nan_equality :
    (Pred.compare .float64 .eq (.float64 0x7ff8000000000000) (.float64 0x7ff8000000000000)).evalClosed = some false := by decide
theorem float_nan_not_lt :
    (Pred.not (.compare .float64 .lt (.float64 0x7ff8000000000000) (.float64 0))).evalClosed = some true := by decide
theorem float_nan_ge :
    (Pred.compare .float64 .ge (.float64 0x7ff8000000000000) (.float64 0)).evalClosed = some false := by decide
theorem signed_zero_equal :
    (Pred.compare .float64 .eq (.float64 0x8000000000000000) (.float64 0)).evalClosed = some true := by decide
theorem float32_class :
    (Pred.floatClass .binary32 .negativeInfinity (.float32 0xff800000)).evalClosed = some true := by decide

theorem atomic_sort_table :
    [Pred.compare .character .lt (.character 'a') (.character 'b'),
     Pred.compare .boolean .ne (.boolean true) (.boolean false),
     Pred.compare .string .eq (.string "x") (.string "x"),
     Pred.compare .unit .eq .unitValue .unitValue,
     Pred.decimalRepresented (.decimal 12 1),
     Pred.charactersIn (.string "abc") 'a' 'z',
     Pred.constructorIs (.dataValue "Box" []) "Box",
     Pred.member .path (.targetValue none (.path ["tmp"])) (.path (.tree []))].map Pred.evalClosed =
    List.replicate 8 (some true) := by decide

theorem unbound_snapshot :
    (Pred.not (.member .path (.targetValue none (.path ["tmp"])) (.based .work (.tree [])))).evalClosed = none := by decide

theorem wrong_field_constructor :
    (Pred.eq (.field ⟨"Box","Other",0,.integer⟩ (.dataValue "Box" [some (.integer 1)]))
      (.integer 1)).evalClosed = none := by decide

theorem seven_carrier (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ExternalCarrier P B Ψ seven positive := .refined (.scalar (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide))) (positive_ann P)
theorem zero_carrier (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ExternalCarrier P B Ψ zero positive := .refined (.scalar (.V_Const (by change (-128 : Int) ≤ 0 ∧ 0 ≤ 127; decide))) (positive_ann P)
theorem receive_seven : externalCheck P seven positive = true := by check_external
theorem receive_zero : externalCheck P zero positive = false := by check_external
theorem received_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] [] [] seven positive := (seven_carrier P B Ψ).checked_typed receive_seven
theorem failed_receive_err (P : Program) :
    externalCheckedOutcome P positive (.val zero) = .err "ExternalRefinement" :=
  externalCheckedOutcome_reject receive_zero

theorem receive_list : externalCheck P (.list [seven,seven]) (.list positive) = true := by check_external
theorem reject_list : externalCheck P (.list [seven,zero]) (.list positive) = false := by check_external
theorem reject_map_key : externalCheck P (.mapV [zero] [seven]) (.map positive positive) = false := by check_external
theorem reject_map_value : externalCheck P (.mapV [seven] [zero]) (.map positive positive) = false := by check_external
theorem reject_set : externalCheck P (.setV [zero]) (.set positive) = false := by check_external

def boxDecl : ConDecl := ⟨"Box",0,[positive]⟩
def program : Program := ⟨fun _ => none, fun c => if c = "Box" then some boxDecl else none,
  fun _ => none, fun _ => none, fun _ => none, fun _ => none, []⟩

theorem positive_subst : positive.subst [] [] = positive := by
  simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, positive, scalar, typeEnvAt]

theorem receive_data : externalCheck program (.con "Box" [] [seven]) (.data "Box" []) = true  := by
  simp [externalCheck, externalCheckFields, program, boxDecl, positive_subst, receive_seven]

theorem reject_data_field : externalCheck program (.con "Box" [] [zero]) (.data "Box" []) = false  := by
  simp [externalCheck, externalCheckFields, program, boxDecl, positive_subst, receive_zero]

theorem reject_nested_data :
    externalCheck program (.list [.con "Box" [] [zero]]) (.list (.data "Box" [])) = false  := by
  simp [externalCheck, externalCheckEach, externalCheckFields, program, boxDecl,
    positive_subst, receive_zero]

theorem box_ann : Ty.Annotation program [] [] (.data "Box" []) := by
  refine ⟨by trivial, by trivial, ?_⟩
  refine ⟨⟨0, ⟨?_, ?_⟩, rfl⟩, trivial⟩
  · exact ⟨"Box", boxDecl, rfl, rfl⟩
  · intro c cd hc _
    by_cases he : c = "Box"
    · subst c; have hx : cd = boxDecl := Option.some.inj hc.symm; subst cd; rfl
    · simp [program, he] at hc

theorem box_carrier (B : Builtins) (Ψ : StoreTy) :
    ExternalCarrier program B Ψ (.con "Box" [] [seven]) (.data "Box" []) := by
  apply ExternalCarrier.data (cd := boxDecl) rfl rfl
  · exact ⟨rfl, [], rfl, by simp⟩
  · intro a ha
    have he : a = positive := List.mem_singleton.mp ha
    subst a
    exact (positive_ann program).wf
  · change ExternalCarrierFields program B Ψ [seven] [positive.subst [] []]
    rw [positive_subst]
    exact .cons (seven_carrier program B Ψ) .nil
  · exact box_ann

theorem received_data_typed (B : Builtins) (Ψ : StoreTy) :
    HasTypeV program B Ψ [] [] [] (.con "Box" [] [seven]) (.data "Box" []) :=
  (box_carrier B Ψ).checked_typed receive_data

theorem data_inside_map_typed (B : Builtins) (Ψ : StoreTy) (hk : B.sat [] positive TParam.keyC) :
    HasTypeV program B Ψ [] [] [] (.mapV [seven] [.con "Box" [] [seven]])
      (.map positive (.data "Box" [])) := by
  have hc : ExternalCarrier program B Ψ (.mapV [seven] [.con "Box" [] [seven]])
      (.map positive (.data "Box" [])) :=
    .map (.cons (seven_carrier program B Ψ) .nil) (.cons (box_carrier B Ψ) .nil)
      rfl hk (positive_ann program) box_ann
  apply hc.checked_typed
  simp [externalCheck, externalCheckEach, externalCheckFields, receive_seven, program,
    boxDecl, positive_subst]

-- この入力は組込みの契約の充足モデルではなく、鍵の制約だけを指定する有限の例である。
def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }

theorem concrete_received_map :
    HasTypeV program builtins (fun _ => none) [] [] [] (.mapV [seven] [.con "Box" [] [seven]])
      (.map positive (.data "Box" [])) := data_inside_map_typed builtins _ trivial

def lengthCondition : Pred := .not (.le (.add (.measure .listLength (.var 0)) (.integer 1)) (.integer 2))
def sized : Ty := .refined (.list scalar) lengthCondition

theorem length_ground : Entails [] (lengthCondition.open (.listValue [some (.integer 7), some (.integer 7)])) :=
  .ground (by decide) (by decide) (by decide)

theorem sized_ann (P : Program) : Ty.Annotation P [] [] sized := by
  refine ⟨?_, ?_, ?_⟩
  · simp [sized, scalar, lengthCondition, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]
  · simp [sized, scalar, lengthCondition, Ty.Sorted, Pred.Sorted, Term.HasSort,
      Term.References, Term.VarsIn, Term.Shape, Ctx.Readable, Ty.HasSort, Ty.sort?,
      Ordinary, Measure.input, Measure.output]
  · simp [sized, scalar, lengthCondition, Ty.Declared, Pred.Declared, Term.Declared,
      Ctx.declarationSelf, Ctx.extend, Ty.shiftV, Ordinary, Ctx.Readable]

theorem actual_length_refined (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] [] [] (.list [seven,seven]) sized := by
  have hs : HasTypeV P B Ψ [] [] [] seven scalar := .V_Const (by change (-128:Int) ≤ 7 ∧ 7 ≤ 127; decide)
  have ha := sized_ann P
  exact .V_Refine (.V_List (.cons hs (.cons hs .nil)) trivial trivial trivial)
    rfl rfl ha.sorted.2 ha.wf.2.1 length_ground trivial ha.declared.2

theorem full_carrier_erasure :
    (Ty.refined (.map positive (.list (.refined (.data "Box" [positive]) .truth))) .truth).carrier =
      .map scalar (.list (.data "Box" [scalar])) := rfl

theorem sortless_truth (P : Program) : externalCheck P (.externalHandle ⟨⟨0⟩,⟨0⟩,0,0⟩ [])
    (.refined (.external ⟨0⟩ []) .truth) = true := by check_external

theorem observed_length :
    (lengthCondition.open (.listValue [some (.integer 7), some (.integer 7)])).ClosedObservable :=
  .not (.atom trivial (by decide))

theorem complete_length :
    (lengthCondition.open (.listValue [some (.integer 7), some (.integer 7)])).evalClosed =
      some ((lengthCondition.open (.listValue [some (.integer 7), some (.integer 7)])).interpret (fun _ => none)) :=
  Pred.evalClosed_complete (by decide) (by decide) observed_length

theorem missing_not_observable : ¬ missing.ClosedObservable := by
  intro h
  cases h with
  | atom _ hr => change false = true at hr; cases hr

theorem contradiction_not_ground : ¬ Entails [] (.eq (.integer 1) (.integer 2)) := by
  intro h
  have he := h.sound (fun _ => none) (by simp)
  change false = true at he
  cases he

theorem ground_survives_bind :
    Entails [] (predBind (fun _ => none) (condition.open (.integer 7))) := not_add_ground.bind _

theorem zero_still_has_carrier (B : Builtins) (Ψ : StoreTy) :
    ExternalCarrier program B Ψ (.con "Box" [] [zero]) (.data "Box" []) := by
  apply ExternalCarrier.data (cd := boxDecl) rfl rfl
  · exact ⟨rfl, [], rfl, by simp⟩
  · intro a ha
    have he : a = positive := List.mem_singleton.mp ha
    subst a
    exact (positive_ann program).wf
  · change ExternalCarrierFields program B Ψ [zero] [positive.subst [] []]
    rw [positive_subst]
    exact .cons (zero_carrier program B Ψ) .nil
  · exact box_ann

theorem received_data_violation_err :
    externalCheckedOutcome program (.data "Box" []) (.val (.con "Box" [] [zero])) =
      .err "ExternalRefinement" := externalCheckedOutcome_reject reject_data_field

theorem evaluation_failure_rejects_receive (P : Program) :
    externalCheck P seven (.refined scalar missing) = false := by check_external

theorem sort_failure_rejects_receive (P : Program) :
    externalCheck P seven (.refined scalar (.eq (.boolean true) (.integer 0))) = false := by check_external

theorem unordered_nested_keys :
    Key.equal
      (.mapValue [some (.integer 1),some (.integer 2)] [some dec1,some (.integer 4)])
      (.mapValue [some (.integer 2),some (.integer 1)] [some (.integer 4),some dec2]) = some true := by cbv

theorem set_keys_ignore_order_duplicates :
    Key.equal (.setValue [some dec1,some (.integer 2),some dec2])
      (.setValue [some (.integer 2),some dec1]) = some true := by cbv

theorem all_comparisons :
    [Comparison.eq, .ne, .lt, .le, .gt, .ge].map (fun o =>
      (Pred.compare .decimal o (.decimal (-10) 1) (.decimal 20 1)).evalClosed) =
      [some false, some true, some true, some true, some false, some false] := by decide

theorem all_float_classes :
    [FloatClass.finite, .nan, .positiveInfinity, .negativeInfinity, .positiveZero, .negativeZero].map
      (fun c => (Pred.floatClass .binary64 c (.float64 0x8000000000000000)).evalClosed) =
      [some true,some false,some false,some false,some false,some true] := by decide

def handle : ExternalHandle := ⟨⟨0⟩,⟨0⟩,0,0⟩
def handleDecl : ExternalTypeDecl := ⟨⟨0⟩,⟨0⟩,"Handle",0,0⟩
def handleProgram : Program := {program with externals := [(.type ⟨0⟩,.type handleDecl)]}
def handleTy : Ty := .external ⟨0⟩ []

theorem handle_ann : Ty.Annotation handleProgram [] [] handleTy :=
  ⟨trivial,trivial,⟨⟨handleDecl,rfl,rfl,rfl⟩,trivial⟩⟩

theorem handle_refined_ann : Ty.Annotation handleProgram [] [] (.refined handleTy .truth) := by
  refine ⟨?_, ⟨trivial,trivial⟩, ⟨handle_ann.declared,trivial⟩⟩
  simp [handleTy, Ty.WF, Ty.WFList, Pred.WF, Pred.VarsIn, Ty.NotContCore, Ty.core]

theorem handle_refined_typed (B : Builtins) (Ψ : StoreTy) :
    HasTypeV handleProgram B Ψ [] [] [] (.externalHandle handle []) (.refined handleTy .truth) := by
  have hc : ExternalCarrier handleProgram B Ψ (.externalHandle handle []) (.refined handleTy .truth) :=
    .refined (.handle (.V_ExternalHandle handle handleDecl rfl rfl rfl rfl handle_ann)) handle_refined_ann
  apply hc.checked_typed
  simp only [externalCheck, handleTy, handle, Ty.sort?]
  decide

theorem receive_outer_sized (P : Program) : externalCheck P (.list [seven,seven]) sized = true := by
  simp only [externalCheck, externalCheckEach, sized, scalar, seven, Val.toTerm?, Ty.sort?]
  decide

theorem receive_sized_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeV P B Ψ [] [] [] (.list [seven,seven]) sized := by
  have hc : ExternalCarrier P B Ψ (.list [seven,seven]) sized :=
    .refined (.list (.cons (.scalar (.V_Const (by change (-128:Int) ≤ 7 ∧ 7 ≤ 127; decide)))
      (.cons (.scalar (.V_Const (by change (-128:Int) ≤ 7 ∧ 7 ≤ 127; decide))) .nil))
      (scalar_ann P)) (sized_ann P)
  exact hc.checked_typed (receive_outer_sized P)

theorem model_default_is_not_evaluation_success :
    (Term.add unknownField (.integer 1)).interpret (fun _ => none) = some (.integer 1) ∧
    (Pred.eq (.add unknownField (.integer 1)) (.integer 1)).evalClosed = none := by
  constructor
  · rfl
  · decide

end
end Benitoite.Release.Refinement.ClosedBoundary


open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let ns := env.constants.toList.filterMap fun (n,_) =>
    if (`Benitoite.Release.Refinement.ClosedBoundary).isPrefixOf n then some n else none
  let ns := ns.mergeSort (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {ns.length}"
  for n in ns do elabCommand (← `(#print axioms $(mkIdent n)))
