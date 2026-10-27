import Benitoite.Interval.Eval

/-!
# 同じ Range 成功値の局所記録

整数の環境の対応を強めず、成功値の由来を通常位置と同じ番号で保持する。
（設計書 01-12「区間解析の同じ成功値の直接射影」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

/-- Rust の BindingId との対応に使う、現在の局所環境の束縛番号の土台。 -/
structure BindingScope where
  positions : List Nat
  nextId : Nat
  deriving DecidableEq, Repr

/-- de Bruijn の位置に対応する、現在の局所環境の束縛番号を読む。 -/
def BindingScope.idAt (scope : BindingScope) (index : Nat) : Option Nat :=
  scope.positions[index]?

/-- 通常・パターン・専用束縛は位置を作り、ワイルドカードはこの操作を呼ばない。 -/
def BindingScope.fresh (scope : BindingScope) : BindingScope :=
  ⟨scope.nextId :: scope.positions, scope.nextId + 1⟩

/-- 新しい値の番号は旧位置の番号を上書きしない。
Range の成功値も通常束縛と同じ番号の割り当てを使う。 -/
theorem BindingScope.fresh_idAt (scope : BindingScope) :
    scope.fresh.idAt 0 = some scope.nextId ∧
      ∀ index, scope.fresh.idAt (index + 1) = scope.idAt index := by
  exact ⟨rfl, fun _ => rfl⟩

/-- 既存の全番号が nextId 未満なら、新しい番号は既存番号と異なる。 -/
theorem BindingScope.fresh_distinct (scope : BindingScope)
    (valid : ∀ id ∈ scope.positions, id < scope.nextId) :
    scope.nextId ∉ scope.positions := by
  intro member
  have := valid _ member
  omega

/-- 新しい番号を追加した後も、次番号が現在の全番号より大きい条件が保たれる。 -/
theorem BindingScope.fresh_valid (scope : BindingScope)
    (valid : ∀ id ∈ scope.positions, id < scope.nextId) :
    ∀ id ∈ scope.fresh.positions, id < scope.fresh.nextId := by
  intro id member
  simp only [BindingScope.fresh, List.mem_cons] at member
  rcases member with same | old
  · subst id; exact Nat.lt_succ_self _
  · exact Nat.lt_trans (valid _ old) (Nat.lt_succ_self _)

/-- 固定端点と検査の呼び出しの同一性。成功した整数自体は抽象記録に保存しない。 -/
structure RangeOrigin where
  names : RangeNames
  checkKey : OperationKey
  minimum : Integer64Value
  maximum : Integer64Value

/-- 同じ標準規則と二端点の検査が返し得る Result を表す。
具体値との関係は呼び出しキーによらない。Ok の同定だけからは作らない。 -/
def RangeOrigin.ResultModels (origin : RangeOrigin) (result : ConcreteValue) : Prop :=
  ∃ value : Integer64Value,
    (StandardRule.rangeCheck origin.names).finish
      (rangeCheck origin.names origin.checkKey origin.minimum origin.maximum value) =
        .normal result

/-- 由来の二端点と成功値の実三欄・所属を対応させる。具体値との関係は
呼び出しキーによらない。キーは由来の認定と記録の側に、束縛番号は
RangeLocalFact に保持し、値そのものには入れない。 -/
def RangeOrigin.CheckedModels (origin : RangeOrigin) (value : ConcreteValue) : Prop :=
  ∃ number : Integer64Value,
    value = rangePayload origin.names.record origin.minimum origin.maximum number ∧
    Checked.Range.InRange origin.minimum.toInt origin.maximum.toInt number.toInt

/-- 通常の未知位置と区別して保持する、Result と Ok 成功値の由来。 -/
inductive RangeLocalFact where
  | result (origin : RangeOrigin)
  | checked (origin : RangeOrigin) (bindingId : Nat)

/-- 成功値の記録は、その値を結び付けた番号にだけ有効である。 -/
def RangeLocalFact.Models (fact : RangeLocalFact) (bindingId : Nat)
    (value : ConcreteValue) : Prop :=
  match fact with
  | .result origin => origin.ResultModels value
  | .checked origin successId => successId = bindingId ∧ origin.CheckedModels value

/-- 整数の環境を強めずに保持する補助記録。位置は通常束縛・専用位置と共通である。 -/
structure RangeState where
  scope : BindingScope
  facts : List (Option RangeLocalFact)

/-- 位置と番号の対応、および次番号が現在の全番号より大きい条件。 -/
def RangeState.Valid (state : RangeState) : Prop :=
  state.facts.length = state.scope.positions.length ∧
    ∀ id ∈ state.scope.positions, id < state.scope.nextId

