import Benitoite
namespace L50FContracts
open Benitoite.Release.Refinement

-- 元の F07 の全量化を、同じ共通表と δ で読む。
example {P io} (hp : ScopeDeclarations.HasHttp P) :
    ∀ Ψ b sg ts es rs ws a e, (ScopeSignatures.builtins ScopeResponse.delta io).sig b = some sg →
      sg.kind = .pure → BuiltinArgs P (ScopeSignatures.builtins ScopeResponse.delta io) Ψ b sg ts es rs ws a e →
      ∃ out, (ScopeSignatures.builtins ScopeResponse.delta io).delta b ts es rs ws = some out ∧
        (∀ n, out ≠ .exit n) ∧ Outcome.Typed P (ScopeSignatures.builtins ScopeResponse.delta io) Ψ out a ∧
        AdequateResult ws out := by
  intros; exact ScopeResponse.delta_typed hp ‹_› ‹_› ‹_›

example (P : Program) (delta io) :
    (ScopeSignatures.builtins delta io).ValueAssumptions P ∧
      (ScopeSignatures.builtins delta io).TypeAssumptions P := by
  have h := ScopeSignatures.substitutionAssumptions P delta io
  exact ⟨h.toValueAssumptions,h.toTypeAssumptions⟩

example : ∀ (id : ExternalFunctionId) (ts : List Ty) (ws : List Val),
    AdequateResult ws (.val (.externalRef id ts)) := ScopeResponse.adequate_externalRef
example : ∀ (h : ExternalHandle) (ts : List Ty) (ws : List Val),
    AdequateResult ws (.val (.externalHandle h ts)) := ScopeResponse.adequate_externalHandle
example : ∀ (r : RangeExpr) (ws : List Val),
    AdequateResult ws (.val (.scopePattern r)) := ScopeResponse.adequate_scopePattern
end L50FContracts
