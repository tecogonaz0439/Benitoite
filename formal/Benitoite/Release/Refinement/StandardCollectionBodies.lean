import Benitoite.Release.Refinement.StandardListBodies
import Benitoite.Release.Refinement.StandardKeySound

/-! # Map と Set の通常の高階本体 -/
namespace Benitoite.Release.Refinement.StandardBodies
noncomputable section

private def keyParam : TParamDecl := ⟨TParam.keyC,.value⟩
private def higherParams (map filter : Bool) : List TParamDecl :=
  if map then [keyParam,TypeCtx.valueParam] ++ (if filter then [] else [TypeCtx.valueParam])
  else [keyParam] ++ (if filter then [] else [keyParam])
private def pairType (b : Nat) : Ty := .data "Pair" [.tvar 0,.tvar b]
private def sourceType (map : Bool) : Ty := if map then .map (.tvar 0) (.tvar 1) else .set (.tvar 0)
private def outputElement (map filter : Bool) : Ty := .tvar (if filter then (if map then 1 else 0) else (if map then 2 else 1))
private def outputType (map filter : Bool) : Ty := if map then .map (.tvar 0) (outputElement map filter) else .set (outputElement map filter)
private def higherCallback (map filter : Bool) : Ty :=
  .fn (if map then ["key","value"] else ["value"])
    (if map then [.tvar 0,.tvar 1] else [.tvar 0])
    (if filter then .base .boolean else outputElement map filter) (Eff.row 0)
private def higherTel (map filter : Bool) : Tel :=
  .param (if map then "m" else "s") (sourceType map)
    (.param (if filter then "p" else "f") (higherCallback map filter)
      (.done (outputType map filter) (Eff.row 0)))

private def projection (second : Bool) (i : Nat) : Comp :=
  .app (.fnRef (if second then "Pair.second" else "Pair.first") [.tvar 0,.tvar 1] []) [.var i]

/-- 外側の鍵、callback の鍵と値を元の式の順に読み、callback を一度呼ぶ。 -/
def mapCallbackBody (filter : Bool) : Comp :=
  if filter then .letIn (projection false 0)
    (.letIn (projection true 1) (.app (.var 4) [.var 1,.var 0]))
  else .letIn (projection false 0)
    (.letIn (projection false 1)
      (.letIn (projection true 2)
        (.letIn (.app (.var 5) [.var 1,.var 0])
          (.ret (.con "Pair.Pair" [.tvar 0,.tvar 2] [.var 3,.var 0])))))

def collectionHigherBody (map filter : Bool) : Comp :=
  .letIn (.app (.prim (if map then "Map.toList" else "Set.toList")
      (if map then [.tvar 0,.tvar 1] else [.tvar 0]) [] []) [.var 1])
    (.letIn (.app (.fnRef (if filter then "List.filter" else "List.map")
      (if map then (if filter then [pairType 1] else [pairType 1,pairType 2])
        else (if filter then [.tvar 0] else [.tvar 0,.tvar 1])) [Eff.row 0])
      [.var 0,if map then .lam ["value"] [pairType 1] (mapCallbackBody filter) else .var 1])
      (.app (.prim (if map then "Map.fromList" else "Set.fromList")
        (if map then [.tvar 0,outputElement map filter] else [outputElement map filter]) [] []) [.var 0]))

def collectionHigherRow (map filter : Bool) : StandardContracts.Row :=
  ⟨(if map then "Map." else "Set.") ++ (if filter then "filter" else "map"),
    higherParams map filter,1,higherTel map filter,some (collectionHigherBody map filter),.core,
    [if map then .mapHigherOrder else .setUpdate]⟩

