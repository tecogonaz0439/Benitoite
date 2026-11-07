import Benitoite.Release.Refinement.SurfaceTargetObservedExamples

/-!
# 範囲付きの上限での一段と到達先の対象健全性の具体例

標準の型の宣言を収集した表層のプログラムを脱糖した核のプログラムと、範囲付きのパス操作を持つ実例の表
（`ExternalModels.targets`）の上で、次を確かめる（設計書 01-12「確かめる性質」、07-04「証明する性質」）。

- 上限 `{File.Write["/data/**"], File.Read}` は `File.Read` の名前で `/etc/passwd` を許し、名前を落とした形
  （`∃ l, …`）も満たす。しかし `File.Write` の名前では許さないので、この上限を末尾に持つ型の付いた状態から、
  観測に `/etc/passwd` を含む書き込みの事象の遷移はない（`no_write_event_passwd`。一段の対象健全性）。
- 範囲付きの読取り `File.readTextIn["/data/**"](checked(/data/a.txt))` を効果 `{File.Read["/data/**"]}` で型付けた閉包から
  始めた実行が到達したどの読取りの事象も `/etc/passwd` を観測しない（`readCall_no_passwd`。到達先の対象健全性）。
  この閉包は一段で、観測 `/data/a.txt` を持つ読取りの事象へ進む（`readCall_observed`）。
-/
namespace Benitoite.Release.Refinement.Surface.TargetStepExamples
noncomputable section
open StandardModel TargetObservedExamples Scope.Domain

/-- `/data/**`。 -/
def dataRange : RangeExpr := .absolute (.path (.tree ["data"]))
/-- `/etc/passwd`。 -/
def passwd : Target := .path ["etc", "passwd"]
/-- `/data/a.txt`。 -/
def dataTarget : Target := .path ["data", "a.txt"]

/-- 上限 `{File.Write["/data/**"], File.Read}`。 -/
def writeReadBound : Eff :=
  .mk (fun a => decide (a = .name "File.Write" (.fixed dataRange)) || decide (a = .name "File.Read" .top)) []

/-- 対象の環境。 -/
abbrev σ0 : PathEnv := TargetReachExamples.environment

/-- 名前を落とすと上限は `/etc/passwd` を許す（`File.Read` の名前で許す）。 -/
theorem passwd_read_allowed (p : String) :
    Eff.Allows σ0 (table p).effKind writeReadBound "File.Read" passwd ∧
      ∃ l, Eff.Allows σ0 (table p).effKind writeReadBound l passwd := by
  have h : Eff.Allows σ0 (table p).effKind writeReadBound "File.Read" passwd :=
    ⟨.path, .absolute .top, rfl, by simp [writeReadBound, Eff.mem, Eff.test, Eff.atoms, RangeIx.top],
      by simp [RangeExpr.Mem, RangeExpr.resolve, Range.Mem, passwd, Target.kind]⟩
  exact ⟨h, _, h⟩

/-- `File.Write` の名前では、上限は `/etc/passwd` を許さない。 -/
theorem passwd_write_not_allowed (κ : EffName → Option Kind) :
    ¬ Eff.Allows σ0 κ writeReadBound "File.Write" passwd := by
  rintro ⟨k, r, -, hm, ht⟩
  simp [writeReadBound, Eff.mem, Eff.test, Eff.atoms] at hm
  subst hm
  revert ht
  simp [dataRange, passwd, RangeExpr.Mem, RangeExpr.resolve, Range.Mem, PathPattern.Matches]

theorem program_facts (p : String) :
    (core p).WellFormed ∧ (core p).WellTyped (table p) ∧ (core p).EffectsOk (table p) ∧
      (table p).CoreAssumptions (core p) ∧ (table p).TargetAgreement (core p) := by
  have hc := ExternalModels.targets_core _ (hasFile p)
  obtain ⟨hf, hp, he⟩ := desugar_typed (wellFormed p) (wellTyped p) hc.values
  exact ⟨hf, hp, he, hc, (ExternalModels.targets_scope _ (hasFile _)).toTargetAgreement⟩

theorem sig_write (p : String) : (table p).sig "File.writeTextIn" = some ScopeSignatures.writeTextIn := rfl
theorem sig_read (p : String) : (table p).sig "File.readTextIn" = some ScopeSignatures.readTextIn := rfl

