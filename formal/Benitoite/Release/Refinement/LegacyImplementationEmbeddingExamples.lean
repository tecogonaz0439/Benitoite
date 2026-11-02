import Benitoite.Release.Refinement.LegacyProgramTyping
import Benitoite.Release.Refinement.LegacyPatternExamples

namespace Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples
noncomputable section
open LegacyPatternExamples (kinds oldBuiltins builtins)

private abbrev U : Benitoite.Release.Ty := .base .unit
private abbrev E : Benitoite.Release.Eff := .empty
private def signature : Benitoite.Release.MethSig := ⟨[],0,["x"],[U],U,E⟩
private def baseClass : Benitoite.Release.ClassDecl := ⟨[],fun _ => none⟩
private def childClass : Benitoite.Release.ClassDecl :=
  ⟨["Base"],fun m => if m = "identity" then some signature else none⟩
private def baseImpl : Benitoite.Release.ImplDecl :=
  ⟨[],[],"Base",U,fun _ => none,fun _ => none⟩
private def childImpl : Benitoite.Release.ImplDecl :=
  ⟨[],[],"Child",U,fun s => if s = "Base" then some (.dict "unitBase" [] []) else none,
    fun m => if m = "identity" then some (.ret (.var 0)) else none⟩
private def program : Benitoite.Release.Program :=
  ⟨fun _ => none,fun _ => none,fun _ => none,fun _ => none,
    fun c => if c = "Base" then some baseClass else if c = "Child" then some childClass else none,
    fun i => if i = "unitBase" then some baseImpl else if i = "unitChild" then some childImpl else none⟩

private theorem only_class {c cd} (h : program.classes c = some cd) :
    (c = "Base" ∧ cd = baseClass) ∨ (c = "Child" ∧ cd = childClass) := by
  simp only [program] at h
  split at h
  · rename_i hc; exact .inl ⟨hc,Option.some.inj h.symm⟩
  · split at h
    · rename_i hc; exact .inr ⟨hc,Option.some.inj h.symm⟩
    · cases h

private theorem only_impl {i id} (h : program.impls i = some id) :
    id = baseImpl ∨ id = childImpl := by
  simp only [program] at h
  split at h
  · exact .inl (Option.some.inj h.symm)
  · split at h
    · exact .inr (Option.some.inj h.symm)
    · cases h

private theorem only_method {m ms} (h : childClass.methods m = some ms) :
    m = "identity" ∧ ms = signature := by
  simp only [childClass] at h
  split at h
  · rename_i hm; exact ⟨hm,Option.some.inj h.symm⟩
  · cases h

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

private theorem kinds_valid : kinds.WF program := by
  constructor
  · intro f d hd; cases hd
  · intro cl cd m ms hc hm
    rcases only_class hc with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · cases hm
    · obtain ⟨rfl,rfl⟩ := only_method hm; rfl

private theorem unit_type (n : Nat) : LegacyTypeInput kinds program ⟨[],[],0,n⟩ U .value :=
  ⟨trivial,trivial,trivial,trivial,trivial⟩

private theorem signature_input (Δ : LegacyInputCtx) :
    LegacyTypeInput kinds program Δ (.fn ["x"] [U] U E) .value := by
  unfold LegacyTypeInput
  rw [show embedTy (.fn ["x"] [U] U E) = .fn ["x"] [.base .unit] (.base .unit) Eff.empty from
    congrArg (Ty.fn ["x"] [.base .unit] (.base .unit)) legacy_empty]
  simp [Ty.HasKind,NamesWF,kindsList,kindsEff,Ty.WF,Ty.WFList,Eff.WF,Eff.Canonical,
    Eff.empty,Eff.norm,Ty.normTys,Ty.Sorted,sortedTys,sortedEff,Ty.Declared,declaredTys,
    declaredEff,Ty.RangesScoped,rangesScopedTypes,Eff.RangesScoped]

private theorem method_type : LegacyTypeInput kinds program ⟨[.value],[{}],0,0⟩
    (.fn ["x"] [U] U E) .value := signature_input _

