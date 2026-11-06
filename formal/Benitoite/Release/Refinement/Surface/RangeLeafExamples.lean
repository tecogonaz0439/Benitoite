import Benitoite.Release.Refinement.Surface.RangeStandard

/-! # 開いた型引数を持つ標準の組込み参照

List.length の型引数へ、関数の範囲パラメータを添字に持つ型を渡す。
許容と署名の葉は全具体化を例の中で直接証明せず、有限な形成条件から供給する。
-/
namespace Benitoite.Release.Refinement.Surface.RangeLeafExamples
noncomputable section
open OpenSurface OpenLeafFormation

private def argument : Ty := .opaque "Scope.PathIn" (.rvar 0)
private def lengthSig : PrimSig := StandardListResponse.API.signature .length

private theorem length_lookup (P : Refinement.Program) :
    (StandardModel.builtins P).sig "List.length" = some lengthSig := rfl

private theorem length_scoped (P : Refinement.Program) : lengthSig.Scoped P := by
  constructor
  all_goals simp [lengthSig, StandardListResponse.API.signature, StandardListResponse.API.names,
    StandardListResponse.API.inputs, StandardListResponse.API.result, PrimSig.tel, signatureTel,
    NamesWF, Ty.SourceScoped, Ty.WF, Tel.WF, Ty.WFList, Ty.RowsIn, Tel.RowsIn,
    Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped, Tel.RangesScoped, rangesScopedTypes,
    Eff.RangesScoped, Eff.WF, Eff.empty, Eff.Canonical, Eff.norm, Ty.normTys, Ty.HasKind, TypeCtx.valueParam,
    kindsTel, kindsList, kindsEff, TypeCtx.kinds, Tel.Sorted, Ty.Sorted, sortedTys, sortedEff,
    Tel.Declared, Ty.Declared, declaredTys, declaredEff, RangeIx.WF]

private theorem length_primitive : PrimitiveCheck [.path] [] 0 lengthSig Qempty [argument] [] := by
  constructor
  all_goals simp [lengthSig, StandardListResponse.API.signature, StandardListResponse.API.names,
    StandardListResponse.API.inputs, StandardListResponse.API.result, argument, PrimSig.tel, signatureTel,
    Ty.WF, Ty.core, RangeIx.WF, Eff.empty, Eff.RowsIn, Ty.RowsInList,
    Tel.RowsIn, Ty.RowsIn, Ty.normTys, Ty.norm, RowTransport, NoFail, Qsig, QTys, QTy, QEff, Qempty]

private theorem length_signature (P : Refinement.Program) :
    SignatureCheck P [.path] [] [] lengthSig.tel (TypeCtx.kinds lengthSig.tparams) [argument] [] := by
  constructor
  all_goals simp [lengthSig, StandardListResponse.API.signature, StandardListResponse.API.names,
    StandardListResponse.API.inputs, StandardListResponse.API.result, argument, PrimSig.tel, signatureTel,
    Ty.WF, Tel.WF, Ty.WFList, Eff.WF, Eff.empty, Eff.Canonical,
    Eff.norm, Ty.normTys, Ty.norm, TypeCtx.kinds, TypeCtx.valueParam,

    Annotations, OpenSurface.RowAnnotations, TypeArgsKinded, instantiatedTel, Tel.bind, Tel.rawBind,
    typeEnvAt, SubstEnv.up, Ty.rawBind, rawBindTys, Eff.rawBind, substAtoms_nil,
    instAtoms_nil, rowFails, Tel.norm]
  all_goals first
    | (constructor <;> simp [Ty.WF, Tel.WF, Ty.WFList, RangeIx.WF,
        Eff.WF, Eff.Canonical, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted,
        sortedTys, sortedEff, Ty.Declared, Tel.Declared, declaredTys, declaredEff])
    | (intro i a k ha hk
       cases i with
       | zero =>
         simp only [List.getElem?_cons_zero, Option.some.injEq] at ha hk
         cases ha; cases hk
         exact ⟨trivial, by intro _ b t e he; cases he⟩
       | succ i => simp at ha)

/-- 範囲変数を含む非空の型引数列を、標準の List.length の参照で受理する。 -/
theorem list_length_reference (D : Declarations) (op : OpPrim) :
    OpenSurface.HasTypeQ D (StandardModel.builtins D.core) [.path] op Qempty [] [] [] [] none .tail
      (.primName "List.length" [argument] [] [])
      (.dependentFn (instantiatedTel lengthSig.tel [argument] [])) Eff.empty := by
  apply OpenSurface.HasTypeQ.E_Prim
  apply OpenSurface.CallHeadTy.prim (length_lookup D.core) (length_scoped D.core)
    (by exact ⟨rfl, by intro i ix k hi; cases hi⟩)
    (RangeStandard.ranges_of_check (by exact ⟨rfl, by intro i ix k hi; cases hi⟩)
      (Or.inl (by intro ix hi; cases hi)))
    (by decide)
    (RangeStandard.primitive_of_check (length_lookup D.core) length_primitive)
    (SignatureCheck.sound (length_signature D.core))

end
end Benitoite.Release.Refinement.Surface.RangeLeafExamples
