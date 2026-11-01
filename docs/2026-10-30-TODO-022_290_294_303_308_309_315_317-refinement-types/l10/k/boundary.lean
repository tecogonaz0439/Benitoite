import Lean
import Benitoite.Release.Refinement.LegacyValues
import Benitoite.Release.Refinement.LegacyTableFacts

namespace Benitoite.Release.Refinement.L10KBoundary
noncomputable section

def kinds : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def program : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def oldBuiltins : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def builtins : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def store : Benitoite.Release.StoreTy := fun _ => none
def unit : Benitoite.Release.Ty := .base .unit

theorem tables : LegacyTables kinds program oldBuiltins builtins := by
  constructor <;> simp [program, oldBuiltins, builtins]

theorem input_unit (Δ : LegacyInputCtx) : LegacyTypeInput kinds program Δ unit .value :=
  ⟨trivial, trivial, trivial, trivial, trivial⟩
theorem annotation_unit (Γ : Ctx) : Ty.Annotation (embedProgramWithKinds kinds program) [] Γ (.base .unit) :=
  ⟨trivial, trivial, trivial⟩
theorem empty_row (Δ : LegacyInputCtx) : LegacyRowsInput kinds program Δ [Benitoite.Release.Eff.empty] := by
  intro e he
  simp only [List.mem_singleton] at he; subst e
  refine ⟨⟨⟨rfl, by simp⟩, trivial, trivial, trivial⟩, ?_, ⟨trivial, trivial, trivial⟩, ⟨trivial, trivial, trivial⟩, ?_⟩
  · exact ⟨⟨rfl, by simp⟩, trivial, trivial, trivial, embed_canonical rfl⟩
  · refine ⟨trivial, trivial, ?_, trivial⟩
    intro name ix h
    cases ix with
    | fixed _ => trivial
    | rvar i => simp [embedAtoms, Atom.toOld?] at h

theorem context_empty : LegacyNodeContext kinds program [] store [] [] := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · intro l lt h; cases h
  · intro i a h; simp at h

theorem context_one : LegacyNodeContext kinds program [] store [] [some unit] := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · intro l lt h; cases h
  · intro i a h
    cases i <;> simp [unit] at h
    subst a
    exact ⟨input_unit _, annotation_unit _⟩

def constNode : LegacyJudgment := .value [] store Benitoite.Release.Qempty [] [] (.const .unit) unit
def leftNode : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [] none (.ret (.const .unit)) unit Benitoite.Release.Eff.empty []
def variableNode : LegacyJudgment := .value [] store Benitoite.Release.Qempty [] [some unit] (.var 0) unit
def rightNode : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [some unit] none (.ret (.var 0)) unit Benitoite.Release.Eff.empty []
def letNode : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [] none
  (.letIn (.ret (.const .unit)) (.ret (.var 0))) unit Benitoite.Release.Eff.empty []

theorem const_regular : LegacyNodeRegular kinds program oldBuiltins builtins constNode :=
  ⟨context_empty, trivial, trivial, by intro a ha; simp at ha; subst a; exact input_unit _⟩
theorem variable_regular : LegacyNodeRegular kinds program oldBuiltins builtins variableNode :=
  ⟨context_one, trivial, trivial, by intro a ha; simp at ha; subst a; exact input_unit _⟩
theorem left_regular : LegacyNodeRegular kinds program oldBuiltins builtins leftNode :=
  ⟨context_empty, trivial, by intro a ha; simp at ha; subst a; exact input_unit _, empty_row _, by simp [LegacyNodeLocal]⟩
theorem right_regular : LegacyNodeRegular kinds program oldBuiltins builtins rightNode :=
  ⟨context_one, trivial, by intro a ha; simp at ha; subst a; exact input_unit _, empty_row _, by simp [LegacyNodeLocal]⟩
theorem let_regular : LegacyNodeRegular kinds program oldBuiltins builtins letNode :=
  ⟨context_empty, ⟨trivial, trivial⟩, by intro a ha; simp at ha; subst a; exact input_unit _, empty_row _, by simp [LegacyNodeLocal]⟩

theorem const_input : LegacyOutputInput kinds program oldBuiltins builtins constNode :=
  .node .V_Const const_regular (by simp)
theorem variable_input : LegacyOutputInput kinds program oldBuiltins builtins variableNode :=
  .node (.V_Var rfl (by intro b t e h; cases h)) variable_regular (by simp)
theorem left_input : LegacyOutputInput kinds program oldBuiltins builtins leftNode :=
  .node .C_Return left_regular (by intro child hc; simp only [List.mem_singleton] at hc; subst child; exact const_input)
theorem right_input : LegacyOutputInput kinds program oldBuiltins builtins rightNode :=
  .node .C_Return right_regular (by intro child hc; simp only [List.mem_singleton] at hc; subst child; exact variable_input)
theorem let_input : LegacyOutputInput kinds program oldBuiltins builtins letNode :=
  .node (.C_Let (a := unit)) let_regular (by
    intro child hc; simp only [List.mem_cons, List.not_mem_nil, or_false] at hc
    rcases hc with rfl | rfl
    · exact left_input
    · exact right_input)
theorem let_old : letNode.OldHolds program oldBuiltins := let_input.old

