import Benitoite.Release.Refinement.LegacyValueEmbedding
import Benitoite.Release.Refinement.LegacyPatternExamples
import Benitoite.Release.Refinement.LegacyTableFacts

namespace Benitoite.Release.Refinement
noncomputable section

namespace LegacyEmbeddingExamples
open LegacyPatternExamples

private theorem empty_context : LegacyNodeContext kinds oldProgram [] Benitoite.Release.StoreTy.empty [] [] := by
  refine ⟨rfl,rfl,rfl,?_,?_⟩
  · intro l lt h; cases h
  · intro i a h; simp at h

private theorem unit_regular : LegacyNodeRegular kinds oldProgram oldBuiltins builtins
    (.value [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] [] (.const .unit) (.base .unit)) := by
  refine ⟨empty_context,trivial,trivial,?_⟩
  intro a ha
  obtain rfl := List.mem_singleton.mp ha
  exact ⟨trivial,trivial,trivial,trivial,trivial⟩

theorem unit_input : LegacyOutputInput kinds oldProgram oldBuiltins builtins
    (.value [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] [] (.const .unit) (.base .unit)) :=
  .node .V_Const unit_regular (by simp)

theorem unit_from_induction : ∀ Φ, HasTypeVQ (embedProgramWithKinds kinds oldProgram) builtins
    (embedStoreTy Benitoite.Release.StoreTy.empty) Benitoite.Release.Qempty [] [] Φ (.const .unit) (.base .unit) :=
  unit_input.embed_constants

theorem unit_from_value_rule : ∀ Φ, HasTypeVQ (embedProgramWithKinds kinds oldProgram) builtins
    (embedStoreTy Benitoite.Release.StoreTy.empty) Benitoite.Release.Qempty [] [] Φ (.const .unit) (.base .unit) :=
  LegacyRule.embed_value .V_Const kinds_wf tables unit_regular (by simp)

theorem list_from_value_rule : ∀ Φ, HasTypeVQ (embedProgramWithKinds kinds oldProgram) builtins
    (embedStoreTy Benitoite.Release.StoreTy.empty) Benitoite.Release.Qempty [] [] Φ
    (.list [.const .unit]) (.list (.base .unit)) := by
  have reg : LegacyNodeRegular kinds oldProgram oldBuiltins builtins
      (.value [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] []
        (.list [.const .unit]) (.list (.base .unit))) := by
    refine ⟨empty_context,⟨trivial,trivial⟩,trivial,?_⟩
    intro a ha
    obtain rfl := List.mem_singleton.mp ha
    exact ⟨trivial,trivial,trivial,trivial,trivial⟩
  apply LegacyRule.embed_value (.V_List (C := []) (a := .base .unit) trivial) kinds_wf tables reg
  intro child hc
  obtain rfl := List.mem_singleton.mp hc
  intro Φ
  exact .cons (unit_from_value_rule Φ)  .nil