private theorem method_input : methodBodyInput kinds program oldBuiltins builtins childImpl
    "identity" signature (.ret (.var 0)) := by
  unfold methodBodyInput
  simp only [signature,childImpl,Benitoite.Release.ImplDecl.dictTys,Benitoite.Release.ImplDecl.methTy,
    Benitoite.Release.Ty.substAt,Benitoite.Release.Eff.substAt_empty]
  change LegacyOutputInput kinds program oldBuiltins builtins
    (.comp [] Benitoite.Release.StoreTy.empty (Benitoite.Release.Qsig [U] U E) [] [some U]
      (some U) (.ret (.var 0)) U E [])
  have ctx : LegacyNodeContext kinds program [] Benitoite.Release.StoreTy.empty [] [some U] := by
    refine ⟨rfl,rfl,rfl,?_,?_⟩
    · intro l t h; cases h
    · intro i a hi
      cases i with
      | zero => cases hi; exact ⟨unit_type 1,⟨trivial,trivial,trivial⟩⟩
      | succ i => simp at hi
  have ts : LegacyNodeTypes kinds program [] [] 1 [U] := by
    intro a ha; obtain rfl := List.mem_singleton.mp ha; exact unit_type 1
  have rs : LegacyRowsInput kinds program ⟨[],[],0,1⟩ [E] := by
    intro e he; obtain rfl := List.mem_singleton.mp he
    unfold LegacyTypeInput
    rw [show embedTy (.fn [] [] U E) = .fn [] [] (.base .unit) Eff.empty from
      congrArg (Ty.fn [] [] (.base .unit)) legacy_empty]
    exact ⟨⟨⟨rfl,by simp⟩,trivial,trivial,trivial⟩,⟨⟨rfl,by simp⟩,trivial,trivial,trivial,rfl⟩,
      ⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩,⟨trivial,by simp [Eff.RangesScoped,Eff.empty,rangesScopedTypes,Ty.RangesScoped]⟩⟩
  have hv : LegacyOutputInput kinds program oldBuiltins builtins
      (.value [] Benitoite.Release.StoreTy.empty (Benitoite.Release.Qsig [U] U E) [] [some U] (.var 0) U) :=
    .node (.V_Var rfl (by intro b t e h; cases h)) ⟨ctx,trivial,trivial,ts⟩ (by simp)
  refine .node .C_Return ⟨ctx,trivial,?_,rs,by simp [LegacyNodeLocal]⟩ ?_
  · intro a ha
    have he : a = U := by simpa using ha
    subst a; exact unit_type 1
  · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact hv

private theorem dictionary_type : LegacyTypeInput kinds program .closed (.dict "Base" U) .value := by
  refine ⟨?_,trivial,trivial,trivial,trivial⟩
  exact embed_dictionary_kind (cd := baseClass) (by simp [program]) (unit_type 0).1

private theorem super_input : superBodyInput kinds program oldBuiltins builtins childImpl
    "Base" (.dict "unitBase" [] []) := by
  have ctx : LegacyNodeContext kinds program [] Benitoite.Release.StoreTy.empty [] [] := by
    refine ⟨rfl,rfl,rfl,?_,?_⟩
    · intro l t h; cases h
    · intro i a hi; simp at hi
  have empty : LegacyOutputInput kinds program oldBuiltins builtins
      (.values [] Benitoite.Release.StoreTy.empty Qempty [] [] [] []) :=
    .node .Vs_nil ⟨ctx,trivial,by simp [LegacyNodeTypes]⟩ (by simp)
  change LegacyOutputInput kinds program oldBuiltins builtins
    (.value [] Benitoite.Release.StoreTy.empty Qempty [] [] (.dict "unitBase" [] []) (.dict "Base" U))
  refine .node (.V_Dict (id := baseImpl) (by simp [program]) (by simp [Benitoite.Release.SatAll,baseImpl]))
    ⟨ctx,?_,trivial,?_⟩ ?_
  · exact ⟨⟨baseImpl,by simp [program],unit_type 0,by simp [baseImpl,Benitoite.Release.ImplDecl.dictTys],⟨rfl,by simp⟩⟩,trivial⟩
  · intro a ha; obtain rfl := List.mem_singleton.mp ha; exact dictionary_type
  · intro child hc; obtain rfl := List.mem_singleton.mp hc; exact empty

