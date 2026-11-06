import Benitoite.Release.Refinement.ModelTargets

/-! # パス操作モデルの実引数と三つの観測の形 -/
namespace Benitoite.Release.Refinement.ModelTargetsApplications
noncomputable section
open Scope.Domain ScopeSignatures ScopeDeclarations ScopedIOResponse

private def range (wide : Bool) : RangeExpr :=
  .absolute (if wide then .top else .path (.tree ["data"]))
private def target : Target := .path ["data","a"]
private def result : Ty := .data "Result" [.base .string,.opaque "IOError" .top]
private def effect (wide : Bool) : Eff :=
  .mk (fun a => decide (a = .name "File.Read" (.fixed (range wide)))) []
private def B : Builtins := ModelTargets.builtins

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
    ModelTargets.io_op rfl (Or.inl rfl)
  have had : ∀ w ∈ [Val.checked target], w.Adequate σ := by simp [Val.Adequate]
  have raw : ioResponse "File.readTextIn" [] [] [.checked target]
      (.val (ScopeDelta.resultValue false (.base .string) (.opaque "IOError" .top)
        (.const (.opaque "IOError" 0)))) [target] :=
    ⟨.readText,rfl,rfl,rfl,.error 0,target,rfl,rfl,rfl,by intro h; cases h⟩
  have hr : B.ioResponse "File.readTextIn" [] [] [.checked target]
      (.val (ScopeDelta.resultValue false (.base .string) (.opaque "IOError" .top)
        (.const (.opaque "IOError" 0)))) [target] :=
    Or.inl ⟨.readText,by decide,rfl,raw⟩
  have membership := shape.single_target rfl names args had
  obtain ⟨l,hl,allowed⟩ := ModelTargets.obs_allowed program_hasHttp.file rfl (Or.inl rfl) args had hr
  have eq : l = "File.Read" := Option.some.inj hl.symm
  subst l
  exact ⟨names,rfl,shape,args,had,ModelTargets.targetAgreement program,hr,membership,allowed⟩


private inductive LegacyOp where
  | print | exit | read

private def LegacyOp.name : LegacyOp → PrimName
  | .print => "print" | .exit => "exit" | .read => "File.readText"
private def LegacyOp.signature : LegacyOp → PrimSig
  | .print => ModelTargets.printSig | .exit => ModelTargets.exitSig | .read => ModelTargets.readTextSig
private def LegacyOp.input (op : LegacyOp) (raw : String) (code : Integer64Value) : Val :=
  match op with | .exit => .const (.integer code) | _ => .const (.string raw)

private theorem legacy_lookup (op : LegacyOp) : B.sig op.name = some op.signature := by
  cases op <;> rfl

private theorem legacy_instantiated (op : LegacyOp) :
    instantiatedTel (Tel.instR [] op.signature.tel) [] [] = op.signature.tel := by
  have atoms (l : EffName) : mapRangeAtoms (rangeAt 0 [])
      (fun a => decide (a = .name l .top)) = (fun a => decide (a = .name l .top)) := by
    funext a; simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  cases op <;> simp [LegacyOp.signature,ModelTargets.printSig,ModelTargets.exitSig,
    ModelTargets.readTextSig,unscopedIO,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.shiftV,Eff.norm,Eff.single,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,mapIx,RangeIx.inst,atoms]

private theorem legacy_annotation (op : LegacyOp) (Γ : Ctx) :
    Ty.Annotation program [] Γ (.dependentFn op.signature.tel) := by
  have ar := (program_hasHttp.file ScopeDeclarations.result (by simp [file])).1
  change program.DataArity "Result" 2 at ar
  cases op
  all_goals constructor
  all_goals simp [LegacyOp.signature,ModelTargets.printSig,ModelTargets.exitSig,
    ModelTargets.readTextSig,unscopedIO,PrimSig.tel,signatureTel,
    Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,
    Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,Ty.Declared,Tel.Declared,declaredTys,declaredEff,ar]

