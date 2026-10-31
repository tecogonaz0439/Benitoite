import Benitoite.Interval.Flow
import Benitoite.Shared.Approximation

/-!
# 独立評価と共有近似の対応

具体値・失敗理由・警告・キーは独立評価の側に残す。
旧 FlowApprox が保持しない戻り値の範囲は、変換の呼出し側が明示する。
-/
namespace Benitoite.Interval

def ConcreteValue.toApprox : ConcreteValue → Shared.ApproxValue
  | .integer n => .integer .integer64 n
  | .integer8 n => .integer .integer8 n
  | .integer16 n => .integer .integer16 n
  | .integer32 n => .integer .integer32 n
  | .unsignedInteger16 n => .integer .unsignedInteger16 n
  | .unsignedInteger32 n => .integer .unsignedInteger32 n
  | .unsignedInteger64 n => .integer .unsignedInteger64 n
  | .boolean b => .boolean b
  | _ => .other

@[simp] theorem ConcreteValue.ofInteger_toApprox (kind : IntKind) (n : IntegerValue kind) :
    (ConcreteValue.ofInteger kind n).toApprox = .integer kind n := by cases kind <;> rfl

def EvalOutcome.toShared : EvalOutcome → Shared.EvalResult ConcreteValue Failure
  | .normal v => .normal v
  | .returned v => .returned v
  | .failed e => .failed e

def EvalOutcome.ofShared : Shared.EvalResult ConcreteValue Failure → EvalOutcome
  | .normal v => .normal v
  | .returned v => .returned v
  | .failed e => .failed e

@[simp] theorem EvalOutcome.ofShared_toShared (outcome : EvalOutcome) :
    ofShared outcome.toShared = outcome := by cases outcome <;> rfl

@[simp] theorem EvalOutcome.toShared_ofShared (result : Shared.EvalResult ConcreteValue Failure) :
    (ofShared result).toShared = result := by cases result <;> rfl

def EvalOutcome.toApprox (outcome : EvalOutcome) : Shared.EvalResult Shared.ApproxValue Failure :=
  outcome.toShared.map ConcreteValue.toApprox id

/-- 旧解析の型付きの正常域を共有表現へ写す。型の一致は旧 NormalMem が検査する。 -/
def normalToShared (type : Release.Ty) (range : NormalRange type) : Shared.ValueApprox := by
  cases type with
  | base base =>
    cases base with
    | integer => exact .integer .integer64 range
    | boolean => exact .boolean range.1 range.2
    | _ => exact bif (range : Bool) then .unknown else .bottom
  | _ => exact bif (range : Bool) then .unknown else .bottom

theorem normalToShared_mem {type range value} (h : NormalMem type range value) :
    (normalToShared type range).Mem value.toApprox := by
  cases type with
  | base base =>
    cases base <;> cases value <;>
      simp_all [NormalMem, NormalContains, normalToShared, ConcreteValue.type,
        ConcreteValue.toApprox, Shared.ValueApprox.Mem, IntegerValue.toInt,
        Release.Integer64Value.toInt]
    rename_i truth
    cases truth <;> exact h
  | _ =>
    have hr : (range : Bool) = true := h.2
    simp only [normalToShared, hr, Shared.ValueApprox.Mem]
    trivial

def FlowApprox.toShared {type : Release.Ty} (flow : FlowApprox type)
    (returned : Shared.ValueApprox) : Shared.FlowApprox :=
  ⟨normalToShared type flow.normal, returned, flow.mayFail⟩

theorem FlowApprox.toShared_normal {type : Release.Ty} (flow : FlowApprox type)
    (returned : Shared.ValueApprox) {value : ConcreteValue}
    (h : NormalMem type flow.normal value) :
    (flow.toShared returned).NormalMem value.toApprox := normalToShared_mem h

@[simp] theorem FlowApprox.toShared_returned {type : Release.Ty} (flow : FlowApprox type)
    (returned : Shared.ValueApprox) (value : Shared.ApproxValue) :
    (flow.toShared returned).ReturnedMem value ↔ returned.Mem value := Iff.rfl

@[simp] theorem FlowApprox.toShared_mayFail {type : Release.Ty} (flow : FlowApprox type)
    (returned : Shared.ValueApprox) : (flow.toShared returned).mayFail = flow.mayFail := rfl

end Benitoite.Interval
