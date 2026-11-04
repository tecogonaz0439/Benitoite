import Benitoite.Release.Refinement.ScopedIOResponse

/-! # 実際の範囲付き IO 表への型付き適用 -/
namespace Benitoite.Release.Refinement.ScopedIOExamples
noncomputable section
open Scope.Domain ScopeSignatures ScopeDeclarations ScopedIOResponse

private def range (wide : Bool) : RangeExpr :=
  .absolute (if wide then .top else .path (.tree ["data"]))
private def target : Target := .path ["data","a"]
private def result : Ty := .data "Result" [.base .string,.opaque "IOError" .top]
private def effect (wide : Bool) : Eff :=
  .mk (fun a => decide (a = .name "File.Read" (.fixed (range wide)))) []
private def B : Builtins := builtins ScopeResponse.delta ioResponse

private theorem instantiated (wide : Bool) :
    instantiatedTel (Tel.instR [range wide] ScopeSignatures.readTextIn.tel) [] [] =
      .param "path" (.opaque "Scope.PathIn" (.fixed (range wide))) (.done result (effect wide)) := by
  have atoms : mapRangeAtoms (rangeAt 0 [range wide])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" (.fixed (range wide)))) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  simp [ScopeSignatures.readTextIn,ioIn,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
    Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,atoms,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,result,effect,
    RangeIx.inst,SubstEnv.up]

private theorem result_annotation (Γ : Ctx) : Ty.Annotation program [] Γ result := by
  have ar := (program_hasHttp.file ScopeDeclarations.result (by simp [file])).1
  exact ⟨by trivial,by trivial,⟨⟨2,ar,rfl⟩,by trivial⟩⟩

