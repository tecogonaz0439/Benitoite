import Benitoite.Release.Refinement.TermSyntax

/-! # 有限の項と述語の構成的な構造比較

既存のDecidableEqを置き換えず、snapshotのnoneとスロットの順序を保つ。
-/
namespace Benitoite.Release.Refinement

mutual
  def termEq : Term → Term → Bool
    | .var a0, .var b0 => decide (a0 = b0)
    | .integer a0, .integer b0 => decide (a0 = b0)
    | .character a0, .character b0 => decide (a0 = b0)
    | .float64 a0, .float64 b0 => decide (a0 = b0)
    | .float32 a0, .float32 b0 => decide (a0 = b0)
    | .decimal a0 a1, .decimal b0 b1 => decide (a0 = b0) && decide (a1 = b1)
    | .boolean a0, .boolean b0 => decide (a0 = b0)
    | .unitValue , .unitValue  => true
    | .string a0, .string b0 => decide (a0 = b0)
    | .listValue a0, .listValue b0 => slotsEq a0 b0
    | .bytesValue a0, .bytesValue b0 => decide (a0 = b0)
    | .mapValue a0 a1, .mapValue b0 b1 => slotsEq a0 b0 && slotsEq a1 b1
    | .setValue a0, .setValue b0 => slotsEq a0 b0
    | .dataValue a0 a1, .dataValue b0 b1 => decide (a0 = b0) && slotsEq a1 b1
    | .targetValue a0 a1, .targetValue b0 b1 => decide (a0 = b0) && decide (a1 = b1)
    | .field a0 a1, .field b0 b1 => decide (a0 = b0) && termEq a1 b1
    | .measure a0 a1, .measure b0 b1 => decide (a0 = b0) && termEq a1 b1
    | .add a0 a1, .add b0 b1 => termEq a0 b0 && termEq a1 b1
    | .neg a0, .neg b0 => termEq a0 b0
    | .scale a0 a1, .scale b0 b1 => decide (a0 = b0) && termEq a1 b1
    | _, _ => false
  def slotEq : Option Term → Option Term → Bool
    | none, none => true
    | some a, some b => termEq a b
    | _, _ => false
  def slotsEq : List (Option Term) → List (Option Term) → Bool
    | [], [] => true
    | a::as, b::bs => slotEq a b && slotsEq as bs
    | _, _ => false
end

mutual
  theorem termEq_spec (t u : Term) : termEq t u = true ↔ t = u := by
    cases t <;> cases u <;>
      simp [termEq, termEq_spec, slotsEq_spec, Bool.and_eq_true]
  theorem slotEq_spec (a b : Option Term) : slotEq a b = true ↔ a = b := by
    cases a <;> cases b <;> simp [slotEq, termEq_spec]
  theorem slotsEq_spec (as bs : List (Option Term)) : slotsEq as bs = true ↔ as = bs := by
    cases as <;> cases bs <;> simp [slotsEq, slotEq_spec, slotsEq_spec, Bool.and_eq_true]
end

def predEq : Pred → Pred → Bool
  | .truth , .truth  => true
  | .falsity , .falsity  => true
  | .eq a0 a1, .eq b0 b1 => termEq a0 b0 && termEq a1 b1
  | .le a0 a1, .le b0 b1 => termEq a0 b0 && termEq a1 b1
  | .lt a0 a1, .lt b0 b1 => termEq a0 b0 && termEq a1 b1
  | .compare a0 a1 a2 a3, .compare b0 b1 b2 b3 => decide (a0 = b0) && decide (a1 = b1) && termEq a2 b2 && termEq a3 b3
  | .floatClass a0 a1 a2, .floatClass b0 b1 b2 => decide (a0 = b0) && decide (a1 = b1) && termEq a2 b2
  | .decimalRepresented a0, .decimalRepresented b0 => termEq a0 b0
  | .charactersIn a0 a1 a2, .charactersIn b0 b1 b2 => termEq a0 b0 && decide (a1 = b1) && decide (a2 = b2)
  | .member a0 a1 a2, .member b0 b1 b2 => decide (a0 = b0) && termEq a1 b1 && decide (a2 = b2)
  | .constructorIs a0 a1, .constructorIs b0 b1 => termEq a0 b0 && decide (a1 = b1)
  | .and a0 a1, .and b0 b1 => predEq a0 b0 && predEq a1 b1
  | .or a0 a1, .or b0 b1 => predEq a0 b0 && predEq a1 b1
  | .not a0, .not b0 => predEq a0 b0
  | _, _ => false

theorem predEq_spec (p q : Pred) : predEq p q = true ↔ p = q := by
  cases p <;> cases q <;> simp [predEq, termEq_spec, predEq_spec, Bool.and_eq_true, and_assoc]

end Benitoite.Release.Refinement