private theorem inputs : LegacyDeclarationInputs kinds program oldBuiltins builtins := by
  constructor
  · refine ⟨?_,?_,?_,?_⟩
    · intro f d hd; cases hd
    · intro o od ho; cases ho
    · intro cl cd m ms hc hm
      rcases only_class hc with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
      · cases hm
      · obtain ⟨rfl,rfl⟩ := only_method hm; exact method_type
    · intro i id hi
      rcases only_impl hi with rfl | rfl
      · exact ⟨unit_type 0,by simp [baseImpl,Benitoite.Release.ImplDecl.dictTys],by simp [baseImpl],by simp [baseImpl,program,childClass,baseClass]⟩
      · refine ⟨unit_type 0,by simp [childImpl,Benitoite.Release.ImplDecl.dictTys],?_,?_⟩
        · intro s v hv
          simp only [childImpl] at hv
          split at hv
          · cases hv; exact super_input.regular.2.1
          · cases hv
        · intro cd m ms body hc hm hb
          have hc' : cd = childClass := by simpa [program,childImpl] using hc.symm
          subst cd
          obtain ⟨rfl,rfl⟩ := only_method hm
          have hb' : body = .ret (.var 0) := by simpa [childImpl] using hb.symm
          subst body; trivial
  · refine ⟨?_,?_,?_⟩
    · intro f d hd; cases hd
    · intro i id cd m ms body hi hc hm hb
      rcases only_impl hi with rfl | rfl
      · have he : cd = baseClass := by simpa [program,baseImpl] using hc.symm
        subst cd; cases hm
      · have he : cd = childClass := by simpa [program,childImpl] using hc.symm
        subst cd
        obtain ⟨rfl,rfl⟩ := only_method hm
        have hb' : body = .ret (.var 0) := by simpa [childImpl] using hb.symm
        subst body; exact method_input
    · intro i id cd s value hi hc hs hv
      rcases only_impl hi with rfl | rfl
      · have he : cd = baseClass := by simpa [program,baseImpl] using hc.symm
        subst cd; cases hs
      · have he : cd = childClass := by simpa [program,childImpl] using hc.symm
        subst cd
        have hname : s = "Base" := by simpa [childClass] using hs
        subst s
        have hv' : value = .dict "unitBase" [] [] := by simpa [childImpl] using hv.symm
        subst value; exact super_input
  · intro f d hd; cases hd
  · intro i id cd m ms body hi hc hm hb
    rcases only_impl hi with rfl | rfl
    · have he : cd = baseClass := by simpa [program,baseImpl] using hc.symm
      subst cd; cases hm
    · have he : cd = childClass := by simpa [program,childImpl] using hc.symm
      subst cd
      obtain ⟨rfl,rfl⟩ := only_method hm
      have hb' : body = .ret (.var 0) := by simpa [childImpl] using hb.symm
      subst body
      simp [signature,childImpl,Benitoite.Release.ImplDecl.dictTys,embedComp,embedVal,Comp.SourceScoped,Val.SourceScoped]
  · intro i id s value hi hv
    rcases only_impl hi with rfl | rfl
    · cases hv
    · simp only [childImpl] at hv
      split at hv
      · cases hv
        simp [embedVal,embedTys,embedVals,Val.SourceScoped,scopedTypes,scopedValues]
      · cases hv

private theorem old_base : Benitoite.Release.ImplDecl.WellTyped program oldBuiltins baseImpl := by
  refine ⟨baseClass,by simp [program,baseImpl],?_,?_,?_,?_⟩
  · intro m; rfl
  · intro s; simp [baseImpl,baseClass]
  · intro m ms hm; cases hm
  · intro s hs; cases hs

