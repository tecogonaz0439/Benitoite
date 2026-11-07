import Benitoite.Release.Refinement.TypeSubstTypingMotives
import Benitoite.Release.Refinement.Narrowing
import Benitoite.Release.Refinement.TypeSubstLocalSignature
import Benitoite.Release.Refinement.TypeSubstAux

namespace Benitoite.Release.Refinement.S02Internal
variable {P : Program} {B : Builtins}

theorem case_V_Var :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {i : Nat} {a : Ty},
  Γ[i]? = some (some a) → Ordinary a → VGoal P B Ψ Q C Γ Φ (Val.var i) a := by
  intro Ψ Q C Γ Φ i a hv ho C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact .V_Var (by simp only [Ctx.bindTypes, List.getElem?_map, hv, Option.map_some]; rfl)
    (Ty.ordinary_bind ho _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary))

theorem case_V_Const :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {c : Const},
  ConstOK B c → VGoal P B Ψ Q C Γ Φ (Val.const c) c.type := by
  intro Ψ Q C Γ Φ c hv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  cases c <;> exact .V_Const hv

theorem case_V_Lam :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {ns : List String}
  {ps : List Ty} {body : Comp} {r : Ty} {ε : EffR},
  NamesWF ns ps →
    Ty.WF 0 (List.length C) (List.length Γ) (Ty.fn ns ps r ε) →
      Ty.Sorted Γ (Ty.fn ns ps r ε) →
        HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
            (some (Ty.shiftV ps.length 0 r)) body (Ty.shiftV ps.length 0 r) (Eff.shiftV ps.length 0 ε) →
          Ty.Declared P C Γ (Ty.fn ns ps r ε) →
            CGoal P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
                (some (Ty.shiftV ps.length 0 r)) body (Ty.shiftV ps.length 0 r) (Eff.shiftV ps.length 0 ε) [] →
              VGoal P B Ψ Q C Γ Φ (Val.lam ns ps body) (Ty.fn ns ps r ε) := by
  intro Ψ Q C Γ Φ ns ps body r e hn hw hs hb hd ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  apply HasTypeVQ.type_subst_lam hf hi hn ⟨hw,hs,hd⟩
  have hb' := ih rfl ⟨hf.1,hf.2.1,hf.2.2.1,hf.2.2.2.hide⟩ hi
    (hc.binders 0 ps.length (fun _ _ _ _ h => h.2.2)) hq
  simpa only [Ctx.bindTypes_params hi.typeWF hi.rowWF, Ctx.bindTypes_hideConts Γ _
    (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary), List.length_map,
    substAt_shiftV_closed hi.typeWF hi.rowWF, eff_substAt_shiftV_closed hi.typeWF hi.rowWF,
    Option.map_some, List.map_nil, map_typeImages_shiftV_closed hi.typeWF,
    map_rowImages_shiftV_closed hi.rowWF] using hb' 

theorem case_V_DependentLam :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {t : Tel} {body : Comp},
  Ty.Annotation P C Γ (Ty.dependentFn t) →
    TelBodyTy P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body →
      BodyGoal P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body →
        VGoal P B Ψ Q C Γ Φ (Val.dependentLam t body) (Ty.dependentFn t) := by
  intro Ψ Q C Γ Φ t body ha hb ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ha' := Tel.annotation_substAt hf hi ha
  have hb' := ih rfl ⟨hf.1,hf.2.1,hf.2.2.1,hf.2.2.2.hide⟩ hi
    (hc.binders 0 (telBinders t) (fun _ _ _ _ h => h.2)) hq
  simp only [] at hb'
  rw [Ctx.bindTypes_hideConts Γ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary)] at hb'
  have out := HasTypeVQ.V_Normal (HasTypeVQ.V_DependentLam ha' hb')
  simpa only [Val.substTyAt, map_typeImages_shiftV_closed hi.typeWF,
    map_rowImages_shiftV_closed hi.rowWF, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind,
    Ty.norm, Tel.substAt, Tel.bind, Tel.norm_idem] using out

theorem case_V_Closure :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {runtime t : Tel}
  {body : Closure},
  Ty.Annotation P C Γ (Ty.dependentFn t) →
    runtime.RuntimeShape t →
      DependentClosureTy P B Ψ body t →
        DependentClosureTy P B Ψ body t → VGoal P B Ψ Q C Γ Φ (Val.closure runtime body) (Ty.dependentFn t) := by
  intro Ψ Q C Γ Φ runtime t body ha hr hb ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact HasTypeVQ.type_subst_closure hf hi hc ha hr ih

theorem case_V_Fun :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {f : Benitoite.Release.FunName} {d : Def} {ts : List Ty} {es : List Eff} {rs : List RangeExpr},
  P.defs f = some d →
    NamesWF d.names d.params →
      Def.RangeAdmissible d rs →
      Admissible B C (List.length Γ) (TypeCtx.constraints d.tparams) d.neffs (Qsig d.params d.ret d.eff) Q ts es d.eff →
        SignatureInstance P C Γ (d.instTel rs) (TypeCtx.kinds d.tparams) ts es →
          VGoal P B Ψ Q C Γ Φ (Val.fnRef f ts es (List.map RangeIx.fixed rs)) (Ty.dependentFn (instantiatedTel (d.instTel rs) ts es)) := by
  intro Ψ Q C Γ Φ f d ts es rs hd hn hr ha hs C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact gate_fun_case_ranges hf hi hc hq (.V_Fun hd hn hr ha hs)

