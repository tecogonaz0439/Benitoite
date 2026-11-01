import Benitoite.Release.Refinement.HandlerTelescope
import Benitoite.Release.Refinement.HandlerFailure
import Benitoite.Release.Refinement.HandlerPreservation

/-! # 単相の節への引数と継続の捕捉 -/
namespace Benitoite.Release.Refinement
noncomputable section

set_option maxHeartbeats 2000000

private theorem typeEnv_nil : typeEnvAt 0 [] [] = renEnv id := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1 <;> funext i <;> simp [typeEnvAt,renEnv]

private theorem mono_tel (name : String) (x y : Ty) (eff : EffName)
    (hxn : x.Normal) (hyn : y.Normal) :
    instantiatedTel (OpDecl.tel ⟨eff, [], [name], [x], y, []⟩) [] [] =
      .param name x (.done y (Eff.single eff)) := by
  change x.norm = x at hxn
  change y.norm = y at hyn
  simp only [instantiatedTel,typeEnv_nil,Tel.bind,Tel.rawBind_id,OpDecl.tel,signatureTel,Tel.norm,hxn,hyn]
  congr 2
  apply congrArg (fun f => EffR.mk f [])
  funext a
  cases a with
  | rho i => rfl
  | name l ix => cases ix with
    | rvar i => simp [RangeIx.top]
    | fixed r =>
      cases r with
      | absolute r => cases r <;> simp [RangeIx.top,RangeExpr.top]
      | based b p => simp [RangeIx.top,RangeExpr.top]
      | secrets => simp [RangeIx.top,RangeExpr.top]

private theorem annotation_closed {P Γ x} (hx : Ty.Annotation P [] [] x) : Ty.Annotation P [] Γ x := by
  have hm : ShiftMap Γ.length 0 [] Γ := ⟨by simp,by intro i a hi; cases hi⟩
  simpa only [Ty.shiftV_of_wf_zero hx.wf] using hm.annotation hx

private theorem annotation_one {P x y} {Γ : Ctx} (hx : Ty.Annotation P [] [] x)
    (hy : Ty.Annotation P [] (Ctx.extend [] x) y) : Ty.Annotation P [] (Γ.extend x) y := by
  have hwx : (x.shiftV 1 0).WF 0 0 1 := by simpa using Ty.wf_shiftV hx.wf 1 0
  have hwy : y.WF 0 0 1 := by simpa [Ctx.extend] using hy.wf
  have hm : ShiftMap Γ.length 1 (Ctx.extend [] x) (Γ.extend x) := by
    refine ⟨by simp [Ctx.extend]; omega,?_⟩
    intro i a hi _
    cases i with
    | zero =>
      cases Option.some.inj hi
      simp only [shiftIndex,show 0 < 1 by decide,↓reduceIte]
      rw [Ty.shiftV_fixed_before hwx _ 1 (by omega)]
      rfl
    | succ i => simp [Ctx.extend] at hi
  simpa only [Ty.shiftV_fixed_before hwy _ 1 (by omega)] using hm.annotation hy

private theorem close_one (cap : Capture) (name : String) (eff : EffName) {P x y} (v : Val)
    (hx : Ty.Annotation P [] [] x) (hy : Ty.Annotation P [] (Ctx.extend [] x) y)
    (hxn : x.Normal) (hyn : y.Normal) :
    (cap.extend v).closeTy y = substTyValues (openValue v) y := by
  change x.norm = x at hxn
  change y.norm = y at hyn
  let t := Tel.param name x (.done y (Eff.single eff))
  have ht : t.WF 0 0 0 :=
    ⟨hx.wf,by simpa [Ctx.extend] using hy.wf,by simp [Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.WFList]⟩
  have hn : t.Normal := by simp [t,Tel.Normal,Tel.norm,hxn,hyn,Eff.single,Eff.norm]
  have he : cap.closeTel t = t := (Tel.bind_values_of_wf_zero ht _).trans hn
  have h := Capture.instantiate cap t [v] rfl
  rw [he] at h
  simp only [t,Tel.instantiate,Tel.bind_done,←valEnv_openValue] at h
  have hh := (Prod.mk.inj (Option.some.inj h)).1.symm
  simpa only [Capture.extendMany,List.foldl_cons,List.foldl_nil,Tel.result,
    substTyValues,Ty.bind,Ty.norm_idem] using hh

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

