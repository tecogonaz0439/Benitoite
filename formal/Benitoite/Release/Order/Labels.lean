import Benitoite.Release.Order.Atoms

/-!
# 型の木が持つラベル

構成子の順位、番号、名前、契約名の列、名前と行の所属関数を区別する。
文字列は Unicode スカラー値列の辞書式順で比較する。
型から木への写像を接続するための部品である（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release.Order

open Std

/-- 名前の辞書式比較。原子の符号順とは区別する。 -/
def stringCompare : String → String → Ordering := compareOn String.toList

instance : LawfulEqCmp stringCompare where
  compare_self := ReflCmp.compare_self (cmp := compareOn String.toList)
  eq_of_compare h := String.toList_inj.mp (LawfulEqOrd.eq_of_compare h)

instance : TransCmp stringCompare := inferInstanceAs (TransCmp (compareOn String.toList))

/-- 型構成子の順位とその欄を表すラベル。 -/
inductive Label where
  | rank (n : Nat)
  | nat (n : Nat)
  | text (s : String)
  | texts (ss : List String)
  | atoms (f : Atom → Bool)

private def Label.tag : Label → Nat
  | .rank _ => 0
  | .nat _ => 1
  | .text _ => 2
  | .texts _ => 3
  | .atoms _ => 4

/-- 同じ種類のラベルはその内容、異なる種類は宣言順で比較する。 -/
noncomputable def labelCompare : Label → Label → Ordering
  | .rank a, .rank b => compare a b
  | .nat a, .nat b => compare a b
  | .text a, .text b => stringCompare a b
  | .texts a, .texts b => List.compareLex stringCompare a b
  | .atoms a, .atoms b => atomsCompare a b
  | a, b => compare a.tag b.tag

instance : LawfulEqCmp labelCompare where
  compare_self {a} := by cases a <;> simp [labelCompare, ReflCmp.compare_self]
  eq_of_compare {a b} h := by
    cases a <;> cases b <;>
      simp only [labelCompare, Label.tag, LawfulEqCmp.compare_eq_iff_eq] at h <;>
      simp_all

instance : TransCmp labelCompare where
  eq_swap {a b} := by
    cases a <;> cases b <;>
      simp only [labelCompare, Label.tag] <;> first | exact OrientedCmp.eq_swap | rfl
  isLE_trans {a b c} hab hbc := by
    cases a <;> cases b <;> cases c <;>
      simp only [labelCompare, Label.tag] at hab hbc ⊢ <;>
      first | contradiction | exact TransCmp.isLE_trans hab hbc | trivial

end Benitoite.Release.Order
