import Benitoite.Release.Refinement.ApproxAdapter
namespace RV
open Benitoite Benitoite.Interval Benitoite.Release.Refinement
-- ∃ n の値が定数の値に等しいことまで言えるか
theorem const_value {B : Builtins} {n : Int} (k : IntKind)
    (bounded : k.min ≤ n ∧ n ≤ k.max) :
    (Shared.ApproxValue.ofInt k n) = .integer k ⟨n, bounded⟩ :=
  Shared.ApproxValue.ofInt_bounded k ⟨n, bounded⟩

-- ∃ n だけの言明は、値を変える写しでも成り立つ（言明が値を固定しないことの確認）
def wrong : Const → Shared.ApproxValue
  | .integer8 _ => .integer .integer8 ⟨0, by decide⟩
  | c => c.toApprox

example {B : Builtins} {c : Const} {k : IntKind} (ok : ConstOK B c)
    (kindOf : IntKind.ofRefinementType c.type = some k) :
    ∃ n : IntegerValue k, wrong c = .integer k n := by
  cases c
  case integer8 n =>
    simp [Const.type, IntKind.ofRefinementType] at kindOf
    subst kindOf
    exact ⟨⟨0, by decide⟩, rfl⟩
  all_goals exact constOK_toApprox ok kindOf
end RV