private theorem clause_one {P B Ψ Q C Γ Φ R eb cs t ec L o name x y eff body}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t ec L)
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
    (hc : findClause cs (.user o) = some (.mk (.user o) 1 0 body)) :
    HasTypeCQ P B (hideBuilders Ψ) Q C
      ((Γ.extend x).extend (.cont y (t.shiftV 1 0) (ec.shiftV 1 0)))
      (liftMany 2 Φ) (R.map (Ty.shiftV 2 0)) body (t.shiftV 2 0) (ec.shiftV 2 0) [] := by
  match h with
  | .nil => cases hc
  | .cons hs hnames hn hk hw hb hcs =>
    simp only [findClause,List.find?_cons] at hc
    split at hc
    · rename_i heq
      have hop := beq_iff_eq.mp heq
      simp only [Clause.op] at hop
      cases hop
      cases Option.some.inj hc
      obtain ⟨S,_,hsig⟩ := hs
      simp only [opSigAt,hd,Option.map_some,Option.some.injEq] at hsig
      cases hsig
      simpa only [OpSig.context,OpSig.continuation,Ctx.shiftE,Ctx.shiftEAt,
        List.length_nil,List.length_cons,Nat.zero_add,List.nil_append,shiftTypes_zero,
        shiftRowsTypes_zero,Ctx.extendMany,Nat.reduceAdd,Option.map_id, List.map_id,show shiftTypes 0 0 = id from funext (fun a => shiftTypes_zero a 0)] using hb
    · exact clause_one hcs hd hc
termination_by structural h

private theorem closeEff_shift (cap : Capture) (v : Val) (e : Eff) :
    (cap.extend v).closeEff (e.shiftV 1 0) = cap.closeEff e := by
  have h := cap.closeTy_shift v (.cont (.base .unit) (.base .unit) e)
  exact (Ty.cont.inj h).2.2

private theorem closeTy_two (cap : Capture) (v w : Val) (a : Ty) :
    ((cap.extend v).extend w).closeTy (a.shiftV 2 0) = cap.closeTy a := by
  rw [show a.shiftV 2 0 = (a.shiftV 1 0).shiftV 1 0 from (Ty.shiftV_add a 1 1).symm,
    Capture.closeTy_shift,Capture.closeTy_shift]

private theorem closeEff_two (cap : Capture) (v w : Val) (e : Eff) :
    ((cap.extend v).extend w).closeEff (e.shiftV 2 0) = cap.closeEff e := by
  rw [show e.shiftV 2 0 = (e.shiftV 1 0).shiftV 1 0 from (Eff.shiftV_add e 1 1).symm,
    closeEff_shift,closeEff_shift]

private theorem covers_state {outer inner : Eff} (h : Eff.Covers [] [] outer inner)
    (hm : inner.mem (.name stateEff (.fixed .top))) : outer.mem (.name stateEff (.fixed .top)) := by
  obtain ⟨a,ha,hcov⟩ := h.1 _ hm
  obtain ⟨ix,rfl⟩ := hcov.name_right
  cases ix with
  | rvar i => cases hcov
  | fixed r =>
    have hr : r = .top := (RangeExpr.covers_top_iff _).mp hcov.2
    rwa [hr] at ha

private theorem handle_no_fail {P B σ Ψ R e frames a b Eb Re cap cs k1 k2 o}
    (h : ContTy P B σ Ψ R e frames a b Eb Re)
    (he : frames = k1 ++ .handleF cap cs :: k2) (hopen : handles cs (.user o) = true) :
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
    | nil => cases he; cases hcs; simp [handles,Clause.op] at hopen
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

theorem ContTy.guard_effect {P B σ Ψ R e frames a b Eb Re v cap arms next body k}
    (h : ContTy P B σ Ψ R e frames a b Eb Re)
    (he : frames = .guardF v cap arms next body :: k) : R = none ∧ e = Eff.empty := by
  induction h with
  | K_Guard => cases he; exact ⟨rfl,rfl⟩
  | K_Sub _ _ ih => exact ih he
  | _ => cases he

