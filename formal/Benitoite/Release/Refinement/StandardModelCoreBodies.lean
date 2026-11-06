import Benitoite.Release.Refinement.StandardModelCollectionRows
import Benitoite.Release.Refinement.StandardModelListBodies

/-! # 合成表の上の通常のcore本体・getter・別名・Pairの射影

合成プログラムの同じ有限宣言と合成表の署名を、本体の型付けの環境（`StandardModel.BodyEnv`）から、元の本体の
証明が読む宣言・組込み・関数参照の条件として供給し、元の証明の構成で本体を検査する。精密な署名のMap.toListとSet.toListは、結果の篩を忘れて通常の関数型で読む。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
open StandardKeyTyping StandardOrdinaryCoreBodies StandardOrdinaryCoreProgram

/-! ## 合成プログラムの宣言 -/

/-- 合成プログラムの構成子の表の全行が同じデータ名に同じarityを持つなら、そのデータ名のarityが
定まる。 -/
theorem data_arity {externals} {c : String} {cd : ConDecl} (d : String) (n : Nat)
    (lookup : (program externals).cons c = some cd) (owner : cd.data = d)
    (all : (constructors.all fun e => e.2.data != d || e.2.ntys == n) = true) :
    (program externals).DataArity d n := by
  refine ⟨⟨c, cd, lookup, owner⟩, ?_⟩
  intro c' cd' h' owner'
  have entry := List.all_eq_true.mp all _ (cons_mem h')
  simp only [Bool.or_eq_true, bne_iff_ne, ne_eq, beq_iff_eq] at entry
  rcases entry with entry | entry
  · exact absurd owner' entry
  · exact entry

/-- 合成プログラムの構成子の表で、データ名 `d` を持つ構成子は `allowed` の名前に限る。 -/
theorem data_only {externals} (d : String) (allowed : List String)
    (all : (constructors.all fun e => e.2.data != d || allowed.contains e.1) = true)
    {c : String} {cd : ConDecl} (h : (program externals).cons c = some cd) (owner : cd.data = d) :
    c ∈ allowed := by
  have entry := List.all_eq_true.mp all _ (cons_mem h)
  simp only [Bool.or_eq_true, bne_iff_ne, ne_eq, List.contains_iff_mem] at entry
  rcases entry with entry | entry
  · exact absurd owner entry
  · exact entry

/-- 通常のcoreの本体が読む十一のデータ名のarity。 -/
theorem core_arity (externals : List (ExternalKey × ExternalDecl)) (d : DataId) :
    (program externals).DataArity d.owner d.count := by
  cases d
  all_goals first
    | exact data_arity _ _ (c := "Option.None") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Pair.Pair") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.Result.Result.Ok") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.Range.CheckedInteger") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.Range.CheckedLength") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.Range.CheckedIndex") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.NonEmptyList.NonEmptyList") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.Range.RangeError.InvalidBounds") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.Range.LengthError.InvalidBounds") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.Range.IndexError.OutOfBounds") rfl rfl (by decide)
    | exact data_arity _ _ (c := "Benitoite.NonEmptyList.EmptyListError.EmptyList") rfl rfl (by decide)

/-- 四つの記録型は同名の一つの構成子だけを持つ。 -/
theorem records (externals : List (ExternalKey × ExternalDecl)) :
    StandardOrdinaryCoreBodies.Records (program externals) := by
  refine ⟨fun r => by cases r <;> rfl, ?_⟩
  intro r c cd h owner
  exact List.mem_singleton.mp (data_only r.owner [r.owner] (by cases r <;> decide) h owner)

theorem sat_empty (externals : List (ExternalKey × ExternalDecl)) (C : List TParam) (a : Ty) :
    (builtins (program externals)).sat C a {} :=
  ModelConstraints.sat_unconstrained _ _ _

/-! ## 精密な署名のMap.toListとSet.toList -/

private def isToList : Prim → Bool
  | .mapFoldList | .mapForEachList | .setFoldList | .setForEachList => true
  | _ => false

