import Benitoite.Release.Refinement.Syntax

/-!
# 項の改名と置換

値・計算・腕・節の型注釈も移し、束縛を越えるときに像を移動する。
-/

namespace Benitoite.Release.Refinement

def renEnv (ξ : Nat → Nat) : SubstEnv :=
  ⟨Ty.tvar, [], [], fun i => some (.var (ξ i))⟩
@[simp] theorem renEnv_up (ξ : Nat → Nat) : (renEnv ξ).up = renEnv (upRen 1 ξ) := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  funext i
  cases i <;> simp [upValues, renEnv, upRen, termBind, termBind?]

def renameTy (ξ : Nat → Nat) (a : Ty) : Ty := a.rawBind (renEnv ξ)
def renameEff (ξ : Nat → Nat) (e : Eff) : Eff := Eff.rawBind (renEnv ξ) e
def renameKind (ξ : Nat → Nat) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (renameTy ξ a)

def telBinders : Tel → Nat
  | .done _ _ => 0
  | .param _ _ t => telBinders t + 1


mutual
  def Val.rename (ξ : Nat → Nat) : Val → Val
    | .var i => .var (ξ i)
    | .const c => .const c
    | .fnRef f tys effs rs => .fnRef f (tys.map (renameTy ξ)) (effs.map (renameEff ξ)) rs
    | .prim b tys effs rs => .prim b (tys.map (renameTy ξ)) (effs.map (renameEff ξ)) rs
    | .lam names params body => .lam names (params.map (renameTy ξ)) (Comp.rename (upRen params.length ξ) body)
    | .dependentLam t body => .dependentLam (Tel.rawBind (renEnv ξ) t) (Comp.rename (upRen (telBinders t) ξ) body)
    | .closure t body => .closure t body
    | .con c tys args => .con c (tys.map (renameTy ξ)) (Val.renameList ξ args)
    | .list elems => .list (Val.renameList ξ elems)
    | .op o tys => .op o (tys.map (renameTy ξ))
    | .raise t e => .raise (renameTy ξ t) (renameTy ξ e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.renameList ξ ks) (Val.renameList ξ vs)
    | .setV elems => .setV (Val.renameList ξ elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (renameTy ξ)) (Val.renameList ξ args)
    | .super v cl => .super (Val.rename ξ v) cl
    | .externalRef f tys => .externalRef f (tys.map (renameTy ξ))
    | .externalHandle h tys => .externalHandle h (tys.map (renameTy ξ))
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  def Val.renameList (ξ : Nat → Nat) : List Val → List Val
    | [] => []
    | v :: vs => Val.rename ξ v :: Val.renameList ξ vs

  def Comp.rename (ξ : Nat → Nat) : Comp → Comp
    | .builderLet k body => .builderLet (renameKind ξ k) (Comp.rename (upRen 1 ξ) body)
    | .builderOp k op r args => .builderOp (renameKind ξ k) op (r.rename ξ) (Val.renameList ξ args)
    | .ret v => .ret (Val.rename ξ v)
    | .letIn m n => .letIn (Comp.rename ξ m) (Comp.rename (upRen 1 ξ) n)
    | .app f args => .app (Val.rename ξ f) (Val.renameList ξ args)
    | .ite v m n => .ite (Val.rename ξ v) (Comp.rename ξ m) (Comp.rename ξ n)
    | .match v arms => .match (Val.rename ξ v) (Arm.renameList ξ arms)
    | .lazyC m => .lazyC (Comp.rename ξ m)
    | .escape v => .escape (Val.rename ξ v)
    | .use v m => .use (Val.rename ξ v) (Comp.rename ξ m)
    | .handle m h => .handle (Comp.rename ξ m) (Clause.renameList ξ h)
    | .resume k v => .resume (Val.rename ξ k) (Val.rename ξ v)
    | .externalCall f tys args => .externalCall f (tys.map (renameTy ξ)) (Val.renameList ξ args)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh bs p v ix => .checkAt k o {sh with errorType := renameTy ξ sh.errorType}
        (match bs with | none => none | some b => some (b.rename ξ)) (p.rename ξ) (v.rename ξ) ix
    | .meth d m tys effs args => .meth (Val.rename ξ d) m (tys.map (renameTy ξ)) (effs.map (renameEff ξ)) (Val.renameList ξ args)

  def Arm.renameList (ξ : Nat → Nat) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.rename (upRen (Benitoite.Release.Arm.bindersOf alts) ξ) m) :: Arm.renameList ξ arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.rename (upRen (Benitoite.Release.Arm.bindersOf alts) ξ) g))
          (Comp.rename (upRen (Benitoite.Release.Arm.bindersOf alts) ξ) m) :: Arm.renameList ξ arms

  def Clause.renameList (ξ : Nat → Nat) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.rename (upRen (n + 1) ξ) m) :: Clause.renameList ξ cs
    | .fail e m :: cs => .fail (renameTy ξ e) (Comp.rename (upRen 2 ξ) m) :: Clause.renameList ξ cs
