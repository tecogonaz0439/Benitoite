import ClosureR4Extra

namespace Benitoite.Release.Refinement.ClosureR4Rows
open Benitoite.Release.Refinement.ClosureR4
open Benitoite.Release.Refinement.ClosureR4Extra
noncomputable section
set_option linter.unusedSimpArgs false

def ioName : String := "IO.Secrets.Read"
def topE : Eff := Eff.single ioName
def eps : Eff := .mk topE.atoms [unitT]
def rawEc (atoms : Atom → Bool) : Eff := .mk atoms [unitT,unitT]
def ec (atoms : Atom → Bool) : Eff := .mk atoms [unitT]
def dupE : Eff := rawEc (fun _ => false)
def narrowAtoms (a : Atom) : Bool := decide (a = .name ioName (.fixed .secrets))
def outerH : List Clause := [.fail unitT (.ret (.var 2))]
def outerK : Cont := [.handleF cap outerH]
def rowK : Cont := polyK ++ outerK

theorem close_raw (atoms) (c : Capture) : c.closeEff (rawEc atoms) = ec atoms := by
  simp [Capture.closeEff,substEffValues,rawEc,ec,unitT,Eff.bind,Eff.rawBind,valEnv,Ty.rawBind,rawBindTys,
    rowFails,instAtoms_nil,substAtoms_nil,Eff.norm,Ty.norm,Ty.normTys_eq_map]
  rfl

theorem close_top (c : Capture) : c.closeEff topE = topE :=
  Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := topE) trivial rfl _

theorem ec_ann (atoms) : Ty.Annotation polyP [] [] (.dependentFn (.done refTy (ec atoms))) :=
  ⟨⟨(ref_ann polyP).wf,⟨trivial,trivial⟩,rfl⟩,
    ⟨(ref_ann polyP).sorted,⟨trivial,trivial⟩⟩,⟨(ref_ann polyP).declared,⟨trivial,trivial⟩⟩⟩

theorem eps_builtin : BuiltinOnly polyP polyB topE := by
  refine ⟨rfl,?_⟩
  intro a ha
  have he : a = .name ioName (.fixed .top) := of_decide_eq_true ha
  subst a; exact ⟨ioName,.fixed .top,rfl,rfl,rfl⟩

theorem outer_clause (Ψ : StoreTy) :
    HasFailureClause polyP polyB Ψ Qempty [] Γ0 [] unitT none outerH (R 0) Eff.empty [] := by
  refine .one ⟨trivial,trivial,trivial⟩ ⟨(contents0_ann polyP).wf,R0_sorted,R0_declared polyP⟩ ?_ ?_
  · intro e he; have he := List.mem_singleton.mp he; subst e
    exact ⟨⟨⟨rfl,by decide⟩,trivial,trivial,trivial,rfl⟩,⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩⟩
  · have ha : Ty.Annotation polyP [{}] (failureContext Γ0 unitT) (R 2) :=
      ⟨by simp [R,scalar,failureContext,Γ0,Ctx.shiftE,Ctx.shiftEAt,Ctx.extend,Ctx.extendNone,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core],
       ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩,
       ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar,rfl,by simp [scalar]⟩⟩⟩⟩
    exact .C_Return (.V_Refine (.V_Var (i := 2) rfl (by change scalar.Ordinary; simp [scalar,Ty.Ordinary])) rfl rfl
      ha.sorted.2 ha.wf.2.1 .eq_refl trivial ha.declared.2)

theorem outer_cont (σ : PathEnv) (Ψ : StoreTy) :
    ContTy polyP polyB σ Ψ none eps outerK refTy refTy topE none := by
  refine .K_Handle_Fail (ec := Eff.empty) (rest := topE) (E := unitT)
    (.K_Empty (subRefl _) (ref_ann polyP)) (Eff.Covers.refl [] [] _)
    ⟨rfl,by intro i hi; cases hi⟩ (capture_typed polyP polyB _) (outer_clause _)
    rfl rfl (close_empty _) (close_base _ _) (by intros; contradiction) ?_ (ref_ann polyP) ?_
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx)⟩
  · simp [Frame.Adequate,outerH,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,adequateClauses,Comp.Adequate,Val.Adequate]

