import Benitoite.Release.Refinement.ClosureViewTyping
import Benitoite.Release.Refinement.ReferenceCalls

/-! # 実行 view の適用の契約（設計書 01-12「篩を含む状態の型付け」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem Tel.arguments_observations (t : Tel) {vs ws : List Val}
    (h : Val.toTermSlots vs = Val.toTermSlots ws) : Tel.arguments t vs = Tel.arguments t ws := by
  induction vs generalizing t ws with
  | nil => cases ws <;> simp_all [Val.toTermSlots]
  | cons v vs ih =>
    cases ws with
    | nil => simp [Val.toTermSlots] at h
    | cons w ws =>
      simp only [Val.toTermSlots,List.cons.injEq] at h
      cases t with
      | done => simp only [Tel.arguments]
      | param n a rest =>
        have he : Tel.argumentsEnv v = Tel.argumentsEnv w := by
          simp only [argumentsEnv_eq,h.1]
        simp only [Tel.arguments,he]
        exact congrArg (Option.map fun (as,r,e) => (a.norm :: as,r,e)) (ih _ h.2)

theorem HasTypeTelArgsQ.close_typed {P B Ψ R Γ Φ cap vs t a e}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ht : Ty.Annotation P [] Γ (.dependentFn t))
    (hv : HasTypeTelArgsQ P B Ψ Qempty [] Γ Φ vs t a e) :
    HasTypeTelArgsQ P B Ψ Qempty [] [] [] (closeVals cap vs) (cap.closeTel t)
      (cap.closeTy a) (cap.closeEff e) := by
  obtain ⟨as,ha,hvs⟩ := hv.normInput.arguments (Tel.norm_idem t)
  have hh := Tel.arguments_subst (Tel.norm t) vs cap.env LocalRef.bound
  rw [ha,Option.map_some] at hh
  rw [←Tel.arguments_observations _ (closeVals_observations cap vs)] at hh
  have htel : cap.closeTel (Tel.norm t) = cap.closeTel t := Tel.norm_rawBind _ t
  change (cap.closeTel (Tel.norm t)).arguments (closeVals cap vs) = _ at hh
  rw [htel] at hh
  simp only [substTyValues_norm_source,substEffValues_norm_source] at hh
  exact HasTypeTelArgsQ.of_arguments hh (close_values_typed hP hPB hB hw hs hd hc hvs)
    (hc.substOk.telAnnotation ht) (by simp [Ctx.WF]) (Tel.norm_idem _)

theorem HasTypeCQ.close_app_aux {P B Ψ Q C Γ Φ Rs m a e L cap R f vs}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .app f vs) (Rt : Option Ty) :
    HasTypeCQ P B Ψ Qempty [] [] [] Rt (.app (closeVal cap f) (closeVals cap vs))
      (cap.closeTy a) (cap.closeEff e) [] := by
  match h with
  | .C_App hf hv =>
    subst Q C
    cases hm
    have hf' := close_value_typed hP hPB hB hw hs hd hc hf
    have hv' := close_values_typed hP hPB hB hw hs hd hc hv
    simp only [Capture.closeTy,substTyValues,Ty.bind_fn] at hf'
    exact HasTypeCQ.C_App (R := Rt) (Δ := []) hf' hv'
  | .C_DependentApp (t := t) hf hv =>
    subst Q C
    cases hm
    have ht := open_value_annotation hw hs hd hc.contextRegular hf
    have hf' := close_value_typed hP hPB hB hw hs hd hc hf
    have hv' := hv.close_typed hP hPB hB hw hs hd hc ht
    have he : cap.closeTy (.dependentFn t) = (Ty.dependentFn (cap.closeTel t)).norm := by
      simp only [Capture.closeTy,substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Capture.closeTel,Tel.bind,
        Tel.norm_idem]
    rw [he] at hf'
    exact .C_DependentAppNorm hf' hv'
  | .C_Sub hb hl he hwf hsort hdecl =>
    have hh := hb.close_app_aux hP hPB hB hw hs hd hc hQ hC hm Rt
    subst Q C
    have ht := hc.substOk.annotation (Ty.Annotation.mk hwf hsort hdecl)
    exact .C_Sub hh (hl.bind (valEnv cap.env) hc.transport)
      (he.bind (valEnv cap.env)) ht.wf ht.sorted ht.declared
  | .C_Normal hb =>
    have hh := hb.close_app_aux hP hPB hB hw hs hd hc hQ hC hm Rt
    simpa only [Capture.closeTy,substTyValues_norm_source] using hh
  | .C_Eff hb he =>
    have hh := hb.close_app_aux hP hPB hB hw hs hd hc hQ hC hm Rt
    subst Q C
    exact .C_Eff hh (he.bind (valEnv cap.env))
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

