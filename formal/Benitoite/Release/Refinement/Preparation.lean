import Benitoite.Release.Refinement.RuntimeSyntax
import Benitoite.Release.Refinement.Typing

/-! # 初期状態と既知の契約から辿る起点

宣言表を列挙せず、lookupと有限の導出で到達を表す。動的なScopePatternの内容は既知の契約と区別する。
-/
namespace Benitoite.Release.Refinement

inductive PathRequirement where
  | base (base : PathBase)
  | secrets
  deriving DecidableEq

inductive PreparationNode where
  | state (value : State) | closure (value : Closure) | capture (value : Capture)
  | frame (value : Frame) | cell (value : Cell) | comp (value : Comp) | val (value : Val)
  | ty (value : Ty) | tel (value : Tel) | eff (value : Eff) | range (value : RangeExpr)
  | pred (value : Pred) | term (value : Term)
  | function (name : FunName) | constructor (name : ConName) | operation (name : OpName)
  | implementation (name : ImplName) | typeclass (name : ClassName)
  | external (id : ExternalFunctionId) | primitive (name : PrimName)

private def typeNodes (ts : List Ty) (n : PreparationNode) : Prop := ∃ t ∈ ts, n = .ty t
private def valueNodes (vs : List Val) (n : PreparationNode) : Prop := ∃ v ∈ vs, n = .val v
private def rowNodes (es : List Eff) (n : PreparationNode) : Prop := ∃ e ∈ es, n = .eff e
private def frameNodes (k : Cont) (n : PreparationNode) : Prop := ∃ f ∈ k, n = .frame f
private def storeNodes (μ : Store) (n : PreparationNode) : Prop := ∃ l c, μ l = some c ∧ n = .cell c
private def clauseNodes (cs : List Clause) (n : PreparationNode) : Prop :=
  ∃ c ∈ cs, n = .comp c.body ∨ match c with
    | .mk (.user o) _ _ _ => n = .operation o
    | .mk (.prim b) _ _ _ => n = .primitive b
    | .fail e _ => n = .ty e
    | _ => False
private def armNodes (arms : List Arm) (n : PreparationNode) : Prop :=
  ∃ a ∈ arms, n = .comp a.body ∨ ∃ g, a.guard = some g ∧ n = .comp g
private def termNodes (ts : List (Option Term)) (n : PreparationNode) : Prop :=
  ∃ t, some t ∈ ts ∧ n = .term t
private def indexNode (ix : RangeIx) (n : PreparationNode) : Prop :=
  match ix with | .fixed r => n = .range r | .rvar _ => False

