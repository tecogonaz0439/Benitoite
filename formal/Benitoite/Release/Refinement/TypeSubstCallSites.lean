import Benitoite.Release.Refinement.TypeSubstMain

/-! # 関数・メソッド・通常節・失敗節の本体への型置換の適用 -/
namespace Benitoite.Release.Refinement
set_option maxHeartbeats 2000000

theorem CaptureContextRegular.empty (P : Program) (C : TypeCtx) : CaptureContextRegular P C [] := ⟨by intro i a hi; simp at hi,by intro i a hi; simp at hi⟩

theorem CaptureContextRegular.bindParams_empty {P C ps}
    (ha : TypeAnnotations P C [] ps) : CaptureContextRegular P C (bindParams [] ps) := by
  have hx (i : Nat) (a : Ty) (hi : (bindParams [] ps)[i]? = some (some a)) :
      Ty.Annotation P C (bindParams [] ps) a := by
    have hm : some a ∈ bindParams [] ps := List.mem_of_getElem? hi
    simp only [bindParams,List.map_nil,List.append_nil,List.mem_map,List.mem_reverse] at hm
    obtain ⟨b,hb,he⟩ := hm
    cases he
    exact (ShiftMap.outer [] ps).annotation (ha b hb)
  exact ⟨fun i a hi => (hx i a hi).wf.capture,
    fun i a hi => ⟨(hx i a hi).sorted.capture,(hx i a hi).declared.capture⟩⟩

theorem hideBuilders_idem (Ψ : StoreTy) : hideBuilders (hideBuilders Ψ) = hideBuilders Ψ := by
  funext l
  simp only [hideBuilders]
  cases h : Ψ l with
  | none => rfl
  | some x => cases x <;> rfl

theorem HasTypeVQ.fun_body_input {P B Ψ Q C Γ Φ v a f ts es d}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hC : C = []) (hΓ : Γ = []) (hv : v = .fnRef f ts es)
    (hd : P.defs f = some d) :
    SignatureInstance P [] [] d.tel (TypeCtx.kinds d.tparams) ts es ∧
    Admissible B [] 0 (TypeCtx.constraints d.tparams) d.neffs (Qsig d.params d.ret d.eff) Q ts es d.eff := by
  match h with
  | .V_Fun hl _ ha hs =>
    cases hC; cases hΓ; cases hv
    have he := Option.some.inj (hl.symm.trans hd)
    subst he
    exact ⟨hs,ha⟩
  | .V_Sub hv' .. | .V_Normal hv' | .V_Refine hv' .. => exact hv'.fun_body_input hC hΓ hv hd
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Op .. |
    .V_Prim .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
    .V_List .. => cases hv
termination_by structural h

theorem type_subst_fun_body {P B Ψ Φ0 callerTy f d ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P)
    (hd : P.defs f = some d)
    (hcall : HasTypeVQ P B Ψ Qempty [] [] Φ0 (.fnRef f ts es) callerTy) :
    TelBodyTy P B StoreTy.empty Qempty [] [] [] (Tel.substAt 0 ts es d.tel) (d.body.substTy ts es) := by
  obtain ⟨hi,ha⟩ := hcall.fun_body_input rfl rfl rfl hd
  have wt := hf.2.1.defs f d hd
  have inp : ClosedTypeSubstInput P B d.tparams [] [] ts es :=
    {toTypeSubstInput := hi.closedInput ha.types,context := CaptureContextRegular.empty P d.tparams}
  have hq : RowTransport (QTel d.tel) Qempty es := by
    rw [Def.QTel_eq_Qsig d wt.1]
    exact ha.noFailRows
  exact type_subst_body ⟨hf.1,hf.2.1,hf.2.2,StoreTy.WF.empty⟩ inp
    (Or.inr ⟨0,d.ntys,d.neffs,d.params.length,(hf.1.defs f d hd).2.2⟩) hq wt.2.2.2

