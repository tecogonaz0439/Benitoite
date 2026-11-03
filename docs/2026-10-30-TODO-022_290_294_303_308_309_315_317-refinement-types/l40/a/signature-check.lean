import Benitoite
open Benitoite.Release.Refinement
namespace Benitoite.Release.Refinement.Signatures

-- V_Var の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T i}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .var i) ,
    (∃ a b, Γ[i]? = some (some a) ∧ a.Ordinary ∧
      T.norm.core = b ∧ Ty.LeQ P Γ Φ a.norm.core b) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_Const の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T c}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .const c) ,
    (ConstOK B c ∧ T.norm.core = c.type.norm.core) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_Lam の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {ns} {ps} {body},
    HasTypeVQ P B Ψ Q C Γ Φ (.lam ns ps body) T →
    ∃ r ε u,
      (NamesWF ns ps) ∧
      (Ty.WF 0 C.length Γ.length (.fn ns ps r ε)) ∧
      (Ty.Sorted Γ (.fn ns ps r ε)) ∧
      (HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) []) ∧
      (Ty.Declared P C Γ (.fn ns ps r ε)) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel ns ps r ε) u : Prop)

-- V_DependentLam の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {t} {body},
    HasTypeVQ P B Ψ Q C Γ Φ (.dependentLam t body) T →
    ∃ u,
      (Ty.Annotation P C Γ (.dependentFn t)) ∧
      (TelBodyTy P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ t u : Prop)

-- V_Closure の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {runtime} {body},
    HasTypeVQ P B Ψ Q C Γ Φ (.closure runtime body) T →
    ∃ t u,
      (Ty.Annotation P C Γ (.dependentFn t)) ∧
      (Tel.RuntimeShape runtime t) ∧
      (DependentClosureTy P B Ψ body t) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ t u : Prop)

-- V_Fun の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {f} {ts} {es},
    HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es) T →
    ∃ d u,
      (P.defs f = some d) ∧
      (NamesWF d.names d.params) ∧
      (Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
          (Qsig d.params d.ret d.eff) Q ts es d.eff) ∧
      (SignatureInstance P C Γ d.tel (TypeCtx.kinds d.tparams) ts es) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.tel ts es) u : Prop)

-- V_Prim の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {b} {ts} {es} {rs},
    HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts es rs) T →
    ∃ s u,
      (B.sig b = some s) ∧
      (B.RangeAdmissible b s rs) ∧
      (NamesWF s.names s.params) ∧
      (PrimitiveAdmissible C Γ.length s Q ts es) ∧
      (SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel (Tel.instR rs s.tel) ts es) u : Prop)

-- V_Op の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {o} {ts},
    HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T →
    ∃ od u,
      (P.ops o = some od) ∧
      (NamesWF od.names od.params) ∧
      (SatAll B C ts od.tparams) ∧
      (SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts []) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel od.tel ts []) u : Prop)

-- V_ExternalRef の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {f} {ts},
    HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts) T →
    ∃ d u,
      (P.externalFunction f = some d) ∧
      (d.WF P) ∧
      (ExternalCallAdmissible P B C d ts) ∧
      (SignatureInstance P C Γ d.parameters d.kinds ts []) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.parameters ts []) u : Prop)

-- V_ExternalHandle の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {ts} {h : ExternalHandle},
    HasTypeVQ P B Ψ Q C Γ Φ (.externalHandle h ts) T →
    ∃ (td : ExternalTypeDecl),
      (P.externalType h.typeId = some td) ∧
      (td.component = h.component) ∧
      (td.resource = h.resource) ∧
      (ts.length = td.arity) ∧
      (Ty.Annotation P C Γ (.external h.typeId ts)) ∧
      Ty.LeQ P Γ Φ (.external h.typeId ts) T : Prop)

-- V_PathBases の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {snapshot},
    HasTypeVQ P B Ψ Q C Γ Φ (.pathBases snapshot) T →
    (snapshot.Valid) ∧
      Ty.LeQ P Γ Φ .pathBases T : Prop)

-- V_ScopePattern の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {range},
    HasTypeVQ P B Ψ Q C Γ Φ (.scopePattern range) T →
    ∃ kind,
      (range.WF) ∧
      (range.Canonical) ∧
      (range.FitsKind kind) ∧
      Ty.LeQ P Γ Φ (.scopePattern kind) T : Prop)

