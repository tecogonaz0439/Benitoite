import Benitoite
import Lean.Elab.Command
namespace ModelTargetsContracts
open Benitoite.Release.Refinement

-- 群 A の F09File と同じ全称の型であり、同じ P/B を保つ。
example : ∀ P, ScopeDeclarations.HasFile P → ModelScopeConditions P ModelTargets.builtins :=
  ModelTargets.scopeConditions

def Pure (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg → sg.kind = .pure →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out

example {P} (hp : ScopeDeclarations.HasFile P) : ∀ b, Pure P ModelTargets.builtins b := by
  intro b Ψ sg ts es rs ws a e hs hk args
  exact ModelTargets.delta_typed hp hs hk args

def Ground (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e out v, B.sig b = some sg → sg.kind = .pure →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → B.delta b ts es rs ws = some out →
    out = .val v → v.Ground

example {P} (hp : ScopeDeclarations.HasFile P) : ∀ b, Ground P ModelTargets.builtins b := by
  intro b Ψ sg ts es rs ws a e out v hs hk args hd hv
  exact (ModelTargets.pure_outcome hp hs hk args hd).2.2.2 v hv

def IO (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg → sg.kind = .io →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ out obs, B.ioResponse b ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Benitoite.Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs) ∧
    ∃ out obs, B.ioResponse b ts es ws out obs

example {P} (hp : ScopeDeclarations.HasFile P) : ∀ b, IO P ModelTargets.builtins b := by
  intro b Ψ sg ts es rs ws a e hs hk args
  refine ⟨?_,ModelTargets.io_exists hp hs (Or.inl hk) args⟩
  intro out obs hr
  obtain ⟨ht,ha⟩ := ModelTargets.io_typed hp hs (Or.inl hk) args hr
  have kind := ModelTargets.io_kind hs args hr
  have noExit : ¬ (sg.kind = .exit ∧ ∀ v, out ≠ .val v) := by rw [hk]; simp
  exact ⟨ht,ha,(kind.resolve_right noExit).2,
    (ModelTargets.targetAgreement P).io_target Ψ b sg ts es rs ws a e out obs hs (Or.inl hk) args hr⟩

-- 新 Core 全体の充足と区別し、外部三条件と通常資源の解放を受け取る。
example {P} (hp : ScopeDeclarations.HasFile P)
    (external : ModelTargets.builtins.ExternalAssumptions P)
    (release : ∀ Ψ v o, HasTypeV P ModelTargets.builtins Ψ [] [] [] v (.opaque o (.fixed .top)) →
      ModelTargets.builtins.isResource o = true → ∃ r, ModelTargets.builtins.releaseResponse v r) :
    ModelTargets.builtins.CoreAssumptions P ∧ ModelTargets.builtins.TargetAgreement P :=
  ⟨(ModelTargets.scopeConditions P hp).core external release,
    (ModelTargets.scopeConditions P hp).toTargetAgreement⟩
end ModelTargetsContracts
