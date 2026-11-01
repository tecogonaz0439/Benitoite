import Benitoite.Release.Refinement.ProgramTyping
import Benitoite.Release.Refinement.Context.WF
import Benitoite.Release.Refinement.Source

/-! # 格納された宣言の適格性（設計書 07-04「01-12 との対応」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/- Eff.WF は Fail の型だけを読むため、効果原子の範囲添字を別に検査する。 -/
mutual
  def Ty.RangesScoped (nr : Nat) : Ty → Prop
    | .opaque _ ix | .scoped _ _ ix => ix.WF nr
    | .data _ as | .tapp _ as | .external _ as => rangesScopedTypes nr as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => a.RangesScoped nr
    | .map a b => a.RangesScoped nr ∧ b.RangesScoped nr
    | .fn _ ps r e => rangesScopedTypes nr ps ∧ r.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .cont a b e => a.RangesScoped nr ∧ b.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .dependentFn t => t.RangesScoped nr
    | _ => True
  def Tel.RangesScoped (nr : Nat) : Tel → Prop
    | .done a e => a.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .param _ a t => a.RangesScoped nr ∧ t.RangesScoped nr
  def Eff.RangesScoped (nr : Nat) : Eff → Prop
    | .mk atoms fs => (∀ name ix, atoms (.name name ix) = true → ix.WF nr) ∧ rangesScopedTypes nr fs
  def rangesScopedTypes (nr : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.RangesScoped nr ∧ rangesScopedTypes nr as
end

/-- 四名前空間のうち、型注釈に現れる範囲・型・値と、行変数の上限。 -/
def Ty.SourceScoped (nr nt ne nv : Nat) (a : Ty) : Prop :=
  a.WF nr nt nv ∧ a.RowsIn (· < ne) ∧ a.RangesScoped nr

def Eff.SourceScoped (nr nt ne nv : Nat) (e : Eff) : Prop :=
  e.WF nr nt nv ∧ e.RowsIn (· < ne) ∧ Eff.RangesScoped nr e

def BuilderKind.SourceScoped (nr nt ne nv : Nat) : BuilderKind → Prop
  | .list a => a.SourceScoped nr nt ne nv
  | .string | .bytes => True

mutual
  /-- ソースの値構文だけを受け入れ、束縛位置で各名前空間の深さを増やす。 -/
  def Val.SourceScoped (nr nt ne nv : Nat) : Val → Prop
    | .var i => i < nv
    | .const _ | .bytesV _ => True
    | .fnRef _ ts es => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es
    | .prim _ ts es rs => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es ∧
        (∀ r ∈ rs, r.WF ∧ r.Canonical)
    | .lam ns ps body => NamesWF ns ps ∧ scopedTypes nr nt ne nv ps ∧
        body.SourceScoped nr nt ne (nv + ps.length)
    | .dependentLam t body => (Ty.dependentFn t).SourceScoped nr nt ne nv ∧
        body.SourceScoped nr nt ne (nv + telBinders t)
    | .con _ ts vs | .dict _ ts vs => scopedTypes nr nt ne nv ts ∧ scopedValues nr nt ne nv vs
    | .list vs | .setV vs => scopedValues nr nt ne nv vs
    | .op _ ts | .externalRef _ ts => scopedTypes nr nt ne nv ts
    | .raise a e => a.SourceScoped nr nt ne nv ∧ e.SourceScoped nr nt ne nv
    | .mapV ks vs => scopedValues nr nt ne nv ks ∧ scopedValues nr nt ne nv vs
    | .super v _ => v.SourceScoped nr nt ne nv
    | .scopePattern r => r.WF ∧ r.Canonical
    | .closure _ _ | .loc _ | .externalHandle _ _ | .pathBases _ |
        .checkedAt _ _ _ _ | .atError _ | .checked _ | .checkedRequest _ _ => False
  def scopedValues (nr nt ne nv : Nat) : List Val → Prop
    | [] => True
    | v :: vs => v.SourceScoped nr nt ne nv ∧ scopedValues nr nt ne nv vs
  def Comp.SourceScoped (nr nt ne nv : Nat) : Comp → Prop
    | .builderLet k m => k.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne (nv+1)
    | .builderOp k _ r vs => k.SourceScoped nr nt ne nv ∧
        (match r with | .bound i => i < nv | .loc _ => False) ∧ scopedValues nr nt ne nv vs
    | .ret v | .escape v => v.SourceScoped nr nt ne nv
    | .letIn m n => m.SourceScoped nr nt ne nv ∧ n.SourceScoped nr nt ne (nv+1)
    | .app v vs => v.SourceScoped nr nt ne nv ∧ scopedValues nr nt ne nv vs
    | .ite v m n => v.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne nv ∧ n.SourceScoped nr nt ne nv
    | .match v arms => v.SourceScoped nr nt ne nv ∧ scopedArms nr nt ne nv arms
    | .lazyC m => m.SourceScoped nr nt ne nv
    | .use v m => v.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne nv
    | .handle m cs => m.SourceScoped nr nt ne nv ∧ scopedClauses nr nt ne nv cs
    | .resume k v => k.SourceScoped nr nt ne nv ∧ v.SourceScoped nr nt ne nv
    | .externalCall _ ts vs => scopedTypes nr nt ne nv ts ∧ scopedValues nr nt ne nv vs
    | .issuePathBases _ => False
    | .checkAt _ _ sh bs p v ix => sh.errorType.SourceScoped nr nt ne nv ∧ ix.WF nr ∧
        (match bs with | none => True | some b => b.SourceScoped nr nt ne nv) ∧
        p.SourceScoped nr nt ne nv ∧ v.SourceScoped nr nt ne nv
    | .meth d _ ts es vs => d.SourceScoped nr nt ne nv ∧ scopedTypes nr nt ne nv ts ∧
        scopedRows nr nt ne nv es ∧ scopedValues nr nt ne nv vs
  def scopedArms (nr nt ne nv : Nat) : List Arm → Prop
    | [] => True
    | .mk alts guard body :: arms =>
        (match guard with | none => True | some g => g.SourceScoped nr nt ne (nv + Benitoite.Release.Arm.bindersOf alts)) ∧
        body.SourceScoped nr nt ne (nv + Benitoite.Release.Arm.bindersOf alts) ∧ scopedArms nr nt ne nv arms
  def scopedClauses (nr nt ne nv : Nat) : List Clause → Prop
    | [] => True
    | .mk _ arity k body :: cs => body.SourceScoped nr (nt+k) ne (nv+arity+1) ∧ scopedClauses nr nt ne nv cs
    | .fail e body :: cs => e.SourceScoped nr nt ne nv ∧
        body.SourceScoped nr (nt+1) ne (nv+2) ∧ scopedClauses nr nt ne nv cs
  def scopedTypes (nr nt ne nv : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.SourceScoped nr nt ne nv ∧ scopedTypes nr nt ne nv as
  def scopedRows (nr nt ne nv : Nat) : List Eff → Prop
    | [] => True
    | e :: es => e.SourceScoped nr nt ne nv ∧ scopedRows nr nt ne nv es
end

/-- WF は依存列内の深さを増やし、Annotation は参照順序・sort・宣言を同時に読む。 -/
def SignatureScoped (P : Program) (C : List TParam) (K : KindCtx) (ne : Nat) (t : Tel) : Prop :=
  (Ty.dependentFn t).SourceScoped 0 K.length ne 0 ∧ t.RowsIn (· < ne) ∧
    Ty.HasKind P K (.dependentFn t) .value ∧ Ty.Annotation P C [] (.dependentFn t)

def Def.Scoped (P : Program) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
    SignatureScoped P (d.tparams.map TParamDecl.constraints) (d.tparams.map TParamDecl.kind) d.neffs d.tel ∧
    d.body.SourceScoped 0 d.ntys d.neffs d.params.length

def ConDecl.Scoped (P : Program) (cd : ConDecl) : Prop :=
  ∀ a ∈ cd.args, a.SourceScoped 0 cd.ntys 0 0 ∧
    Ty.Annotation P (List.replicate cd.ntys ({} : TParam)) [] a ∧
    Ty.HasKind P (List.replicate cd.ntys .value) a .value

def OpDecl.Scoped (P : Program) (od : OpDecl) : Prop :=
  NamesWF od.names od.params ∧
    (∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
    od.params.take od.dictParams.length = od.dictParams.map (fun p => .dict p.1 (.tvar p.2)) ∧
    SignatureScoped P od.tparams (List.replicate od.tparams.length .value) 0 od.tel

def MethSig.Scoped (P : Program) (argumentKind : TyKind) (ms : MethSig) : Prop :=
  NamesWF ms.names ms.params ∧
    SignatureScoped P (ms.tparams.map TParamDecl.constraints ++ [({} : TParam)])
      (ms.tparams.map TParamDecl.kind ++ [argumentKind]) ms.neffs ms.tel

def ClassDecl.Scoped (P : Program) (cl : ClassDecl) : Prop :=
  ∀ m ms, cl.methods m = some ms → ms.Scoped P cl.argumentKind

def ImplDecl.Scoped (P : Program) (id : ImplDecl) : Prop :=
  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    id.target.SourceScoped 0 id.tparams.length 0 0 ∧
    Ty.Annotation P id.tparams [] id.target ∧
    TypeAnnotations P id.tparams [] id.dictTys ∧
    (∀ a ∈ id.dictTys, a.HasKind P (List.replicate id.tparams.length .value) .value) ∧
    (∀ s u, id.supers s = some u → u.SourceScoped 0 id.tparams.length 0 id.dictTys.length) ∧
    (∀ cd m ms body, P.classes id.cls = some cd → cd.methods m = some ms → id.methods m = some body →
      body.SourceScoped 0 (ms.tparams.length + id.tparams.length) ms.neffs (id.dictTys.length + ms.params.length))

/-- 格納済み metadata の検査。原ソースからの収集の完全性を表さない。 -/
def Program.MetadataScoped (P : Program) : Prop :=
  ∀ d info, P.dataInfo d = some info →
    info.variances.length = info.arity ∧
    (∀ c cd, P.cons c = some cd → cd.data = d → cd.ntys = info.arity) ∧
    (∀ a ∈ info.requirements ++ info.publicBoundary.map Prod.snd,
      a.SourceScoped 0 info.arity 0 0 ∧
      Ty.Annotation P (List.replicate info.arity ({} : TParam)) [] a ∧
      Ty.HasKind P (List.replicate info.arity .value) a .value)

structure Program.WellFormed (P : Program) : Prop where
  defs : ∀ f d, P.defs f = some d → d.Scoped P
  cons : ∀ c cd, P.cons c = some cd → P.DataArity cd.data cd.ntys ∧ cd.Scoped P
  ops : ∀ o od, P.ops o = some od → od.Scoped P
  classes : ∀ cl cd, P.classes cl = some cd → cd.Scoped P
  impls : ∀ i id, P.impls i = some id → id.Scoped P
  metadata : P.MetadataScoped
  external : P.ExternalWF

end
end Benitoite.Release.Refinement
