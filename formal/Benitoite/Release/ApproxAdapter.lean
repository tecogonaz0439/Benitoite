import Benitoite.Release.Syntax
import Benitoite.Shared.Approximation

/-! 旧 Release の値から、整数と Boolean だけを読む共有近似への写し。 -/
namespace Benitoite.Release

def Const.toApprox : Const → Shared.ApproxValue
  | .integer n => .integer .integer64 n
  | .integer8 n => .ofInt .integer8 n
  | .integer16 n => .ofInt .integer16 n
  | .integer32 n => .ofInt .integer32 n
  | .unsignedInteger16 n => .ofInt .unsignedInteger16 n
  | .unsignedInteger32 n => .ofInt .unsignedInteger32 n
  | .unsignedInteger64 n => .ofInt .unsignedInteger64 n
  | .boolean b => .boolean b
  | _ => .other

def Val.toApprox : Val → Shared.ApproxValue
  | .const c => c.toApprox
  | _ => .other

end Benitoite.Release