/-- 一つの構文参照又はlookup。各証拠は有限で、関数の表の全列挙を要求しない。 -/
def PreparationNode.Child (P : Program) (B : Builtins) : PreparationNode → PreparationNode → Prop
  | .state (.run q k μ), n => n = .closure q ∨ frameNodes k n ∨ storeNodes μ n
  | .state (.matchRun v cap arms _ k μ), n => n = .val v ∨ n = .capture cap ∨
      armNodes arms n ∨ frameNodes k n ∨ storeNodes μ n
  | .state (.error _ k μ), n | .state (.exit _ _ k μ), n => frameNodes k n ∨ storeNodes μ n
  | .closure (.mk cap m), n => n = .capture cap ∨ n = .comp m
  | .capture (.mk vs), n => ∃ v, some v ∈ vs ∧ n = .val v
  | .frame (.letF q), n => n = .closure q
  | .frame (.release v), n => n = .val v
  | .frame (.handleF cap cs), n => n = .capture cap ∨ clauseNodes cs n
  | .frame (.guardF v cap arms _ q), n => n = .val v ∨ n = .capture cap ∨ armNodes arms n ∨ n = .closure q
  | .cell (.builder (.list vs)), n => valueNodes vs n
  | .cell (.val v), n | .cell (.done v), n => n = .val v
  | .cell (.thunk q), n => n = .closure q
  | .cell (.cont k), n => frameNodes k n
  | .ty (.opaque _ ix), n | .ty (.scoped _ _ ix), n => indexNode ix n
  | .ty (.data d ts), n => typeNodes ts n ∨
      ∃ c cd, P.cons c = some cd ∧ cd.data = d ∧ n = .constructor c
  | .ty (.external _ ts), n | .ty (.tapp _ ts), n => typeNodes ts n
  | .ty (.list t), n | .ty (.set t), n | .ty (.reference t), n | .ty (.lazy t), n => n = .ty t
  | .ty (.dict cl t), n => n = .typeclass cl ∨ n = .ty t
  | .ty (.refined t p), n => n = .ty t ∨ n = .pred p
  | .ty (.fn _ ps r e), n => typeNodes ps n ∨ n = .ty r ∨ n = .eff e
  | .ty (.cont a b e), n => n = .ty a ∨ n = .ty b ∨ n = .eff e
  | .ty (.map a b), n => n = .ty a ∨ n = .ty b
  | .ty (.dependentFn t), n => n = .tel t
  | .tel (.done r e), n => n = .ty r ∨ n = .eff e
  | .tel (.param _ a t), n => n = .ty a ∨ n = .tel t
  | .eff e, n => typeNodes e.fails n ∨ ∃ l r, e.test (.name l (.fixed r)) = true ∧ n = .range r
  | .pred (.eq a b), n | .pred (.le a b), n | .pred (.lt a b), n |
      .pred (.compare _ _ a b), n => n = .term a ∨ n = .term b
  | .pred (.floatClass _ _ t), n | .pred (.decimalRepresented t), n |
      .pred (.charactersIn t _ _), n => n = .term t
  | .pred (.member _ t r), n => n = .term t ∨ n = .range r
  | .pred (.constructorIs t c), n => n = .term t ∨ n = .constructor c
  | .pred (.and p q), n | .pred (.or p q), n => n = .pred p ∨ n = .pred q
  | .pred (.not p), n => n = .pred p
  | .term (.field ref t), n => n = .term t ∨ n = .constructor ref.constructor
  | .term (.measure _ t), n | .term (.neg t), n | .term (.scale _ t), n => n = .term t
  | .term (.add a b), n => n = .term a ∨ n = .term b
  | .term (.dataValue c ts), n => n = .constructor c ∨ termNodes ts n
  | .term (.listValue ts), n | .term (.setValue ts), n => termNodes ts n
  | .term (.mapValue ks vs), n => termNodes ks n ∨ termNodes vs n
  | .val (.fnRef f ts es), n => n = .function f ∨ typeNodes ts n ∨ rowNodes es n
  | .val (.prim b ts es rs), n => n = .primitive b ∨ typeNodes ts n ∨ rowNodes es n ∨ ∃ r ∈ rs, n = .range r
  | .val (.lam _ ps body), n => typeNodes ps n ∨ n = .comp body
  | .val (.dependentLam t body), n => n = .tel t ∨ n = .comp body
  | .val (.closure t q), n => n = .tel t ∨ n = .closure q
  | .val (.con c ts vs), n => n = .constructor c ∨ typeNodes ts n ∨ valueNodes vs n
  | .val (.dict i ts vs), n => n = .implementation i ∨ typeNodes ts n ∨ valueNodes vs n
  | .val (.list vs), n | .val (.setV vs), n => valueNodes vs n
  | .val (.mapV ks vs), n => valueNodes ks n ∨ valueNodes vs n
  | .val (.op o ts), n => n = .operation o ∨ typeNodes ts n
  | .val (.raise a b), n => n = .ty a ∨ n = .ty b
  | .val (.super v cl), n => n = .val v ∨ n = .typeclass cl
  | .val (.checkedRequest _ v), n => n = .val v
  | .val (.checkedAt r _ _ req), n => n = .range r ∨ ∃ v, req = some v ∧ n = .val v
  | .val (.externalRef f ts), n => n = .external f ∨ typeNodes ts n
  | .val (.externalHandle _ ts), n => typeNodes ts n
  | .comp (.builderLet b m), n => n = .ty b.contents ∨ n = .comp m
  | .comp (.builderOp b _ _ vs), n => n = .ty b.contents ∨ valueNodes vs n
  | .comp (.ret v), n | .comp (.escape v), n => n = .val v
  | .comp (.letIn m body), n => n = .comp m ∨ n = .comp body
  | .comp (.app f vs), n => n = .val f ∨ valueNodes vs n
  | .comp (.ite v m body), n => n = .val v ∨ n = .comp m ∨ n = .comp body
  | .comp (.match v arms), n => n = .val v ∨ armNodes arms n
  | .comp (.lazyC m), n => n = .comp m
  | .comp (.use v m), n => n = .val v ∨ n = .comp m
  | .comp (.handle m cs), n => n = .comp m ∨ clauseNodes cs n
  | .comp (.resume k v), n => n = .val k ∨ n = .val v
  | .comp (.meth v _ ts es vs), n => n = .val v ∨ typeNodes ts n ∨ rowNodes es n ∨ valueNodes vs n
  | .comp (.externalCall f ts vs), n => n = .external f ∨ typeNodes ts n ∨ valueNodes vs n
  | .comp (.issuePathBases b), n => n = .primitive b
  | .comp (.checkAt _ _ sh bs p v ix), n => n = .ty sh.errorType ∨ indexNode ix n ∨
      (∃ b, bs = some b ∧ n = .val b) ∨ n = .val p ∨ n = .val v
  | .function f, n => ∃ d, P.defs f = some d ∧ (n = .tel d.tel ∨ n = .comp d.body)
  | .constructor c, n => ∃ d, P.cons c = some d ∧ typeNodes d.args n
  | .operation o, n => ∃ d, P.ops o = some d ∧ n = .tel d.tel
  | .implementation i, n => ∃ d, P.impls i = some d ∧
      (n = .typeclass d.cls ∨ n = .ty d.target ∨ typeNodes d.dictTys n ∨ (∃ cl v, d.supers cl = some v ∧ n = .val v) ∨
        ∃ m body, d.methods m = some body ∧ n = .comp body)
  | .typeclass cl, n => ∃ d, P.classes cl = some d ∧
      ((∃ super ∈ d.supers, n = .typeclass super) ∨ ∃ m ms, d.methods m = some ms ∧ n = .tel ms.tel)
  | .external f, n => ∃ d, P.externalFunction f = some d ∧ n = .tel d.parameters
  | .primitive b, n => ∃ sg, B.sig b = some sg ∧ n = .tel sg.tel
  | _, _ => False

inductive PreparationNode.Reachable (P : Program) (B : Builtins) (root : PreparationNode) : PreparationNode → Prop where
  | root : Reachable P B root root
  | child {parent node} : Reachable P B root parent → parent.Child P B node → Reachable P B root node

inductive PathEnv.Required (P : Program) (B : Builtins) (s : State) : PathRequirement → Prop where
  | base {b p} : PreparationNode.Reachable P B (.state s) (.range (.based b p)) → Required P B s (.base b)
  | secrets : PreparationNode.Reachable P B (.state s) (.range .secrets) → Required P B s .secrets

def PathEnv.Ready (P : Program) (B : Builtins) (σ : PathEnv) (s : State) : Prop :=
  σ.Valid ∧ ∀ r, PathEnv.Required P B s r → match r with
    | .base b => ∃ w, σ.Binds b w
    | .secrets => σ.secrets.isSome = true

structure InitialPrepared (P : Program) (B : Builtins) (σ : PathEnv) (s : State) : Prop where
  prepared : σ.Ready P B s

theorem InitialPrepared.ready {P B σ s} (h : InitialPrepared P B σ s) : σ.Ready P B s := h.prepared

end Benitoite.Release.Refinement
