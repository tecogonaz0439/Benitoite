import Benitoite.Release.Refinement.HandlerOperation
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.RV14eT1
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
def od : OpDecl := ⟨stateEff,[],[],[],U,[]⟩
def P : Program :=
  { defs := fun _ => none, cons := fun _ => none,
    ops := fun o => if o = "abort" then some od else none,
    effects := fun e => if e = stateEff then some ["abort"] else none,
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
    releaseResponse := fun _ _ => True, isResource := fun _ => true,
    effects := fun _ => none, sat := fun _ _ _ => True, refGet := "get",refSet := "set" }

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
  pathBases_shape := by
    intro b s hs hk
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> cases hk
  opEff_io := by
    intro b s l hs ho
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> cases ho
  effect_ops := by intro l bs b hs; cases hs
  ref_get := ⟨sg .refGet,rfl,rfl⟩
  ref_set := ⟨sg .refSet,rfl,rfl⟩
  store_shape := by
    intro b s hs _
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> simp [sg,PrimSig.StoreShape,E]
  store_admits := by
    intro b s C ts hs
    rcases sig_cases hs with rfl | rfl | rfl | rfl | rfl <;> intros <;> trivial

abbrev r : Val := .const (.opaque "Res" 0)
abbrev unitV : Val := .const .unit
abbrev clauseBody : Comp := .ret unitV
def cs : List Clause := [.mk (.user "abort") 0 0 clauseBody]
abbrev saved : Cont := [.release r,.handleF Capture.empty cs]
def Ψ1 : StoreTy := StoreTy.empty.put 0 (.cont U U Eff.empty none)
def μ1 : Store := Store.empty.set 0 (.cont saved)
def μ2 : Store := μ1.set 0 .used
abbrev s0 : State := .run (.pure (.ret unitV)) [.drop 0] μ1
abbrev s1 : State := .run (.pure (.ret unitV)) (releases saved ++ []) μ2

theorem state_handled : Eff.Sub (Eff.single stateEff) (Eff.union Eff.empty (handled P B cs)) := by
  constructor
  · intro a ha
    change decide (a = .name stateEff .top) = true at ha
    cases of_decide_eq_true ha
    simp [Eff.mem,Eff.test,Eff.atoms,Eff.union,Eff.norm,Eff.empty,handled,effOps,P,cs,handles,Clause.op]
  · intro a ha; obtain ⟨_,h,_⟩ := ha; cases h

private theorem sub_empty (e : Eff) : Eff.Sub Eff.empty e := by
  constructor
  · intro a h; cases h
  · intro a h; obtain ⟨_,h,_⟩ := h; cases h

