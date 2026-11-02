import Benitoite.Release.Refinement.MethodClosure
import Benitoite.Release.Refinement.CallBodyScope

/-! # 上位辞書の具体化（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section
theorem CaptureOk.closed_arguments {P B Ψ R ps vs}
    (ha : TypeAnnotations P [] [] ps) (hn : ∀ a ∈ ps, a.Normal)
    (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs ps) (hg : ∀ v ∈ vs, v.Ground) :
    CaptureOk P B Ψ R (Refinement.bindParams [] ps) [] (Capture.empty.extendMany vs) := by
  have hv' : HasTypeVsQ P B Ψ Qempty [] [] [] vs (ps.map Capture.empty.closeTy) := by
    have heq : ps.map Capture.empty.closeTy = ps := by
      conv => rhs; rw [←List.map_id ps]
      exact List.map_congr_left (fun a hm => (Ty.subst_values_of_wf_zero (ha a hm).wf _).trans (hn a hm))
    rw [heq]; exact hv
  have hh := (CaptureOk.empty P B Ψ R).bindParams ha hv' hg
  simpa only [liftMany_eq,List.map_nil] using hh

theorem HasTypeVQ.super_dictionary {P B σ Ψ μ i us vs cl τ cd s id u}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] (.dict i us vs) (.dict cl τ))
    (hcl : P.classes cl = some cd) (hm : s ∈ cd.supers) (hτ : Ty.Declared P [] [] τ)
    (hi : P.impls i = some id) (hu : id.supers s = some u)
    (hg : (Val.dict i us vs).Ground) (had : (Val.dict i us vs).Adequate σ) :
    HasTypeVQ P B Ψ Qempty [] [] [] ((u.substTy us []).instantiate vs) (.dict s τ) ∧
      ((u.substTy us []).instantiate vs).Ground ∧ ((u.substTy us []).instantiate vs).Adequate σ
 := by
  obtain ⟨id0,hi0,heq,ds,dt,dk,hvs⟩ := hv.dict_callInputs rfl
  cases Option.some.inj (hi0.symm.trans hi)
  have hlink : id.cls = cl ∧ τ.norm = (id.target.subst us []).norm := by
    simpa only [Ty.norm,Ty.core,Ty.dict.injEq,eq_comm (a := cl)] using heq
  have hcl' : P.classes id.cls = some cd := hlink.1 ▸ hcl
  obtain ⟨cd',hcd',_,_,_,_,_,hsup⟩ := hPB.impls i id hi
  cases Option.some.inj (hcd'.symm.trans hcl')
  obtain ⟨u',hu',ht⟩ := hsup s hm
  cases Option.some.inj (hu'.symm.trans hu)
  have inp : TypeSubstInput P B (TypeCtx.values id.tparams) [] us [] :=
    { typeCount := by simpa only [TypeCtx.values,List.length_map,List.length_replicate] using dk.1
      typeWF := fun a ha => (dt a ha).wf
      typeKinds := by simpa only [TypeCtx.kinds,TypeCtx.values,List.map_map,
        Function.comp_def,embedTParam,List.map_const'] using dk
      typeAnnotations := dt
      constraints := by simpa [TypeCtx.constraints,TypeCtx.values,List.map_map,
        Function.comp_def,embedTParam,List.map_id] using ds
      rowWF := by intro e he; cases he
      rowAnnotations := by intro e he; cases he
      rowKinds := by intro e he; cases he }
  have ht' := ht.store_extend hB.values StoreTy.WF.empty
    (show StoreTy.empty.Extends Ψ from fun _ _ h => by cases h)
  have hs02 := S02Internal.substV (C0 := TypeCtx.values id.tparams) (C1 := [])
    ⟨hP,hPB,hB,hs.wf⟩ inp (Or.inl rfl)
    (show RowTransport Qempty Qempty [] from fun _ h => False.elim h) ht'
  change HasTypeVQ P B Ψ Qempty [] ((Refinement.bindParams [] id.dictTys).bindTypes (typeEnvAt 0 us [])) []
    (u.substTy us []) (.dict s (id.target.subst us [])) at hs02
  rw [Ctx.bindTypes_params inp.typeWF inp.rowWF] at hs02
  change HasTypeVQ P B Ψ Qempty [] (bindParams [] (id.dictTys.map (Ty.subst us []))) []
    (u.substTy us []) (.dict s (id.target.subst us [])) at hs02
  have hdict := open_values_annotation hs.wf hs.sorted hs.declared (CaptureContextRegular.empty P []) hvs
  have hcap := CaptureOk.closed_arguments (R := none) hdict
    (fun a ha => by obtain ⟨t,ht,rfl⟩ := List.mem_map.mp ha; exact Ty.norm_idem _) hvs
    (fun v hv => hg.2.member hv)
  have hclosed := close_value_typed hP hPB hB hs.wf hs.sorted hs.declared hcap hs02
  have htargetclose := dependent_result_close (hP.impls i id hi).2.1.1 us
    (Capture.empty.extendMany vs)
  have htypesclose : us.map (Capture.empty.extendMany vs).closeTy = us.map Ty.norm :=
    List.map_congr_left (fun a ha => Ty.subst_values_of_wf_zero (dt a ha).wf _)
  rw [htypesclose,←Ty.normTys_eq_map,Ty.subst_norm_images] at htargetclose
  change HasTypeVQ P B Ψ Qempty [] [] []
    (closeVal (Capture.empty.extendMany vs) (u.substTy us []))
    (.dict s ((Capture.empty.extendMany vs).closeTy (id.target.subst us []))) at hclosed
  rw [htargetclose] at hclosed
  have ha := open_value_annotation hs.wf hs.sorted hs.declared (CaptureContextRegular.empty P [])
    (HasTypeVQ.V_Super hv hcl hm hτ)
  have hv' : HasTypeVQ P B Ψ Qempty [] [] [] ((u.substTy us []).instantiate vs) (.dict s τ) :=
    .V_Sub hclosed (.convert (by simpa only [Ty.norm,Ty.norm_idem] using congrArg (Ty.dict s) hlink.2.symm))
      ha.wf ha.sorted ha.declared
  have hsrc := (hP.impls i id hi).2.2.2.2.2.1 s u hu
  have hsrc' : u.SourceScoped 0 (0+us.length) 0 id.dictTys.length := by
    simpa only [Nat.zero_add,inp.typeCount,TypeCtx.values,List.length_map] using hsrc
  have hscope := hsrc'.runtime_inst inp.typeWF inp.rowWF inp.typeKinds.ordinary σ
  have hlen := hvs.length
  refine ⟨hv',?_,?_⟩
  · apply hs02.close_ground hcap rfl hcap.closed
    change (u.substTy us []).ClosedAt 0 (Capture.empty.extendMany vs).values.length
    rw [Capture.extendMany_values]
    simpa only [Val.substTy,hlen,Capture.empty,Capture.values,List.length_append,
      List.length_reverse,List.length_map,List.length_nil,Nat.zero_add,Nat.add_zero] using hscope.1
  · exact closeVal_adequate ((show Capture.Adequate σ Capture.empty from trivial).extendMany had) hscope.2

theorem Val.superStep_source {P : Program} {v w : Val} (hs : v.superStep P = some w) :
    ∃ u s, v = .super u s := by
  cases v <;> first | exact ⟨_,_,rfl⟩ | cases hs

theorem HasTypeVQ.super_step_aux {P B σ Ψ μ Q C Γ Φ v a w}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hstep : v.superStep P = some w) (hg : v.Ground) (had : v.Adequate σ) :
    HasTypeVQ P B Ψ Qempty [] [] [] w a ∧ w.Ground ∧ w.Adequate σ
 := by
  match h with
  | .V_Super (v := dv) (super := s) hv hc hm hd =>
    have ih (w0 : Val) (hst : dv.superStep P = some w0) (hg : dv.Ground) (had : dv.Adequate σ) :=
      hv.super_step_aux hP hPB hB hs hQ hC hΓ hΦ hst hg had
    subst Q C Γ Φ
    cases dv
    case dict i us vs =>
      cases hi : P.impls i with
      | none => simp only [Val.superStep,hi] at hstep; cases hstep
      | some id =>
        cases hu : id.supers s with
        | none => simp only [Val.superStep,hi,hu,Option.map_none] at hstep; cases hstep
        | some u =>
          simp only [Val.superStep,hi,hu,Option.map_some,Option.some.injEq] at hstep
          subst w
          exact hv.super_dictionary hP hPB hB hs hc hm hd hi hu hg had
    case «super» dv s0 =>
      change ((Val.super dv s0).superStep P).map (fun w => Val.super w s) = some w at hstep
      obtain ⟨w0,hstep0,rfl⟩ := Option.map_eq_some_iff.mp hstep
      obtain ⟨hw,hg',ha'⟩ := ih w0 hstep0 hg had
      exact ⟨.V_Super hw hc hm hd,hg',ha'⟩
    all_goals (simp only [Val.superStep] at hstep; cases hstep)
  | .V_Sub hv hl hw hsort hd =>
    obtain ⟨hv',hg',ha'⟩ := hv.super_step_aux hP hPB hB hs hQ hC hΓ hΦ hstep hg had
    subst Q C Γ Φ
    exact ⟨.V_Sub hv' hl hw hsort hd,hg',ha'⟩
  | .V_Normal hv =>
    obtain ⟨hv',hg',ha'⟩ := hv.super_step_aux hP hPB hB hs hQ hC hΓ hΦ hstep hg had
    exact ⟨.V_Normal hv',hg',ha'⟩
  | .V_Refine _ _ ht .. =>
    obtain ⟨dv,s,rfl⟩ := Val.superStep_source hstep
    cases ht
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. |
    .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. |
    .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. |
    .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. |
    .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_List .. => cases hstep
termination_by structural h

theorem HasTypeCQ.method_super_aux {P B σ Ψ μ Q C Γ Φ R code a e L v w name ss es ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hs : StoreOk P B σ Ψ μ)
    (hQ : Q = Qempty) (hC : C = []) (hΓ : Γ = []) (hΦ : Φ = [])
    (hc : code = .meth v name ss es ws) (hstep : v.superStep P = some w)
    (hg : v.Ground) (had : v.Adequate σ) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.meth w name ss es ws) a e L ∧
      w.Ground ∧ w.Adequate σ ∧ (∀ t ∈ ss, t.WF 0 0 0) ∧ (∀ e ∈ es, e.WF 0 0 0 ∧ e.Canonical)
 := by
  match h with
  | .C_Meth hv hcl hm hn hsat hi hr hargs hvs ha =>
    subst Q C Γ Φ
    cases hc
    obtain ⟨hv',hg',ha'⟩ := hv.super_step_aux hP hPB hB hs rfl rfl rfl rfl hstep hg had
    exact ⟨.C_Meth hv' hcl hm hn hsat hi hr hargs hvs ha,hg',ha',
      fun t ht => (hi.types t (List.mem_append_left _ ht)).wf,
      fun e he => (hi.rows e he).wf.2.2.2⟩
  | .C_Sub hh hl he hw hsort hd =>
    obtain ⟨hh',hg',ha',hts,hes⟩ := hh.method_super_aux hP hPB hB hs hQ hC hΓ hΦ hc hstep hg had
    subst Q C Γ Φ
    exact ⟨.C_Sub hh' hl he hw hsort hd,hg',ha',hts,hes⟩
  | .C_Normal hh =>
    obtain ⟨hh',hg',ha',hts,hes⟩ := hh.method_super_aux hP hPB hB hs hQ hC hΓ hΦ hc hstep hg had
    exact ⟨.C_Normal hh',hg',ha',hts,hes⟩
  | .C_Eff hh he =>
    obtain ⟨hh',hg',ha',hts,hes⟩ := hh.method_super_aux hP hPB hB hs hQ hC hΓ hΦ hc hstep hg had
    subst Q C Γ Φ
    exact ⟨.C_Eff hh' he,hg',ha',hts,hes⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. |
    .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. |
    .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

end
end Benitoite.Release.Refinement