theorem StateTyE.operation_under_guard_false
    {P B σ Eb o name x y eff arg v cap arms next body k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o []) [arg]))
      (.guardF v cap arms next body :: k) μ))
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
    (hxn : x.Normal) (hyn : y.Normal) : False := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,_⟩ := h
  obtain ⟨_,rfl⟩ := hk.guard_effect rfl
  obtain ⟨r,f,hargs,hle,hcov⟩ := hq.pure_operation hA.values hs.wf hd
  rw [mono_tel name x y eff hxn hyn] at hargs
  cases hargs with
  | param _ _ ht =>
    simp only [Tel.bind_done,←valEnv_openValue,←substEffValues_eq_bind,Eff.subst_values_single] at ht
    cases ht
    obtain ⟨atom,hm,_⟩ := (he.covers.trans hcov).1 (.name eff .top)
      (by simp [Eff.mem,Eff.test,Eff.single,Eff.atoms])
    cases hm

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

theorem ClosureTy.widen_atoms {P B Ψ R q a ec et}
    (hq : ClosureTy P B Ψ [] R q a ec) (he : Eff.Covers [] [] et ec) :
    ClosureTy P B Ψ [] R q a (.mk et.atoms ec.fails) ∧ Eff.Sub (.mk et.atoms ec.fails) et := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,heqQ,hcap,hbody,hL,hR,ha,hec,hr⟩ := hq.open_zero
  have hatoms : ec.atoms = es.atoms := by rw [←hec]; exact substEffValues_atoms es cap.env
  have hc : Eff.Covers Γ Φ (.mk et.atoms es.fails) es := by
    refine ⟨?_,fun _ h => h⟩
    intro atom hm
    exact he.1 atom (by simpa only [Eff.mem,Eff.test,hatoms] using hm)
  have hwide : cap.closeEff (.mk et.atoms es.fails) = .mk et.atoms ec.fails := by
    cases es; cases ec
    have hf := congrArg Eff.fails hec
    simp only [Capture.closeEff,substEffValues,Eff.bind,Eff.rawBind,valEnv,instAtoms_nil,substAtoms_nil,
      Eff.norm,Eff.fails,rowFails,List.length_nil,List.range_zero,List.filter_nil,List.flatMap_nil,List.append_nil] at hf ⊢
    rw [hf]
  have hcl := ClosureTy.capture_resolved_closed hcap (.C_Eff hbody hc) hL
    (by rw [ha,hwide]; exact done_annotation_with_atoms hq.annotation et.atoms) hR hr
  rw [ha,hwide,←heqQ] at hcl
  exact ⟨hcl,he.widen_atoms.2⟩

