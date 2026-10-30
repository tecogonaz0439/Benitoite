import Benitoite.Surface.Lemmas.Typing

/- 本番のリテラル・desugarExpr・shapeAt のAPIが一致する部分を使う代表。
   元: Surface/Syntax.lean:53-88, Typing.lean:196-198,
   Desugar.lean:228-240, Lemmas/Typing.lean:522,
   Release/Typing.lean:528,616、Assumptions.lean:59-63。
   新しい型付けの葉だけを独立に縮め、本番の主定理を書き換えない。 -/
namespace P3bBoundary
open Benitoite.Release
open Benitoite.Surface
set_option maxHeartbeats 200000

def ConstOK (B : Builtins) : Const → Prop
  | .integer8 n => -128 ≤ n ∧ n ≤ 127
  | .integer16 n => -32768 ≤ n ∧ n ≤ 32767
  | .integer32 n => -2147483648 ≤ n ∧ n ≤ 2147483647
  | .unsignedInteger16 n => 0 ≤ n ∧ n ≤ 65535
  | .unsignedInteger32 n => 0 ≤ n ∧ n ≤ 4294967295
  | .unsignedInteger64 n => 0 ≤ n ∧ n ≤ 18446744073709551615
  | .byte n => n ≤ 255
  | .decimal n scale => -(2^96-1 : Int) ≤ n ∧ n ≤ 2^96-1 ∧ scale ≤ 28
  | .opaque o _ => B.valKind o = none
  | _ => True

def LiteralOK : Literal → Prop
  | .integer8 n => n ≤ 127
  | .integer16 n => n ≤ 32767
  | .integer32 n => n ≤ 2147483647
  | .unsignedInteger16 n => n ≤ 65535
  | .unsignedInteger32 n => n ≤ 4294967295
  | .unsignedInteger64 n => n ≤ 18446744073709551615
  | .byte n => n ≤ 255
  | .decimal n scale => -(2^96-1 : Int) ≤ n ∧ n ≤ 2^96-1 ∧ scale ≤ 28
  | _ => True

theorem literal_toConst_ok (B : Builtins) (l : Literal) (h : LiteralOK l) : ConstOK B l.toConst := by
  cases l <;> simp only [LiteralOK] at h <;> simp only [Literal.toConst, ConstOK, Int.ofNat_eq_natCast]
  all_goals first | exact h | trivial | omega

-- 強める新しいcoreの定数の葉とreturnだけの写し。
inductive CheckedReturn (B : Builtins) : Comp → Ty → Prop where
  | const {c} : ConstOK B c → CheckedReturn B (.ret (.const c)) c.type

inductive CheckedLiteral (B : Builtins) : Benitoite.Surface.Expr → Ty → Prop where
  | literal {l} : LiteralOK l → CheckedLiteral B (.literal l) l.toConst.type
  | neg8 {n : Nat} : n ≤ 128 → CheckedLiteral B (.negInteger8 n) (.base .integer8)

theorem literal_desugar_preserves {B : Builtins} {e : Benitoite.Surface.Expr} {a : Ty}
    (opPrim : OpPrim) (p : Position) (h : CheckedLiteral B e a) :
    CheckedReturn B (desugarExpr opPrim p e) a := by
  cases h with
  | literal h => exact .const (literal_toConst_ok B _ h)
  | neg8 h =>
    apply CheckedReturn.const
    change -128 ≤ -(Int.ofNat _) ∧ -(Int.ofNat _) ≤ 127
    simp only [Int.ofNat_eq_natCast]
    omega

theorem old_surface_integer8_128 (D : Declarations) (B : Builtins) (opPrim : OpPrim) :
    HasTypeQ D B opPrim Qempty [] [] [] none .other (.literal (.integer8 128))
      (.base .integer8) Eff.empty := .E_Literal

example : ¬ LiteralOK (.integer8 128) := by change ¬ (128 : Nat) ≤ 127; decide
example (B : Builtins) : CheckedLiteral B (.negInteger8 128) (.base .integer8) := .neg8 (by decide)

-- 対象のある呼出しではshapeAtの旧Topへの分岐は選ばれない。
theorem shapeAt_of_target {s : PrimSig} {k : Benitoite.Scope.Domain.Kind} {pos : Nat}
    {ws : List Val} {v : Val} {t : Benitoite.Scope.Domain.Target}
    (hs : s.shape = .single k pos) (hv : ws[pos]? = some v) (ht : v.target? = some t) :
    s.shapeAt ws = .single k pos := by
  simp [PrimSig.shapeAt, hs, hv, ht]

#print axioms literal_desugar_preserves
#print axioms shapeAt_of_target
end P3bBoundary
