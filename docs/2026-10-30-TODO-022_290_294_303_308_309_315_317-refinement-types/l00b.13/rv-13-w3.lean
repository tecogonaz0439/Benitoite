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
  · simp [rawPair,rawStr,Ty.Sorted,sortedTys,Pred.Sorted,Ordinary,Ty.core]
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
  simp [Val.Ground,reqRaw,pairV,Val.ClosedAt,Val.ClosedList,rawStr,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Ty.NotContCore,Ty.core]

theorem reqRaw_notGround : groundVal reqRaw = false := rfl
theorem reqRaw_target : reqRaw.reqTarget = some target := req_target

/-- 正規形が同じ要求でも保持できない（生の型引数）。 -/
theorem reqRaw_not_held (T : Ty) :
    ¬ HasTypeV P B StoreTy.empty [] [] [] (.checkedRequest target reqRaw) T := by
  intro h
  obtain ⟨_,_,_,_,_,_,_,hg,_⟩ := h.inv_checkedRequest rfl
  rw [reqRaw_notGround] at hg
  cases hg

def Bh : Builtins := B
theorem at_rejects_raw : ∃ _h : HasTypeV P B StoreTy.empty [] [] [] reqRaw TargetTable.clientRequestTy.norm,
    reqRaw.Ground ∧ reqRaw.reqTarget = some target ∧ groundVal reqRaw = false :=
  ⟨reqRaw_typed.V_Normal,reqRaw_ground,reqRaw_target,rfl⟩
#print axioms at_rejects_raw
#print axioms reqRaw_typed
#print axioms reqRaw_ground
#print axioms reqRaw_not_held
end Http
end
end Benitoite.Release.Refinement.ValueLeafBoundary
