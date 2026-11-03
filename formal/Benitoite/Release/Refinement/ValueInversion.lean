import Benitoite.Release.Refinement.ValueFacts
import Benitoite.Release.Refinement.TypedMeaningExamples

/-! # 値の芯と値に固有の篩の事実の逆転 -/
namespace Benitoite.Release.Refinement

private theorem core_le {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    Ty.LeQ P Γ Φ a.norm.core b.norm.core := by
  match h with
  | .refl => exact .refl
  | .convert he => exact .convert (congrArg (fun a : Ty => a.core.norm) he)
  | .trans h g => exact .trans (core_le h) (core_le g)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using (Ty.LeQ.refl (P := P) (Γ := Γ) (Φ := Φ))
  | .refine h .. => simpa only [Ty.refined_norm_core] using core_le h
  | h@(.fn_effect _) | h@(.list _) | h@(.lazy _) | h@(.map_value _ _) | h@(.dependentFn _) |
      h@(.scoped _) | h@(.scoped_forget) | h@(.data _) =>
    simpa only [Ty.norm, Ty.core, Ty.core_foldFn] using h.norm

/-- 変数の元の型との関係は芯までとし、最外の篩はfactsから別に読む。 -/
theorem HasTypeVQ.inv_var {P B Ψ Q C Γ Φ v T i}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .var i) :
    ∃ a b, Γ[i]? = some (some a) ∧ a.Ordinary ∧
      T.norm.core = b ∧ Ty.LeQ P Γ Φ a.norm.core b := by
  match h with
  | .V_Var hi ho => cases hv; exact ⟨_,_,hi,ho,rfl,.refl⟩
  | .V_Normal h =>
    obtain ⟨a,b,hi,ho,ht,le⟩ := h.inv_var hv
    exact ⟨a,b,hi,ho,by simpa only [Ty.norm_idem] using ht,le⟩
  | .V_Sub h hl .. =>
    obtain ⟨a,b,hi,ho,ht,le⟩ := h.inv_var hv
    refine ⟨a,T.norm.core,hi,ho,rfl,.trans le ?_⟩
    rw [←ht]
    exact core_le hl
  | .V_Refine h .. =>
    obtain ⟨a,b,hi,ho,ht,le⟩ := h.inv_var hv
    exact ⟨a,b,hi,ho,by simpa only [Ty.refined_norm_core] using ht,le⟩
  | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
      .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. |
      .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
      .V_Super .. | .V_List .. => cases hv

theorem HasTypeVQ.inv_fnRef {P B Ψ Q C Γ Φ T f ts es v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .fnRef f ts es) :
    ∃ d u,
      (P.defs f = some d) ∧
      (NamesWF d.names d.params) ∧
      (Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
          (Qsig d.params d.ret d.eff) Q ts es d.eff) ∧
      (SignatureInstance P C Γ d.tel (TypeCtx.kinds d.tparams) ts es) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.tel ts es) u := by
  match h with
  | .V_Fun h0 h1 h2 h3 => cases hv; exact ⟨_, _, h0, h1, h2, h3, rfl, .refl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨d, u, h0, h1, h2, h3, hu, rel⟩ := h.inv_fnRef hv
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨d, w, h0, h1, h2, h3, hw, rel.trans step⟩
  | .V_Sub h hl .. =>
    obtain ⟨d, u, h0, h1, h2, h3, hu, rel⟩ := h.inv_fnRef hv
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨d, w, h0, h1, h2, h3, hw, rel.trans step⟩
  | .V_Refine h .. =>
    obtain ⟨d, u, h0, h1, h2, h3, hu, rel⟩ := h.inv_fnRef hv
    exact ⟨d, u, h0, h1, h2, h3, hu, rel⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. |
      .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. |
      .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
      .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

