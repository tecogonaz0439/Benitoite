import Benitoite.Interval.Range

/-!
# 直接引数の固定の定義域

シフト量の契約を、読み込み済みの標準宣言に付ける。
定義域との不交差だけを判定し、シフト結果の値を保証しない
（設計書 01-12「区間解析の直接引数と固定の定義域」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

/-- Byte は算術の整数七種へ加えず、シフトの対象としてだけ区別する。 -/
inductive ShiftOperand where
  | integer (kind : IntKind)
  | byte
  deriving DecidableEq, Repr

/-- シフトの値の型。シフト量の型は、いずれの場合も Integer64 である。 -/
def ShiftOperand.type : ShiftOperand → Ty
  | .integer kind => kind.type
  | .byte => .base .byte

/-- 言語の幅を使い、ホストの整数幅には依存しない。 -/
def ShiftOperand.width : ShiftOperand → Nat
  | .integer .integer8 | .byte => 8
  | .integer .integer16 | .integer .unsignedInteger16 => 16
  | .integer .integer32 | .integer .unsignedInteger32 => 32
  | .integer .integer64 | .integer .unsignedInteger64 => 64

/-- 符号付きの右シフトと区別する、標準関数の三つの操作。 -/
inductive ShiftOperation where
  | left | right | rightUnsigned
  deriving DecidableEq, Repr

/-- 固定表のキーは API の役割であり、宣言の同一性は別に渡す。 -/
inductive FixedDomainApi where
  | shift (operand : ShiftOperand) (operation : ShiftOperation)
  deriving DecidableEq, Repr

/-- 契約上の引数位置・名前・正常域。ソース順の引数番号とは区別する。 -/
structure FixedDomainContract where
  argument : Nat
  parameters : List String
  lo : Int
  hi : Int
  ordered : lo ≤ hi

/-- 存在しない unsigned/Byte.shiftRightUnsigned の規則を表から作らない。 -/
def FixedDomainApi.contract : FixedDomainApi → Option FixedDomainContract
  | .shift .byte .rightUnsigned => none
  | .shift (.integer kind) .rightUnsigned =>
      if kind.min < 0 then
        some ⟨1, ["a", "n"], 0, (ShiftOperand.integer kind).width - 1,
          by cases kind <;> decide⟩
      else none
  | .shift operand _ =>
      match operand with
      | .byte => some ⟨1, ["a", "n"], 0, 7, by decide⟩
      | .integer kind => some ⟨1, ["a", "n"], 0,
          (ShiftOperand.integer kind).width - 1, by cases kind <;> decide⟩
/-- シフトの正常結果はシフトする値と同じ型である。 -/
def FixedDomainApi.resultType (api : FixedDomainApi) : Ty :=
  match api with
  | .shift operand _ => operand.type
/-- 他の引数はそれぞれの型を保つ。全引数を Integer とみなさない。 -/
def FixedDomainApi.argumentTypes : FixedDomainApi → List Ty
  | .shift operand _ => [operand.type, .base .integer]
/-- 正常域は既存の評価関係の定義へ付ける。δ や公理の前提にしない。 -/
def FixedDomainContract.rule (contract : FixedDomainContract) (result : Ty) : StandardRule :=
  .fixedDomain contract.argument contract.lo contract.hi result

/-- 宣言名を推測・追加ロードせず、読み込み済み宣言に評価規則を付ける。 -/
def FixedDomainApi.binding (api : FixedDomainApi) (declaration : FunName)
    : Option StandardBinding := do
  let contract ← api.contract
  pure ⟨declaration, contract.rule (api.resultType), api.argumentTypes⟩

/-- 空の正常区間には重ねて警告しない。非空なら二端点の比較だけで判定する。 -/
def FixedDomainContract.disjoint (contract : FixedDomainContract) : Interval → Bool
  | .bottom => false
  | .closed lo hi _ => decide (hi < contract.lo ∨ contract.hi < lo)

/-- 不交差と判定した区間に属する正常整数は、すべて契約の外にある。 -/
theorem fixed_disjoint_outside {contract : FixedDomainContract} {normal : Interval} {value : Int}
    (disjoint : contract.disjoint normal = true) (member : Mem value normal) :
    ¬ (contract.lo ≤ value ∧ value ≤ contract.hi) := by
  cases normal with
  | bottom => contradiction
  | closed lo hi valid =>
    simp only [FixedDomainContract.disjoint, decide_eq_true_eq] at disjoint
    simp only [Mem] at member
    omega