theorem case_V_Prim :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {b : Benitoite.Release.PrimName} {s : PrimSig} {ts : List Ty} {es : List Eff} {rs : List RangeExpr},
  B.sig b = some s →
    B.RangeAdmissible b s rs →
      NamesWF s.names s.params →
        PrimitiveAdmissible C (List.length Γ) s Q ts es →
          SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es →
            VGoal P B Ψ Q C Γ Φ (Val.prim b ts es (List.map RangeIx.fixed rs)) (Ty.dependentFn (instantiatedTel (Tel.instR rs s.tel) ts es)) := by
  intro Ψ Q C Γ Φ b s ts es rs hl hr hn ha hsi C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have rows := Tel.rowsIn_instR ha.sourceTelRows rs
  have hs' := hsi.substAt hf hi rows
  have out := HasTypeVQ.V_Normal (HasTypeVQ.V_Prim (Ψ := Ψ) (Q := Q') (Φ := Φ)
    hl hr hn (ha.substAt hf hi hl hsi.types hsi.rows hq) hs')
  have hlen := hsi.kinds.1
  have comm := instantiatedTel_substAt hsi.source ts es (by omega) rows C1.length us fs
  rw [←comm] at out
  dsimp only [Val.substTyAt, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    Tel.substAt,Tel.bind] at out ⊢
  rw [show Ty.substAt C1.length us fs = substTypeAt C1.length us fs from rfl,
    show Eff.substAt C1.length us fs = substRowAt C1.length us fs from rfl] at out
  simpa only [Tel.norm_idem] using out

theorem case_V_Op :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {o : Benitoite.Release.OpName}
  {od : OpDecl} {ts : List Ty},
  P.ops o = some od →
    NamesWF od.names od.params →
      SatAll B C ts od.tparams →
        SignatureInstance P C Γ od.tel (List.replicate od.tparams.length TyKind.value) ts [] →
          VGoal P B Ψ Q C Γ Φ (Val.op o ts) (Ty.dependentFn (instantiatedTel od.tel ts [])) := by
  intro Ψ Q C Γ Φ o od ts hd hn ha hs C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact gate_op_case hf hi hc hq (.V_Op hd hn ha hs)

theorem case_V_ExternalRef :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {f : ExternalFunctionId}
  {d : ExternalSignature} {ts : List Ty},
  P.externalFunction f = some d →
    ExternalSignature.WF P d →
      ExternalCallAdmissible P B C d ts →
        SignatureInstance P C Γ d.parameters d.kinds ts [] →
          VGoal P B Ψ Q C Γ Φ (Val.externalRef f ts) (Ty.dependentFn (instantiatedTel d.parameters ts [])) := by
  intro Ψ Q C Γ Φ f d ts hl hw ha hsi C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ht := ha.types_nil hw
  subst ts
  have adm : ExternalCallAdmissible P B C1 d [] := by
    refine ⟨by simp [hw.monomorphic],⟨by simp [hw.kinds],?_⟩,⟨by simp [hw.monomorphic],?_⟩,?_⟩
    · intro i a k h; cases h
    · intro i a k h; cases h
    · intro a h; cases h
  have hsi' := hsi.substAt hf hi hw.sourceTelRows
  simp only [List.map_nil] at hsi'
  have comm := instantiatedTel_substAt hsi.source [] [] (by have := hsi.kinds.1; simp_all)
    hw.sourceTelRows C1.length us fs
  simp only [List.map_nil] at comm
  have out := HasTypeVQ.V_Normal (HasTypeVQ.V_ExternalRef (Ψ := Ψ) (Q := Q') (Φ := Φ)
    hl hw adm hsi')
  rw [←comm] at out
  dsimp only [Val.substTyAt, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    Tel.substAt,Tel.bind] at out ⊢
  simpa only [List.map_nil,Tel.norm_idem] using out

theorem case_V_ExternalHandle :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {ts : List Ty}
  (h : ExternalHandle) (td : ExternalTypeDecl),
  P.externalType h.typeId = some td →
    td.component = h.component →
      td.resource = h.resource →
        ts.length = td.arity →
          Ty.Annotation P C Γ (Ty.external h.typeId ts) →
            VGoal P B Ψ Q C Γ Φ (Val.externalHandle h ts) (Ty.external h.typeId ts) := by
  intro Ψ Q C Γ Φ ts h td hl hc hr hn ha C0 C1 us fs Q' hC hf hi hcode hq
  subst C
  have ha' := ha.substAt hf hi
  dsimp only [Val.substTyAt, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm] at ha' ⊢
  simp only [rawBindTys_eq_map, Ty.normTys_eq_map, List.map_map] at ha' ⊢
  exact .V_ExternalHandle h td hl hc hr (by simpa only [List.length_map] using hn) ha' 

theorem case_V_PathBases :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {snapshot : PathEnv},
  snapshot.Valid → VGoal P B Ψ Q C Γ Φ (Val.pathBases snapshot) Ty.pathBases := by
  intro Ψ Q C Γ Φ snapshot hv C0 C1 us fs Q' hC hf hi hc hq
  exact .V_PathBases hv

theorem case_V_ScopePattern :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {range : RangeExpr}
  {kind : Benitoite.Scope.Domain.Kind},
  range.WF → range.Canonical → range.FitsKind kind → VGoal P B Ψ Q C Γ Φ (Val.scopePattern range) (Ty.scopePattern kind) := by
  intro Ψ Q C Γ Φ range kind hw hn hk C0 C1 us fs Q' hC hf hi hc hq
  exact .V_ScopePattern hw hn hk

theorem case_V_Checked :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind} {range : Benitoite.Scope.Domain.Range}
  {target : Benitoite.Scope.Domain.Target},
  B.valKind o = some k →
    B.valContent o = none →
      Benitoite.Scope.Domain.Range.MemK k range target →
        VGoal P B Ψ Q C Γ Φ (Val.checked target) (Ty.scoped o k (RangeIx.fixed (RangeExpr.absolute range))) := by
  intro Ψ Q C Γ Φ o k range target hk hn hm C0 C1 us fs Q' hC hf hi hc hq
  exact .V_Checked hk hn hm

theorem case_V_CheckedRequest :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {o : Benitoite.Release.OpaqueName} {range : Benitoite.Scope.Domain.Range} {target : Benitoite.Scope.Domain.Target}
  {req : Val} {T : Ty},
  B.valKind o = some Benitoite.Scope.Domain.Kind.endpoint →
    B.valContent o = some T →
      HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] req T.norm →
        groundVal req = true →
          req.reqTarget = some target →
            Benitoite.Scope.Domain.Range.MemK Benitoite.Scope.Domain.Kind.endpoint range target →
              VGoal P B Ψ Benitoite.Release.Qempty [] [] [] req T.norm →
                VGoal P B Ψ Q C Γ Φ (Val.checkedRequest target req)
                  (Ty.scoped o Benitoite.Scope.Domain.Kind.endpoint (RangeIx.fixed (RangeExpr.absolute range))) := by
  intro Ψ Q C Γ Φ o range target req T hk hn hv hg ht hm ih C0 C1 us fs Q' hC hf hi hc hq
  exact .V_CheckedRequest hk hn hv hg ht hm

theorem case_V_CheckedAt :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind} {range : RangeExpr} {snapshot : Option PathEnv}
  {target : Benitoite.Scope.Domain.Target} {request : Option Val},
  CheckedWitness P B Ψ o k range snapshot target request →
    CheckedWitness P B Ψ o k range snapshot target request →
      VGoal P B Ψ Q C Γ Φ (Val.checkedAt range snapshot target request) (Ty.scoped o k (RangeIx.fixed range)) := by
  intro Ψ Q C Γ Φ o k range snapshot target request hw ih C0 C1 us fs Q' hC hf hi hc hq
  exact .V_CheckedAt ih

theorem case_V_AtError :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {shape : ResultShape}
  {detail : AtError}, ResultShape.Declared P shape → VGoal P B Ψ Q C Γ Φ (Val.atError detail) shape.errorType := by
  intro Ψ Q C Γ Φ shape detail hs C0 C1 us fs Q' hC hf hi hc hq
  simpa only [Val.substTyAt, hs.errorType_eq, atErrorType, Ty.substAt, substTypeAt, Ty.bind,
    Ty.rawBind, Ty.norm, rawBindTys, Ty.normTys] using
    HasTypeVQ.V_AtError (Ψ := Ψ) (Q := Q') (C := C1)
      (Γ := Γ.bindTypes (typeEnvAt C1.length us fs)) (Φ := Φ) (detail := detail) hs

theorem case_V_Map :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {ks vs : List Val} {a b : Ty},
  HasTypeEachQ P B Ψ Q C Γ Φ ks a →
    HasTypeEachQ P B Ψ Q C Γ Φ vs b →
      ks.length = vs.length →
        B.sat C.constraints a.norm Benitoite.Release.TParam.keyC →
          Ty.Annotation P C Γ a →
            Ty.Annotation P C Γ b →
              EachGoal P B Ψ Q C Γ Φ ks a → EachGoal P B Ψ Q C Γ Φ vs b → VGoal P B Ψ Q C Γ Φ (Val.mapV ks vs) (a.map b) := by
  intro Ψ Q C Γ Φ ks vs a b hks hvs hn hk ha hb ihk ihv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ha' := ha.substAt hf hi
  have hb' := hb.substAt hf hi
  have hk' := hf.2.2.1.sat_subst C0 C1 a.norm _ us fs hk hi.typeWF hi.constraints hi.typeCount
  simp only [Ty.substAt_norm_source] at hk'
  have out := HasTypeVQ.V_Map
    (ihk rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq)
    (ihv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq)
    (by simpa only [List.length_map] using hn)
    (by simpa only [Ty.substAt,substTypeAt,Ty.bind,Ty.norm_idem] using hk') ha' hb'
  simpa only [Val.substTyAt, Val.substTyAtList_eq_map,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm] using out

theorem case_V_Set :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {a : Ty},
  HasTypeEachQ P B Ψ Q C Γ Φ vs a →
    B.sat C.constraints a.norm Benitoite.Release.TParam.keyC →
      Ty.Annotation P C Γ a → EachGoal P B Ψ Q C Γ Φ vs a → VGoal P B Ψ Q C Γ Φ (Val.setV vs) a.set := by
  intro Ψ Q C Γ Φ vs a hv hk ha ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ha' := ha.substAt hf hi
  have hk' := hf.2.2.1.sat_subst C0 C1 a.norm _ us fs hk hi.typeWF hi.constraints hi.typeCount
  simp only [Ty.substAt_norm_source] at hk'
  have out := HasTypeVQ.V_Set (ih rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h)) hq)
    (by simpa only [Ty.substAt,substTypeAt,Ty.bind,Ty.norm_idem] using hk') ha'
  simpa only [Val.substTyAt, Val.substTyAtList_eq_map,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm] using out

theorem case_V_Dict :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {i : Benitoite.Release.ImplName} {id : ImplDecl} {ts : List Ty} {vs : List Val},
  P.impls i = some id →
    SatAll B C ts id.tparams →
      TypeAnnotations P C Γ ts →
        TypeArgsKinded P C ts (List.replicate id.tparams.length TyKind.value) →
          (∀ (a : Ty), a ∈ id.dictTys → Ty.WF 0 id.tparams.length 0 a) →
            Ty.WF 0 id.tparams.length 0 id.target →
              HasTypeVsQ P B Ψ Q C Γ Φ vs (List.map (Ty.subst ts []) id.dictTys) →
                Ty.Annotation P C Γ (Ty.dict id.cls (Ty.subst ts [] id.target)) →
                  VsGoal P B Ψ Q C Γ Φ vs (List.map (Ty.subst ts []) id.dictTys) →
                    VGoal P B Ψ Q C Γ Φ (Val.dict i ts vs) (Ty.dict id.cls (Ty.subst ts [] id.target)) := by
  intro Ψ Q C Γ Φ i id ts vs hl hs ht hk hw htarget hv ha ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hh := ih rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq
  have hr : ∀ a ∈ id.dictTys, a.RowsIn (· < 0) := by
    intro a ha
    obtain ⟨p,hp,rfl⟩ := List.mem_map.mp ha
    trivial
  have comm : (id.dictTys.map (Ty.subst ts [])).map (Ty.substAt C1.length us fs) =
      id.dictTys.map (Ty.subst (ts.map (Ty.substAt C1.length us fs)) []) := by
    rw [List.map_map]
    exact List.map_congr_left (fun a ha => by
      simpa only [List.map_nil,Function.comp_def] using Ty.subst_substAt (hw a ha) ts [] (by have := hs.1; omega)
        (hr a ha) C1.length us fs)
  rw [comm] at hh
  have ha' := ha.substAt hf hi
  have htarg := Ty.subst_substAt htarget ts [] (by have := hs.1; omega)
    (hf.1.impls i id hl).2.1.2.1 C1.length us fs
  simp only [List.map_nil] at htarg
  have out := HasTypeVQ.V_Dict hl (hs.substAt hf.2.2.1 hi) (ht.substAt hf hi)
    (hk.substAt hi.typeKinds hi.rowKinds) hw htarget hh
    (by simpa only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,←htarg] using ha')
  dsimp only [Val.substTyAt,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm] at out ⊢
  simp only [Val.substTyAtList_eq_map] at out ⊢
  try dsimp only [Ty.substAt,substTypeAt,Ty.bind] at out ⊢
  rw [show Ty.substAt C1.length us fs = substTypeAt C1.length us fs from rfl] at out
  rw [show Ty.substAt C1.length us fs = substTypeAt C1.length us fs from rfl] at htarg
  rw [←htarg] at out
  simpa only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm] using out

theorem case_V_Raise :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {t e : Ty},
  Ty.Annotation P C Γ (Ty.fn ["error"] [e] t (Eff.singleFail e)) →
    Ordinary t →
      Ordinary e →
        Ty.HasKind P C.kinds t TyKind.value →
          VGoal P B Ψ Q C Γ Φ (Val.raise t e) (Ty.fn ["error"] [e] t (Eff.singleFail e)) := by
  intro Ψ Q C Γ Φ t e ha ho he hk C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact HasTypeVQ.type_subst_raise hf hi ha ho he hk

theorem case_V_LocRef :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {l : Nat} {a : Ty},
  Ψ l = some (LocTy.ref a) → Ty.Declared P C Γ a → VGoal P B Ψ Q C Γ Φ (Val.loc l) a.reference := by
  intro Ψ Q C Γ Φ l a hl hd C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact HasTypeVQ.type_subst_locRef hf hi hc hl hd

theorem case_V_LocLazy :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {l : Nat} {a : Ty},
  Ψ l = some (LocTy.lazy a) → Ty.Declared P C Γ a → VGoal P B Ψ Q C Γ Φ (Val.loc l) a.lazy := by
  intro Ψ Q C Γ Φ l a hl hd C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact HasTypeVQ.type_subst_locLazy hf hi hc hl hd

theorem case_V_Bytes :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {bs : List Nat},
  (∀ (b : Nat), b ∈ bs → b ≤ 255) → VGoal P B Ψ Q C Γ Φ (Val.bytesV bs) Ty.bytes := by
  intro Ψ Q C Γ Φ bs hb C0 C1 us fs Q' hC hf hi hc hq
  exact .V_Bytes hb

theorem case_V_Con :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {c : Benitoite.Release.ConName} {cd : ConDecl} {ts : List Ty} {vs : List Val},
  P.cons c = some cd →
    ts.length = cd.ntys →
      TypeArgsKinded P C ts (List.replicate cd.ntys TyKind.value) →
        (∀ (t : Ty), t ∈ cd.args → Ty.WF 0 cd.ntys 0 t) →
          HasTypeVsQ P B Ψ Q C Γ Φ vs (List.map (Ty.subst ts []) cd.args) →
            Ty.Annotation P C Γ (Ty.data cd.data ts) →
              VsGoal P B Ψ Q C Γ Φ vs (List.map (Ty.subst ts []) cd.args) →
                VGoal P B Ψ Q C Γ Φ (Val.con c ts vs) (Ty.data cd.data ts) := by
  intro Ψ Q C Γ Φ c cd ts vs hl hn hk hw hv ha ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hh := ih rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq
  have comm : (cd.args.map (Ty.subst ts [])).map (Ty.substAt C1.length us fs) =
      cd.args.map (Ty.subst (ts.map (Ty.substAt C1.length us fs)) []) := by
    rw [List.map_map]
    exact List.map_congr_left (fun a ha => by
      simpa only [List.map_nil,Function.comp_def] using Ty.subst_substAt (hw a ha) ts [] (by omega)
        ((hf.1.cons c cd hl).2 a ha).1.2.1 C1.length us fs)
  rw [comm] at hh
  have ha' := ha.substAt hf hi
  dsimp only [Val.substTyAt,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm] at ha' ⊢
  simp only [rawBindTys_eq_map,Ty.normTys_eq_map,List.map_map,Val.substTyAtList_eq_map]
    at ha' ⊢
  exact .V_Con hl (by simpa using hn) (hk.substAt hi.typeKinds hi.rowKinds) hw hh ha' 

theorem case_V_Super :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val}
  {cl : Benitoite.Release.ClassName} {a : Ty} {cd : ClassDecl} {super : Benitoite.Release.ClassName},
  HasTypeVQ P B Ψ Q C Γ Φ v (Ty.dict cl a) →
    P.classes cl = some cd →
      super ∈ cd.supers →
        Ty.Declared P C Γ a →
          VGoal P B Ψ Q C Γ Φ v (Ty.dict cl a) → VGoal P B Ψ Q C Γ Φ (v.super super) (Ty.dict super a) := by
  intro Ψ Q C Γ Φ v cl a cd super hv hl hs hd ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact .V_Super (ih rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h)) hq)
    hl hs (hd.typeSubst hf hi)

theorem case_V_List :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {vs : List Val} {a : Ty},
  HasTypeEachQ P B Ψ Q C Γ Φ vs a →
    Ty.WF 0 (List.length C) (List.length Γ) a →
      Ty.Sorted Γ a → Ty.Declared P C Γ a → EachGoal P B Ψ Q C Γ Φ vs a → VGoal P B Ψ Q C Γ Φ (Val.list vs) a.list := by
  intro Ψ Q C Γ Φ vs a hv hw hs hd ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ha := (Ty.Annotation.mk hw hs hd).substAt hf hi
  exact .V_List (by simpa only [Val.substTyAtList_eq_map, Ty.substAt, substTypeAt, Ty.bind] using
      (ih rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h)) hq)) ha.wf ha.sorted ha.declared

theorem case_V_Sub :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {a b : Ty},
  HasTypeVQ P B Ψ Q C Γ Φ v a →
    Ty.LeQ P Γ Φ a b →
      Ty.WF 0 (List.length C) (List.length Γ) b →
        Ty.Sorted Γ b → Ty.Declared P C Γ b → VGoal P B Ψ Q C Γ Φ v a → VGoal P B Ψ Q C Γ Φ v b := by
  intro Ψ Q C Γ Φ v a b hv hl hw hs hd ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ha := (Ty.Annotation.mk hw hs hd).substAt hf hi
  exact .V_Sub (ih rfl hf hi hc hq) (hl.substAt _ _ _ hi.typeKinds.ordinary)
    ha.wf ha.sorted ha.declared

theorem case_V_Normal :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty},
  HasTypeVQ P B Ψ Q C Γ Φ v a → VGoal P B Ψ Q C Γ Φ v a → VGoal P B Ψ Q C Γ Φ v a.norm := by
  intro Ψ Q C Γ Φ v a hv ih C0 C1 us fs Q' hC hf hi hc hq
  simpa only [Ty.substAt_norm_source] using ih hC hf hi hc hq

theorem case_V_Refine :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {a : Ty}
  {t : Benitoite.Release.Refinement.Term} {p : Pred} {sort : «Sort»},
  HasTypeVQ P B Ψ Q C Γ Φ v a →
    a.HasSort sort →
      v.toTerm? = some t →
        Pred.Sorted Γ (some a) p →
          Pred.WF (List.length Γ + 1) p →
            Entails (Γ.facts ++ Φ) (p.open t) →
              Ty.Declared P C Γ a →
                Pred.Declared P C Γ (some a) p → VGoal P B Ψ Q C Γ Φ v a → VGoal P B Ψ Q C Γ Φ v (a.refined p) := by
  intro Ψ Q C Γ Φ v a t p sort hv has ht hs hw he hda hdp ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hm := Transport.types Γ Φ (typeEnvAt C1.length us fs) rfl
    (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary)
  have ent : Entails ((Γ.bindTypes (typeEnvAt C1.length us fs)).facts ++ Φ) (p.open t) := by
    simpa only [typeEnvAt, predBind_id] using hm.entails he
  have out := HasTypeVQ.V_Normal (HasTypeVQ.V_Refine (ih rfl hf hi hc hq)
    (Ty.hasSort_bind has _) (by simpa only [Val.toTerm_substTyAt] using ht)
    (hs.typeSubst hi) (by simpa only [Ctx.bindTypes,List.length_map] using hw) ent
    (hda.typeSubst hf hi) (hdp.typeSubst hf hi))
  simpa only [Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, typeEnvAt,
    upValues_id, predBind_id, Ty.norm_idem] using out

