import Benitoite.Release.Refinement.HandlerStore

/-! # 操作の宣言に対する引数と依存する結果の逆転 -/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

private theorem toTel_annotation {P ns ps r e}
    (ha : Ty.Annotation P [] [] (.fn ns ps r e)) :
    Ty.Annotation P [] [] (.dependentFn (Ty.toTel ns ps r e)) := by
  induction ns generalizing ps r e with
  | nil =>
    cases ps with
    | cons => have hn := ha.wf.1.1; simp at hn
    | nil => exact ⟨⟨ha.wf.2.2.1,ha.wf.2.2.2⟩,⟨ha.sorted.2.1,ha.sorted.2.2⟩,
        ⟨ha.declared.2.1,ha.declared.2.2⟩⟩
  | cons n ns ih =>
    cases ps with
    | nil => have hn := ha.wf.1.1; simp at hn
    | cons x xs =>
      have hr : Ty.Annotation P [] [] (.fn ns xs r e) :=
        ⟨⟨⟨by simpa [NamesWF] using Nat.succ.inj ha.wf.1.1,ha.wf.1.2.of_cons⟩,
          ha.wf.2.1.2,ha.wf.2.2⟩,⟨ha.sorted.1.2,ha.sorted.2⟩,
          ⟨ha.declared.1.2,ha.declared.2⟩⟩
      have ht := (ShiftMap.outerValue ([] : Ctx) (some (x.shiftV 1 0))).annotation (ih hr)
      simp only [Ty.shiftV,Tel.shiftV_toTel] at ht
      exact ⟨⟨ha.wf.2.1.1,by simpa [Ty.WF,Ctx.extend] using ht.wf⟩,
        ⟨ha.sorted.1.1,ht.sorted⟩,⟨ha.declared.1.1,ht.declared⟩⟩

private theorem bind_shift_ty (a : Ty) (v : Val) :
    (a.shiftV 1 0).bind (Tel.argumentsEnv v) = a.norm := by
  rw [argumentsEnv_eq]
  unfold Ty.bind SubstEnv.valuesOnly
  rw [←Ty.rawSubstV_eq_rawBind,Ty.substV_shift_cancel a (by intro i; rfl)]

private theorem bind_shift_eff (e : Eff) (v : Val) :
    Eff.bind (Tel.argumentsEnv v) (e.shiftV 1 0) = e.norm := by
  rw [argumentsEnv_eq]
  unfold Eff.bind SubstEnv.valuesOnly
  rw [←Eff.rawSubstV_eq_rawBind,Eff.substV_shift_cancel e (by intro i; rfl)]

private theorem vs_normal {P B Ψ Q C Γ Φ vs ps}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs ps) :
    HasTypeVsQ P B Ψ Q C Γ Φ vs (Ty.normTys ps) := by
  match h with
  | .nil => exact .nil
  | .cons hv hs => exact .cons hv.V_Normal (vs_normal hs)

private theorem vs_toTel {P B Ψ vs ns ps r e}
    (ha : Ty.Annotation P [] [] (.fn ns ps r e))
    (hs : HasTypeVsQ P B Ψ Qempty [] [] [] vs ps) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (Ty.toTel ns (Ty.normTys ps) r.norm (Eff.norm e)) r.norm (Eff.norm e) := by
  induction ns generalizing ps vs r e with
  | nil =>
    cases ps with
    | cons => have hn := ha.wf.1.1; simp at hn
    | nil => cases hs; exact .done (toTel_annotation ha.norm)
  | cons n ns ih =>
    cases ps with
    | nil => have hn := ha.wf.1.1; simp at hn
    | cons x ps =>
      cases hs with
      | cons hv hs =>
        have hr : Ty.Annotation P [] [] (.fn ns ps r e) :=
          ⟨⟨⟨by simpa [NamesWF] using Nat.succ.inj ha.wf.1.1,ha.wf.1.2.of_cons⟩,
            ha.wf.2.1.2,ha.wf.2.2⟩,⟨ha.sorted.1.2,ha.sorted.2⟩,
            ⟨ha.declared.1.2,ha.declared.2⟩⟩
        apply HasTypeTelArgsQ.param (⟨ha.wf.2.1.1,ha.sorted.1.1,ha.declared.1.1⟩ : Ty.Annotation P [] [] x).norm hv.V_Normal
        have hh := ih hr.norm (vs_normal hs)
        simpa only [Ty.toTel,Tel.bind_toTel,bind_shift_ty,bind_shift_eff,
          shiftVTys_eq_map,List.map_map,Function.comp_def,Ty.normTys_eq_map,
          Ty.norm_idem,Eff.norm_idem] using hh

