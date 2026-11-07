import Benitoite.Release.Refinement.StandardModelCoreRows
import Benitoite.Release.Refinement.Surface.PredicateProjectionTable

/-! # 検査器が使う組込みの表の構成元 -/
namespace Benitoite.Release.Refinement.Surface.Check

/-- 組込みの表の構成元。標準行と判定の内部行は、その宣言データから構成する。 -/
inductive BuiltinSource where
  | custom (table : Builtins)
  | standard (program : Refinement.Program)
  | unrestrictedRanges (table : Builtins)
  | predicates {program : Refinement.Program} (data : StandardModel.DataTable program)
      (rows : PredicateProjection.Table.Rows)
  | resolved (base : BuiltinSource) (rows : PredicateProjection.Table.Rows)

/-- 公開の表の全欄を保ち、名前解決した内部行の署名と純粋な応答だけを加える。 -/
noncomputable def predicateOverlay (base : Builtins) (rows : PredicateProjection.Table.Rows) : Builtins :=
  { base with
    sig := fun name => match rows.lookup name with
      | some row => some row.signature
      | none => base.sig name
    delta := fun name ts es rs vs => match rows.lookup name with
      | some row => row.delta ts es rs vs
      | none => base.delta name ts es rs vs }

noncomputable def BuiltinSource.builtins : BuiltinSource → Builtins
  | .custom B => B
  | .standard P => StandardModel.builtins P
  | .resolved base rows => predicateOverlay base.builtins rows
  | .predicates data rows => PredicateProjection.Table.builtins data rows
  | .unrestrictedRanges B => { B with admitsR := fun _ _ => True }

end Benitoite.Release.Refinement.Surface.Check