theorem HasTypeVQ.inv_prim {P B Ψ Q C Γ Φ T b ts es rs v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .prim b ts es rs) :
    ∃ s u,
      (B.sig b = some s) ∧
      (B.RangeAdmissible b s rs) ∧
      (NamesWF s.names s.params) ∧
      (PrimitiveAdmissible C Γ.length s Q ts es) ∧
      (SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel (Tel.instR rs s.tel) ts es) u := by
  match h with
  | .V_Prim h0 h1 h2 h3 h4 => cases hv; exact ⟨_, _, h0, h1, h2, h3, h4, rfl, .refl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨d, u, h0, h1, h2, h3, h4, hu, rel⟩ := h.inv_prim hv
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨d, w, h0, h1, h2, h3, h4, hw, rel.trans step⟩
  | .V_Sub h hl .. =>
    obtain ⟨d, u, h0, h1, h2, h3, h4, hu, rel⟩ := h.inv_prim hv
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨d, w, h0, h1, h2, h3, h4, hw, rel.trans step⟩
  | .V_Refine h .. =>
    obtain ⟨d, u, h0, h1, h2, h3, h4, hu, rel⟩ := h.inv_prim hv
    exact ⟨d, u, h0, h1, h2, h3, h4, hu, rel⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Op .. | .V_ExternalRef .. |
      .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. |
      .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
      .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

/-- 正規化後の関数参照からも、元の宣言の適格性を取り出す。 -/
example {P B Ψ Q C Γ Φ T f ts es}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es) T) :
    ∃ d, P.defs f = some d ∧
      Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
        (Qsig d.params d.ret d.eff) Q ts es d.eff := by
  obtain ⟨d,_,hd,_,ad,_,_,_⟩ := h.V_Normal.inv_fnRef rfl
  exact ⟨d,hd,ad⟩

/-- 正規化後のprimitiveでも、同じ範囲実引数の適格性を保つ。 -/
example {P B Ψ Q C Γ Φ T b ts es rs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts es rs) T) :
    ∃ s, B.sig b = some s ∧ B.RangeAdmissible b s rs := by
  obtain ⟨s,_,hs,range,_,_,_,_,_⟩ := h.V_Normal.inv_prim rfl
  exact ⟨s,hs,range⟩

theorem HasTypeVQ.inv_op {P B Ψ Q C Γ Φ T o ts v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .op o ts) :
    ∃ od u,
      (P.ops o = some od) ∧
      (NamesWF od.names od.params) ∧
      (SatAll B C ts od.tparams) ∧
      (SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts []) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel od.tel ts []) u := by
  match h with
  | .V_Op h0 h1 h2 h3 => cases hv; exact ⟨_, _, h0, h1, h2, h3, rfl, .refl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨x0, u, h0, h1, h2, h3, hu, rel⟩ := h.inv_op hv
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨x0, w, h0, h1, h2, h3, hw, rel.trans step⟩
  | .V_Sub h hl .. =>
    obtain ⟨x0, u, h0, h1, h2, h3, hu, rel⟩ := h.inv_op hv
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨x0, w, h0, h1, h2, h3, hw, rel.trans step⟩
  | .V_Refine h .. =>
    obtain ⟨x0, u, h0, h1, h2, h3, hu, rel⟩ := h.inv_op hv
    exact ⟨x0, u, h0, h1, h2, h3, hu, rel⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_ExternalRef .. |
      .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. |
      .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
      .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

theorem HasTypeVQ.inv_lam {P B Ψ Q C Γ Φ T ns ps body v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .lam ns ps body) :
    ∃ r ε u,
      (NamesWF ns ps) ∧
      (Ty.WF 0 C.length Γ.length (.fn ns ps r ε)) ∧
      (Ty.Sorted Γ (.fn ns ps r ε)) ∧
      (HasTypeCQ P B (hideBuilders Ψ) Q C (bindParams (hideConts Γ) ps) (liftMany ps.length Φ)
          (some (r.shiftV ps.length 0)) body (r.shiftV ps.length 0) (Eff.shiftV ps.length 0 ε) []) ∧
      (Ty.Declared P C Γ (.fn ns ps r ε)) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel ns ps r ε) u := by
  match h with
  | .V_Lam h0 h1 h2 h3 h4 => cases hv; exact ⟨_, _, _, h0, h1, h2, h3, h4, rfl, .refl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨x0, x1, u, h0, h1, h2, h3, h4, hu, rel⟩ := h.inv_lam hv
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨x0, x1, w, h0, h1, h2, h3, h4, hw, rel.trans step⟩
  | .V_Sub h hl .. =>
    obtain ⟨x0, x1, u, h0, h1, h2, h3, h4, hu, rel⟩ := h.inv_lam hv
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨x0, x1, w, h0, h1, h2, h3, h4, hw, rel.trans step⟩
  | .V_Refine h .. =>
    obtain ⟨x0, x1, u, h0, h1, h2, h3, h4, hu, rel⟩ := h.inv_lam hv
    exact ⟨x0, x1, u, h0, h1, h2, h3, h4, hu, rel⟩
  | .V_Var .. | .V_Const .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. |
      .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. |
      .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
      .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

