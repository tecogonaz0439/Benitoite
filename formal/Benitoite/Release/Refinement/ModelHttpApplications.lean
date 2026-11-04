import Benitoite.Release.Refinement.ModelHttpConditions
import Benitoite.Release.Refinement.PathBasesTargets

/-! # 要求モデルの実引数、保持した端点と発行の適用 -/
namespace Benitoite.Release.Refinement.ModelHttpApplications
noncomputable section
open Scope.Domain ScopeSignatures ScopeDeclarations
private def B : Builtins := ModelHttp.builtins

private def stringTrue : Ty := .refined (.base .string) .truth
private def header : Val := .con "Pair.Pair" [stringTrue,.base .string]
  [.const (.string "Accept"),.const (.string "text/plain")]
private def request : Val := .con "Http.ClientRequest" []
  [.const (.string "GET"),.const (.string "https://127.0.0.1/"),
    .list [header],.bytesV [],.const (.integer ⟨1,by decide⟩)]
private def endpoint : Target := .endpoint ⟨.ip (.v4 2130706433 (by decide)),⟨443,by decide⟩⟩

private theorem typed {P B Ψ} (hP : ScopeDeclarations.HasHttp P) :
    HasTypeV P B Ψ [] [] [] request TargetTable.clientRequestTy := by
  have hp := hP ScopeDeclarations.pair (by simp [ScopeDeclarations.http])
  have hc := hP ScopeDeclarations.clientRequest (by simp [ScopeDeclarations.http])
  have pairLookup : P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩ :=
    hp.2 ("Pair.Pair", ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
      (by simp [ScopeDeclarations.pair,StandardKeyTyping.DataDecl.entries])
  have reqLookup : P.cons "Http.ClientRequest" = some ⟨"Http.ClientRequest",0,
      [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
       .bytes,.base .integer]⟩ :=
    hc.2 ("Http.ClientRequest",⟨"Http.ClientRequest",0,
      [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
       .bytes,.base .integer]⟩)
      (by simp [ScopeDeclarations.clientRequest,StandardKeyTyping.DataDecl.entries])
  have hd : Ty.Declared P [] [] (.data "Pair" [stringTrue,.base .string]) :=
    ⟨⟨2,hp.1,rfl⟩,⟨⟨trivial,trivial⟩,trivial,trivial⟩⟩
  have ht : HasTypeV P B Ψ [] [] [] (.const (.string "Accept")) stringTrue :=
    .V_Sub (.V_Const trivial) (.introduce trivial .truth)
      ⟨trivial,trivial,by intro b t e h; cases h⟩ ⟨trivial,trivial⟩ ⟨trivial,trivial⟩
  have hh : HasTypeV P B Ψ [] [] [] header (.data "Pair" [stringTrue,.base .string]) := by
    refine .V_Con pairLookup rfl ?_ ?_ ?_ ⟨?_,?_,hd⟩
    · constructor
      · rfl
      · intro i a k ha hk
        cases i with
        | zero => simp at ha hk; subst a; subst k
                  exact ⟨⟨trivial,by intro b t e h; cases h⟩,by intro _ b t e h; cases h⟩
        | succ i =>
          cases i with
          | zero => simp at ha hk; subst a; subst k
                    exact ⟨trivial,by intro _ b t e h; cases h⟩
          | succ i => simp at ha
    · intro t hm; simp at hm; rcases hm with rfl | rfl <;> simp [Ty.WF]
    · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,
        stringTrue,Ty.norm_refined_truth,Ty.norm] using
        (show HasTypeVsQ P B Ψ Qempty [] [] []
          [.const (.string "Accept"),.const (.string "text/plain")]
          [stringTrue.norm,.base .string] from .cons ht.V_Normal (.cons (.V_Const trivial) .nil))
    · simp [Ty.WF,Ty.WFList,stringTrue,Pred.WF,Pred.VarsIn,Ty.NotContCore,Ty.core]
    · simp [Ty.Sorted,sortedTys,stringTrue,Pred.Sorted]
  have headerPlain : HasTypeV P B Ψ [] [] [] header (.data "Pair" [.base .string,.base .string]) := by
    simpa only [Ty.norm,Ty.normTys,List.map_cons,List.map_nil,stringTrue,
      Ty.norm_refined_truth] using hh.V_Normal
  refine .V_Con reqLookup rfl ?_ ?_ ?_ ⟨?_,?_,?_⟩
  · exact ⟨rfl,by intro i a k ha; cases i <;> cases ha⟩
  · intro t hm
    simp at hm
    rcases hm with rfl | rfl | rfl | rfl <;> simp [Ty.WF,Ty.WFList]
  · exact .cons (.V_Const trivial) (.cons (.V_Const trivial)
      (.cons (.V_List (.cons headerPlain .nil) (by trivial) (by trivial)
        ⟨⟨2,hp.1,rfl⟩,by trivial⟩)
      (.cons (.V_Bytes (by simp)) (.cons (.V_Const trivial) .nil))))
  · trivial
  · trivial
  · exact ⟨⟨0,hc.1,rfl⟩,trivial⟩