-- 空リストの要素の型は旧 WF に通るが、value kind でない。
def badType : Benitoite.Release.Ty := .list (.ctor .list)
def badLeft : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [] none (.ret (.list [])) badType Benitoite.Release.Eff.empty []
def badRight : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [some badType] none (.ret (.const .unit)) unit Benitoite.Release.Eff.empty []
def badLet : LegacyJudgment := .comp [] store Benitoite.Release.Qempty [] [] none
  (.letIn (.ret (.list [])) (.ret (.const .unit))) unit Benitoite.Release.Eff.empty []

theorem bad_left_old : badLeft.OldHolds program oldBuiltins :=
  .C_Return (.V_List .nil trivial)
theorem bad_let_old : badLet.OldHolds program oldBuiltins :=
  .C_Let bad_left_old (.C_Return .V_Const)
theorem bad_root_regular : LegacyNodeRegular kinds program oldBuiltins builtins badLet :=
  ⟨context_empty, ⟨trivial, trivial⟩, by intro a ha; simp at ha; subst a; exact input_unit _, empty_row _, by simp [LegacyNodeLocal]⟩
theorem bad_let_rule : LegacyRule kinds program oldBuiltins badLet [badLeft, badRight] := .C_Let

theorem reject_intermediate : ¬ LegacyOutputInput kinds program oldBuiltins builtins badLeft := by
  intro h
  have typed := h.regular.2.2.1 badType (by simp)
  exact typed.1

theorem reject_bad_children : ¬ (∀ child ∈ [badLeft, badRight], LegacyOutputInput kinds program oldBuiltins builtins child) :=
  fun h => reject_intermediate (h _ (by simp))

-- constructor 欄は旧の範囲だけでは適格性を示せない。
def badConstructor : Benitoite.Release.ConDecl := ⟨"Bad", 0, [.ctor .list]⟩
def badProgram : Benitoite.Release.Program := { program with cons := fun _ => some badConstructor }
theorem reject_constructor_table : ¬ LegacyTables kinds badProgram oldBuiltins builtins := by
  intro h
  have field := (h.constructorFields "Bad.C" badConstructor rfl (.ctor .list) (by simp [badConstructor])).2
  exact field

-- 型変数の範囲が壊れた欄は Annotation で拒む。
def unscopedConstructor : Benitoite.Release.ConDecl := ⟨"Bad", 0, [.tvar 0]⟩
def unscopedProgram : Benitoite.Release.Program := { program with cons := fun _ => some unscopedConstructor }
theorem reject_constructor_annotation : ¬ LegacyTables kinds unscopedProgram oldBuiltins builtins := by
  intro h
  have field := (h.constructorFields "Bad.C" unscopedConstructor rfl (.tvar 0) (by simp [unscopedConstructor])).1
  exact Nat.not_lt_zero 0 field.wf

def arityProgram : Benitoite.Release.Program := { program with cons := fun c =>
  if c = "Zero" then (some { data := "Same", ntys := 0, args := [] }) else (some { data := "Same", ntys := 1, args := [] }) }

theorem reject_constructor_arity : ¬ LegacyTables kinds arityProgram oldBuiltins builtins := by
  intro h
  have same := h.constructorArity "Zero" ⟨"Same", 0, []⟩ "One" ⟨"Same", 1, []⟩
    (by simp [arityProgram]) (by simp [arityProgram]) rfl
  exact Nat.zero_ne_one same

end
end Benitoite.Release.Refinement.L10KBoundary

namespace Benitoite.Release.Refinement.L10KHigherKinds
open L10KBoundary
noncomputable section

def optionDecl : Benitoite.Release.ConDecl := ⟨"Option", 1, []⟩
def functionDecl : Benitoite.Release.Def :=
  ⟨[{}], 0, ["d"], [.dict "Functor" (.tvar 0)], .base .unit, Benitoite.Release.Eff.empty, .ret (.const .unit)⟩
def methodDecl : Benitoite.Release.MethSig := ⟨[], 0, [], [], .base .unit, Benitoite.Release.Eff.empty⟩
def classDecl : Benitoite.Release.ClassDecl := ⟨[], fun m => if m = "ping" then some methodDecl else none⟩
def hkKinds : DeclarationKinds := ⟨fun _ => .constructor 1, fun _ => [.constructor 1], fun _ _ => []⟩
def hkProgram : Benitoite.Release.Program := { program with
  cons := fun _ => some optionDecl
  defs := fun _ => some functionDecl
  classes := fun _ => some classDecl }

theorem kinds_wf : hkKinds.WF hkProgram := by
  constructor
  · intro f d hd; cases hd; rfl
  · intro cl cd m ms hc hm
    cases hc; simp only [classDecl] at hm
    split at hm <;> cases hm
    rfl

theorem arity : (embedProgramWithKinds hkKinds hkProgram).DataArity "Option" 1 := by
  refine ⟨⟨"None", embedConDecl optionDecl, rfl, rfl⟩, ?_⟩
  intro c cd hc _
  change some (embedConDecl optionDecl) = some cd at hc
  cases hc; rfl

theorem option_kind : (embedTy (.ctor (.data "Option"))).HasKind (embedProgramWithKinds hkKinds hkProgram) [] (.constructor 1) :=
  TyCon.arity_data arity

theorem option_not_value : ¬ (embedTy (.ctor (.data "Option"))).HasKind (embedProgramWithKinds hkKinds hkProgram) [] .value :=
  fun h => h

theorem functor_dictionary : (embedTy (.dict "Functor" (.ctor (.data "Option")))).HasKind
    (embedProgramWithKinds hkKinds hkProgram) [] .value :=
  embed_dictionary_kind (show hkProgram.classes "Functor" = some classDecl from rfl) option_kind

