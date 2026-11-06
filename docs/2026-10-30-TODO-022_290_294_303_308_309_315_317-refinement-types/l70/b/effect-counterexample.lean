import Benitoite.Release.Refinement.MainStatements
import Benitoite.Release.Refinement.Model

/-! # エフェクトの健全性の言明の反例（記録用の試行。既定ビルドに含めない）

`EffectSoundnessStatement` は、空の効果で型が付いた閉包から始めた実行が事象を伴う遷移をしないことを述べる。
`E_IssuePathBases` は、処理する枠の有無を見ずに σ の発行の事象を出す。開始の閉包が `issuePathBases` を
Process.Environment の全操作を処理する `handle` の中に直接書くと、`C_Handle` がその効果を消して閉包は空の効果で
型が付き、二段の後に σ の発行の事象が起きる。開始の条件（`StartCondition`）は表層から作る構文（`Comp.Source`）
であることを要求しない。

`formal/` で `lake env lean -M 12288 <この入力>` として検査する。
-/
namespace Benitoite.Release.Refinement
noncomputable section
namespace EffectCounterexample

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

/-- Process.Environment の唯一の操作を処理する節は、その効果全体を処理する。 -/
theorem handled_environment :
    Eff.Sub (Eff.single processEnvironmentEff) (Eff.union Eff.empty (handled program Model.builtins clauses)) := by
  refine ⟨fun a ha => (Eff.mem_union_iff _ _ _).mpr (.inr ?_),fun t ht => ?_⟩
  · simp only [Eff.single,Eff.mem,Eff.test,Eff.atoms,decide_eq_true_eq] at ha
    subst ha
    simp [handled,effOps,program,Model.builtins,Model.effects,handles,clauses,Clause.op,
      Eff.mem,Eff.test,Eff.atoms,processEnvironmentEff,stateEff]
  · obtain ⟨u,hu,_⟩ := ht
    simp [Eff.single,Eff.fails] at hu

/-- 開始の閉包は空の効果で型が付く。 -/
theorem typed : ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) Eff.empty := by
  have ha : Ty.Annotation program [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hissue : HasTypeC program Model.builtins StoreTy.empty [] [] [] none (.issuePathBases pathBasesName)
      .pathBases (Eff.single processEnvironmentEff) :=
    core.issuePathBases_typed sig rfl
  have hbody : HasTypeC program Model.builtins StoreTy.empty [] [] [] none body (.base .unit)
      (Eff.single processEnvironmentEff) :=
    .C_Let hissue (.C_Eff (.C_Return (.V_Const (c := .unit) (by trivial))) (empty_sub _).covers) (by trivial)
  let sg : OpSig := ⟨[],[],[],.pathBases,processEnvironmentEff⟩
  have hcs : HasTypeClauses program Model.builtins StoreTy.empty [] [] [] none
      (Eff.single processEnvironmentEff) clauses (.base .unit) Eff.empty := by
    refine .cons (sg := sg) (ClauseSig.of_opSig ?_ ?_) (by trivial) rfl rfl (by trivial) ?_ .nil
    · simp [opSig,opSigAt,sig,pathBases,sg]
    · intro b s ho hs
      cases ho
      cases Option.some.inj (hs.symm.trans sig)
      simp [pathBases,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.single]
    · exact .C_Eff (.C_Return (.V_Const (by trivial))) (empty_sub _).covers
  exact ClosureTy.pure (.C_Handle hbody handled_environment hcs) ha.done_empty
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

/-- 現在のエフェクトの健全性の言明は、この表とプログラムについて成り立たない。 -/
theorem not_effect_soundness : ¬ EffectSoundnessStatement program Model.builtins σFull := by
  intro h
  obtain ⟨hno,_⟩ := h wellFormed wellTyped effectsOk core start (.base .unit) typed startCondition [] _ reach
  exact hno _ _ issue

end EffectCounterexample
end
end Benitoite.Release.Refinement