-- V_Checked の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T target}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checked target) ,
    (∃ o k range ix, B.valKind o = some k ∧ B.valContent o = none ∧
      Scope.Domain.Range.MemK k range target ∧ T.Holds o k ix ∧
      ix.Covers (.fixed (.absolute range))) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_CheckedRequest の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedRequest target req) ,
    (∃ o range A ix, B.valKind o = some .endpoint ∧ B.valContent o = some A ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
      req.reqTarget = some target ∧ Scope.Domain.Range.MemK .endpoint range target ∧
      T.Holds o .endpoint ix ∧ ix.Covers (.fixed (.absolute range))) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_CheckedAt の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T r snapshot target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .checkedAt r snapshot target req) ,
    (∃ o k ix, CheckedWitness P B Ψ o k r snapshot target req ∧
      T.Holds o k ix ∧ ix.Covers (.fixed r)) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_AtErrorの芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ T} (detail : AtError),
  HasTypeVQ P B Ψ Q C Γ Φ (.atError detail) T →
  (∃ shape : ResultShape, shape.Declared P ∧ T.norm.core = shape.errorType.norm.core) ∧
  (∀ t, (Val.atError detail).toTerm? = some t → ∀ p ∈ T.assume,
    Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_Map の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {ks} {vs},
    HasTypeVQ P B Ψ Q C Γ Φ (.mapV ks vs) T →
    ∃ a b k w,
      (HasTypeEachQ P B Ψ Q C Γ Φ ks a) ∧
      (HasTypeEachQ P B Ψ Q C Γ Φ vs b) ∧
      (ks.length = vs.length) ∧
      (B.sat (TypeCtx.constraints C) a.norm TParam.keyC) ∧
      (Ty.Annotation P C Γ a) ∧
      (Ty.Annotation P C Γ b) ∧
      T.norm.core = .map k w ∧ a.norm = k.norm ∧ Ty.LeQ P Γ Φ b w : Prop)

-- V_Set の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {vs},
    HasTypeVQ P B Ψ Q C Γ Φ (.setV vs) T →
    ∃ a w,
      (HasTypeEachQ P B Ψ Q C Γ Φ vs a) ∧
      (B.sat (TypeCtx.constraints C) a.norm TParam.keyC) ∧
      (Ty.Annotation P C Γ a) ∧
      T.norm.core = .set w ∧ a.norm = w.norm : Prop)

-- V_Dict の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {i} {ts} {vs},
    HasTypeVQ P B Ψ Q C Γ Φ (.dict i ts vs) T →
    ∃ id,
      (P.impls i = some id) ∧
      (SatAll B C ts id.tparams) ∧
      (TypeAnnotations P C Γ ts) ∧
      (TypeArgsKinded P C ts (List.replicate id.tparams.length .value)) ∧
      ((∀ a ∈ id.dictTys, a.WF 0 id.tparams.length 0)) ∧
      (id.target.WF 0 id.tparams.length 0) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ vs (id.dictTys.map (Ty.subst ts []))) ∧
      (Ty.Annotation P C Γ (.dict id.cls (id.target.subst ts []))) ∧
      T.norm.core = (Ty.dict id.cls (id.target.subst ts [])).norm.core : Prop)

-- V_Raise の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {t} {e},
    HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T →
    ∃ u,
      (Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e))) ∧
      (Ordinary t) ∧
      (Ordinary e) ∧
      (t.HasKind P (TypeCtx.kinds C) .value) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel ["error"] [e] t (Eff.singleFail e)) u : Prop)

-- V_LocRef の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {l},
    HasTypeVQ P B Ψ Q C Γ Φ (.loc l) T →
    ∃ a,
      (Ψ l = some (.ref a)) ∧
      (Ty.Declared P C Γ a) ∧
      Ty.LeQ P Γ Φ (.reference a) T : Prop)

-- V_LocLazy の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {l},
    HasTypeVQ P B Ψ Q C Γ Φ (.loc l) T →
    ∃ a,
      (Ψ l = some (.lazy a)) ∧
      (Ty.Declared P C Γ a) ∧
      Ty.LeQ P Γ Φ (.lazy a) T : Prop)

-- V_Bytes の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {bs},
    HasTypeVQ P B Ψ Q C Γ Φ (.bytesV bs) T →
    ((∀ b ∈ bs, b ≤ 255)) ∧
      T.norm.core = .bytes : Prop)

