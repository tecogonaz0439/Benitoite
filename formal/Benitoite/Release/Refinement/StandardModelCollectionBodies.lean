import Benitoite.Release.Refinement.StandardModelCoreBodies

/-! # 合成表の名前で参照するMapとSetのmapとfilterの本体

通常側・精密側のMap・Setのmapとfilterは、同じ公開名に二つの元の定義を持つListのmap・filterを、
合成表の内部の名前で参照する。元の本体と関数参照の名前だけが異なる合成用の定義を、元の証明の
構成（StandardCollectionBodies・StandardCollectionRefinedBodies）で検査する。通常側は合成表の精密な
Map.toList・Map.fromList・Set.toList・Set.fromListから結果の篩を忘れて読む。 -/
namespace Benitoite.Release.Refinement.StandardModelRefinedCollection
noncomputable section
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
    (.letIn (.app (.fnRef (if filter then "%List.filter.refined" else "%List.map.refined")
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
private def collectionListDefinition := StandardModelPreciseList.publicDefinition
private theorem list_decl (filter : Bool) : collectionListDefinition filter =
    ⟨List.replicate (if filter then 1 else 2) TypeCtx.valueParam,1,["xs",if filter then "p" else "f"],
      [.list (.tvar 0),.fn ["value"] [.tvar 0] (if filter then .base .boolean else .tvar 1) (Eff.row 0)],
      .refined (.list (.tvar (if filter then 0 else 1)))
        (if filter then .le (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.length (.var 2))
         else .eq (StandardCollectionPrecision.length (.var 0)) (StandardCollectionPrecision.length (.var 2))),
      Eff.row 0,StandardModelPreciseList.publicBody filter⟩ := by cases filter <;> rfl

local macro "precision_simp" : tactic => `(tactic|
 ((try simp_all [list_decl,listTel,StandardCollectionPrecision.signature,StandardBodies.collectionPrimitiveSig,
   StandardCollectionPrecision.result,StandardCollectionPrecision.input,StandardCollectionPrecision.collection,
   StandardCollectionPrecision.element,StandardCollectionPrecision.predicate,StandardCollectionPrecision.size,
   StandardCollectionPrecision.length,Pred.Sorted,Pred.WF,Pred.VarsIn,Pred.Declared,Term.Declared,
   Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Tel.argumentsEnv,valEnv,Val.toTerm?,Pred.open,
   Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,
   predBind,termBind,termBind?,upValues]) <;> (try higher_simp)))
private theorem list_function {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (map filter : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (lookup : P.defs (if filter then "%List.filter.refined" else "%List.map.refined") = some (collectionListDefinition filter)) :
    HasTypeVQ P B StoreTy.empty Q (higherParams map filter) Γ Φ
      (.fnRef (if filter then "%List.filter.refined" else "%List.map.refined") (listArgs map filter) [Eff.row 0])
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
  have typed := HasTypeVQ.V_Fun (Ψ := StoreTy.empty) (Φ := Φ) lookup names ad inst
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

/-- 精密な署名の構築と射影の組込みは、結果の篩を忘れると通常の関数型を持つ。 -/
theorem primitive_ordinary {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (map filter build : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (lookup : B.sig (primitiveName map build) = some (collectionPrimitiveSig B.sat map build)) :
    HasTypeVQ P B StoreTy.empty Q (higherParams map filter) Γ Φ
      (.prim (primitiveName map build) (inputTypes map filter build) [] [])
      (.fn [if build then (if map then "pairs" else "xs") else (if map then "m" else "s")]
        [primitiveInput map filter build] (primitiveResult map filter build) Eff.empty) := by
  have pairAr : map = true → ∃ n, P.DataArity "Pair" n ∧ 2 = n := fun h => ⟨2,arity h,rfl⟩
  have typed := primitive_function (Γ := Γ) (Φ := Φ) (Q := Q) table map filter build arity lookup
  let tel : Tel := .param (if build then (if map then "pairs" else "xs") else (if map then "m" else "s"))
    (primitiveInput map filter build) (.done (primitiveResult map filter build) Eff.empty)
  have ann : Ty.Annotation P (higherParams map filter) Γ (.dependentFn tel) := by
    cases map <;> cases filter <;> cases build <;> constructor <;> simp only [tel] <;> precision_simp
  have forget : HasTypeVQ P B StoreTy.empty Q (higherParams map filter) Γ Φ
      (.prim (primitiveName map build) (inputTypes map filter build) [] []) (.dependentFn tel) :=
    .V_Sub typed (.dependentFn (.tail .refl (.param .refl (.done .forget (Eff.Covers.refl _ _ _)))))
      ann.wf ann.sorted ann.declared
  apply forget.convert
  · cases map <;> cases filter <;> cases build
    all_goals
      simp only [tel, primitiveInput, primitiveResult, outputType, outputElement, sourceType, pairType]
      first
        | simpa [Ty.toTel, Ty.shiftV, shiftVTys, Eff.shiftV, Eff.empty] using
            Ty.norm_toTel (ns := ["s"]) (ps := [.set (.tvar 0)]) (r := .list (.tvar 0)) (e := Eff.empty) (by simp [NamesWF])
        | simpa [Ty.toTel, Ty.shiftV, shiftVTys, Eff.shiftV, Eff.empty] using
            Ty.norm_toTel (ns := ["xs"]) (ps := [.list (.tvar 1)]) (r := .set (.tvar 1)) (e := Eff.empty) (by simp [NamesWF])
        | simpa [Ty.toTel, Ty.shiftV, shiftVTys, Eff.shiftV, Eff.empty] using
            Ty.norm_toTel (ns := ["xs"]) (ps := [.list (.tvar 0)]) (r := .set (.tvar 0)) (e := Eff.empty) (by simp [NamesWF])
        | simpa [Ty.toTel, Ty.shiftV, shiftVTys, Eff.shiftV, Eff.empty] using
            Ty.norm_toTel (ns := ["m"]) (ps := [.map (.tvar 0) (.tvar 1)]) (r := .list (.data "Pair" [.tvar 0,.tvar 1])) (e := Eff.empty) (by simp [NamesWF])
        | simpa [Ty.toTel, Ty.shiftV, shiftVTys, Eff.shiftV, Eff.empty] using
            Ty.norm_toTel (ns := ["pairs"]) (ps := [.list (.data "Pair" [.tvar 0,.tvar 2])]) (r := .map (.tvar 0) (.tvar 2)) (e := Eff.empty) (by simp [NamesWF])
        | simpa [Ty.toTel, Ty.shiftV, shiftVTys, Eff.shiftV, Eff.empty] using
            Ty.norm_toTel (ns := ["pairs"]) (ps := [.list (.data "Pair" [.tvar 0,.tvar 1])]) (r := .map (.tvar 0) (.tvar 1)) (e := Eff.empty) (by simp [NamesWF])
  · cases map <;> cases filter <;> cases build <;> constructor <;> precision_simp

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

/-- 四つの精密な公開本体の大きさを、合成表の名前の精密なList.map・List.filterを参照して検査する。 -/
theorem higher_typed {P B} (table : StandardKeyTyping.Table P B)
    (map filter : Bool) (arity : map=true → P.DataArity "Pair" 2)
    (pairDecl : map=true → P.cons "Pair.Pair"=some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
    (projections : map=true → ∀ second, P.defs (if second then "Pair.second" else "Pair.first") = some (collectionPairProjection second))
    (primitives : ∀ build, B.sig (primitiveName map build)=some (collectionPrimitiveSig B.sat map build))
    (replacement : B.sig "%Map.replaceValues"=some (StandardMapReplaceValues.signature B.sat))
    (lists : P.defs (if filter then "%List.filter.refined" else "%List.map.refined")=some (collectionListDefinition filter)) :
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


end
end Benitoite.Release.Refinement.StandardModelRefinedCollection

namespace Benitoite.Release.Refinement.StandardModelOrdinaryCollection
noncomputable section
set_option linter.unusedSimpArgs false

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

private def collectionHigherBody (map filter : Bool) : Comp :=
  .letIn (.app (.prim (if map then "Map.toList" else "Set.toList")
      (if map then [.tvar 0,.tvar 1] else [.tvar 0]) [] []) [.var 1])
    (.letIn (.app (.fnRef (if filter then "%List.filter.ordinary" else "%List.map.ordinary")
      (if map then (if filter then [pairType 1] else [pairType 1,pairType 2])
        else (if filter then [.tvar 0] else [.tvar 0,.tvar 1])) [Eff.row 0])
      [.var 0,if map then .lam ["value"] [pairType 1] (StandardBodies.mapCallbackBody filter) else .var 1])
      (.app (.prim (if map then "Map.fromList" else "Set.fromList")
        (if map then [.tvar 0,outputElement map filter] else [outputElement map filter]) [] []) [.var 0]))

private def collectionHigherRow (map filter : Bool) : StandardContracts.Row :=
  ⟨(if map then "Map." else "Set.") ++ (if filter then "filter" else "map"),
    higherParams map filter,1,higherTel map filter,some (collectionHigherBody map filter),.core,
    [if map then .mapHigherOrder else .setUpdate]⟩

local macro "collection_simp" : tactic => `(tactic|
  simp_all [keyParam,higherParams,pairType,sourceType,outputElement,outputType,higherCallback,higherTel,
    StandardBodies.collectionPrimitiveSig,collectionHigherRow,StandardBodies.collectionPairProjection,StandardBodies.listHigherRow,
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
  if map then (if filter then [pairType 1] else [pairType 1,pairType 2])
  else (if filter then [.tvar 0] else [.tvar 0,.tvar 1])
private def listElement (map : Bool) : Ty := if map then pairType 1 else .tvar 0
private def listOutput (map filter : Bool) : Ty :=
  if map then (if filter then pairType 1 else pairType 2) else outputElement map filter
private def listCallback (map filter : Bool) : Ty :=
  .fn ["value"] [listElement map] (if filter then .base .boolean else listOutput map filter) (Eff.row 0)

local macro "higher_simp" : tactic => `(tactic|
  ((try simp_all [StandardBodies.collectionListDefinition,listArgs,listElement,listOutput,listCallback,
    inputTypes,primitiveName,primitiveInput,primitiveResult,FnView.toTel,Ty.toTel]) <;> (try collection_simp)))

set_option maxHeartbeats 2000000 in
private theorem list_function {P B Γ Φ Q} (table : StandardKeyTyping.Table P B)
    (map filter : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (body : Comp) (lookup : P.defs (if filter then "%List.filter.ordinary" else "%List.map.ordinary") =
      some {StandardBodies.collectionListDefinition filter with body := body}) :
    HasTypeVQ P B StoreTy.empty Q (higherParams map filter) Γ Φ
      (.fnRef (if filter then "%List.filter.ordinary" else "%List.map.ordinary") (listArgs map filter) [Eff.row 0])
      (.fn ["xs",if filter then "p" else "f"] [.list (listElement map),listCallback map filter]
        (.list (listOutput map filter)) (Eff.row 0)) := by
  have ar : map = true → ∃ n, P.DataArity "Pair" n ∧ 2 = n := fun h => ⟨2,arity h,rfl⟩
  have pairKind : map = true → TyCon.arity P (.data "Pair") = some 2 := fun h => TyCon.arity_data (arity h)
  have selfrow := row_self
  simp only [Eff.row,Eff.atoms] at selfrow
  have names : NamesWF (StandardBodies.collectionListDefinition filter).names (StandardBodies.collectionListDefinition filter).params := by
    clear lookup
    cases filter <;> higher_simp
  have ad : Admissible B (higherParams map filter) Γ.length
      (TypeCtx.constraints (StandardBodies.collectionListDefinition filter).tparams) 1
      (Qsig (StandardBodies.collectionListDefinition filter).params (StandardBodies.collectionListDefinition filter).ret (StandardBodies.collectionListDefinition filter).eff)
      Q (listArgs map filter) [Eff.row 0] (StandardBodies.collectionListDefinition filter).eff := by
    clear lookup
    cases map <;> cases filter <;> constructor
    all_goals first | (constructor <;> higher_simp) | higher_simp
    all_goals rintro (_|(_|i)) t p ht hp <;> higher_simp
    all_goals subst_vars; exact sat_empty table _ _
  have inst : SignatureInstance P (higherParams map filter) Γ (StandardBodies.collectionListDefinition filter).tel
      (TypeCtx.kinds (StandardBodies.collectionListDefinition filter).tparams) (listArgs map filter) [Eff.row 0] := by
    clear lookup
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
  have typed := HasTypeVQ.V_Fun (Ψ := StoreTy.empty) (Φ := Φ) lookup names ad inst
  clear lookup
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

private theorem lift_pure {P B Ψ Q C Γ Φ R m a Δ} (ann : Ty.Annotation P C Γ a)
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a Eff.empty Δ) :
    HasTypeCQ P B Ψ Q C Γ Φ R m a (Eff.row 0) Δ := by
  apply HasTypeCQ.C_Sub typed .refl _ ann.wf ann.sorted ann.declared
  constructor
  · intro a h; simp [Eff.mem,Eff.empty,Eff.test,Eff.atoms] at h
  · intro t h; simp [Eff.memFail,Eff.empty,Eff.fails] at h

local macro "collection_var" : tactic => `(tactic|
  (refine HasTypeVQ.V_Var rfl ?_; intro b t e; higher_simp))

/-- 通常側の四本の本体は、合成表の名前のList.map・List.filterと、精密な署名から結果の篩を忘れた
構築・射影の組込みで型付く。 -/
theorem higher_typed {P B} (table : StandardKeyTyping.Table P B)
    (map filter : Bool) (arity : map = true → P.DataArity "Pair" 2)
    (pairDecl : map = true → P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
    (projections : map = true → ∀ second, P.defs (if second then "Pair.second" else "Pair.first") = some (StandardBodies.collectionPairProjection second))
    (primitives : ∀ build, B.sig (primitiveName map build) = some (StandardCollectionPrecision.signature B.sat map build))
    (body : Comp) (lists : P.defs (if filter then "%List.filter.ordinary" else "%List.map.ordinary") =
      some {StandardBodies.collectionListDefinition filter with body := body}) :
    (collectionHigherRow map filter).BodyTyped P B := by
  have ar : map = true → ∃ n, P.DataArity "Pair" n ∧ 2 = n := fun h => ⟨2,arity h,rfl⟩
  have pairKind : map = true → TyCon.arity P (.data "Pair") = some 2 := fun h => TyCon.arity_data (arity h)
  have prim : ∀ Γ Φ build, HasTypeVQ P B StoreTy.empty (QTel (higherTel map filter)) (higherParams map filter) Γ Φ
      (.prim (primitiveName map build) (inputTypes map filter build) [] [])
      (.fn [if build then (if map then "pairs" else "xs") else (if map then "m" else "s")]
        [primitiveInput map filter build] (primitiveResult map filter build) Eff.empty) :=
    fun Γ Φ build => StandardModelRefinedCollection.primitive_ordinary (Γ := Γ) (Φ := Φ)
      (Q := QTel (higherTel map filter)) table map filter build arity (primitives build)
  have listFn := fun Γ Φ => list_function (Γ := Γ) (Φ := Φ)
    (Q := QTel (higherTel map filter)) table map filter arity body lists
  clear lists primitives
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
        · exact StandardBodies.map_wrapper table filter (arity rfl) (pairDecl rfl) (projections rfl) (by cases filter <;> rfl)
      · apply lift_pure (by cases map <;> cases filter <;> constructor <;> higher_simp)
        cases map <;> cases filter
        all_goals exact .C_App (prim _ _ true) (.cons (by collection_var) .nil)
      · cases map <;> cases filter <;> higher_simp
    · cases map <;> cases filter <;> higher_simp

end
end Benitoite.Release.Refinement.StandardModelOrdinaryCollection

namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

private theorem pair_projection (externals : List (ExternalKey × ExternalDecl)) (second : Bool) :
    (program externals).defs (if second then "Pair.second" else "Pair.first") =
      some (StandardBodies.collectionPairProjection second) := by
  rw [pair_lookup]
  cases second <;> rfl

section
variable {externals : List (ExternalKey × ExternalDecl)} {P : Program} {B : Builtins}

/-- 精密なMapとSetのmap・filterの四本は、本体の型付けの環境で型付く。 -/
theorem refined_collection_typed_of [env : BodyEnv externals P B] (map filter : Bool) :
    (if map then (if filter then Body.b109 else Body.b108) else (if filter then Body.b111 else Body.b110)).definition.WellTyped
      P B := by
  obtain ⟨d, hd, ht⟩ := StandardModelRefinedCollection.higher_typed env.keys map filter
    (fun _ => core_arity_of (externals := externals) (P := P) (B := B) .pair) (fun _ => env.extends_.cons _ _ rfl)
    (fun _ second => env.extends_.defs _ _ (pair_projection externals second))
    (by
      intro build
      cases map <;> cases build
      · exact RowLookup.sig_with .p292 rfl rfl
      · exact RowLookup.sig_with .p288 rfl rfl
      · exact RowLookup.sig_with .p277 rfl rfl
      · exact RowLookup.sig_with .p271 rfl rfl)
    (RowLookup.sig_with .p076 rfl rfl) (env.extends_.defs _ _ (by cases filter <;> rfl))
  cases map <;> cases filter <;> cases Option.some.inj (hd.symm.trans rfl) <;> exact ht

/-- 通常側のMapとSetのmap・filterの四本は、本体の型付けの環境で型付く。 -/
theorem ordinary_collection_typed_of [env : BodyEnv externals P B] (map filter : Bool) :
    (if map then (if filter then Body.b009 else Body.b008) else (if filter then Body.b013 else Body.b012)).definition.WellTyped
      P B := by
  obtain ⟨d, hd, ht⟩ := StandardModelOrdinaryCollection.higher_typed env.keys map filter
    (fun _ => core_arity_of (externals := externals) (P := P) (B := B) .pair) (fun _ => env.extends_.cons _ _ rfl)
    (fun _ second => env.extends_.defs _ _ (pair_projection externals second))
    (by
      intro build
      cases map <;> cases build
      · exact RowLookup.sig_with .p292 rfl rfl
      · exact RowLookup.sig_with .p288 rfl rfl
      · exact RowLookup.sig_with .p277 rfl rfl
      · exact RowLookup.sig_with .p271 rfl rfl)
    (if filter then Body.b002 else Body.b001).definition.body
    (env.extends_.defs _ _ (by cases filter <;> rfl))
  cases map <;> cases filter <;> cases Option.some.inj (hd.symm.trans rfl) <;> exact ht

end

/-- 精密なMapとSetのmap・filterの四本は、任意の外部宣言の合成表で型付く。 -/
theorem refined_collection_typed (externals : List (ExternalKey × ExternalDecl)) (map filter : Bool) :
    (if map then (if filter then Body.b109 else Body.b108) else (if filter then Body.b111 else Body.b110)).definition.WellTyped
      (program externals) (builtins (program externals)) :=
  refined_collection_typed_of (externals := externals) map filter

/-- 通常側のMapとSetのmap・filterの四本は、任意の外部宣言の合成表で型付く。 -/
theorem ordinary_collection_typed (externals : List (ExternalKey × ExternalDecl)) (map filter : Bool) :
    (if map then (if filter then Body.b009 else Body.b008) else (if filter then Body.b013 else Body.b012)).definition.WellTyped
      (program externals) (builtins (program externals)) :=
  ordinary_collection_typed_of (externals := externals) map filter

end
end Benitoite.Release.Refinement.StandardModel
