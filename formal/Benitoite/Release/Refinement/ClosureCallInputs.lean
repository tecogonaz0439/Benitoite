import Benitoite.Release.Refinement.CloseApplication
import Benitoite.Release.Refinement.ClosureApply
import Benitoite.Release.Refinement.TypeSubstCallSites

/-! # 適用の元の契約と本体（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem HasTypeCQ.call_inputs {P B Ψ Q C Γ Φ R code a e L f ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .app f ws) (O : Tel → Prop)
    (origin : ∀ T, HasTypeVQ P B Ψ Qempty [] [] [] f T →
      ∃ t u, Ty.Annotation P [] [] (.dependentFn t) ∧ T.fnCore = some u ∧
        TelClosure P [] [] t u ∧ O t) :
    ∃ t r g, O t ∧ HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g := by
  match h with
  | .C_DependentApp hv ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨t,u,ht,hu,hle,ho⟩ := origin _ hv
    cases Option.some.inj hu
    obtain ⟨r,g,hargs,hl,hcov⟩ := ha.pullback ht hle
    exact ⟨t,r,g,ho,hargs,hl,hcov⟩
  | .C_App hv ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨t,u,ht,hu,hle,ho⟩ := origin _ hv
    cases Option.some.inj hu
    have hann := open_value_annotation hw hs hd (CaptureContextRegular.empty P []) hv
    have hargs := ha.toTel_normal hann
    rw [←Tel.norm_toTel] at hargs
    obtain ⟨r,g,hargs,hl,hcov⟩ := hargs.pullback ht
      (.tail hle (TelLe.of_norm_eq (Tel.norm_idem _).symm))
    exact ⟨t,r,g,ho,hargs,.trans hl (.convert (Ty.norm_idem _)),Eff.covers_norm_left.mp hcov⟩
  | .C_Sub hh hl he _ _ _ =>
    obtain ⟨t,r,g,ho,ha,hle,hcov⟩ := hh.call_inputs hw hs hd hQ hC hΓ hΦ hc O origin
    subst Q C Γ Φ
    exact ⟨t,r,g,ho,ha,.trans hle hl,he.trans hcov⟩
  | .C_Eff hh he =>
    obtain ⟨t,r,g,ho,ha,hle,hcov⟩ := hh.call_inputs hw hs hd hQ hC hΓ hΦ hc O origin
    subst Q C Γ Φ
    exact ⟨t,r,g,ho,ha,hle,he.trans hcov⟩
  | .C_Normal hh =>
    obtain ⟨t,r,g,ho,ha,hle,hcov⟩ := hh.call_inputs hw hs hd hQ hC hΓ hΦ hc O origin
    exact ⟨t,r,g,ho,ha,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

theorem HasTypeCQ.closure_inputs {P B Ψ R code a e L runtime body ws}
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R code a e L)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : code = .app (.closure runtime body) ws) :
    ∃ t r g, Tel.RuntimeShape runtime t ∧ DependentClosureTy P B Ψ body t ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g := by
  obtain ⟨t,r,g,⟨hr,hb⟩,ha,hl,he⟩ := h.call_inputs hw hs hd rfl rfl rfl rfl hc
    (fun t => Tel.RuntimeShape runtime t ∧ DependentClosureTy P B Ψ body t) (by
      intro T hv
      obtain ⟨t,u,ha,hr,hb,hu,hl⟩ := hv.inv_closure rfl
      exact ⟨t,u,ha,hu,hl,hr,hb⟩)
  exact ⟨t,r,g,hr,hb,ha,hl,he⟩

theorem HasTypeVQ.fun_origin {P B Ψ Q C Γ Φ v T f d ts es}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hv : v = .fnRef f ts es)
    (hd : P.defs f = some d) :
    ∃ u, T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel d.tel ts es) u := by
  obtain ⟨d',u,hl,_,_,_,hu,hr⟩ := h.inv_fnRef hv
  cases Option.some.inj (hl.symm.trans hd)
  exact ⟨u,hu,hr⟩

theorem HasTypeVQ.fun_origin_ranges {P B Ψ Q C Γ Φ v T f d ts es rs}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T)
    (hv : v = .fnRef f ts es (rs.map RangeIx.fixed)) (hd : P.defs f = some d) :
    ∃ u, T.fnCore = some u ∧ TelClosure P Γ Φ (instantiatedTel (d.instTel rs) ts es) u := by
  obtain ⟨d',u,rs',hrs,_,hl,_,_,_,hu,hr⟩ := h.inv_fnRef_ranges hv
  have he : rs = rs' := by
    have hc := congrArg closedRanges hrs
    simpa only [closedRanges_fixed, Option.some.injEq] using hc
  subst rs'
  cases Option.some.inj (hl.symm.trans hd)
  exact ⟨u,hu,hr⟩

theorem HasTypeCQ.fun_apply_all_ranges {P B σ Ψ μ R code a e L f d ts es rs ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R code a e L)
    (hc : code = .app (.fnRef f ts es (rs.map RangeIx.fixed)) ws) (hd : P.defs f = some d)
    (hg : ∀ v ∈ ws, v.Ground) :
    ∃ r g, ClosureTy P B Ψ [] (some r)
      (.mk (Capture.empty.extendMany ws) ((d.body.instR rs).substTy ts es)) r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g := by
  obtain ⟨t,r,g,ho,ha,hle,hcov⟩ := h.call_inputs hs.wf hs.sorted hs.declared
    rfl rfl rfl rfl hc
    (fun t => Ty.Annotation P [] [] (.dependentFn t) ∧ t.Normal ∧
      TelBodyTy P B StoreTy.empty Qempty [] [] [] t ((d.body.instR rs).substTy ts es)) (by
      intro T hv
      obtain ⟨u,hu,hl⟩ := hv.fun_origin_ranges rfl hd
      have hi := (hv.fun_body_input_ranges rfl rfl rfl hd).2.1
      have hb := type_subst_fun_body_ranges ⟨hP,hPB,hB⟩ hd hv
      exact ⟨_,u,hi.result,hu,hl,hi.result,Tel.norm_idem _,hb⟩)
  have hb := TelBodyTy.capture_all hB.values StoreTy.WF.empty
    (show StoreTy.empty.Extends Ψ from fun _ _ h => by cases h)
    (CaptureOk.empty P B Ψ (some r)) ho.2.2 ho.1
    (by simpa only [Capture.empty_closeTel ho.1.wf ho.2.1] using ha) hg
  exact ⟨r,g,hb,hle,hcov⟩

theorem HasTypeCQ.fun_apply_all {P B σ Ψ μ R code a e L f d ts es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (h : HasTypeCQ P B Ψ Qempty [] [] [] R code a e L)
    (hc : code = .app (.fnRef f ts es) ws) (hd : P.defs f = some d)
    (hg : ∀ v ∈ ws, v.Ground) :
    ∃ r g, ClosureTy P B Ψ [] (some r)
      (.mk (Capture.empty.extendMany ws) (d.body.substTy ts es)) r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g := by
  simpa only [Comp.instR_nil] using h.fun_apply_all_ranges (rs := []) hP hPB hB hs hc hd hg

end
end Benitoite.Release.Refinement
