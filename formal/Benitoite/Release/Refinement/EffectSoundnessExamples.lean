import Benitoite.Release.Refinement.MainEffects
import Benitoite.Release.Refinement.OperationStateExamples

/-! # 起点発行の効果を残す型付けと、空の効果の拒否 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace EffectSoundnessExamples

open ScopeSignatures

/-- 宣言を持たないプログラム。 -/
def program : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

/-- すべての起点と secrets を束縛する σ。 -/
def σFull : PathEnv := ⟨[],[],[],some [],some [],some []⟩

def clauses : List Clause := [.mk (.prim pathBasesName) 0 0 (.ret (.const .unit))]
def body : Comp := .letIn (.issuePathBases pathBasesName) (.ret (.const .unit))
def start : Closure := Closure.pure (.handle body clauses)

theorem valid : σFull.Valid := by
  simp [PathEnv.Valid,σFull,Scope.Domain.PathWordWF]

theorem wellFormed : program.WellFormed where
  defs := by intro f d h; cases h
  cons := by intro c cd h; cases h
  ops := by intro o od h; cases h
  classes := by intro cl cd h; cases h
  impls := by intro i id h; cases h
  metadata := by intro d info h; cases h
  external := ⟨by simp [program],by intro key decl h; cases h⟩

theorem wellTyped : program.WellTyped Model.builtins where
  variance := ⟨(by intro d info h; cases h),(by intro c cd h; cases h)⟩
  external := ⟨by simp [program],by intro key decl h; cases h⟩
  defs := by intro f d h; cases h
  impls := by intro i id h; cases h

theorem effectsOk : program.EffectsOk Model.builtins :=
  ⟨by intro l os o h; simp [program] at h,by intro o od h; simp [program] at h,
    by intro l os h; simp [program] at h⟩

theorem core : Model.builtins.CoreAssumptions program :=
  (Model.scopeConditions program).core
    ⟨by intro _ _ _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,program] at h,
      by intro _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,program] at h,
      by intro _ _ _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,program] at h⟩
    (by intro Ψ v o _ h; cases h)

theorem sig : Model.builtins.sig pathBasesName = some pathBases := rfl

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e :=
  ⟨by intro a ha; simp [Eff.empty,Eff.mem,Eff.test,Eff.atoms] at ha,
    by intro t ht; obtain ⟨u,hu,_⟩ := ht; simp [Eff.empty,Eff.fails] at hu⟩

/-- 発行を含む保護本体の効果は、同じ節で空へ除けない。 -/
theorem handled_environment_rejected :
    ¬ Eff.Sub (Eff.single processEnvironmentEff) (Eff.union Eff.empty (handled program Model.builtins clauses)) := by
  intro hsub
  have hm : (Eff.single processEnvironmentEff).mem (.name processEnvironmentEff (.fixed .top)) := by
    simp [Eff.single,Eff.mem,Eff.test,Eff.atoms]
  rcases (Eff.mem_union_iff _ _ _).mp (hsub.1 _ hm) with he | he
  · cases he
  · exact core.pathBases_never_handled effectsOk sig rfl he

/-- 開始の閉包は発行の効果を保って型が付く。 -/
theorem typed_environment : ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) (Eff.single processEnvironmentEff) := by
  have ha : Ty.Annotation program [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hissue : HasTypeC program Model.builtins StoreTy.empty [] [] [] none (.issuePathBases pathBasesName)
      .pathBases (Eff.single processEnvironmentEff) :=
    core.issuePathBases_typed sig rfl
  have hbody : HasTypeC program Model.builtins StoreTy.empty [] [] [] none body (.base .unit)
      (Eff.single processEnvironmentEff) :=
    .C_Let hissue (.C_Eff (.C_Return (.V_Const (c := .unit) (by trivial))) (empty_sub _).covers) (by trivial)
  let sg : OpSig := ⟨[],[],[],.pathBases,processEnvironmentEff⟩
  have hcs : HasTypeClauses program Model.builtins StoreTy.empty [] [] [] none
      (Eff.single processEnvironmentEff) clauses (.base .unit) (Eff.single processEnvironmentEff) := by
    refine .cons (sg := sg) (ClauseSig.of_opSig ?_ ?_) (by trivial) rfl rfl (by trivial) ?_ .nil
    · simp [opSig,opSigAt,sig,pathBases,sg]
    · intro b s ho hs
      cases ho
      cases Option.some.inj (hs.symm.trans sig)
      simp [pathBases,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.single]
    · exact .C_Eff (.C_Return (.V_Const (by trivial))) (empty_sub _).covers
  have hann : Ty.Annotation program [] [] (.dependentFn (.done (.base .unit) (Eff.single processEnvironmentEff))) :=
    ⟨by simp [Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.normTys],by trivial,by trivial⟩
  exact ClosureTy.pure (.C_Handle hbody
    ⟨fun a ha => (Eff.mem_union_iff _ _ _).mpr (.inl ha),
      fun a ha => (Eff.memFail_union_iff _ _ _).mpr (.inl ha)⟩ hcs) hann
    (by intro r hr; cases hr) rfl (by intro r hr; cases hr)

/-- 開始の条件を満たす。σ がすべての起点と secrets を束縛するので、必要な束縛は辿り方によらない。 -/
theorem startCondition : StartCondition program Model.builtins σFull start := by
  refine ⟨by simp [start,Closure.pure,body,clauses,Closure.Adequate,Comp.Adequate,adequateClauses,
      Capture.Adequate,adequateCaptureSlots,Capture.empty,Val.Adequate],
    by simp [start,Closure.pure,body,clauses,Closure.ClosedAt,Comp.ClosedAt,Clause.ClosedList,Val.ClosedAt,
      Capture.Closed,captureSlotsClosed,Capture.empty],⟨valid,fun r _ => ?_⟩⟩
  cases r with
  | base b => cases b <;> exact ⟨_,rfl⟩
  | secrets => rfl

/-- 二段で、発行の計算が処理する枠の下に現れる。 -/
theorem reach : Steps program Model.builtins σFull (.run start [] Store.empty) []
    (.run (Closure.mk Capture.empty (.issuePathBases pathBasesName))
      [.letF (Closure.mk Capture.empty (.ret (.const .unit))),.handleF Capture.empty clauses] Store.empty) :=
  .cons (.E_Handle rfl) (.cons (.E_Let rfl) .nil)

/-- その状態は σ の発行の事象を伴って遷移する。 -/
theorem issue : Step program Model.builtins σFull
    (.run (Closure.mk Capture.empty (.issuePathBases pathBasesName))
      [.letF (Closure.mk Capture.empty (.ret (.const .unit))),.handleF Capture.empty clauses] Store.empty)
    (some (.pathBases pathBasesName σFull))
    (.run (Closure.pure (.ret (.pathBases σFull)))
      [.letF (Closure.mk Capture.empty (.ret (.const .unit))),.handleF Capture.empty clauses] Store.empty) :=
  .E_IssuePathBases rfl sig rfl rfl valid

/-- 同じ開始条件と実際の発行を持つ入力には、空の効果の型付けがない。 -/
theorem empty_typing_rejected :
    ¬ ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) Eff.empty := by
  intro typed
  have h := effect_soundness program Model.builtins σFull wellFormed wellTyped effectsOk core
    start (.base .unit) typed startCondition [] _ reach
  exact h.1 _ _ issue

