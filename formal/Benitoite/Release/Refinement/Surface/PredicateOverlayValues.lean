import Benitoite.Release.Refinement.Surface.CheckPreparation
import Benitoite.Release.Refinement.StandardModelSubstitution

/-! # 判定の内部行を重ねた表の値の置換条件

制約の欄は標準表と同じであり、追加行の許容は型引数の個数だけを読む。
型付き像から別の表への型付けを仮定せず、四つの保存則を直接構成する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateOverlayValues
noncomputable section
open PredicateProjection

private theorem row_admits_map (row : Row) (C : List TParam) (types : List Ty) (f : Ty → Ty)
    (allowed : row.signature.admits C types) : row.signature.admits C (types.map f) := by
  cases row with
  | scalar entry =>
    change types = [] at allowed
    simp only [allowed, List.map_nil]
    rfl
  | projected projection =>
    change types.length = projection.ntys at allowed
    change (types.map f).length = projection.ntys
    simpa only [List.length_map] using allowed

/-- 任意の内部行の追加は、標準表の値改名と値置換の四条件を保つ。 -/
theorem standard_values (P base : Refinement.Program) (rows : Table.Rows) :
    Builtins.ValueAssumptions P (Check.predicateOverlay (StandardModel.builtins base) rows) where
  sat_rename := by
    intro C Γ Δ a p ξ _ _ _ h
    exact (ModelConstraints.sat_rename _ _ a p ξ).mpr h
  admits_rename := by
    intro name signature C Γ Δ types ξ found _ _ _ allowed
    change (match rows.lookup name with
      | some row => some row.signature | none => (StandardModel.builtins base).sig name) = some signature at found
    cases selected : rows.lookup name with
    | some row =>
      simp only [selected, Option.some.injEq] at found
      subst signature
      exact row_admits_map row _ _ _ allowed
    | none =>
      simp only [selected] at found
      obtain ⟨row, _, _, rfl⟩ := (StandardModel.builtins_lookup_iff base name signature).mp found
      have allowed' : (row.signatureWith (ModelConstraints.sat StandardModel.summaries)).admits (TypeCtx.constraints C) types := by
        simpa only [show row.signatureWith (ModelConstraints.sat StandardModel.summaries) = row.signature from StandardModel.Primitive.signatureWith_base row] using allowed
      simpa only [show row.signatureWith (ModelConstraints.sat StandardModel.summaries) = row.signature from StandardModel.Primitive.signatureWith_base row] using
        StandardModel.admits_rename_with StandardModel.summaries row ξ allowed'
  sat_values := by
    intro Ψ Q C Γ Δ Ξ ν a p _ _ h
    exact (ModelConstraints.sat_values _ _ a p ν).mpr h
  admits_values := by
    intro name signature Ψ Q C Γ Δ Ξ ν types found _ _ allowed
    change (match rows.lookup name with
      | some row => some row.signature | none => (StandardModel.builtins base).sig name) = some signature at found
    cases selected : rows.lookup name with
    | some row =>
      simp only [selected, Option.some.injEq] at found
      subst signature
      exact row_admits_map row _ _ _ allowed
    | none =>
      simp only [selected] at found
      obtain ⟨row, _, _, rfl⟩ := (StandardModel.builtins_lookup_iff base name signature).mp found
      have allowed' : (row.signatureWith (ModelConstraints.sat StandardModel.summaries)).admits (TypeCtx.constraints C) types := by
        simpa only [show row.signatureWith (ModelConstraints.sat StandardModel.summaries) = row.signature from StandardModel.Primitive.signatureWith_base row] using allowed
      simpa only [show row.signatureWith (ModelConstraints.sat StandardModel.summaries) = row.signature from StandardModel.Primitive.signatureWith_base row] using
        StandardModel.admits_values_with StandardModel.summaries row ν allowed'

