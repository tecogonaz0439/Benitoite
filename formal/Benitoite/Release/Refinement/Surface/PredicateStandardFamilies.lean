import Benitoite.Release.Refinement.Surface.PredicateStandardAtoms

/-! # 標準の署名の族ごとの有限支持 -/
namespace Benitoite.Release.Refinement.Surface.PredicateStandardSupport
open StandardModel
noncomputable section

abbrev Supported (s : PrimSig) :=
  CheckArguments.SignatureSupport atoms s.params s.ret s.eff s.tel

theorem support_structural  :
    Supported (StandardEqualityResponse.fullSignature signatureBase.sat) := by
  all_goals try dsimp only [StandardEqualityResponse.fullSignature, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_decimal (api : StandardDecimalResponse.API) :
    Supported (api.signature) := by
  cases api
  all_goals try dsimp only [StandardDecimalResponse.API.signature,StandardDecimalResponse.API.names,StandardDecimalResponse.API.inputs,StandardDecimalResponse.API.result, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_replaceValues  :
    Supported (StandardMapReplaceValues.signature signatureBase.sat) := by
  all_goals try dsimp only [StandardMapReplaceValues.signature,StandardMapReplaceValues.size,StandardMapReplaceValues.length, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_bytesOrdinary (api : StandardBytesOrdinaryResponse.API) :
    Supported (api.signature) := by
  cases api
  all_goals try dsimp only [StandardBytesOrdinaryResponse.API.signature,StandardBytesOrdinaryResponse.API.names,StandardBytesOrdinaryResponse.API.inputs,StandardBytesOrdinaryResponse.API.resultKind, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_bytes (api : StandardBytesResponse.API) :
    Supported (api.signature) := by
  cases api
  all_goals try dsimp only [StandardBytesResponse.API.signature,StandardBytesResponse.API.names,StandardBytesResponse.API.inputs,StandardBytesResponse.API.result, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_append  :
    Supported (StandardHeadTail.appendSignature) := by
  all_goals try dsimp only [StandardHeadTail.appendSignature,StandardHeadTail.appendPredicate, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_list (api : StandardListResponse.API) :
    Supported (api.signature) := by
  cases api
  all_goals try dsimp only [StandardListResponse.API.signature,StandardListResponse.API.names,StandardListResponse.API.inputs,StandardListResponse.API.result, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_listRemaining (api : StandardListRemainingResponse.API) :
    Supported (StandardListRemainingResponse.API.signature signatureBase.sat api) := by
  cases api
  all_goals try dsimp only [StandardListRemainingResponse.API.signature,StandardListRemainingResponse.API.names,StandardListRemainingResponse.API.inputs,StandardListRemainingResponse.API.result,StandardListRemainingResponse.API.constraint, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_headTail (tail : Bool) :
    Supported (if tail then StandardHeadTail.tailSignature else StandardHeadTail.headSignature) := by
  cases tail
  all_goals try dsimp only [StandardHeadTail.headSignature,StandardHeadTail.tailSignature,StandardHeadTail.headPredicate,StandardHeadTail.tailPredicate,StandardHeadTail.someField, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_range  :
    Supported (StandardListRemainingResponse.rangeSignature) := by
  all_goals try dsimp only [StandardListRemainingResponse.rangeSignature, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_map (api : StandardCollections.MapAPI) :
    Supported (StandardCollections.MapAPI.signature signatureBase.sat api) := by
  cases api
  all_goals try dsimp only [StandardCollections.MapAPI.signature,StandardCollections.MapAPI.names,StandardCollections.MapAPI.inputs,StandardCollections.MapAPI.result, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_precision (map build : Bool) :
    Supported (StandardCollectionPrecision.signature signatureBase.sat map build) := by
  cases map <;> cases build
  all_goals try dsimp only [StandardCollectionPrecision.signature,StandardBodies.collectionPrimitiveSig,StandardCollectionPrecision.result,StandardCollectionPrecision.input,StandardCollectionPrecision.collection,StandardCollectionPrecision.element,StandardCollectionPrecision.predicate,StandardCollectionPrecision.size,StandardCollectionPrecision.length, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList,   ]

theorem support_set (api : StandardCollections.SetAPI) :
    Supported (StandardCollections.SetAPI.signature signatureBase.sat api) := by
  cases api
  all_goals try dsimp only [StandardCollections.SetAPI.signature,StandardCollections.SetAPI.names,StandardCollections.SetAPI.inputs,StandardCollections.SetAPI.result, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_string (api : StandardStringOrdinaryResponse.API) :
    Supported (api.signature) := by
  cases api
  all_goals try dsimp only [StandardStringOrdinaryResponse.API.signature,StandardStringOrdinaryResponse.API.names,StandardStringOrdinaryResponse.API.inputs,StandardStringOrdinaryResponse.API.resultKind, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_unary (n : String) (i o : BaseTy) :
    Supported (unarySig n i o) := by
  all_goals try dsimp only [unarySig, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_binary (n m : String) (i j o : BaseTy)
    : Supported (binarySig n m i j o) := by
  all_goals try dsimp only [binarySig, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_option (n : String) (i o : BaseTy) :
    Supported (optionSig n i o) := by
  all_goals try dsimp only [optionSig, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_store :
    Supported refNewSig ∧ Supported refUpdateSig ∧
      Supported forceSig ∧ Supported StandardSafe.frontSig := by
  refine ⟨?_, ?_, ?_, ?_⟩
  all_goals try dsimp only [refNewSig, refUpdateSig, forceSig, StandardSafe.frontSig, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all [decide_eq_true_eq]
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_predicate (api : PredicateResponse.API) :
    Supported api.signature := by
  cases api <;> try (rename_i w t; cases w)
  all_goals try dsimp only [PredicateResponse.API.signature,PredicateResponse.API.names,PredicateResponse.API.inputs, Supported, CheckArguments.SignatureSupport, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty, Eff.single, Eff.row,
    Eff.atoms, Eff.fails, atoms, stateEff,
    Ty.shiftV, shiftVTys, Eff.shiftV, Tel.shiftV, StandardPureResults.Kind.type,
    StandardOperatorArguments.signature, StandardFloatMathResponse.base, embedTy, embedTys,
    Benitoite.Interval.IntKind.type, TypeCtx.valueParam,
    RefinementCheck.result, RefinementCheck.errorType]
  all_goals try dsimp only [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support, stateEff]
  all_goals simp_all
  all_goals simp [Ty.Support, Ty.SupportList, Tel.Support, signatureTel, Eff.Support]

theorem support_check : Supported RefinementCheck.signature := by
  simp [Supported, CheckArguments.SignatureSupport, RefinementCheck.signature,
    RefinementCheck.result, RefinementCheck.errorType, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty]

end
end Benitoite.Release.Refinement.Surface.PredicateStandardSupport
