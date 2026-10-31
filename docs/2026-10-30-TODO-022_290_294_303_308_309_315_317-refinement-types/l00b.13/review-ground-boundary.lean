import Lean
import Benitoite.Release.Refinement.ModelHttp
import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.ClosureTyping
import Benitoite.Release.Refinement.Step
import Benitoite.Release.Refinement.AtSound

namespace Benitoite.Release.Refinement.ReviewValueLeafBoundary
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


def rawStr : Ty := .refined (.base .string) .truth
def rawPair : Ty := .data "Pair" [rawStr,.base .string]
def pairV : Val := .con "Pair" [rawStr,.base .string] [.const (.string "k"),.const (.string "v")]
def reqRaw : Val := .con "Http.ClientRequest" [] [.const (.string "GET"),
  .const (.string "http://a"),.list [pairV],.bytesV [],.const (.integer timeout)]

theorem rawStr_norm : rawStr.norm = .base .string := by
  simp [rawStr,Ty.norm,Ty.refineNorm,Ty.core,Ty.refinementPredicates,Pred.conjuncts,Ty.packRefinements]

theorem pair_norm : rawPair.norm = pair := by
  simp only [rawPair,pair,Ty.norm,Ty.normTys,rawStr_norm]

theorem rawPair_ann : Ty.Annotation P [] [] rawPair := by
  refine ⟨?_,?_,?_⟩
  · simp [rawPair,rawStr,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Ty.NotContCore,Ty.core]
  · simp [rawPair,rawStr,Ty.Sorted,sortedTys,Pred.Sorted]
  · refine ⟨⟨2,arity "Pair" "Pair" pairDecl rfl rfl,rfl⟩,?_⟩
    simp [rawStr,Ty.Declared,Pred.Declared,declaredTys]

theorem pairV_typed {B0 : Builtins} : HasTypeV P B0 StoreTy.empty [] [] [] pairV rawPair := by
  refine .V_Con (cd := pairDecl) rfl rfl ?_ ?_ ?_ rawPair_ann
  · refine ⟨rfl,[],rfl,?_⟩
    intro i a k hi hk
    cases i with
    | zero => 
      simp [pairDecl] at hi hk; subst hi; subst hk
      simp [rawStr,Ty.HasKind,Ty.NotContCore,Ty.core]
    | succ i => 
      cases i with
      | zero => simp [pairDecl] at hi hk; subst hi; subst hk; trivial
      | succ i => simp at hi
  · intro a ha; simp only [pairDecl,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl <;> simp [Ty.WF,pairDecl]
  · have h0 : (Ty.tvar 0).subst [rawStr,.base .string] [] = .base .string := by
      simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,rawStr_norm]
    have h1 : (Ty.tvar 1).subst [rawStr,.base .string] [] = .base .string := by
      simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,Ty.norm]
    simp only [pairDecl,List.map_cons,List.map_nil,h0,h1]
    exact .cons (.V_Const trivial) (.cons (.V_Const trivial) .nil)

theorem pairV_pair {B0 : Builtins} : HasTypeV P B0 StoreTy.empty [] [] [] pairV pair := by
  have h := (pairV_typed (B0 := B0)).V_Normal
  rwa [pair_norm] at h

theorem reqRaw_typed {B0 : Builtins} : HasTypeV P B0 StoreTy.empty [] [] [] reqRaw TargetTable.clientRequestTy := by
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
      (.cons (.V_List (.cons pairV_pair .nil) (by simp [pair,Ty.WF,Ty.WFList]) (by simp [pair,Ty.Sorted,sortedTys]) pair_declared)
        (.cons (.V_Bytes (by simp)) (.cons (.V_Const trivial) .nil))))
  · exact ⟨trivial,trivial,⟨⟨0,arity "Http.ClientRequest" "Http.ClientRequest" reqDecl rfl rfl,rfl⟩,trivial⟩⟩

theorem reqRaw_ground : reqRaw.Ground := by
  simp [Val.Ground,reqRaw,pairV,Val.ClosedAt,Val.ClosedList,rawStr,Ty.WF,Pred.WF,Pred.VarsIn,Ty.NotContCore,Ty.core]

theorem reqRaw_groundCheck : groundVal reqRaw = true := rfl

theorem reqRaw_target : reqRaw.reqTarget = some target := req_target

theorem reqRaw_held : HasTypeV P B StoreTy.empty [] [] [] (.checkedRequest target reqRaw)
    (.scoped "Http.RequestIn" .endpoint (.fixed (.absolute range))) :=
  .V_CheckedRequest rfl rfl reqRaw_typed.V_Normal reqRaw_groundCheck reqRaw_target (by decide)