theorem operation_from_value_rule : ∀ Φ, HasTypeVQ (embedProgramWithKinds kinds oldProgram) builtins
    (embedStoreTy Benitoite.Release.StoreTy.empty) Benitoite.Release.Qempty [] [] Φ
    (.op "unitOp" []) (embedTy (Benitoite.Release.fnTy [] [] (.base .unit)
      (Benitoite.Release.Eff.single "UnitEffect") [] [])) := by
  have source : LegacyTypeInput kinds oldProgram ⟨[],[],0,0⟩
      (.fn [] [] (.base .unit) (Benitoite.Release.Eff.single "UnitEffect")) .value := by
    unfold LegacyTypeInput
    rw [show embedTy (.fn [] [] (.base .unit) (Benitoite.Release.Eff.single "UnitEffect")) =
      .fn [] [] (.base .unit) (Eff.single "UnitEffect") from
        congrArg (Ty.fn [] [] (.base .unit)) (legacy_single "UnitEffect")]
    simp [Ty.HasKind,kindsList,kindsEff,Ty.WF,NamesWF,Ty.WFList,Eff.WF,Eff.Canonical,
      Eff.norm,Eff.single,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
      declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped]
    trivial
  have reg : LegacyNodeRegular kinds oldProgram oldBuiltins builtins
      (.value [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] []
        (.op "unitOp" []) (Benitoite.Release.fnTy [] [] (.base .unit)
          (Benitoite.Release.Eff.single "UnitEffect") [] [])) := by
    refine ⟨empty_context,⟨unitOperation,by simp [oldProgram],source,?_⟩,trivial,?_⟩
    · exact ⟨rfl,by simp⟩
    · intro a ha
      obtain rfl := List.mem_singleton.mp ha
      have eq : Benitoite.Release.fnTy [] [] (.base .unit)
          (Benitoite.Release.Eff.single "UnitEffect") [] [] =
          .fn [] [] (.base .unit) (Benitoite.Release.Eff.single "UnitEffect") := by
        simp [Benitoite.Release.fnTy,Benitoite.Release.Ty.subst,Benitoite.Release.Ty.substAt,
          Benitoite.Release.Eff.single,Benitoite.Release.Eff.ofAtoms]
      rw [eq]
      exact source
  apply LegacyRule.embed_value
    (.V_Op (od := unitOperation) (by simp [oldProgram]) ⟨rfl,by simp [unitOperation]⟩
      (by simp [Benitoite.Release.SatAll,unitOperation]))
    kinds_wf tables reg
  simp

theorem local_let : HasTypeCQ (embedProgramWithKinds kinds oldProgram) builtins StoreTy.empty
    Benitoite.Release.Qempty [] [] [] none
    (.letIn (.ret (.const .unit)) (.ret (.var 0))) (.base .unit) Eff.empty [] := by
  apply HasTypeCQ.C_Let (b := .base .unit) (.C_Return (.V_Const (c := .unit) trivial)) _ trivial
  exact legacy_local_zero (n := 1) (L := []) (.C_Return (.V_Var rfl (by intro b t e h; cases h)))

private theorem unit_alts : Benitoite.Release.AltsTy oldProgram [⟨.var,[0]⟩] (.base .unit) [.base .unit] := by
  refine ⟨by simp,rfl,?_,?_⟩
  · intro alt h; cases h; rfl
  · intro alt h
    obtain rfl := List.mem_singleton.mp h
    exact ⟨_,.P_Var,.refl _,rfl⟩

theorem local_arm : HasTypeArmsQ (embedProgramWithKinds kinds oldProgram) builtins StoreTy.empty
    Benitoite.Release.Qempty [] [] [] none none
    [.mk [⟨.var,[0]⟩] none (.ret (.var 0))] (.base .unit) (.base .unit) Eff.empty [] := by
  apply HasTypeArmsQ.plainEmpty (embedAltsTy tables unit_alts) (by simp [FactsWF,pathFacts]) _
    (.nil (C := []) (Γ := []) (b := .base .unit) ⟨trivial,trivial,trivial⟩)
  exact legacy_local_zero (n := 1) (L := []) (.C_Return (.V_Var rfl (by intro b t e h; cases h)))

theorem nonempty_local_bound : LocalRef.HasKind StoreTy.empty
    (localExtend 2 [some .string]) (.bound 2) .string := by
  apply LocalRef.HasKind.local_zero
    (L := (Benitoite.Release.LocalCtx.extend 2 [some .string]).map (Option.map embedBuilderKind))
    (.bound rfl)
  exact legacy_local_shift 2 [some .string]

private theorem child_context : LegacyNodeContext kinds oldProgram [] Benitoite.Release.StoreTy.empty []
    (Benitoite.Release.binds [.base .integer] ++ []) := by
  refine ⟨rfl,rfl,rfl,?_,?_⟩
  · intro l lt h; cases h
  · intro i a h
    cases i with
    | zero =>
      cases h
      exact ⟨⟨trivial,trivial,trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩⟩
    | succ i => simp [Benitoite.Release.binds] at h

