import Benitoite.Release.Refinement.LegacyProgramTyping
import Benitoite.Release.Refinement.LegacyFullEmbeddingExamples

namespace Benitoite.Release.Refinement.LegacyStateEmbeddingExamples
noncomputable section
open LegacyPatternExamples

private abbrev U : Benitoite.Release.Ty := .base .unit
private abbrev E : Benitoite.Release.Eff := .empty
private abbrev S : Benitoite.Release.StoreTy := .empty
private abbrev F : Benitoite.Release.Ty := .fn [] [] U E
private def functionValue : Benitoite.Release.Val := .lam [] [] (.ret (.const .unit))
private def arms : List Benitoite.Release.Arm := [.mk [⟨.wild,[]⟩] none (.ret (.const .unit))]
private def guardStack : Benitoite.Release.Cont := [.guardF functionValue arms 0 (.ret (.const .unit))]

private theorem empty_context : LegacyNodeContext kinds oldProgram [] S [] [] := by
  refine ⟨rfl,rfl,rfl,?_,?_⟩
  · intro l lt h; cases h
  · intro i a h; simp at h

private theorem unit_type : LegacyTypeInput kinds oldProgram .closed U .value :=
  ⟨trivial,trivial,trivial,trivial,trivial⟩

private theorem function_type : LegacyTypeInput kinds oldProgram .closed F .value := by
  unfold LegacyTypeInput F
  rw [show embedTy (.fn [] [] U E) = .fn [] [] (.base .unit) Eff.empty from
    congrArg (Ty.fn [] [] (.base .unit)) legacy_empty]
  simp [Ty.HasKind,NamesWF,kindsList,kindsEff,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,
    Eff.empty,Eff.norm,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
    declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped,LegacyInputCtx.closed]

private theorem rows : LegacyRowsInput kinds oldProgram .closed [E] := by
  intro e he
  obtain rfl := List.mem_singleton.mp he
  exact function_type

private theorem ret_input (R : Option Benitoite.Release.Ty) (hr : ∀ a ∈ R.toList, a = U) :
    LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp [] S Benitoite.Release.Qempty [] [] R (.ret (.const .unit)) U E []) := by
  refine .node .C_Return ⟨empty_context,trivial,?_,rows,by simp [LegacyNodeLocal]⟩ ?_
  · intro a ha
    rcases List.mem_cons.mp ha with rfl | ha
    · exact unit_type
    · obtain rfl := hr a ha; exact unit_type
  · intro child hc
    obtain rfl := List.mem_singleton.mp hc
    exact LegacyEmbeddingExamples.unit_input

private theorem lambda_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.value [] S Benitoite.Release.Qempty [] [] functionValue F) := by
  refine .node (.V_Lam ⟨rfl,by simp⟩ (legacy_wf function_type.2.1))
    ⟨empty_context,?_,trivial,?_⟩ ?_
  · exact ⟨⟨rfl,by simp⟩,by simp, trivial⟩
  · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact function_type
  · intro child hc
    obtain rfl := List.mem_singleton.mp hc
    exact ret_input (some U) (by simp)

private theorem match_input : LegacyClosedCompInput kinds oldProgram oldBuiltins builtins S [] none
    (.match functionValue arms) U E := by
  have alts : Benitoite.Release.AltsTy oldProgram [⟨.wild,[]⟩] F [] := by
    refine ⟨by simp,rfl,?_,?_⟩
    · intro alt h; cases h; rfl
    · intro alt h; obtain rfl := List.mem_singleton.mp h
      exact ⟨[],.P_Wild,.refl _,rfl⟩
  have regular (xs : List Benitoite.Release.Arm) (hi : LegacyArmsInput kinds oldProgram oldBuiltins builtins .closed xs) :
      LegacyNodeRegular kinds oldProgram oldBuiltins builtins
        (.arms [] S Benitoite.Release.Qempty [] [] none xs F U E []) := by
    refine ⟨empty_context,hi,?_,rows,by simp [LegacyNodeLocal]⟩
    intro a ha
    have hm : a = F ∨ a = U := by simpa using ha
    rcases hm with rfl | rfl
    · exact function_type
    · exact unit_type
  have empty : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.arms [] S Benitoite.Release.Qempty [] [] none [] F U E []) :=
    .node (.Arms_nil trivial) (regular [] trivial) (by simp)
  have nonempty : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.arms [] S Benitoite.Release.Qempty [] [] none arms F U E []) := by
    refine .node (.Arms_plain (δ := []) alts) (regular arms ⟨trivial,trivial,trivial⟩) ?_
    intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact ret_input none (by simp)
    · obtain rfl := List.mem_singleton.mp hc; exact empty
  have coverage : Benitoite.Release.Exhaustive oldProgram F (Benitoite.Release.unguardedPats arms) := by
    intro v hv
    exact ⟨.wild,by simp [arms,Benitoite.Release.unguardedPats],by simp [Benitoite.Release.Pat.matchVal]⟩
  refine ⟨.node (.C_Match coverage) ⟨empty_context,?_,?_,rows,by simp [LegacyNodeLocal]⟩ ?_,?_⟩
  · exact ⟨lambda_input.regular.2.1,⟨trivial,trivial,trivial⟩⟩
  · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type
  · intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact lambda_input
    · obtain rfl := List.mem_singleton.mp hc; exact nonempty
  · simp [embedComp,functionValue,embedVal,arms,embedArms,embedArm,Comp.ClosedAt,
      Val.ClosedAt,Arm.ClosedList,NamesWF]