theorem all_value_loses_kind : ¬ (embedTy (.dict "Functor" (.ctor (.data "Option")))).HasKind (embedProgram hkProgram) [] .value := by
  rintro ⟨cd, hc, hk⟩
  change some (embedClassDecl classDecl) = some cd at hc
  cases hc
  exact hk

theorem option_annotation (Γ : Ctx) : Ty.Annotation (embedProgramWithKinds hkKinds hkProgram) [] Γ (embedTy (.ctor (.data "Option"))) :=
  ⟨trivial, trivial, ⟨1, arity⟩⟩

theorem option_args : LegacyKindArgs hkKinds hkProgram [] [.ctor (.data "Option")] [.constructor 1] := by
  refine ⟨rfl, ?_⟩
  intro i a k ha hk
  cases i with
  | zero => simp only [List.getElem?_cons_zero, Option.some.injEq] at ha hk; subst a; subst k; exact option_kind
  | succ i => simp at ha

theorem function_signature : SignatureInstance (embedProgramWithKinds hkKinds hkProgram) [] []
    (embedDefWithKinds (hkKinds.functionParams "f") functionDecl).tel [.constructor 1]
    (embedTys [.ctor (.data "Option")]) [] := by
  apply legacy_signatureInstance (κ := []) (es := []) rfl
  · change (Ty.dependentFn (.param "d" (.dict "Functor" (.tvar 0))
      (.done (.base .unit) (embedEff Benitoite.Release.Eff.empty)))).WF 0 1 0
    exact ⟨show 0 < 1 from Nat.zero_lt_succ 0, trivial, trivial, embed_canonical (e := Benitoite.Release.Eff.empty) rfl⟩
  · intro t ht; simp only [embedTys, List.mem_singleton] at ht; subst t; exact option_annotation _
  · exact option_args
  · simp [RowAnnotations]
  · unfold instantiatedTel Tel.bind
    constructor
    · exact ⟨trivial, trivial, trivial, Eff.norm_idem _⟩
    · exact ⟨trivial, trivial, trivial⟩
    · exact ⟨⟨1, arity⟩, trivial, trivial⟩

theorem function_signature_actual : SignatureInstance (embedProgramWithKinds hkKinds hkProgram) [] []
    (embedDefWithKinds (hkKinds.functionParams "f") functionDecl).tel
    ((embedDefWithKinds (hkKinds.functionParams "f") functionDecl).tparams.map TParamDecl.kind)
    (embedTys [.ctor (.data "Option")]) [] := by
  rw [(embedDefWithKinds_parameters kinds_wf (show hkProgram.defs "f" = some functionDecl from rfl)).2]
  exact function_signature

theorem method_signature (Γ : Ctx) : SignatureInstance (embedProgramWithKinds hkKinds hkProgram) [] Γ
    (embedMethSigWithKinds (hkKinds.methodParams "Functor" "ping") methodDecl).tel
    ((embedMethSigWithKinds (hkKinds.methodParams "Functor" "ping") methodDecl).tparams.map TParamDecl.kind ++
      [(embedClassDeclWithKinds hkKinds "Functor" classDecl).argumentKind])
    (embedTys [.ctor (.data "Option")]) [] := by
  apply legacy_signatureInstance (κ := []) (es := []) rfl
  · exact ⟨trivial, trivial, embed_canonical (e := Benitoite.Release.Eff.empty) rfl⟩
  · intro t ht; simp only [embedTys, List.mem_singleton] at ht; subst t; exact option_annotation _
  · exact option_args
  · simp [RowAnnotations]
  · constructor
    · exact ⟨trivial, trivial, Eff.norm_idem _⟩
    · exact ⟨trivial, trivial⟩
    · exact ⟨trivial, trivial⟩

theorem function_admissible : Admissible builtins [] 0 [{}] 0
    (Qsig (embedDefWithKinds (hkKinds.functionParams "f") functionDecl).params
      (embedDefWithKinds (hkKinds.functionParams "f") functionDecl).ret
      (embedDefWithKinds (hkKinds.functionParams "f") functionDecl).eff)
    Benitoite.Release.Qempty (embedTys [.ctor (.data "Option")]) []
    (embedDefWithKinds (hkKinds.functionParams "f") functionDecl).eff := by
  constructor
  · exact ⟨rfl, by intros; trivial⟩
  · intro t ht
    simp only [embedTys, List.mem_singleton] at ht; subst t
    exact ⟨trivial, by intro b r e h; cases h⟩
  · rfl
  · simp
  · constructor
    · intro i h; simp [embedAtoms, Atom.toOld?] at h
    · trivial
  · intro i h
    change (False ∨ False) ∨ False ∨ ((([] : List Ty) ≠ [] ∧ _) ∨ False) at h
    simp at h
  · intro i h
    change (False ∨ False) ∨ False ∨ ((([] : List Ty) ≠ [] ∧ _) ∨ False) at h
    simp at h

theorem function_entry : HasTypeVQ (embedProgramWithKinds hkKinds hkProgram) builtins
    StoreTy.empty Benitoite.Release.Qempty [] [] []
    (.fnRef "f" (embedTys [.ctor (.data "Option")]) [])
    (.dependentFn (instantiatedTel (embedDefWithKinds (hkKinds.functionParams "f") functionDecl).tel
      (embedTys [.ctor (.data "Option")]) [])) := by
  refine .V_Fun (embedProgramWithKinds_def rfl) ?_ function_admissible function_signature_actual
  simp [NamesWF, embedDefWithKinds, embedDef, functionDecl, embedParameters]

