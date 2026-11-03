import Benitoite.Release.Refinement.ReplyState
import Benitoite.Release.Refinement.CanonicalValues

/-! # 外部呼出しの元の導出と受信契約 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem typeEnv_nil : typeEnv [] = renEnv id := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1 <;> funext i <;> simp [typeEnv,typeEnvAt,renEnv]

private theorem close_external {P B Ψ Q C Γ Φ Rs m a e L cap R f ts vs}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .externalCall f ts vs) (Rt : Option Ty) :
    HasTypeCQ P B Ψ Qempty [] [] [] Rt (.externalCall f (ts.map cap.closeTy) (closeVals cap vs))
      (cap.closeTy a) (cap.closeEff e) [] := by
  match h with
  | .C_External (d := d) hf hdecl had hargs =>
    subst Q C
    cases hm
    have ht := had.types_nil hdecl
    subst ts
    have he : Tel.bind (typeEnv []) d.parameters = Tel.norm d.parameters := by
      rw [typeEnv_nil,Tel.bind,Tel.rawBind_id]
    simp only [he] at hargs
    have ht0 : Ty.Annotation P [] [] (.dependentFn (Tel.norm d.parameters)) :=
      ⟨Tel.wf_norm hdecl.annotation.wf,Tel.sorted_norm hdecl.annotation.sorted,Tel.Declared.norm hdecl.annotation.declared⟩
    have htann := ht0.closed_context (C := []) (Γ := Γ)
    have ha := hargs.close_typed hP hPB hB hw hs hd hc htann
    have hec : cap.closeTel (Tel.norm d.parameters) = Tel.norm d.parameters := by
      rw [Capture.closeTel,Tel.bind_values_of_wf_zero ht0.wf,Tel.norm_idem]
    rw [hec] at ha
    exact .C_External hf hdecl had (by simpa only [List.map_nil,typeEnv_nil,Tel.bind,Tel.rawBind_id] using ha)
  | .C_Sub hb hl he hwf hsort hdecl =>
    have hh := close_external hb hP hPB hB hw hs hd hc hQ hC hm Rt
    subst Q C
    have ht := hc.substOk.annotation (Ty.Annotation.mk hwf hsort hdecl)
    exact .C_Sub hh (hl.bind (valEnv cap.env) hc.transport)
      (he.bind (valEnv cap.env)) ht.wf ht.sorted ht.declared
  | .C_Normal hb =>
    simpa only [Capture.closeTy,substTyValues_norm_source] using
      close_external hb hP hPB hB hw hs hd hc hQ hC hm Rt
  | .C_Eff hb he =>
    have hh := close_external hb hP hPB hB hw hs hd hc hQ hC hm Rt
    subst Q C
    exact .C_Eff hh (he.bind (valEnv cap.env))
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_App .. | .C_DependentApp .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

theorem ClosureTy.external_view_typed {P B Ψ R q a e f ts vs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .externalCall f ts vs) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.externalCall f ts vs) a e [] := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,hl,hr,rfl,rfl,hrs⟩ := hq.open_zero
  cases m
  case externalCall f0 ts0 vs0 =>
    have hh := close_external hb hP hPB hB hw hs hd hc rfl rfl rfl R
    have hvs : Val.resolveLocalsList ρ vs0 = vs0 := by
      rw [Val.resolveLocalsList_eq_map]
      have he : vs0.map (fun v => v.resolveLocals ρ) = vs0.map id := List.map_congr_left
        (fun v hv => (hb.read_values v hv).choose_spec.resolve_id ρ)
      simpa only [List.map_id] using he
    simp only [Comp.resolveLocals,hvs,Closure.view] at hv
    cases hv
    exact hh
  case checkAt k o sh bs p v ix =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view] at hv; injection hv)
  all_goals (simp only [Comp.resolveLocals,Closure.view] at hv; injection hv)

