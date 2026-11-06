import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.CheckPredicateExamples
import Benitoite.Release.Refinement.Surface.PredicateStandardSupport
import Benitoite.Release.Refinement.Surface.PredicateProgramGuarantees
import Benitoite.Release.Refinement.Surface.Examples

/-! # 公開の判定の呼出しをそのまま渡すプログラムの実入口 -/
namespace Benitoite.Release.Refinement.Surface.CheckPredicateProgramExamples
open PredicateRows PredicateResponse CheckPredicateExamples Scope.Domain
noncomputable section

/-- 元のプログラムは、ifの条件に公開の呼出しを書き、内部名を持たない。 -/
def program (entry : Entry) (facts : Bool) : Program where
  defs := fun name => if name = "predicate" then some (sourceDefinition entry facts) else none
  cons := fun _ => none

def input (entry : Entry) (facts : Bool) : Check.Input where
  D := (program entry facts).declarations
  builtinSource := .standard (program entry facts).declarations.core
  opPrim := fun _ _ => none
  formation := { atoms := PredicateStandardSupport.atoms, ctors := fun _ => [] }
  proofSteps := 200
  defs := ["predicate"]

private def required : CheckAccept.AcceptInput where
  ok := "Ok"
  rules := fun _ => none
  limits := ⟨⟨100,100⟩,⟨100,100⟩⟩
  methodKey := fun i m => i ++ "." ++ m

/-- 標準の全行の有限支持を使い、実入口へ渡す入力の健全性を構成する。 -/
theorem input_sound (entry : Entry) (facts : Bool) : (input entry facts).Sound := by
  refine ⟨⟨?_, ?_⟩, ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro c cd found; cases found
  · intro c cd found; cases found
  · intro i d found; cases found
  · intro name d found
    by_cases hn : name = "predicate"
    · subst name
      have same : d = (sourceDefinition entry facts).toFunDecl := by
        simpa only [input, program, Program.declarations, Program.declarationsFor, Program.lookupFun, ite_true, Option.some.injEq] using found.symm
      subst d
      simp [CheckArguments.SignatureSupport, sourceDefinition, FunDecl.coreParams, FunDecl.dictTys,
        FunDecl.tel, FunDecl.coreNames, internalNames, signatureTel, Ty.Support, Ty.SupportList, Tel.Support,
        Eff.Support, Eff.empty]
    · have missing : (input entry facts).D.funs name = none := by
        simp only [input, program, Program.declarations, Program.declarationsFor, Program.lookupFun, hn, ite_false]
      rw [missing] at found
      cases found
  · intro name signature found
    obtain ⟨row, _, _, rfl⟩ := (StandardModel.builtins_lookup_iff _ _ _).mp found
    exact PredicateStandardSupport.signature row
  · intro o d found; cases found
  · intro c cd m ms found; cases found
  · intro f d found; cases found
  · intro C a p accepted; cases accepted
  · intro name signature C types found accepted; cases accepted
  · intro name ranges accepted; cases accepted
  · intro op type name types found; cases found

/-- 成功から型付けへの接続に使う、解決後の同じ入力の健全性。 -/
theorem prepared_input_sound (entry : Entry) (facts : Bool) :
    (CheckPreparation.prepare (input entry facts) (program entry facts)).input.Sound :=
  CheckPreparation.prepare_sound (input_sound entry facts) _

attribute [local cbv_opaque] StandardModel.builtins

/-- pathの真偽の両枝は公開呼出しのまま受理し、素のBooleanの対照を型付けの段で拒否する。 -/
theorem path_entry :
    CheckTables.checkProgram (input (.path (.exact ["a"])) true) (program (.path (.exact ["a"])) true) = .ok () ∧
    CheckAccept.checkProgramAccepted (input (.path (.exact ["a"])) true) required (program (.path (.exact ["a"])) true) = .ok () ∧
    (CheckTables.checkProgram (input (.path (.exact ["a"])) false) (program (.path (.exact ["a"])) false)).toBool = false := by
  cbv <;> simp [Eff.atoms]

/-- hostの両枝とBooleanの対照も、全プログラムの入口で確認する。 -/
theorem host_entry :
    CheckAccept.checkProgramAccepted (input (.host (.name (.exact ["a"]))) true) required (program (.host (.name (.exact ["a"]))) true) = .ok () ∧
    (CheckTables.checkProgram (input (.host (.name (.exact ["a"]))) false) (program (.host (.name (.exact ["a"]))) false)).toBool = false := by
  cbv <;> simp [Eff.atoms]