-- V_Con の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T c ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .con c ts vs) ,
    (∃ cd, P.cons c = some cd ∧ ts.length = cd.ntys ∧
      TypeArgsKinded P C ts (List.replicate cd.ntys .value) ∧
      Ty.Annotation P C Γ (.data cd.data ts) ∧
      HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) ∧
      ∃ us, T.norm.core = .data cd.data us ∧
        TypeArgsLe P Γ Φ (P.varianceFor cd.data ts.length) (Ty.normTys ts) us) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- V_Super の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {v} {super},
    HasTypeVQ P B Ψ Q C Γ Φ (.super v super) T →
    ∃ cl a cd,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl a)) ∧
      (P.classes cl = some cd) ∧
      (super ∈ cd.supers) ∧
      (Ty.Declared P C Γ a) ∧
      T.norm.core = (Ty.dict super a).norm.core : Prop)

-- V_List の芯と事実の枝
#check (∀ {P B Ψ Q C Γ Φ v T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) ,
    (∃ a b, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧ Ty.Annotation P C Γ a ∧
      T.norm.core = .list b ∧ Ty.LeQ P Γ Φ a b) ∧
    (∀ t, v.toTerm? = some t → ∀ p ∈ T.assume, Entails (Γ.facts ++ Φ) (p.open t)) : Prop)

-- C_BuilderLet の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {body},
    HasTypeCQ P B Ψ Q C Γ Φ R (.builderLet kind body) T outEff Δ →
    ∃ a ε,
      (Ty.Annotation P C Γ kind.contents) ∧
      (TypeArgsKinded P C [kind.contents] [.value]) ∧
      (HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          body (a.shiftV 1 0) (ε.shiftV 1 0)
          (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ)) ∧
      (Ty.Declared P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_BuilderOp の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {op} {ref} {args},
    HasTypeCQ P B Ψ Q C Γ Φ R (.builderOp kind op ref args) T outEff Δ →
    (Ty.Annotation P C Γ kind.contents) ∧
      (TypeArgsKinded P C [kind.contents] [.value]) ∧
      (LocalRef.HasKind Ψ Δ ref kind) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind)) ∧
      Ty.LeQ P Γ Φ (op.resultType kind) T ∧ Eff.Covers Γ Φ outEff Eff.empty : Prop)

-- C_Return の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.ret v) T outEff Δ →
    ∃ a,
      (HasTypeVQ P B Ψ Q C Γ Φ v a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff Eff.empty : Prop)

-- C_Let の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {n},
    HasTypeCQ P B Ψ Q C Γ Φ R (.letIn m n) T outEff Δ →
    ∃ a b ε,
      (HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) ∧
      (HasTypeCQ P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 Δ)) ∧
      (Ty.Declared P C Γ b) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_App の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {f} {args},
    HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) T outEff Δ →
    ∃ ns as b ε,
      (HasTypeVQ P B Ψ Q C Γ Φ f (.fn ns as b ε)) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ args as) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_DependentApp の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {f} {args},
    HasTypeCQ P B Ψ Q C Γ Φ R (.app f args) T outEff Δ →
    ∃ t a e,
      (HasTypeVQ P B Ψ Q C Γ Φ f (.dependentFn t)) ∧
      (HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff e : Prop)

-- C_If の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m} {n},
    HasTypeCQ P B Ψ Q C Γ Φ R (.ite v m n) T outEff Δ →
    ∃ t a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean)) ∧
      (v.toTerm? = some t) ∧
      (HasTypeCQ P B Ψ Q C Γ (boolCond t true :: Φ) R m a ε Δ) ∧
      (HasTypeCQ P B Ψ Q C Γ (boolCond t false :: Φ) R n a ε Δ) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Match の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {arms},
    HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) T outEff Δ →
    ∃ obs a b ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v a) ∧
      ((∀ t, obs = some t → v.toTerm? = some t ∧ ∃ s, t.HasSort Γ s)) ∧
      (HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ) ∧
      (Exhaustive P a (unguardedPats arms)) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Lazy の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m},
    HasTypeCQ P B Ψ Q C Γ Φ R (.lazyC m) T outEff Δ →
    ∃ a,
      (HasTypeCQ P B (hideBuilders Ψ) Q C (hideConts Γ) Φ none m a Eff.empty []) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ (.lazy a) T ∧ Eff.Covers Γ Φ outEff Eff.empty : Prop)

