import Benitoite.Release.Refinement.Surface.PredicateSimulationInvariants
import Benitoite.Release.Refinement.SurfaceLibrary

/-! # 実際の全本体の一覧からの生成鍵の不在 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateGeneratedNames
noncomputable section

/-- 有限な本体の一覧から避けた名前は、元の脱糖した全本体でも現れない。 -/
theorem source_program_avoid {q : Check.Input} {p : Program} {keys}
    (fresh : NamesAvoid keys (sourceNames q p))
    (definitions : ∀ name definition, p.defs name = some definition → name ∈ q.defs)
    (implementations : ∀ name implementation, p.impls name = some implementation → name ∈ q.impls)
    (methods : ∀ name implementation, p.impls name = some implementation →
      ∀ method body, implementation.methods method = some body → method ∈ q.methods) :
    ProgramAvoid keys (desugarProgram q.opPrim p) := by
  constructor
  · intro name definition found key member
    exact fresh key (kernel_def_names definitions found member)
  · intro name implementation found
    constructor
    · intro method body methodFound key member
      have mapped : (p.impls name).map (desugarImpl q.opPrim) = some implementation := found
      obtain ⟨original,lookup,same⟩ := Option.map_eq_some_iff.mp mapped
      have listed := implementations name original lookup
      have methodListed : method ∈ q.methods := by
        have actual := methodFound
        rw [← same] at actual
        change (original.methods method).map (desugarBlock q.opPrim .tail) = some body at actual
        obtain ⟨originalBody,originalFound,_⟩ := Option.map_eq_some_iff.mp actual
        exact methods name original lookup method originalBody originalFound
      exact fresh key (kernel_method_names listed methodListed found methodFound member)
    · intro superclass value selected
      change NamesAvoid keys (valueNames value)
      rw [kernel_super_names found selected]
      exact .nil _

/-- 準備後の実装の型導出は、元の各実装の同じクラスの宣言の存在を供給する。 -/
theorem checked_method_names {q : Check.Input} {p : Program}
    (listed : ∀ name implementation, p.impls name = some implementation →
      CheckDeclarations.ImplNamesComplete q implementation)
    (checked : CheckTables.CheckedUnder (CheckPreparation.prepare q p).program
      (CheckPreparation.prepare q p).input) :
    ∀ name implementation, p.impls name = some implementation →
      ∀ method body, implementation.methods method = some body → method ∈ q.methods := by
  intro name implementation found method body selected
  rcases CheckPreparation.prepare_cases q p with identity | ⟨rows,prepared⟩
  · rw [identity] at checked
    obtain ⟨classDeclaration,declared,_⟩ := checked.impls name implementation found
    exact (listed name implementation found).methods classDeclaration declared method
      (Or.inl (by rw [selected]; rfl))
  · rw [prepared] at checked
    let resolved : ImplDecl := { implementation with methods :=
      (fun method => Option.map (PredicateProjectionCalls.resolveBlock rows p) (implementation.methods method)) }
    have resolvedFound : (CheckPreparation.resolveProgram rows p).impls name = some resolved := by
      simp only [CheckPreparation.resolveProgram,found,Option.map_some]
      rfl
    obtain ⟨classDeclaration,declared,_⟩ := checked.impls name resolved resolvedFound
    change q.D.classes implementation.cls = some classDeclaration at declared
    exact (listed name implementation found).methods classDeclaration declared method
      (Or.inl (by rw [selected]; rfl))

mutual
  private theorem renamed_value_names (rename : String → String) (value : Val) :
      valueNames (FunctionNames.value rename value) = valueNames value := by
    cases value with
    | closure type closure => cases closure with | mk cap body => cases cap <;>
        simp only [FunctionNames.value,valueNames,closureNames,captureNames,renamed_slots_names,renamed_code_names]
    | checkedAt resource scope actual saved => cases saved <;>
        simp only [FunctionNames.value,valueNames,optionalNames,renamed_value_names]
    | _ => simp only [FunctionNames.value,valueNames,renamed_value_names,renamed_values_names,renamed_code_names]
  private theorem renamed_values_names (rename : String → String) (values : List Val) :
      valuesNames (FunctionNames.values rename values) = valuesNames values := by
    cases values <;> simp only [FunctionNames.values,valuesNames,renamed_value_names,renamed_values_names]
  private theorem renamed_slots_names (rename : String → String) (values : List (Option Val)) :
      slotsNames (FunctionNames.slots rename values) = slotsNames values := by
    cases values with
    | nil => rfl
    | cons value rest => cases value <;>
        simp only [FunctionNames.slots,slotsNames,optionalNames,renamed_value_names,renamed_slots_names]
  private theorem renamed_code_names (rename : String → String) (body : Comp) :
      compNames (FunctionNames.computation rename body) = compNames body := by
    cases body with
    | checkAt kind mode shape bases pattern input source => cases bases <;>
        simp only [FunctionNames.computation,compNames,optionalNames,renamed_value_names]
    | _ => simp only [FunctionNames.computation,compNames,renamed_value_names,renamed_values_names,
        renamed_code_names,renamed_arms_names,renamed_clauses_names]
  private theorem renamed_arms_names (rename : String → String) (arms : List Arm) :
      armsNames (FunctionNames.arms rename arms) = armsNames arms := by
    cases arms with
    | nil => rfl
    | cons arm rest => cases arm with | mk alternatives guard body => cases guard <;>
        simp only [FunctionNames.arms,armsNames,renamed_code_names,renamed_arms_names]
  private theorem renamed_clauses_names (rename : String → String) (clauses : List Clause) :
      clausesNames (FunctionNames.clauses rename clauses) = clausesNames clauses := by
    cases clauses with
    | nil => rfl
    | cons clause rest => cases clause <;>
        simp only [FunctionNames.clauses,clausesNames,renamed_code_names,renamed_clauses_names]