def cap : Capture := .mk [some reqRaw]

theorem prepared_raw : AtPrepared B cap .endpoint "Http.RequestIn" none
    (.scopePattern .top) (.var 0) (.fixed .top) none .top (.absolute target) .top := by
  cbv

def shape : ResultShape := ⟨"Result","Ok","Err",.data "Scope.ScopeError" []⟩
def call : Closure := .mk cap (.checkAt .endpoint "Http.RequestIn" shape none
  (.scopePattern .top) (.var 0) (.fixed .top))
def initial : State := .run call [] Store.empty
def finished : State := .run (.pure (.ret (.con shape.ok
  [.scoped "Http.RequestIn" .endpoint (.fixed .top),cap.closeTy shape.errorType]
  [.checkedAt .top none target (AtRequest B "Http.RequestIn" (closeVal cap (.var 0)))]))) [] Store.empty

theorem checked_target : checkAt none .endpoint .top (.absolute target) .top = .ok target := by cbv

theorem at_ok_step (σ : PathEnv) : Step P B σ initial none finished :=
  .E_AtOk rfl prepared_raw (by intro ρ h; cases h) checked_target

theorem witness_from_preparation : CheckedWitness P B StoreTy.empty "Http.RequestIn" .endpoint
    .top none target (AtRequest B "Http.RequestIn" (closeVal cap (.var 0))) :=
  .of_prepared_request rfl rfl reqRaw_typed.V_Normal prepared_raw (by intro ρ h; cases h) checked_target

theorem reached_value_leaf : ∃ as v,
    finished = .run (.pure (.ret (.con shape.ok as [v]))) [] Store.empty ∧
    HasTypeV P B StoreTy.empty [] [] [] v (.scoped "Http.RequestIn" .endpoint (.fixed .top)) ∧
    ModelHttp.valueRun [v] = .val reqRaw := by
  have ht := HasTypeVQ.V_CheckedAt (Q := Qempty) (C := []) (Γ := []) (Φ := []) witness_from_preparation
  have projection := (ModelHttp.valueRun_checkedAt_typed ht).1
  exact ⟨_,_,rfl,ht,projection⟩

-- 外側の値を参照する述語は ground 判定を通らない。
def openPredicate : Pred := .le (.var 1) (.integer 1)
def openStr : Ty := .refined (.base .string) openPredicate
def openReq : Val := .con "Http.ClientRequest" [] [.const (.string "GET"),
  .const (.string "http://a"),.list [.con "Pair" [openStr,.base .string]
    [.const (.string "k"),.const (.string "v")]],.bytesV [],.const (.integer timeout)]

theorem predicate_open : ¬ openPredicate.WF 1 := by decide

theorem open_type_rejected : groundTy openStr = false := rfl

theorem open_request_rejected : groundVal openReq = false := rfl

theorem open_request_not_held (T : Ty) :
    ¬ HasTypeV P B StoreTy.empty [] [] [] (.checkedRequest target openReq) T := by
  intro h
  obtain ⟨_,_,_,_,_,_,_,hg,_⟩ := h.inv_checkedRequest rfl
  rw [open_request_rejected] at hg
  cases hg

theorem open_at_invalid : ∃ detail,
    AtPrepare B (.mk [some openReq]) .endpoint "Http.RequestIn" none (.scopePattern .top)
      (.var 0) (.fixed .top) = .error detail ∧ detail.failure = .invalidTarget := by
  refine ⟨_,rfl,rfl⟩

namespace Nonempty
-- data の変性を仮定せず、残る篩に合う欄型の宣言を使う。
def condition : Pred := .le (.integer 0) (.integer 1)
def rawStr : Ty := .refined (.base .string) condition
def rawPair : Ty := .data "Pair" [rawStr,.base .string]
def pairV : Val := .con "Pair" [rawStr,.base .string] [.const (.string "k"),.const (.string "v")]
def reqDecl : ConDecl := ⟨"Http.ClientRequest",0,
  [.base .string,.base .string,.list rawPair,.bytes,.base .integer]⟩
def P : Program := {Http.P with cons := fun c =>
  if c = "Http.ClientRequest" then some reqDecl else if c = "Pair" then some pairDecl else none}
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
    rcases cases_cons c' cd' hc' with rfl | rfl <;> simp_all [reqDecl,pairDecl]
  all_goals have impossible := hd.trans hd'.symm
  all_goals contradiction

theorem rawStr_normal : rawStr.norm = rawStr := rfl

theorem remaining_fact : condition ∈ rawStr.assume := by change condition ∈ [condition]; simp

