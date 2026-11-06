import Benitoite.Release.Refinement.MainStepSound
import Benitoite.Release.Refinement.MainTargets
import Benitoite.Release.Refinement.StartLamNames
import Benitoite.Release.Refinement.Model

/-! # 主な定理

設計書 01-12「確かめる性質」の性質 2（進行と保存）と性質 3 のうち到達先の対象健全性を、`MainStatements` の命題として
閉じる。各定理は、継続の末尾の効果 Eb を固定した状態の型付け `StateTyE` についての一段の性質（保存・進行・実行関数の
健全性・IO の事象の対象健全性）を、公開の状態の型付け `StateTy` と開始の状態の型付けへ包む。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 保存。型が付いた状態から遷移した先の状態も型が付く。 -/
theorem preservation (P : Program) (B : Builtins) (σ : PathEnv) : PreservationStatement P B σ := by
  intro hP hPB hdecl hB s l s' hs hst
  obtain ⟨hσ,Eb,hEb,h⟩ := hs
  exact ⟨hσ,Eb,hEb,h.step_preserved hP hPB hdecl hB hσ hst⟩

/-- 実行の列の保存。 -/
theorem steps_preservation (P : Program) (B : Builtins) (σ : PathEnv) :
    StepsPreservationStatement P B σ := by
  intro hP hPB hdecl hB s evs s' hs hst
  obtain ⟨hσ,Eb,hEb,h⟩ := hs
  exact ⟨hσ,Eb,hEb,h.steps_preserved hP hPB hdecl hB hσ hst⟩

/-- 進行。型が付いた状態は終端であるか、遷移を持つ。 -/
theorem progress (P : Program) (B : Builtins) (σ : PathEnv) : ProgressStatement P B σ := by
  intro hP hPB hdecl hB s hs
  obtain ⟨hσ,Eb,hEb,h⟩ := hs
  exact h.progress hP hPB hdecl hB hσ hEb

/-- 実行関数の健全性。選択の条件を満たす実行関数が型が付いた状態について返す遷移は、関係の遷移である。 -/
theorem step_sound (P : Program) (B : Builtins) (σ : PathEnv) (oracle : Oracle)
    (externalOracle : ExternalOracle) (rel : Val → Option ErrKind) (fresh : Store → Nat) :
    StepSoundStatement P B σ oracle externalOracle rel fresh := by
  intro hP hPB hB hsel s l s' hs hstep
  obtain ⟨_,Eb,_,h⟩ := hs
  exact h.step_sound hP hPB hB hsel hstep

/-- 開始の状態の型付け。開始の閉包の効果を継続の末尾に固定する。 -/
theorem initial_typing (P : Program) (B : Builtins) (σ : PathEnv) : InitialTypingStatement P B σ := by
  intro _ _ _ q a ε hq hstart
  have ha := hq.annotation
  exact ⟨StoreTy.empty,none,a,a,ε,ε,StoreOk.empty P B σ,hq,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩,
    hstart.adequate,hstart.closed,(by intro f hf; cases hf),(by intro l c h; cases h)⟩

/-- 一段の対象健全性。継続の末尾に効果 Eb を固定した状態の IO の事象の観測の対象は、その操作の名前の Eb の原子が
σ の下で許す。 -/
theorem step_target_sound (P : Program) (B : Builtins) (σ : PathEnv) : StepTargetStatement P B σ := by
  intro hP hPB hdecl hB ht _ Eb s s' b ws o obs h hst
  exact h.io_target_sound hP hPB hdecl hB ht hst

/-- 到達先の対象健全性。型が付いた閉包から始めた実行が到達した状態の IO の事象の観測の対象は、初期の効果 ε の
操作の名前の原子が σ の下で許す。 -/
theorem reachable_target_sound (P : Program) (B : Builtins) (σ : PathEnv) :
    ReachableTargetStatement P B σ := by
  intro hP hPB hdecl hB ht q a ε hq hstart evs s s' b ws o obs hsteps hst
  have hσ := hstart.prepared.ready.1
  have h0 := initial_typing P B σ hP hPB hB q a ε hq hstart
  exact step_target_sound P B σ hP hPB hdecl hB ht hσ ε s s' b ws o obs
    (h0.steps_preserved hP hPB hdecl hB hσ hsteps) hst