theorem type_subst_method_body {P B Ψ Q Φ R a e L i us vs name ss fs ws}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hcall : HasTypeCQ P B Ψ Q [] [] Φ R (.meth (.dict i us vs) name ss fs ws) a e L) :
    ∃ id cl cd ms body,
      P.impls i = some id ∧ P.classes cl = some cd ∧ cd.methods name = some ms ∧
      id.cls = cl ∧ id.methods name = some body ∧
      TelBodyTy P B StoreTy.empty Q []
        ((bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))).bindTypes (typeEnvAt 0 (ss++us) fs)) []
        (Tel.substAt 0 (ss++us) fs (Tel.shiftV id.dictTys.length 0
          (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)))
        (body.substTy (ss++us) fs) := by
  obtain ⟨id,cl,cd,ms,τ,hl,hcl,hm,hcls,_,_,hi,_,hq⟩ := hcall.method_body_input rfl
  have hwt := hf.2.1.impls i id hl
  rw [←hcls] at hcl
  obtain ⟨body,hbody,hn,hb⟩ := hwt.method_body hcl hm
  have htypes : TypeAnnotations P (TypeCtx.values id.tparams) [] id.dictTys := hwt.choose_spec.2.2.2.2.1
  have hr : TypeParamRenaming (TypeCtx.values id.tparams)
      (ms.tparams ++ TypeCtx.values id.tparams) (shiftIndex ms.tparams.length 0) := by
    simpa only [List.nil_append,List.length_nil] using TypeParamRenaming.insert [] ms.tparams (TypeCtx.values id.tparams)
  have hdicts : TypeAnnotations P (ms.tparams ++ TypeCtx.values id.tparams) []
      (id.dictTys.map (Ty.shift ms.tparams.length 0)) := by
    intro x hx
    obtain ⟨a,ha,rfl⟩ := List.mem_map.mp hx
    have hm : TypeCtxMap ms.tparams.length 0 [] [] := ⟨rfl,by intro i a hi; simp at hi⟩
    have hh := hm.annotation (by simp [TypeCtx.values]; omega) (htypes a ha) hr
    simpa only [Ty.shift,Ty.bind,Ty.rawBind_shiftTypes] using hh.norm
  have inp : ClosedTypeSubstInput P B (ms.tparams ++ TypeCtx.values id.tparams) []
      (bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))) (ss++us) fs :=
    {toTypeSubstInput := hi,context := CaptureContextRegular.bindParams_empty hdicts}
  have hc : TypeSubstCode fs (fun nr nt ne nv => body.SourceScoped nr nt ne nv) :=
    Or.inr ⟨0,ms.tparams.length+id.tparams.length,ms.neffs,id.dictTys.length+ms.params.length,
      (hf.1.impls i id hl).2.2.2.2.2.2 cd name ms body hcl hm hbody⟩
  refine ⟨id,id.cls,cd,ms,body,hl,hcl,hm,rfl,hbody,?_⟩
  have hq' : RowTransport (Qsig ms.params ms.ret ms.eff) Q fs := by
    rwa [MethSig.QTel_eq_Qsig ms hn] at hq
  exact type_subst_body ⟨hf.1,hf.2.1,hf.2.2.1,StoreTy.WF.empty⟩ inp hc hq' hb

