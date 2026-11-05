import Benitoite.Release.Refinement.ExternalModelExamples

/-! # 同じ拡張表での外部入力と三モデルの条件 -/
namespace Benitoite.Release.Refinement.ExternalModels
open ExternalModelExamples
noncomputable section

/-- 外部応答を拡張したModelにもpure/IO/exit署名は登録されない。 -/
theorem model_no_response_kind {P b s} (lookup : (model P).sig b = some s) :
    s.kind ≠ .pure ∧ s.kind ≠ .io ∧ s.kind ≠ .exit := by
  rcases Model.sig_cases lookup with ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩
  all_goals simp [ScopeSignatures.refGet,ScopeSignatures.refSet,ScopeSignatures.pathBases]

/-- 三モデルの区別。各場合の表は `ExternalModels.model/targets/http`。 -/
inductive ModelCase where
  | model | targets | http

def ModelCase.base : ModelCase → Builtins
  | .model => Model.builtins
  | .targets => ModelTargets.builtins
  | .http => ModelHttp.builtins

def ModelCase.table (m : ModelCase) (P : Program) : Builtins :=
  match m with
  | .model => ExternalModels.model P
  | .targets => ExternalModels.targets P
  | .http => ExternalModels.http P

def ModelCase.Declarations : ModelCase → Program → Prop
  | .model, _ => True
  | .targets, P => ScopeDeclarations.HasFile P
  | .http, P => ScopeDeclarations.HasHttp P

private theorem table_eq (m : ModelCase) (P : Program) : m.table P =
    ExternalModel.builtins P m.base (ResourceRelease.response m.base.isResource) := by
  cases m <;> rfl

private theorem keys (m : ModelCase) (b : Bool) :
    m.base.sat [] (filtered (.base .integer) b).norm TParam.keyC := by
  cases m <;> cases b <;> rfl

/-- 任意Pの同じ表で二十五条件と外部三条件を読む。宣言条件は元の三モデルと同じ。 -/
theorem conditions (m : ModelCase) (P : Program) (decls : m.Declarations P) :
    ModelScopeConditions P (m.table P) ∧ Builtins.ExternalAssumptions P (m.table P) := by
  cases m with
  | model => exact ⟨model_scope P,(model_core P).toExternalAssumptions⟩
  | targets => exact ⟨targets_scope P decls,(targets_core P decls).toExternalAssumptions⟩
  | http => exact ⟨http_scope P decls,(http_core P decls).toExternalAssumptions⟩

/-- 全三表で、正常値と篩違反値は同じP/Bの外部三条件の前提を満たす。 -/
theorem shape_inputs (m : ModelCase) (s : Shape) (b : Bool) (Ψ : StoreTy) :
    m.Declarations (program s b) ∧
    (program s b).ExternalWF ∧
    ExternalArgs (program s b) (m.table (program s b)) Ψ (signature s b) [] [] (s.type b) Eff.empty ∧
    (m.table (program s b)).externalResponse ⟨0⟩ [] [] (.val (s.raw b)) [] ∧
    externalCheck (program s b) (s.raw b) (s.type b) = b := by
  have declarations : m.Declarations (program s b) := by
    cases m with
    | model => trivial
    | targets => exact (program_hasHttp s b).file
    | http => exact program_hasHttp s b
  refine ⟨declarations,?_⟩
  cases m with
  | model => exact raw_response s b Model.builtins (keys .model b) _ Ψ
  | targets => exact raw_response s b ModelTargets.builtins (keys .targets b) _ Ψ
  | http => exact raw_response s b ModelHttp.builtins (keys .http b) _ Ψ

/-- 同じ三表でborrow/own/Stateの実入力と、正常・拒否の両生応答を構成する。 -/
theorem handle_inputs (m : ModelCase) (b : Bool) (Ψ : StoreTy) (identity : Nat) :
    m.Declarations (handleProgram b) ∧
    (handleProgram b).ExternalWF ∧
    ExternalArgs (handleProgram b) (m.table (handleProgram b)) Ψ (handleSignature b) [] [handle identity]
      (handleType b) ExternalSignatureLeaves.stateEffect ∧
    (m.table (handleProgram b)).externalResponse ⟨0⟩ [] [handle identity] (.val (handle identity)) [] ∧
    externalCheck (handleProgram b) (handle identity) (handleType b) = b := by
  have declarations : m.Declarations (handleProgram b) := by
    cases m with
    | model => trivial
    | targets => exact (handle_program_hasHttp b).file
    | http => exact handle_program_hasHttp b
  refine ⟨declarations,?_⟩
  rw [table_eq]
  exact handle_raw_response b m.base _ Ψ identity

