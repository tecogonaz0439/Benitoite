import Lean
import Benitoite.Release.Refinement.BuiltinEffects
import Benitoite.Release.Refinement.HandlerOperation
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.ModelCompatibility15
noncomputable section
set_option linter.unusedSimpArgs false
local instance : OfNat Integer64Value 3 := ⟨⟨3,by decide⟩⟩
local instance : OfNat Integer64Value 9 := ⟨⟨9,by decide⟩⟩
abbrev I : Ty := .base .integer
abbrev U : Ty := .base .unit
abbrev p : Pred := .lt (.var 0) (.integer 8)
abbrev Small : Ty := .refined I p
abbrev rp : Pred := .and (.eq (.var 0) (.var 1)) p
abbrev Result : Ty := .refined I rp
abbrev three : Val := .const (.integer 3)
abbrev nine : Val := .const (.integer 9)
def od : OpDecl := ⟨"Choose",[],["input"],[Small],Result,[]⟩
def P : Program :=
  { defs := fun _ => none, cons := fun _ => none,
    ops := fun o => if o = "choose" then some od else none,
    effects := fun e => if e = "Choose" then some ["choose"] else none,
    classes := fun _ => none, impls := fun _ => none }
def E : Eff := Eff.single stateEff
def σ : PathEnv := ⟨[],[],[],none,none,none⟩
def sg (k : PrimKind) : PrimSig :=
  match k with
  | .refNew => ⟨[{}],0,["value"],[.tvar 0],.reference (.tvar 0),E,fun _ _ => True,k,none,[],.untargeted⟩
  | .refGet => ⟨[{}],0,["reference"],[.reference (.tvar 0)],.tvar 0,E,fun _ _ => True,k,none,[],.untargeted⟩
  | .force => ⟨[{}],0,["value"],[.lazy (.tvar 0)],.tvar 0,Eff.empty,fun _ _ => True,k,none,[],.untargeted⟩
  | .refSet => ⟨[{}],0,["reference","value"],[.reference (.tvar 0),.tvar 0],U,E,fun _ _ => True,k,none,[],.untargeted⟩
  | _ => ⟨[{}],0,["reference","f"],[.reference (.tvar 0),.fn ["value"] [.tvar 0] (.tvar 0) Eff.empty],
      U,E,fun _ _ => True,k,none,[],.untargeted⟩
def B : Builtins :=
  { sig := fun b => if b = "new" then some (sg .refNew) else
      if b = "get" then some (sg .refGet) else if b = "set" then some (sg .refSet) else
      if b = "update" then some (sg .refUpdate) else if b = "force" then some (sg .force) else none,
    delta := fun _ _ _ _ _ => none, ioResponse := fun _ _ _ _ _ _ => False,
    releaseResponse := fun _ _ => True, isResource := fun o => decide (o = "Res"),
    effects := fun l => if l = stateEff then some [] else none, sat := fun _ _ _ => True, refGet := "get",refSet := "set" }

theorem sig_cases {b s} (hs : B.sig b = some s) :
    s = sg .refNew ∨ s = sg .refGet ∨ s = sg .refSet ∨ s = sg .refUpdate ∨ s = sg .force := by
  change (if b = "new" then _ else if b = "get" then _ else if b = "set" then _ else
    if b = "update" then _ else if b = "force" then _ else none) = some s at hs
  split at hs
  · exact Or.inl (Option.some.inj hs).symm
  · split at hs
    · exact Or.inr (Or.inl (Option.some.inj hs).symm)
    · split at hs
      · exact Or.inr (Or.inr (Or.inl (Option.some.inj hs).symm))
      · split at hs
        · exact Or.inr (Or.inr (Or.inr (Or.inl (Option.some.inj hs).symm)))
        · split at hs
          · exact Or.inr (Or.inr (Or.inr (Or.inr (Option.some.inj hs).symm)))
          · cases hs

theorem assumptions : Builtins.CoreAssumptions P B where
  sat_rename := by intros; trivial
  sat_values := by intros; trivial
  sat_renameTypes := by intros; trivial
  sat_subst := by intros; trivial
  admits_rename := by
    intro b s C Γ Δ ts ξ hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> trivial
  admits_values := by
    intro b s Ψ Q C Γ Δ Ξ ν ts hs _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> trivial
  admits_renameTypes := by
    intro b s C C' Γ Δ ts ρ hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> trivial
  admits_subst := by
    intro b s C0 C1 ts ts' es' hs _ _ _ _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> trivial
  external_typed := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  external_exists := by intro Ψ f d ts vs a e hw hs; cases hs
  external_no_targets := by intro Ψ f d ts vs a e out obs hw hs; cases hs
  delta_typed := by
    intro Ψ b s ts es rs ws a e hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> cases hk
  io_typed := by intro Ψ b s ts es rs ws a e out obs hs hk ha hi; cases hi
  io_kind := by intro Ψ b s ts es rs ws a e out obs hs ha hi; cases hi
  io_exists := by
    intro Ψ b s ts es rs ws a e hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  io_op := by
    intro b s hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> rcases hk with hk | hk <;> cases hk
  pathBases_shape := by
    intro b s hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> cases hk
  opEff_io := by
    intro b s l hs ho
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> cases ho
  effect_ops := by
    intro l bs b hs hm
    change (if l = stateEff then some [] else none) = some bs at hs
    split at hs
    · cases Option.some.inj hs; cases hm
    · cases hs
  state_effect := by simp [B]
  ref_get := ⟨sg .refGet,rfl,rfl⟩
  ref_set := ⟨sg .refSet,rfl,rfl⟩
  store_shape := by
    intro b s hs _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> simp [sg,PrimSig.StoreShape,E]
  store_admits := by
    intro b s C ts hs
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> intros <;> trivial

