import Benitoite.Release.Refinement.StandardModelCoreRows

/-! # 検査器が使う組込みの表の構成元 -/
namespace Benitoite.Release.Refinement.Surface.Check

/-- 組込みの表の構成元。標準表はその宣言データから構成する。 -/
inductive BuiltinSource where
  | custom (table : Builtins)
  | standard (program : Refinement.Program)
  | unrestrictedRanges (table : Builtins)

def BuiltinSource.builtins : BuiltinSource → Builtins
  | .custom B => B
  | .standard P => StandardModel.builtins P
  | .unrestrictedRanges B => { B with admitsR := fun _ _ => True }

end Benitoite.Release.Refinement.Surface.Check
