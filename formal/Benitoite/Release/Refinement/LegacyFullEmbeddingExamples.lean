import Benitoite.Release.Refinement.LegacyAdequate
import Benitoite.Release.Refinement.LegacyEmbeddingExamples

namespace Benitoite.Release.Refinement.LegacyFullEmbeddingExamples
noncomputable section
open LegacyPatternExamples

private abbrev U : Benitoite.Release.Ty := .base .unit
private abbrev E : Benitoite.Release.Eff := .empty
private abbrev S : Benitoite.Release.StoreTy := .empty

private theorem unit_type (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat) :
    LegacyTypeInput kinds oldProgram ⟨κ,C,0,nv⟩ U .value :=
  ⟨trivial,trivial,trivial,trivial,trivial⟩

private theorem context (κ : KindCtx) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) (count : κ.length = C.length)
    (hΓ : ∀ (i : Nat) a, Γ[i]? = some (some a) → a = U) :
    LegacyNodeContext kinds oldProgram κ S C Γ := by
  refine ⟨rfl,rfl,count,?_,?_⟩
  · intro l lt hl; cases hl
  · intro i a hi
    have ha := hΓ i a hi
    subst a
    exact ⟨unit_type κ C Γ.length,⟨trivial,trivial,trivial⟩⟩

private theorem rows (κ : KindCtx) (C : List Benitoite.Release.TParam) (nv : Nat) :
    LegacyRowsInput kinds oldProgram ⟨κ,C,0,nv⟩ [E] := by
  intro e he
  obtain rfl := List.mem_singleton.mp he
  unfold LegacyTypeInput
  rw [show embedTy (.fn [] [] (.base .unit) E) = .fn [] [] (.base .unit) Eff.empty from
    congrArg (Ty.fn [] [] (.base .unit)) legacy_empty]
  simp [Ty.HasKind,kindsList,kindsEff,NamesWF,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,
    Eff.empty,Eff.norm,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
    declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped]

private theorem ret_input (κ : KindCtx) (C : List Benitoite.Release.TParam)
    (Γ : List (Option Benitoite.Release.Ty)) (count : κ.length = C.length)
    (hΓ : ∀ (i : Nat) a, Γ[i]? = some (some a) → a = U) :
    LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp κ S Benitoite.Release.Qempty C Γ none (.ret (.const .unit)) U E []) := by
  have ctx := context κ C Γ count hΓ
  have value : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.value κ S Benitoite.Release.Qempty C Γ (.const .unit) U) := by
    exact .node .V_Const ⟨ctx,trivial,trivial,by
      intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type κ C Γ.length⟩ (by simp)
  refine .node .C_Return ⟨ctx,trivial,?_,rows κ C Γ.length,by simp [LegacyNodeLocal]⟩ ?_
  · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type κ C Γ.length
  · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact value

private theorem values_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.values [] S Benitoite.Release.Qempty [] [] [.const .unit] [U]) := by
  have ctx := context [] [] [] rfl (by simp)
  refine .node .Vs_cons ⟨ctx,⟨trivial,trivial⟩,?_⟩ ?_
  · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 0
  · intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact LegacyEmbeddingExamples.unit_input
    · obtain rfl := List.mem_singleton.mp hc
      exact .node .Vs_nil ⟨ctx,trivial,by simp [LegacyNodeTypes]⟩ (by simp)

private theorem each_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.each [] S Benitoite.Release.Qempty [] [] [.const .unit] U) := by
  have ctx := context [] [] [] rfl (by simp)
  have types : LegacyNodeTypes kinds oldProgram [] [] 0 [U] := by
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 0
  refine .node .Each_cons ⟨ctx,⟨trivial,trivial⟩,types⟩ ?_
  intro child hc
  rcases List.mem_cons.mp hc with rfl | hc
  · exact LegacyEmbeddingExamples.unit_input
  · obtain rfl := List.mem_singleton.mp hc
    exact .node .Each_nil ⟨ctx,trivial,types⟩ (by simp)

private theorem arms_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.arms [] S Benitoite.Release.Qempty [] [] none [] U U E []) := by
  refine .node (.Arms_nil trivial) ⟨context [] [] [] rfl (by simp),trivial,?_,rows [] [] 0,by simp [LegacyNodeLocal]⟩ (by simp)
  intro a ha
  have ha' : a = U := by simpa using ha
  subst a
  exact unit_type [] [] 0

private theorem clauses_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.clauses [] S Benitoite.Release.Qempty [] [] none E [] U E []) := by
  refine .node .Clauses_nil ⟨context [] [] [] rfl (by simp),trivial,?_,?_,by simp [LegacyNodeLocal]⟩ (by simp)
  · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 0
  · intro e he
    exact rows [] [] 0 e (by simpa using he)

