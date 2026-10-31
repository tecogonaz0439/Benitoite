import Lean
import Benitoite.Release.Refinement.ModelHttp
import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.ClosureTyping
import Benitoite.Release.Refinement.Step

namespace Benitoite.Release.Refinement.ValueLeafBoundary
noncomputable section

def scalar : Ty := .base .integer
def p : Pred := .le (.integer 0) (.var 0)
def positive : Ty := .refined scalar p
def q : Pred := .le (.var 0) (.integer 7)
def nested : Ty := .refined positive q
def sevenN : Integer64Value := ⟨7,by decide⟩
def seven : Val := .const (.integer sevenN)
def rawUnit : Ty := .refined (.base .unit) .truth

def boxInt : ConDecl := ⟨"Box",0,[positive]⟩
def boxText : ConDecl := ⟨"Box",0,[.base .string]⟩
def P : Program :=
  { defs := fun _ => none, cons := fun c =>
      if c = "Box.Int" then some boxInt else if c = "Box.Text" then some boxText else none,
    ops := fun _ => none, effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun o => o == "File", effects := fun _ => none,
    sat := fun _ _ _ => True, refGet := "get", refSet := "set",
    valKind := fun o => if o = "Http.RequestIn" then some .endpoint else none,
    valContent := TargetTable.valContent }

