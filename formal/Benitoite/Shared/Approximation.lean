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

/-- 正常値が一つでも属しうるか。空を表す三つの形を区別せず判定する。 -/
def ValueApprox.possible : ValueApprox → Bool
  | .bottom => false
  | .integer _ .bottom => false
  | .integer _ (.closed _ _ _) => true
  | .boolean mayFalse mayTrue => mayFalse || mayTrue
  | .unknown => true

/-- 空の表現を制限せず、閉区間の証拠に記した値域と順序を確認する。 -/
def ValueApprox.WF : ValueApprox → Prop
  | .integer kind (.closed lo hi _) => kind.min ≤ lo ∧ lo ≤ hi ∧ hi ≤ kind.max
  | _ => True

def FlowApprox.WF (a : FlowApprox) : Prop := a.normal.WF ∧ a.returned.WF

theorem ValueApprox.wf (a : ValueApprox) : a.WF := by
  cases a with
  | integer kind interval => cases interval with
    | bottom => trivial
    | closed _ _ valid => exact valid
  | _ => trivial

theorem FlowApprox.wf (a : FlowApprox) : a.WF := ⟨a.normal.wf, a.returned.wf⟩

/-- 可能性の判定は、近似へ属する値の存在と一致する。 -/
theorem ValueApprox.possible_iff (a : ValueApprox) :
    a.possible = true ↔ ∃ v, a.Mem v := by
  cases a with
  | bottom =>
    simp [possible, Mem]
  | integer kind interval =>
    cases interval with
    | bottom =>
      simp only [possible, Bool.false_eq_true, false_iff]
      rintro ⟨v, hv⟩
      cases v <;> simp_all [Mem, Benitoite.Interval.Mem]
    | closed lo hi valid =>
      exact ⟨fun _ => ⟨.integer kind ⟨lo, by omega⟩, rfl, Int.le_refl _, valid.2.1⟩,
        fun _ => rfl⟩
  | boolean f t =>
    cases f <;> cases t
    case false.false =>
      simp only [possible, Bool.or_false, Bool.false_eq_true, false_iff]
      rintro ⟨v, hv⟩
      cases v with
      | boolean b => cases b <;> simp [Mem] at hv
      | integer k n => exact hv
      | other => exact hv
    case false.true => exact ⟨fun _ => ⟨.boolean true, rfl⟩, fun _ => rfl⟩
    case true.false => exact ⟨fun _ => ⟨.boolean false, rfl⟩, fun _ => rfl⟩
    case true.true => exact ⟨fun _ => ⟨.boolean true, rfl⟩, fun _ => rfl⟩
  | unknown => exact ⟨fun _ => ⟨.other, trivial⟩, fun _ => rfl⟩

theorem ValueApprox.not_possible_iff (a : ValueApprox) :
    a.possible = false ↔ ∀ v, ¬ a.Mem v := by
  constructor
  · intro empty v inside
    have := a.possible_iff.mpr ⟨v, inside⟩
    simp_all
  · intro empty
    cases hp : a.possible with
    | false => rfl
    | true =>
      obtain ⟨v, inside⟩ := a.possible_iff.mp hp
      exact False.elim (empty v inside)

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