private theorem sub_empty : Benitoite.Release.Eff.Sub E E := ⟨fun _ h => h,fun _ h => h⟩

private theorem oldGuard : Benitoite.Release.ContTy oldProgram oldBuiltins S none E guardStack
    (.base .boolean) U E none :=
  .K_Guard match_input.1.old sub_empty (by intro arm h; simp at h)
    (ret_input none (by simp)).old (.K_Empty sub_empty trivial)

theorem guard_input : LegacyContInput kinds oldProgram oldBuiltins builtins S oldGuard := by
  have regular (a : Benitoite.Release.Ty) (ha : LegacyTypeInput kinds oldProgram .closed a .value) :
      LegacyContRegular kinds oldProgram S none E a U E none := by
    refine ⟨empty_context,?_,?_⟩
    · intro t ht
      have hm : t = a ∨ t = U := by simpa using ht
      rcases hm with rfl | rfl
      · exact ha
      · exact unit_type
    · intro e he; exact rows e (by simpa using he)
  exact .guard (ht := match_input.1.old) (hs := sub_empty) (hp := by intro arm h; simp at h)
    (hm := (ret_input none (by simp)).old)
    (hk := Benitoite.Release.ContTy.K_Empty sub_empty trivial) (regular (.base .boolean) ⟨trivial,trivial,trivial,trivial,trivial⟩)
    match_input ⟨ret_input none (by simp),trivial⟩ (.empty (R := none) (a := U) (e := E) (out := E) (hs := sub_empty) (hw := trivial) (regular U unit_type))

private theorem no_closed_lambda (v : Val) (ns : List String) (ps : List Ty) (body : Comp) :
    closeVal Capture.empty v ≠ .lam ns ps body := by
  cases v <;> simp [closeVal,Capture.env,Capture.empty,Capture.values]

theorem no_embedded_guard {P : Program} {B : Builtins} {σ : PathEnv} {Ψ : StoreTy}
    {R : Option Ty} {e : Eff} {k : Cont} {a b : Ty} {out : Eff} {Re : Option Ty}
    {ns : List String} {ps : List Ty} {body : Comp} {arms : List Arm} {next : Nat} {q : Closure} :
    ¬ ContTy P B σ Ψ R e (.guardF (.lam ns ps body) Capture.empty arms next q :: k) a b out Re := by
  intro h
  generalize he : (.guardF (.lam ns ps body) Capture.empty arms next q :: k) = stack at h
  induction h with
  | K_Sub _ _ ih => exact ih he
  | @K_Guard R e v cap arms next body k a b Eb Re e1 Γ Φ Rs vs t as es arms0 L ρ obs input
      hc hv ho ha hl hAr hr hx heq hR ht heff hb hs hp hk had ih =>
    have hh := List.cons.inj he
    cases hh.1
    exact no_closed_lambda vs _ _ _ heq.symm
  | _ => cases he

theorem old_guard_embedding_impossible (σ : PathEnv) :
    LegacyContInput kinds oldProgram oldBuiltins builtins S oldGuard ∧
    ¬ ContTy (embedProgramWithKinds kinds oldProgram) builtins σ (embedStoreTy S) none (embedEff E)
      ([.guardF (embedVal functionValue) Capture.empty (embedArms arms) 0 (.pure (.ret (.const .unit)))]) (embedTy (.base .boolean)) (embedTy U) (embedEff E) none :=
  ⟨guard_input,no_embedded_guard⟩

private def matchState : Benitoite.Release.State :=
  .matchRun functionValue arms 0 [] Benitoite.Release.Store.empty

private theorem empty_store : LegacyStoreInput kinds oldProgram oldBuiltins builtins S Benitoite.Release.Store.empty := by
  refine ⟨⟨⟨0,by intro l _; rfl⟩,?_,?_,?_⟩,empty_context,?_⟩
  all_goals intro l c hc <;> cases hc

