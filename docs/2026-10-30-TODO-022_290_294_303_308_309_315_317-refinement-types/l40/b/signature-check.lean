import Benitoite
namespace Benitoite.Release.Refinement.FixedInversionSignatures

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {f} {ts} {es} :
    HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es) T →
    ∃ d u,
      (P.defs f = some d) ∧
      (NamesWF d.names d.params) ∧
      (Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
          (Qsig d.params d.ret d.eff) Q ts es d.eff) ∧
      (SignatureInstance P C Γ d.tel (TypeCtx.kinds d.tparams) ts es) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.tel ts es) u := by
  intro h
  exact h.inv_fnRef rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {b} {ts} {es} {rs} :
    HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts es rs) T →
    ∃ s u,
      (B.sig b = some s) ∧
      (B.RangeAdmissible b s rs) ∧
      (NamesWF s.names s.params) ∧
      (PrimitiveAdmissible C Γ.length s Q ts es) ∧
      (SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel (Tel.instR rs s.tel) ts es) u := by
  intro h
  exact h.inv_prim rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {o} {ts} :
    HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T →
    ∃ od u,
      (P.ops o = some od) ∧
      (NamesWF od.names od.params) ∧
      (SatAll B C ts od.tparams) ∧
      (SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts []) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel od.tel ts []) u := by
  intro h
  exact h.inv_op rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {ns} {ps} {body} :
    HasTypeVQ P B Ψ Q C Γ Φ (.lam ns ps body) T →
    ∃ r ε u,
      (NamesWF ns ps) ∧
      (Ty.WF 0 C.length Γ.length (.fn ns ps r ε)) ∧
      (Ty.Sorted Γ (.fn ns ps r ε)) ∧
      (HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) []) ∧
      (Ty.Declared P C Γ (.fn ns ps r ε)) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel ns ps r ε) u := by
  intro h
  exact h.inv_lam rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {t} {body} :
    HasTypeVQ P B Ψ Q C Γ Φ (.dependentLam t body) T →
    ∃ u,
      (Ty.Annotation P C Γ (.dependentFn t)) ∧
      (TelBodyTy P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ t u := by
  intro h
  exact h.inv_dependentLam rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {t} {e} :
    HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T →
    ∃ u,
      (Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e))) ∧
      (Ordinary t) ∧
      (Ordinary e) ∧
      (t.HasKind P (TypeCtx.kinds C) .value) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel ["error"] [e] t (Eff.singleFail e)) u := by
  intro h
  exact h.inv_raise rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {ks} {vs} :
    HasTypeVQ P B Ψ Q C Γ Φ (.mapV ks vs) T →
    ∃ a b k w,
      (HasTypeEachQ P B Ψ Q C Γ Φ ks a) ∧
      (HasTypeEachQ P B Ψ Q C Γ Φ vs b) ∧
      (ks.length = vs.length) ∧
      (B.sat (TypeCtx.constraints C) a.norm TParam.keyC) ∧
      (Ty.Annotation P C Γ a) ∧
      (Ty.Annotation P C Γ b) ∧
      T.norm.core = .map k w ∧ a.norm = k.norm ∧ Ty.LeQ P Γ Φ b w := by
  intro h
  exact h.inv_mapV rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {vs} :
    HasTypeVQ P B Ψ Q C Γ Φ (.setV vs) T →
    ∃ a w,
      (HasTypeEachQ P B Ψ Q C Γ Φ vs a) ∧
      (B.sat (TypeCtx.constraints C) a.norm TParam.keyC) ∧
      (Ty.Annotation P C Γ a) ∧
      T.norm.core = .set w ∧ a.norm = w.norm := by
  intro h
  exact h.inv_setV rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {bs} :
    HasTypeVQ P B Ψ Q C Γ Φ (.bytesV bs) T →
    ((∀ b ∈ bs, b ≤ 255)) ∧
      T.norm.core = .bytes := by
  intro h
  exact h.inv_bytesV rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {i} {ts} {vs} :
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
      T.norm.core = (Ty.dict id.cls (id.target.subst ts [])).norm.core := by
  intro h
  exact h.inv_dict rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {v} {super} :
    HasTypeVQ P B Ψ Q C Γ Φ (.super v super) T →
    ∃ cl a cd,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl a)) ∧
      (P.classes cl = some cd) ∧
      (super ∈ cd.supers) ∧
      (Ty.Declared P C Γ a) ∧
      T.norm.core = (Ty.dict super a).norm.core := by
  intro h
  exact h.inv_super rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {n} :
    HasTypeCQ P B Ψ Q C Γ Φ R (.letIn m n) T outEff Δ →
    ∃ a b ε,
      (HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) ∧
      (HasTypeCQ P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 Δ)) ∧
      (Ty.Declared P C Γ b) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε := by
  intro h
  exact h.inv_let rfl

example {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} :
    HasTypeCQ P B Ψ Q C Γ Φ R (.escape v) T outEff Δ →
    ∃ r a ε,
      (R = (some r)) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v r) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε := by
  intro h
  exact h.inv_escape rfl

end Benitoite.Release.Refinement.FixedInversionSignatures