theorem HasTypeVQ.inv_dependentLam {P B Ψ Q C Γ Φ T t body v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .dependentLam t body) :
    ∃ u,
      (Ty.Annotation P C Γ (.dependentFn t)) ∧
      (TelBodyTy P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ t u := by
  match h with
  | .V_DependentLam h0 h1 => cases hv; exact ⟨_, h0, h1, rfl, .refl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨u, h0, h1, hu, rel⟩ := h.inv_dependentLam hv
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨w, h0, h1, hw, rel.trans step⟩
  | .V_Sub h hl .. =>
    obtain ⟨u, h0, h1, hu, rel⟩ := h.inv_dependentLam hv
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨w, h0, h1, hw, rel.trans step⟩
  | .V_Refine h .. =>
    obtain ⟨u, h0, h1, hu, rel⟩ := h.inv_dependentLam hv
    exact ⟨u, h0, h1, hu, rel⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. |
      .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. |
      .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
      .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

theorem HasTypeVQ.inv_raise {P B Ψ Q C Γ Φ T t e v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .raise t e) :
    ∃ u,
      (Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e))) ∧
      (Ordinary t) ∧
      (Ordinary e) ∧
      (t.HasKind P (TypeCtx.kinds C) .value) ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (Ty.toTel ["error"] [e] t (Eff.singleFail e)) u := by
  match h with
  | .V_Raise h0 h1 h2 h3 => cases hv; exact ⟨_, h0, h1, h2, h3, rfl, .refl⟩
  | .V_Normal (a := T0) h =>
    obtain ⟨u, h0, h1, h2, h3, hu, rel⟩ := h.inv_raise hv
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨w, h0, h1, h2, h3, hw, rel.trans step⟩
  | .V_Sub h hl .. =>
    obtain ⟨u, h0, h1, h2, h3, hu, rel⟩ := h.inv_raise hv
    obtain ⟨w, hw, step⟩ := hl.fnCore hu
    exact ⟨w, h0, h1, h2, h3, hw, rel.trans step⟩
  | .V_Refine h .. =>
    obtain ⟨u, h0, h1, h2, h3, hu, rel⟩ := h.inv_raise hv
    exact ⟨u, h0, h1, h2, h3, hu, rel⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
      .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
      .V_Map .. | .V_Set .. | .V_Dict .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

/-- lambdaの名前と注釈の形成を、その本体の契約から射影する。 -/
theorem HasTypeVQ.inv_lam_wf {P B Ψ Q C Γ Φ v T ns ps body}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .lam ns ps body) :
    ∃ r e, NamesWF ns ps ∧ Ty.WF 0 C.length Γ.length (.fn ns ps r e) ∧
      Ty.Sorted Γ (.fn ns ps r e) ∧ Ty.Declared P C Γ (.fn ns ps r e) := by
  obtain ⟨r,e,_,hn,hw,hs,_,hd,_,_⟩ := h.inv_lam hv
  exact ⟨r,e,hn,hw,hs,hd⟩

/-- 到達型を正規化しても、opの元の型引数の制約は保持する。 -/
example {P B Ψ Q C Γ Φ T o ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) T) :
    ∃ d, P.ops o = some d ∧ SatAll B C ts d.tparams := by
  obtain ⟨d,_,hd,_,sat,_,_,_⟩ := h.V_Normal.inv_op rfl
  exact ⟨d,hd,sat⟩

