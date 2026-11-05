import Benitoite.Release.Refinement.StandardModelCoreRows
import Benitoite.Release.Refinement.StandardModelCoreBodies
import Benitoite.Release.Refinement.StandardModelPureInputs

/-! # 合成表の全署名の形成

合成表の377行の署名は、合成プログラムの同じ宣言の上で `PrimSig.Scoped` を満たす。出典の表の族ごとに、
全ての構成子の署名を検査し、行の振り分けで各行をその族の署名へ対応させる。範囲付きのパス・要求の
行とIOの行は、ModelTargets・ModelHttpの既存の形成の補題を同じ宣言で読む。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
set_option linter.unusedSimpArgs false

/-- 署名が読むデータ名のarityと、その型の構成子の種類。 -/
theorem arities (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).DataArity "Option" 1 ∧ TyCon.arity (program externals) (.data "Option") = some 1 ∧
    (program externals).DataArity "Result" 2 ∧ TyCon.arity (program externals) (.data "Result") = some 2 ∧
    (program externals).DataArity "Scope.ScopeError" 0 ∧
      TyCon.arity (program externals) (.data "Scope.ScopeError") = some 0 ∧
    (program externals).DataArity "Pair" 2 ∧ TyCon.arity (program externals) (.data "Pair") = some 2 ∧
    (program externals).DataArity "Http.ClientRequest" 0 ∧
      TyCon.arity (program externals) (.data "Http.ClientRequest") = some 0 ∧
    (program externals).DataArity "Http.RequestCheckError" 0 ∧
      TyCon.arity (program externals) (.data "Http.RequestCheckError") = some 0 ∧
    (program externals).DataArity "RoundingMode" 0 ∧
      TyCon.arity (program externals) (.data "RoundingMode") = some 0 ∧
    (program externals).DataArity "ByteOrder" 0 ∧
      TyCon.arity (program externals) (.data "ByteOrder") = some 0 := by
  have o := data_arity (externals := externals) "Option" 1 (c := "Option.None") rfl rfl (by decide)
  have r := data_arity (externals := externals) "Result" 2 (c := "Result.Ok") rfl rfl (by decide)
  have s := data_arity (externals := externals) "Scope.ScopeError" 0 (c := "Scope.ScopeError.InvalidPattern") rfl rfl
    (by decide)
  have p := data_arity (externals := externals) "Pair" 2 (c := "Pair.Pair") rfl rfl (by decide)
  have c := data_arity (externals := externals) "Http.ClientRequest" 0 (c := "Http.ClientRequest") rfl rfl
    (by decide)
  have e := data_arity (externals := externals) "Http.RequestCheckError" 0
    (c := "Http.RequestCheckError.InvalidUrl") rfl rfl (by decide)
  have m := data_arity (externals := externals) "RoundingMode" 0 (c := "RoundingMode.HalfToEven") rfl rfl
    (by decide)
  have b := data_arity (externals := externals) "ByteOrder" 0 (c := "ByteOrder.BigEndian") rfl rfl (by decide)
  exact ⟨o, TyCon.arity_data o, r, TyCon.arity_data r, s, TyCon.arity_data s, p, TyCon.arity_data p,
    c, TyCon.arity_data c, e, TyCon.arity_data e, m, TyCon.arity_data m, b, TyCon.arity_data b⟩