private theorem arguments (wide : Bool) (Ψ : StoreTy) :
    BuiltinArgs program B Ψ "File.readTextIn" ScopeSignatures.readTextIn [] [] [range wide]
      [.checked target] result (effect wide) := by
  constructor
  · constructor
    · rfl
    · rfl
    · simp
    · rfl
    · simp
    · simp [ScopeSignatures.readTextIn,ioIn,Eff.RowsIn,Ty.RowsInList]
    · intro i h; simp [Qsig,ScopeSignatures.readTextIn,ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · intro i h; simp [Qsig,ScopeSignatures.readTextIn,ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · simp [ScopeSignatures.readTextIn,ioIn,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn]
  · refine ⟨rfl,?_,?_,Or.inr ⟨by simp, rfl⟩⟩
    · intro i r k hr hk
      cases i <;> simp at hr hk
      cases hr; cases hk
      cases wide <;> decide
    · intro r hr; simp at hr; subst r
      cases wide <;> exact ⟨by decide,by decide⟩
  · constructor
    · simp [ScopeSignatures.readTextIn,ioIn,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
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
      (HasTypeVQ.checked_opaque rfl rfl (by cases wide <;> decide)) ?_
    simp only [Tel.bind_done]
    have hb : result.bind (Tel.argumentsEnv (.checked target)) = result := by
      simp [result,Ty.bind,Ty.rawBind,rawBindTys,Tel.argumentsEnv,Ty.norm,Ty.normTys,RangeIx.inst]
    have he : Eff.bind (Tel.argumentsEnv (.checked target)) (effect wide) = effect wide := by
      simp [effect,Eff.bind,Eff.rawBind,Tel.argumentsEnv,valEnv,Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]
    rw [hb,he]
    exact .done ⟨⟨by trivial,by trivial⟩,⟨by trivial,by trivial⟩,
      ⟨(result_annotation _).declared,trivial⟩⟩
  · intro w hw; simp at hw; subst w; trivial
  · simp
  · simp
  · exact ⟨by trivial,rfl⟩
  · exact ⟨by cases wide <;> simp [effect,Eff.WF,Ty.WFList,range],rfl⟩

/-- 非 Top と Top の両方で、実表の全前提と空でない観測を同時に満たす。 -/
example (wide : Bool) (Ψ : StoreTy) (σ : PathEnv) :
    NamesWF ScopeSignatures.readTextIn.names ScopeSignatures.readTextIn.params ∧
    B.sig "File.readTextIn" = some ScopeSignatures.readTextIn ∧
    B.ShapeOk "File.readTextIn" ScopeSignatures.readTextIn ∧
    BuiltinArgs program B Ψ "File.readTextIn" ScopeSignatures.readTextIn [] [] [range wide]
      [.checked target] result (effect wide) ∧
    (∀ w ∈ [Val.checked target], w.Adequate σ) ∧ B.TargetAgreement program ∧
    B.ioResponse "File.readTextIn" [] [] [.checked target]
      (.val (ScopeDelta.resultValue false (.base .string) (.opaque "IOError" .top)
        (.const (.opaque "IOError" 0)))) [target] ∧
    (∃ r t, [range wide] = [r] ∧ (([.checked target] : List Val)[0]?).bind Val.target? = some t ∧
      r.Mem σ .path t ∧ ScopeSignatures.readTextIn.shapeAt [.checked target] = .single .path 0) ∧
    ∀ t ∈ [target], Eff.Allows σ B.effKind (effect wide) "File.Read" t := by
  have names : NamesWF ScopeSignatures.readTextIn.names ScopeSignatures.readTextIn.params := by
    simp [ScopeSignatures.readTextIn,ioIn,NamesWF]
  have args := arguments wide Ψ
  have shape : B.ShapeOk "File.readTextIn" ScopeSignatures.readTextIn :=
    ScopeSignatures.io_op rfl (Or.inl rfl)
  have had : ∀ w ∈ [Val.checked target], w.Adequate σ := by simp [Val.Adequate]
  have raw : ioResponse "File.readTextIn" [] [] [.checked target]
      (.val (ScopeDelta.resultValue false (.base .string) (.opaque "IOError" .top)
        (.const (.opaque "IOError" 0)))) [target] :=
    ⟨.readText,rfl,rfl,rfl,.error 0,target,rfl,rfl,rfl,by intro h; cases h⟩
  have hr : B.ioResponse "File.readTextIn" [] [] [.checked target]
      (.val (ScopeDelta.resultValue false (.base .string) (.opaque "IOError" .top)
        (.const (.opaque "IOError" 0)))) [target] :=
    ⟨_,rfl,Or.inl rfl,raw⟩
  have membership := shape.single_target rfl names args had
  obtain ⟨l,hl,allowed⟩ := ScopedIOResponse.obs_allowed program_hasHttp rfl (Or.inl rfl) args had hr
  have eq : l = "File.Read" := Option.some.inj hl.symm
  subst l
  exact ⟨names,rfl,shape,args,had,targetAgreement program ScopeResponse.delta,hr,membership,allowed⟩

/-- 任意のストアと全適格環境で、七つの実名の存在・対象一致を同時に読む。 -/
example {Ψ b sg ts es rs ws a e σ}
    (hs : B.sig b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs program B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ out obs, B.ioResponse b ts es ws out obs ∧ Outcome.Typed program B Ψ out a ∧
      AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      ∃ k r t l, sg.shape = .single k 0 ∧ rs = [r] ∧ obs = [t] ∧
        (ws[0]?).bind Val.target? = some t ∧ r.Mem σ k t ∧
        sg.shapeAt ws = .single k 0 ∧ sg.opEff = some l ∧ Eff.Allows σ B.effKind e l t := by
  obtain ⟨out,obs,hr⟩ := io_exists program_hasHttp.file hs kind args
  obtain ⟨ht,ha⟩ := io_typed program_hasHttp.file hs kind args hr
  exact ⟨out,obs,hr,ht,ha,(io_kind hs hr).2,target_member program_hasHttp hs kind args had hr⟩

/-- 全ての応答条件を、同じ有限の P と実表で同時に供給する。 -/
example : B.ResponseAssumptions program ∧ B.TargetAgreement program :=
  ⟨responseAssumptions program_hasHttp,targetAgreement program ScopeResponse.delta⟩

/-- 読取りの成功値と実行時エラーも、Error と同じ保持パスを観測する。 -/
example (w : Word) (s : String) (bs : List Nat) (hb : ∀ b ∈ bs, b ≤ 255) (reason : String) :
    ioResponse "File.readTextIn" [] [] [.checked (.path w)]
      (.val (ScopeDelta.resultValue true (.base .string) (.opaque "IOError" .top) (.const (.string s)))) [.path w] ∧
    ioResponse "File.readBytesIn" [] [] [.checked (.path w)]
      (.val (ScopeDelta.resultValue true .bytes (.opaque "IOError" .top) (.bytesV bs))) [.path w] ∧
    ioResponse "File.readBytesIn" [] [] [.checked (.path w)] (.err reason) [.path w] :=
  ⟨⟨.readText,rfl,rfl,rfl,.ok (.text s),.path w,rfl,rfl,rfl,by intro h; cases h⟩,
    ⟨.readBytes,rfl,rfl,rfl,.ok (.bytes bs hb),.path w,rfl,rfl,rfl,by intro h; cases h⟩,
    ⟨.readBytes,rfl,rfl,rfl,.err reason,.path w,rfl,rfl,rfl,by intro h; cases h⟩⟩

/-- 送信の二つの保持経路は、同じ要求と endpoint を使う成功・Error・err を持つ。 -/
example (r : RangeExpr) (snap : Option PathEnv) (t : Target) (req : Val)
    (hg : groundVal req = true) (ht : req.reqTarget = some t) (id : Nat) (reason : String) :
    ioResponse "Http.sendIn" [] [] [.checkedRequest t req]
      (.val (ScopeDelta.resultValue true (.opaque "Http.Response" .top) (.opaque "NetworkError" .top)
        (.const (.opaque "Http.Response" id)))) [t] ∧
    ioResponse "Http.sendIn" [] [] [.checkedAt r snap t (some req)]
      (.val (ScopeDelta.resultValue false (.opaque "Http.Response" .top) (.opaque "NetworkError" .top)
        (.const (.opaque "NetworkError" id)))) [t] ∧
    ioResponse "Http.sendIn" [] [] [.checkedAt r snap t (some req)] (.err reason) [t] := by
  have hkind := Val.reqTarget_kind ht
  have plain : RequestSent .send [.checkedRequest t req] t :=
    fun _ => ⟨_,req,rfl,Or.inl rfl,ModelHttp.valueRun_checkedRequest hg,hg,ht⟩
  have atReply : RequestSent .send [.checkedAt r snap t (some req)] t :=
    fun _ => ⟨_,req,rfl,Or.inr ⟨r,snap,rfl⟩,ModelHttp.valueRun_checkedAt hg,hg,ht⟩
  exact ⟨⟨.send,rfl,rfl,rfl,.ok (.http id),t,rfl,hkind,rfl,plain⟩,
    ⟨.send,rfl,rfl,rfl,.error id,t,rfl,hkind,rfl,atReply⟩,
    ⟨.send,rfl,rfl,rfl,.err reason,t,rfl,hkind,rfl,atReply⟩⟩

/-- 観測は送信関係からも同じ reqTarget へ取り出せる。 -/
example {ts es ws out obs} (hr : ioResponse "Http.sendIn" ts es ws out obs) :
    ∃ w req t, ws = [w] ∧ ModelHttp.valueRun [w] = .val req ∧ groundVal req = true ∧
      req.reqTarget = some t ∧ w.target? = some t ∧ obs = [t] := sent_request hr

/-- 端点の不一致と、対象を持たない要求は送信関係に入らない。 -/
example (req : Val) (t : Target) (other : Target) (hne : t ≠ other)
    (hg : groundVal req = true) (ht : req.reqTarget = some t) :
    (∃ out, ioResponse "Http.sendIn" [] [] [.checkedRequest t req] out [t]) ∧
    ¬ (∃ out obs, ioResponse "Http.sendIn" [] [] [.checkedRequest other req] out obs) := by
  constructor
  · exact ⟨_,.send,rfl,rfl,rfl,.error 0,t,rfl,Val.reqTarget_kind ht,rfl,
      fun _ => ⟨_,req,rfl,Or.inl rfl,ModelHttp.valueRun_checkedRequest hg,hg,ht⟩⟩
  · rintro ⟨out,obs,hr⟩
    obtain ⟨w,q,u,hw,hq,_,hu,held,_⟩ := sent_request hr
    cases List.singleton_inj.mp hw
    have he : u = other := Option.some.inj held.symm
    subst u
    have run := ModelHttp.valueRun_checkedRequest (target := other) hg
    rw [run] at hq
    cases Outcome.val.inj hq
    exact hne (Option.some.inj (ht.symm.trans hu))

/-- 四つの書込み・追記は、同じパスと適切な内容を使う Unit の Ok を持つ。 -/
example (w : Word) (text : String) (bytes : List Nat) :
    ∀ op ∈ [Operation.writeText,.writeBytes,.appendText,.appendBytes],
      ioResponse op.name [] [] [.checked (.path w),
        if op = .writeText ∨ op = .appendText then .const (.string text) else .bytesV bytes]
        (.val (ScopeDelta.resultValue true (.base .unit) (.opaque "IOError" .top) (.const .unit))) [.path w] := by
  intro op member
  simp only [List.mem_cons,List.not_mem_nil,or_false] at member
  rcases member with rfl | rfl | rfl | rfl
  all_goals exact ⟨_,rfl,rfl,rfl,.ok .unit,.path w,rfl,rfl,rfl,by intro h; cases h⟩

/-- 要求を持たない保持対象は、送信の関係からも拒否する。 -/
example (t : Target) (ts : List Ty) (es : List Eff) (out : Outcome) (obs : List Target) :
    ¬ ioResponse "Http.sendIn" ts es [.checked t] out obs := by
  rintro ⟨op,hn,_,_,_,u,_,_,_,sent⟩
  have eq : op = .send := by cases op <;> simp only [Operation.name] at hn <;> first | rfl | contradiction
  subst op
  obtain ⟨w,req,hw,form,_⟩ := sent rfl
  cases List.singleton_inj.mp hw
  rcases form with form | ⟨r,snap,form⟩ <;> cases form

end
end Benitoite.Release.Refinement.ScopedIOExamples