theorem bindings_from_child : LegacyNodeTypes kinds oldProgram [] [] 0 [.base .integer] ∧
    PatTy (embedProgramWithKinds kinds oldProgram) .var (.base .integer) [.base .integer] :=
  ⟨child_context.bindings 0,embedPatTy tables (.P_Var (a := .base .integer))⟩

theorem at_shape : ResultShape.StandardError (embedProgramWithKinds kinds oldProgram)
    ⟨"Result","Ok","Error",atErrorType⟩ := by
  have lookup : oldProgram.cons "Scope.ScopeError.At" = some atDecl := rfl
  exact ⟨rfl,tables.dataArity lookup,⟨embedConDecl atDecl,
    by simp only [embedProgramWithKinds_cons,lookup,Option.map_some],rfl,rfl,rfl⟩,embedded_public⟩

theorem at_legacy_inhabits (detail : AtError) : Benitoite.Release.Inhabits oldProgram
    (.data "Scope.ScopeError" []) (legacyPatternVal (.atError detail)) :=
  legacy_inhabits (nt := 0) tables (.atError at_shape) _ rfl trivial

private theorem var_patterns (P0 : Benitoite.Release.Program) (a : Benitoite.Release.Ty) (n : Nat) :
    Benitoite.Release.PatTys P0 (List.replicate n .var) (List.replicate n a) (List.replicate n a) := by
  induction n with
  | zero => exact .nil
  | succ n ih => simpa only [List.replicate_succ,List.singleton_append] using
      Benitoite.Release.PatTys.cons (.P_Var (a := a)) ih

theorem at_pattern_typed : PatTy (embedProgramWithKinds kinds oldProgram) atPattern atErrorType
    (embedTys [.data "Scope.AtDetail" []]) := by
  change PatTy _ atPattern (embedTy (.data "Scope.ScopeError" [])) _
  apply embedPatTy tables
  exact .P_Con (c := "Scope.ScopeError.At") (cd := atDecl) (ts := [])
    rfl rfl (var_patterns oldProgram (.data "Scope.AtDetail" []) 1)

theorem at_type_argument_rejected : ¬ LegacyNodeTypes kinds oldProgram [] [] 0
    [.data "Scope.ScopeError" [.base .unit]] := by
  intro h
  have bad := (h _ (List.mem_cons_self)).1.1
  have good := TyCon.arity_data at_shape.2.1
  rw [good] at bad
  cases bad

theorem nested_at_correspondence (detail : AtError) :
    Benitoite.Release.Pat.matchVal (.list [atPattern] none [])
        (legacyPatternVal (.list [.atError detail])) =
      (matchVal (.list [atPattern] none []) (.list [.atError detail])).map legacyPatternVals :=
  legacy_matchVal _ _