-- C_Escape の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.escape v) T outEff Δ →
    ∃ r a ε,
      (R = (some r)) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v r) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Use の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m},
    HasTypeCQ P B Ψ Q C Γ Φ R (.use v m) T outEff Δ →
    ∃ o a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.opaque o (.fixed .top))) ∧
      (B.isResource o = true) ∧
      (HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) ∧
      (ε.test (.name stateEff (.fixed .top)) = true) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Handle の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {h},
    HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) T outEff Δ →
    ∃ t εm ε,
      (HasTypeCQ P B Ψ Q C Γ Φ R m t εm Δ) ∧
      (Eff.Sub εm (Eff.union ε (handled P B h))) ∧
      (HasTypeClausesQ P B Ψ Q C Γ Φ R εm h t ε Δ) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_Handle_Fail の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {h},
    HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) T outEff Δ →
    ∃ t E eb rest ec,
      (HasTypeCQ P B Ψ Q C Γ Φ R m t eb Δ) ∧
      (Eff.Sub eb (Eff.union (Eff.singleFail E) rest)) ∧
      (NoFail Q rest) ∧
      (HasFailureClause P B Ψ Q C Γ Φ E R h t ec Δ) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff (Eff.union rest ec) : Prop)

-- C_Resume の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {i} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.var i) v) T outEff Δ →
    ∃ b t ε,
      (Γ[i]? = some (some (.cont b t ε))) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b) ∧
      (Ty.Declared P C Γ t) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_ResumeL の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {l} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) T outEff Δ →
    ∃ b t ε,
      (Ψ l = some (.cont b t ε R)) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b) ∧
      (Ty.Declared P C Γ t) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_ResumeNorm の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {i} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.var i) v) T outEff Δ →
    ∃ b t ε,
      (Γ[i]? = some (some (.cont b t ε))) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b.norm) ∧
      (Ty.Declared P C Γ t.norm) ∧
      Ty.LeQ P Γ Φ t.norm T ∧ Eff.Covers Γ Φ outEff (Eff.norm ε) : Prop)

-- C_ResumeLNorm の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {l} {v},
    HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) T outEff Δ →
    ∃ R' b t ε,
      (Ψ l = some (.cont b t ε R')) ∧
      (R'.map Ty.norm = R.map Ty.norm) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b.norm) ∧
      (Ty.Declared P C Γ t.norm) ∧
      Ty.LeQ P Γ Φ t.norm T ∧ Eff.Covers Γ Φ outEff (Eff.norm ε) : Prop)

-- C_Meth の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m} {ss} {es} {ws},
    HasTypeCQ P B Ψ Q C Γ Φ R (.meth v m ss es ws) T outEff Δ →
    ∃ cl τ cd ms as a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl τ)) ∧
      (P.classes cl = some cd) ∧
      (cd.methods m = some ms) ∧
      (NamesWF ms.names ms.params) ∧
      (SatAll B C ss (TypeCtx.constraints ms.tparams)) ∧
      (SignatureInstance P C Γ ms.tel (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) es) ∧
      (MethodRowsAdmissible C Γ.length Q ms es) ∧
      (Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) es) ws = some (as, a, ε)) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ ws as) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε : Prop)

-- C_External の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {f} {ts} {vs},
    HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts vs) T outEff Δ →
    ∃ d a e,
      (P.externalFunction f = some d) ∧
      (d.WF P) ∧
      (ExternalCallAdmissible P B C d ts) ∧
      (HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (typeEnv ts) d.parameters) a e) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff e : Prop)

-- C_IssuePathBases の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {b : PrimName},
    HasTypeCQ P B Ψ Q C Γ Φ R (.issuePathBases b) T outEff Δ →
    ∃ (sg : PrimSig),
      (B.sig b = some sg) ∧
      (sg.kind = .pathBases) ∧
      (sg.opEff = some processEnvironmentEff) ∧
      (sg.params = []) ∧
      (sg.ret = .pathBases) ∧
      (sg.eff = Eff.single processEnvironmentEff) ∧
      Ty.LeQ P Γ Φ .pathBases T ∧ Eff.Covers Γ Φ outEff (Eff.single processEnvironmentEff) : Prop)

-- C_CheckAt の直接の枝
#check (∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {name} {shape} {bases} {pattern} {input} {index},
    HasTypeCQ P B Ψ Q C Γ Φ R (.checkAt kind name shape bases pattern input index) T outEff Δ →
    (AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) ∧
      Ty.LeQ P Γ Φ (.data shape.owner [.scoped name kind index, shape.errorType]) T ∧ Eff.Covers Γ Φ outEff Eff.empty : Prop)

end Benitoite.Release.Refinement.Signatures
