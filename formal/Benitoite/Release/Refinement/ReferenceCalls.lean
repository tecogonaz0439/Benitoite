import Benitoite.Release.Refinement.ReferenceStore
import Benitoite.Release.Refinement.ConstraintAssumptions

/-! # 参照の呼出しが使う引数列の逆転 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem narrow_transport {Γ Φ a b} (h : Ty.LeQ Γ Φ b a) :
    Transport (renEnv id) (Γ.extend a) (Φ.map Pred.lift) (Γ.extend b) (Φ.map Pred.lift) := by
  have look : ∀ (i : Nat) (x : Ty), (Γ.extend a)[i]? = some (some x) →
      ∃ y : Ty, (Γ.extend b)[i]? = some (some y) ∧
        (x.Ordinary → y.Ordinary) ∧ (∀ s, x.HasSort s → y.HasSort s) := by
    intro i x hi
    cases i with
    | zero =>
      cases Option.some.inj hi
      exact ⟨b.shiftV 1 0,rfl,fun ho => (Ty.ordinary_shiftV _ _ _).mpr
        (h.notContCore.mpr ((Ty.ordinary_shiftV _ _ _).mp ho)),
        fun s hs => (Ty.hasSort_shiftV _ _ _ _).mpr
          (h.hasSort_source ((Ty.hasSort_shiftV _ _ _ _).mp hs))⟩
    | succ i =>
      rw [Ctx.lookup_extend] at hi ⊢
      exact ⟨x,hi,id,fun _ hs => hs⟩
  refine ⟨?_,?_,(Transport.id Γ Φ).typeImages,?_⟩
  · intro i x s hi hs
    obtain ⟨y,hy,ho,ht⟩ := look i x hi
    exact ⟨.var i,rfl,⟨y,hy,ho hs.ordinary⟩,y,hy,ht s hs⟩
  · intro i x hi ho t ht
    cases ht
    obtain ⟨y,hy,hyO,_⟩ := look i x hi
    exact ⟨y,hy,hyO ho⟩
  · intro p hp
    simp only [renEnv_values,id_eq,predBind_id]
    rcases List.mem_append.mp hp with hp | hp
    · rcases Ctx.mem_facts_extend.mp hp with hp | ⟨q,hq,rfl⟩
      · apply (h.assume p hp).weaken
        intro q hq
        rcases List.mem_append.mp hq with hq | hq
        · exact List.mem_append_left _ (Ctx.mem_facts_extend.mpr (Or.inl hq))
        · obtain ⟨r,hr,rfl⟩ := List.mem_map.mp hq
          rcases List.mem_append.mp hr with hr | hr
          · exact List.mem_append_left _ (Ctx.mem_facts_extend.mpr (Or.inr ⟨r,hr,rfl⟩))
          · exact List.mem_append_right _ (List.mem_map.mpr ⟨r,hr,rfl⟩)
      · exact .hyp (List.mem_append_left _ (Ctx.mem_facts_extend.mpr (Or.inr ⟨q,hq,rfl⟩)))
    · exact .hyp (List.mem_append_right _ hp)

private theorem tel_narrow {Γ Φ a b t u} (h : Ty.LeQ Γ Φ b a)
    (ht : TelClosure (Γ.extend a) (Φ.map Pred.lift) t u) :
    TelClosure (Γ.extend b) (Φ.map Pred.lift) t u := by
  have hh := ht.rawBind (renEnv id) (narrow_transport h)
  simpa only [Tel.rawBind_id] using hh

private theorem param_inv_aux {Γ Φ s u} (h : TelClosure Γ Φ s u) :
    ∀ n a t, s = .param n a t →
      ∃ b v, u = .param n b v ∧ Ty.LeQ Γ Φ b a ∧
        TelClosure (Γ.extend b) (Φ.map Pred.lift) t v := by
  match h with
  | .refl => intro n a t hs; cases hs; exact ⟨a,t,rfl,.refl,.refl⟩
  | .tail hpre hl =>
    intro n a t hs
    obtain ⟨b,v,hv,hba,ht⟩ := param_inv_aux hpre n a t hs
    cases hv
    cases hl with
    | param hcb htail => exact ⟨_,_,rfl,.trans hcb hba,.tail (tel_narrow hcb ht) htail⟩
termination_by structural h

private theorem param_inv {Γ Φ n a t u} (h : TelClosure Γ Φ (.param n a t) u) :
    ∃ b v, u = .param n b v ∧ Ty.LeQ Γ Φ b a ∧
      TelClosure (Γ.extend b) (Φ.map Pred.lift) t v := param_inv_aux h n a t rfl

private theorem done_inv_aux {Γ Φ s u} (h : TelClosure Γ Φ s u) :
    ∀ a e, s = .done a e →
      ∃ b f, u = .done b f ∧ Ty.LeQ Γ Φ a b ∧ Eff.Covers Γ Φ f e := by
  match h with
  | .refl => intro a e hs; cases hs; exact ⟨a,e,rfl,.refl,.refl _ _ _⟩
  | .tail hpre hl =>
    intro a e hs
    obtain ⟨b,f,hf,hab,hcov⟩ := done_inv_aux hpre a e hs
    cases hf
    cases hl with
    | done hbc hg => exact ⟨_,_,rfl,.trans hab hbc,hg.trans hcov⟩