theorem rawPair_ann : Ty.Annotation P [] [] rawPair := by
  refine ⟨?_,?_,?_⟩
  · simp [rawPair,rawStr,condition,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,
      Ty.NotContCore,Ty.core]
  · simp [rawPair,rawStr,condition,Ty.Sorted,sortedTys,Pred.Sorted,Term.HasSort,
      Term.References,Term.VarsIn,Term.Shape]
  · refine ⟨⟨2,arity "Pair" "Pair" pairDecl rfl rfl,rfl⟩,?_⟩
    simp [rawStr,condition,Ty.Declared,declaredTys,Pred.Declared,Term.Declared]

theorem string_typed {B0 : Builtins} : HasTypeV P B0 StoreTy.empty [] [] []
    (.const (.string "k")) rawStr := by
  refine .V_Refine (.V_Const trivial) (sort := .string) rfl rfl ?_ (by trivial) ?_ trivial ?_
  · simp [condition,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape]
  · change Entails [] (.le (.integer 0) (.integer 1))
    exact .integer_le (by decide)
  · simp [condition,Pred.Declared,Term.Declared]

theorem pairV_typed {B0 : Builtins} : HasTypeV P B0 StoreTy.empty [] [] [] pairV rawPair := by
  refine .V_Con (cd := pairDecl) rfl rfl ?_ ?_ ?_ rawPair_ann
  · refine ⟨rfl,[],rfl,?_⟩
    intro i a k hi hk
    cases i with
    | zero =>
      simp [pairDecl] at hi hk; subst hi; subst hk
      simp [rawStr,Ty.HasKind,Ty.NotContCore,Ty.core]
    | succ i =>
      cases i with
      | zero => simp [pairDecl] at hi hk; subst hi; subst hk; trivial
      | succ i => simp at hi
  · intro a ha; simp only [pairDecl,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl <;> simp [Ty.WF,pairDecl]
  · have h0 : (Ty.tvar 0).subst [rawStr,.base .string] [] = rawStr := by
      simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,rawStr_normal]
    have h1 : (Ty.tvar 1).subst [rawStr,.base .string] [] = .base .string := by
      simp [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,Ty.norm]
    simp only [pairDecl,List.map_cons,List.map_nil,h0,h1]
    exact .cons string_typed (.cons (.V_Const trivial) .nil)

def request : Val := .con "Http.ClientRequest" [] [.const (.string "GET"),
  .const (.string "http://a"),.list [pairV],.bytesV [],.const (.integer timeout)]

theorem request_typed : HasTypeV P B StoreTy.empty [] [] [] request TargetTable.clientRequestTy := by
  refine .V_Con (cd := reqDecl) rfl rfl ⟨rfl,[],rfl,by intro i a k hi; simp at hi⟩ ?_ ?_ ?_
  · intro a ha
    simp only [reqDecl,List.mem_cons,List.not_mem_nil,or_false] at ha
    rcases ha with rfl | rfl | rfl | rfl | rfl <;> try trivial
    exact rawPair_ann.wf
  · simp only [reqDecl,List.map_cons,List.map_nil,Ty.subst,Ty.substAt,substTypeAt,
      Ty.bind,Ty.rawBind,Ty.norm]
    change HasTypeVs P B StoreTy.empty [] [] [] _
      [.base .string,.base .string,.list rawPair,.bytes,.base .integer]
    exact .cons (.V_Const trivial) (.cons (.V_Const trivial)
      (.cons (.V_List (.cons pairV_typed .nil) rawPair_ann.wf rawPair_ann.sorted rawPair_ann.declared)
        (.cons (.V_Bytes (by simp)) (.cons (.V_Const trivial) .nil))))
  · exact ⟨trivial,trivial,⟨⟨0,arity "Http.ClientRequest" "Http.ClientRequest" reqDecl rfl rfl,rfl⟩,trivial⟩⟩

theorem request_ground : groundVal request = true := rfl

theorem request_held : HasTypeV P B StoreTy.empty [] [] [] (.checkedRequest target request)
    (.scoped "Http.RequestIn" .endpoint (.fixed (.absolute range))) :=
  .V_CheckedRequest rfl rfl request_typed.V_Normal request_ground req_target (by decide)

theorem prepared_request : AtPrepared B (.mk [some request]) .endpoint "Http.RequestIn" none
    (.scopePattern .top) (.var 0) (.fixed .top) none .top (.absolute target) .top := by cbv

end Nonempty

end Http
end
end Benitoite.Release.Refinement.ReviewValueLeafBoundary


open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "ReviewValueLeafBoundary").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