private theorem op_annotation {P B Ψ Q C Γ Φ v T o ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .op o ts) :
    Ty.Annotation P C Γ T := by
  match h with
  | .V_Op _ _ _ hi => exact hi.result
  | .V_Normal hh => exact (op_annotation hh hv).norm
  | .V_Sub _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .V_Refine hh hi ht hs hw he hd hp =>
    have ha := op_annotation hh hv
    exact ⟨⟨ha.wf,hw,by simpa [Ty.NotContCore] using hi.ordinary⟩,⟨ha.sorted,hs⟩,⟨hd,hp⟩⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

private theorem op_inv {P B Ψ Q C Γ Φ v T o ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .op o ts) :
    ∃ od u, P.ops o = some od ∧
      SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts [] ∧
      T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel od.tel ts []) u := by
  match h with
  | .V_Op hs hn ha hi => cases hv; exact ⟨_,_,hs,hi,rfl,.refl⟩
  | .V_Normal (a := T0) hh =>
    obtain ⟨s,u,hs,hi,hu,ht⟩ := op_inv hh hv
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w,hw,ht'⟩ := hl.fnCore hu
    exact ⟨s,w,hs,hi,hw,ht.trans ht'⟩
  | .V_Sub hh hl _ _ _ =>
    obtain ⟨s,u,hs,hi,hu,ht⟩ := op_inv hh hv
    obtain ⟨w,hw,ht'⟩ := hl.fnCore hu
    exact ⟨s,w,hs,hi,hw,ht.trans ht'⟩
  | .V_Refine hh .. =>
    obtain ⟨s,u,hs,hi,hu,ht⟩ := op_inv hh hv
    exact ⟨s,u,hs,hi,hu,ht⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

/-- 実際の操作値から宣言とその具体化を取り出す。 -/
theorem HasTypeVQ.op_signature {P B Ψ Q C Γ Φ o ts a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) a) :
    ∃ od, P.ops o = some od ∧
      SignatureInstance P C Γ od.tel (List.replicate od.tparams.length .value) ts [] := by
  obtain ⟨od,_,hd,hi,_,_⟩ := op_inv h rfl
  exact ⟨od,hd,hi⟩

/-- 操作の型引数の形成と非継続は、V_OpとSignatureInstanceから得る。 -/
theorem HasTypeVQ.op_typeScope {P B Ψ Q C Γ Φ o ts a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.op o ts) a) :
    ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t := by
  obtain ⟨_, _, _, hi, _, _⟩ := op_inv h rfl
  exact hi.typeScope

private theorem operation_call_aux {P B Ψ Q C Γ Φ R code a e L o ws od ts}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .app (.op o ts) ws) (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
      (instantiatedTel od.tel ts []) r f ∧ Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f := by
  match h with
  | .C_DependentApp hv ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨sg,u,hsg,hi,hu,ht⟩ := op_inv hv rfl
    cases hd.symm.trans hsg
    cases Option.some.inj hu
    exact ha.pullback hi.result ht
  | .C_App hv ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨sg,u,hsg,hi,hu,ht⟩ := op_inv hv rfl
    cases hd.symm.trans hsg
    cases Option.some.inj hu
    have hargs := vs_toTel (op_annotation hv rfl) ha
    rw [←Tel.norm_toTel] at hargs
    obtain ⟨r,f,ha',hle,hcov⟩ := hargs.pullback hi.result
      (.tail ht (TelLe.of_norm_eq (Tel.norm_idem _).symm))
    exact ⟨r,f,ha',.trans hle (.convert (Ty.norm_idem _)),Eff.covers_norm_left.mp hcov⟩
  | .C_Sub hh hl he _ _ _ =>
    obtain ⟨r,f,ha,hle,hcov⟩ := operation_call_aux hh hQ hC hΓ hΦ hc hd
    subst Q C Γ Φ
    exact ⟨r,f,ha,.trans hle hl,he.trans hcov⟩
  | .C_Eff hh he =>
    obtain ⟨r,f,ha,hle,hcov⟩ := operation_call_aux hh hQ hC hΓ hΦ hc hd
    subst Q C Γ Φ
    exact ⟨r,f,ha,hle,he.trans hcov⟩
  | .C_Normal hh =>
    obtain ⟨r,f,ha,hle,hcov⟩ := operation_call_aux hh hQ hC hΓ hΦ hc hd
    exact ⟨r,f,ha,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

theorem HasTypeCQ.operation_call {P B Ψ R o v a e L od ts}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.op o ts) [v]) a e L)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f :=
  operation_call_aux h rfl rfl rfl rfl rfl hd

