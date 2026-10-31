import ClosureR3Boundary

namespace Benitoite.Release.Refinement.ClosureR3Extra
open Benitoite.Release.Refinement.ClosureR3
noncomputable section
set_option linter.unusedSimpArgs false

/-! パターンが束縛した参照を、捕捉に依存する型の引数へ実際に渡す。 -/
def matchedΓ : Ctx := refΓ.extend (.reference (R 1))
def matchedCap : Capture := refCap.extend (.loc 0)
def matchedQ : Closure := .mk matchedCap refMatchUse

theorem matched_R_ann (P : Program) : Ty.Annotation P [] matchedΓ (R 2) :=
  ⟨by simp [matchedΓ,refΓ,Γ0,Ctx.extend,R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core],
   ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩,
   ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩⟩

theorem matched_capture (P : Program) (B : Builtins) : CaptureOk P B refΨ none matchedΓ [] matchedCap := by
  have hget : ∀ i a, matchedΓ[i]? = some (some a) →
      (i = 0 ∧ a = .reference (R 2)) ∨ (i = 1 ∧ a = .reference (R 2)) ∨ (i = 2 ∧ a = scalar) := by
    intro i a hi
    cases i with
    | zero => cases hi; exact Or.inl ⟨rfl,rfl⟩
    | succ i => cases i with
      | zero => cases hi; exact Or.inr (Or.inl ⟨rfl,rfl⟩)
      | succ i => cases i with
        | zero => cases hi; exact Or.inr (Or.inr ⟨rfl,rfl⟩)
        | succ i => simp [matchedΓ,refΓ,Γ0,Ctx.extend] at hi
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact (matched_R_ann P).wf
    · exact (matched_R_ann P).wf
    · trivial
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨.loc 0,rfl⟩
    · exact ⟨.loc 0,rfl⟩
    · exact ⟨seven,rfl⟩
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨(matched_R_ann P).sorted,(matched_R_ann P).declared⟩
    · exact ⟨(matched_R_ann P).sorted,(matched_R_ann P).declared⟩
    · exact ⟨trivial,trivial⟩
  · intro p hp; cases hp
  · intro ov ho v he
    simp [matchedCap,refCap,cap,seven,Capture.extend,Capture.values] at ho
    rcases ho with rfl | rfl <;> cases he <;> trivial
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · refine .ordinary (by simp [Ty.Ordinary]) ?_
      change HasTypeV P B refΨ [] [] [] (.loc 0) (.reference refTy)
      exact .V_LocRef rfl (ref_ann P).declared
    · refine .ordinary (by simp [Ty.Ordinary]) ?_
      change HasTypeV P B refΨ [] [] [] (.loc 0) (.reference refTy)
      exact .V_LocRef rfl (ref_ann P).declared
    · exact .ordinary (by simp [Ty.Ordinary,scalar]) (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide))
  · intro p hp; simp [matchedΓ,refΓ,Γ0,Ctx.extend,Ctx.facts,Ty.shiftV,renameTy,scalar,Ty.assume] at hp