theorem ClosureTy.app_view_typed {P B Ψ R q a e f vs}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .app f vs) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.app f vs) a e [] := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,hl,hr,rfl,rfl,hrs⟩ := hq.open_zero
  cases m
  case app f0 vs0 =>
    have hh := hb.close_app_aux hP hPB hB hw hs hd hc rfl rfl rfl R
    have he : (Comp.app f0 vs0).resolveLocals ρ = .app f0 vs0 := by
      have hm := hb.read_values
      have hf : f0.resolveLocals ρ = f0 := (hm _ List.mem_cons_self).choose_spec.resolve_id ρ
      have hvs : Val.resolveLocalsList ρ vs0 = vs0 := by
        rw [Val.resolveLocalsList_eq_map]
        have he : vs0.map (fun v => v.resolveLocals ρ) = vs0.map id := List.map_congr_left
          (fun v hv => (hm v (List.mem_cons_of_mem _ hv)).choose_spec.resolve_id ρ)
        simpa only [List.map_id] using he
      simp only [Comp.resolveLocals,hf,hvs]
    rw [he] at hv
    cases hv
    exact hh
  case checkAt k o sh bs p v ix =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)
  all_goals (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)

theorem ClosureTy.ret_view_typed {P B Ψ R q a e v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .ret v) :
    HasTypeVQ P B Ψ Qempty [] [] [] v a := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,_,_,rfl,_,_⟩ := hq.open_zero
  cases m
  case ret v0 =>
    have hval := hb.ret_value rfl
    have he : (Comp.ret v0).resolveLocals ρ = .ret v0 := by
      simp only [Comp.resolveLocals,hval.resolve_id ρ]
    rw [he] at hv
    cases hv
    exact close_value_typed hP hPB hB hw hs hd hc hval
  case checkAt k o sh bs p v ix =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)
  all_goals (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)

theorem HasTypeCQ.close_method_aux {P B Ψ Q C Γ Φ Rs m a e L cap R v name ss es ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .meth v name ss es ws) (Rt : Option Ty) :
    HasTypeCQ P B Ψ Qempty [] [] [] Rt
      (.meth (closeVal cap v) name (ss.map cap.closeTy) (es.map cap.closeEff) (closeVals cap ws))
      (cap.closeTy a) (cap.closeEff e) [] := by
  match h with
  | .C_Meth (ms := ms) (τ := τ) hv hcl hmethod hn hsat hi hr hargs hvs ha =>
    subst Q C
    cases hm
    have hv' := close_value_typed hP hPB hB hw hs hd hc hv
    have hvs' := close_values_typed hP hPB hB hw hs hd hc hvs
    have hsat' := hsat.map cap.closeTy (fun t ht p hp =>
      hc.close_sat hB (hi.types t (List.mem_append_left _ ht)) hp)
    have hargs' := Tel.arguments_subst (instantiatedTel ms.tel (ss++[τ]) es) ws cap.env LocalRef.bound
    rw [←Tel.arguments_observations _ (closeVals_observations cap ws),
      instantiatedTel_subst_eq hi.source,hargs,Option.map_some] at hargs'
    simp only [List.map_append,List.map_cons,List.map_nil] at hargs'
    have hi' := hc.substOk.signature hi
    simp only [List.map_append,List.map_cons,List.map_nil] at hi'
    have hr' := hc.substOk.methodRows hi.rows hr
    have ha' := hc.substOk.annotation ha
    change HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (.dict _ (cap.closeTy τ)) at hv'
    exact .C_Meth hv' hcl hmethod hn hsat' hi' hr' hargs' hvs' ha'
  | .C_Sub hb hl he hwf hsort hdecl =>
    have hh := hb.close_method_aux hP hPB hB hw hs hd hc hQ hC hm Rt
    subst Q C
    have ht := hc.substOk.annotation (Ty.Annotation.mk hwf hsort hdecl)
    exact .C_Sub hh (hl.bind (valEnv cap.env) hc.transport)
      (he.bind (valEnv cap.env)) ht.wf ht.sorted ht.declared
  | .C_Normal hb =>
    have hh := hb.close_method_aux hP hPB hB hw hs hd hc hQ hC hm Rt
    simpa only [Capture.closeTy,substTyValues_norm_source] using hh
  | .C_Eff hb he =>
    have hh := hb.close_method_aux hP hPB hB hw hs hd hc hQ hC hm Rt
    subst Q C
    exact .C_Eff hh (he.bind (valEnv cap.env))
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_App .. | .C_DependentApp .. |
    .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

theorem ClosureTy.method_view_typed {P B Ψ R q a e v name ss es ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .meth v name ss es ws) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.meth v name ss es ws) a e [] := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,hl,hr,rfl,rfl,hrs⟩ := hq.open_zero
  cases m
  case meth v0 name0 ss0 es0 ws0 =>
    have hh := hb.close_method_aux hP hPB hB hw hs hd hc rfl rfl rfl R
    have he : (Comp.meth v0 name0 ss0 es0 ws0).resolveLocals ρ = .meth v0 name0 ss0 es0 ws0 := by
      have hm := hb.read_values
      have hf : v0.resolveLocals ρ = v0 := (hm _ List.mem_cons_self).choose_spec.resolve_id ρ
      have hvs : Val.resolveLocalsList ρ ws0 = ws0 := by
        rw [Val.resolveLocalsList_eq_map]
        have he : ws0.map (fun v => v.resolveLocals ρ) = ws0.map id := List.map_congr_left
          (fun v hv => (hm v (List.mem_cons_of_mem _ hv)).choose_spec.resolve_id ρ)
        simpa only [List.map_id] using he
      simp only [Comp.resolveLocals,hf,hvs]
    rw [he] at hv
    cases hv
    exact hh
  case checkAt k o sh bs p v ix =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)
  all_goals (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)

end
end Benitoite.Release.Refinement