/-- 文字集合の両端は元の呼出しのリテラルから収集する。 -/
theorem characters_entry :
    CheckAccept.checkProgramAccepted (input (.characters 'a' 'z') true) required (program (.characters 'a' 'z') true) = .ok () ∧
    (CheckTables.checkProgram (input (.characters 'a' 'z') false) (program (.characters 'a' 'z') false)).toBool = false := by
  cbv <;> simp [Eff.atoms]

/-- 二つの幅の全ての分類は、公開名を自動で解決して両枝の事実を得る。Float32.isInfiniteも含む。 -/
theorem floating_entry (width : FloatWidth) (test : FloatTest) :
    CheckAccept.checkProgramAccepted (input (.floating width test) true) required (program (.floating width test) true) = .ok () ∧
    (CheckTables.checkProgram (input (.floating width test) false) (program (.floating width test) false)).toBool = false := by
  cases width <;> cases test <;> cbv <;> simp [Eff.atoms]

private def pathEntry : Entry := .path (.exact ["a"])

private def pathRows : PredicateProjection.Table.Rows := [("%Predicate.0", .scalar pathEntry)]

private def pathDefinition : Def :=
  { sourceDefinition pathEntry true with
    body := .last (.ite (.partialCall (.primName "%Predicate.0" [] [] []) []
      (.expr none 0 (.local 0) .nil) (pathEntry.result (.var 1)) Eff.empty)
      (branch pathEntry true) (branch pathEntry false)) }

private theorem path_prepared :
    CheckPreparation.prepare (input pathEntry true) (program pathEntry true) =
      ⟨CheckPreparation.input (input pathEntry true) pathRows,
       CheckPreparation.resolveProgram pathRows (program pathEntry true)⟩ := by
  cbv

private theorem path_definitions (name : FunName) :
    (CheckPreparation.prepare (input pathEntry true) (program pathEntry true)).program.defs name =
      if name = "predicate" then some pathDefinition else none := by
  rw [path_prepared]
  by_cases hn : name = "predicate"
  · subst name
    cbv
  · simp only [CheckPreparation.resolveProgram, program, hn, ite_false, Option.map_none]

private theorem path_names : CheckTables.NamesComplete (input pathEntry true) (program pathEntry true) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro name d found
    change (if name = "predicate" then some (sourceDefinition pathEntry true) else none) = some d at found
    split at found
    · simp [input, ‹name = "predicate"›]
    · cases found
  · intro name id found; cases found
  · intro name operations found; cases found
  · intro name operation found; cases found
  · intro name info found; cases found
  · intro name constructor found; cases found

private theorem path_support : ∀ name d,
    (CheckPreparation.prepare (input pathEntry true) (program pathEntry true)).program.defs name = some d →
      CheckDeclarations.DefSupport (CheckPreparation.prepare (input pathEntry true) (program pathEntry true)).input d := by
  intro name d found
  rw [path_definitions] at found
  rw [path_prepared]
  split at found
  · cases found
    constructor
    · simp [pathDefinition, sourceDefinition, FunDecl.tel, FunDecl.coreParams, FunDecl.coreNames, FunDecl.dictTys,
        internalNames, signatureTel, Tel.Support, Ty.Support, Ty.SupportList, Eff.Support, Eff.empty]
    · have head := CheckArguments.primitive_empty_support
        (b := "%Predicate.0") (ts := []) (prepared_input_sound pathEntry true).tables (by trivial)
      rw [path_prepared] at head
      simpa [Check.BlockSupport, CheckSource.BlockSupport, CheckSource.ExprSupport, CheckSource.HolesSupport,
        pathDefinition, sourceDefinition, branch, Entry.result, Ty.Support, Ty.SupportList, Eff.Support, Eff.empty] using head
  · cases found


/-- 公開呼出しのまま成功した全プログラムを、解決後の同じ表で型付ける。 -/
theorem path_typed :
    CheckTables.CheckedUnder
      (CheckPreparation.prepare (input pathEntry true) (program pathEntry true)).program
      (CheckPreparation.prepare (input pathEntry true) (program pathEntry true)).input := by
  apply CheckTables.checkProgram_sound (q := input pathEntry true) (p := program pathEntry true)
    (prepared_input_sound _ _) (CheckTables.prepare_names path_names) ?_ ?_ ?_ ?_ path_entry.1
  · exact path_support
  · rw [path_prepared]
    intro name id found; cases found
  · rw [path_prepared]
    intro name id found; cases found
  · apply CheckTables.prepare_extension
    exact CheckTables.Extends.refl _


