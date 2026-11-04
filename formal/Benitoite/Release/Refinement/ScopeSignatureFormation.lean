import Benitoite.Release.Refinement.ScopeSignatures

/-! # 同じ有限の宣言からの全署名の形成 -/
namespace Benitoite.Release.Refinement.ScopeSignatures
open ScopeDeclarations

set_option maxRecDepth 4000
set_option maxHeartbeats 2000000

/-- 全16署名は、同じ有限宣言の lookup と arity から形成される。 -/
theorem entries_scoped {P : Program} (hP : HasHttp P) :
    ∀ row ∈ entries, PrimSig.Scoped P row.2 := by
  have hr := (hP result (by simp [http,file])).1
  have hs := (hP scopeError (by simp [http,file])).1
  have hc := (hP clientRequest (by simp [http])).1
  have he := (hP requestCheckError (by simp [http])).1
  change P.DataArity "Result" 2 at hr
  change P.DataArity "Scope.ScopeError" 0 at hs
  change P.DataArity "Http.ClientRequest" 0 at hc
  change P.DataArity "Http.RequestCheckError" 0 at he
  have kr := TyCon.arity_data hr
  have ks := TyCon.arity_data hs
  have kc := TyCon.arity_data hc
  have ke := TyCon.arity_data he
  intro row hm
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false] at hm
  rcases hm with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals constructor
  all_goals first
    | (simp [readTextIn,readBytesIn,writeTextIn,appendTextIn,writeBytesIn,appendBytesIn,sendIn,
        checkPathIn,checkRequestIn,pathInValue,requestInValue,widenPathIn,widenRequestIn,
        refGet,refSet,pathBases,pureIn,ioIn,PrimSig.tel,signatureTel,
        NamesWF,Ty.SourceScoped,Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,
        Ty.RowsIn,Tel.RowsIn,Ty.RowsInList,Eff.RowsIn,
        Ty.RangesScoped,Tel.RangesScoped,rangesScopedTypes,Eff.RangesScoped,
        Eff.WF,Eff.single,Eff.empty,Eff.Canonical,Eff.norm,Ty.normTys,
        Ty.HasKind,kindsTel,kindsList,kindsEff,TypeCtx.kinds,TypeCtx.valueParam,
        Tel.Sorted,Ty.Sorted,sortedTys,sortedEff,
        Tel.Declared,Ty.Declared,declaredTys,declaredEff,
        PrimSig.OperationWF,BinderTypes.TargetWF,Ty.TargetWF,
        TargetTable.clientRequestTy,embedTy,Benitoite.Release.TargetTable.clientRequestTy,
        atErrorType,kr,ks,kc,ke,hr,hs,hc,he])

/-- 同じ表の lookup で成功する任意の署名の形成。 -/
theorem sig_scoped {P : Program} (hP : HasHttp P) {delta io b sg}
    (h : (builtins delta io).sig b = some sg) : PrimSig.Scoped P sg :=
  entries_scoped hP (b,sg) (lookup_mem h)

/-- 宣言した行の上限を、実際の依存列に供給する。 -/
theorem sourceTelRows {P : Program} (hP : HasHttp P) {delta io b sg}
    (h : (builtins delta io).sig b = some sg) : sg.tel.RowsIn (· < sg.neffs) :=
  (sig_scoped hP h).source.2.1

example {delta io b sg} (h : (builtins delta io).sig b = some sg) :
    PrimSig.Scoped ScopeDeclarations.program sg ∧ sg.tel.RowsIn (· < sg.neffs) :=
  ⟨sig_scoped program_hasHttp h,sourceTelRows program_hasHttp h⟩
end Benitoite.Release.Refinement.ScopeSignatures
