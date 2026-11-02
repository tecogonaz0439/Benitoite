import Benitoite.Release.Refinement.LegacyProgramTyping
import Benitoite.Release.Refinement.LegacyPatternExamples

namespace Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples
noncomputable section
open LegacyPatternExamples (kinds oldBuiltins builtins)

private abbrev U : Benitoite.Release.Ty := .base .unit
private abbrev E : Benitoite.Release.Eff := .empty
private def declaration : Benitoite.Release.Def := ⟨[],0,["x"],[U],U,E,.ret (.var 0)⟩
private def program : Benitoite.Release.Program :=
  ⟨fun f => if f = "identity" then some declaration else none,fun _ => none,fun _ => none,
    fun _ => none,fun _ => none,fun _ => none⟩

private theorem lookup : program.defs "identity" = some declaration := by simp [program]
private theorem only_function {f d} (h : program.defs f = some d) : d = declaration := by
  simp only [program] at h
  split at h <;> cases h
  rfl

private theorem kinds_valid : kinds.WF program := by
  constructor
  · intro f d hd; obtain rfl := only_function hd; rfl
  · intro cl cd m ms hc hm; cases hc

private theorem tables : LegacyTables kinds program oldBuiltins builtins := by
  constructor
  · intro b s hs; cases hs
  · intro C a p h; trivial
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · intro o; rfl
  · intro b rs h; cases h
  · intro c cd c' cd' hc hc' h; cases hc
  · intro c cd hc; cases hc
  · intro c cd hc; cases hc

private theorem unit_type (n : Nat) : LegacyTypeInput kinds program ⟨[],[],0,n⟩ U .value :=
  ⟨trivial,trivial,trivial,trivial,trivial⟩

private theorem function_type : LegacyTypeInput kinds program .closed (.fn ["x"] [U] U E) .value := by
  unfold LegacyTypeInput
  rw [show embedTy (.fn ["x"] [U] U E) = .fn ["x"] [.base .unit] (.base .unit) Eff.empty from
    congrArg (Ty.fn ["x"] [.base .unit] (.base .unit)) legacy_empty]
  simp [Ty.HasKind,NamesWF,kindsList,kindsEff,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,
    Eff.empty,Eff.norm,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
    declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped,LegacyInputCtx.closed]

private theorem body_input : functionBodyInput kinds program oldBuiltins builtins "identity" declaration := by
  unfold functionBodyInput declaration
  have ctx : LegacyNodeContext kinds program [] Benitoite.Release.StoreTy.empty [] [some U] := by
    refine ⟨rfl,rfl,rfl,?_,?_⟩
    · intro l x hl; cases hl
    · intro i a hi
      cases i with
      | zero => cases hi; exact ⟨unit_type 1,⟨trivial,trivial,trivial⟩⟩
      | succ i => simp at hi
  have rows : LegacyRowsInput kinds program ⟨[],[],0,1⟩ [E] := by
    intro e he; obtain rfl := List.mem_singleton.mp he
    unfold LegacyTypeInput
    rw [show embedTy (.fn [] [] U E) = .fn [] [] (.base .unit) Eff.empty from
      congrArg (Ty.fn [] [] (.base .unit)) legacy_empty]
    exact ⟨⟨⟨rfl,by simp⟩,trivial,trivial,trivial⟩,⟨⟨rfl,by simp⟩,trivial,trivial,trivial,rfl⟩,
      ⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩,⟨trivial,by simp [Eff.RangesScoped,Eff.empty,rangesScopedTypes,Ty.RangesScoped]⟩⟩
  have types : LegacyNodeTypes kinds program [] [] 1 [U] := by
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type 1
  have value : LegacyOutputInput kinds program oldBuiltins builtins
      (.value [] Benitoite.Release.StoreTy.empty (Benitoite.Release.Qsig [U] U E) [] [some U] (.var 0) U) :=
    .node (.V_Var rfl (by intro b t e he; cases he)) ⟨ctx,trivial,trivial,types⟩ (by simp)
  refine .node .C_Return ⟨ctx,trivial,?_,rows,by simp [LegacyNodeLocal]⟩ ?_
  · intro a ha
    have h : a = U := by simpa using ha
    subst a; exact unit_type 1
  · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact value

private theorem inputs : LegacyDeclarationInputs kinds program oldBuiltins builtins := by
  constructor
  · refine ⟨?_,?_,?_,?_⟩
    · intro f d hd; obtain rfl := only_function hd
      exact ⟨function_type,trivial⟩
    · intro o od ho; cases ho
    · intro cl cd m ms hc hm; cases hc
    · intro i id hi; cases hi
  · refine ⟨?_,?_,?_⟩
    · intro f d hd; obtain rfl := only_function hd
      exact body_input
    · intro i id cd m ms body hi; cases hi
    · intro i id cd s value hi; cases hi
  · intro f d hd; obtain rfl := only_function hd
    simp [declaration,embedComp,embedVal,Comp.SourceScoped,Val.SourceScoped]
  · intro i id cd m ms body hi; cases hi
  · intro i id s value hi; cases hi

private theorem old_typed : Benitoite.Release.Program.WellTyped program oldBuiltins := by
  constructor
  · intro f d hd; obtain rfl := only_function hd
    exact ⟨by simp [declaration,Benitoite.Release.NamesWF],body_input.old⟩
  · intro i id hi; cases hi

private theorem old_scoped : Benitoite.Release.Program.WellFormed program := by
  refine ⟨?_,?_,?_,?_,?_⟩
  · intro f d hd; obtain rfl := only_function hd
    simp [Benitoite.Release.Def.Scoped,declaration,U,E,Benitoite.Release.NamesWF,
      Benitoite.Release.Ty.VarsInList,Benitoite.Release.Ty.VarsIn,Benitoite.Release.Eff.VarsIn,
      Benitoite.Release.Eff.empty,Benitoite.Release.Comp.VarsIn,Benitoite.Release.Val.VarsIn]
  · intro c cd hc; cases hc
  · intro o od ho; cases ho
  · intro cl cd hc; cases hc
  · intro i id hi; cases hi

theorem function_embedded : Def.WellTyped (embedProgramWithKinds kinds program) builtins (embedDefWithKinds [] declaration) :=
  embedDefWellTyped kinds_valid tables inputs.declarations lookup body_input

theorem program_embedded : Program.WellTyped (embedProgramWithKinds kinds program) builtins :=
  embedProgramWellTyped kinds_valid tables inputs old_typed

theorem program_well_formed : Program.WellFormed (embedProgramWithKinds kinds program) :=
  embedProgramWellFormed kinds_valid tables inputs old_scoped

end
end Benitoite.Release.Refinement.LegacyProgramEmbeddingExamples
