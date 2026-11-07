import Benitoite.Release.Refinement.SurfaceCheckedMainExamples
import Benitoite.Release.Refinement.Surface.PredicateProgramGuarantees
import Benitoite.Release.Refinement.Surface.PredicateOverlayTable
import Benitoite.Release.Refinement.Surface.PredicateProgramObservations

/-! # 公開の文字集合判定を条件に持つmainの実入口と、名前解決の前後の観測 -/
namespace Benitoite.Release.Refinement.Surface.PredicateMainExamples
open StandardModel PredicateRows PredicateProjection
noncomputable section

private def entry : Entry := .characters 'a' 'z'

private def condition : Expr := .call (.primName "String.charactersIn" [] [] [])
  [some "text", some "minimum", some "maximum"] [0, 1, 2]
  (.cons (.literal (.string "a")) (.cons (.literal (.character 'a')) (.cons (.literal (.character 'z')) .nil)))

private def mainDef : Def := {Examples.mainDef with body := .last (.ite condition .empty .empty)}

private def source (externals : List (ExternalKey × ExternalDecl)) : Program :=
  {MainExamples.source externals with defs := fun name => if name = "main" then some mainDef else none}

private def rows : Table.Rows := [("%Predicate.0", .scalar entry)]

private def resolved (externals : List (ExternalKey × ExternalDecl)) : Program :=
  CheckPreparation.resolveProgram rows (source externals)

private def linked (externals : List (ExternalKey × ExternalDecl)) : Refinement.Program :=
  linkProgram (program externals) (fun _ _ => none) (resolved externals)

private theorem main_fresh (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).defs "main" = none := rfl

private theorem includes (externals : List (ExternalKey × ExternalDecl)) : Includes externals (linked externals) where
  extends_ := { Refinement.Program.Extends.refl (program externals) with
    defs := by
      intro name d found
      have fresh : name ≠ "main" := by intro same; subst name; rw [main_fresh] at found; cases found
      simpa [linked, linkProgram, desugarProgram, Program.lookupFun, resolved, CheckPreparation.resolveProgram,
        source, MainExamples.source, Examples.mainProgram, fresh] using found }
  internal := by
    intro name d missing found
    by_cases same : name = "main"
    · subst name; simp only [String.startsWith_string_iff]; decide
    · simp [linked, linkProgram, desugarProgram, Program.lookupFun, resolved, CheckPreparation.resolveProgram,
        source, MainExamples.source, Examples.mainProgram, same, missing] at found
  publicCollisions := by
    intro name member
    have old := (Includes.refl externals).publicCollisions name member
    have fresh : name ≠ "main" := by intro same; subst name; simp [FunctionNames.collisionNames] at member
    simpa [linked, linkProgram, desugarProgram, Program.lookupFun, resolved, CheckPreparation.resolveProgram,
      source, MainExamples.source, Examples.mainProgram, fresh] using old

private def data (externals : List (ExternalKey × ExternalDecl)) : DataTable (linked externals) :=
  {dataTable externals with valid := (variance_valid externals).sameTypes ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩}

private def input (externals : List (ExternalKey × ExternalDecl)) : Check.Input where
  D := (source externals).declarations
  builtinSource := .predicates (data externals) []
  opPrim := fun _ _ => none
  formation := ⟨StandardSupport.atoms, fun _ => constructorNames, []⟩
  proofSteps := 4
  defs := ["main"]
  ctorNames := constructorNames

attribute [local cbv_opaque] StandardModel.program data CheckedMainExamples.input StandardModel.constructorNames PredicateProjection.Table.builtins

private theorem prepared (externals : List (ExternalKey × ExternalDecl)) :
    CheckPreparation.prepare (input externals) (source externals) =
      ⟨CheckPreparation.input (input externals) rows, resolved externals⟩ := by cbv

private def required : CheckAccept.AcceptInput := {
  ok := "Ok", rules := fun _ => none, limits := ⟨⟨100,100⟩,⟨100,100⟩⟩,
  methodKey := fun i m => i ++ "." ++ m}