/-- 一段の対象健全性から: 末尾に `{File.Write["/data/**"], File.Read}` を持つどの型付きの状態からも、観測に
`/etc/passwd` を含む書き込みの事象の遷移はない。 -/
theorem no_write_event_passwd (p : String) {s s' : State} {ws : List Val} {o : Outcome} {obs : List Target}
    (hs : StateTyE (core p) (table p) σ0 writeReadBound s) (hobs : passwd ∈ obs) :
    ¬ Step (core p) (table p) σ0 s (some (.io "File.writeTextIn" ws o obs)) s' := by
  intro hst
  obtain ⟨hf, hp, he, hc, ht⟩ := program_facts p
  obtain ⟨e, l, hsig, hop, hall⟩ := step_target_sound _ _ _ hf hp he hc ht
    (TargetReachExamples.ready |>.1) _ _ _ _ _ _ _ hs hst
  rw [sig_write] at hsig
  cases hsig
  simp [ScopeSignatures.writeTextIn, ScopeSignatures.ioIn] at hop
  subst hop
  exact passwd_write_not_allowed _ (hall passwd hobs)


/-! ## 範囲付きの読取りの閉包 -/

/-- 読取りの結果型。 -/
abbrev readResult : Ty := .data "Result" [.base .string, .opaque "IOError" .top]
/-- 効果 `{File.Read["/data/**"]}`。 -/
def readBound : Eff := .mk (fun a => decide (a = .name "File.Read" (.fixed dataRange))) []
/-- `File.readTextIn["/data/**"](checked(/data/a.txt))`。 -/
def readComp : Comp := .app (.prim "File.readTextIn" [] [] [.fixed dataRange]) [.checked dataTarget]
/-- 開始の閉包。 -/
def readClosure : Closure := Closure.pure readComp

private theorem instantiated :
    instantiatedTel (Tel.instR [dataRange] ScopeSignatures.readTextIn.tel) [] [] =
      .param "path" (.opaque "Scope.PathIn" (.fixed dataRange)) (.done readResult readBound) := by
  have atoms : mapRangeAtoms (rangeAt 0 [dataRange])
      (fun a => decide (a = .name "File.Read" (.rvar 0))) =
      (fun a => decide (a = .name "File.Read" (.fixed dataRange))) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,atoms,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,typeEnvAt,substAtoms_nil,instAtoms_nil,rowFails,readResult,readBound,
    RangeIx.inst,SubstEnv.up]

theorem result_annotation (p : String) (Γ : Ctx) : Ty.Annotation (core p) [] Γ readResult := by
  have ar := ((hasFile p) ScopeDeclarations.result (by simp [ScopeDeclarations.file])).1
  exact ⟨by trivial,by trivial,⟨⟨2,ar,rfl⟩,by trivial⟩⟩

private theorem arguments (p : String) (Ψ : StoreTy) :
    BuiltinArgs (core p) (table p) Ψ "File.readTextIn" ScopeSignatures.readTextIn [] [] [dataRange]
      [.checked dataTarget] readResult readBound := by
  constructor
  · constructor
    · rfl
    · rfl
    · simp
    · rfl
    · simp
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,Eff.RowsIn,Ty.RowsInList]
    · intro i h; simp [Qsig,ScopeSignatures.readTextIn,ScopeSignatures.ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · intro i h; simp [Qsig,ScopeSignatures.readTextIn,ScopeSignatures.ioIn,QTys,QTy,QEff,Benitoite.Release.Qempty] at h
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,
        Ty.RowsInList,Eff.RowsIn]
  · refine ⟨rfl,?_,?_,Or.inr ⟨by simp, rfl⟩⟩
    · intro i r k hr hk
      cases i <;> simp at hr hk
      cases hr; cases hk
      decide
    · intro r hr; simp at hr; subst r
      exact ⟨by decide,by decide⟩
  · constructor
    · simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,
        Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
        Ty.WF,Ty.WFList,Tel.WF,Tel.norm,Ty.norm,Eff.norm,Eff.WF,Eff.Canonical,
        RangeIx.inst,RangeIx.WF]
    · simp [TypeAnnotations]
    · exact ⟨rfl,by intro i a k h; cases i <;> cases h⟩
    · simp [RowAnnotations]
    · simp
    · rw [instantiated]
      exact ⟨by trivial,by trivial,⟨trivial,(result_annotation p _).declared,trivial⟩⟩
  · rw [instantiated]
    refine .param ⟨trivial,trivial,trivial⟩
      (HasTypeVQ.checked_opaque rfl rfl (by decide)) ?_
    simp only [Tel.bind_done]
    have hb : readResult.bind (Tel.argumentsEnv (.checked dataTarget)) = readResult := by
      simp [readResult,Ty.bind,Ty.rawBind,rawBindTys,Ty.norm,Ty.normTys,RangeIx.inst]
    have he : Eff.bind (Tel.argumentsEnv (.checked dataTarget)) readBound = readBound := by
      simp [readBound,Eff.bind,Eff.rawBind,Tel.argumentsEnv,valEnv,Eff.norm,substAtoms_nil,instAtoms_nil,rowFails]
    rw [hb,he]
    exact .done ⟨⟨by trivial,by trivial⟩,⟨by trivial,by trivial⟩,
      ⟨(result_annotation p _).declared,trivial⟩⟩
  · intro w hw; simp at hw; subst w; trivial
  · simp
  · simp
  · exact ⟨by trivial,rfl⟩
  · exact ⟨by simp [readBound,Eff.WF,Ty.WFList,dataRange],rfl⟩