theorem method_entry : ∃ a e, HasTypeCQ (embedProgramWithKinds hkKinds hkProgram) builtins
    StoreTy.empty Benitoite.Release.Qempty [] [some (.dict "Functor" (.ctor (.data "Option")))] [] none
    (.meth (.var 0) "ping" [] [] []) a e [] := by
  refine ⟨_, _, .C_Meth (.V_Var rfl (by intro b t e h; cases h))
    (embedProgramWithKinds_class (show hkProgram.classes "Functor" = some classDecl from rfl))
    (show (embedClassDeclWithKinds hkKinds "Functor" classDecl).methods "ping" =
      some (embedMethSigWithKinds [] methodDecl) from by simp [embedClassDeclWithKinds, classDecl, hkKinds])
    (by simp [NamesWF, embedMethSigWithKinds, embedMethSig, methodDecl, embedParameters]) ⟨rfl, by simp⟩ (method_signature _) ?_ (by
      change (Tel.done (.base .unit) _).arguments [] = some ([], _, _)
      simp only [Tel.arguments, Ty.norm]; rfl) .nil ?_⟩
  · refine ⟨rfl, by simp, ?_, ?_, ?_⟩
    · constructor
      · intro i h; simp [embedAtoms, Atom.toOld?] at h
      · trivial
    · intro i h
      change False ∨ False ∨ ((([] : List Ty) ≠ [] ∧ _) ∨ False) at h
      simp at h
    · intro i h
      change False ∨ False ∨ ((([] : List Ty) ≠ [] ∧ _) ∨ False) at h
      simp at h
  · exact ⟨trivial, trivial, trivial⟩

theorem hk_tables : LegacyTables hkKinds hkProgram oldBuiltins builtins := by
  constructor <;> simp [hkProgram, optionDecl, oldBuiltins, builtins]

theorem option_type_input : LegacyTypeInput hkKinds hkProgram .closed (.ctor (.data "Option")) (.constructor 1) :=
  ⟨option_kind, trivial, trivial, ⟨1, arity⟩, trivial⟩

theorem function_source_input : LegacyTypeInput hkKinds hkProgram
    ⟨hkKinds.functionParams "f", functionDecl.tparams, 0, 0⟩
    (.fn functionDecl.names functionDecl.params functionDecl.ret functionDecl.eff) .value := by
  refine ⟨?_, ?_, embedTy_sorted _ _, ?_, ?_⟩
  · exact ⟨⟨rfl, by simp [functionDecl]⟩,
      ⟨⟨embedClassDeclWithKinds hkKinds "Functor" classDecl, rfl, rfl⟩, trivial⟩, trivial, trivial⟩
  · exact ⟨⟨rfl, by simp [functionDecl]⟩, ⟨Nat.zero_lt_succ 0, trivial⟩,
      trivial, trivial, embed_canonical (e := Benitoite.Release.Eff.empty) rfl⟩
  · exact ⟨⟨trivial, trivial⟩, trivial, trivial⟩
  · exact ⟨⟨trivial, trivial⟩, trivial, (empty_row .closed _ (by simp [functionDecl])).2.2.2.2.2.2⟩

theorem legacy_function_syntax : LegacyValueInput hkKinds hkProgram oldBuiltins builtins .closed
    (.fnRef "f" [.ctor (.data "Option")] []) := by
  refine ⟨functionDecl, rfl, function_source_input, ⟨rfl, ?_⟩, by simp [LegacyRowsInput]⟩
  intro i a k ha hk
  cases i with
  | zero => simp only [hkKinds, List.getElem?_cons_zero, Option.some.injEq] at ha hk; subst a; subst k; exact option_type_input
  | succ i => simp at ha

-- 参照先の元の署名を検査し、具体化後の型だけで代用しない。
def badSource : Benitoite.Release.Def :=
  ⟨[{}], 0, ["x"], [.tvar 1], .base .unit, Benitoite.Release.Eff.empty, .ret (.const .unit)⟩
def badSourceProgram : Benitoite.Release.Program := { program with defs := fun _ => some badSource }
def valueKinds : DeclarationKinds := ⟨fun _ => .value, fun _ => [.value], fun _ _ => []⟩

theorem reject_signature_source : ¬ LegacyValueInput valueKinds badSourceProgram oldBuiltins builtins
    ⟨[.value], [{}], 0, 0⟩ (.fnRef "bad" [.base .unit] []) := by
  rintro ⟨fd, hd, source, _⟩
  change some badSource = some fd at hd
  cases hd
  have bound : 1 < 1 := source.2.1.2.1.1
  omega

end
end Benitoite.Release.Refinement.L10KHigherKinds

namespace Benitoite.Release.Refinement.L10KHeld
open L10KBoundary
noncomputable section

def requestDecl : Benitoite.Release.ConDecl := ⟨"Http.ClientRequest", 0,
  [.base .unit, .base .string, .base .unit, .base .unit, .base .unit]⟩
def requestProgram : Benitoite.Release.Program := { program with cons := fun _ => some requestDecl }
def request : Benitoite.Release.Val := .con "Http.ClientRequest" []
  [.const .unit, .const (.string "http://a"), .const .unit, .const .unit, .const .unit]
