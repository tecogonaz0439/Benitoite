import Benitoite.Release.Typing
/- 元: Release/Syntax.lean:145-182, Typing.lean:528,582-592。
値の表現を変えず、V_Constへ一つの前提を足す精密化の写し。
Decimalの係数96bit・scale28は、この試作の明示的な表現可能性の規則。
Float/float32の特殊値・丸めについて新しい主張を加えない。 -/
namespace P1Constants
open Benitoite.Release

def ConstOK (B : Builtins) : Const → Prop
  | .integer8 n => -128 ≤ n ∧ n ≤ 127
  | .integer16 n => -32768 ≤ n ∧ n ≤ 32767
  | .integer32 n => -2147483648 ≤ n ∧ n ≤ 2147483647
  | .unsignedInteger16 n => 0 ≤ n ∧ n ≤ 65535
  | .unsignedInteger32 n => 0 ≤ n ∧ n ≤ 4294967295
  | .unsignedInteger64 n => 0 ≤ n ∧ n ≤ 18446744073709551615
  | .byte n => n ≤ 255
  | .decimal n scale => -(2^96-1 : Int) ≤ n ∧ n ≤ (2^96-1 : Int) ∧ scale ≤ 28
  | .opaque o _ => B.valKind o = none
  | _ => True

-- 試作の新しい定数の葉。部分型・本体・状態へはまだ組み込んでいない。
inductive Leaf (B : Builtins) : Const → Prop where
  | V_Const {c} : ConstOK B c → Leaf B c

-- 元の規則が実際に範囲外の抽象値を型付けることを検査する。
-- Decimalの出どころ: crates/benitoite/src/base/decimal.rs:4-15 と 01-04「Decimal」。
theorem old_integer8_128 (P : Program) (B : Builtins) :
    HasTypeV P B StoreTy.empty [] [] (.const (.integer8 128)) (.base .integer8) := .V_Const

theorem reject_integer8_128 (B : Builtins) : ¬Leaf B (.integer8 128) := by
  intro h; cases h with | V_Const h => simp [ConstOK] at h

theorem bounded_integer8 (h : Leaf B (.integer8 n)) : -128 ≤ n ∧ n ≤ 127 := by
  cases h with | V_Const h => exact h

theorem byte_max (B : Builtins) : Leaf B (.byte 255) := .V_Const (by change 255 ≤ 255; decide)
theorem reject_byte_256 (B : Builtins) : ¬Leaf B (.byte 256) := by
  intro h; cases h with | V_Const h => exact (by decide : ¬256 ≤ 255) h

theorem decimal_scale (h : Leaf B (.decimal n scale)) : scale ≤ 28 := by
  cases h with | V_Const h => exact h.2.2

theorem reject_decimal_scale29 (B : Builtins) : ¬Leaf B (.decimal 0 29) := by
  intro h; have hs := decimal_scale h; omega

theorem reject_bare_target_top (B : Builtins) (o : OpaqueName)
    (htarget : B.valKind o = some kind) (id : Nat) : ¬Leaf B (.opaque o id) := by
  intro h
  cases h with | V_Const h => simp [ConstOK, htarget] at h

theorem keep_resource_opaque (B : Builtins) (o : OpaqueName)
    (hresource : B.valKind o = none) (id : Nat) : Leaf B (.opaque o id) := .V_Const hresource

-- bytesの葉も同じByteの条件を各要素へ要求する。
def BytesOK (xs : List Nat) := ∀ n ∈ xs, n ≤ 255
theorem bytes_ok_cons {xs : List Nat} {x : Nat} : BytesOK (x::xs) ↔ x ≤ 255 ∧ BytesOK xs := by
  simp [BytesOK]
theorem old_bare_opaque_top (P : Program) (B : Builtins) (o : OpaqueName) (id : Nat) :
    HasTypeV P B StoreTy.empty [] [] (.const (.opaque o id)) (.opaqueTop o) := .V_Const

-- 不変条件を保つ checked の葉は残る。Targetの所属は元の規則から得る。
theorem checked_still_typed (P : Program) (B : Builtins) {t : Benitoite.Scope.Domain.Target}
    {o : OpaqueName} {r : Benitoite.Scope.Domain.Range}
    (hk : B.valKind o = some t.kind) (hr : r.Mem t) :
    HasTypeV P B StoreTy.empty [] [] (.checked t) (.opaque o (.fixed r)) := .V_Checked hk hr

#print axioms bounded_integer8
#print axioms reject_bare_target_top
end P1Constants