/-- 範囲付きの読取りの呼出しは効果 `{File.Read["/data/**"]}` で型付く。 -/
theorem readComp_typed (p : String) :
    HasTypeCQ (core p) (table p) StoreTy.empty Qempty [] [] [] none readComp readResult readBound [] :=
  have ha := arguments p StoreTy.empty
  .C_DependentApp (.V_Prim rfl ha.ranges (by simp [ScopeSignatures.readTextIn,ScopeSignatures.ioIn,NamesWF])
    ha.admissible ha.signature) ha.arguments

/-- 範囲付きの読取りの閉包は効果 `{File.Read["/data/**"]}` で型付く。 -/
theorem readClosure_typed (p : String) :
    ClosureTy (core p) (table p) StoreTy.empty [] none readClosure readResult readBound := by
  refine ClosureTy.pure (readComp_typed p) ⟨⟨(result_annotation p []).wf, ?_⟩, ⟨(result_annotation p []).sorted, ?_⟩,
    ⟨(result_annotation p []).declared, ?_⟩⟩ (by intro r h; cases h) rfl (by intro r h; cases h)
  · simp [readBound,Eff.WF,Ty.WFList,Eff.Canonical,Eff.norm]
  · simp [readBound,sortedEff,sortedTys]
  · simp [readBound,declaredEff,declaredTys]

/-- 開始の条件。 -/
theorem readClosure_start (p : String) : StartCondition (core p) (table p) σ0 readClosure := by
  refine StartCondition.of_noLamNames (readComp_typed p)
    (by simp [readComp,Comp.Adequate,Val.Adequate,adequateVals])
    (by simp [readComp,Comp.ClosedNoLamNames,Val.ClosedNoLamNames,Val.ClosedNoLamNamesList]; decide) ⟨?_⟩
  refine ⟨by simp [PathEnv.Valid,TargetReachExamples.environment,Scope.Domain.PathWordWF], ?_⟩
  intro r _
  cases r with
  | base b => cases b <;> exact ⟨[],rfl⟩
  | secrets => rfl

/-- 到達先の対象健全性から: 範囲付きの読取りの閉包から始めた実行が到達したどの読取りの事象も `/etc/passwd` を
観測しない。 -/
theorem readCall_no_passwd (p : String) {evs : List Event} {s s' : State} {ws : List Val} {o : Outcome}
    {obs : List Target}
    (hsteps : Steps (core p) (table p) σ0 (.run readClosure [] Store.empty) evs s)
    (hst : Step (core p) (table p) σ0 s (some (.io "File.readTextIn" ws o obs)) s') : passwd ∉ obs := by
  intro hobs
  obtain ⟨hf, hp, he, hc, ht⟩ := program_facts p
  obtain ⟨e, l, hsig, hop, hall⟩ := reachable_target_sound _ _ _ hf hp he hc ht _ _ _
    (readClosure_typed p) (readClosure_start p) _ _ _ _ _ _ _ hsteps hst
  rw [sig_read] at hsig
  cases hsig
  simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn] at hop
  subst hop
  obtain ⟨k, r, -, hm, hmem⟩ := hall passwd hobs
  simp [readBound, Eff.mem, Eff.test, Eff.atoms] at hm
  subst hm
  revert hmem
  simp [dataRange, passwd, RangeExpr.Mem, RangeExpr.resolve, Range.Mem, PathPattern.Matches]


/-- 範囲付きの読取りの閉包は一段で、観測 `/data/a.txt` を持つ読取りの事象へ進む（読取りの失敗の応答）。 -/
theorem readCall_observed (p : String) :
    Step (core p) (table p) σ0 (.run readClosure [] Store.empty)
      (some (.io "File.readTextIn" [.checked dataTarget] (.err "IO") [dataTarget])) (.error ["IO"] [] Store.empty) :=
  .E_IOErr (rs := [dataRange]) rfl rfl (Or.inl rfl) (by simp [NoHandler])
    (Or.inl ⟨.readText, by decide, rfl, ⟨.readText, rfl, rfl, rfl, .err "IO", dataTarget, rfl, rfl, rfl,
      by intro h; cases h⟩⟩)

/-- 到達した事象の観測 `/data/a.txt` は、開始の効果 `{File.Read["/data/**"]}` が許す（前提が空疎でないこと）。 -/
theorem readCall_allowed (p : String) :
    Eff.Allows σ0 (table p).effKind readBound "File.Read" dataTarget := by
  obtain ⟨hf, hp, he, hc, ht⟩ := program_facts p
  obtain ⟨e, l, hsig, hop, hall⟩ := reachable_target_sound _ _ _ hf hp he hc ht _ _ _
    (readClosure_typed p) (readClosure_start p) [] _ _ _ _ _ _ .nil (readCall_observed p)
  rw [sig_read] at hsig
  cases hsig
  simp [ScopeSignatures.readTextIn, ScopeSignatures.ioIn] at hop
  subst hop
  exact hall dataTarget (List.mem_singleton_self _)

end
end Benitoite.Release.Refinement.Surface.TargetStepExamples
