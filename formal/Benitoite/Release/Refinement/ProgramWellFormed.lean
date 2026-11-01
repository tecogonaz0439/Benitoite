import Benitoite.Release.Refinement.ProgramTyping
import Benitoite.Release.Refinement.Context.WF
import Benitoite.Release.Refinement.SourceScope

/-! # 格納された宣言の適格性（設計書 07-04「01-12 との対応」） -/
namespace Benitoite.Release.Refinement
noncomputable section

def Def.Scoped (P : Program) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
    SignatureScoped P d.tparams d.neffs d.tel ∧
    d.body.SourceScoped 0 d.ntys d.neffs d.params.length

def ConDecl.Scoped (P : Program) (cd : ConDecl) : Prop :=
  ∀ a ∈ cd.args, a.SourceScoped 0 cd.ntys 0 0 ∧
    Ty.Annotation P (List.replicate cd.ntys TypeCtx.valueParam) [] a ∧
    Ty.HasKind P (List.replicate cd.ntys .value) a .value

def OpDecl.Scoped (P : Program) (od : OpDecl) : Prop :=
  NamesWF od.names od.params ∧
    (∀ p ∈ od.dictParams, p.2 < od.tparams.length) ∧
    od.params.take od.dictParams.length = od.dictParams.map (fun p => .dict p.1 (.tvar p.2)) ∧
    SignatureScoped P (TypeCtx.values od.tparams) 0 od.tel

def MethSig.Scoped (P : Program) (argumentKind : TyKind) (ms : MethSig) : Prop :=
  NamesWF ms.names ms.params ∧
    SignatureScoped P (ms.tparams ++ [⟨{}, argumentKind⟩]) ms.neffs ms.tel

def ClassDecl.Scoped (P : Program) (cl : ClassDecl) : Prop :=
  ∀ m ms, cl.methods m = some ms → ms.Scoped P cl.argumentKind

def ImplDecl.Scoped (P : Program) (id : ImplDecl) : Prop :=
  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    id.target.SourceScoped 0 id.tparams.length 0 0 ∧
    Ty.Annotation P (TypeCtx.values id.tparams) [] id.target ∧
    TypeAnnotations P (TypeCtx.values id.tparams) [] id.dictTys ∧
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
      Ty.Annotation P (List.replicate info.arity TypeCtx.valueParam) [] a ∧
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