/-- File.readText・print・exit に、実表の単一の定数引数から全 BuiltinArgs を供給する。 -/
private theorem legacy_arguments (op : LegacyOp) (raw : String) (code : Integer64Value) (Ψ : StoreTy) :
    BuiltinArgs program B Ψ op.name op.signature [] [] [] [op.input raw code]
      op.signature.ret op.signature.eff := by
  have nr : op.signature.rkinds = [] := by cases op <;> rfl
  have nt : op.signature.tparams = [] := by cases op <;> rfl
  have ne : op.signature.neffs = 0 := by cases op <;> rfl
  have hi : SignatureInstance program [] [] (Tel.instR [] op.signature.tel) [] [] [] := by
    refine ⟨?_,(by intro a ha; cases ha),⟨rfl,by intro i a k ha; cases ha⟩,
      (by intro e he; cases he),(by intro e he; cases he),?_⟩
    · have h := ((ModelTargets.sig_scoped program_hasHttp.file (legacy_lookup op)).inst
          (rs := []) (by rw [nr]; rfl)).2.2.2.wf
      simpa only [nt,List.length_nil] using h
    · rw [legacy_instantiated]; exact legacy_annotation op []
  refine ⟨?_,?_,?_,?_,?_,(by intro t ht; cases ht),(by intro e he; cases he),?_,?_⟩
  · refine ⟨by rw [nt]; rfl,?_,(by intro t ht; cases ht),ne.symm,
      (by intro e he; cases he),?_,?_,?_,?_⟩
    · cases op <;> rfl
    · cases op <;> simp [LegacyOp.signature,ModelTargets.printSig,ModelTargets.exitSig,
        ModelTargets.readTextSig,unscopedIO,Eff.RowsIn,Ty.RowsInList,Eff.single]
    · cases op <;> simp [LegacyOp.signature,ModelTargets.printSig,ModelTargets.exitSig,
        ModelTargets.readTextSig,unscopedIO,Qsig,QTys,QTy,QEff,Qempty,Eff.single]
    · cases op <;> simp [LegacyOp.signature,ModelTargets.printSig,ModelTargets.exitSig,
        ModelTargets.readTextSig,unscopedIO,RowTransport,Qsig,QTys,QTy,QEff,Qempty,Eff.single]
    · simpa only [ne,List.length_nil] using ModelTargets.sourceTelRows program_hasHttp.file (legacy_lookup op)
  · exact ⟨by rw [nr]; rfl,(by intro i r k h; cases h),(by intro r h; cases h),
      Or.inl (by intro r h; cases h)⟩
  · simpa only [nt,List.map_nil] using hi
  · rw [legacy_instantiated]
    cases op
    all_goals refine .param ⟨trivial,trivial,trivial⟩ (.V_Const trivial) ?_
    all_goals simp only [LegacyOp.signature,LegacyOp.input,ModelTargets.printSig,ModelTargets.exitSig,
      ModelTargets.readTextSig,unscopedIO,signatureTel,Tel.bind_done]
    all_goals simp only [Ty.bind,Ty.rawBind,rawBindTys,Ty.norm,Ty.normTys,
      Eff.bind,Eff.rawBind,Eff.single,Eff.norm,Tel.argumentsEnv,valEnv,
      substAtoms_nil,instAtoms_nil,rowFails,RangeIx.inst]
    all_goals apply HasTypeTelArgsQ.done
    all_goals have ar := (program_hasHttp.file ScopeDeclarations.result (by simp [file])).1
    all_goals change program.DataArity "Result" 2 at ar
    all_goals constructor
    all_goals simp [Ty.WF,Tel.WF,Ty.WFList,RangeIx.WF,Eff.WF,Eff.Canonical,Eff.norm,
      Ty.Sorted,Tel.Sorted,sortedTys,sortedEff,Ty.Declared,Tel.Declared,declaredTys,declaredEff,ar]
  · intro w hw; simp only [List.mem_singleton] at hw; subst w; cases op <;> trivial
  · cases op <;> exact ⟨by simp [LegacyOp.signature,ModelTargets.printSig,ModelTargets.exitSig,
      ModelTargets.readTextSig,unscopedIO,Ty.WF,Ty.WFList,RangeIx.WF],rfl⟩
  · cases op <;> exact ⟨by simp [LegacyOp.signature,ModelTargets.printSig,ModelTargets.exitSig,
      ModelTargets.readTextSig,unscopedIO,Eff.WF,Eff.single,Ty.WFList],
      by simp [LegacyOp.signature,ModelTargets.printSig,ModelTargets.exitSig,
        ModelTargets.readTextSig,unscopedIO,Eff.Canonical,Eff.norm,Eff.single]⟩

