import Benitoite.Interval.TypeAdapter

/-!
# 整数の閉区間の互換入口

数値の定義と補題は Shared.Interval、旧 Release 型との対応は TypeAdapter に置く。
既存の import と公開名を保つ。
-/
namespace Benitoite.Interval
open Benitoite.Release (min64 max64)

-- 独立した十進の端点で、七種のTopが過大にも過小にもならないことを確かめる。
-- Byteは型の認定の対象外とし、Integerの別名に別の種類を作らない。
example :
    ([ (IntKind.integer8, -128, 127), (.integer16, -32768, 32767),
       (.integer32, -2147483648, 2147483647),
       (.integer64, -9223372036854775808, 9223372036854775807),
       (.unsignedInteger16, 0, 65535), (.unsignedInteger32, 0, 4294967295),
       (.unsignedInteger64, 0, 18446744073709551615) ] : List (IntKind × Int × Int)).all
      (fun (kind, lo, hi) => decide (
        Mem lo (top kind) ∧ Mem hi (top kind) ∧
        ¬ Mem (lo - 1) (top kind) ∧ ¬ Mem (hi + 1) (top kind) ∧
        normalize (lo - 1) (hi + 1) kind = top kind ∧
        normalize (lo - 2) (lo - 1) kind = .bottom ∧
        normalize (hi + 1) (hi + 2) kind = .bottom)) = true ∧
    IntKind.ofType (.base .byte) = none ∧
    IntKind.ofType (.base .integer) = some .integer64 := by decide +kernel

-- 独立期待値で、空・一点・両端・凸な合流による穴の消失を確かめる。
example : normalize 2 1 = .bottom ∧ meet (normalize (-2) (-1)) (normalize 1 2) =
    .bottom := by decide

example : Mem 7 (normalize 7 7) ∧ ¬ Mem 6 (normalize 7 7) ∧
    ¬ Mem 8 (normalize 7 7) := by decide

example : meet (normalize (-2) 0) (normalize 0 3) = normalize 0 0 ∧
    Subset (normalize 0 0) (normalize (-2) 3) ∧
    ¬ Subset (normalize (-2) 3) (normalize 0 0) ∧ Subset .bottom top := by decide

example : Mem min64 top ∧ Mem max64 top ∧
    normalize (min64 - 1) (max64 + 1) = top ∧
    normalize (max64 + 1) (max64 + 2) = .bottom ∧
    normalize (min64 - 2) (min64 - 1) = .bottom := by decide

example : join (normalize (-2) (-1)) (normalize 1 2) = normalize (-2) 2 ∧
    Mem 0 (join (normalize (-2) (-1)) (normalize 1 2)) ∧
    ¬ Mem 0 (normalize (-2) (-1)) ∧ ¬ Mem 0 (normalize 1 2) := by decide

end Benitoite.Interval