theorem state_input : LegacyStateInput kinds oldProgram oldBuiltins builtins E matchState := by
  let hk : Benitoite.Release.ContTy oldProgram oldBuiltins S none E [] U U E none :=
    .K_Empty sub_empty trivial
  refine ⟨S,none,U,U,E,E,hk,empty_store,match_input,sub_empty,?_,?_,?_,?_,?_⟩
  · refine .empty (R := none) (a := U) (e := E) (out := E) (hs := sub_empty) (hw := trivial) ?_
    refine ⟨empty_context,?_,?_⟩
    · intro a ha
      have he : a = U := by simpa using ha
      subst a; exact unit_type
    · intro e he; exact rows e (by simpa using he)
  · simp [functionValue,arms,Benitoite.Release.Comp.VarsIn,Benitoite.Release.Val.VarsIn,
      Benitoite.Release.Arm.VarsInList,Benitoite.Release.NamesWF,Benitoite.Release.Ty.VarsInList]
  · simp [Benitoite.Release.Cont.Closed]
  · intro l c hc; cases hc
  · intro arm hm; simp at hm

theorem old_state_embedding_impossible (σ : PathEnv) :
    LegacyStateInput kinds oldProgram oldBuiltins builtins E matchState ∧
    ¬ StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E)
      (.matchRun (embedVal functionValue) Capture.empty (embedArms arms) 0 [] (embedStore Benitoite.Release.Store.empty)) := by
  refine ⟨state_input,?_⟩
  intro h
  obtain ⟨Ψ,R,a,b,e,e1,hs,code,rest⟩ := h
  obtain ⟨vs,he,hq⟩ := code
  exact no_closed_lambda vs [] [] (.ret (.const .unit)) he.symm

theorem old_match_step : Benitoite.Release.Step oldProgram oldBuiltins
    (.run (.match functionValue arms) [] Benitoite.Release.Store.empty) none matchState := .E_Match


theorem guard_embedding_accepted (σ : PathEnv) :
    ContTy (embedProgramWithKinds kinds oldProgram) builtins σ (embedStoreTy S) none (embedEff E)
      (embedCont guardStack) (embedTy (.base .boolean)) (embedTy U) (embedEff E) none :=
  embedContTy kinds_wf tables guard_input

theorem state_embedding_accepted (σ : PathEnv) :
    StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E) (embedState matchState) :=
  embedStateTyE kinds_wf tables state_input

theorem held_lambda_typed :
    HasTypeVQ (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Qempty [] [] []
      (embedHeldVal functionValue) (embedTy F) := embedHeldVal_typed kinds_wf tables lambda_input

theorem held_lambda_covered : ∃ p ∈ ([.wild] : List Pat), (matchVal p (embedHeldVal functionValue)).isSome := by
  apply Capture.typed_coverage (P := embedProgramWithKinds kinds oldProgram) (B := builtins)
    (Ψ := embedStoreTy S) (a := embedTy F) (cap := Capture.empty) tables.varianceValid
  · simpa only [Capture.closeTy,substTyValues_embed,embedTy_norm,legacy_normal function_type.2.1] using held_lambda_typed
  · intro v hv; exact ⟨.wild,by simp,by simp [matchVal]⟩

theorem state_typed_of_valid (σ : PathEnv) (valid : σ.Valid) :
    StateTy (embedProgramWithKinds kinds oldProgram) builtins σ (embedState matchState) := by
  refine ⟨valid,embedEff E,?_,state_embedding_accepted σ⟩
  rw [legacy_empty]
  exact ⟨rfl,by intro a ha; cases ha⟩

theorem empty_store_embedded (σ : PathEnv) :
    StoreOk (embedProgramWithKinds kinds oldProgram) builtins σ (embedStoreTy S) (embedStore Benitoite.Release.Store.empty) :=
  embedStoreOk kinds_wf tables empty_store

theorem run_embedded (σ : PathEnv) :
    StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E)
      (embedState (.run (.ret (.const .unit)) [] Benitoite.Release.Store.empty)) :=
  embedStateTyE kinds_wf tables LegacyFullEmbeddingExamples.run_input

