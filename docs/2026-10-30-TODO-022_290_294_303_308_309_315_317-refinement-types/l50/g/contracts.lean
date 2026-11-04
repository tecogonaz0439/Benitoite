import Benitoite

namespace ScopedIOContracts
open Benitoite.Release.Refinement
open ScopeSignatures ScopedIOResponse

/-- 群 A で固定した F07IO と同じ全称の契約。 -/
def F07IO (P : Program) (B : Builtins) (b : Benitoite.Release.PrimName) : Prop :=
  ∀ Ψ sg ts es rs ws a e, B.sig b = some sg → sg.kind = .io →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    (∀ out obs, B.ioResponse b ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      (∀ n, out ≠ .exit n) ∧
      Benitoite.Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs) ∧
    ∃ out obs, B.ioResponse b ts es ws out obs

example {P delta} (hp : ScopeDeclarations.HasFile P) (op : Operation) :
    (builtins delta ioResponse).sig op.name = some op.signature ∧
    F07IO P (builtins delta ioResponse) op.name := by
  refine ⟨op.lookup,?_⟩
  intro Ψ sg ts es rs ws a e hs kind args
  constructor
  · intro out obs hr
    obtain ⟨ht,ha⟩ := io_typed hp hs (Or.inl kind) args hr
    have hn := (io_kind hs hr).2
    obtain ⟨_,_,_,raw⟩ := hr
    exact ⟨ht,ha,hn,targets hs raw⟩
  · exact io_exists hp hs (Or.inl kind) args

example {P} (hp : ScopeDeclarations.HasHttp P) :
    (builtins ScopeResponse.delta ioResponse).ResponseAssumptions P ∧
    (builtins ScopeResponse.delta ioResponse).TargetAgreement P :=
  ⟨responseAssumptions hp,targetAgreement P ScopeResponse.delta⟩

/-- 任意 P/B の入口を、単独の表へ限定せず後段へ渡す。 -/
example {P B Ψ b sg ts es rs ws a e} (hp : ScopeDeclarations.HasHttp P)
    (hs : entries.lookup b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (pk : B.valKind "Scope.PathIn" = some .path)
    (rk : B.valKind "Http.RequestIn" = some .endpoint)
    (rc : B.valContent "Http.RequestIn" = some clientRequestTy)
    (ioError : B.valKind "IOError" = none ∧ B.valContent "IOError" = none)
    (httpResponse : B.valKind "Http.Response" = none ∧ B.valContent "Http.Response" = none)
    (networkError : B.valKind "NetworkError" = none ∧ B.valContent "NetworkError" = none)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e) :
    (∀ out obs, ioResponse b ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Benitoite.Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse b ts es ws out obs :=
  response hp.file hs kind pk rk rc ioError httpResponse networkError args
end ScopedIOContracts
