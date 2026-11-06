import Benitoite.Release.Refinement.StandardCollectionPrecision
import Benitoite.Release.Refinement.StandardHeadTailBodies
import Benitoite.Release.Refinement.StandardMapReplaceValues

/-! # 大きさの上限を検査するMap・Setの高階本体 -/
namespace Benitoite.Release.Refinement.StandardCollectionRefinedBodies
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 4000000
set_option linter.unusedSimpArgs false
open StandardCollections

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
      (.done (.refined (outputType map filter)
        (if map && !filter then .eq (StandardCollectionPrecision.size map (.var 0)) (StandardCollectionPrecision.size map (.var 2))
         else .le (StandardCollectionPrecision.size map (.var 0)) (StandardCollectionPrecision.size map (.var 2)))) (Eff.row 0)))


private def higherBody (map filter : Bool) : Comp :=
  .letIn (.app (.prim (if map then "Map.toList" else "Set.toList")
      (if map then [.tvar 0,.tvar 1] else [.tvar 0]) [] []) [.var 1])
    (.letIn (.app (.fnRef (if filter then "List.filter" else "List.map")
      (if map then (if filter then [pairType 1] else [pairType 1,.tvar 2])
        else (if filter then [.tvar 0] else [.tvar 0,.tvar 1])) [Eff.row 0])
      [.var 0,if map then .lam ["value"] [pairType 1] (StandardBodies.mapCallbackBody true) else .var 1])
      (.letIn (if map && !filter then
          .app (.prim "%Map.replaceValues" [.tvar 0,.tvar 1,.tvar 2] [] []) [.var 3,.var 0]
        else .app (.prim (if map then "Map.fromList" else "Set.fromList")
          (if map then [.tvar 0,outputElement map filter] else [outputElement map filter]) [] []) [.var 0])
        (.ret (.var 0))))

private def higherRow (map filter : Bool) : StandardContracts.Row :=
  ⟨(if map then "Map." else "Set.") ++ (if filter then "filter" else "map"),
    higherParams map filter,1,higherTel map filter,some (higherBody map filter),.core,
    [if map then .mapHigherOrder else .setUpdate]⟩
private def collectionPrimitiveSig := StandardCollectionPrecision.signature
private def collectionPairProjection := StandardBodies.collectionPairProjection
local macro "collection_simp" : tactic => `(tactic|
  try simp_all [StandardMapReplaceValues.signature,StandardMapReplaceValues.size,StandardMapReplaceValues.length,StandardCollectionPrecision.signature,StandardBodies.collectionPrimitiveSig,
    StandardCollectionPrecision.result,StandardCollectionPrecision.input,StandardCollectionPrecision.collection,
    StandardCollectionPrecision.element,StandardCollectionPrecision.predicate,StandardCollectionPrecision.size,
    StandardCollectionPrecision.length,Pred.Sorted,Pred.WF,Pred.VarsIn,Pred.Declared,Term.Declared,
    Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Tel.argumentsEnv,valEnv,Val.toTerm?,Pred.open,
    Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,
    predBind,termBind,termBind?,upValues,keyParam,higherParams,pairType,sourceType,outputElement,outputType,higherCallback,higherTel,
    collectionPrimitiveSig,higherRow,collectionPairProjection,
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

private def listArgs (map filter : Bool) : List Ty :=
  if map then (if filter then [pairType 1] else [pairType 1,.tvar 2])
  else (if filter then [.tvar 0] else [.tvar 0,.tvar 1])
private def listElement (map : Bool) : Ty := if map then pairType 1 else .tvar 0
private def listOutput (map filter : Bool) : Ty :=
  if map then (if filter then pairType 1 else .tvar 2) else outputElement map filter
private def listCallback (map filter : Bool) : Ty :=
  .fn ["value"] [listElement map] (if filter then .base .boolean else listOutput map filter) (Eff.row 0)

local macro "higher_simp" : tactic => `(tactic|
  ((try simp_all [listArgs,listElement,listOutput,listCallback,
    inputTypes,primitiveName,primitiveInput,primitiveResult,FnView.toTel,Ty.toTel]) <;> (try collection_simp)))


private def listTel (map filter : Bool) : Tel :=
  .param "xs" (.list (listElement map)) (.param (if filter then "p" else "f") (listCallback map filter)
    (.done (.refined (.list (listOutput map filter))
      (if filter then .le (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.length (.var 2))
       else .eq (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.length (.var 2)))) (Eff.row 0)))
private def collectionListDefinition := StandardHeadTail.publicDefinition
private theorem list_decl (filter : Bool) : collectionListDefinition filter =
    ⟨List.replicate (if filter then 1 else 2) TypeCtx.valueParam,1,["xs",if filter then "p" else "f"],
      [.list (.tvar 0),.fn ["value"] [.tvar 0] (if filter then .base .boolean else .tvar 1) (Eff.row 0)],
      .refined (.list (.tvar (if filter then 0 else 1)))
        (if filter then .le (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.length (.var 2))
         else .eq (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.length (.var 2))),
      Eff.row 0,StandardHeadTail.publicBody filter,[]⟩ := by cases filter <;> rfl