theorem HasTypeVQ.op_body_input {P B Ψ Q C Γ Φ v a o ts od}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hC : C = []) (hΓ : Γ = []) (hv : v = .op o ts)
    (hl : P.ops o = some od) : TypeSubstInput P B (TypeCtx.values od.tparams) [] ts [] := by
  match h with
  | .V_Op (od := od') hl' _ hs hi =>
    cases hC; cases hΓ; cases hv
    have hd : od' = od := Option.some.inj (hl'.symm.trans hl)
    subst od'
    apply SignatureInstance.closedInput (ts := ts) (es := []) (t := od.tel)
      (by simpa only [TypeCtx.kinds,TypeCtx.values,List.map_map,Function.comp_def,
        embedTParam,List.map_const'] using hi)
      (by simpa [TypeCtx.constraints,TypeCtx.values,Function.comp_def,embedTParam] using hs)
  | .V_Sub hv' .. | .V_Normal hv' | .V_Refine hv' .. => exact hv'.op_body_input hC hΓ hv hl
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. |
    .V_Prim .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
    .V_List .. => cases hv
termination_by structural h

theorem type_subst_op_body {P B Ψ Q Φ0 Γ Φ body t e ts callerTy o eb} {R : Option Ty} {sg : OpSig}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hcall : HasTypeVQ P B Ψ Q [] [] Φ0 (.op o ts) callerTy)
    (hselected : ClauseSig P B eb (.user o) sg)
    (hb : HasTypeCQ P B (hideBuilders Ψ) Q sg.tparams (sg.context Γ t e)
      (liftMany (sg.params.length+1) Φ)
      (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)) body
      ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0)
      ((shiftRowsTypes sg.tparams.length 0 e).shiftV (sg.params.length+1) 0) []) :
    HasTypeCQ P B (hideBuilders Ψ) Q [] ((sg.context Γ t e).bindTypes (typeEnvAt 0 ts []))
      (liftMany (sg.params.length+1) Φ)
      ((R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)).map (Ty.substAt 0 ts []))
      (body.substTy ts [])
      (((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0).substAt 0 ts [])
      (Eff.substAt 0 ts [] ((shiftRowsTypes sg.tparams.length 0 e).shiftV (sg.params.length+1) 0)) [] := by
  obtain ⟨S,_,hl,_⟩ := hselected
  simp only [opSigAt] at hl
  obtain ⟨d,hd,rfl⟩ := Option.map_eq_some_iff.mp hl
  have inp : TypeSubstInput P B (TypeCtx.values d.tparams) [] ts [] := hcall.op_body_input rfl rfl rfl hd
  exact S02Internal.substC (C0 := TypeCtx.values d.tparams) (C1 := []) ⟨hf.1,hf.2.1,hf.2.2.1,hf.2.2.2.hide⟩ inp (Or.inl rfl)
    (by
      intro i hi
      constructor
      · rfl
      · intro j hj
        have he : j = i := by simpa [Eff.row,Eff.mem,Eff.test,Eff.atoms] using hj
        exact he ▸ hi) hb

theorem type_subst_opfail_body {P B Ψ Q Φ0 Γ Φ T E0 Es callerTy body a e} {R : Option Ty}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hcall : HasTypeVQ P B Ψ Q [] [] Φ0 (.raise T E0) callerTy)
    (hb : HasTypeCQ P B (hideBuilders Ψ) Q [TypeCtx.valueParam] (failureContext Γ Es) (liftMany 2 Φ)
      (R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)) body
      ((shiftTypes 1 0 a).shiftV 2 0) (Eff.shiftV 2 0 (shiftRowsTypes 1 0 e)) []) :
    HasTypeCQ P B (hideBuilders Ψ) Q [] ((failureContext Γ Es).bindTypes (typeEnvAt 0 [T] [])) (liftMany 2 Φ)
      ((R.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)).map (Ty.substAt 0 [T] []))
      (body.substTy [T] []) (((shiftTypes 1 0 a).shiftV 2 0).substAt 0 [T] [])
      (Eff.substAt 0 [T] [] (Eff.shiftV 2 0 (shiftRowsTypes 1 0 e))) [] := by
  have base := fail_input hf.2.2.1 hcall
  exact S02Internal.substC (C0 := [TypeCtx.valueParam]) (C1 := []) ⟨hf.1,hf.2.1,hf.2.2.1,hf.2.2.2.hide⟩
    base.toTypeSubstInput (Or.inl rfl)
    (by
      intro i hi
      constructor
      · rfl
      · intro j hj
        have he : j = i := by simpa [Eff.row,Eff.mem,Eff.test,Eff.atoms] using hj
        exact he ▸ hi) hb

