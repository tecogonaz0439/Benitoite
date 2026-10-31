import Benitoite
open Benitoite

namespace RV2
open Interval

/-- 型付きの幅付き定数は ConstOK から .integer へ写る（`.other` に落ちない）。 -/
theorem constOK_toApprox {B} {c : Release.Refinement.Const} {k : IntKind}
    (ok : Release.Refinement.ConstOK B c)
    (kindOf : IntKind.ofRefinementType c.type = some k) :
    ∃ n : IntegerValue k, c.toApprox = .integer k n := by
  cases c <;> simp [Release.Refinement.Const.type, IntKind.ofRefinementType] at kindOf <;> subst kindOf
  case integer n => exact ⟨n, rfl⟩
  case integer8 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .integer8 ⟨n, ok⟩⟩
  case integer16 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .integer16 ⟨n, ok⟩⟩
  case integer32 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .integer32 ⟨n, ok⟩⟩
  case unsignedInteger16 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .unsignedInteger16 ⟨n, ok⟩⟩
  case unsignedInteger32 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .unsignedInteger32 ⟨n, ok⟩⟩
  case unsignedInteger64 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .unsignedInteger64 ⟨n, ok⟩⟩

/-- 実解析の出力 BaseApprox は、入力の型を添えれば共有の ValueApprox へ写せる。 -/
def baseToShared (type : Release.Ty) (b : BaseApprox) : Shared.ValueApprox :=
  match IntKind.ofType type with
  | some k => .integer k (b.rangeKind k)
  | none => match type with
    | .base .boolean => .boolean b.boolean.1 b.boolean.2
    | _ => .unknown

theorem baseToShared_mem {b : BaseApprox} {value : ConcreteValue} (h : b.Contains value) :
    (baseToShared value.type b).Mem value.toApprox := by
  cases value with
  | boolean t => cases t <;> simpa [baseToShared, ConcreteValue.type, IntKind.ofType, ConcreteValue.toApprox, Shared.ValueApprox.Mem, BaseApprox.Contains] using h
  | integer n => exact ⟨rfl, h⟩
  | integer8 n => exact ⟨rfl, h.2⟩
  | integer16 n => exact ⟨rfl, h.2⟩
  | integer32 n => exact ⟨rfl, h.2⟩
  | unsignedInteger16 n => exact ⟨rfl, h.2⟩
  | unsignedInteger32 n => exact ⟨rfl, h.2⟩
  | unsignedInteger64 n => exact ⟨rfl, h.2⟩
  | unit => simp [baseToShared, ConcreteValue.type, IntKind.ofType, ConcreteValue.toApprox, Shared.ValueApprox.Mem]
  | other t nI nB nU =>
    have : ∀ r, (Shared.ValueApprox.unknown).Mem r := fun _ => trivial
    simp only [ConcreteValue.toApprox, ConcreteValue.type, baseToShared, nI]
    cases t with
    | base b => cases b <;> first | exact absurd rfl nB | trivial
    | _ => all_goals trivial
  | rangeError o n e => simp [baseToShared, ConcreteValue.type, IntKind.ofType, ConcreteValue.toApprox, Shared.ValueApprox.Mem]
  | con o ts n a => simp [baseToShared, ConcreteValue.type, IntKind.ofType, ConcreteValue.toApprox, Shared.ValueApprox.Mem]

end RV2
#print axioms RV2.constOK_toApprox
#print axioms RV2.baseToShared_mem