/-- 発行の開始は空の効果では拒否され、宣言した効果では型付きの実行と正常値を持つ。 -/
theorem environment_witness :
    (¬ Eff.Sub (Eff.single processEnvironmentEff) (Eff.union Eff.empty (handled program Model.builtins clauses))) ∧
    (¬ ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) Eff.empty) ∧
    ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) (Eff.single processEnvironmentEff) ∧
    StartCondition program Model.builtins σFull start ∧
    ∃ s t, Steps program Model.builtins σFull (.run start [] Store.empty) [] s ∧
      Step program Model.builtins σFull s (some (.pathBases pathBasesName σFull)) t ∧
      StateTyE program Model.builtins σFull (Eff.single processEnvironmentEff) t := by
  have h0 := initial_typing program Model.builtins σFull wellFormed wellTyped core
    _ _ _ typed_environment startCondition
  have hr := h0.steps_preserved wellFormed wellTyped effectsOk core valid reach
  exact ⟨handled_environment_rejected,empty_typing_rejected,typed_environment,startCondition,_,_,reach,issue,
    hr.step_preserved wellFormed wellTyped effectsOk core valid issue⟩

/-- 同じ発行の組込みの節がある具体の型付きの状態でも、発行を差し替えない。 -/
theorem handler_bypass_witness :
    ∃ q cap cs mid next,
      handles cs (.prim pathBasesName) = true ∧
      StateTyE program Model.builtins σFull
        (Eff.union (Eff.single processEnvironmentEff) (Eff.single stateEff))
        (.run q [.handleF cap cs] Store.empty) ∧
      Step program Model.builtins σFull (.run q [.handleF cap cs] Store.empty) none mid ∧
      Step program Model.builtins σFull mid (some (.pathBases pathBasesName σFull)) next ∧
      StateTyE program Model.builtins σFull
        (Eff.union (Eff.single processEnvironmentEff) (Eff.single stateEff)) mid ∧
      StateTyE program Model.builtins σFull
        (Eff.union (Eff.single processEnvironmentEff) (Eff.single stateEff)) next := by
  obtain ⟨hsource,happly,hmid,hissue,hnext⟩ :=
    OperationStateExamples.primitive_pathBases wellFormed wellTyped core rfl valid
  refine ⟨_,_,_,_,_,?_,hsource,happly,hissue,hmid,hnext⟩
  rfl

/-- 同じ実表と有効環境の単位値の開始に、ラムダ名を前提にしない定理を適用する。 -/
theorem unit_noLamNames_witness :
    ∃ q, ClosureTy program Model.builtins StoreTy.empty [] none q (.base .unit) Eff.empty ∧
      q.Adequate σFull ∧ q.ClosedNoLamNames 0 ∧ InitialPrepared program Model.builtins σFull (.run q [] Store.empty) ∧
      (∀ ev s', ¬ Step program Model.builtins σFull (.run q [] Store.empty) (some ev) s') ∧
      ¬ UnhandledOp (.run q [] Store.empty) := by
  let q := Closure.pure (.ret (.const .unit))
  have ha : Ty.Annotation program [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hm : HasTypeC program Model.builtins StoreTy.empty [] [] [] none
      (.ret (.const .unit)) (.base .unit) Eff.empty := .C_Return (.V_Const (by trivial))
  have hq : ClosureTy program Model.builtins StoreTy.empty [] none q (.base .unit) Eff.empty :=
    ClosureTy.pure hm ha.done_empty (by intro r hr; cases hr) rfl (by intro r hr; cases hr)
  have hp : InitialPrepared program Model.builtins σFull (.run q [] Store.empty) := by
    refine ⟨valid,fun r _ => ?_⟩
    cases r with
    | base b => cases b <;> exact ⟨_,rfl⟩
    | secrets => rfl
  have hn := effect_soundness_noLamNames program Model.builtins σFull wellFormed wellTyped effectsOk core
    q (.base .unit) hq (by trivial) (by trivial) hp [] _ .nil
  exact ⟨q,hq,(by trivial),(by trivial),hp,hn⟩

end EffectSoundnessExamples
end
end Benitoite.Release.Refinement
