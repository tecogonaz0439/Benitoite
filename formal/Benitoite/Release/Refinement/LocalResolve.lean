import Benitoite.Release.Refinement.Subst

/-! 型注釈を変えず、局所の参照だけを置き換える。 -/
namespace Benitoite.Release.Refinement

mutual
  def Val.resolveLocals (ρ : Nat → LocalRef) : Val → Val
    | .var i => .var i
    | .const c => .const c
    | .fnRef f tys effs rs => .fnRef f tys effs rs
    | .prim b tys effs rs => .prim b tys effs rs
    | .lam names params body => .lam names params (Comp.resolveLocals (upLocalSubst params.length ρ) body)
    | .dependentLam t body => .dependentLam t (Comp.resolveLocals (upLocalSubst (telBinders t) ρ) body)
    | .closure t body => .closure t body
    | .con c tys args => .con c tys (Val.resolveLocalsList ρ args)
    | .list elems => .list (Val.resolveLocalsList ρ elems)
    | .op o tys => .op o tys
    | .raise t e => .raise t e
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.resolveLocalsList ρ ks) (Val.resolveLocalsList ρ vs)
    | .setV elems => .setV (Val.resolveLocalsList ρ elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i tys (Val.resolveLocalsList ρ args)
    | .super v cl => .super (Val.resolveLocals ρ v) cl
    | .externalRef f tys => .externalRef f tys
    | .externalHandle h tys => .externalHandle h tys
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  def Val.resolveLocalsList (ρ : Nat → LocalRef) : List Val → List Val
    | [] => []
    | v :: vs => Val.resolveLocals ρ v :: Val.resolveLocalsList ρ vs

  def Comp.resolveLocals (ρ : Nat → LocalRef) : Comp → Comp
    | .builderLet k body => .builderLet k (Comp.resolveLocals (upLocalSubst 1 ρ) body)
    | .builderOp k op r args => .builderOp k op (r.subst ρ) (Val.resolveLocalsList ρ args)
    | .ret v => .ret (Val.resolveLocals ρ v)
    | .letIn m n => .letIn (Comp.resolveLocals ρ m) (Comp.resolveLocals (upLocalSubst 1 ρ) n)
    | .app f args => .app (Val.resolveLocals ρ f) (Val.resolveLocalsList ρ args)
    | .ite v m n => .ite (Val.resolveLocals ρ v) (Comp.resolveLocals ρ m) (Comp.resolveLocals ρ n)
    | .match v arms => .match (Val.resolveLocals ρ v) (Arm.resolveLocalsList ρ arms)
    | .lazyC m => .lazyC (Comp.resolveLocals ρ m)
    | .escape v => .escape (Val.resolveLocals ρ v)
    | .use v m => .use (Val.resolveLocals ρ v) (Comp.resolveLocals ρ m)
    | .handle m h => .handle (Comp.resolveLocals ρ m) (Clause.resolveLocalsList ρ h)
    | .resume k v => .resume (Val.resolveLocals ρ k) (Val.resolveLocals ρ v)
    | .externalCall f tys args => .externalCall f tys (Val.resolveLocalsList ρ args)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh bs p v ix => .checkAt k o sh
        (match bs with | none => none | some b => some (b.resolveLocals ρ)) (p.resolveLocals ρ) (v.resolveLocals ρ) ix
    | .meth d m tys effs args => .meth (Val.resolveLocals ρ d) m tys effs (Val.resolveLocalsList ρ args)

  def Arm.resolveLocalsList (ρ : Nat → LocalRef) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.resolveLocals (upLocalSubst (Benitoite.Release.Arm.bindersOf alts) ρ) m) :: Arm.resolveLocalsList ρ arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.resolveLocals (upLocalSubst (Benitoite.Release.Arm.bindersOf alts) ρ) g))
          (Comp.resolveLocals (upLocalSubst (Benitoite.Release.Arm.bindersOf alts) ρ) m) :: Arm.resolveLocalsList ρ arms

  def Clause.resolveLocalsList (ρ : Nat → LocalRef) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.resolveLocals (upLocalSubst (n + 1) ρ) m) :: Clause.resolveLocalsList ρ cs
    | .fail e m :: cs => .fail e (Comp.resolveLocals (upLocalSubst 2 ρ) m) :: Clause.resolveLocalsList ρ cs
end

end Benitoite.Release.Refinement
