import Benitoite.Release.Refinement.StandardModelCoreRows
import Benitoite.Release.Refinement.Surface.PredicateProjectionTable

/-! # 検査器が使う組込みの表の構成元 -/
namespace Benitoite.Release.Refinement.Surface.Check

/-- 組込みの表の構成元。標準表と、判定の内部行を加えた標準表は、その宣言データから構成した表を、構成の等号とともに
持つ。名前解決した内部行は、元の構成元の表へ重ねる。 -/
inductive BuiltinSource where
  | custom (table : Builtins)
  | standard (program : Refinement.Program) (table : Builtins := StandardModel.builtins program)
      (built : table = StandardModel.builtins program := by rfl)
  | unrestrictedRanges (table : Builtins)
  | predicates {program : Refinement.Program} (data : StandardModel.DataTable program)
      (rows : PredicateProjection.Table.Rows)
      (table : Builtins := PredicateProjection.Table.builtins data rows)
      (built : table = PredicateProjection.Table.builtins data rows := by rfl)
  | resolved (base : BuiltinSource) (rows : PredicateProjection.Table.Rows)

/-- 公開の表の全欄を保ち、名前解決した内部行の署名と純粋な応答だけを加える。 -/
def predicateOverlay (base : Builtins) (rows : PredicateProjection.Table.Rows) : Builtins :=
  { base with
    sig := fun name => match rows.lookup name with
      | some row => some row.signature
      | none => base.sig name
    delta := fun name ts es rs vs => match rows.lookup name with
      | some row => row.delta ts es rs vs
      | none => base.delta name ts es rs vs }

def BuiltinSource.builtins : BuiltinSource → Builtins
  | .custom B => B
  | .standard _ B _ => B
  | .resolved base rows => predicateOverlay base.builtins rows
  | .predicates _ _ B _ => B
  | .unrestrictedRanges B => { B with admitsR := fun _ _ => True }

end Benitoite.Release.Refinement.Surface.Check