/-- lambdaの名前と形成を、同じ本体を保持した正規化後の導出から読む。 -/
example {P B Ψ Q C Γ Φ T ns ps body}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.lam ns ps body) T) :
    ∃ r e, NamesWF ns ps ∧ Ty.Annotation P C Γ (.fn ns ps r e) := by
  obtain ⟨r,e,hn,hw,hs,hd⟩ := h.V_Normal.inv_lam_wf rfl
  exact ⟨r,e,hn,hw,hs,hd⟩

/-- 依存lambdaの本体は、元の列と同じ隠蔽文脈で検査されている。 -/
example {P B Ψ Q C Γ Φ T t body}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.dependentLam t body) T) :
    TelBodyTy P B (hideBuilders Ψ) Q C (hideConts Γ) Φ t body := by
  obtain ⟨_,_,hb,_,_⟩ := h.V_Normal.inv_dependentLam rfl
  exact hb

/-- raiseの注釈は同じ誤り型のFailとerrorという引数名を保持する。 -/
example {P B Ψ Q C Γ Φ T t e}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.raise t e) T) :
    Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) := by
  obtain ⟨_,ha,_,_,_,_,_⟩ := h.V_Normal.inv_raise rfl
  exact ha

/-- 辞書はクラスと型引数の正規形を保持する。 -/
theorem Ty.LeQ.dict_core {P Γ Φ a b cl t} (h : Ty.LeQ P Γ Φ a b)
    (ha : a.norm.core = .dict cl t) : b.norm.core = .dict cl t := by
  match h with
  | .refl => exact ha
  | .convert he => rw [←he]; exact ha
  | .trans h g => exact g.dict_core (h.dict_core ha)
  | .forget | .introduce .. => simpa only [Ty.refined_norm_core] using ha
  | .refine h .. =>
    simp only [Ty.refined_norm_core] at ha ⊢
    exact h.dict_core ha
  | .fn_effect .. | .dependentFn .. | .list .. | .lazy .. | .map_value .. |
      .scoped .. | .scoped_forget | .data .. =>
    simp only [Ty.norm,Ty.core,Ty.core_foldFn] at ha
    first | cases ha | (unfold Ty.foldFn at ha; split at ha <;> cases ha)

theorem HasTypeVQ.inv_dict {P B Ψ Q C Γ Φ T i ts vs v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .dict i ts vs) :
    ∃ id,
      (P.impls i = some id) ∧
      (SatAll B C ts id.tparams) ∧
      (TypeAnnotations P C Γ ts) ∧
      (TypeArgsKinded P C ts (List.replicate id.tparams.length .value)) ∧
      ((∀ a ∈ id.dictTys, a.WF 0 id.tparams.length 0)) ∧
      (id.target.WF 0 id.tparams.length 0) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ vs (id.dictTys.map (Ty.subst ts []))) ∧
      (Ty.Annotation P C Γ (.dict id.cls (id.target.subst ts []))) ∧
      T.norm.core = (Ty.dict id.cls (id.target.subst ts [])).norm.core  := by
  match h with
  | .V_Dict h0 h1 h2 h3 h4 h5 h6 h7 => cases hv; exact ⟨_, h0, h1, h2, h3, h4, h5, h6, h7, rfl⟩
  | .V_Normal h .. =>
    obtain ⟨x0, h0, h1, h2, h3, h4, h5, h6, h7, ht⟩ := h.inv_dict hv
    exact ⟨x0, h0, h1, h2, h3, h4, h5, h6, h7, by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht⟩
  | .V_Refine h .. =>
    obtain ⟨x0, h0, h1, h2, h3, h4, h5, h6, h7, ht⟩ := h.inv_dict hv
    exact ⟨x0, h0, h1, h2, h3, h4, h5, h6, h7, by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht⟩
  | .V_Sub h hl .. =>
    obtain ⟨x0, h0, h1, h2, h3, h4, h5, h6, h7, ht⟩ := h.inv_dict hv
    exact ⟨x0, h0, h1, h2, h3, h4, h5, h6, h7, hl.dict_core ht⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
      .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
      .V_Map .. | .V_Set .. | .V_Raise .. | .V_LocRef .. |
      .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. => cases hv

