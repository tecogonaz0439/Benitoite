import Benitoite.Release.Refinement.Surface.Basic
import Benitoite.Scope.Inference
import Benitoite.Interval.Budget

/-!
# Scope の必須の判定の状態と予算

規則の表を篩付きの型の核の値で具体化し、局所の由来と、操作数・保持数の上限を別に持つ。
上限を超えた解析は由来を忘れ、後続の束縛へ由来を加えない
（設計書 01-12「Scope の局所解析の状態と規則の表」「Scope の局所解析の予算と忘却」）。
-/
namespace Benitoite.Release.Refinement.Surface.ScopeState

open Benitoite.Scope.Inference
open Benitoite.Scope.Domain (Range)

/-- 整数のリテラルの抽象の綴り。 -/
def intLitText (n : Integer64Value) : String := String.ofList ('\u0000' :: n.toInt.repr.toList)

/-- 抽象の綴りが整数のリテラルなら、その整数。 -/
def litInt? (s : String) : Option Int :=
  match s.toList with
  | '\u0000' :: rest => (String.ofList rest).toInt?
  | _ => none

/-- 解決済みの宣言の所有元。標準の所有元か、利用者のモジュールか。 -/
inductive Owner where
  | standard
  | user (module : String)
  deriving DecidableEq, Repr

/-- 出現を解決した宣言（所有元と宣言の名前）。 -/
structure Resolved where
  owner : Owner
  declaration : String
  deriving DecidableEq, Repr

/-- 出現の解決の結果から作る表。`apiAt` は標準の所有元に解決した宣言だけを返し、同じ綴りの利用者の関数は
入らない。 -/
def standardTable (resolve : Key → Option Resolved) (rules : String → Option (ScopeRule Refinement.Val)) :
    ScopeTable Refinement.Val where
  apiAt key :=
    match resolve key with
    | some ⟨.standard, d⟩ => some d
    | _ => none
  rules := rules

inductive Arg where
  | lit (s : String)
  | int (n : Integer64Value)
  | loc (index : Nat)
  | proj (key : Key) (index : Nat)
  | other
  deriving DecidableEq, Repr

/-- 抽象の引数。整数のリテラルは `intLitText` の綴りにする。先頭が U+0000 で整数の綴りと読める文字列のリテラルは、
整数のリテラルと取り違えないよう未知にする。 -/
def absArg (T : ScopeTable Refinement.Val) (st : ScopeState) : Arg → AbsArg
  | .lit s => if (litInt? s).isSome then .unknown else .lit s
  | .int n => .lit (intLitText n)
  | .loc i => st.readLocal i
  | .proj key i =>
    match absApply T key [st.readLocal i] with
    | some f => .value f
    | none => .unknown
  | .other => .unknown

/-- 文の一段。`call` は標準の直接呼び出しの結果を新しい位置へ一度だけ保存する。`okArm i` は位置 i の Result の
`Ok` の腕で成功値を新しい位置へ束縛する。`alias i` は別名、`unknown` は未知の呼び出し・再包装・リテラルの束縛、
`join` は合流と本体の境界。 -/
inductive Step where
  | call (key : Key) (args : List Arg)
  | okArm (index : Nat)
  | alias (index : Nat)
  | unknown
  | join
  deriving DecidableEq, Repr

/-- 抽象の一段。成功値の事実を作るのは `okArm` だけで、読む Result の事実の由来を写し、新しい位置の束縛番号を
成功値番号にする。 -/
def absStep (T : ScopeTable Refinement.Val) (st : ScopeState) : Step → ScopeState
  | .call key args => st.extend (absApply T key (args.map (absArg T st)))
  | .okArm i =>
    st.extend <|
      match st.facts[i]? with
      | some (some (.result o)) => some (.checked o st.scope.nextId)
      | _ => none
  | .alias _ => st.extend none
  | .unknown => st.extend none
  | .join => st.forgetAll

abbrev LimitFailure := Benitoite.Interval.Budget.LimitFailure

/-- 一つの範囲に許す累積の操作数と同時の保持項目数。 -/
structure Cap where
  operations : Nat
  items : Nat
  deriving DecidableEq, Repr

/-- 本体と全体の上限。既定値を持たない（値は処理系の測定で決める）。 -/
structure Limits where
  body : Cap
  whole : Cap
  deriving DecidableEq, Repr

/-- 必須の判定の予算の状態。現在の本体の累積の操作数、全体の累積の操作数、外側の本体が保持する項目の数。
現在の本体の保持項目の数は局所状態から数える（`heldItems`）。 -/
structure Budget where
  bodyOperations : Nat
  wholeOperations : Nat
  outerItems : Nat
  deriving DecidableEq, Repr

def Budget.initial : Budget := ⟨0, 0, 0⟩

/-- 保持の数え方。事実を持つ位置ごとに一項であり、由来は事実に含める。事実を持たない位置は数えない。 -/
def heldItems (st : ScopeState) : Nat := st.facts.countP Option.isSome

/-- 局所の読み取りの操作数。位置の読み取りに一回、同じ成功値の事実なら再照合に一回。 -/
def readCost (st : ScopeState) (i : Nat) : Nat :=
  1 + match st.facts[i]? with
    | some (some (.checked _ _)) => 1
    | _ => 0

