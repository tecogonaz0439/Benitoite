import Benitoite.Shared.Interval

/-!
# 正常値と明示 return の共有近似

数値の領域だけを読み、項・具体評価・失敗理由・警告には依存しない。
正常値と関数からの戻り値は、別々の成分で所属を検査する。
-/
namespace Benitoite.Shared

open Benitoite.Interval (IntKind IntegerValue)

inductive ValueApprox where
  | bottom
  | integer (kind : IntKind) (interval : Benitoite.Interval.Interval kind)
  | boolean (mayFalse mayTrue : Bool)
  | unknown

inductive ApproxValue where
  | integer (kind : IntKind) (value : IntegerValue kind)
  | boolean (value : Bool)
  | other

structure FlowApprox where
  normal : ValueApprox
  returned : ValueApprox
  mayFail : Bool

inductive EvalResult (V E : Type) where
  | normal (value : V)
  | returned (value : V)
  | failed (reason : E)

/-- 整数は幅も一致する場合にだけ所属する。未知値は全種類を含む。 -/
def ValueApprox.Mem : ValueApprox → ApproxValue → Prop
  | .bottom, _ => False
  | .unknown, _ => True
  | .integer kind interval, .integer other value =>
      other = kind ∧ Benitoite.Interval.Mem value.toInt interval
  | .boolean mayFalse mayTrue, .boolean value =>
      (if value then mayTrue else mayFalse) = true
  | _, _ => False

def FlowApprox.NormalMem (flow : FlowApprox) (value : ApproxValue) : Prop :=
  flow.normal.Mem value

def FlowApprox.ReturnedMem (flow : FlowApprox) (value : ApproxValue) : Prop :=
  flow.returned.Mem value

/-- 失敗理由の内容を共有層へ持ち込まず、三つの結果を分けて照合する。 -/
def FlowApprox.ResultMem {E : Type} (flow : FlowApprox) : EvalResult ApproxValue E → Prop
  | .normal value => flow.NormalMem value
  | .returned value => flow.ReturnedMem value
  | .failed _ => flow.mayFail = true

/-- 非有界な旧定数は、表現可能性を捏造せず観測しない値へ写す。 -/
def ApproxValue.ofInt (kind : IntKind) (value : Int) : ApproxValue :=
  if bounded : kind.min ≤ value ∧ value ≤ kind.max then
    .integer kind ⟨value, bounded⟩
  else .other

@[simp] theorem ApproxValue.ofInt_bounded (kind : IntKind) (value : IntegerValue kind) :
    ofInt kind value.toInt = .integer kind value := by
  unfold ofInt
  split
  · rfl
  · rename_i h
    exact False.elim (h value.property)

@[simp] theorem ApproxValue.ofInt_outside {kind : IntKind} {value : Int}
    (h : ¬ (kind.min ≤ value ∧ value ≤ kind.max)) : ofInt kind value = .other := by
  simp only [ofInt, dite_eq_right h]

@[simp] theorem ValueApprox.mem_bottom (value : ApproxValue) :
    ¬ ValueApprox.bottom.Mem value := id

@[simp] theorem ValueApprox.mem_unknown (value : ApproxValue) :
    ValueApprox.unknown.Mem value := trivial

@[simp] theorem ValueApprox.mem_integer (kind : IntKind)
    (interval : Benitoite.Interval.Interval kind) (value : IntegerValue kind) :
    (ValueApprox.integer kind interval).Mem (.integer kind value) ↔
      Benitoite.Interval.Mem value.toInt interval := by
  simp only [Mem, true_and]

/-- 同じ変換を使っても、normal と returned の構成子を保つ。 -/
def EvalResult.map {V W E F : Type} (value : V → W) (failure : E → F) :
    EvalResult V E → EvalResult W F
  | .normal v => .normal (value v)
  | .returned v => .returned (value v)
  | .failed e => .failed (failure e)

@[simp] theorem EvalResult.map_id {V E : Type} (result : EvalResult V E) :
    result.map id id = result := by cases result <;> rfl

end Benitoite.Shared