private theorem u_ann {Γ : Ctx} : Ty.Annotation P [] Γ U := ⟨trivial,trivial,trivial⟩
private theorem empty_ann {Γ a} (ha : Ty.Annotation P [] Γ a) :
    Ty.Annotation P [] Γ (.dependentFn (.done a Eff.empty)) :=
  ⟨⟨ha.wf,by simp [Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨ha.sorted,by simp [sortedEff,Eff.empty,sortedTys]⟩,⟨ha.declared,by simp [declaredEff,Eff.empty,declaredTys]⟩⟩

private theorem clauses_typed {Ψ : StoreTy} :
    HasTypeClausesQ P B Ψ Qempty [] [] [] none (Eff.single stateEff) cs U Eff.empty [] := by
  apply HasTypeClausesQ.cons (sg := ⟨[],[],[],U,stateEff⟩)
    (ClauseSig.of_opSig (by simp [opSig,opSigAt,P,od])) (by simp [NamesWF]) rfl rfl
  · exact ⟨trivial,trivial⟩
  · exact HasTypeCQ.C_Return (.V_Const (c:=.unit) trivial)
  · exact .nil

private theorem saved_cont {Ψ : StoreTy} :
    ContTy P B σ Ψ none (Eff.single stateEff) saved U U Eff.empty none := by
  refine .K_Release (.V_Const (c:=.opaque "Res" 0) (by simp [ConstOK,B])) trivial rfl ?_ ?_
  · simp [Eff.mem,Eff.test,Eff.single,Eff.atoms]
  · apply ContTy.K_Handle (ec := Eff.empty) (ε := Eff.empty) (Γ := []) (Φ := []) (Rs := none)
      (ts := U) (ecs := Eff.empty) (ebs := Eff.single stateEff)
      (.K_Empty (sub_empty _) u_ann) (.refl _ _ _) state_handled
      (CaptureOk.empty P B (hideBuilders Ψ) none) clauses_typed rfl rfl
      (Eff.subst_values_empty _) (Eff.subst_values_single _ _) (empty_ann u_ann) u_ann
      (by intros; contradiction)
    trivial

theorem store1 : StoreOk P B σ Ψ1 μ1 := by
  have hk : ContTy P B σ StoreTy.empty none (Eff.single stateEff) saved U U Eff.empty none := saved_cont
  exact (StoreOk.empty P B σ).allocate_continuation assumptions.values rfl
    (⟨trivial,trivial,by simp [Eff.WF,Eff.empty,Ty.WFList],by rfl,by intros; contradiction⟩)
    (⟨trivial,trivial,by simp [declaredEff,Eff.empty,declaredTys],by intros; contradiction⟩)
    ⟨[.release r],Capture.empty,cs,rfl⟩ ⟨none,_,hk⟩

theorem start : StateTyE P B σ Eff.empty s0 := by
  refine ⟨Ψ1,none,U,U,Eff.empty,Eff.empty,store1,?_,⟨fun _ h => h,fun _ h => h⟩,
    .K_Drop (b' := U) (t' := U) (e' := Eff.empty) (R' := none) rfl (by intro h; cases h)
      (.K_Empty (sub_empty _) u_ann),?_,?_,?_,?_⟩
  · exact ClosureTy.pure (.C_Return (.V_Const (c:=.unit) trivial)) (empty_ann u_ann)
      (by intros; contradiction) (by rfl) (by intros; contradiction)
  · simp [Closure.Adequate,Closure.pure,Capture.empty,Capture.Adequate,adequateCaptureSlots,Comp.Adequate,Val.Adequate]
  · simp [Closure.ClosedAt,Closure.pure,Capture.Closed,Capture.empty,captureSlotsClosed,Comp.ClosedAt,Val.ClosedAt,Capture.values]
  · intro f hf; simp at hf; subst f; trivial
  · intro l c hc
    by_cases h0 : l = 0
    · subst l; simp [μ1,Store.set] at hc; subst c
      intro f hf
      simp only [saved,List.mem_cons,List.not_mem_nil,or_false] at hf
      rcases hf with rfl | rfl
      · simp [Frame.Closed,Val.Ground]; first | trivial | rfl
      · simp [Frame.Closed,Capture.Closed,Capture.empty,captureSlotsClosed,cs,Clause.ClosedList,Comp.ClosedAt,Val.ClosedAt,Capture.values]
    · simp [μ1,Store.set,Store.empty,h0] at hc

/-- E_DropRel は実際の遷移である。 -/
theorem drop_rel_step : Step P B σ s0 none s1 := .E_DropRel rfl rfl

private theorem release_tail {Ψ R e k a b Eb Re v}
    (h : ContTy P B σ Ψ R e k a b Eb Re) (hk : k = [.release v]) : Eff.mem e (.name stateEff (.fixed .top)) ∧ Eff.Sub e Eb := by
  induction h with
  | K_Sub _ _ ih => exact ih hk
  | K_Release _ _ _ hm ht _ =>
    cases hk
    exact ⟨hm,(ht.nil_inv rfl).2.1⟩
  | _ => cases hk

/-- 開始の StateTyE は成り立つが、到達の状態には型が付かない。 -/
theorem target_untypable : ¬ StateTyE P B σ Eff.empty s1 := by
  rintro ⟨Ψ,R,a,b,e,e1,_,_,_,hk,_⟩
  obtain ⟨hm,hs⟩ := release_tail hk (v := r) rfl
  have := hs.1 _ hm
  cases this

/-- 抽象の B・P の全保存の言明は CoreAssumptions だけからは偽である。 -/
theorem no_drop_rel_preservation :
    Builtins.CoreAssumptions P B ∧ StateTyE P B σ Eff.empty s0 ∧ Step P B σ s0 none s1 ∧
      ¬ StateTyE P B σ Eff.empty s1 :=
  ⟨assumptions,start,drop_rel_step,target_untypable⟩

/-- 同じ継続を持つ操作の遷移の前段が実際に source の形から作れることの確認: handled が State を含む。 -/
theorem effects_hole : P.effects stateEff = some ["abort"] := by simp [P]
end
end Benitoite.Release.Refinement.RV14eT1
#print axioms Benitoite.Release.Refinement.RV14eT1.no_drop_rel_preservation
