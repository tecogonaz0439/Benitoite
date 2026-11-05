import Benitoite.Release.Refinement.BuiltinResponseTransport
import Benitoite.Release.Refinement.ExternalModelResponse
import Benitoite.Release.Refinement.ResourceReleaseModel

/-! # 外部応答と解放を差し替える三つのモデル -/
namespace Benitoite.Release.Refinement
namespace ExternalModel

/-- 型付き入力を元の表へ戻し、同じ生の応答のcarrierを拡張した表へ移す。 -/
theorem external_assumptions (P : Program) (base : Builtins)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) :
    Builtins.ExternalAssumptions P (builtins P base release) where
  external_typed := by
    intro Ψ f d ts vs a e out obs _ lookup args response
    have source := args.of_fields (typing_fields P base release).symm
    have result := response.2 Ψ d a e lookup source
    exact ⟨result.1.of_fields (typing_fields P base release),result.2⟩
  external_exists := by
    intro Ψ f d ts vs a e _ lookup args
    exact ⟨.err "External",[],response_err P base f ts vs "External"⟩
  external_no_targets := by
    intro Ψ f d ts vs a e out obs _ lookup args response
    exact response.1

/-- 同じ七射影と実応答を持つ表へ、既存の全25条件を移す。 -/
theorem scope_conditions {P base} (release : Val → Option Benitoite.Release.ErrKind → Prop)
    (h : ModelScopeConditions P base) : ModelScopeConditions P (builtins P base release) :=
  h.of_responses (typing_fields P base release) rfl rfl rfl rfl rfl
end ExternalModel

/-- 応答の証人があるときはその対を選ぶ。 -/
noncomputable def Builtins.selectExternal (B : Builtins) : ExternalOracle := by
  classical
  exact fun f ts vs =>
    if h : ∃ out obs, B.externalResponse f ts vs out obs then
      (Classical.choose h,Classical.choose (Classical.choose_spec h))
    else (.err "External",[])

theorem Builtins.selectExternal_response {B : Builtins} {f ts vs}
    (h : ∃ out obs, B.externalResponse f ts vs out obs) :
    B.externalResponse f ts vs (B.selectExternal f ts vs).1 (B.selectExternal f ts vs).2 := by
  simp only [Builtins.selectExternal,dite_eq_left h]
  exact Classical.choose_spec (Classical.choose_spec h)

namespace ExternalModels

def model (P : Program) : Builtins := ExternalModel.builtins P Model.builtins
  (ResourceRelease.response Model.builtins.isResource)
def targets (P : Program) : Builtins := ExternalModel.builtins P ModelTargets.builtins
  (ResourceRelease.response ModelTargets.builtins.isResource)
def http (P : Program) : Builtins := ExternalModel.builtins P ModelHttp.builtins
  (ResourceRelease.response ModelHttp.builtins.isResource)

theorem model_scope (P : Program) : ModelScopeConditions P (model P) :=
  ExternalModel.scope_conditions _ (Model.scopeConditions P)
theorem targets_scope (P : Program) (h : ScopeDeclarations.HasFile P) : ModelScopeConditions P (targets P) :=
  ExternalModel.scope_conditions _ (ModelTargets.scopeConditions P h)
theorem http_scope (P : Program) (h : ScopeDeclarations.HasHttp P) : ModelScopeConditions P (http P) :=
  ExternalModel.scope_conditions _ (ModelHttp.scopeConditions P h)

/-- 外部宣言の有無を制限せず、資源のない模型のCoreを返す。 -/
theorem model_core (P : Program) : Builtins.CoreAssumptions P (model P) :=
  (model_scope P).core (ExternalModel.external_assumptions P _ _) (by
    intro Ψ v o typed resource
    exact Bool.noConfusion resource)
theorem targets_core (P : Program) (h : ScopeDeclarations.HasFile P) :
    Builtins.CoreAssumptions P (targets P) :=
  (targets_scope P h).core (ExternalModel.external_assumptions P _ _) (by
    intro Ψ v o typed resource
    refine ⟨none,ResourceRelease.typed_response (B := targets P) ?_ typed resource none⟩
    intro name resource
    exact ResourceRelease.targets_classification name resource)

theorem http_core (P : Program) (h : ScopeDeclarations.HasHttp P) :
    Builtins.CoreAssumptions P (http P) :=
  (http_scope P h).core (ExternalModel.external_assumptions P _ _) (by
    intro Ψ v o typed resource
    exact Bool.noConfusion resource)

/-- 三つの表は各々の同じCoreと対象条件を構成する。 -/
example (P : Program) (h : ScopeDeclarations.HasHttp P) :
    (Builtins.CoreAssumptions P (model P) ∧ Builtins.TargetAgreement P (model P)) ∧
    (Builtins.CoreAssumptions P (targets P) ∧ Builtins.TargetAgreement P (targets P)) ∧
    (Builtins.CoreAssumptions P (http P) ∧ Builtins.TargetAgreement P (http P)) :=
  ⟨⟨model_core P,(model_scope P).toTargetAgreement⟩,
   ⟨targets_core P h.file,(targets_scope P h.file).toTargetAgreement⟩,
   ⟨http_core P h,(http_scope P h).toTargetAgreement⟩⟩

end ExternalModels
end Benitoite.Release.Refinement