theorem row_clause (atoms) (Ψ : StoreTy) :
    HasTypeClauses polyP polyB Ψ [] Γ0 [] none pickE polyH (R 0) (rawEc atoms) := by
  refine .cons (sg := pickSig) (ClauseSig.of_opSig rfl) ⟨rfl,by decide⟩ rfl rfl ?_ ?_ .nil
  · exact ⟨⟨(by simp [pickSig,Ty.WF]),trivial⟩,(by simp [pickSig,Ty.WF])⟩
  · refine .C_Resume (i := 0) rfl (.V_Var (i := 1) rfl (by simp [pickSig,Ty.Ordinary,Ty.shiftV,shiftTypes])) ?_
    exact ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar,rfl,by simp [scalar]⟩⟩⟩

theorem pick_sub_any (e : Eff) : Eff.Sub pickE (Eff.union e (handled polyP polyB polyH)) := by
  refine ⟨?_,?_⟩
  · intro a ha
    have h := (Eff.mem_norm _ _).mp (pick_sub.1 a ha)
    have hh : (handled polyP polyB polyH).test a = true := by
      change (false || _) = true at h; exact h
    apply (Eff.mem_norm _ _).mpr
    change (e.test a || _) = true; simp only [hh,Bool.or_true]
  · intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx

theorem row_cont (atoms) (hc : Eff.Covers [] [] eps (ec atoms)) (σ : PathEnv) (Ψ : StoreTy) :
    ContTy polyP polyB σ Ψ none pickE rowK refTy refTy topE none := by
  refine .K_Handle (ec := ec atoms) (eb := pickE) (Rs := none) (ts := R 0) (ecs := rawEc atoms) (ebs := pickE)
    (outer_cont σ Ψ) hc (pick_sub_any _) (capture_typed polyP polyB _)
    (row_clause atoms _) rfl rfl (close_raw _ _) (pick_close _)
    (done_annotation_of_covers (done_annotation_with_atoms (ec_ann atoms) eps.atoms) hc rfl)
    ⟨(contents0_ann polyP).wf,R0_sorted,R0_declared polyP⟩ (by intros; contradiction) ?_
  simp [Frame.Adequate,polyH,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,adequateClauses,Comp.Adequate,Val.Adequate]

theorem captured_cont (atoms) (σ : PathEnv) (Ψ : StoreTy) :
    ContTy polyP polyB σ Ψ none pickE polyK refTy refTy (ec atoms) none := by
  refine .K_Handle (ec := ec atoms) (eb := pickE) (Rs := none) (ts := R 0) (ecs := rawEc atoms) (ebs := pickE)
    (.K_Empty (subRefl _) (ref_ann polyP)) (Eff.Covers.refl [] [] _) (pick_sub_any _)
    (capture_typed polyP polyB _) (row_clause atoms _) rfl rfl (close_raw _ _) (pick_close _)
    (ec_ann atoms) ⟨(contents0_ann polyP).wf,R0_sorted,R0_declared polyP⟩ (by intros; contradiction) ?_
  simp [Frame.Adequate,polyH,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,adequateClauses,Comp.Adequate,Val.Adequate]

theorem outer_closed : (Frame.handleF cap outerH).Closed := by
  simp [Frame.Closed,outerH,cap,seven,Capture.values,Capture.Closed,captureSlotsClosed,Clause.ClosedList,Comp.ClosedAt,Val.ClosedAt,unitT,Ty.WF]


def rowΓ (atoms : Atom → Bool) : Ctx := [some (.cont refTy (R 2) (rawEc atoms)),some refTy,some scalar]
def rowΨ (atoms : Atom → Bool) : StoreTy := oneTy (.cont refTy refTy (ec atoms) none)
def rowμ : Store := Store.empty.set 0 (.cont polyK)