private theorem old_child : Benitoite.Release.ImplDecl.WellTyped program oldBuiltins childImpl := by
  refine ⟨childClass,by simp [program,childImpl],?_,?_,?_,?_⟩
  · intro m
    by_cases hm : m = "identity" <;> simp [childImpl,childClass,hm]
  · intro s
    by_cases hs : s = "Base" <;> simp [childImpl,childClass,hs]
  · intro m ms hm
    obtain ⟨rfl,rfl⟩ := only_method hm
    exact ⟨.ret (.var 0),by simp [childImpl],by simp [signature,Benitoite.Release.NamesWF],method_input.old⟩
  · intro s hs
    have he : s = "Base" := by simpa [childClass] using hs
    subst s
    exact ⟨.dict "unitBase" [] [],by simp [childImpl],super_input.old⟩

private theorem old_typed : Benitoite.Release.Program.WellTyped program oldBuiltins := by
  constructor
  · intro f d hd; cases hd
  · intro i id hi; rcases only_impl hi with rfl | rfl
    · exact old_base
    · exact old_child

private theorem old_formed : Benitoite.Release.Program.WellFormed program := by
  refine ⟨?_,?_,?_,?_,?_⟩
  · intro f d hd; cases hd
  · intro c cd hc; cases hc
  · intro o od ho; cases ho
  · intro c cd hc
    rcases only_class hc with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    · intro m ms hm; cases hm
    · intro m ms hm
      obtain ⟨rfl,rfl⟩ := only_method hm
      simp [Benitoite.Release.MethSig.Scoped,signature,U,E,Benitoite.Release.NamesWF,
        Benitoite.Release.Ty.VarsInList,Benitoite.Release.Ty.VarsIn,Benitoite.Release.Eff.VarsIn,Benitoite.Release.Eff.empty]
  · intro i id hi
    rcases only_impl hi with rfl | rfl
    · simp [Benitoite.Release.ImplDecl.Scoped,baseImpl,U,Benitoite.Release.Ty.VarsIn,program,baseClass]
    · refine ⟨by simp [childImpl],trivial,?_,?_⟩
      · intro s v hv
        simp only [childImpl] at hv
        split at hv
        · cases hv
          simp [Benitoite.Release.Val.VarsIn,Benitoite.Release.Val.VarsInList,Benitoite.Release.Ty.VarsInList]
        · cases hv
      · intro cd m ms body hc hm hb
        have he : cd = childClass := by simpa [program,childImpl] using hc.symm
        subst cd
        obtain ⟨rfl,rfl⟩ := only_method hm
        have hb' : body = .ret (.var 0) := by simpa [childImpl] using hb.symm
        subst body
        simp [Benitoite.Release.Comp.VarsIn,Benitoite.Release.Val.VarsIn]

theorem implementation_parents :
    LegacyDeclarationInputs kinds program oldBuiltins builtins ∧
    Benitoite.Release.Program.WellTyped program oldBuiltins ∧
    Benitoite.Release.Program.WellFormed program ∧
    ImplDecl.WellTyped (embedProgramWithKinds kinds program) builtins (embedImplDecl childImpl) ∧
    Program.WellTyped (embedProgramWithKinds kinds program) builtins ∧
    Program.WellFormed (embedProgramWithKinds kinds program) ∧
    (embedImplDecl childImpl).methods "identity" = some (embedComp (.ret (.var 0))) ∧
    (embedImplDecl childImpl).supers "Base" = some (embedVal (.dict "unitBase" [] [])) :=
  ⟨inputs,old_typed,old_formed,embedImplWellTyped (i := "unitChild") kinds_valid tables inputs (by simp [program]) old_child,
    embedProgramWellTyped kinds_valid tables inputs old_typed,
    embedProgramWellFormed kinds_valid tables inputs old_formed,rfl,rfl⟩

end
end Benitoite.Release.Refinement.LegacyImplementationEmbeddingExamples
