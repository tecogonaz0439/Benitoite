import Benitoite.Release.Refinement.Model
import Benitoite.Release.Refinement.ModelTargets
import Benitoite.Release.Refinement.ModelHttpConditions

/-! # 三つの実表が構成する七十五条件 -/
namespace Benitoite.Release.Refinement.ScopeModels
noncomputable section

/-- 同じ P の三つの表の二十五条件を、それぞれの実証明から構成する。 -/
theorem conditions (P : Program) (hp : ScopeDeclarations.HasHttp P) :
    ModelScopeConditions P Model.builtins ∧
    ModelScopeConditions P ModelTargets.builtins ∧
    ModelScopeConditions P ModelHttp.builtins :=
  ⟨Model.scopeConditions P,ModelTargets.scopeConditions P hp.file,ModelHttp.scopeConditions P hp⟩

/-- 有限宣言の具体 P でも、三モデルを同時に構成できる。 -/
example : ModelScopeConditions ScopeDeclarations.program Model.builtins ∧
    ModelScopeConditions ScopeDeclarations.program ModelTargets.builtins ∧
    ModelScopeConditions ScopeDeclarations.program ModelHttp.builtins :=
  conditions ScopeDeclarations.program ScopeDeclarations.program_hasHttp

/-- 各表の外部応答三条件と資源解放を別々に受け取り、各 Core と対象条件を得る。 -/
example (P : Program) (hp : ScopeDeclarations.HasHttp P)
    (em : Model.builtins.ExternalAssumptions P)
    (et : ModelTargets.builtins.ExternalAssumptions P)
    (eh : ModelHttp.builtins.ExternalAssumptions P)
    (rm : ∀ Ψ v o, HasTypeV P Model.builtins Ψ [] [] [] v (.opaque o (.fixed .top)) →
      Model.builtins.isResource o = true → ∃ r, Model.builtins.releaseResponse v r)
    (rt : ∀ Ψ v o, HasTypeV P ModelTargets.builtins Ψ [] [] [] v (.opaque o (.fixed .top)) →
      ModelTargets.builtins.isResource o = true → ∃ r, ModelTargets.builtins.releaseResponse v r)
    (rh : ∀ Ψ v o, HasTypeV P ModelHttp.builtins Ψ [] [] [] v (.opaque o (.fixed .top)) →
      ModelHttp.builtins.isResource o = true → ∃ r, ModelHttp.builtins.releaseResponse v r) :
    (Model.builtins.CoreAssumptions P ∧ Model.builtins.TargetAgreement P) ∧
    (ModelTargets.builtins.CoreAssumptions P ∧ ModelTargets.builtins.TargetAgreement P) ∧
    (ModelHttp.builtins.CoreAssumptions P ∧ ModelHttp.builtins.TargetAgreement P) := by
  obtain ⟨m,t,h⟩ := conditions P hp
  exact ⟨⟨m.core em rm,m.toTargetAgreement⟩,⟨t.core et rt,t.toTargetAgreement⟩,⟨h.core eh rh,h.toTargetAgreement⟩⟩
end
end Benitoite.Release.Refinement.ScopeModels
