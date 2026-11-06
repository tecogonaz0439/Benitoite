import Benitoite.Release.Refinement.Surface.PredicateSimulationBackward
import Benitoite.Release.Refinement.Surface.PredicateSimulationProgram
import Benitoite.Release.Refinement.Surface.PredicateSimulationProgramAvoid
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionValidity
import Benitoite.Release.Refinement.Surface.PredicateSimulationLookup
import Benitoite.Release.Refinement.Surface.PredicateSimulationEffects

/-! # 公開の行での実行と解決後の実行の観測の同値

名前解決の前のプログラムは公開の呼出しを公開の行の δ で実行し、実入口が準備したプログラムは
同じ判定を内部の行の δ で実行する。二つの実行は、同じ標準の本体と結合した核の main の開始から、
同じ有限の事象列・終端の観測・無限の実行・効果の被覆を持つ。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
open PredicateSimulation SafeCheckErasure CheckErasure
noncomputable section

/-- 名前解決の前のプログラムを標準の本体と結合した核。公開の呼出しは公開の行を読む。 -/
def original (base : Refinement.Program) (q : Check.Input) (p : Program) : Refinement.Program :=
  linkProgram base q.opPrim p

/-- 実入口が準備したプログラムを同じ標準の本体と結合した核。 -/
def resolved (base : Refinement.Program) (q : Check.Input) (p : Program) : Refinement.Program :=
  linkProgram base (CheckPreparation.prepare q p).input.opPrim (CheckPreparation.prepare q p).program

/-- 名前解決の前のプログラムの、元の表での有限の実行。 -/
def execution (base : Refinement.Program) (q : Check.Input) (p : Program) (σ : PathEnv)
    (start : State) (events : List Event) (finish : State) : Prop :=
  Steps (original base q p) q.B σ start events finish

/-- 名前解決の前のプログラムの、各段のラベルを持つ無限の実行。 -/
def infinite (base : Refinement.Program) (q : Check.Input) (p : Program) (σ : PathEnv)
    (start : State) (labels : Nat → Option Event) : Prop :=
  InfiniteExecution (original base q p) q.B σ start labels

/-- 準備後の入力が重ねた内部行。準備が恒等なら空である。 -/
def preparedRows (q : Check.Input) : PredicateProjection.Table.Rows :=
  match q.builtinSource with
  | .resolved _ rows => rows
  | _ => []

/-- 終端の観測。正常値は閉包の本体の対応で比較し、失敗と終了は全ての payload を比べる。 -/
abbrev observe (q : Check.Input) (p : Program) : State → Option (TerminalObservation p (preparedRows (CheckPreparation.prepare q p).input)) :=
  terminal p (preparedRows (CheckPreparation.prepare q p).input)

private theorem resolved_ne (base : Check.BuiltinSource) (rows : PredicateProjection.Table.Rows) :
    Check.BuiltinSource.resolved base rows ≠ base := by
  intro same
  have size := congrArg sizeOf same
  simp only [Check.BuiltinSource.resolved.sizeOf_spec] at size
  omega

/-- 内部行を重ねる準備は、解決を有効にする元の入力と、実際に収集した行の表から作る。 -/
theorem prepare_resolved {q : Check.Input} {p : Program} {rows}
    (same : CheckPreparation.prepare q p = ⟨CheckPreparation.input q rows, CheckPreparation.resolveProgram rows p⟩) :
    CheckPreparation.enabled q.builtinSource = true ∧
      rows = PredicateRowCollection.collectAvoid p (CheckPreparation.sources q p) (PredicateGeneratedNames.forbidden q p) := by
  unfold CheckPreparation.prepare at same
  split at same
  · next active =>
    dsimp only at same
    split at same
    · exact False.elim (resolved_ne q.builtinSource rows
        (congrArg Check.Input.builtinSource (congrArg CheckPreparation.Prepared.input same).symm))
    · injection same with input
      have source := congrArg Check.Input.builtinSource input
      simp only [CheckPreparation.input,Check.BuiltinSource.resolved.injEq] at source
      exact ⟨active,source.2.symm⟩
  · exact False.elim (resolved_ne q.builtinSource rows
      (congrArg Check.Input.builtinSource (congrArg CheckPreparation.Prepared.input same).symm))

