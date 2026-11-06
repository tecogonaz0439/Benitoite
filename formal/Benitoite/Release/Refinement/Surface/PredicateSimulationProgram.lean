import Benitoite.Release.Refinement.Surface.PredicateSimulationSourceCode
import Benitoite.Release.Refinement.Surface.PredicateSimulationOpenPipeSafety
import Benitoite.Release.Refinement.Surface.PredicateSimulationSteps
import Benitoite.Release.Refinement.SurfaceLibrary

/-! # 名前解決の前後の核のプログラムの対応

元のプログラムと全本体を解決したプログラムを、同じ標準の本体と結合した核の間で対応させる。
本体の対応は、解決後の本体の型付けが与えるパイプの形の条件の下で、全ての表層の構文から構成する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

variable {source : Program} {rows : PredicateProjection.Table.Rows}

theorem DefinitionRel.refl (d : Refinement.Def) : DefinitionRel source rows d d :=
  ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,Code.refl _⟩

theorem ImplementationRel.refl (id : Refinement.ImplDecl) : ImplementationRel source rows id id where
  tparams := rfl
  dictionaries := rfl
  className := rfl
  target := rfl
  supers := fun superclass => by
    cases id.supers superclass with
    | none => exact .none
    | some value => exact .some (Value.refl value)
  methods := fun method => by
    cases id.methods method with
    | none => exact .none
    | some body => exact .some (Code.refl body)

/-- 解決後の全ての定義と実装メソッドの本体が、パイプの右辺に内部の判定を置かないこと。 -/
structure ResolvedSafe (rows : PredicateProjection.Table.Rows) (p : Program) : Prop where
  defs : ∀ name d, p.defs name = some d → SafeBlock (PredicateProjectionCalls.resolveBlock rows p d.body)
  methods : ∀ name id, p.impls name = some id → ∀ method body, id.methods method = some body →
    SafeBlock (PredicateProjectionCalls.resolveBlock rows p body)

/-- 解決後の本体の型付けから、全本体のパイプの形の条件を得る。 -/
theorem ResolvedSafe.of_checked {rows : PredicateProjection.Table.Rows} {p : Program} {q : Check.Input}
    (checked : CheckTables.CheckedUnder (CheckPreparation.resolveProgram rows p) q) : ResolvedSafe rows p where
  defs := by
    intro name d found
    have typed := checked.defs name { d with body := PredicateProjectionCalls.resolveBlock rows p d.body }
      (by simp only [CheckPreparation.resolveProgram,found,Option.map_some])
    exact BodyTyR.predicate_pipe_safe typed.2.2.2
  methods := by
    intro name id found method body methodFound
    obtain ⟨cd,classFound,same,_,_,_,bodies,_⟩ := checked.impls name
      { id with methods := fun method => (id.methods method).map fun body =>
        PredicateProjectionCalls.resolveBlock rows p body }
      (by simp only [CheckPreparation.resolveProgram,found,Option.map_some])
    have present := same method
    simp only [methodFound,Option.map_some,Option.isSome_some] at present
    cases signature : cd.methods method with
    | none => rw [signature] at present; cases present
    | some ms =>
      obtain ⟨resolved,resolvedFound,_,typed⟩ := bodies method ms signature
      simp only [methodFound,Option.map_some,Option.some.injEq] at resolvedFound
      subst resolved
      exact BodyTy.predicate_pipe_safe typed

/-- 元のプログラムと解決後のプログラムを同じ本体と結合した核は、本体ごとに対応する。 -/
theorem resolved_program_rel (op : OpPrim) (rows : PredicateProjection.Table.Rows) (p : Program)
    (base : Refinement.Program) (safe : ResolvedSafe rows p) :
    ProgramRel p rows (linkProgram base op p) (linkProgram base op (CheckPreparation.resolveProgram rows p)) where
  types := ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩
  definitions := by
    intro name
    change Option.Rel _ (((desugarProgram op p).defs name).orElse (fun _ => base.defs name))
      (((desugarProgram op (CheckPreparation.resolveProgram rows p)).defs name).orElse (fun _ => base.defs name))
    simp only [desugarProgram,Program.lookupFun,CheckPreparation.resolveProgram]
    cases found : p.defs name with
    | some d =>
      simp only [Option.map_some,Option.orElse_some]
      exact .some ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,source_block op .tail d.body (safe.defs name d found)⟩
    | none =>
      simp only [Option.map_none]
      cases ((match p.accessors name with
        | some (c, k) => (p.cons c).map fun cd => accessorDef c cd k
        | none => match p.testers name with
          | none => none
          | some c => (p.cons c).map fun cd => testerDef c cd).orElse (fun _ => base.defs name)) with
      | none => exact .none
      | some d => exact .some (DefinitionRel.refl d)
  implementations := by
    intro name
    change Option.Rel _ ((p.impls name).map (desugarImpl op))
      (((CheckPreparation.resolveProgram rows p).impls name).map (desugarImpl op))
    simp only [CheckPreparation.resolveProgram]
    cases found : p.impls name with
    | none => exact .none
    | some id =>
      refine .some ⟨rfl,rfl,rfl,rfl,fun superclass => ?_,fun method => ?_⟩
      · show Option.Rel _ ((id.supers superclass).map DictEv.toVal) ((id.supers superclass).map DictEv.toVal)
        cases (id.supers superclass).map DictEv.toVal with
        | none => exact .none
        | some value => exact .some (Value.refl value)
      · simp only [desugarImpl]
        cases methodFound : id.methods method with
        | none => exact .none
        | some body => exact .some (source_block op .tail body (safe.methods name id found method body methodFound))
  getters := (getter_environment p op).link base

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