theorem row_R_ann (atoms) : Ty.Annotation polyP [] (rowΓ atoms) (R 2) := by
  refine ⟨?_,?_,?_⟩
  · simp [R,scalar,rowΓ,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · exact ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩
  · exact ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar,rfl,by simp [scalar]⟩⟩⟩

theorem row_capture (atoms) : CaptureOk polyP polyB (rowΨ atoms) none (rowΓ atoms) [] opCap := by
  have hget : ∀ i a, (rowΓ atoms)[i]? = some (some a) →
      (i = 0 ∧ a = .cont refTy (R 2) (rawEc atoms)) ∨ (i = 1 ∧ a = refTy) ∨ (i = 2 ∧ a = scalar) := by
    intro i a hi
    cases i with
    | zero => cases hi; exact Or.inl ⟨rfl,rfl⟩
    | succ i => cases i with
      | zero => cases hi; exact Or.inr (Or.inl ⟨rfl,rfl⟩)
      | succ i => cases i with
        | zero => cases hi; exact Or.inr (Or.inr ⟨rfl,rfl⟩)
        | succ i => simp [rowΓ] at hi
  have hRef : substTyValues opCap.env refTy = refTy := Ty.subst_values_of_wf_zero (ref_ann polyP).wf _
  have hR : substTyValues opCap.env (R 2) = refTy := rfl
  have hκ : substTyValues opCap.env (.cont refTy (R 2) (rawEc atoms)) = .cont refTy refTy (ec atoms) := by
    change Ty.cont (substTyValues opCap.env refTy) (substTyValues opCap.env (R 2)) (substEffValues opCap.env (rawEc atoms)) = _
    rw [hRef,hR,show substEffValues opCap.env (rawEc atoms) = ec atoms from close_raw atoms opCap]
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨(closed_ref_ann polyP (rowΓ atoms)).wf,(row_R_ann atoms).wf⟩
    · exact (closed_ref_ann polyP (rowΓ atoms)).wf
    · trivial
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨.loc 0,rfl⟩
    · exact ⟨seven,rfl⟩
    · exact ⟨seven,rfl⟩
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨⟨(closed_ref_ann polyP (rowΓ atoms)).sorted,(row_R_ann atoms).sorted⟩,⟨(closed_ref_ann polyP (rowΓ atoms)).declared,(row_R_ann atoms).declared⟩⟩
    · exact ⟨(closed_ref_ann polyP (rowΓ atoms)).sorted,(closed_ref_ann polyP (rowΓ atoms)).declared⟩
    · exact ⟨trivial,trivial⟩
  · intro p hp; cases hp
  · intro ov ho v he
    simp [opCap,cap,seven,Capture.extendMany,Capture.extend,Capture.values] at ho
    rcases ho with rfl | rfl <;> cases he <;> trivial
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact .contLoc rfl hκ (by rw [hκ]; exact ⟨(ref_ann polyP).wf,(ref_ann polyP).wf,⟨trivial,trivial⟩,rfl⟩) rfl rfl (by intros; contradiction)
    · refine .ordinary (by change Ty.Ordinary (.refined scalar (.eq (.var 0) (.integer 7))); simp [Ty.Ordinary]) ?_
      rw [hRef]; exact seven_ref polyP polyB (rowΨ atoms)
    · exact .ordinary (by simp [scalar]) (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide))
  · intro p hp
    have hf : (rowΓ atoms).facts = [.eq (.var 1) (.integer 7)] := rfl
    rw [List.append_nil,hf] at hp
    have he := List.mem_singleton.mp hp; subst p
    exact .eq_refl