end

private theorem standard_body_no_prefix (body : StandardModel.Body) :
    (compNames body.definition.body).all (fun key => !key.startsWith "%Predicate.") = true := by
  simp only [StandardModel.Body.definition,FunctionNames.definition,renamed_code_names]
  cases body <;> cbv

/-- 標準の本体の参照する組込み名は、生成鍵の接頭辞を持たない。 -/
theorem standard_program_avoid {keys} (externals : List (ExternalKey × ExternalDecl))
    (prefixed : ∀ key ∈ keys, key.startsWith "%Predicate." = true) :
    ProgramAvoid keys (StandardModel.program externals) := by
  constructor
  · intro name definition found key member forbidden
    obtain ⟨body,_,_,rfl⟩ := StandardModel.lookup_body found
    have notPrefix := List.all_eq_true.mp (standard_body_no_prefix body) key member
    rw [prefixed key forbidden] at notPrefix
    cases notPrefix
  · intro name implementation found
    change none = some implementation at found
    cases found

/-- 結合は利用者の全本体を優先し、残る標準本体の同じ不在を保持する。 -/
theorem ProgramAvoid.link {keys : List PrimName} {q : Check.Input} {p : Program} {base : Refinement.Program}
    (source : ProgramAvoid keys (desugarProgram q.opPrim p))
    (library : ∀ name definition, base.defs name = some definition → CodeAvoid keys definition.body) :
    ProgramAvoid keys (linkProgram base q.opPrim p) := by
  constructor
  · intro name definition found
    change ((desugarProgram q.opPrim p).defs name).orElse (fun _ => base.defs name) = some definition at found
    cases original : (desugarProgram q.opPrim p).defs name with
    | none => exact library name definition (by simpa only [original,Option.orElse_none] using found)
    | some value =>
      have same : value = definition := Option.some.inj (by simpa only [original,Option.orElse_some] using found)
      exact same ▸ source.1 name value original
  · exact source.2

/-- 実際の収集は、元の全本体と結合する標準本体の生成鍵を避ける。 -/
theorem collected_linked_avoid (q : Check.Input) (p : Program)
    (externals : List (ExternalKey × ExternalDecl))
    (definitions : ∀ name definition, p.defs name = some definition → name ∈ q.defs)
    (implementations : ∀ name implementation, p.impls name = some implementation → name ∈ q.impls)
    (methods : ∀ name implementation, p.impls name = some implementation →
      ∀ method body, implementation.methods method = some body → method ∈ q.methods) :
    let rows := PredicateRowCollection.collectAvoid p (CheckPreparation.sources q p) (forbidden q p)
    ProgramAvoid (rows.map Prod.fst) (linkProgram (StandardModel.program externals) q.opPrim p) := by
  dsimp only
  apply ProgramAvoid.link
  · apply source_program_avoid (definitions := definitions) (implementations := implementations) (methods := methods)
    intro key member keyMember
    obtain ⟨⟨name,row⟩,rowMember,same⟩ := List.mem_map.mp keyMember
    cases same
    exact (CheckPreparation.collected_fresh rowMember).1 member
  · apply (standard_program_avoid (keys := _) externals ?_).1
    intro key keyMember
    obtain ⟨⟨name,row⟩,rowMember,same⟩ := List.mem_map.mp keyMember
    cases same
    exact PredicateRowCollection.collectAvoid_prefix rowMember

/-- 実入口の名前の完全性と準備後の型導出から、結合した元本体の不在を供給する。 -/
theorem collected_linked_avoid_checked (q : Check.Input) (p : Program)
    (externals : List (ExternalKey × ExternalDecl)) (names : CheckTables.NamesComplete q p)
    (listed : ∀ name implementation, p.impls name = some implementation →
      CheckDeclarations.ImplNamesComplete q implementation)
    (checked : CheckTables.CheckedUnder (CheckPreparation.prepare q p).program
      (CheckPreparation.prepare q p).input) :
    let rows := PredicateRowCollection.collectAvoid p (CheckPreparation.sources q p) (forbidden q p)
    ProgramAvoid (rows.map Prod.fst) (linkProgram (StandardModel.program externals) q.opPrim p) :=
  collected_linked_avoid q p externals names.defs names.impls (checked_method_names listed checked)

/-- main の開始は値もコードも生成済みの組込み名を含まない。 -/
theorem main_start_avoid (rows : PredicateProjection.Table.Rows) :
    NoGeneratedKeys rows (.run mainClosure [] Store.empty) := by
  change NamesAvoid _ [] ∧ ContAvoid _ [] ∧ StoreAvoid _ Store.empty
  exact ⟨NamesAvoid.nil _,ContAvoid.nil _,StoreAvoid.empty _⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