def requestType : Benitoite.Release.Ty := .data "Http.ClientRequest" []
def target : Scope.Domain.Target := .endpoint ⟨.name ["a"], 80⟩
def requestBuiltins : Builtins := { builtins with
  valKind := fun _ => some .endpoint, valContent := fun _ => some (embedTy requestType) }
def requestOldBuiltins : Benitoite.Release.Builtins := { oldBuiltins with
  valKind := fun _ => some .endpoint, valContent := fun _ => some requestType }

set_option maxHeartbeats 2000000 in
theorem endpoint_kept : (embedVal request).reqTarget = some target := by
  change parseUrlTarget "http://a" = some target
  cbv
theorem request_ground : groundVal (embedVal request) = true := by decide

theorem request_arity : (embedProgramWithKinds kinds requestProgram).DataArity "Http.ClientRequest" 0 := by
  refine ⟨⟨"Http.ClientRequest", embedConDecl requestDecl, rfl, rfl⟩, ?_⟩
  intro c cd hc _; change some (embedConDecl requestDecl) = some cd at hc
  cases hc; rfl

theorem content_typed : HasTypeVQ (embedProgramWithKinds kinds requestProgram) requestBuiltins
    StoreTy.empty Benitoite.Release.Qempty [] [] [] (embedVal request) (embedTy requestType).norm := by
  refine .V_Con (ts := []) (show (embedProgramWithKinds kinds requestProgram).cons "Http.ClientRequest" = some (embedConDecl requestDecl) from rfl)
    rfl ⟨rfl, ([] : KindCtx), rfl, ?_⟩ ?_ ?_ ?_
  · intro i a k ha hk; simp at ha
  · intro t ht
    simp only [embedConDecl, requestDecl, embedTys, List.mem_cons, List.not_mem_nil, or_false] at ht
    rcases ht with rfl | rfl | rfl | rfl | rfl <;> trivial
  · exact .cons (.V_Const trivial) (.cons (.V_Const trivial) (.cons (.V_Const trivial)
      (.cons (.V_Const trivial) (.cons (.V_Const trivial) .nil))))
  · exact ⟨trivial, trivial, ⟨⟨0, request_arity, rfl⟩, trivial⟩⟩

theorem request_leaf : HasTypeVQ (embedProgramWithKinds kinds requestProgram) requestBuiltins
    StoreTy.empty Benitoite.Release.Qempty [] [] []
    (embedVal (.checkedRequest target request)) (embedTy (.opaque "RequestIn" (.fixed .top))) :=
  embed_checkedRequest_opaque rfl rfl content_typed request_ground endpoint_kept ⟨rfl, trivial⟩

theorem request_syntax : LegacyValueInput kinds requestProgram requestOldBuiltins requestBuiltins .closed
    (.checkedRequest target request) := by
  refine ⟨?_, request_ground, endpoint_kept, "RequestIn", requestType, rfl, rfl, rfl, rfl⟩
  exact ⟨⟨requestDecl, rfl, rfl, by intro i a k ha hk; simp at ha⟩,
    ⟨trivial, ⟨trivial, ⟨trivial, ⟨trivial, ⟨trivial, trivial⟩⟩⟩⟩⟩⟩

theorem reject_wrong_endpoint : ¬ LegacyValueInput kinds requestProgram requestOldBuiltins requestBuiltins .closed
    (.checkedRequest (.endpoint ⟨.name ["other", "example"], 443⟩) request) := by
  intro h
  have same := h.2.2.1.symm.trans endpoint_kept
  exact (by decide : some (Scope.Domain.Target.endpoint ⟨.name ["other", "example"], 443⟩) ≠ some target) same

theorem reject_byte : ¬ LegacyValueInput kinds program oldBuiltins builtins .closed (.const (.byte 256)) := by change ¬ (256 ≤ 255); omega
theorem reject_bytes : ¬ LegacyValueInput kinds program oldBuiltins builtins .closed (.bytesV [0,256]) := by
  intro h; have := h 256 (by simp); omega

end
end Benitoite.Release.Refinement.L10KHeld

/-! 高 kind の `.tapp` を持つ元の署名と、旧 V_Fun の導出全体の入力を確認する。 -/
namespace Benitoite.Release.Refinement.L10KApplied
open Benitoite.Release.Refinement
noncomputable section

def optionDecl : Benitoite.Release.ConDecl := ⟨"Option", 1, []⟩
def eE : Benitoite.Release.Eff := Benitoite.Release.Eff.empty
def unit : Benitoite.Release.Ty := .base .unit
def fd : Benitoite.Release.Def :=
  ⟨[{}], 0, ["x"], [.tapp 0 [unit]], unit, eE, .ret (.const .unit)⟩
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [.constructor 1], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => some fd, cons := fun _ => some optionDecl, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B0 : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def B : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def opt : Benitoite.Release.Ty := .ctor (.data "Option")
def result : Benitoite.Release.Ty := Benitoite.Release.fnTy fd.names fd.params fd.ret fd.eff [opt] []


theorem subst_eff : Benitoite.Release.Eff.substAt 0 [opt] [] eE = eE := by
  show Benitoite.Release.EffR.mk _ [] = Benitoite.Release.EffR.mk _ []
  congr 1
  funext x
  cases x <;> rfl
theorem result_eq : result = .fn ["x"] [.data "Option" [unit]] unit eE := by
  show Benitoite.Release.Ty.fn ["x"] [.data "Option" [unit]] unit (Benitoite.Release.Eff.substAt 0 [opt] [] eE) = _
  rw [subst_eff]