/-- 引数の操作数。リテラルとそれ以外の式は数えず、局所の読み取りと、射影ならその適用に一回。 -/
def argCost (st : ScopeState) : Arg → Nat
  | .lit _ | .int _ | .other => 0
  | .loc i => readCost st i
  | .proj _ i => readCost st i + 1

/-- 一段の操作数（計上点）。呼び出しは出現の同定と表の参照に一回、引数ごとの操作数、事実を書き込めば一回。
`Ok` の腕は Result の位置の読み取りに一回、由来を写せば一回。別名は読み取りに一回。忘却は事実を持つ位置の数。 -/
def stepCost (T : ScopeTable Refinement.Val) (st : ScopeState) : Step → Nat
  | .call key args =>
    1 + (args.map (argCost st)).sum + (if (absApply T key (args.map (absArg T st))).isSome then 1 else 0)
  | .okArm i =>
    1 + match st.facts[i]? with
      | some (some (.result _)) => 1
      | _ => 0
  | .alias _ => 1
  | .unknown => 0
  | .join => heldItems st

/-- 計上。操作数を加え、計上の後の保持数を確かめる。操作数を保持数より先に、本体を全体より先に報告する。
拒否では候補の状態を採用しない。 -/
def Budget.checkLimit (L : Limits) (b : Budget) (ops held : Nat) : Except LimitFailure Budget :=
  let next : Budget := { b with bodyOperations := b.bodyOperations + ops,
                                wholeOperations := b.wholeOperations + ops }
  if next.bodyOperations > L.body.operations then .error ⟨.body, .operations⟩
  else if next.wholeOperations > L.whole.operations then .error ⟨.whole, .operations⟩
  else if held > L.body.items then .error ⟨.body, .items⟩
  else if b.outerItems + held > L.whole.items then .error ⟨.whole, .items⟩
  else .ok next

/-- 本体の入口（ラムダ、handle の保護本体と節、Task の入口）。現在の本体の保持を外側の保持へ移し、本体の操作数を
0 から数える。全体の操作数は引き継ぐ。 -/
def Budget.enter (b : Budget) (held : Nat) : Budget :=
  { b with bodyOperations := 0, outerItems := b.outerItems + held }

/-- 本体の出口。外側の本体の操作数と保持へ戻し、全体の操作数は内側の値を引き継ぐ。 -/
def Budget.leave (outer inner : Budget) : Budget :=
  { outer with wholeOperations := inner.wholeOperations }

/-- 由来を作らない一段。位置と番号は通常の一段と同じに保つ（予算の超過の後に使う）。 -/
def blindStep (st : ScopeState) : Step → ScopeState
  | .join => st.forgetAll
  | _ => st.extend none

/-- 予算付きの局所解析の状態。上限内で進む状態か、超過の補足と、全ての由来を忘れた状態。 -/
inductive Run where
  | running (st : ScopeState) (budget : Budget)
  | stopped (failure : LimitFailure) (st : ScopeState) (budget : Budget)

def Run.state : Run → ScopeState
  | .running st _ | .stopped _ st _ => st

def Run.budget : Run → Budget
  | .running _ b | .stopped _ _ b => b

/-- 超過の理由。診断の理由の `budgetExceeded` に当たり、補足の欄に本体か全体か、操作数か保持数かを持つ。 -/
inductive ExceedReason where
  | budgetExceeded (detail : LimitFailure)
  deriving DecidableEq, Repr

def Run.exceeded : Run → Option ExceedReason
  | .running _ _ => none
  | .stopped f _ _ => some (.budgetExceeded f)

/-- 予算付きの一段。計上が上限内なら通常の一段、超えたら予算の状態を変えずに全ての由来を忘れて止まる。止まった後は
由来を作らず、計上もしない。 -/
def Run.step (T : ScopeTable Refinement.Val) (L : Limits) : Run → Step → Run
  | .running st b, s =>
    let next := absStep T st s
    match b.checkLimit L (stepCost T st s) (heldItems next) with
    | .ok b' => .running next b'
    | .error f => .stopped f (blindStep st.forgetAll s) b
  | .stopped f st b, s => .stopped f (blindStep st s) b

def Run.steps (T : ScopeTable Refinement.Val) (L : Limits) : Run → List Step → Run
  | r, [] => r
  | r, s :: ss => Run.steps T L (r.step T L s) ss

/-- 本体の入口の予算付きの状態。由来を仮定しない。全体の上限の超過は内側にも及ぶ。 -/
def Run.enter (scope : Interval.BindingScope) : Run → Run
  | .running st b => .running (ScopeState.empty scope) (b.enter (heldItems st))
  | .stopped f st b =>
    if f.scope = .whole then .stopped f (ScopeState.empty scope) b
    else .running (ScopeState.empty scope) (b.enter (heldItems st))

/-- 本体の出口。外側の状態に戻り、全体の操作数を引き継ぐ。内側が全体の上限を超えていたら外側も止まる。 -/
def Run.leave (outer inner : Run) : Run :=
  match inner with
  | .stopped f _ ib =>
    if f.scope = .whole then .stopped f outer.state.forgetAll (outer.budget.leave ib)
    else
      match outer with
      | .running st b => .running st (b.leave ib)
      | .stopped g st b => .stopped g st (b.leave ib)
  | .running _ ib =>
    match outer with
    | .running st b => .running st (b.leave ib)
    | .stopped g st b => .stopped g st (b.leave ib)


end Benitoite.Release.Refinement.Surface.ScopeState
