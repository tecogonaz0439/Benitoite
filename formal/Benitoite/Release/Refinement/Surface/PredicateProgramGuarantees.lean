import Benitoite.Release.Refinement.Surface.PredicateProgramSemantics
import Benitoite.Release.Refinement.Surface.PredicateOverlayValues

/-! # 標準表を持つ公開ソースの受理と性質1 -/
namespace Benitoite.Release.Refinement.Surface.PredicateProgramGuarantees
noncomputable section

/-- 標準表の値の四条件を構成し、実入口の受理を同じ解決後の核へ接続する。 -/
theorem accepted_standard_property1 {q : Check.Input} {p : Program} {A : CheckAccept.AcceptInput}
    {base : Refinement.Program} (source : q.builtinSource = .standard base)
    (hq : q.Sound) (hn : CheckTables.NamesComplete q p)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d →
      CheckDeclarations.DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id →
      CheckDeclarations.ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, p.impls n = some id → CheckDeclarations.ImplNamesComplete q id)
    (hD : (CheckPreparation.prepare q p).input.D = (CheckPreparation.prepare q p).program.declarations)
    (ha : CheckAccept.NamesComplete q p)
    (hw : (CheckPreparation.prepare q p).program.WellFormed)
    (accepted : CheckAccept.checkProgramAccepted q A p = .ok ()) :
    (CheckPreparation.prepare q p).program.WellTyped
      (CheckPreparation.prepare q p).input.B (CheckPreparation.prepare q p).input.opPrim ∧
    CheckAccept.Accepted A q p ∧
    (PredicateProgramSemantics.meaning q p).WellFormed ∧
    (PredicateProgramSemantics.meaning q p).WellTyped (CheckPreparation.prepare q p).input.B ∧
    (PredicateProgramSemantics.meaning q p).EffectsOk (CheckPreparation.prepare q p).input.B :=
  PredicateProgramSemantics.accepted_property1 hq hn hd hi him hD ha hw
    (PredicateOverlayValues.prepared_standard_values _ base p source) accepted

end
end Benitoite.Release.Refinement.Surface.PredicateProgramGuarantees