theorem case_Vs_nil :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}, VsGoal P B Ψ Q C Γ Φ [] [] := by
  intro Ψ Q C Γ Φ C0 C1 us fs Q' hC hf hi hc hq
  exact .nil

theorem case_Vs_cons :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {vs : List Val}
  {a : Ty} {as : List Ty},
  HasTypeVQ P B Ψ Q C Γ Φ v a →
    HasTypeVsQ P B Ψ Q C Γ Φ vs as →
      VGoal P B Ψ Q C Γ Φ v a → VsGoal P B Ψ Q C Γ Φ vs as → VsGoal P B Ψ Q C Γ Φ (v :: vs) (a :: as) := by
  intro Ψ Q C Γ Φ v vs a as hv hvs ih ihs C0 C1 us fs Q' hC hf hi hc hq
  apply HasTypeVsQ.cons
  · exact ih hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq
  · exact ihs hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq

theorem case_Each_nil :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {a : Ty},
  EachGoal P B Ψ Q C Γ Φ [] a := by
  intro Ψ Q C Γ Φ a C0 C1 us fs Q' hC hf hi hc hq
  exact .nil

theorem case_Each_cons :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {v : Val} {vs : List Val}
  {a : Ty},
  HasTypeVQ P B Ψ Q C Γ Φ v a →
    HasTypeEachQ P B Ψ Q C Γ Φ vs a →
      VGoal P B Ψ Q C Γ Φ v a → EachGoal P B Ψ Q C Γ Φ vs a → EachGoal P B Ψ Q C Γ Φ (v :: vs) a := by
  intro Ψ Q C Γ Φ v vs a hv hvs ih ihs C0 C1 us fs Q' hC hf hi hc hq
  apply HasTypeEachQ.cons
  · exact ih hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq
  · exact ihs hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq

theorem case_C_BuilderLet :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {kind : BuilderKind} {body : Comp} {a : Ty} {ε : Eff},
  Ty.Annotation P C Γ kind.contents →
    TypeArgsKinded P C [kind.contents] [TyKind.value] →
      HasTypeCQ P B Ψ Q C Γ.extendNone (List.map Pred.lift Φ) (Option.map (Ty.shiftV 1 0) R) body (Ty.shiftV 1 0 a)
          (Eff.shiftV 1 0 ε) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ) →
        Ty.Declared P C Γ a →
          CGoal P B Ψ Q C Γ.extendNone (List.map Pred.lift Φ) (Option.map (Ty.shiftV 1 0) R) body (Ty.shiftV 1 0 a)
              (Eff.shiftV 1 0 ε) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ) →
            CGoal P B Ψ Q C Γ Φ R (Comp.builderLet kind body) a ε Δ := by
  intro Ψ Q C Γ Φ Δ R kind body a e ha hk hb hd ib C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hb' := ib rfl hf hi (hc.binders 0 1 (fun _ _ _ _ h => h.2)) hq
  have out := HasTypeCQ.C_BuilderLet (kind := kind.substAt C1.length us fs) (R := R.map (Ty.substAt C1.length us fs)) (Δ := Δ.map (Option.map (BuilderKind.substAt C1.length us fs)))
    (by simpa only [BuilderKind.contents_substAt] using ha.substAt hf hi)
    (by simpa only [BuilderKind.contents_substAt,List.map_cons,List.map_nil]
      using hk.substAt hi.typeKinds hi.rowKinds)
    (by simpa only [Ctx.bindTypes_extendNone hi,return_typeSubst_shiftV hi,
      substAt_shiftV_closed hi.typeWF hi.rowWF,eff_substAt_shiftV_closed hi.typeWF hi.rowWF,
      LocalCtx.typeSubst_extend hi,Option.map_some,BuilderKind.substAt_rename_shift hi] using hb')
    (hd.typeSubst hf hi)
  have hcode : (Comp.builderLet kind body).substTyAt C1.length us fs =
      .builderLet (kind.substAt C1.length us fs) (body.substTyAt C1.length us fs) := by
    cases kind <;> simp only [Comp.substTyAt,map_typeImages_shiftV_closed hi.typeWF,
      map_rowImages_shiftV_closed hi.rowWF]
    all_goals rfl
  simpa only [hcode] using out

theorem case_C_BuilderOp :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {kind : BuilderKind} {op : BuilderOp} {ref : Benitoite.Release.LocalRef} {args : List Val},
  Ty.Annotation P C Γ kind.contents →
    TypeArgsKinded P C [kind.contents] [TyKind.value] →
      LocalRef.HasKind Ψ Δ ref kind →
        HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind) →
          VsGoal P B Ψ Q C Γ Φ args (op.parameters kind) →
            CGoal P B Ψ Q C Γ Φ R (Comp.builderOp kind op ref args) (op.resultType kind) Eff.empty Δ := by
  intro Ψ Q C Γ Φ Δ R kind op ref args ha hk hr hv iv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have href : fs = [] ∨ ∃ i, ref = .bound i := by
    rcases hc with he | ⟨nr,nt,ne,nv,h⟩
    · exact Or.inl he
    · cases ref with
      | bound i => exact Or.inr ⟨i,rfl⟩
      | loc l => exact False.elim h.2.1
  have out := HasTypeCQ.C_BuilderOp (op := op) (R := R.map (Ty.substAt C1.length us fs))
    (by simpa only [BuilderKind.contents_substAt] using ha.substAt hf hi)
    (by simpa only [BuilderKind.contents_substAt,List.map_cons,List.map_nil]
      using hk.substAt hi.typeKinds hi.rowKinds)
    (hr.typeSubst hf.2.2.2 href)
    (by simpa only [BuilderOp.parameters_substAt] using (iv rfl hf hi
      (hc.binders 0 0 (fun _ _ _ _ h => h.2.2)) hq))
  have hcode : (Comp.builderOp kind op ref args).substTyAt C1.length us fs =
      .builderOp (kind.substAt C1.length us fs) op ref (Val.substTyAtList C1.length us fs args) := by
    cases kind <;> rfl
  simpa only [hcode,←BuilderOp.resultType_substAt,Eff.substAt_empty,Val.substTyAtList_eq_map] using out

theorem case_C_Return :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {v : Val} {a : Ty},
  HasTypeVQ P B Ψ Q C Γ Φ v a → VGoal P B Ψ Q C Γ Φ v a → CGoal P B Ψ Q C Γ Φ R (Comp.ret v) a Eff.empty Δ := by
  intro Ψ Q C Γ Φ Δ R v a hv ih C0 C1 us fs Q' hC hf hi hc hq
  simp only [Comp.substTyAt, Eff.substAt_empty]
  exact .C_Return (ih hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h)) hq)

theorem case_C_Let :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {m n : Comp} {a b : Ty} {ε : Eff},
  HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
    HasTypeCQ P B Ψ Q C (Γ.extend a) (List.map Pred.lift Φ) (Option.map (Ty.shiftV 1 0) R) n (Ty.shiftV 1 0 b)
        (Eff.shiftV 1 0 ε) (localExtend 1 Δ) →
      Ty.Declared P C Γ b →
        CGoal P B Ψ Q C Γ Φ R m a ε Δ →
          CGoal P B Ψ Q C (Γ.extend a) (List.map Pred.lift Φ) (Option.map (Ty.shiftV 1 0) R) n (Ty.shiftV 1 0 b)
              (Eff.shiftV 1 0 ε) (localExtend 1 Δ) →
            CGoal P B Ψ Q C Γ Φ R (m.letIn n) b ε Δ := by
  intro Ψ Q C Γ Φ Δ R m n a b e hm hn hd im in' C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hm' := im rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq
  have hn' := in' rfl hf hi (hc.binders 0 1 (fun _ _ _ _ h => h.2)) hq
  have out := HasTypeCQ.C_Let hm'
    (by simpa only [Ctx.bindTypes_extend hi,return_typeSubst_shiftV hi,
      substAt_shiftV_closed hi.typeWF hi.rowWF,eff_substAt_shiftV_closed hi.typeWF hi.rowWF,
      BuilderKind.substAt_eq,LocalCtx.typeSubst_localExtend hi] using hn') (hd.typeSubst hf hi)
  simpa only [Comp.substTyAt,map_typeImages_shiftV_closed hi.typeWF,
    map_rowImages_shiftV_closed hi.rowWF] using out

theorem case_C_App :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {f : Val} {args : List Val} {ns : List String} {as : List Ty} {b : Ty} {ε : EffR},
  HasTypeVQ P B Ψ Q C Γ Φ f (Ty.fn ns as b ε) →
    HasTypeVsQ P B Ψ Q C Γ Φ args as →
      VGoal P B Ψ Q C Γ Φ f (Ty.fn ns as b ε) →
        VsGoal P B Ψ Q C Γ Φ args as → CGoal P B Ψ Q C Γ Φ R (Comp.app f args) b ε Δ := by
  intro Ψ Q C Γ Φ Δ R f args ns as b e hf0 ha ihf iha C0 C1 us fs Q' hC hf hi hc hq
  have hv := ihf hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq
  have hs := iha hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq
  rw [Ty.substAt_fn] at hv
  simp only [Comp.substTyAt, Val.substTyAtList_eq_map]
  exact .C_App hv hs

theorem case_C_DependentApp :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {f : Val} {args : List Val} {t : Tel} {a : Ty} {e : Eff},
  HasTypeVQ P B Ψ Q C Γ Φ f (Ty.dependentFn t) →
    HasTypeTelArgsQ P B Ψ Q C Γ Φ args t a e →
      VGoal P B Ψ Q C Γ Φ f (Ty.dependentFn t) →
        ArgsGoal P B Ψ Q C Γ Φ args t a e → CGoal P B Ψ Q C Γ Φ R (Comp.app f args) a e Δ := by
  intro Ψ Q C Γ Φ Δ R f args t a e hv ha iv ia C0 C1 us fs Q' hC hf hi hc hq
  subst C
  apply HasTypeCQ.C_DependentAppNorm (t := Tel.substAt C1.length us fs t)
  · simpa only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,Tel.substAt,Tel.bind,Tel.norm_idem]
      using iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq
  · simpa only [Val.substTyAtList_eq_map] using ia rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq

theorem case_C_If :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {v : Val} {t : Benitoite.Release.Refinement.Term} {m n : Comp} {a : Ty} {ε : Eff},
  HasTypeVQ P B Ψ Q C Γ Φ v (Ty.base Benitoite.Release.BaseTy.boolean) →
    v.toTerm? = some t →
      HasTypeCQ P B Ψ Q C Γ (boolCond t true :: Φ) R m a ε Δ →
        HasTypeCQ P B Ψ Q C Γ (boolCond t false :: Φ) R n a ε Δ →
          VGoal P B Ψ Q C Γ Φ v (Ty.base Benitoite.Release.BaseTy.boolean) →
            CGoal P B Ψ Q C Γ (boolCond t true :: Φ) R m a ε Δ →
              CGoal P B Ψ Q C Γ (boolCond t false :: Φ) R n a ε Δ → CGoal P B Ψ Q C Γ Φ R (Comp.ite v m n) a ε Δ := by
  intro Ψ Q C Γ Φ Δ R v t m n a e hv ht hm hn ihv ihm ihn C0 C1 us fs Q' hC hf hi hc hq
  exact .C_If (ihv hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq)
    (by simpa only [Val.toTerm_substTyAt] using ht)
    (ihm hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.1)) hq)
    (ihn hC hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.2)) hq)

theorem case_C_Match :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {v : Val} {obs : Option Benitoite.Release.Refinement.Term} {arms : List Arm} {a b : Ty} {ε : Eff},
  HasTypeVQ P B Ψ Q C Γ Φ v a →
    (∀ (t : Benitoite.Release.Refinement.Term), obs = some t → v.toTerm? = some t ∧ ∃ s, Term.HasSort Γ t s) →
      HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
        Ty.Declared P C Γ a →
        Exhaustive P a (unguardedPats arms) →
          VGoal P B Ψ Q C Γ Φ v a →
            ArmsGoal P B Ψ Q C Γ Φ R obs arms a b ε Δ → CGoal P B Ψ Q C Γ Φ R (Comp.match v arms) b ε Δ := by
  intro Ψ Q C Γ Φ Δ R v obs arms a b e hv ho ha hdecl he iv ia C0 C1 us fs Q' hC hf hi hc hq
  subst C
  refine .C_Match (iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq) ?_
    (ia rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq) (hdecl.typeSubst hf hi) ?_
  · intro t ht
    obtain ⟨hv,s,hs⟩ := ho t ht
    exact ⟨by simpa only [Val.toTerm_typeSubst] using hv,s,
      by simpa only [termBind_id] using (Term.hasSort_termBind hs _ (Ctx.typeSubst_sortMap Γ hi).values
        (Ctx.typeSubst_sortMap Γ hi).references)⟩
  · rw [unguardedPats_substTy]
    exact he.substAt hf.1 C1.length us fs