local macro "precision_simp" : tactic => `(tactic|
 ((try simp_all [list_decl,listTel,StandardCollectionPrecision.signature,StandardBodies.collectionPrimitiveSig,
   StandardCollectionPrecision.result,StandardCollectionPrecision.input,StandardCollectionPrecision.collection,
   StandardCollectionPrecision.element,StandardCollectionPrecision.predicate,StandardCollectionPrecision.size,
   StandardCollectionPrecision.length,Pred.Sorted,Pred.WF,Pred.VarsIn,Pred.Declared,Term.Declared,
   Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Tel.argumentsEnv,valEnv,Val.toTerm?,Pred.open,
   Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,
   predBind,termBind,termBind?,upValues]) <;> (try higher_simp)))
set_option maxHeartbeats 2000000 in
private theorem list_function {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (map filter : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (lookup : P.defs (if filter then "List.filter" else "List.map") = some (collectionListDefinition filter)) :
    HasTypeVQ P B StoreTy.empty Q (higherParams map filter) Γ Φ
      (.fnRef (if filter then "List.filter" else "List.map") (listArgs map filter) [Eff.row 0])
      (.dependentFn (listTel map filter)) := by
  have ar : map = true → ∃ n, P.DataArity "Pair" n ∧ 2 = n := fun h => ⟨2,arity h,rfl⟩
  have pairKind : map = true → TyCon.arity P (.data "Pair") = some 2 := fun h => TyCon.arity_data (arity h)
  have selfrow := row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  have names : NamesWF (collectionListDefinition filter).names (collectionListDefinition filter).params := by
    simp only [list_decl]
    cases filter <;> precision_simp
  have ad : Admissible B (higherParams map filter) Γ.length
      (TypeCtx.constraints (collectionListDefinition filter).tparams) 1
      (Qsig (collectionListDefinition filter).params (collectionListDefinition filter).ret (collectionListDefinition filter).eff)
      Q (listArgs map filter) [Eff.row 0] (collectionListDefinition filter).eff := by
    simp only [list_decl]
    cases map <;> cases filter <;> constructor
    all_goals first | (constructor <;> precision_simp) | precision_simp
    all_goals rintro (_|(_|i)) t p ht hp <;> precision_simp
    all_goals subst_vars; exact sat_empty table _ _
  have inst : SignatureInstance P (higherParams map filter) Γ (collectionListDefinition filter).tel
      (TypeCtx.kinds (collectionListDefinition filter).tparams) (listArgs map filter) [Eff.row 0] := by
    simp only [list_decl]
    cases map <;> cases filter <;> constructor
    all_goals first
      | (constructor <;> precision_simp)
      | precision_simp
      | (rintro (_|(_|i)) a k ha hk <;> precision_simp <;> subst_vars <;> precision_simp)
      | (intro e he; cases List.mem_singleton.mp he; constructor <;> precision_simp)
    all_goals first
      | (solve | constructor <;> (constructor <;> precision_simp))
      | (solve | constructor <;> constructor <;> precision_simp)
      | (solve | constructor <;> precision_simp)
      | (rintro (_|(_|i)) a k ha hk <;> precision_simp <;> subst_vars <;> constructor <;> precision_simp)
  have typed := HasTypeVQ.fun_empty (Ψ := StoreTy.empty) (Φ := Φ) lookup names (by rfl) ad inst
  have same : instantiatedTel (collectionListDefinition filter).tel (listArgs map filter) [Eff.row 0] =
      listTel map filter := by
    simp only [list_decl]
    cases map <;> cases filter <;> precision_simp
  rw [same] at typed
  exact typed


private def primitiveTel (map filter build : Bool) : Tel :=
  .param (if build then (if map then "pairs" else "xs") else (if map then "m" else "s"))
    (primitiveInput map filter build)
    (.done (.refined (primitiveResult map filter build)
      (StandardCollectionPrecision.predicate map build (.var 0) (.var 1))) Eff.empty)

set_option maxHeartbeats 2000000 in
private theorem primitive_function {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (map filter build : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (lookup : B.sig (primitiveName map build) = some (collectionPrimitiveSig B.sat map build)) :
    HasTypeVQ P B StoreTy.empty Q (higherParams map filter) Γ Φ
      (.prim (primitiveName map build) (inputTypes map filter build) [] [])
      (.dependentFn (primitiveTel map filter build)) := by
  have pairAr : map = true → ∃ n, P.DataArity "Pair" n ∧ 2 = n := fun h => ⟨2,arity h,rfl⟩
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext a; simp [mapRangeAtoms]
  have range : B.RangeAdmissible (primitiveName map build) (collectionPrimitiveSig B.sat map build) [] := by
    cases map <;> cases build <;> precision_simp
  have names : NamesWF (collectionPrimitiveSig B.sat map build).names (collectionPrimitiveSig B.sat map build).params := by
    cases map <;> cases build <;> precision_simp
  have admissible : PrimitiveAdmissible (higherParams map filter) Γ.length (collectionPrimitiveSig B.sat map build) Q
      (inputTypes map filter build) [] := by
    simp only [inputTypes]
    cases map <;> cases filter <;> cases build <;> constructor
    all_goals first
      | (constructor <;> precision_simp)
      | precision_simp
    all_goals rintro (_|(_|i)) t p ht hp <;> precision_simp
    all_goals subst_vars; rw [table.sat_eq]; rfl
  have inst : SignatureInstance P (higherParams map filter) Γ
      (Tel.instR [] (collectionPrimitiveSig B.sat map build).tel)
      (TypeCtx.kinds (collectionPrimitiveSig B.sat map build).tparams)
      (inputTypes map filter build) [] := by
    simp only [inputTypes]
    cases map <;> cases filter <;> cases build <;> constructor
    all_goals first
      | (constructor <;> precision_simp)
      | precision_simp
      | (rintro (_|(_|i)) a k ha hk <;> precision_simp <;> subst_vars <;> precision_simp)
    all_goals first
      | (solve | constructor <;> (constructor <;> precision_simp))
      | (solve | repeat constructor <;> precision_simp)
      | (rintro (_|(_|i)) a k ha hk <;> precision_simp <;> subst_vars <;> constructor <;> precision_simp)
  have typed := HasTypeVQ.V_Prim (Ψ := StoreTy.empty) (Φ := Φ) lookup range names admissible inst
  have same : instantiatedTel (Tel.instR [] (collectionPrimitiveSig B.sat map build).tel)
      (inputTypes map filter build) [] = primitiveTel map filter build := by
    simp only [primitiveTel]
    cases map <;> cases filter <;> cases build <;> precision_simp
  rw [same] at typed
  exact typed

private theorem pure_effect {P B Ψ Q C Γ Φ R m a L}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a Eff.empty L) :
    HasTypeCQ P B Ψ Q C Γ Φ R m a (Eff.row 0) L := by
  refine HasTypeCQ.C_Eff (ε' := Eff.row 0) typed ⟨?_,?_⟩
  · intro a h; simp [Eff.mem,Eff.empty,Eff.test,Eff.atoms] at h
  · intro t h; simp [Eff.memFail,Eff.empty,Eff.fails] at h
local macro "collection_var" : tactic => `(tactic|
 (refine HasTypeVQ.V_Var rfl ?_; intro b t e; precision_simp))