/-- File.readText・print・exit の実引数から、存在・型・適格性・種類・同じ環境での許容を読む。 -/
example (raw : String) (code : Integer64Value) (Ψ : StoreTy) (σ : PathEnv) :
    ∀ op : LegacyOp, ∃ out obs,
      BuiltinArgs program B Ψ op.name op.signature [] [] [] [op.input raw code]
        op.signature.ret op.signature.eff ∧
      B.ioResponse op.name [] [] [op.input raw code] out obs ∧
      Outcome.Typed program B Ψ out op.signature.ret ∧ AdequateResult [op.input raw code] out ∧
      ((op.signature.kind = .io ∧ ∀ n, out ≠ .exit n) ∨
        (op.signature.kind = .exit ∧ ∀ v, out ≠ .val v)) ∧
      ∃ l, op.signature.opEff = some l ∧
        ∀ t ∈ obs, Eff.Allows σ B.effKind op.signature.eff l t := by
  intro op
  have args := legacy_arguments op raw code Ψ
  have kind : op.signature.kind = .io ∨ op.signature.kind = .exit := by
    cases op <;> first | exact Or.inl rfl | exact Or.inr rfl
  have had : ∀ w ∈ [op.input raw code], w.Adequate σ := by
    intro w hw; cases List.mem_singleton.mp hw; cases op <;> trivial
  obtain ⟨out,obs,hr⟩ := ModelTargets.io_exists program_hasHttp.file (legacy_lookup op) kind args
  obtain ⟨ht,ha⟩ := ModelTargets.io_typed program_hasHttp.file (legacy_lookup op) kind args hr
  exact ⟨out,obs,args,hr,ht,ha,ModelTargets.io_kind (legacy_lookup op) args hr,
    ModelTargets.obs_allowed program_hasHttp.file (legacy_lookup op) kind args had hr⟩

/-- File.readText は裸の String と Top の効果を保ち、観測は空でない場合がある。 -/
example (text : String) :
    ModelTargets.readTextSig.shape = .topTargeted .path ∧
    ModelTargets.readTextSig.rkinds = [] ∧
    ModelTargets.readTextSig.params = [.base .string] ∧
    B.ioResponse "File.readText" [] [] [.const (.string "/")]
      (.val (ScopeDelta.resultValue true (.base .string) (.opaque "IOError" .top)
        (.const (.string text)))) [.path []] := by
  refine ⟨rfl,rfl,rfl,Or.inr (Or.inr (Or.inr ⟨rfl,.ok (.text text),?_⟩))⟩
  simp [ModelTargets.readObs,ScopeLegacyContracts.pathInput,parseAtInput,parseTargetInput]