private theorem input_sound : (input positiveExternals).Sound := by
  have previous := CheckedMainExamples.input_sound
  refine ⟨previous.formation, ⟨?_, ?_, ?_, previous.tables.ops,
    previous.tables.methods, previous.tables.externals⟩, ?_, ?_, ?_, previous.operators⟩
  · refine ⟨?_⟩
    intro name declaration found; cases found
  · intro name declaration found
    by_cases same : name = "main"
    · subst name
      have same : declaration = mainDef.toFunDecl := by
        simpa [input, source, Program.declarations, Program.declarationsFor, Program.lookupFun] using found.symm
      subst declaration
      simp [CheckArguments.SignatureSupport, mainDef, Examples.mainDef, FunDecl.tel,
        FunDecl.coreNames, FunDecl.coreParams, FunDecl.dictTys, internalNames, signatureTel,
        Tel.Support, Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]
    · have missing : (input positiveExternals).D.funs name = none := by
        simp [input, source, Program.declarations, Program.declarationsFor, Program.lookupFun, same,
          MainExamples.source, Examples.mainProgram]
      rw [missing] at found
      cases found
  · intro name signature found
    rcases Table.lookup_cases (data positiveExternals) found with ⟨row, _, rfl⟩ | ⟨row, missing, _⟩
    · exact StandardSupport.primitive _ row
    · cases missing
  · intro C a p accepted; cases accepted
  · intro name signature C types found accepted; cases accepted
  · intro name ranges accepted; cases accepted

private def resolvedMain : Def := {mainDef with body := .last (.ite
  (.partialCall (.primName "%Predicate.0" [] [] []) [] (.expr none 0 (.literal (.string "a")) .nil)
    (entry.result (.string "a")) Eff.empty) .empty .empty)}

private theorem resolved_main (externals : List (ExternalKey × ExternalDecl)) :
    (resolved externals).defs "main" = some resolvedMain := by cbv

private theorem checker_succeeds : CheckTables.checkProgram (input positiveExternals) (source positiveExternals) = .ok () := by
  unfold CheckTables.checkProgram
  rw [prepared]
  unfold CheckTables.checkPreparedProgram
  have variance : CheckVariance.check (CheckPreparation.input (input positiveExternals) rows).formation
      (CheckPreparation.input (input positiveExternals) rows).D.core
      (CheckPreparation.input (input positiveExternals) rows).dataNames
      (CheckPreparation.input (input positiveExternals) rows).ctorNames = true := rfl
  have effects : CheckTables.effectsCheck (CheckPreparation.input (input positiveExternals) rows) = true := rfl
  simp only [variance, effects, Check.require, ite_true, Except.bind, Bind.bind]
  have definitions : (CheckPreparation.input (input positiveExternals) rows).defs = ["main"] := rfl
  have implementations : (CheckPreparation.input (input positiveExternals) rows).impls = [] := rfl
  simp only [definitions, implementations, CheckTables.checkNamed, resolved_main, Except.bind, Bind.bind]
  cbv

/-- 公開の呼出しのまま書いたmainを、準備と型付けと必須判定の実入口が受理する。 -/
theorem entry_succeeds :
    CheckAccept.checkProgramAccepted (input positiveExternals) required (source positiveExternals) = .ok () := by
  simp only [CheckAccept.checkProgramAccepted, checker_succeeds]
  cbv


private theorem resolved_defs (externals : List (ExternalKey × ExternalDecl)) (name : FunName) :
    (resolved externals).defs name = if name = "main" then some resolvedMain else none := by
  by_cases same : name = "main"
  · subst name; exact resolved_main externals
  · simp [resolved, CheckPreparation.resolveProgram, source, same]

private theorem names_complete : CheckTables.NamesComplete (input positiveExternals) (source positiveExternals) where
  defs := by
    intro name d found
    change (if name = "main" then some mainDef else none) = some d at found
    split at found
    · simp [input, ‹name = "main"›]
    · cases found
  impls := by intro name id found; cases found
  effects := by intro name operations found; cases found
  operations := by intro name operation found; cases found
  dataNames := by intro name info found; cases found
  ctorNames := by
    intro name declaration found
    have member := StandardModel.cons_mem (externals := positiveExternals) found
    exact List.mem_map.mpr ⟨(name,declaration),member,rfl⟩

