import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.CheckErasure
import Benitoite.Release.Refinement.Surface.PredicatePublicDeltas

/-! # 実入口が準備した核と性質1

実入口が用意する核は、全本体の収集・登録・解決に続く通常の脱糖である。
名前解決の前の実行との観測の同値は `PredicateProgramObservations` で示す。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
open PredicateRows PredicateResponse PredicateProjection MatchFacts
noncomputable section

/-- 解決済みのプログラムと同じ入力表が持つ、核のプログラム。 -/
def core (ready : CheckPreparation.Prepared) : Refinement.Program :=
  desugarProgram ready.input.opPrim ready.program

/-- 実入口が準備したプログラムの核。収集・名前解決に続いて通常の脱糖を行う。 -/
def meaning (q : Check.Input) (p : Program) : Refinement.Program :=
  core (CheckPreparation.prepare q p)

/-- 実入口の受理は、解決後の型付けと通常の性質1へ接続する。
入力の健全性は元の表から構成する。全件性・有限支持とプログラムの整形式・値の束縛の仮定は区別する。 -/
theorem accepted_property1 {q : Check.Input} {p : Program} {A : CheckAccept.AcceptInput}
    (hq : q.Sound)
    (hn : CheckTables.NamesComplete q p)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d →
      CheckDeclarations.DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id →
      CheckDeclarations.ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, p.impls n = some id → CheckDeclarations.ImplNamesComplete q id)
    (hD : (CheckPreparation.prepare q p).input.D = (CheckPreparation.prepare q p).program.declarations)
    (ha : CheckAccept.NamesComplete q p)
    (hw : (CheckPreparation.prepare q p).program.WellFormed)
    (hvalues : Builtins.ValueAssumptions (meaning q p) (CheckPreparation.prepare q p).input.B)
    (accepted : CheckAccept.checkProgramAccepted q A p = .ok ()) :
    (CheckPreparation.prepare q p).program.WellTyped
      (CheckPreparation.prepare q p).input.B (CheckPreparation.prepare q p).input.opPrim ∧
    CheckAccept.Accepted A q p ∧
    (meaning q p).WellFormed ∧ (meaning q p).WellTyped (CheckPreparation.prepare q p).input.B ∧
      (meaning q p).EffectsOk (CheckPreparation.prepare q p).input.B := by
  obtain ⟨typed, ranges⟩ := CheckAccept.checkProgramAccepted_empty (q := q) (p := p) (A := A)
    (CheckPreparation.prepare_sound hq p) (CheckTables.prepare_names hn) hd hi
    (CheckTables.prepare_impl_names him) hD ha accepted
  exact ⟨typed, ranges, desugar_typed hw typed hvalues⟩

end
end Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