private theorem failure_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.failure [] S Benitoite.Release.Qempty [] [] U none [.fail U (.ret (.const .unit))] U E []) := by
  have body := ret_input [.value] [({} : Benitoite.Release.TParam)] [none,some U] rfl
    (by intro i a hi; cases i with
        | zero => cases hi
        | succ i => cases i <;> simp_all)
  have shiftE : Benitoite.Release.Eff.shift 1 0 E = E := by
    simp [Benitoite.Release.Eff.shift,Benitoite.Release.Eff.rawShift,E,
      Benitoite.Release.Eff.empty,Benitoite.Release.Eff.norm,Benitoite.Release.Ty.rawShiftTys,
      Benitoite.Release.Ty.normTys]
  refine .node (.Failure_one trivial trivial trivial)
    ⟨context [] [] [] rfl (by simp),?_,?_,rows [] [] 0,by simp [LegacyNodeLocal]⟩ ?_
  · exact ⟨unit_type [] [] 0,trivial,trivial⟩
  · intro a ha
    have ha' : a = U := by simpa using ha
    subst a; exact unit_type [] [] 0
  · intro child hc; obtain rfl := List.mem_singleton.mp hc
    have hs : S.hideBuilders = S := by funext l; rfl
    simpa only [hs,Benitoite.Release.Ty.shift,Option.map_none,Benitoite.Release.shiftEnv,List.map_nil,shiftE] using body