private theorem support : ∀ name d,
    (CheckPreparation.prepare (input positiveExternals) (source positiveExternals)).program.defs name = some d →
      CheckDeclarations.DefSupport (CheckPreparation.prepare (input positiveExternals) (source positiveExternals)).input d := by
  intro name d found
  rw [prepared, resolved_defs] at found
  rw [prepared]
  split at found
  · cases found
    constructor
    · simp [resolvedMain, mainDef, Examples.mainDef, FunDecl.tel, FunDecl.coreNames, FunDecl.coreParams,
        FunDecl.dictTys, internalNames, signatureTel, Tel.Support, Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]
    · have head := CheckArguments.primitive_empty_support
        (b := "%Predicate.0") (ts := [])
        (CheckPreparation.input_sound input_sound rows).tables (by trivial)
      simpa [Check.BlockSupport, CheckSource.BlockSupport, CheckSource.ExprSupport,
        CheckSource.HolesSupport, resolvedMain, mainDef, Examples.mainDef, entry, Entry.result,
        Ty.Support, Ty.SupportList, Eff.Support, Eff.empty] using head
  · cases found

private theorem wellFormed :
    (CheckPreparation.prepare (input positiveExternals) (source positiveExternals)).program.WellFormed where
  types := by
    rw [CheckPreparation.prepare_declarations]
    exact (MainExamples.wellFormed positiveExternals positive_wf).types
  defs := by
    intro name d found
    rw [prepared, resolved_defs] at found
    split at found
    · cases found
      refine ⟨by simp [resolvedMain, mainDef, Examples.mainDef, FunDecl.coreNames,
        FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF], ?_, ?_⟩
      · change SignatureScopedR _ [] [] 0 (.done (.base .unit) Eff.empty)
        refine ⟨⟨(Examples.mainTel_annotation (CheckPreparation.prepare (input positiveExternals) (source positiveExternals)).program.declarations.core).wf, ?_, ?_⟩, ?_, ?_, (Examples.mainTel_annotation (CheckPreparation.prepare (input positiveExternals) (source positiveExternals)).program.declarations.core).range_empty⟩
        all_goals simp [Ty.RowsIn, Ty.RowsInList, Tel.RowsIn, Eff.RowsIn, Ty.RangesScoped,
          Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, Ty.HasKind, kindsTel, kindsEff,
          kindsList, Eff.empty]
      · simp [resolvedMain, mainDef, Examples.mainDef, entry, Entry.result, Entry.predicate,
          agreement, agreementAt, FunDecl.coreParams, FunDecl.dictTys,
          holeTel, HoleArgs.holeNames, HoleArgs.holeTypes, Block.Scoped, Expr.Scoped,
          HoleArgs.Scoped, Tel.WF, Tel.RowsIn, Tel.RangesScoped, Eff.Canonical, Eff.norm,
          Ty.WFList, Ty.NotContCore, Ty.core, Ty.SourceScoped, Ty.WF, Eff.WF, Eff.empty,
          Ty.RowsIn, Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped, Eff.RangesScoped,
          rangesScopedTypes, scopedTypes, scopedRows, Pred.WF, Pred.VarsIn, Term.VarsIn]
    · cases found
  impls := by rw [prepared]; intro name id found; cases found
  accessors := by rw [prepared]; intro name c k found; cases found
  testers := by rw [prepared]; intro name c found; cases found

