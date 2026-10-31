import Benitoite.Shared.Interval
import Benitoite.Release.Types

/-! 七種の整数と旧 Release 型の対応。数値の領域は型の層を読まない。 -/
namespace Benitoite.Interval

/-- 整数の別名は解決済みの型で同じinteger64に対応する。 -/
def IntKind.type : IntKind → Benitoite.Release.Ty
  | .integer8 => .base .integer8
  | .integer16 => .base .integer16
  | .integer32 => .base .integer32
  | .integer64 => .base .integer
  | .unsignedInteger16 => .base .unsignedInteger16
  | .unsignedInteger32 => .base .unsignedInteger32
  | .unsignedInteger64 => .base .unsignedInteger64

/-- 七種だけを認定し、Byteと整数以外の型を除外する。 -/
def IntKind.ofType : Benitoite.Release.Ty → Option IntKind
  | .base .integer8 => some .integer8
  | .base .integer16 => some .integer16
  | .base .integer32 => some .integer32
  | .base .integer => some .integer64
  | .base .unsignedInteger16 => some .unsignedInteger16
  | .base .unsignedInteger32 => some .unsignedInteger32
  | .base .unsignedInteger64 => some .unsignedInteger64
  | _ => none

@[simp] theorem IntKind.ofType_type (kind : IntKind) : ofType kind.type = some kind := by
  cases kind <;> rfl

end Benitoite.Interval