private theorem value_wrapper {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (arity : P.DataArity "Pair" 2)
    (lookup : ∀ second, P.defs (if second then "Pair.second" else "Pair.first") = some (collectionPairProjection second))
    (fvar : Γ[1]? = some (some (higherCallback true false))) :
    HasTypeVQ P B StoreTy.empty Q (higherParams true false) Γ Φ
      (.lam ["value"] [pairType 1] (StandardBodies.mapCallbackBody true)) (listCallback true false) := by
  have ar : ∃ n, P.DataArity "Pair" n ∧ 2=n := ⟨2,arity,rfl⟩
  have pairKind := TyCon.arity_data arity
  have proj (Γ : Ctx) (Φ : List Pred) (second : Bool) :
      HasTypeVQ P B StoreTy.empty Q (higherParams true false) Γ Φ
        (.fnRef (if second then "Pair.second" else "Pair.first") [.tvar 0,.tvar 1] [])
        (.fn ["p"] [pairType 1] (.tvar (if second then 1 else 0)) Eff.empty) :=
    StandardBodies.pair_function (Γ := Γ) (Φ := Φ) (Q := Q) table false second arity (lookup second)
  have hidden : (hideConts Γ)[1]? = some (some (higherCallback true false)) :=
    hideConts_lookup.mpr ⟨fvar,by intro b t e; simp [higherCallback,Ty.core]⟩
  apply HasTypeVQ.V_Lam
  · simp [NamesWF]
  · precision_simp
  · precision_simp
  · dsimp only [StandardBodies.mapCallbackBody]
    apply HasTypeCQ.C_Let (a := .tvar 0)
    · apply pure_effect
      exact .C_App (proj _ _ false) (.cons (by collection_var) .nil)
    · apply HasTypeCQ.C_Let (a := .tvar 1)
      · apply pure_effect
        exact .C_App (proj _ _ true) (.cons (by collection_var) .nil)
      · apply HasTypeCQ.C_App (ns := ["key","value"]) (as := [.tvar 0,.tvar 1])
        · refine HasTypeVQ.V_Var ?_ ?_
          · simp [bindParams,Ctx.extend,hidden,Ty.shiftV,shiftVTys,higherCallback,outputElement,listOutput]
          · intro b t e; precision_simp
        · exact .cons (by collection_var) (.cons (by collection_var) .nil)
      · precision_simp
    · precision_simp
  · precision_simp

private def replaceTel : Tel :=
  .param "m" (.map (.tvar 0) (.tvar 1))
    (.param "values" (.refined (.list (.tvar 2))
      (.eq (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.size true (.var 1))))
      (.done (.refined (.map (.tvar 0) (.tvar 2))
        (.eq (StandardCollectionPrecision.size true (.var 0)) (StandardCollectionPrecision.size true (.var 2)))) Eff.empty))

private theorem replace_function {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (lookup : B.sig "%Map.replaceValues" = some (StandardMapReplaceValues.signature B.sat)) :
    HasTypeVQ P B StoreTy.empty Q (higherParams true false) Γ Φ
      (.prim "%Map.replaceValues" [.tvar 0,.tvar 1,.tvar 2] [] []) (.dependentFn replaceTel) := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext a; cases a <;> simp [mapRangeAtoms]
  have range : B.RangeAdmissible "%Map.replaceValues" (StandardMapReplaceValues.signature B.sat) [] := by precision_simp
  have names : NamesWF (StandardMapReplaceValues.signature B.sat).names (StandardMapReplaceValues.signature B.sat).params := by precision_simp
  have admissible : PrimitiveAdmissible (higherParams true false) Γ.length (StandardMapReplaceValues.signature B.sat) Q
      [.tvar 0,.tvar 1,.tvar 2] [] := by
    constructor
    all_goals first | (constructor <;> precision_simp) | precision_simp
    all_goals rintro (_|(_|(_|i))) t p ht hp <;> precision_simp
    all_goals subst_vars; rw [table.sat_eq]; rfl
  have inst : SignatureInstance P (higherParams true false) Γ
      (Tel.instR [] (StandardMapReplaceValues.signature B.sat).tel)
      (TypeCtx.kinds (StandardMapReplaceValues.signature B.sat).tparams) [.tvar 0,.tvar 1,.tvar 2] [] := by
    constructor
    all_goals first
      | (constructor <;> precision_simp)
      | precision_simp
      | (rintro (_|(_|(_|i))) a k ha hk <;> precision_simp <;> subst_vars <;> precision_simp)
    all_goals first
      | (solve | constructor <;> (constructor <;> precision_simp))
      | (solve | repeat constructor <;> precision_simp)
      | (rintro (_|(_|(_|i))) a k ha hk <;> precision_simp <;> subst_vars <;> constructor <;> precision_simp)
  have typed := HasTypeVQ.V_Prim (Ψ := StoreTy.empty) (Φ := Φ) lookup range names admissible inst
  have same : instantiatedTel (Tel.instR [] (StandardMapReplaceValues.signature B.sat).tel)
      [.tvar 0,.tvar 1,.tvar 2] [] = replaceTel := by
    simp only [replaceTel]
    precision_simp
  rw [same] at typed
  exact typed
private def upper_map_premise : Pred := (.and (.le (.var (0)) (.var (1))) (.and (.eq (.var (1)) (.var (2))) (.eq (.var (2)) (.var (3)))))
private def upper_map_goal : Pred := (.le (.var (0)) (.var (3)))
private def upper_map_certificate : Certificate := (.refute (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.derive (.combine [(0,1),(1,1),(3,1),(5,1)] ⟨List.replicate 8 0,-1⟩) (.closeLinear 6))))))))))))))
private theorem upper_map_checked : CertificateKernel.check upper_map_premise upper_map_goal upper_map_certificate = true := by decide