theorem closed_wrap {Ψ Γ cap body a e}
    (hc : CaptureOk polyP polyB Ψ none Γ [] cap)
    (hb : HasTypeC polyP polyB Ψ [] Γ [] none body a e)
    (ha : Ty.Annotation polyP [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e)))) :
    ClosureTy polyP polyB Ψ [] none (.mk cap body) (cap.closeTy a) (cap.closeEff e) := by
  have hb' : HasTypeCQ polyP polyB Ψ Qempty [] (bindParams Γ []) (liftMany 0 []) none body a e [] := by
    simpa only [bindParams,List.reverse_nil,List.map_nil,List.length_nil,List.nil_append,liftMany_eq,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hb
  have hh := ClosureTy.mk (ss := []) (Rs := none) (a := a) (e := e) hc hb'
    (by simpa only [List.length_nil,upSubst_zero] using CaptureLocals.empty Ψ cap.env LocalRef.bound) (Comp.resolveLocals_id body).symm
    (by simp [TypeAnnotations]) (by simp [TypeAnnotations]) rfl
    (by simpa [bindParams,Capture.closeTyAt,Capture.closeTy,upSubst_zero] using
      (show Ty.Annotation polyP [] [] (cap.closeTy a) from ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩))
    (by simpa [bindParams,Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero] using ha)
    (by intros; contradiction) (by intros; contradiction)
  simpa [Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero] using hh

theorem row_store (atoms) (σ : PathEnv) : StoreOk polyP polyB σ (rowΨ atoms) rowμ :=
  one_store ⟨(ref_ann polyP).wf,(ref_ann polyP).wf,⟨trivial,trivial⟩,rfl,by intros; contradiction⟩
    ⟨(ref_ann polyP).declared,(ref_ann polyP).declared,⟨trivial,trivial⟩,by intros; contradiction⟩
    ⟨refTy,refTy,ec atoms,none,rfl,⟨[],cap,polyH,rfl⟩,none,pickE,captured_cont atoms σ _⟩

theorem row_drop (atoms) (hc : Eff.Covers [] [] eps (ec atoms)) (σ : PathEnv) :
    ContTy polyP polyB σ (rowΨ atoms) none eps (.drop 0 :: outerK) refTy refTy topE none := by
  refine .K_Drop rfl ?_ (outer_cont σ _)
  intro hs
  obtain ⟨b,hb,hcover⟩ := hc.1 _ hs
  have he : b = .name ioName (.fixed .top) := of_decide_eq_true hb
  subst b
  exact False.elim ((by decide : ioName ≠ stateEff) hcover.1)

theorem raw_covered (atoms) : Eff.Covers [] [] (ec atoms) (rawEc atoms) := by
  refine ⟨fun a ha => ⟨a,ha,Atom.Covers.refl a⟩,?_⟩
  intro t ht; obtain ⟨x,hx,he⟩ := ht
  have hx : x = unitT := by simpa [rawEc,Eff.fails] using hx
  subst x; exact ⟨unitT,by simp [ec,Eff.fails],he⟩

theorem op_after (atoms) (hc : Eff.Covers [] [] eps (ec atoms)) (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run opQ (.drop 0 :: outerK) rowμ) := by
  have hb : HasTypeC polyP polyB (rowΨ atoms) [] (rowΓ atoms) [] none
      (.resume (.var 0) (.var 1)) (R 2) (rawEc atoms) :=
    .C_Resume (i := 0) rfl (.V_Var (i := 1) rfl
      (by change Ty.Ordinary (.refined scalar (.eq (.var 0) (.integer 7))); simp [Ty.Ordinary])) (row_R_ann atoms).declared
  have hw : Eff.Covers [] [] eps (rawEc atoms) := hc.widen_atoms.1.trans (raw_covered atoms)
  have hw' : Eff.Covers (rowΓ atoms) [] eps (rawEc atoms) := hw
  have he : opCap.closeEff eps = eps :=
    Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := eps) ⟨trivial,trivial⟩ rfl _
  have hq : ClosureTy polyP polyB (rowΨ atoms) [] none opQ refTy eps := by
    change ClosureTy polyP polyB (rowΨ atoms) [] none opQ (opCap.closeTy (R 2)) eps
    have ha : Ty.Annotation polyP [] [] (.dependentFn (.done (opCap.closeTy (R 2)) (opCap.closeEff eps))) := by
      rw [he]; exact done_annotation_with_atoms (ec_ann atoms) eps.atoms
    simpa [opQ,he] using closed_wrap (row_capture atoms) (.C_Eff hb hw') ha
  apply run_state hv eps_builtin (row_store atoms σ) hq (row_drop atoms hc σ)
  · simp [opQ,opCap,cap,seven,Capture.values,Capture.extendMany,Capture.extend,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [opQ,opCap,cap,seven,Capture.values,Capture.extendMany,Capture.extend,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; simp [outerK] at hf; rcases hf with rfl | rfl
    · trivial
    · exact outer_closed
  · exact one_closed (by intro f hf; have he := List.mem_singleton.mp hf; subst f; exact poly_frame_closed)

theorem handle_after (atoms) (hc : Eff.Covers [] [] eps (ec atoms)) (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyQ rowK Store.empty) := by
  have hq : ClosureTy polyP polyB StoreTy.empty [] none polyQ refTy pickE := by
    simpa [polyQ,refTy,pick_close] using wrap poly_comp
      (show Ty.Annotation polyP [] Γ0 (.dependentFn (.done (R 0) pickE)) from
        ⟨⟨(contents0_ann polyP).wf,trivial,rfl⟩,⟨R0_sorted,trivial⟩,⟨R0_declared polyP,trivial⟩⟩)
  apply run_state hv eps_builtin (StoreOk.empty polyP polyB σ) hq (row_cont atoms hc σ _)
  · simp [polyQ,polyCode,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [polyQ,polyCode,cap,seven,Capture.values,R,scalar,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · intro f hf; simp [rowK,polyK,outerK] at hf; rcases hf with rfl | rfl
    · exact poly_frame_closed
    · exact outer_closed
  · intro l c hc; cases hc

theorem handle_before (atoms) (hc : Eff.Covers [] [] eps (ec atoms)) (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyHandleQ outerK Store.empty) := by
  have hb : HasTypeC polyP polyB StoreTy.empty [] Γ0 [] none (.handle polyCode polyH) (R 0) (rawEc atoms) :=
    .C_Handle poly_comp (pick_sub_any _) (row_clause atoms _)
  have he : cap.closeEff eps = eps :=
    Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := eps) ⟨trivial,trivial⟩ rfl _
  have hw : Eff.Covers Γ0 [] eps (rawEc atoms) := hc.widen_atoms.1.trans (raw_covered atoms)
  have hq : ClosureTy polyP polyB StoreTy.empty [] none polyHandleQ refTy eps := by
    have ha : Ty.Annotation polyP [] [] (.dependentFn (.done (cap.closeTy (R 0)) (cap.closeEff eps))) := by
      rw [he]; exact done_annotation_with_atoms (ec_ann atoms) eps.atoms
    simpa [polyHandleQ,refTy,he] using closed_wrap (capture_typed polyP polyB _) (.C_Eff hb hw) ha
  apply run_state hv eps_builtin (StoreOk.empty polyP polyB σ) hq (outer_cont σ _)
  · simp [polyHandleQ,polyCode,polyH,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals,adequateClauses]
  · simp [polyHandleQ,polyCode,polyH,cap,seven,Capture.values,R,scalar,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Clause.ClosedList,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f; exact outer_closed
  · intro l c hc; cases hc

theorem fail_handle (atoms) (hc : Eff.Covers [] [] eps (ec atoms)) (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyHandleQ outerK Store.empty) ∧
    Step polyP polyB σ (.run polyHandleQ outerK Store.empty) none (.run polyQ rowK Store.empty) ∧
    StateTy polyP polyB σ (.run polyQ rowK Store.empty) :=
  ⟨handle_before atoms hc σ hv,.E_Handle rfl,handle_after atoms hc σ hv⟩

theorem fail_op (atoms) (hc : Eff.Covers [] [] eps (ec atoms)) (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyQ rowK Store.empty) ∧
    Step polyP polyB σ (.run polyQ rowK Store.empty) none (.run opQ (.drop 0 :: outerK) rowμ) ∧
    StateTy polyP polyB σ (.run opQ (.drop 0 :: outerK) rowμ) := by
  refine ⟨handle_after atoms hc σ hv,?_,op_after atoms hc σ hv⟩
  exact .E_Op (q := polyQ) (μ := Store.empty) (k := rowK) (hcap := cap) (h := polyH)
    (c := .mk (.user "pick") 1 1 (.resume (.var 0) (.var 1))) (o := "pick") (ts := [refTy]) (ws := [seven])
    (k1 := []) (k2 := outerK) (κ := 0) rfl ⟨rfl,rfl,by intro cap h he; cases he⟩ rfl rfl


theorem false_covers : Eff.Covers [] [] eps (ec (fun _ => false)) :=
  ⟨(by intro a ha; cases ha),fun _ hx => hx⟩

theorem narrow_covers : Eff.Covers [] [] eps (ec narrowAtoms) := by
  refine ⟨?_,fun _ hx => hx⟩
  intro a ha
  have he : a = .name ioName (.fixed .secrets) := of_decide_eq_true ha
  subst a
  exact ⟨.name ioName (.fixed .top),by decide,⟨rfl,RangeExpr.top_covers _⟩⟩

theorem narrow_not_sub : ¬ Eff.Sub (ec narrowAtoms) eps := by
  intro h
  have hh := h.1 (.name ioName (.fixed .secrets)) (by decide)
  change decide ((Atom.name ioName (.fixed .secrets)) = .name ioName (.fixed .top)) = true at hh
  have hn : decide ((Atom.name ioName (.fixed .secrets)) = .name ioName (.fixed .top)) = false := by decide
  rw [hn] at hh; cases hh

theorem dup_context_not_wf : ¬ Ctx.WF 0 0 (rowΓ (fun _ => false)) := by
  intro h
  have hc := (h 0 _ rfl).2.2.2
  have hl := congrArg (fun e : Eff => e.fails.length) hc
  change 1 = 2 at hl
  cases hl

theorem dup_capture_wf : Ctx.CaptureWF 0 0 (rowΓ (fun _ => false)) :=
  (row_capture (fun _ => false)).wf

theorem dup_closed_image_wf :
    (substTyValues opCap.env (.cont refTy (R 2) dupE)).WF 0 0 0 :=
  (row_capture (fun _ => false)).continuation_image_wf (i := 0) rfl

theorem ordinary_capture_annotation {P B Ψ R Γ Φ cap} {i : Nat} {a : Ty}
    (h : CaptureOk P B Ψ R Γ Φ cap) (hi : Γ[i]? = some (some a)) (ho : a.Ordinary) :
    Ty.Annotation P [] Γ a := by
  cases h with
  | mk hw _ _ hd _ _ _ _ =>
    have hh := hd i a hi
    refine ⟨(hw i a hi).ordinary ho,?_,?_⟩
    · cases a <;> first | exact hh.1 | cases ho _ _ _ rfl
    · cases a <;> first | exact hh.2 | cases ho _ _ _ rfl

theorem dup_handle (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyHandleQ outerK Store.empty) ∧
    Step polyP polyB σ (.run polyHandleQ outerK Store.empty) none (.run polyQ rowK Store.empty) ∧
    StateTy polyP polyB σ (.run polyQ rowK Store.empty) :=
  fail_handle (fun _ => false) false_covers σ hv

theorem dup_op (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyQ rowK Store.empty) ∧
    Step polyP polyB σ (.run polyQ rowK Store.empty) none (.run opQ (.drop 0 :: outerK) rowμ) ∧
    StateTy polyP polyB σ (.run opQ (.drop 0 :: outerK) rowμ) :=
  fail_op (fun _ => false) false_covers σ hv

theorem narrow_handle (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyHandleQ outerK Store.empty) ∧
    Step polyP polyB σ (.run polyHandleQ outerK Store.empty) none (.run polyQ rowK Store.empty) ∧
    StateTy polyP polyB σ (.run polyQ rowK Store.empty) :=
  fail_handle narrowAtoms narrow_covers σ hv

theorem narrow_op (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyQ rowK Store.empty) ∧
    Step polyP polyB σ (.run polyQ rowK Store.empty) none (.run opQ (.drop 0 :: outerK) rowμ) ∧
    StateTy polyP polyB σ (.run opQ (.drop 0 :: outerK) rowμ) :=
  fail_op narrowAtoms narrow_covers σ hv

/-- C_Subを二つ重ねても、本体の像の型付けと閉じた結果の一致が得られる。 -/
theorem builder_sub_chain {P B Ψ Q C Γ Φ} {R : Option Ty} {body : Comp} {a : Ty} {e : Eff} {L k} {b d : Ty} {f g : Eff}
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) (hΓ : Ctx.WF 0 C.length Γ)
    (hb : HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) body
      (a.shiftV 1 0) (e.shiftV 1 0) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L))
    (hab : Ty.LeQ Γ.extendNone (Φ.map Pred.lift) (a.shiftV 1 0) (b.shiftV 1 0))
    (hbd : Ty.LeQ Γ.extendNone (Φ.map Pred.lift) (b.shiftV 1 0) (d.shiftV 1 0))
    (hef : Eff.Covers Γ.extendNone (Φ.map Pred.lift) (f.shiftV 1 0) (e.shiftV 1 0))
    (hfg : Eff.Covers Γ.extendNone (Φ.map Pred.lift) (g.shiftV 1 0) (f.shiftV 1 0))
    (hbAnn : Ty.Annotation P C Γ.extendNone (b.shiftV 1 0))
    (hdAnn : Ty.Annotation P C Γ.extendNone (d.shiftV 1 0)) :
    HasTypeCQ P B Ψ Q C Γ Φ ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst))
      (body.subst builderValueSubst LocalRef.bound)
      (substTyValues builderValueSubst (d.shiftV 1 0)) (substEffValues builderValueSubst (g.shiftV 1 0))
      (some (imageKind k) :: imageLocal L) := by
  exact HasTypeCQ.builderBody_image hA hw hΓ
    (.C_Sub (.C_Sub hb hab hef hbAnn.wf hbAnn.sorted hbAnn.declared) hbd hfg hdAnn.wf hdAnn.sorted hdAnn.declared)