/-- 到達先の対象健全性の、事象の種類によらない形。 -/
theorem reachable_target_sound_event (P : Program) (B : Builtins) (σ : PathEnv) :
    ReachableTargetEventStatement P B σ := by
  intro hP hPB hdecl hB ht q a ε hq hstart evs s s' ev hsteps hst t htm
  cases ev with
  | io b ws o obs =>
    obtain ⟨e,l,hsig,hop,hall⟩ :=
      reachable_target_sound P B σ hP hPB hdecl hB ht q a ε hq hstart evs s s' b ws o obs hsteps hst
    exact ⟨b,ws,o,obs,e,l,rfl,hsig,hop,hall t htm⟩
  | release v r => simp [Event.targets] at htm
  | pathBases b ρ => simp [Event.targets] at htm

/-- 具体の表の型付きの状態について、進行・保存・実行関数の健全性を同時に適用する。実行関数は合成表と空の場所の
選択（`Builtins.selected_stepSelection`）を使う。 -/
example : ∃ P B σ s, StateTy P B σ s ∧ (s.Final ∨ ∃ l s', Step P B σ s l s') ∧
    ∀ l s', step P B σ B.selectOracle B.selectExternal B.selectRelease Store.selectFresh s = some (l,s') →
      Step P B σ s l s' ∧ StateTy P B σ s' := by
  obtain ⟨P,B,σ,source,_,hP,hPB,hdecl,hB,hσ,hs,_,_⟩ := concrete_finite_preservation
  have hty : StateTy P B σ source := ⟨hσ,Eff.empty,⟨rfl,fun _ h => by cases h⟩,hs⟩
  refine ⟨P,B,σ,source,hty,progress P B σ hP hPB hdecl hB source hty,fun l s' hstep => ?_⟩
  have hst := step_sound P B σ _ _ _ _ hP hPB hB (B.selected_stepSelection) source l s' hty hstep
  exact ⟨hst,preservation P B σ hP hPB hdecl hB source l s' hty hst⟩

/-- 単位の値を返す閉包から始める状態は、起点の範囲を何も辿らない。 -/
private theorem unit_start_ready {P B} {σ : PathEnv} (hσ : σ.Valid) :
    σ.Ready P B (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) := by
  refine ⟨hσ,fun r hr => ?_⟩
  have inv : ∀ {n}, PreparationNode.Reachable P B
      (.state (.run (Closure.pure (.ret (.const .unit))) [] Store.empty)) n →
      n = .state (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∨
      n = .closure (Closure.pure (.ret (.const .unit))) ∨ n = .capture Capture.empty ∨
      n = .comp (.ret (.const .unit)) ∨ n = .val (.const .unit) := by
    intro n h
    induction h with
    | root => exact .inl rfl
    | child _ hc ih =>
      rcases ih with rfl | rfl | rfl | rfl | rfl
      · rcases hc with rfl | ⟨f,hf,_⟩ | ⟨l,c,hl,_⟩
        · exact .inr (.inl rfl)
        · cases hf
        · cases hl
      · rcases hc with rfl | rfl
        · exact .inr (.inr (.inl rfl))
        · exact .inr (.inr (.inr (.inl rfl)))
      · obtain ⟨v,hv,_⟩ := hc
        cases hv
      · cases hc
        exact .inr (.inr (.inr (.inr rfl)))
      · cases hc
  cases hr with
  | base h => rcases inv h with h | h | h | h | h <;> cases h
  | secrets h => rcases inv h with h | h | h | h | h <;> cases h

/-- 開始の条件を満たす閉包がある。具体の表で、単位の値を返す閉包は、ラムダ名の整形式を外した閉じ方から開始の
条件を満たし、開始の状態は型が付く。 -/
example : ∃ P B σ q a, P.WellFormed ∧ P.WellTyped B ∧ P.EffectsOk B ∧ B.CoreAssumptions P ∧
    ClosureTy P B StoreTy.empty [] none q a Eff.empty ∧ StartCondition P B σ q ∧
    StateTyE P B σ Eff.empty (.run q [] Store.empty) := by
  obtain ⟨P,B,σ,_,_,hP,hPB,hdecl,hB,hσ,_⟩ := concrete_finite_preservation
  have ha : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hm : HasTypeC P B StoreTy.empty [] [] [] none (.ret (.const .unit)) (.base .unit) Eff.empty :=
    .C_Return (.V_Const (c := .unit) (by trivial))
  have hq := ClosureTy.pure hm ha.done_empty (by intro r hr; cases hr) rfl (by intro r hr; cases hr)
  have hp : InitialPrepared P B σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) :=
    ⟨unit_start_ready hσ⟩
  have hstart := StartCondition.of_noLamNames hm trivial trivial hp
  exact ⟨P,B,σ,_,_,hP,hPB,hdecl,hB,hq,hstart,initial_typing P B σ hP hPB hB _ _ _ hq hstart⟩