private def upper_filter_premise : Pred := (.and (.le (.var (0)) (.var (1))) (.and (.le (.var (1)) (.var (2))) (.eq (.var (2)) (.var (3)))))
private def upper_filter_goal : Pred := (.le (.var (0)) (.var (3)))
private def upper_filter_certificate : Certificate := (.refute (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.derive (.combine [(0,1),(1,1),(2,1),(4,1)] ⟨List.replicate 8 0,-1⟩) (.closeLinear 5))))))))))))
private theorem upper_filter_checked : CertificateKernel.check upper_filter_premise upper_filter_goal upper_filter_certificate = true := by decide

private def equal_chain_premise : Pred := (.and (.eq (.var (0)) (.var (1))) (.eq (.var (1)) (.var (2))))
private def equal_chain_goal : Pred := (.eq (.var (0)) (.var (2)))
private def equal_chain_certificate : Certificate := (.refute (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.consume (.cases (.consume (.derive (.combine [(1,1),(3,1),(4,1)] ⟨List.replicate 6 0,-1⟩) (.closeLinear 5))) (.consume (.derive (.combine [(0,1),(2,1),(4,1)] ⟨List.replicate 6 0,-1⟩) (.closeLinear 5)))))))))))))
private theorem equal_chain_checked : CertificateKernel.check equal_chain_premise equal_chain_goal equal_chain_certificate = true := by decide


private theorem upper_entails {Ξ : List Pred} (map filter : Bool) (original xs ys output : Term)
    (build : Entails Ξ (.le (StandardCollectionPrecision.size map output) (StandardCollectionPrecision.length ys)))
    (mapped : Entails Ξ (if filter then .le (StandardCollectionPrecision.length ys) (StandardCollectionPrecision.length xs)
      else .eq (StandardCollectionPrecision.length ys) (StandardCollectionPrecision.length xs)))
    (projected : Entails Ξ (.eq (StandardCollectionPrecision.length xs) (StandardCollectionPrecision.size map original))) :
    Entails Ξ (.le (StandardCollectionPrecision.size map output) (StandardCollectionPrecision.size map original)) := by
  let ν : ObservationEnv := fun i => if i=0 then some (StandardCollectionPrecision.size map output)
    else if i=1 then some (StandardCollectionPrecision.length ys)
    else if i=2 then some (StandardCollectionPrecision.length xs) else some (StandardCollectionPrecision.size map original)
  cases filter
  · exact Entails.checkedAt ν upper_map_checked (.and_intro build (.and_intro mapped projected))
  · exact Entails.checkedAt ν upper_filter_checked (.and_intro build (.and_intro mapped projected))

private theorem equal_entails {Ξ : List Pred} (a b c : Term)
    (first : Entails Ξ (.eq a b)) (second : Entails Ξ (.eq b c)) : Entails Ξ (.eq a c) := by
  exact Entails.checkedAt (fun i => if i=0 then some a else if i=1 then some b else some c)
    equal_chain_checked (.and_intro first second)

private theorem variable_carrier {P B Ψ Q C Γ Φ i a p}
    (hi : Γ[i]?=some (some (.refined a p))) (ordinary : Ordinary a)
    (ann : Ty.Annotation P C Γ a) : HasTypeVQ P B Ψ Q C Γ Φ (.var i) a :=
  .V_Sub (.V_Var hi ordinary) .forget ann.wf ann.sorted ann.declared