macro "scalar_ann" : tactic => `(tactic| simp [Ty.Annotation,scalar,positive,p,q,nested,
  rawUnit,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.Sorted,
  Pred.Sorted,Term.HasSort,Term.Shape,Term.References,Ctx.Readable,Ty.HasSort,Ty.sort?,
  Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.extend,Ty.shiftV])

theorem positive_ann : Ty.Annotation P [] [] positive := ⟨by scalar_ann,by scalar_ann,by scalar_ann⟩
theorem nested_ann : Ty.Annotation P [] [] nested := ⟨by scalar_ann,by scalar_ann,by scalar_ann⟩

theorem seven_positive : HasTypeV P B StoreTy.empty [] [] [] seven positive := by
  refine .V_Refine (.V_Const trivial) (sort := .integer) rfl rfl ?_ ?_ ?_ trivial ?_
  · exact positive_ann.sorted.2
  · exact positive_ann.wf.2.1
  · change Entails [] (.le (.integer 0) (.integer 7)); exact .integer_le (by decide)
  · exact positive_ann.declared.2

theorem seven_nested : HasTypeV P B StoreTy.empty [] [] [] seven nested := by
  refine .V_Refine seven_positive (sort := .integer) rfl rfl ?_ ?_ ?_ ?_ ?_
  · exact nested_ann.sorted.2
  · exact nested_ann.wf.2.1
  · change Entails [] (.le (.integer 7) (.integer 7)); exact .le_refl
  · exact positive_ann.declared
  · exact nested_ann.declared.2

theorem nested_to_positive : Ty.LeQ [] [] nested positive :=
  .trans .forget (.trans
    (.introduce (a := positive) (p := p) (by scalar_ann) (.hyp (by change p ∈ [p]; simp))) .forget)

theorem seven_wrapped : HasTypeV P B StoreTy.empty [] [] [] seven positive.norm :=
  .V_Normal (.V_Sub seven_nested nested_to_positive positive_ann.wf positive_ann.sorted positive_ann.declared)

theorem integer_extracted : Entails [] (.le (.integer 0) (.integer 7)) := by
  have hf := seven_wrapped.integer_facts
  exact hf.2.2 p (by rw [Ty.assume_norm]; change p ∈ [p]; simp)

theorem subtype_fact_direct : Entails [] (.le (.integer 0) (.integer 7)) :=
  seven_nested.subtype_facts nested_to_positive rfl p (by change p ∈ [p]; simp)

theorem raw_unit : HasTypeV P B StoreTy.empty [] [] [] (.const .unit) rawUnit := by
  exact .V_Sub (.V_Const trivial) (.introduce trivial .truth)
    (by scalar_ann) (by scalar_ann) (by scalar_ann)

theorem raw_unit_inverted : rawUnit.norm.core = .base .unit ∧
    ConstOK B .unit := by
  have h := raw_unit.V_Normal.inv_const rfl
  exact ⟨h.2,h.1⟩

theorem list_raw : HasTypeV P B StoreTy.empty [] [] [] (.list [.const .unit]) (.list rawUnit) :=
  .V_List (.cons raw_unit .nil) (by scalar_ann) (by scalar_ann) (by scalar_ann)

theorem list_wrapped : HasTypeV P B StoreTy.empty [] [] [] (.list [.const .unit]) (.list (.base .unit)) :=
  .V_Normal (.V_Sub list_raw (.trans .refl .refl) (by scalar_ann) (by scalar_ann) (by scalar_ann))

theorem list_element : ∃ a, HasTypeV P B StoreTy.empty [] [] [] (.const .unit) a ∧
    Ty.LeQ [] [] a (.base .unit) := by
  obtain ⟨⟨a,b,hs,hb,hl⟩,_⟩ := list_wrapped.list_facts rfl
  have he : b = .base .unit := Option.some.inj hb.symm
  subst b
  exact ⟨a,hs.member (by simp),hl⟩

def lengthOne : Pred := .eq (.measure .listLength (.var 0)) (.integer 1)

theorem list_refined : HasTypeV P B StoreTy.empty [] [] [] (.list [.const .unit])
    (.refined (.list (.base .unit)) lengthOne) := by
  refine .V_Refine list_wrapped (sort := .list) rfl rfl ?_ ?_ ?_ trivial ?_
  · simp [lengthOne,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,
      Term.Shape,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Measure.input,Measure.output]
  · simp [lengthOne,Pred.WF,Pred.VarsIn,Term.VarsIn]
  · exact .closed (by trivial) (by trivial) (by cbv)
  · simp [lengthOne,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.extend,
      Ty.shiftV,Ctx.Readable,Ordinary,Ty.core]

theorem list_length_fact : Entails [] (.eq
    (.measure .listLength (.listValue [some .unitValue])) (.integer 1)) :=
  (list_refined.V_Normal.list_facts rfl).2 lengthOne (by
    rw [Ty.assume_norm]; change lengthOne ∈ [lengthOne]; simp)

theorem list_element_refined_fact : Entails [] (.le (.integer 0) (.integer 7)) := by
  have hs : HasTypeV P B StoreTy.empty [] [] [] (.list [seven]) (.list positive) :=
    .V_List (.cons seven_positive .nil) positive_ann.wf positive_ann.sorted positive_ann.declared
  apply hs.V_Normal.list_element_facts (b := positive.norm) (v := seven) (t := .integer 7) rfl (by simp) rfl p
  rw [Ty.assume_norm]
  change p ∈ [p]
  simp

theorem box_arity : P.DataArity "Box" 0 := by
  refine ⟨⟨"Box.Int",boxInt,rfl,rfl⟩,?_⟩
  intro c cd hc _
  simp only [P] at hc
  split at hc
  · cases Option.some.inj hc; rfl
  · split at hc
    · cases Option.some.inj hc; rfl
    · cases hc

theorem box_typed : HasTypeV P B StoreTy.empty [] [] [] (.con "Box.Int" [] [seven]) (.data "Box" []) := by
  refine .V_Con (cd := boxInt) rfl rfl ?_ ?_ ?_ ?_
  · exact ⟨rfl,[],rfl,by intro i a k hi; simp at hi⟩
  · intro a ha; simp only [boxInt,List.mem_singleton] at ha; subst a; exact positive_ann.wf
  · have he : positive.subst [] [] = positive.norm := by
      simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,positive,scalar,Ty.rawBind,p,
        typeEnvAt,upValues,predBind,termBind,termBind?]
    simpa only [boxInt,List.map_cons,List.map_nil,he] using
      (HasTypeVsQ.cons seven_positive.V_Normal HasTypeVsQ.nil)
  · exact ⟨trivial,trivial,⟨⟨0,box_arity,rfl⟩,trivial⟩⟩

theorem box_wrapped : HasTypeV P B StoreTy.empty [] [] [] (.con "Box.Int" [] [seven]) (.data "Box" []) :=
  .V_Normal (.V_Sub box_typed (.trans .refl .refl) trivial trivial ⟨⟨0,box_arity,rfl⟩,trivial⟩)

theorem box_field_fact : Entails [] (.le (.integer 0) (.integer 7)) := by
  have hf := box_wrapped.field_facts (cd := boxInt) (i := 0) (a := positive)
    (t := .integer 7) rfl rfl rfl
  apply hf p
  have he : positive.subst [] [] = positive.norm := by
    simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,positive,scalar,Ty.rawBind,p,
      typeEnvAt,upValues,predBind,termBind,termBind?]
  rw [he,Ty.assume_norm]
  change p ∈ [p]
  simp

theorem box_field_by_type : Entails [] (.le (.integer 0) (.integer 7)) := by
  have hf := box_wrapped.field_facts_by_type (cd := boxInt) (us := []) (i := 0)
    (a := positive) (t := .integer 7) rfl rfl rfl rfl
  apply hf p
  have he : positive.subst [] [] = positive.norm := by
    simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,positive,scalar,Ty.rawBind,p,
      typeEnvAt,upValues,predBind,termBind,termBind?]
  rw [he,Ty.assume_norm]
  change p ∈ [p]
  simp

theorem other_constructor : P.cons "Box.Text" = some boxText := rfl

theorem resource_opaque : HasTypeV P B StoreTy.empty [] [] []
    (.const (.opaque "File" 0)) (.opaque "File" (.fixed .top)) := .V_Const ⟨rfl,rfl⟩

theorem resource_kind : B.isResource "File" = true := rfl

theorem bare_request_rejected (T : Ty) : ¬ HasTypeV P B StoreTy.empty [] [] []
    (.const (.opaque "Http.RequestIn" 0)) T := by
  intro h
  have hc := (h.inv_const rfl).1
  have hn : B.valKind "Http.RequestIn" = none := hc.1
  cases hn

namespace Http
open Scope.Domain

def reqDecl : ConDecl := embedConDecl Benitoite.Release.ModelHttp.clientRequestDecl
def pairDecl : ConDecl := ⟨"Pair",2,[.tvar 0,.tvar 1]⟩
def P : Program :=
  { defs := fun _ => none, cons := fun c => if c = "Http.ClientRequest" then some reqDecl
      else if c = "Pair" then some pairDecl else none,
    ops := fun _ => none, effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def pair : Ty := .data "Pair" [.base .string,.base .string]
def timeout : Integer64Value := ⟨30000,by decide⟩
def req : Val := .con "Http.ClientRequest" [] [.const (.string "GET"),
  .const (.string "http://a"),.list [],.bytesV [],.const (.integer timeout)]
def target : Target := .endpoint ⟨.name ["a"],80⟩
def other : Target := .endpoint ⟨.name ["other","example","com"],443⟩
def range : Range := .endpoint ⟨.name (.exact ["a"]),⟨80,80⟩⟩

theorem arity (name : String) (c : String) (cd : ConDecl) (hc : P.cons c = some cd)
    (hd : cd.data = name) : P.DataArity name cd.ntys := by
  refine ⟨⟨c,cd,hc,hd⟩,?_⟩
  intro c' cd' hc' hd'
  have cases_cons : ∀ c cd, P.cons c = some cd → cd = reqDecl ∨ cd = pairDecl := by
    intro c cd h
    simp only [P] at h
    split at h
    · exact Or.inl (Option.some.inj h).symm
    · split at h
      · exact Or.inr (Option.some.inj h).symm
      · cases h
  rcases cases_cons c cd hc with rfl | rfl <;>
    rcases cases_cons c' cd' hc' with rfl | rfl <;> simp_all [reqDecl,embedConDecl,
      Benitoite.Release.ModelHttp.clientRequestDecl,pairDecl]
  all_goals have impossible := hd.trans hd'.symm
  all_goals contradiction

theorem pair_declared : Ty.Declared P [] [] pair :=
  ⟨⟨2,arity "Pair" "Pair" pairDecl rfl rfl,rfl⟩,trivial,trivial,trivial⟩

theorem req_typed {B0 : Builtins} : HasTypeV P B0 StoreTy.empty [] [] [] req TargetTable.clientRequestTy := by
  refine .V_Con (cd := reqDecl) rfl rfl ⟨rfl,[],rfl,by intro i a k hi; simp at hi⟩ ?_ ?_ ?_
  · intro a ha
    simp only [reqDecl,embedConDecl,Benitoite.Release.ModelHttp.clientRequestDecl,embedTys,
      embedTy,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl | rfl | rfl <;> trivial
  · simp only [reqDecl,embedConDecl,Benitoite.Release.ModelHttp.clientRequestDecl,
      Benitoite.Release.ModelHttp.pairTy,embedTys,embedTy,Ty.subst,Ty.substAt,
      substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,Ty.normTys,rawBindTys,List.map_cons,List.map_nil]
    change HasTypeVs P B0 StoreTy.empty [] [] [] _
      [.base .string,.base .string,.list pair,.bytes,.base .integer]
    exact .cons (.V_Const trivial) (.cons (.V_Const trivial)
      (.cons (.V_List .nil (by simp [pair,Ty.WF,Ty.WFList]) (by simp [pair,Ty.Sorted,sortedTys]) pair_declared)
        (.cons (.V_Bytes (by simp)) (.cons (.V_Const trivial) .nil))))
  · exact ⟨trivial,trivial,⟨⟨0,arity "Http.ClientRequest" "Http.ClientRequest" reqDecl rfl rfl,rfl⟩,trivial⟩⟩

theorem req_ground : groundVal req = true := rfl

set_option maxHeartbeats 2000000 in
theorem req_target : req.reqTarget = some target := by
  change parseUrlTarget "http://a" = some target
  cbv

theorem range_member : Range.MemK .endpoint range target := by decide

def held : Val := .checkedRequest target req

theorem held_typed : HasTypeV P B StoreTy.empty [] [] [] held
    (.scoped "Http.RequestIn" .endpoint (.fixed (.absolute range))) :=
  .V_CheckedRequest rfl rfl req_typed.V_Normal req_ground req_target range_member

theorem held_top : HasTypeV P B StoreTy.empty [] [] [] held
    (.opaque "Http.RequestIn" (.fixed .top)) :=
  .V_Sub (.V_Normal (HasTypeVQ.checkedRequest_widen (outer := .top) rfl rfl
      req_typed.V_Normal req_ground req_target range_member (RangeExpr.top_covers _)))
    (.trans .refl .scoped_forget) trivial trivial trivial

theorem projection : ModelHttp.valueRun [held] = .val req ∧ req.reqTarget = some target := by
  obtain ⟨hv,_,_,_,_,_,_,_,ht,_,_,_⟩ := ModelHttp.valueRun_typed held_top
  exact ⟨hv,ht⟩

theorem no_request (T : Ty) (hT : T.Holds "Http.RequestIn" .endpoint (.fixed .top)) :
    ¬ HasTypeV P B StoreTy.empty [] [] [] (.checked target) T :=
  HasTypeVQ.checked_without_request (by decide) hT

theorem wrong_endpoint (T : Ty) :
    ¬ HasTypeV P B StoreTy.empty [] [] [] (.checkedRequest other req) T :=
  HasTypeVQ.checkedRequest_mismatch (by rw [req_target]; decide)

theorem checked_at : HasTypeV P B StoreTy.empty [] [] []
    (.checkedAt (.absolute range) none target (some req))
    (.scoped "Http.RequestIn" .endpoint (.fixed (.absolute range))) :=
  .V_CheckedAt (.request rfl rfl req_typed.V_Normal req_ground req_target range_member)

theorem checked_at_wrong (T : Ty) :
    ¬ HasTypeV P B StoreTy.empty [] [] [] (.checkedAt (.absolute range) none other (some req)) T :=
  HasTypeVQ.checkedAt_request_mismatch (by rw [req_target]; decide)

theorem checked_at_no_request : ¬ HasTypeV P B StoreTy.empty [] [] []
    (.checkedAt (.absolute range) none target none) (.opaque "Http.RequestIn" (.fixed .top)) :=
  HasTypeVQ.checkedAt_without_request (k := .endpoint) (by decide) (Or.inr rfl)

def before : State := .run (.pure (.ite (.const (.boolean true)) (.ret held) (.ret held))) [] Store.empty
def after : State := .run (.pure (.ret held)) [] Store.empty

theorem actual_step (σ : PathEnv) : Step P B σ before none after := by
  exact .E_IfT rfl

theorem after_typed : HasTypeV P B StoreTy.empty [] [] []
    (closeVal Capture.empty held) (.opaque "Http.RequestIn" (.fixed .top)) := held_top

theorem after_leaf : ∃ v, after = .run (.pure (.ret v)) [] Store.empty ∧
    ModelHttp.valueRun [v] = .val req ∧ req.reqTarget = some target :=
  ⟨held,rfl,(ModelHttp.valueRun_typed after_typed).1,projection.2⟩

def constructorFact : Pred := .constructorIs (.var 0) "Http.ClientRequest"
def refinedRequest : Ty := .refined TargetTable.clientRequestTy constructorFact
def Bf : Builtins := { B with valContent := fun o =>
  if o = "Http.RequestIn" then some refinedRequest else none }

theorem refined_req : HasTypeV P Bf StoreTy.empty [] [] [] req refinedRequest := by
  refine .V_Refine req_typed (sort := .data) rfl rfl ?_ ?_ ?_ ?_ ?_
  · simp [constructorFact,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,
      Ctx.Readable,Ty.HasSort,Ty.sort?,TargetTable.clientRequestTy,
      Benitoite.Release.TargetTable.clientRequestTy,embedTy,Ordinary,Ty.core]
  · simp [constructorFact,Pred.WF,Pred.VarsIn,Term.VarsIn]
  · exact .closed (by trivial) (by trivial) (by cbv)
  · exact ⟨⟨0,arity "Http.ClientRequest" "Http.ClientRequest" reqDecl rfl rfl,rfl⟩,trivial⟩
  · refine ⟨?_,"Http.ClientRequest",[],reqDecl,?_,rfl,rfl⟩
    · refine ⟨_,rfl,?_⟩
      change Ordinary (.data "Http.ClientRequest" [])
      intro b t e he
      cases he
    · exact .var rfl rfl

theorem held_refined_content : HasTypeV P Bf StoreTy.empty [] [] [] held
    (.opaque "Http.RequestIn" (.fixed .top)) :=
  .V_Sub (HasTypeVQ.checkedRequest_widen (outer := .top) rfl rfl refined_req.V_Normal
    req_ground req_target range_member (RangeExpr.top_covers _)) .scoped_forget trivial trivial trivial

theorem retained_fact : Entails [] (constructorFact.open (req.toTerm?.getD (.integer 0))) := by
  have hh := (held_refined_content.checkedRequest_content
    (Or.inr rfl) (o := "Http.RequestIn") (A := refinedRequest) rfl).1
  have ht : req.toTerm? = some (req.toTerm?.getD (.integer 0)) := rfl
  apply hh.facts ht constructorFact
  rw [Ty.assume_norm]
  change constructorFact ∈ [constructorFact]
  simp

theorem projection_known_content : ModelHttp.valueRun [held] = .val req ∧
    HasTypeV P B StoreTy.empty [] [] [] req TargetTable.clientRequestTy.norm ∧
    req.Ground ∧ req.reqTarget = some target :=
  ModelHttp.valueRun_request held_top (Or.inr rfl) rfl

def result : Ty := .opaque "Http.RequestIn" (.fixed .top)
theorem result_ann : Ty.Annotation P [] [] result := ⟨trivial,trivial,trivial⟩
theorem result_fn_ann : Ty.Annotation P [] [] (.dependentFn (.done result Eff.empty)) :=
  ⟨⟨trivial,trivial,rfl⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

private theorem state_of_comp {body : Comp}
    (hb : HasTypeC P B StoreTy.empty [] [] [] none body result Eff.empty)
    (hc : body.ClosedAt 0 0) (ha : body.Adequate σ) (hv : σ.Valid) :
    StateTy P B σ (.run (.pure body) [] Store.empty) := by
  refine ⟨hv,Eff.empty,⟨rfl,?_⟩,StoreTy.empty,none,result,result,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,?_,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ result_ann,?_,?_,?_,?_⟩
  · intro a ha; cases ha
  · exact .pure hb result_fn_ann (by intros; contradiction) rfl (by intros; contradiction)
  · exact ⟨trivial,ha⟩
  · exact ⟨trivial,hc⟩
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem before_state (hv : σ.Valid) : StateTy P B σ before := by
  have hb : HasTypeC P B StoreTy.empty [] [] [] none
      (.ite (.const (.boolean true)) (.ret held) (.ret held)) result Eff.empty :=
    .C_If (.V_Const trivial) (.C_Return held_top) (.C_Return held_top)
  exact state_of_comp hb
    ⟨trivial,groundVal_ground (v := req) req_ground,groundVal_ground (v := req) req_ground⟩ (by trivial) hv

theorem after_state (hv : σ.Valid) : StateTy P B σ after :=
  state_of_comp (.C_Return held_top) (groundVal_ground (v := req) req_ground) (by trivial) hv

def atHeld : Val := .checkedAt (.absolute range) none target (some req)

theorem at_top : HasTypeV P B StoreTy.empty [] [] [] atHeld result :=
  .V_Sub checked_at.V_Normal
    (.trans (.scoped (inner := .fixed (.absolute range)) (outer := .fixed .top)
      (RangeExpr.top_covers (.absolute range))) .scoped_forget) trivial trivial trivial

theorem at_projection : ModelHttp.valueRun [atHeld] = .val req ∧
    HasTypeV P B StoreTy.empty [] [] [] req TargetTable.clientRequestTy.norm ∧
    req.Ground ∧ req.reqTarget = some target :=
  ModelHttp.valueRun_checkedAt_request at_top (Or.inr rfl) rfl

theorem at_transition (hv : σ.Valid) :
    let start := State.run (.pure (.ite (.const (.boolean true)) (.ret atHeld) (.ret atHeld))) [] Store.empty
    let finish := State.run (.pure (.ret atHeld)) [] Store.empty
    StateTy P B σ start ∧ Step P B σ start none finish ∧ StateTy P B σ finish ∧
      ModelHttp.valueRun [atHeld] = .val req := by
  have ha : atHeld.Adequate σ := ⟨⟨range,rfl⟩,by trivial⟩
  have hb : HasTypeC P B StoreTy.empty [] [] [] none
      (.ite (.const (.boolean true)) (.ret atHeld) (.ret atHeld)) result Eff.empty :=
    .C_If (.V_Const trivial) (.C_Return at_top) (.C_Return at_top)
  refine ⟨state_of_comp hb ?_ ?_ hv,.E_IfT rfl,
    state_of_comp (.C_Return at_top) ?_ ?_ hv,at_projection.1⟩
  · exact ⟨trivial,groundVal_ground (v := req) req_ground,groundVal_ground (v := req) req_ground⟩
  · exact ⟨trivial,ha,ha⟩
  · exact groundVal_ground (v := req) req_ground
  · exact ha

end Http
end
end Benitoite.Release.Refinement.ValueLeafBoundary


open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "ValueLeafBoundary").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