theorem case_C_Lazy :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {m : Comp} {a : Ty},
  HasTypeCQ P B (hideBuilders Ψ) Q C (hideConts Γ) Φ none m a Eff.empty →
    Ty.Annotation P C Γ a →
      CGoal P B (hideBuilders Ψ) Q C (hideConts Γ) Φ none m a Eff.empty [] →
        CGoal P B Ψ Q C Γ Φ R m.lazyC a.lazy Eff.empty Δ := by
  intro Ψ Q C Γ Φ Δ R m a hb ha ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hb' := ih rfl ⟨hf.1,hf.2.1,hf.2.2.1,hf.2.2.2.hide⟩ hi
    (hc.binders 0 0 (fun _ _ _ _ h => h)) hq
  simp only [Ctx.bindTypes_hideConts Γ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary),
    Eff.substAt_empty,Option.map_none,List.map_nil] at hb'
  simp only [Comp.substTyAt, Eff.substAt_empty,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm]
  apply HasTypeCQ.C_Lazy
  · simpa only [Ty.substAt,substTypeAt,Ty.bind] using hb'
  · simpa only [Ty.substAt,substTypeAt,Ty.bind] using ha.substAt hf hi

theorem case_C_Escape :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {r : Ty}
  {v : Val} {a : Ty} {ε : Eff},
  HasTypeVQ P B Ψ Q C Γ Φ v r →
    Ty.Annotation P C Γ a → VGoal P B Ψ Q C Γ Φ v r → CGoal P B Ψ Q C Γ Φ (some r) (Comp.escape v) a ε Δ := by
  intro Ψ Q C Γ Φ Δ r v a e hv ha ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact .C_Escape
    (ih rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h)) hq) (ha.substAt hf hi)

theorem case_C_Use :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {v : Val} {o : Benitoite.Release.OpaqueName} {m : Comp} {a : Ty} {ε : Eff},
  HasTypeVQ P B Ψ Q C Γ Φ v (Ty.opaque o (RangeIx.fixed RangeExpr.top)) →
    B.isResource o = true →
      HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
        ε.test (Atom.name Benitoite.Release.stateEff (RangeIx.fixed RangeExpr.top)) = true →
          VGoal P B Ψ Q C Γ Φ v (Ty.opaque o (RangeIx.fixed RangeExpr.top)) →
            CGoal P B Ψ Q C Γ Φ R m a ε Δ → CGoal P B Ψ Q C Γ Φ R (Comp.use v m) a ε Δ := by
  intro Ψ Q C Γ Φ Δ R v o m a e hv hr hm he iv im C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact .C_Use (iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq) hr
    (im rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq)
    (by
      change (Eff.rawBind (typeEnvAt C1.length us fs) e).norm.mem _
      rw [Eff.mem_norm,Eff.mem_rawBind]
      exact Or.inl ⟨_,he,rfl,by simp⟩)

theorem case_C_Handle :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {m : Comp} {h : List Clause} {t : Ty} {εm ε : Eff},
  HasTypeCQ P B Ψ Q C Γ Φ R m t εm Δ →
    εm.Sub (ε.union (handled P B h)) →
      HasTypeClausesQ P B Ψ Q C Γ Φ R εm h t ε Δ →
        CGoal P B Ψ Q C Γ Φ R m t εm Δ →
          ClausesGoal P B Ψ Q C Γ Φ R εm h t ε Δ → CGoal P B Ψ Q C Γ Φ R (m.handle h) t ε Δ := by
  intro Ψ Q C Γ Φ Δ R m cs t em e hm hs hcs im ics C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact .C_Handle (im rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq)
    (by simpa only [Eff.substAt_union,handled_substAt,handled_typeSubst]
      using (show Eff.Sub (Eff.substAt C1.length us fs em) (Eff.substAt C1.length us fs (e.union (handled P B cs))) from hs.bind (typeEnvAt C1.length us fs)))
    (ics rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq)

theorem case_C_Handle_Fail :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {m : Comp} {h : List Clause} {t E : Ty} {eb rest ec : Eff},
  HasTypeCQ P B Ψ Q C Γ Φ R m t eb Δ →
    eb.Sub ((Eff.singleFail E).union rest) →
      NoFail Q rest →
        HasFailureClause P B Ψ Q C Γ Φ E R h t ec Δ →
          CGoal P B Ψ Q C Γ Φ R m t eb Δ →
            FailureGoal P B Ψ Q C Γ Φ E R h t ec Δ → CGoal P B Ψ Q C Γ Φ R (m.handle h) t (rest.union ec) Δ := by
  intro Ψ Q C Γ Φ Δ R m cs t E eb rest ec hm hs hn hcs im ics C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have out := HasTypeCQ.C_Handle_Fail (im rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq)
    (by simpa only [Eff.substAt_union,Eff.substAt_singleFail]
      using (show Eff.Sub (Eff.substAt C1.length us fs eb) (Eff.substAt C1.length us fs ((Eff.singleFail E).union rest)) from hs.bind (typeEnvAt C1.length us fs)))
    (hn.substAt C1.length us fs hq)
    (ics rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq)
  simpa only [Comp.substTyAt,Eff.substAt,substRowAt,Eff.bind_union] using out

theorem case_C_Resume :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {i : Nat} {v : Val} {b t : Ty} {ε : Eff},
  Γ[i]? = some (some (b.cont t ε)) →
    HasTypeVQ P B Ψ Q C Γ Φ v b →
      Ty.Declared P C Γ t → VGoal P B Ψ Q C Γ Φ v b → CGoal P B Ψ Q C Γ Φ R (Comp.resume (Val.var i) v) t ε Δ := by
  intro Ψ Q C Γ Φ Δ R i v b t e hl hv hd iv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact .C_Resume
    (by simp only [Ctx.bindTypes,List.getElem?_map,hl,Option.map_some,
      Ty.bind,Ty.rawBind,Ty.norm]; rfl)
    (iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq) (hd.typeSubst hf hi)

theorem case_C_ResumeL :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {l : Nat} {v : Val} {b t : Ty} {ε : Eff},
  Ψ l = some (LocTy.cont b t ε R) →
    HasTypeVQ P B Ψ Q C Γ Φ v b →
      Ty.Declared P C Γ t → VGoal P B Ψ Q C Γ Φ v b → CGoal P B Ψ Q C Γ Φ R (Comp.resume (Val.loc l) v) t ε Δ := by
  intro Ψ Q C Γ Φ Δ R l v b t e hl hv hd iv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact HasTypeCQ.type_subst_resumeL hf hi hc hl hd
    (iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq)

theorem case_C_ResumeNorm :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {i : Nat} {v : Val} {b t : Ty} {ε : Eff},
  Γ[i]? = some (some (b.cont t ε)) →
    HasTypeVQ P B Ψ Q C Γ Φ v b.norm →
      Ty.Declared P C Γ t.norm →
        VGoal P B Ψ Q C Γ Φ v b.norm → CGoal P B Ψ Q C Γ Φ R (Comp.resume (Val.var i) v) t.norm ε.norm Δ := by
  intro Ψ Q C Γ Φ Δ R i v b t e hl hv hd iv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hv' := iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq
  have hd' := hd.typeSubst hf hi
  simp only [Ty.substAt_norm_source] at hv' hd'
  have out := HasTypeCQ.C_Resume (i := i) (ε := Eff.substAt C1.length us fs e) (Δ := Δ.map (Option.map (BuilderKind.substAt C1.length us fs))) (R := R.map (Ty.substAt C1.length us fs))
    (by simp only [Ctx.bindTypes,List.getElem?_map,hl,Option.map_some,
      Ty.bind,Ty.rawBind,Ty.norm]; rfl) hv' hd'
  simpa only [Comp.substTyAt,Val.substTyAt,Ty.substAt_norm_source,Eff.substAt,substRowAt,
    Eff.bind,Eff.norm_rawBind,Eff.norm_idem,BuilderKind.substAt_eq] using out

theorem case_C_ResumeLNorm :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx}
  {R R' : Option Ty} {l : Nat} {v : Val} {b t : Ty} {ε : Eff},
  Ψ l = some (LocTy.cont b t ε R') →
    Option.map Ty.norm R' = Option.map Ty.norm R →
      HasTypeVQ P B Ψ Q C Γ Φ v b.norm →
        Ty.Declared P C Γ t.norm →
          VGoal P B Ψ Q C Γ Φ v b.norm → CGoal P B Ψ Q C Γ Φ R (Comp.resume (Val.loc l) v) t.norm ε.norm Δ := by
  intro Ψ Q C Γ Φ Δ R R' l v b t e hl hr hv hd iv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hfs : fs = [] := hc.resolve_right (by rintro ⟨nr,nt,ne,nv,h⟩; exact h.1)
  subst fs
  have hw := hf.2.2.2 l _ hl
  have hb : b.substAt C1.length us [] = b.norm :=
    Ty.substAt_nil_of_wf us b (hw.1.closed_context (C := C1) (Γ := []))
  have ht : t.substAt C1.length us [] = t.norm :=
    Ty.substAt_nil_of_wf us t (hw.2.1.closed_context (C := C1) (Γ := []))
  have he : Eff.substAt C1.length us [] e = Eff.norm e :=
    by
      change (Eff.rawBind (typeEnvAt C1.length us []) e).norm = Eff.norm e
      rw [Eff.rawBind_agrees hw.2.2.1 (θ := typeEnvAt C1.length us []) (τ := renEnv id)
        ⟨by intro i hi; omega,rfl,rfl,rfl⟩,Eff.rawBind_id]
  have hv' := iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq
  have hd' := hd.typeSubst hf hi
  have hr' := congrArg (Option.map (Ty.substAt C1.length us [])) hr
  have hleft : (R'.map Ty.norm).map (Ty.substAt C1.length us []) = R'.map Ty.norm := by
    cases hx : R' with
    | none => rfl
    | some a =>
      simp only [Option.map_some,Ty.substAt_norm_source]
      rw [Ty.substAt_nil_of_wf us a ((hw.2.2.2.2 a hx).closed_context (C := C1) (Γ := []))]
  rw [hleft] at hr'
  have hcomm : (R.map Ty.norm).map (Ty.substAt C1.length us []) =
      (R.map (Ty.substAt C1.length us [])).map Ty.norm := by
    cases R <;> simp only [Option.map_none,Option.map_some,
      Ty.substAt,substTypeAt,Ty.bind,Ty.norm_idem,Ty.norm_rawBind]
  rw [hcomm] at hr'
  simp only [Ty.substAt_norm_source,hb,ht] at hv' hd'
  simpa only [Comp.substTyAt,Val.substTyAt,Ty.substAt_norm_source,ht,
    Eff.substAt,substRowAt,Eff.bind,Eff.norm_rawBind,Eff.norm_idem,show (Eff.rawBind (typeEnvAt C1.length us []) e).norm = Eff.norm e from he] using
    (HasTypeCQ.C_ResumeLNorm (Δ := Δ.map (Option.map (BuilderKind.substAt C1.length us []))) hl hr' hv' hd')

theorem case_C_Normal :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {m : Comp} {a : Ty} {ε : Eff},
  HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ → CGoal P B Ψ Q C Γ Φ R m a ε Δ → CGoal P B Ψ Q C Γ Φ R m a.norm ε Δ := by
  intro Ψ Q C Γ Φ Δ R m a e hv ih C0 C1 us fs Q' hC hf hi hc hq
  simpa only [Ty.substAt_norm_source] using ih hC hf hi hc hq

theorem case_C_Meth :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {v : Val} {cl : Benitoite.Release.ClassName} {τ : Ty} {cd : ClassDecl} {m : Benitoite.Release.MethName} {ms : MethSig}
  {ss : List Ty} {es : List Eff} {ws : List Val} {as : List Ty} {a : Ty} {ε : Eff},
  HasTypeVQ P B Ψ Q C Γ Φ v (Ty.dict cl τ) →
    P.classes cl = some cd →
      cd.methods m = some ms →
        NamesWF ms.names ms.params →
          SatAll B C ss (TypeCtx.constraints ms.tparams) →
            SignatureInstance P C Γ ms.tel (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) es →
              MethodRowsAdmissible C (List.length Γ) Q ms es →
                (instantiatedTel ms.tel (ss ++ [τ]) es).arguments ws = some (as, a, ε) →
                  HasTypeVsQ P B Ψ Q C Γ Φ ws as →
                    Ty.Annotation P C Γ a →
                      VGoal P B Ψ Q C Γ Φ v (Ty.dict cl τ) →
                        VsGoal P B Ψ Q C Γ Φ ws as → CGoal P B Ψ Q C Γ Φ R (Comp.meth v m ss es ws) a ε Δ := by
  intro Ψ Q C Γ Φ Δ R v cl τ cd m ms ss es ws as a e hv hcl hm hn hs hsi hr ha hws hann ihv ihws C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have out := HasTypeCQ.type_subst_meth (L := Δ) (R := R) hf hi hq hcl hm hn hs hsi hr ha hann
    (ihv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq)
    (ihws rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.2.2)) hq)
  apply Eq.mp ?_ out
  congr 1
  apply List.map_congr_left
  intro b _
  cases b with
  | none => rfl
  | some b => cases b <;> rfl

theorem case_C_External :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {f : ExternalFunctionId} {d : ExternalSignature} {ts : List Ty} {vs : List Val} {a : Ty} {e : Eff},
  P.externalFunction f = some d →
    ExternalSignature.WF P d →
      ExternalCallAdmissible P B C d ts →
        HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (typeEnv ts) d.parameters) a e →
          ArgsGoal P B Ψ Q C Γ Φ vs (Tel.bind (typeEnv ts) d.parameters) a e →
            CGoal P B Ψ Q C Γ Φ R (Comp.externalCall f ts vs) a e Δ := by
  intro Ψ Q C Γ Φ Δ R f ext ts vs a e hl hw ha hargs ia C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hts := ha.types_nil hw
  subst ts
  have adm : ExternalCallAdmissible P B C1 ext [] := by
    refine ⟨by simp [hw.monomorphic],⟨by simp [hw.kinds],?_⟩,⟨by simp [hw.monomorphic],?_⟩,?_⟩
    · intro i a k h; cases h
    · intro i a k h; cases h
    · intro a h; cases h
  have ha' := ia rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq
  have comm := instantiatedTel_substAt hw.annotation.wf [] [] (by simp)
    hw.sourceTelRows C1.length us fs
  simp only [instantiatedTel,List.map_nil] at comm
  have henv : typeEnv [] = typeEnvAt 0 [] [] := rfl
  rw [henv,comm,←henv] at ha' 
  simpa only [Comp.substTyAt,List.map_nil,Val.substTyAtList_eq_map] using
    (HasTypeCQ.C_External (R := R.map (Ty.substAt C1.length us fs)) (Δ := Δ.map (Option.map (BuilderKind.substAt C1.length us fs))) hl hw adm ha')

theorem case_C_IssuePathBases :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  (b : Benitoite.Release.PrimName) (sg : PrimSig),
  B.sig b = some sg →
    sg.kind = PrimKind.pathBases →
      sg.opEff = some processEnvironmentEff →
        sg.params = [] →
          sg.ret = Ty.pathBases →
            sg.eff = Eff.single processEnvironmentEff →
              CGoal P B Ψ Q C Γ Φ R (Comp.issuePathBases b) Ty.pathBases (Eff.single processEnvironmentEff) Δ := by
  intro Ψ Q C Γ Φ Δ R b sg hl hk ho hp hr he C0 C1 us fs Q' hC hf hi hc hq
  rcases hc with rfl | ⟨nr,nt,ne,nv,hsc⟩
  · simp [Comp.substTyAt,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,
      Eff.substAt,substRowAt,Eff.bind,Eff.rawBind,Eff.single,typeEnvAt,
      instAtoms_nil,substAtoms_nil,rowFails,rawBindTys,Eff.norm,Ty.normTys]
    exact .C_IssuePathBases b sg hl hk ho hp hr he
  · cases hsc

theorem case_C_CheckAt :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName} {shape : ResultShape} {bases : Option Val}
  {pattern input : Val} {index : RangeIx},
  AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index →
    AtGoal P B Ψ Q C Γ Φ kind name shape bases pattern input index →
      CGoal P B Ψ Q C Γ Φ R (Comp.checkAt kind name shape bases pattern input index)
        (Ty.data shape.owner [Ty.scoped name kind index, shape.errorType]) Eff.empty Δ := by
  intro Ψ Q C Γ Φ Δ R kind name shape bases pattern input index ha ia C0 C1 us fs Q' hC hf hi hc hq
  subst C
  cases bases
  all_goals
    have hs : shape.Declared P := by cases ha <;> assumption
    have he : substTypeAt C1.length us fs shape.errorType = shape.errorType := by
      rw [hs.errorType_eq]
      rfl
    have hsh : {shape with errorType := substTypeAt C1.length us fs shape.errorType} = shape := by
      rw [he]
    have htype : (Ty.data shape.owner [Ty.scoped name kind index,shape.errorType]).substAt C1.length us fs =
        Ty.data shape.owner [Ty.scoped name kind index,shape.errorType] := by
      simp only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,Ty.normTys,rawBindTys,
        typeEnvAt,RangeIx.inst_nil]
      change Ty.data shape.owner [Ty.scoped name kind index,substTypeAt C1.length us fs shape.errorType] = _
      rw [he]
    have hout := ia rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.2)) hq
    simpa only [Comp.substTyAt,hsh,htype,Eff.substAt_empty,Option.map_none,Option.map_some] using
      HasTypeCQ.C_CheckAt (R := R.map (Ty.substAt C1.length us fs))
        (Δ := Δ.map (Option.map (BuilderKind.substAt C1.length us fs))) hout