termination_by structural h

private theorem done_inv {Γ Φ a e u} (h : TelClosure Γ Φ (.done a e) u) :
    ∃ b f, u = .done b f ∧ Ty.LeQ Γ Φ a b ∧ Eff.Covers Γ Φ f e := done_inv_aux h a e rfl

theorem HasTypeTelArgsQ.pullback {P B Ψ ws t u a e}
    (ht : Ty.Annotation P [] [] (.dependentFn t))
    (hr : TelClosure [] [] t u)
    (ha : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws u a e) :
    ∃ b f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t b f ∧
      Ty.LeQ [] [] b a ∧ Eff.Covers [] [] e f := by
  induction ws generalizing t u a e with
  | nil =>
    cases t with
    | param n x t => obtain ⟨_,_,rfl,_,_⟩ := param_inv hr; cases ha
    | done r f =>
      obtain ⟨_,_,rfl,hle,hcov⟩ := done_inv hr
      cases ha
      exact ⟨r,f,.done ht,hle,hcov⟩
  | cons v vs ih =>
    cases t with
    | done r f => obtain ⟨_,_,rfl,_,_⟩ := done_inv hr; cases ha
    | param n x t =>
      obtain ⟨y,u,rfl,hyx,htu⟩ := param_inv hr
      cases ha with
      | param hy hv hs =>
        have hx : Ty.Annotation P [] [] x := ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩
        have hvx := HasTypeVQ.V_Sub hv hyx hx.wf hx.sorted hx.declared
        have htr : Ty.Annotation P [] (Ctx.extend [] x) (.dependentFn t) :=
          ⟨by simpa [Ty.WF,Ctx.extend] using ht.wf.2,ht.sorted.2,ht.declared.2⟩
        have ht' := (SubstOk.openValue (R := none) hvx hx (by simp [Ctx.WF])).telAnnotation htr
        have hr' := htu.bind (valEnv (openValue v))
          ((SubstOk.openValue (R := none) hv hy (by simp [Ctx.WF])).transport (by simp))
        rw [valEnv_openValue] at ht' hr'
        obtain ⟨b,f,hb,hle,hcov⟩ := ih ht' hr' hs
        exact ⟨b,f,.param hx hvx hb,hle,hcov⟩

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

private theorem prim_annotation {P B Ψ Q C Γ Φ v T b ts es rs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .prim b ts es rs) :
    Ty.Annotation P C Γ T := by
  match h with
  | .V_Prim _ _ _ _ hi => exact hi.result
  | .V_Normal hh => exact (prim_annotation hh hv).norm
  | .V_Sub _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .V_Refine hh hi ht hs hw he hd hp =>
    have ha := prim_annotation hh hv
    exact ⟨⟨ha.wf,hw,by simpa [Ty.NotContCore] using hi.ordinary⟩,⟨ha.sorted,hs⟩,⟨hd,hp⟩⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

private theorem prim_inv {P B Ψ Q C Γ Φ v T b ts es rs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .prim b ts es rs) :
    ∃ s u, B.sig b = some s ∧ B.RangeAdmissible b s rs ∧
      PrimitiveAdmissible C Γ.length s Q ts es ∧
      SignatureInstance P C Γ (Tel.instR rs s.tel) (s.tparams.map TParamDecl.kind) ts es ∧
      T.fnCore = some u ∧ TelClosure Γ Φ (instantiatedTel (Tel.instR rs s.tel) ts es) u := by
  match h with
  | .V_Prim hs hr hn ha hi => cases hv; exact ⟨_,_,hs,hr,ha,hi,rfl,.refl⟩
  | .V_Normal (a := T0) hh =>
    obtain ⟨s,u,hs,hr,ha,hi,hu,ht⟩ := prim_inv hh hv
    have hl : Ty.LeQ Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨w,hw,ht'⟩ := hl.fnCore hu
    exact ⟨s,w,hs,hr,ha,hi,hw,ht.trans ht'⟩
  | .V_Sub hh hl _ _ _ =>
    obtain ⟨s,u,hs,hr,ha,hi,hu,ht⟩ := prim_inv hh hv
    obtain ⟨w,hw,ht'⟩ := hl.fnCore hu
    exact ⟨s,w,hs,hr,ha,hi,hw,ht.trans ht'⟩
  | .V_Refine hh .. =>
    obtain ⟨s,u,hs,hr,ha,hi,hu,ht⟩ := prim_inv hh hv
    exact ⟨s,u,hs,hr,ha,hi,hu,ht⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

