import Benitoite.Release.Refinement.StandardModelComposedRows
import Benitoite.Release.Refinement.MainEffects
import Benitoite.Release.Refinement.ExternalModelComposition

/-! # 利用者のプログラムへの主定理の適用

宣言の一覧、標準の宣言の包含、追加宣言の検査と仮定側の表の契約から、完成した同じ表で主定理を適用する
（設計書 01-12「確かめる性質」、07-04「01-12 との対応」）。開始・応答の選択・環境の条件は各言明に残す。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- プログラム全体の検査と表の条件を供給した後の、同じ P/B/σ での主定理の結論。 -/
structure ProgramGuarantees (P : Program) (B : Builtins) (σ : PathEnv) : Prop where
  progress : ∀ s, StateTy P B σ s → s.Final ∨ ∃ l s', Step P B σ s l s'
  preservation : ∀ s l s', StateTy P B σ s → Step P B σ s l s' → StateTy P B σ s'
  steps_preservation : ∀ s evs s', StateTy P B σ s → Steps P B σ s evs s' → StateTy P B σ s'
  step_sound : ∀ (oracle : Oracle) (externalOracle : ExternalOracle) (rel : Val → Option ErrKind) (fresh : Store → Nat),
    StepSelection B oracle externalOracle rel fresh →
    ∀ s l s', StateTy P B σ s → step P B σ oracle externalOracle rel fresh s = some (l, s') → Step P B σ s l s'
  initial_typing : ∀ q a ε, ClosureTy P B StoreTy.empty [] none q a ε → StartCondition P B σ q →
      StateTyE P B σ ε (.run q [] Store.empty)
  effect_soundness : ∀ q a, ClosureTy P B StoreTy.empty [] none q a Eff.empty → StartCondition P B σ q →
      ∀ evs s, Steps P B σ (.run q [] Store.empty) evs s →
        (∀ ev s', ¬ Step P B σ s (some ev) s') ∧ ¬ UnhandledOp s
  step_target_sound : σ.Valid →
    ∀ Eb s s' b ws o obs, StateTyE P B σ Eb s → Step P B σ s (some (.io b ws o obs)) s' →
      ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind Eb l t
  reachable_target_sound : ∀ q a ε, ClosureTy P B StoreTy.empty [] none q a ε → StartCondition P B σ q →
      ∀ evs s s' b ws o obs, Steps P B σ (.run q [] Store.empty) evs s →
        Step P B σ s (some (.io b ws o obs)) s' →
        ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind ε l t
  reachable_target_sound_event : ∀ q a ε, ClosureTy P B StoreTy.empty [] none q a ε → StartCondition P B σ q →
      ∀ evs s s' ev, Steps P B σ (.run q [] Store.empty) evs s → Step P B σ s (some ev) s' →
        ∀ t ∈ ev.targets, ∃ b ws o obs e l, ev = .io b ws o obs ∧ B.sig b = some e ∧ e.opEff = some l ∧
          Eff.Allows σ B.effKind ε l t
  effect_soundness_noLamNames : ∀ q a,
    ClosureTy P B StoreTy.empty [] none q a Eff.empty → q.Adequate σ → q.ClosedNoLamNames 0 →
    InitialPrepared P B σ (.run q [] Store.empty) → ∀ evs s,
    Steps P B σ (.run q [] Store.empty) evs s →
      (∀ ev s', ¬ Step P B σ s (some ev) s') ∧ ¬ UnhandledOp s

/-- 主定理の各前提を、同じ P/B について一度供給する。 -/
theorem program_guarantees {P : Program} {B : Builtins} (hP : P.WellFormed) (hPB : P.WellTyped B)
    (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P) (ht : B.TargetAgreement P) (σ : PathEnv) :
    ProgramGuarantees P B σ where
  progress := progress P B σ hP hPB hdecl hB
  preservation := preservation P B σ hP hPB hdecl hB
  steps_preservation := steps_preservation P B σ hP hPB hdecl hB
  step_sound := fun oracle externalOracle rel fresh => step_sound P B σ oracle externalOracle rel fresh hP hPB hB
  initial_typing := initial_typing P B σ hP hPB hB
  effect_soundness := effect_soundness P B σ hP hPB hdecl hB
  step_target_sound := step_target_sound P B σ hP hPB hdecl hB ht
  reachable_target_sound := reachable_target_sound P B σ hP hPB hdecl hB ht
  reachable_target_sound_event := reachable_target_sound_event P B σ hP hPB hdecl hB ht
  effect_soundness_noLamNames := effect_soundness_noLamNames P B σ hP hPB hdecl hB

namespace StandardModel

/-- 含まれる有限の外部宣言表の構造検証を利用者のプログラムへ移す。 -/
theorem Includes.externalWF {externals P} (hI : Includes externals P)
    (hw : (program externals).ExternalWF) : P.ExternalWF := hw.ofExtends hI.extends_