theorem seven_empty_entries :
    HasTypeVQ (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Benitoite.Release.Qempty [] [] [] (.const .unit) (.base .unit) ∧
    HasTypeVsQ (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Benitoite.Release.Qempty [] [] [] [.const .unit] [.base .unit] ∧
    HasTypeEachQ (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Benitoite.Release.Qempty [] [] [] [.const .unit] (.base .unit) ∧
    HasTypeCQ (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Benitoite.Release.Qempty [] [] [] none (.ret (.const .unit)) (.base .unit) (embedEff E) [] ∧
    HasTypeArmsQ (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Benitoite.Release.Qempty [] [] [] none none [] (.base .unit) (.base .unit) (embedEff E) [] ∧
    HasTypeClausesQ (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Benitoite.Release.Qempty [] [] [] none (embedEff E) [] (.base .unit) (embedEff E) [] ∧
    HasFailureClause (embedProgramWithKinds kinds oldProgram) builtins (embedStoreTy S) Benitoite.Release.Qempty [] [] [] (.base .unit) none
      [.fail (.base .unit) (.ret (.const .unit))] (.base .unit) (embedEff E) [] :=
  ⟨embedHasTypeVQ_empty kinds [] kinds_wf tables LegacyEmbeddingExamples.unit_input,
    embedHasTypeVsQ_empty kinds [] kinds_wf tables values_input,
    embedHasTypeEachQ_empty kinds [] kinds_wf tables each_input,
    embedHasTypeCQ_empty kinds [] kinds_wf tables (ret_input [] [] [] rfl (by simp)),
    embedHasTypeArmsQ_empty kinds [] kinds_wf tables arms_input,
    embedHasTypeClausesQ_empty kinds [] kinds_wf tables clauses_input,
    embedHasFailureClause_empty kinds [] kinds_wf tables failure_input⟩

theorem match_with_truth : HasTypeCQ (embedProgramWithKinds kinds oldProgram) builtins
    (embedStoreTy S) Benitoite.Release.Qempty [] [] [.truth] none
    (.match (.const .unit) [.mk [⟨.wild,[]⟩] none (.ret (.const .unit))]) (.base .unit) (embedEff E) [] :=
  embedHasTypeCQ kinds [] kinds_wf tables LegacyEmbeddingExamples.match_node_coverage.1 [.truth]

theorem if_true_embedded (Φ : List Pred) : HasTypeCQ (embedProgramWithKinds kinds oldProgram) builtins
    (embedStoreTy S) Benitoite.Release.Qempty [] [] Φ none
    (.ite (.const (.boolean true)) (.ret (.const .unit)) (.ret (.const .unit)))
    (.base .unit) (embedEff E) [] := by
  have ctx := context [] [] [] rfl (by simp)
  have boolean : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.value [] S Benitoite.Release.Qempty [] [] (.const (.boolean true)) (.base .boolean)) := by
    refine .node .V_Const ⟨ctx,trivial,trivial,?_⟩ (by simp)
    intro a ha
    obtain rfl := List.mem_singleton.mp ha
    exact ⟨trivial,trivial,trivial,trivial,trivial⟩
  have ret := ret_input [] [] [] rfl (by simp)
  have input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp [] S Benitoite.Release.Qempty [] [] none
        (.ite (.const (.boolean true)) (.ret (.const .unit)) (.ret (.const .unit))) U E []) := by
    refine .node .C_If ⟨ctx,⟨trivial,trivial,trivial⟩,?_,rows [] [] 0,by simp [LegacyNodeLocal]⟩ ?_
    · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 0
    · intro child hc
      simp only [List.mem_cons,List.not_mem_nil,or_false] at hc
      rcases hc with rfl | rfl | rfl
      · exact boolean
      · exact ret
      · exact ret
  exact embedHasTypeCQ kinds [] kinds_wf tables input Φ

theorem unit_operation_clause_embedded (Φ : List Pred) :
    HasTypeClausesQ (embedProgramWithKinds kinds oldProgram) builtins
      (embedStoreTy S) Benitoite.Release.Qempty [] [] Φ none
      (embedEff (Benitoite.Release.Eff.single "UnitEffect"))
      [.mk (.user "unitOp") 0 0 (.ret (.const .unit))] (.base .unit) (embedEff E) [] := by
  let sg : Benitoite.Release.OpSig := ⟨[],[],[],U,"UnitEffect"⟩
  have lookup : Benitoite.Release.opSig oldProgram oldBuiltins (.user "unitOp") = some sg := by
    simp [Benitoite.Release.opSig,oldProgram,unitOperation,sg]
  have signature : Benitoite.Release.ClauseSig oldProgram oldBuiltins
      (Benitoite.Release.Eff.single "UnitEffect") (.user "unitOp") sg :=
    ⟨.top,Or.inl rfl,by simpa only [Benitoite.Release.opSigAt_top] using lookup⟩
  have source : LegacyTypeInput kinds oldProgram ⟨[],[],0,0⟩
      (.fn [] [] U (Benitoite.Release.Eff.single "UnitEffect")) .value := by
    unfold LegacyTypeInput
    rw [show embedTy (.fn [] [] U (Benitoite.Release.Eff.single "UnitEffect")) =
      .fn [] [] (.base .unit) (Eff.single "UnitEffect") from
      congrArg (Ty.fn [] [] (.base .unit)) (legacy_single "UnitEffect")]
    simp [Ty.HasKind,kindsList,kindsEff,Ty.WF,NamesWF,Ty.WFList,Eff.WF,Eff.Canonical,
      Eff.norm,Eff.single,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
      declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped]
    trivial
  have continuation : LegacyTypeInput kinds oldProgram ⟨[],[],0,1⟩ (.cont U U E) .value := by
    simp [LegacyTypeInput,embedTy,legacy_empty,Ty.HasKind,kindsList,kindsEff,Ty.WF,Ty.WFList,sortedTys,declaredTys,Eff.WF,Eff.Canonical,
      Eff.empty,Eff.norm,Ty.normTys,Ty.Sorted,sortedEff,Ty.Declared,declaredEff,
      Ty.RangesScoped,Eff.RangesScoped,rangesScopedTypes]
  have ctx := context [] [] [] rfl (by simp)
  have bodyCtx : LegacyNodeContext kinds oldProgram [] S [] [some (.cont U U E)] := by
    refine ⟨rfl,rfl,rfl,?_,?_⟩
    · intro l lt hl; cases hl
    · intro i a hi
      cases i with
      | zero =>
        cases Option.some.inj (Option.some.inj hi)
        exact ⟨continuation,continuation.annotation_at rfl rfl _⟩
      | succ i => simp at hi
  have bodyValue : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.value [] S Benitoite.Release.Qempty [] [some (.cont U U E)] (.const .unit) U) := by
    refine .node .V_Const ⟨bodyCtx,trivial,trivial,?_⟩ (by simp)
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 1
  have body : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp [] S Benitoite.Release.Qempty [] [some (.cont U U E)] none (.ret (.const .unit)) U E []) := by
    refine .node .C_Return ⟨bodyCtx,trivial,?_,rows [] [] 1,by simp [LegacyNodeLocal]⟩ ?_
    · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 1
    · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact bodyValue
  have rowInputs : LegacyRowsInput kinds oldProgram ⟨[],[],0,0⟩
      [Benitoite.Release.Eff.single "UnitEffect",E] := by
    intro e he
    rcases List.mem_cons.mp he with rfl | he
    · exact source
    · exact rows [] [] 0 e he
  have regular : ∀ cs, LegacyClausesInput kinds oldProgram oldBuiltins builtins ⟨[],[],0,0⟩ cs →
      LegacyNodeRegular kinds oldProgram oldBuiltins builtins
        (.clauses [] S Benitoite.Release.Qempty [] [] none
          (Benitoite.Release.Eff.single "UnitEffect") cs U E []) := by
    intro cs input
    refine ⟨ctx,input,?_,rowInputs,by simp [LegacyNodeLocal]⟩
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type [] [] 0
  have input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.clauses [] S Benitoite.Release.Qempty [] [] none
        (Benitoite.Release.Eff.single "UnitEffect") [.mk (.user "unitOp") 0 0 (.ret (.const .unit))] U E []) := by
    refine .node (.Clauses_cons signature (by simp [sg,Benitoite.Release.NamesWF]) rfl rfl trivial)
      (regular _ ⟨⟨sg,lookup,rfl,rfl,source,trivial⟩,trivial⟩) ?_
    intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · have hs : S.hideBuilders = S := by funext l; rfl
      have he : Benitoite.Release.Eff.shift 0 0 E = E := by
        simp [Benitoite.Release.Eff.shift,Benitoite.Release.Eff.rawShift,E,
          Benitoite.Release.Eff.empty,Benitoite.Release.Eff.norm,Benitoite.Release.Ty.rawShiftTys,
          Benitoite.Release.Ty.normTys]
      simpa only [sg,List.length_nil,List.replicate_zero,List.nil_append,List.append_nil,
        hs,Option.map_none,Benitoite.Release.Ty.shift,he,Benitoite.Release.binds,List.reverse_nil,
        List.map_nil,Benitoite.Release.shiftEnv] using body
    · obtain rfl := List.mem_singleton.mp hc
      exact .node .Clauses_nil (regular [] trivial) (by simp)
  exact embedHasTypeClausesQ kinds [] kinds_wf tables input Φ

private theorem empty_store : LegacyStoreInput kinds oldProgram oldBuiltins builtins S Benitoite.Release.Store.empty := by
  refine ⟨⟨⟨0,by intro l _; rfl⟩,?_,?_,?_⟩,context [] [] [] rfl (by simp),?_⟩
  all_goals intro l c hc <;> cases hc

private theorem empty_cont_regular : LegacyContRegular kinds oldProgram S none E U U E none := by
  refine ⟨context [] [] [] rfl (by simp),?_,?_⟩
  · intro a ha
    have ha' : a = U := by simpa using ha
    subst a; exact unit_type [] [] 0
  · intro e he; exact rows [] [] 0 e (by simpa using he)

private theorem empty_sub : Benitoite.Release.Eff.Sub E E := ⟨fun _ h => h,fun _ h => h⟩

theorem run_input : LegacyStateInput kinds oldProgram oldBuiltins builtins E
    (.run (.ret (.const .unit)) [] Benitoite.Release.Store.empty) := by
  let hk : Benitoite.Release.ContTy oldProgram oldBuiltins S none E [] U U E none :=
    .K_Empty empty_sub trivial
  refine ⟨S,none,U,U,E,E,hk,empty_store,?_,empty_sub,?_,trivial,by simp [Benitoite.Release.Cont.Closed],?_⟩
  · exact ⟨ret_input [] [] [] rfl (by simp),trivial⟩
  · exact LegacyContInput.empty (a := U) (R := none) (e := E) (out := E) (hs := empty_sub) (hw := trivial) empty_cont_regular
  · intro l c hc; cases hc

theorem run_inputs_used (σ : PathEnv) :
    Benitoite.Release.StateTyE oldProgram oldBuiltins E
      (.run (.ret (.const .unit)) [] Benitoite.Release.Store.empty) ∧
    (Closure.pure (embedComp (.ret (.const .unit)))).Adequate σ ∧
    (embedCont []).Adequate σ ∧ (embedStore Benitoite.Release.Store.empty).Adequate σ :=
  ⟨run_input.old,⟨trivial,legacy_comp_adequate _ σ⟩,legacy_cont_adequate _ σ,legacy_store_adequate _ σ⟩

theorem byte_rejected : ¬ LegacyStateInput kinds oldProgram oldBuiltins builtins E
    (.run (.ret (.const (.integer8 128))) [] Benitoite.Release.Store.empty) := by
  intro h
  obtain ⟨Ψ,R,a,b,e,e1,hk,store,code,rest⟩ := h
  have bad := code.1.regular.2.1
  change -128 ≤ (128 : Int) ∧ (128 : Int) ≤ 127 at bad
  omega

theorem old_byte_accepted : Benitoite.Release.HasTypeV oldProgram oldBuiltins S [] []
    (.const (.integer8 128)) (.base .integer8) := .V_Const


end
end Benitoite.Release.Refinement.LegacyFullEmbeddingExamples