theorem effects_ok : P.EffectsOk B := by
  constructor
  · intro l os o he ho
    change (if l = "Choose" then some ["choose"] else none) = some os at he
    split at he
    · cases Option.some.inj he
      simp only [List.mem_singleton] at ho
      subst o
      exact ⟨od,by simp [P],by simp_all [od]⟩
    · cases he
  · constructor
    · intro o d hd
      change (if o = "choose" then some od else none) = some d at hd
      split at hd
      · cases Option.some.inj hd
        exact ⟨["choose"],by simp [P,od],by simp_all⟩
      · cases hd
    · intro l os he
      change (if l = "Choose" then some ["choose"] else none) = some os at he
      split at he
      · simp_all [B,stateEff]
      · cases he

theorem state_unhandled : NoStateHandled P B := effects_ok.noStateHandled assumptions

theorem i_ann {Γ : Ctx} : Ty.Annotation P [] Γ I := ⟨trivial,trivial,trivial⟩
theorem small_ann {Γ : Ctx} : Ty.Annotation P [] Γ Small := by
  constructor <;> simp [Small,p,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,
    Ty.Sorted,predBind,termBind?,upValues,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.declarationSelf,
    Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Ctx.Readable,Ctx.extend,Ty.shiftV,I]

theorem three_small {Ψ : StoreTy} {Γ : Ctx} {Φ} :
    HasTypeV P B Ψ [] Γ Φ three Small := by
  refine .V_Refine (.V_Const trivial) rfl rfl small_ann.sorted.2 small_ann.wf.2.1
    ?_ trivial small_ann.declared.2
  exact (CaptureOk.evaluated_fact (by decide)).weaken (by simp)


abbrev Returned : Ty := .refined I (.and (.eq (.var 0) (.integer 3)) p)
abbrev κTy : Ty := .cont Result (Small.shiftV 1 0) (Eff.empty.shiftV 1 0)
abbrev Γcl : Ctx := (Ctx.extend [] Small).extend κTy
abbrev clauseBody : Comp := .resume (.var 0) (.var 1)
def cs : List Clause := [.mk (.user "choose") 1 0 clauseBody]
abbrev q0 : Closure := .pure (.app (.op "choose" []) [three])
abbrev qlet : Closure := .pure (.ret (.var 0))
abbrev saved : Cont := [.letF qlet,.handleF Capture.empty cs]
def μ1 : Store := Store.empty.set 0 (.cont saved)
def μ2 : Store := μ1.set 0 .used
def Ψ1 : StoreTy := StoreTy.empty.put 0 (.cont Returned Small Eff.empty none)
abbrev s0 : State := .run q0 saved Store.empty
abbrev s1 : State := .run (.mk (Capture.empty.extendMany [three,.loc 0]) clauseBody) [.drop 0] μ1
abbrev s2 : State := .run (.pure (.ret three)) (saved ++ [.drop 0]) μ2
abbrev s3 : State := .run (qlet.apply [three]) [.handleF Capture.empty cs,.drop 0] μ2
abbrev s4 : State := .run (.pure (.ret three)) [.drop 0] μ2
abbrev s5 : State := .run (.pure (.ret three)) [] μ2

set_option maxRecDepth 3000

private theorem result_ann : Ty.Annotation P [] (Ctx.extend [] Small) Result := by
  constructor <;> simp [Result,rp,Small,p,I,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,
    Term.VarsIn,Ty.Sorted,predBind,termBind?,upValues,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,
    Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Ctx.Readable,Ctx.declarationSelf,Ctx.extend,
    Ty.shiftV,Pred.shiftV,shiftIndex]

private theorem returned_ann {Γ : Ctx} : Ty.Annotation P [] Γ Returned := by
  constructor <;> simp [Returned,I,p,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,
    Ty.Sorted,predBind,termBind?,upValues,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,
    Ty.Declared,Pred.Declared,Term.Declared,Ctx.Readable,Ctx.declarationSelf,Ctx.extend,Ty.shiftV]