/-- 実入口の受理から、二つの実行の main の開始が全ての観測で一致する。
正常値は閉包の本体の対応の同値類で観測し、失敗と終了は全ての payload で観測する。 -/
theorem observations_preserved {p : Program} {q : Check.Input} {Ai : CheckAccept.AcceptInput}
    (hq : q.Sound) (hn : CheckTables.NamesComplete q p)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d →
      CheckDeclarations.DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id →
      CheckDeclarations.ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, p.impls n = some id → CheckDeclarations.ImplNamesComplete q id)
    (hext : CheckTables.Extends (CheckPreparation.prepare q p).input.D (CheckPreparation.prepare q p).program.declarations)
    (ha : CheckAccept.NamesComplete q p)
    (haccept : CheckAccept.checkProgramAccepted q Ai p = .ok ())
    {L : StandardModel.NameLists} (hL : L.WF) {externals}
    (T : StandardModel.DataTable (linkProgram (StandardModel.program externals) (CheckPreparation.prepare q p).input.opPrim (CheckPreparation.prepare q p).program))
    {A : StandardModel.AssumedTable} (hB : (CheckPreparation.prepare q p).input.B = StandardModel.complete L T A)
    (hI : StandardModel.Includes externals (linkProgram (StandardModel.program externals) (CheckPreparation.prepare q p).input.opPrim (CheckPreparation.prepare q p).program))
    (hR : (CheckPreparation.prepare q p).input.D.Realizes (linkProgram (StandardModel.program externals) (CheckPreparation.prepare q p).input.opPrim (CheckPreparation.prepare q p).program))
    (hc : StandardModel.Completion L T A) (hw : (StandardModel.program externals).ExternalWF)
    (hwf : (CheckPreparation.prepare q p).program.WellFormed) (sourceFormed : p.WellFormed)
    {σ : PathEnv} {ε : Eff} (hm : (CheckPreparation.prepare q p).program.HasMain ε)
    (hr : σ.Ready (linkProgram (StandardModel.program externals) (CheckPreparation.prepare q p).input.opPrim (CheckPreparation.prepare q p).program)
      (StandardModel.complete L T A) (.run mainClosure [] Store.empty)) :
    let base := StandardModel.program externals
    let start := State.run mainClosure [] Store.empty
    (∀ events observation,
      (∃ last, execution base q p σ start events last ∧ observe q p last = some observation) ↔
        (∃ last, Steps (resolved base q p) (CheckPreparation.prepare q p).input.B σ start events last ∧
          observe q p last = some observation)) ∧
    ((∃ labels, infinite base q p σ start labels) ↔
      (∃ labels, InfiniteExecution (resolved base q p) (CheckPreparation.prepare q p).input.B σ start labels)) ∧
    (∀ events, (∃ last, execution base q p σ start events last ∧ Diverges (original base q p) q.B σ last) ↔
      (∃ last, Steps (resolved base q p) (CheckPreparation.prepare q p).input.B σ start events last ∧
        Diverges (resolved base q p) (CheckPreparation.prepare q p).input.B σ last)) ∧
    (∀ Γ Φ effect events observation,
      (∃ last, execution base q p σ start events last ∧ observe q p last = some observation ∧
        ∀ event ∈ events, Event.Covered q.B Γ Φ effect event) ↔
        (∃ last, Steps (resolved base q p) (CheckPreparation.prepare q p).input.B σ start events last ∧
          observe q p last = some observation ∧
          ∀ event ∈ events, Event.Covered (CheckPreparation.prepare q p).input.B Γ Φ effect event)) := by
  intro base start
  obtain ⟨checked,_⟩ := CheckAccept.checkProgramAccepted_sound (CheckPreparation.prepare_sound hq p)
    (CheckTables.prepare_names hn) hd hi (CheckTables.prepare_impl_names him) hext ha haccept
  obtain ⟨_,_,main⟩ := checkProgramAccepted_main hq hn hd hi him hext ha haccept hL T hB hI hR hc hw hwf hm hr
  have hcore := (StandardModel.completion_core L externals hL _ T A hI hc).1
  have additions := link_additions _ hwf checked hR (hB ▸ hcore.values)
  obtain ⟨formed,typed,effects,core,_⟩ := StandardModel.included_premises hL T hI hc hw (hB ▸ additions)
  rcases CheckPreparation.prepare_cases_fresh q p with same | ⟨rows,same,fresh⟩
  · have identity : resolved base q p = original base q p := by
      simp only [resolved,original,same]
    have table : (CheckPreparation.prepare q p).input.B = q.B := by rw [same]
    simp only [execution,infinite,identity,table,iff_self,implies_true,and_self]
  · obtain ⟨active,collected⟩ := prepare_resolved same
    have rowsEq : preparedRows (CheckPreparation.prepare q p).input = rows := by rw [same]; rfl
    have programEq : resolved base q p =
        linkProgram base q.opPrim (CheckPreparation.resolveProgram rows p) := by
      simp only [resolved,same]; rfl
    have tableEq : (CheckPreparation.prepare q p).input.B = responseTable q.builtinSource rows := by
      rw [same]; rfl
    have overlayActive : CheckPreparation.enabled (.resolved q.builtinSource rows) = true := by
      rw [collected]; exact CheckPreparation.enabled_generated active
    haveI sourceLookup : StandardModel.RowLookup q.builtinSource.builtins := source_lookup active
    haveI targetEnv : StandardModel.RowEnv (resolved base q p) (StandardModel.complete L T A) :=
      StandardModel.RowEnv.ofAgree hL T hI (StandardModel.complete_agree L T A)
    have tableComplete : responseTable q.builtinSource rows = StandardModel.complete L T A := tableEq.symm.trans hB
    haveI responseEnv : StandardModel.RowEnv (resolved base q p) (responseTable q.builtinSource rows) :=
      tableComplete ▸ targetEnv
    have checkedResolved : CheckTables.CheckedUnder (CheckPreparation.resolveProgram rows p)
        (CheckPreparation.input q rows) := by
      rw [same] at checked; exact checked
    have coreResponse : (responseTable q.builtinSource rows).CoreAssumptions (resolved base q p) := tableComplete ▸ core
    have rowsValid : PredicateProjection.Table.Rows.Valid (resolved base q p) rows := by
      have valid := collected_valid_of_core (P := resolved base q p) p q (CheckPreparation.sources q p)
        (PredicateGeneratedNames.forbidden q p) sourceFormed (by rw [programEq]; exact ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩)
        (by rw [← collected]; exact coreResponse)
      rw [← collected] at valid
      exact valid
    have setting : Setting p rows q.builtinSource (original base q p) (resolved base q p) σ :=
      { active := overlayActive
        program := by
          rw [programEq]
          exact resolved_program_rel q.opPrim rows p base (ResolvedSafe.of_checked checkedResolved)
        programAvoid := by
          have avoid := collected_linked_avoid_checked q p externals hn him checked
          rw [← collected] at avoid
          exact avoid
        wellFormed := formed
        wellTyped := tableComplete ▸ typed
        effects := tableComplete ▸ effects
        core := coreResponse
        pathEnvironment := hr.1
        variance := typed.variance
        valid := fun key projection lookup => rowsValid.1 key (.projected projection) (ScopeSignatures.lookup_mem lookup)
        included := ⟨externals,hI⟩ }
    have startRel : InvariantRel p rows (resolved base q p) (responseTable q.builtinSource rows) σ ε start start :=
      ⟨.run (.mk (.mk .nil) (Code.refl _)) .nil (StoreRel.empty _ _),main_start_avoid rows,tableComplete ▸ main.initial⟩
    have forward : Trace.Forward (original base q p) q.B (resolved base q p) (responseTable q.builtinSource rows) σ
        (InvariantRel p rows (resolved base q p) (responseTable q.builtinSource rows) σ ε) (administrativeRank p) :=
      setting.forward
    have backward : Trace.Forward (resolved base q p) (responseTable q.builtinSource rows) (original base q p) q.B σ
        (fun t s => InvariantRel p rows (resolved base q p) (responseTable q.builtinSource rows) σ ε s t) (fun _ => 0) :=
      setting.backward
    have environment := setting.program.getters
    simp only [observe,execution,infinite]
    rw [rowsEq,tableEq]
    exact ⟨fun events observation => InvariantRel.observations forward backward environment startRel events observation,
      Trace.infinite forward backward startRel,
      fun events => Trace.diverging_prefixes forward backward startRel events,
      fun Γ Φ effect events observation => InvariantRel.effects forward backward environment startRel Γ Φ effect
        (overlay_coverage q.B rows (fun key row member => (fresh key row member).2) Γ Φ effect) events observation⟩

end
end Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
