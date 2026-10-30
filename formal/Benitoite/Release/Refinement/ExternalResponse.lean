import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.Ground

/-!
# 外部応答の型付き入力と三つの信頼条件

errは実行時エラー、exitは外部応答では禁止する。正常応答の存在と決定性は要求しない。
-/
namespace Benitoite.Release.Refinement

noncomputable def ExternalSignature.instantiate (d : ExternalSignature) (ts : List Ty) (vs : List Val) :
    Option (Ty × Eff) :=
  if ts.length = d.tparams.length then Tel.instantiate (Tel.bind (typeEnv ts) d.parameters) vs else none

structure ExternalArgs (P : Program) (B : Builtins) (Ψ : StoreTy) (d : ExternalSignature)
    (ts : List Ty) (vs : List Val) (a : Ty) (e : Eff) : Prop where
  admissible : ExternalCallAdmissible P B [] d ts
  arguments : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (Tel.bind (typeEnv ts) d.parameters) a e
  ground : ∀ v ∈ vs, v.Ground
  types : ∀ t ∈ ts, t.WF 0 0 0 ∧ t.Canonical
  result : a.WF 0 0 0 ∧ a.Canonical
  effect : Eff.WF 0 0 0 e ∧ e.Canonical

def Outcome.Typed (P : Program) (B : Builtins) (Ψ : StoreTy) (out : Outcome) (a : Ty) : Prop :=
  match out with
  | .val v => HasTypeV P B Ψ [] [] [] v a ∧ v.Ground
  | .err _ | .exit _ => True

structure Builtins.ExternalAssumptions (P : Program) (B : Builtins) : Prop where
  external_typed : ∀ Ψ f d ts vs a e out obs,
    P.ExternalWF → P.externalFunction f = some d → ExternalArgs P B Ψ d ts vs a e →
    B.externalResponse f ts vs out obs → Outcome.Typed P B Ψ out a ∧ (∀ n : Int, out ≠ .exit n)
  external_exists : ∀ Ψ f d ts vs a e,
    P.ExternalWF → P.externalFunction f = some d → ExternalArgs P B Ψ d ts vs a e →
    ∃ out obs, B.externalResponse f ts vs out obs
  external_no_targets : ∀ Ψ f d ts vs a e out obs,
    P.ExternalWF → P.externalFunction f = some d → ExternalArgs P B Ψ d ts vs a e →
    B.externalResponse f ts vs out obs → obs = []

end Benitoite.Release.Refinement
