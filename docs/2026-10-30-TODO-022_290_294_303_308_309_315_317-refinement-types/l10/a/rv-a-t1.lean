import Benitoite.Interval.BudgetNormal
import Benitoite.Release.Refinement.ApproxAdapter
namespace RV
open Benitoite Benitoite.Interval

-- 中心定理から共有層の ResultMem への合成
theorem compose {Models : AbstractEnv → ConcreteEnv → Prop}
    (hs : NormalSoundness Models BudgetAnalysis.analyze)
    {abstract concrete input} {params : BudgetAnalysis.Parameters} {value trace}
    (ret : Shared.ValueApprox)
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.normal value) trace) :
    ((BudgetAnalysis.analyzeExpr params.limits params.state params.fuel abstract input.key input.source).sharedFlow
      input.type ret).ResultMem (E := Failure) (EvalOutcome.toApprox (.normal value)) := by
  have h := hs abstract concrete input params value trace models eval
  exact BudgetAnalysis.Report.shared_normal _ _ _ h

-- possible の一致
theorem possible_agrees (t : Release.Ty) (r : NormalRange t) :
    (normalToShared t r).possible = normalPossible t r := by
  cases t with
  | base b =>
    cases b <;> first
      | (cases r <;> rfl)
      | (cases (show Bool from r) <;> rfl)
      | skip
  | _ => cases (show Bool from r) <;> rfl

private def run (source : Surface.Expr) : BudgetAnalysis.Report :=
  BudgetAnalysis.analyzeExpr {} {} 5 (AbstractEnv.ofLocals []) ⟨"Boundary.shared", 0⟩ source

private def retUnit : Surface.Expr := .returnE (.base .unit) (.literal (.integer ⟨7, by decide⟩))

-- 正常値のない Unit の return: 旧の正常域は空を保つが、baseToShared は unknown
example : (run retUnit).approx.live = false := by cbv
example : (run retUnit).approx.other = false := by cbv
example : (run retUnit).coverage = .complete := by cbv
-- 任意の Report で Unit の normal は可能と判定される（実データを読まない）
example (r : BudgetAnalysis.Report) : (r.sharedFlow (.base .unit) .bottom).normal.possible = true := rfl
example : (normalToShared (.base .unit) false).possible = false := rfl

-- flag を読む精密化が健全であること
def preciseToShared (type : Release.Ty) (b : BaseApprox) : Shared.ValueApprox :=
  match IntKind.ofType type with
  | some kind => .integer kind (b.rangeKind kind)
  | none => match type with
    | .base .boolean => .boolean b.boolean.1 b.boolean.2
    | _ => bif (b.other && b.nonIntegerOther) then .unknown else .bottom

theorem precise_mem {b : BaseApprox} {value : ConcreteValue} (h : b.Contains value) :
    (preciseToShared value.type b).Mem value.toApprox := by
  cases value with
  | boolean t => exact (by cases t <;>
      simpa [preciseToShared, ConcreteValue.type, IntKind.ofType, ConcreteValue.toApprox,
        Shared.ValueApprox.Mem, BaseApprox.Contains] using h)
  | integer n => exact ⟨rfl, h⟩
  | integer8 n => exact ⟨rfl, h.2⟩
  | integer16 n => exact ⟨rfl, h.2⟩
  | integer32 n => exact ⟨rfl, h.2⟩
  | unsignedInteger16 n => exact ⟨rfl, h.2⟩
  | unsignedInteger32 n => exact ⟨rfl, h.2⟩
  | unsignedInteger64 n => exact ⟨rfl, h.2⟩
  | unit =>
    have h' : b.other = true ∧ b.nonIntegerOther = true := h
    simp [preciseToShared, ConcreteValue.type, IntKind.ofType, h'.1, h'.2, Shared.ValueApprox.Mem]
  | other t nI nB nU =>
    have h' : b.other = true ∧ b.nonIntegerOther = true := h
    simp only [preciseToShared, ConcreteValue.type, ConcreteValue.toApprox, nI, h'.1, h'.2]
    cases t with
    | base base => cases base <;> first | exact absurd rfl nB | trivial
    | _ => trivial
  | rangeError _ _ _ =>
    have h' : b.other = true ∧ b.nonIntegerOther = true := h
    simp [preciseToShared, ConcreteValue.type, IntKind.ofType, h'.1, h'.2, Shared.ValueApprox.Mem]
  | con _ _ _ _ =>
    have h' : b.other = true ∧ b.nonIntegerOther = true := h
    simp [preciseToShared, ConcreteValue.type, IntKind.ofType, h'.1, h'.2, Shared.ValueApprox.Mem]

#print axioms precise_mem

-- report_width の実出力は一点か
private def u64src : Surface.Expr := .literal (.unsignedInteger64 18446744073709551615)
#eval match (run u64src).approx.rangeKind .unsignedInteger64 with
  | .bottom => "bottom" | .closed l h _ => s!"{l} {h}"
#eval match (run u64src).approx.rangeKind .integer32 with
  | .bottom => "bottom" | .closed l h _ => s!"{l} {h}"

-- 文書: Byte / Decimal の範囲外
example (B) : ¬ Release.Refinement.ConstOK B (.byte 256) := by simp [Release.Refinement.ConstOK]
example (B) : ¬ Release.Refinement.ConstOK B (.decimal 1 29) := by simp [Release.Refinement.ConstOK]
example (B) : Release.Refinement.ConstOK B (.decimal (-79228162514264337593543950335) 28) := by
  simp [Release.Refinement.ConstOK]
example (B) : ¬ Release.Refinement.ConstOK B (.decimal (-79228162514264337593543950336) 0) := by
  simp [Release.Refinement.ConstOK]
end RV