/-- 同じ標準宣言から作る pure の署名。制約の成功は同じ B.sat で検査する。 -/
def collectionPrimitiveSig (sat : List TParam → Ty → TParam → Prop) (map build : Bool) : PrimSig :=
  let tps := if map then [keyParam,TypeCtx.valueParam] else [keyParam]
  let collection := if map then .map (.tvar 0) (.tvar 1) else .set (.tvar 0)
  let element := if map then pairType 1 else .tvar 0
  ⟨tps,0,[if build then (if map then "pairs" else "xs") else (if map then "m" else "s")],
    [if build then .list element else collection],if build then collection else .list element,Eff.empty,
    (fun C ts => ts.length = tps.length ∧ ∀ (i : Nat) (t : Ty) (p : TParam),
      ts[i]? = some t → (tps.map TParamDecl.constraints)[i]? = some p → sat C t p),
    .pure,none,[],.untargeted⟩

/-- Pair の元の二射影の宣言。型引数の順と欄の順は同じである。 -/
def collectionPairProjection (second : Bool) : Def :=
  ⟨[TypeCtx.valueParam,TypeCtx.valueParam],0,["p"],[pairType 1],
    .tvar (if second then 1 else 0),Eff.empty,
    .match (.var 0) [.mk [⟨.con "Pair.Pair"
      [if second then .wild else .var,if second then .var else .wild],[0]⟩] none
      (.ret (.var 0)) ], []⟩