theorem arity : (embedProgramWithKinds K P0).DataArity "Option" 1 := by
  refine ⟨⟨"None", embedConDecl optionDecl, rfl, rfl⟩, ?_⟩
  intro c cd hc _
  change some (embedConDecl optionDecl) = some cd at hc
  cases hc; rfl
theorem opt_kind : (embedTy opt).HasKind (embedProgramWithKinds K P0) [] (.constructor 1) := TyCon.arity_data arity
theorem unit_input (Δ : LegacyInputCtx) : LegacyTypeInput K P0 Δ unit .value := ⟨trivial, trivial, trivial, trivial, trivial⟩

theorem canon : (embedEff eE).Canonical := embed_canonical rfl
theorem atoms : Eff.RangesScoped 0 (embedEff eE) := by
  refine ⟨?_, trivial⟩
  intro name ix h
  cases ix with
  | fixed _ => trivial
  | rvar i => simp [embedAtoms, Atom.toOld?] at h
theorem rows_nil (Δ : LegacyInputCtx) : LegacyRowsInput K P0 Δ [] := by simp [LegacyRowsInput]

theorem result_input (Δ : LegacyInputCtx) (h : Δ.nr = 0) : LegacyTypeInput K P0 Δ result .value := by
  rw [result_eq]; obtain ⟨κ, c, nr, nv⟩ := Δ; subst h
  refine ⟨⟨⟨rfl, by simp⟩, ⟨⟨(TyCon.arity_data arity), ⟨trivial, trivial⟩⟩, trivial⟩, trivial, trivial⟩,
    ⟨⟨rfl, by simp⟩, ⟨⟨trivial, trivial⟩, trivial⟩, trivial, trivial, canon⟩, embedTy_sorted _ _,
    ⟨⟨⟨⟨1, arity, rfl⟩, trivial, trivial⟩, trivial⟩, trivial, trivial⟩, ⟨⟨⟨trivial, trivial⟩, trivial⟩, trivial, atoms⟩⟩

theorem source_input : LegacyTypeInput K P0 ⟨[.constructor 1], [{}], 0, 0⟩
    (.fn fd.names fd.params fd.ret fd.eff) .value := by
  refine ⟨⟨⟨rfl, by simp [fd]⟩, ⟨⟨rfl, ⟨trivial, trivial⟩⟩, trivial⟩, trivial, trivial⟩,
    ⟨⟨rfl, by simp [fd]⟩, ⟨⟨Nat.zero_lt_succ 0, ⟨trivial, trivial⟩⟩, trivial⟩, trivial, trivial, canon⟩,
    embedTy_sorted _ _, ⟨⟨⟨trivial, trivial⟩, trivial⟩, trivial, trivial⟩, ⟨⟨⟨trivial, trivial⟩, trivial⟩, trivial, atoms⟩⟩

theorem syntax_ : LegacyValueInput K P0 B0 B .closed (.fnRef "f" [opt] []) := by
  refine ⟨fd, rfl, source_input, ⟨rfl, ?_⟩, rows_nil _⟩
  intro i a k ha hk
  cases i with
  | zero =>
    simp only [K, List.getElem?_cons_zero, Option.some.injEq] at ha hk; subst a; subst k
    exact ⟨opt_kind, trivial, trivial, ⟨1, arity⟩, trivial⟩
  | succ i => simp at ha


theorem old_q : ∀ i, ¬ Benitoite.Release.Qsig fd.params fd.ret fd.eff i := by
  intro i h
  simp [Benitoite.Release.Qsig, fd, Benitoite.Release.QTys, Benitoite.Release.QTy, Benitoite.Release.QEff, unit, eE, Benitoite.Release.Eff.empty, Benitoite.Release.Qempty] at h

theorem old_admissible : Benitoite.Release.Admissible B0 [] fd.tparams fd.neffs
    (Benitoite.Release.Qsig fd.params fd.ret fd.eff) Benitoite.Release.Qempty [opt] [] fd.eff := by
  refine ⟨⟨rfl, by intros; trivial⟩, ?_, rfl, by simp, ?_, ?_, ?_⟩
  · intro t ht; simp only [List.mem_singleton] at ht; subst t
    exact ⟨trivial, by intro b r e h; cases h⟩
  · exact ⟨by intro i h; simp at h, trivial⟩
  · intro i h; exact (old_q i h).elim
  · intro i h; exact (old_q i h).elim

def store : Benitoite.Release.StoreTy := fun _ => none
def node : LegacyJudgment := .value [] store Benitoite.Release.Qempty [] [] (.fnRef "f" [opt] []) result

theorem ctx : LegacyNodeContext K P0 [] store [] [] := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · intro l lt h; cases h
  · intro i a h; simp at h

/-- 高 kind の `.tapp` を読む実際の旧の葉の全入力。 -/
theorem node_input : LegacyOutputInput K P0 B0 B node :=
  .node (.V_Fun (d := fd) rfl (by simp [Benitoite.Release.NamesWF, fd]) old_admissible)
    ⟨ctx, syntax_, trivial, by intro a ha; simp only [List.mem_singleton] at ha; subst a; exact result_input _ rfl⟩ (by simp)

theorem tel_eq : (embedDefWithKinds (K.functionParams "f") fd).tel =
    .param "x" (.tapp 0 [.base .unit]) (.done ((embedTy unit).shiftV 1 0) ((embedEff eE).shiftV 1 0)) := rfl