private theorem primitive_call_aux {P B Ψ Q C Γ Φ R code a e L b ts es rs ws s}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hg : ∀ v ∈ ws, v.Ground)
    (hc : code = .app (.prim b ts es rs) ws) (hs : B.sig b = some s) :
    ∃ r f, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r f ∧
      Ty.LeQ [] [] r a ∧ Eff.Covers [] [] e f := by
  match h with
  | .C_DependentApp hv ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨sg,u,hsg,hr,had,hi,hu,ht⟩ := prim_inv hv rfl
    cases hs.symm.trans hsg
    cases Option.some.inj hu
    obtain ⟨r,f,ha',hle,hcov⟩ := ha.pullback hi.result ht
    exact ⟨r,f,.normalized had hr hi ha' hg,hle,hcov⟩
  | .C_App hv ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨sg,u,hsg,hr,had,hi,hu,ht⟩ := prim_inv hv rfl
    cases hs.symm.trans hsg
    cases Option.some.inj hu
    have hargs := vs_toTel (prim_annotation hv rfl) ha
    rw [←Tel.norm_toTel] at hargs
    obtain ⟨r,f,ha',hle,hcov⟩ := hargs.pullback hi.result
      (.tail ht (TelLe.of_norm_eq (Tel.norm_idem _).symm))
    exact ⟨r,f,.normalized had hr hi ha' hg,
      .trans hle (.convert (Ty.norm_idem _)),
      Eff.covers_norm_left.mp hcov⟩
  | .C_Sub hh hl he _ _ _ =>
    obtain ⟨r,f,ha,hle,hcov⟩ := primitive_call_aux hh hQ hC hΓ hΦ hg hc hs
    subst Q C Γ Φ
    exact ⟨r,f,ha,.trans hle hl,he.trans hcov⟩
  | .C_Eff hh he =>
    obtain ⟨r,f,ha,hle,hcov⟩ := primitive_call_aux hh hQ hC hΓ hΦ hg hc hs
    subst Q C Γ Φ
    exact ⟨r,f,ha,hle,he.trans hcov⟩
  | .C_Normal hh =>
    obtain ⟨r,f,ha,hle,hcov⟩ := primitive_call_aux hh hQ hC hΓ hΦ hg hc hs
    exact ⟨r,f,ha,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

theorem HasTypeCQ.primitive_call {P B Ψ R code a e L b ts es rs ws s}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R code a e L)
    (hg : ∀ v ∈ ws, v.Ground)
    (hc : code = .app (.prim b ts es rs) ws) (hs : B.sig b = some s) :
    ∃ r f, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r f ∧
      Ty.LeQ [] [] r a ∧ Eff.Covers [] [] e f :=
  primitive_call_aux h rfl rfl rfl rfl hg hc hs

private theorem primitive_annotation {P B Ψ Q C Γ Φ R code a e L b ts es rs ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hc : code = .app (.prim b ts es rs) ws) : Ty.Annotation P C Γ a := by
  match h with
  | .C_App hv _ =>
    cases hc
    have ha := prim_annotation hv rfl
    exact ⟨ha.wf.2.2.1,ha.sorted.2.1,ha.declared.2.1⟩
  | .C_DependentApp _ ha => cases hc; exact ha.resultAnnotation
  | .C_Sub _ _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .C_Normal hh => exact (primitive_annotation hh hc).norm
  | .C_Eff hh _ => exact primitive_annotation hh hc
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

private def isApp : Comp → Bool | .app .. => true | _ => false

/-- 空の捕捉でも導出に存在しうる Φ を閉じた事実から除去し、呼出しの葉を得る。 -/
theorem ClosureTy.pure_primitive {P B Ψ R a e b ts es rs ws s}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.app (.prim b ts es rs) ws)) a e)
    (hg : ∀ v ∈ ws, v.Ground) (hs : B.sig b = some s) :
    ∃ r f, BuiltinArgs P B Ψ b s (Ty.normTys ts) (es.map Eff.norm) rs ws r f ∧
      Ty.LeQ [] [] r a ∧ Eff.Covers [] [] e f := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es0,L,ρ,hq,hcap,hbody,hL,hR,ha,he,hr⟩ := h.open_zero
  have hc : cap = Capture.empty := (Closure.mk.inj hq).1.symm
  subst cap
  have hΓ : Γ = [] := by
    cases hcap with
    | mk _ hn _ _ _ _ _ _ => exact List.length_eq_zero_iff.mp hn.symm
  subst Γ
  have hcode : code0.resolveLocals ρ = .app (.prim b ts es rs) ws := (Closure.mk.inj hq).2.symm
  have htag : isApp code0 = true := by
    have hh := congrArg isApp hcode
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
  have han := primitive_annotation hb rfl
  obtain ⟨r,f,hargs,hle,hcov⟩ := hb.primitive_call hg rfl hs
  have hae : Capture.empty.closeTy as = as.norm := Ty.subst_values_of_wf_zero han.wf _
  rw [hae] at ha
  subst a
  refine ⟨r,f,hargs,.trans hle (.convert (Ty.norm_idem _).symm),?_⟩
  have hh := hcov.bind (Δ := []) (Ψ := []) (valEnv Capture.empty.env)
  have hf : Eff.bind (valEnv Capture.empty.env) f = f :=
    Eff.subst_values_of_wf_zero hargs.effect.1 hargs.effect.2 _
  rw [hf] at hh
  change Eff.Covers [] [] (Capture.empty.closeEff es0) f at hh
  rwa [he] at hh

end
end Benitoite.Release.Refinement