/-- 六形の証人の宣言で、全Shape・Ψ・σ・identityの受信と同じ表の二十五条件・外部三条件を読む。 -/
theorem responses (m : ModelCase) (Ψ : StoreTy) (σ : PathEnv) (identity : Nat) :
    (∀ s : Shape,
      (∀ b, ModelScopeConditions (program s b) (m.table (program s b)) ∧
        Builtins.ExternalAssumptions (program s b) (m.table (program s b))) ∧
      (externalReceive (program s true) (signature s true) [] [] (.val (s.raw true)) = some (.val (s.raw true)) ∧
        HasTypeV (program s true) (m.table (program s true)) Ψ [] [] [] (s.raw true) (s.type true) ∧
        (s.raw true).Ground ∧ (s.raw true).Adequate σ) ∧
      externalReceive (program s false) (signature s false) [] [] (.val (s.raw false)) = some (.err "ExternalRefinement") ∧
      (s.raw false).Adequate σ) ∧
    (∀ b, ModelScopeConditions (handleProgram b) (m.table (handleProgram b)) ∧
      Builtins.ExternalAssumptions (handleProgram b) (m.table (handleProgram b))) ∧
    (externalReceive (handleProgram true) (handleSignature true) [] [handle identity] (.val (handle identity)) = some (.val (handle identity)) ∧
      HasTypeV (handleProgram true) (m.table (handleProgram true)) Ψ [] [] [] (handle identity) (handleType true) ∧
      (handle identity).Ground ∧ (handle identity).Adequate σ) ∧
    (externalReceive (handleProgram false) (handleSignature false) [] [handle identity] (.val (handle identity)) = some (.err "ExternalRefinement") ∧
      (handle identity).Adequate σ) ∧
    (∀ b r, (m.table (handleProgram b)).externalResponse ⟨0⟩ [] [handle identity] (.err r) [] ∧
      externalReceive (handleProgram b) (handleSignature b) [] [handle identity] (.err r) = some (.err r) ∧
      ∀ n obs, ¬ (m.table (handleProgram b)).externalResponse ⟨0⟩ [] [handle identity] (.exit n) obs) := by
  refine ⟨?_,?_,?_⟩
  · intro s
    refine ⟨fun b => conditions m _ (shape_inputs m s b Ψ).1,?_⟩
    simpa only [table_eq] using receive_pair s m.base (keys m) _ Ψ σ
  · intro b
    exact conditions m _ (handle_inputs m b Ψ identity).1
  · simpa only [table_eq] using handle_receive_pair m.base _ Ψ σ identity

/-- 正常値を持つ全前提から、外部の型と対象条件の両欄を実際に適用する。 -/
example (m : ModelCase) (s : Shape) (b : Bool) (Ψ : StoreTy) :
    Outcome.Carrier (program s b) (m.table (program s b)) Ψ (.val (s.raw b)) (s.type b) ∧
    (∀ n : Int, Outcome.val (s.raw b) ≠ .exit n) ∧
    (∀ obs, (m.table (program s b)).externalResponse ⟨0⟩ [] [] (.val (s.raw b)) obs → obs = []) := by
  have input := shape_inputs m s b Ψ
  have h := (conditions m _ input.1).2
  refine ⟨(h.external_typed _ _ _ _ _ _ _ _ _ input.2.1 rfl input.2.2.1 input.2.2.2.1).1,
    (h.external_typed _ _ _ _ _ _ _ _ _ input.2.1 rfl input.2.2.1 input.2.2.2.1).2,?_⟩
  intro obs raw
  exact h.external_no_targets _ _ _ _ _ _ _ _ _ input.2.1 rfl input.2.2.1 raw

/-- 外部宣言を含む三モデルで同時に受信を検査し、Modelのpure/IO/exit不在も保持する。 -/
example (Ψ : StoreTy) (σ : PathEnv) (identity depth : Nat) :
    (∀ m : ModelCase, externalReceive (program (.data depth) false) (signature (.data depth) false) [] []
      (.val ((Shape.data depth).raw false)) = some (.err "ExternalRefinement") ∧
      HasTypeV (handleProgram true) (m.table (handleProgram true)) Ψ [] [] []
        (handle identity) (handleType true)) ∧
    (∀ P name sig, (model P).sig name = some sig → sig.kind ≠ .pure ∧ sig.kind ≠ .io ∧ sig.kind ≠ .exit) := by
  refine ⟨?_,fun _ _ _ lookup => model_no_response_kind lookup⟩
  intro m
  have result := responses m Ψ σ identity
  exact ⟨(result.1 (.data depth)).2.2.1,result.2.2.1.2.1⟩

end
end Benitoite.Release.Refinement.ExternalModels