/-- 宣言を持たないプログラム。 -/
private def emptyProgram : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

/-- 参照二行と起点発行一行の表と、宣言を持たないプログラムは、到達先の対象健全性の前提をすべて同時に満たし、
単位の値を返す閉包から始めた実行に定理を適用できる。開始の条件は、閉包の型付けとラムダ名の整形式を外した閉じ方から
得る。 -/
example : ∃ (P : Program) (B : Builtins) (σ : PathEnv) (q : Closure) (a : Ty),
    P.WellFormed ∧ P.WellTyped B ∧ P.EffectsOk B ∧ B.CoreAssumptions P ∧ B.TargetAgreement P ∧
    ClosureTy P B StoreTy.empty [] none q a Eff.empty ∧ StartCondition P B σ q ∧
    ∀ evs s s' b ws o obs, Steps P B σ (.run q [] Store.empty) evs s →
      Step P B σ s (some (.io b ws o obs)) s' →
      ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind Eff.empty l t := by
  let σ : PathEnv := ⟨[],[],[],none,none,none⟩
  have hσ : σ.Valid := by simp [PathEnv.Valid,σ,Scope.Domain.PathWordWF]
  have hP : emptyProgram.WellFormed :=
    ⟨(by intro f d h; cases h),(by intro c cd h; cases h),(by intro o od h; cases h),
      (by intro cl cd h; cases h),(by intro i id h; cases h),(by intro d info h; cases h),
      ⟨by simp [emptyProgram],by intro key decl h; cases h⟩⟩
  have hPB : emptyProgram.WellTyped Model.builtins :=
    ⟨⟨(by intro d info h; cases h),(by intro c cd h; cases h)⟩,⟨by simp [emptyProgram],by intro key decl h; cases h⟩,
      (by intro f d h; cases h),(by intro i id h; cases h)⟩
  have hdecl : emptyProgram.EffectsOk Model.builtins :=
    ⟨by intro l os o h; simp [emptyProgram] at h,by intro o od h; simp [emptyProgram] at h,
      by intro l os h; simp [emptyProgram] at h⟩
  have hB : Model.builtins.CoreAssumptions emptyProgram :=
    (Model.scopeConditions emptyProgram).core
      ⟨by intro _ _ _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,emptyProgram] at h,
        by intro _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,emptyProgram] at h,
        by intro _ _ _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,emptyProgram] at h⟩
      (by intro Ψ v o _ h; cases h)
  have ht := Model.targetAgreement emptyProgram
  have ha : Ty.Annotation emptyProgram [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hm : HasTypeC emptyProgram Model.builtins StoreTy.empty [] [] [] none (.ret (.const .unit))
      (.base .unit) Eff.empty := .C_Return (.V_Const (c := .unit) (by trivial))
  have hq := ClosureTy.pure hm ha.done_empty (by intro r hr; cases hr) rfl (by intro r hr; cases hr)
  have hstart := StartCondition.of_typed_noLamNames (σ := σ) hq ⟨trivial,trivial⟩ trivial ⟨unit_start_ready hσ⟩
  exact ⟨emptyProgram,Model.builtins,σ,_,_,hP,hPB,hdecl,hB,ht,hq,hstart,
    fun evs s s' b ws o obs hs hst =>
      reachable_target_sound _ _ σ hP hPB hdecl hB ht _ _ _ hq hstart evs s s' b ws o obs hs hst⟩

end
end Benitoite.Release.Refinement