private theorem path_wellFormed :
    (CheckPreparation.prepare (input pathEntry true) (program pathEntry true)).program.WellFormed where
  types := by
    rw [CheckPreparation.prepare_declarations]
    exact Examples.mainProgram_wellFormed.types
  defs := by
    intro name d found
    rw [path_definitions] at found
    split at found
    · cases found
      refine ⟨by simp [pathDefinition, sourceDefinition, FunDecl.coreNames, FunDecl.coreParams,
        FunDecl.dictTys, internalNames, NamesWF], ?_, ?_⟩
      · change SignatureScopedR _ [] [] 0 (.param "value" (.base .string) (.done (.base .unit) Eff.empty))
        refine ⟨⟨?_, ?_, ?_⟩, ?_, ?_, Ty.annotationR_nil.mpr ⟨?_, ?_, ?_⟩⟩
        all_goals simp [Ty.WF, Tel.WF, Eff.WF, Eff.Canonical, Eff.norm, Eff.empty, Ty.WFList,
          Ty.RowsIn, Ty.RowsInList, Tel.RowsIn, Eff.RowsIn, Ty.RangesScoped, Tel.RangesScoped,
          Eff.RangesScoped, rangesScopedTypes, Ty.HasKind, kindsTel, kindsEff, kindsList,
          TypeCtx.kinds, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys,
          Ty.Declared, Tel.Declared, declaredEff, declaredTys]
      · simp [pathDefinition, sourceDefinition, branch, pathEntry, Entry.result, Entry.predicate,
          agreement, agreementAt, FunDecl.coreParams, FunDecl.dictTys, Entry.input,
          holeTel, HoleArgs.holeNames, HoleArgs.holeTypes,
          Block.Scoped, Expr.Scoped, HoleArgs.Scoped, Tel.WF, Tel.RowsIn, Tel.RangesScoped,
          Eff.Canonical, Eff.norm, Ty.WFList, Ty.NotContCore, Ty.core,
          Ty.SourceScoped, Ty.WF, Eff.WF, Eff.empty, Ty.RowsIn, Ty.RowsInList, Eff.RowsIn,
          Ty.RangesScoped, Eff.RangesScoped, rangesScopedTypes, scopedTypes, scopedRows,
          Pred.WF, Pred.VarsIn, Term.VarsIn]
    · cases found
  impls := by rw [path_prepared]; intro name id found; cases found
  accessors := by rw [path_prepared]; intro name c k found; cases found
  testers := by rw [path_prepared]; intro name c found; cases found

/-- 公開のpath判定の受理は、値の四条件を仮定せず同じ核の性質1へ届く。 -/
theorem path_property1 :
    CheckAccept.Accepted required (input pathEntry true) (program pathEntry true) ∧
    (PredicateProgramSemantics.meaning (input pathEntry true) (program pathEntry true)).WellFormed ∧
    (PredicateProgramSemantics.meaning (input pathEntry true) (program pathEntry true)).WellTyped
      (CheckPreparation.prepare (input pathEntry true) (program pathEntry true)).input.B ∧
    (PredicateProgramSemantics.meaning (input pathEntry true) (program pathEntry true)).EffectsOk
      (CheckPreparation.prepare (input pathEntry true) (program pathEntry true)).input.B := by
  have result := PredicateProgramGuarantees.accepted_standard_property1
    (q := input pathEntry true) (p := program pathEntry true) (A := required)
    rfl (input_sound _ _) path_names path_support
    (by rw [path_prepared]; intro name id found; cases found)
    (by intro name id found; cases found) ?_ ?_ path_wellFormed path_entry.2.1
  · exact result.2
  · rw [path_prepared]
    change (program pathEntry true).declarations = (CheckPreparation.resolveProgram pathRows (program pathEntry true)).declarations
    exact (CheckPreparation.resolveProgram_declarations _ _).symm
  · exact ⟨path_names.defs, path_names.impls, by intro name id found; cases found⟩

end
end Benitoite.Release.Refinement.Surface.CheckPredicateProgramExamples