theorem HasTypeVQ.inv_super {P B Ψ Q C Γ Φ T inner super v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .super inner super) :
    ∃ cl a cd,
      (HasTypeVQ P B Ψ Q C Γ Φ inner (.dict cl a)) ∧
      (P.classes cl = some cd) ∧
      (super ∈ cd.supers) ∧
      (Ty.Declared P C Γ a) ∧
      T.norm.core = (Ty.dict super a).norm.core  := by
  match h with
  | .V_Super h0 h1 h2 h3 => cases hv; exact ⟨_, _, _, h0, h1, h2, h3, rfl⟩
  | .V_Normal h .. =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, ht⟩ := h.inv_super hv
    exact ⟨x0, x1, x2, h0, h1, h2, h3, by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht⟩
  | .V_Refine h .. =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, ht⟩ := h.inv_super hv
    exact ⟨x0, x1, x2, h0, h1, h2, h3, by simpa only [Ty.norm_idem,Ty.refined_norm_core] using ht⟩
  | .V_Sub h hl .. =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, ht⟩ := h.inv_super hv
    exact ⟨x0, x1, x2, h0, h1, h2, h3, hl.dict_core ht⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. |
      .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
      .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
      .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. |
      .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
      .V_List .. => cases hv

/-- 辞書の型を正規化しても、元の実装と同じ辞書引数の導出を得る。 -/
example {P B Ψ Q C Γ Φ T i ts vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.dict i ts vs) T) :
    ∃ d, P.impls i = some d ∧
      HasTypeVsQ P B Ψ Q C Γ Φ vs (d.dictTys.map (Ty.subst ts [])) := by
  obtain ⟨d,hd,_,_,_,_,_,args,_,_⟩ := h.V_Normal.inv_dict rfl
  exact ⟨d,hd,args⟩

/-- 上位クラスへの射影でも、同じ辞書とクラス宣言を保つ。 -/
example {P B Ψ Q C Γ Φ T v super}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.super v super) T) :
    ∃ cl a d, HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl a) ∧
      P.classes cl = some d ∧ super ∈ d.supers := by
  obtain ⟨cl,a,d,hv,hd,hs,_,_⟩ := h.V_Normal.inv_super rfl
  exact ⟨cl,a,d,hv,hd,hs⟩

private theorem list_core {a b : Ty} (h : a.listCore = some b) : a.core = .list b := by
  match a with
  | .refined a p => exact list_core (a := a) h
  | .list a => cases h; rfl
  | .base .. | .opaque .. | .data .. | .fn .. | .tvar .. | .reference .. | .lazy .. |
      .cont .. | .map .. | .set .. | .bytes | .dict .. | .tapp .. | .ctor .. |
      .dependentFn .. | .external .. | .scoped .. | .pathBases | .scopePattern .. => cases h

/-- 要素の部分型関係を芯のListまで返し、列全体の篩と区別する。 -/
theorem HasTypeVQ.inv_list_core {P B Ψ Q C Γ Φ v T vs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .list vs) :
    ∃ a b, HasTypeEachQ P B Ψ Q C Γ Φ vs a ∧ Ty.Annotation P C Γ a ∧
      T.norm.core = .list b ∧ Ty.LeQ P Γ Φ a b := by
  match h with
  | .V_List hs hw hsort hd =>
    cases hv
    exact ⟨_,_,hs,⟨hw,hsort,hd⟩,rfl,.convert (Ty.norm_idem _).symm⟩
  | .V_Normal h =>
    obtain ⟨a,b,hs,ha,ht,le⟩ := h.inv_list_core hv
    exact ⟨a,b,hs,ha,by simpa only [Ty.norm_idem] using ht,le⟩
  | .V_Sub h hl .. =>
    obtain ⟨a,b,hs,ha,ht,le⟩ := h.inv_list_core hv
    have hc : _ := congrArg Ty.listCore ht
    simp only [Ty.listCore_core,Ty.listCore] at hc
    obtain ⟨c,hc,hbc⟩ := hl.norm.listCore hc
    exact ⟨a,c,hs,ha,list_core hc,.trans le hbc⟩
  | .V_Refine h .. =>
    obtain ⟨a,b,hs,ha,ht,le⟩ := h.inv_list_core hv
    exact ⟨a,b,hs,ha,by simpa only [Ty.refined_norm_core] using ht,le⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
      .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
      .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
      .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. |
      .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
      .V_Super .. => cases hv