private def toListMap : Prim → Bool
  | .mapFoldList | .mapForEachList => true
  | _ => false

local macro "model_simp" : tactic => `(tactic|
  simp_all [StandardCollectionPrecision.signature,StandardBodies.collectionPrimitiveSig,
    StandardCollectionPrecision.result,StandardCollectionPrecision.input,StandardCollectionPrecision.collection,
    StandardCollectionPrecision.element,StandardCollectionPrecision.predicate,StandardCollectionPrecision.size,
    StandardCollectionPrecision.length,Pred.Sorted,Pred.WF,Pred.VarsIn,Pred.Declared,Term.Declared,
    Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,Ty.NotContCore,
    Ty.HasSort,Ty.sort?,Measure.input,Measure.output,
    toListMap,Prim.context,Prim.name,Prim.args,Prim.names,Prim.inputs,Prim.result,API.context,
    StandardOrdinaryCoreProgram.keyParam,StandardOrdinaryCoreProgram.pair,DataId.owner,DataId.count,
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

section
variable {externals : List (ExternalKey × ExternalDecl)} {P : Program} {B : Builtins}

/-- 合成プログラムの宣言を同じ値で持つプログラムは、通常のcoreの本体が読む十一のデータ名のarityを持つ。 -/
theorem core_arity_of [env : BodyEnv externals P B] (d : DataId) : P.DataArity d.owner d.count :=
  env.extends_.dataArity (core_arity externals d)

theorem records_of [env : BodyEnv externals P B] : StandardOrdinaryCoreBodies.Records P :=
  ⟨fun r => env.extends_.cons _ _ ((records externals).decl r),
    fun r _ _ h owner => (records externals).only r
      (env.extends_.consData h owner (Or.inl ⟨_, _, (records externals).decl r, rfl⟩)) owner⟩

set_option maxHeartbeats 4000000 in
/-- 行の環境の表のMap.toListとSet.toListは精密な署名を持つ。その結果の篩を忘れると、通常のcoreの本体が
読む通常の関数型になる。 -/
private theorem toList_typed [env : BodyEnv externals P B] {Q Γ Φ} (p : Prim)
    (hp : isToList p = true) :
    HasTypeVQ P B StoreTy.empty Q p.context Γ Φ
      (.prim p.name p.args [] []) (.fn p.names p.inputs p.result Eff.empty) := by
  have arity := core_arity_of (externals := externals) (P := P) (B := B)
  have pairAr : ∃ n, P.DataArity "Pair" n ∧ 2 = n := ⟨2, arity .pair, rfl⟩
  have pairKind := TyCon.arity_data (arity .pair)
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext a; simp [mapRangeAtoms]
  have satKey : ∀ C, B.sat (TParam.keyC :: C) (.tvar 0) TParam.keyC := by
    intro C; rw [RowEnv.sat_eq (P := P)]; rfl
  have satEmpty : ∀ C a, B.sat C a {} := RowEnv.sat_empty (P := P)
  have hR : B.admitsR = signatureBase.admitsR := RowLookup.admitsR
  have lookup : B.sig p.name =
      some (StandardCollectionPrecision.signature B.sat (toListMap p) false) := by
    cases p <;> first | exact RowLookup.sig .p277 | exact RowLookup.sig .p292 | cases hp
  have range : B.RangeAdmissible p.name
      (StandardCollectionPrecision.signature B.sat (toListMap p) false) [] := by
    cases p <;> first | (cases hp; done) | model_simp
  have names : NamesWF (StandardCollectionPrecision.signature B.sat (toListMap p) false).names
      (StandardCollectionPrecision.signature B.sat (toListMap p) false).params := by
    cases p <;> first | (cases hp; done) | model_simp
  have admissible : PrimitiveAdmissible p.context Γ.length
      (StandardCollectionPrecision.signature B.sat (toListMap p) false) Q p.args [] := by
    cases p <;> first | (cases hp; done) | skip
    all_goals constructor
    all_goals first
      | (constructor <;> model_simp)
      | model_simp
    all_goals rintro (_|(_|i)) t c ht hc <;> model_simp
    all_goals subst_vars; first | exact satKey _ | exact satEmpty _ _
  have inst : SignatureInstance P p.context Γ
      (Tel.instR [] (StandardCollectionPrecision.signature B.sat (toListMap p) false).tel)
      (TypeCtx.kinds (StandardCollectionPrecision.signature B.sat (toListMap p) false).tparams)
      p.args [] := by
    cases p <;> first | (cases hp; done) | skip
    all_goals constructor
    all_goals first
      | (constructor <;> model_simp)
      | model_simp
      | (rintro (_|(_|i)) a k ha hk <;> model_simp <;> subst_vars <;> model_simp)
    all_goals first
      | (solve | constructor <;> (constructor <;> model_simp))
      | (solve | repeat constructor <;> model_simp)
      | (rintro (_|(_|i)) a k ha hk <;> model_simp <;> subst_vars <;> constructor <;> model_simp)
  have typed := HasTypeVQ.V_Prim (Ψ := StoreTy.empty) (Q := Q) (Φ := Φ) lookup range names admissible inst
  let ordinary : Tel := .param (p.names.headD "") (p.inputs.headD (.base .unit)) (.done p.result Eff.empty)
  have ann : Ty.Annotation P p.context Γ (.dependentFn ordinary) := by
    cases p <;> first | (cases hp; done) | skip
    all_goals constructor <;> simp only [ordinary] <;> model_simp
  have forget : HasTypeVQ P B StoreTy.empty Q p.context Γ Φ
      (.prim p.name p.args [] []) (.dependentFn ordinary) := by
    refine .V_Sub typed (.dependentFn (.tail .refl ?_)) ann.wf ann.sorted ann.declared
    cases p <;> first | (cases hp; done) | skip
    all_goals
      simp only [ordinary, Prim.names, Prim.inputs, Prim.result, List.headD]
      model_simp
      exact .param .refl (.done .forget (Eff.Covers.refl _ _ _))
  apply forget.convert
  · have fold := Ty.norm_toTel (ns := p.names) (ps := p.inputs) (r := p.result) (e := Eff.empty)
      (by cases p <;> model_simp)
    cases p <;> first | (cases hp; done) | skip
    all_goals
      simp only [ordinary, Prim.names, Prim.inputs, Prim.result, List.headD]
      simpa [FnView.toTel, Ty.toTel, Ty.shiftV, shiftVTys, Eff.shiftV, Eff.empty, Prim.names, Prim.inputs,
        Prim.result, StandardOrdinaryCoreProgram.pair] using fold
  · cases p <;> first | (cases hp; done) | skip
    all_goals constructor <;> model_simp

/-! ## 通常のcoreの十本 -/

private theorem core_prim [env : BodyEnv externals P B] (Q Γ Φ) (p : Prim) :
    HasTypeVQ P B StoreTy.empty Q p.context Γ Φ
      (.prim p.name p.args [] []) (.fn p.names p.inputs p.result Eff.empty) := by
  have arity := core_arity_of (externals := externals) (P := P) (B := B)
  cases p
  all_goals first
    | exact toList_typed (externals := externals) _ rfl
    | exact primitive_of arity .get ((get_signature_of (P := P)).trans rfl)
    | exact primitive_of arity _ (RowLookup.sig_eq (B := B) rfl rfl)

private theorem ref_lookup (externals : List (ExternalKey × ExternalDecl)) (r : Ref) (body : Body)
    (key : FunctionNames.rename false r.name = body.key)
    (same : body.definition = FunctionNames.definition (FunctionNames.rename false) r.source) :
    (program externals).defs (FunctionNames.rename false r.name) =
      some (FunctionNames.definition (FunctionNames.rename false) r.source) := by
  rw [key, body_lookup, same]

private theorem pair_original (second : Bool) :
    (if second then Body.b107 else Body.b106).original = pairDefinition second := by
  cases second <;> rfl

private theorem pair_definition (second : Bool) :
    (if second then Body.b107 else Body.b106).definition =
      FunctionNames.definition (FunctionNames.rename false) (pairDefinition second) := by
  have plain : ∀ ρ : String → String, FunctionNames.definition ρ (pairDefinition second) = pairDefinition second := by
    intro ρ; cases second <;> rfl
  rw [Body.correspondence, pair_original, plain, plain]

/-- 合成表のPairの二射影のlookupは、元のPairの射影の定義を返す。 -/
theorem pair_lookup (externals : List (ExternalKey × ExternalDecl)) (second : Bool) :
    (program externals).defs (if second then "Pair.second" else "Pair.first") = some (pairDefinition second) := by
  have plain : ∀ ρ : String → String, FunctionNames.definition ρ (pairDefinition second) = pairDefinition second := by
    intro ρ; cases second <;> rfl
  have lookup := body_lookup externals (if second then Body.b107 else Body.b106)
  rw [pair_definition, plain] at lookup
  cases second <;> exact lookup

private theorem pair_first : Body.b106.definition =
    FunctionNames.definition (FunctionNames.rename false) (pairDefinition false) := pair_definition false
private theorem pair_second : Body.b107.definition =
    FunctionNames.definition (FunctionNames.rename false) (pairDefinition true) := pair_definition true

private theorem core_ref [env : BodyEnv externals P B] (Q Γ Φ) (r : Ref) :
    HasTypeVQ P B StoreTy.empty Q r.context Γ Φ
      (.fnRef (FunctionNames.rename false r.name) r.args r.rows) (.fn r.names r.inputs r.result r.effect) := by
  refine reference_of (core_arity_of (externals := externals) (P := P) (B := B)) (RowEnv.sat_empty (P := P)) r
    (env.extends_.defs _ _ ?_)
  cases r
  case foldMap | foldSet => exact ref_lookup externals _ .b003 (by decide) rfl
  case eachMap | eachSet => exact ref_lookup externals _ .b004 (by decide) rfl
  case pairFirstFold | pairFirstEach => exact ref_lookup externals _ .b106 (by decide) pair_first
  case pairSecondFold | pairSecondEach => exact ref_lookup externals _ .b107 (by decide) pair_second
  case neFirstList | neFirstMap => exact ref_lookup externals _ .b127 (by decide) rfl
  case neRestList | neRestMap => exact ref_lookup externals _ .b128 (by decide) rfl
  case listMap => exact ref_lookup externals _ .b001 (by decide) rfl

/-- 本体の型付けの環境は、通常のcoreの本体が読む宣言・組込み・関数参照を、通常側の名前の写像で供給する。 -/
theorem core_context_of [env : BodyEnv externals P B] :
    StandardOrdinaryCoreProgram.Context P B (FunctionNames.rename false) :=
  ⟨core_arity_of (externals := externals) (P := P) (B := B), (fun c => env.extends_.cons _ _ (by cases c <;> rfl)), env.options,
    core_prim (externals := externals) (P := P) (B := B), core_ref (externals := externals) (P := P) (B := B)⟩

/-- 通常のcoreの十本（MapとSetのfold・forEach、範囲の三つの検査、非空の列の構成・列への変換・map）。 -/
theorem core_bodies_typed_of [BodyEnv externals P B] (a : StandardOrdinaryCoreProgram.API) :
    (FunctionNames.definition (FunctionNames.rename false) a.definition).WellTyped P B :=
  body_typed_of (core_context_of (externals := externals) (P := P) (B := B)) a

/-! ## 通常のListの高階関数・getter・射影・別名・安全な入口・Pairの射影 -/

private theorem list_inputs [env : BodyEnv externals P B] : StandardOrdinaryListBodies.Inputs P B :=
  ⟨env.options, (get_signature_of (P := P)).trans rfl, RowLookup.sig (B := B) .p036,
    (fun o => env.extends_.defs _ _ (by cases o <;> rfl)), RowEnv.sat_empty (P := P)⟩

theorem list_helpers_typed_of [BodyEnv externals P B] (o : StandardOrdinaryListBodies.Op) :
    o.definition.WellTyped P B ∧ o.publicDefinition.WellTyped P B :=
  ⟨StandardOrdinaryListBodies.helper_typed (list_inputs (externals := externals) (P := P) (B := B)) o,
    StandardOrdinaryListBodies.public_typed (list_inputs (externals := externals) (P := P) (B := B)) o⟩

theorem getters_typed_of [env : BodyEnv externals P B] (g : Getter) :
    g.definition.WellTyped P B ∧ g.publicDefinition.WellTyped P B :=
  ⟨getter_typed_of (records_of (externals := externals) (P := P) (B := B)) _ g,
    projection_typed_of (records_of (externals := externals) (P := P) (B := B)) (RowEnv.sat_empty (P := P)) g
      (env.extends_.defs _ _ (by cases g <;> rfl))⟩

theorem aliases_typed_of [BodyEnv externals P B] (api : StandardAliasBodies.API) :
    api.row.BodyTyped P B :=
  StandardAliasBodies.body_typed_of (core_arity_of (externals := externals) (P := P) (B := B) .option) api
    (by cases api <;> exact RowLookup.sig_eq (B := B) rfl rfl)

theorem pairs_typed_of [env : BodyEnv externals P B] (second : Bool) :
    (pairDefinition second).WellTyped P B :=
  pair_typed_of (env.extends_.cons _ _ rfl)
    (fun c cd h owner => List.mem_singleton.mp (data_only (externals := externals) "Pair" ["Pair.Pair"] (by decide)
      (env.extends_.consData h owner (Or.inl ⟨"Pair.Pair", _, rfl, rfl⟩)) owner))
    (core_arity_of (externals := externals) (P := P) (B := B) .pair) second

end

/-- 合成表は通常のcoreの本体が読む宣言・組込み・関数参照を、通常側の名前の写像で供給する。 -/
theorem core_context (externals : List (ExternalKey × ExternalDecl)) :
    StandardOrdinaryCoreProgram.Context (program externals) (builtins (program externals))
      (FunctionNames.rename false) :=
  core_context_of (externals := externals)

theorem core_bodies_typed (externals : List (ExternalKey × ExternalDecl)) (a : StandardOrdinaryCoreProgram.API) :
    (FunctionNames.definition (FunctionNames.rename false) a.definition).WellTyped
      (program externals) (builtins (program externals)) :=
  core_bodies_typed_of (externals := externals) a

theorem list_helpers_typed (externals : List (ExternalKey × ExternalDecl)) (o : StandardOrdinaryListBodies.Op) :
    o.definition.WellTyped (program externals) (builtins (program externals)) ∧
      o.publicDefinition.WellTyped (program externals) (builtins (program externals)) :=
  list_helpers_typed_of (externals := externals) o

theorem getters_typed (externals : List (ExternalKey × ExternalDecl)) (g : Getter) :
    g.definition.WellTyped (program externals) (builtins (program externals)) ∧
      g.publicDefinition.WellTyped (program externals) (builtins (program externals)) :=
  getters_typed_of (externals := externals) g

theorem aliases_typed (externals : List (ExternalKey × ExternalDecl)) (api : StandardAliasBodies.API) :
    api.row.BodyTyped (program externals) (builtins (program externals)) :=
  aliases_typed_of (externals := externals) api

theorem pairs_typed (externals : List (ExternalKey × ExternalDecl)) (second : Bool) :
    (pairDefinition second).WellTyped (program externals) (builtins (program externals)) :=
  pairs_typed_of (externals := externals) second

end
end Benitoite.Release.Refinement.StandardModel
