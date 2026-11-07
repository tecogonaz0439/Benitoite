import Benitoite.Release.Refinement.Surface.CheckPreparation
import Benitoite.Release.Refinement.StandardModelGeneral

/-! # 解決を有効にする表の標準行のlookup

完成表の合成済みの行は仮定側の行より先に選ぶ。内部行を重ねる構成では、
接頭辞又は未登録性の証拠から同じ標準行を保持する。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateProjection StandardModel
noncomputable section

private theorem primitive_composed (row : Primitive) : row.name ∈ nameLists.composed := by
  apply nameLists_wf.composedAll row.name
  change (StandardModel.signature row.name).isSome = true
  simp only [signature,primitive_lookup,Option.map_some,Option.isSome_some]

/-- 判定行を持つ完成表は、その内容によらず合成済みの標準行を優先する。 -/
theorem table_lookup {P : Refinement.Program} (T : DataTable P) (rows : Table.Rows) :
    RowLookup (Table.builtins T rows) where
  valKind := rfl
  valContent := rfl
  admitsR := rfl
  sig row := by
    change (if row.name ∈ nameLists.composed then
      (primitive row.name).map (Primitive.signatureWith T.sat) else _) = _
    rw [ite_eq_left (primitive_composed row),primitive_lookup]
    rfl
  delta row noKeys := by
    change (if row.name ∈ nameLists.composed then
      (primitive row.name).elim (fun _ _ _ _ => none) (fun found => found.deltaWith T.keyNames row.name)
      else _) = _
    rw [ite_eq_left (primitive_composed row),primitive_lookup]
    exact congrFun (Primitive.deltaWith_of_not_readsKeys noKeys T.keyNames) row.name
  io row ts es vs outcome observed := by
    change ((if row.name ∈ nameLists.composed then
      T.base.ioResponse row.name else _) ts es vs outcome observed) ↔ _
    rw [ite_eq_left (primitive_composed row)]
    change (∃ found, primitive row.name = some found ∧
      found.provider.ioResponse row.name ts es vs outcome observed) ↔ _
    rw [primitive_lookup]
    simp

/-- 各標準名に内部行が無ければ、元の表の全標準行のlookupを保つ。 -/
theorem overlay_lookup {B : Builtins} (lookup : RowLookup B) (rows : Table.Rows)
    (absent : ∀ row : Primitive, rows.lookup row.name = none) :
    RowLookup (Check.predicateOverlay B rows) where
  valKind := lookup.valKind
  valContent := lookup.valContent
  admitsR := lookup.admitsR
  sig row := by
    change (match rows.lookup row.name with | some found => some found.signature | none => B.sig row.name) = _
    rw [absent row]
    exact lookup.sig row
  delta row noKeys := by
    funext ts es rs vs
    change (match rows.lookup row.name with
      | some found => found.delta ts es rs vs | none => B.delta row.name ts es rs vs) = _
    rw [absent row]
    exact congrFun (congrFun (congrFun (congrFun (lookup.delta row noKeys) ts) es) rs) vs
  io row ts es vs outcome observed := lookup.io row ts es vs outcome observed

private theorem primitive_no_prefix (row : Primitive) : row.name.startsWith "%Predicate." = false := by
  apply String.startsWith_string_eq_false_iff.mpr
  cases row <;> decide

private theorem prefixed_absent {rows : Table.Rows}
    (prefixed : rows.all (fun pair => pair.1.startsWith "%Predicate.") = true) (row : Primitive) :
    rows.lookup row.name = none := by
  cases selected : rows.lookup row.name with
  | none => rfl
  | some entry =>
    have present := ScopeSignatures.lookup_mem selected
    have hasPrefix := List.all_eq_true.mp prefixed (row.name,entry) present
    rw [primitive_no_prefix row] at hasPrefix
    cases hasPrefix

/-- 実入口が解決を有効にする入力は、構成データから標準行のlookupを供給する。 -/
theorem source_lookup {source : Check.BuiltinSource} (active : CheckPreparation.enabled source = true) :
    RowLookup source.builtins := by
  induction source with
  | custom _ | unrestrictedRanges _ => cases active
  | standard P B built => subst built; exact RowLookup.builtins P
  | predicates data rows B built => subst built; exact table_lookup data rows
  | resolved base rows ih =>
    obtain ⟨enabled,prefixed⟩ := Bool.and_eq_true_iff.mp active
    exact overlay_lookup (ih enabled) rows (prefixed_absent prefixed)

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