theorem case_C_Sub :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {m : Comp} {a b : Ty} {ε ε' : Eff},
  HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
    Ty.LeQ P Γ Φ a b →
      Eff.Covers Γ Φ ε' ε →
        Ty.WF 0 (List.length C) (List.length Γ) b →
          Ty.Sorted Γ b → Ty.Declared P C Γ b → CGoal P B Ψ Q C Γ Φ R m a ε Δ → CGoal P B Ψ Q C Γ Φ R m b ε' Δ := by
  intro Ψ Q C Γ Φ Δ R m a b e e' hv hl he hw hs hd ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ha := (Ty.Annotation.mk hw hs hd).substAt hf hi
  exact .C_Sub (ih rfl hf hi hc hq) (hl.substAt _ _ _ hi.typeKinds.ordinary)
    (he.substAt _ _ _) ha.wf ha.sorted ha.declared

theorem case_C_Eff :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {m : Comp} {a : Ty} {ε ε' : Eff},
  HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ →
    Eff.Covers Γ Φ ε' ε → CGoal P B Ψ Q C Γ Φ R m a ε Δ → CGoal P B Ψ Q C Γ Φ R m a ε' Δ := by
  intro Ψ Q C Γ Φ Δ R m a e e' hv he ih C0 C1 us fs Q' hC hf hi hc hq
  exact .C_Eff (ih hC hf hi hc hq) (he.substAt _ _ _)

theorem case_Args_done :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {a : Ty} {e : EffR},
  Ty.Annotation P C Γ (Ty.dependentFn (Tel.done a e)) → ArgsGoal P B Ψ Q C Γ Φ [] (Tel.done a e) a e := by
  intro Ψ Q C Γ Φ a e ha C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ha' := Tel.annotation_substAt hf hi ha
  simpa only [Tel.substAt,Tel.bind,Tel.rawBind,Tel.norm,Ty.substAt,substTypeAt,Ty.bind,
    Eff.substAt,substRowAt,Eff.bind,List.map_nil] using HasTypeTelArgsQ.done ha' 

theorem case_Args_param :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {name : String} {a : Ty}
  {rest : Tel} {v : Val} {vs : List Val} {r : Ty} {e : Eff},
  Ty.Annotation P C Γ a →
    HasTypeVQ P B Ψ Q C Γ Φ v a →
      HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (Tel.argumentsEnv v) rest) r e →
        VGoal P B Ψ Q C Γ Φ v a →
          ArgsGoal P B Ψ Q C Γ Φ vs (Tel.bind (Tel.argumentsEnv v) rest) r e →
            ArgsGoal P B Ψ Q C Γ Φ (v :: vs) (Tel.param name a rest) r e := by
  intro Ψ Q C Γ Φ name a rest v vs r e ha hv hs ihv ihs C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have ha' := ha.substAt hf hi
  have hv' := ihv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.1)) hq
  have hs' := ihs rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq
  have out := HasTypeTelArgsQ.param (name := name) (rest := Tel.bind (typeEnvAt C1.length us fs).up rest) ha' hv'
    (by simpa only [Tel.open_typeSubst] using hs')
  simpa only [List.map_cons,Tel.substAt,Tel.bind,Tel.rawBind,Tel.norm,Ty.substAt,substTypeAt,Ty.bind] using out

theorem case_Body_done :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {a : Ty} {e : Eff}
  {body : Comp},
  HasTypeCQ P B Ψ Q C Γ Φ (some a) body a e →
    CGoal P B Ψ Q C Γ Φ (some a) body a e [] → BodyGoal P B Ψ Q C Γ Φ (Tel.done a e) body := by
  intro Ψ Q C Γ Φ a e body hb ih C0 C1 us fs Q' hC hf hi hc hq
  exact .done (ih hC hf hi hc hq)

theorem case_Body_param :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {name : String} {a : Ty}
  {rest : Tel} {body : Comp},
  TelBodyTy P B Ψ Q C (Γ.extend a) (List.map Pred.lift Φ) rest body →
    BodyGoal P B Ψ Q C (Γ.extend a) (List.map Pred.lift Φ) rest body →
      BodyGoal P B Ψ Q C Γ Φ (Tel.param name a rest) body := by
  intro Ψ Q C Γ Φ name a rest body hb ih C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hb' := ih rfl hf hi hc hq
  simp only [] at hb'
  rw [Ctx.bindTypes_extend hi] at hb'
  simpa only [Ty.substAt, substTypeAt, Ty.bind, Tel.substAt, Tel.bind, Tel.rawBind, Tel.norm, typeEnvAt_up,
    map_typeImages_shiftV_closed hi.typeWF, map_rowImages_shiftV_closed hi.rowWF] using
    TelBodyTy.param (name := name) hb' 

theorem case_Capture_mk :
∀ {Ψ : StoreTy} {R : Option Ty} {Γ : Ctx} {Φ : List Pred} {cap : Capture},
  Ctx.CaptureWF 0 0 Γ →
    cap.values.length = List.length Γ →
      (∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → ∃ v, cap.values[i]? = some (some v)) →
        (∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → Ty.CaptureSorted Γ a ∧ Ty.CaptureDeclared P [] Γ a) →
          (∀ (p : Pred), p ∈ Φ → Pred.WF (List.length Γ) p ∧ Pred.Sorted Γ none p ∧ Pred.Declared P [] Γ none p) →
            (∀ (ov : Option Val), ov ∈ cap.values → ∀ (v : Val), ov = some v → v.Ground) →
              (∀ (i : Nat) (a : Ty),
                  Γ[i]? = some (some a) → ImageOk P B Ψ Benitoite.Release.Qempty [] [] [] R cap.env i a) →
                (∀ (p : Pred), p ∈ Γ.facts ++ Φ → Entails [] (predBind (valEnv cap.env).values p)) →
                  (∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → True) → CaptureOk P B Ψ R Γ Φ cap := by
  intros
  apply CaptureOk.mk <;> assumption

theorem case_Closure_mk :
∀ {Ψ : StoreTy} {cap : Capture} {code : Comp} {Γ : Ctx} {Φ : List Pred} {t : Tel},
  CaptureOk P B (hideBuilders Ψ) none Γ Φ cap →
    TelBodyTy P B (hideBuilders Ψ) Benitoite.Release.Qempty [] (hideConts Γ) Φ t code →
      Ty.Annotation P [] (hideConts Γ) (Ty.dependentFn t) →
        Ty.Annotation P [] [] (Ty.dependentFn (cap.closeTel t)) →
          CaptureOk P B (hideBuilders Ψ) none Γ Φ cap →
            BodyGoal P B (hideBuilders Ψ) Benitoite.Release.Qempty [] (hideConts Γ) Φ t code →
              DependentClosureTy P B Ψ (Closure.mk cap code) (cap.closeTel t) := by
  intros
  apply DependentClosureTy.mk <;> assumption

theorem case_Witness_plain :
∀ {Ψ : StoreTy} {o : Benitoite.Release.OpaqueName} {k : Benitoite.Scope.Domain.Kind} {range : RangeExpr}
  {snapshot : Option PathEnv} {target : Benitoite.Scope.Domain.Target},
  B.valKind o = some k →
    B.valContent o = none →
      target.kind = k → SnapshotMem snapshot k range target → CheckedWitness P B Ψ o k range snapshot target none := by
  intros
  apply CheckedWitness.plain <;> assumption

theorem case_Witness_request :
∀ {Ψ : StoreTy} {o : Benitoite.Release.OpaqueName} {range : RangeExpr} {snapshot : Option PathEnv}
  {target : Benitoite.Scope.Domain.Target} {req : Val} {T : Ty},
  B.valKind o = some Benitoite.Scope.Domain.Kind.endpoint →
    B.valContent o = some T →
      HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] [] req T.norm →
        groundVal req = true →
          req.reqTarget = some target →
            SnapshotMem snapshot Benitoite.Scope.Domain.Kind.endpoint range target →
              VGoal P B Ψ Benitoite.Release.Qempty [] [] [] req T.norm →
                CheckedWitness P B Ψ o Benitoite.Scope.Domain.Kind.endpoint range snapshot target (some req) := by
  intros
  apply CheckedWitness.request <;> assumption

theorem case_At_mk :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName} {shape : ResultShape} {bases : Option Val}
  {pattern input : Val} {index : RangeIx} {inputTy : Ty},
  ResultShape.Declared P shape →
    B.valKind name = some kind →
      (∀ (v : Val), bases = some v → HasTypeVQ P B Ψ Q C Γ Φ v Ty.pathBases) →
        HasTypeVQ P B Ψ Q C Γ Φ pattern (Ty.scopePattern kind) →
          inputTy = Ty.base Benitoite.Release.BaseTy.string ∧ B.valContent name = none ∨
              B.valContent name = some inputTy ∧ Ty.WF 0 0 0 inputTy ∧ Ty.RowsIn (fun x => x < 0) inputTy →
            HasTypeVQ P B Ψ Q C Γ Φ input inputTy.norm →
              RangeIx.WF 0 index →
                (∀ (r : RangeExpr), index = RangeIx.fixed r → r.WF ∧ r.Canonical ∧ r.FitsKind kind) →
                  (∀ (v : Val), bases = some v → VGoal P B Ψ Q C Γ Φ v Ty.pathBases) →
                    VGoal P B Ψ Q C Γ Φ pattern (Ty.scopePattern kind) →
                      VGoal P B Ψ Q C Γ Φ input inputTy.norm →
                        AtGoal P B Ψ Q C Γ Φ kind name shape bases pattern input index := by
  intro Ψ Q C Γ Φ kind name shape bases pattern input index inputTy hs hk hb hp ht hv hw hr ib ip iv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hv' := iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.2)) hq
  have hfixed : inputTy.substAt C1.length us fs = inputTy.norm := by
    rcases ht with ⟨rfl,_⟩ | ⟨_,hw,hrows⟩
    · rfl
    · exact Ty.substAt_local_rowfree us fs inputTy hw hrows (by omega)
  rw [Ty.substAt_norm_source,hfixed] at hv'
  refine .mk hs hk ?_ (ip rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.1)) hq) ht hv' hw hr
  intro v hv
  obtain ⟨w,hew,rfl⟩ := Option.map_eq_some_iff.mp hv
  exact ib w hew rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => by
    simpa only [hew,Nat.add_zero] using h.1)) hq

