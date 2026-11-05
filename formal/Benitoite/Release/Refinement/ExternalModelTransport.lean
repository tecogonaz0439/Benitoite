import Benitoite.Release.Refinement.BuiltinResponseTransport
import Benitoite.Release.Refinement.ExternalModelResponse
import Benitoite.Release.Refinement.ResourceReleaseModel
import Benitoite.Release.Refinement.ExternalConnection

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

/-- 同じ宣言の具体化を照合し、全ストアのcarrierから正常な生応答を構成する。 -/
theorem response_value {P base f d ts vs a e v}
    (lookup : P.externalFunction f = some d)
    (inst : d.instantiate ts vs = some (a,e))
    (carrier : ∀ Ψ, ExternalCarrier P base Ψ v a) (ground : v.Ground) :
    response P base f ts vs (.val v) [] := by
  refine ⟨rfl, ?_⟩
  intro Ψ other result effect found args
  have same := Option.some.inj (lookup.symm.trans found)
  subst other
  have equal := Option.some.inj (inst.symm.trans args.instantiate)
  cases equal
  exact ⟨⟨carrier Ψ,ground⟩,by intro n; simp⟩

/-- 正常な受信は元の結果型・閉性と、任意のσでの適格性を保つ。 -/
theorem receive_value {P base release Ψ f d ts vs a e v obs}
    (wf : P.ExternalWF) (lookup : P.externalFunction f = some d)
    (args : ExternalArgs P (builtins P base release) Ψ d ts vs a e)
    (raw : response P base f ts vs (.val v) obs)
    (check : externalCheck P v a = true) (σ : PathEnv) :
    externalReceive P d ts vs (.val v) = some (.val v) ∧
    HasTypeV P (builtins P base release) Ψ [] [] [] v a ∧ v.Ground ∧
    v.Adequate σ := by
  have received : externalReceive P d ts vs (.val v) = some (.val v) := by
    rw [externalReceive_of_args args]
    simp [externalCheckedOutcome,check]
  exact ⟨received,(external_assumptions P base release).received_value wf lookup args raw received σ⟩

/-- carrierを満たす篩違反は、生応答の関係を保ったまま受信時に拒否する。 -/
theorem receive_reject {P base release Ψ f d ts vs a e v obs}
    (wf : P.ExternalWF) (lookup : P.externalFunction f = some d)
    (args : ExternalArgs P (builtins P base release) Ψ d ts vs a e)
    (raw : response P base f ts vs (.val v) obs)
    (check : externalCheck P v a = false) :
    externalReceive P d ts vs (.val v) = some (.err "ExternalRefinement") ∧
    (∀ σ, v.Adequate σ) ∧ obs = [] := by
  refine ⟨?_,?_,?_⟩
  · rw [externalReceive_of_args args,externalCheckedOutcome_reject check]
  · exact fun σ => (external_assumptions P base release).external_adequate wf lookup args raw σ
  · exact (external_assumptions P base release).external_no_targets _ _ _ _ _ _ _ _ _ wf lookup args raw

/-- errは受信後も同じerrであり、任意のexitは型付き入力の生応答から除外する。 -/
theorem receive_error_no_exit {P base release Ψ f d ts vs a e}
    (args : ExternalArgs P (builtins P base release) Ψ d ts vs a e)
    (lookup : P.externalFunction f = some d) (r : Benitoite.Release.ErrKind) :
    response P base f ts vs (.err r) [] ∧
    externalReceive P d ts vs (.err r) = some (.err r) ∧
    ∀ n obs, ¬ response P base f ts vs (.exit n) obs := by
  refine ⟨response_err P base f ts vs r,?_,?_⟩
  · rw [externalReceive_of_args args]; rfl
  · intro n obs raw
    have result := raw.2 Ψ d a e lookup (args.of_fields (typing_fields P base release).symm)
    exact result.2 n rfl

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