theorem error_and_exit_embedded (σ : PathEnv) (rs : List ErrKind) (code : Int) :
    StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E)
      (embedState (.error rs [] Benitoite.Release.Store.empty)) ∧
    StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E)
      (embedState (.exit code rs [] Benitoite.Release.Store.empty)) := by
  obtain ⟨Ψ,R,a,b,e,e1,hk,store,body,sub,cont,closed,kclosed,μclosed⟩ := LegacyFullEmbeddingExamples.run_input
  exact ⟨embedStateTyE kinds_wf tables ⟨Ψ,R,a,b,e,hk,store,cont,kclosed,μclosed⟩,
    embedStateTyE kinds_wf tables ⟨Ψ,R,a,b,e,hk,store,cont,kclosed,μclosed⟩⟩

private def listArms : List Benitoite.Release.Arm :=
  [.mk [⟨.list [.var] (some .skip) [],[0]⟩] none (.ret (.var 0)),
   .mk [⟨.list [] none [],[]⟩] none (.ret functionValue)]

private theorem function_type_at (n : Nat) :
    LegacyTypeInput kinds oldProgram ⟨[],[],0,n⟩ F .value := function_type

private theorem list_type : LegacyTypeInput kinds oldProgram .closed (.list F) .value := function_type

private theorem list_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.value [] S Qempty [] [] (.list [functionValue]) (.list F)) := by
  have ts : LegacyNodeTypes kinds oldProgram [] [] 0 [F] := by
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact function_type
  have empty : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.each [] S Qempty [] [] [] F) :=
    .node .Each_nil ⟨empty_context,trivial,ts⟩ (by simp)
  have each : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.each [] S Qempty [] [] [functionValue] F) := by
    refine .node .Each_cons ⟨empty_context,⟨lambda_input.regular.2.1,trivial⟩,ts⟩ ?_
    intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact lambda_input
    · obtain rfl := List.mem_singleton.mp hc; exact empty
  refine .node (.V_List (legacy_wf function_type.2.1)) ⟨empty_context,each.regular.2.1,trivial,?_⟩ ?_
  · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact list_type
  · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact each

private theorem list_match_input : LegacyClosedCompInput kinds oldProgram oldBuiltins builtins S [] none
    (.match (.list [functionValue]) listArms) F E := by
  have rs : LegacyRowsInput kinds oldProgram .closed [E] := rows
  have typ : LegacyNodeTypes kinds oldProgram [] [] 0 [F] := by
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact function_type
  have t1 : LegacyNodeTypes kinds oldProgram [] [] 1 [F] := by
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact function_type_at 1
  have ctx : LegacyNodeContext kinds oldProgram [] S [] [some F] := by
    refine ⟨rfl,rfl,rfl,?_,?_⟩
    · intro l t h; cases h
    · intro i a hi
      cases i with
      | zero => cases hi; exact ⟨function_type_at 1,function_type.annotation_at rfl rfl _⟩
      | succ i => simp at hi
  have hv : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.value [] S Qempty [] [some F] (.var 0) F) :=
    .node (.V_Var rfl (by intro b t e h; cases h)) ⟨ctx,trivial,trivial,t1⟩ (by simp)
  have retFirst : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp [] S Qempty [] [some F] none (.ret (.var 0)) F E []) := by
    refine .node .C_Return ⟨ctx,trivial,?_,(by intro e he; obtain rfl := List.mem_singleton.mp he; exact function_type_at 1),by simp [LegacyNodeLocal]⟩ ?_
    · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact function_type_at 1
    · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact hv
  have retEmpty : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp [] S Qempty [] [] none (.ret functionValue) F E []) := by
    refine .node .C_Return ⟨empty_context,lambda_input.regular.2.1,?_,rs,by simp [LegacyNodeLocal]⟩ ?_
    · exact typ
    · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact lambda_input
  have tail : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.arms [] S Qempty [] [] none [] (.list F) F E []) := by
    refine .node (.Arms_nil (legacy_wf function_type.2.1)) ⟨empty_context,trivial,?_,rs,by simp [LegacyNodeLocal]⟩ (by simp)
    intro a ha
    have hm : a = .list F ∨ a = F := by simpa using ha
    rcases hm with rfl | rfl
    · exact list_type
    · exact function_type
  have pats0 : Benitoite.Release.AltsTy oldProgram [⟨.list [] none [],[]⟩] (.list F) [] := by
    refine ⟨by simp,rfl,?_,?_⟩
    · intro a ha; cases ha; rfl
    · intro a ha; obtain rfl := List.mem_singleton.mp ha
      exact ⟨[],.P_List .nil .nil (by simp),.refl _,rfl⟩
  have tail1 : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.arms [] S Qempty [] [] none [.mk [⟨.list [] none [],[]⟩] none (.ret functionValue)] (.list F) F E []) := by
    refine .node (.Arms_plain (δ := []) pats0) ⟨empty_context,⟨trivial,lambda_input.regular.2.1,trivial⟩,?_,rs,by simp [LegacyNodeLocal]⟩ ?_
    · exact tail.regular.2.2.1
    · intro child hc
      rcases List.mem_cons.mp hc with rfl | hc
      · exact retEmpty
      · obtain rfl := List.mem_singleton.mp hc; exact tail
  have pats1 : Benitoite.Release.AltsTy oldProgram [⟨.list [.var] (some .skip) [],[0]⟩] (.list F) [F] := by
    refine ⟨by simp,rfl,?_,?_⟩
    · intro a ha; cases ha; rfl
    · intro a ha; obtain rfl := List.mem_singleton.mp ha
      exact ⟨[F],.P_List (.cons .P_Var .nil) .nil (by intro h; cases h),.refl _,rfl⟩
  have armsInput : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.arms [] S Qempty [] [] none listArms (.list F) F E []) := by
    refine .node (.Arms_plain pats1) ⟨empty_context,⟨trivial,trivial,tail1.regular.2.1⟩,tail.regular.2.2.1,rs,by simp [LegacyNodeLocal]⟩ ?_
    intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact retFirst
    · obtain rfl := List.mem_singleton.mp hc; exact tail1
  have covered : Benitoite.Release.Exhaustive oldProgram (.list F) (Benitoite.Release.unguardedPats listArms) := by
    intro v hv
    generalize ht : (Benitoite.Release.Ty.list F) = t at hv
    cases hv with
    | list hs =>
      cases ht
      rename_i vs
      cases vs with
      | nil => exact ⟨.list [] none [],by simp [listArms,Benitoite.Release.unguardedPats],by simp [Benitoite.Release.Pat.matchVal,Benitoite.Release.Pat.matchList]⟩
      | cons v vs => exact ⟨.list [.var] (some .skip) [],by simp [listArms,Benitoite.Release.unguardedPats],by simp [Benitoite.Release.Pat.matchVal,Benitoite.Release.Pat.matchList]⟩
    | const => rename_i c; cases c <;> simp [Benitoite.Release.Const.type,Benitoite.Release.Ty.opaqueTop] at ht
    | _ => cases ht
  refine ⟨.node (.C_Match covered) ⟨empty_context,⟨list_input.regular.2.1,armsInput.regular.2.1⟩,typ,rs,by simp [LegacyNodeLocal]⟩ ?_,?_⟩
  · intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact list_input
    · obtain rfl := List.mem_singleton.mp hc; exact armsInput
  · simp [listArms,embedComp,embedVal,embedVals,embedArms,embedArm,functionValue,
      Comp.ClosedAt,Val.ClosedAt,Val.ClosedList,Arm.ClosedList,Arm.bindersOf,Pat.binders,Pat.bindersList,ListRest.binders,NamesWF]