theorem case_At_text :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred}
  {kind : Benitoite.Scope.Domain.Kind} {name : Benitoite.Release.OpaqueName} {shape : ResultShape} {bases : Option Val}
  {pattern input : Val} {index : RangeIx} {inputTy : Ty},
  ResultShape.Declared P shape →
    B.valKind name = some kind →
      (∀ (v : Val), bases = some v → HasTypeVQ P B Ψ Q C Γ Φ v Ty.pathBases) →
        HasTypeVQ P B Ψ Q C Γ Φ pattern (Ty.base Benitoite.Release.BaseTy.string) →
          inputTy = Ty.base Benitoite.Release.BaseTy.string ∧ B.valContent name = none ∨
              B.valContent name = some inputTy ∧ Ty.WF 0 0 0 inputTy ∧ Ty.RowsIn (fun x => x < 0) inputTy →
            HasTypeVQ P B Ψ Q C Γ Φ input inputTy.norm →
              RangeIx.WF 0 index →
                (∀ (r : RangeExpr), index = RangeIx.fixed r → r.WF ∧ r.Canonical ∧ r.FitsKind kind) →
                  (∀ (v : Val), bases = some v → VGoal P B Ψ Q C Γ Φ v Ty.pathBases) →
                    VGoal P B Ψ Q C Γ Φ pattern (Ty.base Benitoite.Release.BaseTy.string) →
                      VGoal P B Ψ Q C Γ Φ input inputTy.norm →
                        AtGoal P B Ψ Q C Γ Φ kind name shape bases pattern input index := by
  intro Ψ Q C Γ Φ kind name shape bases pattern input index inputTy hs hk hb hp ht hv hw hr ib ip iv C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hv' := iv rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.2)) hq
  have hfixed : inputTy.substAt C1.length us fs = inputTy.norm := by
    rcases ht with ⟨rfl,_⟩ | ⟨_,hw,hrows⟩
    · rfl
    · exact Ty.substAt_local_rowfree us fs inputTy hw hrows (by omega)
  rw [Ty.substAt_norm_source,hfixed] at hv'
  refine .text hs hk ?_ (ip rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.1)) hq) ht hv' hw hr
  intro v hv
  obtain ⟨w,hew,rfl⟩ := Option.map_eq_some_iff.mp hv
  exact ib w hew rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => by
    simpa only [hew,Nat.add_zero] using h.1)) hq

theorem case_Arms_nil :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {obs : Option Benitoite.Release.Refinement.Term} {a b : Ty} {ε : Eff},
  Ty.Annotation P C Γ b → ArmsGoal P B Ψ Q C Γ Φ R obs [] a b ε Δ := by
  intro Ψ Q C Γ Φ Δ R obs a b e hb C0 C1 us fs Q' hC hf hi hc hq
  subst C
  exact .nil (hb.substAt hf hi)

