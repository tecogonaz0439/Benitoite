import Benitoite.Release.Refinement.ExternalResponse
import Benitoite.Release.Refinement.Adequate

/-! # 組込み応答の型付き入力と保持値の適格性 -/
namespace Benitoite.Release.Refinement

structure BuiltinArgs (P : Program) (B : Builtins) (Ψ : StoreTy) (b : PrimName) (sg : PrimSig)
    (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) (a : Ty) (e : Eff) : Prop where
  admissible : PrimitiveAdmissible [] 0 sg Qempty ts es
  ranges : B.RangeAdmissible b sg rs
  signature : SignatureInstance P [] [] (Tel.instR rs sg.tel) (sg.tparams.map TParamDecl.kind) ts es
  arguments : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
    (instantiatedTel (Tel.instR rs sg.tel) ts es) a e
  ground : ∀ w ∈ ws, w.Ground
  types : ∀ t ∈ ts, t.WF 0 0 0 ∧ t.Canonical
  rows : ∀ e ∈ es, Eff.WF 0 0 0 e ∧ e.Canonical
  result : a.WF 0 0 0 ∧ a.Canonical
  effect : Eff.WF 0 0 0 e ∧ e.Canonical

structure Builtins.ResponseAssumptions (P : Program) (B : Builtins) : Prop where
  delta_typed : ∀ Ψ b sg ts es rs ws a e,
    B.sig b = some sg → sg.kind = .pure → BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out, B.delta b ts es rs ws = some out ∧ (∀ n, out ≠ .exit n) ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
  io_typed : ∀ Ψ b sg ts es rs ws a e out obs,
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → B.ioResponse b ts es ws out obs →
    Outcome.Typed P B Ψ out a ∧ AdequateResult ws out
  io_kind : ∀ Ψ b sg ts es rs ws a e out obs,
    B.sig b = some sg → BuiltinArgs P B Ψ b sg ts es rs ws a e →
    B.ioResponse b ts es ws out obs →
    (sg.kind = .io ∧ ∀ n, out ≠ .exit n) ∨ (sg.kind = .exit ∧ ∀ v, out ≠ .val v)
  io_exists : ∀ Ψ b sg ts es rs ws a e,
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e →
    ∃ out obs, B.ioResponse b ts es ws out obs

def PrimSig.shapeAt (sg : PrimSig) (ws : List Val) : Scope.Signature.IOShape :=
  match sg.shape with
  | .single k p => if ((ws[p]?).bind Val.target?).isSome then .single k p else .topTargeted k
  | shape => shape

structure Builtins.TargetAgreement (P : Program) (B : Builtins) : Prop where
  io_target : ∀ Ψ b sg ts es rs ws a e out obs,
    B.sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
    BuiltinArgs P B Ψ b sg ts es rs ws a e → B.ioResponse b ts es ws out obs →
    Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs

end Benitoite.Release.Refinement
