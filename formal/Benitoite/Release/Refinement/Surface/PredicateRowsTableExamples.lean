import Benitoite.Release.Refinement.Surface.PredicateRowsTable

/-! # 標準の表と内部の判定の行を使う適用例 -/
namespace Benitoite.Release.Refinement.Surface.PredicateRows.TableExamples
noncomputable section

def key : PrimName := "%Predicate.example.isFinite"

def entry : Entry := .floating .binary64 .finite

def rows : Rows := [(key, entry)]

private theorem composed_fresh : key ∉ StandardModel.nameLists.composed := by
  intro hm
  change key ∈ StandardModel.Primitive.all.map StandardModel.Primitive.name at hm
  obtain ⟨row, _, he⟩ := List.mem_map.mp hm
  have hn : row.name ≠ key := by cases row <;> decide
  exact hn he

/-- 内部名は各標準名との比較で非衝突を示し、長い行の一覧の評価を使わない。 -/
theorem valid : rows.Valid := by
  constructor
  · intro name candidate hm
    simp only [rows, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hm
    obtain ⟨rfl, rfl⟩ := hm
    trivial
  · intro name candidate hm
    simp only [rows, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at hm
    obtain ⟨rfl, rfl⟩ := hm
    exact ⟨composed_fresh, by decide, by decide, by decide, by decide⟩

def data : StandardModel.DataTable (StandardModel.program []) := StandardModel.dataTable []

def table : Builtins := builtins data rows

/-- 標準表を完成した同じ表で、内部の精密な署名を引く。 -/
theorem signature_lookup : table.sig key = some entry.signature :=
  lookup_signature data valid rfl

/-- 内部の全入力の応答の条件も、標準表の合成に含まれる。 -/
theorem conditions :
    table.CoreAssumptions (StandardModel.program []) ∧ table.TargetAgreement (StandardModel.program []) :=
  core data (StandardModel.Includes.refl []) valid

end
end Benitoite.Release.Refinement.Surface.PredicateRows.TableExamples