/-- 記録のある局所値だけについて同一性を要求する。既存 Models の定義は変えない。 -/
def RangeState.Models (state : RangeState) (env : ConcreteEnv) : Prop :=
  ∀ index fact, state.facts[index]? = some (some fact) →
    ∃ id value, state.scope.idAt index = some id ∧
      env.locals[index]? = some (some value) ∧ fact.Models id value

/-- 引数・捕捉値の入口。位置と番号を残すが、Range の由来を仮定しない。 -/
def RangeState.empty (scope : BindingScope) : RangeState :=
  ⟨scope, List.replicate scope.positions.length none⟩

/-- 通常束縛・shadow・専用位置は全て番号を増やし、未知位置も一つ数える。 -/
def RangeState.extend (state : RangeState) (fact : Option RangeLocalFact) : RangeState :=
  ⟨state.scope.fresh, fact :: state.facts⟩

/-- 合流・再包装・本体境界での忘却。端点が偶然同じでも由来を合成しない。 -/
def RangeState.forget (state : RangeState) : RangeState := .empty ⟨[], state.scope.nextId⟩

/-- 未知の入口は、任意の具体表現を持つ環境に対して成立する。 -/
theorem range_empty_models (scope : BindingScope) (env : ConcreteEnv) :
    (RangeState.empty scope).Models env := by
  intro index fact found
  simp only [RangeState.empty, List.getElem?_replicate] at found
  split at found <;> simp_all

/-- 由来を忘れる操作は、具体環境に条件を加えない。 -/
theorem range_forget_models (state : RangeState) (env : ConcreteEnv) :
    state.forget.Models env := range_empty_models ⟨[], state.scope.nextId⟩ env

/-- 位置を一つ増やしても、番号の新規性の条件と記録の長さを保つ。 -/
theorem range_extend_valid {state : RangeState} (valid : state.Valid) (fact : Option RangeLocalFact) :
    (state.extend fact).Valid :=
  ⟨congrArg Nat.succ valid.1, state.scope.fresh_valid valid.2⟩

/-- 追加する値の記録が正しければ、既存の値と記録の対応も保つ。 -/
theorem range_extend_models {state : RangeState} {env : ConcreteEnv} {value : ConcreteValue}
    {fact : Option RangeLocalFact}
    (related : state.Models env)
    (head : ∀ known, fact = some known → known.Models state.scope.nextId value) :
    (state.extend fact).Models { env with locals := some value :: env.locals } := by
  intro index known found
  cases index with
  | zero =>
    simp only [RangeState.extend, List.getElem?_cons_zero, Option.some.injEq] at found
    exact ⟨state.scope.nextId, value, rfl, rfl, head known found⟩
  | succ index =>
    obtain ⟨id, old, atId, atValue, modeled⟩ := related index known found
    exact ⟨id, old, atId, atValue, modeled⟩

/-- 通常の複数位置を増やし、その位置には成功由来を推測しない。 -/
def RangeState.extendUnknown : RangeState → Nat → RangeState
  | state, 0 => state
  | state, count + 1 => (state.extendUnknown count).extend none

/-- 同じ未知位置の追加は、先頭を一つ構成してから残りを作っても一致する。 -/
theorem RangeState.extendUnknown_extend (state : RangeState) (count : Nat) :
    (state.extend none).extendUnknown count = (state.extendUnknown count).extend none := by
  induction count with
  | zero => rfl
  | succ count ih => simpa only [RangeState.extendUnknown] using congrArg (·.extend none) ih

/-- 由来を持たない新位置の追加は、任意の具体値に対応する。 -/
theorem range_extend_unknown_models {state : RangeState} {env : ConcreteEnv}
    (related : state.Models env) (value : Option ConcreteValue) :
    (state.extend none).Models { env with locals := value :: env.locals } := by
  intro index fact found
  cases index with
  | zero => simp [RangeState.extend] at found
  | succ index =>
    obtain ⟨id, old, atId, atValue, modeled⟩ := related index fact found
    exact ⟨id, old, atId, atValue, modeled⟩

/-- 複数の未知位置も既存の成功値の同一性を保存する。 -/
theorem range_extend_unknowns_models {state : RangeState} {env : ConcreteEnv}
    (related : state.Models env) (values : List (Option ConcreteValue)) :
    (state.extendUnknown values.length).Models
      { env with locals := values ++ env.locals } := by
  induction values with
  | nil => exact related
  | cons value rest ih =>
    exact range_extend_unknown_models ih value

/-- 同じ位置の記録を捨てる忘却は冪等である。 -/
theorem RangeState.forget_idempotent (state : RangeState) : state.forget.forget = state.forget := rfl

end Benitoite.Interval
