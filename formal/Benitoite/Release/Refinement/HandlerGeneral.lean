import Benitoite.Release.Refinement.MatchStateLeaves
import Benitoite.Release.Refinement.BuiltinEffects
import Benitoite.Release.Refinement.RuntimeTypeSubst
import Benitoite.Release.Refinement.HeldValues
import Benitoite.Release.Refinement.RangeFormation

/-! # 捕捉を保持する handler の状態の葉 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem clauses_hide_empty {P B Ψ Q C Γ Φ R eb cs t e L}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) :
    HasTypeClausesQ P B (hideBuilders Ψ) Q C Γ Φ R eb cs t e [] := by
  match h with
  | .nil => exact .nil
  | .cons hs hn hn1 hk hw hb ht =>
    exact .cons hs hn hn1 hk hw (by rw [hideBuilders_idem]; exact hb) (clauses_hide_empty ht)
termination_by structural h

private theorem failure_hide_empty {P B Ψ Q C Γ Φ E R cs t e L}
    (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) :
    HasFailureClause P B (hideBuilders Ψ) Q C Γ Φ E R cs t e [] := by
  cases h with
  | one hE ht he hb => exact .one hE ht he (by rw [hideBuilders_idem]; exact hb)

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e := by
  constructor
  · intro a ha; cases ha
  · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu

private theorem handler_tail {P B σ Ψ R e k a b Eb Re cap cs}
    (h : ContTy P B σ Ψ R e (.handleF cap cs :: k) a b Eb Re) :
    ∃ t et, Ty.LeQ P [] [] a t ∧ ContTy P B σ Ψ R et k t b Eb Re := by
  generalize he : (.handleF cap cs :: k) = frames at h
  induction h with
  | K_Handle ht _ _ _ _ _ _ _ _ _ _ _ _ => cases he; exact ⟨_,_,.refl,ht⟩
  | K_Handle_Fail ht _ _ _ _ _ _ _ _ _ _ _ _ _ => cases he; exact ⟨_,_,.refl,ht⟩
  | K_Sub _ hl ih =>
    obtain ⟨t,et,hle,ht⟩ := ih he
    exact ⟨t,et,.trans hl hle,ht⟩
  | _ => cases he

private theorem union_left_sub (e f : Eff) : Eff.Sub e (Eff.union e f) :=
  ⟨fun _ ha => (Eff.mem_union_iff _ _ _).mpr (Or.inl ha),
    fun _ ht => (Eff.memFail_union_iff _ _ _).mpr (Or.inl ht)⟩

private theorem union_right_sub (e f : Eff) : Eff.Sub f (Eff.union e f) :=
  ⟨fun _ ha => (Eff.mem_union_iff _ _ _).mpr (Or.inr ha),
    fun _ ht => (Eff.memFail_union_iff _ _ _).mpr (Or.inr ht)⟩

theorem StateTyE.handle_step {P B σ Eb q k μ m cs}
    (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .handle m cs) :
    StateTyE P B σ Eb (.run (.mk q.capture m) (.handleF q.capture cs :: k) μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμc⟩ := h
  have hann := hq.annotation
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,rfl,hcap,hcode,hL,hR,ha,hee,hr⟩ := hq.open_zero
  have hform : ∃ m0 h0, code0 = .handle m0 h0 := by
    cases code0
    case handle => exact ⟨_,_,rfl⟩
    case checkAt _ _ _ bs _ _ _ =>
      exfalso; cases bs <;> (simp only [Comp.resolveLocals] at hv; injection hv)
    all_goals (exfalso; simp only [Comp.resolveLocals] at hv; injection hv)
  obtain ⟨m0,h0,rfl⟩ := hform
  rw [←ha,←hee] at hann
  have hchide := hcap.store hB.values hs.wf (StoreTy.preserves_hide Ψ)
  rcases handle_inv hcode rfl with ⟨t,eb,ec,hbody,hsub,hcs,hcov,hle⟩ |
      ⟨t,E,eb,rest,ec,hbody,hsub,hn,hcs,hcov,hle⟩
  · simp only [Comp.resolveLocals,hcs.resolve_id ρ,Closure.view,Closure.code] at hv
    obtain ⟨rfl,rfl⟩ := Comp.handle.inj hv
    change cap.Adequate σ ∧ (m0.resolveLocals ρ).Adequate σ ∧ adequateClauses σ (Clause.resolveLocalsList ρ h0) at had
    change cap.Closed ∧ (m0.resolveLocals ρ).ClosedAt 0 cap.values.length ∧ Clause.ClosedList 0 cap.values.length (Clause.resolveLocalsList ρ h0) at hcl
    rw [hcs.resolve_id ρ] at had hcl
    have hresult := capture_comp_annotation hs.wf hs.sorted hs.declared hcap hbody
    have hu := done_inner hann hresult hcov
    have hbann := capture_handle_body_annotation hu hsub
    have hbody' := ClosureTy.capture_resolved_closed hcap hbody hL hbann hR hr
    have hopen := open_comp_annotation hs.wf hs.sorted hs.declared hcap.contextRegular hbody
    have hclosedsub : Eff.Sub (cap.closeEff eb) (Eff.union (cap.closeEff ec) (handled P B h0)) := by
      simpa only [Capture.closeEff,←substEffValues_eq_bind,substEffValues_union,handled_subst_values]
        using hsub.bind (valEnv cap.env)
    have hclosedcov : Eff.Covers [] [] e (cap.closeEff ec) :=
      he.covers.trans (by rw [←hee]; exact hcov.bind (valEnv cap.env))
    have hle' := hle.bind (valEnv cap.env) hcap.transport
    change Ty.LeQ P [] [] (cap.closeTy t) (cap.closeTy as) at hle'
    rw [ha] at hle'
    have hcont := ContTy.K_Handle (.K_Sub hk hle') hclosedcov hclosedsub hchide
      (clauses_hide_empty hcs) hR rfl rfl rfl hu hopen hr
      (show Frame.Adequate σ (.handleF cap h0) from ⟨had.1,had.2.2⟩)
    exact ⟨Ψ,R,cap.closeTy t,b,cap.closeEff eb,cap.closeEff eb,hs,hbody',
      ⟨fun _ h => h,fun _ h => h⟩,hcont,⟨had.1,had.2.1⟩,⟨hcl.1,hcl.2.1⟩,
      (by intro f hf; rcases List.mem_cons.mp hf with rfl | hf
          · exact ⟨hcl.1,hcl.2.2⟩
          · exact hkc f hf),hμc⟩
  · simp only [Comp.resolveLocals,hcs.resolve_id ρ,Closure.view,Closure.code] at hv
    obtain ⟨rfl,rfl⟩ := Comp.handle.inj hv
    change cap.Adequate σ ∧ (m0.resolveLocals ρ).Adequate σ ∧ adequateClauses σ (Clause.resolveLocalsList ρ h0) at had
    change cap.Closed ∧ (m0.resolveLocals ρ).ClosedAt 0 cap.values.length ∧ Clause.ClosedList 0 cap.values.length (Clause.resolveLocalsList ρ h0) at hcl
    rw [hcs.resolve_id ρ] at had hcl
    have hu := hcs.capture_result_effect hcap
    have hbann := capture_failure_body_annotation hcap hcs hn hsub
    have hbody' := ClosureTy.capture_resolved_closed hcap hbody hL hbann hR hr
    have hclosedsub : Eff.Sub (cap.closeEff eb) (Eff.union (Eff.singleFail (cap.closeTy E)) (cap.closeEff rest)) := by
      simpa only [Capture.closeEff,Capture.closeTy,←substEffValues_eq_bind,substEffValues_union,substEffValues_singleFail]
        using hsub.bind (valEnv cap.env)
    have hclosedcov : Eff.Covers [] [] e (Eff.union (cap.closeEff rest) (cap.closeEff ec)) := by
      apply he.covers.trans
      rw [←hee]
      simpa only [Capture.closeEff,←substEffValues_eq_bind,substEffValues_union] using hcov.bind (valEnv cap.env)
    have hle' := hle.bind (valEnv cap.env) hcap.transport
    change Ty.LeQ P [] [] (cap.closeTy t) (cap.closeTy as) at hle'
    rw [ha] at hle'
    have hcont := ContTy.K_Handle_Fail (.K_Sub hk hle')
      (hclosedcov.trans (union_left_sub _ _).covers) (hn.subst_values cap.env) hchide
      (failure_hide_empty hcs) hR rfl rfl rfl hr
      (hclosedcov.trans (union_right_sub _ _).covers)
      ⟨hu.wf.1,hu.sorted.1,hu.declared.1⟩
      (show Frame.Adequate σ (.handleF cap h0) from ⟨had.1,had.2.2⟩)
    obtain ⟨hwide,hwideSub⟩ := hbody'.widen_atoms hclosedsub.covers
    exact ⟨Ψ,R,cap.closeTy t,b,_,_,hs,hwide,hwideSub,hcont,⟨had.1,had.2.1⟩,⟨hcl.1,hcl.2.1⟩,
      (by intro f hf; rcases List.mem_cons.mp hf with rfl | hf
          · exact ⟨hcl.1,hcl.2.2⟩
          · exact hkc f hf),hμc⟩

theorem StateTyE.handler_return {P B σ Eb q v cap cs k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q (.handleF cap cs :: k) μ)) (hv : q.view = .ret v) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμc⟩ := h
  obtain ⟨t,et,hle,ht⟩ := handler_tail hk
  have hvt := hq.ret_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have ha : Ty.Annotation P [] [] a := ⟨hq.annotation.wf.1,hq.annotation.sorted.1,hq.annotation.declared.1⟩
  obtain ⟨R',hRn,ht⟩ := ht.normal_return_tail rfl a ha hq.result_normal hle
  have hr := ContTy.return_annotation ht rfl
  have hq' := ClosureTy.pure (.C_Return (R := R') hvt) ha.done_empty
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) hq.result_normal hRn
  have hva := Closure.view_adequate had
  rw [hv] at hva
  have hvg : v.Ground := hq.view_read_ground hcl (by rw [hv]; exact List.mem_cons_self)
  exact ⟨Ψ,R',a,b,et,Eff.empty,hs,hq',empty_sub et,ht,
    ⟨trivial,hva⟩,⟨trivial,hvg⟩,(fun f hf => hkc f (List.mem_cons_of_mem _ hf)),hμc⟩

private theorem shifted_type_cancel (a : Ty) (ts : List Ty) :
    (shiftTypes ts.length 0 a).substAt 0 ts [] = a.norm := by
  change ((shiftTypes ts.length 0 a).rawBind (typeEnvAt 0 ts [])).norm = _
  rw [Ty.rawBind_shift_source]
  have he : {typeEnvAt 0 ts [] with types := fun i => (typeEnvAt 0 ts []).types (i+ts.length)} = renEnv id := by
    simp only [typeEnvAt,renEnv]
    congr 1
    funext i
    simp only [Nat.not_lt_zero,↓reduceIte,Nat.sub_zero]
    split <;> rename_i h
    · omega
    · simp only [Nat.add_sub_cancel]
  rw [he,Ty.rawBind_id]

private theorem shifted_eff_cancel (e : Eff) (ts : List Ty) :
    Eff.substAt 0 ts [] (shiftRowsTypes ts.length 0 e) = e.norm := by
  have h := shifted_type_cancel (.cont (.base .unit) (.base .unit) e) ts
  exact (Ty.cont.inj h).2.2

private theorem shifted_context_cancel (Γ : Ctx) (ts : List Ty) :
    (Γ.shiftE ts.length).bindTypes (typeEnvAt 0 ts []) = Γ.map (Option.map Ty.norm) := by
  simp only [Ctx.shiftE,Ctx.shiftEAt,Ctx.bindTypes,List.map_map,Function.comp_def,Option.map_map]
  apply List.map_congr_left
  intro a _
  cases a with
  | none => rfl
  | some a => exact congrArg some (shifted_type_cancel a ts)

private theorem norm_context_lookup {Γ : Ctx} {i : Nat} {a : Ty}
    (hi : (Γ.map (Option.map Ty.norm))[i]? = some (some a)) :
    ∃ b, Γ[i]? = some (some b) ∧ b.norm = a := by
  simp only [List.getElem?_map] at hi
  cases hb : Γ[i]? with
  | none => simp [hb] at hi
  | some b => cases b with
    | none => simp [hb] at hi
    | some b => exact ⟨b,rfl,by simpa only [hb,Option.map_some,Option.some.injEq] using hi⟩