private theorem empty_ann {Γ a} (ha : Ty.Annotation P [] Γ a) :
    Ty.Annotation P [] Γ (.dependentFn (.done a Eff.empty)) :=
  ⟨⟨ha.wf,by simp [Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨ha.sorted,by simp [sortedEff,Eff.empty,sortedTys]⟩,⟨ha.declared,by simp [declaredEff,Eff.empty,declaredTys]⟩⟩

private theorem sub_empty (e : Eff) : Eff.Sub Eff.empty e := by
  constructor
  · intro a h; cases h
  · intro a h; obtain ⟨_,h,_⟩ := h; cases h

private theorem clause_value {Ψ : StoreTy} :
    HasTypeV P B Ψ [] Γcl [] (.var 1) (Result.shiftV 1 0) := by
  change HasTypeV P B Ψ [] Γcl [] (.var 1) (.refined I (.and (.eq (.var 0) (.var 2)) p))
  have hi : HasTypeV P B Ψ [] Γcl [] (.var 1) I :=
    .V_Sub (.V_Var (by rfl) (by intro a b e h; cases h)) .forget trivial trivial trivial
  refine .V_Refine hi rfl rfl ?_ ?_ ?_ trivial ?_
  · simp [Result,rp,Small,p,I,Γcl,κTy,Ctx.extend,Ty.shiftV,Pred.shiftV,shiftIndex,
      predBind,termBind?,upValues,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Term.VarsIn,Ctx.Readable,Ty.core,Ty.HasSort,Ty.sort?,Ordinary]
  · decide
  · exact .and_intro .eq_refl (.hyp (by
      apply List.mem_append_left
      exact Ctx.mem_facts.mpr ⟨1,Small,p,rfl,by simp [Ty.assume,Small,I,p,Ty.refinementPredicates,Pred.conjuncts,Ty.core],rfl⟩))
  · simp [Result,rp,Small,p,I,Γcl,κTy,Ctx.extend,Ty.shiftV,Pred.shiftV,shiftIndex,
      Pred.Declared,Term.Declared,Ctx.Readable,Ctx.declarationSelf,Ty.HasSort,Ty.sort?,Ordinary]

theorem clause_reads_input {Ψ : StoreTy} :
    HasTypeC P B Ψ [] Γcl [] none clauseBody (Small.shiftV 2 0) (Eff.empty.shiftV 2 0) :=
  .C_Resume (by rfl) clause_value small_ann.declared

private theorem clauses_typed {Ψ : StoreTy} :
    HasTypeClausesQ P B Ψ Qempty [] [] [] none (Eff.single "Choose") cs Small Eff.empty [] := by
  apply HasTypeClausesQ.cons (sg := ⟨[],["input"],[Small],Result,"Choose"⟩)
    (ClauseSig.of_opSig (by simp [opSig,opSigAt,P,od])) (by simp [NamesWF]) rfl rfl
  · exact ⟨⟨(small_ann (Γ := [])).wf,trivial⟩,by simpa [Ctx.extend] using result_ann.wf⟩
  · simpa [OpSig.context,OpSig.continuation,Ctx.shiftE,Ctx.shiftEAt,Ctx.extendMany,
      shiftTypes_zero,shiftRowsTypes_zero,Γcl,κTy,show liftMany 2 [] = [] from rfl] using (clause_reads_input (Ψ := hideBuilders Ψ))
  · exact .nil

private theorem op_tel : instantiatedTel od.tel [] [] = .param "input" Small (.done Result (Eff.single "Choose")) := by
  have he : typeEnvAt 0 [] [] = renEnv id := by
    change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
    congr 1 <;> funext i <;> simp [typeEnvAt,renEnv]
  simp only [instantiatedTel,he,Tel.bind,Tel.rawBind_id,od,OpDecl.tel,signatureTel,Tel.norm]
  congr 2
  apply congrArg (fun f => EffR.mk f [])
  funext a
  cases a with
  | rho i => rfl
  | name l ix => cases ix with
    | rvar i => simp [RangeIx.top]
    | fixed r => cases r with
      | absolute r => cases r <;> simp [RangeIx.top,RangeExpr.top] <;> rfl
      | based b p => simp [RangeIx.top,RangeExpr.top]
      | secrets => simp [RangeIx.top,RangeExpr.top]

private theorem op_signature : SignatureInstance P [] [] od.tel [] [] [] where
  source := by
    change Small.WF 0 0 0 ∧ Result.WF 0 0 1 ∧ _
    exact ⟨(small_ann (Γ := [])).wf,by simpa [Ctx.extend] using result_ann.wf,
      by simp [Eff.WF,Eff.Canonical,Eff.norm,Ty.WFList]⟩
  types := by simp [TypeAnnotations]
  kinds := by simp [TypeArgsKinded]
  rows := by simp [RowAnnotations]
  result := by
    rw [op_tel]
    exact ⟨⟨small_ann.wf,by simpa [Ctx.extend] using result_ann.wf,
      by simp [Eff.single,Eff.WF,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
      ⟨small_ann.sorted,result_ann.sorted,by simp [sortedEff,Eff.single,sortedTys]⟩,
      ⟨small_ann.declared,result_ann.declared,by simp [declaredEff,Eff.single,declaredTys]⟩⟩

private theorem call_typed {Ψ : StoreTy} :
    HasTypeC P B Ψ [] [] [] none q0.code Returned (Eff.single "Choose") := by
  have ho : HasTypeV P B Ψ [] [] [] (.op "choose" []) (.dependentFn (instantiatedTel od.tel [] [])) :=
    .V_Op (by simp [P]) (by simp [od,NamesWF]) ⟨rfl,by intros; contradiction⟩ op_signature
  have hs := op_signature.result
  rw [op_tel] at ho hs
  have ha := HasTypeTelArgsQ.one (Ψ := Ψ) (B := B) (Q := Qempty) (Φ := []) hs (by simp [Ctx.WF]) (three_small (Ψ := Ψ) (Γ := []) (Φ := []))
  have happ := HasTypeCQ.C_DependentApp (R := none) (Δ := []) ho ha
  have hr : substTyValues (openValue three) Result = Returned := by rfl
  simpa only [Eff.subst_values_single,hr,q0,Closure.pure,Closure.code] using happ

private theorem returned_to_small {Γ : Ctx} {Φ} : Ty.LeQ Γ Φ Returned Small := by
  exact .refine .refl returned_ann.sorted.2 small_ann.sorted.2 (.and_right (.hyp List.mem_cons_self))

private theorem let_body {Ψ : StoreTy} :
    HasTypeC P B Ψ [] (Ctx.extend [] Returned) [] none (.ret (.var 0)) Small Eff.empty := by
  exact .C_Return (.V_Sub (.V_Var rfl (by intro a b e h; cases h)) returned_to_small
    small_ann.wf small_ann.sorted small_ann.declared)

private theorem let_closure {Ψ : StoreTy} :
    ClosureTy P B Ψ [Returned] none qlet (Small.shiftV 1 0) (Eff.empty.shiftV 1 0) := by
  change ClosureTy P B Ψ [Returned] none qlet Small Eff.empty
  have heR : Capture.empty.closeTy Returned = Returned := by rfl
  have heS : Capture.empty.closeTyAt 1 Small = Small := by rfl
  have heE : Capture.empty.closeEffAt 1 Eff.empty = Eff.empty := Eff.subst_values_empty _
  have hc := ClosureTy.mk (ss := [Returned]) (Rs := none) (a := Small) (e := Eff.empty)
    (cap := Capture.empty) (Γ := []) (Φ := []) (code0 := .ret (.var 0)) (L := []) (ρ := LocalRef.bound)
    (CaptureOk.empty P B Ψ none) (by simpa [bindParams,Ctx.extend] using (let_body (Ψ := Ψ)))
    (CaptureLocals.empty _ _ _) (by rfl)
    (by intro a ha; cases ha with | head => exact returned_ann | tail _ h => cases h)
    (by intro a ha; simp only [List.map_cons,List.map_nil,List.mem_singleton,heR] at ha; subst a; exact returned_ann)
    rfl (by simpa only [List.length_cons,List.length_nil,heS,List.map_cons,List.map_nil,heR] using (small_ann (Γ := bindParams [] [Returned])) )
    (by simpa only [List.length_cons,List.length_nil,heS,heE,List.map_cons,List.map_nil,heR] using
      (empty_ann (small_ann (Γ := bindParams [] [Returned]))))
    (by intros; contradiction) (by intros; contradiction)
  simpa only [List.map_cons,List.map_nil,heR,List.length_cons,List.length_nil,heS,heE,Comp.resolveLocals_id,qlet,Closure.pure] using hc

private theorem handler_tail {Ψ : StoreTy} {k : Cont}
    (hk : ContTy P B σ Ψ none Eff.empty k Small Small Eff.empty none) :
    ContTy P B σ Ψ none (Eff.single "Choose") (.handleF Capture.empty cs :: k) Small Small Eff.empty none := by
  apply ContTy.K_Handle (ec := Eff.empty) (ε := Eff.empty) (Γ := []) (Φ := []) (Rs := none)
    (ts := Small) (ecs := Eff.empty) (ebs := Eff.single "Choose") hk (.refl _ _ _)
  · constructor
    · intro a ha
      change decide (a = .name "Choose" .top) = true at ha
      cases of_decide_eq_true ha
      simp [Eff.mem,Eff.test,Eff.atoms,Eff.union,Eff.norm,Eff.empty,handled,effOps,P,cs,handles,Clause.op]
    · intro a ha; obtain ⟨_,h,_⟩ := ha; cases h
  · exact CaptureOk.empty P B (hideBuilders Ψ) none
  · exact clauses_typed
  · rfl
  · rfl
  · exact Eff.subst_values_empty _
  · exact Eff.subst_values_single _ _
  · exact empty_ann small_ann
  · exact small_ann
  · intros; contradiction
  · trivial

private theorem saved_cont {Ψ : StoreTy} {k : Cont}
    (hk : ContTy P B σ Ψ none Eff.empty k Small Small Eff.empty none) :
    ContTy P B σ Ψ none (Eff.single "Choose")
      (.letF qlet :: .handleF Capture.empty cs :: k) Returned Small Eff.empty none :=
  .K_Let let_closure (by trivial) returned_ann (sub_empty _) (handler_tail hk)

theorem start : StateTyE P B σ Eff.empty s0 := by
  refine ⟨StoreTy.empty,none,Returned,Small,Eff.single "Choose",Eff.single "Choose",
    StoreOk.empty P B σ,?_,⟨fun _ h => h,fun _ h => h⟩,saved_cont (.K_Empty (sub_empty _) small_ann),?_,?_,?_,?_⟩
  · exact ClosureTy.pure call_typed
      ⟨⟨returned_ann.wf,by simp [Eff.single,Eff.WF,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
        ⟨returned_ann.sorted,by simp [sortedEff,Eff.single,sortedTys]⟩,
        ⟨returned_ann.declared,by simp [declaredEff,Eff.single,declaredTys]⟩⟩
      (by intros; contradiction) (by rfl) (by intros; contradiction)
  all_goals simp [s0,q0,saved,qlet,cs,clauseBody,Closure.pure,Closure.Adequate,Capture.empty,Capture.Adequate,adequateVals,
    adequateCaptureSlots,Comp.Adequate,Val.Adequate,adequateClauses,Cont.Closed,Frame.Closed,
    Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Capture.values,Comp.ClosedAt,Val.ClosedAt,
    Val.ClosedList,Clause.ClosedList,Store.Closed,Store.empty]

theorem operation_pair : Step P B σ s0 none s1 ∧ StateTyE P B σ Eff.empty s1 := by
  exact StateTyE.operation_one (x := Small) (y := Result) (name := "input") (eff := "Choose") (cs := cs) (k1 := [.letF qlet])
    (k2 := []) (cap := Capture.empty) (body := clauseBody) assumptions start (by simp [P,od]) (by rfl) (by rfl)
    ⟨rfl,by decide,by intro cap cs h; simp only [List.mem_singleton] at h; cases h⟩
    (by rfl) rfl rfl rfl

theorem resume_pair : Step P B σ s1 none s2 ∧ StateTyE P B σ Eff.empty s2 :=
  StateTyE.resume_const assumptions operation_pair.2 rfl rfl


theorem three_returned {Ψ : StoreTy} : HasTypeV P B Ψ [] [] [] three Returned := by
  refine .V_Refine (.V_Const trivial) rfl rfl returned_ann.sorted.2 returned_ann.wf.2.1 ?_ trivial returned_ann.declared.2
  exact CaptureOk.evaluated_fact (by decide)

private theorem store1 : StoreOk P B σ Ψ1 μ1 := by
  apply (StoreOk.empty P B σ).allocate_continuation assumptions.values rfl
    (show LocTy.WF (.cont Returned Small Eff.empty none) from
      ⟨(returned_ann (Γ := [])).wf,(small_ann (Γ := [])).wf,by simp [Eff.WF,Eff.empty,Ty.WFList],by rfl,by intros; contradiction⟩)
    (show LocTy.Declared P (.cont Returned Small Eff.empty none) from
      ⟨returned_ann.declared,small_ann.declared,by simp [declaredEff,Eff.empty,declaredTys],by intros; contradiction⟩)
    ⟨[.letF qlet],Capture.empty,cs,rfl⟩ ⟨none,Eff.single "Choose",saved_cont (.K_Empty (sub_empty _) small_ann)⟩

private theorem store2 : StoreOk P B σ Ψ1 μ2 := store1.use_continuation (by rfl)

private theorem drop_tail : ContTy P B σ Ψ1 none Eff.empty [.drop 0] Small Small Eff.empty none :=
  .K_Drop (b' := Returned) (t' := Small) (e' := Eff.empty) (R' := none) rfl
    (by intro h; cases h) (.K_Empty (sub_empty _) small_ann)

theorem let_pair : Step P B σ s2 none s3 ∧ StateTyE P B σ Eff.empty s3 := by
  have hc := (CaptureOk.empty P B Ψ1 none).extend (a := Returned) returned_ann
    (by simpa only [show Capture.empty.closeTy Returned = Returned from rfl] using three_returned (Ψ := Ψ1)) (by trivial)
  have hq := ClosureTy.capture hc (let_body (Ψ := Ψ1)) (empty_ann small_ann) rfl (by intros; contradiction)
  have hqe : ClosureTy P B Ψ1 [] none (qlet.apply [three]) Small Eff.empty := by
    simpa only [qlet,Closure.pure,Closure.code,Closure.capture,Closure.apply,Capture.extendMany,List.foldl_cons,List.foldl_nil,
      show (Capture.empty.extend three).closeTy Small = Small from rfl,Capture.closeEff,Eff.subst_values_empty] using hq
  refine ⟨.E_Return rfl,Ψ1,none,Small,Small,Eff.single "Choose",Eff.empty,
    store2,hqe,sub_empty _,handler_tail drop_tail,?_,?_,?_,?_⟩
  all_goals simp [qlet,Closure.pure,Closure.code,Closure.capture,Closure.apply,Capture.extendMany,Capture.extend,Capture.empty,
    Capture.values,Closure.Adequate,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate,
    Closure.ClosedAt,Capture.Closed,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,
    Cont.Closed,Frame.Closed,cs,clauseBody,Clause.ClosedList,
    Store.Closed,μ2,μ1,Store.set,Store.empty,saved,adequateClauses]
  intro l c hi
  by_cases h0 : l = 0 <;> simp_all [Cell.Closed]
  subst c
  trivial

theorem handler_pair : Step P B σ s3 none s4 ∧ StateTyE P B σ Eff.empty s4 :=
  StateTyE.handler_return_const assumptions let_pair.2 rfl

theorem drop_pair : Step P B σ s4 none s5 ∧ StateTyE P B σ Eff.empty s5 :=
  StateTyE.drop_used_const assumptions handler_pair.2 rfl rfl

/-- ソースの開始から、操作、再開、継続の読取り、返却、drop の5遷移。 -/
theorem execution : StateTyE P B σ Eff.empty s0 ∧
    (Step P B σ s0 none s1 ∧ StateTyE P B σ Eff.empty s1) ∧
    (Step P B σ s1 none s2 ∧ StateTyE P B σ Eff.empty s2) ∧
    (Step P B σ s2 none s3 ∧ StateTyE P B σ Eff.empty s3) ∧
    (Step P B σ s3 none s4 ∧ StateTyE P B σ Eff.empty s4) ∧
    (Step P B σ s4 none s5 ∧ StateTyE P B σ Eff.empty s5) :=
  ⟨start,operation_pair,resume_pair,let_pair,handler_pair,drop_pair⟩

theorem used_after_resume : μ2 0 = some .used := rfl

theorem resume_twice :
    Step P B σ (.run (.mk (Capture.empty.extendMany [three,.loc 0]) clauseBody) [.drop 0] μ2) none
      (.error [rResume] [.drop 0] μ2) ∧
    StateTyE P B σ Eff.empty (.error [rResume] [.drop 0] μ2) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := operation_pair.2
  obtain ⟨aa,tt,ee,rr,hp,_,_,_,_⟩ := hs.2.2.2.2 0 _ (show μ1 0 = some (.cont saved) from rfl)
  have hs' := hs.use_continuation hp
  have hμ2 : μ2.Closed := by
    intro i c hi
    by_cases h0 : i = 0
    · subst i; simp [μ2,Store.set] at hi; cases hi; trivial
    · simp [μ2,μ1,Store.set,Store.empty,h0] at hi
  exact StateTyE.resume_used ⟨Ψ,R,a,b,e,e1,hs',hq,he,hk,had,hcl,hkc,hμ2⟩ rfl rfl

theorem nine_not_small {Ψ : StoreTy} : ¬ HasTypeV P B Ψ [] [] [] nine Small := by
  intro h
  have hf := h.facts rfl p (by simp [Ty.assume,Ty.core,Ty.refinementPredicates,Pred.conjuncts])
  have hh := hf.sound (fun _ => none) (by intro q hq; cases hq)
  change false = true at hh
  cases hh

theorem call_rejects_nine {Ψ : StoreTy} {a e} :
    ¬ HasTypeC P B Ψ [] [] [] none (.app (.op "choose" []) [nine]) a e := by
  intro h
  obtain ⟨r,f,ht,_,_⟩ := h.operation_call (show P.ops "choose" = some od by simp [P])
  rw [op_tel] at ht
  cases ht with
  | param _ hv _ => exact nine_not_small hv

abbrev Γplain : Ctx := (Ctx.extend [] I).extend (.cont Result (Small.shiftV 1 0) (Eff.empty.shiftV 1 0))

theorem input_contract_removed {Ψ : StoreTy} :
    ¬ HasTypeV P B Ψ [] Γplain [] (.var 1) (Result.shiftV 1 0) := by
  intro h
  have hf := h.facts rfl p (by simp [Result,rp,p,Ty.assume,Ty.core,Ty.refinementPredicates,
    Pred.conjuncts,Ty.shiftV,Pred.shiftV,predBind,termBind?,shiftIndex])
  have hh := hf.sound (fun _ => some (.integer 9)) (by intro q hq; cases hq)
  change false = true at hh
  cases hh

theorem result_contract_removed {Ψ : StoreTy} :
    ¬ HasTypeC P B Ψ [] (Ctx.extend [] I) [] none (.ret (.var 0)) Small Eff.empty := by
  intro h
  have hf := h.ret_value rfl |>.facts rfl p (by simp [Ty.assume,Ty.core,Ty.refinementPredicates,Pred.conjuncts])
  have hh := hf.sound (fun _ => some (.integer 9)) (by intro q hq; cases hq)
  change false = true at hh
  cases hh

namespace Snapshot
abbrev Γ : Ctx := Ctx.extend [] I
abbrev cap : Capture := Capture.empty.extend three
abbrev fact : Pred := .lt (.var 0) (.integer 8)

theorem captured {Ψ : StoreTy} : CaptureOk P B Ψ none Γ [fact] cap := by
  have hc := (CaptureOk.empty P B Ψ none).extend (a := I) (v := three) i_ann (.V_Const trivial) (by trivial)
  exact hc.addEvaluated
    (by constructor <;> simp [fact,Γ,I,Ctx.extend,Ty.shiftV,Pred.WF,Pred.VarsIn,Term.VarsIn,
      Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,
      Pred.Declared,Term.Declared,Ctx.Readable,Ctx.declarationSelf,Ty.core]) (by decide)

theorem after_use : StoreOk P B σ Ψ1 μ2 ∧ CaptureOk P B Ψ1 none Γ [fact] cap ∧
    Entails [] (predBind (valEnv cap.env).values fact) := by
  have hc := captured (Ψ := Ψ1)
  exact ⟨store2,hc.store assumptions.values store1.wf (StoreTy.PreservesNormals.refl _),
    hc.close_entails (.hyp (by simp))⟩

end Snapshot

namespace Release
abbrev resource : Val := .const (.opaque "Res" 0)
abbrev unitV : Val := .const .unit
abbrev saved : Cont := [.release resource,.handleF Capture.empty []]
def Ψ : StoreTy := StoreTy.empty.put 0 (.cont U U E none)
def μ : Store := Store.empty.set 0 (.cont saved)
abbrev q : Closure := .pure (.ret unitV)
abbrev before : State := .run q [.drop 0] μ
abbrev after : State := .run q [.release resource] (μ.set 0 .used)
private theorem u_ann {Γ : Ctx} : Ty.Annotation P [] Γ U := ⟨trivial,trivial,trivial⟩
private theorem state_ann : Ty.Annotation P [] [] (.dependentFn (.done U E)) := by
  exact ⟨⟨trivial,by simp [E,Eff.single,Eff.WF,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
private theorem saved_typed {Ξ : StoreTy} : ContTy P B σ Ξ none E saved U U E none := by
  refine .K_Release (.V_Const ⟨rfl,rfl⟩) (by trivial) (by rfl) (by decide) ?_
  refine .K_Handle (ec := E) (ε := E) (Γ := []) (Φ := []) (Rs := none)
    (ts := U) (ecs := E) (ebs := E) (.K_Empty ⟨fun _ h => h,fun _ h => h⟩ u_ann)
    (.refl _ _ _) ?_ (CaptureOk.empty P B (hideBuilders Ξ) none) .nil rfl rfl
    (Eff.subst_values_single _ _) (Eff.subst_values_single _ _) state_ann u_ann
    (by intros; contradiction) (by trivial)
  constructor
  · intro a ha
    change E.mem a at ha
    simpa [Eff.mem,Eff.test,Eff.union,Eff.norm,Eff.atoms,handled,handles] using Or.inl ha
  · intro a ha; obtain ⟨_,h,_⟩ := ha; cases h
private theorem store : StoreOk P B σ Ψ μ := by
  exact (StoreOk.empty P B σ).allocate_continuation assumptions.values rfl
    ⟨trivial,trivial,state_ann.wf.2.1,rfl,by intros; contradiction⟩
    ⟨trivial,trivial,trivial,by intros; contradiction⟩
    ⟨[.release resource],Capture.empty,[],rfl⟩ ⟨none,E,saved_typed⟩
private theorem tail {R} : ContTy P B σ Ψ R E [.drop 0] U U E R :=
  .K_Drop (b' := U) (t' := U) (e' := E) (R' := none) rfl (fun h => h)
    (.K_Empty ⟨fun _ h => h,fun _ h => h⟩ u_ann)
private theorem closed_store : μ.Closed := by
  intro l c hc
  by_cases h0 : l = 0
  · subst l
    simp only [μ,Store.set,↓reduceIte,Option.some.injEq] at hc
    subst c
    simp [Cell.Closed,saved,Cont.Closed,Frame.Closed,resource,Capture.Closed,Capture.empty,
      captureSlotsClosed,Clause.ClosedList,Val.Ground,Val.ClosedAt]
  · simp [μ,Store.set,Store.empty,h0] at hc

theorem start : StateTyE P B σ E before := by
  exact ⟨Ψ,none,U,U,E,Eff.empty,store,
    ClosureTy.pure (.C_Return (.V_Const trivial)) (empty_ann u_ann)
      (by intros; contradiction) rfl (by intros; contradiction),
    sub_empty _,tail,⟨trivial,trivial⟩,⟨trivial,trivial⟩,
    (by intro f hf; simp only [List.mem_singleton] at hf; subst f; trivial),closed_store⟩

theorem drop_release : Step P B σ before none after ∧ StateTyE P B σ E after :=
  StateTyE.drop_rel_const effects_ok assumptions start rfl rfl

theorem releases_nonempty : releases saved = [.release resource] := rfl

theorem used_after_drop : (μ.set 0 .used) 0 = some .used := rfl

theorem error_start : StateTyE P B σ E (.error [rResume] [.drop 0] μ) :=
  ⟨Ψ,none,U,U,E,store,tail,(by intro f hf; simp only [List.mem_singleton] at hf; subst f; trivial),closed_store⟩

theorem error_release :
    Step P B σ (.error [rResume] [.drop 0] μ) none
      (.error [rResume] [.release resource] (μ.set 0 .used)) ∧
    StateTyE P B σ E (.error [rResume] [.release resource] (μ.set 0 .used)) :=
  StateTyE.err_drop_rel effects_ok assumptions error_start rfl

theorem exit_release :
    Step P B σ (.exit 0 [] [.drop 0] μ) none
      (.exit 0 [] [.release resource] (μ.set 0 .used)) ∧
    StateTyE P B σ E (.exit 0 [] [.release resource] (μ.set 0 .used)) :=
  StateTyE.exit_drop_rel effects_ok assumptions
    ⟨Ψ,none,U,U,E,store,tail,(by intro f hf; simp only [List.mem_singleton] at hf; subst f; trivial),closed_store⟩ rfl

abbrev qe : Closure := .pure (.escape unitV)
theorem escape_start : StateTyE P B σ E (.run qe [.drop 0,.mark] μ) := by
  refine ⟨Ψ,some U,U,U,E,Eff.empty,store,?_,sub_empty _,?_,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩,?_,closed_store⟩
  · exact ClosureTy.pure (.C_Escape (.V_Const trivial) u_ann)
      (empty_ann u_ann) (by intro r hr; cases hr; exact ⟨trivial,trivial⟩) rfl
      (by intro r hr; cases hr; rfl)
  · exact .K_Drop (b' := U) (t' := U) (e' := E) (R' := none) rfl (fun h => h)
      (.K_Mark (.K_Empty ⟨fun _ h => h,fun _ h => h⟩ u_ann) u_ann)
  · intro f hf
    simp only [List.mem_cons,List.not_mem_nil,or_false] at hf
    rcases hf with rfl | rfl <;> trivial

theorem escape_release :
    Step P B σ (.run qe [.drop 0,.mark] μ) none
      (.run qe [.release resource,.mark] (μ.set 0 .used)) ∧
    StateTyE P B σ E (.run qe [.release resource,.mark] (μ.set 0 .used)) :=
  StateTyE.esc_drop_rel_const effects_ok assumptions escape_start rfl
end Release

namespace Failure
abbrev body : Comp := .ret (.const .unit)
abbrev cs : List Clause := [.fail U body]
abbrev e : Eff := Eff.union (Eff.singleFail U) Eff.empty
private theorem ua {C : List TParam} {Γ : Ctx} : Ty.Annotation P C Γ U := ⟨trivial,trivial,trivial⟩
private theorem clauses {Ξ : StoreTy} :
    HasFailureClause P B Ξ Qempty [] [] [] U none cs U Eff.empty [] := by
  refine .one ua ua ?_ (.C_Return (.V_Const trivial))
  intro e he
  simp only [List.mem_singleton] at he
  subst e
  constructor <;> simp [Ty.WF,Ty.WFList,NamesWF,U,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,
    Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,declaredEff]
private theorem handled_typed {Ξ : StoreTy} :
    ContTy P B σ Ξ none e [.handleF Capture.empty cs] U U Eff.empty none := by
  exact .K_Handle_Fail (rest := Eff.empty) (.K_Empty (sub_empty _) ua) (.refl _ _ _)
    ⟨rfl,by intros; contradiction⟩ (CaptureOk.empty P B (hideBuilders Ξ) none) clauses
    rfl rfl (Eff.subst_values_empty _) rfl (by intros; contradiction) (.refl _ _ _) ua
    (by simp [Frame.Adequate,cs,adequateClauses,body,Comp.Adequate,Val.Adequate,Capture.Adequate,Capture.empty,adequateVals,adequateCaptureSlots])
-- 入力は結論の切り出しや等号ではなく、具体の失敗節の型付けから作る。
theorem split {Ξ : StoreTy} :
    ∃ t ec et Rh,
      ContTy P B σ Ξ none e [.handleF Capture.empty cs] U t (.mk et.atoms ec.fails) Rh ∧
      ContTy P B σ Ξ Rh et [] t U Eff.empty none ∧ Eff.Covers [] [] et ec ∧
      Eff.Sub (.mk et.atoms ec.fails) et :=
  (handled_typed (Ξ := Ξ)).split_fail (k1 := []) (k2 := []) rfl

theorem input {Ξ : StoreTy} :
    ∃ R1 Γ Φ Es Rs ts ecs,
      CaptureOk P B (hideBuilders Ξ) R1 Γ Φ Capture.empty ∧
      HasFailureClause P B (hideBuilders Ξ) Qempty [] Γ Φ Es Rs [.fail U body] ts ecs [] ∧
      (Capture.empty.closeTy Es).norm = U.norm := by
  apply (handled_typed (Ξ := Ξ)).fail_input (k1 := []) (k2 := []) rfl
    (by intro cap cs h; cases h)
  exact ⟨U,by simp [e,Eff.union,Eff.norm,Eff.fails,Eff.singleFail,Eff.empty,U,Ty.norm],rfl⟩
end Failure

namespace TwoArguments
abbrev Out : Ty := .refined I (.and (.eq (.var 0) (.var 2)) p)
abbrev tel : Tel := .param "first" Small (.param "second" Result (.done Out Eff.empty))
private theorem annotation : Ty.Annotation P [] [] (.dependentFn tel) := by
  constructor <;> simp [Tel.WF,Tel.Sorted,Tel.Declared,tel,Out,Result,rp,Small,p,I,Ty.WF,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,
    Term.VarsIn,Ty.Sorted,predBind,termBind?,upValues,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,
    Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Ctx.Readable,Ctx.declarationSelf,
    Ctx.extend,Ty.shiftV,Pred.shiftV,shiftIndex,Eff.empty,Eff.WF,Eff.Canonical,Eff.norm,Ty.WFList,
    sortedEff,sortedTys,declaredEff,declaredTys]
private theorem args {Ξ : StoreTy} :
    HasTypeTelArgsQ P B Ξ Qempty [] [] [] [three,three] tel.norm Returned Eff.empty := by
  apply HasTypeTelArgsQ.param small_ann three_small
  apply HasTypeTelArgsQ.param returned_ann three_returned
  have ht : Tel.bind (Tel.argumentsEnv three)
      (Tel.rawBind (Tel.argumentsEnv three).up (Tel.done Out Eff.empty).norm).norm =
      .done Returned Eff.empty := by
    simp [Tel.bind,Tel.rawBind,Tel.norm,Tel.argumentsEnv,Ty.rawBind,Ty.norm,Eff.rawBind,Eff.norm,
      Out,Returned,I,p,Eff.empty,SubstEnv.up,predBind,upValues,valEnv,three,
      Val.toTerm?,termBind,substAtoms,instAtoms,rowFails,rawBindTys]
    constructor
    · rfl
    · funext a
      cases a with
      | rho i => rfl
      | name l ix => cases ix <;> rfl
  rw [ht]
  exact .done (empty_ann returned_ann)

theorem captured {Ξ : StoreTy} :
    CaptureOk P B Ξ none ((Ctx.extend [] Small).extend Result) []
      ((Capture.empty.extend three).extend three) ∧
    Returned = ((Capture.empty.extend three).extend three).closeTy Out := by
  have ha := args_under_capture (cap := Capture.empty) annotation.wf (args (Ξ := Ξ))
  obtain ⟨hc,hl⟩ := capture_tel tel (CaptureOk.empty P B Ξ none) annotation ha
    (by simp [three,Val.Ground,Val.ClosedAt])
  exact ⟨by simpa [tel,telExtend,telLift,Capture.extendMany] using hc,
    by simpa [tel,Tel.result,Capture.extendMany] using (result_tel ha hl).1⟩
end TwoArguments

namespace ReviewCounterTable
-- t1 の操作表・効果表と組み込み表を再現する。保護した rv 入力には触れない。
def od : OpDecl := ⟨stateEff,[],[],[],U,[]⟩
def P : Program :=
  { defs := fun _ => none, cons := fun _ => none,
    ops := fun o => if o = "abort" then some od else none,
    effects := fun e => if e = stateEff then some ["abort"] else none,
    classes := fun _ => none, impls := fun _ => none }
def B : Builtins := { ModelCompatibility15.B with effects := fun _ => none, isResource := fun _ => true }
theorem old_table_rejected : ¬ Builtins.CoreAssumptions P B := by
  intro h
  have hh := h.state_effect
  change none = some [] at hh
  cases hh
-- State だけを予約し直しても、利用者の操作表との衝突は EffectsOk が断る。
theorem repaired_but_colliding : ¬ P.EffectsOk ModelCompatibility15.B := by
  intro h
  have hh := h.2.2 stateEff ["abort"] (by simp [P])
  change some [] = none at hh
  cases hh
end ReviewCounterTable

/-- 二引数の例: 第二引数の型と結果が先行の引数を読む。 -/
theorem two_dependent_arguments {P B Ψ R Γ Φ} {cap : Capture} {n1 n2 x1 x2 y e v1 v2 r f}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ha : Ty.Annotation P [] Γ (.dependentFn (.param n1 x1 (.param n2 x2 (.done y e)))))
    (hw : (Tel.param n1 x1 (.param n2 x2 (.done y e))).WF 0 0 0)
    (hargs : HasTypeTelArgsQ P B Ψ Qempty [] [] [] [v1,v2]
      (Tel.norm (.param n1 x1 (.param n2 x2 (.done y e)))) r f)
    (hg1 : v1.Ground) (hg2 : v2.Ground) :
    CaptureOk P B Ψ R ((Γ.extend x1).extend x2) ((Φ.map Pred.lift).map Pred.lift) ((cap.extend v1).extend v2) ∧
    r = ((cap.extend v1).extend v2).closeTy y := by
  have h := args_under_capture (cap := cap) hw hargs
  obtain ⟨h1,h2⟩ := capture_tel _ hc ha h (by simp [hg1,hg2])
  exact ⟨by simpa [telExtend,telLift,Capture.extendMany] using h1,
    by simpa [Capture.extendMany,Tel.result] using (result_tel h h2).1⟩


end
end Benitoite.Release.Refinement.ModelCompatibility15

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "Benitoite.Release.Refinement.ModelCompatibility15").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