theorem StateTyE.operation_one {P B σ Eb o name x y eff v cap cs k1 k2 k μ body l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.op o []) [v])) k μ))
    (hd : P.ops o = some ⟨eff, [], [name], [x], y, []⟩)
    (hxn : x.Normal) (hyn : y.Normal)
    (hsp : SplitAt (.user o) k k1 cap cs k2)
    (hc : findClause cs (.user o) = some (.mk (.user o) 1 0 body))
    (hbn : body.substTy [] [] = body) (hf : μ l = none)
    (hv : closeVal Capture.empty v = v) :
    Step P B σ (.run (Closure.pure (.app (.op o []) [v])) k μ) none
      (.run (.mk (cap.extendMany [v, .loc l]) body) (.drop l :: k2)
        (μ.set l (.cont (k1 ++ [.handleF cap cs])))) ∧
    StateTyE P B σ Eb
      (.run (.mk (cap.extendMany [v, .loc l]) body) (.drop l :: k2)
        (μ.set l (.cont (k1 ++ [.handleF cap cs])))) := by
  change x.norm = x at hxn
  change y.norm = y at hyn
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hclosed,hkc,hμ⟩ := h
  obtain ⟨r,f,hargs,hle,hcov⟩ := hq.pure_operation hA.values hs.wf hd
  have hsig := hq.pure_operation_signature hd
  rw [mono_tel name x y eff hxn hyn] at hsig
  have hy : Ty.Annotation P [] (Ctx.extend [] x) y :=
    ⟨by simpa [Ty.WF,Ctx.extend] using hsig.wf.2.1,hsig.sorted.2.1,hsig.declared.2.1⟩
  have hn := hargs.normal (Tel.norm_idem _)
  have hra := hargs.resultAnnotation
  rw [mono_tel name x y eff hxn hyn] at hargs
  cases hargs with
  | param hx hval htail =>
    simp only [Tel.bind_done,←valEnv_openValue,←substTyValues_eq_bind,
      ←substEffValues_eq_bind,Eff.subst_values_single] at htail
    cases htail
    have hnf := handle_no_fail hk hsp.1 hsp.2.1
    obtain ⟨t,ec,eb,et,Rh,hks,hkt,hcove,hsub,hframe⟩ := hk.split_handle hsp.1 hnf
    obtain ⟨Γ,Φ,Rs,ts,ecs,ebs,hcap,hcs,hR,ht,hec,heb,han,has,hRs⟩ := hframe
    have hb := clause_one hcs hd hc
    have hr := hkt.return_annotation rfl
    let result := substTyValues (openValue v) y
    have hw : LocTy.WF (.cont result t ec Rh) := ⟨hra.wf,han.wf.1,han.wf.2.1,han.wf.2.2,fun r hr' => (hr r hr').wf⟩
    have hdecl : LocTy.Declared P (.cont result t ec Rh) :=
      ⟨hra.declared,han.declared.1,han.declared.2,fun r hr' => (hr r hr').declared⟩
    have hend : EndsWithHandle (k1 ++ [.handleF cap cs]) := ⟨k1,cap,cs,rfl⟩
    have hs' := hs.allocate_continuation hA.values hf hw hdecl hend ⟨R,e,.K_Sub hks hle⟩
    have hnone : Ψ l = none := by
      cases hp : Ψ l with
      | none => rfl
      | some x => exact False.elim (hs.2.2.2.1 l x hp hf)
    have hext := StoreTy.extends_put (x := LocTy.cont result t ec Rh) hnone
    let Ψ' := Ψ.put l (.cont result t ec Rh)
    have hhideExt : (hideBuilders Ψ).Extends Ψ' := fun i x hi => hext i x (StoreTy.hide_extends Ψ i x hi)
    have hcap' := hcap.store hA.values hs.wf.hide hhideExt.preservesNormals
    have hval' := hval.store_extend hA.values hs.wf hext
    have hxΓ : Ty.Annotation P [] Γ x := annotation_closed hx
    have hc1 := hcap'.extend (v := v) hxΓ (by
      simpa only [Capture.closeTy,Ty.subst_values_of_wf_zero hx.wf,hxn] using hval') hclosed.2.2.1
    have hcontAnn : (Ty.cont y (ts.shiftV 1 0) (ecs.shiftV 1 0)).CaptureWF 0 0 (Γ.extend x).length :=
      ⟨(annotation_one (Γ := Γ) hx hy).wf,by simpa [Ctx.extend] using Ty.wf_shiftV has.wf 1 0⟩
    have hcontSort : (Ty.cont y (ts.shiftV 1 0) (ecs.shiftV 1 0)).CaptureSorted (Γ.extend x) :=
      ⟨(annotation_one (Γ := Γ) hx hy).sorted,(ShiftMap.outerValue Γ (some (x.shiftV 1 0))).sorted has.sorted⟩
    have hcontDecl : (Ty.cont y (ts.shiftV 1 0) (ecs.shiftV 1 0)).CaptureDeclared P [] (Γ.extend x) :=
      ⟨(annotation_one (Γ := Γ) hx hy).declared,(ShiftMap.outerValue Γ (some (x.shiftV 1 0))).declared has.declared⟩
    have heq : (cap.extend v).closeTy (.cont y (ts.shiftV 1 0) (ecs.shiftV 1 0)) = .cont result t ec := by
      change Ty.cont ((cap.extend v).closeTy y) ((cap.extend v).closeTy (ts.shiftV 1 0))
        ((cap.extend v).closeEff (ecs.shiftV 1 0)) = _
      rw [close_one cap name eff v hx hy hxn hyn,Capture.closeTy_shift,closeEff_shift,ht,hec]
    have hc2 := hc1.extendCont (l := l) hcontAnn hcontSort hcontDecl heq
      (by rw [heq]; exact ⟨hw.1,hw.2.1,hw.2.2.1,hw.2.2.2.1⟩) (by simp [Ψ',StoreTy.put])
      (fun r hr' => (hr r hr').wf)
    have hb' := hb.store_extend hA.values hs.wf.hide.hide
      (fun i x hi => hext i x (StoreTy.hide_extends Ψ i x (StoreTy.hide_extends (hideBuilders Ψ) i x hi)))
    have hR2 : ((cap.extend v).extend (.loc l)).closeR (Rs.map (Ty.shiftV 2 0)) = Rh := by
      cases Rs with
      | none => exact hR
      | some r => change some (((cap.extend v).extend (.loc l)).closeTy (r.shiftV 2 0)) = _; rw [closeTy_two]; exact hR
    have ht2 := closeTy_two cap v (.loc l) ts
    have he2 := closeEff_two cap v (.loc l) ecs
    rw [ht] at ht2
    rw [hec] at he2
    have hbody : ClosureTy P B Ψ' [] Rh (.mk ((cap.extend v).extend (.loc l)) body) t ec := by
      have hrd : ∀ r, Rs.map (Ty.shiftV 2 0) = some r →
          r.Declared P [] ((Γ.extend x).extend (.cont y (ts.shiftV 1 0) (ecs.shiftV 1 0))) := by
        intro r hr'
        obtain ⟨rr,hrr,her⟩ := Option.map_eq_some_iff.mp hr'
        cases her
        have hh := (ShiftMap.outerValue (Γ.extend x) (some ((Ty.cont y (ts.shiftV 1 0) (ecs.shiftV 1 0)).shiftV 1 0))).declared
          ((ShiftMap.outerValue Γ (some (x.shiftV 1 0))).declared (hRs rr hrr))
        simpa only [Ty.shiftV_add,Nat.reduceAdd,Ctx.extend] using hh
      have hh := ClosureTy.capture_resolved_closed hc2 hb' (CaptureLocals.empty _ _ LocalRef.bound)
        (by rw [ht2,he2]; exact han) hR2 hrd
      rw [ht2,he2,hb'.resolve_id LocalRef.bound (LocalsFixed.empty _)] at hh
      exact hh
    have hbody' : ClosureTy P B Ψ' [] Rh (.mk (cap.extendMany [v,.loc l]) body) t ec := by
      simpa only [Capture.extendMany,List.foldl_cons,List.foldl_nil] using hbody
    have hkcSplit : (k1 ++ [Frame.handleF cap cs]).Closed := by
      intro f hf'
      apply hkc f
      rw [hsp.1]
      rcases List.mem_append.mp hf' with hf' | hf'
      · exact List.mem_append_left _ hf'
      · simp only [List.mem_singleton] at hf'; subst f
        exact List.mem_append_right _ List.mem_cons_self
    have hfcl : cap.Closed ∧ Clause.ClosedList 0 cap.values.length cs := by
      exact hkc _ (hsp.1 ▸ List.mem_append_right _ List.mem_cons_self)
    have hfad : Frame.Adequate σ (.handleF cap cs) := hk.adequate _
      (hsp.1 ▸ List.mem_append_right _ List.mem_cons_self)
    have hmem : Clause.mk (.user o) 1 0 body ∈ cs := List.mem_of_find?_eq_some hc
    have hbc : body.ClosedAt 0 (cap.values.length + 2) := by
      simpa only [Nat.add_zero,show cap.values.length+1+1 = cap.values.length+2 by omega] using clause_closed hfcl.2 hmem
    have hba : body.Adequate σ := clause_adequate hfad.2 hmem
    obtain ⟨hbodyWide,hbodySub⟩ := hbody'.widen_atoms hcove
    refine ⟨?_,Ψ',Rh,t,b,et,_,hs',hbodyWide,hbodySub,?_,?_,?_,?_,?_⟩
    · have hstep := Step.E_Op (P := P) (B := B) (σ := σ)
        (q := Closure.pure (.app (.op o []) [v]))
        (by change Comp.app (.op o []) [closeVal Capture.empty v] = _; rw [hv]) hsp hc hf
      simpa only [Closure.capture,Clause.body,hbn,List.cons_append,List.nil_append] using hstep
    · exact .K_Drop (b' := result) (t' := t) (e' := ec) (R' := Rh) (by simp [Ψ',StoreTy.put]) (covers_state hcove) (hkt.store hA.values hs.wf hext)
    · cases cap
      exact ⟨⟨trivial,had.2.2.1,hfad.1⟩,hba⟩
    · change (cap.extendMany [v,.loc l]).Closed ∧ body.ClosedAt 0 _
      constructor
      · cases cap
        exact ⟨trivial,hclosed.2.2.1,hfcl.1⟩
      · simpa [Capture.extendMany,Capture.extend,Capture.values] using hbc
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
        exact hkcSplit
      · simp only [Store.set,hil,↓reduceIte] at hcell
        exact hμ i cell hcell

end
end Benitoite.Release.Refinement
