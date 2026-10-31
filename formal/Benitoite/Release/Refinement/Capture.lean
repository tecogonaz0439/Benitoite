import Benitoite.Release.Refinement.Telescope

namespace Benitoite.Release.Refinement
noncomputable section

def Capture.env (cap : Capture) (i : Nat) : Val := ((cap.values[i]?).join).getD (.const .unit)
def Capture.closeTy (cap : Capture) : Ty → Ty := substTyValues cap.env
def Capture.closeEff (cap : Capture) : Eff → Eff := substEffValues cap.env
def Capture.closeR (cap : Capture) (r : Option Ty) : Option Ty := r.map cap.closeTy
def Capture.closeTyAt (cap : Capture) (n : Nat) : Ty → Ty := substTyValues (upSubst n cap.env)
def Capture.closeEffAt (cap : Capture) (n : Nat) : Eff → Eff := substEffValues (upSubst n cap.env)
def Capture.closeRAt (cap : Capture) (n : Nat) (r : Option Ty) : Option Ty := r.map (cap.closeTyAt n)
def Capture.closeTel (cap : Capture) (t : Tel) : Tel := Tel.bind (valEnv cap.env) t

def Capture.extend (cap : Capture) (v : Val) : Capture := .mk (some v :: cap.values)
def Capture.extendNone (cap : Capture) : Capture := .mk (none :: cap.values)
def Capture.extendMany (cap : Capture) (vs : List Val) : Capture := vs.foldl Capture.extend cap

def Closure.pure (m : Comp) : Closure := .mk Capture.empty m
def Closure.apply (q : Closure) (vs : List Val) : Closure := .mk (q.capture.extendMany vs) q.code

/-- 旧lamの終端は実行が読まない。返り値の型・効果はClosureTyの証拠に保持する。 -/
def lambdaShape (ns : List String) (ps : List Ty) : Tel := Ty.toTel ns ps (.base .unit) Eff.empty

mutual
  def closeVal (cap : Capture) : Val → Val
    | .var i => cap.env i
    | .const c => .const c
    | .fnRef f ts es => .fnRef f (ts.map cap.closeTy) (es.map cap.closeEff)
    | .prim b ts es rs => .prim b (ts.map cap.closeTy) (es.map cap.closeEff) rs
    | .lam ns ps body => .closure (cap.closeTel (lambdaShape ns ps)) (.mk cap body)
    | .dependentLam t body => .closure (cap.closeTel t) (.mk cap body)
    | .closure t q => .closure t q
    | .con c ts vs => .con c (ts.map cap.closeTy) (closeVals cap vs)
    | .list vs => .list (closeVals cap vs)
    | .op o ts => .op o (ts.map cap.closeTy)
    | .raise a e => .raise (cap.closeTy a) (cap.closeTy e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (closeVals cap ks) (closeVals cap vs)
    | .setV vs => .setV (closeVals cap vs)
    | .bytesV bs => .bytesV bs
    | .dict i ts vs => .dict i (ts.map cap.closeTy) (closeVals cap vs)
    | .super v s => .super (closeVal cap v) s
    | .externalRef f ts => .externalRef f (ts.map cap.closeTy)
    | .externalHandle h ts => .externalHandle h (ts.map cap.closeTy)
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t v => .checkedRequest t v
  def closeVals (cap : Capture) : List Val → List Val
    | [] => []
    | v :: vs => closeVal cap v :: closeVals cap vs
end

/-- 一歩で読む値だけを閉じる。内側のcodeは捕捉環境と一緒に残す。 -/
def Closure.view (q : Closure) : Comp := match q.code with
  | .ret v => .ret (closeVal q.capture v)
  | .app f vs => .app (closeVal q.capture f) (closeVals q.capture vs)
  | .builderLet b m => .builderLet (substKind q.capture.env b) m
  | .builderOp b op r vs => .builderOp (substKind q.capture.env b) op r (closeVals q.capture vs)
  | .letIn m n => .letIn m n
  | .ite v m n => .ite (closeVal q.capture v) m n
  | .match v arms => .match (closeVal q.capture v) arms
  | .lazyC m => .lazyC m
  | .escape v => .escape (closeVal q.capture v)
  | .use v m => .use (closeVal q.capture v) m
  | .handle m h => .handle m h
  | .resume k v => .resume (closeVal q.capture k) (closeVal q.capture v)
  | .externalCall f ts vs => .externalCall f (ts.map q.capture.closeTy) (closeVals q.capture vs)
  | .issuePathBases b => .issuePathBases b
  | .checkAt k o sh bs p v ix => .checkAt k o {sh with errorType := q.capture.closeTy sh.errorType}
      (bs.map (closeVal q.capture)) (closeVal q.capture p) (closeVal q.capture v) ix
  | .meth v m ts es vs => .meth (closeVal q.capture v) m (ts.map q.capture.closeTy)
      (es.map q.capture.closeEff) (closeVals q.capture vs)

@[simp] theorem closeVals_length (cap : Capture) (vs : List Val) : (closeVals cap vs).length = vs.length := by
  induction vs <;> simp_all [closeVals]

@[simp] theorem Capture.extend_values (cap : Capture) (v : Val) : (cap.extend v).values = some v :: cap.values := rfl
@[simp] theorem Capture.extend_env_zero (cap : Capture) (v : Val) : (cap.extend v).env 0 = v := rfl
@[simp] theorem Capture.extend_env_succ (cap : Capture) (v : Val) (i : Nat) : (cap.extend v).env (i+1) = cap.env i := rfl
@[simp] theorem Capture.extendNone_env_succ (cap : Capture) (i : Nat) : cap.extendNone.env (i+1) = cap.env i := rfl

def builderValueSubst : Nat → Val
  | 0 => .const .unit
  | i+1 => .var i

def Comp.substTy (ts : List Ty) (es : List Eff) (m : Comp) : Comp := Comp.substTyAt 0 ts es m
def Val.substTy (ts : List Ty) (es : List Eff) (v : Val) : Val := Val.substTyAt 0 ts es v

/-- 宣言本体や辞書の値を、閉じた実引数で具体化する入口。 -/
def Val.instantiate (vs : List Val) (v : Val) : Val := closeVal (Capture.empty.extendMany vs) v

def Clause.op : Clause → OpRef
  | .mk o _ _ _ => o
  | .fail _ _ => .fail

def Clause.body : Clause → Comp
  | .mk _ _ _ m | .fail _ m => m

def handles (h : List Clause) (o : OpRef) : Bool := h.any (fun c => c.op == o)

def Arm.alts : Arm → List Alt
  | .mk alts _ _ => alts

def Arm.guard : Arm → Option Comp
  | .mk _ guard _ => guard

def Arm.body : Arm → Comp
  | .mk _ _ body => body

end
end Benitoite.Release.Refinement