private def range (wide : Bool) : RangeExpr :=
  .absolute (if wide then .top else .endpoint
    ⟨.ip (.exact (.v4 2130706433 (by decide))),⟨⟨443,by decide⟩,⟨443,by decide⟩⟩⟩)
private def result : Ty := .data "Result" [.opaque "Http.Response" .top,.opaque "NetworkError" .top]
private def effect (wide : Bool) : Eff :=
  .mk (fun a => decide (a = .name "Http.Connect" (.fixed (range wide)))) []

private theorem instantiated (wide : Bool) :
    instantiatedTel (Tel.instR [range wide] ScopeSignatures.sendIn.tel) [] [] =
      .param "request" (.opaque "Http.RequestIn" (.fixed (range wide))) (.done result (effect wide)) := by
  have atoms : mapRangeAtoms (rangeAt 0 [range wide])
      (fun a => decide (a = .name "Http.Connect" (.rvar 0))) =
      (fun a => decide (a = .name "Http.Connect" (.fixed (range wide)))) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  simp [ScopeSignatures.sendIn,ioIn,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
    Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,atoms,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,result,effect,
    RangeIx.inst,SubstEnv.up]

private theorem result_annotation (Γ : Ctx) : Ty.Annotation program [] Γ result := by
  have ar := (program_hasHttp.file ScopeDeclarations.result (by simp [file])).1
  exact ⟨by trivial,by trivial,⟨⟨2,ar,rfl⟩,by trivial⟩⟩

