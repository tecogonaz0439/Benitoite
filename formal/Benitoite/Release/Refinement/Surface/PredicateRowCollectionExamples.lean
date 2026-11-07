import Benitoite.Release.Refinement.Surface.PredicateRowCollection

/-! # 元のソースからの収集と同じ表による解決の適用例 -/
namespace Benitoite.Release.Refinement.Surface.PredicateRowCollectionExamples
open PredicateRows PredicateProjection PredicateRowCollection
noncomputable section

private def program : Program where
  defs := fun _ => none
  cons := fun _ => none

private def entry : Entry := .floating .binary64 .finite

private def source : Expr :=
  .call (.primName "Float.isFinite" [] [] []) [none] [0] (.cons (.local 0) .nil)

private theorem selected : candidate program source = some (.scalar entry) := by cbv

/-- 元の呼出しから選んだ同じ行が、生成した表の実lookupに存在する。 -/
theorem contains : ∃ key, (forExpr program source).lookup key = some (.scalar entry) :=
  forExpr_contains (source := source) (by change source ∈ source :: _; exact List.mem_cons_self) selected

/-- 本体の元の呼出しも、本体から収集した同じ表に登録する。 -/
theorem contains_block : ∃ key, (forBlock program (.last source)).lookup key = some (.scalar entry) :=
  forBlock_contains (source := .last source)
    (by change source ∈ source :: _; exact List.mem_cons_self) selected

/-- 表の意味の条件と標準名との非衝突を、同じソースの収集から構成する。 -/
theorem valid : Table.Rows.Valid (StandardModel.program []) (forExpr program source) := by
  apply collect_valid
  intro occurrence member row chosen
  change occurrence ∈ [source, .primName "Float.isFinite" [] [] [], .local 0] at member
  simp only [List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with rfl | rfl | rfl
  · rw [selected] at chosen
    cases chosen
    trivial
  · cases chosen
  · cases chosen

private def prepared : PreparedExpr := prepareExpr program source

/-- 自動収集した番号の行と、その同じ番号への解決を一つの結果に保つ。 -/
theorem prepared_expr :
    prepared.rows = [("%Predicate.0", .scalar entry)] ∧
    prepared.source = .partialCall (.primName "%Predicate.0" [] [] []) []
      (.expr none 0 (.local 0) .nil) (entry.result (.var 1)) Eff.empty := by
  constructor <;> cbv

/-- 本体の入口も、同じソースから収集した表で内部呼出しを作る。 -/
theorem prepared_block :
    (prepareBlock program (.last source)).rows = prepared.rows ∧
    (prepareBlock program (.last source)).source = .last prepared.source := by
  constructor <;> cbv

end
end Benitoite.Release.Refinement.Surface.PredicateRowCollectionExamples
