import Benitoite.Release.Refinement.LeafInputs
import Benitoite.Release.Refinement.BuilderStateLeaves

/-! # 同じ実行の有限な状態の保存 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 既存の全実行葉へ、同じ宣言・表・起点・状態の証拠を分配する。 -/
theorem StateTyE.step_preserved {P B σ Eb source event dest}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (state : StateTyE P B σ Eb source) (step : Step P B σ source event dest) :
    StateTyE P B σ Eb dest := by
  have hsub := hB.toSubstitutionAssumptions
  cases step
  all_goals
    first
    | (apply And.left; apply And.right; apply StateTyE.store_reply <;> first | assumption | (constructor <;> assumption))
    | (apply And.left; apply And.right; apply StateTyE.control_leaf <;> first | assumption | (constructor <;> assumption))
    | (apply And.right; apply StateTyE.external_value_all <;> assumption)
    | (apply And.right; apply StateTyE.external_error_all <;> assumption)
    | (apply And.right; apply StateTyE.issue_path_bases_all <;> assumption)
    | (apply And.right; apply StateTyE.at_ok_all <;> assumption)
    | (apply And.right; apply StateTyE.at_error_all <;> assumption)
    | (apply And.right; apply StateTyE.at_prepare_error_all <;> assumption)
    | (apply And.right; apply StateTyE.primitive_value_all <;> assumption)
    | (apply And.right; apply StateTyE.io_value_all <;> assumption)
    | (apply And.right; apply StateTyE.io_error_all <;> assumption)
    | (apply And.right; apply StateTyE.force_done_all <;> assumption)
    | (apply And.right; apply StateTyE.builder_new <;> assumption)
    | (apply StateTyE.builder_new <;> assumption)
    | (apply And.right; apply StateTyE.builder_operation <;> assumption)
    | (apply StateTyE.builder_operation <;> assumption)
    | (apply And.right; apply StateTyE.builder_error <;> assumption)
    | (apply StateTyE.builder_error <;> assumption)
    | (apply And.right; apply StateTyE.let_step <;> assumption)
    | (apply StateTyE.let_step <;> assumption)
    | (apply And.right; apply StateTyE.return_step <;> assumption)
    | (apply StateTyE.return_step <;> assumption)
    | (apply And.right; apply StateTyE.lambda_beta_all <;> assumption)
    | (apply StateTyE.lambda_beta_all <;> assumption)
    | (apply And.right; apply StateTyE.fun_step <;> assumption)
    | (apply StateTyE.fun_step <;> assumption)
    | (apply And.right; apply StateTyE.method_step <;> assumption)
    | (apply StateTyE.method_step <;> assumption)
    | (apply And.right; apply StateTyE.super_step <;> assumption)
    | (apply StateTyE.super_step <;> assumption)
    | (apply And.right; apply StateTyE.if_true <;> assumption)
    | (apply StateTyE.if_true <;> assumption)
    | (apply And.right; apply StateTyE.if_false <;> assumption)
    | (apply StateTyE.if_false <;> assumption)
    | (apply And.right; apply StateTyE.match_start <;> assumption)
    | (apply StateTyE.match_start <;> assumption)
    | (apply And.right; apply StateTyE.match_skip <;> assumption)
    | (apply StateTyE.match_skip <;> assumption)
    | (apply And.right; apply StateTyE.match_body <;> assumption)
    | (apply StateTyE.match_body <;> assumption)
    | (apply And.right; apply StateTyE.match_guard <;> assumption)
    | (apply StateTyE.match_guard <;> assumption)
    | (apply And.right; apply StateTyE.guard_true <;> assumption)
    | (apply StateTyE.guard_true <;> assumption)
    | (apply And.right; apply StateTyE.guard_false <;> assumption)
    | (apply StateTyE.guard_false <;> assumption)
    | (apply And.right; apply StateTyE.err_pop_guard <;> assumption)
    | (apply StateTyE.err_pop_guard <;> assumption)
    | (apply And.right; apply StateTyE.exit_pop_guard <;> assumption)
    | (apply StateTyE.exit_pop_guard <;> assumption)
    | (apply And.right; apply StateTyE.mark_step <;> assumption)
    | (apply StateTyE.mark_step <;> assumption)
    | (apply And.right; apply StateTyE.handle_step <;> assumption)
    | (apply StateTyE.handle_step <;> assumption)
    | (apply And.right; apply StateTyE.handler_return <;> assumption)
    | (apply StateTyE.handler_return <;> assumption)
    | (apply And.right; apply StateTyE.operation_all <;> assumption)
    | (apply StateTyE.operation_all <;> assumption)
    | (apply And.right; apply StateTyE.operation_failure <;> assumption)
    | (apply StateTyE.operation_failure <;> assumption)
    | (apply And.right; apply StateTyE.operation_primitive <;> assumption)
    | (apply StateTyE.operation_primitive <;> assumption)
    | (apply And.right; apply StateTyE.resume_all <;> assumption)
    | (apply StateTyE.resume_all <;> assumption)
    | (apply And.right; apply StateTyE.resume_used <;> assumption)
    | (apply StateTyE.resume_used <;> assumption)
    | (apply And.right; apply StateTyE.drop_used_all <;> assumption)
    | (apply StateTyE.drop_used_all <;> assumption)
    | (apply And.right; apply StateTyE.drop_release_all <;> assumption)
    | (apply StateTyE.drop_release_all <;> assumption)
    | (apply And.right; apply StateTyE.escape_drop_used <;> assumption)
    | (apply StateTyE.escape_drop_used <;> assumption)
    | (apply And.right; apply StateTyE.escape_drop_release <;> assumption)
    | (apply StateTyE.escape_drop_release <;> assumption)
    | (apply And.right; apply StateTyE.error_drop <;> assumption)
    | (apply StateTyE.error_drop <;> assumption)
    | (apply And.right; apply StateTyE.exit_drop <;> assumption)
    | (apply StateTyE.exit_drop <;> assumption)
    | (apply And.right; apply StateTyE.err_drop_rel <;> assumption)
    | (apply StateTyE.err_drop_rel <;> assumption)
    | (apply And.right; apply StateTyE.exit_drop_rel <;> assumption)
    | (apply StateTyE.exit_drop_rel <;> assumption)
    | (apply And.right; apply StateTyE.error_handler <;> assumption)
    | (apply StateTyE.error_handler <;> assumption)
    | (apply And.right; apply StateTyE.exit_handler <;> assumption)
    | (apply StateTyE.exit_handler <;> assumption)
    | (apply And.right; apply StateTyE.error_release <;> assumption)
    | (apply StateTyE.error_release <;> assumption)
    | (apply And.right; apply StateTyE.error_release_failure <;> assumption)
    | (apply StateTyE.error_release_failure <;> assumption)
    | (apply And.right; apply StateTyE.exit_release <;> assumption)
    | (apply StateTyE.exit_release <;> assumption)
    | (apply And.right; apply StateTyE.exit_release_failure <;> assumption)
    | (apply StateTyE.exit_release_failure <;> assumption)
    | (apply And.right; apply StateTyE.return_release <;> assumption)
    | (apply StateTyE.return_release <;> assumption)
    | (apply And.right; apply StateTyE.return_release_failure <;> assumption)
    | (apply StateTyE.return_release_failure <;> assumption)
    | (apply And.right; apply StateTyE.escape_release <;> assumption)
    | (apply StateTyE.escape_release <;> assumption)
    | (apply And.right; apply StateTyE.escape_release_failure <;> assumption)
    | (apply StateTyE.escape_release_failure <;> assumption)
    | (apply And.right; apply StateTyE.use_all <;> assumption)
    | (apply StateTyE.use_all <;> assumption)