private theorem source_wellFormed : (source positiveExternals).WellFormed where
  types := (MainExamples.wellFormed positiveExternals positive_wf).types
  defs := by
    intro name d found
    change (if name = "main" then some mainDef else none) = some d at found
    split at found
    · cases found
      refine ⟨by simp [mainDef, Examples.mainDef, FunDecl.coreNames,
        FunDecl.coreParams, FunDecl.dictTys, internalNames, NamesWF], ?_, ?_⟩
      · change SignatureScopedR _ [] [] 0 (.done (.base .unit) Eff.empty)
        refine ⟨⟨(Examples.mainTel_annotation (source positiveExternals).declarations.core).wf, ?_, ?_⟩, ?_, ?_,
          (Examples.mainTel_annotation (source positiveExternals).declarations.core).range_empty⟩
        all_goals simp [Ty.RowsIn, Ty.RowsInList, Tel.RowsIn, Eff.RowsIn, Ty.RangesScoped,
          Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, Ty.HasKind, kindsTel, kindsEff,
          kindsList, Eff.empty]
      · simp [mainDef, Examples.mainDef, condition, FunDecl.coreParams, FunDecl.dictTys,
          Block.Scoped, Expr.Scoped, Exprs.Scoped, scopedTypes, scopedRows]
    · cases found
  impls := by intro name id found; cases found
  accessors := by intro name c k found; cases found
  testers := by intro name c found; cases found

private theorem typed : CheckTables.CheckedUnder (resolved positiveExternals)
    (CheckPreparation.input (input positiveExternals) rows) := by
  have checked := CheckTables.checkProgram_sound
    (CheckPreparation.prepare_sound input_sound _) (CheckTables.prepare_names names_complete) support
    (by rw [prepared]; intro name id found; cases found)
    (by rw [prepared]; intro name id found; cases found)
    (CheckTables.prepare_extension (CheckTables.Extends.refl _)) checker_succeeds
  simpa only [prepared] using checked

private theorem core_wellFormed : (linked positiveExternals).WellFormed := by
  have values := PredicateOverlayValues.prepared_predicates_values (linked positiveExternals)
    (data positiveExternals) [] (source positiveExternals) (q := input positiveExternals) rfl
  rw [prepared] at values
  have additions := link_additions (program positiveExternals)
    (p := resolved positiveExternals) (q := CheckPreparation.input (input positiveExternals) rows)
    (by simpa only [prepared, resolved] using wellFormed) typed
    (by
      change (source positiveExternals).declarations.Realizes (linked positiveExternals)
      rw [← CheckPreparation.resolveProgram_declarations rows (source positiveExternals)]
      exact link_realizes _ (by simpa only [prepared, resolved] using wellFormed) closedView) values
  exact StandardModel.included_wellFormed (includes positiveExternals) positive_wf additions