theorem case_Arms_plain :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {obs : Option Benitoite.Release.Refinement.Term} {alts : List Benitoite.Release.Alt} {body : Comp} {arms : List Arm}
  {a b : Ty} {ε : Eff} {δ : List Ty} {links : List FieldLink},
  AltsTy P alts a δ →
    LinksValid alts δ.length links →
    FactsWF P C (bindParams Γ δ) (fieldFacts δ.length obs links) →
    FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts)) →
      HasTypeCQ P B Ψ Q C (bindParams Γ δ) (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
          (Option.map (Ty.shiftV δ.length 0) R) body (Ty.shiftV δ.length 0 b) (Eff.shiftV δ.length 0 ε)
          (localExtend δ.length Δ) →
        HasTypeArmsQ P B Ψ Q C Γ (pathFacts obs (excludedTests alts) ++ Φ) R obs arms a b ε Δ →
          CGoal P B Ψ Q C (bindParams Γ δ) (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
              (Option.map (Ty.shiftV δ.length 0) R) body (Ty.shiftV δ.length 0 b) (Eff.shiftV δ.length 0 ε)
              (localExtend δ.length Δ) →
            ArmsGoal P B Ψ Q C Γ (pathFacts obs (excludedTests alts) ++ Φ) R obs arms a b ε Δ →
              ArmsGoal P B Ψ Q C Γ Φ R obs (Arm.mk alts none body :: arms) a b ε Δ := by
  intro Ψ Q C Γ Φ Δ R obs alts body arms a b e δ links hp hvf hfw hw hb hs ib is' C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hb' := ib rfl hf hi (hc.binders 0 δ.length (fun _ _ _ _ h => by
    simpa only [←hp.2.1,Nat.add_zero] using h.2.1)) hq
  have out := HasTypeArmsQ.plain (hp.substAt hf.1 C1.length us fs)
    (by simpa only [List.length_map] using hvf)
    (by simpa only [Ctx.bindTypes_params hi.typeWF hi.rowWF,List.length_map] using hfw.typeSubst hf hi)
    (hw.typeSubst hf hi)
    (by simpa only [Ctx.bindTypes_params hi.typeWF hi.rowWF,List.length_map,
      return_typeSubst_shiftV hi,substAt_shiftV_closed hi.typeWF hi.rowWF,
      eff_substAt_shiftV_closed hi.typeWF hi.rowWF,LocalCtx.typeSubst_localExtend hi] using hb')
    (is' rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.2)) hq)
  simpa only [Arm.substTyAtList,map_typeImages_shiftV_closed hi.typeWF,
    map_rowImages_shiftV_closed hi.rowWF,←hp.2.1] using out

theorem case_Arms_guarded :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {obs : Option Benitoite.Release.Refinement.Term} {alts : List Benitoite.Release.Alt} {guard body : Comp}
  {arms : List Arm} {a b : Ty} {ε : Eff} {δ : List Ty} {p : Pred} {links : List FieldLink},
  AltsTy P alts a δ →
    LinksValid alts δ.length links →
    FactsWF P C (bindParams Γ δ) (fieldFacts δ.length obs links) →
    FactsWF P C Γ (pathFacts obs (matchedTests alts ++ excludedTests alts)) →
      Ty.Annotation P C (hideConts (bindParams Γ δ)) ((Ty.base Benitoite.Release.BaseTy.boolean).refined p) →
        HasTypeCQ P B Ψ Q C (hideConts (bindParams Γ δ)) (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
            none guard ((Ty.base Benitoite.Release.BaseTy.boolean).refined p) Eff.empty (localExtend δ.length Δ) →
          HasTypeCQ P B Ψ Q C (bindParams Γ δ)
              (p.open (Term.boolean true) :: (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ)))
              (Option.map (Ty.shiftV δ.length 0) R) body (Ty.shiftV δ.length 0 b) (Eff.shiftV δ.length 0 ε)
              (localExtend δ.length Δ) →
            HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
              CGoal P B Ψ Q C (hideConts (bindParams Γ δ)) (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
                  none guard ((Ty.base Benitoite.Release.BaseTy.boolean).refined p) Eff.empty (localExtend δ.length Δ) →
                CGoal P B Ψ Q C (bindParams Γ δ)
                    (p.open (Term.boolean true) :: (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ)))
                    (Option.map (Ty.shiftV δ.length 0) R) body (Ty.shiftV δ.length 0 b) (Eff.shiftV δ.length 0 ε)
                    (localExtend δ.length Δ) →
                  ArmsGoal P B Ψ Q C Γ Φ R obs arms a b ε Δ →
                    ArmsGoal P B Ψ Q C Γ Φ R obs (Arm.mk alts (some guard) body :: arms) a b ε Δ := by
  intro Ψ Q C Γ Φ Δ R obs alts guard body arms a b e δ p links hp hvf hfw hw hgp hg hb hs ig ib is' C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hg' := ig rfl hf hi (hc.binders 0 δ.length (fun _ _ _ _ h => by
    simpa only [←hp.2.1,Nat.add_zero] using h.1)) hq
  have ha := hgp.typeSubst_boolean hf hi
  have hfixed : (Ty.refined (.base .boolean) p).substAt C1.length us fs =
      (Ty.refined (.base .boolean) p).norm := by
    simp only [Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,typeEnvAt,
      upValues_id,predBind_id]
  simp only [Eff.substAt_empty] at hg'
  have hg'' := HasTypeCQ.C_Sub hg' (Ty.LeQ.convert (by rw [hfixed,Ty.norm_idem]))
    (Eff.Covers.refl _ _ _) ha.wf ha.sorted ha.declared
  have hb' := ib rfl hf hi (hc.binders 0 δ.length (fun _ _ _ _ h => by
    simpa only [←hp.2.1,Nat.add_zero] using h.2.1)) hq
  have out := HasTypeArmsQ.guarded (hp.substAt hf.1 C1.length us fs)
    (by simpa only [List.length_map] using hvf)
    (by simpa only [Ctx.bindTypes_params hi.typeWF hi.rowWF,List.length_map] using hfw.typeSubst hf hi)
    (hw.typeSubst hf hi)
    (by simpa only [Ctx.bindTypes_hideConts _ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary),
      Ctx.bindTypes_params hi.typeWF hi.rowWF] using ha)
    (by simpa only [Ctx.bindTypes_hideConts _ _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary),
      Ctx.bindTypes_params hi.typeWF hi.rowWF,List.length_map,
      LocalCtx.typeSubst_localExtend hi,Option.map_none,Eff.substAt_empty] using hg'')
    (by simpa only [Ctx.bindTypes_params hi.typeWF hi.rowWF,List.length_map,
      return_typeSubst_shiftV hi,substAt_shiftV_closed hi.typeWF hi.rowWF,
      eff_substAt_shiftV_closed hi.typeWF hi.rowWF,LocalCtx.typeSubst_localExtend hi] using hb')
    (is' rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2.2)) hq)
  simpa only [Arm.substTyAtList,map_typeImages_shiftV_closed hi.typeWF,
    map_rowImages_shiftV_closed hi.rowWF,←hp.2.1] using out

theorem case_Clauses_nil :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {eb : Eff} {t : Ty} {ε : Eff}, ClausesGoal P B Ψ Q C Γ Φ R eb [] t ε Δ := by
  intro Ψ Q C Γ Φ Δ R eb t e C0 C1 us fs Q' hC hf hi hc hq
  exact .nil

theorem case_Clauses_cons :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {R : Option Ty}
  {eb : Eff} {o : Benitoite.Release.OpRef} {n k : Nat} {body : Comp} {cs : List Clause} {t : Ty} {ε : Eff} {sg : OpSig},
  ClauseSig P B eb o sg →
    NamesWF sg.names sg.params →
      n = sg.params.length →
        k = List.length sg.tparams →
          sg.WF →
            HasTypeCQ P B (hideBuilders Ψ) Q (sg.tparams ++ C) (sg.context Γ t ε) (liftMany (sg.params.length + 1) Φ)
                (Option.map (fun r => Ty.shiftV (sg.params.length + 1) 0 (shiftTypes (List.length sg.tparams) 0 r)) R)
                body (Ty.shiftV (sg.params.length + 1) 0 (shiftTypes (List.length sg.tparams) 0 t))
                (Eff.shiftV (sg.params.length + 1) 0 (shiftRowsTypes (List.length sg.tparams) 0 ε)) →
              HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ε Δ →
                CGoal P B (hideBuilders Ψ) Q (sg.tparams ++ C) (sg.context Γ t ε) (liftMany (sg.params.length + 1) Φ)
                    (Option.map (fun r => Ty.shiftV (sg.params.length + 1) 0 (shiftTypes (List.length sg.tparams) 0 r))
                      R)
                    body (Ty.shiftV (sg.params.length + 1) 0 (shiftTypes (List.length sg.tparams) 0 t))
                    (Eff.shiftV (sg.params.length + 1) 0 (shiftRowsTypes (List.length sg.tparams) 0 ε)) [] →
                  ClausesGoal P B Ψ Q C Γ Φ R eb cs t ε Δ →
                    ClausesGoal P B Ψ Q C Γ Φ R eb (Clause.mk o n k body :: cs) t ε Δ := by
  intro Ψ Q C Γ Φ Δ R eb o n k body cs t e sg hs hn hn' hk hw hb hcs ib ics C0 C1 us fs Q' hC hf hi hc hq
  subst C
  subst n
  subst k
  have hb' := ib (C1 := sg.tparams ++ C1) (C0 := C0)
    (by simp only [List.append_assoc]) ⟨hf.1,hf.2.1,hf.2.2.1,hf.2.2.2.hide⟩
    (hi.under hf.2.2.1 sg.tparams)
    (hc.binders sg.tparams.length (sg.params.length+1) (fun _ _ _ _ h => h.1)) hq
  simp only [List.length_append] at hb'
  rw [Nat.add_comm sg.tparams.length C1.length] at hb'
  simp only [List.map_nil] at hb'
  have hb'' := sg.typeSubst_body (c := C1.length) (L := []) hi hw (hs.localRows hf.1 hf.2.2.1 hn)
    hf.2.2.1.substitutions hf.2.2.2.hide t e hb'
  have hh := HasTypeClausesQ.cons (hs.substAt C1.length us fs) hn rfl rfl hw
    (by simpa only [return_typeSubst_shiftV hi,
      substAt_shiftV_closed hi.typeWF hi.rowWF,eff_substAt_shiftV_closed hi.typeWF hi.rowWF,
      Ty.substAt_shift_types hi,Eff.substAt_shift_types hi,Option.map_map,Function.comp_def,
      List.map_nil] using hb'')
    (ics rfl hf hi (hc.binders 0 0 (fun _ _ _ _ h => h.2)) hq)
  simpa only [Clause.substTyAtList,List.map_map,Function.comp_def,
    map_typeImages_shiftV_closed hi.typeWF,map_rowImages_shiftV_closed hi.rowWF] using hh

theorem case_Failure_one :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {Δ : LocalCtx} {E : Ty}
  {R : Option Ty} {body : Comp} {t : Ty} {ec : Eff},
  Ty.Annotation P C Γ E →
    Ty.Annotation P C Γ t →
      RowAnnotations P C Γ [ec] →
        HasTypeCQ P B (hideBuilders Ψ) Q (TypeCtx.valueParam :: C) (failureContext Γ E) (liftMany 2 Φ)
            (Option.map (fun r => Ty.shiftV 2 0 (shiftTypes 1 0 r)) R) body (Ty.shiftV 2 0 (shiftTypes 1 0 t))
            (Eff.shiftV 2 0 (shiftRowsTypes 1 0 ec)) →
          CGoal P B (hideBuilders Ψ) Q (TypeCtx.valueParam :: C) (failureContext Γ E) (liftMany 2 Φ)
              (Option.map (fun r => Ty.shiftV 2 0 (shiftTypes 1 0 r)) R) body (Ty.shiftV 2 0 (shiftTypes 1 0 t))
              (Eff.shiftV 2 0 (shiftRowsTypes 1 0 ec)) [] →
            FailureGoal P B Ψ Q C Γ Φ E R [Clause.fail E body] t ec Δ := by
  intro Ψ Q C Γ Φ Δ E R body t e ha ht he hb ib C0 C1 us fs Q' hC hf hi hc hq
  subst C
  have hb' := ib (C1 := TypeCtx.valueParam :: C1) (C0 := C0) rfl
    ⟨hf.1,hf.2.1,hf.2.2.1,hf.2.2.2.hide⟩
    (hi.under hf.2.2.1 [TypeCtx.valueParam])
    (hc.binders 1 2 (fun _ _ _ _ h => h.2.1)) hq
  simp only [List.length_cons] at hb'
  have out := HasFailureClause.one (Δ := Δ.map (Option.map (BuilderKind.substAt C1.length us fs))) (R := R.map (Ty.substAt C1.length us fs)) (ha.substAt hf hi) (ht.substAt hf hi)
    (he.substAt hf hi)
    (by simpa only [failureContext_typeSubst hi,return_typeSubst_shiftV hi,
      substAt_shiftV_closed hi.typeWF hi.rowWF,eff_substAt_shiftV_closed hi.typeWF hi.rowWF,
      Ty.substAt_shift_types hi,Eff.substAt_shift_types hi,Option.map_map,Function.comp_def,
      List.map_nil] using hb')
  simpa only [Clause.substTyAtList,Ty.substAt,map_typeImages_shiftV_closed hi.typeWF,
    map_rowImages_shiftV_closed hi.rowWF,BuilderKind.substAt_eq] using out

theorem case_Image_ordinary :
∀ {Ψ : StoreTy} {Q : Benitoite.Release.NoFailCtx} {C : TypeCtx} {Δ : Ctx} {Ξ : List Pred} {_R0 : Option Ty}
  {ν : Nat → Val} {i : Nat} {a : Ty},
  a.Ordinary → HasTypeVQ P B Ψ Q C Δ Ξ (ν i) (substTyValues ν a) → VGoal P B Ψ Q C Δ Ξ (ν i) (substTyValues ν a) → True := by
  intros
  trivial

theorem case_Image_hidden :
∀ {_Ψ : StoreTy} {_Q : Benitoite.Release.NoFailCtx} {_C : TypeCtx} {_Δ : Ctx} {_Ξ : List Pred} {_R0 : Option Ty}
  {_ν : Nat → Val} {_i : Nat} {a : Ty}, ¬a.Ordinary → (∀ (b t : Ty) (e : EffR), a ≠ b.cont t e) → True := by
  intros
  trivial

theorem case_Image_contLoc :
∀ {Ψ : StoreTy} {_Q : Benitoite.Release.NoFailCtx} {_C : TypeCtx} {_Δ : Ctx} {_Ξ : List Pred} {R0 : Option Ty}
  {ν : Nat → Val} {i : Nat} {a b t : Ty} {e : EffR} {b' t' : Ty} {e' : EffR} {l : Nat},
  a = b.cont t e →
    substTyValues ν a = b'.cont t' e' →
      Ty.WF 0 0 0 (substTyValues ν a) →
        ν i = Val.loc l → Ψ l = some (LocTy.cont b' t' e' R0) → (∀ (r : Ty), R0 = some r → Ty.WF 0 0 0 r) → True := by
  intros
  trivial

theorem case_Image_contVar :
∀ {_Ψ : StoreTy} {_Q : Benitoite.Release.NoFailCtx} {_C : TypeCtx} {Δ : Ctx} {_Ξ : List Pred} {_R0 : Option Ty}
  {ν : Nat → Val} {i : Nat} {a b t : Ty} {e : EffR} {j : Nat},
  a = b.cont t e →
    ν i = Val.var j →
      (∃ (b' t' : Ty) (e' : Eff), Δ[j]? = some (some (b'.cont t' e')) ∧ (b'.cont t' e').norm = substTyValues ν a) → True := by
  intros
  trivial

mutual
  theorem deriveV (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : Val) (z6 : Ty) (h : HasTypeVQ P B z0 z1 z2 z3 z4 z5 z6) :
VGoal P B z0 z1 z2 z3 z4 z5 z6 := by
    match h with
    | @HasTypeVQ.V_Var _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact @case_V_Var P B _ _ _ _ _ _ _ x7 x8
    | @HasTypeVQ.V_Const _ _ x0 x1 x2 x3 x4 x5 x6 =>
      exact @case_V_Const P B _ _ _ _ _ _ x6
    | @HasTypeVQ.V_Lam _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_V_Lam P B _ _ _ _ _ _ _ _ _ _ x10 x11 x12 x13 x14 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x13))
    | @HasTypeVQ.V_DependentLam _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact @case_V_DependentLam P B _ _ _ _ _ _ _ x7 x8 (@deriveBody _ _ _ _ _ _ _ _ _ (x8))
    | @HasTypeVQ.V_Closure _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact @case_V_Closure P B _ _ _ _ _ _ _ _ x8 x9 x10 (@deriveClosure _ _ _ _ _ (x10))
    | @HasTypeVQ.V_Fun _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_V_Fun P B _ _ _ _ _ _ _ _ _ _ x10 x11 x12 x13 x14
    | @HasTypeVQ.V_Prim _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_V_Prim P B _ _ _ _ _ _ _ _ _ _ x10 x11 x12 x13 x14
    | @HasTypeVQ.V_Op _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact @case_V_Op P B _ _ _ _ _ _ _ _ x8 x9 x10 x11
    | @HasTypeVQ.V_ExternalRef _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact @case_V_ExternalRef P B _ _ _ _ _ _ _ _ x8 x9 x10 x11
    | @HasTypeVQ.V_ExternalHandle _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact @case_V_ExternalHandle P B _ _ _ _ _ _ x6 x7 x8 x9 x10 x11 x12
    | @HasTypeVQ.V_PathBases _ _ x0 x1 x2 x3 x4 x5 x6 =>
      exact @case_V_PathBases P B _ _ _ _ _ _ x6
    | @HasTypeVQ.V_ScopePattern _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact @case_V_ScopePattern P B _ _ _ _ _ _ _ x7 x8 x9
    | @HasTypeVQ.V_Checked _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact @case_V_Checked P B _ _ _ _ _ _ _ _ _ x9 x10 x11
    | @HasTypeVQ.V_CheckedRequest _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 =>
      exact @case_V_CheckedRequest P B _ _ _ _ _ _ _ _ _ _ x10 x11 x12 x13 x14 x15 (@deriveV _ _ _ _ _ _ _ _ _ (x12))
    | @HasTypeVQ.V_CheckedAt _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact @case_V_CheckedAt P B _ _ _ _ _ _ _ _ _ _ _ x11 (@deriveWitness _ _ _ _ _ _ _ _ _ (x11))
    | @HasTypeVQ.V_AtError _ _ x0 x1 x2 x3 x4 x5 x6 x7 =>
      exact @case_V_AtError P B _ _ _ _ _ _ _ x7
    | @HasTypeVQ.V_Map _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_V_Map P B _ _ _ _ _ _ _ _ _ x9 x10 x11 x12 x13 x14 (@deriveEach _ _ _ _ _ _ _ _ _ (x9)) (@deriveEach _ _ _ _ _ _ _ _ _ (x10))
    | @HasTypeVQ.V_Set _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact @case_V_Set P B _ _ _ _ _ _ _ x7 x8 x9 (@deriveEach _ _ _ _ _ _ _ _ _ (x7))
    | @HasTypeVQ.V_Dict _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact @case_V_Dict P B _ _ _ _ _ _ _ _ _ x9 x10 x11 x12 x13 x14 x15 x16 (@deriveVs _ _ _ _ _ _ _ _ _ (x15))
    | @HasTypeVQ.V_Raise _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact @case_V_Raise P B _ _ _ _ _ _ _ x7 x8 x9 x10
    | @HasTypeVQ.V_LocRef _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact @case_V_LocRef P B _ _ _ _ _ _ _ x7 x8
    | @HasTypeVQ.V_LocLazy _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact @case_V_LocLazy P B _ _ _ _ _ _ _ x7 x8
    | @HasTypeVQ.V_Bytes _ _ x0 x1 x2 x3 x4 x5 x6 =>
      exact @case_V_Bytes P B _ _ _ _ _ _ x6
    | @HasTypeVQ.V_Con _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_V_Con P B _ _ _ _ _ _ _ _ _ x9 x10 x11 x12 x13 x14 (@deriveVs _ _ _ _ _ _ _ _ _ (x13))
    | @HasTypeVQ.V_Super _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 =>
      exact @case_V_Super P B _ _ _ _ _ _ _ _ _ _ x10 x11 x12 x13 (@deriveV _ _ _ _ _ _ _ _ _ (x10))
    | @HasTypeVQ.V_List _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact @case_V_List P B _ _ _ _ _ _ _ x7 x8 x9 x10 (@deriveEach _ _ _ _ _ _ _ _ _ (x7))
    | @HasTypeVQ.V_Sub _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact @case_V_Sub P B _ _ _ _ _ _ _ _ x8 x9 x10 x11 x12 (@deriveV _ _ _ _ _ _ _ _ _ (x8))
    | @HasTypeVQ.V_Normal _ _ x0 x1 x2 x3 x4 x5 x6 x7 =>
      exact @case_V_Normal P B _ _ _ _ _ _ _ x7 (@deriveV _ _ _ _ _ _ _ _ _ (x7))
    | @HasTypeVQ.V_Refine _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact @case_V_Refine P B _ _ _ _ _ _ _ _ _ _ x10 x11 x12 x13 x14 x15 x16 x17 (@deriveV _ _ _ _ _ _ _ _ _ (x10))
  termination_by structural h

  theorem deriveVs (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : List Val) (z6 : List Ty) (h : HasTypeVsQ P B z0 z1 z2 z3 z4 z5 z6) :
VsGoal P B z0 z1 z2 z3 z4 z5 z6 := by
    match h with
    | @HasTypeVsQ.nil _ _ x0 x1 x2 x3 x4 =>
      exact @case_Vs_nil P B _ _ _ _ _
    | @HasTypeVsQ.cons _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact @case_Vs_cons P B _ _ _ _ _ _ _ _ _ x9 x10 (@deriveV _ _ _ _ _ _ _ _ _ (x9)) (@deriveVs _ _ _ _ _ _ _ _ _ (x10))
  termination_by structural h

  theorem deriveEach (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : List Val) (z6 : Ty) (h : HasTypeEachQ P B z0 z1 z2 z3 z4 z5 z6) :
EachGoal P B z0 z1 z2 z3 z4 z5 z6 := by
    match h with
    | @HasTypeEachQ.nil _ _ x0 x1 x2 x3 x4 x5 =>
      exact @case_Each_nil P B _ _ _ _ _ _
    | @HasTypeEachQ.cons _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact @case_Each_cons P B _ _ _ _ _ _ _ _ x8 x9 (@deriveV _ _ _ _ _ _ _ _ _ (x8)) (@deriveEach _ _ _ _ _ _ _ _ _ (x9))
  termination_by structural h

  theorem deriveC (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : Option Ty) (z6 : Comp) (z7 : Ty) (z8 : Eff) (z9 : optParam LocalCtx []) (h : HasTypeCQ P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9) :
CGoal P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 := by
    match h with
    | @HasTypeCQ.C_BuilderLet _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_BuilderLet P B _ _ _ _ _ _ _ _ _ _ _ x11 x12 x13 x14 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x13))
    | @HasTypeCQ.C_BuilderOp _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_BuilderOp P B _ _ _ _ _ _ _ _ _ _ _ x11 x12 x13 x14 (@deriveVs _ _ _ _ _ _ _ _ _ (x14))
    | @HasTypeCQ.C_Return _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact @case_C_Return P B _ _ _ _ _ _ _ _ _ x9 (@deriveV _ _ _ _ _ _ _ _ _ (x9))
    | @HasTypeCQ.C_Let _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_Let P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 x14 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x12)) (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x13))
    | @HasTypeCQ.C_App _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_App P B _ _ _ _ _ _ _ _ _ _ _ _ _ x13 x14 (@deriveV _ _ _ _ _ _ _ _ _ (x13)) (@deriveVs _ _ _ _ _ _ _ _ _ (x14))
    | @HasTypeCQ.C_DependentApp _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 =>
      exact @case_C_DependentApp P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 (@deriveV _ _ _ _ _ _ _ _ _ (x12)) (@deriveArgs _ _ _ _ _ _ _ _ _ _ _ (x13))
    | @HasTypeCQ.C_If _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact @case_C_If P B _ _ _ _ _ _ _ _ _ _ _ _ _ x13 x14 x15 x16 (@deriveV _ _ _ _ _ _ _ _ _ (x13)) (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x15)) (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x16))
    | @HasTypeCQ.C_Match _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact @case_C_Match P B _ _ _ _ _ _ _ _ _ _ _ _ _ x13 x14 x15 x16 x17 (@deriveV _ _ _ _ _ _ _ _ _ (x13)) (@deriveArms _ _ _ _ _ _ _ _ _ _ _ _ _ _ (x15))
    | @HasTypeCQ.C_Lazy _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact @case_C_Lazy P B _ _ _ _ _ _ _ _ _ x9 x10 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x9))
    | @HasTypeCQ.C_Escape _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact @case_C_Escape P B _ _ _ _ _ _ _ _ _ _ x10 x11 (@deriveV _ _ _ _ _ _ _ _ _ (x10))
    | @HasTypeCQ.C_Use _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 =>
      exact @case_C_Use P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 x14 x15 (@deriveV _ _ _ _ _ _ _ _ _ (x12)) (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x14))
    | @HasTypeCQ.C_Handle _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_Handle P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 x14 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x12)) (@deriveClauses _ _ _ _ _ _ _ _ _ _ _ _ _ (x14))
    | @HasTypeCQ.C_Handle_Fail _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact @case_C_Handle_Fail P B _ _ _ _ _ _ _ _ _ _ _ _ _ _ x14 x15 x16 x17 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x14)) (@deriveFailure _ _ _ _ _ _ _ _ _ _ _ _ _ (x17))
    | @HasTypeCQ.C_Resume _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_Resume P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 x14 (@deriveV _ _ _ _ _ _ _ _ _ (x13))
    | @HasTypeCQ.C_ResumeL _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_ResumeL P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 x14 (@deriveV _ _ _ _ _ _ _ _ _ (x13))
    | @HasTypeCQ.C_ResumeNorm _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_ResumeNorm P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 x14 (@deriveV _ _ _ _ _ _ _ _ _ (x13))
    | @HasTypeCQ.C_ResumeLNorm _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact @case_C_ResumeLNorm P B _ _ _ _ _ _ _ _ _ _ _ _ _ x13 x14 x15 x16 (@deriveV _ _ _ _ _ _ _ _ _ (x15))
    | @HasTypeCQ.C_Normal _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact @case_C_Normal P B _ _ _ _ _ _ _ _ _ _ x10 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x10))
    | @HasTypeCQ.C_Meth _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 =>
      exact @case_C_Meth P B _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ x19 x20 x21 x22 x23 x24 x25 x26 x27 x28 (@deriveV _ _ _ _ _ _ _ _ _ (x19)) (@deriveVs _ _ _ _ _ _ _ _ _ (x27))
    | @HasTypeCQ.C_External _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 =>
      exact @case_C_External P B _ _ _ _ _ _ _ _ _ _ _ _ _ x13 x14 x15 x16 (@deriveArgs _ _ _ _ _ _ _ _ _ _ _ (x16))
    | @HasTypeCQ.C_IssuePathBases _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_IssuePathBases P B _ _ _ _ _ _ _ x7 x8 x9 x10 x11 x12 x13 x14
    | @HasTypeCQ.C_CheckAt _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_C_CheckAt P B _ _ _ _ _ _ _ _ _ _ _ _ _ _ x14 (@deriveAt _ _ _ _ _ _ _ _ _ _ _ _ _ _ (x14))
    | @HasTypeCQ.C_Sub _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 =>
      exact @case_C_Sub P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 x14 x15 x16 x17 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x12))
    | @HasTypeCQ.C_Eff _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact @case_C_Eff P B _ _ _ _ _ _ _ _ _ _ _ x11 x12 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x11))
  termination_by structural h

  theorem deriveArgs (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : List Val) (z6 : Tel) (z7 : Ty) (z8 : Eff) (h : HasTypeTelArgsQ P B z0 z1 z2 z3 z4 z5 z6 z7 z8) :
