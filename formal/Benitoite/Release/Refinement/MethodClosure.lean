import Benitoite.Release.Refinement.MethodTypeComposition
import Benitoite.Release.Refinement.ClosureCallInputs

/-! # メソッド本体と辞書の捕捉（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section
theorem HasTypeCQ.method_apply_all {P B σ Ψ μ Q C Γ Φ R code a e L i us vs name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .meth (.dict i us vs) name ss es ws)
    (hgv : ∀ v ∈ vs, v.Ground) (hgw : ∀ w ∈ ws, w.Ground) :
    ∃ id cd ms body r g,
      P.impls i = some id ∧ P.classes id.cls = some cd ∧ cd.methods name = some ms ∧
      id.methods name = some body ∧
      ClosureTy P B Ψ [] (some r)
        (.mk (Capture.empty.extendMany (vs++ws)) (body.substTy (ss++us) es)) r g ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e g
 := by
  match h with
  |  .C_Meth (ms := ms) (cd := cd) (τ := τ) (a := a) (ε := ε) hv hcl hm hn hsat hi hr hargs hws ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨id,hl,hcls,htarget,hvs,inp⟩ := Refinement.method_body_input hv hsat hi
    have hss : ss.length = ms.tparams.length := by
      have hlen := hi.kinds.1
      simp only [TypeCtx.kinds,List.length_map,List.length_append,List.length_cons,List.length_nil] at hlen
      omega
    have hus : us.length = id.tparams.length := by
      have hlen := inp.typeCount
      simp only [List.length_append,TypeCtx.values,List.length_map] at hlen
      omega
    obtain ⟨id',cl',cd',ms',body,hl',hcl',hm',hcls',hbody,hb⟩ :=
      type_subst_method_body ⟨hP,hPB,hB,hs.wf⟩
        (HasTypeCQ.C_Meth (R := R) (Δ := []) hv hcl hm hn hsat hi hr hargs hws ha)
    have hid : id'=id := Option.some.inj (hl'.symm.trans hl)
    subst id'
    subst cl'
    have hcl0 : P.classes id.cls = some cd := hcls ▸ hcl
    have hcd : cd'=cd := Option.some.inj (hcl'.symm.trans hcl0)
    subst cd'
    have hms : ms'=ms := Option.some.inj (hm'.symm.trans hm)
    subst ms'
    have hmeta := hP.impls i id hl
    have hcomp := methodTel_comp (t := ms.tel) (ss := ss) (us := us)
      (es := es) (target := id.target) (τ := τ) (by
      simpa only [Ty.WF,TypeCtx.kinds,List.length_map,List.length_append,List.length_cons,List.length_nil,Nat.zero_add,hss] using hi.source)
      hus hmeta.2.1.1 hmeta.2.1.2.1 htarget
    rw [hss] at hcomp
    rw [tel_substAt_shiftV_closed inp.typeWF inp.rowWF,hcomp,
      Tel.shiftV_of_wf_zero hi.result.wf] at hb
    have hctx := method_dictionary_context hus hmeta.1 inp.typeWF inp.rowWF
    rw [hss] at hctx
    rw [hctx] at hb
    have hdict := open_values_annotation hs.wf hs.sorted hs.declared (CaptureContextRegular.empty P []) hvs
    have hvs' : HasTypeVsQ P B Ψ Qempty [] [] [] vs
        ((id.dictTys.map (Ty.subst us [])).map Capture.empty.closeTy) := by
      have hm : (id.dictTys.map (Ty.subst us [])).map Capture.empty.closeTy =
          id.dictTys.map (Ty.subst us []) := by
        conv => rhs; rw [←List.map_id (id.dictTys.map (Ty.subst us []))]
        apply List.map_congr_left
        intro t ht
        exact (Ty.subst_values_of_wf_zero (hdict t ht).wf Capture.empty.env).trans
          (by obtain ⟨a,ha,rfl⟩ := List.mem_map.mp ht; exact Ty.norm_idem _)
      rw [hm]
      exact hvs
    have hcap := (CaptureOk.empty P B Ψ (some a)).bindParams hdict hvs' hgv
    have ht : Ty.Annotation P [] (bindParams [] (id.dictTys.map (Ty.subst us [])))
        (.dependentFn (instantiatedTel ms.tel (ss++[τ]) es)) :=
      hi.result.closed_context
    have hargs' := HasTypeTelArgsQ.of_arguments hargs hws hi.result (by simp [Ctx.WF]) (Tel.norm_idem _)
    have hargs'' : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
        ((Capture.empty.extendMany vs).closeTel (instantiatedTel ms.tel (ss++[τ]) es)) a ε := by
      have htw : Tel.WF 0 0 0 (instantiatedTel ms.tel (ss++[τ]) es) := hi.result.wf
      have heq : (Capture.empty.extendMany vs).closeTel (instantiatedTel ms.tel (ss++[τ]) es) =
          instantiatedTel ms.tel (ss++[τ]) es :=
        (Tel.bind_values_of_wf_zero htw _).trans (Tel.norm_idem _)
      rw [heq]
      exact hargs'
    have hcap' : CaptureOk P B Ψ (some a)
        (bindParams [] (id.dictTys.map (Ty.subst us []))) [] (Capture.empty.extendMany vs) := by
      simpa only [liftMany_eq,List.map_nil] using hcap
    have hdst := TelBodyTy.capture_all hB.values StoreTy.WF.empty
      (show StoreTy.empty.Extends Ψ from fun _ _ h => by cases h) hcap' hb ht hargs'' hgw
    refine ⟨id,cd,ms,body,a,ε,hl,hcl0,hm,hbody,?_,.refl,Eff.Covers.refl _ _ _⟩
    simpa only [Capture.extendMany,List.foldl_append] using hdst
  | .C_Sub hh hl he _ _ _ =>
    obtain ⟨id,cd,ms,body,r,g,hi,hcl,hm,hb,hd,hle,hcov⟩ := hh.method_apply_all hP hPB hB hs hQ hC hΓ hΦ hc hgv hgw
    subst Q C Γ Φ
    exact ⟨id,cd,ms,body,r,g,hi,hcl,hm,hb,hd,.trans hle hl,he.trans hcov⟩
  | .C_Eff hh he =>
    obtain ⟨id,cd,ms,body,r,g,hi,hcl,hm,hb,hd,hle,hcov⟩ := hh.method_apply_all hP hPB hB hs hQ hC hΓ hΦ hc hgv hgw
    subst Q C Γ Φ
    exact ⟨id,cd,ms,body,r,g,hi,hcl,hm,hb,hd,hle,he.trans hcov⟩
  | .C_Normal hh =>
    obtain ⟨id,cd,ms,body,r,g,hi,hcl,hm,hb,hd,hle,hcov⟩ := hh.method_apply_all hP hPB hB hs hQ hC hΓ hΦ hc hgv hgw
    exact ⟨id,cd,ms,body,r,g,hi,hcl,hm,hb,hd,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. |
    .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. |
    .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

end
end Benitoite.Release.Refinement