local macro "collection_simp" : tactic => `(tactic|
  simp_all [keyParam,higherParams,pairType,sourceType,outputElement,outputType,higherCallback,higherTel,
    collectionPrimitiveSig,collectionHigherRow,collectionPairProjection,listHigherRow,
    Def.tel,PrimSig.tel,signatureTel,Tel.names,Tel.inputs,Tel.result,Tel.effect,
    TypeCtx.valueParam,TypeCtx.kinds,TypeCtx.constraints,TParamDecl.constraints,
    TypeAnnotations,RowAnnotations,Ty.Annotation,Ty.WF,Tel.WF,Ty.WFList,Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,
    Ty.Declared,Tel.Declared,declaredTys,declaredEff,Ty.HasKind,kindsTel,kindsList,kindsEff,
    NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.row,Eff.norm,Ordinary,Ty.core,
    Builtins.RangeAdmissible,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,mapRangeAtoms,Tel.bind,Tel.rawBind,Ty.bind,Ty.rawBind,rawBindTys,
    Ty.norm,Tel.norm,Ty.normTys,Ty.subst,Ty.substAt,substTypeAt,typeEnvAt,SubstEnv.up,SubstEnv.rangesOnly,
    Eff.rawBind,rowFails,substAtoms_nil,instAtoms_nil,
    Qsig,QTel,QTy,QTys,QEff,Qempty,Eff.RowsIn,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,
    RowTransport,NoFail,Eff.test,Eff.atoms,Eff.fails,Eff.shiftV,Ty.shiftV,shiftVTys,Tel.shiftV,Ctx.extend,
    bindParams,localExtend,Pred.lift,liftMany])

private theorem sat_empty {P B} (table : StandardKeyTyping.Table P B) (C : List TParam) (a : Ty) :
    B.sat C a {} := by
  rw [table.sat_eq]
  rfl

private theorem row_self : substAtoms [Eff.row 0] (Eff.row 0).atoms = (Eff.row 0).atoms := by
  funext a
  cases a with
  | name l r => simp [substAtoms,Eff.row,Eff.atoms,Eff.test]
  | rho i => cases i <;> simp [substAtoms,Eff.row,Eff.atoms,Eff.test]

private def inputTypes (map filter build : Bool) : List Ty :=
  if map then (if build then [.tvar 0,outputElement map filter] else [.tvar 0,.tvar 1])
  else [if build then outputElement map filter else .tvar 0]
private def primitiveName (map build : Bool) : String :=
  (if map then "Map." else "Set.") ++ (if build then "fromList" else "toList")
private def primitiveInput (map filter build : Bool) : Ty :=
  if build then .list (if map then .data "Pair" [.tvar 0,outputElement map filter] else outputElement map filter)
  else sourceType map
private def primitiveResult (map filter build : Bool) : Ty :=
  if build then outputType map filter else .list (if map then pairType 1 else .tvar 0)

set_option maxHeartbeats 2000000 in
private theorem primitive_function {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (map filter build : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (lookup : B.sig (primitiveName map build) = some (collectionPrimitiveSig B.sat map build)) :
    HasTypeVQ P B StoreTy.empty Q (higherParams map filter) Γ Φ
      (.prim (primitiveName map build) (inputTypes map filter build) [] [])
      (.fn [if build then (if map then "pairs" else "xs") else (if map then "m" else "s")]
        [primitiveInput map filter build] (primitiveResult map filter build) Eff.empty) := by
  have pairAr : map = true → ∃ n, P.DataArity "Pair" n ∧ 2 = n := fun h => ⟨2,arity h,rfl⟩
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext a; simp [mapRangeAtoms]
  have range : B.RangeAdmissible (primitiveName map build) (collectionPrimitiveSig B.sat map build) [] := by
    cases map <;> cases build <;> collection_simp
  have names : NamesWF (collectionPrimitiveSig B.sat map build).names (collectionPrimitiveSig B.sat map build).params := by
    cases map <;> cases build <;> collection_simp
  have admissible : PrimitiveAdmissible (higherParams map filter) Γ.length (collectionPrimitiveSig B.sat map build) Q
      (inputTypes map filter build) [] := by
    simp only [inputTypes]
    cases map <;> cases filter <;> cases build <;> constructor
    all_goals first
      | (constructor <;> collection_simp)
      | collection_simp
    all_goals rintro (_|(_|i)) t p ht hp <;> collection_simp
    all_goals subst_vars; rw [table.sat_eq]; rfl
  have inst : SignatureInstance P (higherParams map filter) Γ
      (Tel.instR [] (collectionPrimitiveSig B.sat map build).tel)
      (TypeCtx.kinds (collectionPrimitiveSig B.sat map build).tparams)
      (inputTypes map filter build) [] := by
    simp only [inputTypes]
    cases map <;> cases filter <;> cases build <;> constructor
    all_goals first
      | (constructor <;> collection_simp)
      | collection_simp
      | (rintro (_|(_|i)) a k ha hk <;> collection_simp <;> subst_vars <;> collection_simp)
    all_goals first
      | (solve | constructor <;> (constructor <;> collection_simp))
      | (solve | repeat constructor <;> collection_simp)
      | (rintro (_|(_|i)) a k ha hk <;> collection_simp <;> subst_vars <;> constructor <;> collection_simp)
  have typed := HasTypeVQ.V_Prim (Ψ := StoreTy.empty) (Φ := Φ) lookup range names admissible inst
  apply typed.convert
  · cases map <;> cases filter <;> cases build <;>
      simp [inputTypes,primitiveInput,primitiveResult] <;> collection_simp
    all_goals first
      | simpa only [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using
          Ty.foldFn_toTel ⟨["s"],[.set (.tvar 0)],.list (.tvar 0),Eff.empty,by simp [NamesWF]⟩
      | simpa only [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using
          Ty.foldFn_toTel ⟨["xs"],[.list (.tvar 1)],.set (.tvar 1),Eff.empty,by simp [NamesWF]⟩
      | simpa only [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using
          Ty.foldFn_toTel ⟨["xs"],[.list (.tvar 0)],.set (.tvar 0),Eff.empty,by simp [NamesWF]⟩
      | simpa only [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using
          Ty.foldFn_toTel ⟨["m"],[.map (.tvar 0) (.tvar 1)],.list (.data "Pair" [.tvar 0,.tvar 1]),Eff.empty,by simp [NamesWF]⟩
      | simpa only [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using
          Ty.foldFn_toTel ⟨["pairs"],[.list (.data "Pair" [.tvar 0,.tvar 2])],.map (.tvar 0) (.tvar 2),Eff.empty,by simp [NamesWF]⟩
      | simpa only [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using
          Ty.foldFn_toTel ⟨["pairs"],[.list (.data "Pair" [.tvar 0,.tvar 1])],.map (.tvar 0) (.tvar 1),Eff.empty,by simp [NamesWF]⟩
  · cases map <;> cases filter <;> cases build <;>
      simp [primitiveInput,primitiveResult] <;> constructor <;> collection_simp

def collectionListDefinition (filter : Bool) : Def :=
  ⟨List.replicate (if filter then 1 else 2) TypeCtx.valueParam,1,["xs",if filter then "p" else "f"],
    [.list (.tvar 0),.fn ["value"] [.tvar 0] (if filter then .base .boolean else .tvar 1) (Eff.row 0)],
    .list (.tvar (if filter then 0 else 1)),Eff.row 0,
    (listHigherRow filter).body.getD (.ret (.const .unit)), []⟩

theorem collectionListDefinition_eq (filter : Bool) :
    (listHigherRow filter).definition = some (collectionListDefinition filter) := by
  cases filter <;> rfl

private def listArgs (map filter : Bool) : List Ty :=
  if map then (if filter then [pairType 1] else [pairType 1,pairType 2])
  else (if filter then [.tvar 0] else [.tvar 0,.tvar 1])
private def listElement (map : Bool) : Ty := if map then pairType 1 else .tvar 0
private def listOutput (map filter : Bool) : Ty :=
  if map then (if filter then pairType 1 else pairType 2) else outputElement map filter
private def listCallback (map filter : Bool) : Ty :=
  .fn ["value"] [listElement map] (if filter then .base .boolean else listOutput map filter) (Eff.row 0)

local macro "higher_simp" : tactic => `(tactic|
  ((try simp_all [collectionListDefinition,listArgs,listElement,listOutput,listCallback,
    inputTypes,primitiveName,primitiveInput,primitiveResult,FnView.toTel,Ty.toTel]) <;> (try collection_simp)))