ArgsGoal P B z0 z1 z2 z3 z4 z5 z6 z7 z8 := by
    match h with
    | @HasTypeTelArgsQ.done _ _ x0 x1 x2 x3 x4 x5 x6 x7 =>
      exact @case_Args_done P B _ _ _ _ _ _ _ x7
    | @HasTypeTelArgsQ.param _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_Args_param P B _ _ _ _ _ _ _ _ _ _ _ _ x12 x13 x14 (@deriveV _ _ _ _ _ _ _ _ _ (x13)) (@deriveArgs _ _ _ _ _ _ _ _ _ _ _ (x14))
  termination_by structural h

  theorem deriveBody (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : Tel) (z6 : Comp) (h : TelBodyTy P B z0 z1 z2 z3 z4 z5 z6) :
BodyGoal P B z0 z1 z2 z3 z4 z5 z6 := by
    match h with
    | @TelBodyTy.done _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 =>
      exact @case_Body_done P B _ _ _ _ _ _ _ _ x8 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x8))
    | @TelBodyTy.param _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact @case_Body_param P B _ _ _ _ _ _ _ _ _ x9 (@deriveBody _ _ _ _ _ _ _ _ _ (x9))
  termination_by structural h

  theorem deriveCapture (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Option Ty) (z2 : Ctx) (z3 : List Pred) (z4 : Capture) (h : CaptureOk P B z0 z1 z2 z3 z4) :
CaptureOk P B z0 z1 z2 z3 z4 := by
    match h with
    | @CaptureOk.mk _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact @case_Capture_mk P B _ _ _ _ _ x5 x6 x7 x8 x9 x10 x11 x12 (fun u0 u1 u2 => (@deriveImage _ _ _ _ _ _ _ _ _ _ _ (x11 u0 u1 u2)))
  termination_by structural h

  theorem deriveClosure (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Closure) (z2 : Tel) (h : DependentClosureTy P B z0 z1 z2) :
DependentClosureTy P B z0 z1 z2 := by
    match h with
    | @DependentClosureTy.mk _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact @case_Closure_mk P B _ _ _ _ _ _ x6 x7 x8 x9 (@deriveCapture _ _ _ _ _ _ _ (x6)) (@deriveBody _ _ _ _ _ _ _ _ _ (x7))
  termination_by structural h

  theorem deriveWitness (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.OpaqueName) (z2 : Benitoite.Scope.Domain.Kind) (z3 : RangeExpr) (z4 : Option PathEnv) (z5 : Benitoite.Scope.Domain.Target) (z6 : Option Val) (h : CheckedWitness P B z0 z1 z2 z3 z4 z5 z6) :
CheckedWitness P B z0 z1 z2 z3 z4 z5 z6 := by
    match h with
    | @CheckedWitness.plain _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact @case_Witness_plain P B _ _ _ _ _ _ x6 x7 x8 x9
    | @CheckedWitness.request _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 =>
      exact @case_Witness_request P B _ _ _ _ _ _ _ x7 x8 x9 x10 x11 x12 (@deriveV _ _ _ _ _ _ _ _ _ (x9))
  termination_by structural h

  theorem deriveAt (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : Benitoite.Scope.Domain.Kind) (z6 : Benitoite.Release.OpaqueName) (z7 : ResultShape) (z8 : Option Val) (z9 : Val) (z10 : Val) (z11 : RangeIx) (h : AtCallAdmissible P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 z11) :
AtGoal P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 z11 := by
    match h with
    | @AtCallAdmissible.mk _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 =>
      exact @case_At_mk P B _ _ _ _ _ _ _ _ _ _ _ _ _ x13 x14 x15 x16 x17 x18 x19 x20 (fun u0 u1 => (@deriveV _ _ _ _ _ _ _ _ _ (x15 u0 u1))) (@deriveV _ _ _ _ _ _ _ _ _ (x16)) (@deriveV _ _ _ _ _ _ _ _ _ (x18))
    | @AtCallAdmissible.text _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 =>
      exact @case_At_text P B _ _ _ _ _ _ _ _ _ _ _ _ _ x13 x14 x15 x16 x17 x18 x19 x20 (fun u0 u1 => (@deriveV _ _ _ _ _ _ _ _ _ (x15 u0 u1))) (@deriveV _ _ _ _ _ _ _ _ _ (x16)) (@deriveV _ _ _ _ _ _ _ _ _ (x18))
  termination_by structural h

  theorem deriveArms (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : Option Ty) (z6 : Option Benitoite.Release.Refinement.Term) (z7 : List Arm) (z8 : Ty) (z9 : Ty) (z10 : Eff) (z11 : optParam LocalCtx []) (h : HasTypeArmsQ P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 z11) :
ArmsGoal P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 z11 := by
    match h with
    | @HasTypeArmsQ.nil _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 =>
      exact @case_Arms_nil P B _ _ _ _ _ _ _ _ _ _ _ x11
    | @HasTypeArmsQ.plain _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 =>
      exact @case_Arms_plain P B _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ x16 x17 x18 x19 x20 x21 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x20)) (@deriveArms _ _ _ _ _ _ _ _ _ _ _ _ _ _ (x21))
    | @HasTypeArmsQ.guarded _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 x23 x24 x25 =>
      exact @case_Arms_guarded P B _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ x18 x19 x20 x21 x22 x23 x24 x25 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x23)) (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x24)) (@deriveArms _ _ _ _ _ _ _ _ _ _ _ _ _ _ (x25))
  termination_by structural h

  theorem deriveClauses (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : Option Ty) (z6 : Eff) (z7 : List Clause) (z8 : Ty) (z9 : Eff) (z10 : optParam LocalCtx []) (h : HasTypeClausesQ P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 z10) :
ClausesGoal P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 := by
    match h with
    | @HasTypeClausesQ.nil _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 =>
      exact @case_Clauses_nil P B _ _ _ _ _ _ _ _ _ _
    | @HasTypeClausesQ.cons _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 x22 =>
      exact @case_Clauses_cons P B _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ x16 x17 x18 x19 x20 x21 x22 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x21)) (@deriveClauses _ _ _ _ _ _ _ _ _ _ _ _ _ (x22))
  termination_by structural h

  theorem deriveFailure (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : Ty) (z6 : Option Ty) (z7 : List Clause) (z8 : Ty) (z9 : Eff) (z10 : optParam LocalCtx []) (h : HasFailureClause P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 z10) :
FailureGoal P B z0 z1 z2 z3 z4 z5 z6 z7 z8 z9 z10 := by
    match h with
    | @HasFailureClause.one _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 =>
      exact @case_Failure_one P B _ _ _ _ _ _ _ _ _ _ _ x11 x12 x13 x14 (@deriveC _ _ _ _ _ _ _ _ _ _ _ _ (x14))
  termination_by structural h

  theorem deriveImage (P : Program) (B : Builtins) (z0 : StoreTy) (z1 : Benitoite.Release.NoFailCtx) (z2 : TypeCtx) (z3 : Ctx) (z4 : List Pred) (z5 : Option Ty) (z6 : Nat → Val) (z7 : Nat) (z8 : Ty) (h : ImageOk P B z0 z1 z2 z3 z4 z5 z6 z7 z8) :
True := by
    match h with
    | @ImageOk.ordinary _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact @case_Image_ordinary P B x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 (@deriveV _ _ _ _ _ _ _ _ _ (x10))
    | @ImageOk.hidden _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 =>
      exact @case_Image_hidden x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10
    | @ImageOk.contLoc _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 x16 x17 x18 x19 x20 x21 =>
      exact @case_Image_contLoc x0 x1 x2 x3 x4 x5 x6 x7 x8 _ _ _ _ _ _ _ x16 x17 x18 x19 x20 x21
    | @ImageOk.contVar _ _ x0 x1 x2 x3 x4 x5 x6 x7 x8 x9 x10 x11 x12 x13 x14 x15 =>
      exact @case_Image_contVar x0 x1 x2 x3 x4 x5 x6 x7 x8 _ _ _ _ x13 x14 x15
  termination_by structural h

end


end Benitoite.Release.Refinement.S02Internal
