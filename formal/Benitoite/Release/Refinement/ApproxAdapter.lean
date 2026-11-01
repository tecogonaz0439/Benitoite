import Benitoite.Release.Refinement.Embedding
import Benitoite.Release.ApproxAdapter
import Benitoite.Interval.TypeAdapter

/-!
# 並置体系から共有近似への写し

型と値の埋め込みが整数の幅と Boolean の観測を保つ。
この写しから篩の所属や状態の保存を仮定しない。
-/
namespace Benitoite.Release.Refinement

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

@[simp] theorem embedConst_toApprox (c : Benitoite.Release.Const) :
    (embedConst c).toApprox = c.toApprox := by cases c <;> rfl

@[simp] theorem embedVal_toApprox (v : Benitoite.Release.Val) :
    (embedVal v).toApprox = v.toApprox := by
  cases v <;> try rfl
  exact embedConst_toApprox _

end Benitoite.Release.Refinement

namespace Benitoite.Interval

def IntKind.refinementType (kind : IntKind) : Release.Refinement.Ty :=
  Release.Refinement.embedTy kind.type

def IntKind.ofRefinementType : Release.Refinement.Ty → Option IntKind
  | .base .integer8 => some .integer8
  | .base .integer16 => some .integer16
  | .base .integer32 => some .integer32
  | .base .integer => some .integer64
  | .base .unsignedInteger16 => some .unsignedInteger16
  | .base .unsignedInteger32 => some .unsignedInteger32
  | .base .unsignedInteger64 => some .unsignedInteger64
  | _ => none

@[simp] theorem IntKind.ofRefinementType_type (kind : IntKind) :
    ofRefinementType kind.refinementType = some kind := by cases kind <;> rfl

@[simp] theorem IntKind.ofRefinementType_embed (type : Release.Ty) :
    ofRefinementType (Release.Refinement.embedTy type) = ofType type := by
  cases type <;> try rfl
  rename_i b
  cases b <;> rfl

end Benitoite.Interval

namespace Benitoite.Release.Refinement

/-- 七整数の適格な定数は、同じ幅の証拠付き整数へ写る。 -/
theorem constOK_toApprox {B : Builtins} {c : Const} {k : Benitoite.Interval.IntKind}
    (ok : ConstOK B c)
    (kindOf : Benitoite.Interval.IntKind.ofRefinementType c.type = some k) :
    ∃ n : Benitoite.Interval.IntegerValue k, c.toApprox = .integer k n := by
  cases c <;> simp [Const.type, Benitoite.Interval.IntKind.ofRefinementType] at kindOf <;>
    subst kindOf
  case integer n => exact ⟨n, rfl⟩
  case integer8 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .integer8 ⟨n, ok⟩⟩
  case integer16 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .integer16 ⟨n, ok⟩⟩
  case integer32 n => exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .integer32 ⟨n, ok⟩⟩
  case unsignedInteger16 n =>
    exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .unsignedInteger16 ⟨n, ok⟩⟩
  case unsignedInteger32 n =>
    exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .unsignedInteger32 ⟨n, ok⟩⟩
  case unsignedInteger64 n =>
    exact ⟨⟨n, ok⟩, Shared.ApproxValue.ofInt_bounded .unsignedInteger64 ⟨n, ok⟩⟩

end Benitoite.Release.Refinement