theorem matched_typed (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ (.run matchedQ [] refμ) := by
  have hq : ClosureTy P B refΨ [] none matchedQ unitT Eff.empty := by
    have hh := ClosureTy.capture_resolved (matched_capture P B) (ref_match_use_typed P B)
      (captured_none _ _ LocalRef.bound 1) (done_ann (P := P) (Γ := matchedΓ) (a := unitT) ⟨trivial,trivial,trivial⟩)
      rfl (by intros; contradiction)
    simpa only [Comp.resolveLocals_id,unitT,close_base,close_empty,matchedQ] using hh
  apply run_state hv (empty_builtin P B) (ref_store P B σ) hq (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [matchedQ,matchedCap,refCap,cap,seven,Capture.values,Capture.extend,refMatchUse,Closure.Adequate,Capture.Adequate,
      adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [matchedQ,matchedCap,refCap,cap,seven,Capture.values,Capture.extend,refMatchUse,unitT,R,scalar,
      Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Ty.WF,Ty.WFList,
      Pred.WF,Pred.VarsIn,Term.VarsIn,NamesWF,Eff.WF,Eff.Canonical,Eff.norm,Eff.empty,Ty.NotContCore,Ty.core]
  · intro f hf; cases hf
  · exact one_closed trivial

theorem match_body (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (matchState 1) ∧ Step P B σ (matchState 1) none (.run matchedQ [] refμ) ∧
    StateTy P B σ (.run matchedQ [] refμ) :=
  ⟨match_typed P B σ hv 1 (by decide),.E_MatchBody (ws := [.loc 0]) rfl rfl,matched_typed P B σ hv⟩

/-! trueのguardが返った場合にも、同じ捕捉を持つ成功時の本体へ戻る。 -/
def trueArms : List Arm := [.mk wildAlt (some (.ret (.const (.boolean true)))) matchBody,
  .mk varAlt none refMatchUse]
def trueGuardQ : Closure := .mk refCap (.ret (.const (.boolean true)))
def trueGuardK : Cont := [.guardF (.loc 0) refCap trueArms 1 guardBody]

theorem true_arms (P : Program) (B : Builtins) :
    HasTypeArms P B refΨ [] refΓ [] none trueArms (.reference (R 1)) unitT Eff.empty :=
  .guarded (wild_alts P _) (.C_Return (.V_Const trivial)) (.C_Return (.V_Const trivial))
    (.plain (var_alts P _) (ref_match_use_typed P B) (.nil ⟨trivial,trivial,trivial⟩))

theorem true_guard_cont (P : Program) (B : Builtins) (σ : PathEnv) :
    ContTy P B σ refΨ none Eff.empty trueGuardK (.base .boolean) unitT Eff.empty none := by
  refine .K_Guard (Rs := none) (as := unitT) (es := Eff.empty)
    (ref_capture P B) (.V_Var (i := 0) rfl (by simp [Ty.Ordinary,Ty.shiftV,renameTy,R]))
    (true_arms P B) (CaptureLocals.empty _ _ LocalRef.bound) (Arm.resolveLocalsList_id trueArms).symm
    (by intros; contradiction) ?_ rfl rfl (close_base _ _) (close_empty _)
    (by simpa [guardBody,matchBody,unitT] using ref_wrap (P := P) (B := B) (.C_Return (.V_Const (c := .unit) trivial)) (a := unitT) ⟨trivial,trivial,trivial⟩)
    (subRefl _) ?_ (.K_Empty (subRefl _) ⟨trivial,trivial,trivial⟩) ?_
  · intro v hv; exact ⟨.var,by simp [trueArms,varAlt,unguardedPats],by simp [matchVal]⟩
  · intro arm ha hg; simp [trueArms] at ha; subst arm; cases hg
  · simp [Frame.Adequate,trueArms,guardBody,matchBody,refMatchUse,refCap,cap,seven,Capture.values,Capture.extend,
      Capture.Adequate,adequateCaptureSlots,Closure.Adequate,Comp.Adequate,Val.Adequate,adequateVals,adequateArms]

theorem true_guard_before (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run trueGuardQ trueGuardK refμ) := by
  apply run_state hv (empty_builtin P B) (ref_store P B σ)
    (by simpa [trueGuardQ] using ref_wrap (P := P) (B := B) (.C_Return (.V_Const (c := .boolean true) trivial)) (a := .base .boolean) ⟨trivial,trivial,trivial⟩)
    (true_guard_cont P B σ)
  · simp [trueGuardQ,refCap,cap,seven,Capture.values,Capture.extend,Capture.Adequate,adequateCaptureSlots,Closure.Adequate,Comp.Adequate,Val.Adequate]
  · simp [trueGuardQ,refCap,cap,seven,Capture.values,Capture.extend,Capture.Closed,captureSlotsClosed,Closure.ClosedAt,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f
    simp [Val.Ground,Frame.Closed,guardBody,matchBody,trueArms,refMatchUse,show Arm.bindersOf varAlt = 1 from rfl,
      unitT,R,scalar,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core,NamesWF,Eff.WF,Eff.Canonical,
      Eff.norm,Eff.empty,Val.ClosedList,refCap,cap,seven,Capture.values,Capture.extend,Capture.Closed,captureSlotsClosed,
      Closure.ClosedAt,Comp.ClosedAt,Val.ClosedAt,Arm.ClosedList]
  · exact one_closed trivial

theorem true_guard_after (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) : StateTy P B σ (.run guardBody [] refμ) := by
  apply run_state hv (empty_builtin P B) (ref_store P B σ)
    (by simpa [guardBody,matchBody,unitT] using ref_wrap (P := P) (B := B) (.C_Return (.V_Const (c := .unit) trivial)) (a := unitT) ⟨trivial,trivial,trivial⟩)
    (.K_Empty (a := unitT) (subRefl _) ⟨trivial,trivial,trivial⟩)
  · simp [guardBody,matchBody,refCap,cap,seven,Capture.values,Capture.extend,Capture.Adequate,adequateCaptureSlots,Closure.Adequate,Comp.Adequate,Val.Adequate]
  · simp [guardBody,matchBody,refCap,cap,seven,Capture.values,Capture.extend,Capture.Closed,captureSlotsClosed,Closure.ClosedAt,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; cases hf
  · exact one_closed trivial

theorem guard_true (P : Program) (B : Builtins) (σ : PathEnv) (hv : σ.Valid) :
    StateTy P B σ (.run trueGuardQ trueGuardK refμ) ∧
    Step P B σ (.run trueGuardQ trueGuardK refμ) none (.run guardBody [] refμ) ∧
    StateTy P B σ (.run guardBody [] refμ) :=
  ⟨true_guard_before P B σ hv,.E_GuardT rfl,true_guard_after P B σ hv⟩

/-! 操作の型引数とhandlerの結果を、捕捉したxの篩R(0)にする。 -/
def polyOp : OpDecl := ⟨"Pick",[{}],["value"],[.tvar 0],.tvar 0,[]⟩
def polyP : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun o => if o = "pick" then some polyOp else none
  effects := fun e => if e = "Pick" then some ["pick"] else none
  classes := fun _ => none
  impls := fun _ => none

def polyB : Builtins := {emptyBuiltins with sat := fun _ _ _ => True}
def pickE : Eff := .mk (fun a => match a with | .name n (.fixed .top) => decide (n = "Pick") | _ => false) []
def pickSig : OpSig := ⟨[{}],["value"],[.tvar 0],.tvar 0,"Pick"⟩
def polyH : List Clause := [.mk (.user "pick") 1 1 (.resume (.var 0) (.var 1))]
def polyCode : Comp := .app (.op "pick" [R 0]) [.var 0]
def polyQ : Closure := .mk cap polyCode
def polyHandleQ : Closure := .mk cap (.handle polyCode polyH)
def polyK : Cont := [.handleF cap polyH]

theorem refined_slot {P B Ψ Γ i} (hi : Γ[i]? = some (some scalar))
    (ha : Ty.Annotation P [] Γ (R i)) : HasTypeV P B Ψ [] Γ [] (.var i) (R i) := by
  exact .V_Refine (.V_Var hi (by simp [scalar,Ty.Ordinary])) rfl rfl ha.sorted.2 ha.wf.2.1 .eq_refl trivial ha.declared.2

theorem pick_inst : instantiatedTel polyOp.tel [R 0] [] =
    .param "value" (R 0) (.done (R 1) pickE) := by
  simp [instantiatedTel,polyOp,OpDecl.tel,signatureTel,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,
    typeEnvAt,SubstEnv.up,Tel.norm,Ty.norm,Eff.norm,instAtoms_nil,substAtoms_nil,rowFails,
    R,scalar,Ty.shiftV,renameTy,renEnv,predBind,termBind?,upValues,pickE]
  funext a; cases a <;> rfl

theorem pick_value : HasTypeV polyP polyB StoreTy.empty [] Γ0 [] (.op "pick" [R 0])
    (.dependentFn (.param "value" (R 0) (.done (R 1) pickE))) := by
  rw [←pick_inst]
  refine .V_Op (od := polyOp) rfl ⟨rfl,by decide⟩ ?_ ?_
  · exact ⟨rfl,by intros; trivial⟩
  · refine ⟨?_,?_,?_,by simp [RowAnnotations],?_⟩
    · exact ⟨(by simp [polyOp,Ty.WF]),(by simp [polyOp,Ty.WF]),trivial,rfl⟩
    · intro a ha; have he := List.mem_singleton.mp ha; subst a
      exact ⟨(contents0_ann polyP).wf,R0_sorted,R0_declared polyP⟩
    · exact kinded polyP _ (R_kind polyP 0)
    · rw [pick_inst]
      exact ⟨⟨(contents0_ann polyP).wf,by simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Γ0,Ty.NotContCore,Ty.core],trivial,rfl⟩,
        ⟨R0_sorted,R1_sorted,trivial⟩,⟨R0_declared polyP,R1_declared polyP,trivial⟩⟩

theorem pick_arguments : Tel.arguments (.param "value" (R 0) (.done (R 1) pickE)) [.var 0] =
    some ([R 0],R 0,pickE) := by
  have ht : Ty.bind (Tel.argumentsEnv (.var 0)) (R 1) = R 0 := by
    rw [←valEnv_openValue]
    exact (Ty.openValue_shift (R 0) (.var 0)).trans R0_canonical
  have he : Eff.bind (Tel.argumentsEnv (.var 0)) pickE = pickE := by
    rw [←valEnv_openValue]
    exact Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := pickE) trivial rfl _
  simp only [Tel.arguments,Tel.bind_done,ht,he,R0_canonical,show Eff.norm pickE = pickE from rfl,Option.map_some]

theorem poly_comp : HasTypeC polyP polyB StoreTy.empty [] Γ0 [] none polyCode (R 0) pickE := by
  refine HasTypeCQ.C_DependentApp pick_value ?_
  exact HasTypeTelArgsQ.of_arguments pick_arguments (.cons (source_refined_var polyP polyB _) .nil)
    (by
      change Ty.Annotation polyP [] Γ0 (.dependentFn (.param "value" (R 0) (.done (R 1) pickE)))
      exact ⟨⟨(contents0_ann polyP).wf,by simp [R,scalar,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Γ0,Ty.NotContCore,Ty.core],trivial,rfl⟩,
        ⟨R0_sorted,R1_sorted,trivial⟩,⟨R0_declared polyP,R1_declared polyP,trivial⟩⟩)
    (capture_typed polyP polyB StoreTy.empty).wf

theorem poly_clause (Ψ : StoreTy) : HasTypeClauses polyP polyB Ψ [] Γ0 [] none pickE polyH (R 0) Eff.empty := by
  refine .cons (sg := pickSig) (ClauseSig.of_opSig rfl) ⟨rfl,by decide⟩ rfl rfl ?_ ?_ .nil
  · exact ⟨⟨(by simp [pickSig,Ty.WF]),trivial⟩,(by simp [pickSig,Ty.WF])⟩
  · refine .C_Resume (i := 0) rfl (.V_Var (i := 1) rfl (by simp [pickSig,Ty.Ordinary,Ty.shiftV,shiftTypes])) ?_
    exact ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩

theorem pick_sub : Eff.Sub pickE (Eff.union Eff.empty (handled polyP polyB polyH)) := by
  refine ⟨?_,?_⟩
  · intro a ha
    cases a with
    | rho i => cases ha
    | name n ix =>
      cases ix with
      | rvar i => cases ha
      | fixed r =>
        cases r with
        | based b p => cases ha
        | secrets => cases ha
        | absolute r =>
          cases r with
          | path p | host p | endpoint p => cases ha
          | top =>
            have hn : n = "Pick" := of_decide_eq_true ha
            subst n; rfl
  · intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx

theorem pick_close (cap : Capture) : cap.closeEff pickE = pickE :=
  Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := pickE) trivial rfl _

theorem poly_cont (σ : PathEnv) (Ψ : StoreTy) :
    ContTy polyP polyB σ Ψ none pickE polyK refTy refTy Eff.empty none := by
  refine .K_Handle (ec := Eff.empty) (eb := pickE) (Rs := none) (ts := R 0) (ecs := Eff.empty) (ebs := pickE)
    (.K_Empty (subRefl _) (ref_ann polyP)) (Eff.Covers.refl [] [] _) pick_sub
    (capture_typed polyP polyB _) ?_ rfl rfl (close_empty _) (pick_close _)
    (done_ann (ref_ann polyP)) (by intros; contradiction) (ref_ann polyP) ?_
  · exact poly_clause _
  · simp [Frame.Adequate,polyH,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,
      adequateClauses,Comp.Adequate,Val.Adequate]

theorem poly_handle_before (σ : PathEnv) (hv : σ.Valid) : StateTy polyP polyB σ (.run polyHandleQ [] Store.empty) := by
  have hc : HasTypeC polyP polyB StoreTy.empty [] Γ0 [] none (.handle polyCode polyH) (R 0) Eff.empty :=
    .C_Handle poly_comp pick_sub (poly_clause _)
  have hq : ClosureTy polyP polyB StoreTy.empty [] none polyHandleQ refTy Eff.empty := by
    simpa [polyHandleQ,refTy] using wrap hc
      (done_ann (P := polyP) (Γ := Γ0) (a := R 0) ⟨(contents0_ann polyP).wf,R0_sorted,R0_declared polyP⟩)
  apply run_state hv (empty_builtin polyP polyB) (StoreOk.empty polyP polyB σ) hq
    (.K_Empty (subRefl _) (ref_ann polyP))
  · simp [polyHandleQ,polyCode,polyH,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,
      Comp.Adequate,Val.Adequate,adequateVals,adequateClauses]
  · simp [polyHandleQ,polyCode,polyH,cap,seven,Capture.values,R,scalar,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Clause.ClosedList,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · intro f hf; cases hf
  · intro l c hc; cases hc

theorem poly_handle_after (σ : PathEnv) (hv : σ.Valid) : StateTy polyP polyB σ (.run polyQ polyK Store.empty) := by
  have ha : Ty.Annotation polyP [] Γ0 (.dependentFn (.done (R 0) pickE)) :=
    ⟨⟨(contents0_ann polyP).wf,trivial,rfl⟩,⟨R0_sorted,trivial⟩,⟨R0_declared polyP,trivial⟩⟩
  have hq : ClosureTy polyP polyB StoreTy.empty [] none polyQ refTy pickE := by
    simpa [polyQ,refTy,pick_close] using wrap poly_comp ha
  apply run_state hv (empty_builtin polyP polyB) (StoreOk.empty polyP polyB σ) hq (poly_cont σ _)
  · simp [polyQ,polyCode,cap,seven,Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateVals]
  · simp [polyQ,polyCode,cap,seven,Capture.values,R,scalar,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f
    simp [Frame.Closed,polyH,cap,seven,Capture.values,Capture.Closed,captureSlotsClosed,Clause.ClosedList,Comp.ClosedAt,Val.ClosedAt]
  · intro l c hc; cases hc

theorem normal_handle (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyHandleQ [] Store.empty) ∧
    Step polyP polyB σ (.run polyHandleQ [] Store.empty) none (.run polyQ polyK Store.empty) ∧
    StateTy polyP polyB σ (.run polyQ polyK Store.empty) :=
  ⟨poly_handle_before σ hv,.E_Handle rfl,poly_handle_after σ hv⟩

/-! 節への実引数と継続の捕捉にも、元の結果型 R 0 の像を保持する。 -/
def opΓ : Ctx := [some (.cont refTy (R 2) Eff.empty),some refTy,some scalar]
def opCap : Capture := cap.extendMany [seven,.loc 0]
def opQ : Closure := .mk opCap (.resume (.var 0) (.var 1))
def opΨ : StoreTy := oneTy (.cont refTy refTy Eff.empty none)
def opμ : Store := Store.empty.set 0 (.cont polyK)
def opUsed : Store := Store.empty.set 0 .used

theorem closed_ref_ann (P : Program) (Γ : Ctx) : Ty.Annotation P [] Γ refTy := by
  have hm : ShiftMap Γ.length 0 [] Γ := ⟨by simp,by intro i a hi; cases hi⟩
  simpa only [Ty.shiftV_of_wf_zero (ref_ann P).wf] using hm.annotation (ref_ann P)

theorem op_R_ann : Ty.Annotation polyP [] opΓ (R 2) := by
  refine ⟨?_,?_,?_⟩
  · simp [R,scalar,opΓ,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · exact ⟨trivial,⟨⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩,⟨⟨scalar,rfl,by simp [scalar]⟩,scalar,rfl,rfl⟩⟩⟩
  · exact ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar,rfl,by simp [scalar]⟩⟩⟩

theorem op_cont_ann : Ty.Annotation polyP [] opΓ (.cont refTy (R 2) Eff.empty) :=
  ⟨⟨(closed_ref_ann polyP opΓ).wf,op_R_ann.wf,trivial,rfl⟩,
    ⟨(closed_ref_ann polyP opΓ).sorted,op_R_ann.sorted,trivial⟩,
    ⟨(closed_ref_ann polyP opΓ).declared,op_R_ann.declared,trivial⟩⟩

theorem op_capture : CaptureOk polyP polyB opΨ none opΓ [] opCap := by
  have hget : ∀ i a, opΓ[i]? = some (some a) →
      (i = 0 ∧ a = .cont refTy (R 2) Eff.empty) ∨ (i = 1 ∧ a = refTy) ∨ (i = 2 ∧ a = scalar) := by
    intro i a hi
    cases i with
    | zero => cases hi; exact Or.inl ⟨rfl,rfl⟩
    | succ i => cases i with
      | zero => cases hi; exact Or.inr (Or.inl ⟨rfl,rfl⟩)
      | succ i => cases i with
        | zero => cases hi; exact Or.inr (Or.inr ⟨rfl,rfl⟩)
        | succ i => simp [opΓ] at hi
  have hRef : substTyValues opCap.env refTy = refTy := Ty.subst_values_of_wf_zero (ref_ann polyP).wf _
  have hR : substTyValues opCap.env (R 2) = refTy := rfl
  have hκ : substTyValues opCap.env (.cont refTy (R 2) Eff.empty) = .cont refTy refTy Eff.empty := by
    change Ty.cont (substTyValues opCap.env refTy) (substTyValues opCap.env (R 2)) (substEffValues opCap.env Eff.empty) = _
    rw [hRef,hR,substEffValues_empty]
  refine .mk ?_ rfl ?_ ?_ ?_ ?_ ?_ ?_
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact op_cont_ann.wf
    · exact (closed_ref_ann polyP opΓ).wf
    · trivial
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨.loc 0,rfl⟩
    · exact ⟨seven,rfl⟩
    · exact ⟨seven,rfl⟩
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact ⟨op_cont_ann.sorted,op_cont_ann.declared⟩
    · exact ⟨(closed_ref_ann polyP opΓ).sorted,(closed_ref_ann polyP opΓ).declared⟩
    · exact ⟨trivial,trivial⟩
  · intro p hp; cases hp
  · intro ov ho v he
    simp [opCap,cap,seven,Capture.extendMany,Capture.extend,Capture.values] at ho
    rcases ho with rfl | rfl <;> cases he <;> trivial
  · intro i a hi; rcases hget i a hi with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · exact .contLoc rfl hκ (by rw [hκ]; exact ⟨(ref_ann polyP).wf,(ref_ann polyP).wf,trivial,rfl⟩) rfl rfl (by intros; contradiction)
    · refine .ordinary (by change Ty.Ordinary (.refined scalar (.eq (.var 0) (.integer 7))); simp [Ty.Ordinary]) ?_
      rw [hRef]; exact seven_ref polyP polyB opΨ
    · exact .ordinary (by simp [scalar]) (.V_Const (by change (-128 : Int) ≤ 7 ∧ 7 ≤ 127; decide))
  · intro p hp
    have hf : opΓ.facts = [.eq (.var 1) (.integer 7)] := rfl
    rw [List.append_nil,hf] at hp
    have he := List.mem_singleton.mp hp; subst p
    exact .eq_refl

theorem poly_frame_closed : (Frame.handleF cap polyH).Closed := by
  simp [Frame.Closed,polyH,cap,seven,Capture.values,Capture.Closed,captureSlotsClosed,Clause.ClosedList,Comp.ClosedAt,Val.ClosedAt]

theorem op_store (σ : PathEnv) : StoreOk polyP polyB σ opΨ opμ :=
  one_store ⟨(ref_ann polyP).wf,(ref_ann polyP).wf,trivial,rfl,by intros; contradiction⟩
    ⟨(ref_ann polyP).declared,(ref_ann polyP).declared,trivial,by intros; contradiction⟩
    ⟨refTy,refTy,Eff.empty,none,rfl,⟨[],cap,polyH,rfl⟩,none,pickE,poly_cont σ _⟩

theorem op_used_store (σ : PathEnv) : StoreOk polyP polyB σ opΨ opUsed :=
  one_store ⟨(ref_ann polyP).wf,(ref_ann polyP).wf,trivial,rfl,by intros; contradiction⟩
    ⟨(ref_ann polyP).declared,(ref_ann polyP).declared,trivial,by intros; contradiction⟩
    ⟨refTy,refTy,Eff.empty,none,rfl⟩

theorem op_drop (σ : PathEnv) : ContTy polyP polyB σ opΨ none Eff.empty dropK refTy refTy Eff.empty none :=
  .K_Drop rfl (by intro h; cases h) (.K_Empty (subRefl _) (ref_ann polyP))

theorem normal_op_after (σ : PathEnv) (hv : σ.Valid) : StateTy polyP polyB σ (.run opQ dropK opμ) := by
  have hb : HasTypeC polyP polyB opΨ [] opΓ [] none (.resume (.var 0) (.var 1)) (R 2) Eff.empty :=
    .C_Resume (i := 0) rfl (.V_Var (i := 1) rfl (by change Ty.Ordinary (.refined scalar (.eq (.var 0) (.integer 7))); simp [Ty.Ordinary])) op_R_ann.declared
  have hq : ClosureTy polyP polyB opΨ [] none opQ refTy Eff.empty := by
    change ClosureTy polyP polyB opΨ [] none opQ (opCap.closeTy (R 2)) Eff.empty
    simpa [opQ,close_empty] using ClosureTy.capture op_capture hb (done_ann op_R_ann) rfl (by intros; contradiction)
  apply run_state hv (empty_builtin polyP polyB) (op_store σ) hq (op_drop σ)
  · simp [opQ,opCap,cap,seven,Capture.values,Capture.extendMany,Capture.extend,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [opQ,opCap,cap,seven,Capture.values,Capture.extendMany,Capture.extend,Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial
  · exact one_closed (by intro f hf; have he := List.mem_singleton.mp hf; subst f; exact poly_frame_closed)

theorem normal_op (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run polyQ polyK Store.empty) ∧
    Step polyP polyB σ (.run polyQ polyK Store.empty) none (.run opQ dropK opμ) ∧
    StateTy polyP polyB σ (.run opQ dropK opμ) := by
  refine ⟨poly_handle_after σ hv,?_,normal_op_after σ hv⟩
  exact .E_Op (q := polyQ) (μ := Store.empty) (k := polyK) (hcap := cap) (h := polyH) (c := .mk (.user "pick") 1 1 (.resume (.var 0) (.var 1))) (o := "pick") (ts := [refTy]) (ws := [seven]) (k1 := []) (k2 := []) (κ := 0)
    rfl ⟨rfl,rfl,by intro cap h he; cases he⟩ rfl rfl

def pureSeven : Closure := .pure (.ret seven)

theorem poly_cont_drop (σ : PathEnv) :
    ContTy polyP polyB σ opΨ none pickE (polyK ++ dropK) refTy refTy Eff.empty none := by
  refine .K_Handle (ec := Eff.empty) (eb := pickE) (Rs := none) (ts := R 0) (ecs := Eff.empty) (ebs := pickE)
    (op_drop σ) (Eff.Covers.refl [] [] _) pick_sub
    (capture_typed polyP polyB _) ?_ rfl rfl (close_empty _) (pick_close _)
    (done_ann (ref_ann polyP)) (by intros; contradiction) (ref_ann polyP) ?_
  · exact poly_clause _
  · simp [Frame.Adequate,polyH,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,
      adequateClauses,Comp.Adequate,Val.Adequate]

theorem pure_seven_closure (e : Eff) (he : Eff.Sub Eff.empty e)
    (ha : Ty.Annotation polyP [] [] (.dependentFn (.done refTy e))) :
    ClosureTy polyP polyB opΨ [] none pureSeven refTy e :=
  ClosureTy.pure (by simpa [pureSeven] using HasTypeCQ.C_Eff (.C_Return (seven_ref polyP polyB opΨ)) he.covers)
    ha (by intros; contradiction)

theorem normal_resume_after (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run pureSeven (polyK ++ dropK) opUsed) := by
  apply run_state hv (empty_builtin polyP polyB) (op_used_store σ)
    (pure_seven_closure pickE ⟨(by intro a h; cases h),(by intro t h; obtain ⟨x,hx,_⟩ := h; cases hx)⟩
      ⟨⟨(ref_ann polyP).wf,trivial,rfl⟩,⟨(ref_ann polyP).sorted,trivial⟩,⟨(ref_ann polyP).declared,trivial⟩⟩)
    (poly_cont_drop σ)
  · simp [pureSeven,Closure.pure,Closure.Adequate,Capture.empty,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,seven]
  · simp [pureSeven,Closure.pure,Closure.ClosedAt,Capture.empty,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,seven]
  · intro f hf; simp [polyK,dropK] at hf; rcases hf with rfl | rfl
    · exact poly_frame_closed
    · trivial
  · exact one_closed trivial

theorem normal_resume (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run opQ dropK opμ) ∧
    Step polyP polyB σ (.run opQ dropK opμ) none (.run pureSeven (polyK ++ dropK) opUsed) ∧
    StateTy polyP polyB σ (.run pureSeven (polyK ++ dropK) opUsed) := by
  refine ⟨normal_op_after σ hv,?_,normal_resume_after σ hv⟩
  have hu : opμ.set 0 .used = opUsed := by
    funext l; simp [opμ,opUsed,Store.set]; split <;> rfl
  rw [←hu]
  exact .E_Resume (q := opQ) (κ := 0) (v := seven) (k' := polyK) rfl rfl

theorem normal_hret_after (σ : PathEnv) (hv : σ.Valid) : StateTy polyP polyB σ (.run pureSeven dropK opUsed) := by
  apply run_state hv (empty_builtin polyP polyB) (op_used_store σ)
    (pure_seven_closure Eff.empty (subRefl _) (done_ann (ref_ann polyP))) (op_drop σ)
  · simp [pureSeven,Closure.pure,Closure.Adequate,Capture.empty,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,seven]
  · simp [pureSeven,Closure.pure,Closure.ClosedAt,Capture.empty,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,seven]
  · intro f hf; have he := List.mem_singleton.mp hf; subst f; trivial
  · exact one_closed trivial

theorem normal_hret (σ : PathEnv) (hv : σ.Valid) :
    StateTy polyP polyB σ (.run pureSeven (polyK ++ dropK) opUsed) ∧
    Step polyP polyB σ (.run pureSeven (polyK ++ dropK) opUsed) none (.run pureSeven dropK opUsed) ∧
    StateTy polyP polyB σ (.run pureSeven dropK opUsed) :=
  ⟨normal_resume_after σ hv,.E_HRet rfl,normal_hret_after σ hv⟩

end
end Benitoite.Release.Refinement.ClosureR3Extra


namespace Benitoite.Release.Refinement.ClosureR3Extra
open Benitoite.Release.Refinement.ClosureR3
noncomputable section
set_option linter.unusedSimpArgs false
set_option linter.unusedVariables false

def dupE : Eff := .mk (fun _ => false) [.base .unit,.base .unit]
def oneE : Eff := .mk (fun _ => false) [.base .unit]

theorem one_canonical : oneE.Canonical := rfl
theorem dup_norm : dupE.norm = oneE := by
  simp only [dupE,oneE,Eff.norm,Ty.normTys_eq_map]
  congr 1

theorem close_dup (c : Capture) : c.closeEff dupE = oneE := by
  have h : c.closeEff dupE = c.closeEff oneE := by
    simp only [Capture.closeEff,substEffValues,Eff.bind]
    have h1 := Eff.norm_rawBind (valEnv c.env) dupE
    have h2 := Eff.norm_rawBind (valEnv c.env) oneE
    rw [dup_norm] at h1
    rw [show oneE.norm = oneE from one_canonical] at h2
    rw [←h1,h2]
  rw [h]
  exact Eff.subst_values_of_wf_zero (nr := 0) (nt := 0) (e := oneE) ⟨trivial,trivial⟩ one_canonical _

theorem poly_clause_dup (Ψ : StoreTy) :
    HasTypeClauses polyP polyB Ψ [] Γ0 [] none pickE polyH (R 0) dupE := by
  refine .cons (sg := pickSig) (ClauseSig.of_opSig rfl) ⟨rfl,by decide⟩ rfl rfl ?_ ?_ .nil
  · exact ⟨⟨(by simp [pickSig,Ty.WF]),trivial⟩,(by simp [pickSig,Ty.WF])⟩
  · refine .C_Resume (i := 0) rfl (.V_Var (i := 1) rfl (by simp [pickSig,Ty.Ordinary,Ty.shiftV,shiftTypes])) ?_
    exact ⟨trivial,⟨⟨scalar,rfl,by simp [scalar]⟩,⟨scalar.shiftV 1 0,rfl,by simp [scalar,Ty.shiftV]⟩⟩⟩

/-- K_Handle の全欄は満たされる。 -/
theorem frame_dup (σ : PathEnv) (Ψ : StoreTy) :
    ContTy polyP polyB σ Ψ none pickE polyK refTy refTy oneE none := by
  refine .K_Handle (ε := oneE) (ec := oneE) (eb := pickE) (Rs := none) (ts := R 0) (ecs := dupE) (ebs := pickE)
    (.K_Empty (subRefl _) (ref_ann polyP)) (Eff.Covers.refl [] [] _) ?_
    (capture_typed polyP polyB _) (poly_clause_dup _) rfl rfl (close_dup _) (pick_close _)
    ?_ (by intros; contradiction) (ref_ann polyP) ?_
  · refine ⟨fun a ha => ?_,?_⟩
    · have h := pick_sub.1 a ha
      have h0 : (Eff.empty.test a || (handled polyP polyB polyH).test a) = true := (Eff.mem_norm _ _).mp h
      have h1 : (handled polyP polyB polyH).test a = true := by
        rcases Bool.or_eq_true _ _ |>.mp h0 with h2 | h2
        · cases h2
        · exact h2
      refine (Eff.mem_norm _ _).mpr ?_
      show (oneE.test a || (handled polyP polyB polyH).test a) = true
      simp only [h1,Bool.or_true]
    · intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx
  · exact ⟨⟨(ref_ann polyP).wf,⟨trivial,trivial⟩,one_canonical⟩,⟨(ref_ann polyP).sorted,⟨trivial,trivial⟩⟩,⟨(ref_ann polyP).declared,⟨trivial,trivial⟩⟩⟩
  · simp [Frame.Adequate,polyH,cap,seven,Capture.values,Capture.Adequate,adequateCaptureSlots,
      adequateClauses,Comp.Adequate,Val.Adequate]

/-- しかし E_Op の節の閉包が CaptureOk に要るソースの文脈は Ctx.WF を満たさない。 -/
theorem clause_context_not_wf : ¬ Ctx.WF 0 0 (pickSig.context Γ0 (R 0) dupE) := by
  intro h
  have hw := h 0 _ rfl
  have hc : Eff.Canonical dupE := hw.2.2.2
  have hl := congrArg (fun e : Eff => e.fails.length) hc
  rw [show Eff.norm dupE = oneE from dup_norm] at hl
  cases hl

#print axioms frame_dup
#print axioms clause_context_not_wf
end
end Benitoite.Release.Refinement.ClosureR3Extra