/-- 非空の二つの閉区間について、端点の不交差判定は交差の不存在と一致する。 -/
theorem fixed_disjoint_iff (contract : FixedDomainContract) (lo hi : Int)
    (valid : min64 ≤ lo ∧ lo ≤ hi ∧ hi ≤ max64) :
    contract.disjoint (Interval.closed (kind := .integer64) lo hi valid) = true ↔
      ¬ ∃ value, Mem value (Interval.closed (kind := .integer64) lo hi valid) ∧ contract.lo ≤ value ∧ value ≤ contract.hi := by
  simp only [FixedDomainContract.disjoint, decide_eq_true_eq, Mem]
  have ordered := contract.ordered
  constructor
  · rintro outside ⟨value, member, inside⟩; omega
  · intro absent
    by_cases left : hi < contract.lo
    · exact Or.inl left
    by_cases right : contract.hi < lo
    · exact Or.inr right
    exact False.elim (absent ⟨max lo contract.lo, ⟨by omega, by omega⟩, by omega, by omega⟩)

/-- 正常域の外で可能な結果は outsideDomain による拒否だけである。 -/
theorem fixed_outside_result {contract : FixedDomainContract} {result key args value output}
    (atPosition : args[contract.argument]? = some (.integer value))
    (outside : ¬ (contract.lo ≤ value.toInt ∧ value.toInt ≤ contract.hi))
    (evaluated : EvalStandard (contract.rule result) key args output) :
    output = .rejected .outsideDomain := by
  cases evaluated with
  | domainNormal _ _ _ _ _ _ other _ found inside _ =>
    have same : other = value := by simpa [atPosition] using found.symm
    subst other; exact False.elim (outside inside)
  | domainOtherFailure _ _ _ _ _ _ other found inside =>
    have same : other = value := by simpa [atPosition] using found.symm
    subst other; exact False.elim (outside inside)
  | domainRejected => rfl

/-- 任意の正常整数に導出が残る。正常域の内側も他の失敗を許す。 -/
theorem fixed_evaluation_total (contract : FixedDomainContract) (result key args value)
    (atPosition : args[contract.argument]? = some (.integer value)) :
    ∃ output, EvalStandard (contract.rule result) key args output := by
  by_cases inside : contract.lo ≤ value.toInt ∧ value.toInt ≤ contract.hi
  · exact ⟨.rejected .unknown, .domainOtherFailure _ _ _ _ _ _ _ atPosition inside⟩
  · exact ⟨.rejected .outsideDomain, .domainRejected _ _ _ _ _ _ _ atPosition inside⟩

/-- 正常な結果がある場合だけ、その結果の型と引数の正常域への所属を得る。 -/
theorem fixed_normal_inside {contract : FixedDomainContract} {result key args value output}
    (atPosition : args[contract.argument]? = some (.integer value))
    (evaluated : EvalStandard (contract.rule result) key args (.normal output)) :
    contract.lo ≤ value.toInt ∧ value.toInt ≤ contract.hi ∧ output.type = result := by
  cases evaluated with
  | domainNormal _ _ _ _ _ _ other _ found inside typed =>
    have same : other = value := by simpa [atPosition] using found.symm
    subst other; exact ⟨inside.1, inside.2, typed⟩

/-- 左シフトで捨てるビットを算術のあふれへ読み替えない。 -/
theorem fixed_not_overflow {contract : FixedDomainContract} {result key args}
    (evaluated : EvalStandard (contract.rule result) key args (.rejected .overflow)) : False := by
  cases evaluated

/-- 警告位置に到達して得た引数と、抽象区間の不交差から拒否理由を得る。 -/
theorem fixed_disjoint_rejected {contract : FixedDomainContract} {normal : Interval}
    {result key args value output}
    (disjoint : contract.disjoint normal = true) (member : Mem value.toInt normal)
    (atPosition : args[contract.argument]? = some (.integer value))
    (evaluated : EvalStandard (contract.rule result) key args output) :
    output = .rejected .outsideDomain :=
  fixed_outside_result atPosition (fixed_disjoint_outside disjoint member) evaluated

/-- 標準束縛の同定から式の失敗までを、評価規則の内側で合成する。 -/
theorem fixed_at_disjoint_failed {env : ConcreteEnv} {key args outcome binding}
    {contract : FixedDomainContract} {normal : Interval} {result value}
    (identified : env.standardAt key = some binding)
    (rule : binding.rule = contract.rule result)
    (disjoint : contract.disjoint normal = true) (member : Mem value.toInt normal)
    (atPosition : args[contract.argument]? = some (.integer value))
    (evaluated : EvalStandardAt env key args outcome) : outcome = .failed .outsideDomain := by
  cases evaluated with
  | apply other output found evaluated =>
    have same : other = binding := by simpa [identified] using found.symm
    subst other
    rw [rule] at evaluated ⊢
    rw [fixed_disjoint_rejected disjoint member atPosition evaluated]
    rfl

end Benitoite.Interval