private theorem rows_valid : rows.Valid (linked positiveExternals) := by
  constructor
  · intro name row member
    simp only [rows, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at member
    obtain ⟨rfl,rfl⟩ := member
    trivial
  · intro name row member
    simp only [rows, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at member
    obtain ⟨rfl,rfl⟩ := member
    exact PredicateRowCollection.name_fresh 0


private theorem ready (P : Refinement.Program) (B : Builtins) :
    MainExamples.environment.Ready P B (.run mainClosure [] Store.empty) := by
  refine ⟨by simp [PathEnv.Valid, MainExamples.environment, Scope.Domain.PathWordWF], ?_⟩
  intro range member
  cases range with
  | base base => cases base <;> exact ⟨[],rfl⟩
  | secrets => rfl

/-- 文字集合の公開呼出しを含む元のmainは、受理から同じ完成表の全主保証と開始の保証へ届く。 -/
theorem main_guarantees :
    CheckAccept.Accepted required (input positiveExternals) (source positiveExternals) ∧
    ProgramGuarantees (linked positiveExternals) (Table.builtins (data positiveExternals) rows) MainExamples.environment ∧
    MainGuarantees (linked positiveExternals) (Table.builtins (data positiveExternals) rows) MainExamples.environment Eff.empty := by
  have apply_main := checkProgramAccepted_main
    (q := input positiveExternals) (p := source positiveExternals) (Ai := required)
    (L := Table.names rows) (externals := positiveExternals) (A := Table.assumed rows)
    (σ := MainExamples.environment) (ε := Eff.empty)
  rw [prepared] at apply_main
  have op : (CheckPreparation.input (input positiveExternals) rows).opPrim = (fun _ _ => none) := rfl
  rw [op] at apply_main
  apply apply_main input_sound names_complete (by simpa only [prepared] using support)
    (by intro name id found; cases found) (by intro name id found; cases found)
    (by
      change CheckTables.Extends (source positiveExternals).declarations (CheckPreparation.resolveProgram rows (source positiveExternals)).declarations
      rw [CheckPreparation.resolveProgram_declarations]
      exact CheckTables.Extends.refl _)
    ⟨names_complete.defs, names_complete.impls, by intro name id found; cases found⟩ entry_succeeds
    (Table.names_wf rows_valid) (data positiveExternals)
    (PredicateOverlayTable.builtins_eq _ rows_valid core_wellFormed)
    (includes positiveExternals)
    (by
      change (source positiveExternals).declarations.Realizes (linked positiveExternals)
      rw [← CheckPreparation.resolveProgram_declarations rows (source positiveExternals)]
      exact link_realizes _ (by simpa only [prepared, resolved] using wellFormed) closedView)
    (Table.completion _ rows_valid core_wellFormed) positive_wf
    (by simpa only [prepared] using wellFormed)
    ⟨resolvedMain, resolved_main _, rfl, rfl, rfl, rfl, rfl, Or.inl rfl, rfl⟩
    (ready _ _)

/-- 同じmainの、公開の行での実行と解決後の内部行での実行は、開始から同じ事象列と終端の観測を持つ。 -/
theorem main_observations (events : List Event)
    (observation : PredicateSimulation.TerminalObservation (source positiveExternals) rows) :
    (∃ last, PredicateProgramSemantics.execution (program positiveExternals) (input positiveExternals)
        (source positiveExternals) MainExamples.environment (.run mainClosure [] Store.empty) events last ∧
      PredicateSimulation.terminal (source positiveExternals) rows last = some observation) ↔
    (∃ last, Steps (PredicateProgramSemantics.resolved (program positiveExternals) (input positiveExternals)
        (source positiveExternals))
        (CheckPreparation.input (input positiveExternals) rows).B
        MainExamples.environment (.run mainClosure [] Store.empty) events last ∧
      PredicateSimulation.terminal (source positiveExternals) rows last = some observation) := by
  have apply_observations := PredicateProgramSemantics.observations_preserved
    (q := input positiveExternals) (p := source positiveExternals) (Ai := required)
    (L := Table.names rows) (externals := positiveExternals) (A := Table.assumed rows)
    (σ := MainExamples.environment) (ε := Eff.empty)
  simp only [PredicateProgramSemantics.observe] at apply_observations
  rw [prepared] at apply_observations
  have op : (CheckPreparation.input (input positiveExternals) rows).opPrim = (fun _ _ => none) := rfl
  rw [op] at apply_observations
  have conclusion := apply_observations input_sound names_complete (by simpa only [prepared] using support)
    (by intro name id found; cases found) (by intro name id found; cases found)
    (by
      change CheckTables.Extends (source positiveExternals).declarations (CheckPreparation.resolveProgram rows (source positiveExternals)).declarations
      rw [CheckPreparation.resolveProgram_declarations]
      exact CheckTables.Extends.refl _)
    ⟨names_complete.defs, names_complete.impls, by intro name id found; cases found⟩ entry_succeeds
    (Table.names_wf rows_valid) (data positiveExternals)
    (PredicateOverlayTable.builtins_eq _ rows_valid core_wellFormed)
    (includes positiveExternals)
    (by
      change (source positiveExternals).declarations.Realizes (linked positiveExternals)
      rw [← CheckPreparation.resolveProgram_declarations rows (source positiveExternals)]
      exact link_realizes _ (by simpa only [prepared, resolved] using wellFormed) closedView)
    (Table.completion _ rows_valid core_wellFormed) positive_wf
    (by simpa only [prepared] using wellFormed) source_wellFormed
    ⟨resolvedMain, resolved_main _, rfl, rfl, rfl, rfl, rfl, Or.inl rfl, rfl⟩
    (ready _ _)
  exact conclusion.1 events observation

end
end Benitoite.Release.Refinement.Surface.PredicateMainExamples
