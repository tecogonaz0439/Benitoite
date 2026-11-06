import Benitoite.Release.Refinement.StringMembership
import Benitoite.Release.Refinement.Typing

namespace Benitoite.Release.Refinement.F2Resume2Evidence
open Scope.Domain

/-- 結果の Boolean と所属の真偽の一致。self は番号0、対象は番号1である。 -/
def agreement (p : Pred) : Pred :=
  .or (.and (.compare .boolean .eq (.var 0) (.boolean true)) p)
    (.and (.not (.compare .boolean .eq (.var 0) (.boolean true))) (.not p))

/-- 値引数の置換は所属の対象を変えるが、範囲を変えない。 -/
theorem member_range_fixed (ν : ObservationEnv) (k : Kind) (t : Term) (r : RangeExpr) :
    predBind ν (.member k t r) = .member k (termBind ν t) r := rfl

/-- 述語に書いた範囲の列も値の置換では変わらない。 -/
def memberRanges : Pred → List RangeExpr
  | .member _ _ r => [r]
  | .and p q | .or p q => memberRanges p ++ memberRanges q
  | .not p => memberRanges p
  | _ => []

theorem memberRanges_bind (ν : ObservationEnv) (p : Pred) :
    memberRanges (predBind ν p) = memberRanges p := by
  induction p <;> simp_all [predBind, memberRanges]

/-- 同じ置換は charactersIn の対象だけを変え、リテラルの端を変えない。 -/
theorem character_bounds_fixed (ν : ObservationEnv) (t : Term) (lo hi : Char) :
    predBind ν (.charactersIn t lo hi) = .charactersIn (termBind ν t) lo hi := rfl

/-- 同じ対象を検査する二つの絶対形のリテラルは、反対の正常な結果を持つ。 -/
theorem two_literal_results :
    parseAbsolutePathPattern "/" = some (.exact []) ∧
    parseAbsolutePathPattern "/x" = some (.exact ["x"]) ∧
    stringMember .path (.path (.exact [])) "/" = true ∧
    stringMember .path (.path (.exact ["x"])) "/" = false := by
  simp +decide [parseAbsolutePathPattern, parseAtInput, parseTargetInput,
    splitText, splitChars, PathWordWF]

/-- いずれの呼出しにも使う String 引数は、同じ型の正常値である。 -/
theorem inputs_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (pattern : String) :
    HasTypeVsQ P B Ψ Qempty [] [] []
      [.const (.string pattern), .const (.string "/")] [.base .string, .base .string] :=
  .cons (.V_Const trivial) (.cons (.V_Const trivial) .nil)

/-- 結果・対象・pattern の順の同時置換。 -/
def arguments (b : Bool) (pattern : String) : ObservationEnv
  | 0 => some (.boolean b)
  | 1 => some (.string "/")
  | _ => some (.string pattern)

/-- 一つの固定範囲を置いた結果の篩は、二つのリテラルの正常応答に同時には一致しない。
これはこの結果型の案への反例であり、任意の表現方式の不可能性は主張しない。 -/
theorem fixed_range_result_obstruction (r : RangeExpr) :
    ¬ ((predBind (arguments true "/") (agreement (.member .path (.var 1) r))).interpret
          (fun _ => none) = true ∧
       (predBind (arguments false "/x") (agreement (.member .path (.var 1) r))).interpret
          (fun _ => none) = true) := by
  simp [agreement, predBind, termBind, termBind?, arguments, Pred.interpret,
    Pred.atomValue, observeAs, Term.interpret, Observation.sort, Observation.compare,
    Comparison.fromEqLt]

/-- 閉じた評価は String の真偽を保ち、二つの所属の整形式も満たす。 -/
theorem closed_results :
    (Pred.member .path (.string "/") (.path (.exact []))).evalClosed = some true ∧
    (Pred.member .path (.string "/") (.path (.exact ["x"]))).evalClosed = some false := by
  decide

end Benitoite.Release.Refinement.F2Resume2Evidence
