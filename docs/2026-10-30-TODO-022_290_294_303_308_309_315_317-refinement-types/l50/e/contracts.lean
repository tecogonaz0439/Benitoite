import Lean
import Benitoite
namespace L50EContracts
open Benitoite.Release.Refinement

/-- 群Aで固定した一つの純粋行の全称の受け口。 -/
def F07Pure (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg → sg.kind = .pure →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out

def F07Ground (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e out v, B.sig b = some sg → sg.kind = .pure →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    B.delta b ts es rs ws = some out → out = .val v → v.Ground

example : ∀ row ∈ ScopeSignatures.entries,
    PrimSig.Scoped ScopeDeclarations.program row.2 :=
  ScopeSignatures.entries_scoped ScopeDeclarations.program_hasHttp

example {P io} (hp : ScopeDeclarations.HasHttp P) :
    F07Pure P (ScopeSignatures.builtins RequestDelta.delta io) "Http.checkRequestIn" := by
  intro Ψ sg ts es rs ws a e hs _ args
  have he : sg = ScopeSignatures.checkRequestIn := (Option.some.inj hs).symm
  subst sg
  obtain ⟨out,hd,hn,ht,ha,_⟩ := RequestDelta.response hp rfl rfl args
  exact ⟨out,hd,hn,ht,ha⟩

example {P io} (hp : ScopeDeclarations.HasFile P) :
    F07Pure P (ScopeSignatures.builtins RequestDelta.delta io) "Scope.checkPathIn" := by
  intro Ψ sg ts es rs ws a e hs _ args
  have he : sg = ScopeSignatures.checkPathIn := (Option.some.inj hs).symm
  subst sg
  obtain ⟨out,hd,hn,ht,ha,_⟩ := ScopeDelta.response hp rfl rfl args
  exact ⟨out,by simpa [ScopeSignatures.builtins,RequestDelta.delta] using hd,hn,ht,ha⟩

example {P io} (hp : ScopeDeclarations.HasHttp P) :
    F07Ground P (ScopeSignatures.builtins RequestDelta.delta io) "Http.checkRequestIn" := by
  intro Ψ sg ts es rs ws a e out v hs _ args hd hv
  have he : sg = ScopeSignatures.checkRequestIn := (Option.some.inj hs).symm
  subst sg
  obtain ⟨out',hd',_,_,_,hg⟩ := RequestDelta.response hp rfl rfl args
  have same : out' = out := Option.some.inj (hd'.symm.trans hd)
  subst out'
  exact hg v hv

example {P io} (hp : ScopeDeclarations.HasFile P) :
    F07Ground P (ScopeSignatures.builtins RequestDelta.delta io) "Scope.checkPathIn" := by
  intro Ψ sg ts es rs ws a e out v hs _ args hd hv
  have he : sg = ScopeSignatures.checkPathIn := (Option.some.inj hs).symm
  subst sg
  obtain ⟨out',hd',_,_,_,hg⟩ := ScopeDelta.response hp rfl rfl args
  have hdelta : ScopeDelta.delta "Scope.checkPathIn" ts es rs ws = some out := by
    simpa [ScopeSignatures.builtins,RequestDelta.delta] using hd
  have same : out' = out := Option.some.inj (hd'.symm.trans hdelta)
  subst out'
  exact hg v hv

example {delta io} (ts es ws out obs) :
    ¬ (ScopeSignatures.builtins delta io).ioResponse ScopeSignatures.pathBasesName ts es ws out obs :=
  ScopeSignatures.pathBases_no_io rfl rfl ts es ws out obs
end L50EContracts