private theorem external_inputs {P B Ψ Q C Γ Φ R m a e L f ts vs d}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hm : m = .externalCall f ts vs) (hd : P.externalFunction f = some d)
    (hg : ∀ v∈vs,v.Ground) :
    ∃ r ef, ExternalArgs P B Ψ d ts vs r ef ∧ Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef := by
  match h with
  | .C_External hd' hw ha hs =>
    subst Q C Γ Φ
    cases hm
    cases Option.some.inj (hd'.symm.trans hd)
    have ht := ha.types_nil hw
    subst ts
    have hn : Tel.norm (Tel.bind (typeEnv []) d.parameters) = Tel.bind (typeEnv []) d.parameters := Tel.norm_idem _
    obtain ⟨hr,he⟩ := hs.normal hn
    refine ⟨_,_,⟨ha,hs,hg,?_,⟨hs.resultAnnotation.wf,hr⟩,⟨hs.effect_wf,he⟩⟩,.refl,.refl _ _ _⟩
    intro t ht; cases ht
  | .C_Sub hb hl he _ _ _ =>
    obtain ⟨r,ef,ha,hle,hcov⟩ := external_inputs hb hQ hC hΓ hΦ hm hd hg
    subst Q C Γ Φ
    exact ⟨r,ef,ha,.trans hle hl,he.trans hcov⟩
  | .C_Eff hb he =>
    obtain ⟨r,ef,ha,hle,hcov⟩ := external_inputs hb hQ hC hΓ hΦ hm hd hg
    subst Q C Γ Φ
    exact ⟨r,ef,ha,hle,he.trans hcov⟩
  | .C_Normal hb =>
    obtain ⟨r,ef,ha,hle,hcov⟩ := external_inputs hb hQ hC hΓ hΦ hm hd hg
    exact ⟨r,ef,ha,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_App .. | .C_DependentApp .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

theorem ClosureTy.external_view_inputs {P B Ψ R q a e f ts vs d}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hc : q.ClosedAt 0)
    (hv : q.view = .externalCall f ts vs) (hf : P.externalFunction f = some d) :
    ∃ r ef, ExternalArgs P B Ψ d ts vs r ef ∧ Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef :=
  external_inputs (hq.external_view_typed hP hPB hB hw hs hd hv) rfl rfl rfl rfl rfl hf
    (fun v hh => hq.view_read_ground hc (by simpa only [hv,Comp.readValues] using hh))

theorem StateTyE.external_value_all {P B σ Eb q f ts vs k μ d out obs v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .externalCall f ts vs)
    (hd : P.externalFunction f = some d) (hr : B.externalResponse f ts vs out obs)
    (hrec : externalReceive P d ts vs out = some (.val v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  refine ⟨.E_External hv hd hr hrec,?_⟩
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_,hk,_,hcl,hkc,hμ⟩ := h
  obtain ⟨r,ef,ha,hle,_⟩ := hq.external_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl hv hd
  obtain ⟨ht,hg,had⟩ := hB.toExternalAssumptions.received_value hP.external hd ha hr hrec σ
  exact reply_value_state hs hk ha.arguments.resultAnnotation ha.result.2 hle ht hg had hkc hμ

theorem StateTyE.external_error_all {P B σ Eb q f ts vs k μ d out obs r}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .externalCall f ts vs)
    (hd : P.externalFunction f = some d) (hr : B.externalResponse f ts vs out obs)
    (hrec : externalReceive P d ts vs out = some (.err r)) :
    Step P B σ (.run q k μ) none (.error [r] k μ) ∧ StateTyE P B σ Eb (.error [r] k μ) :=
  ⟨.E_ExternalErr hv hd hr hrec,h.error_from_run⟩

private theorem external_annotation {P B Ψ Q C Γ Φ v T f ts}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .externalRef f ts) : Ty.Annotation P C Γ T := by
  match h with
  | .V_ExternalRef _ _ _ hi => exact hi.result
  | .V_Normal hh => exact (external_annotation hh hv).norm
  | .V_Sub _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .V_Refine hh hi ht hs hw he hd hp =>
    have ha := external_annotation hh hv
    exact ⟨⟨ha.wf,hw,by simpa [Ty.NotContCore] using hi.ordinary⟩,⟨ha.sorted,hs⟩,⟨hd,hp⟩⟩
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Op .. | .V_Prim .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

