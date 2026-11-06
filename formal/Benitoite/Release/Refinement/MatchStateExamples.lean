import Benitoite.Release.Refinement.HandlerGeneral
import Benitoite.Release.Refinement.TypedMeaningExamples

/-! # 照合・guard・handler の状態の適用例と拒否の境界 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace MatchStateExamples

private def unit : Val := .const .unit
private def root : Val := .list [unit,unit]
private def result : Comp := .ret unit
private def pairs : List Alt := [.mk headRestPattern [0,1]]
private def wild : List Alt := [.mk .wild []]
private def plainArms : List Arm := [.mk pairs none result,.mk wild none result]
private def guardArms (b : Bool) : List Arm := [.mk pairs (some (.ret (.const (.boolean b)))) result,.mk wild none result]

private theorem unit_annotation {P C Γ} : Ty.Annotation P C Γ (.base .unit) := ⟨trivial,trivial,trivial⟩

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e := by
  constructor
  · intro a ha; cases ha
  · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu

private theorem ret_unit {P B Ψ Q C Γ Φ R L} (e : Eff) :
    HasTypeCQ P B Ψ Q C Γ Φ R result (.base .unit) e L :=
  .C_Eff (.C_Return (.V_Const (by trivial))) (empty_sub e).covers

private theorem pair_alts (P : Program) (a : Ty) : AltsTy P pairs (.list a) [a,.list a] := by
  refine ⟨by simp [pairs],rfl,?_,?_⟩
  · intro alt h; cases Option.some.inj h; rfl
  · intro alt h
    cases List.mem_singleton.mp h
    exact ⟨[a,.list a],.P_List (.cons .P_Var .nil) .nil (by intro h; cases h),List.Perm.refl _,rfl⟩

private theorem wild_alts (P : Program) (a : Ty) : AltsTy P wild a [] := by
  refine ⟨by simp [wild],rfl,?_,?_⟩
  · intro alt h; cases Option.some.inj h; rfl
  · intro alt h; cases List.mem_singleton.mp h
    exact ⟨[],.P_Wild,List.Perm.refl _,rfl⟩

private theorem boolean_typed {P B Ψ Q C Γ Φ} (b : Bool) :
    HasTypeVQ P B Ψ Q C Γ Φ (.const (.boolean b)) (.refined (.base .boolean) .truth) := by
  have ha : Ty.Annotation P C Γ (.refined (.base .boolean) .truth) :=
    ⟨⟨trivial,trivial,by intro b t e h; cases h⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
  exact .V_Sub (.V_Const (by trivial)) (.convert rfl) ha.wf ha.sorted ha.declared

private theorem boolean_annotation {P C Γ} : Ty.Annotation P C Γ (.refined (.base .boolean) .truth) :=
  ⟨⟨trivial,trivial,by intro b t e h; cases h⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

private theorem root_typed (P : Program) (B : Builtins) :
    HasTypeVQ P B StoreTy.empty Qempty [] [] [] root (.list (.base .unit)) :=
  .V_List (.cons (.V_Const (by trivial)) (.cons (.V_Const (by trivial)) .nil)) trivial trivial trivial

private theorem plain_code (P : Program) (B : Builtins) :
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none (.match root plainArms) (.base .unit) Eff.empty [] := by
  refine .C_Match (root_typed P B) (obs := none) (by intro t h; cases h)
    (.plainEmpty (pair_alts P _) (by intro p hp; cases hp) (ret_unit _)
      (.plainEmpty (wild_alts P _) (by intro p hp; cases hp) (ret_unit _) (.nil unit_annotation))) trivial ?_
  intro v hv
  exact ⟨.wild,by simp [unguardedPats,plainArms,pairs,wild],by simp [matchVal]⟩

private theorem guard_code (P : Program) (B : Builtins) (b : Bool) :
    HasTypeCQ P B StoreTy.empty Qempty [] [] [] none (.match root (guardArms b)) (.base .unit) Eff.empty [] := by
  refine .C_Match (root_typed P B) (obs := none) (by intro t h; cases h)
    (.guardedEmpty (pair_alts P _) (by intro p hp; cases hp) boolean_annotation
      (.C_Return (boolean_typed b)) (ret_unit _)
      (.plainEmpty (wild_alts P _) (by intro p hp; cases hp) (ret_unit _) (.nil unit_annotation))) trivial ?_
  intro v hv
  exact ⟨.wild,by simp [unguardedPats,guardArms,wild],by simp [matchVal]⟩