set_option maxHeartbeats 2000000 in
private theorem list_function {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (map filter : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (lookup : P.defs (if filter then "List.filter" else "List.map") = some (collectionListDefinition filter)) :
    HasTypeVQ P B StoreTy.empty Q (higherParams map filter) Γ Φ
      (.fnRef (if filter then "List.filter" else "List.map") (listArgs map filter) [Eff.row 0])
      (.fn ["xs",if filter then "p" else "f"] [.list (listElement map),listCallback map filter]
        (.list (listOutput map filter)) (Eff.row 0)) := by
  have ar : map = true → ∃ n, P.DataArity "Pair" n ∧ 2 = n := fun h => ⟨2,arity h,rfl⟩
  have pairKind : map = true → TyCon.arity P (.data "Pair") = some 2 := fun h => TyCon.arity_data (arity h)
  have selfrow := row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  have names : NamesWF (collectionListDefinition filter).names (collectionListDefinition filter).params := by
    cases filter <;> higher_simp
  have ad : Admissible B (higherParams map filter) Γ.length
      (TypeCtx.constraints (collectionListDefinition filter).tparams) 1
      (Qsig (collectionListDefinition filter).params (collectionListDefinition filter).ret (collectionListDefinition filter).eff)
      Q (listArgs map filter) [Eff.row 0] (collectionListDefinition filter).eff := by
    cases map <;> cases filter <;> constructor
    all_goals first | (constructor <;> higher_simp) | higher_simp
    all_goals rintro (_|(_|i)) t p ht hp <;> higher_simp
    all_goals subst_vars; exact sat_empty table _ _
  have inst : SignatureInstance P (higherParams map filter) Γ (collectionListDefinition filter).tel
      (TypeCtx.kinds (collectionListDefinition filter).tparams) (listArgs map filter) [Eff.row 0] := by
    cases map <;> cases filter <;> constructor
    all_goals first
      | (constructor <;> higher_simp)
      | higher_simp
      | (rintro (_|(_|i)) a k ha hk <;> higher_simp <;> subst_vars <;> higher_simp)
      | (intro e he; cases List.mem_singleton.mp he; constructor <;> higher_simp)
    all_goals first
      | (solve | constructor <;> (constructor <;> higher_simp))
      | (solve | constructor <;> constructor <;> higher_simp)
      | (solve | constructor <;> higher_simp)
      | (rintro (_|(_|i)) a k ha hk <;> higher_simp <;> subst_vars <;> constructor <;> higher_simp)
  have typed := HasTypeVQ.fun_empty (Ψ := StoreTy.empty) (Φ := Φ) lookup names (by rfl) ad inst
  apply typed.convert
  · cases map <;> cases filter <;> higher_simp
    all_goals first
      | simpa [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.row] using Ty.foldFn_toTel
          ⟨["xs","f"],[.list (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 1) (Eff.row 0)],.list (.tvar 1),Eff.row 0,by simp [NamesWF]⟩
      | simpa [FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.row] using Ty.foldFn_toTel
          ⟨["xs","p"],[.list (.tvar 0),.fn ["value"] [.tvar 0] (.base .boolean) (Eff.row 0)],.list (.tvar 0),Eff.row 0,by simp [NamesWF]⟩
      | simpa [pairType,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.row] using Ty.foldFn_toTel
          ⟨["xs","f"],[.list (pairType 1),.fn ["value"] [pairType 1] (pairType 2) (Eff.row 0)],.list (pairType 2),Eff.row 0,by simp [NamesWF]⟩
      | simpa [pairType,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.row] using Ty.foldFn_toTel
          ⟨["xs","p"],[.list (pairType 1),.fn ["value"] [pairType 1] (.base .boolean) (Eff.row 0)],.list (pairType 1),Eff.row 0,by simp [NamesWF]⟩
  · cases map <;> cases filter <;> constructor <;> higher_simp

set_option maxHeartbeats 1000000 in
theorem pair_function {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (filter second : Bool) (arity : P.DataArity "Pair" 2)
    (lookup : P.defs (if second then "Pair.second" else "Pair.first") = some (collectionPairProjection second)) :
    HasTypeVQ P B StoreTy.empty Q (higherParams true filter) Γ Φ
      (.fnRef (if second then "Pair.second" else "Pair.first") [.tvar 0,.tvar 1] [])
      (.fn ["p"] [pairType 1] (.tvar (if second then 1 else 0)) Eff.empty) := by
  have ar : ∃ n, P.DataArity "Pair" n ∧ 2 = n := ⟨2,arity,rfl⟩
  have pairKind := TyCon.arity_data arity
  have names : NamesWF (collectionPairProjection second).names (collectionPairProjection second).params := by
    cases second <;> collection_simp
  have ad : Admissible B (higherParams true filter) Γ.length
      (TypeCtx.constraints (collectionPairProjection second).tparams) 0
      (Qsig (collectionPairProjection second).params (collectionPairProjection second).ret (collectionPairProjection second).eff)
      Q [.tvar 0,.tvar 1] [] (collectionPairProjection second).eff := by
    cases filter <;> cases second <;> constructor
    all_goals first | (constructor <;> collection_simp) | collection_simp
    all_goals rintro (_|(_|i)) t p ht hp <;> collection_simp
    all_goals subst_vars; exact sat_empty table _ _
  have inst : SignatureInstance P (higherParams true filter) Γ (collectionPairProjection second).tel
      (TypeCtx.kinds (collectionPairProjection second).tparams) [.tvar 0,.tvar 1] [] := by
    cases filter <;> cases second <;> constructor
    all_goals first | (constructor <;> collection_simp) | collection_simp
    all_goals first
      | (solve | constructor <;> (constructor <;> collection_simp))
      | (rintro (_|(_|i)) a k ha hk <;> collection_simp <;> subst_vars <;> constructor <;> collection_simp)
  have typed := HasTypeVQ.fun_empty (Ψ := StoreTy.empty) (Φ := Φ) lookup names (by rfl) ad inst
  apply typed.convert
  · cases filter <;> cases second <;> collection_simp
    all_goals first
      | simpa [pairType,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using
          Ty.foldFn_toTel ⟨["p"],[pairType 1],.tvar 0,Eff.empty,by simp [NamesWF]⟩
      | simpa [pairType,FnView.toTel,Ty.toTel,Ty.shiftV,shiftVTys,Eff.shiftV,Eff.empty] using
          Ty.foldFn_toTel ⟨["p"],[pairType 1],.tvar 1,Eff.empty,by simp [NamesWF]⟩
  · cases filter <;> cases second <;> constructor <;> collection_simp

private theorem lift_pure {P B Ψ Q C Γ Φ R m a Δ} (ann : Ty.Annotation P C Γ a)
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a Eff.empty Δ) :
    HasTypeCQ P B Ψ Q C Γ Φ R m a (Eff.row 0) Δ := by
  apply HasTypeCQ.C_Sub typed .refl _ ann.wf ann.sorted ann.declared
  constructor
  · intro a h; simp [Eff.mem,Eff.empty,Eff.test,Eff.atoms] at h
  · intro t h; simp [Eff.memFail,Eff.empty,Eff.fails] at h

local macro "collection_var" : tactic => `(tactic|
  (refine HasTypeVQ.V_Var rfl ?_; intro b t e; higher_simp))

set_option maxHeartbeats 1000000 in
theorem map_wrapper {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (filter : Bool) (arity : P.DataArity "Pair" 2)
    (pairDecl : P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
    (lookup : ∀ second, P.defs (if second then "Pair.second" else "Pair.first") = some (collectionPairProjection second))
    (fvar : Γ[1]? = some (some (higherCallback true filter))) :
    HasTypeVQ P B StoreTy.empty Q (higherParams true filter) Γ Φ
      (.lam ["value"] [pairType 1] (mapCallbackBody filter)) (listCallback true filter) := by
  have ar : ∃ n, P.DataArity "Pair" n ∧ 2 = n := ⟨2,arity,rfl⟩
  have pairKind := TyCon.arity_data arity
  have proj := fun Γ Φ second => pair_function (Γ := Γ) (Φ := Φ) (Q := Q) table filter second arity (lookup second)
  have hidden : (hideConts Γ)[1]? = some (some (higherCallback true filter)) :=
    hideConts_lookup.mpr ⟨fvar,by cases filter <;> intro b t e <;> simp [higherCallback,Ty.core]⟩
  cases filter
  all_goals
    apply HasTypeVQ.V_Lam
    · simp [NamesWF]
    · higher_simp
    · higher_simp
    · dsimp only [mapCallbackBody]
      apply HasTypeCQ.C_Let (a := .tvar 0)
      · apply lift_pure (by constructor <;> higher_simp)
        exact .C_App (proj _ _ false) (.cons (by collection_var) .nil)
      · first
        | (apply HasTypeCQ.C_Let (a := .tvar 1)
           · apply lift_pure (by constructor <;> higher_simp)
             exact .C_App (proj _ _ true) (.cons (by collection_var) .nil)
           · apply HasTypeCQ.C_App (ns := ["key","value"]) (as := [.tvar 0,.tvar 1])
             · refine HasTypeVQ.V_Var ?_ ?_
               · simp [bindParams,Ctx.extend,hidden,Ty.shiftV,shiftVTys,higherCallback]
               · intro b t e; higher_simp
             · exact .cons (by collection_var) (.cons (by collection_var) .nil)
           · higher_simp)
        | (apply HasTypeCQ.C_Let (a := .tvar 0)
           · apply lift_pure (by constructor <;> higher_simp)
             exact .C_App (proj _ _ false) (.cons (by collection_var) .nil)
           · apply HasTypeCQ.C_Let (a := .tvar 1)
             · apply lift_pure (by constructor <;> higher_simp)
               exact .C_App (proj _ _ true) (.cons (by collection_var) .nil)
             · apply HasTypeCQ.C_Let (a := .tvar 2)
               · apply HasTypeCQ.C_App (ns := ["key","value"]) (as := [.tvar 0,.tvar 1])
                 · refine HasTypeVQ.V_Var ?_ ?_
                   · simp [bindParams,Ctx.extend,hidden,Ty.shiftV,shiftVTys,higherCallback,outputElement]
                   · intro b t e; higher_simp
                 · try higher_simp
                   exact .cons (by collection_var) (.cons (by collection_var) .nil)
               · apply lift_pure (by constructor <;> higher_simp)
                 apply HasTypeCQ.C_Return
                 apply HasTypeVQ.V_Con pairDecl rfl
                 · constructor
                   · rfl
                   · rintro (_|(_|i)) a k ha hk <;> higher_simp <;> subst_vars <;> constructor <;> higher_simp
                 · intro t ht; simp only [List.mem_cons,List.not_mem_nil,or_false] at ht
                   rcases ht with rfl | rfl <;> simp [Ty.WF]
                 · exact .cons (by collection_var) (.cons (by collection_var) .nil)
                 · constructor <;> higher_simp
               · higher_simp
             · higher_simp
           · higher_simp)
      · higher_simp
    · higher_simp


set_option maxHeartbeats 1000000 in
/-- 四本の静的な本体型付け。callback の動的な保存を前提にしない。 -/
theorem collectionHigher_body_typed {P B} (table : StandardKeyTyping.Table P B)
    (map filter : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (pairDecl : map = true → P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
    (projections : map = true → ∀ second, P.defs (if second then "Pair.second" else "Pair.first") = some (collectionPairProjection second))
    (primitives : ∀ build, B.sig (primitiveName map build) = some (collectionPrimitiveSig B.sat map build))
    (lists : P.defs (if filter then "List.filter" else "List.map") = some (collectionListDefinition filter)) :
    (collectionHigherRow map filter).BodyTyped P B := by
  have ar : map = true → ∃ n, P.DataArity "Pair" n ∧ 2 = n := fun h => ⟨2,arity h,rfl⟩
  have pairKind : map = true → TyCon.arity P (.data "Pair") = some 2 := fun h => TyCon.arity_data (arity h)
  have prim := fun Γ Φ build => primitive_function (Γ := Γ) (Φ := Φ)
    (Q := QTel (higherTel map filter)) table map filter build arity (primitives build)
  have listFn := fun Γ Φ => list_function (Γ := Γ) (Φ := Φ)
    (Q := QTel (higherTel map filter)) table map filter arity lists
  refine ⟨_,rfl,?_,?_,?_,TelBodyTy.param (TelBodyTy.param (TelBodyTy.done ?_))⟩
  · cases map <;> cases filter <;> higher_simp
  · cases map <;> cases filter <;> higher_simp
  · cases map <;> cases filter <;> constructor <;> higher_simp
  · dsimp only [collectionHigherRow,collectionHigherBody]
    apply HasTypeCQ.C_Let (a := .list (listElement map))
    · apply lift_pure (by cases map <;> cases filter <;> constructor <;> higher_simp)
      cases map <;> cases filter
      all_goals exact .C_App (prim _ _ false) (.cons (by collection_var) .nil)
    · apply HasTypeCQ.C_Let (a := .list (listOutput map filter))
      · apply HasTypeCQ.C_App (listFn _ _)
        refine .cons (by cases map <;> cases filter <;> collection_var) (.cons ?_ .nil)
        cases map
        · cases filter <;> collection_var
        · exact map_wrapper table filter (arity rfl) (pairDecl rfl) (projections rfl) (by cases filter <;> rfl)
      · apply lift_pure (by cases map <;> cases filter <;> constructor <;> higher_simp)
        cases map <;> cases filter
        all_goals exact .C_App (prim _ _ true) (.cons (by collection_var) .nil)
      · cases map <;> cases filter <;> higher_simp
    · cases map <;> cases filter <;> higher_simp

end
end Benitoite.Release.Refinement.StandardBodies
