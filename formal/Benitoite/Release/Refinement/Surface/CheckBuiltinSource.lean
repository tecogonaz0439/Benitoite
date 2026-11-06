import Benitoite.Release.Refinement.StandardModelCoreRows

/-! # 検査器が使う組込みの表の構成元 -/
namespace Benitoite.Release.Refinement.Surface.Check

/-- 組込みの表の構成元。標準表はその宣言データから構成した表を、構成の等号とともに持つ。
表を値として持つので、選んだ表を読む検査は実行できる。 -/
inductive BuiltinSource where
  | custom (table : Builtins)
  | standard (program : Refinement.Program) (table : Builtins := StandardModel.builtins program)
      (built : table = StandardModel.builtins program := by rfl)
  | unrestrictedRanges (table : Builtins)

def BuiltinSource.builtins : BuiltinSource → Builtins
  | .custom B => B
  | .standard _ B _ => B
  | .unrestrictedRanges B => { B with admitsR := fun _ _ => True }

end Benitoite.Release.Refinement.Surface.Check