private theorem initial {P B σ m}
    (h : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none m (.base .unit) Eff.empty [])
    (hc : m.ClosedAt 0 0) (ha : m.Adequate σ) :
    StateTyE P B σ Eff.empty (.run (Closure.pure m) [] Store.empty) := by
  have hq := ClosureTy.pure h unit_annotation.done_empty (by intro r hr; cases hr) rfl (by intro r hr; cases hr)
  exact ⟨StoreTy.empty,none,.base .unit,.base .unit,Eff.empty,Eff.empty,StoreOk.empty P B σ,
    hq,⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩ unit_annotation,
    ⟨trivial,ha⟩,⟨trivial,hc⟩,(by intro f hf; cases hf),(by intro l c hc; cases hc)⟩

theorem two_bindings {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty
      (.run (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) [] Store.empty) := by
  have hs := initial (σ := σ) (plain_code P B)
    (by simp [plainArms,root,unit,result,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Arm.ClosedList])
    (by simp [plainArms,root,unit,result,Comp.Adequate,Val.Adequate,adequateVals,adequateArms])
  have hm := hs.match_start rfl
  exact hm.match_body hP hPB hB (n := 0) rfl rfl

private theorem guard_prepared {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (b : Bool) :
    StateTyE P B σ Eff.empty
      (.run (.mk (Capture.empty.extendMany [unit,.list [unit]]) (.ret (.const (.boolean b))))
        (.guardF root Capture.empty (guardArms b) 1 (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) :: []) Store.empty) := by
  have hs := initial (σ := σ) (guard_code P B b)
    (by simp [guardArms,root,unit,result,Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Arm.ClosedList])
    (by simp [guardArms,root,unit,result,Comp.Adequate,Val.Adequate,adequateVals,adequateArms])
  have hm := (hs.match_start rfl).match_guard hP hPB hB (n := 0) (ws := [unit,.list [unit]]) rfl rfl
  exact hm

theorem guard_execution {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (b : Bool) :
    if b then
      StateTyE P B σ Eff.empty (.run (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) [] Store.empty)
    else
      StateTyE P B σ Eff.empty (.matchRun root Capture.empty (guardArms b) 1 [] Store.empty) := by
  have hm := guard_prepared (σ := σ) hP hPB hB b
  cases b with
  | true => exact hm.guard_true hB.substitutions rfl
  | false => exact hm.guard_false rfl

example {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.run (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) [] Store.empty) :=
  guard_execution hP hPB hB true

example {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.matchRun root Capture.empty (guardArms false) 1 [] Store.empty) :=
  guard_execution hP hPB hB false

theorem handler_returned {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.run (Closure.pure result) [] Store.empty) := by
  have ht : HasTypeCQ P B StoreTy.empty Qempty [] [] [] none (.handle result []) (.base .unit) Eff.empty [] :=
    .C_Handle (ret_unit _) (empty_sub _) .nil
  have hs := initial (σ := σ) ht
    (by simp [result,unit,Comp.ClosedAt,Val.ClosedAt,Clause.ClosedList])
    (by simp [result,unit,Comp.Adequate,Val.Adequate,adequateClauses])
  exact (hs.handle_step hB rfl).handler_return hP hPB hB rfl

theorem guard_propagation {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.error [] [] Store.empty) ∧
    StateTyE P B σ Eff.empty (.exit 0 [] [] Store.empty) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,_,_,hk,_,_,hkc,hμ⟩ := guard_prepared (σ := σ) hP hPB hB true
  have herr : StateTyE P B σ Eff.empty
      (.error [] (.guardF root Capture.empty (guardArms true) 1 (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) :: []) Store.empty) :=
    ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩
  have hext : StateTyE P B σ Eff.empty
      (.exit 0 [] (.guardF root Capture.empty (guardArms true) 1 (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) :: []) Store.empty) :=
    ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩
  exact ⟨herr.err_pop_guard,hext.exit_pop_guard⟩

example {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.error [] [] Store.empty) ∧
    StateTyE P B σ Eff.empty (.exit 0 [] [] Store.empty) := guard_propagation hP hPB hB

private def unknownGuardType : Ty := .refined (.base .boolean) TypedMeaningExamples.unknownPredicate

private theorem unknown_guard_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] [] [] none (.ret (.const (.boolean true))) unknownGuardType Eff.empty [] := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Const (by trivial)) rfl rfl ?_ ?_ ?_ trivial ?_
  · simp [TypedMeaningExamples.unknownPredicate,TypedMeaningExamples.unknownTerm,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,varsInSlot,varsInSlots,Term.Shape,Measure.input,Measure.output]
  · simp [TypedMeaningExamples.unknownPredicate,TypedMeaningExamples.unknownTerm,Pred.WF,Pred.VarsIn,Term.VarsIn,varsInSlot,varsInSlots]
  · exact Entails.eq_refl
  · simp [TypedMeaningExamples.unknownPredicate,TypedMeaningExamples.unknownTerm,Pred.Declared,Term.Declared,declaredSlot,declaredSlots]

/-- guard は型や真偽によらず網羅性に数えない。同じパターンの guard なしの腕は数える。 -/
theorem reject_guard_unknown_elimination (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] [] [] none (.ret (.const (.boolean true))) unknownGuardType Eff.empty [] ∧
    TypedMeaningExamples.unknownPredicate.evalWith (fun _ => none) = none ∧
    (∀ g : Comp, ¬ Exhaustive P (.base .boolean)
      (unguardedPats [.mk wild (some g) result])) ∧
    Exhaustive P (.base .boolean) (unguardedPats [.mk wild none result]) := by
  refine ⟨unknown_guard_typed P B Ψ,rfl,?_,?_⟩
  · intro g h
    obtain ⟨pat,hp,_⟩ := h (.const (.boolean true)) (by simpa only [Ty.norm,Const.type] using (Inhabits.const (P := P) (c := .boolean true)))
    cases hp
  · intro v hv
    exact ⟨.wild,by simp [unguardedPats,wild],by simp [matchVal]⟩

theorem reject_false_fact_to_tail {P B Ψ} (valid : P.VarianceValid) :
    HasTypeCQ P B Ψ Qempty [] [] [] none (.ret (.const (.boolean false)))
      (.refined (.base .boolean) .truth) Eff.empty [] ∧
    HasTypeCQ P B Ψ Qempty [] [] [.falsity] none (.ret TypedMeaningExamples.thirteen) monthType Eff.empty [] ∧
    ¬ HasTypeArmsQ P B Ψ Qempty [] [] [] none none
      [.mk wild (some (.ret (.const (.boolean false)))) (.ret TypedMeaningExamples.five),
       .mk wild none (.ret TypedMeaningExamples.thirteen)] (.base .boolean) monthType Eff.empty [] := by
  refine ⟨.C_Return (boolean_typed false),?_,?_⟩
  · apply HasTypeCQ.C_Return
    refine .V_Refine (.V_Const (by trivial)) rfl rfl ?_ ?_ ?_ trivial ?_
    · exact ⟨⟨⟨trivial,rfl⟩,⟨⟨_,rfl,by intro b t e h; cases h⟩,⟨_,rfl,rfl⟩⟩⟩,
        ⟨⟨⟨_,rfl,by intro b t e h; cases h⟩,⟨_,rfl,rfl⟩⟩,⟨trivial,rfl⟩⟩⟩
    · simp [monthPredicate,Pred.WF,Term.VarsIn,Pred.VarsIn]
    · exact .false_elim (.hyp (by simp [Ctx.facts]))
    · exact ⟨⟨trivial,⟨_,rfl,by intro b t e h; cases h⟩⟩,
        ⟨⟨_,rfl,by intro b t e h; cases h⟩,trivial⟩⟩
  intro h
  cases h with
  | guarded _ _ _ _ _ _ _ tail =>
    match tail with
    | .plain (δ := δ) hp _ _ _ hb _ =>
      have hd : δ = [] := List.eq_nil_of_length_eq_zero hp.2.1
      subst δ
      have hv := hb.ret_value rfl
      apply TypedMeaningExamples.reject_top valid
      simpa only [Refinement.bindParams,liftMany_eq,pathFacts,fieldFacts,List.length_nil,List.reverse_nil,List.map_nil,List.nil_append,Ty.shiftV_zero] using hv

example {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.run (.mk (Capture.empty.extendMany [unit,.list [unit]]) result) [] Store.empty) :=
  two_bindings hP hPB hB

example {P B σ} (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    StateTyE P B σ Eff.empty (.run (Closure.pure result) [] Store.empty) := handler_returned hP hPB hB

end MatchStateExamples
end
end Benitoite.Release.Refinement