private theorem arguments (wide : Bool) (Ψ : StoreTy) (v : Val)
    (hv : HasTypeV program B Ψ [] [] [] v (.opaque "Http.RequestIn" (.fixed (range wide))))
    (hg : v.Ground) :
    BuiltinArgs program B Ψ "Http.sendIn" ScopeSignatures.sendIn [] [] [range wide]
      [v] result (effect wide) := by
  constructor
  · constructor
    · rfl
    · rfl
    · simp
    · rfl
    · simp
    · simp [ScopeSignatures.sendIn,ioIn,Eff.RowsIn,Ty.RowsInList]
    · intro i h; simp [Qsig,ScopeSignatures.sendIn,ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · intro i h; simp [Qsig,ScopeSignatures.sendIn,ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · simp [ScopeSignatures.sendIn,ioIn,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn]
  · refine ⟨rfl,?_,?_,Or.inr ⟨by simp, rfl⟩⟩
    · intro i r k hr hk
      cases i <;> simp at hr hk
      cases hr; cases hk
      cases wide <;> decide
    · intro r hr; simp at hr; subst r
      cases wide <;> exact ⟨by decide,by decide⟩
  · constructor
    · simp [ScopeSignatures.sendIn,ioIn,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
        Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
        Ty.WF,Ty.WFList,Tel.WF,Tel.norm,Ty.norm,Eff.norm,Eff.WF,Eff.Canonical,
        RangeIx.inst,RangeIx.WF]
    · simp [TypeAnnotations]
    · exact ⟨rfl,by intro i a k h; cases i <;> cases h⟩
    · simp [RowAnnotations]
    · simp
    · rw [instantiated]
      exact ⟨by trivial,by trivial,⟨trivial,(result_annotation _).declared,trivial⟩⟩
  · rw [instantiated]
    refine .param ⟨trivial,trivial,trivial⟩
      hv ?_
    simp only [Tel.bind_done]
    have hb : result.bind (Tel.argumentsEnv v) = result := by
      simp [result,Ty.bind,Ty.rawBind,rawBindTys,Tel.argumentsEnv,Ty.norm,Ty.normTys,RangeIx.inst]
    have he : Eff.bind (Tel.argumentsEnv v) (effect wide) = effect wide := by
      simp [effect,Eff.bind,Eff.rawBind,Tel.argumentsEnv,valEnv,Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]
    rw [hb,he]
    exact .done ⟨⟨by trivial,by trivial⟩,⟨by trivial,by trivial⟩,
      ⟨(result_annotation _).declared,trivial⟩⟩
  · intro w hw; simp at hw; subst w; exact hg
  · simp
  · simp
  · exact ⟨by trivial,rfl⟩
  · exact ⟨by cases wide <;> simp [effect,Eff.WF,Ty.WFList,range],rfl⟩


/-- 篩付き Pair の要求の両保持形で、非 Top/Top の全前提を実表に供給する。 -/
example (wide : Bool) (Ψ : StoreTy) (σ : PathEnv) :
    ∀ v ∈ [Val.checkedRequest endpoint request,Val.checkedAt (range wide) none endpoint (some request)],
      BuiltinArgs program B Ψ "Http.sendIn" sendIn [] [] [range wide] [v] result (effect wide) ∧
      ∃ out, B.ioResponse "Http.sendIn" [] [] [v] out [endpoint] ∧
        Outcome.Typed program B Ψ out result ∧ AdequateResult [v] out ∧
        Eff.Allows σ B.effKind (effect wide) "Http.Connect" endpoint := by
  have hh := (typed (B := B) (Ψ := Ψ) program_hasHttp).V_Normal
  have hg : groundVal request = true := by decide
  have ht : request.reqTarget = some endpoint := parseUrlTarget_https_loopback
  have hm : Range.MemK .endpoint (if wide then .top else .endpoint
      ⟨.ip (.exact (.v4 2130706433 (by decide))),⟨⟨443,by decide⟩,⟨443,by decide⟩⟩⟩) endpoint := by
    cases wide <;> decide
  have plain : HasTypeV program B Ψ [] [] [] (.checkedRequest endpoint request)
      (.opaque "Http.RequestIn" (.fixed (range wide))) :=
    .V_Sub (.V_CheckedRequest (show B.valKind "Http.RequestIn" = some .endpoint from rfl) (show B.valContent "Http.RequestIn" = some TargetTable.clientRequestTy from rfl) hh hg ht hm) (.scoped_forget) trivial trivial trivial
  have atTyped : HasTypeV program B Ψ [] [] [] (.checkedAt (range wide) none endpoint (some request))
      (.opaque "Http.RequestIn" (.fixed (range wide))) :=
    .V_Sub (.V_CheckedAt (.request (show B.valKind "Http.RequestIn" = some .endpoint from rfl) (show B.valContent "Http.RequestIn" = some TargetTable.clientRequestTy from rfl) hh hg ht hm)) (.scoped_forget)
      trivial trivial trivial
  intro v member
  simp only [List.mem_cons,List.not_mem_nil,or_false] at member
  have hv : HasTypeV program B Ψ [] [] [] v (.opaque "Http.RequestIn" (.fixed (range wide))) := by
    rcases member with rfl | rfl
    · exact plain
    · exact atTyped
  have ground : v.Ground := by
    rcases member with rfl | rfl <;> change request.Ground <;> exact groundVal_ground hg
  have had : ∀ w ∈ [v], w.Adequate σ := by
    intro w hw; simp at hw; subst w
    rcases member with rfl | rfl
    · trivial
    · exact ⟨⟨_,rfl⟩,by trivial⟩
  have args := arguments wide Ψ v hv ground
  have hr := ModelHttp.send_held hg ht (ScopedIOResponse.Reply.error 0) (range wide) none
  have response : B.ioResponse "Http.sendIn" [] [] [v]
      (.val (ScopeDelta.resultValue false (.opaque "Http.Response" .top) (.opaque "NetworkError" .top)
        (.const (.opaque "NetworkError" 0)))) [endpoint] := by
    rcases member with rfl | rfl
    · exact hr.1
    · exact hr.2
  have safe := ModelHttp.io_typed program_hasHttp.file rfl (Or.inl rfl) args response
  obtain ⟨l,hl,allowed⟩ := ModelHttp.obs_allowed program_hasHttp rfl (Or.inl rfl) args had response
  have eq : l = "Http.Connect" := Option.some.inj hl.symm
  subst l
  exact ⟨args,_,response,safe.1,safe.2,allowed endpoint (by simp)⟩

/-- 同じ表の受理側と、両保持形の端点不一致・要求なしの拒否側。 -/
example {req t other} (hg : groundVal req = true) (ht : req.reqTarget = some t)
    (hne : t ≠ other) (r : RangeExpr) (snap : Option PathEnv) :
    (∃ out, B.ioResponse "Http.sendIn" [] [] [.checkedRequest t req] out [t] ∧
      B.ioResponse "Http.sendIn" [] [] [.checkedAt r snap t (some req)] out [t]) ∧
    (∀ ts es out obs,
      ¬ B.ioResponse "Http.sendIn" ts es [.checkedRequest other req] out obs ∧
      ¬ B.ioResponse "Http.sendIn" ts es [.checkedAt r snap other (some req)] out obs) ∧
    (∀ ts es out obs,
      ¬ B.ioResponse "Http.sendIn" ts es [.checked t] out obs ∧
      ¬ B.ioResponse "Http.sendIn" ts es [.checkedAt r snap t none] out obs) :=
  ⟨⟨_,ModelHttp.send_held hg ht (.error 0) r snap⟩,
    ModelHttp.send_mismatch hg ht hne r snap,ModelHttp.send_without_request t r snap⟩

/-- 述語が WF 1 のとき groundTy は篩付きの Pair を受理し、同じ P の正しい arity と欄を使う。 -/
example (p : Pred) (hp : p.WF 1) :
    groundTy (.data "Pair" [.refined (.base .string) p,.base .string]) = true ∧
    HasHttp program ∧ ¬ program.DataArity "Pair" 0 ∧
    (∀ d ∈ [pair,clientRequest,requestCheckError],
      program.DataArity d.name d.ntys ∧ ∀ c ∈ d.entries, program.cons c.1 = some c.2) := by
  refine ⟨by simp [groundTy,groundTys,hp],program_hasHttp,?_,?_⟩
  · intro zero
    have two := (program_hasHttp pair (by simp [http])).1
    cases two.unique zero
  · intro d hd
    exact program_hasHttp d (by simp only [List.mem_cons,List.not_mem_nil,or_false] at hd; rcases hd with rfl | rfl | rfl <;> simp [http])

/-- 保持要求の射影と拡大は、同じ req と同じ値を返す。 -/
example {req t} (hg : groundVal req = true) (r s : RangeExpr) (snap : Option PathEnv) :
    B.delta "Http.requestInValue" [] [] [r] [.checkedRequest t req] = some (.val req) ∧
    B.delta "Http.requestInValue" [] [] [r] [.checkedAt r snap t (some req)] = some (.val req) ∧
    B.delta "Http.widenRequestIn" [] [] [r,s] [.checkedAt r snap t (some req)] =
      some (.val (.checkedAt r snap t (some req))) := by
  simp [B,ModelHttp.builtins,ScopeSignatures.builtins,ScopeResponse.delta,RequestDelta.valueDelta,
    ModelHttp.valueRun,hg,ScopeDelta.widenRun]

/-- 発行の八欄と全 IO 排除は、要求の表と同じ lookup と effects を使う。 -/
example : pathBases.PathBasesShape B pathBasesName ∧
    ∀ ts es ws out obs, ¬ B.ioResponse pathBasesName ts es ws out obs :=
  ⟨ModelHttp.pathBases_shape rfl rfl,ModelHttp.pathBases_no_io rfl rfl⟩

private theorem bases_annotation (P : Program) :
    Ty.Annotation P [] [] (.dependentFn (.done .pathBases (Eff.single processEnvironmentEff))) :=
  ⟨⟨trivial,trivial,by simp [Eff.Canonical,Eff.norm,Eff.single]⟩,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

private theorem bases_instantiated : instantiatedTel (Tel.instR [] pathBases.tel) [] [] =
    .done .pathBases (Eff.single processEnvironmentEff) := by
  rw [Tel.instR_eq_bind]
  simp [instantiatedTel,Tel.bind,Tel.rawBind,SubstEnv.rangesOnly,
    pathBases,PrimSig.tel,signatureTel,Ty.rawBind,Ty.norm,Tel.norm,typeEnvAt,
    Eff.rawBind,Eff.norm,Eff.single,Ty.normTys,rowFails,instAtoms_nil,substAtoms_nil]

/-- 空の型・行・範囲・値引数は、実表の全ての入力条件を満たす。 -/
private theorem bases_arguments (P : Program) (hp : HasHttp P) (Ψ : StoreTy) :
    BuiltinArgs P B Ψ pathBasesName pathBases [] [] [] []
      .pathBases (Eff.single processEnvironmentEff) := by
  have hi : SignatureInstance P [] [] (Tel.instR [] pathBases.tel) [] [] [] := by
    refine ⟨?_,(by intro a ha; cases ha),⟨rfl,(by intro i a k ha; cases ha)⟩,
      (by intro e he; cases he),(by intro e he; cases he),?_⟩
    · exact ((ModelHttp.sig_scoped hp (b := pathBasesName) rfl).inst (rs := []) rfl).2.2.2.wf
    · rw [bases_instantiated]; exact bases_annotation P
  refine ⟨?_,?_,hi,?_,(by intro w hw; cases hw),
    (by intro t ht; cases ht),(by intro e he; cases he),⟨trivial,rfl⟩,?_⟩
  · refine ⟨rfl,rfl,(by intro t ht; cases ht),rfl,(by intro e he; cases he),?_,?_,?_,?_⟩
    · simp [pathBases,Eff.RowsIn,Ty.RowsInList,Eff.single]
    · simp [pathBases,Qsig,QTys,QTy,QEff,Qempty,Eff.single]
    · simp [pathBases,RowTransport,Qsig,QTys,QTy,QEff,Qempty,Eff.single]
    · simp [pathBases,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.single]
  · exact ⟨rfl,(by intro i r k h; cases h),(by intro r h; cases h),
      Or.inl (by intro r h; cases h)⟩
  · rw [bases_instantiated]; exact .done (bases_annotation P)
  · exact ⟨by simp [Eff.WF,Eff.single,Ty.WFList],
      by simp [Eff.Canonical,Eff.norm,Eff.single]⟩


/-- 空引数の型付き発行から、同じ環境の発行事象と At の束縛へ渡す。 -/
example (P : Program) (hp : HasHttp P) (Ψ : StoreTy) (σ : PathEnv) (hσ : σ.Valid)
    (kind name shape pattern input index) :
    HasTypeCQ P B Ψ Qempty [] [] [] none
      (.app (.prim pathBasesName [] [] []) []) .pathBases (Eff.single processEnvironmentEff) [] ∧
    (let body := Comp.checkAt kind name shape (some (.var 0)) pattern input index
     Steps P B σ
       (.run (Closure.pure (.letIn (.app (.prim pathBasesName [] [] []) []) body)) [] Store.empty)
       [.pathBases pathBasesName σ]
       (.run ((Closure.pure body).apply [.pathBases σ]) [] Store.empty)) := by
  have args := bases_arguments P hp Ψ
  constructor
  · exact .C_DependentApp (.V_Prim rfl args.ranges (ModelHttp.sig_scoped hp (b := pathBasesName) rfl).names
      args.admissible args.signature) args.arguments
  · dsimp
    let body := Comp.checkAt kind name shape (some (.var 0)) pattern input index
    have first : Step P B σ
        (.run (Closure.pure (.app (.prim pathBasesName [] [] []) [])) [.letF (Closure.pure body)] Store.empty)
        none (.run (Closure.pure (.issuePathBases pathBasesName)) [.letF (Closure.pure body)] Store.empty) :=
      .E_PathBasesApply rfl rfl rfl (by simp [NoHandler])
    have issued : Step P B σ
        (.run (Closure.pure (.issuePathBases pathBasesName)) [.letF (Closure.pure body)] Store.empty)
        (some (.pathBases pathBasesName σ))
        (.run (Closure.pure (.ret (.pathBases σ))) [.letF (Closure.pure body)] Store.empty) :=
      .E_IssuePathBases rfl rfl rfl rfl hσ
    exact .cons (.E_Let rfl) (.cons first (.cons issued (.cons (.E_Return rfl) .nil)))

end
end Benitoite.Release.Refinement.ModelHttpApplications