theorem continuation_capture_types {P B Ψ R Γ Φ cap} {i : Nat} {b t : Ty} {e : Eff}
    (h : CaptureOk P B Ψ R Γ Φ cap) (hi : Γ[i]? = some (some (.cont b t e))) :
    Ty.Annotation P [] Γ b ∧ Ty.Annotation P [] Γ t := by
  cases h with
  | mk hw _ _ hd _ _ _ _ =>
    have hf := hw i _ hi
    have hs := hd i _ hi
    exact ⟨⟨hf.1,hs.1.1,hs.2.1⟩,⟨hf.2,hs.1.2,hs.2.2⟩⟩

theorem ordinary_dup_rejected {P B Ψ R Φ cap} :
    ¬ CaptureOk P B Ψ R [some (.fn [] [] unitT dupE)] Φ cap := by
  intro h
  have ha := ordinary_capture_annotation h (i := 0) rfl (by simp [Ty.Ordinary])
  have hc : Eff.Canonical dupE := ha.wf.2.2.2.2
  have hl := congrArg (fun e : Eff => e.fails.length) hc
  change 1 = 2 at hl
  cases hl


end
end Benitoite.Release.Refinement.ClosureR4Rows

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := env.constants.toList.filterMap fun (n,_) =>
    if (`Benitoite.Release.Refinement.ClosureR4Rows).isPrefixOf n then some n else none
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for n in names do
    elabCommand (← `(#print axioms $(mkIdent n)))
