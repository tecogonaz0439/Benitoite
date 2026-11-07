import Benitoite.Release.Refinement.Surface.PredicateOverlayExternal

/-! # 判定の内部行を重ねた表と完成表の欄の対応 -/
namespace Benitoite.Release.Refinement.Surface.PredicateOverlayTable
open PredicateProjection
noncomputable section

private theorem row_opEff (row : Row) : row.signature.opEff = none := by
  cases row <;> rfl

private theorem assumedOps_empty (rows : Table.Rows) (effect : EffName) :
    StandardModel.assumedOps (Table.names rows) (Table.assumed rows) effect = [] := by
  apply List.filter_eq_nil_iff.mpr
  intro name member
  change ¬ (((rows.lookup name).map Row.signature).bind PrimSig.opEff == some effect) = true
  cases selected : rows.lookup name with
  | none => intro impossible; cases impossible
  | some row => simp [row_opEff]

private theorem member_assumed {rows : Table.Rows} {name : PrimName} {row : Row}
    (found : rows.lookup name = some row) : name ∈ (Table.names rows).assumed := by
  have member := ScopeSignatures.lookup_mem found
  have names := List.mem_map_of_mem (f := Prod.fst) member
  simp only [Table.names, StandardModel.NameLists.assumed, List.mem_append]
  exact Or.inl (Or.inl (Or.inr names))

private theorem base_eq {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Table.Rows}
    (valid : rows.Valid P) :
    Check.predicateOverlay (StandardModel.completeBase (Table.names []) T (Table.assumed [])) rows =
      StandardModel.completeBase (Table.names rows) T (Table.assumed rows) := by
  have signatures : (Check.predicateOverlay (StandardModel.completeBase (Table.names []) T (Table.assumed [])) rows).sig =
      (StandardModel.completeBase (Table.names rows) T (Table.assumed rows)).sig := by
    funext name
    cases selected : rows.lookup name with
    | none =>
      simp [Check.predicateOverlay, selected, StandardModel.completeBase, Table.names,
        Table.assumed, Table.lookup]
    | some row =>
      have member := ScopeSignatures.lookup_mem selected
      have fresh := (valid.2 _ _ member).1
      have assumed := member_assumed selected
      simp only [Check.predicateOverlay, selected]
      change some row.signature = if name ∈ StandardModel.nameLists.composed then _ else _
      rw [ite_eq_right fresh]
      change some row.signature = if name ∈ (Table.names rows).assumed then _ else _
      simp only [ite_eq_left assumed, Table.assumed, Table.lookup, selected, Option.map_some]
  have deltas : (Check.predicateOverlay (StandardModel.completeBase (Table.names []) T (Table.assumed [])) rows).delta =
      (StandardModel.completeBase (Table.names rows) T (Table.assumed rows)).delta := by
    funext name types effects ranges values
    cases selected : rows.lookup name with
    | none =>
      simp [Check.predicateOverlay, selected, StandardModel.completeBase, Table.names, Table.assumed, Table.lookup]
      rfl
    | some row =>
      have fresh := (valid.2 _ _ (ScopeSignatures.lookup_mem selected)).1
      simp [Check.predicateOverlay, selected, StandardModel.completeBase, Table.names, Table.assumed, Table.lookup, fresh]
  have effects : (StandardModel.completeBase (Table.names []) T (Table.assumed [])).effects =
      (StandardModel.completeBase (Table.names rows) T (Table.assumed rows)).effects := by
    funext label
    change (match T.base.effects label with
      | some names => some (names ++ StandardModel.assumedOps (Table.names []) (Table.assumed []) label)
      | none => if StandardModel.assumedOps (Table.names []) (Table.assumed []) label = [] then none else _) = _
    simp only [assumedOps_empty]
    change (match T.base.effects label with | some names => some (names ++ []) | none => none) = _
    change _ = (match T.base.effects label with
      | some names => some (names ++ StandardModel.assumedOps (Table.names rows) (Table.assumed rows) label)
      | none => if StandardModel.assumedOps (Table.names rows) (Table.assumed rows) label = [] then none else _)
    simp only [assumedOps_empty, ite_true]
  unfold Check.predicateOverlay StandardModel.completeBase
  congr 1


private theorem builtins_eq_of_response {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Table.Rows}
    (valid : rows.Valid P)
    (agreement : ExternalModel.response P (StandardModel.completeBase (Table.names []) T (Table.assumed [])) =
      ExternalModel.response P (StandardModel.completeBase (Table.names rows) T (Table.assumed rows))) :
    Check.predicateOverlay (Table.builtins T []) rows = Table.builtins T rows := by
  have release : (Table.builtins T []).releaseResponse = (Table.builtins T rows).releaseResponse := by
    funext value reason
    have resources := congrArg Builtins.isResource (base_eq T valid)
    change (ResourceRelease.response (StandardModel.completeBase (Table.names []) T (Table.assumed [])).isResource value reason ∨ False) =
      (ResourceRelease.response (StandardModel.completeBase (Table.names rows) T (Table.assumed rows)).isResource value reason ∨ False)
    change (StandardModel.completeBase (Table.names []) T (Table.assumed [])).isResource =
      (StandardModel.completeBase (Table.names rows) T (Table.assumed rows)).isResource at resources
    rw [resources]
  unfold Table.builtins StandardModel.complete
  rw [← base_eq T valid]
  unfold ExternalModel.builtins Check.predicateOverlay
  congr 1
  change ExternalModel.response P (StandardModel.completeBase (Table.names []) T (Table.assumed [])) =
    ExternalModel.response P (Check.predicateOverlay (StandardModel.completeBase (Table.names []) T (Table.assumed [])) rows)
  rw [base_eq T valid]
  exact agreement



/-- 整形式な外部ABIの下で、内部行の重ね合わせは同じ行を登録した完成表に一致する。 -/
theorem builtins_eq {P : Refinement.Program} (T : StandardModel.DataTable P) {rows : Table.Rows}
    (valid : rows.Valid P) (formed : P.WellFormed) :
    Check.predicateOverlay (Table.builtins T []) rows = Table.builtins T rows := by
  apply builtins_eq_of_response T valid
  funext function types values outcome observations
  exact propext (PredicateOverlayExternal.response_eq formed T.valid rfl rfl rfl)

end
end Benitoite.Release.Refinement.Surface.PredicateOverlayTable