/-- 実際の宣言に対する LegacyDeclarationsInput。 -/
theorem decls : LegacyDeclarationsInput K P0 B0 B := by
  refine ⟨?_, (by intro o od h; cases h), (by intro _ _ _ _ h; cases h), (by intro i id h; cases h)⟩
  intro f d h; cases h
  exact ⟨source_input, trivial⟩
end
end Benitoite.Release.Refinement.L10KApplied

/-! 欄を持つ構成子の表の正例と、保持値の node の正例・負例。 -/
namespace Benitoite.Release.Refinement.L10KFieldsHeld

noncomputable section

def someDecl : Benitoite.Release.ConDecl := ⟨"Option", 1, [.tvar 0]⟩
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => some someDecl, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def target : Scope.Domain.Target := .endpoint ⟨.name ["a"], 80⟩
def B0 (c : Option Benitoite.Release.Ty) : Benitoite.Release.Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set",
  valKind := fun _ => some .endpoint, valContent := fun _ => c }
def B (c : Option Ty) : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => none,
  sat := fun _ _ _ => True, refGet := "get", refSet := "set",
  valKind := fun _ => some .endpoint, valContent := fun _ => c }

theorem arity : (embedProgramWithKinds K P0).DataArity "Option" 1 := by
  refine ⟨⟨"Some", embedConDecl someDecl, rfl, rfl⟩, ?_⟩
  intro c cd hc _
  change some (embedConDecl someDecl) = some cd at hc
  cases hc; rfl

theorem tables : LegacyTables K P0 (B0 none) (B none) := by
  refine ⟨?_, ?_, rfl, rfl, rfl, rfl, rfl, rfl, ?_, ?_, ?_, ?_, ?_⟩
  · intro b s0 h; cases h
  · intro C a p; exact fun h => h
  · intro o; rfl
  · intro b rs; exact fun h => h
  · intro c cd c' cd' h h' _; cases h; cases h'; rfl
  · intro c cd h a ha
    cases h; simp only [someDecl, List.mem_singleton] at ha; subst a
    exact ⟨⟨Nat.zero_lt_succ 0, trivial, trivial⟩, rfl⟩
  · intro c cd h a ha
    cases h; simp only [someDecl, List.mem_singleton] at ha; subst a
    exact ⟨Nat.zero_lt_succ 0, trivial, trivial⟩

theorem con_scoped : (embedConDecl someDecl).Scoped (embedProgramWithKinds K P0) :=
  tables.constructor_scoped (c := "Some") rfl
theorem variance : (embedProgramWithKinds K P0).VarianceValid := tables.varianceValid

def store : Benitoite.Release.StoreTy := fun _ => none
def held : Benitoite.Release.Ty := .opaque "O" (.fixed .top)

theorem ctx : LegacyContextInput K P0 store [] [] ⟨[], [], 0, 0⟩ := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · intro l lt h; cases h
  · intro i a h; simp at h

theorem held_input : LegacyOutputInput K P0 (B0 none) (B none)
    (.value [] store Benitoite.Release.Qempty [] [] (.checked target) held) :=
  .node (.V_Checked (o := "O") (R := .top) (t := target) rfl trivial)
    ⟨ctx, ⟨"O", rfl, rfl, rfl⟩, ⟨"O", .top, rfl, rfl, rfl, rfl, rfl, trivial⟩,
      by intro a ha; simp only [List.mem_singleton] at ha; subst a; exact ⟨trivial, trivial, trivial, trivial, trivial⟩⟩
    (by simp)

/-- 保持内容を持つ型名の裸の checked は、旧の規則を通っても node の入力で拒む。 -/
theorem reject_content (T0 T) : ¬ LegacyOutputInput K P0 (B0 (some T0)) (B (some T))
    (.value [] store Benitoite.Release.Qempty [] [] (.checked target) held) := by
  intro h
  obtain ⟨o, r, _, _, _, hc, _⟩ := h.regular.2.2.1
  cases hc

theorem old_content (T0) : Benitoite.Release.HasTypeVQ P0 (B0 (some T0)) store Benitoite.Release.Qempty [] []
    (.checked target) held := .V_Checked (o := "O") (R := .top) (t := target) rfl trivial

end
end Benitoite.Release.Refinement.L10KFieldsHeld

namespace Benitoite.Release.Refinement.L10KClauseSource
open Benitoite.Release.Refinement
noncomputable section

def oldSig : Benitoite.Release.PrimSig := {
  tparams := [], neffs := 0, names := ["x"], params := [.tvar 0], ret := .base .unit,
  eff := Benitoite.Release.Eff.single "E", admits := fun _ _ => True, kind := .pure, opEff := some "E" }
def newSig : PrimSig := {
  tparams := [], neffs := 0, names := ["x"], params := embedParameters [.tvar 0],
  ret := (embedTy (.base .unit)).shiftV 1 0,
  eff := (embedEff (Benitoite.Release.Eff.single "E")).shiftV 1 0,
  admits := fun _ _ => True, kind := .pure, opEff := some "E" }
def B0 : Benitoite.Release.Builtins := {
  sig := fun _ => some oldSig, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => some ["op"],
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def B : Builtins := {
  sig := fun _ => some newSig, delta := fun _ _ _ _ _ => none,
  ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
  isResource := fun _ => false, effects := fun _ => some ["op"],
  sat := fun _ _ _ => True, refGet := "get", refSet := "set" }
def K : DeclarationKinds := ⟨fun _ => .value, fun _ => [], fun _ _ => []⟩
def P0 : Benitoite.Release.Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
  effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }


