import Benitoite.Release.Refinement.Surface.PredicateProjectionTable
import Benitoite.Release.Refinement.Surface.PredicateRowsTableExamples

/-! # scalar と欄の判定を受ける完成した表の具体の適用 -/
namespace Benitoite.Release.Refinement.Surface.PredicateProjection.TableExamples
noncomputable section

def rows : Table.Rows := Table.scalarRows PredicateRows.TableExamples.rows

theorem valid : rows.Valid (StandardModel.program []) :=
  Table.scalar_valid PredicateRows.TableExamples.valid

def table : Builtins := Table.builtins PredicateRows.TableExamples.data rows

theorem signature_lookup : table.sig PredicateRows.TableExamples.key =
    some PredicateRows.TableExamples.entry.signature := by
  exact Table.lookup_signature PredicateRows.TableExamples.data valid
    (name := PredicateRows.TableExamples.key) (entry := .scalar PredicateRows.TableExamples.entry) rfl

private theorem external_formed : (StandardModel.program []).ExternalWF := by
  refine ⟨by simp [StandardModel.program], ?_⟩
  intro key declaration member
  cases member

/-- 合成する行の和を使う表でも、同じ標準プログラムの全条件を内部で構成する。 -/
theorem conditions :
    table.CoreAssumptions (StandardModel.program []) ∧ table.TargetAgreement (StandardModel.program []) :=
  Table.core PredicateRows.TableExamples.data (StandardModel.Includes.refl []) valid
    (StandardModel.program_wellFormed [] external_formed)

end
end Benitoite.Release.Refinement.Surface.PredicateProjection.TableExamples