/-- 全ての型付き exit 応答は、val を返さない。 -/
example (code : Integer64Value) (Ψ : StoreTy) {out obs}
    (hr : B.ioResponse "exit" [] [] [.const (.integer code)] out obs) :
    (∃ out obs, B.ioResponse "exit" [] [] [.const (.integer code)] out obs) ∧
      ∀ v, out ≠ .val v := by
  have args := legacy_arguments .exit "" code Ψ
  have kind := ModelTargets.io_kind (legacy_lookup .exit) args hr
  exact ⟨ModelTargets.io_exists program_hasHttp.file (legacy_lookup .exit) (Or.inr rfl) args,
    (kind.resolve_left (by simp [LegacyOp.signature,ModelTargets.exitSig,unscopedIO])).2⟩

/-- 絶対形のチェックは、動的条件と静的上限の双方の成功を実表の Ok に写す。 -/
example {pattern target p t checked bound}
    (hp : ScopeDelta.parsePattern pattern = some p)
    (ht : parseAtInput .path (.const (.string target)) = some (.absolute (.path t)))
    (hd : Checked.Scope.makePath p t = .ok checked)
    (hm : Range.MemK .path bound (.path t)) :
    B.delta "Scope.checkPathIn" [] [] [.absolute bound]
      [.const (.string pattern),.const (.string target)] =
        some (ScopeDelta.ok (.absolute bound) (.checked (.path t))) := by
  simpa [B,ModelTargets.builtins,ScopeSignatures.builtins,ScopeResponse.delta,ScopeDelta.delta,hd,hm]
    using congrArg some (ScopeDelta.run_absolute hp ht (.absolute bound))

/-- 相対形・home 形は Top でも Error となり、δ の未定義に写さない。 -/
example {pattern target p w} (hp : ScopeDelta.parsePattern pattern = some p)
    (ht : parseAtInput .path (.const (.string target)) = some (.relativePath w) ∨
      parseAtInput .path (.const (.string target)) = some (.homePath w)) (r : RangeExpr) :
    B.delta "Scope.checkPathIn" [] [] [r] [.const (.string pattern),.const (.string target)] =
      some (ScopeDelta.error r (ScopeDelta.invalidTarget target ScopeDelta.text.PATH)) := by
  simpa [B,ModelTargets.builtins,ScopeSignatures.builtins,ScopeResponse.delta,ScopeDelta.delta]
    using congrArg some ((ScopeDelta.input_errors hp r).1 w ht)

/-- 同じ保持値を拡大し、射影では元の絶対対象から同じ文字列を得る。 -/
example (r s : RangeExpr) (snap : Option PathEnv) (w : Word) :
    B.delta "Scope.widenPathIn" [] [] [r,s] [.checkedAt r snap (.path w) none] =
      some (.val (.checkedAt r snap (.path w) none)) ∧
    B.delta "Scope.pathInValue" [] [] [s] [.checkedAt r snap (.path w) none] =
      some (.val (.const (.string ("/" ++ String.intercalate "/" w)))) := by
  simp [B,ModelTargets.builtins,ScopeSignatures.builtins,ScopeResponse.delta,
    ScopeDelta.valueDelta,ScopeDelta.widenRun,ScopeDelta.pathValueRun,Val.target?]

/-- 同じ実表は担当の全条件を満たし、発行を IO 応答に混ぜない。 -/
example : ModelScopeConditions program B ∧
    (∃ bs, B.effects processEnvironmentEff = some bs ∧ pathBasesName ∈ bs) ∧
    ∀ ts es ws out obs, ¬ B.ioResponse pathBasesName ts es ws out obs := by
  refine ⟨ModelTargets.scopeConditions program program_hasHttp.file,
    (ModelTargets.pathBases_shape (b := pathBasesName) rfl rfl).membership,?_⟩
  intro ts es ws out obs hr
  rcases hr with ⟨op,_,hn,_⟩ | ⟨hn,_⟩ | ⟨hn,_⟩ | ⟨hn,_⟩
  · cases op <;> simp [pathBasesName,ScopedIOResponse.Operation.name] at hn
  all_goals simp [pathBasesName] at hn

end
end Benitoite.Release.Refinement.ModelTargetsApplications