private def listState : Benitoite.Release.State :=
  .matchRun (.list [functionValue]) listArms 0 [] Benitoite.Release.Store.empty

private theorem list_state_input : LegacyStateInput kinds oldProgram oldBuiltins builtins E listState := by
  let hk : Benitoite.Release.ContTy oldProgram oldBuiltins S none E [] F F E none := .K_Empty sub_empty (legacy_wf function_type.2.1)
  refine ⟨S,none,F,F,E,E,hk,empty_store,list_match_input,sub_empty,?_,?_,?_,?_,?_⟩
  · exact .empty (hs := sub_empty) (hw := legacy_wf function_type.2.1) ⟨empty_context,(by
        intro a ha
        have he : a = F := by simpa using ha
        subst a
        exact function_type), (by intro e he; exact rows e (by simpa using he))⟩
  · simp [listArms,functionValue,Benitoite.Release.Comp.VarsIn,Benitoite.Release.Val.VarsIn,
      Benitoite.Release.Val.VarsInList,Benitoite.Release.Arm.VarsInList,Benitoite.Release.NamesWF,Benitoite.Release.Ty.VarsInList]
  · simp [Benitoite.Release.Cont.Closed]
  · intro l c hc; cases hc
  · intro arm hi hs; simp at hi

theorem list_lambda_state (σ : PathEnv) :
    StateTyE (embedProgramWithKinds kinds oldProgram) builtins σ (embedEff E) (embedState listState) ∧
    firstAlt (embedHeldVal (.list [functionValue])) [⟨.list [.var] (some .skip) [],[0]⟩] =
      some [embedHeldVal functionValue] := by
  refine ⟨embedStateTyE kinds_wf tables list_state_input,?_⟩
  simp [firstAlt,matchVal,matchList,selectSlots,embedHeldVal,embedVal,embedVals,closeVal,closeVals]

end
end Benitoite.Release.Refinement.LegacyStateEmbeddingExamples