end


def valEnv (σ : Nat → Val) : SubstEnv :=
  ⟨Ty.tvar, [], [], fun i => (σ i).toTerm?⟩
noncomputable def substTyValues (σ : Nat → Val) (a : Ty) : Ty := a.bind (valEnv σ)
noncomputable def substEffValues (σ : Nat → Val) (e : Eff) : Eff := Eff.bind (valEnv σ) e
noncomputable def substKind (σ : Nat → Val) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (substTyValues σ a)

def upSubst (k : Nat) (σ : Nat → Val) (i : Nat) : Val :=
  if i < k then .var i else (σ (i - k)).rename (· + k)

mutual
  def shiftTypes (k c : Nat) : Ty → Ty
    | .base b => .base b
    | .opaque o ix => .opaque o ix
    | .data d as => .data d (shiftTypesList k c as)
    | .list a => .list (shiftTypes k c a)
    | .fn ns ps r e => .fn ns (shiftTypesList k c ps) (shiftTypes k c r) (shiftRowsTypes k c e)
    | .tvar i => .tvar (if i < c then i else i+k)
    | .reference a => .reference (shiftTypes k c a)
    | .lazy a => .lazy (shiftTypes k c a)
    | .cont b t e => .cont (shiftTypes k c b) (shiftTypes k c t) (shiftRowsTypes k c e)
    | .map a b => .map (shiftTypes k c a) (shiftTypes k c b)
    | .set a => .set (shiftTypes k c a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (shiftTypes k c a)
    | .tapp i as => .tapp (if i < c then i else i+k) (shiftTypesList k c as)
    | .ctor φ => .ctor φ
    | .refined a p => .refined (shiftTypes k c a) p
    | .dependentFn t => .dependentFn (shiftTelTypes k c t)
    | .external id as => .external id (shiftTypesList k c as)
    | .scoped o kind ix => .scoped o kind ix
    | .pathBases => .pathBases
    | .scopePattern kind => .scopePattern kind
  def shiftTelTypes (k c : Nat) : Tel → Tel
    | .done r e => .done (shiftTypes k c r) (shiftRowsTypes k c e)
    | .param n a t => .param n (shiftTypes k c a) (shiftTelTypes k c t)
  def shiftTypesList (k c : Nat) : List Ty → List Ty
    | [] => []
    | a :: as => shiftTypes k c a :: shiftTypesList k c as
  def shiftRowsTypes (k c : Nat) : Eff → Eff
    | .mk a fs => .mk a (shiftTypesList k c fs)
end

def shiftKindE (k c : Nat) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (shiftTypes k c a)

mutual
  def Val.shiftEAt (k c : Nat) : Val → Val
    | .var i => .var i
    | .const c => .const c
    | .fnRef f tys effs rs => .fnRef f (tys.map (shiftTypes k c)) (effs.map (shiftRowsTypes k c)) rs
    | .prim b tys effs rs => .prim b (tys.map (shiftTypes k c)) (effs.map (shiftRowsTypes k c)) rs
    | .lam names params body => .lam names (params.map (shiftTypes k c)) (Comp.shiftEAt k c body)
    | .dependentLam t body => .dependentLam (shiftTelTypes k c t) (Comp.shiftEAt k c body)
    | .closure t body => .closure t body
    | .con con tys args => .con con (tys.map (shiftTypes k c)) (Val.shiftEListAt k c args)
    | .list elems => .list (Val.shiftEListAt k c elems)
    | .op o tys => .op o (tys.map (shiftTypes k c))
    | .raise t e => .raise (shiftTypes k c t) (shiftTypes k c e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.shiftEListAt k c ks) (Val.shiftEListAt k c vs)
    | .setV elems => .setV (Val.shiftEListAt k c elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (shiftTypes k c)) (Val.shiftEListAt k c args)
    | .super v cl => .super (Val.shiftEAt k c v) cl
    | .externalRef f tys => .externalRef f (tys.map (shiftTypes k c))
    | .externalHandle h tys => .externalHandle h (tys.map (shiftTypes k c))
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  def Val.shiftEListAt (k c : Nat) : List Val → List Val
    | [] => []
    | v :: vs => Val.shiftEAt k c v :: Val.shiftEListAt k c vs

  def Comp.shiftEAt (k c : Nat) : Comp → Comp
    | .builderLet kind body => .builderLet (shiftKindE k c kind) (Comp.shiftEAt k c body)
    | .builderOp kind op r args => .builderOp (shiftKindE k c kind) op r (Val.shiftEListAt k c args)
    | .ret v => .ret (Val.shiftEAt k c v)
    | .letIn m n => .letIn (Comp.shiftEAt k c m) (Comp.shiftEAt k c n)
    | .app f args => .app (Val.shiftEAt k c f) (Val.shiftEListAt k c args)
    | .ite v m n => .ite (Val.shiftEAt k c v) (Comp.shiftEAt k c m) (Comp.shiftEAt k c n)
    | .match v arms => .match (Val.shiftEAt k c v) (Arm.shiftEListAt k c arms)
    | .lazyC m => .lazyC (Comp.shiftEAt k c m)
    | .escape v => .escape (Val.shiftEAt k c v)
    | .use v m => .use (Val.shiftEAt k c v) (Comp.shiftEAt k c m)
    | .handle m h => .handle (Comp.shiftEAt k c m) (Clause.shiftEListAt k c h)
    | .resume cont v => .resume (Val.shiftEAt k c cont) (Val.shiftEAt k c v)
    | .externalCall f tys args => .externalCall f (tys.map (shiftTypes k c)) (Val.shiftEListAt k c args)
    | .issuePathBases b => .issuePathBases b
    | .checkAt kind o sh bs p v ix => .checkAt kind o {sh with errorType := shiftTypes k c sh.errorType}
        (match bs with | none => none | some b => some (b.shiftEAt k c)) (p.shiftEAt k c) (v.shiftEAt k c) ix
    | .meth d m tys effs args => .meth (Val.shiftEAt k c d) m (tys.map (shiftTypes k c)) (effs.map (shiftRowsTypes k c)) (Val.shiftEListAt k c args)

  def Arm.shiftEListAt (k c : Nat) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.shiftEAt k c m) :: Arm.shiftEListAt k c arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.shiftEAt k c g))
          (Comp.shiftEAt k c m) :: Arm.shiftEListAt k c arms

  def Clause.shiftEListAt (k c : Nat) : List Clause → List Clause
    | [] => []
    | .mk o n k' m :: cs => .mk o n k' (Comp.shiftEAt k (c + k') m) :: Clause.shiftEListAt k c cs
    | .fail e m :: cs => .fail (shiftTypes k c e) (Comp.shiftEAt k (c+1) m) :: Clause.shiftEListAt k c cs
end

noncomputable section
mutual
  def Val.subst (σ : Nat → Val) (v : Val) (ρ : Nat → LocalRef := LocalRef.bound) : Val :=
    match v with
    | .var i => σ i
    | .const c => .const c
    | .fnRef f tys effs rs => .fnRef f (tys.map (substTyValues σ)) (effs.map (substEffValues σ)) rs
    | .prim b tys effs rs => .prim b (tys.map (substTyValues σ)) (effs.map (substEffValues σ)) rs
    | .lam names params body => .lam names (params.map (substTyValues σ)) (Comp.subst (upSubst params.length σ) body (upLocalSubst params.length ρ))
    | .dependentLam t body => .dependentLam (Tel.bind (valEnv σ) t) (Comp.subst (upSubst (telBinders t) σ) body (upLocalSubst (telBinders t) ρ))
    | .closure t body => .closure t body
    | .con c tys args => .con c (tys.map (substTyValues σ)) (Val.substList σ args ρ)
    | .list elems => .list (Val.substList σ elems ρ)
    | .op o tys => .op o (tys.map (substTyValues σ))
    | .raise t e => .raise (substTyValues σ t) (substTyValues σ e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.substList σ ks ρ) (Val.substList σ vs ρ)
    | .setV elems => .setV (Val.substList σ elems ρ)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (substTyValues σ)) (Val.substList σ args ρ)
    | .super v cl => .super (Val.subst σ v ρ) cl
    | .externalRef f tys => .externalRef f (tys.map (substTyValues σ))
    | .externalHandle h tys => .externalHandle h (tys.map (substTyValues σ))
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  def Val.substList (σ : Nat → Val) (vs : List Val) (ρ : Nat → LocalRef := LocalRef.bound) : List Val :=
    match vs with
    | [] => []
    | v :: vs => Val.subst σ v ρ :: Val.substList σ vs ρ

  def Comp.subst (σ : Nat → Val) (m : Comp) (ρ : Nat → LocalRef := LocalRef.bound) : Comp :=
    match m with
    | .builderLet k body => .builderLet (substKind σ k) (Comp.subst (upSubst 1 σ) body (upLocalSubst 1 ρ))
    | .builderOp k op r args => .builderOp (substKind σ k) op (r.subst ρ) (Val.substList σ args ρ)
    | .ret v => .ret (Val.subst σ v ρ)
    | .letIn m n => .letIn (Comp.subst σ m ρ) (Comp.subst (upSubst 1 σ) n (upLocalSubst 1 ρ))
    | .app f args => .app (Val.subst σ f ρ) (Val.substList σ args ρ)
    | .ite v m n => .ite (Val.subst σ v ρ) (Comp.subst σ m ρ) (Comp.subst σ n ρ)
    | .match v arms => .match (Val.subst σ v ρ) (Arm.substList σ arms ρ)
    | .lazyC m => .lazyC (Comp.subst σ m ρ)
    | .escape v => .escape (Val.subst σ v ρ)
    | .use v m => .use (Val.subst σ v ρ) (Comp.subst σ m ρ)
    | .handle m h => .handle (Comp.subst σ m ρ) (Clause.substList σ h ρ)
    | .resume k v => .resume (Val.subst σ k ρ) (Val.subst σ v ρ)
    | .externalCall f tys args => .externalCall f (tys.map (substTyValues σ)) (Val.substList σ args ρ)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh bs p v ix => .checkAt k o {sh with errorType := substTyValues σ sh.errorType}
        (match bs with | none => none | some b => some (b.subst σ ρ)) (p.subst σ ρ) (v.subst σ ρ) ix
    | .meth d m tys effs args => .meth (Val.subst σ d ρ) m (tys.map (substTyValues σ)) (effs.map (substEffValues σ)) (Val.substList σ args ρ)

  def Arm.substList (σ : Nat → Val) (arms : List Arm) (ρ : Nat → LocalRef := LocalRef.bound) : List Arm :=
    match arms with
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.subst (upSubst (Benitoite.Release.Arm.bindersOf alts) σ) m (upLocalSubst (Benitoite.Release.Arm.bindersOf alts) ρ)) :: Arm.substList σ arms ρ
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.subst (upSubst (Benitoite.Release.Arm.bindersOf alts) σ) g (upLocalSubst (Benitoite.Release.Arm.bindersOf alts) ρ)))
          (Comp.subst (upSubst (Benitoite.Release.Arm.bindersOf alts) σ) m (upLocalSubst (Benitoite.Release.Arm.bindersOf alts) ρ)) :: Arm.substList σ arms ρ

  def Clause.substList (σ : Nat → Val) (cs : List Clause) (ρ : Nat → LocalRef := LocalRef.bound) : List Clause :=
    match cs with
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.subst (upSubst (n + 1) (fun i => (σ i).shiftEAt k 0)) m (upLocalSubst (n + 1) ρ)) :: Clause.substList σ cs ρ
    | .fail e m :: cs => .fail (substTyValues σ e) (Comp.subst (upSubst 2 (fun i => (σ i).shiftEAt 1 0)) m (upLocalSubst 2 ρ)) :: Clause.substList σ cs ρ
