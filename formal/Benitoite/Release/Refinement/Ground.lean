import Benitoite.Release.Refinement.Admissible

/-!
# 実引数と応答の閉性

型・行・範囲・値の自由変数を構文で検査する。場所番号と名目IDは束縛変数ではない。
-/
namespace Benitoite.Release.Refinement

private def localBound (n : Nat) : LocalRef → Prop
  | .bound i => i < n
  | .loc _ => True
private def builderBound (nt n : Nat) : BuilderKind → Prop
  | .list a => a.WF 0 nt n
  | _ => True

mutual
  def Val.ClosedAt (nt nv : Nat) : Val → Prop
    | .var i => i < nv
    | .const _ | .loc _ | .bytesV _ | .checked _ | .pathBases _ | .scopePattern _ | .atError _ => True
    | .checkedAt _ _ _ req => match req with | none => True | some v => v.ClosedAt 0 0
    | .fnRef _ ts es => (∀ a ∈ ts, a.WF 0 nt nv) ∧ (∀ e ∈ es, Eff.WF 0 nt nv e ∧ e.Canonical)
    | .prim _ ts es rs => (∀ a ∈ ts, a.WF 0 nt nv) ∧
        (∀ e ∈ es, Eff.WF 0 nt nv e ∧ e.Canonical) ∧ (∀ r ∈ rs, r.WF)
    | .externalRef _ ts | .externalHandle _ ts => ∀ a ∈ ts, a.WF 0 nt nv
    | .lam ns ps body => NamesWF ns ps ∧ (∀ a ∈ ps, a.WF 0 nt nv) ∧
        Comp.ClosedAt nt (nv + ps.length) body
    | .dependentLam t body => Tel.WF 0 nt nv t ∧ Comp.ClosedAt nt (nv + telBinders t) body
    | .closure t q => Tel.WF 0 0 0 t ∧ Closure.ClosedAt (telBinders t) q
    | .con _ ts vs | .dict _ ts vs => (∀ a ∈ ts, a.WF 0 nt nv) ∧ Val.ClosedList nt nv vs
    | .list vs | .setV vs => Val.ClosedList nt nv vs
    | .op _ ts => ∀ a ∈ ts, a.WF 0 nt nv
    | .raise a e => a.WF 0 nt nv ∧ e.WF 0 nt nv
    | .mapV ks vs => Val.ClosedList nt nv ks ∧ Val.ClosedList nt nv vs
    | .super v _ => v.ClosedAt nt nv
    | .checkedRequest _ req => req.ClosedAt 0 0
  def Val.ClosedList (nt nv : Nat) : List Val → Prop
    | [] => True
    | v :: vs => v.ClosedAt nt nv ∧ Val.ClosedList nt nv vs
  def Comp.ClosedAt (nt nv : Nat) : Comp → Prop
    | .builderLet b m => builderBound nt nv b ∧ m.ClosedAt nt (nv+1)
    | .builderOp b _ r vs => builderBound nt nv b ∧ localBound nv r ∧ Val.ClosedList nt nv vs
    | .ret v | .escape v => v.ClosedAt nt nv
    | .letIn m n => m.ClosedAt nt nv ∧ n.ClosedAt nt (nv+1)
    | .app v vs => v.ClosedAt nt nv ∧ Val.ClosedList nt nv vs
    | .ite v m n => v.ClosedAt nt nv ∧ m.ClosedAt nt nv ∧ n.ClosedAt nt nv
    | .match v arms => v.ClosedAt nt nv ∧ Arm.ClosedList nt nv arms
    | .lazyC m => m.ClosedAt nt nv
    | .use v m => v.ClosedAt nt nv ∧ m.ClosedAt nt nv
    | .handle m cs => m.ClosedAt nt nv ∧ Clause.ClosedList nt nv cs
    | .resume k v => k.ClosedAt nt nv ∧ v.ClosedAt nt nv
    | .meth v _ ts es vs => v.ClosedAt nt nv ∧ (∀ a ∈ ts, a.WF 0 nt nv) ∧
        (∀ e ∈ es, Eff.WF 0 nt nv e ∧ e.Canonical) ∧ Val.ClosedList nt nv vs
    | .issuePathBases _ => True
    | .checkAt _ _ shape bases p v ix => shape.errorType.WF 0 nt nv ∧ ix.WF 0 ∧
        (match bases with | none => True | some b => b.ClosedAt nt nv) ∧
        p.ClosedAt nt nv ∧ v.ClosedAt nt nv
    | .externalCall _ ts vs => (∀ a ∈ ts, a.WF 0 nt nv) ∧ Val.ClosedList nt nv vs
  def Arm.ClosedList (nt nv : Nat) : List Arm → Prop
    | [] => True
    | .mk alts guard body :: arms =>
        (match guard with | none => True | some g => g.ClosedAt nt (nv + Benitoite.Release.Arm.bindersOf alts)) ∧
        body.ClosedAt nt (nv + Benitoite.Release.Arm.bindersOf alts) ∧ Arm.ClosedList nt nv arms
  def Clause.ClosedList (nt nv : Nat) : List Clause → Prop
    | [] => True
    | .mk _ arity ntys body :: cs => body.ClosedAt (nt+ntys) (nv+arity+1) ∧ Clause.ClosedList nt nv cs
    | .fail e body :: cs => e.WF 0 nt nv ∧ body.ClosedAt (nt+1) (nv+2) ∧ Clause.ClosedList nt nv cs
  def Capture.Closed : Capture → Prop
    | .mk vs => captureSlotsClosed vs
  def captureSlotsClosed : List (Option Val) → Prop
    | [] => True
    | none :: vs => captureSlotsClosed vs
    | some v :: vs => v.ClosedAt 0 0 ∧ captureSlotsClosed vs
  def Closure.ClosedAt (inputs : Nat) : Closure → Prop
    | .mk cap m => cap.Closed ∧ m.ClosedAt 0 (cap.values.length + inputs)
end

def Val.Ground (v : Val) : Prop := v.ClosedAt 0 0

end Benitoite.Release.Refinement