/-- 呼出しの引数列を元の操作の依存列へ戻す。 -/
theorem HasTypeCQ.operation_call_all {P B Ψ R o ws a e L od ts}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.op o ts) ws) a e L)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f :=
  operation_call_aux h rfl rfl rfl rfl rfl hd

private theorem operation_signature_aux {P B Ψ Q C Γ Φ R code a e L o v od ts}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hc : code = .app (.op o ts) [v]) (hd : P.ops o = some od) :
    Ty.Annotation P C Γ (.dependentFn (instantiatedTel od.tel ts [])) := by
  match h with
  | .C_App hv _ | .C_DependentApp hv _ =>
    cases hc
    obtain ⟨sg,u,hsg,hi,_,_⟩ := op_inv hv rfl
    cases hd.symm.trans hsg
    exact hi.result
  | .C_Sub hh .. | .C_Normal hh | .C_Eff hh _ => exact operation_signature_aux hh hc hd
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

private theorem operation_annotation {P B Ψ Q C Γ Φ R code a e L o v ts}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hc : code = .app (.op o ts) [v]) : Ty.Annotation P C Γ a := by
  match h with
  | .C_App hv _ =>
    cases hc
    have ha := op_annotation hv rfl
    exact ⟨ha.wf.2.2.1,ha.sorted.2.1,ha.declared.2.1⟩
  | .C_DependentApp _ ha => cases hc; exact ha.resultAnnotation
  | .C_Sub _ _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .C_Normal hh => exact (operation_annotation hh hc).norm
  | .C_Eff hh _ => exact operation_annotation hh hc
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

private theorem app_resolve {P B Ψ Q C Γ Φ R code a e L f ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .app f ws) (ρ) :
    code.resolveLocals ρ = code := by
  match h with
  | .C_App hv ha => cases hc; simp only [Comp.resolveLocals,hv.resolve_id ρ,ha.resolve_id ρ]
  | .C_DependentApp hv ha => cases hc; simp only [Comp.resolveLocals,hv.resolve_id ρ,ha.resolve_id ρ]
  | .C_Sub hh .. | .C_Normal hh | .C_Eff hh _ => exact app_resolve hh hc ρ
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

theorem ClosureTy.pure_operation {P B Ψ R a e o v od ts}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e)
    (hd : P.ops o = some od) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (instantiatedTel od.tel ts []) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es0,L,ρ,hq,hcap,hbody,hL,hR,ha,he,hr⟩ := h.open_zero
  have hc : cap = Capture.empty := (Closure.mk.inj hq).1.symm
  subst cap
  have hΓ : Γ = [] := by
    cases hcap with
    | mk _ hn _ _ _ _ _ _ => exact List.length_eq_zero_iff.mp hn.symm
  subst Γ
  have hcode : code0.resolveLocals ρ = .app (.op o ts) [v] := (Closure.mk.inj hq).2.symm
  have htag : (match code0 with | .app .. => true | _ => false) = true := by
    have hh := congrArg (fun code => match code with | .app .. => true | _ => false) hcode
    cases code0 <;> exact hh
  cases code0 <;> try cases htag
  rw [app_resolve hbody rfl ρ] at hcode
  cases hcode
  have hΦ : ∀ p ∈ Φ, Entails [] p := by
    cases hcap with
    | mk _ _ _ _ hfw _ _ hf =>
      intro p hp
      have hh := hf p (List.mem_append_right _ hp)
      rwa [Pred.bind_closed (hfw p hp).1] at hh
  have hb := hbody.weaken_conditions hA hw (Ξ := []) (by simpa [Ctx.facts] using hΦ)
  have han := operation_annotation hb rfl
  obtain ⟨r,f,hargs,hle,hcov⟩ := hb.operation_call hd
  have hae : Capture.empty.closeTy as = as.norm := Ty.subst_values_of_wf_zero han.wf _
  rw [hae] at ha
  subst a
  refine ⟨r,f,hargs,.trans hle (.convert (Ty.norm_idem _).symm),?_⟩
  have hh := hcov.bind (Δ := []) (Ψ := []) (valEnv Capture.empty.env)
  have hf : Eff.bind (valEnv Capture.empty.env) f = f := by
    have hf := hargs.effect_wf
    exact Eff.subst_values_of_wf_zero hf (hargs.normal (Tel.norm_idem _)).2 _
  rw [hf] at hh
  change Eff.Covers [] [] (Capture.empty.closeEff es0) f at hh
  rwa [he] at hh