theorem match_node_coverage :
    LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] [] none
        (.match (.const .unit) [.mk [⟨.wild,[]⟩] none (.ret (.const .unit))])
        (.base .unit) Benitoite.Release.Eff.empty []) ∧
    Exhaustive (embedProgramWithKinds kinds oldProgram) (.base .unit) [.wild] := by
  let arms : List Benitoite.Release.Arm := [.mk [⟨.wild,[]⟩] none (.ret (.const .unit))]
  have coverage : Benitoite.Release.Exhaustive oldProgram (.base .unit)
      (Benitoite.Release.unguardedPats arms) := by
    intro v _
    exact ⟨.wild,by simp [arms,Benitoite.Release.unguardedPats],rfl⟩
  have types : LegacyNodeTypes kinds oldProgram [] [] 0 [.base .unit] := unit_regular.2.2.2
  have rows : LegacyRowsInput kinds oldProgram ⟨[],[],0,0⟩ [Benitoite.Release.Eff.empty] := by
    intro e he
    obtain rfl := List.mem_singleton.mp he
    simp [LegacyTypeInput,embedTy,embedEff,Benitoite.Release.Eff.empty,
      Ty.HasKind,kindsList,kindsEff,Ty.WF,NamesWF,Ty.WFList,Eff.WF,Eff.Canonical,Eff.norm,
      Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,declaredEff,
      Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped,embedAtoms]
    intro name ix h
    cases he : (Atom.name name ix).toOld? <;> simp [he] at h

  have retReg : LegacyNodeRegular kinds oldProgram oldBuiltins builtins
      (.comp [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] [] none
        (.ret (.const .unit)) (.base .unit) Benitoite.Release.Eff.empty []) :=
    ⟨empty_context,trivial,types,rows,by simp [LegacyNodeLocal]⟩
  have retInput : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.comp [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] [] none
        (.ret (.const .unit)) (.base .unit) Benitoite.Release.Eff.empty []) := by
    apply LegacyOutputInput.node .C_Return retReg
    intro child hc
    obtain rfl := List.mem_singleton.mp hc
    exact unit_input
  have armTypes : LegacyNodeTypes kinds oldProgram [] [] 0 [.base .unit,.base .unit] := by
    intro a ha
    rcases List.mem_cons.mp ha with rfl | ha
    · exact types _ (List.mem_cons_self)
    · exact types a ha
  have armsReg : ∀ xs, LegacyArmsInput kinds oldProgram oldBuiltins builtins ⟨[],[],0,0⟩ xs →
      LegacyNodeRegular kinds oldProgram oldBuiltins builtins
        (.arms [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] [] none xs
          (.base .unit) (.base .unit) Benitoite.Release.Eff.empty []) := by
    intro xs h
    exact ⟨empty_context,h,armTypes,rows,by simp [LegacyNodeLocal]⟩
  have alts : Benitoite.Release.AltsTy oldProgram [⟨.wild,[]⟩] (.base .unit) [] := by
    refine ⟨by simp,rfl,?_,?_⟩
    · intro alt h; cases h; rfl
    · intro alt h
      obtain rfl := List.mem_singleton.mp h
      exact ⟨_,.P_Wild,.refl _,rfl⟩
  have armsInput : LegacyOutputInput kinds oldProgram oldBuiltins builtins
      (.arms [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] [] none arms
        (.base .unit) (.base .unit) Benitoite.Release.Eff.empty []) := by
    apply LegacyOutputInput.node (.Arms_plain alts) (armsReg arms ⟨trivial,trivial,trivial⟩)
    intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact retInput
    · obtain rfl := List.mem_singleton.mp hc
      exact .node (.Arms_nil trivial) (armsReg [] trivial) (by simp)
  have children : ∀ child ∈ [
      LegacyJudgment.value [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] []
        (.const .unit) (.base .unit),
      .arms [] Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty [] [] none arms
        (.base .unit) (.base .unit) Benitoite.Release.Eff.empty []],
      LegacyOutputInput kinds oldProgram oldBuiltins builtins child := by
    intro child hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact unit_input
    · obtain rfl := List.mem_singleton.mp hc
      exact armsInput
  refine ⟨.node (.C_Match coverage)
    ⟨empty_context,⟨trivial,trivial,trivial,trivial⟩,types,rows,by simp [LegacyNodeLocal]⟩ children,?_⟩
  have scrutinee := children _ (List.mem_cons_self)
  have wf : Benitoite.Release.Ty.WF 0 0 (.base .unit) :=
    legacy_wf (scrutinee.regular.2.2.2 _ (List.mem_cons_self)).2.1
  simpa only [embedTy,arms,Benitoite.Release.unguardedPats,List.map_cons,List.map_nil,
    List.append_nil,List.cons_append] using embedExhaustive tables wf coverage

end LegacyEmbeddingExamples

end
end Benitoite.Release.Refinement