theorem scoped_structural (externals : List (ExternalKey × ExternalDecl))  :
    PrimSig.Scoped (program externals) (StandardEqualityResponse.fullSignature signatureBase.sat) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  skip <;> constructor <;> simp_all [StandardEqualityResponse.fullSignature,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_decimal (externals : List (ExternalKey × ExternalDecl)) (api : StandardDecimalResponse.API) :
    PrimSig.Scoped (program externals) (api.signature) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases api <;> constructor <;> simp_all [StandardDecimalResponse.API.signature,StandardDecimalResponse.API.names,StandardDecimalResponse.API.inputs,StandardDecimalResponse.API.result,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_replaceValues (externals : List (ExternalKey × ExternalDecl))  :
    PrimSig.Scoped (program externals) (StandardMapReplaceValues.signature signatureBase.sat) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  skip <;> constructor <;> simp_all [StandardMapReplaceValues.signature,StandardMapReplaceValues.size,StandardMapReplaceValues.length,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_bytesOrdinary (externals : List (ExternalKey × ExternalDecl)) (api : StandardBytesOrdinaryResponse.API) :
    PrimSig.Scoped (program externals) (api.signature) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases api <;> constructor <;> simp_all [StandardBytesOrdinaryResponse.API.signature,StandardBytesOrdinaryResponse.API.names,StandardBytesOrdinaryResponse.API.inputs,StandardBytesOrdinaryResponse.API.resultKind,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_bytes (externals : List (ExternalKey × ExternalDecl)) (api : StandardBytesResponse.API) :
    PrimSig.Scoped (program externals) (api.signature) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases api <;> constructor <;> simp_all [StandardBytesResponse.API.signature,StandardBytesResponse.API.names,StandardBytesResponse.API.inputs,StandardBytesResponse.API.result,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_append (externals : List (ExternalKey × ExternalDecl))  :
    PrimSig.Scoped (program externals) (StandardHeadTail.appendSignature) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  skip <;> constructor <;> simp_all [StandardHeadTail.appendSignature,StandardHeadTail.appendPredicate,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_list (externals : List (ExternalKey × ExternalDecl)) (api : StandardListResponse.API) :
    PrimSig.Scoped (program externals) (api.signature) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases api <;> constructor <;> simp_all [StandardListResponse.API.signature,StandardListResponse.API.names,StandardListResponse.API.inputs,StandardListResponse.API.result,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_listRemaining (externals : List (ExternalKey × ExternalDecl)) (api : StandardListRemainingResponse.API) :
    PrimSig.Scoped (program externals) (StandardListRemainingResponse.API.signature signatureBase.sat api) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases api <;> constructor <;> simp_all [StandardListRemainingResponse.API.signature,StandardListRemainingResponse.API.names,StandardListRemainingResponse.API.inputs,StandardListRemainingResponse.API.result,StandardListRemainingResponse.API.constraint,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_headTail (externals : List (ExternalKey × ExternalDecl)) (tail : Bool) :
    PrimSig.Scoped (program externals) (if tail then StandardHeadTail.tailSignature else StandardHeadTail.headSignature) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases tail <;> constructor <;> simp_all [StandardHeadTail.headSignature,StandardHeadTail.tailSignature,StandardHeadTail.headPredicate,StandardHeadTail.tailPredicate,StandardHeadTail.someField,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]
  case false.declared => exact ⟨"Option", ⟨_, Term.HasData.var rfl rfl⟩, ⟨_, rfl, rfl⟩⟩
  case true.declared =>
    refine ⟨⟨"Option", ⟨_, Term.HasData.var rfl rfl⟩, ⟨_, rfl, rfl⟩⟩,
      ⟨"Option", ⟨_, Term.HasData.var rfl rfl⟩, ⟨_, rfl, rfl⟩⟩, ?_⟩
    refine ⟨_, _, _, Term.HasData.var (by rfl) (by rfl), by rfl, rfl, by rfl, by rfl, ?_, ?_⟩
    · simp [Ty.WF]
    · rfl

theorem scoped_range (externals : List (ExternalKey × ExternalDecl))  :
    PrimSig.Scoped (program externals) (StandardListRemainingResponse.rangeSignature) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  skip <;> constructor <;> simp_all [StandardListRemainingResponse.rangeSignature,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_map (externals : List (ExternalKey × ExternalDecl)) (api : StandardCollections.MapAPI) :
    PrimSig.Scoped (program externals) (StandardCollections.MapAPI.signature signatureBase.sat api) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases api <;> constructor <;> simp_all [StandardCollections.MapAPI.signature,StandardCollections.MapAPI.names,StandardCollections.MapAPI.inputs,StandardCollections.MapAPI.result,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_precision (externals : List (ExternalKey × ExternalDecl)) (map build : Bool) :
    PrimSig.Scoped (program externals) (StandardCollectionPrecision.signature signatureBase.sat map build) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases map <;> cases build <;> constructor <;> simp_all [StandardCollectionPrecision.signature,StandardBodies.collectionPrimitiveSig,StandardCollectionPrecision.result,StandardCollectionPrecision.input,StandardCollectionPrecision.collection,StandardCollectionPrecision.element,StandardCollectionPrecision.predicate,StandardCollectionPrecision.size,StandardCollectionPrecision.length,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_set (externals : List (ExternalKey × ExternalDecl)) (api : StandardCollections.SetAPI) :
    PrimSig.Scoped (program externals) (StandardCollections.SetAPI.signature signatureBase.sat api) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases api <;> constructor <;> simp_all [StandardCollections.SetAPI.signature,StandardCollections.SetAPI.names,StandardCollections.SetAPI.inputs,StandardCollections.SetAPI.result,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_string (externals : List (ExternalKey × ExternalDecl)) (api : StandardStringOrdinaryResponse.API) :
    PrimSig.Scoped (program externals) (api.signature) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  cases api <;> constructor <;> simp_all [StandardStringOrdinaryResponse.API.signature,StandardStringOrdinaryResponse.API.names,StandardStringOrdinaryResponse.API.inputs,StandardStringOrdinaryResponse.API.resultKind,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_unary (externals : List (ExternalKey × ExternalDecl)) (n : String) (i o : BaseTy) :
    PrimSig.Scoped (program externals) (unarySig n i o) := by
  constructor <;> simp [unarySig,PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_binary (externals : List (ExternalKey × ExternalDecl)) (n m : String) (i j o : BaseTy)
    (names : n ≠ m) : PrimSig.Scoped (program externals) (binarySig n m i j o) := by
  constructor <;> simp [binarySig,names,PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

theorem scoped_option (externals : List (ExternalKey × ExternalDecl)) (n : String) (i o : BaseTy) :
    PrimSig.Scoped (program externals) (optionSig n i o) := by
  obtain ⟨o1, o2, r1, r2, s1, s2, p1, p2, c1, c2, e1, e2, m1, m2, b1, b2⟩ := arities externals
  constructor <;> simp_all [optionSig,PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,atErrorType,Pred.Sorted,Pred.WF,Pred.VarsIn,
      Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,Term.VarsIn,Ctx.Readable,Ctx.declarationSelf,
      Ty.NotContCore,Ty.HasSort,Ty.sort?,Measure.input,Measure.output,Ctx.extend,Ordinary,Ty.core,
      ScopedIOResponse.ResultKind.type,Tel.argumentsEnv,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
      Pred.conjuncts,Pred.ofConjuncts,StandardPureResults.Kind.type,embedTy,embedTys,Benitoite.Interval.IntKind.type,
      StandardOperatorArguments.signature,StandardFloatMathResponse.base,
      Ty.shiftV,shiftVTys,Eff.shiftV,Tel.shiftV,StandardHeadTail.length,StandardCollectionPrecision.length,
      StandardCollectionPrecision.size,Eff.row]

private theorem targets_scoped (externals : List (ExternalKey × ExternalDecl)) {b s}
    (lookup : ModelTargets.builtins.sig b = some s) : PrimSig.Scoped (program externals) s :=
  ModelTargets.sig_scoped (http_declarations externals).file lookup

private theorem http_scoped (externals : List (ExternalKey × ExternalDecl)) {b s}
    (lookup : ModelHttp.builtins.sig b = some s) : PrimSig.Scoped (program externals) s :=
  ModelHttp.sig_scoped (http_declarations externals) lookup

theorem scoped_store (externals : List (ExternalKey × ExternalDecl)) :
    PrimSig.Scoped (program externals) refNewSig ∧ PrimSig.Scoped (program externals) refUpdateSig ∧
      PrimSig.Scoped (program externals) forceSig ∧ PrimSig.Scoped (program externals) StandardSafe.frontSig := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;> constructor <;> simp_all [refNewSig, refUpdateSig, forceSig, StandardSafe.frontSig,
      PrimSig.tel,signatureTel,NamesWF,Ty.SourceScoped,Eff.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
      Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
      Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,Ty.HasKind,kindsTel,kindsList,kindsEff,
      TypeCtx.kinds,TypeCtx.valueParam,Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,Tel.Declared,Ty.Declared,declaredTys,
      declaredEff,PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,Ordinary,Ty.core]

/-- 合成表の全lookupの署名は、同じ合成プログラムの上で形成される。 -/
theorem sig_scoped (externals : List (ExternalKey × ExternalDecl)) :
    ∀ b s, (builtins (program externals)).sig b = some s → PrimSig.Scoped (program externals) s := by
  intro b s lookup
  obtain ⟨row, _, rfl, rfl⟩ := (builtins_lookup_iff _ b s).mp lookup
  have store := scoped_store externals
  cases row
  case p001 => exact scoped_binary externals "left" "right" .byte .byte .boolean (by decide)
  case p002 => exact scoped_binary externals "left" "right" .byte .byte .boolean (by decide)
  case p003 => exact scoped_binary externals "left" "right" .byte .byte .boolean (by decide)
  case p004 => exact scoped_binary externals "left" "right" .byte .byte .boolean (by decide)
  case p005 => exact scoped_binary externals "left" "right" .character .character .boolean (by decide)
  case p006 => exact scoped_binary externals "left" "right" .character .character .boolean (by decide)
  case p007 => exact scoped_binary externals "left" "right" .character .character .boolean (by decide)
  case p008 => exact scoped_binary externals "left" "right" .character .character .boolean (by decide)
  case p009 => exact scoped_binary externals "left" "right" .decimal .decimal .decimal (by decide)
  case p010 => exact scoped_binary externals "left" "right" .decimal .decimal .decimal (by decide)
  case p011 => exact scoped_binary externals "left" "right" .decimal .decimal .boolean (by decide)
  case p012 => exact scoped_binary externals "left" "right" .decimal .decimal .boolean (by decide)
  case p013 => exact scoped_binary externals "left" "right" .decimal .decimal .boolean (by decide)
  case p014 => exact scoped_binary externals "left" "right" .decimal .decimal .boolean (by decide)
  case p015 => exact scoped_binary externals "left" "right" .decimal .decimal .decimal (by decide)
  case p016 => exact scoped_unary externals "value" .decimal .decimal
  case p017 => exact scoped_binary externals "left" "right" .decimal .decimal .decimal (by decide)
  case p018 => exact scoped_binary externals "left" "right" .float .float .float (by decide)
  case p019 => exact scoped_binary externals "left" "right" .float .float .float (by decide)
  case p020 => exact scoped_binary externals "left" "right" .float .float .boolean (by decide)
  case p021 => exact scoped_binary externals "left" "right" .float .float .boolean (by decide)
  case p022 => exact scoped_binary externals "left" "right" .float .float .boolean (by decide)
  case p023 => exact scoped_binary externals "left" "right" .float .float .boolean (by decide)
  case p024 => exact scoped_binary externals "left" "right" .float .float .float (by decide)
  case p025 => exact scoped_unary externals "value" .float .float
  case p026 => exact scoped_binary externals "left" "right" .float .float .float (by decide)
  case p027 => exact scoped_binary externals "left" "right" .float32 .float32 .float32 (by decide)
  case p028 => exact scoped_binary externals "left" "right" .float32 .float32 .float32 (by decide)
  case p029 => exact scoped_binary externals "left" "right" .float32 .float32 .boolean (by decide)
  case p030 => exact scoped_binary externals "left" "right" .float32 .float32 .boolean (by decide)
  case p031 => exact scoped_binary externals "left" "right" .float32 .float32 .boolean (by decide)
  case p032 => exact scoped_binary externals "left" "right" .float32 .float32 .boolean (by decide)
  case p033 => exact scoped_binary externals "left" "right" .float32 .float32 .float32 (by decide)
  case p034 => exact scoped_unary externals "value" .float32 .float32
  case p035 => exact scoped_binary externals "left" "right" .float32 .float32 .float32 (by decide)
  case p036 => exact scoped_binary externals "left" "right" .integer .integer .integer (by decide)
  case p037 => exact scoped_binary externals "left" "right" .integer .integer .integer (by decide)
  case p038 => exact scoped_binary externals "left" "right" .integer .integer .boolean (by decide)
  case p039 => exact scoped_binary externals "left" "right" .integer .integer .boolean (by decide)
  case p040 => exact scoped_binary externals "left" "right" .integer .integer .boolean (by decide)
  case p041 => exact scoped_binary externals "left" "right" .integer .integer .boolean (by decide)
  case p042 => exact scoped_binary externals "left" "right" .integer .integer .integer (by decide)
  case p043 => exact scoped_binary externals "left" "right" .integer .integer .integer (by decide)
  case p044 => exact scoped_unary externals "value" .integer .integer
  case p045 => exact scoped_binary externals "left" "right" .integer .integer .integer (by decide)
  case p046 => exact scoped_binary externals "left" "right" .integer16 .integer16 .integer16 (by decide)
  case p047 => exact scoped_binary externals "left" "right" .integer16 .integer16 .integer16 (by decide)
  case p048 => exact scoped_binary externals "left" "right" .integer16 .integer16 .boolean (by decide)
  case p049 => exact scoped_binary externals "left" "right" .integer16 .integer16 .boolean (by decide)
  case p050 => exact scoped_binary externals "left" "right" .integer16 .integer16 .boolean (by decide)
  case p051 => exact scoped_binary externals "left" "right" .integer16 .integer16 .boolean (by decide)
  case p052 => exact scoped_binary externals "left" "right" .integer16 .integer16 .integer16 (by decide)
  case p053 => exact scoped_binary externals "left" "right" .integer16 .integer16 .integer16 (by decide)
  case p054 => exact scoped_unary externals "value" .integer16 .integer16
  case p055 => exact scoped_binary externals "left" "right" .integer16 .integer16 .integer16 (by decide)
  case p056 => exact scoped_binary externals "left" "right" .integer32 .integer32 .integer32 (by decide)
  case p057 => exact scoped_binary externals "left" "right" .integer32 .integer32 .integer32 (by decide)
  case p058 => exact scoped_binary externals "left" "right" .integer32 .integer32 .boolean (by decide)
  case p059 => exact scoped_binary externals "left" "right" .integer32 .integer32 .boolean (by decide)
  case p060 => exact scoped_binary externals "left" "right" .integer32 .integer32 .boolean (by decide)
  case p061 => exact scoped_binary externals "left" "right" .integer32 .integer32 .boolean (by decide)
  case p062 => exact scoped_binary externals "left" "right" .integer32 .integer32 .integer32 (by decide)
  case p063 => exact scoped_binary externals "left" "right" .integer32 .integer32 .integer32 (by decide)
  case p064 => exact scoped_unary externals "value" .integer32 .integer32
  case p065 => exact scoped_binary externals "left" "right" .integer32 .integer32 .integer32 (by decide)
  case p066 => exact scoped_binary externals "left" "right" .integer8 .integer8 .integer8 (by decide)
  case p067 => exact scoped_binary externals "left" "right" .integer8 .integer8 .integer8 (by decide)
  case p068 => exact scoped_binary externals "left" "right" .integer8 .integer8 .boolean (by decide)
  case p069 => exact scoped_binary externals "left" "right" .integer8 .integer8 .boolean (by decide)
  case p070 => exact scoped_binary externals "left" "right" .integer8 .integer8 .boolean (by decide)
  case p071 => exact scoped_binary externals "left" "right" .integer8 .integer8 .boolean (by decide)
  case p072 => exact scoped_binary externals "left" "right" .integer8 .integer8 .integer8 (by decide)
  case p073 => exact scoped_binary externals "left" "right" .integer8 .integer8 .integer8 (by decide)
  case p074 => exact scoped_unary externals "value" .integer8 .integer8
  case p075 => exact scoped_binary externals "left" "right" .integer8 .integer8 .integer8 (by decide)
  case p076 => exact scoped_replaceValues externals
  case p077 => exact scoped_binary externals "left" "right" .string .string .string (by decide)
  case p078 => exact scoped_binary externals "left" "right" .string .string .boolean (by decide)
  case p079 => exact scoped_binary externals "left" "right" .string .string .boolean (by decide)
  case p080 => exact scoped_binary externals "left" "right" .string .string .boolean (by decide)
  case p081 => exact scoped_binary externals "left" "right" .string .string .boolean (by decide)
  case p082 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p083 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p084 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean (by decide)
  case p085 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean (by decide)
  case p086 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean (by decide)
  case p087 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .boolean (by decide)
  case p088 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p089 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p090 => exact scoped_binary externals "left" "right" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p091 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p092 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p093 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean (by decide)
  case p094 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean (by decide)
  case p095 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean (by decide)
  case p096 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .boolean (by decide)
  case p097 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p098 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p099 => exact scoped_binary externals "left" "right" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p100 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p101 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p102 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean (by decide)
  case p103 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean (by decide)
  case p104 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean (by decide)
  case p105 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .boolean (by decide)
  case p106 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p107 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p108 => exact scoped_binary externals "left" "right" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p109 => exact scoped_structural externals
  case p110 => exact scoped_structural externals
  case p111 => exact scoped_binary externals "a" "b" .byte .byte .byte (by decide)
  case p112 => exact scoped_binary externals "a" "b" .byte .byte .byte (by decide)
  case p113 => exact scoped_unary externals "a" .byte .byte
  case p114 => exact scoped_binary externals "a" "b" .byte .byte .byte (by decide)
  case p115 => exact scoped_option externals "n" .integer .byte
  case p116 => exact scoped_binary externals "a" "n" .byte .integer .byte (by decide)
  case p117 => exact scoped_binary externals "a" "n" .byte .integer .byte (by decide)
  case p118 => exact scoped_unary externals "b" .byte .integer
  case p119 => exact scoped_unary externals "b" .byte .string
  case p120 => exact scoped_bytesOrdinary externals .concatenate
  case p121 => exact scoped_bytesOrdinary externals .empty
  case p122 => exact scoped_bytesOrdinary externals .fromBinary
  case p123 => exact scoped_bytesOrdinary externals .fromHex
  case p124 => exact scoped_bytesOrdinary externals .fromIntegers
  case p125 => exact scoped_bytes externals .bytesFromList
  case p126 => exact scoped_bytesOrdinary externals .fromSigned
  case p127 => exact scoped_bytesOrdinary externals .fromUnsigned
  case p128 => exact scoped_bytesOrdinary externals .get
  case p129 => exact scoped_bytes externals .bytesLength
  case p130 => exact scoped_bytesOrdinary externals .readSigned
  case p131 => exact scoped_bytesOrdinary externals .readUnsigned
  case p132 => exact scoped_bytesOrdinary externals .slice
  case p133 => exact scoped_bytesOrdinary externals .toBinary
  case p134 => exact scoped_bytesOrdinary externals .toHex
  case p135 => exact scoped_bytes externals .bytesToList
  case p136 => exact scoped_option externals "n" .integer .character
  case p137 => exact scoped_unary externals "c" .character .boolean
  case p138 => exact scoped_unary externals "c" .character .boolean
  case p139 => exact scoped_unary externals "c" .character .boolean
  case p140 => exact scoped_unary externals "c" .character .boolean
  case p141 => exact scoped_unary externals "c" .character .boolean
  case p142 => exact scoped_unary externals "c" .character .boolean
  case p143 => exact scoped_unary externals "c" .character .boolean
  case p144 => exact scoped_unary externals "c" .character .integer
  case p145 => exact scoped_unary externals "c" .character .string
  case p146 => exact scoped_unary externals "c" .character .string
  case p147 => exact scoped_unary externals "c" .character .string
  case p148 => exact scoped_unary externals "x" .decimal .decimal
  case p149 => exact scoped_option externals "x" .float .decimal
  case p150 => exact scoped_unary externals "n" .integer .decimal
  case p151 => exact scoped_option externals "s" .string .decimal
  case p152 => exact scoped_decimal externals .round
  case p153 => exact scoped_unary externals "x" .decimal .float
  case p154 => exact scoped_unary externals "x" .decimal .string
  case p155 => exact scoped_option externals "x" .decimal .integer
  case p164 => exact scoped_unary externals "x" .float .float
  case p165 => exact scoped_unary externals "x" .float .float
  case p166 => exact scoped_unary externals "x" .float .float
  case p167 => exact scoped_unary externals "x" .float .boolean
  case p168 => exact scoped_option externals "s" .string .float
  case p169 => exact scoped_unary externals "x" .float .float
  case p170 => exact scoped_unary externals "x" .float .float
  case p171 => exact scoped_unary externals "x" .float .string
  case p172 => exact scoped_option externals "x" .float .integer
  case p173 => exact scoped_unary externals "n" .float32 .float32
  case p174 => exact scoped_unary externals "n" .float32 .float32
  case p175 => exact scoped_unary externals "n" .float32 .float32
  case p176 => exact scoped_option externals "n" .float .float32
  case p177 => exact scoped_unary externals "n" .float32 .boolean
  case p178 => exact scoped_unary externals "n" .float32 .boolean
  case p179 => exact scoped_option externals "s" .string .float32
  case p180 => exact scoped_unary externals "n" .float32 .float32
  case p181 => exact scoped_unary externals "n" .float32 .float32
  case p182 => exact scoped_unary externals "n" .float32 .float
  case p183 => exact scoped_unary externals "n" .float32 .string
  case p184 => exact scoped_option externals "n" .float32 .integer
  case p189 => exact scoped_unary externals "n" .integer .integer
  case p190 => exact scoped_binary externals "a" "b" .integer .integer .integer (by decide)
  case p191 => exact scoped_binary externals "a" "b" .integer .integer .integer (by decide)
  case p192 => exact scoped_unary externals "a" .integer .integer
  case p193 => exact scoped_binary externals "a" "b" .integer .integer .integer (by decide)
  case p194 => exact scoped_binary externals "a" "b" .integer .integer .integer (by decide)
  case p195 => exact scoped_binary externals "a" "b" .integer .integer .integer (by decide)
  case p196 => exact scoped_binary externals "a" "b" .integer .integer .integer (by decide)
  case p197 => exact scoped_binary externals "a" "b" .integer .integer .integer (by decide)
  case p198 => exact scoped_option externals "s" .string .integer
  case p199 => exact scoped_binary externals "a" "n" .integer .integer .integer (by decide)
  case p200 => exact scoped_binary externals "a" "n" .integer .integer .integer (by decide)
  case p201 => exact scoped_binary externals "a" "n" .integer .integer .integer (by decide)
  case p202 => exact scoped_unary externals "n" .integer .float
  case p203 => exact scoped_unary externals "n" .integer .string
  case p204 => exact scoped_unary externals "n" .integer16 .integer16
  case p205 => exact scoped_binary externals "a" "b" .integer16 .integer16 .integer16 (by decide)
  case p206 => exact scoped_binary externals "a" "b" .integer16 .integer16 .integer16 (by decide)
  case p207 => exact scoped_unary externals "a" .integer16 .integer16
  case p208 => exact scoped_binary externals "a" "b" .integer16 .integer16 .integer16 (by decide)
  case p209 => exact scoped_binary externals "a" "b" .integer16 .integer16 .integer16 (by decide)
  case p210 => exact scoped_binary externals "a" "b" .integer16 .integer16 .integer16 (by decide)
  case p211 => exact scoped_option externals "n" .integer .integer16
  case p212 => exact scoped_binary externals "a" "b" .integer16 .integer16 .integer16 (by decide)
  case p213 => exact scoped_binary externals "a" "b" .integer16 .integer16 .integer16 (by decide)
  case p214 => exact scoped_option externals "s" .string .integer16
  case p215 => exact scoped_binary externals "a" "n" .integer16 .integer .integer16 (by decide)
  case p216 => exact scoped_binary externals "a" "n" .integer16 .integer .integer16 (by decide)
  case p217 => exact scoped_binary externals "a" "n" .integer16 .integer .integer16 (by decide)
  case p218 => exact scoped_unary externals "n" .integer16 .float
  case p219 => exact scoped_unary externals "n" .integer16 .integer
  case p220 => exact scoped_unary externals "n" .integer16 .string
  case p221 => exact scoped_unary externals "n" .integer32 .integer32
  case p222 => exact scoped_binary externals "a" "b" .integer32 .integer32 .integer32 (by decide)
  case p223 => exact scoped_binary externals "a" "b" .integer32 .integer32 .integer32 (by decide)
  case p224 => exact scoped_unary externals "a" .integer32 .integer32
  case p225 => exact scoped_binary externals "a" "b" .integer32 .integer32 .integer32 (by decide)
  case p226 => exact scoped_binary externals "a" "b" .integer32 .integer32 .integer32 (by decide)
  case p227 => exact scoped_binary externals "a" "b" .integer32 .integer32 .integer32 (by decide)
  case p228 => exact scoped_option externals "n" .integer .integer32
  case p229 => exact scoped_binary externals "a" "b" .integer32 .integer32 .integer32 (by decide)
  case p230 => exact scoped_binary externals "a" "b" .integer32 .integer32 .integer32 (by decide)
  case p231 => exact scoped_option externals "s" .string .integer32
  case p232 => exact scoped_binary externals "a" "n" .integer32 .integer .integer32 (by decide)
  case p233 => exact scoped_binary externals "a" "n" .integer32 .integer .integer32 (by decide)
  case p234 => exact scoped_binary externals "a" "n" .integer32 .integer .integer32 (by decide)
  case p235 => exact scoped_unary externals "n" .integer32 .float
  case p236 => exact scoped_unary externals "n" .integer32 .integer
  case p237 => exact scoped_unary externals "n" .integer32 .string
  case p238 => exact scoped_unary externals "n" .integer8 .integer8
  case p239 => exact scoped_binary externals "a" "b" .integer8 .integer8 .integer8 (by decide)
  case p240 => exact scoped_binary externals "a" "b" .integer8 .integer8 .integer8 (by decide)
  case p241 => exact scoped_unary externals "a" .integer8 .integer8
  case p242 => exact scoped_binary externals "a" "b" .integer8 .integer8 .integer8 (by decide)
  case p243 => exact scoped_binary externals "a" "b" .integer8 .integer8 .integer8 (by decide)
  case p244 => exact scoped_binary externals "a" "b" .integer8 .integer8 .integer8 (by decide)
  case p245 => exact scoped_option externals "n" .integer .integer8
  case p246 => exact scoped_binary externals "a" "b" .integer8 .integer8 .integer8 (by decide)
  case p247 => exact scoped_binary externals "a" "b" .integer8 .integer8 .integer8 (by decide)
  case p248 => exact scoped_option externals "s" .string .integer8
  case p249 => exact scoped_binary externals "a" "n" .integer8 .integer .integer8 (by decide)
  case p250 => exact scoped_binary externals "a" "n" .integer8 .integer .integer8 (by decide)
  case p251 => exact scoped_binary externals "a" "n" .integer8 .integer .integer8 (by decide)
  case p252 => exact scoped_unary externals "n" .integer8 .float
  case p253 => exact scoped_unary externals "n" .integer8 .integer
  case p254 => exact scoped_unary externals "n" .integer8 .string
  case p255 => exact scoped_append externals
  case p256 => exact scoped_list externals .concatenate
  case p257 => exact scoped_listRemaining externals .contains
  case p258 => exact scoped_listRemaining externals .drop
  case p259 => exact scoped_listRemaining externals .get
  case p260 => exact scoped_headTail externals false
  case p261 => exact scoped_list externals .isEmpty
  case p262 => exact scoped_list externals .length
  case p263 => exact scoped_list externals .prepend
  case p264 => exact scoped_range externals
  case p265 => exact scoped_list externals .reverse
  case p266 => exact scoped_listRemaining externals .sort
  case p267 => exact scoped_headTail externals true
  case p268 => exact scoped_listRemaining externals .take
  case p269 => exact scoped_map externals .contains
  case p270 => exact scoped_map externals .empty
  case p271 => exact scoped_precision externals true true
  case p272 => exact scoped_map externals .get
  case p273 => exact scoped_map externals .keys
  case p274 => exact scoped_map externals .remove
  case p275 => exact scoped_map externals .set
  case p276 => exact scoped_map externals .size
  case p277 => exact scoped_precision externals true false
  case p278 => exact scoped_map externals .values
  case p284 => exact scoped_set externals .add
  case p285 => exact scoped_set externals .contains
  case p286 => exact scoped_set externals .difference
  case p287 => exact scoped_set externals .empty
  case p288 => exact scoped_precision externals false true
  case p289 => exact scoped_set externals .intersection
  case p290 => exact scoped_set externals .remove
  case p291 => exact scoped_set externals .size
  case p292 => exact scoped_precision externals false false
  case p293 => exact scoped_set externals .union
  case p294 => exact scoped_string externals .byteIndexOf
  case p295 => exact scoped_bytes externals .stringBytes
  case p296 => exact scoped_string externals .byteSlice
  case p297 => exact scoped_string externals .characterAt
  case p298 => exact scoped_bytes externals .stringCharacters
  case p299 => exact scoped_string externals .characterSlice
  case p300 => exact scoped_string externals .characters
  case p301 => exact scoped_string externals .contains
  case p302 => exact scoped_string externals .displayWidth
  case p303 => exact scoped_string externals .displayWidthCJK
  case p304 => exact scoped_string externals .displayWidthPadEnd
  case p305 => exact scoped_string externals .displayWidthPadEndCJK
  case p306 => exact scoped_string externals .displayWidthPadStart
  case p307 => exact scoped_string externals .displayWidthPadStartCJK
  case p308 => exact scoped_string externals .endsWith
  case p309 => exact scoped_string externals .fromCharacters
  case p310 => exact scoped_string externals .fromUTF8
  case p311 => exact scoped_string externals .isEmpty
  case p312 => exact scoped_string externals .join
  case p313 => exact scoped_string externals .lines
  case p314 => exact scoped_string externals .repeat
  case p315 => exact scoped_string externals .replace
  case p316 => exact scoped_string externals .split
  case p317 => exact scoped_string externals .startsWith
  case p318 => exact scoped_string externals .toLowercase
  case p319 => exact scoped_string externals .toUTF8
  case p320 => exact scoped_string externals .toUppercase
  case p321 => exact scoped_string externals .trim
  case p322 => exact scoped_unary externals "n" .unsignedInteger16 .unsignedInteger16
  case p323 => exact scoped_binary externals "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p324 => exact scoped_binary externals "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p325 => exact scoped_unary externals "a" .unsignedInteger16 .unsignedInteger16
  case p326 => exact scoped_binary externals "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p327 => exact scoped_binary externals "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p328 => exact scoped_binary externals "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p329 => exact scoped_option externals "n" .integer .unsignedInteger16
  case p330 => exact scoped_binary externals "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p331 => exact scoped_binary externals "a" "b" .unsignedInteger16 .unsignedInteger16 .unsignedInteger16 (by decide)
  case p332 => exact scoped_option externals "s" .string .unsignedInteger16
  case p333 => exact scoped_binary externals "a" "n" .unsignedInteger16 .integer .unsignedInteger16 (by decide)
  case p334 => exact scoped_binary externals "a" "n" .unsignedInteger16 .integer .unsignedInteger16 (by decide)
  case p335 => exact scoped_unary externals "n" .unsignedInteger16 .float
  case p336 => exact scoped_unary externals "n" .unsignedInteger16 .integer
  case p337 => exact scoped_unary externals "n" .unsignedInteger16 .string
  case p338 => exact scoped_unary externals "n" .unsignedInteger32 .unsignedInteger32
  case p339 => exact scoped_binary externals "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p340 => exact scoped_binary externals "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p341 => exact scoped_unary externals "a" .unsignedInteger32 .unsignedInteger32
  case p342 => exact scoped_binary externals "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p343 => exact scoped_binary externals "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p344 => exact scoped_binary externals "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p345 => exact scoped_option externals "n" .integer .unsignedInteger32
  case p346 => exact scoped_binary externals "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p347 => exact scoped_binary externals "a" "b" .unsignedInteger32 .unsignedInteger32 .unsignedInteger32 (by decide)
  case p348 => exact scoped_option externals "s" .string .unsignedInteger32
  case p349 => exact scoped_binary externals "a" "n" .unsignedInteger32 .integer .unsignedInteger32 (by decide)
  case p350 => exact scoped_binary externals "a" "n" .unsignedInteger32 .integer .unsignedInteger32 (by decide)
  case p351 => exact scoped_unary externals "n" .unsignedInteger32 .float
  case p352 => exact scoped_unary externals "n" .unsignedInteger32 .integer
  case p353 => exact scoped_unary externals "n" .unsignedInteger32 .string
  case p354 => exact scoped_unary externals "n" .unsignedInteger64 .unsignedInteger64
  case p355 => exact scoped_binary externals "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p356 => exact scoped_binary externals "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p357 => exact scoped_unary externals "a" .unsignedInteger64 .unsignedInteger64
  case p358 => exact scoped_binary externals "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p359 => exact scoped_binary externals "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p360 => exact scoped_binary externals "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p361 => exact scoped_option externals "x" .decimal .unsignedInteger64
  case p362 => exact scoped_option externals "n" .integer .unsignedInteger64
  case p363 => exact scoped_binary externals "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p364 => exact scoped_binary externals "a" "b" .unsignedInteger64 .unsignedInteger64 .unsignedInteger64 (by decide)
  case p365 => exact scoped_option externals "s" .string .unsignedInteger64
  case p366 => exact scoped_binary externals "a" "n" .unsignedInteger64 .integer .unsignedInteger64 (by decide)
  case p367 => exact scoped_binary externals "a" "n" .unsignedInteger64 .integer .unsignedInteger64 (by decide)
  case p368 => exact scoped_unary externals "n" .unsignedInteger64 .decimal
  case p369 => exact scoped_unary externals "n" .unsignedInteger64 .float
  case p370 => exact scoped_option externals "n" .unsignedInteger64 .integer
  case p371 => exact scoped_unary externals "n" .unsignedInteger64 .string
  case p374 => exact store.2.2.1
  case p375 => exact store.1
  case p376 => exact store.2.1
  case p377 => exact store.2.2.2
  case p185 => exact http_scoped externals (b := "Http.checkRequestIn") rfl
  case p186 => exact http_scoped externals (b := "Http.requestInValue") rfl
  case p187 => exact http_scoped externals (b := "Http.sendIn") rfl
  case p188 => exact http_scoped externals (b := "Http.widenRequestIn") rfl
  case p156 => exact targets_scoped externals (b := "Example.pathBases") rfl
  case p157 => exact targets_scoped externals (b := "File.appendBytesIn") rfl
  case p158 => exact targets_scoped externals (b := "File.appendTextIn") rfl
  case p159 => exact targets_scoped externals (b := "File.readBytesIn") rfl
  case p160 => exact targets_scoped externals (b := "File.readText") rfl
  case p161 => exact targets_scoped externals (b := "File.readTextIn") rfl
  case p162 => exact targets_scoped externals (b := "File.writeBytesIn") rfl
  case p163 => exact targets_scoped externals (b := "File.writeTextIn") rfl
  case p279 => exact targets_scoped externals (b := "Reference.get") rfl
  case p280 => exact targets_scoped externals (b := "Reference.set") rfl
  case p281 => exact targets_scoped externals (b := "Scope.checkPathIn") rfl
  case p282 => exact targets_scoped externals (b := "Scope.pathInValue") rfl
  case p283 => exact targets_scoped externals (b := "Scope.widenPathIn") rfl
  case p372 => exact targets_scoped externals (b := "exit") rfl
  case p373 => exact targets_scoped externals (b := "print") rfl

end
end Benitoite.Release.Refinement.StandardModel