/-- 呼出しを包む部分型付けの下にも、元の宣言の依存列の注釈が存在する。 -/
theorem ClosureTy.pure_operation_signature {P B Ψ R a e o v od ts}
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e)
    (hd : P.ops o = some od) :
    Ty.Annotation P [] [] (.dependentFn (instantiatedTel od.tel ts [])) := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,hq,hcap,hbody,_,_,_,_,_⟩ := h.open_zero
  have hc : cap = Capture.empty := (Closure.mk.inj hq).1.symm
  subst cap
  have hΓ : Γ = [] := by
    cases hcap with
    | mk _ hn _ _ _ _ _ _ => exact List.length_eq_zero_iff.mp hn.symm
  subst Γ
  have hcode : code0.resolveLocals ρ = .app (.op o ts) [v] := (Closure.mk.inj hq).2.symm
  have htag : (match code0 with | .app .. => true | _ => false) = true := by
    have hh := congrArg (fun code => match code with | .app .. => true | _ => false) hcode
    cases code0 <;> exact hh
  cases code0 <;> try cases htag
  rw [app_resolve hbody rfl ρ] at hcode
  cases hcode
  exact operation_signature_aux hbody rfl hd

private theorem operation_typeScope_aux {P B Ψ Q C Γ Φ R m a e D o ts v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e D) (hm : m = .app (.op o ts) [v]) :
    ∀ t ∈ ts, t.WF 0 C.length Γ.length ∧ Ordinary t := by
  match h with
  | .C_App hv _ | .C_DependentApp hv _ => cases hm; exact hv.op_typeScope
  | .C_Sub h .. | .C_Normal h | .C_Eff h _ => exact operation_typeScope_aux h hm
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

/-- 捕捉の無い操作の呼出しでも、型引数は空列に限定しない。 -/
theorem ClosureTy.pure_operation_typeScope {P B Ψ R a e o v ts}
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.op o ts) [v])) a e) :
    ∀ t ∈ ts, t.WF 0 0 0 ∧ Ordinary t := by
  obtain ⟨cap, Γ, Φ, Rs, code, as, es, L, ρ, hq, hcap, hbody, _⟩ := h.open_zero
  have hc : cap = Capture.empty := (Closure.mk.inj hq).1.symm
  subst cap
  have hΓ : Γ = [] := by
    cases hcap with
    | mk _ hn _ _ _ _ _ _ => exact List.length_eq_zero_iff.mp hn.symm
  subst Γ
  have hcode : code.resolveLocals ρ = .app (.op o ts) [v] := (Closure.mk.inj hq).2.symm
  have htag : (match code with | .app .. => true | _ => false) = true := by
    have hh := congrArg (fun code => match code with | .app .. => true | _ => false) hcode
    cases code <;> exact hh
  cases code <;> try cases htag
  rw [app_resolve hbody rfl ρ] at hcode
  cases hcode
  exact operation_typeScope_aux hbody rfl
private theorem raise_inv {P B Ψ Q C Γ Φ v A T E}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v A) (hv : v = .raise T E) :
    ∃ u, A.fnCore = some u ∧
      TelClosure P Γ Φ (Ty.toTel ["error"] [E] T (Eff.singleFail E)) u := by
  match h with
  | .V_Raise _ _ _ _ => cases hv; exact ⟨_,rfl,.refl⟩
  | .V_Normal (a := A0) hh =>
    obtain ⟨u,hu,ht⟩ := raise_inv hh hv
    have hl : Ty.LeQ P Γ Φ A0 A0.norm := .convert (Ty.norm_idem A0).symm
    obtain ⟨w,hw,ht'⟩ := hl.fnCore hu
    exact ⟨w,hw,ht.trans ht'⟩
  | .V_Sub hh hl _ _ _ =>
    obtain ⟨u,hu,ht⟩ := raise_inv hh hv
    obtain ⟨w,hw,ht'⟩ := hl.fnCore hu
    exact ⟨w,hw,ht.trans ht'⟩
  | .V_Refine hh .. =>
    obtain ⟨u,hu,ht⟩ := raise_inv hh hv
    exact ⟨u,hu,ht⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. |
    .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