/-- 完成した表の三検査と Core・対象条件。追加宣言の義務、外部宣言の構造検証、data 宣言の一覧は別に受ける。 -/
theorem included_premises {L : NameLists} (hL : L.WF) {externals P} (T : DataTable P)
    {A : AssumedTable} (hI : Includes externals P) (hc : Completion L T A)
    (hw : (program externals).ExternalWF) (hadd : Program.Additions (program externals) P (complete L T A)) :
    P.WellFormed ∧ P.WellTyped (complete L T A) ∧ P.EffectsOk (complete L T A) ∧
      (complete L T A).CoreAssumptions P ∧ (complete L T A).TargetAgreement P := by
  have core := completion_core L externals hL P T A hI hc
  exact ⟨included_wellFormed hI hw hadd,
    included_typed hL T hI (complete_agree L T A) (hI.externalWF hw) hadd,
    included_effectsOk hI hadd, core⟩

/-- 標準の宣言を含む利用者のプログラムへの系。合成表全体の証拠と仮定側の契約から同じ完成した表を使う。 -/
theorem included_guarantees {L : NameLists} (hL : L.WF) {externals P} (T : DataTable P)
    {A : AssumedTable} (hI : Includes externals P) (hc : Completion L T A)
    (hw : (program externals).ExternalWF) (hadd : Program.Additions (program externals) P (complete L T A))
    (σ : PathEnv) : ProgramGuarantees P (complete L T A) σ := by
  obtain ⟨hP,hPB,hdecl,hB,ht⟩ := included_premises hL T hI hc hw hadd
  exact program_guarantees hP hPB hdecl hB ht σ

/-- 形式化の外の名前には署名を付けない。 -/
theorem complete_outside {L : NameLists} (hL : L.WF) {P} (T : DataTable P) (A : AssumedTable)
    {b : PrimName} (hb : b ∈ L.outside) : (complete L T A).sig b = none := by
  obtain ⟨hnc,hna⟩ := hL.outside b hb
  simp [complete, ExternalModel.builtins, completeBase, hnc, hna]

/-- 内部名は追加した利用者の定義の名前にならない。 -/
theorem Includes.getFront_fresh {externals P} (hI : Includes externals P) {d : Def}
    (hnew : (program externals).defs "%List.getFront" = none) : P.defs "%List.getFront" ≠ some d := by
  intro hd
  exact hI.internal _ _ hnew hd (by simpa only [String.startsWith_string_iff] using (show "%".toList <+: "%List.getFront".toList from ⟨"List.getFront".toList, rfl⟩))

/-- 合成側の各構成子は同じ名前・宣言で利用者の一覧に含まれる。順序自体は DataTable が指定し、δ が同じ順序を読む。 -/
theorem Includes.constructor_entry {externals P} (hI : Includes externals P) (T : DataTable P)
    {c : ConName} {cd : ConDecl} (hc : (program externals).cons c = some cd) :
    (T.declarations.flatMap StandardKeyTyping.DataDecl.entries).lookup c = some cd := by
  have h := hI.extends_.cons c cd hc
  rw [T.cons_eq] at h
  exact h

/-- 完成した表の合成側の δ は、利用者の宣言の一覧の構成子順で作る。 -/
theorem complete_delta {L : NameLists} (hL : L.WF) {P} (T : DataTable P) (A : AssumedTable)
    (row : Primitive) : (complete L T A).delta row.name = row.deltaWith T.keyNames row.name := by
  have hm := hL.composedAll row.name (by simp [baseBuiltins, signature, primitive_lookup])
  change (if row.name ∈ L.composed then T.base.delta row.name else A.delta row.name) = _
  rw [ite_eq_left hm]
  change (primitive row.name).elim _ _ = _
  rw [primitive_lookup]
  rfl

end StandardModel

/-- model の表に P の外部応答と抽象の解放を付けた模型への適用。 -/
example {P} (hP : P.WellFormed) (hPB : P.WellTyped (ExternalModels.model P))
    (hd : P.EffectsOk (ExternalModels.model P)) (σ : PathEnv) : ProgramGuarantees P (ExternalModels.model P) σ :=
  program_guarantees hP hPB hd (ExternalModels.model_core P)
    (ExternalModels.model_scope P).toTargetAgreement σ

/-- targets の表に P の外部応答と抽象の解放を付けた模型への適用。 -/
example {P} (decls : ScopeDeclarations.HasFile P) (hP : P.WellFormed) (hPB : P.WellTyped (ExternalModels.targets P))
    (hd : P.EffectsOk (ExternalModels.targets P)) (σ : PathEnv) : ProgramGuarantees P (ExternalModels.targets P) σ :=
  program_guarantees hP hPB hd (ExternalModels.targets_core P decls)
    (ExternalModels.targets_scope P decls).toTargetAgreement σ

/-- http の表に P の外部応答と抽象の解放を付けた模型への適用。 -/
example {P} (decls : ScopeDeclarations.HasHttp P) (hP : P.WellFormed) (hPB : P.WellTyped (ExternalModels.http P))
    (hd : P.EffectsOk (ExternalModels.http P)) (σ : PathEnv) : ProgramGuarantees P (ExternalModels.http P) σ :=
  program_guarantees hP hPB hd (ExternalModels.http_core P decls)
    (ExternalModels.http_scope P decls).toTargetAgreement σ

end
end Benitoite.Release.Refinement