/-- 一段の保存を同じ有限の Steps に沿って反復する。 -/
theorem StateTyE.steps_preserved {P B σ Eb source events dest}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (state : StateTyE P B σ Eb source) (trace : Steps P B σ source events dest) :
    StateTyE P B σ Eb dest := by
  revert state
  induction trace with
  | nil => intro state; exact state
  | cons step rest ih =>
    intro state
    exact ih (state.step_preserved hP hPB hdecl hB hσ step)

private theorem mark_reader {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (ops : P.ops = fun _ => none) (effects : P.effects = fun _ => none) :
    ∃ source dest, P.EffectsOk B ∧ StateTyE P B σ Eff.empty source ∧
      Steps P B σ source [] dest ∧ StateTyE P B σ Eff.empty dest := by
  have hdecl : Program.EffectsOk P B := by
    refine ⟨?_,?_,?_⟩
    · intro l os o h ho; rw [effects] at h; cases h
    · intro o od h; rw [ops] at h; cases h
    · intro l os h; rw [effects] at h; cases h
  have ha : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hq := ClosureTy.pure (B := B) (Ψ := StoreTy.empty) (R := some (.base .unit))
    (.C_Return (.V_Const (c := .unit) (by trivial))) ha.done_empty
    (by intro r hr; cases hr; trivial) rfl (by intro r hr; cases hr; rfl)
  have hk := ContTy.K_Mark (ContTy.K_Empty (R := none) (P := P) (B := B) (σ := σ)
    (Ψ := StoreTy.empty) (show Eff.Sub Eff.empty Eff.empty from ⟨fun _ h => h,fun _ h => h⟩) ha) ha
  have hs : StateTyE P B σ Eff.empty
      (.run (Closure.pure (.ret (.const .unit))) [.mark] Store.empty) :=
    ⟨StoreTy.empty,some (.base .unit),.base .unit,.base .unit,Eff.empty,Eff.empty,
      StoreOk.empty P B σ,hq,⟨fun _ h => h,fun _ h => h⟩,hk,by trivial,by trivial,
      (by intro f hf; cases List.mem_singleton.mp hf; trivial),(by intro l c h; cases h)⟩
  have ht : Steps P B σ (.run (Closure.pure (.ret (.const .unit))) [.mark] Store.empty) []
      (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) := .cons (.E_Mark rfl) .nil
  have hd := hs.steps_preserved hP hPB hdecl hB hσ ht
  exact ⟨_,_,hdecl,hs,ht,hd⟩


/-- 具体の表の効果宣言の対応を計算し、mark の実遷移へ保存を適用する。 -/
theorem concrete_finite_preservation :
    ∃ P B σ source dest,
      P.WellFormed ∧ P.WellTyped B ∧ P.EffectsOk B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      StateTyE P B σ Eff.empty source ∧ Steps P B σ source [] dest ∧
      StateTyE P B σ Eff.empty dest := by
  obtain ⟨σ,hσ,hP,hPB,hB,_⟩ := NormalReplyExamples.concrete_normal_replies
  obtain ⟨source,dest,hdecl,hs,ht,hd⟩ := mark_reader hP hPB hB hσ rfl rfl
  exact ⟨_,_,σ,source,dest,hP,hPB,hdecl,hB,hσ,hs,ht,hd⟩

end
end Benitoite.Release.Refinement