private theorem external_apply {P B Ψ Q C Γ Φ R m a e L f ts vs}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hm : m = .app (.externalRef f ts) vs) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.externalCall f ts vs) a e [] := by
  match h with
  | .C_DependentApp hv ha =>
    subst Q C Γ Φ
    cases hm
    obtain ⟨d,u,hd,hw,had,hi,hu,ht⟩ := hv.inv_externalRef rfl
    cases Option.some.inj hu
    obtain ⟨r,ef,ha',hle,hcov⟩ := ha.pullback hi.result ht
    have he : instantiatedTel d.parameters ts [] = Tel.bind (typeEnv ts) d.parameters := rfl
    exact .C_Sub (.C_External hd hw had (by rw [←he]; exact ha')) hle hcov
      ha.resultAnnotation.wf ha.resultAnnotation.sorted ha.resultAnnotation.declared
  | .C_App hv ha =>
    subst Q C Γ Φ
    cases hm
    obtain ⟨d,u,hd,hw,had,hi,hu,ht⟩ := hv.inv_externalRef rfl
    cases Option.some.inj hu
    have hann := external_annotation hv rfl
    have hs := ha.toTel_normal hann
    rw [←Tel.norm_toTel] at hs
    obtain ⟨r,ef,ha',hle,hcov⟩ := hs.pullback hi.result
      (.tail ht (TelLe.of_norm_eq (Tel.norm_idem _).symm))
    exact .C_Sub (.C_External hd hw had ha')
      (.trans hle (.convert (Ty.norm_idem _))) (Eff.covers_norm_left.mp hcov)
      hann.wf.2.2.1 hann.sorted.2.1 hann.declared.2.1
  | .C_Sub hb hl he hw hs hd =>
    have hh := external_apply hb hQ hC hΓ hΦ hm
    subst Q C Γ Φ
    exact .C_Sub hh hl he hw hs hd
  | .C_Eff hb he =>
    have hh := external_apply hb hQ hC hΓ hΦ hm
    subst Q C Γ Φ
    exact .C_Eff hh he
  | .C_Normal hb => exact .C_Normal (external_apply hb hQ hC hΓ hΦ hm)
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

theorem StateTyE.external_apply_all {P B σ Eb q f ts vs k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.externalRef f ts) vs) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.externalCall f ts vs)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.externalCall f ts vs)) k μ) := by
  refine ⟨.E_ExternalApply hv,?_⟩
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  have hc := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have hb := external_apply hc rfl rfl rfl rfl rfl
  have hret := hk.return_annotation rfl
  have hq' := ClosureTy.pure hb hq.annotation
    (fun r hr => ⟨(hret r hr).wf,(hret r hr).declared⟩) hq.result_normal hq.return_normal
  have hva := Closure.view_adequate had
  rw [hv] at hva
  have hg : ∀ v∈vs,v.Ground := fun v hh => hq.view_read_ground hcl (by rw [hv]; exact List.mem_cons_of_mem _ hh)
  have hvs : Val.ClosedList 0 0 vs := by
    clear hv hc hb hva hq'
    induction vs with
    | nil => trivial
    | cons v vs ih => exact ⟨hg v List.mem_cons_self,ih (fun w hw => hg w (List.mem_cons_of_mem _ hw))⟩
  have hf := hq.view_read_ground hcl (by rw [hv]; exact List.mem_cons_self)
  exact ⟨Ψ,R,a,b,e,e1,hs,hq',he,hk,⟨trivial,hva.2⟩,⟨trivial,hf,hvs⟩,hkc,hμ⟩

end
end Benitoite.Release.Refinement
