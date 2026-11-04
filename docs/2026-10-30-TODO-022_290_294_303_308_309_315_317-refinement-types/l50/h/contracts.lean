import Benitoite
namespace ModelContracts
open Benitoite.Release.Refinement
-- 群 A の F09Model と同じ全称の型であり、追加の P の条件はない。
example : ∀ P, ModelScopeConditions P Model.builtins := Model.scopeConditions
example (P : Program) : Model.builtins.SubstitutionAssumptions P := Model.substitutionAssumptions P
example (P : Program) : Model.builtins.ResponseAssumptions P := Model.responseAssumptions P
example (P : Program) : Model.builtins.TargetAgreement P := Model.targetAgreement P
-- 元の Core の未充足欄を独立した入力として残す。
example (P : Program) (external : Model.builtins.ExternalAssumptions P)
    (release : ∀ Ψ v o, HasTypeV P Model.builtins Ψ [] [] [] v (.opaque o (.fixed .top)) →
      Model.builtins.isResource o = true → ∃ r, Model.builtins.releaseResponse v r) :
    Model.builtins.CoreAssumptions P := (Model.scopeConditions P).core external release
end ModelContracts