local macro "collection_carrier" : tactic => `(tactic|
 first
 | collection_var
 | (apply variable_carrier rfl (by intro b t e; precision_simp); constructor <;> precision_simp))

open Lean Elab Tactic in
elab "collection_assumption" i:num a:term : tactic => do
  let target ← instantiateMVars (← (← getMainGoal).getType)
  let args := target.getAppArgs[0]!.getAppArgs
  let ctx := args[args.size-2]!.getAppArgs[0]!
  let facts := args[args.size-1]!
  let cs ← PrettyPrinter.delab ctx
  let fs ← PrettyPrinter.delab facts
  evalTactic (← `(tactic|
    have h := StandardHeadTail.variable_refinement (Γ := $cs) (Φ := $fs) (i := $i) (a := $a)
      (by rfl) (by intro b t e; precision_simp);
    precision_simp; all_goals exact h))

private def projectionType (map : Bool) : Ty := .refined (.list (listElement map))
  (.eq (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.size map (.var 2)))
private def mappedType (map filter : Bool) : Ty := .refined (.list (listOutput map filter))
  (if filter then .le (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.length (.var 1))
   else .eq (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.length (.var 1)))
private def builtType (map filter : Bool) : Ty := .refined (outputType map filter)
  (if map && !filter then .eq (StandardCollectionPrecision.size map (.var 0)) (StandardCollectionPrecision.size map (.var 4))
   else .le (StandardCollectionPrecision.size map (.var 0)) (StandardCollectionPrecision.length (.var 1)))
local macro "body_simp" : tactic => `(tactic|
 (try simp only [projectionType,mappedType,builtType,replaceTel,primitiveTel]
  precision_simp))
local macro "body_annotation" : tactic => `(tactic|
 (constructor <;> body_simp
  all_goals first | omega | rfl))