theorem HasTypeClausesQ.findClause_body {P B Ψ Q Γ Φ Rs eb cs t ecs o c}
    (hcs : HasTypeClausesQ P B Ψ Q [] Γ Φ Rs eb cs t ecs [])
    (hc : findClause cs o = some c) :
    ∃ (sg : OpSig) (n k : Nat) (body : Comp), c = .mk o n k body ∧ ClauseSig P B eb o sg ∧
      HasTypeCQ P B (hideBuilders Ψ) Q sg.tparams (sg.context Γ t ecs)
        (liftMany (sg.params.length+1) Φ)
        (Rs.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)) body
        ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0)
        ((shiftRowsTypes sg.tparams.length 0 ecs).shiftV (sg.params.length+1) 0) [] := by
  induction cs with
  | nil => cases hc
  | cons x cs ih =>
    cases hcs with
    | cons hs hn hn1 hk hw hb hrest =>
      rename_i o' n' k' body' sg'
      simp only [findClause,List.find?_cons] at hc
      by_cases he : o' = o
      · subst he
        simp only [Clause.op,beq_self_eq_true,Option.some.injEq] at hc
        subst hc
        exact ⟨sg',n',k',body',rfl,hs,by simpa only [List.append_nil] using hb⟩
      · have hne : (Clause.op (Clause.mk o' n' k' body') == o) = false := by
          simp [Clause.op,he]
        simp only [hne] at hc
        exact ih hrest hc

theorem type_subst_e_op_site {P B Ψ Φ0 Γ Φ Rs ebs h t ecs o ts c callerTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hcall : HasTypeVQ P B Ψ Qempty [] [] Φ0 (.op o ts) callerTy)
    (hcs : HasTypeClausesQ P B (hideBuilders Ψ) Qempty [] Γ Φ Rs ebs h t ecs [])
    (hc : findClause h (.user o) = some c) :
    ∃ sg : OpSig, HasTypeCQ P B (hideBuilders Ψ) Qempty [] ((sg.context Γ t ecs).bindTypes (typeEnvAt 0 ts []))
      (liftMany (sg.params.length+1) Φ)
      ((Rs.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)).map (Ty.substAt 0 ts []))
      (c.body.substTy ts [])
      (((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0).substAt 0 ts [])
      (Eff.substAt 0 ts [] ((shiftRowsTypes sg.tparams.length 0 ecs).shiftV (sg.params.length+1) 0)) [] := by
  obtain ⟨sg,n,k,body,rfl,hs,hb⟩ := HasTypeClausesQ.findClause_body hcs hc
  rw [hideBuilders_idem] at hb
  exact ⟨sg,type_subst_op_body hf hcall hs hb⟩

theorem type_subst_e_opfail_site {P B Ψ Φ0 Γ Φ Rs Es h t ecs T E0 E body callerTy}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hcall : HasTypeVQ P B Ψ Qempty [] [] Φ0 (.raise T E0) callerTy)
    (hcs : HasFailureClause P B (hideBuilders Ψ) Qempty [] Γ Φ Es Rs h t ecs [])
    (hh : h = [.fail E body]) :
    HasTypeCQ P B (hideBuilders Ψ) Qempty [] ((failureContext Γ Es).bindTypes (typeEnvAt 0 [T] [])) (liftMany 2 Φ)
      ((Rs.map (fun r => (shiftTypes 1 0 r).shiftV 2 0)).map (Ty.substAt 0 [T] []))
      (body.substTy [T] []) (((shiftTypes 1 0 t).shiftV 2 0).substAt 0 [T] [])
      (Eff.substAt 0 [T] [] (Eff.shiftV 2 0 (shiftRowsTypes 1 0 ecs))) [] := by
  cases hcs with
  | one _ _ _ hb =>
    cases hh
    rw [hideBuilders_idem] at hb
    exact type_subst_opfail_body hf hcall hb

end Benitoite.Release.Refinement