/-- 篩付き定数でも、芯とその同じ値の事実を同時に読む。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ConstOK B (.integer ⟨5,by decide⟩) ∧
    monthType.norm.core = .base .integer ∧
    ∀ p ∈ monthType.assume, Entails [] (p.open (.integer 5)) := by
  have h := TypedMeaningExamples.month_typed P B Ψ
  exact ⟨(h.inv_const rfl).1,(h.inv_const rfl).2,h.facts rfl⟩

namespace ValueInversionExamples

/-- 値5の篩から、Integer全体が同じ篩に入るとは結論できない。 -/
private theorem whole_type_rejected (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ¬ (∀ {Q C Γ Φ T c}, HasTypeVQ P B Ψ Q C Γ Φ (.const c) T →
        ConstOK B c ∧ Ty.LeQ P Γ Φ (Const.type c) T) := by
  intro h
  have le := (h (TypedMeaningExamples.month_typed P B Ψ)).2
  have z : HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨0,by decide⟩))
      (Const.type (.integer ⟨5,by decide⟩)) := .V_Const trivial
  have mem : Pred.le (.integer 1) (.var 0) ∈ monthType.assume := by
    simp [monthType,monthPredicate,Ty.assume,Ty.core,Ty.carrierFacts,
      Ty.refinementPredicates,Pred.conjuncts]
  have unsound := Entails.sound (z.subtype_facts le rfl _ mem) (fun _ => none) (by simp [Ctx.facts])
  revert unsound
  decide

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ConstOK B (.integer ⟨5,by decide⟩) ∧ monthType.norm.core = .base .integer ∧
    ¬ (∀ {Q C Γ Φ T c}, HasTypeVQ P B Ψ Q C Γ Φ (.const c) T →
        ConstOK B c ∧ Ty.LeQ P Γ Φ (Const.type c) T) :=
  ⟨((TypedMeaningExamples.month_typed P B Ψ).inv_const rfl).1,
    ((TypedMeaningExamples.month_typed P B Ψ).inv_const rfl).2,whole_type_rejected P B Ψ⟩

/-- V_Refineを経た変数でも、芯と同じ変数の事実を別々に返す。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ a b, [some (Ty.base .integer)][0]? = some (some a) ∧ a.Ordinary ∧
      (Ty.refined (.base .integer) .truth).norm.core = b ∧
      Ty.LeQ P [some (.base .integer)] [] a.norm.core b := by
  have raw : HasTypeVQ P B Ψ Qempty [] [some (.base .integer)] [] (.var 0) (.base .integer) :=
    .V_Var rfl (by intro b t e h; cases h)
  have typed := HasTypeVQ.V_Refine (p := Pred.truth) raw rfl rfl trivial trivial
    Entails.truth trivial trivial
  exact typed.inv_var rfl

/-- 観測不能な子を含む非空列でも、要素と列全体の篩を混同しない。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ a b, HasTypeEachQ P B Ψ Qempty [] [] []
      (List.replicate 1 unobservableFunction) a ∧ Ty.Annotation P [] [] a ∧
      (nonemptyType unobservableFunctionType).norm.core = .list b ∧ Ty.LeQ P [] [] a b := by
  obtain ⟨typed,_⟩ := unobservable_length_coverage P B Ψ 1 (by decide)
  exact typed.inv_list_core rfl

end ValueInversionExamples

end Benitoite.Release.Refinement