def store : Benitoite.Release.StoreTy := fun _ => none
def unit : Benitoite.Release.Ty := .base .unit
def C0 : List Benitoite.Release.TParam := [{}]
def eE : Benitoite.Release.Eff := Benitoite.Release.Eff.empty
def body : Benitoite.Release.Comp := .ret (.const .unit)
def clause : Benitoite.Release.Clause := .mk (.prim "b") 1 0 body
def sg0 : Benitoite.Release.OpSig := ⟨[], ["x"], [.tvar 0], .base .unit, "E"⟩

def Γc : List (Option Benitoite.Release.Ty) := [some (.cont unit unit eE), some (.tvar 0)]

abbrev Q0 := Benitoite.Release.Qempty
/-- 外側の制約があっても、元の操作署名の範囲外の型変数を許さない。 -/
theorem reject_clause_source : ¬ LegacyClausesInput K P0 B0 B ⟨[.value], C0, 0, 0⟩ [clause] := by
  rintro ⟨⟨sg, hs, _, _, source, _⟩, _⟩
  change some sg0 = some sg at hs
  cases hs
  have impossible : 0 < 0 := source.2.1.2.1.1
  omega

theorem reject_clause_node : ¬ LegacyOutputInput K P0 B0 B
    (.clauses [.value] store Q0 C0 [] none eE [clause] unit eE []) :=
  fun h => reject_clause_source h.regular.2.1

/-- 旧規則はこの署名の型変数の不足を検査しない。 -/
theorem old_holds : LegacyJudgment.OldHolds P0 B0
    (.clauses [.value] store Q0 C0 [] none eE [clause] unit eE []) := by
  refine Benitoite.Release.HasTypeClausesQ.cons (sg := sg0)
    ⟨.top, Or.inl rfl, rfl⟩ (by simp [Benitoite.Release.NamesWF, sg0]) rfl rfl trivial ?_ .nil
  have shifted : Benitoite.Release.Eff.shift 0 0 eE = eE := by
    rw [Benitoite.Release.Eff.shift_zero_norm]
    exact Benitoite.Release.Eff.canonical_ofAtoms _
  rw [shifted]
  exact .C_Return .V_Const

def scopedOldSig : Benitoite.Release.PrimSig := { oldSig with
  params := [.opaque "O" (.rvar 0)], rkinds := [.endpoint] }
def scopedBuiltins : Benitoite.Release.Builtins := { B0 with sig := fun _ => some scopedOldSig }
def scopedTop : Benitoite.Release.OpSig :=
  ⟨[], ["x"], [.opaque "O" (.fixed .top)], .base .unit, "E"⟩

/-- 有効な元の署名は、Top 以外を含む任意の節の範囲へ WF を渡せる。 -/
theorem signature_at_range (S : Scope.Domain.Range) :
    (embedTy (.fn ["x"] [.opaque "O" (.fixed S)] (.base .unit)
      (Benitoite.Release.Eff.single "E"))).WF 0 0 0 := by
  apply legacy_opSigAt_signature_wf (topSig := scopedTop)
    (P0 := P0) (B0 := scopedBuiltins) (o := .prim "b") (S := S) rfl rfl
  exact ⟨⟨rfl, by simp [scopedTop]⟩, ⟨trivial, trivial⟩, trivial, trivial,
    embed_canonical (Benitoite.Release.Eff.canonical_ofAtoms _)⟩

end
end Benitoite.Release.Refinement.L10KClauseSource

namespace Benitoite.Release.Refinement.L10KOneWay
open L10KBoundary
noncomputable section

def restrictive : Benitoite.Release.Builtins := { oldBuiltins with sat := fun _ _ _ => False }
def permissive : Builtins := { builtins with admitsR := fun _ _ => True }

/-- 新しい受理が増えても、旧から新への表の条件を満たす。 -/
theorem tables : LegacyTables kinds program restrictive permissive := by
  constructor <;> simp [program, restrictive, permissive, oldBuiltins, builtins]

theorem sat_new_only : permissive.sat [] (.base .unit) ({} : Benitoite.Release.TParam) ∧
    ¬ restrictive.sat [] (.base .unit) ({} : Benitoite.Release.TParam) := ⟨trivial, id⟩
theorem range_new_only : permissive.admitsR "b" [] ∧ ¬ restrictive.admitsR "b" [] := ⟨trivial, id⟩

def oldSig : Benitoite.Release.PrimSig := {
  tparams := [], neffs := 0, names := [], params := [], ret := .base .unit,
  eff := Benitoite.Release.Eff.empty, admits := fun _ _ => False, kind := .pure, opEff := none }
def newSig : PrimSig := {
  tparams := [], neffs := 0, names := [], params := [], ret := .base .unit,
  eff := (embedEff Benitoite.Release.Eff.empty).shiftV 0 0,
  admits := fun _ _ => True, kind := .pure, opEff := none }

theorem signature : LegacyPrimSignature oldSig newSig :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, fun _ _ _ => trivial⟩
theorem admits_new_only : newSig.admits [] [] ∧ ¬ oldSig.admits [] [] := ⟨trivial, id⟩

end
end Benitoite.Release.Refinement.L10KOneWay

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if env.getModuleIdxFor? name == none && name.toString.startsWith "Benitoite.Release.Refinement.L10K" then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_CONSTANTS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