private theorem raise_annotation {P B Ψ Q C Γ Φ v A T E}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v A) (hv : v = .raise T E) :
    Ty.Annotation P C Γ A := by
  match h with
  | .V_Raise ha _ _ _ => exact ha
  | .V_Normal hh => exact (raise_annotation hh hv).norm
  | .V_Sub _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .V_Refine hh hi ht hs hw he hd hp =>
    have ha := raise_annotation hh hv
    exact ⟨⟨ha.wf,hw,by simpa [Ty.NotContCore] using hi.ordinary⟩,⟨ha.sorted,hs⟩,⟨hd,hp⟩⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. |
    .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

private theorem raise_source_annotation {P B Ψ Q C Γ Φ v A T E}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v A) (hv : v = .raise T E) :
    Ty.Annotation P C Γ (.fn ["error"] [E] T (Eff.singleFail E)) := by
  match h with
  | .V_Raise ha _ _ _ => cases hv; exact ha
  | .V_Normal hh | .V_Sub hh .. | .V_Refine hh .. => exact raise_source_annotation hh hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. |
    .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

private theorem failure_call_aux {P B Ψ Q C Γ Φ R code a e L T E v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .app (.raise T E) [v]) :
    ∃ r f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v]
      (Ty.toTel ["error"] [E] T (Eff.singleFail E)) r f ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e f := by
  match h with
  | .C_DependentApp hv ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨u,hu,ht⟩ := raise_inv hv rfl
    cases Option.some.inj hu
    exact ha.pullback (toTel_annotation (raise_source_annotation hv rfl)) ht
  | .C_App hv ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨u,hu,ht⟩ := raise_inv hv rfl
    cases Option.some.inj hu
    have hargs := vs_toTel (raise_annotation hv rfl) ha
    rw [←Tel.norm_toTel] at hargs
    obtain ⟨r,f,ha',hle,hcov⟩ := hargs.pullback (toTel_annotation (raise_source_annotation hv rfl))
      (.tail ht (TelLe.of_norm_eq (Tel.norm_idem _).symm))
    exact ⟨r,f,ha',.trans hle (.convert (Ty.norm_idem _)),Eff.covers_norm_left.mp hcov⟩
  | .C_Sub hh hl he _ _ _ =>
    obtain ⟨r,f,ha,hle,hcov⟩ := failure_call_aux hh hQ hC hΓ hΦ hc
    subst Q C Γ Φ
    exact ⟨r,f,ha,.trans hle hl,he.trans hcov⟩
  | .C_Eff hh he =>
    obtain ⟨r,f,ha,hle,hcov⟩ := failure_call_aux hh hQ hC hΓ hΦ hc
    subst Q C Γ Φ
    exact ⟨r,f,ha,hle,he.trans hcov⟩
  | .C_Normal hh =>
    obtain ⟨r,f,ha,hle,hcov⟩ := failure_call_aux hh hQ hC hΓ hΦ hc
    exact ⟨r,f,ha,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

/-- 失敗呼出しの引数と結果を、元の raise の型へ戻す。 -/
theorem HasTypeCQ.failure_call {P B Ψ R T E v a e L}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R (.app (.raise T E) [v]) a e L) :
    HasTypeVQ P B Ψ Qempty [] [] [] v E.norm ∧
      Ty.LeQ P [] [] T.norm a ∧ Eff.Covers [] [] e (Eff.singleFail E) := by
  obtain ⟨r,f,hargs,hle,hcov⟩ := failure_call_aux h rfl rfl rfl rfl rfl
  cases hargs with
  | param ha hv ht =>
    simp only [Ty.toTel,Tel.bind_done,bind_shift_ty,bind_shift_eff] at ht
    cases ht
    exact ⟨hv.V_Normal,hle,Eff.covers_norm_right.mp hcov⟩

end
end Benitoite.Release.Refinement