local macro "higher_body" map:term:max filter:term:max table:ident arity:ident pairDecl:ident
    projections:ident prim:ident listFn:ident replaceFn:ident : tactic => `(tactic|
 (refine ⟨_,rfl,?_,?_,?_,TelBodyTy.param (TelBodyTy.param (TelBodyTy.done ?_))⟩
  · precision_simp
  · precision_simp
  · body_annotation
  · dsimp only [higherRow,higherBody]
    apply HasTypeCQ.C_Let (a := projectionType $map)
    · apply pure_effect
      apply HasTypeCQ.C_DependentApp ($prim _ _ false)
      refine .param (by body_annotation) (by collection_var) ?_
      body_simp
      apply HasTypeTelArgsQ.done
      body_annotation
    · apply HasTypeCQ.C_Let (a := mappedType $map $filter)
      · apply HasTypeCQ.C_DependentApp ($listFn _ _)
        refine .param (by body_annotation) (by collection_carrier) ?_
        body_simp
        refine .param (by body_annotation) ?_ ?_
        · first
          | collection_var
          | exact value_wrapper $table $arity (by intro second; cases second; exact $projections.1; exact $projections.2) (by rfl)
          | exact StandardBodies.map_wrapper $table true $arity $pairDecl (by intro second; cases second; exact $projections.1; exact $projections.2) (by rfl)
        · body_simp
          apply HasTypeTelArgsQ.done
          body_annotation
      · apply HasTypeCQ.C_Let (a := builtType $map $filter)
        · apply pure_effect
          first
          | (apply HasTypeCQ.C_DependentApp ($replaceFn _ _)
             refine .param (by body_annotation) (by collection_var) ?_
             body_simp
             refine .param (by body_annotation) ?_ (by
               body_simp
               apply HasTypeTelArgsQ.done
               body_annotation)
             apply HasTypeVQ.V_Refine (a := .list (.tvar 2)) (sort := .list)
               (by collection_carrier) rfl rfl
             all_goals first | (solve | body_simp) | skip
             apply equal_entails (StandardCollectionPrecision.length (.var 0))
               (StandardCollectionPrecision.length (.var 1)) (StandardCollectionPrecision.size true (.var 3))
             · collection_assumption 0 (.list (.tvar 2))
             · collection_assumption 1 (.list (pairType 1)))
          | (apply HasTypeCQ.C_DependentApp ($prim _ _ true)
             refine .param (by body_annotation) (by collection_carrier) ?_
             body_simp
             apply HasTypeTelArgsQ.done
             body_annotation)
        · apply pure_effect
          apply HasTypeCQ.C_Return
          first
          | collection_var
          | (body_simp
             first
             | apply HasTypeVQ.V_Refine (a := .set (.tvar 0)) (sort := .set) (by collection_carrier) rfl rfl
             | apply HasTypeVQ.V_Refine (a := .set (.tvar 1)) (sort := .set) (by collection_carrier) rfl rfl
             | apply HasTypeVQ.V_Refine (a := .map (.tvar 0) (.tvar 1)) (sort := .map) (by collection_carrier) rfl rfl
             all_goals first | (solve | body_simp) | skip
             apply upper_entails $map $filter (.var 4) (.var 2) (.var 1) (.var 0)
             · first
               | collection_assumption 0 (.set (.tvar 0))
               | collection_assumption 0 (.set (.tvar 1))
               | collection_assumption 0 (.map (.tvar 0) (.tvar 1))
             · first
               | collection_assumption 1 (.list (.tvar 0))
               | collection_assumption 1 (.list (.tvar 1))
               | collection_assumption 1 (.list (pairType 1))
             · first
               | collection_assumption 2 (.list (.tvar 0))
               | collection_assumption 2 (.list (pairType 1)))
        · body_simp
      · body_simp
    · body_simp
))

/-- 四つの公開本体の大きさを、callbackの意味を別の前提にせず検査する。 -/
private theorem higher_typed {P B} (table : StandardKeyTyping.Table P B)
    (map filter : Bool) (arity : map=true → P.DataArity "Pair" 2)
    (pairDecl : map=true → P.cons "Pair.Pair"=some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
    (projections : map=true → ∀ second, P.defs (if second then "Pair.second" else "Pair.first") = some (collectionPairProjection second))
    (primitives : ∀ build, B.sig (primitiveName map build)=some (collectionPrimitiveSig B.sat map build))
    (replacement : B.sig "%Map.replaceValues"=some (StandardMapReplaceValues.signature B.sat))
    (lists : P.defs (if filter then "List.filter" else "List.map")=some (collectionListDefinition filter)) :
    (higherRow map filter).BodyTyped P B := by
  have ar : map=true → ∃ n, P.DataArity "Pair" n ∧ 2=n := fun h => ⟨2,arity h,rfl⟩
  have pairKind : map=true → TyCon.arity P (.data "Pair")=some 2 := fun h => TyCon.arity_data (arity h)
  have prim := fun Γ Φ build => primitive_function (Γ := Γ) (Φ := Φ) (Q := QTel (higherTel map filter))
    table map filter build arity (primitives build)
  have listFn := fun Γ Φ => list_function (Γ := Γ) (Φ := Φ) (Q := QTel (higherTel map filter)) table map filter arity lists
  have replaceFn := fun Γ Φ => replace_function (Γ := Γ) (Φ := Φ) (Q := QTel (higherTel map filter)) table replacement
  cases map <;> cases filter
  case false.false => higher_body false false table arity pairDecl projections prim listFn replaceFn
  case false.true => higher_body false true table arity pairDecl projections prim listFn replaceFn
  case true.false => higher_body true false table arity pairDecl projections prim listFn replaceFn
  case true.true => higher_body true true table arity pairDecl projections prim listFn replaceFn

/-- 精密な結果を持つ四つの公開行。 -/
inductive API where | mapMap | mapFilter | setMap | setFilter
  deriving DecidableEq
def API.map : API → Bool | .mapMap | .mapFilter => true | _ => false
def API.filter : API → Bool | .mapFilter | .setFilter => true | _ => false
def API.row (api : API) : StandardContracts.Row := higherRow api.map api.filter
def API.all : List API := [.mapMap,.mapFilter,.setMap,.setFilter]

private def pairRow (second : Bool) : StandardContracts.Row :=
  let d := collectionPairProjection second
  ⟨if second then "Pair.second" else "Pair.first",d.tparams,d.neffs,d.tel,some d.body,.core,[.record]⟩
def coreRows : List StandardContracts.Row := [StandardHeadTail.fromRow false,StandardHeadTail.fromRow true,
  StandardHeadTail.publicRow false,StandardHeadTail.publicRow true,StandardHeadTail.nonemptyPublicRow,
  pairRow false,pairRow true] ++ API.all.map API.row
def definitions : List (FunName × Def) := coreRows.filterMap (fun row => row.definition.map (row.name,·))
def program : Program := { StandardCollectionModel.program with defs := fun f => definitions.lookup f }

private inductive Primitive where | head | tail | append | mapFrom | mapTo | setFrom | setTo | replace
  deriving DecidableEq
private def Primitive.all : List Primitive := [.head,.tail,.append,.mapFrom,.mapTo,.setFrom,.setTo,.replace]
private def Primitive.name : Primitive → String
  | .head => "List.head" | .tail => "List.tail" | .append => "List.append"
  | .mapFrom => "Map.fromList" | .mapTo => "Map.toList" | .setFrom => "Set.fromList" | .setTo => "Set.toList"
  | .replace => "%Map.replaceValues"
private def Primitive.signature (p : Primitive) : PrimSig :=
  match p with
  | .head => StandardHeadTail.headSignature | .tail => StandardHeadTail.tailSignature
  | .append => StandardHeadTail.appendSignature
  | .mapFrom => StandardCollectionPrecision.signature StandardCollectionModel.builtins.sat true true
  | .mapTo => StandardCollectionPrecision.signature StandardCollectionModel.builtins.sat true false
  | .setFrom => StandardCollectionPrecision.signature StandardCollectionModel.builtins.sat false true
  | .setTo => StandardCollectionPrecision.signature StandardCollectionModel.builtins.sat false false
  | .replace => StandardMapReplaceValues.signature StandardCollectionModel.builtins.sat
private def signatures : List (PrimName × PrimSig) := Primitive.all.map (fun p => (p.name,p.signature))
def builtins : Builtins := { StandardCollectionModel.builtins with
  sig := fun name => signatures.lookup name
  delta := fun name ts es rs ws =>
    if name="List.head" then StandardListRemainingResponse.delta .head name ts es rs ws
    else if name="List.tail" then StandardListRemainingResponse.delta .tail name ts es rs ws
    else if name="List.append" then StandardCollections.insertDelta name ts es rs ws
    else if name="%Map.replaceValues" then StandardMapReplaceValues.delta StandardCollectionModel.constructors name ts es rs ws
    else if name="Map.fromList" ∨ name="Map.toList" then mapDelta StandardCollectionModel.constructors name ts es rs ws
    else setDelta StandardCollectionModel.constructors name ts es rs ws }

def table : StandardKeyTyping.Table program builtins :=
  ⟨StandardCollectionModel.declarations,by decide,by decide,rfl,by decide,fun _ _ _ => Iff.rfl⟩
private theorem cons_mem {c cd} (h : program.cons c=some cd) :
    (c,cd) ∈ StandardCollectionModel.declarations.flatMap StandardKeyTyping.DataDecl.entries := by
  obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp h
  rw [eq]
  exact List.mem_append_right _ List.mem_cons_self
private theorem variance_valid : program.VarianceValid := by
  constructor
  · intro d info h; cases h
  · intro c cd h
    have mem := cons_mem h
    change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals
      constructor
      · intro info h; cases h
      · intro a ha
        simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
        all_goals first | subst a | (rcases ha with rfl | rfl)
        all_goals refine ⟨⟨?_,?_,?_⟩,?_,?_⟩
        all_goals simp [Ty.WF,Ty.Sorted,Ty.Declared,Ty.HasKind,TypeCtx.valueParam,
          Ty.VarianceOK,Program.varianceFor,Variance.accepts,program,StandardCollectionModel.program]
private theorem pair_arity : program.DataArity "Pair" 2 := by
  exact StandardCollectionModel.pair_arity
private theorem declarations : MapSetDeclarations program := by
  refine ⟨rfl,pair_arity,?_,rfl,rfl,?_⟩
  · intro c cd h same
    have mem := cons_mem h
    change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all
  · refine ⟨⟨"Option.Some",_,rfl,rfl⟩,?_⟩
    intro c cd h same
    have mem := cons_mem h
    change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all

private theorem head_tail_inputs : StandardHeadTail.Inputs program builtins := by
  refine ⟨⟨rfl,rfl,declarations.optionArity,?_⟩,rfl,rfl,rfl,?_,?_⟩
  · intro c cd h same
    have mem := cons_mem h
    change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all
  · intro filter; cases filter <;> rfl
  · intro C a; rfl

/-- 同じ具体的なP/Bの四つの公開本体を、精密telで検査する。 -/
theorem concrete_typed (api : API) : api.row.BodyTyped program builtins := by
  exact higher_typed table api.map api.filter (fun _ => pair_arity) (fun _ => rfl)
    (by intro _ second; cases second <;> rfl)
    (by intro build; cases api <;> cases build <;> rfl) rfl (by cases api <;> rfl)

/-- 同じ表のList二本と非空mapも固定した依存列を使う。 -/
theorem seven_public_rows :
    (StandardHeadTail.publicRow false).BodyTyped program builtins ∧
    (StandardHeadTail.publicRow true).BodyTyped program builtins ∧
    StandardHeadTail.nonemptyPublicRow.BodyTyped program builtins ∧
    ∀ api ∈ API.all, api.row.BodyTyped program builtins :=
  ⟨StandardHeadTail.public_typed head_tail_inputs false,StandardHeadTail.public_typed head_tail_inputs true,
    StandardHeadTail.nonempty_public_typed head_tail_inputs rfl,fun api _ => concrete_typed api⟩

private theorem primitive_lookup {name sg} (lookup : builtins.sig name=some sg) :
    ∃ p ∈ Primitive.all, name=p.name ∧ sg=p.signature := by
  have mem : (name,sg) ∈ signatures := by
    obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp lookup
    rw [eq]
    exact List.mem_append_right _ List.mem_cons_self
  obtain ⟨p,hp,eq⟩ := List.mem_map.mp mem
  exact ⟨p,hp,(congrArg Prod.fst eq).symm,(congrArg Prod.snd eq).symm⟩

/-- 追加する内部補助を含む全八署名を、同じ実δと全入力で照合する。 -/
theorem concrete_response {Ψ name sg ts es rs ws r e}
    (lookup : builtins.sig name=some sg)
    (args : BuiltinArgs program builtins Ψ name sg ts es rs ws r e) :
    ∃ out, builtins.delta name ts es rs ws=some out ∧ Outcome.Typed program builtins Ψ out r ∧
      AdequateResult ws out ∧ (∀ n,out ≠ .exit n) := by
  obtain ⟨p,_,rfl,rfl⟩ := primitive_lookup lookup
  cases p
  · exact StandardHeadTail.option_response false declarations.someDecl declarations.noneDecl declarations.optionArity args
  · exact StandardHeadTail.option_response true declarations.someDecl declarations.noneDecl declarations.optionArity args
  · exact StandardHeadTail.append_response args
  · exact StandardCollectionPrecision.map_response true table variance_valid declarations args
  · exact StandardCollectionPrecision.map_response false table variance_valid declarations args
  · exact StandardCollectionPrecision.set_response true table variance_valid args
  · exact StandardCollectionPrecision.set_response false table variance_valid args
  · exact StandardMapReplaceValues.response table variance_valid declarations args

/-- 全八署名の純粋応答を、実行の応答の仮定へ渡す読者。 -/
theorem response_assumptions : builtins.ResponseAssumptions program := by
  refine ⟨?_,?_,?_,?_⟩
  · intro Ψ name sg ts es rs ws a e lookup pure args
    obtain ⟨out,delta,typed,adequate,noexit⟩ := concrete_response lookup args
    exact ⟨out,delta,noexit,typed,adequate⟩
  · intro Ψ name sg ts es rs ws a e out obs lookup kind args response
    cases response
  · intro Ψ name sg ts es rs ws a e out obs lookup args response
    cases response
  · intro Ψ name sg ts es rs ws a e lookup kind args
    obtain ⟨p,_,rfl,rfl⟩ := primitive_lookup lookup
    cases p <;> cases kind with
    | inl h => cases h
    | inr h => cases h

private def pairInput : Ty := .data "Pair" [.tvar 0,.tvar 1]
private def pairPattern (second : Bool) : Pat := .con "Pair.Pair"
  [if second then .wild else .var,if second then .var else .wild]
private def pairAlts (second : Bool) : List Alt := [⟨pairPattern second,[0]⟩]
private theorem pair_decl (second : Bool) : collectionPairProjection second =
    ⟨[TypeCtx.valueParam,TypeCtx.valueParam],0,["p"],[pairInput],.tvar (if second then 1 else 0),Eff.empty,
      .match (.var 0) [.mk (pairAlts second) none (.ret (.var 0))],[]⟩ := by cases second <;> rfl
private theorem pair_alts (second : Bool) : AltsTy program (pairAlts second) pairInput [.tvar (if second then 1 else 0)] := by
  cases second <;> refine ⟨by simp [pairAlts],rfl,?_,?_⟩
  all_goals first
    | (solve | intro alt h; cases Option.some.inj h; rfl)
    | (intro alt h; cases List.mem_singleton.mp h
       refine ⟨[_],.P_Con declarations.pair rfl ?_ ?_,by simp,rfl⟩
       · intro a ha; simp only [List.mem_cons,List.not_mem_nil,or_false] at ha
         rcases ha with rfl | rfl <;> simp [Ty.WF]
       · first | exact .cons .P_Var (.cons .P_Wild .nil) | exact .cons .P_Wild (.cons .P_Var .nil))
private theorem pair_exhaustive (second : Bool) : Exhaustive program pairInput [pairPattern second] := by
  intro v inhabitant
  have aux : ∀ t v, Inhabits program t v → t=pairInput.norm → (matchVal (pairPattern second) v).isSome := by
    intro t v h eq
    cases h <;> try (solve | cases eq)
    case const c => cases c <;> cases eq
    case atError => simp [pairInput,atErrorType,Ty.norm,Ty.normTys] at eq
    case con c ts tys args cd lookup ntys wf fields =>
      have hc := declarations.pairOnly c cd lookup (Ty.data.inj eq).1
      subst c
      cases Option.some.inj (lookup.symm.trans declarations.pair)
      cases fields with
      | cons x fields =>
        cases fields with
        | cons y fields =>
          cases fields
          cases second <;> rfl
  exact ⟨pairPattern second,by simp,aux _ _ inhabitant rfl⟩
private theorem pair_definition_typed (second : Bool) :
    (collectionPairProjection second).WellTyped program builtins := by
  have ar : ∃ n, program.DataArity "Pair" n ∧ 2=n := ⟨2,pair_arity,rfl⟩
  have ak := TyCon.arity_data pair_arity
  rw [pair_decl]
  cases second <;> refine ⟨?_,?_,?_,TelBodyTy.param (TelBodyTy.done ?_)⟩
  all_goals first
    | (solve | simp only [pairInput]; precision_simp)
    | (solve | constructor <;> (try simp only [pairInput]) <;> precision_simp)
    | (apply HasTypeCQ.C_Match (obs := none)
       · simp only [pairInput]; collection_var
       · intro t h; cases h
       · apply HasTypeArmsQ.plainEmpty (pair_alts _) (by simp [pathFacts,FactsWF])
         · exact .C_Return (by collection_var)
         · apply HasTypeArmsQ.nil; constructor <;> precision_simp
       · simp only [pairInput]; precision_simp
       · exact pair_exhaustive _)

/-- 同じ表に置く全十一の定義を、参照先も含めて検査する。 -/
theorem core_rows_typed : ∀ row ∈ coreRows, row.BodyTyped program builtins := by
  intro row member
  simp only [coreRows,API.all,List.map_cons,List.map_nil,List.mem_append,List.mem_cons,List.not_mem_nil,or_false] at member
  rcases member with (rfl | rfl | rfl | rfl | rfl | rfl | rfl) | (rfl | rfl | rfl | rfl)
  · exact StandardHeadTail.from_typed head_tail_inputs false
  · exact StandardHeadTail.from_typed head_tail_inputs true
  · exact StandardHeadTail.public_typed head_tail_inputs false
  · exact StandardHeadTail.public_typed head_tail_inputs true
  · exact StandardHeadTail.nonempty_public_typed head_tail_inputs rfl
  · exact ⟨_,rfl,pair_definition_typed false⟩
  · exact ⟨_,rfl,pair_definition_typed true⟩
  · exact concrete_typed .mapMap
  · exact concrete_typed .mapFilter
  · exact concrete_typed .setMap
  · exact concrete_typed .setFilter

/-- lookupした実定義の本体の型付けを返す。 -/
theorem definition_typed {name d} (lookup : program.defs name=some d) : d.WellTyped program builtins := by
  have member : (name,d) ∈ definitions := by
    obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp lookup
    rw [eq]
    exact List.mem_append_right _ List.mem_cons_self
  obtain ⟨row,hr,hd⟩ := List.mem_filterMap.mp member
  cases he : row.definition with
  | none => simp [he] at hd
  | some defn =>
    have eq : (row.name,defn)=(name,d) := Option.some.inj (by simpa only [he,Option.map_some] using hd)
    obtain ⟨_,rd,typed⟩ := core_rows_typed row hr
    cases Option.some.inj (he.symm.trans rd)
    cases congrArg Prod.snd eq
    exact typed

/-- 四つの精密公開行と参照先を同じProgram.WellTypedへ集める。 -/
theorem program_typed : program.WellTyped builtins := by
  refine ⟨variance_valid,⟨by simp [program,StandardCollectionModel.program],?_⟩,?_,?_⟩
  · intro key decl member; cases member
  · intro name d lookup; exact definition_typed lookup
  · intro i id lookup; cases lookup

end
end Benitoite.Release.Refinement.StandardCollectionRefinedBodies