/-- data宣言の要約を持つ完成表でも、内部行の追加は同じ値の四条件を保つ。 -/
theorem predicates_values (P : Refinement.Program) {base : Refinement.Program}
    (T : StandardModel.DataTable base) (previous rows : Table.Rows) :
    Builtins.ValueAssumptions P (Check.predicateOverlay (Table.builtins T previous) rows) where
  sat_rename := by
    intro C Γ Δ a p ξ _ _ _ h
    exact (ModelConstraints.sat_rename _ _ a p ξ).mpr h
  admits_rename := by
    intro name signature C Γ Δ types ξ found _ _ _ allowed
    change (match rows.lookup name with
      | some row => some row.signature | none => (Table.builtins T previous).sig name) = some signature at found
    cases selected : rows.lookup name with
    | some row =>
      simp only [selected, Option.some.injEq] at found
      subst signature
      exact row_admits_map row _ _ _ allowed
    | none =>
      simp only [selected] at found
      rcases Table.lookup_cases T found with ⟨row, _, rfl⟩ | ⟨row, _, rfl⟩
      · exact StandardModel.admits_rename_with _ row ξ allowed
      · exact row_admits_map row _ _ _ allowed
  sat_values := by
    intro Ψ Q C Γ Δ Ξ ν a p _ _ h
    exact (ModelConstraints.sat_values _ _ a p ν).mpr h
  admits_values := by
    intro name signature Ψ Q C Γ Δ Ξ ν types found _ _ allowed
    change (match rows.lookup name with
      | some row => some row.signature | none => (Table.builtins T previous).sig name) = some signature at found
    cases selected : rows.lookup name with
    | some row =>
      simp only [selected, Option.some.injEq] at found
      subst signature
      exact row_admits_map row _ _ _ allowed
    | none =>
      simp only [selected] at found
      rcases Table.lookup_cases T found with ⟨row, _, rfl⟩ | ⟨row, _, rfl⟩
      · exact StandardModel.admits_values_with _ row ν allowed
      · exact row_admits_map row _ _ _ allowed


/-- 標準表を持つ実入力は、準備後も任意の核プログラムに対する値の四条件を満たす。 -/
theorem prepared_standard_values (P base : Refinement.Program) {q : Check.Input} (p : Program)
    (source : q.builtinSource = .standard base) :
    Builtins.ValueAssumptions P (CheckPreparation.prepare q p).input.B := by
  rcases CheckPreparation.prepare_cases q p with same | ⟨rows, same⟩
  · rw [same]
    change Builtins.ValueAssumptions P q.B
    have h := standard_values P base []
    simpa only [Check.Input.B, source, Check.BuiltinSource.builtins, Check.predicateOverlay,
      List.lookup_nil] using h
  · rw [same]
    change Builtins.ValueAssumptions P (Check.predicateOverlay q.B rows)
    simpa only [Check.Input.B, source, Check.BuiltinSource.builtins] using standard_values P base rows


/-- 完成表を持つ実入力の準備も、型付き像への新たな仮定なしに値の四条件を満たす。 -/
theorem prepared_predicates_values (P : Refinement.Program) {base : Refinement.Program}
    (T : StandardModel.DataTable base) (previous : Table.Rows) {q : Check.Input} (p : Program)
    (source : q.builtinSource = .predicates T previous) :
    Builtins.ValueAssumptions P (CheckPreparation.prepare q p).input.B := by
  rcases CheckPreparation.prepare_cases q p with same | ⟨rows, same⟩
  · rw [same]
    change Builtins.ValueAssumptions P q.B
    have h := predicates_values P T previous []
    simpa only [Check.Input.B, source, Check.BuiltinSource.builtins, Check.predicateOverlay, List.lookup_nil] using h
  · rw [same]
    change Builtins.ValueAssumptions P (Check.predicateOverlay q.B rows)
    simpa only [Check.Input.B, source, Check.BuiltinSource.builtins] using predicates_values P T previous rows

end
end Benitoite.Release.Refinement.Surface.PredicateOverlayValues