private theorem norm_context_eq (Γ : Ctx) : Γ.NormEq (Γ.map (Option.map Ty.norm)) := by
  simp only [Ctx.NormEq,List.map_map,Function.comp_def,Option.map_map,Ty.norm_idem]

private theorem capture_normal {P B Ψ R Γ Φ cap} (hc : CaptureOk P B Ψ R Γ Φ cap) :
    CaptureOk P B Ψ R (Γ.map (Option.map Ty.norm)) Φ cap := by
  have hn := norm_context_eq Γ
  have hd := hn.declaration (P := P) (B := B) (C := [])
  cases hc with
  | mk hw hl hv hs hf hg hi hfacts =>
    refine .mk ?_ (by simpa only [List.length_map] using hl) ?_ ?_ ?_ hg ?_ ?_
    · intro i a ha
      obtain ⟨b,hb,rfl⟩ := norm_context_lookup ha
      have h := hw i b hb
      simp only [List.length_map]
      cases b with
      | cont => exact ⟨Ty.wf_norm h.1,Ty.wf_norm h.2⟩
      | _ => exact (Ty.wf_norm h).capture
    · intro i a ha
      obtain ⟨b,hb,rfl⟩ := norm_context_lookup ha
      exact hv i b hb
    · intro i a ha
      obtain ⟨b,hb,rfl⟩ := norm_context_lookup ha
      obtain ⟨hs,hd'⟩ := hs i b hb
      cases b with
      | cont => exact ⟨⟨(Ty.sorted_norm hs.1).sortMap hn.sortMap,(Ty.sorted_norm hs.2).sortMap hn.sortMap⟩,
          ⟨hd'.1.norm.context hd,hd'.2.norm.context hd⟩⟩
      | _ => exact ⟨((Ty.sorted_norm hs).sortMap hn.sortMap).capture,(hd'.norm.context hd).capture⟩
    · intro p hp
      obtain ⟨hw,hs,hd'⟩ := hf p hp
      have hh := (Pred.WellFormed.mk hw hs hd').map hn.sortMap.values hn.sortMap.references hd
      simpa only [renEnv_values,id_eq,predBind_id] using And.intro hh.wf (And.intro hh.sorted hh.declared)
    · intro i a ha
      obtain ⟨b,hb,rfl⟩ := norm_context_lookup ha
      cases hi i b hb with
      | ordinary ho ht =>
        exact .ordinary ((Ty.ordinary_norm _).mpr ho) (by rw [substTyValues_norm_source]; exact ht)
      | hidden ho hn =>
        have hwb : b.WF 0 0 Γ.length := by
          cases b <;> first | exact hw i _ hb | exact False.elim (hn _ _ _ rfl)
        exact False.elim (ho (Ty.WF.ordinary_of_not_cont hwb hn))
      | contLoc he hs hw hv hl hr =>
        subst b
        exact .contLoc rfl (by rw [substTyValues_norm_source]; exact hs)
          (by rw [substTyValues_norm_source]; exact hw) hv hl hr
      | contVar he hv hj =>
        obtain ⟨_,_,_,hj,_⟩ := hj
        simp at hj
    · intro p hp
      rw [←hn.facts] at hp
      exact hfacts p hp

private theorem type_env_up {ts : List Ty} (ht : ∀ t ∈ ts, t.WF 0 0 0) :
    (typeEnvAt 0 ts []).up = typeEnvAt 0 ts [] := by
  rw [typeEnvAt_up,map_typeImages_shiftV_closed ht]
  rfl

private theorem signature_inst (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    {ts : List Ty} (ht : ∀ t ∈ ts, t.WF 0 0 0) :
    Tel.bind (typeEnvAt 0 ts []) (signatureTel ns ps r e) =
      signatureTel ns (ps.map (Ty.substAt 0 ts [])) (r.substAt 0 ts []) (Eff.substAt 0 ts [] e) := by
  induction ns generalizing ps with
  | nil => rfl
  | cons n ns ih =>
    cases ps with
    | nil => rfl
    | cons a ps =>
      simp only [signatureTel,Tel.bind_param,type_env_up ht,List.map_cons,ih]
      rfl

private theorem signature_inputs (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : ns.length = ps.length) : (signatureTel ns ps r e).inputs = ps := by
  induction ns generalizing ps with
  | nil => cases ps <;> simp_all [signatureTel,Tel.inputs]
  | cons n ns ih =>
    cases ps with
    | nil => simp at hn
    | cons a ps => simp only [signatureTel,Tel.inputs,ih _ (Nat.succ.inj hn)]

private theorem signature_result (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) :
    (signatureTel ns ps r e).result = r := by
  induction ns generalizing ps with
  | nil => rfl
  | cons n ns ih => cases ps <;> simp_all [signatureTel,Tel.result]

private theorem tel_extend_eq (t : Tel) (Γ : Ctx) : telExtend Γ t = t.context Γ := by
  cases t with
  | done => rfl
  | param n a t => exact tel_extend_eq t _
termination_by structural t

private theorem tel_lift_eq (t : Tel) (Φ : List Pred) : telLift Φ t = liftMany t.arity Φ := by
  cases t with
  | done => rfl
  | param n a t =>
    simp only [telLift,tel_lift_eq t,Tel.arity,Tel.names,List.length_cons]
    simpa only [liftMany_one,Tel.arity,Nat.add_comm 1] using (liftMany_add 1 t.arity Φ)
termination_by structural t

private theorem clause_selected {P B Ψ Q Γ Φ R eb cs t ec o c}
    (hcs : HasTypeClausesQ P B Ψ Q [] Γ Φ R eb cs t ec [])
    (hc : findClause cs o = some c) :
    ∃ (sg : OpSig) (body : Comp), c = .mk o sg.params.length sg.tparams.length body ∧
      ClauseSig P B eb o sg ∧ NamesWF sg.names sg.params ∧ sg.WF ∧
      HasTypeCQ P B (hideBuilders Ψ) Q sg.tparams (sg.context Γ t ec)
        (liftMany (sg.params.length+1) Φ)
        (R.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)) body
        ((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0)
        ((shiftRowsTypes sg.tparams.length 0 ec).shiftV (sg.params.length+1) 0) [] := by
  match hcs with
  | .nil => cases hc
  | .cons (o := o') (n := n) (k := k) (body := body) (sg := sg) hs hnames hn hk hw hb ht =>
    simp only [findClause,List.find?_cons] at hc
    by_cases he : o' = o
    · subst o'
      simp only [Clause.op,beq_self_eq_true,Option.some.injEq] at hc
      subst c
      subst n k
      exact ⟨sg,body,rfl,hs,hnames,hw,by simpa only [List.append_nil] using hb⟩
    · have hne : (Clause.op (.mk o' n k body) == o) = false := by simp [Clause.op,he]
      simp only [hne] at hc
      exact clause_selected ht hc
termination_by structural cs

private theorem op_context_inst {P B C ts} (hi : TypeSubstInput P B C [] ts [])
    (sg : OpSig) (Γ : Ctx) (t : Ty) (e : Eff) (hn : ts.length = sg.tparams.length) :
    (sg.context Γ t e).bindTypes (typeEnvAt 0 ts []) =
      (Ctx.extendMany (Γ.map (Option.map Ty.norm)) (sg.params.map (Ty.substAt 0 ts []))).extend
        (.cont (sg.ret.substAt 0 ts []) (t.norm.shiftV sg.params.length 0)
          (e.norm.shiftV sg.params.length 0)) := by
  simp only [OpSig.context,Ctx.bindTypes_extend hi,Ctx.bindTypes_extendMany hi,←hn,
    shifted_context_cancel]
  congr 1
  simp only [OpSig.continuation,←hn]
  change Ty.cont (sg.ret.substAt 0 ts [])
    (((shiftTypes ts.length 0 t).shiftV sg.params.length 0).substAt 0 ts [])
    (Eff.substAt 0 ts [] ((shiftRowsTypes ts.length 0 e).shiftV sg.params.length 0)) = _
  rw [substAt_shiftV_closed hi.typeWF hi.rowWF,eff_substAt_shiftV_closed hi.typeWF hi.rowWF,
    shifted_type_cancel,shifted_eff_cancel]

private theorem op_result_inst {P B C ts} (hi : TypeSubstInput P B C [] ts [])
    (a : Ty) (n : Nat) :
    ((shiftTypes ts.length 0 a).shiftV n 0).substAt 0 ts [] = a.norm.shiftV n 0 := by
  rw [substAt_shiftV_closed hi.typeWF hi.rowWF,shifted_type_cancel]

private theorem op_effect_inst {P B C ts} (hi : TypeSubstInput P B C [] ts [])
    (e : Eff) (n : Nat) :
    Eff.substAt 0 ts [] ((shiftRowsTypes ts.length 0 e).shiftV n 0) = e.norm.shiftV n 0 := by
  rw [eff_substAt_shiftV_closed hi.typeWF hi.rowWF,shifted_eff_cancel]

private theorem annotation_many {P C Γ a} (ha : Ty.Annotation P C Γ a) (ps : List Ty) :
    Ty.Annotation P C (Γ.extendMany ps) (a.shiftV ps.length 0) := by
  induction ps generalizing Γ a with
  | nil => simpa only [Ctx.extendMany,List.length_nil,Ty.shiftV_zero] using ha
  | cons x ps ih =>
    have hh := ih ((ShiftMap.outerValue Γ (some (x.shiftV 1 0))).annotation ha)
    simpa only [Ctx.extendMany,Ctx.extend,List.length_cons,Ty.shiftV_add,Nat.add_comm 1] using hh

private theorem declared_many {P C Γ} {a : Ty} (ha : a.Declared P C Γ) (ps : List Ty) :
    (a.shiftV ps.length 0).Declared P C (Γ.extendMany ps) := by
  induction ps generalizing Γ a with
  | nil => simpa only [Ctx.extendMany,List.length_nil,Ty.shiftV_zero] using ha
  | cons x ps ih =>
    have hh := ih ((ShiftMap.outerValue Γ (some (x.shiftV 1 0))).declared ha)
    simpa only [Ctx.extendMany,Ctx.extend,List.length_cons,Ty.shiftV_add,Nat.add_comm 1] using hh

private theorem extend_many_append (Γ : Ctx) (ps qs : List Ty) :
    Γ.extendMany (ps ++ qs) = (Γ.extendMany ps).extendMany qs := by
  induction ps generalizing Γ with
  | nil => rfl
  | cons x ps ih => exact ih _

private theorem operation_capture {P B Ψ Ψ' R Γ Φ Rs cap ts t ec tb ecb body l r f ws} {sg : OpSig} {srcEff : Eff}
    (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hp : (hideBuilders Ψ).Extends Ψ')
    (hcap : CaptureOk P B (hideBuilders Ψ) R Γ Φ cap)
    (inp : TypeSubstInput P B sg.tparams [] ts [])
    (hinst : Ty.Annotation P [] [] (.dependentFn (instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts [])))
    (hargs : HasTypeTelArgsQ P B Ψ' Qempty [] [] [] ws (instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts []) r f)
    (hg : ∀ w ∈ ws, w.Ground)
    (hb : HasTypeCQ P B Ψ' Qempty []
      (sg.context Γ t ec |>.bindTypes (typeEnvAt 0 ts []))
      (liftMany (sg.params.length+1) Φ)
      ((Rs.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0)).map (Ty.substAt 0 ts []))
      body (((shiftTypes sg.tparams.length 0 t).shiftV (sg.params.length+1) 0).substAt 0 ts [])
      (Eff.substAt 0 ts [] ((shiftRowsTypes sg.tparams.length 0 ec).shiftV (sg.params.length+1) 0)) [])
    (hn : sg.names.length = sg.params.length)
    (hR : cap.closeR Rs = R) (ht : cap.closeTy t = tb) (he : cap.closeEff ec = ecb)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done tb ecb)))
    (has : Ty.Annotation P [] Γ t) (hrs : ∀ a, Rs = some a → a.Declared P [] Γ)
    (hl : Ψ' l = some (.cont r tb ecb R))
    (hrw : ∀ a, R = some a → a.WF 0 0 0) :
    ClosureTy P B Ψ' [] R (.mk (cap.extendMany (ws ++ [.loc l])) body) tb ecb := by
  have hc0 := capture_normal (hcap.store hB.values hw.hide hp.preservesNormals)
  have htel : Ty.Annotation P [] (Γ.map (Option.map Ty.norm)) (.dependentFn (instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts [])) :=
    hinst.closed_context
  have hargscap : HasTypeTelArgsQ P B Ψ' Qempty [] [] [] ws
      (cap.closeTel (instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts [])) r f := by
    rw [Capture.closeTel,Tel.bind_values_of_wf_zero hinst.wf]
    simpa only [instantiatedTel,Tel.bind,Tel.norm_idem] using hargs
  obtain ⟨hc1,hlen⟩ := capture_tel _ hc0 htel hargscap hg
  have hre := result_tel hargscap hlen
  have htelEq := signature_inst sg.names sg.params sg.ret srcEff inp.typeWF
  change instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts [] = _ at htelEq
  have hin : (instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts []).inputs = sg.params.map (Ty.substAt 0 ts []) := by
    rw [htelEq,signature_inputs _ _ _ _ (by simpa only [List.length_map] using hn)]
  have hret : (instantiatedTel (signatureTel sg.names sg.params sg.ret srcEff) ts []).result = sg.ret.substAt 0 ts [] := by
    rw [htelEq,signature_result]
  have hlen' : ws.length = sg.params.length := by
    rw [←Tel.inputs_length,hin,List.length_map] at hlen
    exact hlen
  rw [tel_extend_eq,Tel.context_eq_extendMany,hin,tel_lift_eq,←hlen,hlen'] at hc1
  have htNorm : Ty.Annotation P [] (Γ.map (Option.map Ty.norm)) t.norm :=
    (norm_context_eq Γ).annotation (B := B) has.norm
  have hresult := Tel.annotation_result htel
  rw [Tel.context_eq_extendMany,hin,hret] at hresult
  have hshift := annotation_many htNorm (sg.params.map (Ty.substAt 0 ts []))
  simp only [List.length_map] at hshift
  have hcont : (Ty.cont (sg.ret.substAt 0 ts []) (t.norm.shiftV sg.params.length 0)
      (ec.norm.shiftV sg.params.length 0)).CaptureWF 0 0 _ := ⟨hresult.wf,hshift.wf⟩
  have hcontS : (Ty.cont (sg.ret.substAt 0 ts []) (t.norm.shiftV sg.params.length 0)
      (ec.norm.shiftV sg.params.length 0)).CaptureSorted _ := ⟨hresult.sorted,hshift.sorted⟩
  have hcontD : (Ty.cont (sg.ret.substAt 0 ts []) (t.norm.shiftV sg.params.length 0)
      (ec.norm.shiftV sg.params.length 0)).CaptureDeclared P [] _ := ⟨hresult.declared,hshift.declared⟩
  have hcontEq : (cap.extendMany ws).closeTy (.cont (sg.ret.substAt 0 ts [])
      (t.norm.shiftV sg.params.length 0) (ec.norm.shiftV sg.params.length 0)) = .cont r tb ecb := by
    change Ty.cont ((cap.extendMany ws).closeTy (sg.ret.substAt 0 ts []))
      ((cap.extendMany ws).closeTy (t.norm.shiftV sg.params.length 0))
      ((cap.extendMany ws).closeEff (ec.norm.shiftV sg.params.length 0)) = _
    rw [←hret,←hre.1,←hlen',Capture.closeTy_shift_many,Capture.closeEff_shift_many]
    simp only [Capture.closeTy,Capture.closeEff,substTyValues_norm_source,substEffValues_norm_source] at ht he ⊢
    rw [ht,he]
  have hc2 := hc1.extendCont hcont hcontS hcontD hcontEq (by
      rw [hcontEq]
      exact ⟨hargs.resultAnnotation.wf,ha.wf.1,ha.wf.2⟩) hl hrw
  have hc2' : CaptureOk P B Ψ' R
      ((Ctx.extendMany (Γ.map (Option.map Ty.norm)) (sg.params.map (Ty.substAt 0 ts []))).extend
        (.cont (sg.ret.substAt 0 ts []) (t.norm.shiftV sg.params.length 0) (ec.norm.shiftV sg.params.length 0))) (liftMany (sg.params.length+1) Φ)
      (cap.extendMany (ws ++ [.loc l])) := by
    simpa only [Capture.extendMany,List.foldl_append,List.foldl_cons,List.foldl_nil,
      ←liftMany_one,liftMany_add,Nat.add_comm 1] using hc2
  have hh := op_context_inst inp sg Γ t ec inp.typeCount
  change (sg.context Γ t ec).bindTypes _ = _ at hh
  rw [hh] at hb
  have hnTy : sg.tparams.length = ts.length := inp.typeCount.symm
  simp only [hnTy,op_result_inst inp,op_effect_inst inp,Option.map_map,Function.comp_def] at hb
  have hty : (cap.extendMany (ws ++ [.loc l])).closeTy (t.norm.shiftV (sg.params.length+1) 0) = tb := by
    rw [←show (ws ++ [Val.loc l]).length = sg.params.length+1 by simp [hlen'],Capture.closeTy_shift_many]
    simpa only [Capture.closeTy,substTyValues_norm_source] using ht
  have hef : (cap.extendMany (ws ++ [.loc l])).closeEff (ec.norm.shiftV (sg.params.length+1) 0) = ecb := by
    rw [←show (ws ++ [Val.loc l]).length = sg.params.length+1 by simp [hlen'],Capture.closeEff_shift_many]
    simpa only [Capture.closeEff,substEffValues_norm_source] using he
  have hRs : (cap.extendMany (ws ++ [.loc l])).closeR (Rs.map (fun r => r.norm.shiftV (sg.params.length+1) 0)) = R := by
    cases Rs with
    | none => exact hR
    | some r =>
      change some ((cap.extendMany _).closeTy _) = _
      rw [←show (ws ++ [Val.loc l]).length = sg.params.length+1 by simp [hlen'],Capture.closeTy_shift_many]
      simpa only [Capture.closeR,Capture.closeTy,Option.map_some,substTyValues_norm_source] using hR
  have hrd : ∀ r, (Rs.map (fun r => r.norm.shiftV (sg.params.length+1) 0)) = some r →
      r.Declared P []
        ((Ctx.extendMany (Γ.map (Option.map Ty.norm)) (sg.params.map (Ty.substAt 0 ts []))).extend
          (.cont (sg.ret.substAt 0 ts []) (t.norm.shiftV sg.params.length 0) (ec.norm.shiftV sg.params.length 0))) := by
    intro r hr
    obtain ⟨rr,hrr,rfl⟩ := Option.map_eq_some_iff.mp hr
    have hd := (norm_context_eq Γ).declaration (P := P) (B := B) (C := [])
    have hd0 := (hrs rr hrr).norm.context hd
    have hds := declared_many hd0
      ((sg.params.map (Ty.substAt 0 ts [])) ++
        [.cont (sg.ret.substAt 0 ts []) (t.norm.shiftV sg.params.length 0) (ec.norm.shiftV sg.params.length 0)])
    simpa only [List.length_append,List.length_map,List.length_cons,List.length_nil,Nat.add_zero,
      extend_many_append,Ctx.extendMany] using hds
  have hcl := ClosureTy.capture_resolved_closed hc2' hb (CaptureLocals.empty _ _ LocalRef.bound)
    (by rw [hty,hef]; exact ha) hRs hrd
  rw [hty,hef,hb.resolve_id LocalRef.bound (LocalsFixed.empty _)] at hcl
  exact hcl
private theorem clauses_no_fail {P B Ψ Q C Γ Φ R eb cs t ec L}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ec L) : handles cs .fail = false := by
  match h with
  | .nil => rfl
  | .cons hsig _ _ _ _ _ hcs =>
    have hn := hsig.ne_fail
    have ih := clauses_no_fail hcs
    simp only [handles,List.any_cons,Clause.op,Bool.or_eq_false_iff] at ih ⊢
    exact ⟨Bool.eq_false_iff.mpr (fun hb => hn (beq_iff_eq.mp hb)),ih⟩
termination_by structural h

private theorem covers_state {outer inner : Eff} (h : Eff.Covers [] [] outer inner)
    (hm : inner.mem (.name stateEff (.fixed .top))) : outer.mem (.name stateEff (.fixed .top)) := by
  obtain ⟨a,ha,hcov⟩ := h.1 _ hm
  obtain ⟨ix,rfl⟩ := hcov.name_right
  cases ix with
  | rvar i => cases hcov
  | fixed r =>
    have hr : r = .top := (RangeExpr.covers_top_iff _).mp hcov.2
    rwa [hr] at ha

private theorem handle_no_failure {P B σ Ψ R e frames a b Eb Re cap cs k1 k2} {o : OpRef}
    (h : ContTy P B σ Ψ R e frames a b Eb Re)
    (he : frames = k1 ++ .handleF cap cs :: k2) (hne : o ≠ .fail) (hopen : handles cs o = true) :
    handles cs .fail = false := by
  induction h generalizing k1 with
  | K_Empty _ _ => cases k1 <;> simp at he
  | K_Sub _ _ ih => exact ih he
  | K_Handle ht hc hb hcap hcs hR hty hec heb ha has hr had ih =>
    cases k1 with
    | nil => cases he; exact clauses_no_fail hcs
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Handle_Fail ht hc hn hcap hcs hR hty hec hE hr hcov ha had ih =>
    cases k1 with
    | nil => cases he; cases hcs; simp [handles,Clause.op,Ne.symm hne] at hopen
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Let _ _ _ _ _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Mark _ _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Update _ _ _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Release _ _ _ _ _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Drop _ _ _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih =>
    cases k1 with
    | nil => cases he
    | cons f k1 =>
      simp only [List.cons_append,List.cons.injEq] at he
      exact ih he.2

private theorem clause_closed {cs : List Clause} {op ar nty body nt nv}
    (h : Clause.ClosedList nt nv cs) (hc : Clause.mk op ar nty body ∈ cs) :
    body.ClosedAt (nt+nty) (nv+ar+1) := by
  induction cs with
  | nil => cases hc
  | cons d cs ih =>
    cases d with
    | mk op' ar' nty' body' =>
      rcases List.mem_cons.mp hc with he | hc
      · cases he; exact h.1
      · exact ih h.2 hc
    | fail e body' =>
      rcases List.mem_cons.mp hc with he | hc
      · cases he
      · exact ih h.2.2 hc

private theorem clause_adequate {cs : List Clause} {c : Clause} {σ}
    (h : adequateClauses σ cs) (hc : c ∈ cs) : c.body.Adequate σ := by
  induction cs with
  | nil => cases hc
  | cons d cs ih =>
    cases d <;> rcases List.mem_cons.mp hc with rfl | hc <;> first | exact h.1 | exact ih h.2 hc


private theorem tel_args_store {P B Ψ Ψ' vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    HasTypeTelArgsQ P B Ψ' Qempty [] [] [] vs t a e := by
  match h with
  | .done ha => exact .done ha
  | .param ha hv ht => exact .param ha (hv.store_extend hA hw he) (tel_args_store ht hA hw he)
termination_by structural vs

/-- 実際の操作の全引数・型引数と、選択された節の同じ捕捉を保存する。 -/
theorem StateTyE.operation_all {P B σ Eb q o ts ws k μ k1 cs k2 c l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.op o ts) ws)
    (hsp : SplitAt (.user o) k k1 hcap cs k2) (hc : findClause cs (.user o) = some c)
    (hf : μ l = none) :
    StateTyE P B σ Eb (.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs])))) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hclosed,hkc,hμ⟩ := h
  have hcode := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  obtain ⟨callerTy,hcall⟩ := hcode.read_values (.op o ts) List.mem_cons_self
  obtain ⟨od,hd,hi⟩ := hcall.op_signature
  obtain ⟨r,f,hargs,hle,hcov⟩ := hcode.operation_call_all hd
  have hnf := handle_no_failure hk hsp.1 (by intro hh; cases hh) hsp.2.1
  obtain ⟨t,ec,eb,et,Rh,hks,hkt,hcove,hsub,hframe,_⟩ := hk.split_handle hsp.1 hnf
  obtain ⟨Γ,Φ,Rs,as,ecs,ebs,hcap',hcs,hR,ht,hec,heb,han,has,hRs⟩ := hframe
  obtain ⟨sg,body,rfl,hsg,hn,hw,hbody⟩ := clause_selected hcs hc
  have hsgeq : sg = ⟨TypeCtx.values od.tparams,od.names,od.params,od.ret,od.eff⟩ := by
    obtain ⟨S,_,hl,_⟩ := hsg
    simpa only [opSigAt,hd,Option.map_some,Option.some.injEq] using hl.symm
  subst sg
  have hbody' := type_subst_op_body ⟨hP,hPB,hB,hs.wf⟩ hcall hsg (by
    rw [hideBuilders_idem] at hbody
    exact hbody)
  have hra := hargs.resultAnnotation
  have hr := hkt.return_annotation rfl
  have hlocWF : LocTy.WF (.cont r t ec Rh) :=
    ⟨hra.wf,han.wf.1,han.wf.2.1,han.wf.2.2,fun r hr' => (hr r hr').wf⟩
  have hlocD : LocTy.Declared P (.cont r t ec Rh) :=
    ⟨hra.declared,han.declared.1,han.declared.2,fun r hr' => (hr r hr').declared⟩
  have hs' := hs.allocate_continuation hB.values hf hlocWF hra.sorted han.sorted.1 han.sorted.2 hlocD
    ⟨k1,hcap,cs,rfl⟩ ⟨R,e,.K_Sub hks hle⟩
  have hnone : Ψ l = none := by
    cases hh : Ψ l with
    | none => rfl
    | some x => exact False.elim (hs.domain l x hh hf)
  let Ψ' := Ψ.put l (.cont r t ec Rh)
  have hext : Ψ.Extends Ψ' := StoreTy.extends_put hnone
  have hhideExt : (hideBuilders Ψ).Extends Ψ' := fun i x hi => hext i x (StoreTy.hide_extends Ψ i x hi)
  have hbody'' := hbody'.store_extend hB.values hs.wf.hide hhideExt
  have hg : ∀ w ∈ ws, w.Ground := by
    intro w hw
    exact hq.view_read_ground hclosed (by rw [hv]; exact List.mem_cons_of_mem _ hw)
  have hargs' := tel_args_store hargs hB.values hs.wf hext
  have hclosure := operation_capture (l := l)
    (sg := ⟨TypeCtx.values od.tparams,od.names,od.params,od.ret,od.eff⟩)
    (srcEff := .mk (fun a => match a with | .name n (.fixed .top) => decide (n = od.eff) | _ => false) []) hB hs.wf hhideExt hcap'
    (hcall.op_body_input rfl rfl rfl hd) hi.result hargs' hg
    hbody'' hn.1 hR ht hec han has hRs (by simp [Ψ',StoreTy.put]) (fun r hr' => (hr r hr').wf)
  have hsaved : (k1 ++ [Frame.handleF hcap cs]).Closed := by
    intro f hf'
    apply hkc f
    rw [hsp.1]
    rcases List.mem_append.mp hf' with hf' | hf'
    · exact List.mem_append_left _ hf'
    · simp only [List.mem_singleton] at hf'; subst f
      exact List.mem_append_right _ List.mem_cons_self
  have hfcl : hcap.Closed ∧ Clause.ClosedList 0 hcap.values.length cs :=
    hkc (.handleF hcap cs) (hsp.1 ▸ List.mem_append_right _ List.mem_cons_self)
  have hfad : Frame.Adequate σ (.handleF hcap cs) := hk.adequate _
    (hsp.1 ▸ List.mem_append_right _ List.mem_cons_self)
  have hmem : Clause.mk (.user o) od.params.length (TypeCtx.values od.tparams).length body ∈ cs :=
    List.mem_of_find?_eq_some hc
  have hbcl := clause_closed hfcl.2 hmem
  have hbad := clause_adequate hfad.2 hmem
  have inp := hcall.op_body_input rfl rfl rfl hd
  have hrun := Comp.ClosedAt.runtime_type_inst (c := 0) (es := [])
    (by simpa only [Nat.zero_add,←inp.typeCount,Clause.body] using hbcl) hbad inp.typeWF inp.rowWF
    (fun t ht => (hcall.op_typeScope t ht).2)
  have hlen : ws.length = od.params.length := by
    have hl := hargs.length
    have htelEq := signature_inst od.names od.params od.ret
      (show Eff from .mk (fun a => match a with | .name n (.fixed .top) => decide (n = od.eff) | _ => false) []) inp.typeWF
    change instantiatedTel od.tel ts [] = _ at htelEq
    rw [htelEq,←Tel.inputs_length,signature_inputs _ _ _ _ (by simpa only [List.length_map] using hn.1),List.length_map] at hl
    exact hl
  obtain ⟨hqWide,hqSub⟩ := hclosure.widen_atoms hcove
  refine ⟨Ψ',Rh,t,b,et,_,hs',hqWide,hqSub,?_,?_,?_,?_,?_⟩
  · exact .K_Drop (b' := r) (t' := t) (e' := ec) (R' := Rh)
      (by simp [Ψ',StoreTy.put]) (covers_state hcove) (hkt.store hB.values hs.wf hext)
  · change (hcap.extendMany (ws ++ [.loc l])).Adequate σ ∧ _
    have ha := Closure.view_adequate had
    rw [hv] at ha
    have hwa : adequateVals σ (ws ++ [.loc l]) := by
      have hx : ∀ xs : List Val, adequateVals σ xs → adequateVals σ (xs ++ [.loc l]) := by
        intro xs
        induction xs with
        | nil => exact fun _ => ⟨trivial,trivial⟩
        | cons w xs ih => exact fun hh => ⟨hh.1,ih hh.2⟩
      exact hx ws ha.2
    exact ⟨Capture.Adequate.extendMany hfad.1 hwa,hrun.2⟩
  · change (hcap.extendMany (ws ++ [.loc l])).Closed ∧ _
    constructor
    · exact Capture.Closed.extendMany hfcl.1 (by
        intro w hw; rcases List.mem_append.mp hw with hw | hw
        · exact hg w hw
        · cases List.mem_singleton.mp hw; trivial)
    · simpa only [Capture.extendMany_values,List.length_append,List.length_reverse,List.length_map,
        List.length_cons,List.length_nil,Nat.add_zero,Nat.zero_add,hlen,Nat.add_assoc,Nat.add_comm,Nat.add_left_comm,Comp.substTy] using hrun.1
  · intro f hf'
    rcases List.mem_cons.mp hf' with rfl | hf'
    · trivial
    · apply hkc f
      rw [hsp.1]
      exact List.mem_append_right _ (List.mem_cons_of_mem _ hf')
  · intro i cell hcell
    by_cases hil : i = l
    · subst i
      simp only [Store.set,↓reduceIte,Option.some.injEq] at hcell
      cases hcell
      exact hsaved
    · simp only [Store.set,hil,↓reduceIte] at hcell
      exact hμ i cell hcell
private theorem close_return_contract {Ψ : StoreTy} {cap : Capture} {Rs R Rs' : Option Ty} {l x t e}
    (hw : Ψ.WF) (hp : Ψ l = some (.cont x t e Rs'))
    (hR : cap.closeR Rs = R) (he : Rs'.map Ty.norm = Rs.map Ty.norm) :
    Rs'.map Ty.norm = R.map Ty.norm := by
  have hh : (Rs'.map Ty.norm).map cap.closeTy = Rs'.map Ty.norm := by
    cases Rs' with
    | none => rfl
    | some r =>
      have hr := (hw l _ hp).2.2.2.2 r rfl
      simp only [Option.map_some]
      rw [Capture.closeTy,Ty.subst_values_of_wf_zero (Ty.wf_norm hr),Ty.norm_idem]
  have hsrc : (Rs.map Ty.norm).map cap.closeTy = cap.closeR Rs := by
    simp only [Option.map_map,Function.comp_def,Capture.closeR,Capture.closeTy,substTyValues_norm_source]
  rw [he,hsrc,hR] at hh
  rw [hh]
  simpa only [Option.map_map,Function.comp_def,Ty.norm_idem] using he

private theorem close_resume_aux {P B Ψ Q C Γ Φ Rs m a e L cap R kv v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hr : cap.closeR Rs = R)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .resume kv v) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.resume (closeVal cap kv) (closeVal cap v))
      (cap.closeTy a) (cap.closeEff e) [] := by
  match h with
  | .C_Resume hi hv hdt =>
    subst Q C
    cases hm
    have hv' := close_value_typed hP hPB hB hw hs hd hc hv
    have hdt' := hdt.bind_values hc.substOk.declaration
    have hh := hc.substOk _ _ hi
    cases hh with
    | ordinary ho _ => exact False.elim (ho _ _ _ rfl)
    | hidden _ hn => exact False.elim (hn _ _ _ rfl)
    | contVar _ _ hx => obtain ⟨_,_,_,hx,_⟩ := hx; cases hx
    | contLoc _ heq _ he hl _ =>
      change Ty.cont (cap.closeTy _) (cap.closeTy _) (cap.closeEff _) = _ at heq
      obtain ⟨hb,ht,hef⟩ := Ty.cont.inj heq
      simp only [closeVal,he]
      rw [hb] at hv'
      rw [←ht,←hef] at hl
      exact .C_ResumeL hl hv' hdt'
  | .C_ResumeNorm hi hv hdt =>
    subst Q C
    cases hm
    have hv' := close_value_typed hP hPB hB hw hs hd hc hv
    have hdt' := hdt.bind_values hc.substOk.declaration
    change Ty.Declared P [] [] (substTyValues cap.env _) at hdt'
    simp only [Capture.closeTy,substTyValues_norm_source] at hv' hdt' ⊢
    simp only [Capture.closeEff,substEffValues_norm_source]
    have hh := hc.substOk _ _ hi
    cases hh with
    | ordinary ho _ => exact False.elim (ho _ _ _ rfl)
    | hidden _ hn => exact False.elim (hn _ _ _ rfl)
    | contVar _ _ hx => obtain ⟨_,_,_,hx,_⟩ := hx; cases hx
    | contLoc _ heq _ he hl _ =>
      change Ty.cont (cap.closeTy _) (cap.closeTy _) (cap.closeEff _) = _ at heq
      obtain ⟨hb,ht,hef⟩ := Ty.cont.inj heq
      simp only [closeVal,he]
      change HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap _) (cap.closeTy _) at hv'
      rw [hb] at hv'
      rw [←ht,←hef] at hl
      exact .C_ResumeL hl hv' hdt'
  | .C_ResumeL hl hv hdt =>
    subst Q C
    cases hm
    have hv' := close_value_typed hP hPB hB hw hs hd hc hv
    have hh := hw _ _ hl
    have heR := close_return_contract hw hl hr (Eq.refl _)
    simp only [Capture.closeTy,Capture.closeEff,Ty.subst_values_of_wf_zero hh.1,
      Ty.subst_values_of_wf_zero hh.2.1,Eff.subst_values_of_wf_zero hh.2.2.1 hh.2.2.2.1] at hv' ⊢
    have hn := hh.2.2.2.1
    change Eff.norm _ = _ at hn
    simpa only [closeVal,hn] using
      (HasTypeCQ.C_ResumeLNorm (Δ := []) hl heR hv' (hd _ _ hl).2.1.norm)
  | .C_ResumeLNorm hl he hv hdt =>
    subst Q C
    cases hm
    have hv' := close_value_typed hP hPB hB hw hs hd hc hv
    have hh := hw _ _ hl
    have heR := close_return_contract hw hl hr he
    simp only [Capture.closeTy,Capture.closeEff,substTyValues_norm_source,substEffValues_norm_source,
      Ty.subst_values_of_wf_zero hh.1,Ty.subst_values_of_wf_zero hh.2.1,
      Eff.subst_values_of_wf_zero hh.2.2.1 hh.2.2.2.1] at hv' ⊢
    have hn := hh.2.2.2.1
    change Eff.norm _ = _ at hn
    simpa only [closeVal,hn] using
      (HasTypeCQ.C_ResumeLNorm (Δ := []) hl heR hv' (hd _ _ hl).2.1.norm)
  | .C_Sub hb hl he hwf hsort hdecl =>
    have hh := close_resume_aux hb hP hPB hB hw hs hd hc hr hQ hC hm
    subst Q C
    have ht := hc.substOk.annotation (Ty.Annotation.mk hwf hsort hdecl)
    exact .C_Sub hh (hl.bind (valEnv cap.env) hc.transport)
      (he.bind (valEnv cap.env)) ht.wf ht.sorted ht.declared
  | .C_Normal hb =>
    have hh := close_resume_aux hb hP hPB hB hw hs hd hc hr hQ hC hm
    simpa only [Capture.closeTy,substTyValues_norm_source] using hh
  | .C_Eff hb he =>
    have hh := close_resume_aux hb hP hPB hB hw hs hd hc hr hQ hC hm
    subst Q C
    exact .C_Eff hh (he.bind (valEnv cap.env))
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h
private theorem resume_resolve {P B Ψ Q C Γ Φ R code a e L kv v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (he : code = .resume kv v) (ρ) :
    code.resolveLocals ρ = code := by
  match h with
  | .C_Resume _ hv _ | .C_ResumeL _ hv _ | .C_ResumeNorm _ hv _ | .C_ResumeLNorm _ _ hv _ =>
    cases he; simp only [Comp.resolveLocals,Val.resolveLocals,hv.resolve_id]
  | .C_Normal hh | .C_Sub hh .. | .C_Eff hh _ => exact resume_resolve hh he ρ
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases he
termination_by structural h

private theorem resume_inv {P B Ψ Q C Γ Φ R code a e L l v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (he : code = .resume (.loc l) v) :
    ∃ x t ec r, Ψ l = some (.cont x t ec r) ∧ r.map Ty.norm = R.map Ty.norm ∧
      HasTypeVQ P B Ψ Q C Γ Φ v x.norm ∧ Ty.LeQ P Γ Φ t.norm a ∧ Eff.Covers Γ Φ e ec := by
  match h with
  | .C_ResumeL hl hv hd => cases he; exact ⟨_,_,_,_,hl,rfl,hv.V_Normal,.convert (Ty.norm_idem _),.refl _ _ _⟩
  | .C_ResumeLNorm hl hr hv hd => cases he; exact ⟨_,_,_,_,hl,hr,hv,.refl,Eff.covers_norm_left.mpr (.refl _ _ _)⟩
  | .C_Sub hh hl hc _ _ _ =>
    obtain ⟨x,t,ec,r,hp,hr,hv,hle,hcov⟩ := resume_inv hh he
    exact ⟨x,t,ec,r,hp,hr,hv,.trans hle hl,hc.trans hcov⟩
  | .C_Normal hh =>
    obtain ⟨x,t,ec,r,hp,hr,hv,hle,hcov⟩ := resume_inv hh he
    exact ⟨x,t,ec,r,hp,hr,hv,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_Eff hh hc =>
    obtain ⟨x,t,ec,r,hp,hr,hv,hle,hcov⟩ := resume_inv hh he
    exact ⟨x,t,ec,r,hp,hr,hv,hle,hc.trans hcov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeNorm .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases he
termination_by structural h

private theorem closed_set {μ : Store} {l c} (h : μ.Closed) (hc : c.Closed) :
    (μ.set l c).Closed := by
  intro i x hx
  by_cases hi : i = l
  · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hx; subst x; exact hc
  · simp only [Store.set,hi,↓reduceIte] at hx; exact h i x hx



private theorem resume_view_typed {P B Ψ R q a e l v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .resume (.loc l) v) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.resume (.loc l) v) a e [] := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,_,hr,rfl,rfl,_⟩ := hq.open_zero
  cases m
  case resume kv v0 =>
    have hh := close_resume_aux hb hP hPB hB hw hs hd hc hr rfl rfl rfl
    rw [resume_resolve hb rfl ρ] at hv
    change Comp.resume (closeVal cap kv) (closeVal cap v0) = _ at hv
    obtain ⟨hkv,hvv⟩ := Comp.resume.inj hv
    rw [hkv,hvv] at hh
    exact hh
  case checkAt _ _ _ bs _ _ _ =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)
  all_goals (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)

/-- 保存継続の任意の入力値を再開し、同じ場所型のまま used へ更新する。 -/
theorem StateTyE.resume_all {P B σ Eb q l v k μ saved}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .resume (.loc l) v)
    (hl : μ l = some (.cont saved)) :
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) (saved ++ k) (μ.set l .used)) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨x,t,ec,r,hp,hr,hv',hle,hcov⟩ := resume_inv
    (resume_view_typed hP hPB hB hs.wf hs.sorted hs.declared hq hv) rfl
  have hrraw := resume_raw_return hs hp hl hr hq.return_normal
  subst r
  obtain ⟨x',t',ec',r',hp',hend,R0,e0,hks⟩ := hs.cell l _ hl
  cases Option.some.inj (hp'.symm.trans hp)
  have ht := hks.resume_append hend (.trans (.convert (Ty.norm_idem _).symm) hle) hk
    (he.covers.trans hcov)
  have hxa : Ty.Annotation P [] [] x.norm :=
    ⟨Ty.wf_norm (hs.wf l _ hp).1,Ty.sorted_norm (hs.sorted l _ hp).1,(hs.declared l _ hp).1.norm⟩
  have ht' := ContTy.K_Sub ht (Ty.LeQ.convert (Ty.norm_idem x))
  obtain ⟨R'',hRn,ht''⟩ := ht'.normal_return_tail rfl x.norm hxa (Ty.norm_idem _) .refl
  have hra := ContTy.return_annotation ht'' rfl
  have hq' := ClosureTy.pure (.C_Return (R := R'') hv') hxa.done_empty
    (fun r hh => ⟨(hra r hh).wf,(hra r hh).declared⟩) (Ty.norm_idem _) hRn
  have hva := Closure.view_adequate had
  rw [hv] at hva
  have hvg : v.Ground := hq.view_read_ground hcl (by rw [hv]; exact List.mem_cons_self)
  exact ⟨Ψ,R'',x.norm,b,e0,Eff.empty,hs.use_continuation hp,hq',empty_sub e0,ht'',
    ⟨trivial,hva.2⟩,⟨trivial,hvg⟩,
    (fun f hf => by
      rcases List.mem_append.mp hf with hf | hf
      · exact hμ l _ hl f hf
      · exact hkc f hf),closed_set hμ trivial⟩
/-- 失敗節の型1・値2の置換と hidden な継続場所を、実際の raise から組み立てる。 -/
theorem StateTyE.operation_failure {P B σ Eb q T E0 v k μ k1 E body k2 l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.raise T E0) [v])
    (hsp : SplitAt .fail k k1 hcap [.fail E body] k2) (hf : μ l = none) :
    StateTyE P B σ Eb (.run (.mk (hcap.extendMany [v,.loc l]) (body.substTy [T] []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap [.fail E body]])))) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hclosed,hkc,hμ⟩ := h
  have hcode := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  obtain ⟨callerTy,hcall⟩ := hcode.read_values (.raise T E0) List.mem_cons_self
  obtain ⟨hval,hle,hcov⟩ := hcode.failure_call
  have hfail : e.memFail E0 := he.2 _ (hcov.2 _ (by
    exact ⟨E0.norm,by simp [Eff.singleFail,Eff.fails],Ty.norm_idem E0⟩))
  obtain ⟨t,ec,et,Rh,hks,hkt,hcove,hsub,han,Γ,Φ,Rs,Es,as,ecs,hcap',hcs,hR,ht,hec,hRs⟩ :=
    split_fail_annotated hk hsp.1
  obtain ⟨_,Γ0,Φ0,Es0,Rs0,ts0,ecs0,hcap0,hcs0,herr⟩ := hk.fail_input hsp.1 hsp.2.2 hfail
  have hEs : Es = E := by cases hcs; rfl
  have hEs0 : Es0 = E := by cases hcs0; rfl
  subst Es Es0
  have hbody := type_subst_e_opfail_site ⟨hP,hPB,hB,hs.wf⟩ hcall hcs rfl
  have inp := fail_input hB hcall
  have hEann : Ty.Annotation P [] Γ E := by cases hcs with | one hE _ _ _ => exact hE
  have htann : Ty.Annotation P [] Γ as := by cases hcs with | one _ ht _ _ => exact ht
  have hT : T.WF 0 0 0 ∧ Ordinary T :=
    ⟨(hcall.raise_annotation_kind rfl).1.wf.2.2.1,(hcall.raise_annotation_kind rfl).2.1⟩
  have hr := hkt.return_annotation rfl
  let savedEff : Eff := .mk et.atoms ec.fails
  have savedAnn := done_annotation_with_atoms han et.atoms
  have hlocWF : LocTy.WF (.cont T.norm t savedEff Rh) :=
    ⟨Ty.wf_norm hT.1,han.wf.1,savedAnn.wf.2.1,savedAnn.wf.2.2,fun r hr' => (hr r hr').wf⟩
  have hlocS : sortedEff [] savedEff := savedAnn.sorted.2
  have hlocD : LocTy.Declared P (.cont T.norm t savedEff Rh) :=
    ⟨(hcall.raise_annotation_kind rfl).1.declared.2.1.norm,han.declared.1,savedAnn.declared.2,
      fun r hr' => (hr r hr').declared⟩
  have hs' := hs.allocate_continuation hB.values hf hlocWF (Ty.sorted_norm (hcall.raise_annotation_kind rfl).1.sorted.2.1)
    han.sorted.1 hlocS hlocD ⟨k1,hcap,[.fail E body],rfl⟩ ⟨R,e,.K_Sub hks hle⟩
  have hnone : Ψ l = none := by
    cases hh : Ψ l with
    | none => rfl
    | some x => exact False.elim (hs.domain l x hh hf)
  let Ψ' := Ψ.put l (.cont T.norm t savedEff Rh)
  have hext : Ψ.Extends Ψ' := StoreTy.extends_put hnone
  have hhideExt : (hideBuilders Ψ).Extends Ψ' := fun i x hi => hext i x (StoreTy.hide_extends Ψ i x hi)
  have hbody' := hbody.store_extend hB.values hs.wf.hide hhideExt
  have hcapN := capture_normal (hcap'.store hB.values hs.wf.hide hhideExt.preservesNormals)
  have hEN := (norm_context_eq Γ).annotation (B := B) hEann.norm
  have hval' := hval.store_extend hB.values hs.wf hext
  have hval'' : HasTypeVQ P B Ψ' Qempty [] [] [] v (hcap.closeTy E.norm) := by
    have herr' : hcap.closeTy E = E0.norm := by
      exact (substTyValues_normal E hcap.env).symm.trans herr
    change HasTypeVQ P B Ψ' Qempty [] [] [] v (substTyValues hcap.env E.norm)
    rw [substTyValues_norm_source]
    change HasTypeVQ P B Ψ' Qempty [] [] [] v (hcap.closeTy E)
    rw [herr']
    exact hval'
  have hvg : v.Ground := hq.view_read_ground hclosed (by rw [hv]; exact List.mem_cons_of_mem _ List.mem_cons_self)
  have hcap1 := hcapN.extend hEN hval'' hvg
  have hcap2 := hcap1.extendHidden (.loc l) trivial
  have hctx : (failureContext Γ E).bindTypes (typeEnvAt 0 [T] []) =
      (Ctx.extend (Γ.map (Option.map Ty.norm)) E.norm).extendNone := by
    simp only [failureContext,Ctx.bindTypes_extendNone inp.toTypeSubstInput,
      Ctx.bindTypes_extend inp.toTypeSubstInput]
    rw [show (1 : Nat) = [T].length from rfl,shifted_context_cancel,shifted_type_cancel]
  rw [hctx] at hbody'
  simp only [show (1 : Nat) = [T].length from rfl,op_result_inst inp.toTypeSubstInput,
    op_effect_inst inp.toTypeSubstInput,Option.map_map,Function.comp_def] at hbody'
  have hty : (hcap.extendMany [v,.loc l]).closeTy (as.norm.shiftV 2 0) = t := by
    rw [show (2 : Nat) = [v,Val.loc l].length from rfl,Capture.closeTy_shift_many]
    simpa only [Capture.closeTy,substTyValues_norm_source] using ht
  have hef : (hcap.extendMany [v,.loc l]).closeEff (ecs.norm.shiftV 2 0) = ec := by
    rw [show (2 : Nat) = [v,Val.loc l].length from rfl,Capture.closeEff_shift_many]
    simpa only [Capture.closeEff,substEffValues_norm_source] using hec
  have hret : (hcap.extendMany [v,.loc l]).closeR (Rs.map (fun r => r.norm.shiftV 2 0)) = Rh := by
    cases Rs with
    | none => exact hR
    | some r =>
      change some ((hcap.extendMany _).closeTy _) = _
      rw [show (2 : Nat) = [v,Val.loc l].length from rfl,Capture.closeTy_shift_many]
      simpa only [Capture.closeR,Capture.closeTy,Option.map_some,substTyValues_norm_source] using hR
  have hrd : ∀ r, Rs.map (fun r => r.norm.shiftV 2 0) = some r →
      r.Declared P [] (Ctx.extend (Γ.map (Option.map Ty.norm)) E.norm).extendNone := by
    intro r hr'
    obtain ⟨rr,hrr,rfl⟩ := Option.map_eq_some_iff.mp hr'
    have hd0 := (hRs rr hrr).norm.context ((norm_context_eq Γ).declaration (B := B))
    have hd1 := (ShiftMap.outerValue (Γ.map (Option.map Ty.norm)) (some (E.norm.shiftV 1 0))).declared hd0
    have hd2 := (ShiftMap.outerNone (Ctx.extend (Γ.map (Option.map Ty.norm)) E.norm)).declared hd1
    simpa only [Ty.shiftV_add,Nat.reduceAdd] using hd2
  simp only [Capture.extendMany,List.foldl_cons,List.foldl_nil] at hty hef hret
  have hclosure := ClosureTy.capture_resolved_closed (a := as.norm.shiftV 2 0) (e := ecs.norm.shiftV 2 0) hcap2 hbody' (CaptureLocals.empty _ _ LocalRef.bound)
    (by rw [hty,hef]; exact han) hret hrd
  rw [hbody'.resolve_id LocalRef.bound (LocalsFixed.empty _),hty,hef] at hclosure
  obtain ⟨hqWide,hqSub⟩ := hclosure.widen_atoms hcove
  have hsaved : (k1 ++ [Frame.handleF hcap [.fail E body]]).Closed := by
    intro f hf'
    apply hkc f
    rw [hsp.1]
    rcases List.mem_append.mp hf' with hf' | hf'
    · exact List.mem_append_left _ hf'
    · cases List.mem_singleton.mp hf'
      exact List.mem_append_right _ List.mem_cons_self
  have hfcl := hkc (.handleF hcap [.fail E body]) (hsp.1 ▸ List.mem_append_right _ List.mem_cons_self)
  have hfad := hk.adequate (.handleF hcap [.fail E body]) (hsp.1 ▸ List.mem_append_right _ List.mem_cons_self)
  have hrun := Comp.ClosedAt.runtime_type_inst (c := 0) (ts := [T]) (es := [])
    (show body.ClosedAt 1 (hcap.values.length+2) from hfcl.2.2.1) hfad.2.1
    inp.typeWF inp.rowWF (by intro t ht; cases List.mem_singleton.mp ht; exact hT.2)
  have hva := Closure.view_adequate had
  rw [hv] at hva
  refine ⟨Ψ',Rh,t,b,et,_,hs',hqWide,hqSub,?_,?_,?_,?_,?_⟩
  · exact .K_Drop (b' := T.norm) (t' := t) (e' := savedEff) (R' := Rh)
      (by simp [Ψ',StoreTy.put]) (fun h => hsub.1 _ h) (hkt.store hB.values hs.wf hext)
  · exact ⟨Capture.Adequate.extendMany hfad.1 ⟨hva.2.1,trivial,trivial⟩,hrun.2⟩
  · exact ⟨Capture.Closed.extendMany hfcl.1 (by
      intro w hw; rcases List.mem_cons.mp hw with rfl | hw
      · exact hvg
      · cases List.mem_singleton.mp hw; trivial),by
        simpa only [Capture.extendMany_values,List.length_append,List.length_reverse,List.length_map,
          List.length_cons,List.length_nil,Nat.add_zero,Nat.zero_add,Comp.substTy,Nat.add_comm] using hrun.1⟩
  · intro f hf'
    rcases List.mem_cons.mp hf' with rfl | hf'
    · trivial
    · apply hkc f
      rw [hsp.1]
      exact List.mem_append_right _ (List.mem_cons_of_mem _ hf')
  · intro i cell hcell
    by_cases hil : i = l
    · subst i
      simp only [Store.set,↓reduceIte,Option.some.injEq] at hcell
      cases hcell
      exact hsaved
    · simp only [Store.set,hil,↓reduceIte] at hcell
      exact hμ i cell hcell
private theorem widen_opaque_value {P B Ψ v o inner outer}
    (valid : P.VarianceValid)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.opaque o (.fixed inner)))
    (hcov : outer.Covers inner) :
    HasTypeVQ P B Ψ Qempty [] [] [] v (.opaque o (.fixed outer)) := by
  obtain ⟨hshape,_⟩ := typed_value_meaning_closed valid h
  change ValueShapeMeaning P (fun _ => none) (.opaque o (.fixed inner)) v at hshape
  generalize he : Ty.opaque o (.fixed inner) = a at hshape
  cases hshape with
  | @const c =>
    cases c <;> try cases he
    have hout := (RangeExpr.covers_top_iff outer).mp hcov
    subst outer
    exact h
  | checked =>
    cases he
    obtain ⟨name,k,r,ix,hk,hc,hm,hh,hi⟩ := h.inv_checked rfl
    rcases hh with hh | hh
    · cases hh
    · cases hh
      have hw := hcov.trans hi
      exact .V_Sub (HasTypeVQ.checked_widen hk hc hm hw) .scoped_forget trivial trivial trivial
  | checkedRequest =>
    cases he
    obtain ⟨name,r,A,ix,hk,hc,hreq,hg,ht,hm,hh,hi⟩ := h.inv_checkedRequest rfl
    rcases hh with hh | hh
    · cases hh
    · cases hh
      exact .V_Sub (HasTypeVQ.checkedRequest_widen hk hc hreq hg ht hm (hcov.trans hi))
        .scoped_forget trivial trivial trivial
  | checkedAtOpaque =>
    cases he
    obtain ⟨name,k,ix,hw,hh,hi⟩ := h.inv_checkedAt rfl
    rcases hh with hh | hh
    · cases hh
    · cases hh
      exact .V_Sub (.V_Sub (.V_CheckedAt hw) (.scoped (outer := .fixed outer) (hcov.trans hi)) trivial trivial trivial)
        .scoped_forget trivial trivial trivial
  | _ => cases he
private inductive TargetWiden : Ty → Ty → Prop where
  | same (a : Ty) : TargetWiden a a
  | opaque {o inner outer} : RangeExpr.Covers outer inner →
      TargetWiden (.opaque o (.fixed inner)) (.opaque o (.fixed outer))
  | scoped {o k inner outer} : RangeExpr.Covers outer inner →
      TargetWiden (.scoped o k (.fixed inner)) (.scoped o k (.fixed outer))

private theorem target_bind {a b : Ty} (h : TargetWiden a b) (θ : SubstEnv) (hr : θ.ranges = []) :
    TargetWiden (a.bind θ) (b.bind θ) := by
  cases h with
  | same a => exact .same _
  | «opaque» hc => simpa only [Ty.bind,Ty.rawBind,Ty.norm,hr,RangeIx.inst_nil] using TargetWiden.opaque hc
  | «scoped» hc => simpa only [Ty.bind,Ty.rawBind,Ty.norm,hr,RangeIx.inst_nil] using TargetWiden.scoped hc

private theorem target_value {P B Ψ v a b} (valid : P.VarianceValid) (h : TargetWiden a b)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a) : HasTypeVQ P B Ψ Qempty [] [] [] v b := by
  cases h with
  | same => exact hv
  | «opaque» hc => exact widen_opaque_value valid hv hc
  | «scoped» hc => exact .V_Sub hv (.scoped hc) trivial trivial trivial

private noncomputable def TelTargetWiden (t u : Tel) : Prop := match t,u with
  | .done a _, .done b _ => a = b
  | .param n a t, .param m b u => n = m ∧ TargetWiden a b ∧ TelTargetWiden t u
  | _, _ => False
termination_by structural t

private theorem tel_target_bind {t u : Tel} (h : TelTargetWiden t u) (θ : SubstEnv) (hr : θ.ranges = []) :
    TelTargetWiden (Tel.bind θ t) (Tel.bind θ u) := by
  cases t with
  | done a e =>
    cases u with
    | param => cases h
    | done b f => cases h; rfl
  | param n a t =>
    cases u with
    | done => cases h
    | param m b u =>
      obtain ⟨rfl,hab,htu⟩ := h
      exact ⟨rfl,target_bind hab θ hr,tel_target_bind htu θ.up hr⟩
termination_by structural t

private theorem tel_target_arguments {P B Ψ vs t u a e}
    (valid : P.VarianceValid) (h : TelTargetWiden t u)
    (ha : Ty.Annotation P [] [] (.dependentFn u))
    (hv : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e) :
    ∃ f, HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs u a f := by
  match hv with
  | .done ht =>
    cases u with
    | param => cases h
    | done b f => cases h; exact ⟨f,.done ha⟩
  | .param (v := v) hx hv ht =>
    cases u with
    | done => cases h
    | param m y more =>
      obtain ⟨rfl,hxy,hr⟩ := h
      have hy : Ty.Annotation P [] [] y := ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
      have hv' := target_value valid hxy hv
      have hmore : Ty.Annotation P [] (Ctx.extend [] y) (.dependentFn more) :=
        ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_nil,List.length_map] using ha.wf.2,
          ha.sorted.2,ha.declared.2⟩
      have hmore' := (SubstOk.openValue (R := none) hv' hy (by simp [Ctx.WF])).telAnnotation hmore
      rw [valEnv_openValue] at hmore'
      obtain ⟨f,hf⟩ := tel_target_arguments valid
        (tel_target_bind hr (Tel.argumentsEnv v) rfl) hmore' ht
      exact ⟨f,.param hy hv' hf⟩
termination_by structural vs
private theorem map_atoms_closed (ats : Atom → Bool) (ρ : Nat → RangeIx)
    (h : ∀ l ix, ats (.name l ix) = true → ix.WF 0) : mapRangeAtoms ρ ats = ats := by
  have fixed : ∀ x, ats x = true → mapAtomRanges ρ x = x := by
    intro x hx
    cases x with
    | rho => rfl
    | name l ix =>
      have hi := h l ix hx
      cases ix with
      | fixed => rfl
      | rvar => cases hi
  funext x
  apply Bool.eq_iff_iff.mpr
  simp only [mapRangeAtoms,decide_eq_true_eq]
  constructor
  · rintro ⟨y,hy,he⟩
    rw [fixed y hy] at he
    exact he ▸ hy
  · intro hx
    exact ⟨x,hx,fixed x hx⟩

mutual
  private theorem ranges_closed (a : Ty) (h : a.RangesScoped 0) (ρ : Nat → RangeIx) :
      a.rawMapRanges ρ = a := by
    cases a <;> simp only [Ty.rawMapRanges,Ty.RangesScoped] at h ⊢
    all_goals first | rfl | exact congrArg _ (ranges_closed _ h ρ) | skip
    case «opaque» o ix => cases ix with
      | fixed => rfl
      | rvar => cases h
    case «scoped» o k ix => cases ix with
      | fixed => rfl
      | rvar => cases h
    case data => rw [ranges_types_closed _ h ρ]
    case external => rw [ranges_types_closed _ h ρ]
    case tapp => rw [ranges_types_closed _ h ρ]
    case fn => rw [ranges_types_closed _ h.1 ρ,ranges_closed _ h.2.1 ρ,ranges_eff_closed _ h.2.2 ρ]
    case cont => rw [ranges_closed _ h.1 ρ,ranges_closed _ h.2.1 ρ,ranges_eff_closed _ h.2.2 ρ]
    case map => rw [ranges_closed _ h.1 ρ,ranges_closed _ h.2 ρ]
    case dependentFn => rw [ranges_tel_closed _ h ρ]
    case refined => rw [ranges_closed _ h ρ]
  private theorem ranges_types_closed (as : List Ty) (h : rangesScopedTypes 0 as) (ρ : Nat → RangeIx) :
      mapRangesTys ρ as = as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [mapRangesTys,ranges_closed _ h.1 ρ,ranges_types_closed _ h.2 ρ]
  private theorem ranges_eff_closed (e : Eff) (h : e.RangesScoped 0) (ρ : Nat → RangeIx) :
      Eff.rawMapRanges ρ e = e := by
    cases e with
    | mk ats fs => simp only [Eff.rawMapRanges,map_atoms_closed _ _ h.1,ranges_types_closed _ h.2 ρ]
  private theorem ranges_tel_closed (t : Tel) (h : t.RangesScoped 0) (ρ : Nat → RangeIx) :
      Tel.rawMapRanges ρ t = t := by
    cases t with
    | done a e => simp only [Tel.rawMapRanges,ranges_closed _ h.1 ρ,ranges_eff_closed _ h.2 ρ]
    | param n a t => simp only [Tel.rawMapRanges,ranges_closed _ h.1 ρ,ranges_tel_closed _ h.2 ρ]
end

private theorem operation_param_map {p : Ty}
    (h : (∃ o ix, p = .opaque o ix) ∨ (∃ o k ix, p = .scoped o k ix) ∨ p.RangesScoped 0)
    (rs : List RangeExpr) : p.rawMapRanges (rangeAt 0 rs) = p.instTarget rs := by
  rcases h with ⟨o,ix,rfl⟩ | ⟨o,k,ix,rfl⟩ | hr
  · cases ix <;> simp only [Ty.rawMapRanges,Ty.instTarget,mapIx_rangeAt,RangeIx.inst]
  · cases ix <;> simp only [Ty.rawMapRanges,Ty.instTarget,mapIx_rangeAt,RangeIx.inst]
  · rw [ranges_closed p hr]
    cases p <;> try rfl
    case «opaque» o ix => cases ix with | fixed => rfl | rvar => cases hr
    case «scoped» o k ix => cases ix with | fixed => rfl | rvar => cases hr

private theorem map_signature (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) (ρ : Nat → RangeIx) :
    Tel.rawMapRanges ρ (signatureTel ns ps r e) =
      signatureTel ns (ps.map (fun p => p.rawMapRanges ρ)) (r.rawMapRanges ρ) (Eff.rawMapRanges ρ e) := by
  induction ns generalizing ps with
  | nil => rfl
  | cons n ns ih => cases ps <;> simp only [signatureTel,Tel.rawMapRanges,List.map_cons,List.map_nil,ih]

private noncomputable def erase_effect : Tel → Tel
  | .done a _ => .done a Eff.empty
  | .param n a t => .param n a (erase_effect t)

private theorem erase_effect_norm (t : Tel) : erase_effect t.norm = (erase_effect t).norm := by
  cases t with
  | done => rfl
  | param n a t => simp only [Tel.norm,erase_effect,erase_effect_norm t]

private theorem erase_effect_annotation {P C Γ t}
    (h : Ty.Annotation P C Γ (.dependentFn t)) : Ty.Annotation P C Γ (.dependentFn (erase_effect t)) := by
  cases t with
  | done a e => exact ⟨⟨h.wf.1,by simp [Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Ty.WFList]⟩,
      ⟨h.sorted.1,by simp [sortedEff,Eff.empty,sortedTys]⟩,
      ⟨h.declared.1,by simp [declaredEff,Eff.empty,declaredTys]⟩⟩
  | param n a t =>
    have ht : Ty.Annotation P C (Γ.extend a) (.dependentFn t) :=
      ⟨by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using h.wf.2,h.sorted.2,h.declared.2⟩
    have hi := erase_effect_annotation ht
    exact ⟨⟨h.wf.1,by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using hi.wf⟩,
      ⟨h.sorted.1,hi.sorted⟩,⟨h.declared.1,hi.declared⟩⟩
termination_by structural t

private theorem erase_signature (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) :
    erase_effect (signatureTel ns ps r e) = signatureTel ns ps r Eff.empty := by
  induction ns generalizing ps with
  | nil => rfl
  | cons n ns ih => cases ps <;> simp only [signatureTel,erase_effect,ih]
private theorem operation_param_widen {p : Ty} {nr nt nv : Nat} {rs : List RangeExpr} {S : RangeExpr}
    (hp : (∃ o ix, p = .opaque o ix) ∨ (∃ o k ix, p = .scoped o k ix) ∨ p.RangesScoped 0)
    (hw : p.TargetWF nr nt nv) (hn : rs.length = nr) (hc : ∀ r ∈ rs, S.Covers r) :
    TargetWiden (p.rawMapRanges (rangeAt 0 rs)) (p.instTarget (List.replicate nr S)) := by
  rw [operation_param_map hp rs]
  cases p <;> try exact .same _
  case «opaque» o ix =>
    cases ix with
    | fixed => exact .same _
    | rvar i =>
      have hi : i < nr := hw
      have hir : i < rs.length := by omega
      simp only [Ty.instTarget,RangeIx.inst,List.getElem?_eq_getElem hir,List.getElem?_replicate,hi,↓reduceIte]
      exact .opaque (hc _ (List.getElem_mem hir))
  case «scoped» o k ix =>
    cases ix with
    | fixed => exact .same _
    | rvar i =>
      have hi : i < nr := hw
      have hir : i < rs.length := by omega
      simp only [Ty.instTarget,RangeIx.inst,List.getElem?_eq_getElem hir,List.getElem?_replicate,hi,↓reduceIte]
      exact .scoped (hc _ (List.getElem_mem hir))

private theorem signature_target_widen {nr nt nv : Nat} (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    {rs : List RangeExpr} {S : RangeExpr} (hn : rs.length = nr) (hc : ∀ r ∈ rs, S.Covers r)
    (hp : ∀ p ∈ ps, (∃ o ix, p = .opaque o ix) ∨ (∃ o k ix, p = .scoped o k ix) ∨ p.RangesScoped 0)
    (hw : BinderTypes.TargetWF nr nt nv ps) (hr : r.RangesScoped 0) :
    TelTargetWiden (Tel.rawMapRanges (rangeAt 0 rs) (signatureTel ns ps r e))
      (signatureTel ns (ps.map (Ty.instTarget (List.replicate nr S))) r Eff.empty) := by
  induction ns generalizing ps nv with
  | nil => exact ranges_closed r hr _
  | cons n ns ih =>
    cases ps with
    | nil => exact ranges_closed r hr _
    | cons p ps =>
      exact ⟨rfl,operation_param_widen (hp p List.mem_cons_self) hw.1 hn hc,
        ih ps (fun p hp' => hp p (List.mem_cons_of_mem _ hp')) hw.2⟩

private theorem handler_signature_annotation {P B} {Ψ : StoreTy} {s : PrimSig} {ts S}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B s.tparams [] ts []) (hsource : s.Scoped P) (ho : s.opEff ≠ none) :
    Ty.Annotation P [] [] (.dependentFn (instantiatedTel
      (signatureTel s.names (s.params.map (Ty.instTarget (List.replicate s.rkinds.length S))) s.ret Eff.empty) ts [])) := by
  have hs := (hsource.inst (rs := List.replicate s.rkinds.length S) (by simp only [List.length_replicate])).2.2.2
  have hh := erase_effect_annotation hs
  have hparams : s.params.map (fun p => p.rawMapRanges (rangeAt 0 (List.replicate s.rkinds.length S))) =
      s.params.map (Ty.instTarget (List.replicate s.rkinds.length S)) := by
    apply List.map_congr_left
    intro p hp
    exact operation_param_map ((hsource.operation ho).2.1 p hp) _
  simp only [Tel.instR,Tel.substRAt,Tel.mapRanges,PrimSig.tel,map_signature,erase_effect_norm,
    erase_signature,hparams,ranges_closed s.ret (hsource.operation ho).2.2] at hh
  have hinst := Tel.annotation_substAt hf hi hh
  simpa only [List.nil_append,Ctx.bindTypes,List.map_nil,List.length_nil,Tel.substAt,
    Tel.bind,Tel.norm_rawBind,instantiatedTel] using hinst
private theorem tel_effect_atoms_bind (t : Tel) (θ : SubstEnv) (hr : θ.rows = []) (hg : θ.ranges = []) :
    (Tel.bind θ t).effect.atoms = t.effect.atoms := by
  cases t with
  | done a e =>
    cases e
    simp only [Tel.bind_done,Tel.effect,Eff.bind,Eff.rawBind,hr,hg,instAtoms_nil,substAtoms_nil,Eff.norm,Eff.atoms]
  | param n a t =>
    simp only [Tel.bind_param,Tel.effect]
    exact tel_effect_atoms_bind t θ.up (by simp [SubstEnv.up,hr]) hg
termination_by structural t

private theorem arguments_effect_atoms {P B Ψ vs t a e}
    (h : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs t a e) : e.atoms = t.effect.atoms := by
  match h with
  | .done _ => rfl
  | .param _ _ ht =>
    exact (arguments_effect_atoms ht).trans (tel_effect_atoms_bind _ (Tel.argumentsEnv _) rfl rfl)
termination_by structural vs

private theorem signature_effect (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) :
    (signatureTel ns ps r e).effect = e := by
  induction ns generalizing ps with
  | nil => rfl
  | cons n ns ih => cases ps <;> simp only [signatureTel,Tel.effect,ih]

private theorem inst_effect_mem {e : Eff} {l ix} (rs : List RangeExpr) (h : e.mem (.name l ix)) :
    (Eff.instR rs e).mem (.name l (ix.inst rs)) := by
  rw [Eff.instR_eq_bind,Eff.bind,Eff.mem_norm]
  apply (Eff.mem_rawBind _ _ _).mpr
  exact Or.inl ⟨.name l ix,h,rfl,trivial⟩

private theorem primitive_effect_shape {P : Program} {B : Builtins} {b : PrimName} {s : PrimSig} (hB : B.CoreAssumptions P)
    (hs : B.sig b = some s) (hk : s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) :
    ∃ l bs, s.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧ s.neffs = 0 ∧
      ((s.rkinds = [] ∧ s.eff = Eff.single l) ∨
       ∃ k, s.rkinds = [k] ∧ s.eff = .mk (fun a => decide (a = .name l (.rvar 0))) []) := by
  rcases hk with hk | hk | hk
  · obtain ⟨l,bs,ho,hn,he,hb,hshape⟩ := hB.io_op b s hs (Or.inl hk)
    refine ⟨l,bs,ho,he,hb,hn,?_⟩
    cases hsh : s.shape <;> simp only [hsh] at hshape
    case untargeted => exact Or.inl ⟨hshape.2.1,hshape.2.2⟩
    case topTargeted => exact Or.inl ⟨hshape.2.1,hshape.2.2⟩
    case single k p => exact Or.inr ⟨k,hshape.2.1,hshape.2.2.1⟩
  · obtain ⟨l,bs,ho,hn,he,hb,hshape⟩ := hB.io_op b s hs (Or.inr hk)
    refine ⟨l,bs,ho,he,hb,hn,?_⟩
    cases hsh : s.shape <;> simp only [hsh] at hshape
    case untargeted => exact Or.inl ⟨hshape.2.1,hshape.2.2⟩
    case topTargeted => exact Or.inl ⟨hshape.2.1,hshape.2.2⟩
    case single k p => exact Or.inr ⟨k,hshape.2.1,hshape.2.2.1⟩
  · have sh := hB.pathBases_shape b s hs hk
    obtain ⟨bs,he,hb⟩ := sh.membership
    exact ⟨processEnvironmentEff,bs,sh.operation,he,hb,sh.rows,Or.inl ⟨sh.ranges,sh.effect⟩⟩

private theorem primitive_inst_member {s : PrimSig} {l : EffName} {rs : List RangeExpr}
    (hshape : (s.rkinds = [] ∧ s.eff = Eff.single l) ∨
      ∃ k, s.rkinds = [k] ∧ s.eff = .mk (fun a => decide (a = .name l (.rvar 0))) [])
    (hn : rs.length = s.rkinds.length) :
    ∃ rr, (Eff.instR rs s.eff).mem (.name l (.fixed rr)) ∧
      (∀ S, RangeIx.Covers (.fixed S) (.fixed rr) → ∀ r ∈ rs, S.Covers r) := by
  rcases hshape with ⟨hr,he⟩ | ⟨k,hr,he⟩
  · have hrs : rs = [] := List.length_eq_zero_iff.mp (by simpa only [hr,List.length_nil] using hn)
    subst rs
    refine ⟨.top,?_,?_⟩
    · rw [he]
      exact inst_effect_mem [] (e := Eff.single l) (l := l) (ix := .fixed .top)
        (by simp [Eff.single,Eff.mem,Eff.test,Eff.atoms])
    · intro S _ r hr; cases hr
  · have hlen : rs.length = 1 := by simpa only [hr,List.length_cons,List.length_nil] using hn
    obtain ⟨r,rfl⟩ := List.length_eq_one_iff.mp hlen
    refine ⟨r,?_,?_⟩
    · rw [he]
      have hm := inst_effect_mem [r] (l := l) (ix := .rvar 0)
        (e := .mk (fun a => decide (a = .name l (.rvar 0))) []) (by simp [Eff.mem,Eff.test,Eff.atoms])
      exact hm
    · intro S hc r' hr'; cases List.mem_singleton.mp hr'; exact hc

private theorem tel_effect_norm (t : Tel) : t.norm.effect = t.effect.norm := by
  cases t with
  | done => rfl
  | param n a t => exact tel_effect_norm t
termination_by structural t

private theorem primitive_arguments_atoms {P B Ψ rs ts ws r f} {s : PrimSig}
    (h : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel (Tel.instR rs s.tel) ts []) r f) :
    f.atoms = (Eff.instR rs s.eff).atoms := by
  rw [arguments_effect_atoms h,instantiatedTel,tel_effect_atoms_bind _ _ rfl rfl]
  simp only [Tel.instR,Tel.substRAt,Tel.mapRanges,PrimSig.tel,map_signature,tel_effect_norm,signature_effect,
    Eff.instR,Eff.substRAt,Eff.mapRanges]

private theorem covered_name_general {outer inner : Eff} {l ix}
    (h : Eff.Covers [] [] outer inner) (hm : inner.mem (.name l ix)) :
    ∃ jx, outer.mem (.name l jx) ∧ jx.Covers ix := by
  obtain ⟨a,ha,hc⟩ := h.1 _ hm
  obtain ⟨jx,rfl⟩ := hc.name_right
  refine ⟨jx,ha,?_⟩
  cases ix <;> cases jx <;> first | exact hc.2 | cases hc

/-- 組込みの実引数と効果表から、同じ捕捉の節へ移る全操作の葉。 -/
theorem StateTyE.operation_primitive {P B σ Eb q b s ts es rs ws k μ k1 cs k2 c l hcap}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hdecl : P.EffectsOk B)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b ts es rs) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases)
    (hsp : SplitAt (.prim b) k k1 hcap cs k2) (hc : findClause cs (.prim b) = some c)
    (hf : μ l = none) :
    StateTyE P B σ Eb (.run (.mk (hcap.extendMany (ws ++ [.loc l])) (c.body.substTy ts []))
      (.drop l :: k2) (μ.set l (.cont (k1 ++ [.handleF hcap cs])))) := by
  obtain ⟨Ψ,R,a,z,e,e1,hs,hq,he,hk,had,hclosed,hkc,hμ⟩ := h
  have hcode := hq.app_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  have hg : ∀ w ∈ ws, w.Ground := by
    intro w hw
    exact hq.view_read_ground hclosed (by rw [hv]; exact List.mem_cons_of_mem _ hw)
  obtain ⟨callerTy,hcall⟩ := hcode.read_values (.prim b ts es rs) List.mem_cons_self
  obtain ⟨hranges,hadm,hi⟩ := hcall.primitive_inputs hsig
  obtain ⟨eff,bs,hop,heffects,hb,hnrows,hshape⟩ := primitive_effect_shape hB hsig hkind
  have hes : es = [] := List.length_eq_zero_iff.mp (hadm.rowCount.trans hnrows)
  subst es
  have inp : TypeSubstInput P B s.tparams [] ts [] :=
    hi.closedInput (hB.admits_sat b s [] ts hsig hadm.admits)
  obtain ⟨r,f,hba,hle,hcov⟩ := hcode.primitive_call hg rfl hsig
  have hargs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws (instantiatedTel (Tel.instR rs s.tel) ts []) r f := by
    have hh := hba.arguments
    rw [instantiatedTel_norm_images] at hh
    exact hh
  obtain ⟨ix,hmem,hrs⟩ := primitive_inst_member hshape hranges.1
  have hm : f.mem (.name eff (.fixed ix)) := by
    change f.atoms (.name eff (.fixed ix)) = true
    rw [primitive_arguments_atoms hargs]
    exact hmem
  obtain ⟨ix1,hm1,hcov1⟩ := covered_name_general hcov hm
  have hm2 := he.1 _ hm1
  have hnf := handle_no_failure hk hsp.1 (by intro hh; cases hh) hsp.2.1
  obtain ⟨t,ec,eb,et,Rh,hks,hkt,hcove,hsub,hframe,hmove⟩ := hk.split_handle hsp.1 hnf
  obtain ⟨ix2,hm3,hcov2⟩ := hmove eff ix1 hm2 (by
    intro cap' cs' jx hm'
    exact hdecl.operation_not_handled heffects hb (hsp.2.2 cap' cs' hm'))
  obtain ⟨Γ,Φ,Rs,as,ecs,ebs,hcap',hcs,hR,ht,hec,heb,han,has,hRs⟩ := hframe
  have hm4 : ebs.mem (.name eff ix2) := by
    rw [←heb] at hm3
    simpa only [Capture.closeEff,Eff.mem,Eff.test,substEffValues_atoms] using hm3
  obtain ⟨sg,body,rfl,hsg,hn,hw,hbody⟩ := clause_selected hcs hc
  obtain ⟨S,hix,hlookup,hrows⟩ := hsg
  have hsgeq : sg = ⟨s.tparams,s.names,s.params.map (Ty.instTarget (List.replicate s.rkinds.length S)),s.ret,eff⟩ := by
    simpa only [opSigAt,hsig,hop,Option.map_some,Option.some.injEq] using hlookup.symm
  subst sg
  have hcover : ∀ rr ∈ rs, S.Covers rr := by
    apply hrs S
    have hc := hcov2.trans hcov1
    rcases hix with rfl | ⟨b',s',eff',ho,hs',hop',hrange⟩
    · exact RangeExpr.top_covers _
    · cases ho
      have hh : s' = s := Option.some.inj (hs'.symm.trans hsig)
      subst s'
      have hh : eff' = eff := Option.some.inj (hop'.symm.trans hop)
      subst eff'
      rw [hrange.2.2 ix2 hm4] at hc
      exact hc
  have htann := handler_signature_annotation ⟨hP,hPB,hB,hs.wf⟩ inp (hB.sig_scoped b s hsig)
    (by rw [hop]; intro hh; cases hh) (S := S)
  have hrel := signature_target_widen s.names s.params s.ret s.eff hranges.1 hcover
    ((hB.sig_scoped b s hsig).operation (by rw [hop]; intro hh; cases hh)).2.1
    ((hB.sig_scoped b s hsig).operation (by rw [hop]; intro hh; cases hh)).1.1
    ((hB.sig_scoped b s hsig).operation (by rw [hop]; intro hh; cases hh)).2.2
  have hrel' := tel_target_bind hrel (typeEnvAt 0 ts []) rfl
  have hrel'' : TelTargetWiden (instantiatedTel (Tel.instR rs s.tel) ts [])
      (instantiatedTel (signatureTel s.names (s.params.map (Ty.instTarget (List.replicate s.rkinds.length S))) s.ret Eff.empty) ts []) := by
    simpa only [instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,PrimSig.tel,Tel.bind,
      Tel.norm_rawBind] using hrel'
  obtain ⟨ft,htargs⟩ := tel_target_arguments hPB.variance hrel'' htann hargs
  have hbody' := S02Internal.substC (C0 := s.tparams) (C1 := [])
    ⟨hP,hPB,hB,hs.wf.hide⟩ inp (Or.inl rfl) (by
      intro i hi
      constructor
      · rfl
      · intro j hj
        have he : j = i := by simpa [Eff.row,Eff.mem,Eff.test,Eff.atoms] using hj
        exact he ▸ hi) (by rw [hideBuilders_idem] at hbody; exact hbody)
  have hra := hargs.resultAnnotation
  have hr := hkt.return_annotation rfl
  have hlocWF : LocTy.WF (.cont r t ec Rh) :=
    ⟨hra.wf,han.wf.1,han.wf.2.1,han.wf.2.2,fun r hr' => (hr r hr').wf⟩
  have hlocD : LocTy.Declared P (.cont r t ec Rh) :=
    ⟨hra.declared,han.declared.1,han.declared.2,fun r hr' => (hr r hr').declared⟩
  have hs' := hs.allocate_continuation hB.values hf hlocWF hra.sorted han.sorted.1 han.sorted.2 hlocD
    ⟨k1,hcap,cs,rfl⟩ ⟨R,e,.K_Sub hks hle⟩
  have hnone : Ψ l = none := by
    cases hh : Ψ l with
    | none => rfl
    | some x => exact False.elim (hs.domain l x hh hf)
  let Ψ' := Ψ.put l (.cont r t ec Rh)
  have hext : Ψ.Extends Ψ' := StoreTy.extends_put hnone
  have hhideExt : (hideBuilders Ψ).Extends Ψ' := fun i x hi => hext i x (StoreTy.hide_extends Ψ i x hi)
  have hbody'' := hbody'.store_extend hB.values hs.wf.hide hhideExt
  have hargs' := tel_args_store htargs hB.values hs.wf hext
  have hclosure := operation_capture (l := l)
    (sg := ⟨s.tparams,s.names,s.params.map (Ty.instTarget (List.replicate s.rkinds.length S)),s.ret,eff⟩)
    (srcEff := Eff.empty) hB hs.wf hhideExt hcap' inp htann hargs' hg
    hbody'' hn.1 hR ht hec han has hRs (by simp [Ψ',StoreTy.put]) (fun r hr' => (hr r hr').wf)
  have hsaved : (k1 ++ [Frame.handleF hcap cs]).Closed := by
    intro f hf'
    apply hkc f
    rw [hsp.1]
    rcases List.mem_append.mp hf' with hf' | hf'
    · exact List.mem_append_left _ hf'
    · simp only [List.mem_singleton] at hf'; subst f
      exact List.mem_append_right _ List.mem_cons_self
  have hfcl : hcap.Closed ∧ Clause.ClosedList 0 hcap.values.length cs :=
    hkc (.handleF hcap cs) (hsp.1 ▸ List.mem_append_right _ List.mem_cons_self)
  have hfad : Frame.Adequate σ (.handleF hcap cs) := hk.adequate _
    (hsp.1 ▸ List.mem_append_right _ List.mem_cons_self)
  have hmem : Clause.mk (.prim b) (s.params.map (Ty.instTarget (List.replicate s.rkinds.length S))).length s.tparams.length body ∈ cs :=
    List.mem_of_find?_eq_some hc
  have hbcl := clause_closed hfcl.2 hmem
  have hbad := clause_adequate hfad.2 hmem
  have hrun := Comp.ClosedAt.runtime_type_inst (c := 0) (es := [])
    (by simpa only [Nat.zero_add,←inp.typeCount,Clause.body] using hbcl) hbad inp.typeWF inp.rowWF
    (fun t ht => (hadm.typeScope t ht).2)
  have hlen : ws.length = (s.params.map (Ty.instTarget (List.replicate s.rkinds.length S))).length := by
    have hl := htargs.length
    have htelEq := signature_inst s.names (s.params.map (Ty.instTarget (List.replicate s.rkinds.length S))) s.ret Eff.empty inp.typeWF
    change instantiatedTel _ ts [] = _ at htelEq
    rw [htelEq,←Tel.inputs_length,signature_inputs _ _ _ _ (by simpa only [List.length_map] using hn.1),List.length_map] at hl
    exact hl
  obtain ⟨hqWide,hqSub⟩ := hclosure.widen_atoms hcove
  refine ⟨Ψ',Rh,t,z,et,_,hs',hqWide,hqSub,?_,?_,?_,?_,?_⟩
  · exact .K_Drop (b' := r) (t' := t) (e' := ec) (R' := Rh)
      (by simp [Ψ',StoreTy.put]) (covers_state hcove) (hkt.store hB.values hs.wf hext)
  · change (hcap.extendMany (ws ++ [.loc l])).Adequate σ ∧ _
    have ha := Closure.view_adequate had
    rw [hv] at ha
    have hwa : adequateVals σ (ws ++ [.loc l]) := by
      have hx : ∀ xs : List Val, adequateVals σ xs → adequateVals σ (xs ++ [.loc l]) := by
        intro xs
        induction xs with
        | nil => exact fun _ => ⟨trivial,trivial⟩
        | cons w xs ih => exact fun hh => ⟨hh.1,ih hh.2⟩
      exact hx ws ha.2
    exact ⟨Capture.Adequate.extendMany hfad.1 hwa,hrun.2⟩
  · change (hcap.extendMany (ws ++ [.loc l])).Closed ∧ _
    constructor
    · exact Capture.Closed.extendMany hfcl.1 (by
        intro w hw; rcases List.mem_append.mp hw with hw | hw
        · exact hg w hw
        · cases List.mem_singleton.mp hw; trivial)
    · simpa only [Capture.extendMany_values,List.length_append,List.length_reverse,List.length_map,
        List.length_cons,List.length_nil,Nat.add_zero,Nat.zero_add,hlen,Nat.add_assoc,Nat.add_comm,Nat.add_left_comm,Comp.substTy] using hrun.1
  · intro f hf'
    rcases List.mem_cons.mp hf' with rfl | hf'
    · trivial
    · apply hkc f
      rw [hsp.1]
      exact List.mem_append_right _ (List.mem_cons_of_mem _ hf')
  · intro i cell hcell
    by_cases hil : i = l
    · subst i
      simp only [Store.set,↓reduceIte,Option.some.injEq] at hcell
      cases hcell
      exact hsaved
    · simp only [Store.set,hil,↓reduceIte] at hcell
      exact hμ i cell hcell

end
end Benitoite.Release.Refinement