end
end


def typeEnvAt (c : Nat) (ts : List Ty) (es : List Eff) : SubstEnv :=
  ⟨(fun i => if i < c then .tvar i
    else if i-c < ts.length then shiftTypes c 0 ((ts[i-c]?).getD (.tvar i))
    else .tvar (i-ts.length)), es.map (shiftRowsTypes c 0), [], (fun i => some (.var i))⟩
noncomputable def substTypeAt (c : Nat) (ts : List Ty) (es : List Eff) (t : Ty) : Ty :=
  t.bind (typeEnvAt c ts es)
noncomputable def substRowAt (c : Nat) (ts : List Ty) (es : List Eff) (e : Eff) : Eff :=
  Eff.bind (typeEnvAt c ts es) e
private noncomputable def substBuilderAt (c : Nat) (ts : List Ty) (es : List Eff) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (substTypeAt c ts es a)

noncomputable section
mutual
  def Val.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Val → Val
    | .var i => .var i
    | .const k => .const k
    | .fnRef f tys effs rs => .fnRef f (tys.map (substTypeAt c ts es)) (effs.map (substRowAt c ts es)) rs
    | .prim b tys effs rs => .prim b (tys.map (substTypeAt c ts es)) (effs.map (substRowAt c ts es)) rs
    | .lam names params body => .lam names (params.map (substTypeAt c ts es)) (Comp.substTyAt c (ts.map (Ty.shiftV params.length 0)) (es.map (Eff.shiftV params.length 0)) body)
    | .dependentLam t body => .dependentLam (Tel.bind (typeEnvAt c ts es) t) (Comp.substTyAt c (ts.map (Ty.shiftV (telBinders t) 0)) (es.map (Eff.shiftV (telBinders t) 0)) body)
    | .closure t body => .closure t body
    | .con k tys args => .con k (tys.map (substTypeAt c ts es)) (Val.substTyAtList c ts es args)
    | .list elems => .list (Val.substTyAtList c ts es elems)
    | .op o tys => .op o (tys.map (substTypeAt c ts es))
    | .raise t e => .raise (substTypeAt c ts es t) (substTypeAt c ts es e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.substTyAtList c ts es ks) (Val.substTyAtList c ts es vs)
    | .setV elems => .setV (Val.substTyAtList c ts es elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (substTypeAt c ts es)) (Val.substTyAtList c ts es args)
    | .super v cl => .super (Val.substTyAt c ts es v) cl
    | .externalRef f tys => .externalRef f (tys.map (substTypeAt c ts es))
    | .externalHandle h tys => .externalHandle h (tys.map (substTypeAt c ts es))
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  def Val.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Val → List Val
    | [] => []
    | v :: vs => Val.substTyAt c ts es v :: Val.substTyAtList c ts es vs

  def Comp.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : Comp → Comp
    | .builderLet k body => .builderLet (substBuilderAt c ts es k) (Comp.substTyAt c (ts.map (Ty.shiftV 1 0)) (es.map (Eff.shiftV 1 0)) body)
    | .builderOp k op r args => .builderOp (substBuilderAt c ts es k) op r (Val.substTyAtList c ts es args)
    | .ret v => .ret (Val.substTyAt c ts es v)
    | .letIn m n => .letIn (Comp.substTyAt c ts es m) (Comp.substTyAt c (ts.map (Ty.shiftV 1 0)) (es.map (Eff.shiftV 1 0)) n)
    | .app f args => .app (Val.substTyAt c ts es f) (Val.substTyAtList c ts es args)
    | .ite v m n => .ite (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m) (Comp.substTyAt c ts es n)
    | .match v arms => .match (Val.substTyAt c ts es v) (Arm.substTyAtList c ts es arms)
    | .lazyC m => .lazyC (Comp.substTyAt c ts es m)
    | .escape v => .escape (Val.substTyAt c ts es v)
    | .use v m => .use (Val.substTyAt c ts es v) (Comp.substTyAt c ts es m)
    | .handle m h => .handle (Comp.substTyAt c ts es m) (Clause.substTyAtList c ts es h)
    | .resume k v => .resume (Val.substTyAt c ts es k) (Val.substTyAt c ts es v)
    | .externalCall f tys args => .externalCall f (tys.map (substTypeAt c ts es)) (Val.substTyAtList c ts es args)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh bs p v ix => .checkAt k o {sh with errorType := substTypeAt c ts es sh.errorType}
        (match bs with | none => none | some b => some (b.substTyAt c ts es)) (p.substTyAt c ts es) (v.substTyAt c ts es) ix
    | .meth d m tys effs args =>
        .meth (Val.substTyAt c ts es d) m (tys.map (substTypeAt c ts es)) (effs.map (substRowAt c ts es))
          (Val.substTyAtList c ts es args)

  def Arm.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.substTyAt c (ts.map (Ty.shiftV (Benitoite.Release.Arm.bindersOf alts) 0)) (es.map (Eff.shiftV (Benitoite.Release.Arm.bindersOf alts) 0)) m) :: Arm.substTyAtList c ts es arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.substTyAt c (ts.map (Ty.shiftV (Benitoite.Release.Arm.bindersOf alts) 0)) (es.map (Eff.shiftV (Benitoite.Release.Arm.bindersOf alts) 0)) g)) (Comp.substTyAt c (ts.map (Ty.shiftV (Benitoite.Release.Arm.bindersOf alts) 0)) (es.map (Eff.shiftV (Benitoite.Release.Arm.bindersOf alts) 0)) m) :: Arm.substTyAtList c ts es arms

  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
  def Clause.substTyAtList (c : Nat) (ts : List Ty) (es : List Eff) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.substTyAt (c + k) (ts.map (Ty.shiftV (n+1) 0)) (es.map (Eff.shiftV (n+1) 0)) m) :: Clause.substTyAtList c ts es cs
    | .fail e m :: cs => .fail (substTypeAt c ts es e) (Comp.substTyAt (c + 1) (ts.map (Ty.shiftV 2 0)) (es.map (Eff.shiftV 2 0)) m) :: Clause.substTyAtList c ts es cs
end
end
end Benitoite.Release.Refinement
